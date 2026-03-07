# FedRAMP Dashboard Phase 1: Data Pipeline Implementation

## Overview

This directory contains the complete implementation for Phase 1 of the FedRAMP Security Dashboard: Data Pipeline Ingestion into Azure Monitor and Cosmos DB.

## Directory Structure

```
.
├── docs/
│   └── fedramp-dashboard-phase1-data-pipeline.md  # Complete technical documentation
├── infrastructure/
│   ├── phase1-data-pipeline.bicep                 # Azure infrastructure (Bicep template)
│   └── deploy-phase1.ps1                          # Deployment script
├── scripts/
│   └── azure-monitor-helper.sh                    # Bash helper for test integration
├── functions/
│   ├── ProcessValidationResults.cs                # Azure Function: data pipeline
│   ├── ArchiveExpiredResults.cs                   # Azure Function: cold archival
│   ├── FedRampDashboard.Functions.csproj         # .NET project file
│   └── host.json                                  # Function App configuration
└── .azuredevops/
    └── fedramp-validation-phase1.yml              # CI/CD pipeline configuration

## Quick Start

### 1. Deploy Infrastructure

```powershell
# Deploy to DEV environment
cd infrastructure
.\deploy-phase1.ps1 -Environment dev -Location eastus2

# Deploy to PROD environment with reserved capacity
.\deploy-phase1.ps1 -Environment prod -Location eastus2 -EnableCosmosReservedCapacity
```

### 2. Deploy Azure Functions

```bash
# Build and publish functions
cd functions
dotnet build
func azure functionapp publish fedramp-pipeline-func-<env>
```

### 3. Configure CI/CD Pipeline

1. Create Azure DevOps variable group: `fedramp-dashboard-credentials`
2. Add service connection: `fedramp-dashboard-service-connection`
3. Import pipeline: `.azuredevops/fedramp-validation-phase1.yml`
4. Run pipeline to validate setup

### 4. Run Validation Tests

```bash
# Manual test run
cd tests/fedramp-validation

# Set environment variables
export ENVIRONMENT=dev
export CLUSTER_NAME=$(kubectl config current-context)
export AZURE_MONITOR_TOKEN=$(az account get-access-token --resource https://monitoring.azure.com --query accessToken -o tsv)
export AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export AZURE_RESOURCE_GROUP=fedramp-dashboard-phase1-dev-rg

# Source helper functions
source ../../scripts/azure-monitor-helper.sh

# Test connectivity
test_azure_monitor_connectivity

# Run tests (these will now send results to Azure Monitor)
./network-policy-tests.sh
./waf-rule-tests.sh
./opa-policy-tests.sh
```

### 5. Query Results

**Log Analytics (KQL):**
```bash
az monitor log-analytics query \
  --workspace fedramp-logs-dev \
  --analytics-query "ControlValidationResults_CL | where TimeGenerated > ago(24h) | summarize pass=countif(Status_s=='PASS'), fail=countif(Status_s=='FAIL') by ControlId_s"
```

**Cosmos DB:**
```bash
az cosmosdb sql query \
  --account-name fedramp-cosmos-dev \
  --database-name SecurityDashboard \
  --container-name ControlValidationResults \
  --query-text "SELECT c.control.id, c.test.status, c.timestamp FROM c WHERE c.timestamp >= '2026-03-07T00:00:00Z' ORDER BY c.timestamp DESC"
```

## Key Features

✅ **Infrastructure as Code** — Full Bicep templates for reproducible deployments  
✅ **Managed Identity** — No connection strings, all auth via Azure AD  
✅ **Data Lifecycle** — 90-day hot storage (Cosmos DB) + 2-year cold archive (Blob)  
✅ **Cost Optimized** — $110-120/month with reserved capacity and caching  
✅ **CI/CD Integrated** — Azure DevOps pipeline with automatic validation  
✅ **Security Hardened** — TLS 1.2+, RBAC, firewall rules, Key Vault secrets  

## Architecture

```
CI/CD Pipeline (Azure DevOps)
  ↓ (JSON via REST API)
Azure Monitor Custom Metrics
  ↓ (Event Grid trigger)
Azure Functions (ProcessValidationResults)
  ↓ (parallel write)
  ├─→ Log Analytics (90-day query interface)
  └─→ Cosmos DB (90-day hot + TTL archival)
       ↓ (TTL expiration)
     Azure Functions (ArchiveExpiredResults)
       ↓
     Azure Blob Storage (2-year cold archive)
```

## Cost Breakdown

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| Azure Monitor | 10K metrics/day | $30 |
| Log Analytics | 50GB, 90-day retention | $50 |
| Cosmos DB | 1000 RU/s (reserved) | $40 |
| Azure Functions | 1M executions | $10 |
| Blob Storage | 100GB archive | $2 |
| **Total** | | **$132/month** |

*Optimized from $160/month base cost*

## Dependencies

**Required:**
- Azure subscription with Owner/Contributor role
- Azure CLI (`az`) version 2.50+
- kubectl (for Kubernetes test validation)
- .NET 8 SDK (for Azure Functions)
- Azure Functions Core Tools (`func`)

**Optional:**
- PowerShell 7+ (for deployment script)
- jq (for JSON processing in bash scripts)

## Security & Compliance

✅ **FedRAMP HIGH Controls:** Supports 9 controls (SC-7, SC-8, SI-2, SI-3, RA-5, CM-3, IR-4, AC-3, CM-7)  
✅ **Data Retention:** 90-day operational + 2-year audit compliance  
✅ **Encryption:** TLS 1.2+ in-transit, Microsoft-managed keys at-rest  
✅ **Authentication:** Managed Identity only, no shared credentials  
✅ **Network Security:** Firewall rules, VNet integration (PROD), Private Endpoints (optional)  
✅ **Audit Logging:** All API calls logged to Log Analytics  

## Next Steps

- **Phase 2 (Weeks 3-4):** Dashboard UI (React + Azure Static Web Apps)
- **Phase 3 (Weeks 5-6):** API Gateway with RBAC
- **Phase 4 (Weeks 7-8):** Alerting & Incident Management
- **Phase 5 (Weeks 9-10):** Sovereign Cloud Deployment (Gov)

## Support

**Documentation:** `docs/fedramp-dashboard-phase1-data-pipeline.md`  
**Issue:** #85  
**Related:** Issue #77 (Design), PR #79 (Phase Planning)  
**Owner:** B'Elanna (Infrastructure Expert)

---

**Version:** 1.0  
**Last Updated:** 2026-03-09  
**Status:** ✅ Implementation Complete
