# RP Registration Status — Private.BasePlatform

> **Author:** Picard (Lead)
> **Date:** 2026-03-08
> **Related:** Issue #11, IcM 757549503, Issues #3 (Fleet Manager), #4 (Stability/Aurora)
> **RP Namespace:** `Private.BasePlatform` (targeting `Microsoft.BasePlatform`)

---

## Executive Summary

The DK8S team is registering a **Hybrid RP** (`Private.BasePlatform`) on RPaaS to provide an ARM Resource Provider abstraction for Kubernetes workload deployment. IcM 757549503 — a **Sev 3 production incident** — reports a **Cosmos DB role assignment failure blocking RP manifest rollout**. The incident remains in **New** state with no confirmed resolution. The root cause is a `NullReferenceException` in `CosmosDbRoleAssignmentJob` caused by missing `jobMetadata` parameter. This is blocking the RP registration pipeline from progressing.

---

## 1. IcM 757549503 — Incident Summary

| Field | Value |
|-------|-------|
| **IcM ID** | 757549503 |
| **Title** | [Private.BasePlatform] Cosmos DB role assignment failure blocking RP manifest rollout |
| **Severity** | 3 — Medium |
| **Current State** | New (unresolved) |
| **Area Path** | MSAzure\One\Azure-ARM\Azure-ARM-Extensibility\Livesite |
| **Created By** | Andrew Gao |
| **Created Date** | 2026-03-06 |
| **Portal Link** | https://portal.microsofticm.com/imp/v3/incidents/details/757549503/home |

### What Was Asked

The IcM was filed to report that the **Cosmos DB role assignment step** during RP manifest rollout is failing, which blocks the RP from completing its registration/deployment to ARM. This is a prerequisite step that RPaaS performs when onboarding a new Hybrid RP — it automatically provisions a Cosmos DB instance and assigns role assignments for the RP's subscription.

### Root Cause (Identified)

- **Bug:** `CosmosDbRoleAssignmentJob` throws a `NullReferenceException` in `HandleDeploymentInJob` due to a **missing `jobMetadata` parameter**
- **Related ADO Bug:** Work item 37017046 (MSAzure/One project)
- **Related Incident:** IcM 754149871 — Cosmos DB deployments failing during role assignment creation with `InternalServerError` from `CreateRoleAssignmentInServerPartitionsAsync`

### What Response Was Received

