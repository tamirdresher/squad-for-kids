# FedRAMP Controls Validation Test Plan
**Issue:** #67 — FedRAMP Controls Validation & Testing on DEV/STG Clusters  
**Author:** Worf (Security & Cloud)  
**Date:** 2026-03-07  
**Related PRs:** #55 (Network Policies), #56 (WAF, OPA, Scanning)

---

## Executive Summary

This test plan validates the defense-in-depth security controls implemented in PRs #55 and #56, ensuring FedRAMP compliance before sovereign/government cluster deployment. The validation covers four security layers: Network Policies, WAF rules, OPA admission control, and automated vulnerability scanning.

**Test Objective:** Verify that no single control failure can result in a P0 security incident similar to CVE-2026-24512.

---

## Test Scope

### In Scope
- Network Policy enforcement (default-deny, namespace isolation)
- WAF rule effectiveness (OWASP DRS 2.1, custom CVE rules)
- OPA/Gatekeeper admission control (path injection, annotation allowlist)
- Trivy vulnerability scanning pipeline
- Incident response runbook procedures
- Performance impact measurement
- FedRAMP control validation (SC-7, SI-2, SI-3, RA-5, CM-3, IR-4)

### Out of Scope
- Application-level security testing
- Penetration testing (requires separate authorization)
- Performance load testing (separate test plan)
- Multi-cluster synchronization testing

---

## Test Environments

| Environment | Purpose | Duration | Rollback Plan |
|-------------|---------|----------|---------------|
| **DEV-EUS2-01** | Initial validation, false positive detection | 2 days | Immediate policy removal |
| **STG-EUS2-28** | Integration testing, SLA impact measurement | 3 days | 1-hour rollback window |
| **STG-USGOV-01** | Sovereign cloud validation, TLS-only enforcement | 3 days | Manual rollback (air-gapped) |
| **PPE-EUS2** | Pre-production validation, full workload simulation | 2 days | Automated rollback via ArgoCD |

**Total Test Window:** 10 days (excludes production deployment)

---

## Test Categories

### 1. Network Policy Validation (PR #55)

#### 1.1 Default-Deny Enforcement
**Objective:** Verify zero-trust baseline prevents unauthorized traffic

**Test Cases:**
1. **NP-001:** Default-deny policy exists in `ingress-nginx` namespace
2. **NP-002:** Default-deny applies to all pods (empty podSelector)
3. **NP-003:** Cross-namespace traffic blocked by default
4. **NP-004:** Test pod CANNOT reach ingress-nginx health endpoint
5. **NP-005:** Test pod CANNOT reach ingress-nginx port 80/443

**Success Criteria:**
- All connectivity tests FAIL (blocked by default)
- No false positives (legitimate traffic not affected)
- SLA impact < 5% (p95 latency increase)

**Script:** `tests/fedramp-validation/network-policy-tests.sh`

#### 1.2 Ingress Controller Allow-List
**Objective:** Verify ingress-controller can receive traffic on required ports

**Test Cases:**
1. **NP-101:** Allow-list policy exists and targets ingress-controller pods
2. **NP-102:** Ports 80, 443 accessible from load balancer
3. **NP-103:** Port 10254 accessible from kubelet (health checks)
4. **NP-104:** Port 8443 accessible from API server (webhook)
5. **NP-105:** Egress to backend services allowed (ports 80, 443, 8080, 8443)
6. **NP-106:** DNS egress allowed (port 53 to kube-dns)
7. **NP-107:** API server egress allowed (port 443)

**Success Criteria:**
- Ingress traffic flows normally
- Health checks succeed (no pod restarts)
- Backend connectivity maintained

#### 1.3 CVE-2026-24512 Mitigation
**Objective:** Verify lateral movement prevention limits blast radius

**Test Cases:**
1. **NP-201:** Ingress-controller CANNOT reach kube-system namespace
2. **NP-202:** Ingress-controller CANNOT reach arbitrary pod IPs
3. **NP-203:** Egress limited to DNS, API server, and backend namespaces
4. **NP-204:** Simulated compromise cannot exfiltrate secrets from other namespaces

**Success Criteria:**
- Lateral movement blocked
- Blast radius limited to ingress-nginx namespace
- No secret exfiltration possible

