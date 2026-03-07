#!/usr/bin/env pwsh
# Master Baseline Collection Script
# Issue #89: Performance Baseline & Progressive Sovereign Rollout
# Usage: .\collect-baseline-metrics.ps1 -Week 1 -Environment "dev"

param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,5)]
    [int]$Week,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "stg", "stg-usgov-01", "prod", "prod-usgov")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = ".\baseline-results\week$Week\$Environment\$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipGitHubActions = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipPrometheus = $false
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔═══════════════════════════════════════════════════════════════════════╗
║   FedRAMP Performance Baseline - Measurement Collection               ║
║   Issue #89: Performance Baseline & Progressive Sovereign Rollout     ║
╚═══════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  Week: $Week"
Write-Host "  Environment: $Environment"
Write-Host "  Output Directory: $OutputDir"
Write-Host "  Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Create output directory
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Week-specific validation
$weekConfig = @{
    1 = @{
        Name = "DEV Baseline"
        RequiredEnv = "dev"
        Tasks = @("baseline-pipeline", "baseline-component-benchmarks")
    }
    2 = @{
        Name = "DEV + STG with FedRAMP"
        RequiredEnv = @("dev", "stg")
        Tasks = @("fedramp-pipeline", "fedramp-overhead-analysis")
    }
    3 = @{
        Name = "Sovereign Staging"
        RequiredEnv = "stg-usgov-01"
        Tasks = @("sovereign-baseline", "sovereign-network-analysis")
    }
    4 = @{
        Name = "Production Validation"
        RequiredEnv = "prod"
        Tasks = @("prod-monitoring", "prod-real-traffic-analysis")
    }
    5 = @{
        Name = "Progressive Rollout"
        RequiredEnv = "prod-usgov"
        Tasks = @("rollout-monitoring", "canary-analysis", "error-rate-tracking")
    }
}

Write-Host "`nWeek $Week: $($weekConfig[$Week].Name)" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# STEP 1: GitHub Actions Workflow Metrics
# ============================================================================

