# Infrastructure Review: Azure Monitor Prometheus Integration (Issue #150)

**Reviewer:** B'Elanna (Infrastructure Expert)  
**Date:** 2026-03-12  
**Scope:** Infrastructure/K8s/Cluster Provisioning Perspective  
**PRs Reviewed:**
- PR #14966543 (Infra.K8s.Clusters) — Add AZURE_MONITOR_SUBSCRIPTION_ID to Tenants.json
- PR #14968397 (WDATP.Infra.System.Cluster) — ARM templates + GoTemplates + Ev2 specs
- PR #14968532 (WDATP.Infra.System.ClusterProvisioning) — Pipeline stage integration

---

## Executive Summary

**VERDICT: ✅ APPROVE with 4 MINOR CONCERNS**

This is a **well-architected infrastructure integration** that follows DK8S deployment patterns correctly. The three-repo split (inventory → ARM templates → pipeline) is the standard Ev2 deployment model for DK8S. The addition of Azure Monitor Prometheus capability is properly feature-gated, uses per-region shared resources, and integrates cleanly into the cluster provisioning flow.

**Strengths:**
- ✅ Follows DK8S inventory schema extension patterns
- ✅ ARM templates use conditional deployment with feature flags correctly
- ✅ Pipeline stage ordering is correct (AzureMonitoring_ after Cluster_, before dependent stages)
- ✅ Uses shared per-region resources (DCE, DCR, AMW from ManagedPrometheus repo)
- ✅ Rollback script validates flag-vs-reality mismatches

**Minor Concerns (Non-Blocking):**
1. **AMPLS Private Endpoint DNS:** Verify DNS zone links to VNet correctly
2. **Role Assignment Timing:** Ensure Monitoring Metrics Publisher assignment succeeds before metrics ingestion
3. **Rollback Script Scope:** AzureMonitoringValidation.sh only checks flag state, doesn't rollback ARM resources
4. **Pipeline Parallelization Opportunity:** AzureMonitoring_ stage could run in parallel with other post-Cluster_ stages

---

## 1. Ev2 Deployment Pattern Compliance

**ASSESSMENT: ✅ FULLY COMPLIANT**

### 1.1 Three-Repo Pattern (Standard DK8S Model)

The PR follows the canonical DK8S Ev2 deployment pattern:

1. **Inventory Repo (Infra.K8s.Clusters):** Schema + tenant configuration
2. **ARM Template Repo (WDATP.Infra.System.Cluster):** ARM/Bicep resources + GoTemplates
3. **Pipeline Repo (WDATP.Infra.System.ClusterProvisioning):** Ev2 orchestration YAML

This matches the pattern used for ACR_SUBSCRIPTION, Karpenter, ArgoCD, and other cluster-level features.

### 1.2 RolloutSpec Variants (PR #14968397)

Three rollout spec variants provided:

1. **Per-Cluster RolloutSpec** (`RolloutSpec.AzureMonitoring.Metrics.PerCluster.json`)
   - One deployment per cluster
   - Use case: Cluster-specific metrics configuration

2. **Per-Tenant RolloutSpec** (`RolloutSpec.AzureMonitoring.Metrics.PerTenant.json`)
   - One deployment per tenant
   - Use case: Tenant-wide metrics aggregation

3. **Per-ServiceTree RolloutSpec** (`RolloutSpec.AzureMonitoring.Metrics.PerServiceTree.json`)
   - One deployment per service tree
   - Use case: Organization-wide metrics aggregation

**Pattern Assessment:** ✅ This follows the DK8S multi-scope deployment model. Similar to how Karpenter and ArgoCD provide multiple rollout scopes.

### 1.3 ServiceModel Variants (PR #14968397)

Three service model variants provided to match the rollout specs:

- `ServiceModel.AzureMonitoring.Metrics.PerCluster.json`
- `ServiceModel.AzureMonitoring.Metrics.PerTenant.json`
- `ServiceModel.AzureMonitoring.Metrics.PerServiceTree.json`

**Pattern Assessment:** ✅ ServiceModels correctly reference the corresponding RolloutSpecs. This is standard Ev2 mapping.

### 1.4 GoTemplate Parameter Files (PR #14968397)

GoTemplates generate dynamic parameters from cluster inventory:

- `Parameters.AzureMonitoring.Metrics.json` — Base parameter template
- Uses `{{ .Tenant.AzureMonitorSubscriptionId }}` from inventory
- Uses `{{ .Cluster.Name }}` for resource association

**Pattern Assessment:** ✅ Follows DK8S GoTemplate conventions. Correctly reads from Tenant-level inventory field.

### 1.5 ScopeBindings Update (PR #14968397)

Added `AzureMonitoringValidation` to ScopeBindings configuration to run validation script during Ev2 deployment.

**Pattern Assessment:** ✅ Standard mechanism for running pre/post-deployment validation in DK8S.

**MINOR CONCERN 1:** The validation script (`AzureMonitoringValidation.sh`) appears to only check flag state vs. reality, not perform rollback actions. Clarify if Ev2 expects this script to:
- (a) Only validate and exit non-zero on mismatch (detection only)
- (b) Actively rollback resources if flag=false but monitoring enabled (remediation)

If (a), naming is correct. If (b), script needs rollback logic added.

---

## 2. ARM Template Design Assessment

**ASSESSMENT: ✅ GOOD with 1 NETWORKING CONCERN**

### 2.1 Resource Naming Conventions (Template.AzureMonitoring.Metrics.json)

**Expected Pattern (from DK8S standards):**
```
{prefix}-{component}-{environment}-{region}-{cluster}
```

**Observed Naming:**
- DCR Association: `dcra-{clusterName}-{dcrName}` ✅
- AMPLS: `ampls-{clusterName}-{region}` ✅
- Private Endpoint: `pe-{clusterName}-ampls` ✅
- DNS Zone: `privatelink.monitor.azure.com` ✅ (Standard Azure naming)

**Assessment:** ✅ Naming follows DK8S conventions. Uses cluster name as primary identifier.

### 2.2 Parameter Handling

**Required Parameters:**
- `clusterName` (string)
- `location` (string)
- `azureMonitorSubscriptionId` (string) — From Tenants.json
- `dceName` (string) — From shared ManagedPrometheus repo
- `dcrName` (string) — From shared ManagedPrometheus repo
- `amwName` (string) — From shared ManagedPrometheus repo

**Feature Gate:**
- `enableAzureMonitoring` (bool) — Controls conditional deployment

**Assessment:** ✅ All parameters are well-documented and sourced from inventory or shared resources.

### 2.3 Conditional Deployment with Feature Flags

**Pattern Observed:**
```json
"condition": "[parameters('enableAzureMonitoring')]"
```

Applied to:
- DCR Association resource
- AMPLS resource
- Private Endpoint resource
- DNS Zone Group resource
- AKS metrics profile update

**Assessment:** ✅ This is the correct ARM/Bicep pattern for feature gating. If `enableAzureMonitoring` is false, resources are not deployed. This matches how DK8S handles optional features like Karpenter, ArgoCD, and private endpoints.

### 2.4 AKS Metrics Profile Injection

**Pattern:**
```json
"azureMonitorProfile": {
  "metrics": {
    "enabled": "[parameters('enableAzureMonitoring')]",
    "kubeStateMetrics": {
      "metricLabelsAllowlist": "*",
      "metricAnnotationsAllowList": "*"
    }
  }
}
```

**Assessment:** ✅ This updates the AKS cluster resource to enable the managed Prometheus metrics profile. Correct approach for Azure Monitor Prometheus integration.

### 2.5 Role Assignment Template (Template.AzureMonitoring.Metrics.RoleAssignment.json)

**Role Assigned:** `Monitoring Metrics Publisher`  
**Principal:** AKS cluster managed identity  
**Scope:** Azure Monitor Workspace (AMW)

**Assessment:** ✅ Correct RBAC for allowing AKS to publish metrics to Azure Monitor Workspace.

**MINOR CONCERN 2:** Role assignment timing is critical. If the role assignment is not complete before metrics start flowing, ingestion will fail. Verify that:
- Ev2 deployment stages wait for role propagation (typically 30-60 seconds)
- Or pipeline includes retry logic for metrics ingestion
- Or AKS metrics profile doesn't enable until role assignment completes

Recommend adding `dependsOn` in ARM template or Ev2 stage ordering to ensure role assignment completes before metrics profile activation.

---

## 3. AMPLS + Private Endpoint Networking Assessment

**ASSESSMENT: ⚠️ GOOD with 1 DNS CONCERN**

### 3.1 AMPLS (Azure Monitor Private Link Scope)

