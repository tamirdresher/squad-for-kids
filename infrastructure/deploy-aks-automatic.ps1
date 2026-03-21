# Deploy AKS Automatic cluster for Squad
# Usage: .\deploy-aks-automatic.ps1 [-Environment dev] [-Location eastus]

param(
    [string]$Environment = "dev",
    [string]$Location = "eastus"
)

$ErrorActionPreference = "Stop"

$ResourceGroup = "squad-aks-$Environment-rg"
$DeploymentName = "squad-aks-automatic-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "🚀 Deploying AKS Automatic cluster for Squad" -ForegroundColor Cyan
Write-Host "Environment: $Environment"
Write-Host "Location: $Location"
Write-Host "Resource Group: $ResourceGroup"
Write-Host ""

# Check if logged in to Azure
try {
    $null = az account show 2>$null
} catch {
    Write-Host "❌ Not logged in to Azure. Run 'az login' first." -ForegroundColor Red
    exit 1
}

# Create resource group if it doesn't exist
Write-Host "📦 Creating resource group..." -ForegroundColor Yellow
az group create `
    --name $ResourceGroup `
    --location $Location `
    --tags "Project=Squad" "Environment=$Environment" "ManagedBy=Bicep"

# Deploy Bicep template
Write-Host "🔨 Deploying infrastructure..." -ForegroundColor Yellow
az deployment group create `
    --name $DeploymentName `
    --resource-group $ResourceGroup `
    --template-file ./aks-automatic-squad.bicep `
    --parameters environment=$Environment location=$Location `
    --verbose

# Get outputs
Write-Host ""
Write-Host "✅ Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Outputs:" -ForegroundColor Cyan

$AksName = az deployment group show -g $ResourceGroup -n $DeploymentName --query properties.outputs.aksClusterName.value -o tsv
$AcrName = az deployment group show -g $ResourceGroup -n $DeploymentName --query properties.outputs.acrName.value -o tsv
$AcrServer = az deployment group show -g $ResourceGroup -n $DeploymentName --query properties.outputs.acrLoginServer.value -o tsv

Write-Host "AKS Cluster Name: $AksName"
Write-Host "ACR Name: $AcrName"
Write-Host "ACR Login Server: $AcrServer"
Write-Host ""

# Get cluster credentials
Write-Host "🔑 Getting cluster credentials..." -ForegroundColor Yellow
az aks get-credentials `
    --resource-group $ResourceGroup `
    --name $AksName `
    --overwrite-existing

Write-Host ""
Write-Host "🎉 Setup complete! You can now use kubectl to interact with the cluster." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Verify cluster: kubectl get nodes"
Write-Host "  2. Check KEDA installation: kubectl get pods -n kube-system | grep keda"
Write-Host "  3. Deploy Squad workloads: kubectl apply -f k8s/"
Write-Host "  4. Build and push images: az acr build -t squad-monitor:latest -r $AcrName ."