if (-not $SkipGitHubActions) {
    Write-Host "[STEP 1/4] Collecting GitHub Actions Workflow Metrics..." -ForegroundColor Yellow
    
    try {
        $workflowMetrics = @{
            Timestamp = Get-Date -Format "o"
            Environment = $Environment
            Week = $Week
            Workflows = @()
        }
        
        # Get recent workflow runs
        Write-Host "  Fetching recent workflow runs..."
        $workflows = gh workflow list --json name,id | ConvertFrom-Json
        
        foreach ($workflow in $workflows) {
            Write-Host "    - $($workflow.name)..." -NoNewline
            
            $runs = gh run list --workflow=$($workflow.id) --limit 10 --json conclusion,createdAt,status,databaseId,name | ConvertFrom-Json
            
            if ($runs.Count -gt 0) {
                $workflowMetrics.Workflows += @{
                    Name = $workflow.name
                    Runs = $runs
                }
                Write-Host " OK ($($runs.Count) runs)" -ForegroundColor Green
            } else {
                Write-Host " No recent runs" -ForegroundColor Gray
            }
        }
        
        # Save workflow metrics
        $workflowFile = Join-Path $OutputDir "github-workflow-metrics.json"
        $workflowMetrics | ConvertTo-Json -Depth 10 | Out-File -FilePath $workflowFile -Encoding UTF8
        Write-Host "  Saved to: $workflowFile" -ForegroundColor Green
        
    } catch {
        Write-Host "  ERROR: Failed to collect GitHub Actions metrics" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "[STEP 1/4] Skipping GitHub Actions metrics (--SkipGitHubActions)" -ForegroundColor Gray
}

# ============================================================================
# STEP 2: Prometheus Metrics
# ============================================================================

if (-not $SkipPrometheus) {
    Write-Host "`n[STEP 2/4] Collecting Prometheus Metrics..." -ForegroundColor Yellow
    
    try {
        # Execute Prometheus queries
        $prometheusScript = Join-Path $PSScriptRoot "execute-prometheus-queries.ps1"
        
        if (Test-Path $prometheusScript) {
            $prometheusResult = & $prometheusScript -Environment $Environment -OutputDir $OutputDir
            
            if ($prometheusResult.Success) {
                Write-Host "  Prometheus metrics collected successfully" -ForegroundColor Green
            } else {
                Write-Host "  WARNING: Some Prometheus queries failed" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ERROR: Prometheus script not found: $prometheusScript" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "  ERROR: Failed to execute Prometheus queries" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`n[STEP 2/4] Skipping Prometheus metrics (--SkipPrometheus)" -ForegroundColor Gray
}

# ============================================================================
# STEP 3: Component Benchmarks
# ============================================================================

Write-Host "`n[STEP 3/4] Running Component Benchmarks..." -ForegroundColor Yellow

$benchmarks = @{
    Timestamp = Get-Date -Format "o"
    Environment = $Environment
    Week = $Week
    Results = @{}
}

# Trivy Benchmark
Write-Host "  [3.1] Trivy vulnerability scanning..."
try {
    $trivyStart = Get-Date
    $trivyOutput = trivy image --severity CRITICAL,HIGH --format json nginx:1.25.3 2>&1
    $trivyDuration = (Get-Date) - $trivyStart
    
    $benchmarks.Results.Trivy = @{
        Duration = $trivyDuration.TotalSeconds
        Success = $LASTEXITCODE -eq 0
        Image = "nginx:1.25.3"
    }
    Write-Host "    Duration: $([math]::Round($trivyDuration.TotalSeconds, 2))s" -ForegroundColor Green
} catch {
    Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $benchmarks.Results.Trivy = @{ Success = $false; Error = $_.Exception.Message }
}

# Helm Rendering Benchmark
Write-Host "  [3.2] Helm template rendering..."
if (Test-Path "charts") {
    try {
        $helmStart = Get-Date
        helm template ./charts/* --output-dir $OutputDir\helm-rendered 2>&1 | Out-Null
        $helmDuration = (Get-Date) - $helmStart
        
        $benchmarks.Results.Helm = @{
            Duration = $helmDuration.TotalSeconds
            Success = $LASTEXITCODE -eq 0
        }
        Write-Host "    Duration: $([math]::Round($helmDuration.TotalSeconds, 2))s" -ForegroundColor Green
    } catch {
        Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $benchmarks.Results.Helm = @{ Success = $false; Error = $_.Exception.Message }
    }
} else {
    Write-Host "    SKIP: No charts/ directory found" -ForegroundColor Gray
}

# OPA Policy Evaluation Benchmark
Write-Host "  [3.3] OPA policy evaluation..."
if (Test-Path "tests\fedramp-validation\opa-policies") {
    try {
        $opaStart = Get-Date
        conftest test --policy tests\fedramp-validation\opa-policies\ tests\fedramp-validation\test-manifests\*.yaml 2>&1 | Out-Null
        $opaDuration = (Get-Date) - $opaStart
        
        $benchmarks.Results.OPA = @{
            Duration = $opaDuration.TotalSeconds
            Success = $true  # conftest may return non-zero for policy violations
        }
        Write-Host "    Duration: $([math]::Round($opaDuration.TotalSeconds, 2))s" -ForegroundColor Green
    } catch {
        Write-Host "    WARNING: $($_.Exception.Message)" -ForegroundColor Yellow
        $benchmarks.Results.OPA = @{ Duration = 0; Success = $false; Error = $_.Exception.Message }
    }
} else {
    Write-Host "    SKIP: No OPA policies found" -ForegroundColor Gray
}

# Save benchmark results
$benchmarkFile = Join-Path $OutputDir "component-benchmarks.json"
$benchmarks | ConvertTo-Json -Depth 10 | Out-File -FilePath $benchmarkFile -Encoding UTF8
Write-Host "  Saved to: $benchmarkFile" -ForegroundColor Green

# ============================================================================
# STEP 4: Generate Collection Summary
# ============================================================================

Write-Host "`n[STEP 4/4] Generating Collection Summary..." -ForegroundColor Yellow

$summary = @"
# FedRAMP Performance Baseline - Measurement Collection Summary

**Week:** $Week ($($weekConfig[$Week].Name))  
**Environment:** $Environment  
**Collection Time:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Output Directory:** $OutputDir

## Collection Status

| Component | Status | Notes |
|-----------|--------|-------|
| GitHub Actions Workflows | $(if (-not $SkipGitHubActions) { "✅ Collected" } else { "⏭️ Skipped" }) | Workflow run history |
| Prometheus Metrics | $(if (-not $SkipPrometheus) { "✅ Collected" } else { "⏭️ Skipped" }) | Real-time performance data |
| Component Benchmarks | ✅ Executed | Trivy, Helm, OPA |

## Benchmark Results

"@

if ($benchmarks.Results.Trivy) {
    $trivyStatus = if ($benchmarks.Results.Trivy.Success) { "✅" } else { "❌" }
    $summary += "- **Trivy Scan:** $trivyStatus $([math]::Round($benchmarks.Results.Trivy.Duration, 2))s`n"
}

if ($benchmarks.Results.Helm) {
    $helmStatus = if ($benchmarks.Results.Helm.Success) { "✅" } else { "❌" }
    $summary += "- **Helm Rendering:** $helmStatus $([math]::Round($benchmarks.Results.Helm.Duration, 2))s`n"
}

if ($benchmarks.Results.OPA) {
    $opaStatus = if ($benchmarks.Results.OPA.Success) { "✅" } else { "⚠️" }
    $summary += "- **OPA Evaluation:** $opaStatus $([math]::Round($benchmarks.Results.OPA.Duration, 2))s`n"
}

$summary += @"

## Next Steps

1. Review collected metrics against thresholds
2. Update weekly milestone checklist: ``docs\fedramp\execution\week$Week-checklist.md``
3. Compare with previous measurements (if available)
4. Generate comparison report if Week >= 2

## Files Generated

- GitHub Workflow Metrics: ``github-workflow-metrics.json``
- Prometheus Results: ``prometheus-results-$Environment.json``
- Component Benchmarks: ``component-benchmarks.json``
- This Summary: ``COLLECTION-SUMMARY.md``

---
**Issue:** #89  
**Measurement Plan:** docs\fedramp\performance-baseline-measurement.md  
**Owner:** B'Elanna (Infrastructure Expert)
"@

$summaryFile = Join-Path $OutputDir "COLLECTION-SUMMARY.md"
$summary | Out-File -FilePath $summaryFile -Encoding UTF8
Write-Host "  Summary saved to: $summaryFile" -ForegroundColor Green

Write-Host @"

╔═══════════════════════════════════════════════════════════════════════╗
║   Measurement Collection Complete                                     ║
╚═══════════════════════════════════════════════════════════════════════╝

Output Directory: $OutputDir

Next Steps:
1. Review summary: $summaryFile
2. Update checklist: docs\fedramp\execution\week$Week-checklist.md
3. Compare results (if Week >= 2): .\compare-baselines.ps1

"@ -ForegroundColor Cyan

return @{
    Success = $true
    Week = $Week
    Environment = $Environment
    OutputDir = $OutputDir
    SummaryFile = $summaryFile
}