**Resource Created:**
- AMPLS instance per cluster
- Links to shared DCE, DCR, AMW (from ManagedPrometheus repo)

**Assessment:** ✅ AMPLS is the correct pattern for private endpoint connectivity to Azure Monitor. Using shared per-region resources (DCE, DCR, AMW) is efficient and follows Azure best practices.

### 3.2 Private Endpoint Configuration

**Private Endpoint Created:**
- Targets AMPLS resource
- Deployed in AKS cluster VNet/subnet
- Uses `groupIds: ['azuremonitor']`

**Assessment:** ✅ Correct configuration. Private endpoint for AMPLS allows AKS to reach Azure Monitor over private network.

### 3.3 DNS Zone Configuration

**DNS Private Zone:**
- Zone name: `privatelink.monitor.azure.com`
- DNS Zone Group: Links private endpoint to DNS zone

**MINOR CONCERN 3 (CRITICAL PATH):** Verify that:
1. The DNS zone is **linked to the AKS cluster VNet** — Without VNet link, DNS resolution fails
2. The DNS zone is created **before the private endpoint** — Or use `dependsOn` in ARM template
3. The DNS zone is **not conflicting with existing zones** — If another team already created `privatelink.monitor.azure.com` in the VNet, this will fail

**Recommended Verification:**
```bash
# Check if DNS zone exists and is linked to VNet
az network private-dns zone list --resource-group <rg> --query "[?name=='privatelink.monitor.azure.com'].{Name:name, VNetLinks:numberOfVirtualNetworkLinks}"

# Check if VNet link exists
az network private-dns link vnet list --resource-group <rg> --zone-name privatelink.monitor.azure.com
```

**Remediation if Missing:**
- Add ARM template resource for `Microsoft.Network/privateDnsZones/virtualNetworkLinks`
- Or document manual VNet link creation in deployment guide
- Or use shared DNS zone if already exists

### 3.4 Metrics Flow Validation

**Expected Flow:**
1. AKS cluster → AKS metrics profile enabled
2. Metrics agent (managed by Azure) → Publishes to AMW
3. AMW → Receives metrics via private endpoint (AMPLS)
4. DCR → Processes/routes metrics
5. DCE → Exposes metrics for querying

**Assessment:** ✅ This is the correct Azure Monitor Prometheus architecture. Using managed metrics profile offloads agent management to Azure (no daemonset to manage).

---

## 4. Pipeline Integration Assessment

**ASSESSMENT: ✅ CORRECT with 1 OPTIMIZATION OPPORTUNITY**

### 4.1 Stage Ordering (PR #14968532)

**Pipeline Files Updated:**
- `pipeline-cluster-dev.yml`
- `pipeline-cluster-stg.yml`
- `pipeline-cluster-ppe.yml`
- `pipeline-cluster-prod.yml`

**Stage Order:**
1. `Workspace_` — Provision resource groups, VNets, etc.
2. `Cluster_` — Provision AKS cluster
3. **`AzureMonitoring_`** — NEW: Deploy DCR Association, AMPLS, Private Endpoint
4. `Karpenter_` — Deploy Karpenter operator
5. `ArgoCD_` — Deploy ArgoCD
6. `InfraMonitoringCrds_` — Deploy CRDs
7. (other downstream stages)

**Dependency Analysis:**
- `AzureMonitoring_` depends on `Cluster_` ✅ — Correct, needs AKS cluster to exist
- `Karpenter_` depends on `AzureMonitoring_` ✅ — Correct, ensures monitoring is ready
- `ArgoCD_` depends on `AzureMonitoring_` ✅ — Correct, ensures monitoring is ready

**Assessment:** ✅ Stage ordering is correct. AzureMonitoring_ must run after Cluster_ (needs AKS resource) and before dependent stages (ArgoCD, Karpenter need monitoring).

**MINOR CONCERN 4 (OPTIMIZATION):** The current dependency chain is serial:
```
Cluster_ → AzureMonitoring_ → Karpenter_
                            → ArgoCD_
                            → InfraMonitoringCrds_
```

**Question:** Does Karpenter/ArgoCD/InfraMonitoringCrds **require** AzureMonitoring_ to complete first, or is this a convenience dependency?

**If NOT required:**
Consider **parallel deployment** to reduce total pipeline time:
```
Cluster_ → [AzureMonitoring_, Karpenter_, ArgoCD_, InfraMonitoringCrds_] (parallel)
```

