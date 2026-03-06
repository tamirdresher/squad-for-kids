# Azure Fleet Manager Security Analysis for DK8S RP

**Author:** Worf — Security & Cloud  
**Date:** 2026-03-07  
**Issue:** #3 — Azure Fleet Manager evaluation for DK8S RP  
**Classification:** Internal — Security Assessment  
**Status:** Active Analysis

---

## Executive Summary

This analysis evaluates the security implications of adopting Azure Kubernetes Fleet Manager (AKFM) for the DK8S Resource Provider. Three critical security domains require resolution before adoption: **Federated Identity Credentials (FIC) scaling limits**, **identity movement risks during cross-cluster workload migration**, and **sovereign cloud compliance gaps**. Internal discussions (Feb 18, 2026 meeting) confirm these are first-order concerns, not afterthoughts. DK8S is explicitly described as a **nation-state target**, demanding bulkhead isolation and region-scoped fleets.

---

## 1. Federated Identity Credentials (FIC) Analysis

### 1.1 What FIC Means for DK8S

Federated Identity Credentials allow Kubernetes pods to authenticate to Azure services (KeyVault, Storage, ACR) without storing secrets. Instead, the AKS OIDC issuer signs tokens for service accounts, which Entra ID trusts via configured FIC entries on a User-Assigned Managed Identity (UAMI).

**Current DK8S Identity State:**
- DK8S uses AAD Pod Identity (deprecated, migration to Workload Identity underway)
- Celestial (idk8s) uses UAMI per deployment unit with dSMS/dSTS
- Both platforms use `WDATP.Infra.System.AadPodIdentity` (being sunset)

### 1.2 FIC Scaling Limits — The 20-FIC Ceiling

| Constraint | Value | Impact on DK8S |
|-----------|-------|----------------|
| Max FICs per UAMI | 20 | With 50+ clusters, DK8S cannot map all clusters to a single workload identity |
| Max FICs per App Registration | 20 | Same ceiling applies to app registrations |
| FIC per cluster OIDC issuer | 1 per (namespace, service-account) pair | Each cluster has a unique OIDC issuer URL |

**DK8S Scale Problem:**
- DK8S has clusters across US NAT, US SEC, Azure Gov, Blue, Delos, and public cloud
- Celestial manages 27+ clusters across 7 sovereign clouds
- With 19 tenants and multiple service accounts per tenant, FIC requirements exceed 20 per UAMI rapidly

**Risk:** Identity sprawl. Teams create duplicate UAMIs with identical permissions solely to work around the 20-FIC limit, increasing management complexity and misconfiguration risk.

### 1.3 FIC Security Concerns

| Concern | Severity | Details |
|---------|----------|---------|
| **Broad trust relationships** | HIGH | Misconfigured FIC issuer/subject can grant unintended access. A compromised OIDC issuer affects all FICs trusting it. |
| **Identity reuse/copy attacks** | HIGH | Partners copying FIC configurations into unauthorized plugins (zero-trust concern raised in internal doc). |
| **Audit gaps** | MEDIUM | FIC addition/removal not always monitored. Changes grant/revoke significant access silently. |
| **Token lifetime** | MEDIUM | Default 24h token lifetime creates persistent access window even after intent changes. |
| **Conditional Access gaps** | MEDIUM | Conditional Access policies may not apply equally to all FIC scenarios in multi-tenant contexts. |

### 1.4 Emerging Mitigations

| Solution | Status | Applicability to DK8S |
|----------|--------|----------------------|
| **Identity Bindings (AKS)** | Public Preview | Maps UAMI to multiple clusters with single FIC. Removes 20-FIC barrier. **Not recommended for production yet.** |
| **Flexible FICs (Entra)** | Preview | Wildcard/expression matching reduces FIC count. **Not GA, sovereign cloud availability unknown.** |
| **Multiple UAMIs** | GA | Partition workloads across UAMIs. Operationally heavy but supported. |
| **Namespace/Workload Segmentation** | GA | Careful service-account-to-UAMI mapping. Requires discipline. |

---

## 2. Identity Movement Risks

### 2.1 The Core Problem

When Fleet Manager moves workloads between clusters (the primary value proposition), the workload's identity must move with it. This creates several security risks:

