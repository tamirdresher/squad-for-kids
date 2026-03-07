#!/bin/bash
# FedRAMP WAF Rule Validation Tests
# Issue #67: Validate WAF rules from PR #56
# Tests: OWASP ruleset, custom rules, CVE-2026-24512 attack simulation

set -e

WAF_ENDPOINT="${WAF_ENDPOINT:-https://test-ingress.dk8s.example.com}"
RESULTS_FILE="waf-test-results.json"

echo "=== FedRAMP WAF Rule Validation Suite ==="
echo "Start Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Target Endpoint: ${WAF_ENDPOINT}"

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

# Helper function to send HTTP request and check response
test_request() {
    local test_name="$1"
    local method="$2"
    local path="$3"
    local headers="$4"
    local data="$5"
    local expected_blocked="$6"
    
    echo ""
    echo "Test: ${test_name}"
    
    local cmd="curl -s -o /dev/null -w '%{http_code}' -X ${method}"
    
    if [ -n "$headers" ]; then
        cmd="${cmd} ${headers}"
    fi
    
    if [ -n "$data" ]; then
        cmd="${cmd} -d '${data}'"
    fi
    
    cmd="${cmd} '${WAF_ENDPOINT}${path}'"
    
    local response_code=$(eval $cmd 2>/dev/null || echo "000")
    
    if [ "$expected_blocked" == "true" ]; then
        if [ "$response_code" == "403" ] || [ "$response_code" == "400" ]; then
            log_pass "${test_name}: Blocked (HTTP ${response_code})"
        else
            log_fail "${test_name}: NOT blocked (HTTP ${response_code}, expected 403/400)"
        fi
    else
        if [ "$response_code" != "403" ] && [ "$response_code" != "400" ]; then
            log_pass "${test_name}: Allowed (HTTP ${response_code})"
        else
            log_fail "${test_name}: Incorrectly blocked (HTTP ${response_code})"
        fi
    fi
}

# Test 1: CVE-2026-24512 - Path Injection Attacks
test_cve_path_injection() {
    echo ""
    echo "=== Test Suite 1: CVE-2026-24512 Path Injection ==="
    
    # Test 1a: Semicolon injection
    test_request "Path Injection - Semicolon" \
        "GET" \
        "/api/users;proxy_pass http://internal-admin/" \
        "" \
        "" \
        "true"
    
    # Test 1b: Lua directive injection
    test_request "Path Injection - Lua Directive" \
        "GET" \
        "/api/data?path=/api;lua_need_request_body on" \
        "" \
        "" \
        "true"
    
    # Test 1c: Proxy_pass injection
    test_request "Path Injection - proxy_pass" \
        "GET" \
        "/assets/../../etc;proxy_pass http://metadata.google.internal" \
        "" \
        "" \
        "true"
    
    # Test 1d: Root directive injection
    test_request "Path Injection - root directive" \
        "GET" \
        "/files;root /etc/shadow" \
        "" \
        "" \
        "true"
    
    # Test 1e: Rewrite injection
    test_request "Path Injection - rewrite break" \
        "GET" \
        "/api;rewrite ^/(.*)$ /admin/\$1 break" \
        "" \
        "" \
        "true"
    
    # Test 1f: Config block injection
    test_request "Path Injection - Curly Brace" \
        "GET" \
        "/api/users { proxy_pass internal; }" \
        "" \
        "" \
        "true"
    
    # Test 1g: Set variable injection
    test_request "Path Injection - Set Variable" \
        "GET" \
        "/api;set \$admin_bypass 1" \
        "" \
        "" \
        "true"
}

# Test 2: CVE-2025-1974 - Annotation/Header Injection
test_annotation_injection() {
    echo ""
    echo "=== Test Suite 2: CVE-2025-1974 Annotation Injection ==="
    
    # Test 2a: Snippet in header
    test_request "Annotation Injection - Snippet Header" \
        "GET" \
        "/api/users" \
        "-H 'X-Forwarded-For: snippet:proxy_pass internal'" \
        "" \
        "true"
    
    # Test 2b: Configuration-snippet
    test_request "Annotation Injection - Config Snippet" \
        "POST" \
        "/api/config" \
        "-H 'X-Custom-Config: configuration-snippet: lua_code'" \
        "" \
        "true"
    
    # Test 2c: Server-snippet
    test_request "Annotation Injection - Server Snippet" \
        "GET" \
        "/health" \
        "-H 'X-Debug: server-snippet: access_log off'" \
        "" \
        "true"
}