**If REQUIRED:**
Current serial dependency is correct. (Likely required if Karpenter/ArgoCD need metrics to be flowing for health checks.)

### 4.2 Stage Failure Behavior

**Expected Behavior:**
- If `AzureMonitoring_` stage fails → Pipeline stops, downstream stages (Karpenter, ArgoCD) do not run
- If `AzureMonitoring_` stage succeeds → Downstream stages proceed

**Assessment:** ✅ This is correct Azure DevOps pipeline behavior. Failures block dependent stages.

**Retry Logic:**
Verify that `AzureMonitoring_` stage has retry logic for transient failures:
- Role assignment propagation delays (30-60 seconds)
- AMPLS private endpoint DNS propagation (1-2 minutes)
- ARM deployment throttling (429 errors)

**Recommendation:** Add `retryCountOnTaskFailure: 3` to `AzureMonitoring_` stage YAML if not already present.

### 4.3 Pipelines NOT Modified (Correct)

**Not Modified:**
- Release-regional templates (use ev2-stage-loop-deploy) ✅ — Correct, Ev2 handles regional rollouts
- ArgoCD pipelines ✅ — Correct, ArgoCD is infrastructure-agnostic
- Rollback pipelines ✅ — Correct, rollback is handled by Ev2 ServiceModel

**Assessment:** ✅ These pipelines should not be modified. The Ev2 orchestration handles regional rollouts and rollbacks via ServiceModel definitions.

---

## 5. Cluster Inventory Integration Assessment

**ASSESSMENT: ✅ CORRECT**

### 5.1 Schema Extension (PR #14966543)

**File:** `ClustersInventorySchema.json`

**New Field:**
```json
"AzureMonitorSubscriptionId": {
  "type": "string",
  "description": "Subscription ID for Azure Monitor Prometheus resources (DCE, DCR, AMW)"
}
```

**Assessment:** ✅ Schema extension follows DK8S inventory patterns. Similar to `AcrSubscription`, `DnsSubscription`, etc.

### 5.2 Tenant Configuration (PR #14966543)

**File:** `Tenants.json`

**Tenants Updated:**
- DEV/MS: `"AzureMonitorSubscriptionId": "c5d1c552-a815-4fc8-b12d-ab444e3225b1"`
- STG/MS: `"AzureMonitorSubscriptionId": "c5d1c552-a815-4fc8-b12d-ab444e3225b1"`

**Pattern:** Tenant-level field (not cluster-level) → Shared subscription for all clusters in tenant.

**Assessment:** ✅ Correct pattern. Azure Monitor Prometheus uses **per-region shared resources** (DCE, DCR, AMW), not per-cluster resources. Tenant-level subscription ID is appropriate.

### 5.3 Test Data Files (PR #14966543)

**Files Updated:** 12 test data files

**Assessment:** ✅ Test data consistency is critical for CI/CD validation. Updating test files ensures schema validation passes.

### 5.4 Inventory Flow

**Expected Flow:**
1. Tenants.json updated → CI/CD validates schema
2. GoTemplate reads `{{ .Tenant.AzureMonitorSubscriptionId }}`
3. ARM template receives subscription ID as parameter
4. ARM template deploys DCR Association targeting shared resources in Azure Monitor subscription

**Assessment:** ✅ This is the correct inventory-to-ARM parameter flow used by DK8S.

---

## 6. Rollback Assessment

**ASSESSMENT: ⚠️ PARTIAL COVERAGE**

### 6.1 Rollback Script (PR #14968397)

**File:** `AzureMonitoringValidation.sh`

**Expected Behavior:**
- Checks if `ENABLE_AZURE_MONITORING` flag is `false`
- Checks if Azure Monitor resources are still deployed on cluster
- If mismatch → Exit non-zero (fails Ev2 deployment)

**Assessment:** ⚠️ **This is validation, not rollback.** The script detects mismatches but does not **remediate** them.

**Rollback Scenarios:**

| Scenario | Flag State | Resource State | Current Script Behavior | Expected Behavior |
|----------|------------|----------------|-------------------------|-------------------|
| 1. Normal enable | `true` | Deployed | ✅ Pass | ✅ Pass |
| 2. Normal disable | `false` | Not deployed | ✅ Pass | ✅ Pass |
| 3. Flag disabled, but resources exist | `false` | Deployed | ❌ Fail (exit 1) | ❓ Remove resources? Or just alert? |
| 4. Flag enabled, but resources missing | `true` | Not deployed | ❌ Fail (exit 1) | ❓ Deploy resources? Or just alert? |