```
Cluster A (source)          Fleet Manager          Cluster B (target)
┌──────────────────┐    ┌──────────────┐    ┌──────────────────┐
│ Pod with UAMI    │───>│ Orchestrates │───>│ Pod needs same   │
│ FIC: OIDC-A      │    │ migration    │    │ UAMI access      │
│ Subject: SA-A    │    │              │    │ FIC: OIDC-B ???  │
└──────────────────┘    └──────────────┘    └──────────────────┘
```

**The FIC on the UAMI references Cluster A's OIDC issuer.** When the pod moves to Cluster B, a **new FIC entry referencing Cluster B's OIDC issuer** must exist on the same UAMI — or the workload loses Azure access.

### 2.2 Identity Movement Risk Matrix

| Risk | Severity | Likelihood | Impact | Description |
|------|----------|------------|--------|-------------|
| **R1: FIC pre-provisioning failure** | CRITICAL | Medium | Service outage | If FICs for target cluster aren't pre-configured, migrated workloads lose Azure access immediately |
| **R2: Stale FIC accumulation** | HIGH | High | Identity sprawl | FICs for decommissioned clusters remain, creating unnecessary trust relationships |
| **R3: UAMI node-level exposure** | CRITICAL | Medium | Lateral movement | In shared fleets, anyone on the node can access UAMI and attached resources (confirmed by Falcon team: "UAMI is not secure in shared systems") |
| **R4: Cluster identity as app identity** | CRITICAL | Medium | Blast radius expansion | Past DK8S mistake: using kubelet MI as app identity blocked mobility and created giant security groups violating least-privilege (confirmed in Feb 18 meeting) |
| **R5: Identity continuity gap during migration** | HIGH | Medium | Authentication failure | Window between old-cluster teardown and new-cluster FIC activation causes auth failures |
| **R6: Cross-tenant identity leakage** | HIGH | Low | Unauthorized access | Fleet Manager operating across tenant boundaries could expose identities to wrong tenant |
| **R7: Sovereign cloud FIC mismatch** | HIGH | Medium | Compliance violation | FIC configurations differ across sovereign clouds; automated migration could apply wrong config |

### 2.3 Internal Evidence

**From Feb 18, 2026 meeting (Defender/AKS follow-up):**
- Joshua Johnson explicitly called out a past design mistake: allowing app teams to use node/kubelet managed identity as application identity
- This **blocked workload mobility between clusters** because identity was tied to the cluster
- Created a "giant security group of cluster identities" flagged by EV2 as violating least-privilege

**From Partner Federated Identity Credentials document:**
- Abhishek Gupta (Falcon) warned: "UAMI is not secure in shared systems like FalconFleet — anyone on the node can access the identity and attached resources"
- Workload Identity is the only truly secure setup in shared fleet environments

**From Fleet Manager internal discussion:**
- Identity binding explicitly identified as a **blocker/precondition** for seamless workload migration
- Need to validate identity management when clusters are replaced

---

## 3. Security Architecture Assessment

### 3.1 Fleet Manager Identity Model

Fleet Manager uses managed identities for its own control plane:

| Identity Type | Purpose | Risk Level |
|--------------|---------|------------|
| System-assigned MI | Tied to Fleet Manager resource; deleted when FM deleted | LOW — lifecycle-managed |
| User-assigned MI | Standalone; persists independently; can be shared | MEDIUM — requires governance |
| Hub cluster identity | Fleet Manager hub authenticates member clusters | HIGH — central trust anchor |

**DK8S-Specific Concern:** DK8S is a **nation-state target**. A compromised Fleet Manager hub identity would provide access to orchestrate workloads across all member clusters. This demands:
- Region-scoped fleets (no single global control plane)
- Bulkhead isolation between fleet segments
- Separate Fleet Manager instances per security boundary

### 3.2 Attack Surface Analysis

| Attack Vector | Current (No Fleet) | With Fleet Manager | Delta |
|--------------|-------------------|-------------------|-------|
| **Control plane compromise** | Per-cluster blast radius | Multi-cluster blast radius | ⬆️ INCREASED |
| **Identity theft** | Cluster-scoped impact | Fleet-scoped impact | ⬆️ INCREASED |
| **Lateral movement** | Namespace isolation | Cross-cluster if shared UAMI | ⬆️ INCREASED |
| **Secret exposure** | Per-cluster secrets | Fleet-wide if centralized | ⬆️ INCREASED |
| **Supply chain** | Per-cluster CI/CD | Fleet-wide deployment | ⬆️ INCREASED |
| **DDoS/availability** | Per-cluster impact | Fleet-wide if hub targeted | ⬆️ INCREASED |

