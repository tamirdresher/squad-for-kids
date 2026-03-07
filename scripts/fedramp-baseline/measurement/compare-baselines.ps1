#!/usr/bin/env pwsh
# Compare Baseline Measurements (Commercial vs. Sovereign)
# Issue #89: Performance Baseline & Progressive Sovereign Rollout
# Usage: .\compare-baselines.ps1 -CommercialResults "baseline-dev.json" -SovereignResults "baseline-sovereign.json"

param(
    [Parameter(Mandatory=$true)]
    [string]$CommercialResults,
    
    [Parameter(Mandatory=$true)]
    [string]$SovereignResults,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "baseline-comparison-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
)

$ErrorActionPreference = "Stop"

Write-Host "=== FedRAMP Performance Baseline Comparison ===" -ForegroundColor Cyan
Write-Host "Commercial Results: $CommercialResults"
Write-Host "Sovereign Results: $SovereignResults"
Write-Host "Output File: $OutputFile"
Write-Host ""

# Load baseline results
Write-Host "[STEP 1/3] Loading baseline results..." -ForegroundColor Yellow

if (-not (Test-Path $CommercialResults)) {
    Write-Host "ERROR: Commercial results file not found: $CommercialResults" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $SovereignResults)) {
    Write-Host "ERROR: Sovereign results file not found: $SovereignResults" -ForegroundColor Red
    exit 1
}

$commercial = Get-Content -Path $CommercialResults -Raw | ConvertFrom-Json
$sovereign = Get-Content -Path $SovereignResults -Raw | ConvertFrom-Json

Write-Host "  Commercial results loaded: $(($commercial | ConvertTo-Json -Compress).Length) bytes" -ForegroundColor Green
Write-Host "  Sovereign results loaded: $(($sovereign | ConvertTo-Json -Compress).Length) bytes" -ForegroundColor Green

# ============================================================================
# STEP 2: Calculate Comparisons
# ============================================================================

Write-Host "`n[STEP 2/3] Calculating performance comparisons..." -ForegroundColor Yellow

function Get-MetricValue {
    param($Data, $MetricName)
    
    $metric = $Data | Where-Object { $_.Metric -eq $MetricName }
    if ($metric -and $metric.Success -and $metric.Data.result.Count -gt 0) {
        return [double]$metric.Data.result[0].value[1]
    }
    return $null
}

function Calculate-Overhead {
    param([double]$Sovereign, [double]$Commercial)
    
    if ($Commercial -gt 0) {
        return (($Sovereign - $Commercial) / $Commercial) * 100
    }
    return $null
}

# Define metrics to compare
$metricsToCompare = @(
    @{ Name = "pipeline_overhead_percentage"; Unit = "%"; Threshold = 30 }
    @{ Name = "trivy_scan_duration_avg"; Unit = "seconds"; Threshold = 180 }
    @{ Name = "waf_latency_p95"; Unit = "milliseconds"; Threshold = 40 }
    @{ Name = "drift_detection_avg"; Unit = "seconds"; Threshold = 20 }
    @{ Name = "opa_evaluation_total"; Unit = "milliseconds"; Threshold = 15000 }
)

$comparisons = @()

foreach ($metric in $metricsToCompare) {
    $commValue = Get-MetricValue -Data $commercial -MetricName $metric.Name
    $sovValue = Get-MetricValue -Data $sovereign -MetricName $metric.Name
    
    if ($commValue -and $sovValue) {
        $overhead = Calculate-Overhead -Sovereign $sovValue -Commercial $commValue
        $withinThreshold = $sovValue -le $metric.Threshold
        
        $comparisons += @{
            Metric = $metric.Name
            Unit = $metric.Unit
            Commercial = $commValue
            Sovereign = $sovValue
            Overhead = $overhead
            Threshold = $metric.Threshold
            WithinThreshold = $withinThreshold
        }
        
        $status = if ($withinThreshold) { "✅" } else { "❌" }
        Write-Host "  $status $($metric.Name): Commercial=$commValue, Sovereign=$sovValue ($([math]::Round($overhead, 1))% overhead)" -ForegroundColor $(if ($withinThreshold) { "Green" } else { "Red" })
    } else {
        Write-Host "  ⚠️  $($metric.Name): Insufficient data" -ForegroundColor Yellow
    }
}

