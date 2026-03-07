#!/bin/bash
# FedRAMP OPA/Gatekeeper Policy Validation Tests
# Issue #67: Validate OPA policies from PR #56
# Tests: Admission control, policy violations, dryrun mode

set -e

RESULTS_FILE="opa-policy-test-results.json"

echo "=== FedRAMP OPA/Gatekeeper Policy Validation Suite ==="
echo "Start Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARN++))
}

# Test 1: Verify Gatekeeper is installed
test_gatekeeper_installed() {
    echo ""
    echo "Test 1: Gatekeeper Installation"
    
    if kubectl get namespace gatekeeper-system &>/dev/null; then
        log_pass "Gatekeeper namespace exists"
    else
        log_fail "Gatekeeper namespace NOT found"
        return 1
    fi
    
    # Check Gatekeeper pods
    GATEKEEPER_PODS=$(kubectl get pods -n gatekeeper-system -l control-plane=controller-manager --no-headers 2>/dev/null | wc -l || echo 0)
    
    if [ $GATEKEEPER_PODS -gt 0 ]; then
        log_pass "Gatekeeper controller pods running: $GATEKEEPER_PODS"
    else
        log_fail "No Gatekeeper controller pods found"
    fi
    
    # Check Gatekeeper webhook
    if kubectl get validatingwebhookconfiguration gatekeeper-validating-webhook-configuration &>/dev/null; then
        log_pass "Gatekeeper validating webhook configured"
    else
        log_fail "Gatekeeper validating webhook NOT found"
    fi
}

# Test 2: Verify ConstraintTemplates exist
test_constraint_templates() {
    echo ""
    echo "Test 2: ConstraintTemplate Deployment"
    
    EXPECTED_TEMPLATES=(
        "dk8singresssafepath"
        "dk8singressannotationallowlist"
        "dk8singressbackendrestriction"
        "dk8singresstlsrequired"
        "dk8singressnowildcardhost"
    )
    
    for template in "${EXPECTED_TEMPLATES[@]}"; do
        if kubectl get constrainttemplate $template &>/dev/null; then
            log_pass "ConstraintTemplate exists: $template"
        else
            log_fail "ConstraintTemplate NOT found: $template"
        fi
    done
}

# Test 3: Verify Constraints are deployed
test_constraints_deployed() {
    echo ""
    echo "Test 3: Constraint Deployment"
    
    # Check for path injection constraint
    if kubectl get dk8singresssafepath block-ingress-path-injection &>/dev/null; then
        log_pass "Path injection constraint deployed"
        
        # Verify enforcement action
        ACTION=$(kubectl get dk8singresssafepath block-ingress-path-injection -o jsonpath='{.spec.enforcementAction}')
        if [ "$ACTION" == "deny" ]; then
            log_pass "Path injection constraint in 'deny' mode (enforcing)"
        elif [ "$ACTION" == "dryrun" ]; then
            log_warn "Path injection constraint in 'dryrun' mode (not enforcing)"
        else
            log_fail "Path injection constraint has unexpected action: $ACTION"
        fi
    else
        log_fail "Path injection constraint NOT deployed"
    fi
    
    # Check for annotation allowlist constraint
    if kubectl get dk8singressannotationallowlist ingress-annotation-allowlist &>/dev/null; then
        log_pass "Annotation allowlist constraint deployed"
    else
        log_fail "Annotation allowlist constraint NOT deployed"
    fi
}

# Test 4: Test path injection policy (CVE-2026-24512)
test_path_injection_policy() {
    echo ""
    echo "Test 4: Path Injection Policy (CVE-2026-24512)"
    
    # Test 4a: Attempt to create Ingress with semicolon in path (should FAIL)
    cat <<EOF | kubectl apply --dry-run=server -f - >/dev/null 2>&1
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-path-injection
  namespace: default
spec:
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /api;proxy_pass http://internal
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
EOF
    
    if [ $? -ne 0 ]; then
        log_pass "Ingress with semicolon in path BLOCKED by OPA"
    else
        log_fail "Ingress with semicolon in path ALLOWED (policy not enforcing)"
    fi
    
    # Test 4b: Attempt Lua directive injection
    cat <<EOF | kubectl apply --dry-run=server -f - >/dev/null 2>&1
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-lua-injection
  namespace: default
spec:
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /api/lua_need_request_body
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
EOF
    
    if [ $? -ne 0 ]; then
        log_pass "Ingress with lua directive BLOCKED by OPA"
    else
        log_fail "Ingress with lua directive ALLOWED (policy not enforcing)"
    fi
    
    # Test 4c: Attempt proxy_pass injection
    cat <<EOF | kubectl apply --dry-run=server -f - >/dev/null 2>&1
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-proxy-injection
  namespace: default
spec:
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /api;proxy_pass http://metadata.google.internal
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
EOF
    
    if [ $? -ne 0 ]; then
        log_pass "Ingress with proxy_pass BLOCKED by OPA"
    else
        log_fail "Ingress with proxy_pass ALLOWED (policy not enforcing)"
    fi
    
    # Test 4d: Safe path should be ALLOWED
    cat <<EOF | kubectl apply --dry-run=server -f - >/dev/null 2>&1
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-safe-path
  namespace: default
spec:
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /api/users
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
EOF
    
    if [ $? -eq 0 ]; then
        log_pass "Ingress with safe path ALLOWED"
    else
        log_fail "Ingress with safe path BLOCKED (false positive)"
    fi
}