### 3.3 DK8S-Specific Security Requirements

| Requirement | Fleet Manager Readiness | Gap |
|-------------|------------------------|-----|
| Nation-state threat model | Partial — region-scoping possible | No documented threat model for Fleet Manager itself |
| Sovereign cloud parity | **NOT MET** — features lag in US NAT, US SEC, Blue, Delos | Hard blocker per Feb 18 meeting |
| Workload Identity (not Pod Identity) | Supported | DK8S migration from AAD Pod Identity still in progress |
| Least-privilege identity | Supported via RBAC | Requires discipline; easy to over-provision |
| Default-deny network policies | Orthogonal | Existing gap (Decision 3) compounds Fleet risk |
| Certificate automation | Orthogonal | Existing gap (Decision 3) compounds Fleet risk |

---

## 4. Compliance Considerations

### 4.1 Sovereign Cloud Compliance Matrix

| Cloud | Compliance Framework | Fleet Manager Status | FIC/WI Status | Risk |
|-------|---------------------|---------------------|---------------|------|
| Azure Public | Standard | GA | GA | LOW |
| Fairfax (US Gov) | FedRAMP High | Limited GA | GA | MEDIUM — feature lag |
| US NAT | ITAR/EAR | **Unknown/Limited** | Partial | **HIGH — hard constraint** |
| US SEC | DoD IL5+ | **Unknown/Limited** | Partial | **HIGH — hard constraint** |
| Blue (EU) | GDPR/EUCS | **Unknown/Limited** | Partial | **HIGH — data residency** |
| Delos | EU data sovereignty | **Unknown/Limited** | Partial | **HIGH — data residency** |
| Mooncake (China) | MLPS 2.0/3.0 | **Unknown** | Partial (dSTS only) | **CRITICAL — separate operator** |

### 4.2 Compliance Risks

| Risk | Framework | Impact | Mitigation |
|------|-----------|--------|------------|
| Identity data crossing sovereignty boundary | GDPR, FedRAMP, ITAR | Data residency violation | Region-scoped Fleet instances; no cross-cloud federation |
| FIC configuration drift across clouds | All | Inconsistent security posture | OPA/Rego policy enforcement per cloud; automated compliance checks |
| Fleet Manager feature disparity | FedRAMP, DoD | Inconsistent capability | Minimum viable feature set defined per cloud; fallback to direct AKS |
| Audit trail gaps in identity changes | SOC 2, FedRAMP | Compliance audit failure | Azure Activity Log + custom alerting for FIC CRUD operations |
| Private preview dependency | All | Unsupported in production | Only GA features in sovereign clouds; no preview dependencies |

---

## 5. Risk Matrix — Impact × Likelihood

### 5.1 Comprehensive Risk Assessment

| ID | Risk | Impact (1-5) | Likelihood (1-5) | Score | Priority |
|----|------|:----------:|:---------------:|:-----:|:--------:|
| **R-SEC-01** | Fleet hub compromise → multi-cluster blast radius | 5 | 2 | **10** | 🔴 CRITICAL |
| **R-SEC-02** | UAMI node-level exposure in shared fleet | 5 | 3 | **15** | 🔴 CRITICAL |
| **R-SEC-03** | Sovereign cloud feature unavailability | 4 | 4 | **16** | 🔴 CRITICAL |
| **R-SEC-04** | FIC scaling ceiling (20 per UAMI) | 4 | 4 | **16** | 🔴 CRITICAL |
| **R-SEC-05** | Identity continuity gap during migration | 4 | 3 | **12** | 🟠 HIGH |
| **R-SEC-06** | Stale FIC accumulation/sprawl | 3 | 4 | **12** | 🟠 HIGH |
| **R-SEC-07** | Cluster identity used as app identity (repeat of past mistake) | 5 | 2 | **10** | 🟠 HIGH |
| **R-SEC-08** | Cross-cloud FIC configuration drift | 3 | 3 | **9** | 🟡 MEDIUM |
| **R-SEC-09** | Zero-trust violation via FIC copy attacks | 4 | 2 | **8** | 🟡 MEDIUM |
| **R-SEC-10** | Token lifetime creates persistent access window | 3 | 2 | **6** | 🟡 MEDIUM |
| **R-SEC-11** | Audit trail gaps for FIC CRUD | 3 | 2 | **6** | 🟡 MEDIUM |
| **R-SEC-12** | Conditional Access bypass in FIC scenarios | 3 | 2 | **6** | 🟡 MEDIUM |