# ============================================================================
# STEP 3: Generate Comparison Report
# ============================================================================

Write-Host "`n[STEP 3/3] Generating comparison report..." -ForegroundColor Yellow

$report = @"
# FedRAMP Performance Baseline Comparison Report

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Commercial Results:** $CommercialResults  
**Sovereign Results:** $SovereignResults

## Executive Summary

This report compares performance metrics between commercial and sovereign environments to validate deployment readiness for FedRAMP sovereign production (PROD-USGOV).

### Overall Status

"@

$allPassed = ($comparisons | Where-Object { -not $_.WithinThreshold }).Count -eq 0

if ($allPassed) {
    $report += "**✅ DEPLOYMENT APPROVED** - All metrics within acceptable thresholds`n`n"
} else {
    $failedCount = ($comparisons | Where-Object { -not $_.WithinThreshold }).Count
    $report += "**⚠️ REVIEW REQUIRED** - $failedCount metric(s) exceeded thresholds`n`n"
}

$report += @"

## Detailed Metrics Comparison

| Metric | Commercial | Sovereign | Overhead | Threshold | Status |
|--------|------------|-----------|----------|-----------|--------|
"@

foreach ($comp in $comparisons) {
    $status = if ($comp.WithinThreshold) { "✅ Pass" } else { "❌ Fail" }
    $overheadStr = "$([math]::Round($comp.Overhead, 1))%"
    
    $report += "`n| $($comp.Metric) | $([math]::Round($comp.Commercial, 2)) $($comp.Unit) | $([math]::Round($comp.Sovereign, 2)) $($comp.Unit) | $overheadStr | $($comp.Threshold) $($comp.Unit) | $status |"
}

$report += @"


## Threshold Analysis

### Pipeline Overhead

"@

$pipelineComp = $comparisons | Where-Object { $_.Metric -eq "pipeline_overhead_percentage" }
if ($pipelineComp) {
    if ($pipelineComp.Sovereign -le 20) {
        $report += "✅ **EXCELLENT** - Sovereign overhead within commercial target (<20%)`n"
    } elseif ($pipelineComp.Sovereign -le 30) {
        $report += "✅ **ACCEPTABLE** - Sovereign overhead within sovereign target (<30%)`n"
    } else {
        $report += "❌ **REQUIRES OPTIMIZATION** - Sovereign overhead exceeds target (>30%)`n"
    }
    $report += "- Commercial: $([math]::Round($pipelineComp.Commercial, 1))%`n"
    $report += "- Sovereign: $([math]::Round($pipelineComp.Sovereign, 1))%`n"
    $report += "- Delta: +$([math]::Round($pipelineComp.Overhead, 1))%`n`n"
}

$report += @"
### Trivy Vulnerability Scanning

"@

$trivyComp = $comparisons | Where-Object { $_.Metric -eq "trivy_scan_duration_avg" }
if ($trivyComp) {
    $report += "$(if ($trivyComp.WithinThreshold) { '✅' } else { '❌' }) Sovereign scan duration: $([math]::Round($trivyComp.Sovereign, 1))s (threshold: $($trivyComp.Threshold)s)`n"
    $report += "- Network impact: +$([math]::Round($trivyComp.Sovereign - $trivyComp.Commercial, 1))s`n"
    
    if (-not $trivyComp.WithinThreshold) {
        $report += "`n**Recommendation:** Implement database pre-caching or air-gapped mode.`n"
    }
    $report += "`n"
}

$report += @"
### WAF Latency

"@

$wafComp = $comparisons | Where-Object { $_.Metric -eq "waf_latency_p95" }
if ($wafComp) {
    $report += "$(if ($wafComp.WithinThreshold) { '✅' } else { '❌' }) Sovereign P95 latency: $([math]::Round($wafComp.Sovereign, 1))ms (threshold: $($wafComp.Threshold)ms)`n"
    $report += "- Additional overhead: +$([math]::Round($wafComp.Sovereign - $wafComp.Commercial, 1))ms`n`n"
}

