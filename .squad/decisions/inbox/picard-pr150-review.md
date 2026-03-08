# Architectural Review: Issue #150 — Azure Monitor Prometheus Integration
**Reviewer:** Picard (Lead)  
**Date:** 2026-03-09  
**Scope:** Cross-repo architecture assessment of 3 PRs

---

## Executive Summary

**VERDICT:** ✅ **APPROVE WITH OBSERVATIONS**

Krishna's 3-PR implementation demonstrates solid architectural discipline across the cluster provisioning stack. The design correctly separates concerns (configuration → templates → orchestration), follows existing patterns for subscription isolation, and provides proper rollback paths. The implementation is production-ready for STG rollout with clear follow-up requirements for PRD.

**Key Strengths:**
- Clean separation of shared (per-region) vs. dedicated (per-cluster) resources
- Subscription isolation via AZURE_MONITOR_SUBSCRIPTION_ID follows ACR_SUBSCRIPTION pattern
- Feature flag approach (ENABLE_AZURE_MONITORING) enables controlled rollout
- Buddy pipelines passed, STG.EUS2.9950 deployment validated

**Critical Path to Production:**
- PRD tenant configuration in Tenants.json (PR1 follow-up)
- ManagedPrometheus regional resource rollout completion
- Validation script testing across rollback scenarios

---

## Architecture Assessment

### 1. Resource Ownership Model ✅

The architecture correctly divides responsibilities:

| Resource | Owner | Scope | Rationale |
|---|---|---|---|
| **Azure Monitor Workspace (AMW)** | ManagedPrometheus | Per region | Shared query surface, multi-cluster aggregation |
| **Data Collection Endpoint (DCE)** | ManagedPrometheus | Per region | Network ingress point, reusable across clusters |
| **Data Collection Rule (DCR)** | ManagedPrometheus | Per region | Prometheus scrape config, centrally managed |
| **DCR Association** | WDATP.Infra.System.Cluster | Per cluster | Binds cluster to regional DCR |
| **AMPLS + Private Endpoint + DNS** | WDATP.Infra.System.Cluster | Per cluster | Network isolation, cluster-specific routing |
| **AKS Metrics Profile** | WDATP.Infra.System.Cluster | Per cluster | Enables Prometheus scraping per cluster |

**Analysis:**  
This follows Azure Monitor best practices. Shared regional resources reduce overhead; per-cluster networking preserves isolation. The split ownership reduces blast radius — ManagedPrometheus controls *what* gets monitored, clusters control *how* they connect.

**Risk:** If ManagedPrometheus regional resources aren't deployed before cluster deployment, the DCR Association will fail. The validation script (AzureMonitoringValidation.sh) should explicitly check for DCR existence with actionable error messages.

**Recommendation:** Add pre-flight validation in AzureMonitoringValidation.sh:
```bash
# Check DCR exists in target subscription
DCR_EXISTS=$(az monitor data-collection rule show \
  --name "$DCR_NAME" \
  --resource-group "$DCR_RG" \
  --subscription "$AZURE_MONITOR_SUBSCRIPTION_ID" \
  --query "id" -o tsv 2>/dev/null)

if [ -z "$DCR_EXISTS" ]; then
  echo "ERROR: DCR $DCR_NAME not found in $AZURE_MONITOR_SUBSCRIPTION_ID"
  echo "ACTION: Ensure ManagedPrometheus regional resources deployed first"
  exit 1
fi
```

---

### 2. Subscription Isolation Pattern ✅

**Decision:** Use dedicated `AZURE_MONITOR_SUBSCRIPTION_ID` instead of reusing `ACR_SUBSCRIPTION`.

**Rationale (inferred):**
- **Cost segregation:** Monitoring costs tracked separately from container registry
- **Access control:** Different RBAC requirements (Monitoring Metrics Publisher vs. AcrPull)
- **Blast radius:** Azure Monitor incidents don't impact container image pulls
- **Billing:** Separate subscriptions enable chargeback to monitoring/observability teams

**Analysis:**  
This is the correct architectural choice. ACR and Azure Monitor have different operational characteristics:
- **ACR:** Pull-heavy, latency-sensitive, required for pod startup
- **Azure Monitor:** Push-heavy, eventually consistent, acceptable delays

Mixing them in the same subscription would complicate quota management, incident response, and cost allocation.