### 5.2 Heat Map

```
              LIKELIHOOD
         1    2    3    4    5
    5  │    │R01 │R02 │    │    │  ← Catastrophic
I   4  │    │R09 │R05 │R03 │    │  ← Major
M   3  │    │R10 │R08 │R06 │    │  ← Moderate
P      │    │R11 │    │    │    │
A   2  │    │R12 │    │    │    │  ← Minor
C   1  │    │    │    │    │    │  ← Negligible
T      └────┴────┴────┴────┴────┘
         Rare  Unl  Poss Likely Almost
```

---

## 6. Proposed Mitigations

### 6.1 Pre-Adoption Requirements (Must-Have Before Fleet Manager)

| # | Mitigation | Addresses Risk | Owner | Timeline |
|---|-----------|---------------|-------|----------|
| **M1** | Complete Workload Identity migration (retire AAD Pod Identity) | R-SEC-02, R-SEC-07 | DK8S Platform | Before Fleet adoption |
| **M2** | Validate Fleet Manager GA in all target sovereign clouds | R-SEC-03 | DK8S Platform + AKS PM | Before Fleet adoption |
| **M3** | Design region-scoped Fleet instances (no global hub) | R-SEC-01 | Architecture | Before Fleet adoption |
| **M4** | Establish FIC scaling strategy (Identity Bindings or multi-UAMI) | R-SEC-04 | Identity Team | Before Fleet adoption |

### 6.2 Architecture Controls (Design-Time)

| # | Mitigation | Addresses Risk | Details |
|---|-----------|---------------|---------|
| **M5** | Workload-scoped identity only | R-SEC-02, R-SEC-07 | Never use node/kubelet identity as application identity. Each workload gets dedicated UAMI. |
| **M6** | Pre-provision FICs for all target clusters | R-SEC-05 | Before any migration, validate FIC exists on target cluster's OIDC issuer for all required service accounts. |
| **M7** | FIC lifecycle automation | R-SEC-06 | Automated FIC cleanup when clusters are decommissioned. Azure Policy or custom controller. |
| **M8** | Per-cloud FIC configuration templates | R-SEC-08 | OPA/Rego policies enforce correct FIC configuration per sovereign cloud. No cross-cloud copy-paste. |
| **M9** | Bulkhead Fleet segmentation | R-SEC-01 | Separate Fleet Manager instances per: security boundary, sovereign cloud, compliance zone. |

### 6.3 Operational Controls (Run-Time)

| # | Mitigation | Addresses Risk | Details |
|---|-----------|---------------|---------|
| **M10** | FIC CRUD monitoring and alerting | R-SEC-11 | Azure Activity Log alerts for all FIC create/update/delete operations. Integrate with SIEM. |
| **M11** | Periodic FIC audit | R-SEC-06, R-SEC-09 | Quarterly review: enumerate all FICs, validate each maps to active cluster/service-account, remove stale entries. |
| **M12** | Token lifetime governance | R-SEC-10 | Configure minimum viable token lifetimes. Monitor for long-lived tokens. |
| **M13** | Fleet Manager hub integrity monitoring | R-SEC-01 | Dedicated monitoring for hub cluster health, identity usage anomalies, unauthorized member registration. |
| **M14** | Sovereign cloud compliance gate | R-SEC-03 | Automated pre-deployment check: verify required Fleet Manager features are GA in target cloud before any fleet operation. |

### 6.4 Migration-Specific Controls

| # | Mitigation | Addresses Risk | Details |
|---|-----------|---------------|---------|
| **M15** | Pre-flight identity validation | R-SEC-05 | Before workload migration: verify FIC exists on target, test token acquisition from target cluster, validate RBAC assignments. |
| **M16** | Rollback identity plan | R-SEC-05 | If migration fails, ensure source cluster FICs remain intact. Never delete source FICs until target is validated. |
| **M17** | Zero-trust FIC scope enforcement | R-SEC-09 | FIC subject must specify exact namespace + service-account. No wildcard subjects. Azure Policy enforces. |