Based on available intelligence:
- The IcM was **shared via email** by IcM Incident Management with the thread subject: `"RE: [PROD] Sev 3: ID 757549503: [Private.BasePlatform] Cosmos DB role assignment failure blocking RP manifest rollout"`
- A **related bug (ADO #37017046)** was filed by Andrew Gao identifying the `NullReferenceException` root cause
- **No resolution or mitigation has been recorded** — the incident remains in **New** state
- The ARM-Extensibility/Livesite team owns the investigation
- RPaaS IST Office Hours occurred recently but no transcript references this specific incident

### What Remains Unknown

- Whether the RPaaS team has communicated a **workaround** directly to the RP owner
- Whether the Cosmos DB role assignment failure is a **platform-wide issue** or specific to the Private.BasePlatform registration
- The **expected timeline** for the fix from the ARM-Extensibility team
- Whether **manual role assignment** can unblock the manifest rollout while the automation is fixed

---

## 2. Current RP Registration Status

### Registration Pipeline Progress

| Step | Status | Notes |
|------|--------|-------|
| RP namespace selected | ✅ Done | `Private.BasePlatform` (will become `Microsoft.BasePlatform`) |
| ServiceTree registration | ⚠️ Needs verification | ServiceTree ID required for onboarding IcM |
| RPaaS onboarding IcM filed | ✅ Done | IcM 757549503 filed 2026-03-06 |
| PC Code & Profit Center Program ID | ❓ Unknown | Required for billing — must be obtained from finance |
| Subscription allowlisted | ⚠️ Unclear | RPaaS DRI should have allowlisted via IcM |
| RP registration PUT | ❌ Blocked | Cosmos DB role assignment failure blocking this step |
| Operations RT registered | ❌ Not started | Depends on RP registration completing |
| Manifest checked in | ❌ Not started | Blocked by RP registration |
| Manifest rollout to ARM | ❌ Blocked | This is where the Cosmos DB failure occurs |
| Resource type registrations | ❌ Not started | Workspace, ClusterGroup, Namespace, Application, Deployment |
| Swagger/TypeSpec spec merged | ⚠️ In progress | TypeSpec exists in BasePlatformRP repo |
| AFEC feature flag | ❓ Unknown | `Microsoft.Resources/InventoryInternal` may be needed |
| Dogfood testing | ❌ Not started | Self-service in DF — no ARM assistance needed |
| Private Preview | ❌ Not started | Feature-flagged exposure control |

### Architecture Context

BasePlatformRP is a **Hybrid RP** that:
- Sits **above** idk8s-infrastructure (Celestial) in the stack
- Provides ARM abstraction for K8s workload deployment across providers (DK8S, Celestial, ACA)
- Uses **TypeSpec → OpenAPI → generated C# controllers/models** (ARM-compliant)
- Stores state in **MetaRP + Cosmos DB** via BaseRP framework
- Has a dual-storage pattern with async queue-based workers
- Targets resource hierarchy: `Workspace → ClusterGroup → Namespace → Application → Deployment`

---

## 3. Next Steps — Action Plan

### Immediate (This Week)

| # | Action | Owner | Status |
|---|--------|-------|--------|
| 1 | **Follow up on IcM 757549503** — Request status update from ARM-Extensibility/Livesite team. Ask if manual Cosmos DB role assignment can unblock. | Tamir / RP DRI | 🔴 Urgent |
| 2 | **Check IcM 754149871** — Related Cosmos DB role assignment failure. Determine if same root cause. | Tamir | 🔴 Urgent |
| 3 | **Verify ServiceTree metadata** — Confirm PC Code and Profit Center Program ID are correct. Check ServiceTree hierarchy for finance metadata. | Tamir | 🟡 High |
| 4 | **Confirm subscription allowlisting** — Verify RPaaS DRI completed the PUT mapping for Private.BasePlatform. | Tamir | 🟡 High |
| 5 | **Attend RPaaS IST Office Hours** — Raise the blocking Cosmos DB issue directly with RPaaS DRI team. | Tamir | 🟡 High |

### Short-Term (Next 2 Weeks)

| # | Action | Owner | Status |
|---|--------|-------|--------|
| 6 | **Complete RP registration PUT** — Once Cosmos DB issue is resolved, submit Hybrid RP registration with proper payload (kind: "Hybrid", providerType: "Internal, Hidden", PC Code, etc.) | Tamir / Dev | ⏳ Blocked |
| 7 | **Register Operations RT** — Submit managed Operations resource type registration (required ARM contract). | Dev | ⏳ Blocked |
| 8 | **TypeSpec spec finalization** — Ensure OpenAPI spec matches ARM requirements for all resource types. | Dev | 🟡 In progress |
| 9 | **Manifest checkin** — After RP registration, check manifest into ARM manifest repo. | Dev | ⏳ Blocked |

### Medium-Term (Next Month)

| # | Action | Owner | Status |
|---|--------|-------|--------|
| 10 | **Dogfood deployment & testing** — Self-service manifest application via ACIS in dogfood. Register RP under DF subscription. | Dev | ⏳ Not started |
| 11 | **AFEC feature flag setup** — Create exposure control for Private Preview. | Dev | ⏳ Not started |
| 12 | **CI/CD pipeline setup** — OneBranch PR validation + official build pipelines (major gap per cross-repo analysis). | Dev / Infra | ⏳ Not started |
| 13 | **API Review booking** — Schedule ARM API Modeling Review Office Hours for TypeSpec review and sign-off. | Tamir | ⏳ Not started |

---

## 4. Registration Requirements Checklist

Based on ARM/RPaaS documentation (eng.ms/docs/products/arm/rpaas/):

### Prerequisites

- [ ] **Resource Provider namespace** — `Private.BasePlatform` ✅
- [ ] **Subscription ID** — Team-owned subscription for RP hosting
- [ ] **ServiceTree ID** — Registered in ServiceTree with correct hierarchy
- [ ] **PC Code** — Valid billing Profit Center code from ServiceTree metadata
- [ ] **Profit Center Program ID** — From ServiceTree finance metadata (use "-1" if no corresponding program)
- [ ] **Swagger/TypeSpec spec** — GitHub URL to merged spec (exists in BasePlatformRP repo)
- [ ] **IcM routing info** — Incident routing service, team, and contact email
- [ ] **RP type decision** — Hybrid RP ✅ (confirmed in cross-repo analysis and RP Platform onboarding docs)

### RP Registration Payload (Hybrid RP Template)

```json
{
  "kind": "Hybrid",
  "properties": {
    "providerType": "Internal, Hidden",
    "requiredFeatures": [
      "Microsoft.Resources/InventoryInternal"
    ],
    "metadata": {
      "BypassManifestValidation": true
    },
    "tokenAuthConfiguration": {
      "authenticationScheme": "PoP",
      "signedRequestScope": "ResourceUri",
      "disableCertificateAuthenticationFallback": true
    },
    "management": {
      "incidentRoutingService": "<DK8S IcM Service>",
      "incidentRoutingTeam": "<DK8S IcM Team>",
      "incidentContactEmail": "<DK8S on-call email>",
      "serviceTreeInfos": [
        {
          "serviceId": "<ServiceTree ID>"
        }
      ],
      "pcCode": "<PC Code>",
      "profitCenterProgramId": "<Profit Center Program ID>"
    }
  }
}
```

### Post-Registration Steps

- [ ] **Operations RT registration** — Managed RT with operations/read endpoint
- [ ] **Resource Type registrations** — Workspace, ClusterGroup, Namespace, Application, Deployment
- [ ] **Manifest checked into ARM Manifest Repo**
- [ ] **Manifest rollout** — Self-service in dogfood, ARM approval for prod
- [ ] **AFEC feature flag** — Control exposure for Private Preview
- [ ] **API Review sign-off** — ARM API Modeling Review
- [ ] **SDK/CLI onboarding** — Not required for Private Preview but needed for GA

---

## 5. Blockers and Dependencies

| Blocker | Impact | Dependency | Mitigation |
|---------|--------|------------|------------|
| **Cosmos DB role assignment failure** (IcM 757549503) | Blocks entire RP manifest rollout | ARM-Extensibility/Livesite team fix | Follow up on IcM; ask about manual role assignment workaround |
| **Related Cosmos DB InternalServerError** (IcM 754149871) | May indicate platform-wide issue | Cosmos DB service team | Monitor for resolution; check if same root cause |
| **No CI/CD pipelines** | Cannot build/deploy RP service | OneBranch + EV2 setup | P1 priority — set up PR validation pipeline (Issue #6 in baseplatform-issues.md) |
| **Testing gaps** | Only 4 integration tests | Test infrastructure build-out | Aspire integration test expansion (Issue #7 in baseplatform-issues.md) |
| **Finance metadata** | Cannot complete RP registration without PC Code | Finance team / ServiceTree admin | Check ServiceTree metadata hierarchy |
| **API Review** | Required before GA (not Private Preview) | ARM API Review team | Book office hours early |

---

## 6. Key Documentation References

| Document | URL |
|----------|-----|
| RP Platform Onboarding (Hybrid/RP Lite) | https://eng.ms/docs/products/arm/rpaas/rp-lite/rpplatformonboarding |
| Onboarding New RP to RPaaS | https://eng.ms/docs/products/arm/rpaas/tsg/rpaas/partnericmtsgs/onboardingrpnewtsg |
| RP Registration (RP Lite) | https://eng.ms/docs/products/arm/rpaas/rp-lite/rplite_resourceproviderregistration |
| Resource Provider Onboarding Process | https://eng.ms/docs/products/arm/rp_onboarding/process/onboarding |
| Private RP Onboarding | https://eng.ms/docs/products/arm/rpaas/prp-onboarding |
| RPaaS Production User Guide | https://eng.ms/docs/products/arm/rpaas/production-user-guide |
| Below ARM RP User Guide | https://eng.ms/docs/products/arm/rpaas/below_arm |
| IcM 757549503 | https://portal.microsofticm.com/imp/v3/incidents/details/757549503/home |
| Cross-repo Analysis | `cross-repo-analysis-idk8s-to-baseplatformrp.md` (this repo) |
| BasePlatformRP Issues Roadmap | `baseplatform-issues.md` (this repo) |

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Cosmos DB fix takes >2 weeks | Medium | High — entire RP pipeline blocked | Escalate IcM; request manual workaround; raise in RPaaS Office Hours |
| PC Code / finance metadata incorrect | Low | Medium — registration rejected | Verify with finance before PUT |
| TypeSpec spec doesn't pass ARM review | Medium | Medium — delays Private Preview | Book ARM API Review early; iterate on TypeSpec |
| No CI/CD delays testing | High | Medium — cannot validate in dogfood | Prioritize OneBranch pipeline setup |
| BasePlatformRP codebase not production-ready | High | High — RP cannot serve ARM requests reliably | Address 22 gaps from baseplatform-issues.md |

---

*Last updated: 2026-03-08 by Picard (Lead)*
