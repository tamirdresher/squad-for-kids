# Drift Detection Test Fixtures
# Issue #87 - Helm/Kustomize Drift Detection

This directory contains test fixtures for the drift detection scripts.

## Structure

- `test-drift-detection.sh` - Main test suite
- `fixtures/` - Sample Helm charts and Kustomize overlays for testing
  - `helm/` - Sample Helm charts
  - `kustomize/` - Sample Kustomize overlays
- `expected/` - Expected output files for validation

## Running Tests

```bash
# Run all tests
./test-drift-detection.sh

# Run with verbose output
bash -x ./test-drift-detection.sh
```

## Test Coverage

1. **Change Detection Tests**
   - Detects Helm values.yaml modifications
   - Detects Chart.yaml changes
   - Detects Kustomize overlay modifications
   - No false positives on unrelated changes

2. **Security Field Analysis Tests**
   - Identifies networkPolicy changes
   - Identifies TLS configuration changes
   - Identifies securityContext modifications
   - Identifies image version changes

3. **Validation Tests**
   - Renders Helm charts correctly
   - Builds Kustomize overlays successfully
   - Validates security contexts
   - Runs OPA policy checks (if conftest available)

4. **Compliance Report Tests**
   - Generates markdown report
   - Includes PR metadata
   - Maps changes to FedRAMP controls
   - Provides correct recommendations

5. **Integration Tests**
   - End-to-end workflow (detect → validate → report)
   - Script error handling
   - File permissions and executability

## Test Data

### Sample Helm Chart (Secure)
```yaml
# values.yaml
networkPolicy:
  enabled: true
securityContext:
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
ingress:
  tls:
    enabled: true
```

### Sample Helm Chart (Insecure)
```yaml
# values.yaml
networkPolicy:
  enabled: false  # CRITICAL
securityContext:
  runAsNonRoot: false  # CRITICAL
  allowPrivilegeEscalation: true  # CRITICAL
ingress:
  tls:
    enabled: false  # CRITICAL
```

### Sample Kustomize Overlay
```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: production
patches:
  - path: networkpolicy-patch.yaml
```

## Expected Behavior

### Detection Phase
- Exit code 0 (always continues to validation if drift detected)
- Creates `/tmp/drift-detection/changes.env` with drift flags
- Outputs file list of changed configurations

### Validation Phase
- Exit code 0 if no security issues
- Exit code 1 if CRITICAL security violations detected
- Creates rendered manifest files in `/tmp/drift-detection/rendered/`
- Validates against security baselines

### Reporting Phase
- Exit code 0 if approved for merge
- Exit code 1 if merge blocked
- Generates `/tmp/drift-detection/compliance-delta-report.md`
- Maps changes to FedRAMP controls (SC-7, SC-8, CM-7, SI-2, SI-3)

## CI/CD Integration

These tests run in CI/CD pipelines before the actual drift detection workflow:

```yaml
- name: Test drift detection scripts
  run: |
    chmod +x tests/drift-detection/test-drift-detection.sh
    ./tests/drift-detection/test-drift-detection.sh
```

## Troubleshooting

### Tests fail to find scripts
- Ensure you're running from repository root
- Check that scripts have execute permissions: `chmod +x scripts/drift-detection/*.sh`

### Git errors in tests
- Tests create temporary git repos
- Ensure git is configured with user.name and user.email

### Missing dependencies
- Tests require: git, bash, grep, sed
- Optional: helm, kubectl, conftest (for full validation)

## Future Enhancements

- [ ] Add performance benchmarks (target: < 15 seconds)
- [ ] Add OPA policy test fixtures
- [ ] Add multi-chart repository tests
- [ ] Add Azure DevOps pipeline integration tests
- [ ] Add baseline comparison tests with manifest diffs
