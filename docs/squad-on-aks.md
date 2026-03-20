# Squad on AKS — Azure-Native Deployment Guide

> Closes #1060 | Relates to #1059 (K8s architecture), #994 (Squad-on-K8s), #997 (AKS + KAITO)

## Overview

This guide covers deploying the Squad AI agent framework on Azure Kubernetes Service (AKS),
using Azure-native services for identity, secrets, container hosting, and observability.

**What you'll end up with:**
- Ralph running as a CronJob (reconciliation loop, every 5 minutes)
- Picard running as a long-lived Deployment (architecture/decision maker)
- All secrets sourced from Azure Key Vault via the CSI driver
- `gh` CLI authenticated via Workload Identity (no PAT tokens in containers)
- Container images stored in Azure Container Registry (ACR)
- Logs flowing to Log Analytics; alerts wired through Azure Monitor

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Azure Infrastructure Setup](#azure-infrastructure-setup)
3. [Workload Identity for GitHub Auth](#workload-identity-for-github-auth)
4. [Azure Key Vault Integration](#azure-key-vault-integration)
5. [Container Images and ACR](#container-images-and-acr)
6. [AKS Features to Leverage](#aks-features-to-leverage)
7. [Helm Chart Deployment](#helm-chart-deployment)
8. [GitHub Actions CI/CD Pipeline](#github-actions-cicd-pipeline)
9. [Monitoring and Observability](#monitoring-and-observability)
10. [Step-by-Step Deployment Walkthrough](#step-by-step-deployment-walkthrough)
11. [KAITO Consideration for LLM Inference](#kaito-consideration-for-llm-inference)
12. [Cost Optimization](#cost-optimization)
13. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Tools
```bash
az --version          # Azure CLI >= 2.56
kubectl version       # >= 1.29
helm version          # >= 3.14
gh --version          # GitHub CLI >= 2.45
docker --version      # >= 24.0 (for local builds)
```

### Azure resources (one-time)
| Resource | Purpose | SKU recommendation |
|----------|---------|-------------------|
| AKS cluster | Runs Squad agents | Standard_D4s_v5 system pool + spot worker pools |
| Azure Container Registry (ACR) | Hosts Squad container images | Standard (Premium for geo-replication) |
| Azure Key Vault | Stores GH_TOKEN, API keys, webhook URLs | Standard |
| User-Assigned Managed Identity | Federated credential for GitHub App auth | — |
| Log Analytics Workspace | Squad logs and metrics | Pay-per-use |
| Application Insights | Distributed tracing | Connected to Log Analytics |

### Permissions
- `Contributor` on the resource group (for Bicep/Terraform deployments)
- `Key Vault Secrets Officer` (to push secrets)
- `AcrPush` on the ACR (for CI/CD pipeline)
- `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/write` (for Workload Identity setup)

---

## Azure Infrastructure Setup

Deploy the supporting infrastructure using the provided Bicep template. A skeleton is included
at `infrastructure/bicep/squad-aks.bicep` (to be fleshed out per #1060 acceptance criteria).

### Quick start — Bicep

```bash
# Set variables
RESOURCE_GROUP="rg-squad-prod"
LOCATION="eastus2"
CLUSTER_NAME="aks-squad-prod"
ACR_NAME="acrsquadprod"          # globally unique
KV_NAME="kv-squad-prod"
IDENTITY_NAME="id-squad-workload"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Deploy infrastructure (Bicep template in infrastructure/bicep/)
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file infrastructure/bicep/squad-aks.bicep \
  --parameters \
    clusterName=$CLUSTER_NAME \
    acrName=$ACR_NAME \
    keyVaultName=$KV_NAME \
    managedIdentityName=$IDENTITY_NAME
```

### AKS cluster node pools

Squad agents benefit from dedicated node pools:

```bash
# System pool (already exists)
# --node-count 2 --vm-size Standard_D4s_v5

# Squad monitor pool (Ralph, lightweight)
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name squadmonitor \
  --node-count 1 \
  --vm-size Standard_D2s_v5 \
  --labels squad.github.com/pool=monitor \
  --node-taints squad.github.com/pool=monitor:NoSchedule

# Squad agent pool (Picard, Seven — CPU-intensive reasoning)
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name squadagent \
  --node-count 2 \
  --vm-size Standard_D8s_v5 \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 5 \
  --labels squad.github.com/pool=agent \
  --node-taints squad.github.com/pool=agent:NoSchedule \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1    # pay-as-you-go spot price
```

---

## Workload Identity for GitHub Auth

Workload Identity replaces PAT tokens in containers. The `gh` CLI reads the `GH_TOKEN`
environment variable, which is projected from Azure Key Vault (next section) via the
CSI driver. The Managed Identity itself is used to *pull that secret* from Key Vault
without any credential in the Pod spec.

### Step 1 — Enable OIDC issuer and Workload Identity on AKS

```bash
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-oidc-issuer \
  --enable-workload-identity

# Get OIDC issuer URL (needed for federation)
OIDC_ISSUER=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)
```

### Step 2 — Create user-assigned Managed Identity

```bash
az identity create \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY_NAME

IDENTITY_CLIENT_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY_NAME \
  --query clientId -o tsv)

IDENTITY_OBJECT_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY_NAME \
  --query principalId -o tsv)
```

### Step 3 — Grant identity access to Key Vault

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

### Step 4 — Federate the identity with the K8s ServiceAccount

```bash
# The ServiceAccount name/namespace must match what Helm creates
az identity federated-credential create \
  --resource-group $RESOURCE_GROUP \
  --identity-name $IDENTITY_NAME \
  --name squad-aks-federation \
  --issuer $OIDC_ISSUER \
  --subject "system:serviceaccount:squad:squad-agents" \
  --audiences "api://AzureADTokenExchange"
```

### Step 5 — Annotate the K8s ServiceAccount (handled by Helm)

The Helm chart's `values.yaml` has:
```yaml
serviceAccount:
  annotations:
    azure.workload.identity/client-id: "<IDENTITY_CLIENT_ID>"
```

Set this at deploy time:
```bash
helm upgrade --install squad-agents infrastructure/helm/squad-agents/ \
  --set serviceAccount.annotations."azure\.workload\.identity/client-id"=$IDENTITY_CLIENT_ID \
  ...
```

---

## Azure Key Vault Integration

Squad secrets (GitHub token, MCP API keys, webhook URLs) are stored in Key Vault and
mounted into Pods via the **Secrets Store CSI Driver** (`secrets-store.csi.k8s.io`).

### Install the CSI driver add-on

```bash
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --addons azure-keyvault-secrets-provider
```

### Push secrets to Key Vault

```bash
# GitHub token (classic PAT or fine-grained — until GitHub App support lands)
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "squad-gh-token" \
  --value "$GH_TOKEN"

# Copilot API key
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "squad-copilot-api-key" \
  --value "$COPILOT_API_KEY"

# Optional: MCP webhook URL
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "squad-mcp-webhook-url" \
  --value "$MCP_WEBHOOK_URL"
```

### SecretProviderClass (created by Helm)

The Helm chart generates a `SecretProviderClass` object that the CSI driver reads.
It maps Key Vault secrets → environment variables projected into each Pod.

```yaml
# Excerpt from templates/secret-provider-class.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: squad-secrets
spec:
  provider: azure
  secretObjects:
    - secretName: squad-runtime-secrets
      type: Opaque
      data:
        - objectName: squad-gh-token
          key: GH_TOKEN
        - objectName: squad-copilot-api-key
          key: COPILOT_API_KEY
  parameters:
    usePodIdentity: "false"
    clientID: "<IDENTITY_CLIENT_ID>"
    keyvaultName: "<KV_NAME>"
    objects: |
      array:
        - |
          objectName: squad-gh-token
          objectType: secret
        - |
          objectName: squad-copilot-api-key
          objectType: secret
    tenantId: "<TENANT_ID>"
```

---

## Container Images and ACR

### Attach ACR to AKS

```bash
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --attach-acr $ACR_NAME
```

This grants the AKS kubelet identity `AcrPull` on the registry — no `imagePullSecrets` needed.

### Image strategy

```
Base:   mcr.microsoft.com/powershell:7-ubuntu-22.04
Layer:  Node.js 20 LTS + npm
Layer:  GitHub CLI (gh)
Layer:  git, jq, curl, ca-certificates
Layer:  Copilot CLI extension (gh extension install github/gh-copilot)
Layer:  Squad app code (squad.config.ts, agent scripts, skills)
```

The existing `infrastructure/k8s/Dockerfile.ralph` is the starting point.
For the full squad-agents chart, a single base image is used for all agents
(Ralph, Picard, Seven, etc.) with the agent type selected via an environment variable.

### Build and push manually

```bash
ACR_LOGIN_SERVER=$(az acr show \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --query loginServer -o tsv)

az acr login --name $ACR_NAME

docker build \
  -f infrastructure/k8s/Dockerfile.ralph \
  -t $ACR_LOGIN_SERVER/squad-agents:latest \
  -t $ACR_LOGIN_SERVER/squad-agents:$(git rev-parse --short HEAD) \
  .

docker push $ACR_LOGIN_SERVER/squad-agents:latest
docker push $ACR_LOGIN_SERVER/squad-agents:$(git rev-parse --short HEAD)
```

---

## AKS Features to Leverage

### Node pools per agent type

Map Squad agent capabilities to node pool labels + taints:

| Agent | Pool label | VM size | Rationale |
|-------|-----------|---------|-----------|
| Ralph | `pool=monitor` | Standard_D2s_v5 | Low CPU, mostly polling/waiting |
| Picard | `pool=agent` | Standard_D8s_v5 | Reasoning workloads, can use Spot |
| Seven | `pool=agent` | Standard_D8s_v5 | Document generation, parallel writes |
| KAITO LLM | `pool=gpu` | Standard_NC6s_v3 | GPU inference (see KAITO section) |

Set in `values.yaml`:
```yaml
ralph:
  nodeSelector:
    squad.github.com/pool: monitor
  tolerations:
    - key: squad.github.com/pool
      operator: Equal
      value: monitor
      effect: NoSchedule
```

### KEDA for event-driven scaling

[KEDA](https://keda.sh) scales Squad agent Deployments based on GitHub issue queue depth.
Install via Helm or the AKS KEDA add-on:

```bash
# Enable KEDA add-on (AKS managed)
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-keda
```

Example `ScaledObject` for Picard (scales based on open issues assigned to the agent):

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: picard-scaler
  namespace: squad
spec:
  scaleTargetRef:
    name: picard
  minReplicaCount: 0          # scale to zero when idle
  maxReplicaCount: 3
  triggers:
    - type: github
      metadata:
        owner: tamirdresher_microsoft
        repo: tamresearch1
        labels: "squad:picard"
        state: "open"
        targetIssueCount: "2"  # scale up when >2 open picard issues
      authenticationRef:
        name: github-trigger-auth
```

> **Note:** KEDA's GitHub scaler requires a PAT or GitHub App token.
> Store it in Key Vault and reference via `TriggerAuthentication`.

### Azure Monitor integration

```bash
# Enable Container Insights
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --addons monitoring \
  --workspace-resource-id $LAW_RESOURCE_ID
```

Squad-specific dashboard elements:
- Ralph heartbeat metric → custom metric → alert if missing >10 min
- Pod restart count per agent namespace
- CPU/memory per agent type (node pool breakdown)
- Log query: `ContainerLog | where LogEntry contains "ERROR" | project TimeGenerated, ContainerID, LogEntry`

---

## Helm Chart Deployment

The Helm chart at `infrastructure/helm/squad-agents/` is specific to AKS and extends
the base `infrastructure/helm/squad/` chart with Azure-native resources.

### Chart structure

```
infrastructure/helm/squad-agents/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── _helpers.tpl
    ├── namespace.yaml
    ├── serviceaccount.yaml
    ├── secret-provider-class.yaml
    ├── ralph-cronjob.yaml          ← Ralph: CronJob (5-min poll)
    ├── picard-deployment.yaml      ← Picard: long-running Deployment
    └── keda-scaledobject.yaml      ← KEDA scaling for Picard
```

### Deploy

```bash
# Add the squad namespace
kubectl create namespace squad --dry-run=client -o yaml | kubectl apply -f -

# Label namespace for Workload Identity webhook injection
kubectl label namespace squad azure.workload.identity/use=true

# Install / upgrade
helm upgrade --install squad-agents infrastructure/helm/squad-agents/ \
  --namespace squad \
  --values infrastructure/helm/squad-agents/values.yaml \
  --set global.acrLoginServer=$ACR_LOGIN_SERVER \
  --set global.keyVaultName=$KV_NAME \
  --set global.tenantId=$(az account show --query tenantId -o tsv) \
  --set serviceAccount.annotations."azure\.workload\.identity/client-id"=$IDENTITY_CLIENT_ID \
  --set ralph.image.tag=$(git rev-parse --short HEAD) \
  --set picard.image.tag=$(git rev-parse --short HEAD)
```

### Verify

```bash
kubectl get pods -n squad
kubectl logs -n squad -l app.kubernetes.io/component=ralph --tail=50
kubectl get cronjob -n squad
```

---

## GitHub Actions CI/CD Pipeline

Save as `.github/workflows/squad-agents-deploy.yml`:

```yaml
name: Squad Agents — Build & Deploy

on:
  push:
    branches: [main]
    paths:
      - 'infrastructure/k8s/Dockerfile.ralph'
      - 'ralph-watch.ps1'
      - 'squad.config.ts'
      - 'infrastructure/helm/squad-agents/**'
  workflow_dispatch:
    inputs:
      environment:
        description: Target environment
        required: true
        default: dev
        type: choice
        options: [dev, stg, prod]

permissions:
  id-token: write    # OIDC for Azure login
  contents: read

env:
  RESOURCE_GROUP: rg-squad-prod
  CLUSTER_NAME: aks-squad-prod
  ACR_NAME: acrsquadprod
  HELM_CHART: infrastructure/helm/squad-agents
  NAMESPACE: squad

jobs:
  build-and-push:
    name: Build & Push to ACR
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.version }}
    steps:
      - uses: actions/checkout@v4

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: ACR Login
        run: az acr login --name ${{ env.ACR_NAME }}

      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.ACR_NAME }}.azurecr.io/squad-agents
          tags: |
            type=sha,prefix=
            type=ref,event=branch
            type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}

      - name: Build & Push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: infrastructure/k8s/Dockerfile.ralph
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=registry,ref=${{ env.ACR_NAME }}.azurecr.io/squad-agents:buildcache
          cache-to: type=registry,ref=${{ env.ACR_NAME }}.azurecr.io/squad-agents:buildcache,mode=max

  deploy:
    name: Helm Deploy to AKS
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'dev' }}
    steps:
      - uses: actions/checkout@v4

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Get AKS credentials
        run: |
          az aks get-credentials \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --name ${{ env.CLUSTER_NAME }} \
            --overwrite-existing

      - name: Helm upgrade
        run: |
          helm upgrade --install squad-agents ${{ env.HELM_CHART }} \
            --namespace ${{ env.NAMESPACE }} \
            --create-namespace \
            --atomic \
            --timeout 5m \
            --set global.acrLoginServer=${{ env.ACR_NAME }}.azurecr.io \
            --set global.keyVaultName=${{ secrets.KV_NAME }} \
            --set global.tenantId=${{ secrets.AZURE_TENANT_ID }} \
            --set serviceAccount.annotations."azure\.workload\.identity/client-id"=${{ secrets.IDENTITY_CLIENT_ID }} \
            --set ralph.image.tag=${{ needs.build-and-push.outputs.image-tag }} \
            --set picard.image.tag=${{ needs.build-and-push.outputs.image-tag }}

      - name: Verify rollout
        run: |
          kubectl rollout status deployment/picard -n ${{ env.NAMESPACE }} --timeout=2m
          kubectl get pods -n ${{ env.NAMESPACE }}
```

> **GitHub Actions OIDC → Azure:** The workflow uses federated credentials
> (`AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID`) stored as
> GitHub Actions secrets — no long-lived service principal passwords.

---

## Monitoring and Observability

### Log Analytics queries

```kusto
// Ralph heartbeat gaps (missing heartbeats > 10 min)
ContainerLog
| where ContainerGroup startswith "ralph"
| where LogEntry contains "heartbeat"
| summarize LastHeartbeat=max(TimeGenerated) by ContainerGroup
| where LastHeartbeat < ago(10m)
| project ContainerGroup, LastHeartbeat, GapMinutes=datetime_diff('minute', now(), LastHeartbeat)

// Agent errors in last hour
ContainerLog
| where TimeGenerated > ago(1h)
| where LogEntry contains "ERROR" or LogEntry contains "FATAL"
| project TimeGenerated, ContainerGroup, LogEntry
| order by TimeGenerated desc

// CronJob execution history
KubeEvents
| where ObjectKind == "Job"
| where Namespace == "squad"
| project TimeGenerated, Name, Reason, Message
| order by TimeGenerated desc
```

### Alert rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| Ralph heartbeat missing | No heartbeat log in 10 min | Critical (Sev 1) |
| Pod crash loop | `kube_pod_container_status_restarts_total` rate > 3/5min | High (Sev 2) |
| Image pull failure | `KubeEvents` `Reason=Failed` for `squad` namespace | Medium (Sev 3) |
| Node pool scaling blocked | Cluster autoscaler can't provision node | High (Sev 2) |

---

## Step-by-Step Deployment Walkthrough

> Estimated time: ~45 minutes end-to-end on a fresh Azure subscription.

```bash
# 0. Clone repo and set variables
git clone https://github.com/tamirdresher_microsoft/tamresearch1
cd tamresearch1

export RESOURCE_GROUP="rg-squad-prod"
export LOCATION="eastus2"
export CLUSTER_NAME="aks-squad-prod"
export ACR_NAME="acrsquadprod$(openssl rand -hex 4)"  # ensure global uniqueness
export KV_NAME="kv-squad-$(openssl rand -hex 4)"
export IDENTITY_NAME="id-squad-workload"
export NAMESPACE="squad"

# 1. Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# 2. Create ACR
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Standard

# 3. Create AKS cluster (system pool only to start)
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count 2 \
  --node-vm-size Standard_D4s_v5 \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --attach-acr $ACR_NAME \
  --generate-ssh-keys \
  --enable-addons monitoring,azure-keyvault-secrets-provider

# 4. Create Key Vault and push secrets
az keyvault create \
  --resource-group $RESOURCE_GROUP \
  --name $KV_NAME \
  --enable-rbac-authorization

az keyvault secret set --vault-name $KV_NAME --name "squad-gh-token"        --value "$GH_TOKEN"
az keyvault secret set --vault-name $KV_NAME --name "squad-copilot-api-key" --value "$COPILOT_API_KEY"

# 5. Create Managed Identity and federate
az identity create --resource-group $RESOURCE_GROUP --name $IDENTITY_NAME
IDENTITY_CLIENT_ID=$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_NAME --query clientId -o tsv)
IDENTITY_OBJECT_ID=$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_NAME --query principalId -o tsv)
KV_ID=$(az keyvault show -g $RESOURCE_GROUP -n $KV_NAME --query id -o tsv)
OIDC_ISSUER=$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query "oidcIssuerProfile.issuerUrl" -o tsv)

az role assignment create \
  --assignee-object-id $IDENTITY_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope $KV_ID

az identity federated-credential create \
  --resource-group $RESOURCE_GROUP \
  --identity-name $IDENTITY_NAME \
  --name squad-aks-federation \
  --issuer $OIDC_ISSUER \
  --subject "system:serviceaccount:${NAMESPACE}:squad-agents" \
  --audiences "api://AzureADTokenExchange"

# 6. Get kubeconfig
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# 7. Build and push Squad container image
ACR_LOGIN_SERVER=$(az acr show -g $RESOURCE_GROUP -n $ACR_NAME --query loginServer -o tsv)
az acr login --name $ACR_NAME
IMAGE_TAG=$(git rev-parse --short HEAD)

docker build \
  -f infrastructure/k8s/Dockerfile.ralph \
  -t $ACR_LOGIN_SERVER/squad-agents:$IMAGE_TAG \
  -t $ACR_LOGIN_SERVER/squad-agents:latest .

docker push $ACR_LOGIN_SERVER/squad-agents:$IMAGE_TAG
docker push $ACR_LOGIN_SERVER/squad-agents:latest

# 8. Deploy with Helm
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace $NAMESPACE azure.workload.identity/use=true

TENANT_ID=$(az account show --query tenantId -o tsv)

helm upgrade --install squad-agents infrastructure/helm/squad-agents/ \
  --namespace $NAMESPACE \
  --atomic --timeout 5m \
  --set global.acrLoginServer=$ACR_LOGIN_SERVER \
  --set global.keyVaultName=$KV_NAME \
  --set global.tenantId=$TENANT_ID \
  --set serviceAccount.annotations."azure\.workload\.identity/client-id"=$IDENTITY_CLIENT_ID \
  --set ralph.image.tag=$IMAGE_TAG \
  --set picard.image.tag=$IMAGE_TAG \
  --set global.repository="tamirdresher_microsoft/tamresearch1"

# 9. Verify
kubectl get pods -n $NAMESPACE
kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=ralph --tail=30
kubectl get cronjob -n $NAMESPACE

echo "Squad deployed. Ralph will run on its first CronJob tick within 5 minutes."
```

---

## KAITO Consideration for LLM Inference

[KAITO (Kubernetes AI Toolchain Operator)](https://github.com/azure/kaito) can host
open-weight LLM models (Llama, Mistral, Phi) on AKS GPU node pools.

### When to use KAITO with Squad

| Scenario | KAITO | Azure OpenAI / Copilot |
|----------|-------|----------------------|
| Offline / air-gapped | ✅ | ❌ |
| Cost-sensitive at high volume | ✅ (amortized GPU) | ❌ (per-token) |
| Latest frontier models | ❌ | ✅ |
| Sub-100ms latency | ❌ (GPU cold start) | ✅ |
| Compliance (data never leaves tenant) | ✅ | Depends on config |

### KAITO workspace example

```yaml
# infrastructure/k8s/kaito-workspace.yaml
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: squad-llm
  namespace: squad
resource:
  instanceType: "Standard_NC6s_v3"
  labelSelector:
    matchLabels:
      squad.github.com/pool: gpu
inference:
  preset:
    name: "phi-3-mini-4k-instruct"   # small, fast, 4B params
```

```bash
# Install KAITO
helm repo add kaito https://azure.github.io/kaito/
helm install kaito kaito/kaito-workspace --namespace kaito-system --create-namespace

# Apply workspace
kubectl apply -f infrastructure/k8s/kaito-workspace.yaml

# Wait for GPU node provisioning (~10 min)
kubectl get workspace squad-llm -n squad -w
```

**Recommendation for issue #1060:** Start with Azure OpenAI / Copilot CLI for agent
reasoning (zero infrastructure, proven). Add KAITO for specific high-volume or
privacy-sensitive inference tasks as a later optimization.

---

## Cost Optimization

| Technique | Estimated savings | Notes |
|-----------|------------------|-------|
| Spot node pool for agent workers | 60–80% | Use `--priority Spot` on `squadagent` pool |
| Scale-to-zero with KEDA | Proportional to idle time | Picard/Seven pool scales to 0 replicas when queue empty |
| Ralph as CronJob (not Deployment) | ~1 CPU always-on → bursty | CronJob = pod only runs during 5-min window |
| ACR geo-replication only where needed | Standard tier vs Premium | Skip unless multi-region |
| Reserved Instances for system pool | ~40% | 1-year RI on system node pool VMs |
| Log Analytics retention | Volume-based | Reduce retention to 30 days for debug logs |
| Shutdown non-prod clusters at night | Dev/test only | AKS stop/start feature |

```bash
# Stop a dev cluster overnight
az aks stop --resource-group $RESOURCE_GROUP --name aks-squad-dev

# Start it back up
az aks start --resource-group $RESOURCE_GROUP --name aks-squad-dev
```

---

## Troubleshooting

### gh CLI auth fails in container
```bash
# Verify GH_TOKEN is mounted
kubectl exec -n squad <pod-name> -- env | grep GH_TOKEN
# If empty: check SecretProviderClass and CSI driver logs
kubectl logs -n kube-system -l app=csi-secrets-store-provider-azure
```

### Pod stuck in `Init:0/1`
The CSI sidecar is waiting to mount Key Vault secrets. Check:
```bash
kubectl describe pod -n squad <pod-name>
# Look for events like: "failed to mount secrets store objects"
# Usually means the Managed Identity doesn't have Key Vault Secrets User role
```

### Ralph CronJob not triggering
```bash
kubectl describe cronjob ralph -n squad
# Check "Last Schedule Time" — if it's never run, check namespace labels
kubectl get namespace squad --show-labels
# Must have: azure.workload.identity/use=true
```

### Image pull errors
```bash
kubectl describe pod -n squad <pod-name>
# If "unauthorized": re-run `az aks update --attach-acr <acr-name>`
# ACR attachment grants AcrPull to the AKS kubelet managed identity
```

---

*Generated as part of #1060 — Squad on AKS: Azure-native deployment*
*See also: #1059 (K8s architecture), #994 (Squad-on-K8s), #997 (AKS + KAITO)*
