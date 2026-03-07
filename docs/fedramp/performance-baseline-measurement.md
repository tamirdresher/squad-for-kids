# FedRAMP Performance Baseline Measurement Plan

## Overview

This document establishes performance baselines and measurement methodology for deploying the FedRAMP validation workflow (from PR #73) to sovereign production environments. Ensures validation overhead doesn't degrade CI/CD pipeline performance.

**Related Issues:** #76  
**Related PRs:** #73 (FedRAMP CI/CD Validation), #80 (Drift Detection)  
**Owner:** B'Elanna (Infrastructure Expert)

## Problem Statement

The FedRAMP validation workflow introduced in PR #73 adds 9 control checks to the CI/CD pipeline:
1. Network Policy validation
2. OPA policy tests
3. WAF rule tests
4. Trivy vulnerability scanning
5. Test plan verification
6. Documentation linting
7. Control drift detection
8. Compliance matrix generation
9. Alert integration

**Before production deployment**, we must:
- Measure current pipeline performance (baseline)
- Measure FedRAMP validation overhead
- Define acceptable performance thresholds
- Establish go/no-go criteria for sovereign deployment

## Measurement Methodology

### Test Environments

| Environment | Purpose | Location | Characteristics |
|-------------|---------|----------|-----------------|
| **DEV** | Initial validation | Commercial cloud | Shared resources, non-sovereign |
| **STG** | Pre-production testing | Commercial cloud | Production-like, non-sovereign |
| **STG-USGOV-01** | Sovereign staging | US Gov Cloud | Sovereign environment, production-like |
| **PROD** | Production deployment | Commercial cloud | High availability, critical workload |
| **PROD-USGOV** | Sovereign production | US Gov Cloud | Target environment for FedRAMP controls |

### Measurement Tools

```yaml
# CI/CD Pipeline Instrumentation
tools:
  - GitHub Actions workflow timing (built-in)
  - Trivy scan duration (CLI timing)
  - Helm render duration (time command)
  - OPA evaluation latency (conftest --bench)
  - WAF rule evaluation (mock HTTP requests with timing)
  - Git operations (git diff, checkout timing)
```

### Baseline Metrics Collection

Run the following measurements in each environment:

#### 1. CI/CD Pipeline Execution Time (Without FedRAMP Validation)

**Measurement:**
```bash
# Baseline PR workflow without FedRAMP checks
time gh workflow run build-and-test.yml --ref main
```

**Metrics to collect:**
- Total pipeline duration (wall clock)
- Checkout time
- Build time
- Test time
- Deployment time (if applicable)

**Expected Baseline:**
- DEV/STG: 3-5 minutes
- Sovereign (STG-USGOV-01): 4-7 minutes (network latency)
- PROD: 5-10 minutes (includes deployment)

#### 2. CI/CD Pipeline Execution Time (With FedRAMP Validation)

**Measurement:**
```bash
# Full PR workflow with FedRAMP validation enabled
time gh workflow run build-and-test.yml --ref squad/72-fedramp-cicd
```

**Metrics to collect:**
- Total pipeline duration (wall clock)
- FedRAMP validation job duration (breakdown by step)
- Overhead percentage: `(with_validation - without_validation) / without_validation * 100`

**Target:**
- Overhead < 20% in commercial environments
- Overhead < 30% in sovereign environments (account for network latency)

#### 3. Trivy Scan Duration

**Measurement:**
```bash
#!/bin/bash
# trivy-benchmark.sh

IMAGES=(
  "nginx:1.25.3"
  "myapp:latest"
  "sovereign-app:v1.2.3"
)

for image in "${IMAGES[@]}"; do
  echo "Scanning: $image"
  time trivy image \
    --severity CRITICAL,HIGH \
    --exit-code 1 \
    --format json \
    --output /tmp/trivy-$image.json \
    $image
done
```

**Metrics to collect:**
- Scan duration per image (seconds)
- Database update time (if cache miss)
- Network latency impact (sovereign vs. commercial)
- Scan result size (KB)

**Expected Duration:**
- Small image (<100MB): 10-30 seconds
- Medium image (100-500MB): 30-90 seconds
- Large image (>500MB): 90-180 seconds

**Sovereign-Specific:**
- Database download: +30-60 seconds (first run or cache miss)
- Air-gapped mode: Pre-cache databases (no network overhead)

#### 4. WAF Rule Evaluation Latency

**Measurement:**
```bash
#!/bin/bash
# waf-latency-benchmark.sh

# Simulate HTTP requests through WAF
WAF_ENDPOINT="https://test-waf.example.com"

TEST_REQUESTS=(
  "/api/users"
  "/api/users/123"
  "/api/search?q=test"
  "/api/admin; DROP TABLE users"  # Attack pattern
  "/health"
)

for req in "${TEST_REQUESTS[@]}"; do
  echo "Testing: $req"
  time curl -s -o /dev/null -w "Time: %{time_total}s\n" "$WAF_ENDPOINT$req"
done
```

**Metrics to collect:**
- Request latency with WAF (ms)
- Request latency without WAF (baseline, ms)
- Latency overhead per request: `waf_latency - baseline_latency`
- P50, P95, P99 latency percentiles

**Expected Overhead:**
- Normal requests: <10ms per request
- Attack patterns (blocked): <20ms per request
- DDoS rate limiting: <5ms per request

**Acceptable Thresholds:**
- P95 latency increase: <25ms
- P99 latency increase: <50ms
- Throughput reduction: <5%

#### 5. Control Drift Detection Performance

**Measurement:**
```bash
#!/bin/bash
# drift-detection-benchmark.sh

# Simulate drift detection on various PR sizes
PR_SIZES=(
  "small"   # 1-3 files changed
  "medium"  # 5-10 files changed
  "large"   # 20+ files changed
)

for size in "${PR_SIZES[@]}"; do
  echo "Testing $size PR"
  
  time {
    git diff --name-only origin/main...HEAD | \
    grep -E 'network|opa|waf|policy|values.*\.yaml|Chart\.yaml|kustomization\.yaml'
    
    # Helm rendering (if applicable)
    if [ -d charts/ ]; then
      helm template ./charts/* --output-dir /tmp/rendered
    fi
    
    # Kustomize building (if applicable)
    if [ -d overlays/ ]; then
      kubectl kustomize overlays/staging > /tmp/kustomize-staging.yaml
    fi
  }
done
```

**Metrics to collect:**
- Drift detection time (git diff + pattern matching)
- Helm template rendering time
- Kustomize build time
- Total overhead per PR size

**Expected Duration:**
- Small PR: 2-5 seconds
- Medium PR: 5-10 seconds
- Large PR: 10-20 seconds

**Target:** <15 seconds for 95% of PRs

#### 6. OPA Policy Evaluation Performance

**Measurement:**
```bash
#!/bin/bash
# opa-benchmark.sh

# Benchmark OPA policy evaluation with conftest
time conftest test \
  --bench \
  --policy tests/fedramp-validation/opa-policies/ \
  tests/fedramp-validation/test-manifests/*.yaml
```

**Metrics to collect:**
- Policy evaluation time per manifest (ms)
- Total evaluation time for full test suite (s)
- Policy compilation time (first run)
- Cached evaluation time (subsequent runs)

**Expected Duration:**
- Single manifest: 50-200ms
- Full test suite (50 manifests): 3-8 seconds

**Target:** <10 seconds for full OPA validation

## Performance Thresholds

### Go/No-Go Criteria

| Metric | Commercial Threshold | Sovereign Threshold | Status |
|--------|---------------------|---------------------|--------|
| **Pipeline Overhead** | <20% increase | <30% increase | ⏳ Measure |
| **Trivy Scan Duration** | <120s per image | <180s per image | ⏳ Measure |
| **WAF Latency Overhead** | P95 <25ms | P95 <40ms | ⏳ Measure |
| **Drift Detection** | <15s per PR | <20s per PR | ⏳ Measure |
| **OPA Evaluation** | <10s full suite | <15s full suite | ⏳ Measure |
| **Total Validation Time** | <3 min per PR | <5 min per PR | ⏳ Measure |

### Acceptance Criteria

✅ **Deploy to Sovereign:** All thresholds met or within 10% margin  
⚠ **Deploy with Monitoring:** Some thresholds exceeded but <25% margin  
❌ **Block Deployment:** Critical thresholds exceeded (>25% margin)

## Baseline Measurement Scripts

### Master Benchmark Script

```bash
#!/bin/bash
# fedramp-performance-baseline.sh
# Master script to collect all performance baselines

set -e

OUTPUT_DIR="/tmp/fedramp-performance-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "=== FedRAMP Performance Baseline Measurement ==="
echo "Output directory: $OUTPUT_DIR"
echo "Start time: $(date -u)"
echo ""

# 1. Pipeline baseline (without FedRAMP)
echo "1. Measuring baseline pipeline performance..."
time gh workflow run build-and-test.yml --ref main 2>&1 | tee "$OUTPUT_DIR/01-pipeline-baseline.log"

# 2. Pipeline with FedRAMP validation
echo "2. Measuring pipeline with FedRAMP validation..."
time gh workflow run build-and-test.yml --ref squad/72-fedramp-cicd 2>&1 | tee "$OUTPUT_DIR/02-pipeline-fedramp.log"

# 3. Trivy scan duration
echo "3. Benchmarking Trivy scans..."
./tests/fedramp-validation/trivy-benchmark.sh 2>&1 | tee "$OUTPUT_DIR/03-trivy-benchmark.log"

# 4. WAF latency impact
echo "4. Measuring WAF latency overhead..."
./tests/fedramp-validation/waf-latency-benchmark.sh 2>&1 | tee "$OUTPUT_DIR/04-waf-latency.log"

# 5. Drift detection performance
echo "5. Benchmarking drift detection..."
./tests/fedramp-validation/drift-detection-benchmark.sh 2>&1 | tee "$OUTPUT_DIR/05-drift-detection.log"

# 6. OPA policy evaluation
echo "6. Benchmarking OPA policy evaluation..."
./tests/fedramp-validation/opa-benchmark.sh 2>&1 | tee "$OUTPUT_DIR/06-opa-benchmark.log"

echo ""
echo "=== Benchmark Complete ==="
echo "End time: $(date -u)"
echo "Results: $OUTPUT_DIR"

# Generate summary report
cat > "$OUTPUT_DIR/SUMMARY.md" << 'EOF'
# FedRAMP Performance Baseline Summary

**Date:** $(date -u)
**Environment:** $(echo $ENVIRONMENT_NAME)

## Pipeline Performance

| Measurement | Duration | Threshold | Status |
|-------------|----------|-----------|--------|
| Baseline Pipeline | TBD | N/A | ⏳ |
| Pipeline + FedRAMP | TBD | <20% overhead | ⏳ |
| Overhead % | TBD | <20% | ⏳ |

## Component Benchmarks

### Trivy Scanning
- Small image: TBD (target: <30s)
- Medium image: TBD (target: <90s)
- Large image: TBD (target: <180s)

### WAF Latency
- P50: TBD (target: <10ms)
- P95: TBD (target: <25ms)
- P99: TBD (target: <50ms)

### Drift Detection
- Small PR: TBD (target: <5s)
- Medium PR: TBD (target: <10s)
- Large PR: TBD (target: <15s)

### OPA Evaluation
- Single manifest: TBD (target: <200ms)
- Full suite: TBD (target: <10s)

## Go/No-Go Decision

- [ ] All metrics within acceptable thresholds
- [ ] Sovereign-specific considerations addressed
- [ ] Monitoring and alerting configured
- [ ] Rollback plan documented

## Recommendations

_To be filled after measurement_

---
**Measurement Plan:** docs/fedramp/performance-baseline-measurement.md
**Issue:** #76
EOF

cat "$OUTPUT_DIR/SUMMARY.md"
```

## Sovereign Production Considerations

### Network Latency Impact

**Factors:**
- Trivy database download from sovereign registry
- Helm chart repository access (sovereign-hosted)
- Git operations over VPN/private links
- Container image pulls from sovereign registry

**Mitigation Strategies:**
1. **Pre-cache Trivy databases:** Run `trivy image --download-db-only` in init container
2. **Local Helm repository:** Host chart repositories within sovereign boundary
3. **Registry mirrors:** Use sovereign-local container registry mirrors
4. **Persistent caching:** Cache build artifacts, dependencies across pipeline runs

### Sovereign-Specific Thresholds

Adjust thresholds for sovereign environments:

| Metric | Adjustment | Reason |
|--------|-----------|--------|
| Pipeline overhead | +10% | Network latency, registry access |
| Trivy scan | +60s | Database download over restricted network |
| Drift detection | +5s | Git operations over VPN |
| WAF latency | +15ms | Additional hop through sovereign gateway |

### Pre-Production Validation

Before deploying to **PROD-USGOV:**

1. **Run full benchmark suite in STG-USGOV-01**
2. **Validate with production-like workload** (synthetic PR traffic)
3. **Measure at peak load** (simulate 10 concurrent PRs)
4. **Monitor resource utilization** (CPU, memory, network)
5. **Validate ArgoCD sync performance** (progressive rollout timing)

## Monitoring and Alerting

### Continuous Monitoring (Post-Deployment)

Track these metrics in production:

```yaml
# Prometheus metrics to collect
metrics:
  - fedramp_validation_duration_seconds{job="ci-cd-pipeline"}
  - fedramp_trivy_scan_duration_seconds{image="*"}
  - fedramp_waf_latency_milliseconds{endpoint="*"}
  - fedramp_drift_detection_duration_seconds{pr_size="*"}
  - fedramp_opa_evaluation_duration_seconds{policy="*"}
  - fedramp_pipeline_overhead_percentage
```

### Alert Thresholds

```yaml
# AlertManager rules
alerts:
  - name: FedRAMPValidationSlow
    expr: fedramp_validation_duration_seconds > 300  # 5 minutes
    severity: warning
    message: "FedRAMP validation taking longer than 5 minutes"
  
  - name: FedRAMPValidationFailed
    expr: fedramp_validation_success == 0
    severity: critical
    message: "FedRAMP validation failed — potential control degradation"
  
  - name: FedRAMPTrivyScanSlow
    expr: fedramp_trivy_scan_duration_seconds > 180
    severity: warning
    message: "Trivy scan exceeding 3 minutes"
  
  - name: FedRAMPPipelineOverhead
    expr: fedramp_pipeline_overhead_percentage > 30
    severity: warning
    message: "FedRAMP validation overhead exceeding 30%"
```

## Rollout Schedule

### Week 1: Baseline Measurement (DEV)
- Run benchmark suite in DEV environment
- Collect baseline metrics (without FedRAMP validation)
- Identify bottlenecks and optimization opportunities

### Week 2: FedRAMP Validation Measurement (DEV + STG)
- Deploy FedRAMP validation workflow to DEV
- Measure overhead and performance impact
- Run benchmark suite in STG environment
- Compare DEV vs. STG performance

### Week 3: Sovereign Environment Measurement (STG-USGOV-01)
- Deploy to sovereign staging environment
- Measure sovereign-specific overhead
- Validate network latency mitigation strategies
- Collect production-like workload metrics

### Week 4: Production Validation (PROD Commercial)
- Deploy to commercial production (non-sovereign)
- Monitor performance with real PR traffic
- Validate alert thresholds and monitoring
- Collect 1 week of production metrics

### Week 5+: Sovereign Production Deployment (PROD-USGOV)
- **Go/No-Go Decision:** Review all measurements against thresholds
- Deploy to sovereign production with progressive rollout
- 10% traffic → 25% → 50% → 100% over 2 weeks
- Continuous monitoring and performance validation

## Performance Optimization Strategies

### If Thresholds Exceeded

#### 1. Parallel Execution
```yaml
# Run independent checks in parallel
jobs:
  trivy-scan:
    runs-on: ubuntu-latest
  opa-validation:
    runs-on: ubuntu-latest
  waf-tests:
    runs-on: ubuntu-latest
  # All run simultaneously instead of sequentially
```

#### 2. Conditional Execution
```yaml
# Only run full validation on security-related changes
if: |
  contains(github.event.pull_request.changed_files, 'network') ||
  contains(github.event.pull_request.changed_files, 'opa') ||
  contains(github.event.pull_request.changed_files, 'waf')
```

#### 3. Caching Strategies
```yaml
# Cache Trivy database
- uses: actions/cache@v4
  with:
    path: ~/.cache/trivy
    key: trivy-db-${{ runner.os }}-${{ hashFiles('**/trivy.yaml') }}
    restore-keys: trivy-db-${{ runner.os }}-
```

#### 4. Incremental Validation
- Only validate changed Helm charts (not all charts)
- Only scan changed container images (not all images)
- Only run OPA policies relevant to changed resources

#### 5. Resource Optimization
```yaml
# Use larger GitHub Actions runners for performance-critical jobs
runs-on: ubuntu-latest-8-cores  # Instead of ubuntu-latest
```

## Success Criteria

✅ **Baseline metrics collected** for all 6 measurement categories  
✅ **Overhead < 20%** in commercial environments  
✅ **Overhead < 30%** in sovereign environments  
✅ **No CI/CD pipeline regression** in non-FedRAMP workloads  
✅ **Go/No-Go criteria** defined and validated  
✅ **Monitoring and alerting** configured and tested  
✅ **Optimization strategies** documented for threshold breaches  
✅ **Rollback plan** tested in STG-USGOV-01  

## Related Documentation

- **CI/CD Workflow:** `.github/workflows/fedramp-validation.yml` (PR #73)
- **Test Suite:** `tests/fedramp-validation/` (Issue #72)
- **Drift Detection:** `docs/fedramp/drift-detection-helm-kustomize.md` (Issue #75)
- **FedRAMP Controls:** `docs/fedramp/compensating-controls.md`

## Maintenance

**Review Cadence:** Monthly (post-deployment), Weekly (during rollout)  
**Owner:** B'Elanna (Infrastructure Expert)  
**Related Issues:** #76, #72, #73, #75  
**Status:** Measurement plan ready for execution

---

**Document Version:** 1.0  
**Last Updated:** 2026-03-06  
**Issue:** #76 — Performance Baseline Measurement for Sovereign Production