#### 1.4 Sovereign Cloud Hardening
**Objective:** Verify TLS-only enforcement and source IP restrictions

**Test Cases:**
1. **NP-301:** HTTP port 80 BLOCKED in sovereign policy
2. **NP-302:** Ingress only from Azure Gov Front Door CIDRs
3. **NP-303:** dSTS egress allowed for authentication
4. **NP-304:** Backend egress limited to ports 443, 8443 only

**Success Criteria:**
- HTTP cleartext traffic blocked
- Source IP restrictions enforced
- FedRAMP SC-8 compliance verified

#### 1.5 ArgoCD Sync-Wave Ordering
**Objective:** Verify default-deny deploys before allow-list

**Test Cases:**
1. **NP-401:** Default-deny has sync-wave -10
2. **NP-402:** Allow-list has sync-wave -9
3. **NP-403:** Simulated deployment verifies ordering

**Success Criteria:**
- Default-deny deploys first
- No window where all traffic is allowed

---

### 2. WAF Rule Validation (PR #56)

#### 2.1 CVE-2026-24512 Attack Simulation
**Objective:** Verify WAF blocks nginx config injection patterns

**Test Cases:**
1. **WAF-001:** Semicolon in URL path → HTTP 403
2. **WAF-002:** Lua directive in path → HTTP 403
3. **WAF-003:** `proxy_pass` in path → HTTP 403
4. **WAF-004:** `root` directive in path → HTTP 403
5. **WAF-005:** `rewrite break` in path → HTTP 403
6. **WAF-006:** Curly brace injection → HTTP 403
7. **WAF-007:** `set $variable` in path → HTTP 403

**Success Criteria:**
- All injection attempts blocked
- WAF logs show rule ID match
- No false positives on safe paths

**Script:** `tests/fedramp-validation/waf-rule-tests.sh`

#### 2.2 CVE-2025-1974 Annotation Injection
**Objective:** Verify WAF blocks annotation-based attacks

**Test Cases:**
1. **WAF-101:** `snippet` in X-Forwarded-For → HTTP 403
2. **WAF-102:** `configuration-snippet` in headers → HTTP 403
3. **WAF-103:** `server-snippet` in headers → HTTP 403

**Success Criteria:**
- Header-based injection blocked
- Legitimate headers allowed

#### 2.3 CVE-2026-24514 Heartbeat Rate Limiting
**Objective:** Verify rate limiting prevents DDoS on health endpoints

**Test Cases:**
1. **WAF-201:** Normal heartbeat request succeeds
2. **WAF-202:** 150 requests/min to `/healthz` → rate limited
3. **WAF-203:** Rate limit resets after 1 minute

**Success Criteria:**
- Rate limit threshold: 100 req/min
- Legitimate health checks not affected

#### 2.4 OWASP DRS 2.1 Core Rules
**Objective:** Verify managed ruleset blocks common attacks

**Test Cases:**
1. **WAF-301:** SQL Injection → HTTP 403 (rule 942100)
2. **WAF-302:** XSS attack → HTTP 403 (rule 941100)
3. **WAF-303:** RCE via command injection → HTTP 403 (rule 932100)
4. **WAF-304:** Path traversal → HTTP 403

**Success Criteria:**
- OWASP Top 10 attacks blocked
- Bot Manager ruleset active

#### 2.5 False Positive Testing
**Objective:** Verify legitimate traffic not blocked

**Test Cases:**
1. **WAF-401:** Normal API calls succeed
2. **WAF-402:** JSON POST with safe data succeeds
3. **WAF-403:** Static asset requests succeed

**Success Criteria:**
- Zero false positives on legitimate traffic
- < 1% increase in 4xx error rate

#### 2.6 Sovereign Cloud TLS Enforcement
**Objective:** Verify HTTP cleartext blocked

**Test Cases:**
1. **WAF-501:** HTTP port 80 connection refused or 403
2. **WAF-502:** HTTPS connections succeed
3. **WAF-503:** TLS 1.2+ enforced

**Success Criteria:**
- HTTP blocked or redirected
- TLS < 1.2 rejected
- FedRAMP SC-8 compliance verified

---

### 3. OPA/Gatekeeper Policy Validation (PR #56)

#### 3.1 Path Injection Prevention
**Objective:** Verify admission controller blocks dangerous Ingress paths

