# Deploy FedRAMP Dashboard Cache Hit Rate Alert
# Issue #106 - Post-merge monitoring for PR #102
# Owner: Data (Code Expert)

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'stg', 'stg-gov', 'ppe', 'prod')]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-fedramp-dashboard-$Environment",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId
)

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "FedRAMP Cache Alert Deployment" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow

# Set subscription if provided
if ($SubscriptionId) {
    Write-Host "`nSetting subscription: $SubscriptionId" -ForegroundColor Green
    az account set --subscription $SubscriptionId
}

# Get current subscription
$currentSub = (az account show | ConvertFrom-Json).name
Write-Host "Active subscription: $currentSub" -ForegroundColor Green

# Define environment-specific parameters
$appInsightsName = "appi-fedramp-dashboard-$Environment"
$actionGroupName = "fedramp-oncall-$Environment"

# Get Action Group resource ID
Write-Host "`nRetrieving Action Group resource ID..." -ForegroundColor Yellow
$actionGroupId = az monitor action-group show `
    --resource-group $ResourceGroupName `
    --name $actionGroupName `
    --query id `
    --output tsv

if (-not $actionGroupId) {
    Write-Error "Action Group '$actionGroupName' not found in resource group '$ResourceGroupName'"
    exit 1
}

Write-Host "Action Group: $actionGroupName" -ForegroundColor Green
Write-Host "Resource ID: $actionGroupId" -ForegroundColor Gray

# Validate Bicep template
Write-Host "`nValidating Bicep template..." -ForegroundColor Yellow
az deployment group validate `
    --resource-group $ResourceGroupName `
    --template-file infrastructure/phase4-cache-alert.bicep `
    --parameters `
        appInsightsName=$appInsightsName `
        actionGroupId=$actionGroupId `
        environment=$Environment

if ($LASTEXITCODE -ne 0) {
    Write-Error "Bicep validation failed"
    exit 1
}

Write-Host "✓ Template validation passed" -ForegroundColor Green

# Deploy alert
Write-Host "`nDeploying cache hit rate alert..." -ForegroundColor Yellow
$deploymentName = "cache-alert-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

az deployment group create `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --template-file infrastructure/phase4-cache-alert.bicep `
    --parameters `
        appInsightsName=$appInsightsName `
        actionGroupId=$actionGroupId `
        environment=$Environment

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed"
    exit 1
}

Write-Host "`n✓ Alert deployed successfully!" -ForegroundColor Green

# Get deployment outputs
Write-Host "`nDeployment outputs:" -ForegroundColor Cyan
$outputs = az deployment group show `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --query properties.outputs `
    | ConvertFrom-Json

Write-Host "Alert Name: $($outputs.alertName.value)" -ForegroundColor Gray
Write-Host "Alert ID: $($outputs.alertId.value)" -ForegroundColor Gray

# Verify alert is enabled
Write-Host "`nVerifying alert status..." -ForegroundColor Yellow
$alertStatus = az monitor scheduled-query show `
    --resource-group $ResourceGroupName `
    --name $outputs.alertName.value `
    --query enabled `
    --output tsv

if ($alertStatus -eq "true") {
    Write-Host "✓ Alert is ENABLED and monitoring cache hit rate" -ForegroundColor Green
} else {
    Write-Warning "Alert exists but is DISABLED"
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Verify alert in Azure Portal: Monitor > Alerts > Alert Rules" -ForegroundColor White
Write-Host "2. Test alert by generating low cache hit rate traffic (optional)" -ForegroundColor White
Write-Host "3. Review SLI documentation: docs/fedramp-dashboard-cache-sli.md" -ForegroundColor White
Write-Host "4. Schedule 30-day cache review (first Tuesday of each month)" -ForegroundColor White