**Cross-Repo Consistency:** PR1 (Tenants.json) adds the field at tenant level with cluster-level override support, matching ACR_SUBSCRIPTION pattern exactly. ✅

---

### 3. Data Flow & Dependency Chain ✅

**End-to-End Flow:**

```
1. Configuration Layer (PR1: Infra.K8s.Clusters)
   Tenants.json → SetTenant() enrichment → ClusterInventory JSON
   └─ AZURE_MONITOR_SUBSCRIPTION_ID propagated to all clusters in tenant

2. Template Layer (PR2: WDATP.Infra.System.Cluster)
   ClusterInventory JSON → Ev2 Parameters → ARM Templates
   └─ Template.AzureMonitoring.Metrics.json (AMPLS, PE, DNS, DCR Assoc)
   └─ Template.AzureMonitoring.Metrics.RoleAssignment.json (RBAC)
   └─ GoTemplates for Ev2 ServiceModel (3 variants: Standard, HighSLO, Regional)

3. Orchestration Layer (PR3: WDATP.Infra.System.ClusterProvisioning)
   Pipeline Stage Flow: Workspace → Cluster → AzureMonitoring → [Downstream]
   └─ AzureMonitoring_ stage injects after Cluster_ stage
   └─ Karpenter, ArgoCD, InfraMonitoringCrds, etc. now depend on AzureMonitoring_
```

**Dependency Analysis:**

| Stage | Depends On | Why |
|---|---|---|
| AzureMonitoring_ | Cluster_ | Requires AKS cluster ID for metrics profile enablement |
| Karpenter_ | AzureMonitoring_ | Node autoscaler needs metrics visibility (NEW) |
| ArgoCD_ | AzureMonitoring_ | GitOps controller needs metrics visibility (NEW) |
| InfraMonitoringCrds_ | AzureMonitoring_ | Infrastructure CRDs monitoring (NEW) |

**Analysis:**  
The dependency changes in PR3 are **correct but conservative**. Technically, Karpenter/ArgoCD don't *require* Azure Monitor to function — they could deploy in parallel. However, the sequential approach:
- ✅ Ensures monitoring is available *before* critical controllers start (better debuggability)
- ✅ Matches existing pattern where foundational infra (cluster, networking) deploys before workloads
- ⚠️ Adds ~3-5 minutes to total deployment time (Ev2 stage overhead)

**Trade-off:** Sequential deployment is safer for initial rollout. Consider parallelizing AzureMonitoring with non-dependent stages (e.g., Karpenter) in Phase 2 optimization.

**Risk Check — Circular Dependencies:** None detected. ✅  
Pipeline flow is acyclic: Workspace → Cluster → AzureMonitoring → [Karpenter, ArgoCD, ...] → Validation

---

### 4. Feature Flag & Rollout Strategy ✅

**Control Mechanism:** `ENABLE_AZURE_MONITORING` flag (per-cluster)

**Rollout Path:**
1. **Phase 1 (Current):** DEV/STG tenants only
   - Tenants.json: DEV/MS, STG/MS → AZURE_MONITOR_SUBSCRIPTION_ID = c5d1c552-...
   - Clusters inherit unless explicitly override
2. **Phase 2 (Future):** PRD tenants
   - Requires ManagedPrometheus PRD regional resources
   - Add AZURE_MONITOR_SUBSCRIPTION_ID to PRD tenants in Tenants.json
3. **Cluster-Level Override:** Individual clusters can disable via `ENABLE_AZURE_MONITORING=false`

**Analysis:**  
This is a **textbook progressive rollout**:
- ✅ Environment-based (DEV → STG → PRD)
- ✅ Tenant-level configuration with cluster opt-out
- ✅ Non-disruptive (clusters without the flag simply skip Azure Monitor stages)

**Gap:** No mention of *how* clusters opt out. Clarify in documentation:
- Does `ENABLE_AZURE_MONITORING=false` in ClusterInventory skip the stage?
- Or does the ARM template check the flag and exit early with success?

**Recommendation:** Document opt-out mechanism in Tenants.json schema comments and pipeline README.

---

### 5. Validation & Rollback ✅

**Validation Script:** `AzureMonitoringValidation.sh`

**Responsibilities:**
- Pre-deployment: Check prerequisites (DCR exists, RBAC permissions)
- Post-deployment: Validate AMPLS connectivity, metrics ingestion
- Rollback trigger: Exit non-zero if validation fails