**Test Cases:**
1. **OPA-001:** Ingress with semicolon in path → DENIED
2. **OPA-002:** Ingress with lua directive → DENIED
3. **OPA-003:** Ingress with proxy_pass → DENIED
4. **OPA-004:** Ingress with root directive → DENIED
5. **OPA-005:** Ingress with safe path → ALLOWED

**Success Criteria:**
- Dangerous patterns rejected at admission time
- Safe patterns allowed
- Clear error messages to developers

**Script:** `tests/fedramp-validation/opa-policy-tests.sh`

#### 3.2 Annotation Allowlist Enforcement
**Objective:** Verify only safe nginx annotations allowed

**Test Cases:**
1. **OPA-101:** Snippet annotation → DENIED
2. **OPA-102:** Configuration-snippet → DENIED
3. **OPA-103:** Server-snippet → DENIED
4. **OPA-104:** Allowed annotation (rewrite-target) → ALLOWED
5. **OPA-105:** Allowed annotation (ssl-redirect) → ALLOWED

**Success Criteria:**
- Dangerous annotations blocked
- Allowlist annotations permitted
- Non-allowlisted annotations require security review

#### 3.3 TLS Required Policy
**Objective:** Verify FedRAMP SC-8 TLS enforcement

**Test Cases:**
1. **OPA-201:** Ingress without TLS spec → DENIED
2. **OPA-202:** Ingress with TLS spec → ALLOWED

**Success Criteria:**
- Cleartext Ingress rejected
- TLS-configured Ingress allowed

#### 3.4 Wildcard Host Prevention
**Objective:** Verify subdomain takeover prevention

**Test Cases:**
1. **OPA-301:** Ingress with `*.example.com` → DENIED
2. **OPA-302:** Ingress with specific host → ALLOWED

**Success Criteria:**
- Wildcard hosts blocked
- Specific hosts allowed

#### 3.5 Dryrun Mode Validation
**Objective:** Verify policies can be tested without breaking workloads

**Test Cases:**
1. **OPA-401:** Deploy policy in dryrun mode
2. **OPA-402:** Verify violations logged but not blocked
3. **OPA-403:** Switch to deny mode after validation

**Success Criteria:**
- Dryrun mode functions correctly
- Audit logs capture violations
- Zero production impact during testing

#### 3.6 Performance Impact
**Objective:** Measure admission webhook latency

**Test Cases:**
1. **OPA-501:** Measure baseline Ingress creation time
2. **OPA-502:** Measure Ingress creation time with policies
3. **OPA-503:** Verify latency increase < 200ms

**Success Criteria:**
- Admission latency < 1s p95
- No webhook timeouts
- No resource creation failures

---

### 4. Automated Scanning Validation

#### 4.1 Trivy Image Scanning
**Objective:** Verify vulnerability scanning pipeline detects CVEs

**Test Cases:**
1. **SCAN-001:** Trivy pipeline executes on PR merge
2. **SCAN-002:** Weekly scheduled scan runs
3. **SCAN-003:** CRITICAL vulnerabilities block pipeline
4. **SCAN-004:** HIGH vulnerabilities warn but don't block
5. **SCAN-005:** Scan results published to artifacts

**Success Criteria:**
- Zero CRITICAL vulnerabilities in ingress-nginx image
- Scan completes in < 15 minutes
- Results available for audit

**Pipeline:** `tests/fedramp-validation/trivy-pipeline.yml`

#### 4.2 Configuration Scanning
**Objective:** Verify Trivy detects K8s misconfigurations

**Test Cases:**
1. **SCAN-101:** Scan NetworkPolicy manifests
2. **SCAN-102:** Scan OPA ConstraintTemplates
3. **SCAN-103:** Detect missing resource limits
4. **SCAN-104:** Detect privileged containers

**Success Criteria:**
- Misconfigurations detected
- False positives < 10%

#### 4.3 OPA Policy Scanning (Conftest)
**Objective:** Verify policies validated before deployment

**Test Cases:**
1. **SCAN-201:** Conftest validates Ingress manifests
2. **SCAN-202:** Dangerous patterns detected
3. **SCAN-203:** Policy violations block deployment

**Success Criteria:**
- Conftest integrated in CI/CD
- Policy violations fail build

---

### 5. Incident Response Runbook Validation

