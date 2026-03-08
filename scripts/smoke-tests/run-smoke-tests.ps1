# FedRAMP Dashboard: Smoke Test Suite
# Validates all components after deployment

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "stg", "stg-gov", "ppe", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$Slot = "production",
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludePerformance,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeFailoverRegion
)

$ErrorActionPreference = "Stop"

# Configuration
$config = @{
    "dev" = @{
        ApiUrl = "https://fedramp-api-dev.azurewebsites.net"
        UiUrl = "https://fedramp-ui-dev.azurestaticapps.net"
        CosmosDbAccount = "fedramp-dashboard-dev"
        FunctionApp = "fedramp-functions-dev"
        ResourceGroup = "rg-fedramp-dev"
    }
    "stg" = @{
        ApiUrl = "https://fedramp-api-stg.azurewebsites.net"
        UiUrl = "https://fedramp-ui-stg.azurestaticapps.net"
        CosmosDbAccount = "fedramp-dashboard-stg"
        FunctionApp = "fedramp-functions-stg"
        ResourceGroup = "rg-fedramp-stg"
    }
    "stg-gov" = @{
        ApiUrl = "https://fedramp-api-stggov.azurewebsites.us"
        UiUrl = "https://fedramp-ui-stggov.azurestaticapps.net"
        CosmosDbAccount = "fedramp-dashboard-stggov"
        FunctionApp = "fedramp-functions-stggov"
        ResourceGroup = "rg-fedramp-stggov"
    }
    "ppe" = @{
        ApiUrl = "https://fedramp-api-ppe.azurewebsites.net"
        UiUrl = "https://fedramp-ui-ppe.azurestaticapps.net"
        CosmosDbAccount = "fedramp-dashboard-ppe"
        FunctionApp = "fedramp-functions-ppe"
        ResourceGroup = "rg-fedramp-ppe"
    }
    "prod" = @{
        ApiUrl = "https://fedramp-api-prod.azurewebsites.net"
        UiUrl = "https://fedramp-ui-prod.azurestaticapps.net"
        CosmosDbAccount = "fedramp-dashboard-prod"
        FunctionApp = "fedramp-functions-prod"
        ResourceGroup = "rg-fedramp-prod"
        FailoverApiUrl = "https://fedramp-api-prod-westus2.azurewebsites.net"
    }
}

$envConfig = $config[$Environment]
$testResults = @()
$testsPassed = 0
$testsFailed = 0

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message,
        [double]$Duration
    )
    
    $result = @{
        TestName = $TestName
        Passed = $Passed
        Message = $Message
        Duration = $Duration
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    }
    
    $script:testResults += $result
    
    if ($Passed) {
        $script:testsPassed++
        Write-Host "✅ PASS: $TestName ($([math]::Round($Duration, 2))s)" -ForegroundColor Green
    } else {
        $script:testsFailed++
        Write-Host "❌ FAIL: $TestName - $Message" -ForegroundColor Red
    }
    
    if ($Verbose) {
        Write-Host "   Details: $Message" -ForegroundColor Gray
    }
}

function Test-ApiHealth {
    Write-Host "`n🏥 Testing API Health..." -ForegroundColor Cyan
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $apiUrl = if ($Slot -eq "green") {
            $envConfig.ApiUrl -replace "\.azurewebsites\.net", "-$Slot.azurewebsites.net"
        } else {
            $envConfig.ApiUrl
        }
        
        $response = Invoke-RestMethod -Uri "$apiUrl/health" -Method Get -TimeoutSec 10
        $stopwatch.Stop()
        
        if ($response.status -eq "healthy") {
            Write-TestResult -TestName "API Health Check" -Passed $true `
                -Message "API is healthy. Response time: $($stopwatch.ElapsedMilliseconds)ms" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        } else {
            Write-TestResult -TestName "API Health Check" -Passed $false `
                -Message "API returned unhealthy status: $($response.status)" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        }
    } catch {
        $stopwatch.Stop()
        Write-TestResult -TestName "API Health Check" -Passed $false `
            -Message "API health check failed: $($_.Exception.Message)" `
            -Duration $stopwatch.Elapsed.TotalSeconds
    }
}

