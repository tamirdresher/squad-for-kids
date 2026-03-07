# FedRAMP Dashboard Phase 1: Azure Deployment Script
# Deploys infrastructure and configures resources

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'stg', 'prod')]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = 'eastus2',
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('public', 'government')]
    [string]$CloudType = 'public',
    
    [Parameter(Mandatory=$false)]
    [int]$CosmosDbThroughput = 1000,
    
    [Parameter(Mandatory=$false)]
    [int]$LogAnalyticsRetentionDays = 90,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableCosmosReservedCapacity
)

$ErrorActionPreference = 'Stop'

# Configuration
$ResourceGroupName = "fedramp-dashboard-phase1-$Environment-rg"
$DeploymentName = "fedramp-phase1-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$BicepFile = Join-Path $PSScriptRoot 'phase1-data-pipeline.bicep'

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "FedRAMP Dashboard Phase 1 Deployment" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "Cloud Type: $CloudType" -ForegroundColor Yellow
Write-Host ""

# Verify Azure CLI is logged in
Write-Host "[1/7] Verifying Azure CLI authentication..." -ForegroundColor Green
$account = az account show 2>&1 | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not logged into Azure CLI. Run 'az login' first."
    exit 1
}
Write-Host "✓ Logged in as: $($account.user.name)" -ForegroundColor Green
Write-Host "✓ Subscription: $($account.name) ($($account.id))" -ForegroundColor Green
Write-Host ""

# Create resource group
Write-Host "[2/7] Creating resource group '$ResourceGroupName'..." -ForegroundColor Green
az group create `
    --name $ResourceGroupName `
    --location $Location `
    --tags "Project=FedRAMP-Dashboard" "Phase=Phase1" "Environment=$Environment" | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create resource group"
    exit 1
}
Write-Host "✓ Resource group created" -ForegroundColor Green
Write-Host ""

# Deploy Bicep template
Write-Host "[3/7] Deploying infrastructure (this may take 5-10 minutes)..." -ForegroundColor Green
$deploymentOutput = az deployment group create `
    --resource-group $ResourceGroupName `
    --name $DeploymentName `
    --template-file $BicepFile `
    --parameters environment=$Environment `
                 location=$Location `
                 cloudType=$CloudType `
                 cosmosDbThroughput=$CosmosDbThroughput `
                 logAnalyticsRetentionDays=$LogAnalyticsRetentionDays `
                 enableCosmosReservedCapacity=$EnableCosmosReservedCapacity.IsPresent `
    --query 'properties.outputs' `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed"
    exit 1
}

$outputs = @{
    LogAnalyticsWorkspaceId = $deploymentOutput.logAnalyticsWorkspaceId.value
    LogAnalyticsWorkspaceName = $deploymentOutput.logAnalyticsWorkspaceName.value
    CosmosDbEndpoint = $deploymentOutput.cosmosDbEndpoint.value
    CosmosDbAccountName = $deploymentOutput.cosmosDbAccountName.value
    StorageAccountName = $deploymentOutput.storageAccountName.value
    FunctionAppName = $deploymentOutput.functionAppName.value
    FunctionAppPrincipalId = $deploymentOutput.functionAppPrincipalId.value
    KeyVaultName = $deploymentOutput.keyVaultName.value
    AppInsightsConnectionString = $deploymentOutput.appInsightsConnectionString.value
}

Write-Host "✓ Infrastructure deployed successfully" -ForegroundColor Green
Write-Host ""

# Display outputs
Write-Host "[4/7] Deployment Outputs:" -ForegroundColor Green
Write-Host "  Log Analytics Workspace: $($outputs.LogAnalyticsWorkspaceName)" -ForegroundColor Yellow
Write-Host "  Cosmos DB Account: $($outputs.CosmosDbAccountName)" -ForegroundColor Yellow
Write-Host "  Storage Account: $($outputs.StorageAccountName)" -ForegroundColor Yellow
Write-Host "  Function App: $($outputs.FunctionAppName)" -ForegroundColor Yellow
Write-Host "  Key Vault: $($outputs.KeyVaultName)" -ForegroundColor Yellow
Write-Host ""