#### 5.1 Emergency Patch Workflow
**Objective:** Verify emergency patching procedures work

**Test Cases:**
1. **RUN-001:** Identify vulnerable component
2. **RUN-002:** Obtain patched version
3. **RUN-003:** Test in DEV environment
4. **RUN-004:** Progressive rollout (Test → PPE → Prod → Sovereign)
5. **RUN-005:** Monitor for failures
6. **RUN-006:** Rollback if needed

**Success Criteria:**
- DEV to Prod deployment: < 24 hours
- Prod to Sovereign: < 48 hours (air-gap lag)
- Zero failed deployments

**Document:** `tests/fedramp-validation/runbook-validation-checklist.md`

#### 5.2 Alert-to-Action Chain
**Objective:** Verify security alerts trigger correct responses

**Test Cases:**
1. **RUN-101:** Trivy CRITICAL alert → PagerDuty incident
2. **RUN-102:** OPA policy violation → Slack notification
3. **RUN-103:** WAF block spike → Security review
4. **RUN-104:** NetworkPolicy audit log → Investigation

**Success Criteria:**
- Alerts delivered within 5 minutes
- Correct on-call rotation
- Escalation procedures documented

---

## Test Execution Plan

### Phase 1: DEV Environment (Days 1-2)
1. Deploy Network Policies (dryrun mode)
2. Deploy OPA policies (dryrun mode)
3. Configure WAF rules (detection mode)
4. Execute all test scripts
5. Analyze false positives
6. Switch to enforcement mode

### Phase 2: STG Environment (Days 3-5)
1. Deploy all controls in enforcement mode
2. Run full test suite
3. Measure SLA impact
4. Simulate CVE-2026-24512 attack
5. Validate incident response procedures

### Phase 3: STG Sovereign (Days 6-8)
1. Deploy sovereign-specific configurations
2. Validate TLS-only enforcement
3. Test source IP restrictions
4. Verify air-gapped image transfer
5. Validate dSTS authentication egress

### Phase 4: PPE Environment (Days 9-10)
1. Deploy to pre-production
2. Full workload simulation
3. Performance impact measurement
4. Final validation before production

---

## Success Criteria (Overall)

| Category | Metric | Target |
|----------|--------|--------|
| **Security** | Network Policy violations | 0 |
| **Security** | WAF false positives | < 1% |
| **Security** | OPA policy violations | 0 |
| **Security** | CRITICAL vulnerabilities | 0 |
| **Performance** | p95 latency increase | < 5% |
| **Performance** | Admission webhook latency | < 1s |
| **Reliability** | Failed deployments | 0 |
| **Compliance** | FedRAMP controls validated | 6/6 |

---

## Rollback Triggers

**Immediate Rollback Required:**
- Service outage > 5 minutes
- Error rate > 10%
- p95 latency > 2x baseline
- False positive rate > 5%

**Rollback Procedure:**
1. ArgoCD: Revert to previous sync revision
2. Manual: `kubectl delete -f <policy-manifest>`
3. Verify service recovery
4. Root cause analysis
5. Fix and redeploy

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| False positives block legitimate traffic | Medium | High | Dryrun mode first, extensive testing |
| Performance degradation | Low | Medium | Measure baseline, < 5% SLA impact |
| Webhook timeout | Low | High | 30s timeout, < 10 policies |
| Sovereign deployment lag | High | Medium | 48h window, manual validation |
| Network Policy misconfiguration | Low | Critical | Default-deny first, progressive deployment |

---

## Reporting

**Daily Status Report:**
- Test cases executed
- Pass/fail/warn counts
- Blockers and issues
- Next day plan

**Final Report:**
- All test results
- Performance metrics
- FedRAMP control validation
- Production readiness recommendation

**Artifacts:**
- Test scripts and results (JSON)
- Scan reports (Trivy, Conftest)
- Performance benchmarks
- Runbook validation checklist

---

## Sign-Off

**Test Plan Approval:**
- [ ] Worf (Security & Cloud) — Test plan author
- [ ] B'Elanna (Infrastructure) — Infrastructure controls
- [ ] Picard (Lead) — Overall validation strategy

**Production Deployment Approval (after testing):**
- [ ] Worf — Security sign-off
- [ ] B'Elanna — Infrastructure sign-off
- [ ] Picard — Executive approval