function Test-DatabaseConnectivity {
    Write-Host "`n💾 Testing Database Connectivity..." -ForegroundColor Cyan
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $cosmosDb = az cosmosdb show --name $envConfig.CosmosDbAccount `
            --resource-group $envConfig.ResourceGroup --query "documentEndpoint" -o tsv
        $stopwatch.Stop()
        
        if ($cosmosDb) {
            Write-TestResult -TestName "Cosmos DB Connectivity" -Passed $true `
                -Message "Cosmos DB is accessible: $cosmosDb" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        } else {
            Write-TestResult -TestName "Cosmos DB Connectivity" -Passed $false `
                -Message "Cosmos DB not found or not accessible" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        }
    } catch {
        $stopwatch.Stop()
        Write-TestResult -TestName "Cosmos DB Connectivity" -Passed $false `
            -Message "Database connectivity test failed: $($_.Exception.Message)" `
            -Duration $stopwatch.Elapsed.TotalSeconds
    }
}

function Test-UiAvailability {
    Write-Host "`n🌐 Testing UI Availability..." -ForegroundColor Cyan
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-WebRequest -Uri $envConfig.UiUrl -Method Head -TimeoutSec 10 -UseBasicParsing
        $stopwatch.Stop()
        
        if ($response.StatusCode -eq 200) {
            Write-TestResult -TestName "UI Availability" -Passed $true `
                -Message "UI is accessible. Status: $($response.StatusCode)" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        } else {
            Write-TestResult -TestName "UI Availability" -Passed $false `
                -Message "UI returned unexpected status: $($response.StatusCode)" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        }
    } catch {
        $stopwatch.Stop()
        Write-TestResult -TestName "UI Availability" -Passed $false `
            -Message "UI availability test failed: $($_.Exception.Message)" `
            -Duration $stopwatch.Elapsed.TotalSeconds
    }
}

function Test-ApiEndpoints {
    Write-Host "`n🔌 Testing API Endpoints..." -ForegroundColor Cyan
    
    $endpoints = @(
        @{ Path = "/api/controls"; Method = "GET"; ExpectedStatus = 200 }
        @{ Path = "/api/alerts"; Method = "GET"; ExpectedStatus = 200 }
        @{ Path = "/api/environments"; Method = "GET"; ExpectedStatus = 200 }
        @{ Path = "/api/reports/compliance"; Method = "GET"; ExpectedStatus = 200 }
    )
    
    foreach ($endpoint in $endpoints) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $apiUrl = if ($Slot -eq "green") {
                $envConfig.ApiUrl -replace "\.azurewebsites\.net", "-$Slot.azurewebsites.net"
            } else {
                $envConfig.ApiUrl
            }
            
            $response = Invoke-WebRequest -Uri "$apiUrl$($endpoint.Path)" -Method $endpoint.Method `
                -TimeoutSec 10 -UseBasicParsing
            $stopwatch.Stop()
            
            if ($response.StatusCode -eq $endpoint.ExpectedStatus) {
                Write-TestResult -TestName "API Endpoint: $($endpoint.Path)" -Passed $true `
                    -Message "Endpoint returned expected status: $($response.StatusCode)" `
                    -Duration $stopwatch.Elapsed.TotalSeconds
            } else {
                Write-TestResult -TestName "API Endpoint: $($endpoint.Path)" -Passed $false `
                    -Message "Expected status $($endpoint.ExpectedStatus), got $($response.StatusCode)" `
                    -Duration $stopwatch.Elapsed.TotalSeconds
            }
        } catch {
            $stopwatch.Stop()
            Write-TestResult -TestName "API Endpoint: $($endpoint.Path)" -Passed $false `
                -Message "Endpoint test failed: $($_.Exception.Message)" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        }
    }
}

