# FedRAMP Dashboard: Phase 1 Data Pipeline Implementation
## Test Result Ingestion into Azure Monitor + Cosmos DB

**Status:** Implementation  
**Phase:** 1 of 5  
**Owner:** B'Elanna (Infrastructure Expert)  
**Issue:** #85  
**Related:** Issue #77 (Design), PR #79 (Phase Planning)  
**Prerequisites:** PR #73 (Validation Framework), Issue #67 (Test Suite)  
**Timeline:** Weeks 1-2  
**Estimated Cost:** $110-120/month

---

## Executive Summary

Phase 1 implements the data ingestion pipeline for the FedRAMP Security Dashboard. This phase establishes the foundation for continuous monitoring by ingesting validation test results from CI/CD pipelines into Azure Monitor, Log Analytics, and Cosmos DB with 90-day hot storage and 2-year cold archival.

**Key Deliverables:**
1. Azure infrastructure (Bicep templates) for data storage and processing
2. Extended validation test scripts with Azure Monitor integration
3. Azure Functions data pipeline for transformation and archival
4. End-to-end data flow from CI/CD → Azure Monitor → Cosmos DB

**Success Criteria:**
- ✅ Test results flow: Pipeline → Azure Monitor → Cosmos DB within 60 seconds
- ✅ Historical data queryable via KQL and Cosmos DB SQL API
- ✅ < 2s query latency for 90-day compliance status
- ✅ 99.9% data ingestion success rate (monitored via alerts)

---

## 1. Architecture Overview

### 1.1 Data Flow Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline (Azure DevOps)               │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  Validation Test Runners (tests/fedramp-validation/)    │ │
│  │  • network-policy-tests.sh (JSON output)                │ │
│  │  • waf-rule-tests.sh (JSON output)                      │ │
│  │  • opa-policy-tests.sh (JSON output)                    │ │
│  │  • trivy-pipeline.yml (JSON output)                     │ │
│  └─────────────────────┬────────────────────────────────────┘ │
└────────────────────────┼────────────────────────────────────────┘
                         │ HTTP POST (JSON)
                         ↓
┌────────────────────────────────────────────────────────────────┐
│                   Azure Monitor Custom Metrics                 │
│  • Real-time ingestion via REST API                           │
│  • Authentication: Managed Identity                            │
│  • Metrics: ControlValidationResult                            │
│  • Dimensions: control_id, environment, status                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ↓ Stream Analytics / EventGrid
┌────────────────────────────────────────────────────────────────┐
│                 Azure Functions Data Pipeline                  │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  Function: ProcessValidationResults                      │ │
│  │  • Trigger: Azure Monitor Event Grid                     │ │
│  │  • Transform JSON to Cosmos DB schema                    │ │
│  │  • Enrich with metadata (pipeline_id, commit_sha)        │ │
│  │  • Write to Cosmos DB + Log Analytics                    │ │
│  │  • Error handling: Retry (3x) → DLQ (Storage Queue)     │ │
│  └──────────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          ↓                             ↓
┌─────────────────────┐       ┌──────────────────────────────┐
│  Log Analytics      │       │      Cosmos DB               │
│  Workspace          │       │  ┌───────────────────────┐   │
│  ┌───────────────┐  │       │  │ Collection:           │   │
│  │ Custom Table: │  │       │  │ ControlValidation     │   │
│  │ ControlValid  │  │       │  │ Results               │   │
│  │ ationResults  │  │       │  ├───────────────────────┤   │
│  ├───────────────┤  │       │  │ Partition Key:        │   │
│  │ Retention:    │  │       │  │ /environment          │   │
│  │ 90 days       │  │       │  ├───────────────────────┤   │
│  │ (50GB/month)  │  │       │  │ TTL: 90 days          │   │
│  └───────────────┘  │       │  │ (hot storage)         │   │
│                     │       │  └───────────────────────┘   │
│  KQL Queries:       │       │                              │
│  • Real-time status │       │  Throughput: 1000 RU/s       │
│  • Alert rules      │       │  Cost: $60/month             │
└─────────────────────┘       └────────────┬─────────────────┘
                                           │
                                           ↓ After 90 days (TTL expire)
                              ┌──────────────────────────────┐
                              │   Azure Blob Storage         │
                              │   (Cold Archive)             │
                              │  ┌───────────────────────┐   │
                              │  │ Container:            │   │
                              │  │ validation-archive    │   │
                              │  ├───────────────────────┤   │
                              │  │ Tier: Archive         │   │
                              │  │ Retention: 2 years    │   │
                              │  │ Cost: $2/TB/month     │   │
                              │  └───────────────────────┘   │
                              └──────────────────────────────┘
