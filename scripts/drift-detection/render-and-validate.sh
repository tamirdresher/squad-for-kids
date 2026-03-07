#!/bin/bash
# render-and-validate.sh
# Renders Helm charts and Kustomize overlays, validates against security baselines
# Issue #87 - Helm/Kustomize Drift Detection

set -euo pipefail

# Start timing
START_TIME=$(date +%s)

# Color output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "=================================================="
echo "Manifest Rendering & Validation"
echo "=================================================="
echo ""

# Load drift detection results
if [[ -f /tmp/drift-detection/changes.env ]]; then
    source /tmp/drift-detection/changes.env
else
    echo -e "${RED}Error: Drift detection results not found${NC}"
    echo "Run detect-helm-kustomize-changes.sh first"
    exit 1
fi

# Exit early if no drift detected
if [[ "$HELM_DRIFT" != "true" ]] && [[ "$KUSTOMIZE_DRIFT" != "true" ]]; then
    echo -e "${GREEN}✓ No drift detected — skipping validation${NC}"
    exit 0
fi

# Setup directories
RENDER_DIR="/tmp/drift-detection/rendered"
BASELINE_DIR="/tmp/drift-detection/baseline"
mkdir -p "$RENDER_DIR" "$BASELINE_DIR"

VALIDATION_FAILED=false
BASE_BRANCH="${BASE_BRANCH:-origin/main}"

# Function to validate security fields in rendered manifests
validate_security_fields() {
    local manifest_file="$1"
    local validation_errors=0
    
    echo "  Validating security fields in $(basename "$manifest_file")..."
    
    # Check for critical security misconfigurations
    if grep -q "allowPrivilegeEscalation: true" "$manifest_file" 2>/dev/null; then
        echo -e "    ${RED}✗ CRITICAL: Privilege escalation allowed${NC}"
        validation_errors=$((validation_errors + 1))
    fi
    
    if grep -q "runAsNonRoot: false" "$manifest_file" 2>/dev/null; then
        echo -e "    ${RED}✗ CRITICAL: Container running as root${NC}"
        validation_errors=$((validation_errors + 1))
    fi
    
    if grep -q "hostNetwork: true" "$manifest_file" 2>/dev/null; then
        echo -e "    ${RED}✗ CRITICAL: Host network access enabled${NC}"
        validation_errors=$((validation_errors + 1))
    fi
    
    if grep -q "hostPID: true" "$manifest_file" 2>/dev/null; then
        echo -e "    ${RED}✗ CRITICAL: Host PID namespace access enabled${NC}"
        validation_errors=$((validation_errors + 1))
    fi
    
    if grep -q "hostIPC: true" "$manifest_file" 2>/dev/null; then
        echo -e "    ${RED}✗ CRITICAL: Host IPC namespace access enabled${NC}"
        validation_errors=$((validation_errors + 1))
    fi
    
    if grep -q "privileged: true" "$manifest_file" 2>/dev/null; then
        echo -e "    ${RED}✗ CRITICAL: Privileged container detected${NC}"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Check for dangerous capabilities
    if grep -A 5 "capabilities:" "$manifest_file" 2>/dev/null | grep -E "add:.*\[(.*SYS_ADMIN.*|.*NET_ADMIN.*|.*ALL.*)\]" 2>/dev/null; then
        echo -e "    ${RED}✗ CRITICAL: Dangerous capabilities granted (SYS_ADMIN/NET_ADMIN/ALL)${NC}"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Check for security best practices
    if ! grep -q "readOnlyRootFilesystem: true" "$manifest_file" 2>/dev/null && grep -q "kind: Deployment" "$manifest_file" 2>/dev/null; then
        echo -e "    ${YELLOW}⚠ WARNING: Read-only root filesystem not enforced${NC}"
    fi
    
    if grep -q "kind: NetworkPolicy" "$manifest_file" 2>/dev/null; then
        # Validate NetworkPolicy has actual rules, not just empty spec
        if grep -A 20 "kind: NetworkPolicy" "$manifest_file" 2>/dev/null | grep -qE "(ingress:|egress:)" 2>/dev/null; then
            echo -e "    ${GREEN}✓ NetworkPolicy defined with rules${NC}"
        else
            echo -e "    ${YELLOW}⚠ WARNING: NetworkPolicy defined but has no ingress/egress rules${NC}"
        fi
    fi
    
    # Validate TLS is actually enabled, not just present
    if grep -q "kind: Ingress" "$manifest_file" 2>/dev/null; then
        if grep -A 10 "tls:" "$manifest_file" 2>/dev/null | grep -E "^\s+- hosts:" 2>/dev/null; then
            echo -e "    ${GREEN}✓ TLS properly configured on Ingress${NC}"
        elif grep -qE "tls:\s*(true|enabled)" "$manifest_file" 2>/dev/null; then
            echo -e "    ${GREEN}✓ TLS enabled on Ingress${NC}"
        elif grep -q "tls:" "$manifest_file" 2>/dev/null; then
            echo -e "    ${YELLOW}⚠ WARNING: TLS key present but may not be enabled (check for 'tls: false')${NC}"
        fi
    fi
    
    return $validation_errors
}

