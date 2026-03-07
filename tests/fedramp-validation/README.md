# FedRAMP Controls Validation Test Suite

**Issue:** #67 — FedRAMP Controls Validation & Testing on DEV/STG Clusters  
**Related PRs:** #55 (Network Policies), #56 (WAF, OPA, Scanning)  
**Author:** Worf (Security & Cloud)

---

## Overview

This test suite validates the defense-in-depth security controls implemented for FedRAMP compliance. The suite covers four security layers designed to ensure no single control failure can result in a P0 security incident.

**Security Layers:**
1. **Network Policies** (PR #55) — Zero-trust networking, namespace isolation
2. **WAF Rules** (PR #56) — Azure Front Door/App Gateway protection
3. **OPA/Gatekeeper** (PR #56) — Admission control policies
4. **Trivy Scanning** (PR #56) — Automated vulnerability detection

**FedRAMP Controls Validated:**
- SC-7 (Boundary Protection)
- SI-2 (Flaw Remediation)
- SI-3 (Malicious Code Protection)
- RA-5 (Vulnerability Scanning)
- CM-3 (Configuration Change Control)
- IR-4 (Incident Handling)

---

## Test Suite Contents

```
tests/fedramp-validation/
├── README.md                           # This file
├── TEST_PLAN.md                        # Comprehensive test plan (15KB)
├── runbook-validation-checklist.md     # Incident response validation (13KB)
├── network-policy-tests.sh             # Network Policy validation (11KB)
├── waf-rule-tests.sh                   # WAF rule validation (13KB)
├── opa-policy-tests.sh                 # OPA policy validation (16KB)
└── trivy-pipeline.yml                  # Azure DevOps scanning pipeline (15KB)
```

---

## Quick Start

### Prerequisites
- `kubectl` configured for target cluster
- `curl` for WAF testing
- `jq` for JSON parsing
- Azure CLI (optional, for WAF policy checks)
- Bash shell

### Run All Tests

```bash
cd tests/fedramp-validation

# 1. Network Policy Tests (requires cluster access)
chmod +x network-policy-tests.sh
./network-policy-tests.sh

# 2. WAF Rule Tests (requires deployed WAF endpoint)
export WAF_ENDPOINT="https://your-ingress.example.com"
chmod +x waf-rule-tests.sh
./waf-rule-tests.sh

# 3. OPA Policy Tests (requires Gatekeeper installed)
chmod +x opa-policy-tests.sh
./opa-policy-tests.sh

# 4. Trivy Scanning (run via Azure DevOps)
# See trivy-pipeline.yml for CI/CD integration
```

---

## Test Scripts

### 1. Network Policy Tests (`network-policy-tests.sh`)

**Purpose:** Validate zero-trust networking and CVE-2026-24512 lateral movement prevention.

**Tests:**
- ✅ Default-deny policy deployment
- ✅ Ingress controller allow-list
- ✅ Namespace isolation
- ✅ Connectivity enforcement (default deny)
- ✅ Egress restrictions
- ✅ ArgoCD sync-wave ordering
- ✅ CVE-2026-24512 mitigation
- ✅ Sovereign cloud hardening
- ✅ Performance impact

**Output:** `network-policy-test-results.json`

**Example:**
```bash
=== FedRAMP Network Policy Validation Suite ===
[PASS] Default-deny policy exists in ingress-nginx
[PASS] Default-deny policy applies to all pods (empty selector)
[PASS] Test pod CANNOT reach nginx health endpoint (default-deny enforced)
...
=== Test Results Summary ===
PASSED: 18
FAILED: 0
WARNINGS: 2
```

### 2. WAF Rule Tests (`waf-rule-tests.sh`)

**Purpose:** Validate WAF blocks CVE-2026-24512 attacks and OWASP Top 10 patterns.

**Tests:**
- ✅ CVE-2026-24512 path injection (semicolon, lua, proxy_pass)
- ✅ CVE-2025-1974 annotation injection
- ✅ CVE-2026-24514 heartbeat rate limiting
- ✅ OWASP DRS 2.1 (SQL injection, XSS, RCE)
- ✅ Bot protection
- ✅ Legitimate traffic (false positive check)
- ✅ Sovereign TLS enforcement
- ✅ Request body size limits

**Output:** `waf-test-results.json`

**Environment Variables:**
- `WAF_ENDPOINT` — Target endpoint (required)

**Example:**
```bash
export WAF_ENDPOINT="https://test-ingress.dk8s.example.com"
./waf-rule-tests.sh

=== Test Suite 1: CVE-2026-24512 Path Injection ===
[PASS] Path Injection - Semicolon: Blocked (HTTP 403)
[PASS] Path Injection - Lua Directive: Blocked (HTTP 403)
...
PASSED: 24
FAILED: 0
WARNINGS: 1
```

### 3. OPA Policy Tests (`opa-policy-tests.sh`)

**Purpose:** Validate admission control prevents dangerous Ingress resources.

**Tests:**
- ✅ Gatekeeper installation
- ✅ ConstraintTemplate deployment
- ✅ Constraint enforcement
- ✅ Path injection prevention
- ✅ Annotation allowlist
- ✅ TLS required (FedRAMP SC-8)
- ✅ Wildcard host prevention
- ✅ Audit log analysis
- ✅ Constraint status
- ✅ Performance impact

**Output:** `opa-policy-test-results.json`

**Example:**
```bash
./opa-policy-tests.sh

=== Test 4: Path Injection Policy (CVE-2026-24512) ===
[PASS] Ingress with semicolon in path BLOCKED by OPA
[PASS] Ingress with lua directive BLOCKED by OPA
[PASS] Ingress with safe path ALLOWED
...
PASSED: 22
FAILED: 0
WARNINGS: 3
```

### 4. Trivy Scanning Pipeline (`trivy-pipeline.yml`)

**Purpose:** Automated vulnerability scanning in CI/CD pipeline.

**Stages:**
1. **ContainerImageScanning** — Scan nginx-ingress and custom images
2. **ConfigurationScanning** — Scan K8s manifests and Helm charts
3. **OPAPolicyScanning** — Validate with Conftest
4. **ReportGeneration** — Generate compliance report

**Triggers:**
- PR merge to main/develop/release branches
- Weekly schedule (Monday 2 AM UTC)

**Integration:**
```yaml
# Add to your Azure DevOps pipeline
resources:
  pipelines:
    - pipeline: fedramp-validation
      source: trivy-scanning
      trigger:
        branches:
          - main
```

**Critical Vulnerability Gate:**
- CRITICAL vulnerabilities **BLOCK** the pipeline
- HIGH vulnerabilities **WARN** but don't block
- Scan results published as build artifacts

---

## Test Plan

See `TEST_PLAN.md` for comprehensive test strategy covering:
- Test scope and environments
- Detailed test cases (100+ tests)
- Success criteria and metrics
- Risk assessment
- Rollback triggers
- 10-day execution plan

**Phases:**
1. DEV Environment (Days 1-2)
2. STG Environment (Days 3-5)
3. STG Sovereign (Days 6-8)
4. PPE Environment (Days 9-10)

---

## Runbook Validation

See `runbook-validation-checklist.md` for incident response validation:
- Emergency patching procedures
- OPA policy emergency deployment
- WAF rule emergency updates
- Network Policy incident response
- Alert-to-action chains
- Rollback procedures
- Sovereign cloud air-gap processes

**Target Remediation Times:**
- P0 Commercial: < 24 hours
- P0 Sovereign: < 48 hours (air-gap lag)
- Emergency WAF rule: < 8 hours
- Emergency OPA policy: < 12 hours

---

## Results Interpretation

### Test Results JSON Schema

```json
{
  "test_suite": "FedRAMP Network Policy Validation",
  "issue": "#67",
  "pr_validated": ["#55"],
  "timestamp": "2026-03-07T19:30:00Z",
  "results": {
    "passed": 18,
    "failed": 0,
    "warnings": 2
  },
  "compliance": {
    "fedramp_controls": ["SC-7", "AC-4", "CM-7"],
    "cve_mitigations": ["CVE-2026-24512"]
  }
}
```

### Pass/Fail Criteria

**PASS:** All critical tests pass, warnings acceptable
**FAIL:** Any critical test fails (requires remediation)
**BLOCKED:** Prerequisites not met (requires investigation)

**Production Readiness:**
- PASSED ≥ 90% of tests
- FAILED = 0 critical tests
- WARNINGS ≤ 10% of tests

---

## CVE Mitigations Validated

| CVE | CVSS | Description | Mitigation |
|-----|------|-------------|------------|
| **CVE-2026-24512** | 8.8 (HIGH) | nginx config injection via Ingress path | WAF + OPA + NetworkPolicy |
| **CVE-2025-1974** | 7.5 (HIGH) | RCE via annotation-based injection | OPA annotation allowlist |
| **CVE-2026-24514** | 7.5 (HIGH) | Heartbeat endpoint DDoS | WAF rate limiting |

---

## Troubleshooting

### Network Policy Tests Fail
```bash
# Check if policies are deployed
kubectl get networkpolicy -n ingress-nginx

# Check if ingress-nginx pods exist
kubectl get pods -n ingress-nginx

# View policy details
kubectl describe networkpolicy default-deny-all -n ingress-nginx
```

### WAF Tests Fail
```bash
# Verify WAF endpoint is reachable
curl -I $WAF_ENDPOINT

# Check WAF policy configuration (Azure CLI)
az network front-door waf-policy list

# View WAF logs
az monitor log-analytics query --workspace <workspace-id> \
  --analytics-query "AzureDiagnostics | where Category == 'FrontdoorWebApplicationFirewallLog'"
```

### OPA Tests Fail
```bash
# Check Gatekeeper status
kubectl get pods -n gatekeeper-system

# View constraint violations
kubectl get constraints --all-namespaces

# Check Gatekeeper logs
kubectl logs -n gatekeeper-system -l control-plane=controller-manager
```

---

## Performance Benchmarks

**Target SLA Impact:** < 5% increase in p95 latency

| Control | Latency Impact | Resource Impact |
|---------|----------------|-----------------|
| NetworkPolicy | < 1ms | Minimal (CNI) |
| OPA Admission | < 200ms | Low (webhook) |
| WAF Inspection | < 10ms | Minimal (Front Door) |

**Baseline Measurement:**
```bash
# Measure baseline latency before controls
kubectl run -it --rm load-test --image=busybox --restart=Never -- \
  wget -qO- http://ingress-nginx.ingress-nginx.svc.cluster.local:80
```

---

## CI/CD Integration

### GitHub Actions Example
```yaml
name: FedRAMP Validation
on:
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run OPA Tests
        run: |
          cd tests/fedramp-validation
          chmod +x opa-policy-tests.sh
          ./opa-policy-tests.sh
```

### Azure DevOps Pipeline
See `trivy-pipeline.yml` for full configuration.

---

## References

- **Test Plan:** [TEST_PLAN.md](TEST_PLAN.md)
- **Runbook Checklist:** [runbook-validation-checklist.md](runbook-validation-checklist.md)
- **Network Policies:** [docs/fedramp/](../../docs/fedramp/)
- **Security Controls:** [docs/fedramp-compensating-controls-security.md](../../docs/fedramp-compensating-controls-security.md)
- **Infrastructure Controls:** [docs/fedramp-compensating-controls-infrastructure.md](../../docs/fedramp-compensating-controls-infrastructure.md)

---

## Support

**Questions or Issues:**
- Issue Tracker: [GitHub Issues](https://github.com/tamirdresher_microsoft/tamresearch1/issues)
- Security Contact: platform-security@dk8s.io
- Slack: #dk8s-security

**Test Suite Maintainer:** Worf (Security & Cloud)