**Analysis:**  
Ev2 treats validation scripts as stage gates. If `AzureMonitoringValidation.sh` exits non-zero:
1. Ev2 marks AzureMonitoring_ stage as **failed**
2. Dependent stages (Karpenter, ArgoCD, etc.) are **skipped**
3. Rollback triggered if configured

**Critical Question:** What does rollback actually do?
- ✅ **Safe:** ARM template deletions (AMPLS, Private Endpoint, DCR Association) are idempotent
- ⚠️ **Unknown:** Does rollback revert AKS metrics profile enablement? (Likely requires explicit `az aks update --disable-azure-monitor-metrics`)

**Recommendation:**  
Validate rollback path by:
1. Deploy to test cluster with intentional validation failure
2. Verify rollback script disables AKS metrics profile
3. Confirm no orphaned Azure Monitor resources

---

## Cross-Repo Consistency

### Schema Evolution ✅

**PR1 Changes:**
```json
// K8S.Clusters.Inventory/ClustersInventorySchema.json
{
  "AZURE_MONITOR_SUBSCRIPTION_ID": {
    "type": "string",
    "description": "Subscription ID for Azure Monitor Workspace, DCE, DCR",
    "pattern": "^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$"
  }
}
```

**Test Data:** 12 expected output files updated to reflect new field in ClusterInventory.

**Analysis:**  
✅ Proper schema-first development. Adding the field to the schema *before* consuming it in ARM templates prevents runtime validation errors.

**Consistency Check:**
- Schema pattern enforces GUID format ✅
- Tenant-level field with cluster override supported ✅
- Matches ACR_SUBSCRIPTION precedent ✅

---

### ARM Template Conventions ✅

**PR2 introduces:**
- `Template.AzureMonitoring.Metrics.json` (main resources)
- `Template.AzureMonitoring.Metrics.RoleAssignment.json` (RBAC)

**Pattern Alignment:**
- ✅ Naming: Matches `Template.{Component}.{Subcomponent}.json` pattern
- ✅ Separation: RBAC in separate template (matches existing KeyVault, ACR patterns)
- ✅ Parameters: `AZURE_MONITOR_SUBSCRIPTION_ID` passed via Ev2 parameter files

**GoTemplates (Ev2 Specs):**
- 3 variants: Standard, HighSLO, Regional
- ✅ Matches existing component patterns (Cluster, Workspace, etc.)

**Missing:** No mention of ARM template testing. Recommendation: Validate templates with `az deployment group validate` in PR CI pipeline.

---

### Pipeline Stage Naming ✅

**PR3 Stage:** `AzureMonitoring_`

**Consistency:**
- ✅ Suffix: Matches `Cluster_`, `Workspace_`, `Karpenter_`, `ArgoCD_` pattern
- ✅ CamelCase: Consistent with existing stage names
- ✅ Singular: Follows convention (not `AzureMonitorings_`)

**ScopeBindings Update:**
```json
// ScopeBindings.{ENV}.{TENANT}.{REGION}.json
{
  "AzureMonitoringValidation": {
    "scope": "cluster",
    "validation": "AzureMonitoringValidation.sh"
  }
}
```

**Analysis:** ✅ Correct. Scope tags enable targeted deployments (e.g., re-run AzureMonitoring_ stage without redeploying entire cluster).

---

## Production Readiness

### ✅ Ready for STG (Current State)
- [x] DEV/STG tenant configuration in Tenants.json
- [x] ARM templates validated via buddy pipeline
- [x] Deployment tested on STG.EUS2.9950
- [x] Validation script included
- [x] RBAC (Monitoring Metrics Publisher) templated
- [x] Private endpoint + DNS for secure ingestion

### ⏳ Blockers for PRD
1. **PRD Tenant Configuration:** Add AZURE_MONITOR_SUBSCRIPTION_ID to PRD tenants in Tenants.json
   - **Owner:** Krishna
   - **Dependency:** ManagedPrometheus PRD regional resources must exist first
   - **Verification:** Confirm DCR IDs for PRD regions

2. **Regional Coverage Validation:** Ensure ManagedPrometheus has deployed AMW/DCE/DCR to all PRD regions
   - **Regions:** (Assumed EUS, WUS, NEU, etc. — clarify with ManagedPrometheus team)
   - **Verification:** Query ARM for DCR resources in target subscriptions