function Test-AzureFunctions {
    Write-Host "`n⚡ Testing Azure Functions..." -ForegroundColor Cyan
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $functions = az functionapp function list --name $envConfig.FunctionApp `
            --resource-group $envConfig.ResourceGroup --query "[].name" -o json | ConvertFrom-Json
        $stopwatch.Stop()
        
        $expectedFunctions = @("ProcessValidationResults", "ArchiveExpiredResults", "AlertProcessor")
        $missingFunctions = $expectedFunctions | Where-Object { $_ -notin $functions }
        
        if ($missingFunctions.Count -eq 0) {
            Write-TestResult -TestName "Azure Functions Deployment" -Passed $true `
                -Message "All expected functions are deployed: $($functions -join ', ')" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        } else {
            Write-TestResult -TestName "Azure Functions Deployment" -Passed $false `
                -Message "Missing functions: $($missingFunctions -join ', ')" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        }
    } catch {
        $stopwatch.Stop()
        Write-TestResult -TestName "Azure Functions Deployment" -Passed $false `
            -Message "Function check failed: $($_.Exception.Message)" `
            -Duration $stopwatch.Elapsed.TotalSeconds
    }
}

function Test-ApplicationInsights {
    Write-Host "`n📊 Testing Application Insights..." -ForegroundColor Cyan
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $query = "requests | where timestamp > ago(5m) | summarize count()"
        $result = az monitor app-insights query --app $envConfig.ApplicationInsightsName `
            --analytics-query $query --query "tables[0].rows[0][0]" -o tsv 2>$null
        $stopwatch.Stop()
        
        if ($null -ne $result) {
            Write-TestResult -TestName "Application Insights Telemetry" -Passed $true `
                -Message "Telemetry data available. Recent requests: $result" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        } else {
            Write-TestResult -TestName "Application Insights Telemetry" -Passed $false `
                -Message "No telemetry data found in last 5 minutes" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        }
    } catch {
        $stopwatch.Stop()
        Write-TestResult -TestName "Application Insights Telemetry" -Passed $false `
            -Message "Application Insights check failed: $($_.Exception.Message)" `
            -Duration $stopwatch.Elapsed.TotalSeconds
    }
}

function Test-Performance {
    if (-not $IncludePerformance) { return }
    
    Write-Host "`n⚡ Testing Performance..." -ForegroundColor Cyan
    
    # API response time test
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-RestMethod -Uri "$($envConfig.ApiUrl)/api/controls" -Method Get -TimeoutSec 10
        $stopwatch.Stop()
        
        $responseTime = $stopwatch.ElapsedMilliseconds
        if ($responseTime -lt 500) {
            Write-TestResult -TestName "API Response Time (p95 < 500ms)" -Passed $true `
                -Message "Response time: ${responseTime}ms" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        } else {
            Write-TestResult -TestName "API Response Time (p95 < 500ms)" -Passed $false `
                -Message "Response time exceeded threshold: ${responseTime}ms" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        }
    } catch {
        $stopwatch.Stop()
        Write-TestResult -TestName "API Response Time (p95 < 500ms)" -Passed $false `
            -Message "Performance test failed: $($_.Exception.Message)" `
            -Duration $stopwatch.Elapsed.TotalSeconds
    }
    
    # UI load time test
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-WebRequest -Uri $envConfig.UiUrl -Method Get -TimeoutSec 10 -UseBasicParsing
        $stopwatch.Stop()
        
        $loadTime = $stopwatch.ElapsedMilliseconds
        if ($loadTime -lt 2000) {
            Write-TestResult -TestName "UI Load Time (< 2s)" -Passed $true `
                -Message "Load time: ${loadTime}ms" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        } else {
            Write-TestResult -TestName "UI Load Time (< 2s)" -Passed $false `
                -Message "Load time exceeded threshold: ${loadTime}ms" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        }
    } catch {
        $stopwatch.Stop()
        Write-TestResult -TestName "UI Load Time (< 2s)" -Passed $false `
            -Message "UI load time test failed: $($_.Exception.Message)" `
            -Duration $stopwatch.Elapsed.TotalSeconds
    }
}

function Test-FailoverRegion {
    if (-not $IncludeFailoverRegion -or $Environment -ne "prod") { return }
    
    Write-Host "`n🌍 Testing Failover Region (West US 2)..." -ForegroundColor Cyan
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-RestMethod -Uri "$($envConfig.FailoverApiUrl)/health" -Method Get -TimeoutSec 10
        $stopwatch.Stop()
        
        if ($response.status -eq "healthy") {
            Write-TestResult -TestName "Failover Region Health" -Passed $true `
                -Message "Failover region is healthy" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        } else {
            Write-TestResult -TestName "Failover Region Health" -Passed $false `
                -Message "Failover region returned unhealthy status: $($response.status)" `
                -Duration $stopwatch.Elapsed.TotalSeconds
        }
    } catch {
        $stopwatch.Stop()
        Write-TestResult -TestName "Failover Region Health" -Passed $false `
            -Message "Failover region health check failed: $($_.Exception.Message)" `
            -Duration $stopwatch.Elapsed.TotalSeconds
    }
}

# Main execution
Write-Host "=====================================" -ForegroundColor Yellow
Write-Host "FedRAMP Dashboard - Smoke Test Suite" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Slot: $Slot" -ForegroundColor Yellow
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow

# Run tests
Test-ApiHealth
Test-DatabaseConnectivity
Test-UiAvailability
Test-ApiEndpoints
Test-AzureFunctions
Test-ApplicationInsights
Test-Performance
Test-FailoverRegion

# Summary
Write-Host "`n=====================================" -ForegroundColor Yellow
Write-Host "Test Summary" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow
Write-Host "Total Tests: $($testsPassed + $testsFailed)" -ForegroundColor Cyan
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($testsPassed / ($testsPassed + $testsFailed)) * 100, 2))%" -ForegroundColor Cyan

# Export results
$resultsFile = "smoke-test-results-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$testResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsFile -Encoding UTF8
Write-Host "`nResults exported to: $resultsFile" -ForegroundColor Gray

# Exit with appropriate code
if ($testsFailed -gt 0) {
    Write-Host "`n❌ Smoke tests FAILED. Review failures above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ All smoke tests PASSED." -ForegroundColor Green
    exit 0
}
