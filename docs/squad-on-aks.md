# Squad on AKS — Deployment Guide

> Closes #1161 | Relates to #1060, #1059 (K8s architecture), #1136 (AKS Automatic eval), #1159 (Helm aksMode)

## Overview

Squad agents (Ralph, Picard, Seven, and friends) run on Azure Kubernetes Service (AKS).
This guide covers **two supported deployment paths**:

| Path | Tier | Best for | Cost |
|------|------|----------|------|
| **Path 1: AKS Standard Free** | Free control plane | Dev, staging, cost-sensitive teams | ~$55–80/mo |
| **Path 2: AKS Automatic** | Managed everything | Production, zero-ops teams | ~$150–200/mo |

**Choose Standard Free when** you want maximum control, low cost, and are comfortable running
`helm install` for KEDA, CSI, and managing node pools yourself.

**Choose AKS Automatic when** your team wants to drop the maintenance burden entirely — KEDA,
the CSI Secrets Store driver, Workload Identity webhook, auto-patching, and node provisioning
are all built-in and managed by Azure.

Both paths use the same Squad Helm chart (`infrastructure/helm/squad-agents/`). The only
difference is the `aksMode` flag and a few steps you skip on AKS Automatic.

---

## Table of Contents

1. [Path 1: AKS Standard Free (Development / Low-Cost)](#path-1-aks-standard-free-development--low-cost)
   - [When to use](#when-to-use)
   - [Prerequisites](#prerequisites)
   - [Step 1: Create the cluster](#step-1-create-aks-standard-free-cluster)
   - [Step 2: Install KEDA](#step-2-install-keda)
   - [Step 3: Install CSI Secrets Store](#step-3-install-csi-secrets-store-driver)
   - [Step 4: Configure Workload Identity + Key Vault](#step-4-configure-workload-identity--key-vault)
   - [Step 5: Deploy Squad Helm chart](#step-5-deploy-squad-helm-chart)
   - [Step 6: Verify](#step-6-verify)
2. [Path 2: AKS Automatic (Production / Zero-Ops)](#path-2-aks-automatic-production--zero-ops)
   - [When to use](#when-to-use-1)
   - [What's included automatically](#whats-included-automatically)
   - [Prerequisites](#prerequisites-1)
   - [Step 1: Create the cluster](#step-1-create-aks-automatic-cluster)
   - [Step 2: Configure Workload Identity + Key Vault](#step-2-configure-workload-identity--key-vault)
   - [Step 3: Deploy Squad Helm chart](#step-3-deploy-squad-helm-chart)
   - [Step 4: Verify](#step-4-verify)
3. [Cost Comparison Table](#cost-comparison-table)
4. [Migrating from Standard to Automatic](#migrating-from-standard-to-automatic)
5. [Troubleshooting](#troubleshooting)

---

## Path 1: AKS Standard Free (Development / Low-Cost)

### When to use

- You're setting up Squad for the first time and want to keep costs low
- You need a dev/staging environment for testing new agents or Helm chart changes
- Your team is comfortable managing KEDA, CSI driver, and node pool taints manually
- You want Spot VM node pools to further reduce costs
- Budget constraint: stay under $100/mo

### Prerequisites

Install the following tools before starting:

```bash
# Azure CLI >= 2.56
az --version

# kubectl >= 1.29
kubectl version --client

# Helm >= 3.14
helm version

# GitHub CLI >= 2.45 (for squad.config.ts repo access)
gh --version
```

Azure permissions required:
- `Contributor` on the target resource group
- `Key Vault Secrets Officer` on the Key Vault
- `AcrPush` on the Azure Container Registry

### Step 1: Create AKS Standard Free cluster

Set your environment variables first — these are reused throughout all steps:

```bash
# Core variables
RESOURCE_GROUP="rg-squad-dev"
LOCATION="eastus2"
CLUSTER_NAME="aks-squad-dev"
ACR_NAME="acrsquaddev"        # Must be globally unique
KV_NAME="kv-squad-dev"
IDENTITY_NAME="id-squad-workload"
SQUAD_NAMESPACE="squad"
```

Create the resource group and cluster:

```bash
# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create AKS Standard Free cluster
# - Free control plane tier (no SLA, fine for dev)
# - 2 system nodes (D2s_v3: 2 vCPU / 8 GB RAM)
# - OIDC issuer + Workload Identity webhook enabled at creation time
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --tier free \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --enable-workload-identity \
  --enable-oidc-issuer \
  --network-plugin azure \
  --network-policy calico \
  --generate-ssh-keys \
  --attach-acr $ACR_NAME

# Merge kubeconfig
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Confirm connection
kubectl get nodes
```

> **Optional: Add a dedicated Squad node pool** (recommended for isolation)
>
> ```bash
> az aks nodepool add \
>   --resource-group $RESOURCE_GROUP \
>   --cluster-name $CLUSTER_NAME \
>   --name squadagent \
>   --node-count 1 \
>   --vm-size Standard_D2s_v3 \
>   --labels agentpool=squad \
>   --node-taints agentpool=squad:NoSchedule \
>   --enable-cluster-autoscaler \
>   --min-count 0 \
>   --max-count 3
> ```
>
> If you add this pool, pass `--set nodeSelector.agentpool=squad` to Helm (Step 5).

### Step 2: Install KEDA

KEDA is not included in AKS Standard Free. Install via the AKS add-on (managed) or Helm:

**Option A — AKS add-on (recommended, stays up-to-date automatically):**

```bash
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-keda

# Verify
kubectl get pods -n kube-system -l app=keda-operator
```

**Option B — Helm (more version control):**

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm upgrade --install keda kedacore/keda \
  --namespace keda \
  --create-namespace \
  --version 2.14.0 \
  --set watchNamespace=squad

# Verify
kubectl get pods -n keda
```

### Step 3: Install CSI Secrets Store driver

The CSI driver mounts Azure Key Vault secrets as Kubernetes volumes (no Secrets in etcd).

**Option A — AKS add-on (recommended):**

```bash
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --addons azure-keyvault-secrets-provider

# Verify
kubectl get pods -n kube-system -l app=secrets-store-csi-driver
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-azure
```

**Option B — Helm:**

```bash
helm repo add csi-secrets-store-provider-azure \
  https://azure.github.io/secrets-store-csi-driver-provider-azure/charts
helm repo update

helm upgrade --install csi-secrets-store \
  csi-secrets-store-provider-azure/csi-secrets-store-provider-azure \
  --namespace kube-system \
  --set syncSecret.enabled=true \
  --set enableSecretRotation=true \
  --set rotationPollInterval=2m
```

### Step 4: Configure Workload Identity + Key Vault

This is the same for both paths. Workload Identity allows Squad pods to pull secrets
from Key Vault without storing any credentials in the cluster.

#### 4a. Create the Key Vault

```bash
az keyvault create \
  --resource-group $RESOURCE_GROUP \
  --name $KV_NAME \
  --location $LOCATION \
  --sku standard \
  --enable-rbac-authorization true
```

#### 4b. Create the Managed Identity

```bash
az identity create \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY_NAME \
  --location $LOCATION

# Capture the IDs we'll need
IDENTITY_CLIENT_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY_NAME \
  --query clientId -o tsv)

IDENTITY_OBJECT_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY_NAME \
  --query principalId -o tsv)

TENANT_ID=$(az account show --query tenantId -o tsv)
```

#### 4c. Grant the identity access to Key Vault

```bash
KV_ID=$(az keyvault show \
  --resource-group $RESOURCE_GROUP \
  --name $KV_NAME \
  --query id -o tsv)

az role assignment create \
  --assignee-object-id $IDENTITY_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope $KV_ID
```

#### 4d. Populate the secrets

```bash
# GitHub token — must have: repo, read:org, issues:write
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "squad-gh-token" \
  --value "ghp_YOURTOKEN"

# Copilot / LLM API key
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "squad-copilot-api-key" \
  --value "sk-YOUR_API_KEY"
```

#### 4e. Create the federated identity credential

```bash
OIDC_ISSUER=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

az identity federated-credential create \
  --resource-group $RESOURCE_GROUP \
  --identity-name $IDENTITY_NAME \
  --name squad-aks-federation \
  --issuer "$OIDC_ISSUER" \
  --subject "system:serviceaccount:${SQUAD_NAMESPACE}:squad-agents" \
  --audiences "api://AzureADTokenExchange"
```

#### 4f. Label the namespace for Workload Identity injection

```bash
kubectl create namespace $SQUAD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

kubectl label namespace $SQUAD_NAMESPACE \
  azure.workload.identity/use=true
```

### Step 5: Deploy Squad Helm chart

```bash
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

helm upgrade --install squad \
  ./infrastructure/helm/squad-agents \
  --namespace $SQUAD_NAMESPACE \
  --create-namespace \
  --set aksMode=standard \
  --set nodeSelector.agentpool=squad \
  --set global.acrLoginServer=$ACR_LOGIN_SERVER \
  --set global.keyVaultName=$KV_NAME \
  --set global.tenantId=$TENANT_ID \
  --set global.repository="tamirdresher_microsoft/tamresearch1" \
  --set azure.managedIdentityClientId=$IDENTITY_CLIENT_ID \
  --set keda.enabled=true \
  --wait --timeout 5m
```

> **Note on `aksMode=standard`:** The Helm chart uses this flag to generate post-install
> NOTES.txt with the full checklist (node pool, CSI driver, KEDA, federated identity).
> Setting `--set nodeSelector.agentpool=squad` pins all pods to the dedicated Squad node pool.
> Omit it if you're running on the default system node pool.

### Step 6: Verify

```bash
# All Squad pods running
kubectl get pods -n squad

# Ralph CronJob scheduled
kubectl get cronjob -n squad

# Picard Deployment healthy
kubectl get deployment -n squad

# KEDA ScaledObject reconciled
kubectl get scaledobject -n squad

# TriggerAuthentication bound
kubectl get triggerauthentication -n squad

# Secrets mounted (CSI volumes present)
kubectl describe pod -n squad -l app.kubernetes.io/name=picard | grep -A5 Volumes

# Check Ralph ran successfully (view last job log)
kubectl get jobs -n squad
JOB=$(kubectl get jobs -n squad --sort-by=.metadata.creationTimestamp -o name | tail -1)
kubectl logs -n squad $JOB
```

Expected output:
```
NAME                          READY   STATUS    RESTARTS   AGE
picard-7d4f9b6c8-xk2vp        1/1     Running   0          3m
ralph-28491234-z9qrt           0/1     Completed 0          2m

NAME              SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE
ralph             */5 * * * *   False     0        2m
```

---

## Path 2: AKS Automatic (Production / Zero-Ops)

### When to use

- Running Squad in production where reliability matters
- Your team wants to eliminate manual cluster maintenance (no node pool management, no patching)
- You're okay with the ~$150–200/mo cost in exchange for zero ops overhead
- You need auto-healing, automatic node provisioning (Karpenter-based), and built-in monitoring

### What's included automatically

AKS Automatic bundles the following at cluster creation — you do **not** install these manually:

| Component | Standard Free | AKS Automatic |
|-----------|:---:|:---:|
| KEDA (event-driven scaling) | ❌ Manual install | ✅ Built-in |
| CSI Secrets Store + Azure provider | ❌ Manual install | ✅ Built-in |
| Workload Identity webhook | ❌ Manual (via `--enable-workload-identity`) | ✅ Built-in |
| Node auto-provisioning | ❌ Manual node pools | ✅ Karpenter-based |
| OS auto-patching | ❌ Manual `az aks upgrade` | ✅ Automatic |
| Node pool management | ❌ You create/delete pools | ✅ Managed |
| Default deny network policy | ❌ Optional | ✅ Enforced |
| Azure Monitor managed metrics | ❌ Optional add-on | ✅ Built-in |

### Prerequisites

Same tools as Path 1:

```bash
az --version       # Azure CLI >= 2.56
kubectl version    # >= 1.29
helm version       # >= 3.14
gh --version       # >= 2.45
```

Permissions:
- `Contributor` on the resource group
- `Key Vault Secrets Officer`
- `AcrPush` on ACR

### Step 1: Create AKS Automatic cluster

```bash
# Core variables
RESOURCE_GROUP="rg-squad-prod"
LOCATION="eastus2"
CLUSTER_NAME="aks-squad-prod"
ACR_NAME="acrsquadprod"       # Must be globally unique
KV_NAME="kv-squad-prod"
IDENTITY_NAME="id-squad-workload"
SQUAD_NAMESPACE="squad"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create AKS Automatic cluster
# --sku automatic enables all built-in managed components
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --sku automatic \
  --location $LOCATION \
  --generate-ssh-keys \
  --attach-acr $ACR_NAME

# Merge kubeconfig
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Confirm connection and verify built-in components
kubectl get nodes
kubectl get pods -n kube-system | grep -E "keda|secrets-store|workload"
```

> **No node pool management needed.** AKS Automatic uses node auto-provisioning (NAP) based
> on Karpenter. Pods are scheduled to right-sized nodes automatically — no `az aks nodepool add`
> commands required.

### Step 2: Configure Workload Identity + Key Vault

KEDA and CSI are already installed. You only need to wire up the identity and secrets.

#### 2a. Create the Key Vault

```bash
az keyvault create \
  --resource-group $RESOURCE_GROUP \
  --name $KV_NAME \
  --location $LOCATION \
  --sku standard \
  --enable-rbac-authorization true
```

#### 2b. Create the Managed Identity

```bash
az identity create \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY_NAME \
  --location $LOCATION

IDENTITY_CLIENT_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY_NAME \
  --query clientId -o tsv)

IDENTITY_OBJECT_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY_NAME \
  --query principalId -o tsv)

TENANT_ID=$(az account show --query tenantId -o tsv)
```

#### 2c. Grant the identity access to Key Vault

```bash
KV_ID=$(az keyvault show \
  --resource-group $RESOURCE_GROUP \
  --name $KV_NAME \
  --query id -o tsv)

az role assignment create \
  --assignee-object-id $IDENTITY_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope $KV_ID
```

#### 2d. Populate the secrets

```bash
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "squad-gh-token" \
  --value "ghp_YOURTOKEN"

az keyvault secret set \
  --vault-name $KV_NAME \
  --name "squad-copilot-api-key" \
  --value "sk-YOUR_API_KEY"
```

#### 2e. Create the federated identity credential

```bash
# AKS Automatic always has OIDC issuer enabled
OIDC_ISSUER=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

az identity federated-credential create \
  --resource-group $RESOURCE_GROUP \
  --identity-name $IDENTITY_NAME \
  --name squad-aks-federation \
  --issuer "$OIDC_ISSUER" \
  --subject "system:serviceaccount:${SQUAD_NAMESPACE}:squad-agents" \
  --audiences "api://AzureADTokenExchange"
```

#### 2f. Label the namespace

```bash
kubectl create namespace $SQUAD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

kubectl label namespace $SQUAD_NAMESPACE \
  azure.workload.identity/use=true
```

### Step 3: Deploy Squad Helm chart

```bash
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

helm upgrade --install squad \
  ./infrastructure/helm/squad-agents \
  --namespace $SQUAD_NAMESPACE \
  --create-namespace \
  --set aksMode=automatic \
  --set global.acrLoginServer=$ACR_LOGIN_SERVER \
  --set global.keyVaultName=$KV_NAME \
  --set global.tenantId=$TENANT_ID \
  --set global.repository="tamirdresher_microsoft/tamresearch1" \
  --set azure.managedIdentityClientId=$IDENTITY_CLIENT_ID \
  --set keda.enabled=true \
  --wait --timeout 5m
```

> **Note on `aksMode=automatic`:** No `nodeSelector` is passed — AKS Automatic's node
> auto-provisioner schedules pods on right-sized nodes without explicit pool targeting.
> The Helm chart omits `nodeSelector` from all Pod specs when `aksMode=automatic`.

### Step 4: Verify

```bash
# All Squad pods running
kubectl get pods -n squad

# Ralph CronJob scheduled
kubectl get cronjob -n squad

# Picard Deployment healthy
kubectl get deployment -n squad

# KEDA ScaledObjects active
kubectl get scaledobject -n squad
kubectl describe scaledobject -n squad picard-scaler | grep -A3 "Status:"

# Node auto-provisioner chose an appropriate VM size
kubectl get nodes -L kubernetes.azure.com/node-image-version

# Check Key Vault secrets mounted
kubectl exec -n squad deploy/picard -- ls /mnt/secrets-store/
```

---

## Cost Comparison Table

| Feature | AKS Standard Free | AKS Automatic |
|---------|:-----------------:|:-------------:|
| **Estimated monthly cost** | ~$55–80 | ~$150–200 |
| **Control plane** | Free (no SLA) | Managed (99.9% SLA) |
| **KEDA** | Manual install (add-on or Helm) | ✅ Built-in |
| **CSI Secrets Store** | Manual install (add-on or Helm) | ✅ Built-in |
| **Workload Identity webhook** | Manual (`--enable-workload-identity`) | ✅ Built-in |
| **Node pool management** | Manual (`az aks nodepool add/delete`) | ✅ Auto-provisioned |
| **OS patching** | Manual (`az aks upgrade`) | ✅ Automatic |
| **Node auto-healing** | Limited | ✅ Full |
| **Network policy** | Optional (Calico/Azure) | ✅ Default deny enforced |
| **Azure Monitor metrics** | Optional add-on | ✅ Built-in managed Prometheus |
| **Spot VM support** | ✅ Manual nodepool | ❌ Not supported in Automatic |
| **Setup steps (Squad)** | ~12 steps | ~7 steps |
| **Recommended for** | Dev / staging | Production |
| **Helm flag** | `--set aksMode=standard` | `--set aksMode=automatic` |
| **nodeSelector required** | Yes (`agentpool=squad`) | No |

### Cost breakdown (Standard Free, 2-node D2s_v3)

| Resource | Monthly |
|----------|---------|
| 2× Standard_D2s_v3 nodes (always-on system pool) | ~$140 → with Reserved: ~$55 |
| Azure Key Vault (< 10k operations) | ~$0.50 |
| Azure Container Registry (Basic) | ~$5 |
| Log Analytics (< 1 GB/day) | ~$2 |
| **Total** | **~$63–80/mo** |

### Cost breakdown (AKS Automatic)

| Resource | Monthly |
|----------|---------|
| AKS Automatic control plane | ~$73 |
| Node auto-provisioner base (system nodes) | ~$60–80 |
| Azure Key Vault | ~$0.50 |
| Azure Container Registry (Basic) | ~$5 |
| Log Analytics (managed Prometheus) | ~$10–20 |
| **Total** | **~$150–180/mo** |

---

## Migrating from Standard to Automatic

When your Squad deployment outgrows dev and you're ready for production:

### Step 1: Build and push images to production ACR

```bash
# From your current Standard setup
ACR_PROD="acrsquadprod"
ACR_DEV="acrsquaddev"

# Re-tag and push to prod ACR
az acr import \
  --name $ACR_PROD \
  --source ${ACR_DEV}.azurecr.io/squad-agents:latest \
  --image squad-agents:latest
```

### Step 2: Export your current Helm values

```bash
helm get values squad -n squad > squad-values-backup.yaml
```

### Step 3: Create the AKS Automatic cluster

Follow [Path 2, Step 1](#step-1-create-aks-automatic-cluster) using a new resource group
(`rg-squad-prod`) to avoid touching the dev cluster.

### Step 4: Migrate Key Vault secrets

Option A — re-run `az keyvault secret set` commands against the new Key Vault.

Option B — copy secrets between vaults:

```bash
KV_DEV="kv-squad-dev"
KV_PROD="kv-squad-prod"

for SECRET in squad-gh-token squad-copilot-api-key; do
  VALUE=$(az keyvault secret show \
    --vault-name $KV_DEV \
    --name $SECRET \
    --query value -o tsv)
  az keyvault secret set \
    --vault-name $KV_PROD \
    --name $SECRET \
    --value "$VALUE"
done
```

### Step 5: Create the federated identity credential for the new cluster

```bash
# New OIDC issuer from the Automatic cluster
OIDC_ISSUER_PROD=$(az aks show \
  --resource-group rg-squad-prod \
  --name aks-squad-prod \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

az identity federated-credential create \
  --resource-group rg-squad-prod \
  --identity-name id-squad-workload \
  --name squad-aks-prod-federation \
  --issuer "$OIDC_ISSUER_PROD" \
  --subject "system:serviceaccount:squad:squad-agents" \
  --audiences "api://AzureADTokenExchange"
```

### Step 6: Helm upgrade with aksMode=automatic

```bash
helm upgrade --install squad \
  ./infrastructure/helm/squad-agents \
  --namespace squad \
  --create-namespace \
  --set aksMode=automatic \
  --set global.acrLoginServer=acrsquadprod.azurecr.io \
  --set global.keyVaultName=kv-squad-prod \
  --set global.tenantId=$TENANT_ID \
  --set global.repository="tamirdresher_microsoft/tamresearch1" \
  --set azure.managedIdentityClientId=$IDENTITY_CLIENT_ID \
  --set keda.enabled=true \
  --wait --timeout 5m
```

### Step 7: Validate and decommission dev cluster

```bash
# Confirm prod Squad is healthy
kubectl get pods -n squad
kubectl get scaledobject -n squad

# Delete dev cluster (after a validation period — recommended: 1 week)
az aks delete \
  --resource-group rg-squad-dev \
  --name aks-squad-dev \
  --yes --no-wait
```

---

## Troubleshooting

### Standard Free — KEDA ScaledObject not scaling

```bash
# Check KEDA operator logs
kubectl logs -n keda deploy/keda-operator | tail -50

# Check TriggerAuthentication
kubectl describe triggerauthentication -n squad squad-trigger-auth

# Verify the GitHub token secret is accessible
kubectl get secret -n squad squad-runtime-secrets
```

**Common cause:** The federated credential subject doesn't match the ServiceAccount namespace/name.
Verify: `az identity federated-credential list --identity-name $IDENTITY_NAME --resource-group $RESOURCE_GROUP`

---

### Standard Free — CSI secret not mounted

```bash
# Check SecretProviderClass
kubectl describe secretproviderclass -n squad squad-keyvault

# Check pod events for CSI mount failures
kubectl describe pod -n squad <pod-name> | grep -A20 Events

# Check CSI driver logs
kubectl logs -n kube-system -l app=secrets-store-csi-driver | tail -30
```

**Common cause:** `tenantId` or `clientId` mismatch in the SecretProviderClass. Re-check
`--set global.tenantId=` and `--set azure.managedIdentityClientId=` in your Helm command.

---

### AKS Automatic — Pod stuck in Pending (node provisioning)

```bash
# Check node provisioner events
kubectl describe node -l kubernetes.azure.com/node-provisioner=napcontroller | tail -30

# Check pod events
kubectl describe pod -n squad <pod-name> | grep -A10 Events
```

**Common cause:** Pod resource requests exceed what AKS Automatic can provision within the
configured NodePool constraints. Check `kubectl get nodepool -A` and verify the CPU/memory
limits in `values.yaml`.

---

### Both paths — Workload Identity token not acquired

```bash
# Confirm the namespace label is set
kubectl get namespace squad --show-labels | grep workload-identity

# Confirm the ServiceAccount annotation is present
kubectl get serviceaccount -n squad squad-agents -o yaml | grep client-id

# Test token projection manually
kubectl exec -n squad deploy/picard -- cat /var/run/secrets/azure/tokens/azure-identity-token
```

**Common cause:** The `azure.workload.identity/use=true` label is missing from the namespace,
or the `azure.workload.identity/client-id` annotation is missing/wrong on the ServiceAccount.

---

### Both paths — Ralph CronJob not running

```bash
# Check CronJob spec
kubectl get cronjob -n squad ralph -o yaml | grep -A5 schedule

# Manually trigger a run for testing
kubectl create job -n squad ralph-manual-test \
  --from=cronjob/ralph

# Follow the logs
kubectl logs -n squad job/ralph-manual-test -f
```

**Common cause:** `keda.enabled=false` in values causes the KEDA ScaledObject to not be
deployed, but the CronJob itself runs independently. If you see `Forbid` on overlapping runs,
a previous run may still be active — check `kubectl get jobs -n squad`.

---

### Both paths — ACR image pull failure (`ImagePullBackOff`)

```bash
# Verify ACR attachment
az aks check-acr \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --acr $ACR_NAME

# Re-attach if needed
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --attach-acr $ACR_NAME
```

---

## Reference: Helm Values Quick Reference

| Value | Default | Description |
|-------|---------|-------------|
| `aksMode` | `standard` | `standard` or `automatic` — controls nodeSelector and NOTES.txt |
| `nodeSelector.agentpool` | _(empty)_ | Node pool label; set to `squad` for Standard dedicated pool |
| `azure.managedIdentityClientId` | `""` | Managed Identity client ID for Workload Identity annotation |
| `global.keyVaultName` | `""` | Azure Key Vault name for CSI secret mounting |
| `global.tenantId` | `""` | Azure Tenant ID for CSI driver |
| `global.acrLoginServer` | `""` | ACR login server (e.g. `acrsquadprod.azurecr.io`) |
| `global.repository` | `tamirdresher_microsoft/tamresearch1` | GitHub repo for Squad agents |
| `keda.enabled` | `false` | Enable KEDA ScaledObject for Picard autoscaling |
| `keda.picard.minReplicaCount` | `0` | Scale-to-zero when no open picard issues |
| `keda.picard.maxReplicaCount` | `3` | Maximum Picard replicas |
| `ralph.schedule` | `*/5 * * * *` | CronJob schedule |

Full values reference: [`infrastructure/helm/squad-agents/values.yaml`](../infrastructure/helm/squad-agents/values.yaml)

---

*Last updated: relates to PR #1162 (AKS Automatic eval), PR #1174 (Helm aksMode), Issue #1161 (this guide)*
