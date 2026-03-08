# FedRAMP Dashboard: Production Deployment Runbook

**Phase:** 5 of 5  
**Document Version:** 1.0  
**Owner:** B'Elanna Torres (Infrastructure Expert)  
**Issue:** #88  
**Date:** March 2026  
**Status:** Ready for Production  

---

## 1. Executive Summary

This runbook provides step-by-step deployment procedures for the FedRAMP Security Dashboard across all environments (DEV → STG → STG-GOV → PPE → PROD). It includes pre-deployment checklists, deployment scripts, validation tests, and rollback procedures.

**Deployment Philosophy:**
- **Progressive Rollout:** Deploy to lower environments first, validate, then promote
- **Zero Downtime:** Use blue-green deployment with Azure Traffic Manager
- **Automated Validation:** Smoke tests run after each environment deployment
- **Fast Rollback:** < 5 minutes to rollback if critical issues detected

**Deployment Timeline:**
- DEV: 1 hour (automated, no approval required)
- STG: 2 hours (requires QA approval)
- STG-GOV: 2 hours (requires compliance approval)
- PPE: 3 hours (requires change board approval)
- PROD: 4 hours (requires executive approval + change window)

---

## 2. Pre-Deployment Checklist

### 2.1 Infrastructure Prerequisites

- [ ] Azure subscription approved and provisioned
- [ ] Azure AD tenant configured with user groups
- [ ] Azure DevOps service connection created
- [ ] Azure Key Vault provisioned with secrets:
  - `CosmosDbConnectionString`
  - `PagerDutyApiKey`
  - `TeamsWebhookUrl`
  - `SendGridApiKey`
- [ ] Managed Identities created:
  - `fedramp-dashboard-api` (API app)
  - `fedramp-dashboard-functions` (Azure Functions)
- [ ] Azure Monitor workspace created
- [ ] Log Analytics workspace created
- [ ] Application Insights instrumentation key generated
- [ ] PagerDuty integration key obtained
- [ ] Teams channel created and webhook configured

### 2.2 Code & Configuration

