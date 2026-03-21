#!/bin/bash
# Deploy AKS Automatic cluster for Squad
# Usage: ./deploy-aks-automatic.sh [environment] [location]

set -e

ENVIRONMENT=${1:-dev}
LOCATION=${2:-eastus}
RESOURCE_GROUP="squad-aks-${ENVIRONMENT}-rg"
DEPLOYMENT_NAME="squad-aks-automatic-$(date +%Y%m%d-%H%M%S)"

echo "🚀 Deploying AKS Automatic cluster for Squad"
echo "Environment: $ENVIRONMENT"
echo "Location: $LOCATION"
echo "Resource Group: $RESOURCE_GROUP"
echo ""

# Check if logged in to Azure
if ! az account show &>/dev/null; then
    echo "❌ Not logged in to Azure. Run 'az login' first."
    exit 1
fi

# Create resource group if it doesn't exist
echo "📦 Creating resource group..."
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags "Project=Squad" "Environment=$ENVIRONMENT" "ManagedBy=Bicep"

# Deploy Bicep template
echo "🔨 Deploying infrastructure..."
az deployment group create \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file ./aks-automatic-squad.bicep \
    --parameters environment="$ENVIRONMENT" location="$LOCATION" \
    --verbose

# Get outputs
echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Outputs:"
AKS_NAME=$(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" --query properties.outputs.aksClusterName.value -o tsv)
ACR_NAME=$(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" --query properties.outputs.acrName.value -o tsv)
ACR_SERVER=$(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" --query properties.outputs.acrLoginServer.value -o tsv)

echo "AKS Cluster Name: $AKS_NAME"
echo "ACR Name: $ACR_NAME"
echo "ACR Login Server: $ACR_SERVER"
echo ""

# Get cluster credentials
echo "🔑 Getting cluster credentials..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_NAME" \
    --overwrite-existing

echo ""
echo "🎉 Setup complete! You can now use kubectl to interact with the cluster."
echo ""
echo "Next steps:"
echo "  1. Verify cluster: kubectl get nodes"
echo "  2. Check KEDA installation: kubectl get pods -n kube-system | grep keda"
echo "  3. Deploy Squad workloads: kubectl apply -f k8s/"
echo "  4. Build and push images: az acr build -t squad-monitor:latest -r $ACR_NAME ."