# Configure Azure Monitor Data Collection Rule (DCR)
Write-Host "[5/7] Configuring Azure Monitor Data Collection Rule..." -ForegroundColor Green
# Note: DCR configuration requires az monitor CLI extension
$dcrName = "fedramp-validation-results-dcr-$Environment"

# Create DCR JSON
$dcrConfig = @{
    location = $Location
    properties = @{
        dataFlows = @(
            @{
                streams = @('Custom-ControlValidationResults_CL')
                destinations = @($outputs.LogAnalyticsWorkspaceName)
            }
        )
        destinations = @{
            logAnalytics = @(
                @{
                    workspaceResourceId = "/subscriptions/$($account.id)/resourceGroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$($outputs.LogAnalyticsWorkspaceName)"
                    name = $outputs.LogAnalyticsWorkspaceName
                }
            )
        }
    }
} | ConvertTo-Json -Depth 10

Write-Host "✓ DCR configuration prepared" -ForegroundColor Green
Write-Host "  Note: Apply DCR manually via Azure Portal or REST API" -ForegroundColor Yellow
Write-Host ""

# Create KQL alert rules
Write-Host "[6/7] Creating Log Analytics alert rules..." -ForegroundColor Green

$alertRules = @(
    @{
        name = "fedramp-control-failure-$Environment"
        description = "Alert when P0 FedRAMP control fails"
        severity = 1
        query = @"
ControlValidationResults_CL
| where TimeGenerated > ago(15m)
| where Status_s == "FAIL"
| where ControlId_s in ("SC-7", "SC-8", "SI-2", "SI-3")
| summarize fail_count = count() by ControlId_s, Environment_s, bin(TimeGenerated, 15m)
| where fail_count > 0
"@
    }
    @{
        name = "fedramp-ingestion-lag-$Environment"
        description = "Alert when data ingestion is delayed > 15 minutes"
        severity = 2
        query = @"
ControlValidationResults_CL
| summarize max_time = max(TimeGenerated)
| extend lag_minutes = datetime_diff('minute', now(), max_time)
| where lag_minutes > 15
"@
    }
)

foreach ($rule in $alertRules) {
    Write-Host "  Creating alert: $($rule.name)..." -ForegroundColor Yellow
    # Note: Alert rule creation requires az monitor CLI commands
    # Placeholder for actual alert creation
}

Write-Host "✓ Alert rules prepared (apply manually)" -ForegroundColor Green
Write-Host ""

# Save configuration for pipelines
Write-Host "[7/7] Saving configuration..." -ForegroundColor Green

$config = @{
    Environment = $Environment
    ResourceGroup = $ResourceGroupName
    DeploymentDate = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Outputs = $outputs
} | ConvertTo-Json -Depth 5

$configFile = Join-Path $PSScriptRoot "..\config\phase1-$Environment.json"
New-Item -ItemType Directory -Path (Split-Path $configFile) -Force | Out-Null
$config | Out-File -FilePath $configFile -Encoding UTF8

Write-Host "✓ Configuration saved to: $configFile" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Deploy Azure Functions code: " -ForegroundColor White -NoNewline
Write-Host "cd functions && func azure functionapp publish $($outputs.FunctionAppName)" -ForegroundColor Cyan
Write-Host "2. Update Azure DevOps pipeline variables with outputs" -ForegroundColor White
Write-Host "3. Run validation tests: " -ForegroundColor White -NoNewline
Write-Host "cd tests/fedramp-validation && ./network-policy-tests.sh" -ForegroundColor Cyan
Write-Host "4. Verify data in Log Analytics: " -ForegroundColor White -NoNewline
Write-Host "az monitor log-analytics query ..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration file: $configFile" -ForegroundColor Green
Write-Host ""
