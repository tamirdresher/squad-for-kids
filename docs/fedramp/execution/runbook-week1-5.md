# FedRAMP Performance Baseline & Sovereign Rollout Runbook
**Issue:** #89 - Performance Baseline & Progressive Sovereign Rollout  
**Owner:** B'Elanna (Infrastructure Expert)  
**Last Updated:** 2026-03-08

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Week 1: DEV Baseline](#week-1-dev-baseline)
4. [Week 2: FedRAMP Overhead Measurement](#week-2-fedramp-overhead-measurement)
5. [Week 3: Sovereign Staging](#week-3-sovereign-staging)
6. [Week 4: Production Validation](#week-4-production-validation)
7. [Week 5+: Progressive Rollout](#week-5-progressive-rollout)
8. [Troubleshooting](#troubleshooting)
9. [Rollback Procedures](#rollback-procedures)
10. [Monitoring & Alerting](#monitoring--alerting)

---

## Overview

This runbook provides step-by-step execution instructions for the 5-week FedRAMP performance baseline measurement and progressive sovereign production rollout.

### Goals

- **Week 1:** Establish baseline performance in DEV (no FedRAMP validation)
- **Week 2:** Measure FedRAMP validation overhead in DEV + STG
- **Week 3:** Validate sovereign environment performance in STG-USGOV-01
- **Week 4:** Production commercial validation with real traffic
- **Week 5+:** Progressive rollout to PROD-USGOV (10% → 25% → 50% → 100%)

### Key Performance Thresholds

| Metric | Commercial Threshold | Sovereign Threshold |
|--------|---------------------|---------------------|
| Pipeline Overhead | < 20% | < 30% |
| Trivy Scan Duration | < 120s | < 180s |
| WAF Latency (P95) | < 25ms | < 40ms |
| Drift Detection | < 15s | < 20s |
| OPA Evaluation | < 10s | < 15s |

---

## Prerequisites

### Required Access

- [ ] GitHub repository access with write permissions
- [ ] GitHub CLI (`gh`) authenticated
- [ ] Kubernetes cluster access (kubectl configured for all environments)
- [ ] ArgoCD access with deployment permissions
- [ ] Prometheus read access for all environments
- [ ] VPN access to sovereign environments (STG-USGOV-01, PROD-USGOV)

### Required Tools

```powershell
# Verify tool installation
gh --version          # GitHub CLI
kubectl version       # Kubernetes CLI
helm version          # Helm package manager
trivy --version       # Vulnerability scanner
conftest --version    # OPA policy testing
argocd version        # ArgoCD CLI
```

### Repository Setup

```powershell
# Clone repository
git clone https://github.com/your-org/your-repo.git
cd your-repo

# Verify measurement scripts are present
Get-ChildItem scripts\fedramp-baseline -Recurse
```

---

## Week 1: DEV Baseline

### Objective
Establish baseline performance metrics without FedRAMP validation.

### Execution Steps

#### Step 1: Environment Preparation

```powershell
# Set environment context
$env:ENVIRONMENT = "dev"
$env:PROMETHEUS_URL = "http://prometheus-dev.monitoring.svc:9090"

# Verify DEV environment is accessible
kubectl config use-context dev-cluster
kubectl get nodes
```

#### Step 2: Baseline Pipeline Measurement

```powershell
# Run baseline pipeline (without FedRAMP validation)
# Execute 10 times for statistical significance
1..10 | ForEach-Object {
    Write-Host "Run $_/10..."
    gh workflow run build-and-test.yml --ref main
    Start-Sleep -Seconds 60  # Wait between runs
}

# Wait for all workflows to complete
gh run list --workflow=build-and-test.yml --limit 10

# Collect timing data
gh run list --workflow=build-and-test.yml --json conclusion,startedAt,updatedAt --limit 10 > baseline-runs.json
```

#### Step 3: Component Benchmarks

```powershell
# Run Trivy benchmark
Write-Host "Benchmarking Trivy scans..."
Measure-Command {
    trivy image --severity CRITICAL,HIGH --format json nginx:1.25.3
} | Select-Object TotalSeconds

# Run Helm benchmark (if charts exist)
if (Test-Path "charts") {
    Write-Host "Benchmarking Helm rendering..."
    Measure-Command {
        helm template ./charts/* --output-dir ./temp-helm-output
    } | Select-Object TotalSeconds
    Remove-Item -Recurse -Force ./temp-helm-output
}

# Run OPA benchmark (if policies exist)
if (Test-Path "tests\fedramp-validation\opa-policies") {
    Write-Host "Benchmarking OPA evaluation..."
    Measure-Command {
        conftest test --policy tests\fedramp-validation\opa-policies\ tests\fedramp-validation\test-manifests\*.yaml
    } | Select-Object TotalSeconds
}
```

#### Step 4: Automated Collection

```powershell
# Run automated baseline collection script
.\scripts\fedramp-baseline\measurement\collect-baseline-metrics.ps1 `
    -Week 1 `
    -Environment dev `
    -OutputDir ".\baseline-results\week1-dev"

# Verify output files
Get-ChildItem .\baseline-results\week1-dev\
```

#### Step 5: Prometheus Metrics

```powershell
# Execute Prometheus queries
.\scripts\fedramp-baseline\measurement\execute-prometheus-queries.ps1 `
    -Environment dev `
    -PrometheusUrl "http://prometheus-dev.monitoring.svc:9090" `
    -OutputDir ".\baseline-results\week1-dev"
```

### Week 1 Deliverables

- [ ] `baseline-results/week1-dev/github-workflow-metrics.json`
- [ ] `baseline-results/week1-dev/prometheus-results-dev.json`
- [ ] `baseline-results/week1-dev/component-benchmarks.json`
- [ ] `baseline-results/week1-dev/COLLECTION-SUMMARY.md`
- [ ] Week 1 checklist completed: `docs/fedramp/execution/week1-checklist.md`

### Success Criteria

- ✅ Minimum 10 sample runs collected
- ✅ All metrics captured successfully
- ✅ Baseline thresholds documented
- ✅ No pipeline failures during measurement

---

## Week 2: FedRAMP Overhead Measurement

### Objective
Measure FedRAMP validation overhead in DEV and STG environments.

### Execution Steps

#### Step 1: Deploy FedRAMP Validation

```powershell
# Switch to FedRAMP validation branch
git fetch origin
git checkout squad/72-fedramp-cicd

# Verify FedRAMP workflow exists
Get-Content .github\workflows\fedramp-validation.yml

# Deploy to DEV
kubectl config use-context dev-cluster
kubectl apply -f manifests/fedramp-validation/
```

#### Step 2: Run Pipeline with FedRAMP

```powershell
# Run 10 times with FedRAMP validation enabled
1..10 | ForEach-Object {
    Write-Host "FedRAMP Run $_/10..."
    gh workflow run build-and-test.yml --ref squad/72-fedramp-cicd
    Start-Sleep -Seconds 60
}

# Collect FedRAMP run data
gh run list --workflow=build-and-test.yml --json conclusion,startedAt,updatedAt --limit 10 > fedramp-runs.json
```

#### Step 3: Calculate Overhead

```powershell
# Load baseline and FedRAMP results
$baseline = Get-Content baseline-runs.json | ConvertFrom-Json
$fedramp = Get-Content fedramp-runs.json | ConvertFrom-Json

# Calculate average durations
$baselineAvg = ($baseline | ForEach-Object {
    (New-TimeSpan -Start $_.startedAt -End $_.updatedAt).TotalSeconds
} | Measure-Object -Average).Average

$fedrampAvg = ($fedramp | ForEach-Object {
    (New-TimeSpan -Start $_.startedAt -End $_.updatedAt).TotalSeconds
} | Measure-Object -Average).Average

# Calculate overhead percentage
$overhead = (($fedrampAvg - $baselineAvg) / $baselineAvg) * 100

Write-Host "Baseline Average: $baselineAvg seconds"
Write-Host "FedRAMP Average: $fedrampAvg seconds"
Write-Host "Overhead: $([math]::Round($overhead, 2))%"

# Validate against threshold
if ($overhead -lt 20) {
    Write-Host "✅ Overhead within commercial threshold (<20%)" -ForegroundColor Green
} else {
    Write-Host "❌ Overhead exceeds threshold: $overhead%" -ForegroundColor Red
}
```

#### Step 4: STG Environment Validation

```powershell
# Deploy to STG
kubectl config use-context stg-cluster
kubectl apply -f manifests/fedramp-validation/

# Run collection script for STG
.\scripts\fedramp-baseline\measurement\collect-baseline-metrics.ps1 `
    -Week 2 `
    -Environment stg `
    -OutputDir ".\baseline-results\week2-stg"
```

### Week 2 Deliverables

- [ ] FedRAMP overhead calculation for DEV
- [ ] FedRAMP overhead calculation for STG
- [ ] Component-level overhead breakdown
- [ ] Optimization recommendations (if overhead > 20%)
- [ ] Week 2 checklist completed

### Success Criteria

- ✅ Overhead < 20% in commercial environments
- ✅ All component benchmarks within thresholds
- ✅ Go/No-Go decision documented

---

## Week 3: Sovereign Staging

### Objective
Measure performance in sovereign staging environment (STG-USGOV-01).

### Execution Steps

#### Step 1: Sovereign Environment Access

```powershell
# Connect to sovereign VPN
# (Follow organization-specific VPN procedures)

# Switch to sovereign cluster context
kubectl config use-context stg-usgov-01-cluster

# Verify connectivity
kubectl get nodes
kubectl get namespaces

# Test Prometheus access
$sovereignPrometheusUrl = "http://prometheus-sovereign.monitoring.svc:9090"
Invoke-RestMethod -Uri "$sovereignPrometheusUrl/-/healthy"
```

#### Step 2: Sovereign-Specific Configuration

```powershell
# Deploy Trivy database pre-caching
kubectl apply -f manifests/sovereign/trivy-database-cache.yaml

# Verify init container is running
kubectl get pods -n fedramp-validation -l component=trivy-cache

# Deploy Helm repository mirrors
kubectl apply -f manifests/sovereign/helm-repository-mirror.yaml

# Configure sovereign container registry
kubectl create secret docker-registry sovereign-registry-creds `
    --docker-server=registry.sovereign.example.gov `
    --docker-username=$env:SOVEREIGN_REGISTRY_USER `
    --docker-password=$env:SOVEREIGN_REGISTRY_PASSWORD `
    -n fedramp-validation
```

#### Step 3: Network Latency Baseline

```powershell
# Measure Git operation latency
Measure-Command {
    git clone https://github.com/your-org/your-repo.git test-clone
} | Select-Object TotalSeconds
Remove-Item -Recurse -Force test-clone

# Measure container image pull latency
Measure-Command {
    docker pull registry.sovereign.example.gov/nginx:1.25.3
} | Select-Object TotalSeconds

# Measure Trivy database download
Measure-Command {
    trivy image --download-db-only
} | Select-Object TotalSeconds
```

#### Step 4: Sovereign Baseline Collection

```powershell
# Run collection script for sovereign staging
.\scripts\fedramp-baseline\measurement\collect-baseline-metrics.ps1 `
    -Week 3 `
    -Environment stg-usgov-01 `
    -OutputDir ".\baseline-results\week3-sovereign"

# Execute Prometheus queries
.\scripts\fedramp-baseline\measurement\execute-prometheus-queries.ps1 `
    -Environment stg-usgov-01 `
    -PrometheusUrl $sovereignPrometheusUrl `
    -OutputDir ".\baseline-results\week3-sovereign"
```

#### Step 5: Generate Comparison Report

```powershell
# Compare commercial STG with sovereign STG
.\scripts\fedramp-baseline\measurement\compare-baselines.ps1 `
    -CommercialResults ".\baseline-results\week2-stg\prometheus-results-stg.json" `
    -SovereignResults ".\baseline-results\week3-sovereign\prometheus-results-stg-usgov-01.json" `
    -OutputFile ".\baseline-results\week3-comparison-report.md"

# Review comparison report
Get-Content .\baseline-results\week3-comparison-report.md
```

### Week 3 Deliverables

- [ ] Sovereign performance metrics collected
- [ ] Network latency baseline documented
- [ ] Commercial vs. Sovereign comparison report
- [ ] Mitigation strategy effectiveness validated
- [ ] Go/No-Go decision for production

### Success Criteria

- ✅ Sovereign overhead < 30%
- ✅ All metrics within sovereign thresholds
- ✅ Network mitigation strategies effective
- ✅ Rollback plan tested

---

## Week 4: Production Validation

### Objective
Validate FedRAMP controls in production commercial environment with real traffic.

### Execution Steps

#### Step 1: Production Deployment Planning

```powershell
# Create change management ticket
# Document:
# - Deployment window
# - Rollback plan
# - Communication plan
# - Go/No-Go criteria

# Verify production access
kubectl config use-context prod-cluster
kubectl get nodes

# Review production Prometheus
$prodPrometheusUrl = "http://prometheus-prod.monitoring.svc:9090"
Invoke-RestMethod -Uri "$prodPrometheusUrl/-/healthy"
```

#### Step 2: Production Deployment

```powershell
# Deploy FedRAMP validation to production
kubectl config use-context prod-cluster
kubectl apply -f manifests/fedramp-validation/production/

# Verify deployment
kubectl get deployments -n fedramp-validation
kubectl get pods -n fedramp-validation

# Test with sample PR
gh pr create --title "Test: FedRAMP validation" --body "Production test PR"
```

#### Step 3: Continuous Monitoring (7 days)

```powershell
# Monitor production for 7 days
# Check metrics every 6 hours

$days = 1..7
foreach ($day in $days) {
    Write-Host "Day $day monitoring..."
    
    # Collect daily metrics
    .\scripts\fedramp-baseline\measurement\execute-prometheus-queries.ps1 `
        -Environment prod `
        -PrometheusUrl $prodPrometheusUrl `
        -OutputDir ".\baseline-results\week4-prod\day$day"
    
    Start-Sleep -Seconds 21600  # 6 hours
}
```

#### Step 4: Weekly Analysis

```powershell
# Generate 7-day summary
.\scripts\fedramp-baseline\measurement\collect-baseline-metrics.ps1 `
    -Week 4 `
    -Environment prod `
    -OutputDir ".\baseline-results\week4-prod-summary"

# Analyze error rate
# Calculate from Prometheus
$errorRateQuery = @"
sum(rate(http_requests_total{environment="prod",status=~"5.."}[7d]))
/
sum(rate(http_requests_total{environment="prod"}[7d]))
* 100
"@

# Execute query and validate < 1%
```

### Week 4 Deliverables

- [ ] Production deployment successful
- [ ] 7-day monitoring data collected
- [ ] Error rate < 1% validated
- [ ] User feedback collected
- [ ] Go/No-Go decision for sovereign rollout

### Success Criteria

- ✅ No critical incidents
- ✅ All metrics within thresholds
- ✅ Error rate < 1%
- ✅ User satisfaction positive/neutral

---

## Week 5+: Progressive Rollout

### Objective
Progressive rollout to PROD-USGOV: 10% → 25% → 50% → 100%

### Stage 1: 10% Traffic (Days 1-3)

```powershell
# Deploy canary configuration (10% traffic)
kubectl config use-context prod-usgov-cluster

# Apply Stage 1 traffic split
kubectl apply -f scripts\fedramp-baseline\progressive-rollout-config.yaml

# Verify traffic split
kubectl get virtualservice fedramp-validation-traffic-split-10 -n fedramp-validation -o yaml

# Monitor ArgoCD rollout
argocd app sync fedramp-validation-prod-usgov
argocd app get fedramp-validation-prod-usgov --watch

# Monitor metrics for 3 days
1..3 | ForEach-Object {
    $day = $_
    Write-Host "Stage 1 - Day $day monitoring..."
    
    .\scripts\fedramp-baseline\measurement\collect-baseline-metrics.ps1 `
        -Week 5 `
        -Environment prod-usgov `
        -OutputDir ".\baseline-results\week5-stage1\day$day"
    
    Start-Sleep -Seconds 86400  # 24 hours
}

# Go/No-Go decision for Stage 2
# Criteria:
# - Error rate < 1%
# - Performance within thresholds
# - No critical alerts
```

### Stage 2: 25% Traffic (Days 4-6)

```powershell
# Update traffic split to 25%
kubectl apply -f scripts\fedramp-baseline\progressive-rollout-config.yaml

# Update rollout to Stage 2
kubectl argo rollouts set-weight fedramp-validation-rollout 25 -n fedramp-validation

# Monitor for 3 days
# Repeat monitoring process from Stage 1
```

### Stage 3: 50% Traffic (Week 6, Days 1-3)

```powershell
# Update traffic split to 50%
kubectl apply -f scripts\fedramp-baseline\progressive-rollout-config.yaml

# Update rollout to Stage 3
kubectl argo rollouts set-weight fedramp-validation-rollout 50 -n fedramp-validation

# Monitor for 3 days
```

### Stage 4: 100% Traffic (Week 6, Days 4-7)

```powershell
# Complete rollout to 100%
kubectl apply -f scripts\fedramp-baseline\progressive-rollout-config.yaml

# Update rollout to Stage 4
kubectl argo rollouts promote fedramp-validation-rollout -n fedramp-validation

# Monitor for 4+ days
# Generate final comparison report

.\scripts\fedramp-baseline\measurement\compare-baselines.ps1 `
    -CommercialResults ".\baseline-results\week4-prod\prometheus-results-prod.json" `
    -SovereignResults ".\baseline-results\week5-stage4\prometheus-results-prod-usgov.json" `
    -OutputFile ".\baseline-results\FINAL-COMPARISON-REPORT.md"
```

---

## Troubleshooting

### Issue: Pipeline Overhead > 20%

**Symptoms:**
- FedRAMP validation adds > 20% to pipeline duration
- Threshold breach alerts firing

**Resolution:**
1. Enable parallel job execution
2. Implement conditional checks (security files only)
3. Add Trivy database caching
4. Optimize OPA policy complexity

```powershell
# Check which component is slowest
Get-Content .\baseline-results\*\component-benchmarks.json

# If Trivy is slow:
kubectl apply -f manifests/sovereign/trivy-database-cache.yaml

# If drift detection is slow:
# Implement conditional execution in GitHub Actions
```

### Issue: Trivy Scan Timeout

**Symptoms:**
- Trivy scans exceed 180 seconds
- Database download failures in sovereign

**Resolution:**

```powershell
# Enable database pre-caching
kubectl apply -f manifests/sovereign/trivy-database-cache.yaml

# Verify cache is working
kubectl logs -n fedramp-validation -l component=trivy-cache --tail=50

# Manual database pre-load
kubectl exec -it <trivy-pod> -n fedramp-validation -- trivy image --download-db-only
```

### Issue: WAF Latency High

**Symptoms:**
- P95 latency > 40ms
- User reports slow response times

**Resolution:**

```powershell
# Check WAF rule complexity
kubectl get configmap waf-rules -n fedramp-validation -o yaml

# Optimize WAF rules
# Remove redundant rules
# Enable rule caching

# Monitor after optimization
.\scripts\fedramp-baseline\measurement\execute-prometheus-queries.ps1 -Environment prod-usgov
```

### Issue: Network Latency in Sovereign

**Symptoms:**
- Git operations slow (> 45s)
- Container pulls timing out

**Resolution:**

```powershell
# Check VPN connectivity
Test-NetConnection -ComputerName registry.sovereign.example.gov -Port 443

# Verify local mirrors are configured
kubectl get services -n infrastructure | Select-String mirror

# Test registry pull directly
docker pull registry.sovereign.example.gov/nginx:1.25.3
```

---

## Rollback Procedures

### Rollback Triggers

- Error rate > 5% for 15 minutes
- Critical security incident
- Performance degradation > 50%
- Resource exhaustion (CPU/Memory > 95%)

### Rollback Execution

```powershell
# Immediate rollback to previous stage
kubectl argo rollouts abort fedramp-validation-rollout -n fedramp-validation
kubectl argo rollouts undo fedramp-validation-rollout -n fedramp-validation

# Or rollback via ArgoCD
argocd app rollback fedramp-validation-prod-usgov <previous-revision>

# Verify rollback
kubectl get pods -n fedramp-validation
argocd app get fedramp-validation-prod-usgov

# Monitor for stabilization (30 minutes)
kubectl argo rollouts get rollout fedramp-validation-rollout -n fedramp-validation --watch
```

### Post-Rollback

1. Document rollback reason
2. Analyze root cause
3. Develop remediation plan
4. Update runbook with learnings
5. Schedule re-attempt

---

## Monitoring & Alerting

### Key Dashboards

**Prometheus Dashboards:**
- FedRAMP Pipeline Performance: `http://prometheus:9090/dashboard/fedramp-pipeline`
- Component Benchmarks: `http://prometheus:9090/dashboard/fedramp-components`
- Progressive Rollout: `http://prometheus:9090/dashboard/fedramp-rollout`

**Grafana Dashboards:**
- FedRAMP Overview: `http://grafana:3000/d/fedramp-overview`
- Sovereign vs. Commercial: `http://grafana:3000/d/fedramp-comparison`

### Alert Channels

- **Slack:** `#fedramp-alerts`
- **Email:** fedramp-team@example.com
- **PagerDuty:** FedRAMP On-Call rotation

### Alert Response

**Critical Alerts (Immediate Response):**
- `FedRAMPValidationFailed` - Control validation failure
- `ProgressiveRolloutErrorRateIncreased` - Error spike during rollout
- `TrivyDatabaseUpdateFailed` - Vulnerability database issue

**Warning Alerts (Review within 1 hour):**
- `FedRAMPValidationSlow` - Performance degradation
- `FedRAMPPipelineOverhead` - Overhead threshold breach
- `CIRunnerHighCPU` - Resource constraints

---

## Appendix

### Useful Commands

```powershell
# Check rollout status
kubectl argo rollouts get rollout fedramp-validation-rollout -n fedramp-validation

# View rollout history
kubectl argo rollouts history fedramp-validation-rollout -n fedramp-validation

# Pause rollout
kubectl argo rollouts pause fedramp-validation-rollout -n fedramp-validation

# Resume rollout
kubectl argo rollouts resume fedramp-validation-rollout -n fedramp-validation

# Get ArgoCD app status
argocd app get fedramp-validation-prod-usgov

# View ArgoCD app logs
argocd app logs fedramp-validation-prod-usgov --tail 100

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090/targets
```

### Contact Information

- **Infrastructure Lead:** infrastructure-lead@example.com
- **Security Lead:** security-lead@example.com
- **FedRAMP Compliance:** fedramp-compliance@example.com
- **On-Call:** Use PagerDuty escalation policy

---

**Last Updated:** 2026-03-08  
**Issue:** #89  
**Owner:** B'Elanna (Infrastructure Expert)