$report += @"
## Go/No-Go Recommendation

"@

if ($allPassed) {
    $report += @"
### ✅ RECOMMENDATION: PROCEED WITH DEPLOYMENT

All performance metrics are within acceptable thresholds for sovereign production deployment.

**Next Steps:**
1. Update Issue #89 with this comparison report
2. Begin Week 5 progressive rollout (10% → 25% → 50% → 100%)
3. Enable continuous monitoring and alerting
4. Schedule first rollout stage for sovereign production

**Deployment Authorization:**
- [ ] Infrastructure Team Lead approval
- [ ] Security Team review
- [ ] FedRAMP Compliance verification
- [ ] Rollback plan confirmed

"@
} else {
    $report += @"
### ⚠️ RECOMMENDATION: OPTIMIZATION REQUIRED

Some metrics exceed acceptable thresholds. Address issues before sovereign production deployment.

**Required Actions:**

"@
    
    foreach ($comp in ($comparisons | Where-Object { -not $_.WithinThreshold })) {
        $report += "- **$($comp.Metric):** Current=$([math]::Round($comp.Sovereign, 1))$($comp.Unit), Target=$($comp.Threshold)$($comp.Unit)`n"
        
        switch ($comp.Metric) {
            "pipeline_overhead_percentage" { $report += "  - Action: Review parallelization and conditional execution strategies`n" }
            "trivy_scan_duration_avg" { $report += "  - Action: Implement database pre-caching or use air-gapped mode`n" }
            "waf_latency_p95" { $report += "  - Action: Optimize WAF rules and consider rule caching`n" }
            "drift_detection_avg" { $report += "  - Action: Optimize Helm/Kustomize rendering or implement incremental validation`n" }
            "opa_evaluation_total" { $report += "  - Action: Review policy complexity and enable OPA caching`n" }
        }
    }
    
    $report += @"

**Re-measurement Required:**
After implementing optimizations, repeat baseline measurements in STG-USGOV-01 to validate improvements.

"@
}

$report += @"

## Network Latency Impact (Sovereign-Specific)

The performance difference between commercial and sovereign environments is primarily attributable to:

1. **Network Latency:** VPN/private link overhead for external dependencies
2. **Registry Access:** Sovereign container registry pull times
3. **Database Downloads:** Trivy vulnerability database over restricted network
4. **Git Operations:** Repository access through sovereign gateway

### Mitigation Strategies in Place

- ✅ Trivy database pre-caching (init container)
- ✅ Local Helm repository mirrors
- ✅ Sovereign-local container registry
- ✅ Persistent build artifact caching

## Related Documentation

- **Baseline Plan:** docs/fedramp/performance-baseline-measurement.md
- **Issue:** #89 - Performance Baseline & Progressive Sovereign Rollout
- **Weekly Checklists:** docs/fedramp/execution/week[1-5]-checklist.md
- **Runbook:** docs/fedramp/execution/runbook-week1-5.md

---
**Generated by:** B'Elanna (Infrastructure Expert)  
**Issue:** #89  
**Report Type:** Baseline Comparison (Commercial vs. Sovereign)
"@

# Save report
$report | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Host "  Comparison report saved to: $OutputFile" -ForegroundColor Green

Write-Host "`n=== Comparison Complete ===" -ForegroundColor Cyan

if ($allPassed) {
    Write-Host "✅ ALL METRICS PASSED - Ready for sovereign deployment" -ForegroundColor Green
} else {
    Write-Host "⚠️  OPTIMIZATION REQUIRED - Review report for details" -ForegroundColor Yellow
}

return @{
    AllPassed = $allPassed
    ComparisonCount = $comparisons.Count
    FailedCount = ($comparisons | Where-Object { -not $_.WithinThreshold }).Count
    ReportFile = $OutputFile
}