- [ ] All Phase 1-4 PRs merged to `main` branch
- [ ] Phase 5 PR (#88) merged to `main` branch
- [ ] Git tag created: `v1.0.0-phase5`
- [ ] Environment configuration files validated (see Section 4)
- [ ] Bicep templates validated with `az deployment validate`
- [ ] API unit tests pass (100% coverage for critical paths)
- [ ] UI unit tests pass (> 80% coverage)
- [ ] Integration tests pass on STG
- [ ] Load tests pass on STG (100 concurrent users, 5 minutes)
- [ ] Security scan pass (no High/Critical vulnerabilities)

### 2.3 Access & Approvals

- [ ] Deployment team identified:
  - **Deployment Lead:** [Name]
  - **Infrastructure Engineer:** [Name]
  - **Application Owner:** [Name]
  - **QA Lead:** [Name]
- [ ] Change ticket created in ServiceNow (for PROD)
- [ ] Production change window approved (4-hour window)
- [ ] Emergency contacts list confirmed:
  - On-call SRE: [Phone]
  - Security Admin: [Phone]
  - Azure Support: [Ticket ID]
- [ ] Rollback authorization pre-approved (< 5 min decision time)

---

## 2.4 Cache Configuration & Monitoring

- [ ] Cache hit rate SLI documentation reviewed (see `docs/fedramp-dashboard-cache-sli.md`)
- [ ] Cache hit rate alert deployed to Application Insights
- [ ] 30-day cache review scheduled (first Tuesday of each month)
- [ ] Operational team trained on cache remediation playbook

---

## 3. Deployment Environments

### 3.1 Environment Overview

| Environment | Purpose | Azure Region | Approval Required | SLA |
|-------------|---------|--------------|-------------------|-----|
| **DEV** | Development and feature testing | East US 2 | No | None |
| **STG** | Pre-production testing and UAT | East US 2 | QA Lead | None |
| **STG-GOV** | Government cloud staging | US Gov Virginia | Compliance Officer | None |
| **PPE** | Production validation environment | East US 2 | Change Board | 99.5% |
| **PROD** | Production (Commercial Cloud) | East US 2 (primary), West US 2 (failover) | Executive Sponsor | 99.9% |

### 3.2 Environment Configuration Matrix

| Component | DEV | STG | STG-GOV | PPE | PROD |
|-----------|-----|-----|---------|-----|------|
| **Cosmos DB** | Shared (400 RU) | Dedicated (1000 RU) | Dedicated Gov (1000 RU) | Dedicated (2000 RU) | Dedicated (4000 RU) |
| **Azure Functions** | Consumption | Consumption | Consumption Gov | Premium (EP1) | Premium (EP2) |
| **App Service** | B1 (Basic) | S1 (Standard) | S1 Gov | P1v2 (Premium) | P2v2 (Premium) |
| **Azure Monitor** | Shared workspace | Dedicated workspace | Dedicated Gov workspace | Dedicated workspace | Dedicated workspace + failover |
| **Backup** | None | Daily (7-day retention) | Daily (30-day retention) | Hourly (30-day retention) | Hourly (90-day retention) + geo-redundant |
| **VNet Integration** | No | No | Yes | Yes | Yes |
| **Private Endpoints** | No | No | No | Optional | Yes |
| **Disaster Recovery** | None | None | None | Active-passive (West US 2) | Active-active (West US 2) |

---

## 4. Environment Configuration Files

Configuration files are stored in `infrastructure/environments/` directory. Each environment has:
- `{env}.parameters.json` - Bicep deployment parameters
- `{env}.secrets.json` - Secrets (stored in Key Vault, never committed)
- `{env}.config.json` - Application configuration (feature flags, URLs)

### 4.1 DEV Configuration (`dev.parameters.json`)

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "dev" },
    "location": { "value": "eastus2" },
    "cosmosDbAccountName": { "value": "fedramp-dashboard-dev" },
    "cosmosDbThroughput": { "value": 400 },
    "cosmosDbEnableAutoscale": { "value": false },
    "functionAppName": { "value": "fedramp-functions-dev" },
    "functionAppSku": { "value": "Y1" },
    "appServiceName": { "value": "fedramp-api-dev" },
    "appServiceSku": { "value": "B1" },
    "storageAccountName": { "value": "fedrampstodev" },
    "storageAccountSku": { "value": "Standard_LRS" },
    "logAnalyticsWorkspaceName": { "value": "fedramp-logs-dev" },
    "applicationInsightsName": { "value": "fedramp-appinsights-dev" },
    "keyVaultName": { "value": "fedramp-kv-dev" },
    "enableVNetIntegration": { "value": false },
    "enablePrivateEndpoints": { "value": false },
    "enableBackup": { "value": false },
    "tags": {
      "value": {
        "Environment": "Development",
        "Project": "FedRAMP Dashboard",
        "Owner": "infrastructure-team@contoso.com",
        "CostCenter": "IT-Security"
      }
    }
  }
}
```

### 4.2 STG Configuration (`stg.parameters.json`)

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "stg" },
    "location": { "value": "eastus2" },
    "cosmosDbAccountName": { "value": "fedramp-dashboard-stg" },
    "cosmosDbThroughput": { "value": 1000 },
    "cosmosDbEnableAutoscale": { "value": true },
    "functionAppName": { "value": "fedramp-functions-stg" },
    "functionAppSku": { "value": "Y1" },
    "appServiceName": { "value": "fedramp-api-stg" },
    "appServiceSku": { "value": "S1" },
    "storageAccountName": { "value": "fedrampostostg" },
    "storageAccountSku": { "value": "Standard_GRS" },
    "logAnalyticsWorkspaceName": { "value": "fedramp-logs-stg" },
    "applicationInsightsName": { "value": "fedramp-appinsights-stg" },
    "keyVaultName": { "value": "fedramp-kv-stg" },
    "enableVNetIntegration": { "value": false },
    "enablePrivateEndpoints": { "value": false },
    "enableBackup": { "value": true },
    "backupRetentionDays": { "value": 7 },
    "tags": {
      "value": {
        "Environment": "Staging",
        "Project": "FedRAMP Dashboard",
        "Owner": "infrastructure-team@contoso.com",
        "CostCenter": "IT-Security"
      }
    }
  }
}
```