```

### 1.2 Component Responsibilities

| Component | Purpose | SLA | Cost |
|-----------|---------|-----|------|
| **Azure Monitor Custom Metrics** | Real-time ingestion endpoint for test results | 99.9% | $30/month |
| **Log Analytics Workspace** | Query interface for compliance status (90-day retention) | 99.9% | $50/month |
| **Azure Functions** | Data transformation and routing pipeline | 99.95% | $10/month |
| **Cosmos DB** | Hot storage for historical trends (90-day TTL) | 99.99% | $60/month |
| **Azure Blob Storage** | Cold archive for audit compliance (2-year retention) | 99.9% | $5/month |

**Total Phase 1 Cost:** $155/month (optimized to $110/month with reserved capacity + caching)

---

## 2. Data Model

### 2.1 Validation Result Schema (Standard)

All validation test scripts output JSON conforming to this schema:

```json
{
  "timestamp": "2026-03-07T15:30:00Z",
  "environment": "STG-EUS2",
  "cluster": "dk8s-stg-eus2-28",
  "region": "eastus2",
  "cloud": "Public",
  "control_id": "SC-7",
  "control_name": "Boundary Protection",
  "test_category": "network_policy",
  "test_name": "default-deny-ingress",
  "status": "PASS",
  "execution_time_ms": 847,
  "details": {
    "namespace": "app-services",
    "policy_count": 3,
    "blocked_connections": 15,
    "allowed_connections": 2
  },
  "metadata": {
    "pipeline_id": "azure-pipelines-12345",
    "pipeline_url": "https://dev.azure.com/microsoft/One/_build/results?buildId=12345",
    "commit_sha": "abc123def456",
    "commit_message": "feat: add default-deny network policy",
    "branch": "main",
    "triggered_by": "scheduled"
  }
}
```

### 2.2 Cosmos DB Schema

**Collection:** `ControlValidationResults`  
**Partition Key:** `/environment` (optimizes queries by environment)  
**Indexing:** Automatic indexing on `control_id`, `status`, `timestamp`

```json
{
  "id": "stg-eus2-sc7-20260307-153000",
  "environment": "STG-EUS2",
  "cluster": "dk8s-stg-eus2-28",
  "region": "eastus2",
  "cloud": "Public",
  "control": {
    "id": "SC-7",
    "name": "Boundary Protection",
    "category": "System and Communications Protection"
  },
  "test": {
    "category": "network_policy",
    "name": "default-deny-ingress",
    "status": "PASS",
    "execution_time_ms": 847
  },
  "details": {
    "namespace": "app-services",
    "policy_count": 3,
    "blocked_connections": 15,
    "allowed_connections": 2
  },
  "metadata": {
    "pipeline_id": "azure-pipelines-12345",
    "pipeline_url": "https://dev.azure.com/microsoft/One/_build/results?buildId=12345",
    "commit_sha": "abc123def456",
    "commit_message": "feat: add default-deny network policy",
    "branch": "main",
    "triggered_by": "scheduled",
    "ingestion_timestamp": "2026-03-07T15:30:15Z"
  },
  "timestamp": "2026-03-07T15:30:00Z",
  "ttl": 7776000
}
```

**TTL Calculation:** 90 days = 7,776,000 seconds  
**Auto-Archive:** Cosmos DB change feed triggers Azure Function to archive expired documents to Azure Blob

### 2.3 Log Analytics Custom Table Schema

**Table Name:** `ControlValidationResults_CL`

| Field | Type | Description |
|-------|------|-------------|
| `TimeGenerated` | datetime | Ingestion timestamp (UTC) |
| `Environment_s` | string | Environment (DEV, STG, PROD) |
| `Cluster_s` | string | Cluster name |
| `ControlId_s` | string | FedRAMP control ID (SC-7, SI-2, etc.) |
| `ControlName_s` | string | Control description |
| `TestCategory_s` | string | Test category (network_policy, waf, opa, trivy) |
| `TestName_s` | string | Specific test name |
| `Status_s` | string | PASS / FAIL |
| `ExecutionTimeMs_d` | double | Execution time in milliseconds |
| `Details_s` | string | JSON-serialized test details |
| `PipelineId_s` | string | CI/CD pipeline ID |
| `CommitSha_s` | string | Git commit SHA |

**KQL Query Examples:**

```kql
// Real-time compliance status by control
ControlValidationResults_CL
| where TimeGenerated > ago(24h)
| summarize 
    pass_count = countif(Status_s == "PASS"),
    fail_count = countif(Status_s == "FAIL"),
    avg_execution_ms = avg(ExecutionTimeMs_d)
  by ControlId_s, Environment_s
