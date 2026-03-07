param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'stg', 'prod')]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$true)]
    [string]$LogAnalyticsWorkspaceId,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory=$true)]
    [string]$CosmosDbConnectionString
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Phase 4: Alerting & Integrations" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Retrieve secrets from Key Vault
Write-Host "[1/4] Retrieving secrets from Key Vault: $KeyVaultName" -ForegroundColor Yellow
try {
    $pagerDutyKey = az keyvault secret show --vault-name $KeyVaultName --name "PagerDutyRoutingKey" --query value -o tsv
    $teamsWebhookCritical = az keyvault secret show --vault-name $KeyVaultName --name "TeamsWebhookUrl-Critical" --query value -o tsv
    $teamsWebhookMedium = az keyvault secret show --vault-name $KeyVaultName --name "TeamsWebhookUrl-Medium" --query value -o tsv
    $teamsWebhookLow = az keyvault secret show --vault-name $KeyVaultName --name "TeamsWebhookUrl-Low" --query value -o tsv
    
    Write-Host "  ✓ Secrets retrieved successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to retrieve secrets from Key Vault: $_"
    exit 1
}

Write-Host ""

# Deploy infrastructure
Write-Host "[2/4] Deploying infrastructure (Bicep)..." -ForegroundColor Yellow
Write-Host "  - Redis Cache (Basic C0)" -ForegroundColor Gray
Write-Host "  - Function App (Consumption plan)" -ForegroundColor Gray
Write-Host "  - Application Insights" -ForegroundColor Gray
Write-Host "  - Alert Rules (3 scheduled queries)" -ForegroundColor Gray
Write-Host "  - Action Group" -ForegroundColor Gray
Write-Host ""

try {
    $deploymentOutput = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file "./phase4-alerting.bicep" `
        --parameters `
            environment=$Environment `
            location=$Location `
            logAnalyticsWorkspaceId=$LogAnalyticsWorkspaceId `
            cosmosDbConnectionString=$CosmosDbConnectionString `
            pagerDutyRoutingKey=$pagerDutyKey `
            teamsWebhookUrlCritical=$teamsWebhookCritical `
            teamsWebhookUrlMedium=$teamsWebhookMedium `
            teamsWebhookUrlLow=$teamsWebhookLow `
        --query properties.outputs `
        -o json | ConvertFrom-Json
    
    Write-Host "  ✓ Infrastructure deployed successfully" -ForegroundColor Green
} catch {
    Write-Error "Infrastructure deployment failed: $_"
    exit 1
}

$functionAppName = $deploymentOutput.functionAppName.value
$functionAppUrl = $deploymentOutput.functionAppUrl.value
$redisCacheName = $deploymentOutput.redisCacheName.value

Write-Host ""
Write-Host "  Deployed Resources:" -ForegroundColor Cyan
Write-Host "    - Function App: $functionAppName" -ForegroundColor Gray
Write-Host "    - Redis Cache: $redisCacheName" -ForegroundColor Gray
Write-Host "    - URL: $functionAppUrl" -ForegroundColor Gray
Write-Host ""

# Build and publish function code
Write-Host "[3/4] Building and publishing function code..." -ForegroundColor Yellow

try {
    # Build
    Write-Host "  Building..." -ForegroundColor Gray
    dotnet build ..\functions\FedRampDashboard.Functions.csproj --configuration Release --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) { throw "Build failed" }
    
    # Publish
    Write-Host "  Publishing..." -ForegroundColor Gray
    dotnet publish ..\functions\FedRampDashboard.Functions.csproj --configuration Release --output .\publish --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) { throw "Publish failed" }
    
    # Create ZIP
    Write-Host "  Creating deployment package..." -ForegroundColor Gray
    if (Test-Path .\functions.zip) { Remove-Item .\functions.zip -Force }
    Compress-Archive -Path .\publish\* -DestinationPath .\functions.zip -Force
    
    # Deploy ZIP
    Write-Host "  Deploying to Azure..." -ForegroundColor Gray
    az functionapp deployment source config-zip `
        --resource-group $ResourceGroupName `
        --name $functionAppName `
        --src .\functions.zip `
        --output none
    
    if ($LASTEXITCODE -ne 0) { throw "Deployment failed" }
    
    # Clean up
    Remove-Item .\publish -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item .\functions.zip -Force -ErrorAction SilentlyContinue
    
    Write-Host "  ✓ Function code deployed successfully" -ForegroundColor Green
} catch {
    Write-Error "Function deployment failed: $_"
    exit 1
}

Write-Host ""

# Validation
Write-Host "[4/4] Validating deployment..." -ForegroundColor Yellow

try {
    # Check function app status
    Write-Host "  Checking function app status..." -ForegroundColor Gray
    $appState = az functionapp show --name $functionAppName --resource-group $ResourceGroupName --query state -o tsv
    
    if ($appState -eq "Running") {
        Write-Host "  ✓ Function app is running" -ForegroundColor Green
    } else {
        Write-Warning "  Function app state: $appState (expected: Running)"
    }
    
    # Check Redis cache status
    Write-Host "  Checking Redis cache status..." -ForegroundColor Gray
    $redisStatus = az redis show --name $redisCacheName --resource-group $ResourceGroupName --query provisioningState -o tsv
    
    if ($redisStatus -eq "Succeeded") {
        Write-Host "  ✓ Redis cache provisioned successfully" -ForegroundColor Green
    } else {
        Write-Warning "  Redis cache status: $redisStatus (expected: Succeeded)"
    }
    
} catch {
    Write-Warning "Validation checks failed: $_"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Phase 4 Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Test alert flow: ..\tests\test-alert-flow.sh" -ForegroundColor Gray
Write-Host "  2. Configure PagerDuty escalation policies" -ForegroundColor Gray
Write-Host "  3. Test Teams Adaptive Card rendering" -ForegroundColor Gray
Write-Host "  4. Review Application Insights dashboards" -ForegroundColor Gray
Write-Host ""
Write-Host "Resources:" -ForegroundColor Yellow
Write-Host "  Function App URL: $functionAppUrl" -ForegroundColor Cyan
Write-Host "  Documentation: docs\fedramp-dashboard-phase4-alerting.md" -ForegroundColor Cyan
Write-Host ""