### 4.3 PROD Configuration (`prod.parameters.json`)

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "prod" },
    "location": { "value": "eastus2" },
    "failoverLocation": { "value": "westus2" },
    "cosmosDbAccountName": { "value": "fedramp-dashboard-prod" },
    "cosmosDbThroughput": { "value": 4000 },
    "cosmosDbEnableAutoscale": { "value": true },
    "cosmosDbEnableMultiRegion": { "value": true },
    "functionAppName": { "value": "fedramp-functions-prod" },
    "functionAppSku": { "value": "EP2" },
    "appServiceName": { "value": "fedramp-api-prod" },
    "appServiceSku": { "value": "P2v2" },
    "storageAccountName": { "value": "fedrampstoprod" },
    "storageAccountSku": { "value": "Standard_GZRS" },
    "logAnalyticsWorkspaceName": { "value": "fedramp-logs-prod" },
    "applicationInsightsName": { "value": "fedramp-appinsights-prod" },
    "keyVaultName": { "value": "fedramp-kv-prod" },
    "enableVNetIntegration": { "value": true },
    "enablePrivateEndpoints": { "value": true },
    "enableBackup": { "value": true },
    "backupRetentionDays": { "value": 90 },
    "enableGeoReplication": { "value": true },
    "trafficManagerProfileName": { "value": "fedramp-dashboard-tm" },
    "tags": {
      "value": {
        "Environment": "Production",
        "Project": "FedRAMP Dashboard",
        "Owner": "infrastructure-team@contoso.com",
        "CostCenter": "IT-Security",
        "Compliance": "FedRAMP-High"
      }
    }
  }
}
```

---

## 5. Deployment Procedures

### 5.1 DEV Deployment (Automated)

**Trigger:** Git push to `main` branch  
**Duration:** 45-60 minutes  
**Approval:** None (automated)  

#### Steps:

1. **Build & Test**
   ```powershell
   # Run from Azure DevOps pipeline
   cd infrastructure
   az deployment group validate --resource-group rg-fedramp-dev `
     --template-file main.bicep --parameters @environments/dev.parameters.json
   
   cd ../api
   dotnet test --configuration Release
   
   cd ../dashboard-ui
   npm test -- --coverage
   ```

2. **Deploy Infrastructure**
   ```powershell
   az deployment group create --resource-group rg-fedramp-dev `
     --template-file infrastructure/main.bicep `
     --parameters @infrastructure/environments/dev.parameters.json `
     --mode Incremental
   ```

3. **Deploy Application**
   ```powershell
   # Deploy Azure Functions
   cd functions
   func azure functionapp publish fedramp-functions-dev
   
   # Deploy API
   cd ../api
   dotnet publish -c Release -o ./publish
   az webapp deployment source config-zip --resource-group rg-fedramp-dev `
     --name fedramp-api-dev --src ./publish.zip
   
   # Deploy UI (Azure Static Web Apps)
   cd ../dashboard-ui
   npm run build
   az staticwebapp upload --name fedramp-ui-dev --resource-group rg-fedramp-dev `
     --source-path ./build
   ```

4. **Run Smoke Tests**
   ```powershell
   cd ../scripts/smoke-tests
   pwsh run-smoke-tests.ps1 -Environment dev
   ```

5. **Verify Deployment**
   - Check Application Insights for errors (last 5 minutes)
   - Verify API health endpoint: `https://fedramp-api-dev.azurewebsites.net/health`
   - Verify UI loads: `https://fedramp-ui-dev.azurestaticapps.net`

---

### 5.2 STG Deployment (Manual with QA Approval)

**Trigger:** Manual deployment from Azure DevOps  
**Duration:** 1.5-2 hours  
**Approval:** QA Lead sign-off required  

#### Pre-Deployment Steps:

1. **QA Approval**
   - Verify all DEV smoke tests passed
   - Review DEV deployment logs for warnings
   - Confirm no critical bugs in DEV environment
   - Sign-off in Azure DevOps: "Approved for STG deployment"