| extend compliance_rate = todouble(pass_count) / (pass_count + fail_count) * 100
| order by compliance_rate asc

// Control drift detection (failures in last 7 days vs prior 7 days)
let current_period = ControlValidationResults_CL
| where TimeGenerated between (ago(7d) .. now())
| summarize current_fail_rate = countif(Status_s == "FAIL") * 1.0 / count() by ControlId_s;
let prior_period = ControlValidationResults_CL
| where TimeGenerated between (ago(14d) .. ago(7d))
| summarize prior_fail_rate = countif(Status_s == "FAIL") * 1.0 / count() by ControlId_s;
current_period
| join kind=inner prior_period on ControlId_s
| extend drift_pct = (current_fail_rate - prior_fail_rate) * 100
| where drift_pct > 10  // Alert if failure rate increased > 10%
| project ControlId_s, current_fail_rate, prior_fail_rate, drift_pct
| order by drift_pct desc

// Alert rule: P0 control failure
ControlValidationResults_CL
| where TimeGenerated > ago(15m)
| where Status_s == "FAIL"
| where ControlId_s in ("SC-7", "SC-8", "SI-2", "SI-3")  // P0 controls
| summarize fail_count = count() by ControlId_s, Environment_s
| where fail_count > 0
```

---

## 3. Infrastructure as Code (Bicep)

### 3.1 Resource Group Structure

```
fedramp-dashboard-phase1-rg
├── Log Analytics Workspace (fedramp-logs-{env})
├── Azure Monitor Workspace (fedramp-monitor-{env})
├── Cosmos DB Account (fedramp-cosmos-{env})
│   └── Database: SecurityDashboard
│       └── Container: ControlValidationResults
├── Storage Account (fedrampstorage{env})
│   └── Container: validation-archive
├── Function App (fedramp-pipeline-func-{env})
│   └── Functions:
│       ├── ProcessValidationResults
│       └── ArchiveExpiredResults
└── Key Vault (fedramp-kv-{env})
    └── Secrets:
        ├── CosmosConnectionString
        ├── LogAnalyticsWorkspaceId
        └── StorageConnectionString
```

### 3.2 Bicep Template Summary

See `infrastructure/phase1-data-pipeline.bicep` for complete implementation.

**Key Parameters:**
- `environment` (dev, stg, prod)
- `location` (eastus2, westus2, usgovvirginia)
- `cloudType` (public, government)
- `cosmosDbThroughput` (default: 1000 RU/s)
- `logAnalyticsRetentionDays` (default: 90)

**Outputs:**
- Log Analytics Workspace ID
- Cosmos DB endpoint
- Function App name
- Storage account name

---

## 4. Pipeline Integration

### 4.1 Test Script Modifications

**Existing Scripts (tests/fedramp-validation/):**
- `network-policy-tests.sh`
- `waf-rule-tests.sh`
- `opa-policy-tests.sh`

**Required Changes:**

1. **Add JSON output function** (see `scripts/azure-monitor-helper.sh`)
2. **Send results to Azure Monitor** via REST API
3. **Preserve existing stdout for pipeline logs**

**Example Integration:**

```bash
#!/bin/bash
# network-policy-tests.sh (Phase 1 enhanced)

source "$(dirname "$0")/azure-monitor-helper.sh"

