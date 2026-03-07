# Decision: FedRAMP P0 nginx-ingress Vulnerability Response

**Date:** 2026-03-06  
**Decision Maker:** Worf (Security & Cloud)  
**Issue:** #51 — nginx-ingress-heartbeat FedRAMP P0  
**Context:** STG-EUS2-28 incident (Issue #46) revealed CVE-2026-24512 vulnerabilities

---

## Decision

**IMMEDIATE EMERGENCY PATCH REQUIRED**

Upgrade ingress-nginx to v1.13.7+ or v1.14.3+ within 24 hours across all DK8S clusters.

---

## Rationale

1. **Vulnerability Severity:** CVE-2026-24512 (CVSS 8.8) enables remote code execution and full cluster compromise
2. **Zero Compensating Controls:** DK8S lacks Network Policies, WAF, and OPA validation (all planned Q1-H2 2026)
3. **FedRAMP Compliance:** P0 requires < 24h remediation; risk acceptance NOT viable without defense-in-depth
4. **Exploitability:** Multi-tenant platform with potential tenant Ingress creation = HIGH risk
5. **Regulatory Requirement:** Government cloud deployments (Fairfax, Mooncake) mandate compliance

---

## Rejected Alternatives

- **Rollback:** All older versions vulnerable; FedRAMP requires patch, not reversion
- **WAF Mitigation Only:** Insufficient timeline (Q1 2026) + does not address internal lateral movement
- **Admission Controller Only:** Insufficient timeline (Q2 2026) + does not eliminate CVE

---

## Implementation Plan

### Phase 1: Immediate Patch (0-24h)
- Test ring: 0-8h
- PPE ring: 8-16h
- Prod ring: 16-24h
- Sovereign clouds: 24-48h (with compensating controls)

### Phase 2: Compensating Controls for Sovereign Lag (24-48h)
If Fairfax/Mooncake deployment delayed:
- OPA emergency policy: Block new Ingress creation
- RBAC audit: Verify tenant isolation
- Monitoring: Alert on Ingress modifications
- Network policy: Isolate ingress-controller namespace

### Phase 3: Defense-in-Depth (Q1-Q2 2026)
- WAF deployment (Q1 2026)
- OPA/Rego Ingress validation (Q2 2026)
- Default-deny Network Policies (H2 2026)

---

## Risk Assessment

**Without Patch:**
- Cluster compromise via Ingress path injection
- Secrets exfiltration (controller has broad RBAC by default)
- FedRAMP audit failure + compliance violation
- Potential data breach in government cloud tenants

**With Patch:**
- Vulnerability eliminated
- FedRAMP compliant
- Minimal operational risk (progressive ring deployment)

---

## Validation Criteria

- [x] Security assessment complete (FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md)
- [ ] Current versions identified across all clusters
- [ ] Patch deployed to Test ring (validate heartbeat functional)
- [ ] Patch deployed to PPE ring (monitor for regression)
- [ ] Patch deployed to Prod ring (< 24h from detection)
- [ ] Sovereign clouds patched OR compensating controls active (< 48h)
- [ ] Post-patch validation: Version check, no CVE reproduction

---

## Impact on Team Decisions

**Related to Decision 3 (Security Findings):**
- nginx-ingress patch addresses Finding #1 immediate risk
- Reinforces urgency of Finding #2 (WAF), #3 (OPA), #5 (Network Policies)
- Demonstrates consequence of delayed defense-in-depth: single CVE = P0 incident

**Related to Issue #46 (STG-EUS2-28):**
- Root cause: CVE-2026-24512 exploitation potential
- Mitigation: Patch eliminates root vulnerability

**Related to Issue #29 (Tier 3 Architecture):**
- Security architecture gaps (WAF, Network Policies) = systemic risk
- Defense-in-depth timeline acceleration required

---

## Owner & Next Actions

- **Platform Team:** Version identification + patch deployment coordination
- **SRE Team:** EV2 progressive ring deployment execution
- **Worf (Security):** OPA emergency policy if sovereign cloud lag, post-patch validation
- **Compliance:** FedRAMP audit documentation (timeline, validation results)

---

**Audit Trail:** FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md (full technical analysis)

— Worf  
2026-03-06