---

## 7. Recommendations

### 7.1 Go/No-Go Decision Framework

Fleet Manager adoption for DK8S should be **conditional** on:

| Gate | Condition | Status |
|------|-----------|--------|
| **G1** | Workload Identity migration complete | 🟡 In Progress |
| **G2** | Fleet Manager GA in US NAT, US SEC, Blue, Delos | 🔴 Not Met |
| **G3** | FIC scaling solution (Identity Bindings or alternative) GA | 🔴 Preview Only |
| **G4** | Region-scoped Fleet architecture approved | 🟡 Design Phase |
| **G5** | FIC lifecycle automation deployed | 🔴 Not Started |
| **G6** | Threat model for Fleet Manager hub documented | 🔴 Not Started |

**Current Recommendation: CONDITIONAL NO-GO** — proceed with design and PoC in public cloud only, while waiting for G2 and G3.

### 7.2 Phased Adoption Path

| Phase | Scope | Prerequisites | Timeline |
|-------|-------|--------------|----------|
| **Phase 0: PoC** | Single region, public cloud, non-production | M1, M3, M5 | Q2 2026 |
| **Phase 1: Limited** | Public cloud production, single region | M1–M9, G1, G4 | Q3 2026 |
| **Phase 2: Multi-region** | Public cloud, multi-region | All M1–M17, G1, G3, G4 | Q4 2026 |
| **Phase 3: Sovereign** | Sovereign clouds | G2, G5, G6 + all prior | 2027+ (dependent on AKS roadmap) |

---

## 8. Sources

### Internal Sources
1. **Feb 18, 2026 — Defender/AKS Follow-up Discussion** — Fleet Manager evaluation, identity blast radius, sovereign cloud constraints
2. **Feb 18, 2026 — Fleet Manager Internal Discussion** — Identity binding as migration blocker, cluster replacement identity continuity
3. **Partner Federated Identity Credentials.docx** — FIC security concerns, UAMI exposure in shared fleets, zero-trust gaps
4. **DK8S Platform Announcements (June–Sept 2025)** — AAD Pod Identity deprecation, workload-scoped identity mandate

### EngineeringHub Documentation
5. [FIC with Pod Identity in FalconFleet](https://eng.ms/docs/microsoft-ai/webxt/bing-fundamentals/falcon/falcon/falcon-partner-documentation/content/scale/security/podidentityfic)
6. [Fleet Workload Identity Setup Guide](https://eng.ms/docs/microsoft-security/cloud-ecosystem-security/microsoft-sentinel-graph-msg/security-platform-ecosystem/security-platform-purview/playground-preview-your-doc-here/teams/workload_infra/workload_onboarding/how_to_guides/common/fleet_workload_identity_setup)
7. [MSI FIC Setup Guide (App Service)](https://eng.ms/docs/coreai/devdiv/serverless-paas-balam/serverless-paas-vikr/app-service-web-apps/app-service-team-documents/generalteamdocs/security/msiadoption/msi-federatedidentitycredential)

### External References
8. [Azure Fleet Manager — Managed Identity](https://learn.microsoft.com/en-us/azure/kubernetes-fleet/use-managed-identity)
9. [AKS Workload Identity Overview](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)
10. [Identity Bindings for AKS (Preview)](https://learn.microsoft.com/en-us/azure/aks/identity-bindings-concepts)
11. [Flexible FICs (Preview)](https://learn.microsoft.com/en-us/entra/workload-id/workload-identities-flexible-federated-identity-credentials)
12. [Identify and Prevent Abuse of UAMI with FedCreds](https://www.cloud-architekt.net/identify-prevent-abuse-uami-fedcreds/)

### Team Knowledge Base
13. dk8s-platform-knowledge.md — Platform architecture, security findings
14. dk8s-infrastructure-inventory.md — Cluster inventory, identity infrastructure
15. analysis-worf-security.md — Prior security deep-dive (Decision 3)

---

*"A warrior does not adopt new weapons without testing them against known threats. Fleet Manager is a powerful weapon — but untested in sovereign territory, and its identity model has gaps that adversaries will exploit."* — Worf
