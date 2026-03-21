# AKS Automatic Cluster for Squad Deployment

This directory contains Infrastructure as Code (Bicep) for provisioning an Azure Kubernetes Service (AKS) cluster in **Automatic mode** for Squad AI system deployment.

## Overview

AKS Automatic is a managed Kubernetes mode that provides:
- **Built-in KEDA** (Kubernetes Event-Driven Autoscaling) - no manual installation needed
- **Automatic node autoscaling** with intelligent defaults
- **Optimized security** with Azure RBAC, Azure Policy, and hardened defaults
- **Simplified operations** with reduced configuration overhead

## Architecture

### Components

1. **AKS Cluster (`squad-aks-{env}-{suffix}`)**
   - SKU: `Automatic` with `Standard` tier
   - Kubernetes version: 1.29
   - Network plugin: Azure CNI
   - Network policy: Azure
   - Built-in KEDA enabled

2. **Node Pools**
   - **System pool**: 2-5 nodes (Standard_D4s_v5) - for system workloads
   - **Workload pool**: 1-10 nodes (Standard_D4s_v5) - for Squad services
   - Auto-scaling enabled on both pools
   - Labeled for workload isolation

3. **Azure Container Registry (ACR)**
   - SKU: Standard
   - 30-day retention policy
   - Integrated with AKS via managed identity (AcrPull role)

4. **Virtual Network**
   - Address space: 10.240.0.0/16
   - AKS subnet: 10.240.0.0/22 (1,024 IPs)
   - ACR subnet: 10.240.4.0/24 (256 IPs)

5. **Monitoring**
   - Log Analytics workspace for container insights
   - Azure Monitor integration enabled
   - Metrics collection for nodes and pods

6. **Identity**
   - User-assigned managed identity for AKS control plane
   - Azure AD integration for RBAC
   - Local accounts disabled for security

## Prerequisites

- Azure CLI (`az`) installed and authenticated
- `kubectl` installed (for cluster management)
- Azure subscription with permissions to create resources
- Resource group creation rights

## Deployment

### Option 1: Using Bash Script (Linux/macOS/WSL)

```bash
cd infrastructure
chmod +x deploy-aks-automatic.sh
./deploy-aks-automatic.sh dev eastus
```

### Option 2: Using PowerShell Script (Windows/cross-platform)

```powershell
cd infrastructure
.\deploy-aks-automatic.ps1 -Environment dev -Location eastus
```

### Option 3: Manual Deployment via Azure CLI

```bash
# Set variables
ENVIRONMENT="dev"
LOCATION="eastus"
RESOURCE_GROUP="squad-aks-${ENVIRONMENT}-rg"

# Create resource group
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION

# Deploy Bicep template
az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --template-file ./aks-automatic-squad.bicep \
    --parameters environment=$ENVIRONMENT location=$LOCATION

# Get cluster credentials
AKS_NAME=$(az deployment group show -g $RESOURCE_GROUP -n squad-aks-deployment \
    --query properties.outputs.aksClusterName.value -o tsv)
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME
```

## Post-Deployment Verification

```bash
# Check cluster nodes
kubectl get nodes

# Verify KEDA installation (built-in to AKS Automatic)
kubectl get pods -n kube-system | grep keda

# Check system pods
kubectl get pods -n kube-system

# Verify node pools
az aks nodepool list --resource-group squad-aks-dev-rg --cluster-name <cluster-name> -o table
```

## ACR Integration

Build and push container images to the integrated ACR:

```bash
# Get ACR name from deployment output
ACR_NAME=$(az deployment group show -g squad-aks-dev-rg -n <deployment-name> \
    --query properties.outputs.acrName.value -o tsv)

# Build and push image using ACR build tasks
az acr build -t squad-monitor:latest -r $ACR_NAME ../squad-monitor-standalone/

# Alternative: Build locally and push
docker build -t ${ACR_NAME}.azurecr.io/squad-monitor:latest ../squad-monitor-standalone/
az acr login -n $ACR_NAME
docker push ${ACR_NAME}.azurecr.io/squad-monitor:latest
```

## KEDA Usage

KEDA is pre-installed with AKS Automatic. Deploy ScaledObjects directly:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: ralph-scaler
spec:
  scaleTargetRef:
    name: ralph-deployment
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      metricName: squad_queue_depth
      threshold: '5'
```

## Cost Optimization

- **Dev environment**: Uses auto-scaling (min 2 system + 1 workload nodes)
- **Production**: Increase min counts and enable reserved instances
- **Monitoring**: 30-day Log Analytics retention (adjust as needed)
- **ACR**: Standard tier with 30-day retention policy

## Security Features

- Azure AD integration with Azure RBAC enabled
- Local accounts disabled (enforces AAD-only access)
- Azure Policy enabled for compliance enforcement
- Managed identity for ACR access (no credentials stored)
- Network policy enforcement (Azure CNI)

## Troubleshooting

### Authentication Issues
```bash
# Re-authenticate
az login
az aks get-credentials --resource-group squad-aks-dev-rg --name <cluster-name> --overwrite-existing
```

### Node Scaling Issues
```bash
# Check autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler

# Check node pool status
az aks nodepool show -g squad-aks-dev-rg --cluster-name <cluster-name> -n workload
```

### KEDA Not Working
```bash
# Verify KEDA is enabled (should show "enabled: true")
az aks show -g squad-aks-dev-rg -n <cluster-name> \
    --query workloadAutoScalerProfile.keda

# Check KEDA operator pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=keda-operator
```

## Cleanup

```bash
# Delete entire resource group
az group delete --name squad-aks-dev-rg --yes --no-wait
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `environment` | string | `dev` | Environment name (dev/stg/prod) |
| `location` | string | `eastus` | Azure region |
| `kubernetesVersion` | string | `1.29` | Kubernetes version |
| `enableMonitoring` | bool | `true` | Enable Azure Monitor for containers |
| `enableAzurePolicy` | bool | `true` | Enable Azure Policy add-on |

## Outputs

| Output | Description |
|--------|-------------|
| `aksClusterName` | AKS cluster name |
| `aksClusterId` | AKS cluster resource ID |
| `aksFqdn` | AKS cluster FQDN |
| `acrName` | Azure Container Registry name |
| `acrLoginServer` | ACR login server URL |
| `vnetId` | Virtual network resource ID |
| `logAnalyticsWorkspaceId` | Log Analytics workspace ID |
| `identityId` | Managed identity resource ID |

## References

- [AKS Automatic Documentation](https://learn.microsoft.com/en-us/azure/aks/intro-aks-automatic)
- [KEDA Documentation](https://keda.sh/)
- [Azure Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