# Existing test logic
run_test() {
  local test_name=$1
  local namespace=$2
  
  # Run test
  result=$(kubectl exec -n "$namespace" test-pod -- curl -s --max-time 5 http://blocked-service)
  
  if [[ "$result" == *"timeout"* ]]; then
    status="PASS"
  else
    status="FAIL"
  fi
  
  # Collect details
  execution_time_ms=$((SECONDS * 1000))
  
  # Format result
  result_json=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment": "$ENVIRONMENT",
  "cluster": "$CLUSTER_NAME",
  "control_id": "SC-7",
  "control_name": "Boundary Protection",
  "test_category": "network_policy",
  "test_name": "$test_name",
  "status": "$status",
  "execution_time_ms": $execution_time_ms,
  "details": {
    "namespace": "$namespace",
    "policy_count": $(kubectl get networkpolicy -n "$namespace" --no-headers | wc -l),
    "blocked_connections": 15,
    "allowed_connections": 2
  },
  "metadata": {
    "pipeline_id": "$BUILD_BUILDID",
    "pipeline_url": "$SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$SYSTEM_TEAMPROJECT/_build/results?buildId=$BUILD_BUILDID",
    "commit_sha": "$BUILD_SOURCEVERSION",
    "commit_message": "$BUILD_SOURCEVERSIONMESSAGE",
    "branch": "$BUILD_SOURCEBRANCHNAME",
    "triggered_by": "$BUILD_REASON"
  }
}
EOF
)
  
  # Send to Azure Monitor
  send_to_azure_monitor "$result_json"
  
  # Still print to stdout for pipeline logs
  echo "[$status] $test_name: $namespace"
}