# Test 5: Test annotation allowlist policy
test_annotation_allowlist_policy() {
    echo ""
    echo "Test 5: Annotation Allowlist Policy"
    
    # Test 5a: Blocked annotation (snippet) should FAIL
    cat <<EOF | kubectl apply --dry-run=server -f - >/dev/null 2>&1
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-snippet-annotation
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_pass http://internal-admin;
spec:
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
EOF
    
    if [ $? -ne 0 ]; then
        log_pass "Ingress with snippet annotation BLOCKED by OPA"
    else
        log_fail "Ingress with snippet annotation ALLOWED (policy not enforcing)"
    fi
    
    # Test 5b: Allowed annotation (rewrite-target) should PASS
    cat <<EOF | kubectl apply --dry-run=server -f - >/dev/null 2>&1
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-allowed-annotation
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
EOF
    
    if [ $? -eq 0 ]; then
        log_pass "Ingress with allowed annotations ALLOWED"
    else
        log_fail "Ingress with allowed annotations BLOCKED (false positive)"
    fi
}

# Test 6: Test TLS required policy
test_tls_required_policy() {
    echo ""
    echo "Test 6: TLS Required Policy (FedRAMP SC-8)"
    
    # Check if constraint exists
    if ! kubectl get dk8singresstlsrequired require-ingress-tls &>/dev/null; then
        log_warn "TLS required constraint not deployed, skipping tests"
        return 0
    fi
    
    # Test 6a: Ingress without TLS should FAIL
    cat <<EOF | kubectl apply --dry-run=server -f - >/dev/null 2>&1
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-no-tls
  namespace: default
spec:
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
EOF
    
    if [ $? -ne 0 ]; then
        log_pass "Ingress without TLS BLOCKED by OPA"
    else
        log_fail "Ingress without TLS ALLOWED (TLS policy not enforcing)"
    fi
    
    # Test 6b: Ingress with TLS should PASS
    cat <<EOF | kubectl apply --dry-run=server -f - >/dev/null 2>&1
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-with-tls
  namespace: default
spec:
  tls:
  - hosts:
    - test.example.com
    secretName: test-tls-secret
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
EOF
    
    if [ $? -eq 0 ]; then
        log_pass "Ingress with TLS ALLOWED"
    else
        log_fail "Ingress with TLS BLOCKED (false positive)"
    fi
}

# Test 7: Test wildcard host prevention
test_wildcard_host_policy() {
    echo ""
    echo "Test 7: Wildcard Host Prevention Policy"
    
    # Check if constraint exists
    if ! kubectl get dk8singressnowildcardhost block-wildcard-hosts &>/dev/null; then
        log_warn "Wildcard host constraint not deployed, skipping tests"
        return 0
    fi
    
    # Test 7a: Wildcard host should FAIL
    cat <<EOF | kubectl apply --dry-run=server -f - >/dev/null 2>&1
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-wildcard-host
  namespace: default
spec:
  rules:
  - host: "*.example.com"
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
EOF
    
    if [ $? -ne 0 ]; then
        log_pass "Ingress with wildcard host BLOCKED by OPA"
    else
        log_fail "Ingress with wildcard host ALLOWED (policy not enforcing)"
    fi
    
    # Test 7b: Specific host should PASS
    cat <<EOF | kubectl apply --dry-run=server -f - >/dev/null 2>&1
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-specific-host
  namespace: default
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
EOF
    
    if [ $? -eq 0 ]; then
        log_pass "Ingress with specific host ALLOWED"
    else
        log_fail "Ingress with specific host BLOCKED (false positive)"
    fi
}