# Render and validate Helm charts
if [[ "$HELM_DRIFT" == "true" ]]; then
    echo "Rendering Helm charts..."
    echo ""
    
    # Convert pipe-separated list back to newlines
    HELM_FILES=$(echo "$HELM_CHANGES" | tr '|' '\n' | grep -v '^$')
    
    # Find all Chart.yaml files in changed directories
    CHART_DIRS=$(echo "$HELM_FILES" | xargs -I {} dirname {} | sort -u | while read -r dir; do
        # Walk up to find Chart.yaml
        current_dir="$dir"
        while [[ "$current_dir" != "." && "$current_dir" != "/" ]]; do
            if [[ -f "$current_dir/Chart.yaml" ]]; then
                echo "$current_dir"
                break
            fi
            current_dir=$(dirname "$current_dir")
        done
    done | sort -u)
    
    if [[ -n "$CHART_DIRS" ]]; then
        while IFS= read -r chart_dir; do
            if [[ -f "$chart_dir/Chart.yaml" ]]; then
                chart_name=$(basename "$chart_dir")
                echo "Processing Helm chart: $chart_dir"
                
                # Render baseline (from main branch) - use unique temp file
                TEMP_VALUES=$(mktemp /tmp/values-baseline-$$.XXXXXX.yaml)
                echo "  Rendering baseline from $BASE_BRANCH..."
                git show "${BASE_BRANCH}:${chart_dir}/values.yaml" > "$TEMP_VALUES" 2>/dev/null || {
                    echo -e "  ${YELLOW}⚠ No baseline values.yaml found, skipping baseline comparison${NC}"
                    rm -f "$TEMP_VALUES"
                    continue
                }
                
                if command -v helm &> /dev/null; then
                    helm template "$chart_name" "$chart_dir" -f "$TEMP_VALUES" --output-dir "$BASELINE_DIR/${chart_name}-baseline" 2>/dev/null || {
                        echo -e "  ${YELLOW}⚠ Failed to render baseline chart${NC}"
                    }
                    rm -f "$TEMP_VALUES"
                    
                    # Render current version
                    echo "  Rendering current version..."
                    helm template "$chart_name" "$chart_dir" --output-dir "$RENDER_DIR/${chart_name}-current" 2>/dev/null || {
                        echo -e "  ${RED}✗ Failed to render current chart${NC}"
                        VALIDATION_FAILED=true
                        continue
                    }
                    
                    # Diff the manifests
                    echo "  Comparing manifests..."
                    if [[ -d "$BASELINE_DIR/${chart_name}-baseline" ]] && [[ -d "$RENDER_DIR/${chart_name}-current" ]]; then
                        diff -r "$BASELINE_DIR/${chart_name}-baseline" "$RENDER_DIR/${chart_name}-current" > "$RENDER_DIR/${chart_name}-diff.txt" 2>&1 || true
                        
                        if [[ -s "$RENDER_DIR/${chart_name}-diff.txt" ]]; then
                            echo -e "  ${YELLOW}⚠ Manifest differences detected${NC}"
                            
                            # Show security-relevant changes
                            SECURITY_DIFF=$(grep -E "networkPolicy|securityContext|tls|runAsUser|runAsNonRoot|allowPrivilegeEscalation" "$RENDER_DIR/${chart_name}-diff.txt" || true)
                            if [[ -n "$SECURITY_DIFF" ]]; then
                                echo "  Security-relevant changes:"
                                echo "$SECURITY_DIFF" | head -10 | sed 's/^/    /'
                            fi
                        else
                            echo -e "  ${GREEN}✓ No manifest differences${NC}"
                        fi
                    fi
                    
                    # Validate security fields in current manifests
                    for manifest in "$RENDER_DIR/${chart_name}-current"/**/*.yaml; do
                        if [[ -f "$manifest" ]]; then
                            validate_security_fields "$manifest" || VALIDATION_FAILED=true
                        fi
                    done
                else
                    echo -e "  ${YELLOW}⚠ Helm not installed, skipping chart rendering${NC}"
                fi
                
                echo ""
            fi
        done <<< "$CHART_DIRS"
    else
        echo -e "${YELLOW}⚠ No Helm charts found in changed files${NC}"
        echo ""
    fi
