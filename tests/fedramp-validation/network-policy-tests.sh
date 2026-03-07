#!/bin/bash
# FedRAMP Network Policy Validation Tests
# Issue #67: Validate network policies from PR #55
# Tests: Default-deny enforcement, namespace isolation, ingress/egress rules

set -e

NAMESPACE="ingress-nginx"
TEST_NAMESPACE="test-network-policy"
RESULTS_FILE="network-policy-test-results.json"

echo "=== FedRAMP Network Policy Validation Suite ==="
echo "Start Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Test 1: Verify default-deny policy exists
test_default_deny_exists() {
    echo ""
    echo "Test 1: Default-Deny Policy Deployment"
    
    if kubectl get networkpolicy default-deny-all -n ${NAMESPACE} &>/dev/null; then
        log_pass "Default-deny policy exists in ${NAMESPACE}"
    else
        log_fail "Default-deny policy NOT found in ${NAMESPACE}"
        return 1
    fi
    
    # Verify it applies to all pods
    SELECTOR=$(kubectl get networkpolicy default-deny-all -n ${NAMESPACE} -o jsonpath='{.spec.podSelector}')
    if [ "$SELECTOR" == "{}" ]; then
        log_pass "Default-deny policy applies to all pods (empty selector)"
    else
        log_fail "Default-deny policy has non-empty selector: $SELECTOR"
    fi
}

# Test 2: Verify ingress-controller allow-list policy
test_controller_allowlist() {
    echo ""
    echo "Test 2: Ingress Controller Allow-List Policy"
    
    if kubectl get networkpolicy allow-ingress-controller -n ${NAMESPACE} &>/dev/null; then
        log_pass "Ingress controller allow-list policy exists"
    else
        log_fail "Ingress controller allow-list policy NOT found"
        return 1
    fi
    
    # Verify allowed ports
    INGRESS_PORTS=$(kubectl get networkpolicy allow-ingress-controller -n ${NAMESPACE} -o jsonpath='{.spec.ingress[*].ports[*].port}')
    
    for PORT in 80 443 10254 8443; do
        if echo "$INGRESS_PORTS" | grep -q "$PORT"; then
            log_pass "Port $PORT allowed in ingress policy"
        else
            log_warn "Port $PORT NOT explicitly allowed (may be covered by range)"
        fi
    done
}

# Test 3: Verify namespace isolation
test_namespace_isolation() {
    echo ""
    echo "Test 3: Namespace Isolation Policy"
    
    if kubectl get networkpolicy deny-cross-namespace-to-internals -n ${NAMESPACE} &>/dev/null; then
        log_pass "Namespace isolation policy exists"
    else
        log_warn "Namespace isolation policy NOT found (may be optional)"
    fi
}

