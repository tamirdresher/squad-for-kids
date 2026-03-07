#!/bin/bash
# Test suite for drift detection scripts
# Issue #87 - Helm/Kustomize Drift Detection

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
assert_equals() {
    local expected=$1
    local actual=$2
    local test_name=$3
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_exists() {
    local file=$1
    local test_name=$2
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  File not found: $file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local haystack=$1
    local needle=$2
    local test_name=$3
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if echo "$haystack" | grep -q "$needle"; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Expected to find: $needle"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup test environment
setup_test_repo() {
    TEST_REPO=$(mktemp -d)
    cd "$TEST_REPO"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create initial commit
    mkdir -p charts/app
    cat > charts/app/Chart.yaml << EOF
apiVersion: v2
name: app
version: 1.0.0
appVersion: "1.0"
EOF
    
    cat > charts/app/values.yaml << EOF
replicaCount: 2
networkPolicy:
  enabled: true
securityContext:
  runAsNonRoot: true
  readOnlyRootFilesystem: true
EOF
    
    git add -A
    git commit -q -m "Initial commit"
    git branch -M main
    
    echo "$TEST_REPO"
}

cleanup_test_repo() {
    if [[ -n "${TEST_REPO:-}" ]] && [[ -d "$TEST_REPO" ]]; then
        rm -rf "$TEST_REPO"
    fi
    rm -rf /tmp/drift-detection
}

echo "=================================================="
echo "Drift Detection Test Suite"
echo "=================================================="
echo ""

# Test 1: Detect Helm values.yaml changes
echo "Test Suite 1: Change Detection"
echo "---"

TEST_REPO=$(setup_test_repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Modify values.yaml
cat > charts/app/values.yaml << EOF
replicaCount: 3
networkPolicy:
  enabled: false
EOF
git add charts/app/values.yaml
git commit -q -m "Disable NetworkPolicy"

# Run detection script
export BASE_BRANCH="main"
bash "${SCRIPT_DIR}/scripts/drift-detection/detect-helm-kustomize-changes.sh" > /tmp/test-output.txt 2>&1 || true

# Check results
if [[ -f /tmp/drift-detection/changes.env ]]; then
    source /tmp/drift-detection/changes.env
    assert_equals "true" "$HELM_DRIFT" "Detects Helm values.yaml change"
    assert_equals "true" "$SECURITY_DRIFT" "Detects security field change (networkPolicy)"
else
    echo -e "${RED}✗ FAIL${NC}: Detection script did not create results file"
    TESTS_RUN=$((TESTS_RUN + 2))
    TESTS_FAILED=$((TESTS_FAILED + 2))
fi

cleanup_test_repo
echo ""

# Test 2: Detect Kustomize changes
echo "Test Suite 2: Kustomize Detection"
echo "---"

TEST_REPO=$(setup_test_repo)

# Create kustomize overlay
mkdir -p overlays/production
cat > overlays/production/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: production
EOF
git add overlays/
git commit -q -m "Add kustomize overlay"

export BASE_BRANCH="main"
bash "${SCRIPT_DIR}/scripts/drift-detection/detect-helm-kustomize-changes.sh" > /tmp/test-output.txt 2>&1 || true

if [[ -f /tmp/drift-detection/changes.env ]]; then
    source /tmp/drift-detection/changes.env
    assert_equals "true" "$KUSTOMIZE_DRIFT" "Detects Kustomize overlay change"
else
    echo -e "${RED}✗ FAIL${NC}: Detection script did not create results file"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

cleanup_test_repo
echo ""

# Test 3: No drift when no relevant changes
echo "Test Suite 3: No False Positives"
echo "---"

TEST_REPO=$(setup_test_repo)

# Make non-security change
echo "# README" > README.md
git add README.md
git commit -q -m "Add README"

export BASE_BRANCH="main"
bash "${SCRIPT_DIR}/scripts/drift-detection/detect-helm-kustomize-changes.sh" > /tmp/test-output.txt 2>&1 || true

if [[ -f /tmp/drift-detection/changes.env ]]; then
    source /tmp/drift-detection/changes.env
    assert_equals "false" "$HELM_DRIFT" "No false positive for non-Helm changes"
    assert_equals "false" "$KUSTOMIZE_DRIFT" "No false positive for non-Kustomize changes"
else
    echo -e "${RED}✗ FAIL${NC}: Detection script did not create results file"
    TESTS_RUN=$((TESTS_RUN + 2))
    TESTS_FAILED=$((TESTS_FAILED + 2))
fi

cleanup_test_repo
echo ""

# Test 4: Validation script execution
echo "Test Suite 4: Validation Script"
echo "---"

TEST_REPO=$(setup_test_repo)

# Create drift detection result
mkdir -p /tmp/drift-detection
cat > /tmp/drift-detection/changes.env << EOF
HELM_DRIFT=false
KUSTOMIZE_DRIFT=false
SECURITY_DRIFT=false
EOF

# Run validation (should skip when no drift)
bash "${SCRIPT_DIR}/scripts/drift-detection/render-and-validate.sh" > /tmp/test-output.txt 2>&1
VALIDATION_EXIT_CODE=$?

assert_equals "0" "$VALIDATION_EXIT_CODE" "Validation exits cleanly with no drift"

OUTPUT=$(cat /tmp/test-output.txt)
assert_contains "$OUTPUT" "No drift detected" "Validation skips when no drift"

cleanup_test_repo
echo ""

# Test 5: Compliance report generation
echo "Test Suite 5: Compliance Report"
echo "---"

TEST_REPO=$(setup_test_repo)

# Setup test data
mkdir -p /tmp/drift-detection
cat > /tmp/drift-detection/changes.env << EOF
HELM_DRIFT=true
KUSTOMIZE_DRIFT=false
SECURITY_DRIFT=true
HELM_CHANGES=charts/app/values.yaml
KUSTOMIZE_CHANGES=
EOF

cat > /tmp/drift-detection/validation.env << EOF
VALIDATION_FAILED=false
EOF

export PR_NUMBER="123"
export BRANCH_NAME="test-branch"
export COMMIT_SHA="abc123"

bash "${SCRIPT_DIR}/scripts/drift-detection/compliance-delta-report.sh" > /tmp/test-output.txt 2>&1 || true

assert_file_exists "/tmp/drift-detection/compliance-delta-report.md" "Report file created"

if [[ -f /tmp/drift-detection/compliance-delta-report.md ]]; then
    REPORT_CONTENT=$(cat /tmp/drift-detection/compliance-delta-report.md)
    assert_contains "$REPORT_CONTENT" "FedRAMP Compliance Delta Report" "Report contains title"
    assert_contains "$REPORT_CONTENT" "PR: #123" "Report contains PR number"
    assert_contains "$REPORT_CONTENT" "charts/app/values.yaml" "Report contains changed files"
fi

cleanup_test_repo
echo ""

# Test 6: Script permissions
echo "Test Suite 6: Script Executability"
echo "---"

assert_file_exists "${SCRIPT_DIR}/scripts/drift-detection/detect-helm-kustomize-changes.sh" "Detect script exists"
assert_file_exists "${SCRIPT_DIR}/scripts/drift-detection/render-and-validate.sh" "Validate script exists"
assert_file_exists "${SCRIPT_DIR}/scripts/drift-detection/compliance-delta-report.sh" "Report script exists"

echo ""

# Summary
echo "=================================================="
echo "Test Summary"
echo "=================================================="
echo "Total tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
else
    echo "Failed: $TESTS_FAILED"
fi
echo "=================================================="

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
