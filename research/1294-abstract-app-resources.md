# Research: Abstract App Essential Resources for DK8S

**Issue:** [#1294](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1294)  
**Author:** Picard (Lead/Architecture)  
**Date:** 2026-03-22  
**Status:** ✅ Research Complete — Two options approved for evaluation  

---

## Executive Summary

Every new app deployed to our AKS/DK8S cluster currently requires manual, ad-hoc provisioning of:
- **Managed Identity** (User-Assigned MI + Federated Credential for workload identity)
- **Azure Resource Group** with app-scoped infra (Key Vault, storage, etc.)
- **K8s Namespace** with RBAC, network policies, resource quotas
- **Service Account** bound to the Managed Identity

The user has approved pursuing **two parallel options** to evaluate outcomes:

| Option | Description | Timeline |
|--------|-------------|----------|
| **A — Helm Chart + Bicep** | Reusable `app-bootstrap` Helm chart for K8s-side; Bicep module for Azure-side | 1–2 days |
| **B — ASO v2 + Helm Chart** | Azure Service Operator v2 for declarative Azure provisioning + same Helm chart | 1 week |

---

## Problem Statement

From [squad-on-aks#17](https://github.com/tamirdresher/squad-on-aks/issues/17) (@Anders-Kristiansen):
> All new apps following the same lifecycles will need a managed identity and a resource group with infrastructure related components. Consider a reusable workflow bootstrapping this and custom CRD where we can create resources with apps.

Currently, `dk8s-autobot` was set up manually. Each bot/agent added to DK8S requires re-doing this setup. We need a **declarative, GitOps-compatible, repeatable pattern**.

---

## Current Infrastructure Inventory

Our repo already has mature patterns we can extract:

| Pattern | Status | Source |
|---------|--------|--------|
| Workload Identity binding on SA | ✅ Implemented | `charts/squad/templates/serviceaccount.yaml` |
| Namespace with labels | ✅ Implemented | `charts/squad/templates/namespace.yaml` |
| RBAC Role + RoleBinding | ✅ Implemented | `charts/squad/templates/rbac.yaml` |
| NetworkPolicy | ✅ Implemented | `charts/squad/templates/networkpolicy.yaml` |
| Azure IaC via Bicep | ✅ Implemented | `infrastructure/aks-automatic-squad.bicep` |
| KEDA ScaledObjects | ✅ Implemented | `infrastructure/keda/` |
| ArgoCD / GitOps | ❌ Not yet wired | — |

**Key insight:** 80% of what we need already exists in `charts/squad/`. The work is to parameterize and generalize it.

---

## Options Evaluated

### Option 1: Custom CRD + Operator ❌ Skip

**How it works:** Build a K8s operator from scratch with a custom `AppBootstrap` CRD that orchestrates both Azure and K8s provisioning.

| Factor | Assessment |
|--------|-----------|
| Effort | Very high (months) |
| Maintenance | Ongoing operator lifecycle |
| Fit | We'd be rebuilding what ASO v2 already does |

**Verdict:** Overkill. Not recommended.

---

### Option 2: Azure Service Operator (ASO) v2 ✅ Recommended — Phase B

**Repository:** https://github.com/Azure/azure-service-operator  
**Version:** v2.17.0 (Dec 2025), production-ready  
**Coverage:** 150+ Azure resource types

**How it works:** Installs as a K8s operator. Azure resources are declared as K8s CRDs:
```yaml
apiVersion: managedidentity.azure.com/v1api20230131
kind: UserAssignedIdentity
metadata:
  name: myapp-identity
  namespace: myapp
spec:
  location: westeurope
  owner:
    name: myapp-rg
---
apiVersion: managedidentity.azure.com/v1api20230131
kind: FederatedIdentityCredential
metadata:
  name: myapp-fedcred
  namespace: myapp
spec:
  audiences: ["api://AzureADTokenExchange"]
  issuer: "https://oidc.prod-aks.azure.com/<cluster-id>/"
  subject: "system:serviceaccount:myapp:myapp-sa"
  owner:
    name: myapp-identity
```

**Resources ASO v2 covers for our use case:**
- `ResourceGroup` — `resources.azure.com/v1api20200601`
- `UserAssignedIdentity` — `managedidentity.azure.com/v1api20230131`
- `FederatedIdentityCredential` — `managedidentity.azure.com/v1api20230131`
- `KeyVault` — `keyvault.azure.com/v1api20230701`
- `RoleAssignment` — `authorization.azure.com/v1api20200801`

| Factor | Assessment |
|--------|-----------|
| Effort | 1 week to pilot |
| GitOps | ✅ First-class ArgoCD/Flux support |
| Azure coverage | ✅ All resources we need |
| K8s-side | ❌ Doesn't handle namespace/RBAC/SA (needs our Helm chart) |
| Maintenance | Low (Microsoft-maintained) |
| Support | Microsoft-backed |

**Gap:** ASO v2 handles Azure resources only. K8s-side bootstrapping (namespace, RBAC, SA, network policies) still needs the Helm chart from Option A.

**Resource constraint:** ASO operator needs ~100–200m CPU. Given our Standard_D2s_v3 cluster (~50m CPU allocatable), we may need a dedicated system node pool or use the lightweight CRD-only install.

---

### Option 3: Crossplane + Azure Provider ❌ Skip (for now)

**How it works:** CNCF project that manages multi-cloud resources via K8s CRDs and "Compositions."

| Factor | Assessment |
|--------|-----------|
| Multi-cloud | ✅ Strength — but we're Azure-only |
| Complexity | High (XRDs, Compositions, provider config) |
| Azure coverage | Slightly broader than ASO v2 for niche resources |
| Microsoft support | None (community-maintained) |

**Verdict:** Zero multi-cloud benefit for us. ASO v2 has tighter Azure integration and faster feature coverage. Reconsider if we ever go multi-cloud.

---

### Option 4: GitHub Actions / ADO Pipeline ⚠️ Supplementary

**How it works:** Parameterized pipeline: input = app name → `az cli` + `kubectl` provisions everything.

| Factor | Assessment |
|--------|-----------|
| Simplicity | ✅ Familiar tooling |
| GitOps | ❌ Imperative, drift risk |
| Entra operations | ✅ Good for one-time setup |

**Verdict:** Keep as supplementary tool for Entra ID operations that CRDs can't handle (e.g., app registrations, conditional access). Not the primary pattern.

---

### Option 5 (A): Helm Chart + Bicep Module ✅ Recommended — Phase A (Immediate)

**How it works:**
- Helm chart for K8s resources (namespace, SA, RBAC, network policies, workload identity binding)
- Bicep module for Azure resources (RG, managed identity, federated credential, Key Vault)
- This is essentially what `charts/squad/` already does — just not generalized

**Proposed `app-bootstrap` Helm chart structure:**
```
charts/app-bootstrap/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── namespace.yaml          # with workload identity labels
    ├── serviceaccount.yaml     # annotated with MI client ID
    ├── rbac.yaml               # configurable Role + RoleBinding
    ├── networkpolicy.yaml      # default-deny + configurable egress
    ├── secret-provider-class.yaml  # Key Vault CSI (optional)
    ├── resource-quota.yaml     # optional
    └── limit-range.yaml        # optional
```

**Sample `values.yaml`:**
```yaml
appName: my-new-app
namespace: my-new-app
azure:
  managedIdentityClientId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  keyVaultName: "my-app-kv"       # optional
  tenantId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
rbac:
  rules:
    - apiGroups: ["batch"]
      resources: ["jobs"]
      verbs: ["create", "delete", "get", "list"]
networkPolicy:
  allowEgress:
    - to:
        - ipBlock:
            cidr: "0.0.0.0/0"
      ports:
        - protocol: TCP
          port: 443
```

**Bicep module for Azure side:**
```bicep
// modules/app-identity.bicep
param appName string
param location string
param aksOidcIssuer string
param aksNamespace string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${appName}-identity'
  location: location
}

resource federatedCred 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: identity
  name: '${appName}-fedcred'
  properties: {
    issuer: aksOidcIssuer
    subject: 'system:serviceaccount:${aksNamespace}:${appName}-sa'
    audiences: ['api://AzureADTokenExchange']
  }
}

output identityClientId string = identity.properties.clientId
output identityResourceId string = identity.id
```

| Factor | Assessment |
|--------|-----------|
| Effort | 1–2 days (extracting existing patterns) |
| GitOps | ✅ Helm + ArgoCD compatible |
| Azure coverage | ✅ Via Bicep (already used) |
| K8s-side | ✅ Full coverage |
| Two tools | Slight coordination overhead (Helm + Bicep) |

---

### Option 6: Radius (Microsoft Incubation) ❌ Skip

**Version:** v0.54 (Dec 2025), CNCF Sandbox  
**Status:** Not production-ready. Missing RBAC, mature GitOps, production controls.  
**Verdict:** Revisit when it reaches CNCF Incubating status.

---

## Managed Identity Patterns for AKS

### Azure Workload Identity (OIDC + Federated Credentials) ✅ **Current Best Practice**

The modern, recommended pattern (2024/2025):
1. AKS cluster has OIDC issuer enabled (`--enable-oidc-issuer --enable-workload-identity`)
2. Create a User-Assigned Managed Identity in Azure
3. Create a Federated Identity Credential linking the MI to a K8s SA
4. Annotate the K8s ServiceAccount with `azure.workload.identity/client-id`
5. Label pods with `azure.workload.identity/use: "true"`

This is already implemented in `charts/squad/templates/serviceaccount.yaml`.

### Azure AD Pod Identity (deprecated) ❌

Deprecated as of 2022. Do not use for new workloads.

### Automation approach

For new apps, the federated credential creation can be done via:
- **Bicep module** (Option A) — declarative, version-controlled
- **ASO v2 `FederatedIdentityCredential` CRD** (Option B) — fully K8s-native

---

## Recommended Implementation Plan

Based on user feedback ("Go with the two options to evaluate outcomes"):

### 🟢 Phase A — Helm Chart + Bicep (Start Now, 1–2 days)

**Goal:** Generalize existing patterns into a reusable `app-bootstrap` Helm chart + Bicep module.

**Steps:**
1. Create `charts/app-bootstrap/` by extracting and parameterizing `charts/squad/` templates
2. Create `infrastructure/modules/app-identity.bicep` reusable module
3. Document usage in `charts/app-bootstrap/README.md`
4. Validate by re-deploying dk8s-autobot using the new chart

**Deliverable:** A single `helm install` + `az deployment group create` onboards a new app end-to-end.

---

### 🔵 Phase B — ASO v2 Evaluation (Next, 1 week)

**Goal:** Pilot ASO v2 on the cluster and declare all Azure resources as K8s CRDs.

**Steps:**
1. Install ASO v2 on the AKS cluster (Helm, with workload identity config)
2. Address resource constraint: evaluate lightweight install or dedicated node pool
3. Create ASO-based manifests for a new test app (MI, FederatedCred, KeyVault)
4. Combine with Phase A Helm chart for full declarative onboarding
5. Compare experience vs. Phase A (Bicep) approach

**Deliverable:** A single `kubectl apply -f app-resources/` onboards everything (Azure + K8s).

---

### 🟡 Phase C — ArgoCD ApplicationSet (Future, optional)

Once both options are evaluated:
1. Pick the winning pattern
2. Create an ArgoCD ApplicationSet that auto-deploys `app-bootstrap` for each app directory in Git
3. **Full GitOps:** add `apps/my-new-app/values.yaml` → ArgoCD provisions everything

---

## What a Custom `AppBootstrap` CRD Would Look Like

If we were to build a custom CRD (not recommended, but included for completeness):

```yaml
apiVersion: dk8s.platform/v1alpha1
kind: AppBootstrap
metadata:
  name: my-new-app
spec:
  appName: my-new-app
  namespace: my-new-app
  azure:
    location: westeurope
    resourceGroup: my-new-app-rg
    keyVault: true
    managedIdentity: true
  k8s:
    rbac:
      rules:
        - apiGroups: ["batch"]
          resources: ["jobs"]
          verbs: ["create", "delete", "get", "list"]
    networkPolicy:
      defaultDenyIngress: true
      allowEgress: ["0.0.0.0/0:443"]
    resourceQuota:
      cpuRequest: "500m"
      memoryRequest: "512Mi"
```

This would be the Phase B/C end state if we wanted a fully unified abstraction. But ASO v2 + our Helm chart achieves 95% of this without building a custom operator.

---

## Complexity Estimates

| Phase | Effort | Risk | Dependency |
|-------|--------|------|------------|
| A: Helm chart | 1–2 days | Low (known patterns) | None |
| A: Bicep module | 0.5 day | Low | None |
| B: ASO v2 install | 0.5 day | Medium (cluster resources) | Phase A Helm chart |
| B: ASO v2 manifests | 1–2 days | Low | ASO install |
| C: ArgoCD AppSet | 1 day | Low | Phase A or B |

---

## Decision Matrix

| Criterion | Weight | Helm+Bicep (A) | ASO v2 (B) | Crossplane |
|-----------|--------|----------------|-----------|------------|
| Time to implement | High | ★★★★★ | ★★★ | ★★ |
| GitOps compatibility | High | ★★★★ | ★★★★★ | ★★★★ |
| Azure-native | Medium | ★★★★ | ★★★★★ | ★★★ |
| Maintenance burden | Medium | ★★★★ | ★★★★ | ★★ |
| Ecosystem maturity | Medium | ★★★★★ | ★★★★★ | ★★★★ |
| Full declarative stack | Low | ★★★ | ★★★★★ | ★★★★★ |

**Both A and B are worth running in parallel** to see which is more practical for our cluster constraints and team workflow.

---

## Internal Microsoft Guidance (eng.ms)

Searched eng.ms for DK8S, AKS managed identity, and app bootstrapping patterns. Key relevant findings:

- **Azure Managed Namespaces (AMN)**: Internal Supply Chain AKS Platform has documented guidance on namespace management at `eng.ms/docs/cloud-ai-platform/ahsi/cscp/sc-enable/supply-chain-aks-platform`. This aligns with our Phase A Helm chart approach.
- **Setup Guide for AKS with Entra ID, Azure RBAC, and PIM**: Relevant for the RBAC provisioning step — see `eng.ms/docs/.../aks-with-entra-id-azure-rbac-and-pim-setup`.
- **Onboard Azure Workload Identity on COSMIC**: Internal pattern for workload identity onboarding — confirms our current `azure.workload.identity/client-id` annotation approach.

No specific DK8S internal documentation found on eng.ms (DK8S appears to be our team's own internal Kubernetes platform).

---

## Related Issues and Context

- [squad-on-aks#17](https://github.com/tamirdresher/squad-on-aks/issues/17) — upstream tracking issue
- [#1280](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1280) — KEDA token scaler (similar bootstrapping pattern)
- `dk8s-autobot` — current manual setup that would benefit from this abstraction

---

## References

- [Azure Service Operator v2 GitHub](https://github.com/Azure/azure-service-operator)
- [ASO v2 Getting Started](https://azure.github.io/azure-service-operator/getting-started/)
- [Azure Workload Identity for AKS](https://learn.microsoft.com/en-us/azure/aks/workload-identity-deploy-cluster)
- [Crossplane Azure Provider](https://marketplace.upbound.io/providers/upbound/provider-family-azure)
- [Radius Project](https://github.com/radius-project/radius)
- [AKS Platform Engineering Sample](https://learn.microsoft.com/en-us/samples/azure-samples/aks-platform-engineering/aks-platform-engineering/)