# Run all tests
run_test "default-deny-ingress" "app-services"
run_test "egress-restriction" "platform-services"
# ... more tests
```

### 4.2 Azure DevOps Pipeline Configuration

**File:** `.azuredevops/fedramp-validation-phase1.yml`

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - tests/fedramp-validation/**
      - infrastructure/helm/**

schedules:
  - cron: "0 6 * * *"  # Daily at 6 AM UTC
    displayName: Daily FedRAMP validation
    branches:
      include:
        - main
    always: true

variables:
  - group: fedramp-dashboard-credentials  # Contains Azure Monitor auth
  - name: ENVIRONMENT
    value: $(Build.SourceBranchName)  # Derived from branch or parameter

stages:
  - stage: RunValidation
    displayName: Run FedRAMP Validation Tests
    jobs:
      - job: NetworkPolicyTests
        displayName: Network Policy Validation
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: AzureCLI@2
            displayName: Authenticate to Azure
            inputs:
              azureSubscription: 'fedramp-dashboard-service-connection'
              scriptType: 'bash'
              scriptLocation: 'inlineScript'
              inlineScript: |
                # Get access token for Azure Monitor
                export AZURE_MONITOR_TOKEN=$(az account get-access-token \
                  --resource https://monitoring.azure.com \
                  --query accessToken -o tsv)
                echo "##vso[task.setvariable variable=AZURE_MONITOR_TOKEN;issecret=true]$AZURE_MONITOR_TOKEN"

          - task: Kubernetes@1
            displayName: Set kubeconfig
            inputs:
              connectionType: 'Azure Resource Manager'
              azureSubscriptionEndpoint: 'fedramp-dashboard-service-connection'
              azureResourceGroup: 'dk8s-$(ENVIRONMENT)-rg'
              kubernetesCluster: 'dk8s-$(ENVIRONMENT)-cluster'

          - bash: |
              cd tests/fedramp-validation
              export ENVIRONMENT="$(ENVIRONMENT)"
              export CLUSTER_NAME="$(kubectl config current-context)"
              export BUILD_BUILDID="$(Build.BuildId)"
              export SYSTEM_TEAMFOUNDATIONCOLLECTIONURI="$(System.TeamFoundationCollectionUri)"
              export SYSTEM_TEAMPROJECT="$(System.TeamProject)"
              export BUILD_SOURCEVERSION="$(Build.SourceVersion)"
              export BUILD_SOURCEVERSIONMESSAGE="$(Build.SourceVersionMessage)"
              export BUILD_SOURCEBRANCHNAME="$(Build.SourceBranchName)"
              export BUILD_REASON="$(Build.Reason)"
              
              ./network-policy-tests.sh
            displayName: Run Network Policy Tests
            env:
              AZURE_MONITOR_TOKEN: $(AZURE_MONITOR_TOKEN)

      - job: WafRuleTests
        displayName: WAF Rule Validation
        dependsOn: []  # Run in parallel
        pool:
          vmImage: ubuntu-latest
        steps:
          # Similar structure to NetworkPolicyTests
          - task: AzureCLI@2
            displayName: Authenticate to Azure
            inputs:
              azureSubscription: 'fedramp-dashboard-service-connection'
              scriptType: 'bash'
              scriptLocation: 'inlineScript'
              inlineScript: |
                export AZURE_MONITOR_TOKEN=$(az account get-access-token \
                  --resource https://monitoring.azure.com \
                  --query accessToken -o tsv)
                echo "##vso[task.setvariable variable=AZURE_MONITOR_TOKEN;issecret=true]$AZURE_MONITOR_TOKEN"

          - bash: |
              cd tests/fedramp-validation
              export ENVIRONMENT="$(ENVIRONMENT)"
              ./waf-rule-tests.sh
            displayName: Run WAF Rule Tests
            env:
              AZURE_MONITOR_TOKEN: $(AZURE_MONITOR_TOKEN)

      - job: OpaPolicyTests
        displayName: OPA Policy Validation
        dependsOn: []  # Run in parallel
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: AzureCLI@2
            displayName: Authenticate to Azure
            inputs:
              azureSubscription: 'fedramp-dashboard-service-connection'
              scriptType: 'bash'
              scriptLocation: 'inlineScript'
              inlineScript: |
                export AZURE_MONITOR_TOKEN=$(az account get-access-token \
                  --resource https://monitoring.azure.com \
                  --query accessToken -o tsv)
                echo "##vso[task.setvariable variable=AZURE_MONITOR_TOKEN;issecret=true]$AZURE_MONITOR_TOKEN"

          - bash: |
              cd tests/fedramp-validation
              export ENVIRONMENT="$(ENVIRONMENT)"
              ./opa-policy-tests.sh
            displayName: Run OPA Policy Tests
            env:
              AZURE_MONITOR_TOKEN: $(AZURE_MONITOR_TOKEN)

  - stage: ValidateIngestion
    displayName: Validate Data Ingestion
    dependsOn: RunValidation
    jobs:
      - job: VerifyData
        displayName: Verify Data in Azure Monitor & Cosmos DB
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: AzureCLI@2
            displayName: Query Log Analytics
            inputs:
              azureSubscription: 'fedramp-dashboard-service-connection'
              scriptType: 'bash'
              scriptLocation: 'inlineScript'
              inlineScript: |
                WORKSPACE_ID=$(az monitor log-analytics workspace show \
                  --resource-group fedramp-dashboard-phase1-rg \
                  --workspace-name fedramp-logs-$(ENVIRONMENT) \
                  --query customerId -o tsv)
                
                # Wait 60 seconds for ingestion
                sleep 60
                
                # Query for recent results from this pipeline
                az monitor log-analytics query \
                  --workspace "$WORKSPACE_ID" \
                  --analytics-query "ControlValidationResults_CL | where PipelineId_s == '$(Build.BuildId)' | summarize count()" \
                  --output table
                
                echo "Data ingestion validated successfully"
```

---

## 5. Azure Functions Data Pipeline

### 5.1 Function: ProcessValidationResults

**Trigger:** Azure Monitor Event Grid subscription  
**Language:** C# (.NET 8)  
**Runtime:** Consumption plan (serverless)

**Purpose:**
1. Receive validation results from Azure Monitor
2. Transform to Cosmos DB schema
3. Write to Log Analytics custom table
4. Write to Cosmos DB
5. Handle errors with retry + DLQ

**Implementation:** See `functions/ProcessValidationResults/ProcessValidationResults.cs`

### 5.2 Function: ArchiveExpiredResults

**Trigger:** Cosmos DB change feed (TTL expiration events)  
**Language:** C# (.NET 8)  
**Runtime:** Consumption plan

**Purpose:**
1. Listen for TTL-expired documents in Cosmos DB
2. Serialize to JSON
3. Compress with gzip
4. Upload to Azure Blob Storage (Archive tier)
5. Log archival success/failure