2. **Sync Database Schemas**
   ```powershell
   # Backup STG Cosmos DB before deployment
   az cosmosdb sql database backup --account-name fedramp-dashboard-stg `
     --database-name fedramp-db --backup-retention-hours 24
   
   # Apply schema migrations (if any)
   cd database/migrations
   pwsh apply-migrations.ps1 -Environment stg -DryRun
   # Review output, then run without -DryRun
   pwsh apply-migrations.ps1 -Environment stg
   ```

#### Deployment Steps:

1. **Enable Maintenance Mode**
   ```powershell
   # Set feature flag to show maintenance banner
   az appconfig kv set --name fedramp-appconfig-stg --key "MaintenanceMode" --value "true"
   ```

2. **Deploy Infrastructure** (same as DEV, use `stg.parameters.json`)

3. **Deploy Application** (same as DEV, target STG resources)

4. **Database Seeding**
   ```powershell
   # Seed STG with production-like data (anonymized)
   cd scripts
   pwsh seed-stg-database.ps1 -RecordCount 10000
   ```

5. **Run Smoke Tests**
   ```powershell
   cd scripts/smoke-tests
   pwsh run-smoke-tests.ps1 -Environment stg -Verbose
   ```

6. **Disable Maintenance Mode**
   ```powershell
   az appconfig kv set --name fedramp-appconfig-stg --key "MaintenanceMode" --value "false"
   ```

7. **Verify Deployment**
   - Run integration tests: `pwsh run-integration-tests.ps1 -Environment stg`
   - Manual exploratory testing (30 minutes)
   - Review Application Insights for anomalies

---

### 5.3 STG-GOV Deployment (Government Cloud)

**Trigger:** Manual deployment after STG validation  
**Duration:** 1.5-2 hours  
**Approval:** Compliance Officer sign-off required  

#### Pre-Deployment Steps:

1. **Compliance Review**
   - Verify STG deployment meets FedRAMP control requirements
   - Confirm no High/Critical vulnerabilities in security scan
   - Validate encryption at rest and in transit
   - Confirm audit logging enabled
   - Sign-off: "Approved for Government Cloud deployment"

2. **Switch Azure CLI Context**
   ```powershell
   # Login to Azure Government Cloud
   az cloud set --name AzureUSGovernment
   az login
   az account set --subscription "FedRAMP-Gov-Subscription"
   ```

#### Deployment Steps:

Follow same steps as STG deployment, but:
- Use `stg-gov.parameters.json` configuration
- Deploy to US Gov Virginia region
- Verify compliance with Government Cloud policies:
  - No data egress to commercial cloud
  - No third-party integrations (disable SendGrid, use gov-approved alternatives)
  - Enhanced audit logging (90-day retention minimum)

---

### 5.4 PPE Deployment (Pre-Production Environment)

**Trigger:** Manual deployment after STG-GOV validation  
**Duration:** 2-3 hours  
**Approval:** Change Board approval required  

#### Pre-Deployment Steps:

1. **Change Board Approval**
   - Submit change request 48 hours in advance
   - Include:
     - Deployment plan
     - Rollback plan
     - Risk assessment
     - Test results from STG/STG-GOV
   - Present to Change Advisory Board (CAB)
   - Obtain approval

2. **Production Data Validation**
   ```powershell
   # Sync anonymized production data to PPE
   cd scripts
   pwsh sync-prod-data-to-ppe.ps1 -AnonymizePII -RecordLimit 50000
   ```

#### Deployment Steps:

1. **Blue-Green Deployment Setup**
   ```powershell
   # Create "green" slot for new deployment
   az webapp deployment slot create --resource-group rg-fedramp-ppe `
     --name fedramp-api-ppe --slot green
   ```

