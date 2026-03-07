#!/bin/bash
# detect-helm-kustomize-changes.sh
# Detects changes to Helm charts and Kustomize overlays in PRs
# Issue #87 - Helm/Kustomize Drift Detection

set -euo pipefail

# Color output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "=================================================="
echo "Helm/Kustomize Configuration Drift Detection"
echo "=================================================="
echo ""

# Get base branch (default to main if not in CI)
BASE_BRANCH="${BASE_BRANCH:-origin/main}"

# Get changed files
echo "Analyzing changes against ${BASE_BRANCH}..."
CHANGED_FILES=$(git diff --name-only "${BASE_BRANCH}...HEAD" 2>/dev/null || echo "")

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}⚠ Warning: No changes detected or not in a git repository${NC}"
    exit 0
fi

echo "Changed files:"
echo "$CHANGED_FILES" | sed 's/^/  /'
echo ""

# Detect Helm chart changes
echo "Checking for Helm chart changes..."
HELM_CHANGES=$(echo "$CHANGED_FILES" | grep -E 'values.*\.yaml|Chart\.yaml|charts/.*/values\.yaml' || true)

if [[ -n "$HELM_CHANGES" ]]; then
    echo -e "${YELLOW}⚠ Helm configuration changes detected:${NC}"
    echo "$HELM_CHANGES" | sed 's/^/  - /'
    echo ""
    HELM_DRIFT=true
else
    echo -e "${GREEN}✓ No Helm chart changes detected${NC}"
    echo ""
    HELM_DRIFT=false
fi

# Detect Kustomize changes
echo "Checking for Kustomize overlay changes..."
KUSTOMIZE_CHANGES=$(echo "$CHANGED_FILES" | grep -E 'kustomization\.yaml|overlays/|patches/.*\.yaml' || true)

if [[ -n "$KUSTOMIZE_CHANGES" ]]; then
    echo -e "${YELLOW}⚠ Kustomize configuration changes detected:${NC}"
    echo "$KUSTOMIZE_CHANGES" | sed 's/^/  - /'
    echo ""
    KUSTOMIZE_DRIFT=true
else
    echo -e "${GREEN}✓ No Kustomize overlay changes detected${NC}"
    echo ""
    KUSTOMIZE_DRIFT=false
fi

# Check for security-relevant changes in diffs
echo "Analyzing security-relevant changes..."
SECURITY_PATTERNS="networkPolicy|securityContext|tls\.enabled|runAsNonRoot|allowPrivilegeEscalation|podSecurityContext|image\.tag|appVersion"

SECURITY_CHANGES=$(git diff "${BASE_BRANCH}...HEAD" -- ${HELM_CHANGES} ${KUSTOMIZE_CHANGES} 2>/dev/null | grep -E "^\+.*($SECURITY_PATTERNS)" || true)

if [[ -n "$SECURITY_CHANGES" ]]; then
    echo -e "${RED}⚠ SECURITY-RELEVANT changes detected:${NC}"
    echo "$SECURITY_CHANGES" | head -10 | sed 's/^/  /'
    if [[ $(echo "$SECURITY_CHANGES" | wc -l) -gt 10 ]]; then
        echo "  ... ($(echo "$SECURITY_CHANGES" | wc -l) total changes)"
    fi
    echo ""
    SECURITY_DRIFT=true
else
    echo -e "${GREEN}✓ No security-relevant field changes detected${NC}"
    echo ""
    SECURITY_DRIFT=false
fi

# Export results for downstream scripts
mkdir -p /tmp/drift-detection
cat > /tmp/drift-detection/changes.env << EOF
HELM_DRIFT=${HELM_DRIFT}
KUSTOMIZE_DRIFT=${KUSTOMIZE_DRIFT}
SECURITY_DRIFT=${SECURITY_DRIFT}
HELM_CHANGES=$(echo "$HELM_CHANGES" | tr '\n' '|')
KUSTOMIZE_CHANGES=$(echo "$KUSTOMIZE_CHANGES" | tr '\n' '|')
EOF

# Summary
echo "=================================================="
echo "Detection Summary:"
echo "  Helm Drift: ${HELM_DRIFT}"
echo "  Kustomize Drift: ${KUSTOMIZE_DRIFT}"
echo "  Security Drift: ${SECURITY_DRIFT}"
echo "=================================================="
echo ""

if [[ "$HELM_DRIFT" == "true" ]] || [[ "$KUSTOMIZE_DRIFT" == "true" ]]; then
    echo -e "${YELLOW}⚠ Configuration drift detected — triggering validation pipeline${NC}"
    exit 0  # Continue to validation
else
    echo -e "${GREEN}✓ No configuration drift detected — validation skipped${NC}"
    exit 0
fi