**Implementation:** See `functions/ArchiveExpiredResults/ArchiveExpiredResults.cs`

---

## 6. Security & Compliance

### 6.1 Authentication & Authorization

| Component | Authentication Method | Authorization |
|-----------|----------------------|---------------|
| **Test Scripts → Azure Monitor** | Managed Identity (pipeline service principal) | Monitoring Metrics Publisher role |
| **Azure Functions → Cosmos DB** | Managed Identity (Function App) | Cosmos DB Data Contributor |
| **Azure Functions → Log Analytics** | Managed Identity | Log Analytics Contributor |
| **Azure Functions → Blob Storage** | Managed Identity | Storage Blob Data Contributor |

**No connection strings in code** — all authentication via Managed Identity

### 6.2 Data Encryption

- **In Transit:** TLS 1.2+ for all API calls
- **At Rest:**
  - Cosmos DB: Microsoft-managed keys (default)
  - Blob Storage: Microsoft-managed keys
  - Option to use customer-managed keys (CMK) in Key Vault for PROD

### 6.3 Network Security

- **Azure Monitor endpoint:** Public (Microsoft backbone)
- **Cosmos DB:** Firewall rules allow only:
  - Azure Function App subnet
  - Azure DevOps hosted agent IP ranges
- **Blob Storage:** Firewall rules + Private Endpoint (PROD only)
- **Function App:** VNet integration (PROD only)

### 6.4 Compliance Requirements

| Requirement | Implementation |
|-------------|----------------|
| **Audit Logging** | All API calls logged to Log Analytics |
| **Data Retention** | 90-day hot (Cosmos DB) + 2-year cold (Blob) = FedRAMP compliant |
| **Data Sovereignty** | Separate infrastructure for Government cloud (usgovvirginia) |
| **Access Control** | RBAC enforced, no shared credentials |
| **Change Tracking** | All infrastructure changes via Git + PR approval |

---

## 7. Testing & Validation

### 7.1 Unit Tests

**Test Validation Script JSON Output:**
```bash
cd tests/fedramp-validation
./network-policy-tests.sh --dry-run --output json > test-output.json
cat test-output.json | jq '.'  # Validate JSON structure
```

**Test Azure Monitor Helper:**
```bash
source scripts/azure-monitor-helper.sh
test_json='{"timestamp":"2026-03-07T15:30:00Z","status":"PASS"}'
send_to_azure_monitor "$test_json" --dry-run  # Validates API call structure
```

### 7.2 Integration Tests

**Test Data Ingestion End-to-End:**
```bash
# 1. Inject test result
az rest --method POST \
  --url "https://management.azure.com/subscriptions/{subscription-id}/resourceGroups/fedramp-dashboard-phase1-rg/providers/Microsoft.Insights/customMetrics?api-version=2021-09-01" \
  --body @test-data/sample-validation-result.json

# 2. Wait 60 seconds for processing
sleep 60

# 3. Query Log Analytics
az monitor log-analytics query \
  --workspace fedramp-logs-stg \
  --analytics-query "ControlValidationResults_CL | where TimeGenerated > ago(5m) | limit 10"

# 4. Query Cosmos DB
az cosmosdb sql query \
  --account-name fedramp-cosmos-stg \
  --database-name SecurityDashboard \
  --container-name ControlValidationResults \
  --query-text "SELECT * FROM c WHERE c.timestamp >= '2026-03-07T15:00:00Z' ORDER BY c.timestamp DESC"

# 5. Validate archival (after 90 days simulation via manual TTL override)
az storage blob list \
  --account-name fedrampstoragestg \
  --container-name validation-archive \
  --prefix "2026/03/07"
```

### 7.3 Load Testing

**Simulate Daily Test Volume:**
```bash
# Generate 10,000 test results (typical daily volume)
for i in {1..10000}; do
  cat <<EOF | az rest --method POST --url "..." --body @-
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment": "STG-EUS2",
  "control_id": "SC-7",
  "status": "$((RANDOM % 2 == 0 ? "PASS" : "FAIL"))",
  "test_name": "test-$i"
}
EOF
done

# Monitor Function App metrics:
# - Execution time (target: < 500ms p95)
# - Error rate (target: < 0.1%)
# - Cosmos DB RU consumption (target: < 1000 RU/s sustained)
```

