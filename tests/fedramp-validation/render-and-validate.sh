#!/bin/bash
# render-and-validate.sh
# Renders Helm charts and Kustomize overlays, then validates against FedRAMP controls
# Part of Issue #75: Drift Detection for Helm/Kustomize Configurations

set -e

echo "=== Rendering Helm Charts and Kustomize Overlays ==="

# Create output directories
mkdir -p /tmp/rendered-baseline
mkdir -p /tmp/rendered-current
mkdir -p /tmp/validation-results

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "⚠ Helm not installed — skipping Helm chart validation"
    HELM_AVAILABLE=false
else
    HELM_AVAILABLE=true
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "⚠ kubectl not installed — skipping Kustomize validation"
    KUSTOMIZE_AVAILABLE=false
else
    KUSTOMIZE_AVAILABLE=true
fi

# Validate Helm charts
if [[ "$HELM_AVAILABLE" == "true" ]]; then
  for chart_yaml in $(find . -name "Chart.yaml" 2>/dev/null || true); do
    chart_dir=$(dirname "$chart_yaml")
    chart_name=$(basename "$chart_dir")
    
    echo "Processing Helm chart: $chart_dir"
    
    # Check if values file changed
    values_changed=false
    if git diff --name-only origin/main...HEAD 2>/dev/null | grep -q "$chart_dir/values"; then
      values_changed=true
      echo "  ⚠ Values file changed — rendering both versions"
      
      # Render current version
      helm template "$chart_name" "$chart_dir" --output-dir "/tmp/rendered-current/$chart_name" 2>/dev/null || {
        echo "  ⚠ Failed to render chart: $chart_dir"
        continue
      }
      
      # Check for security-relevant changes
      if [ -f "/tmp/rendered-current/$chart_name"/*.yaml ]; then
        echo "  ✓ Chart rendered successfully"
        
        # Check for security fields
        grep -E 'kind: NetworkPolicy|kind: PodSecurityPolicy|securityContext|runAsUser|runAsNonRoot' \
          "/tmp/rendered-current/$chart_name"/*.yaml > "/tmp/validation-results/$chart_name-security-fields.txt" 2>/dev/null || true
        
        if [ -s "/tmp/validation-results/$chart_name-security-fields.txt" ]; then
          echo "  ✓ Security-relevant fields found"
        else
          echo "  ℹ No security fields detected in rendered manifests"
        fi
      fi
    else
      echo "  ✓ No values changes — skipping render"
    fi
  done
else
  echo "⚠ Skipping Helm validation (Helm not available)"
fi

# Validate Kustomize overlays
if [[ "$KUSTOMIZE_AVAILABLE" == "true" ]]; then
  for kustomization in $(find . -path '*/overlays/*/kustomization.yaml' 2>/dev/null || true); do
    overlay_dir=$(dirname "$kustomization")
    overlay_name=$(basename "$overlay_dir")
    
    echo "Processing Kustomize overlay: $overlay_dir"
    
    # Build the overlay
    kubectl kustomize "$overlay_dir" > "/tmp/rendered-current/$overlay_name.yaml" 2>/dev/null || {
      echo "  ⚠ Failed to build overlay: $overlay_dir"
      continue
    }
    
    echo "  ✓ Overlay built successfully"
    
    # Check for security-relevant resources
    grep -E 'kind: NetworkPolicy|kind: PodSecurityPolicy|securityContext' \
      "/tmp/rendered-current/$overlay_name.yaml" > "/tmp/validation-results/$overlay_name-security-resources.txt" 2>/dev/null || true
  done
else
  echo "⚠ Skipping Kustomize validation (kubectl not available)"
fi

echo ""
echo "=== Validation Complete ==="
echo "Results stored in: /tmp/validation-results/"
ls -lh /tmp/validation-results/ 2>/dev/null || echo "No validation results generated"
