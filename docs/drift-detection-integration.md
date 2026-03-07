# Helm/Kustomize Drift Detection - Integration Guide
**Issue #87**

## Overview

This guide covers the integration of Helm/Kustomize drift detection into existing CI/CD pipelines. The drift detection system automatically identifies and validates security-relevant configuration changes in Helm charts and Kustomize overlays, ensuring FedRAMP compliance controls remain intact.

## Quick Start

### GitHub Actions Integration

1. **Copy the workflow file:**
   ```bash
   # The workflow is already in place
   .github/workflows/drift-detection.yml
   ```

2. **Ensure scripts are executable:**
   ```bash
   chmod +x scripts/drift-detection/*.sh
   ```

3. **Trigger the workflow:**
   - Automatically runs on PRs that modify:
     - `**/values*.yaml`
     - `**/Chart.yaml`
     - `**/kustomization.yaml`
     - `**/overlays/**`
     - `**/patches/**`

### Azure DevOps Integration

1. **Add the pipeline:**
   ```bash
   # Pipeline configuration is in
   .azure-pipelines/drift-detection-pipeline.yml
   ```

2. **Create the pipeline in Azure DevOps:**
   - Go to Pipelines → New Pipeline
   - Select your repository
   - Choose "Existing Azure Pipelines YAML file"
   - Select `.azure-pipelines/drift-detection-pipeline.yml`

3. **Configure branch policies:**
   - Add the drift detection pipeline as a required check
   - Block PRs if the pipeline fails

## Architecture

```
┌─────────────────────────────────────────────────┐
│   Pull Request Opened/Updated                  │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│   Step 1: Detect Changes                       │
│   - detect-helm-kustomize-changes.sh           │
│   - Identifies modified Helm/Kustomize files   │
│   - Flags security-relevant field changes      │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│   Step 2: Render & Validate                    │
│   - render-and-validate.sh                     │
│   - Renders Helm charts with changed values    │
│   - Builds Kustomize overlays                  │
│   - Validates security contexts                │
│   - Runs OPA policy checks                     │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│   Step 3: Generate Report                      │
│   - compliance-delta-report.sh                 │
│   - Maps changes to FedRAMP controls           │
│   - Generates compliance impact analysis       │
│   - Posts report as PR comment                 │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│   Merge Decision                               │
│   ✅ Approve / ⚠️ Review Required / ❌ Block  │
└─────────────────────────────────────────────────┘
```

## Scripts Reference

### 1. detect-helm-kustomize-changes.sh

**Purpose:** Identifies configuration drift in Helm charts and Kustomize overlays.

**Usage:**
```bash
export BASE_BRANCH="origin/main"
./scripts/drift-detection/detect-helm-kustomize-changes.sh
```

**Outputs:**
- Exit code: 0 (always continues to validation)
- Creates: `/tmp/drift-detection/changes.env` with:
  - `HELM_DRIFT` (true/false)
  - `KUSTOMIZE_DRIFT` (true/false)
  - `SECURITY_DRIFT` (true/false)
  - `HELM_CHANGES` (pipe-separated file list)
  - `KUSTOMIZE_CHANGES` (pipe-separated file list)

**Detected Patterns:**
- Helm: `values*.yaml`, `Chart.yaml`, `charts/*/values.yaml`
- Kustomize: `kustomization.yaml`, `overlays/**`, `patches/**`
- Security fields: `networkPolicy`, `securityContext`, `tls`, `image.tag`

### 2. render-and-validate.sh

**Purpose:** Renders manifests and validates security configurations.

**Usage:**
```bash
./scripts/drift-detection/render-and-validate.sh
```

**Prerequisites:**
- `helm` (v3.13.0+)
- `kubectl` (v1.28.0+)
- `conftest` (optional, for OPA policies)

**Outputs:**
- Exit code: 0 (pass) or 1 (fail)
- Creates: `/tmp/drift-detection/rendered/` with rendered manifests
- Creates: `/tmp/drift-detection/validation.env` with `VALIDATION_FAILED` flag

**Validation Checks:**
- ❌ CRITICAL: Privilege escalation allowed
- ❌ CRITICAL: Running as root
- ❌ CRITICAL: Host network access
- ⚠️ WARNING: Read-only root filesystem not enforced
- ✅ PASS: NetworkPolicy defined
- ✅ PASS: TLS configured

### 3. compliance-delta-report.sh

**Purpose:** Generates FedRAMP compliance impact report.

**Usage:**
```bash
export PR_NUMBER="123"
export BRANCH_NAME="feature-branch"
export COMMIT_SHA="abc123def"
./scripts/drift-detection/compliance-delta-report.sh
```

**Outputs:**
- Exit code: 0 (approved) or 1 (blocked)
- Creates: `/tmp/drift-detection/compliance-delta-report.md`

**Report Sections:**
- Configuration changes detected
- Security field analysis
- FedRAMP control validation results (SC-7, SC-8, CM-7, SI-2, SI-3)
- Recommendation (Approve/Review/Block)
- Performance metrics

## FedRAMP Control Mapping

| Control | Description | Validation | Blocking Threshold |
|---------|-------------|------------|-------------------|
| **SC-7** | Boundary Protection | NetworkPolicy enabled | CRITICAL if disabled |
| **SC-8** | Transmission Confidentiality | TLS enabled on Ingress | CRITICAL if disabled |
| **CM-7** | Least Functionality | Security context restrictions | CRITICAL if degraded |
| **SI-2** | Flaw Remediation | Image version tracking | WARNING on version change |
| **SI-3** | Malicious Code Protection | OPA policy validation | FAIL on policy violation |