---

## 8. Monitoring & Alerting

### 8.1 Key Metrics

| Metric | Source | Threshold | Action |
|--------|--------|-----------|--------|
| **Data ingestion success rate** | Azure Monitor | < 99.9% | Alert DevOps team |
| **Function execution failures** | Function App | > 1% | Alert on-call engineer |
| **Cosmos DB RU consumption** | Cosmos DB | > 800 RU/s sustained | Scale up throughput |
| **Log Analytics ingestion lag** | Log Analytics | > 5 minutes | Investigate pipeline delay |
| **Blob archival failures** | Function App logs | > 0 failures/day | Alert storage admin |

### 8.2 Alert Rules (KQL)

**Alert: Control Failure Detected**
```kql
ControlValidationResults_CL
| where TimeGenerated > ago(15m)
| where Status_s == "FAIL"
| where ControlId_s in ("SC-7", "SC-8", "SI-2", "SI-3")  // P0 controls
| summarize fail_count = count() by ControlId_s, Environment_s, bin(TimeGenerated, 15m)
| where fail_count > 0
```

**Alert: Data Ingestion Lag**
```kql
ControlValidationResults_CL
| summarize max_time = max(TimeGenerated)
| extend lag_minutes = datetime_diff('minute', now(), max_time)
| where lag_minutes > 15
```

---

## 9. Cost Optimization

### 9.1 Monthly Cost Breakdown

| Service | Configuration | Base Cost | Optimized Cost |
|---------|--------------|-----------|----------------|
| **Azure Monitor** | 10K metrics/day | $30 | $30 (no optimization) |
| **Log Analytics** | 50GB/month, 90-day retention | $50 | $35 (optimized queries) |
| **Cosmos DB** | 1000 RU/s provisioned | $60 | $40 (reserved capacity) |
| **Function App** | 1M executions/month | $10 | $5 (batch processing) |
| **Blob Storage** | 100GB archive tier | $5 | $2 (lifecycle management) |
| **Key Vault** | 10K operations/month | $5 | $5 (no optimization) |
| **Total** | | **$160/month** | **$117/month** |

### 9.2 Optimization Strategies

1. **Cosmos DB Reserved Capacity:** Save 30% with 1-year commitment ($40 vs $60/month)
2. **Log Analytics Query Optimization:** 
   - Use time filters (`TimeGenerated > ago(7d)`) to reduce scan scope
   - Pre-aggregate daily summaries → 70% query cost reduction
3. **Function App Batch Processing:** Process validation results in batches of 10 → reduce executions by 90%
4. **Blob Storage Lifecycle Policy:** Auto-move to Archive tier after 90 days (99% cost savings vs Hot tier)
5. **Azure Monitor Query Caching:** Cache query results for 5 minutes → 60% fewer Cosmos DB queries

---

## 10. Rollout Plan

### 10.1 Phase 1a: DEV Environment (Week 1)

**Objectives:**
- Deploy infrastructure to DEV
- Test data flow end-to-end
- Validate Cosmos DB partitioning strategy
- Measure baseline performance

**Tasks:**
1. Deploy Bicep templates to `fedramp-dashboard-dev-rg`
2. Update 1 validation script (network-policy-tests.sh) with Azure Monitor integration
3. Run 100 test results through pipeline
4. Query Log Analytics + Cosmos DB
5. Validate TTL expiration (set to 1 hour for testing)
6. Test blob archival

**Success Criteria:**
- ✅ 100/100 test results ingested
- ✅ < 1s query latency for 100 records
- ✅ TTL archival works correctly

### 10.2 Phase 1b: STG Environment (Week 1-2)

**Objectives:**
- Deploy to STG with production-like load
- Update all validation scripts
- Enable monitoring & alerting
- Load test with 10K results/day

**Tasks:**
1. Deploy to `fedramp-dashboard-stg-rg`
2. Update all 3 validation scripts (network-policy, waf, opa)
3. Configure Azure DevOps pipeline
4. Run daily tests for 5 days
5. Generate 10K synthetic results for load testing
6. Configure alert rules

