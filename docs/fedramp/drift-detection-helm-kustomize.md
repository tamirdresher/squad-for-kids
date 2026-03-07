# FedRAMP Drift Detection: Helm & Kustomize Configurations

## Overview

This document extends the FedRAMP control drift detection established in PR #73 to include Helm chart values and Kustomize overlays. Silent configuration drift in these deployment manifests can degrade FedRAMP control posture without triggering existing validation checks.

**Related Issues:** #75  
**Related PRs:** #73 (FedRAMP CI/CD Validation)  
**Owner:** B'Elanna (Infrastructure Expert)

## Problem Statement

Current drift detection (from PR #73) monitors these file patterns:
- `network*` — NetworkPolicies
- `opa*` — OPA admission control policies
- `waf*` — WAF rules
- `policy*` — General security policies

**Gap:** Helm `values.yaml` and Kustomize overlays can modify security configurations indirectly:
- Helm chart version bumps may introduce vulnerable container images
- Values file changes can disable NetworkPolicies or weaken TLS settings
- Kustomize patches can override OPA annotations or security contexts
- Environment-specific overlays (e.g., sovereign vs. commercial) may drift apart

## Drift Detection Design

### Architecture

```
┌─────────────────────────────────────────────────┐
│   Pull Request Changes Detected                │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│   File Pattern Matching                        │
│   - values.yaml, values-*.yaml                 │
│   - Chart.yaml (appVersion, version)           │
│   - kustomization.yaml, overlays/**            │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│   Security Field Change Detection              │
│   - Helm: networkPolicy.enabled                │
│   - Helm: tls.enabled, ingress.tls             │
│   - Helm: securityContext, podSecurityContext  │
│   - Helm: image.tag, appVersion               │
│   - Kustomize: namespace, patches, replicas    │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│   Control Re-Validation Triggered              │
│   - Render Helm charts with changed values     │
│   - Apply Kustomize overlays                   │
│   - Run existing FedRAMP test suite            │
│   - Compare rendered manifests (diff baseline) │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│   Alert & Report                               │
│   - PR comment with control impact analysis    │
│   - Block merge if CRITICAL controls fail      │
│   - Generate compliance delta report           │
└─────────────────────────────────────────────────┘
```

### Integration with Existing CI/CD (PR #73)

The drift detection integrates into `.github/workflows/fedramp-validation.yml`:

**Existing Job:** `check-control-drift`
**Enhancement:** Add Helm/Kustomize pattern detection

## Monitored File Patterns

### Helm Charts

Monitor any changes to:
- `**/values.yaml`
- `**/values-*.yaml` (environment-specific values)
- `**/Chart.yaml` (appVersion, version fields)
- `**/charts/*/values.yaml` (subcharts)

**Security-Relevant Fields:**
```yaml
# Critical fields that affect FedRAMP controls
networkPolicy:
  enabled: true/false                    # SC-7 Boundary Protection
  
ingress:
  enabled: true/false
  tls:
    enabled: true/false                  # SC-8 Transmission Confidentiality
    
securityContext:
  runAsNonRoot: true/false              # CM-7 Least Functionality
  readOnlyRootFilesystem: true/false
  allowPrivilegeEscalation: false
  
podSecurityContext:
  fsGroup: <value>
  runAsUser: <value>
  
image:
  tag: <value>                          # SI-2 Flaw Remediation (version tracking)
  
replicaCount: <value>                   # CP-9 Availability (impacts IR-4)

annotations:
  # OPA policy annotations
  admission.gatekeeper.sh/*: <value>
```

### Kustomize Overlays

Monitor any changes to:
- `**/kustomization.yaml`
- `**/overlays/**/kustomization.yaml`
- `**/patches/*.yaml`
- `**/base/kustomization.yaml`

**Security-Relevant Operations:**
```yaml
# Operations that can degrade controls
namespace: <value>                      # Namespace isolation drift
  
patches:
  - path: <any-security-manifest>       # Direct manifest modifications

patchesStrategicMerge:
  - <any-security-resource>

commonLabels:
  # Label changes can break NetworkPolicy selectors

replicas: <value>                       # Replica count changes affect HA

configMapGenerator:
  # Config injection can bypass OPA validation
```

## Validation Workflow

### Step 1: Detect Changes

```bash
#!/bin/bash
# detect-helm-kustomize-changes.sh

CHANGED_FILES=$(git diff --name-only origin/main...HEAD)

# Helm chart changes
HELM_CHANGES=$(echo "$CHANGED_FILES" | grep -E '(values.*\.yaml|Chart\.yaml)')

# Kustomize changes
KUSTOMIZE_CHANGES=$(echo "$CHANGED_FILES" | grep -E 'kustomization\.yaml|overlays/|patches/')

if [[ -n "$HELM_CHANGES" ]] || [[ -n "$KUSTOMIZE_CHANGES" ]]; then
  echo "⚠ Configuration drift detected — triggering FedRAMP validation"
  exit 0  # Continue to validation
else
  echo "✓ No Helm/Kustomize changes detected"
  exit 0  # Skip validation
fi
```

### Step 2: Render Manifests

```bash
#!/bin/bash
# render-and-validate.sh

set -e

# For Helm charts
for chart in $(find . -name "Chart.yaml" -exec dirname {} \;); do
  echo "Rendering Helm chart: $chart"
  
  # Render with default values
  helm template "$chart" --output-dir /tmp/rendered-baseline
  
  # Render with modified values (if changed)
  if git diff --name-only origin/main...HEAD | grep -q "$(basename $chart)/values"; then
    helm template "$chart" --output-dir /tmp/rendered-current
    
    # Diff the manifests
    diff -r /tmp/rendered-baseline /tmp/rendered-current > /tmp/helm-diff.txt || true
    
    # Check for security field changes
    grep -E 'networkPolicy|securityContext|tls|runAsUser|runAsNonRoot' /tmp/helm-diff.txt || true
  fi
done

# For Kustomize overlays
for overlay in $(find . -path '*/overlays/*/kustomization.yaml' -exec dirname {} \;); do
  echo "Building Kustomize overlay: $overlay"
  
  kubectl kustomize "$overlay" > /tmp/kustomize-rendered.yaml
  
  # Validate against OPA policies
  conftest test /tmp/kustomize-rendered.yaml -p tests/fedramp-validation/opa-policies/
done
```

### Step 3: Run FedRAMP Test Suite

After rendering, execute the existing test suite from PR #73:
- `tests/fedramp-validation/network-policy-tests.sh`
- `tests/fedramp-validation/opa-policy-tests.sh`
- `tests/fedramp-validation/waf-rule-tests.sh`
- `tests/fedramp-validation/trivy-pipeline.yml`

### Step 4: Generate Compliance Delta Report

```bash
#!/bin/bash
# compliance-delta-report.sh

cat > /tmp/compliance-delta.md << EOF
# FedRAMP Compliance Delta Report

**PR:** #${{ github.event.pull_request.number }}
**Branch:** ${{ github.head_ref }}
**Date:** $(date -u)

## Configuration Changes Detected

### Helm Chart Changes
$(echo "$HELM_CHANGES" | sed 's/^/- /')

### Kustomize Overlay Changes
$(echo "$KUSTOMIZE_CHANGES" | sed 's/^/- /')

## Security Field Analysis

### NetworkPolicy Impact
$(grep 'networkPolicy' /tmp/helm-diff.txt | head -5 || echo "No changes")

### TLS Configuration Impact
$(grep 'tls' /tmp/helm-diff.txt | head -5 || echo "No changes")

### Security Context Impact
$(grep 'securityContext' /tmp/helm-diff.txt | head -5 || echo "No changes")

## Control Re-Validation Results

| Control | Status | Notes |
|---------|--------|-------|
| SC-7 (Boundary Protection) | ✓/⚠ | NetworkPolicy validation result |
| SC-8 (Transmission Confidentiality) | ✓/⚠ | TLS enforcement check |
| SI-3 (Malicious Code Protection) | ✓/⚠ | OPA policy validation |
| SI-2 (Flaw Remediation) | ✓/⚠ | Trivy scan result |

## Recommendation

- ✅ **Approve:** All controls pass, no security degradation
- ⚠ **Review Required:** Some controls weakened, manual review needed
- ❌ **Block:** CRITICAL controls failed, merge blocked

---
**Automated by:** FedRAMP Drift Detection (Issue #75)
EOF

cat /tmp/compliance-delta.md
```

## CI/CD Integration

### Enhanced `check-control-drift` Job

Add to `.github/workflows/fedramp-validation.yml`:

```yaml
check-control-drift:
  name: Check Control Drift
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0  # Need full history for diff
    
    - name: Detect changes to security controls
      run: |
        echo "=== Checking for security control modifications ==="
        
        # Existing patterns (from PR #73)
        POLICY_CHANGES=$(git diff --name-only origin/main...HEAD | grep -E 'network|opa|waf|policy' || true)
        
        # NEW: Helm/Kustomize patterns (Issue #75)
        HELM_CHANGES=$(git diff --name-only origin/main...HEAD | grep -E 'values.*\.yaml|Chart\.yaml' || true)
        KUSTOMIZE_CHANGES=$(git diff --name-only origin/main...HEAD | grep -E 'kustomization\.yaml|overlays/|patches/' || true)
        
        if [[ -n "$POLICY_CHANGES" ]] || [[ -n "$HELM_CHANGES" ]] || [[ -n "$KUSTOMIZE_CHANGES" ]]; then
          echo "⚠ Security control drift detected"
          echo "Policy files: $POLICY_CHANGES"
          echo "Helm charts: $HELM_CHANGES"
          echo "Kustomize overlays: $KUSTOMIZE_CHANGES"
          echo "DRIFT_DETECTED=true" >> $GITHUB_ENV
        else
          echo "✓ No drift detected"
          echo "DRIFT_DETECTED=false" >> $GITHUB_ENV
        fi
    
    - name: Install Helm (if needed)
      if: env.DRIFT_DETECTED == 'true'
      uses: azure/setup-helm@v4
      with:
        version: 'v3.13.0'
    
    - name: Install kubectl (if needed)
      if: env.DRIFT_DETECTED == 'true'
      uses: azure/setup-kubectl@v4
    
    - name: Render and validate Helm charts
      if: env.DRIFT_DETECTED == 'true'
      run: |
        # Download validation scripts
        chmod +x tests/fedramp-validation/detect-helm-kustomize-changes.sh
        chmod +x tests/fedramp-validation/render-and-validate.sh
        chmod +x tests/fedramp-validation/compliance-delta-report.sh
        
        # Run validation
        ./tests/fedramp-validation/detect-helm-kustomize-changes.sh
        ./tests/fedramp-validation/render-and-validate.sh
        ./tests/fedramp-validation/compliance-delta-report.sh
    
    - name: Upload compliance delta report
      if: env.DRIFT_DETECTED == 'true'
      uses: actions/upload-artifact@v4
      with:
        name: compliance-delta-report
        path: /tmp/compliance-delta.md
        retention-days: 30
    
    - name: Comment PR with drift analysis
      if: env.DRIFT_DETECTED == 'true' && github.event_name == 'pull_request'
      uses: actions/github-script@v7
      with:
        script: |
          const fs = require('fs');
          const report = fs.readFileSync('/tmp/compliance-delta.md', 'utf8');
          
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: report
          });
```

## Alert Thresholds

### CRITICAL (Block Merge)
- NetworkPolicy disabled (`networkPolicy.enabled: false`)
- TLS disabled (`ingress.tls.enabled: false`)
- Privileged container enabled (`securityContext.allowPrivilegeEscalation: true`)
- Root user allowed (`securityContext.runAsNonRoot: false`)
- Trivy scan finds CRITICAL CVEs

### WARNING (Require Manual Review)
- Chart version bump (major or minor version change)
- Replica count reduced below HA threshold (< 2)
- Namespace changed (potential isolation impact)
- Security annotations removed
- Image tag changed without Trivy re-scan

### INFO (Log Only)
- Values file documentation changes
- Non-security field updates (e.g., resource limits)
- Metadata labels/annotations (non-security)

## Performance Considerations

### Baseline Metrics (Related to Issue #76)

Rendering overhead estimates:
- **Helm template per chart:** ~1-3 seconds
- **Kustomize build per overlay:** ~0.5-2 seconds
- **Manifest diff analysis:** ~0.5-1 second
- **OPA policy validation:** ~2-5 seconds

**Total overhead per PR:** ~5-15 seconds (acceptable within CI/CD budget)

### Optimization Strategies

1. **Conditional Execution:** Only render charts with changed values
2. **Parallel Rendering:** Use `xargs -P` for multiple charts
3. **Caching:** Cache `helm template` output for unchanged charts
4. **Smart Diff:** Only diff security-relevant sections (grep filtering)

## Rollout Plan

### Phase 1: Detection Only (Week 1-2)
- Implement file pattern detection
- Generate INFO-level alerts
- Collect metrics on false positive rate
- **No blocking** — shadow mode only

### Phase 2: Validation Integration (Week 3-4)
- Enable Helm/Kustomize rendering
- Run FedRAMP test suite on rendered manifests
- Generate compliance delta reports
- Warn on CRITICAL issues but don't block

### Phase 3: Enforcement (Week 5+)
- Block PRs with CRITICAL control failures
- Require manual override for WARNING-level issues
- Full integration with ArgoCD deployment gates

## Success Criteria

✅ All Helm `values.yaml` changes detected and logged  
✅ Kustomize overlay modifications trigger re-validation  
✅ Chart version bumps validated against Trivy scan results  
✅ Compliance delta report generated within 15 seconds  
✅ Zero false negatives (all security drift caught)  
✅ False positive rate < 10% (low noise)  
✅ Integration with existing PR #73 workflow  

## Related Documentation

- **CI/CD Workflow:** `.github/workflows/fedramp-validation.yml` (PR #73)
- **Test Suite:** `tests/fedramp-validation/` (Issue #72)
- **Performance Baseline:** `docs/fedramp/performance-baseline-measurement.md` (Issue #76)
- **FedRAMP Controls:** `docs/fedramp/compensating-controls.md`

## Maintenance

**Review Cadence:** Monthly  
**Owner:** B'Elanna (Infrastructure Expert)  
**Related Issues:** #75, #72, #73  
**Status:** Implementation planned (Phase 1 ready)

---

**Document Version:** 1.0  
**Last Updated:** 2026-03-06  
**Issue:** #75 — Expand Drift Detection to Helm/Kustomize Configurations