fi

# Render and validate Kustomize overlays
if [[ "$KUSTOMIZE_DRIFT" == "true" ]]; then
    echo "Building Kustomize overlays..."
    echo ""
    
    # Convert pipe-separated list back to newlines
    KUSTOMIZE_FILES=$(echo "$KUSTOMIZE_CHANGES" | tr '|' '\n' | grep -v '^$')
    
    # Find all kustomization.yaml directories
    KUSTOMIZE_DIRS=$(echo "$KUSTOMIZE_FILES" | xargs -I {} dirname {} | sort -u)
    
    if [[ -n "$KUSTOMIZE_DIRS" ]]; then
        while IFS= read -r kustomize_dir; do
            if [[ -f "$kustomize_dir/kustomization.yaml" ]]; then
                overlay_name=$(echo "$kustomize_dir" | tr '/' '_')
                echo "Processing Kustomize overlay: $kustomize_dir"
                
                if command -v kubectl &> /dev/null; then
                    # Build current overlay
                    echo "  Building overlay..."
                    kubectl kustomize "$kustomize_dir" > "$RENDER_DIR/${overlay_name}.yaml" 2>/dev/null || {
                        echo -e "  ${RED}✗ Failed to build overlay${NC}"
                        VALIDATION_FAILED=true
                        continue
                    }
                    
                    echo -e "  ${GREEN}✓ Overlay built successfully${NC}"
                    
                    # Validate security fields
                    validate_security_fields "$RENDER_DIR/${overlay_name}.yaml" || VALIDATION_FAILED=true
                    
                    # Check for OPA policies if conftest is available
                    if command -v conftest &> /dev/null && [[ -d "tests/fedramp-validation/opa-policies" ]]; then
                        echo "  Running OPA policy validation..."
                        if conftest test "$RENDER_DIR/${overlay_name}.yaml" -p tests/fedramp-validation/opa-policies/ 2>&1 | tee /tmp/conftest-output.txt; then
                            echo -e "  ${GREEN}✓ OPA policies passed${NC}"
                        else
                            echo -e "  ${RED}✗ OPA policy violations detected${NC}"
                            VALIDATION_FAILED=true
                        fi
                    fi
                else
                    echo -e "  ${YELLOW}⚠ kubectl not installed, skipping overlay build${NC}"
                fi
                
                echo ""
            fi
        done <<< "$KUSTOMIZE_DIRS"
    else
        echo -e "${YELLOW}⚠ No Kustomize overlays found in changed files${NC}"
        echo ""
    fi
fi

# Save validation results
cat > /tmp/drift-detection/validation.env << EOF
VALIDATION_FAILED=${VALIDATION_FAILED}
EOF

echo "=================================================="

# Calculate and save timing
END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
echo "$ELAPSED_TIME" > /tmp/drift-detection/timing.txt
echo "Execution time: ${ELAPSED_TIME}s (target: 15s)"

if [[ "$VALIDATION_FAILED" == "true" ]]; then
    echo -e "${RED}✗ Validation FAILED — security issues detected${NC}"
    echo "=================================================="
    exit 1
else
    echo -e "${GREEN}✓ Validation PASSED${NC}"
    echo "=================================================="
    exit 0
fi