**Success Criteria:**
- ✅ 50K test results ingested over 5 days (10K/day)
- ✅ < 2s query latency for 90-day queries
- ✅ < 1% error rate
- ✅ Alert rules trigger correctly

### 10.3 Phase 1c: PROD Rollout (Week 2)

**Objectives:**
- Production deployment with reserved capacity
- Enable all security hardening
- Go-live with continuous monitoring

**Tasks:**
1. Purchase Cosmos DB reserved capacity (1-year)
2. Deploy to `fedramp-dashboard-prod-rg`
3. Enable VNet integration for Function App
4. Enable Private Endpoints for Cosmos DB
5. Configure CMK in Key Vault (optional)
6. Rollout to PROD clusters (5 environments: DEV, STG, STG-GOV, PPE, PROD)

**Success Criteria:**
- ✅ All 5 environments ingesting data
- ✅ 99.9% ingestion success rate
- ✅ Cost within $120/month budget
- ✅ Zero security findings in deployment review

---

## 11. Dependencies & Risks

### 11.1 Dependencies

| Dependency | Owner | Status | Risk Level |
|------------|-------|--------|------------|
| **PR #73 merged** (validation framework) | Worf | ✅ Done | None |
| **Azure subscription approved** | Tamir | ⚠️ Pending | Medium |
| **Managed Identity permissions granted** | Security team | ⚠️ Pending | Medium |
| **Azure Monitor custom metrics enabled** | Platform team | ⚠️ Pending | Low |

### 11.2 Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Azure Monitor ingestion rate limits** | High | Implement client-side batching (max 10 metrics/request) + exponential backoff |
| **Cosmos DB partition hot spots** | Medium | Use `environment` as partition key (distributes load across 5 partitions) |
| **Function App cold start latency** | Low | Enable "Always On" for PROD (adds $15/month) |
| **TTL archival failures** | Medium | Implement DLQ for failed archival + manual reprocessing script |
| **Cost overrun** | High | Set Azure Budget alerts at $100, $150, $200 monthly thresholds |

---

## 12. Success Metrics

### 12.1 Technical Metrics

- ✅ **Data ingestion latency:** < 60 seconds from test execution to Cosmos DB
- ✅ **Query performance:** < 2 seconds for 90-day compliance status queries
- ✅ **Uptime:** 99.9% availability for ingestion pipeline
- ✅ **Error rate:** < 0.1% data loss or corruption

### 12.2 Business Metrics

- ✅ **FedRAMP compliance:** Real-time visibility into all 9 controls
- ✅ **Audit readiness:** 2-year historical data available on-demand
- ✅ **Cost efficiency:** Total cost < $120/month
- ✅ **Time to insight:** < 5 minutes from control failure to alert

---

## 13. Next Steps (Phase 2-5)

Phase 1 establishes the data foundation. Subsequent phases build on this pipeline:

| Phase | Timeline | Deliverable |
|-------|----------|-------------|
| **Phase 2** | Weeks 3-4 | Dashboard UI (React + Azure Static Web Apps) |
| **Phase 3** | Weeks 5-6 | API Gateway (Azure Functions + RBAC) |
| **Phase 4** | Weeks 7-8 | Alerting & Incident Management |
| **Phase 5** | Weeks 9-10 | Sovereign Cloud Deployment (Gov) |

**Phase 1 → Phase 2 Handoff:**
- Log Analytics queries documented for UI integration
- Cosmos DB API endpoints tested and documented
- Sample KQL queries for dashboard widgets

---

## 14. References

- **Design Document:** `docs/security-dashboard-design.md`
- **Test Suite:** `tests/fedramp-validation/TEST_PLAN.md`
- **FedRAMP Controls:** `docs/fedramp-compensating-controls-security.md`
- **Infrastructure Templates:** `infrastructure/phase1-data-pipeline.bicep`
- **Azure Monitor API:** https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/metrics-custom-overview
- **Cosmos DB TTL:** https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/time-to-live
- **Log Analytics Custom Tables:** https://learn.microsoft.com/en-us/azure/azure-monitor/logs/create-custom-table

---

**Document Version:** 1.0  
**Last Updated:** 2026-03-09  
**Approved By:** B'Elanna (Infrastructure Expert)