## Alert Thresholds

### ❌ CRITICAL (Merge Blocked)
- `networkPolicy.enabled: false`
- `ingress.tls.enabled: false`
- `allowPrivilegeEscalation: true`
- `runAsNonRoot: false`
- `hostNetwork: true`
- `hostPID: true`
- `hostIPC: true`

### ⚠️ WARNING (Manual Review Required)
- Chart version bump (major/minor)
- Replica count reduced below 2
- Namespace changed
- Security annotations removed
- Image tag changed without scan

### ℹ️ INFO (Logged Only)
- Documentation changes
- Non-security field updates
- Metadata labels (non-security)

## Performance

Target: **< 15 seconds per PR**

Breakdown:
- Detection: ~1-2 seconds
- Rendering: ~5-10 seconds (depends on chart complexity)
- Validation: ~2-5 seconds
- Report generation: ~1-2 seconds

**Optimization:**
- Only renders charts with changed values
- Skips validation if no drift detected
- Caches rendered manifests as CI artifacts

## Testing

Run the test suite:
```bash
cd tests/drift-detection
chmod +x test-drift-detection.sh
./test-drift-detection.sh
```

Test coverage:
- ✅ Change detection (Helm/Kustomize)
- ✅ Security field analysis
- ✅ Validation script execution
- ✅ Compliance report generation
- ✅ No false positives

## Troubleshooting

### Detection script reports no changes
- Verify `BASE_BRANCH` is set correctly
- Ensure full git history is fetched (`fetch-depth: 0`)
- Check file patterns match your chart structure

### Validation fails to render charts
- Verify Helm is installed (`helm version`)
- Check Chart.yaml syntax
- Ensure values.yaml is valid YAML
- Review helm template errors in logs

### OPA policies not running
- Install conftest: `wget https://github.com/open-policy-agent/conftest/releases/...`
- Create policies in `tests/fedramp-validation/opa-policies/`
- Validate policy syntax: `conftest verify -p tests/fedramp-validation/opa-policies/`

### Performance exceeds 15 seconds
- Profile with `time` command on each script
- Reduce number of charts rendered (use changed-files filter)
- Enable parallel rendering (future enhancement)
- Cache baseline renders between runs

## Rollout Plan

### Phase 1: Shadow Mode (Week 1-2)
- ✅ Detection only, no blocking
- ✅ Generate reports for visibility
- ✅ Measure false positive rate

### Phase 2: Validation (Week 3-4)
- ✅ Enable manifest rendering
- ✅ Run security validations
- ⚠️ Warn on CRITICAL issues (don't block)

### Phase 3: Enforcement (Week 5+)
- ❌ Block PRs with CRITICAL failures
- ⚠️ Require override for WARNINGs
- 🔒 Full integration with deployment gates

## Customization

### Adding Custom Validation Rules

Edit `render-and-validate.sh`:
```bash
# Add custom check
if grep -q "customField: badValue" "$manifest_file" 2>/dev/null; then
    echo -e "    ${RED}✗ CRITICAL: Custom rule violated${NC}"
    validation_errors=$((validation_errors + 1))
fi
```

### Adjusting Alert Thresholds

Edit `compliance-delta-report.sh`:
```bash
# Change recommendation logic
if [[ "$VALIDATION_FAILED" == "true" ]]; then
    # Block instead of review required
    echo "### ❌ **MERGE BLOCKED**" >> "$REPORT_FILE"
fi
```

### Custom File Patterns

Edit `detect-helm-kustomize-changes.sh`:
```bash
# Add custom patterns
CUSTOM_CHANGES=$(echo "$CHANGED_FILES" | grep -E 'your-pattern-here')
```

## Integration with Existing Workflows

### Extending PR #73 (FedRAMP Validation)

Add to `.github/workflows/fedramp-validation.yml`:
```yaml
jobs:
  check-control-drift:
    steps:
      # ... existing steps ...
      
      - name: Run Helm/Kustomize drift detection
        run: |
          bash scripts/drift-detection/detect-helm-kustomize-changes.sh
          bash scripts/drift-detection/render-and-validate.sh
          bash scripts/drift-detection/compliance-delta-report.sh
```

### ArgoCD Integration

Add to ArgoCD Application spec:
```yaml
spec:
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
    syncOptions:
      - CreateNamespace=false
      - PruneLast=true
  # Require drift detection to pass before sync
  ignoreDifferences:
    - group: ""
      kind: ConfigMap
      jsonPointers:
        - /data
```

## Maintenance

**Weekly:**
- Review false positive rates
- Update security patterns as needed
- Check performance metrics

**Monthly:**
- Update Helm/kubectl versions
- Review and tune alert thresholds
- Audit blocked PRs for patterns

**Quarterly:**
- Review FedRAMP control mapping
- Update documentation
- Conduct security posture assessment

## Support

**Documentation:**
- Plan: `docs/fedramp/drift-detection-helm-kustomize.md`
- Tests: `tests/drift-detection/README.md`
- This guide: `docs/drift-detection-integration.md`

**Contact:**
- Issue #87 comments
- @B'Elanna (Infrastructure Expert) - Primary owner
- @Data (Code Expert) - Implementation support

## Related Issues & PRs

- **Issue #75** - Original drift detection requirement
- **PR #80** - Drift detection plan delivery
- **Issue #87** - Implementation (this work)
- **Issue #72** - FedRAMP test suite
- **PR #73** - FedRAMP CI/CD validation workflow
- **Issue #76** - Performance baseline measurement