2. **Deploy to Green Slot**
   ```powershell
   # Deploy API to green slot
   az webapp deployment source config-zip --resource-group rg-fedramp-ppe `
     --name fedramp-api-ppe --slot green --src ./publish.zip
   ```

3. **Smoke Test Green Slot**
   ```powershell
   cd scripts/smoke-tests
   pwsh run-smoke-tests.ps1 -Environment ppe -Slot green
   ```

4. **Traffic Shift (10% → 50% → 100%)**
   ```powershell
   # Shift 10% traffic to green slot
   az webapp traffic-routing set --resource-group rg-fedramp-ppe `
     --name fedramp-api-ppe --distribution green=10
   
   # Monitor for 15 minutes
   Start-Sleep -Seconds 900
   
   # Check error rate
   $errorRate = az monitor metrics list --resource fedramp-api-ppe `
     --metric "Http5xx" --interval PT5M --query "value[0].timeseries[0].data[-1].total"
   
   if ($errorRate -lt 5) {
     # Shift 50% traffic
     az webapp traffic-routing set --resource-group rg-fedramp-ppe `
       --name fedramp-api-ppe --distribution green=50
     
     # Monitor for 15 minutes
     Start-Sleep -Seconds 900
     
     # Full cutover
     az webapp deployment slot swap --resource-group rg-fedramp-ppe `
       --name fedramp-api-ppe --slot green --target-slot production
   } else {
     Write-Error "High error rate detected. Aborting deployment."
     # Rollback (see Section 6)
   }
   ```

5. **Verify Deployment**
   - Run full integration test suite (1 hour)
   - Load test (100 concurrent users, 30 minutes)
   - Security scan (OWASP ZAP or Burp Suite)

---

### 5.5 PROD Deployment (Production)

**Trigger:** Manual deployment during approved change window  
**Duration:** 3-4 hours  
**Approval:** Executive Sponsor + Change Manager  

#### Pre-Deployment Steps:

1. **Executive Approval**
   - Present PPE test results to executive sponsor
   - Confirm change window (e.g., Saturday 2:00 AM - 6:00 AM EST)
   - Obtain sign-off: "Approved for Production deployment"

2. **Pre-Deployment Communication**
   - Send notification to all stakeholders 48 hours in advance
   - Post maintenance window in Teams (#fedramp-announce)
   - Update status page: "Scheduled Maintenance"

3. **Backup Production Database**
   ```powershell
   # Full backup of Cosmos DB
   az cosmosdb sql database backup --account-name fedramp-dashboard-prod `
     --database-name fedramp-db --backup-retention-hours 72
   
   # Export to Azure Blob Storage (additional safety)
   cd scripts
   pwsh backup-cosmos-to-blob.ps1 -Environment prod
   ```

#### Deployment Steps:

1. **Enable Maintenance Mode**
   ```powershell
   az appconfig kv set --name fedramp-appconfig-prod --key "MaintenanceMode" --value "true"
   
   # Update status page
   curl -X POST https://status.contoso.com/api/incidents \
     -H "Authorization: Bearer $STATUS_PAGE_API_KEY" \
     -d '{"status": "maintenance", "message": "FedRAMP Dashboard deployment in progress"}'
   ```

2. **Deploy Infrastructure (Zero-Downtime)**
   ```powershell
   # Deploy infrastructure changes (Bicep incremental mode)
   az deployment group create --resource-group rg-fedramp-prod `
     --template-file infrastructure/main.bicep `
     --parameters @infrastructure/environments/prod.parameters.json `
     --mode Incremental
   ```

3. **Blue-Green Deployment**
   - Follow same blue-green process as PPE (Section 5.4)
   - Traffic shift: 5% → 10% → 25% → 50% → 100%
   - Monitor for 15 minutes at each stage

4. **Deploy to Failover Region (West US 2)**
   ```powershell
   # Deploy to secondary region (active-active)
   az deployment group create --resource-group rg-fedramp-prod-westus2 `
     --template-file infrastructure/main.bicep `
     --parameters @infrastructure/environments/prod-westus2.parameters.json `
     --mode Incremental
   
   # Update Traffic Manager weights (East US 2: 80%, West US 2: 20%)
   az network traffic-manager endpoint update --resource-group rg-fedramp-prod `
     --profile-name fedramp-dashboard-tm --name endpoint-eastus2 --weight 80
   az network traffic-manager endpoint update --resource-group rg-fedramp-prod `
     --profile-name fedramp-dashboard-tm --name endpoint-westus2 --weight 20
   ```

5. **Database Migration (if required)**
   ```powershell
   # Run database migrations (zero-downtime)
   cd database/migrations
   pwsh apply-migrations.ps1 -Environment prod -ZeroDowntime
   ```

6. **Run Smoke Tests**
   ```powershell
   cd scripts/smoke-tests
   pwsh run-smoke-tests.ps1 -Environment prod -Verbose -IncludeFailoverRegion
   ```