# Test 8: Check audit logs for violations
test_audit_logs() {
    echo ""
    echo "Test 8: OPA Audit Log Analysis"
    
    # Count recent violations in gatekeeper-audit logs
    VIOLATIONS=$(kubectl logs -n gatekeeper-system -l control-plane=audit-controller --tail=1000 2>/dev/null | grep -c "denied" || echo 0)
    
    if [ $VIOLATIONS -gt 0 ]; then
        log_warn "Found $VIOLATIONS policy violations in audit logs (review required)"
    else
        log_pass "No policy violations in recent audit logs"
    fi
}

# Test 9: Verify constraint status and enforcement
test_constraint_status() {
    echo ""
    echo "Test 9: Constraint Status and Enforcement"
    
    # Check all constraints for status
    CONSTRAINTS=$(kubectl get constraints --all-namespaces -o json 2>/dev/null | jq -r '.items[] | .kind + "/" + .metadata.name' || echo "")
    
    if [ -z "$CONSTRAINTS" ]; then
        log_warn "Cannot retrieve constraint status (jq required)"
        return 0
    fi
    
    while IFS= read -r constraint; do
        if [ -n "$constraint" ]; then
            VIOLATIONS=$(kubectl get $constraint -o jsonpath='{.status.totalViolations}' 2>/dev/null || echo "0")
            
            if [ "$VIOLATIONS" == "0" ] || [ -z "$VIOLATIONS" ]; then
                log_pass "Constraint $constraint: 0 violations"
            else
                log_warn "Constraint $constraint: $VIOLATIONS current violations"
            fi
        fi
    done <<< "$CONSTRAINTS"
}

# Test 10: Performance impact check
test_performance_impact() {
    echo ""
    echo "Test 10: Performance Impact Assessment"
    
    # Count total ConstraintTemplates
    TEMPLATE_COUNT=$(kubectl get constrainttemplate --no-headers 2>/dev/null | wc -l || echo 0)
    
    if [ $TEMPLATE_COUNT -le 10 ]; then
        log_pass "ConstraintTemplate count within acceptable range: $TEMPLATE_COUNT"
    elif [ $TEMPLATE_COUNT -le 20 ]; then
        log_warn "Moderate ConstraintTemplate count: $TEMPLATE_COUNT (monitor webhook latency)"
    else
        log_warn "High ConstraintTemplate count: $TEMPLATE_COUNT (may increase admission latency)"
    fi
    
    # Check Gatekeeper webhook timeout
    TIMEOUT=$(kubectl get validatingwebhookconfiguration gatekeeper-validating-webhook-configuration -o jsonpath='{.webhooks[0].timeoutSeconds}' 2>/dev/null || echo "30")
    
    if [ $TIMEOUT -ge 10 ]; then
        log_pass "Webhook timeout set to ${TIMEOUT}s (adequate)"
    else
        log_warn "Webhook timeout only ${TIMEOUT}s (may be insufficient for complex policies)"
    fi
}

# Main test execution
main() {
    test_gatekeeper_installed
    test_constraint_templates
    test_constraints_deployed
    test_path_injection_policy
    test_annotation_allowlist_policy
    test_tls_required_policy
    test_wildcard_host_policy
    test_audit_logs
    test_constraint_status
    test_performance_impact
    
    # Generate results
    echo ""
    echo "=== Test Results Summary ==="
    echo -e "${GREEN}PASSED: ${PASS}${NC}"
    echo -e "${RED}FAILED: ${FAIL}${NC}"
    echo -e "${YELLOW}WARNINGS: ${WARN}${NC}"
    echo "End Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    # Write JSON results
    cat > ${RESULTS_FILE} <<EOF
{
  "test_suite": "FedRAMP OPA/Gatekeeper Policy Validation",
  "issue": "#67",
  "pr_validated": ["#56"],
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "results": {
    "passed": ${PASS},
    "failed": ${FAIL},
    "warnings": ${WARN}
  },
  "compliance": {
    "fedramp_controls": ["CM-3", "SI-3", "SC-8"],
    "cve_mitigations": ["CVE-2026-24512", "CVE-2025-1974"],
    "policies_tested": [
      "dk8singresssafepath",
      "dk8singressannotationallowlist",
      "dk8singresstlsrequired",
      "dk8singressnowildcardhost"
    ]
  }
}
EOF
    
    echo ""
    echo "Results written to: ${RESULTS_FILE}"
    
    # Exit with failure if any tests failed
    if [ $FAIL -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run tests
main
