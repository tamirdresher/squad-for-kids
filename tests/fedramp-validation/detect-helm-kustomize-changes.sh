#!/bin/bash
# detect-helm-kustomize-changes.sh
# Detects Helm chart and Kustomize overlay changes that may affect FedRAMP controls
# Part of Issue #75: Drift Detection for Helm/Kustomize Configurations

set -e

echo "=== Detecting Helm/Kustomize Configuration Changes ==="

CHANGED_FILES=$(git diff --name-only origin/main...HEAD 2>/dev/null || git diff --name-only HEAD~1...HEAD)

# Helm chart changes
HELM_CHANGES=$(echo "$CHANGED_FILES" | grep -E '(values.*\.yaml|Chart\.yaml)' || true)

# Kustomize changes
KUSTOMIZE_CHANGES=$(echo "$CHANGED_FILES" | grep -E 'kustomization\.yaml|overlays/|patches/' || true)

if [[ -n "$HELM_CHANGES" ]]; then
  echo "⚠ Helm configuration changes detected:"
  echo "$HELM_CHANGES" | sed 's/^/  - /'
  echo ""
fi

if [[ -n "$KUSTOMIZE_CHANGES" ]]; then
  echo "⚠ Kustomize configuration changes detected:"
  echo "$KUSTOMIZE_CHANGES" | sed 's/^/  - /'
  echo ""
fi

if [[ -n "$HELM_CHANGES" ]] || [[ -n "$KUSTOMIZE_CHANGES" ]]; then
  echo "✓ Configuration drift detected — FedRAMP validation required"
  echo "HELM_CHANGES=$HELM_CHANGES" >> /tmp/drift-detection.env
  echo "KUSTOMIZE_CHANGES=$KUSTOMIZE_CHANGES" >> /tmp/drift-detection.env
  exit 0
else
  echo "✓ No Helm/Kustomize changes detected"
  exit 0
fi
