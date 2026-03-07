# Decision: FedRAMP Controls Validation Strategy

**Date:** 2026-03-07  
**Author:** Worf (Security & Cloud)  
**Status:** Proposed  
**Scope:** Security Testing & Validation  
**Issue:** #67  
**PR:** #70

---

## Context

CVE-2026-24512 incident (Issue #51) revealed DK8S had zero compensating controls for ingress-layer attacks. PRs #55 (Network Policies) and #56 (WAF, OPA, Scanning) delivered four security layers. Before sovereign/government cluster deployment, comprehensive validation testing is required to ensure defense-in-depth effectiveness.

**Problem:** How do we systematically validate that security controls work as designed and that no single control failure can result in a P0 incident?

---

## Decision

Adopt a **layered validation testing strategy** with realistic attack simulation, false positive detection, and environment-specific procedures.

### Test Suite Components

1. **Script-based validation tests** (Bash + kubectl + curl + jq)
   - Network Policy enforcement tests
   - WAF rule effectiveness tests (CVE attack simulation)
   - OPA admission control tests
   - Trivy scanning pipeline

2. **Comprehensive test plan** (10-day, 4-environment progressive deployment)
   - DEV → STG → STG-GOV → PPE
   - 100+ test cases
   - Success criteria: 0 policy violations, < 1% false positives, < 5% SLA impact

3. **Incident response validation** (runbook checklist)
   - Emergency patching < 24h (commercial), < 48h (sovereign)
   - Emergency OPA policy < 12h
   - Emergency WAF rule < 8h
   - NetworkPolicy incident containment < 30min

### Key Principles

**1. Defense-in-Depth Validation**
- Test ALL security layers independently AND in combination
- Verify that no single layer failure enables exploitation
- Example: CVE-2026-24512 path injection must be blocked by WAF AND OPA AND NetworkPolicy lateral movement prevention

**2. Realistic Attack Simulation**
- Use actual CVE payloads (not generic "bad input")
- CVE-2026-24512: `/api;proxy_pass http://internal`, `/api/lua_need_request_body`, `/api { proxy_pass; }`
- Verify HTTP 403 at WAF, admission rejection at OPA, egress block at NetworkPolicy

**3. False Positive Detection**
- Test legitimate traffic patterns extensively
- Normal API calls, JSON POST, static assets
- Target: < 1% false positive rate
- Rollback trigger: > 5% false positives

**4. Environment-Specific Validation**
- Commercial: HTTP redirect acceptable, global Front Door
- Sovereign: HTTP blocked (TLS-only), Azure Gov CIDRs, air-gap procedures, dSTS egress

**5. Performance Impact Measurement**
- Baseline before controls, measure after deployment
- Target: < 5% p95 latency increase, < 1s admission webhook latency
- Rollback trigger: > 2x baseline latency

---

## Rationale

### Why Layered Validation?
**Problem:** Single-layer testing misses interaction failures.
**Solution:** Test each layer independently (unit test) AND all layers together (integration test).
**Example:** WAF might block attacks, but if OPA has false positives, legitimate traffic is rejected.

### Why Realistic Attack Simulation?
**Problem:** Generic "bad input" tests don't validate CVE-specific mitigations.
**Solution:** Use exact CVE payloads from vendor advisories.
**Example:** CVE-2026-24512 requires semicolon in path field — generic XSS payloads won't test this.

### Why False Positive Detection?
**Problem:** Security controls that block legitimate traffic cause production outages.
**Solution:** Test normal traffic patterns extensively before production.
**Example:** OPA annotation allowlist must permit `rewrite-target` and `ssl-redirect` (common patterns).

### Why Environment-Specific Validation?
**Problem:** Commercial and sovereign clouds have different security requirements and capabilities.
**Solution:** Separate test cases for sovereign TLS-only, source IP restrictions, air-gap procedures.
**Example:** Sovereign clusters MUST block HTTP port 80; commercial MAY redirect to HTTPS.

### Why Performance Measurement?
**Problem:** Security controls can degrade service performance below SLA thresholds.
**Solution:** Measure baseline, set rollback triggers (> 2x latency, error rate > 10%).
**Example:** NetworkPolicy count > 10 may impact kube-proxy/CNI performance.

---

## Alternatives Considered

### Alternative 1: Manual Testing Only
**Rejected:** Not repeatable, not auditable, requires human validation for 100+ test cases, does not support CI/CD integration.

### Alternative 2: Unit Tests Only (no integration)
**Rejected:** Misses layer interaction failures. Example: WAF + OPA both block same attack → double-rejection may cause unexpected behavior.

### Alternative 3: Production Validation (no pre-deployment testing)
**Rejected:** FedRAMP requires < 24h P0 remediation. Production-first validation introduces unacceptable risk of prolonged outages.

### Alternative 4: SaaS-based Scanning Tools
**Rejected:** Sovereign/air-gapped clusters cannot use SaaS. Trivy + Conftest provide local scanning with no external dependencies.

---

## Implementation

### Phase 1: DEV Validation (Days 1-2)
- Deploy all controls in dryrun mode
- Execute all test scripts
- Analyze false positives
- Switch to enforcement mode

### Phase 2: STG Validation (Days 3-5)
- Full enforcement mode
- Run complete test suite
- Measure SLA impact
- Simulate CVE-2026-24512 attack

### Phase 3: STG Sovereign (Days 6-8)
- Sovereign-specific configs
- TLS-only validation
- Source IP restrictions
- Air-gap procedures

### Phase 4: PPE Validation (Days 9-10)
- Pre-production full workload
- Performance measurement
- Final validation before Prod

---

## Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| Network Policy violations | 0 | kubectl get violations |
| WAF false positives | < 1% | WAF logs analysis |
| OPA policy violations | 0 | Gatekeeper audit logs |
| CRITICAL vulnerabilities | 0 | Trivy scan results |
| p95 latency increase | < 5% | Prometheus metrics |
| Admission webhook latency | < 1s | Gatekeeper metrics |
| Failed deployments | 0 | ArgoCD sync status |
| FedRAMP controls validated | 6/6 | Manual checklist |

---

## Rollback Triggers

**Immediate rollback required:**
- Service outage > 5 minutes
- Error rate > 10%
- p95 latency > 2x baseline
- False positive rate > 5%

**Rollback procedure:**
1. ArgoCD: Revert to previous sync revision
2. Manual: `kubectl delete -f <policy-manifest>`
3. Verify service recovery
4. Root cause analysis
5. Fix and redeploy

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| False positives block legitimate traffic | Medium | High | Dryrun mode first, extensive testing, < 1% target |
| Performance degradation | Low | Medium | Measure baseline, < 5% SLA impact, rollback triggers |
| Webhook timeout | Low | High | 30s timeout, < 10 policies, performance monitoring |
| Sovereign deployment lag | High | Medium | 48h window for air-gap transfer, manual validation |
| Network Policy misconfiguration | Low | Critical | Default-deny first, progressive deployment, sync-wave ordering |

---

## Impact

**Team-Wide:**
- All security controls must include validation tests before production deployment
- Sovereign/government deployments require environment-specific test cases
- FedRAMP compliance requires evidence of testing (test results as audit artifacts)

**Future Work:**
- Similar validation strategies for other critical controls (encryption, authentication, logging)
- CI/CD integration for continuous validation on every PR
- Automated compliance reporting from test results

---

## References

- Test suite: `tests/fedramp-validation/`
- Test plan: `tests/fedramp-validation/TEST_PLAN.md`
- Runbook checklist: `tests/fedramp-validation/runbook-validation-checklist.md`
- Related issues: #51 (P0 assessment), #54 (controls implementation), #67 (validation)
- Related PRs: #55 (Network Policies), #56 (WAF, OPA, Scanning), #70 (validation suite)

---

**Decision Status:** Proposed — Awaiting Picard (Lead) approval to begin 10-day validation in DEV/STG environments.
