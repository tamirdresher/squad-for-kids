# Decision: FedRAMP Compensating Controls — Security Layer Implementation

**Date:** 2026-03-07  
**Author:** Worf (Security & Cloud)  
**Issue:** #54  
**Status:** Proposed  
**Impact:** Critical — Closes defense-in-depth gaps exposed by CVE-2026-24512

---

## Decision

Implement four compensating control layers for DK8S ingress security, using the following technology choices:

### 1. WAF: Azure Front Door Premium (commercial) + Application Gateway WAF_v2 (sovereign)

**Rationale:** Front Door provides global distribution with built-in DDoS and bot protection. Sovereign clouds require regional Application Gateway due to feature parity gaps. Both are FedRAMP HIGH authorized.

**Key choices:**
- OWASP DRS 2.1 (not CRS 3.x) — Microsoft's default ruleset with better false-positive tuning
- Prevention mode from day one — Detection mode is not acceptable for FedRAMP HIGH
- 3 custom rules specifically targeting nginx config injection vectors

### 2. OPA/Gatekeeper: 5 Admission Policies

**Rationale:** Admission-time validation prevents dangerous Ingress resources from ever being created. This is the most effective defense against CVE-2026-24512-class attacks.

**Key choices:**
- Annotation allowlisting (not blocklisting) — more secure default-deny posture
- Deploy in dryrun first, enforce after 48h validation — prevents tenant disruption
- Exclude kube-system and gatekeeper-system namespaces — platform components need flexibility

### 3. CI/CD: Trivy + Conftest (no SaaS dependency)

**Rationale:** Open source tools that run locally. No external data transmission — critical for FedRAMP and sovereign/air-gapped environments. Snyk rejected due to data residency concerns for gov clouds.

### 4. Emergency Patching: 4-Phase Progressive Rollout

**Rationale:** Follows existing EV2 ring deployment pattern (Test→PPE→Prod→Sovereign) with added sovereign-specific procedures for air-gapped image transfer.

## Consequences

- ✅ Closes all four compensating control gaps identified in Issue #51 assessment
- ✅ FedRAMP SC-7, SI-3, CM-7(5), RA-5, IR-4 compliance
- ✅ No single CVE can escalate to P0 incident when all layers deployed
- ⚠️ OPA policies may initially block legitimate tenant Ingress — mitigated by dryrun period
- ⚠️ WAF custom rules need tuning — may produce false positives on complex URL patterns
- ⚠️ Sovereign cloud WAF deployment lags commercial by 2-4 weeks due to image transfer

## Dependencies

- B'Elanna's Network Policy implementation (parallel track on `squad/54-fedramp-infra`)
- Gatekeeper must be deployed to all clusters (prerequisite for OPA policies)
- Azure Front Door Premium must be provisioned (infrastructure team)

## Timeline

- **Week 1-2:** OPA policies (dryrun → enforce) + WAF custom rules
- **Week 2-3:** CI/CD pipeline integration
- **Week 3-4:** Emergency runbook drill + sovereign cloud deployment