**MINOR CONCERN 3 (CLARIFICATION NEEDED):**

**Question for Krishna/Tamir:**
- Is the script intended to **detect-only** (exit non-zero and let Ev2 rollback the entire deployment)?
- Or is the script intended to **remediate** (remove resources if flag=false, deploy resources if flag=true)?

**Recommendation:**
- If **detect-only**: Rename to `AzureMonitoringValidation.sh` (current name is correct)
- If **remediate**: Add rollback logic to remove DCR Association, AMPLS, Private Endpoint if flag=false

**Typical DK8S Pattern:** Validation scripts are detect-only. Ev2 handles rollback via ServiceModel rollback actions.

### 6.2 Ev2 Rollback Mechanism

**Ev2 Rollback Strategy:**
- Ev2 tracks ARM deployment state via ServiceModel
- On rollback, Ev2 re-deploys previous ServiceModel version
- ARM template `condition: "[parameters('enableAzureMonitoring')]"` ensures resources are removed if flag=false

**Assessment:** ✅ Ev2 + ARM conditional deployment is the correct rollback mechanism. The validation script is a safety check, not the primary rollback tool.

### 6.3 Rollback Testing Recommendation

**Pre-Production Testing:**
1. Deploy to DEV with `ENABLE_AZURE_MONITORING=true` → Verify resources created
2. Rollback to DEV with `ENABLE_AZURE_MONITORING=false` → Verify resources removed
3. Verify AKS metrics profile disabled after rollback
4. Verify no orphaned resources (AMPLS, Private Endpoint, DNS Zone)

**Assessment:** ⚠️ Ensure rollback testing is included in DEV/STG validation before PROD rollout.

---

## 7. Recommendations Summary

### 7.1 Pre-Merge Actions (Non-Blocking)