# Test 3: CVE-2026-24514 - Heartbeat DDoS Rate Limiting
test_heartbeat_rate_limiting() {
    echo ""
    echo "=== Test Suite 3: CVE-2026-24514 Heartbeat Rate Limiting ==="
    
    # Test 3a: Normal heartbeat access (should succeed initially)
    test_request "Heartbeat - Normal Request" \
        "GET" \
        "/healthz" \
        "" \
        "" \
        "false"
    
    # Test 3b: Rapid fire requests (simulate DDoS)
    echo ""
    echo "Test: Heartbeat - Rate Limit (150 requests/min threshold)"
    local blocked_count=0
    local total_requests=150
    
    for i in $(seq 1 $total_requests); do
        response=$(curl -s -o /dev/null -w '%{http_code}' "${WAF_ENDPOINT}/healthz" 2>/dev/null || echo "000")
        if [ "$response" == "403" ] || [ "$response" == "429" ]; then
            ((blocked_count++))
        fi
    done
    
    if [ $blocked_count -gt 0 ]; then
        log_pass "Heartbeat rate limiting active: ${blocked_count}/${total_requests} requests blocked"
    else
        log_fail "Heartbeat rate limiting NOT active: 0/${total_requests} blocked"
    fi
}

# Test 4: OWASP DRS 2.1 Core Rules
test_owasp_core_rules() {
    echo ""
    echo "=== Test Suite 4: OWASP DRS 2.1 Core Rules ==="
    
    # Test 4a: SQL Injection (942100)
    test_request "OWASP - SQL Injection" \
        "GET" \
        "/api/users?id=1' OR '1'='1" \
        "" \
        "" \
        "true"
    
    # Test 4b: XSS Attack (941100)
    test_request "OWASP - XSS Attack" \
        "POST" \
        "/api/comment" \
        "-H 'Content-Type: application/json'" \
        '{"text":"<script>alert(document.cookie)</script>"}' \
        "true"
    
    # Test 4c: RCE via Command Injection (932100)
    test_request "OWASP - Remote Code Execution" \
        "GET" \
        "/api/file?name=test.txt;cat /etc/passwd" \
        "" \
        "" \
        "true"
    
    # Test 4d: Path Traversal
    test_request "OWASP - Path Traversal" \
        "GET" \
        "/api/download?file=../../../../etc/passwd" \
        "" \
        "" \
        "true"
}

# Test 5: Bot Protection Rules
test_bot_protection() {
    echo ""
    echo "=== Test Suite 5: Bot Protection ==="
    
    # Test 5a: Known bad bot user-agent
    test_request "Bot Protection - Bad Bot UA" \
        "GET" \
        "/api/users" \
        "-H 'User-Agent: sqlmap/1.0'" \
        "" \
        "true"
    
    # Test 5b: Suspicious automation pattern
    test_request "Bot Protection - Suspicious UA" \
        "GET" \
        "/api/users" \
        "-H 'User-Agent: python-requests/2.25.1'" \
        "" \
        "false"  # May be allowed for legitimate API clients
    
    # Test 5c: Empty user-agent (suspicious)
    test_request "Bot Protection - Empty UA" \
        "GET" \
        "/api/users" \
        "-H 'User-Agent: '" \
        "" \
        "true"
}

# Test 6: Legitimate Traffic (False Positive Check)
test_legitimate_traffic() {
    echo ""
    echo "=== Test Suite 6: Legitimate Traffic (False Positive Check) ==="
    
    # Test 6a: Normal API request
    test_request "Legitimate - Normal API Call" \
        "GET" \
        "/api/users?page=1&limit=10" \
        "-H 'User-Agent: Mozilla/5.0'" \
        "" \
        "false"
    
    # Test 6b: JSON POST with safe data
    test_request "Legitimate - Safe JSON POST" \
        "POST" \
        "/api/users" \
        "-H 'Content-Type: application/json' -H 'User-Agent: Mozilla/5.0'" \
        '{"name":"John Doe","email":"john@example.com"}' \
        "false"
    
    # Test 6c: Static asset request
    test_request "Legitimate - Static Asset" \
        "GET" \
        "/assets/logo.png" \
        "-H 'User-Agent: Mozilla/5.0'" \
        "" \
        "false"
}

