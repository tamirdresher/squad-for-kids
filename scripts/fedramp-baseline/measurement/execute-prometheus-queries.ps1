#!/usr/bin/env pwsh
# Execute Prometheus Queries for Baseline Measurement
# Issue #89: Performance Baseline & Progressive Sovereign Rollout
# Usage: .\execute-prometheus-queries.ps1 -Environment "dev" -OutputDir "C:\temp\baseline-results"

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "stg", "stg-usgov-01", "prod", "prod-usgov")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$PrometheusUrl = "http://prometheus.monitoring.svc.cluster.local:9090",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = ".\baseline-results\$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    
    [Parameter(Mandatory=$false)]
    [int]$TimeRangeHours = 1
)

$ErrorActionPreference = "Stop"

Write-Host "=== FedRAMP Performance Baseline - Prometheus Query Execution ===" -ForegroundColor Cyan
Write-Host "Environment: $Environment"
Write-Host "Prometheus URL: $PrometheusUrl"
Write-Host "Output Directory: $OutputDir"
Write-Host "Time Range: Last $TimeRangeHours hour(s)"
Write-Host ""

# Create output directory
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Load query templates
$queriesYaml = Get-Content -Path "scripts\fedramp-baseline\prometheus\baseline-queries.yaml" -Raw
Write-Host "[INFO] Loaded query templates from baseline-queries.yaml" -ForegroundColor Green

# Function to execute Prometheus query
function Invoke-PrometheusQuery {
    param(
        [string]$Query,
        [string]$MetricName,
        [string]$PrometheusUrl
    )
    
    try {
        $encodedQuery = [System.Web.HttpUtility]::UrlEncode($Query)
        $url = "$PrometheusUrl/api/v1/query?query=$encodedQuery"
        
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        
        if ($response.status -eq "success") {
            return @{
                Success = $true
                Metric = $MetricName
                Data = $response.data
                Timestamp = Get-Date -Format "o"
            }
        } else {
            return @{
                Success = $false
                Metric = $MetricName
                Error = $response.error
            }
        }
    } catch {
        return @{
            Success = $false
            Metric = $MetricName
            Error = $_.Exception.Message
        }
    }
}

# Critical queries to execute
$criticalQueries = @{
    "pipeline_overhead_percentage" = @"
(
  avg_over_time(github_workflow_run_duration_seconds{fedramp_enabled="true"}[1h])
  -
  avg_over_time(github_workflow_run_duration_seconds{fedramp_enabled="false"}[1h])
) / avg_over_time(github_workflow_run_duration_seconds{fedramp_enabled="false"}[1h]) * 100
"@
    "trivy_scan_duration_avg" = @"
avg_over_time(trivy_scan_duration_seconds{job="fedramp-validation"}[1h])
"@
    "waf_latency_p95" = @"
histogram_quantile(0.95,
  rate(waf_request_duration_milliseconds_bucket{job="fedramp-waf"}[5m])
)
"@
    "drift_detection_avg" = @"
avg_over_time(drift_detection_duration_seconds{job="fedramp-validation"}[1h])
"@
    "opa_evaluation_total" = @"
sum(opa_eval_duration_milliseconds{job="fedramp-validation"})
"@
}

# Execute queries and collect results
$results = @()
$successCount = 0
$failureCount = 0

Write-Host "`n[STEP 1/3] Executing Prometheus queries..." -ForegroundColor Yellow

foreach ($queryName in $criticalQueries.Keys) {
    Write-Host "  Querying: $queryName..." -NoNewline
    
    $result = Invoke-PrometheusQuery -Query $criticalQueries[$queryName] -MetricName $queryName -PrometheusUrl $PrometheusUrl
    $results += $result
    
    if ($result.Success) {
        Write-Host " OK" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "    Error: $($result.Error)" -ForegroundColor Red
        $failureCount++
    }
}

Write-Host "`n[STEP 2/3] Saving results..." -ForegroundColor Yellow

# Save results to JSON
$resultsFile = Join-Path $OutputDir "prometheus-results-$Environment.json"
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsFile -Encoding UTF8
Write-Host "  Results saved to: $resultsFile" -ForegroundColor Green

# Generate summary report
$summaryFile = Join-Path $OutputDir "summary-$Environment.md"
$summaryContent = @"
# FedRAMP Performance Baseline - Prometheus Metrics Summary

**Environment:** $Environment  
**Timestamp:** $(Get-Date -Format "o")  
**Prometheus URL:** $PrometheusUrl  
**Time Range:** Last $TimeRangeHours hour(s)

## Query Execution Summary

- Total Queries: $($criticalQueries.Count)
- Successful: $successCount
- Failed: $failureCount

## Metric Results

"@

foreach ($result in $results) {
    if ($result.Success) {
        $value = "N/A"
        if ($result.Data.result.Count -gt 0) {
            $value = $result.Data.result[0].value[1]
        }
        
        $summaryContent += @"

### $($result.Metric)
- **Status:** ✅ Success
- **Value:** $value
- **Timestamp:** $($result.Timestamp)

"@
    } else {
        $summaryContent += @"

### $($result.Metric)
- **Status:** ❌ Failed
- **Error:** $($result.Error)

"@
    }
}

$summaryContent += @"

## Next Steps

1. Review metric values against thresholds in baseline-queries.yaml
2. Compare results with previous baseline measurements
3. Generate comparison report using: ``.\compare-baselines.ps1``
4. Update weekly milestone checklist

## Related Files

- **Full Results:** $resultsFile
- **Query Templates:** scripts\fedramp-baseline\prometheus\baseline-queries.yaml
- **Comparison Report:** Run .\compare-baselines.ps1 to generate

---
**Issue:** #89  
**Owner:** B'Elanna (Infrastructure Expert)
"@

$summaryContent | Out-File -FilePath $summaryFile -Encoding UTF8
Write-Host "  Summary saved to: $summaryFile" -ForegroundColor Green

Write-Host "`n[STEP 3/3] Execution Complete" -ForegroundColor Yellow
Write-Host "  Success Rate: $successCount/$($criticalQueries.Count) ($([math]::Round($successCount/$criticalQueries.Count*100, 1))%)" -ForegroundColor $(if ($failureCount -eq 0) { "Green" } else { "Yellow" })

if ($failureCount -gt 0) {
    Write-Host "`n[WARNING] Some queries failed. Check Prometheus connectivity and metric availability." -ForegroundColor Yellow
}

Write-Host "`n=== Execution Complete ===" -ForegroundColor Cyan
Write-Host "Output Directory: $OutputDir" -ForegroundColor Cyan

# Return results for pipeline integration
return @{
    Success = ($failureCount -eq 0)
    SuccessCount = $successCount
    FailureCount = $failureCount
    OutputDir = $OutputDir
    ResultsFile = $resultsFile
    SummaryFile = $summaryFile
}
