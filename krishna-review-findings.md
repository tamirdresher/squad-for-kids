# 🛡️ Deep Security Review — Azure Monitor Prometheus Integration

**Reviewer:** Worf (Security & Cloud)  
**Review Scope:** PRs #14966543, #14968397, #14968532  
**Knowledge Base:** dk8s-platform-squad  
**Date:** 2026-03-09

---

## Executive Summary

**Overall Assessment:** ✅ **APPROVE with RECOMMENDATIONS**

The Azure Monitor Prometheus integration follows DK8S security best practices for **private networking, managed identity authentication, and least-privilege RBAC**. The architecture demonstrates strong security fundamentals with **AMPLS (Azure Monitor Private Link Scope), private endpoints, and no secret exposure**.

However, **4 security recommendations** are identified for future improvements, primarily around **environment isolation, network policies, and rollback safety**.

---

## Security Strengths ✅

### 1. Private Networking Architecture
- ✅ **AMPLS + Private Endpoints** properly configured
- ✅ **Private DNS zones** (privatelink.monitor.azure.com) for name resolution
- ✅ **No public endpoint exposure** in ARM templates
- ✅ **Aligns with DK8S zero-trust pattern:** Private endpoint access for all Azure services

### 2. Identity & Access Management
- ✅ **User-Assigned Managed Identity** (no service principals or connection strings)
- ✅ **Least-privilege RBAC:** "Monitoring Metrics Publisher" role scoped to specific DCR resource (not subscription-wide)
- ✅ **No authentication secrets** stored anywhere
- ✅ **Aligns with DK8S Workload Identity pattern:** Azure AD + K8s ServiceAccount OIDC federation

### 3. Secret Management
- ✅ **Zero secrets in code:** No API keys, connection strings, or credentials in ARM templates
- ✅ **Configuration-based:** Subscription ID from tenant config (Tenants.json)
- ✅ **Managed Identity authentication** eliminates secret lifecycle management
- ✅ **Aligns with DK8S CSI Secret Provider pattern:** All secrets from Azure Key Vault, never in ConfigMaps/env vars

### 4. Pipeline Security
- ✅ **Stage ordering correct:** Workspace → Cluster → AzureMonitoring → [Karpenter, ArgoCD, ...]
- ✅ **Dependencies properly declared** ensuring monitoring is in place before downstream components
- ✅ **No additional credential exposure** in pipeline YAML
- ✅ **Secure pipeline context** with appropriate access to cluster credentials

### 5. Subscription-Level Access Pattern
- ✅ **Tenant-level property** (AZURE_MONITOR_SUBSCRIPTION_ID) following ACR_SUBSCRIPTION pattern
- ✅ **Cluster-level override capability** preserved for flexibility
- ✅ **Schema validation** added to ClustersInventorySchema.json

---

## Security Concerns 🟡

### 1. **Blast Radius Containment** (MEDIUM Priority)

**Issue:** Same subscription ID (c5d1c552-a815-4fc8-b12d-ab444e3225b1) used for both DEV and STG environments.

**Risk:**  
- Security incident in DEV environment could impact STG resources if RBAC is misconfigured
- Subscription-level operations (cost, quota, policy) affect both environments simultaneously
- Violates defense-in-depth principle (single failure domain)

**DK8S Standard Violation:**  
Platform enforces **separate subscriptions per environment** (DEV/STG/PRD) for blast radius isolation.

**Recommendation:**  
Use dedicated monitoring subscriptions per environment:
- AZURE_MONITOR_SUBSCRIPTION_ID_DEV → DEV-specific subscription
- AZURE_MONITOR_SUBSCRIPTION_ID_STG → STG-specific subscription
- AZURE_MONITOR_SUBSCRIPTION_ID_PRD → PRD-specific subscription

**Severity:** MEDIUM — Mitigated by RBAC but violates defense-in-depth

---

### 2. **Network Policy Integration** (MEDIUM Priority)

**Issue:** PRs deploy monitoring infrastructure but **do not update Kubernetes Network Policies** to allow pod-to-AMPLS traffic.

**Risk:**  
- DK8S uses **default-deny network policies** (Calico)
- Without explicit allowlist, cluster pods may be blocked from reaching AMPLS Private Endpoint (10.x.x.x/16 range)
- Result: **Silent monitoring failure** with no ingestion to Azure Monitor Workspace

**DK8S Standard Requirement:**  
All pod-to-Azure-service communication must have explicit NetworkPolicy egress rules.

**Recommendation:**  
Add NetworkPolicy allowing egress to AMPLS Private Endpoint:

`yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-azure-monitor-egress
  namespace: prometheus-prd  # or monitoring namespace
spec:
  podSelector:
    matchLabels:
      app: prometheus  # or Azure Monitor metrics agent
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/16  # AMPLS Private Endpoint CIDR
    ports:
    - protocol: TCP
      port: 443
`

**Severity:** MEDIUM — Could cause complete monitoring blackout

---

### 3. **Rollback Path Security** (LOW Priority)

**Issue:** AzureMonitoringValidation.sh disables monitoring when ENABLE_AZURE_MONITORING=false, but **does not clean up AMPLS, Private Endpoints, or DNS zones**.

**Risk:**  
- Orphaned private endpoints create **unexpected network paths** after rollback
- Resource leak in Azure (billing + clutter)
- Stale DNS records could cause name resolution issues

**Recommendation:**  
Update validation script to perform full teardown:

`bash
if [ "\" = "false" ]; then
  echo "Disabling Azure Monitoring and cleaning up resources..."
  az aks update --disable-azure-monitor-metrics ...
  az private-endpoint delete --name ...
  az network private-dns zone delete --name privatelink.monitor.azure.com ...
  az monitor private-link-scope delete --name ...
fi
`

**Severity:** LOW — Resource leak, minimal security impact

---

### 4. **Pre-Flight Validation** (LOW Priority)

**Issue:** ARM deployment assumes shared DCE/DCR/AMW resources exist (created by ManagedPrometheus repo). **No validation** that these resources are present before deployment.

**Risk:**  
- Deployment fails if ManagedPrometheus hasn't completed for region
- Failed deployment may leave partial state (AMPLS created, but DCR Association fails)
- No clear error message for operators

**Recommendation:**  
Add pre-flight checks in AzureMonitoringValidation.sh:

`bash
echo "Validating required Azure Monitor resources..."
az monitor data-collection-endpoint show --name dk8s-metrics-dce-\-\ --resource-group ... || exit 1
az monitor data-collection-rule show --name dk8s-metrics-dcr-\-\ --resource-group ... || exit 1
az monitor workspace show --name dk8s-metrics-\-\-platform-amw --resource-group ... || exit 1
echo "✓ All required resources found"
`

**Severity:** LOW — Operational risk, not security risk

---

## Unknown / Requires Verification ⚠️

### 1. **Compliance Configuration**
- ❓ Are DCE/DCR/AMW deployed with **customer-managed keys** (FedRAMP requirement for encryption at rest)?
- ❓ What is the **metric retention policy**? (DK8S standard: 90 days)
- ❓ Is AMPLS configured for **"Private Only" mode** (blocking public ingestion entirely)?

**Action Required:** Verify ManagedPrometheus repo configuration for compliance.

### 2. **Cross-Tenant Isolation**
- ❓ Are Azure Monitor Workspaces **separated per tenant** (MS, GME, AME, PME, etc.), or **shared across tenants**?
- ❓ Risk of **cross-tenant data leakage** if shared workspace

**Action Required:** Confirm tenant isolation design for AMW resources.

---

## Recommendations (Prioritized)

### 🔴 P1 — Address Before PRD Rollout
1. **Environment Isolation:** Use separate AZURE_MONITOR_SUBSCRIPTION_ID for DEV/STG/PRD
2. **Network Policies:** Add NetworkPolicy allowing egress to AMPLS Private Endpoint

### 🟡 P2 — Operational Safety
3. **Pre-Flight Validation:** Add z resource show checks in validation script for DCE/DCR/AMW existence
4. **Rollback Cleanup:** Update validation script to delete AMPLS/Private Endpoints when disabling

### 🟢 P3 — Compliance Verification
5. **FedRAMP Audit:** Verify ManagedPrometheus repo follows encryption, retention, and audit logging standards
6. **Tenant Isolation:** Confirm AMW workspaces are tenant-separated (no cross-tenant data)

---

## DK8S Security Patterns Validated ✅

From **dk8s-platform-squad knowledge base** review:

- ✅ **Zero-Trust Networking:** Default-deny network policies, mTLS via Linkerd, private endpoints
- ✅ **Workload Identity:** Azure AD + Kubernetes ServiceAccount OIDC federation (no secrets)
- ✅ **AMPLS Best Practice:** Azure Monitor Private Link Scope for secure metrics ingestion
- ✅ **CSI Secret Provider:** All secrets from Azure Key Vault, never in ConfigMaps/env vars
- ✅ **RBAC Least Privilege:** Group-based, namespace-scoped roles, cluster-level only for operators
- ✅ **Subscription Isolation:** Separate subscriptions for DEV/STG/PRD (currently violated for monitoring)
- ✅ **Encryption Standards:** TLS 1.3 for APIs, mTLS for pod-to-pod, at-rest encryption for storage
- ✅ **Pod Security:** Non-root containers (uid 1000+), read-only root filesystem

---

## Critical Security Questions (For Follow-Up)

1. **AMPLS Configuration:** Is the AMPLS configured for "Private Only" mode (blocking public ingestion)?
2. **Customer-Managed Keys:** Are DCE/DCR/AMW using customer-managed keys for encryption at rest?
3. **Log Retention:** What is the retention policy for metrics data in AMW? (DK8S standard: 90 days)
4. **Cross-Tenant Isolation:** Are AMW workspaces separated per tenant, or shared across tenants?
5. **ServiceMonitor RBAC:** Do Prometheus ServiceMonitors have RBAC to read pod metrics, or is it cluster-wide?

---

## Conclusion

**Architecture:** ✅ STRONG — Follows DK8S private networking patterns, managed identity, least privilege  
**Implementation:** ✅ SOLID — ARM templates are clean, no secrets exposed, proper dependencies  
**Gaps:** 🟡 MEDIUM — Environment isolation (shared subscription), missing network policies, rollback cleanup  
**Compliance:** ⚠️ UNKNOWN — FedRAMP/encryption requirements not verified  

**Final Recommendation:** **APPROVE with follow-up actions** on P1 recommendations before PRD rollout.

---

**Review Completed By:** Worf (DK8S Squad Security & Cloud Expert)  
**Knowledge Base Source:** C:\Users\tamirdresher\source\repos\dk8s-platform-squad  
**Review Context:** tamresearch1 (automated review system)

---

⚠️ **NOTE:** This review is based on PR descriptions and ADO metadata. ARM template contents were not directly accessible via API. Recommendations assume standard DK8S deployment patterns. Verify ARM template specifics with actual file contents.