# Test 7: Sovereign Cloud TLS Enforcement
test_sovereign_tls_enforcement() {
    echo ""
    echo "=== Test Suite 7: Sovereign Cloud TLS Enforcement ==="
    
    # Check if HTTP (port 80) is accessible
    if echo "${WAF_ENDPOINT}" | grep -q "^https://"; then
        local http_endpoint="${WAF_ENDPOINT//https:/http:}"
        
        response=$(curl -s -o /dev/null -w '%{http_code}' "${http_endpoint}/api/health" 2>/dev/null || echo "000")
        
        if [ "$response" == "000" ] || [ "$response" == "403" ]; then
            log_pass "HTTP port blocked (TLS-only enforced)"
        elif [ "$response" == "301" ] || [ "$response" == "302" ]; then
            log_warn "HTTP redirects to HTTPS (acceptable but not optimal for sovereign)"
        else
            log_fail "HTTP port accessible (should be blocked in sovereign cloud)"
        fi
    else
        log_warn "Cannot test TLS enforcement (endpoint is HTTP)"
    fi
}

# Test 8: Request Body Size Limits
test_request_body_limits() {
    echo ""
    echo "=== Test Suite 8: Request Body Size Limits ==="
    
    # Test 8a: Normal sized request (should succeed)
    test_request "Body Size - Normal (1KB)" \
        "POST" \
        "/api/data" \
        "-H 'Content-Type: application/json'" \
        '{"data":"'$(head -c 1024 /dev/zero | tr '\0' 'x')'"}' \
        "false"
    
    # Test 8b: Oversized request (should be blocked)
    echo ""
    echo "Test: Body Size - Oversized (>128KB limit)"
    # Generate 150KB payload
    large_payload=$(head -c 153600 /dev/zero | tr '\0' 'x')
    
    response=$(curl -s -o /dev/null -w '%{http_code}' \
        -X POST \
        -H 'Content-Type: application/json' \
        -d "{\"data\":\"${large_payload}\"}" \
        "${WAF_ENDPOINT}/api/data" 2>/dev/null || echo "000")
    
    if [ "$response" == "413" ] || [ "$response" == "400" ]; then
        log_pass "Oversized request blocked (HTTP ${response})"
    else
        log_fail "Oversized request NOT blocked (HTTP ${response}, expected 413)"
    fi
}

# Test 9: WAF Policy Configuration Check
test_waf_configuration() {
    echo ""
    echo "=== Test Suite 9: WAF Configuration Check ==="
    
    # This test requires Azure CLI access
    if command -v az &> /dev/null; then
        echo "Checking WAF policy configuration..."
        
        # Check for Front Door Premium or App Gateway WAF
        waf_policies=$(az network front-door waf-policy list --query "[].{name:name,mode:policySettings.mode,state:policySettings.enabledState}" -o json 2>/dev/null || echo "[]")
        
        if [ "$waf_policies" != "[]" ]; then
            log_pass "WAF policy found via Azure CLI"
            
            # Verify Prevention mode
            if echo "$waf_policies" | grep -q '"mode": "Prevention"'; then
                log_pass "WAF in Prevention mode (not Detection)"
            else
                log_fail "WAF NOT in Prevention mode"
            fi
            
            # Verify enabled state
            if echo "$waf_policies" | grep -q '"state": "Enabled"'; then
                log_pass "WAF policy is Enabled"
            else
                log_fail "WAF policy is NOT Enabled"
            fi
        else
            log_warn "Cannot verify WAF policy (requires Azure CLI access)"
        fi
    else
        log_warn "Azure CLI not available, skipping configuration check"
    fi
}

# Main test execution
main() {
    test_cve_path_injection
    test_annotation_injection
    test_heartbeat_rate_limiting
    test_owasp_core_rules
    test_bot_protection
    test_legitimate_traffic
    test_sovereign_tls_enforcement
    test_request_body_limits
    test_waf_configuration
    
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
  "test_suite": "FedRAMP WAF Rule Validation",
  "issue": "#67",
  "pr_validated": ["#56"],
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "target_endpoint": "${WAF_ENDPOINT}",
  "results": {
    "passed": ${PASS},
    "failed": ${FAIL},
    "warnings": ${WARN}
  },
  "compliance": {
    "fedramp_controls": ["SC-7", "SI-3", "SI-4"],
    "cve_mitigations": ["CVE-2026-24512", "CVE-2025-1974", "CVE-2026-24514"],
    "owasp_rules_tested": ["DRS-2.1-932100", "DRS-2.1-941100", "DRS-2.1-942100"]
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