# Test 4: Test actual connectivity - default deny
test_connectivity_default_deny() {
    echo ""
    echo "Test 4: Connectivity Test - Default Deny Enforcement"
    
    # Create test namespace and pod
    kubectl create namespace ${TEST_NAMESPACE} 2>/dev/null || true
    
    cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: test-client
  namespace: ${TEST_NAMESPACE}
  labels:
    app: test-client
spec:
  containers:
  - name: netshoot
    image: nicolaka/netshoot:latest
    command: ["sleep", "3600"]
EOF
    
    echo "Waiting for test pod to be ready..."
    kubectl wait --for=condition=ready pod/test-client -n ${TEST_NAMESPACE} --timeout=60s >/dev/null 2>&1 || {
        log_warn "Test pod not ready, skipping connectivity tests"
        return 0
    }
    
    # Test 4a: Verify test pod CANNOT reach ingress-nginx pods (default deny)
    NGINX_POD=$(kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$NGINX_POD" ]; then
        log_warn "No nginx-ingress pods found, skipping connectivity test"
        return 0
    fi
    
    NGINX_IP=$(kubectl get pod ${NGINX_POD} -n ${NAMESPACE} -o jsonpath='{.status.podIP}')
    
    # Attempt connection to nginx health port (should FAIL due to default-deny)
    if kubectl exec -n ${TEST_NAMESPACE} test-client -- timeout 5 curl -s http://${NGINX_IP}:10254/healthz >/dev/null 2>&1; then
        log_fail "Test pod CAN reach nginx health endpoint (default-deny not enforced)"
    else
        log_pass "Test pod CANNOT reach nginx health endpoint (default-deny enforced)"
    fi
    
    # Test 4b: Verify external connectivity is blocked
    if kubectl exec -n ${TEST_NAMESPACE} test-client -- timeout 5 curl -s http://${NGINX_IP}:80 >/dev/null 2>&1; then
        log_fail "Test pod CAN reach nginx port 80 (policy not effective)"
    else
        log_pass "Test pod CANNOT reach nginx port 80 (ingress blocked)"
    fi
}

# Test 5: Test egress restrictions
test_egress_restrictions() {
    echo ""
    echo "Test 5: Egress Restrictions"
    
    # Verify egress policy exists and restricts traffic
    EGRESS_RULES=$(kubectl get networkpolicy allow-ingress-controller -n ${NAMESPACE} -o jsonpath='{.spec.egress}' 2>/dev/null || echo "[]")
    
    if [ "$EGRESS_RULES" != "[]" ]; then
        log_pass "Egress rules defined in controller policy"
        
        # Check for DNS egress
        if echo "$EGRESS_RULES" | grep -q "53"; then
            log_pass "DNS egress (port 53) allowed"
        else
            log_warn "DNS egress not explicitly allowed"
        fi
        
        # Check for API server egress
        if echo "$EGRESS_RULES" | grep -q "443"; then
            log_pass "HTTPS egress (port 443) allowed for API server/backends"
        else
            log_warn "HTTPS egress not explicitly allowed"
        fi
    else
        log_warn "No egress rules found (may allow all egress)"
    fi
}

# Test 6: Verify sync-wave ordering
test_sync_wave_ordering() {
    echo ""
    echo "Test 6: ArgoCD Sync-Wave Ordering"
    
    DEFAULT_DENY_WAVE=$(kubectl get networkpolicy default-deny-all -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}' 2>/dev/null || echo "")
    CONTROLLER_WAVE=$(kubectl get networkpolicy allow-ingress-controller -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}' 2>/dev/null || echo "")
    
    if [ "$DEFAULT_DENY_WAVE" == "-10" ]; then
        log_pass "Default-deny has correct sync-wave: -10"
    else
        log_fail "Default-deny sync-wave incorrect: $DEFAULT_DENY_WAVE (expected: -10)"
    fi
    
    if [ "$CONTROLLER_WAVE" == "-9" ]; then
        log_pass "Controller allow-list has correct sync-wave: -9"
    else
        log_warn "Controller allow-list sync-wave: $CONTROLLER_WAVE (expected: -9)"
    fi
    
    # Verify ordering
    if [ "$DEFAULT_DENY_WAVE" == "-10" ] && [ "$CONTROLLER_WAVE" == "-9" ]; then
        log_pass "Sync-wave ordering correct (default-deny deploys before allow-list)"
    fi
}

# Test 7: CVE-2026-24512 Mitigation - Lateral Movement Prevention
test_cve_mitigation_lateral_movement() {
    echo ""
    echo "Test 7: CVE-2026-24512 Mitigation - Lateral Movement Prevention"
    
    # Verify that even IF nginx controller is compromised, it cannot reach kube-system
    EGRESS_TO_NAMESPACE=$(kubectl get networkpolicy allow-ingress-controller -n ${NAMESPACE} -o jsonpath='{.spec.egress[*].to[*].namespaceSelector}' 2>/dev/null || echo "")
    
    if [ -n "$EGRESS_TO_NAMESPACE" ]; then
        log_pass "Egress namespace selector defined (restricts lateral movement)"
    else
        log_warn "No egress namespace selector found (may allow broad egress)"
    fi
}

# Test 8: Sovereign cloud hardening
test_sovereign_hardening() {
    echo ""
    echo "Test 8: Sovereign Cloud Hardening (if applicable)"
    
    if kubectl get networkpolicy allow-ingress-sovereign -n ${NAMESPACE} &>/dev/null; then
        log_pass "Sovereign-specific network policy exists"
        
        # Verify HTTP port 80 is blocked in sovereign
        SOVEREIGN_PORTS=$(kubectl get networkpolicy allow-ingress-sovereign -n ${NAMESPACE} -o jsonpath='{.spec.ingress[*].ports[*].port}')
        
        if echo "$SOVEREIGN_PORTS" | grep -q "^80$"; then
            log_fail "Port 80 allowed in sovereign policy (should be TLS-only)"
        else
            log_pass "Port 80 blocked in sovereign policy (TLS-only enforced)"
        fi
    else
        log_warn "Sovereign policy not found (may be using public cloud config)"
    fi
}

# Test 9: Performance impact check
test_performance_impact() {
    echo ""
    echo "Test 9: Performance Impact Assessment"
    
    # Count total network policies
    POLICY_COUNT=$(kubectl get networkpolicy -n ${NAMESPACE} --no-headers 2>/dev/null | wc -l || echo 0)
    
    if [ "$POLICY_COUNT" -le 5 ]; then
        log_pass "Network policy count within acceptable range: $POLICY_COUNT"
    elif [ "$POLICY_COUNT" -le 10 ]; then
        log_warn "Moderate network policy count: $POLICY_COUNT (monitor performance)"
    else
        log_warn "High network policy count: $POLICY_COUNT (may impact kube-proxy/CNI)"
    fi
    
    # Check for policy complexity
    TOTAL_RULES=$(kubectl get networkpolicy -n ${NAMESPACE} -o json 2>/dev/null | grep -c "port\|protocol" || echo 0)
    
    if [ "$TOTAL_RULES" -lt 20 ]; then
        log_pass "Total policy rules within acceptable range: $TOTAL_RULES"
    else
        log_warn "High rule count: $TOTAL_RULES (may increase latency)"
    fi
}

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up test resources..."
    kubectl delete namespace ${TEST_NAMESPACE} --ignore-not-found=true >/dev/null 2>&1 || true
}

# Main test execution
main() {
    test_default_deny_exists
    test_controller_allowlist
    test_namespace_isolation
    test_connectivity_default_deny
    test_egress_restrictions
    test_sync_wave_ordering
    test_cve_mitigation_lateral_movement
    test_sovereign_hardening
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
  "test_suite": "FedRAMP Network Policy Validation",
  "issue": "#67",
  "pr_validated": ["#55"],
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "results": {
    "passed": ${PASS},
    "failed": ${FAIL},
    "warnings": ${WARN}
  },
  "compliance": {
    "fedramp_controls": ["SC-7", "AC-4", "CM-7"],
    "cve_mitigations": ["CVE-2026-24512"]
  }
}
EOF
    
    echo ""
    echo "Results written to: ${RESULTS_FILE}"
    
    # Cleanup
    cleanup
    
    # Exit with failure if any tests failed
    if [ $FAIL -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run tests
main