7. **Disable Maintenance Mode**
   ```powershell
   az appconfig kv set --name fedramp-appconfig-prod --key "MaintenanceMode" --value "false"
   
   # Update status page
   curl -X POST https://status.contoso.com/api/incidents \
     -H "Authorization: Bearer $STATUS_PAGE_API_KEY" \
     -d '{"status": "operational", "message": "FedRAMP Dashboard deployment complete"}'
   ```

8. **Post-Deployment Monitoring (4 hours)**
   - Monitor Application Insights for errors (target: < 0.1% error rate)
   - Monitor Cosmos DB RU consumption (target: < 80% of provisioned)
   - Monitor API response times (target: p95 < 500ms)
   - Monitor alert delivery times (target: < 60 seconds)
   - On-call SRE standby for 4 hours post-deployment

9. **Post-Deployment Communication**
   - Send "Deployment Successful" notification to stakeholders
   - Update status page: "All Systems Operational"
   - Post summary in Teams (#fedramp-announce)

---

## 6. Rollback Procedures

### 6.1 Rollback Decision Criteria

Initiate rollback if ANY of the following occur within 1 hour of deployment:

- **Critical:** API unavailable (> 5% error rate)
- **Critical:** Database corruption or data loss detected
- **Critical:** Security vulnerability introduced
- **High:** Alert delivery failure rate > 10%
- **High:** Dashboard UI completely broken
- **High:** Performance degradation > 50% (p95 response time)

### 6.2 API Rollback (Blue-Green Slot Swap)

**Duration:** < 2 minutes

```powershell
# Immediately swap back to blue (previous) slot
az webapp deployment slot swap --resource-group rg-fedramp-{env} `
  --name fedramp-api-{env} --slot production --target-slot green

# Verify rollback successful
cd scripts/smoke-tests
pwsh run-smoke-tests.ps1 -Environment {env}
```

### 6.3 Database Rollback (Restore from Backup)

**Duration:** 5-30 minutes (depends on database size)

```powershell
# Option 1: Point-in-time restore (Cosmos DB automatic backup)
az cosmosdb sql database restore --account-name fedramp-dashboard-{env} `
  --database-name fedramp-db --restore-timestamp "2026-03-08T01:00:00Z"

# Option 2: Restore from manual backup (Azure Blob Storage)
cd scripts
pwsh restore-cosmos-from-blob.ps1 -Environment {env} -BackupTimestamp "2026-03-08T01:00:00Z"
```

### 6.4 Infrastructure Rollback (Bicep Re-Deployment)

**Duration:** 10-20 minutes

```powershell
# Re-deploy previous Bicep template (tagged version)
git checkout v1.0.0-phase4
cd infrastructure
az deployment group create --resource-group rg-fedramp-{env} `
  --template-file main.bicep --parameters @environments/{env}.parameters.json `
  --mode Complete
```

### 6.5 Full System Rollback

**Duration:** < 15 minutes

```powershell
# Execute full rollback script
cd scripts
pwsh full-rollback.ps1 -Environment {env} -BackupTimestamp "2026-03-08T01:00:00Z"
```

The script performs:
1. Slot swap (API rollback)
2. UI rollback (re-deploy previous Static Web App version)
3. Database restore (point-in-time)
4. Infrastructure rollback (Bicep re-deployment)
5. Smoke test validation
6. Notification to stakeholders

### 6.6 Post-Rollback Actions

1. **Incident Report**
   - Document reason for rollback
   - Root cause analysis (RCA) within 24 hours
   - Corrective action plan

2. **Communication**
   - Notify stakeholders of rollback
   - Update status page
   - Schedule post-mortem meeting

3. **Re-Deployment Planning**
   - Fix identified issues
   - Re-test in STG/PPE
   - Schedule new deployment window

---

## 7. Monitoring & Alerts

### 7.1 Deployment Health Dashboard

Create Azure Dashboard with following tiles:

1. **API Health**
   - HTTP 2xx/4xx/5xx counts (last 1 hour)
   - Response time (p50, p95, p99)
   - Request throughput (requests/minute)

2. **Database Health**
   - Cosmos DB RU consumption (%)
   - Storage size (GB)
   - Query latency (ms)

3. **Azure Functions**
   - Execution count (last 1 hour)
   - Failure rate (%)
   - Execution duration (avg)

4. **Alert Delivery**
   - PagerDuty delivery success rate (%)
   - Teams delivery success rate (%)
   - Alert processing latency (seconds)

### 7.2 Critical Alerts

Configure Azure Monitor alerts for:

| Alert | Threshold | Severity | Action |
|-------|-----------|----------|--------|
| API Error Rate | > 5% in 5 minutes | Critical | Page on-call SRE |
| API Response Time | p95 > 1000ms in 10 minutes | High | Teams notification |
| Cosmos DB RU | > 90% for 15 minutes | High | Teams notification |
| Function Failures | > 10% in 5 minutes | High | Teams notification |
| Alert Delivery Failure | > 5 failures in 15 minutes | Critical | Page on-call SRE |

---

## 8. Post-Deployment Validation

### 8.1 Immediate Validation (15 minutes)

```powershell
# Run comprehensive smoke tests
cd scripts/smoke-tests
pwsh run-smoke-tests.ps1 -Environment {env} -Verbose -IncludePerformance

# Expected output:
# ✅ API health endpoint responding (200 OK)
# ✅ Database connectivity test passed
# ✅ UI loads within 2 seconds
# ✅ Authentication flow works
# ✅ Sample API requests succeed (GET /api/controls, POST /api/alerts)
# ✅ Alert test delivered to Teams
```

### 8.2 Extended Validation (1 hour)

- Run integration test suite (30 test scenarios)
- Monitor Application Insights for exceptions
- Review deployment logs for warnings
- Verify all Azure Functions triggered successfully
- Check PagerDuty for test alerts

### 8.3 Production Validation (24 hours)

- Monitor error rates (target: < 0.1%)
- Monitor performance (target: p95 < 500ms)
- Monitor Cosmos DB RU consumption (target: < 80%)
- Monitor alert delivery success rate (target: > 99.9%)
- Review user feedback from Teams channel

---

## 9. Cache Management Operations

### 9.1 Overview

The FedRAMP Dashboard API implements HTTP response caching with a 60-second TTL for status endpoints and 300-second TTL for trend endpoints. This section provides operational procedures for cache monitoring and management.

**Reference Documentation:** `docs/fedramp-dashboard-cache-sli.md`

### 9.2 Cache SLI & SLO

**Service Level Indicator (SLI):** Cache Hit Rate  
**Service Level Objective (SLO):** ≥ 70% cache hit rate (24-hour rolling window)

**Impact:**
- Expected performance: 80-85% cache hit rate under normal load
- Backend query reduction: 80-85%
- Latency improvement: 20-30% (P95 < 500ms)

### 9.3 Monitoring Cache Performance

**View Cache Hit Rate (Last 24 Hours):**
```powershell
# Query Application Insights
$query = @"
requests
| where timestamp > ago(24h) and name has "compliance"
| extend IsCacheHit = iff(duration < 100, 1, 0)
| summarize CacheHits = sum(IsCacheHit), Total = count()
| extend HitRate = round((CacheHits * 100.0) / Total, 2)
"@

az monitor app-insights query `
  --app appi-fedramp-dashboard-prod `
  --analytics-query $query
```

**Check Alert Status:**
```powershell
# List active cache-related alerts
az monitor alert list `
  --resource-group rg-fedramp-dashboard-prod `
  --query "[?contains(name, 'Cache')]"
```

### 9.4 Cache Troubleshooting

**Symptom:** Cache hit rate < 70% alert triggered

**Investigation Steps:**
1. Check if recent deployment cleared cache (expected behavior, resolves in 15-30 min)
2. Analyze request patterns for unusual diversity
3. Review recent changes to query parameters
4. Check for bot/scraper traffic patterns

**Emergency Cache Clear (Last Resort):**
```powershell
# Restart API pods to clear in-memory cache
kubectl rollout restart deployment/fedramp-dashboard-api -n fedramp-dashboard

# Verify pods restarted
kubectl get pods -n fedramp-dashboard -w
```

**⚠️ Warning:** Cache clear impacts all users temporarily (expect 5-10% error rate spike for 1-2 minutes)

### 9.5 Monthly Cache Review

**Schedule:** First Tuesday of each month, 10 AM PT  
**Duration:** 30 minutes  
**Attendees:** Data (Code Expert), SRE On-Call, Infrastructure Lead

**Review Checklist:**
- [ ] Review 30-day cache hit rate trend (target: ≥70%)
- [ ] Analyze top 10 query parameter combinations
- [ ] Assess backend query reduction (target: 80-85%)
- [ ] Check Cosmos DB RU savings
- [ ] Identify optimization opportunities
- [ ] Update cache configuration if needed (document in Issue/PR)
- [ ] Archive review summary: `docs/fedramp/cache-reviews/YYYY-MM.md`

**Review Template:**
```markdown
## Cache Configuration Review - [Month Year]
Date: [Date]
Attendees: [Names]

### Metrics (30-day window)
- Cache Hit Rate: [X]% (Target: ≥70%)
- P95 Latency: [X]ms (Cached: [X]ms, Uncached: [X]ms)
- Backend Query Reduction: [X]%
- Cosmos DB RU Savings: [X] RU/month

### Observations
- [Observation 1]
- [Observation 2]

### Recommendations
- [ ] Action 1: [Description] (Owner: [Name], Due: [Date])

### Next Review
Date: [First Tuesday of next month]
```

---

## 10. Deployment Contacts

| Role | Name | Email | Phone | Availability |
|------|------|-------|-------|--------------|
| **Deployment Lead** | [Name] | [Email] | [Phone] | Primary contact during deployment |
| **Infrastructure Engineer** | B'Elanna Torres | belanna@contoso.com | [Phone] | Azure infrastructure issues |
| **Application Owner** | [Name] | [Email] | [Phone] | API/UI issues |
| **Database Admin** | [Name] | [Email] | [Phone] | Cosmos DB issues |
| **QA Lead** | [Name] | [Email] | [Phone] | Test validation |
| **Security Lead** | Worf | worf@contoso.com | [Phone] | Security issues |
| **On-Call SRE** | [Name] | [Email] | [Phone] | Incident response |

---

## 11. Appendix

### 11.1 Deployment Checklist (Quick Reference)

**Pre-Deployment:**
- [ ] Code merged and tagged
- [ ] Tests passed in lower environments
- [ ] Approval obtained
- [ ] Change window scheduled
- [ ] Backup completed

**Deployment:**
- [ ] Maintenance mode enabled
- [ ] Infrastructure deployed
- [ ] Application deployed
- [ ] Smoke tests passed
- [ ] Maintenance mode disabled

**Post-Deployment:**
- [ ] Monitoring enabled
- [ ] Extended validation completed
- [ ] Stakeholders notified
- [ ] Documentation updated

### 10.2 Common Issues & Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Cosmos DB connection timeout** | API returns 500 errors | Verify Cosmos DB firewall allows App Service IP |
| **Key Vault access denied** | Application fails to start | Verify Managed Identity has "Key Vault Secrets User" role |
| **Function cold start timeout** | First request takes > 5 seconds | Enable "Always On" for Premium plan |
| **UI not loading** | Browser shows 404 error | Clear CDN cache, verify Static Web App deployment |
| **Alerts not delivering** | PagerDuty/Teams not receiving alerts | Verify webhook URLs in Key Vault, check network firewall |

### 10.3 Useful Commands

```powershell
# Check deployment status
az deployment group show --resource-group rg-fedramp-{env} --name main

# View App Service logs
az webapp log tail --resource-group rg-fedramp-{env} --name fedramp-api-{env}

# View Function logs
func azure functionapp logstream fedramp-functions-{env}

# Query Application Insights
az monitor app-insights query --app fedramp-appinsights-{env} --analytics-query "requests | where timestamp > ago(1h) | summarize count() by resultCode"

# Check Cosmos DB metrics
az cosmosdb show --resource-group rg-fedramp-{env} --name fedramp-dashboard-{env} --query "{ RU: '{consistencyPolicy.maxIntervalInSeconds}', Storage: '{documentEndpoint}' }"
```

---

**End of Deployment Runbook**

For questions or issues during deployment, contact the Deployment Lead or reference the troubleshooting guide in Confluence.