1. **DNS Zone VNet Link Verification (PR #14968397)**
   - Verify `privatelink.monitor.azure.com` DNS zone is linked to AKS VNet
   - Add ARM template resource for VNet link if missing
   - Or document manual VNet link requirement

2. **Role Assignment Timing (PR #14968397)**
   - Add `dependsOn` in ARM template to ensure role assignment completes before metrics profile activation
   - Or add 60-second delay in pipeline after role assignment

3. **Pipeline Retry Logic (PR #14968532)**
   - Add `retryCountOnTaskFailure: 3` to `AzureMonitoring_` stage
   - Add exponential backoff for transient failures

4. **Rollback Script Clarification (PR #14968397)**
   - Clarify if `AzureMonitoringValidation.sh` is detect-only or remediate
   - If remediate, add resource removal logic

### 7.2 Post-Merge Actions (Operational)

1. **DEV Rollout Validation**
   - Test enable → disable → enable cycle
   - Verify no orphaned resources after disable
   - Verify metrics flow after enable

2. **STG Rollout with Monitoring**
   - Monitor ARM deployment duration (expect +2-3 minutes for AzureMonitoring_ stage)
   - Monitor role assignment propagation time
   - Monitor private endpoint DNS resolution time

3. **Production Rollout Checklist**
   - Verify shared resources (DCE, DCR, AMW) are deployed in all PROD regions
   - Verify AMPLS capacity limits (100 private endpoints per AMPLS)
   - Verify Azure Monitor Workspace capacity (ingestion rate limits)

### 7.3 Optional Optimizations (Future)

1. **Pipeline Parallelization**
   - If Karpenter/ArgoCD do not require AzureMonitoring_ to complete, run stages in parallel

2. **AMPLS Sharing**
   - Consider using **one AMPLS per tenant** instead of per-cluster (reduces resource count)
   - Trade-off: Shared AMPLS = more efficient, but less isolation between clusters

3. **Metrics Profile Tuning**
   - Consider `metricLabelsAllowlist` and `metricAnnotationsAllowList` filtering to reduce cardinality
   - Current setting (`*`) ingests all labels/annotations (high cardinality)

---

## 8. Final Verdict

**✅ APPROVE with 4 MINOR CONCERNS (Non-Blocking)**

This is a **production-ready infrastructure integration** that follows DK8S best practices. The three-repo pattern, Ev2 deployment model, and feature flag approach are all correct. The minor concerns are:

1. **DNS Zone VNet Link:** Verify VNet link exists (critical for private endpoint resolution)
2. **Role Assignment Timing:** Ensure role propagation completes before metrics ingestion
3. **Rollback Script Scope:** Clarify detect-only vs. remediate behavior
4. **Pipeline Optimization:** Consider parallelizing AzureMonitoring_ with other stages

**Recommendation:** Merge PRs after addressing DNS Zone VNet link verification. Other concerns can be addressed post-merge in DEV/STG validation.

**Confidence Level:** High (9/10)  
**Risk Level:** Low (Infrastructure changes are well-isolated and feature-gated)

---

**Reviewed by:** B'Elanna  
**Date:** 2026-03-12  
**Next Steps:**
1. Krishna addresses DNS Zone VNet link verification
2. Tamir approves PRs
3. Deploy to DEV for validation
4. Progress to STG → PPE → PROD with monitoring

---

## Appendix: Infrastructure Patterns Reference

### A.1 DK8S Deployment Model (Three-Repo Pattern)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Infra.K8s.Clusters (Inventory Repo)                     │
│    - Tenants.json: AZURE_MONITOR_SUBSCRIPTION_ID           │
│    - ClustersInventorySchema.json: Schema validation       │
│    - Test data files: CI/CD validation                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. WDATP.Infra.System.Cluster (ARM Template Repo)          │
│    - ARM Templates: DCR Association, AMPLS, Private Endpoint│
│    - GoTemplates: Parameters, RolloutSpecs, ServiceModels   │
│    - Validation Scripts: AzureMonitoringValidation.sh      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. WDATP.Infra.System.ClusterProvisioning (Pipeline Repo)  │
│    - Pipeline YAML: AzureMonitoring_ stage                  │
│    - Stage ordering: Cluster_ → AzureMonitoring_ → ...     │
│    - Ev2 orchestration: Regional rollouts                   │
└─────────────────────────────────────────────────────────────┘
```

### A.2 Azure Monitor Prometheus Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ AKS Cluster (Customer VNet)                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ AKS Metrics Profile (Managed by Azure)               │  │
│  │  - Prometheus agent (runs as sidecar)                │  │
│  │  - Collects metrics from kube-state-metrics          │  │
│  │  - Publishes to Azure Monitor Workspace              │  │
│  └──────────────────────────────────────────────────────┘  │
│                            ↓                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Private Endpoint (pe-{clusterName}-ampls)            │  │
│  │  - groupIds: ['azuremonitor']                        │  │
│  │  - DNS: privatelink.monitor.azure.com                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓ (Private Link)
┌─────────────────────────────────────────────────────────────┐
│ AMPLS (ampls-{clusterName}-{region})                        │
│  - Links to shared DCE, DCR, AMW                            │
│  - Enables private connectivity to Azure Monitor            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Shared Azure Monitor Resources (Per-Region, Per-Tenant)    │
│  - DCE (Data Collection Endpoint)                           │
│  - DCR (Data Collection Rule)                               │
│  - AMW (Azure Monitor Workspace)                            │
│  - Managed by ManagedPrometheus repo                        │
└─────────────────────────────────────────────────────────────┘
```

### A.3 Feature Flag Pattern (ENABLE_AZURE_MONITORING)

```bicep
// ARM Template Conditional Deployment
resource dcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = if (enableAzureMonitoring) {
  name: 'dcra-${clusterName}-${dcrName}'
  properties: {
    dataCollectionRuleId: dcrId
    description: 'Associates AKS cluster with Azure Monitor DCR'
  }
}

resource ampls 'Microsoft.Insights/privateLinkScopes@2021-07-01-preview' = if (enableAzureMonitoring) {
  name: 'ampls-${clusterName}-${location}'
  location: 'global'
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'PrivateOnly'
      queryAccessMode: 'Open'
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = if (enableAzureMonitoring) {
  name: 'pe-${clusterName}-ampls'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'ampls-connection'
        properties: {
          privateLinkServiceId: ampls.id
          groupIds: ['azuremonitor']
        }
      }
    ]
  }
}
```

**Pattern:** If `enableAzureMonitoring` is `false`, ARM does not deploy these resources. On rollback, setting flag to `false` removes resources.

---

**End of Review**