3. **Rollback Testing:** Validate rollback path in non-prod
   - **Scenario:** Intentionally fail validation script post-deployment
   - **Expected:** AKS metrics profile disabled, AMPLS/PE/DNS deleted
   - **Verification:** No orphaned resources, cluster returns to pre-deployment state

4. **Documentation:**
   - Runbook: "How to troubleshoot Azure Monitor ingestion failures"
   - Opt-out guide: "How to disable Azure Monitor for a specific cluster"
   - Incident response: "What to do if DCR association fails during deployment"

---

## Risk Assessment

### 🟡 MEDIUM: Dependency on External Team (ManagedPrometheus)
**Risk:** Cluster deployment fails if ManagedPrometheus regional resources aren't ready.

**Mitigation:**
- ✅ Validation script checks DCR existence (assumed — verify this)
- ⚠️ Error messages must be actionable ("DCR X not found, contact team Y")
- 🔧 Consider automated sync check: Query ManagedPrometheus repo for regional deployment status

**Owner:** Krishna (add to validation script)

---

### 🟢 LOW: Deployment Time Increase
**Risk:** Adding AzureMonitoring_ stage increases total deployment time by ~3-5 minutes.

**Impact:** Acceptable for initial rollout. Clusters deploy infrequently (~monthly for new regions, ad-hoc for new clusters).

**Future Optimization:** Parallelize AzureMonitoring_ with non-dependent stages (Phase 2).

---

### 🟢 LOW: Configuration Drift
**Risk:** Cluster overrides `ENABLE_AZURE_MONITORING=false` but operator expects metrics.

**Mitigation:**
- Document opt-out in Tenants.json schema
- Add validation warning: "Cluster X has Azure Monitor disabled, metrics will not be collected"
- Dashboard: Show Azure Monitor status per cluster

**Owner:** Documentation team

---

### 🟢 LOW: RBAC Permission Gaps
**Risk:** Deployment fails if Ev2 service principal lacks permissions in AZURE_MONITOR_SUBSCRIPTION.

**Mitigation:**
- ✅ Template includes role assignment (Monitoring Metrics Publisher)
- ⚠️ Verify Ev2 SP has permissions to *create* the role assignment
- 🔧 Test in isolated subscription before PRD rollout

**Owner:** B'Elanna (infrastructure RBAC validation)

---

## Recommendations

### Immediate (Before Merge)
1. **✅ PR1:** Merge as-is. Schema changes are backward-compatible (new field, optional at cluster level).

2. **✅ PR2:** Merge with one addition:
   - Add pre-flight DCR existence check to `AzureMonitoringValidation.sh` (see Architecture Assessment #1)

3. **✅ PR3:** Merge as-is. Pipeline changes are safe (new stage with explicit dependencies).

### Post-Merge (Before PRD)
4. **Rollback Testing:** Deploy to throw-away test cluster, intentionally fail validation, verify rollback. Document findings.

5. **Documentation:**
   - Add runbook: `docs/azure-monitor-prometheus-troubleshooting.md`
   - Update cluster deployment guide with Azure Monitor section
   - Document opt-out mechanism in Tenants.json README

6. **ManagedPrometheus Coordination:**
   - Confirm PRD regional resource deployment schedule
   - Get DCR resource IDs for all PRD regions
   - Test cross-subscription RBAC (Ev2 SP → AZURE_MONITOR_SUBSCRIPTION)

### Phase 2 (Optimization)
7. **Parallelization:** Evaluate parallelizing AzureMonitoring_ with Karpenter_ (both depend on Cluster_, neither depends on each other).

8. **Monitoring Coverage Metrics:** Add dashboard showing % of clusters with Azure Monitor enabled, metrics ingestion health.

9. **Automated Drift Detection:** Alert if a cluster's Azure Monitor configuration diverges from Tenants.json specification.

---

## Conclusion

Krishna's implementation is architecturally sound and production-ready for STG deployment. The 3-PR approach correctly separates configuration, templates, and orchestration, following established patterns. Cross-repo consistency is maintained, dependency chains are correct, and rollback paths exist.

**Critical path to PRD:**
1. Complete ManagedPrometheus regional rollout
2. Validate rollback scenarios
3. Add PRD tenant configuration

**Sign-off:** Ready for merge pending pre-flight validation enhancement in PR2.

---

**Review Completed:** 2026-03-09  
**Reviewer:** Picard (Lead)  
**Next Action:** Post to Issue #150, tag @Krishna Chaitanya for follow-up questions
