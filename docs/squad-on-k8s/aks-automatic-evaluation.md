# AKS Automatic Evaluation for Squad Deployment

> **Issue:** [#1136](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1136)
> **Author:** Seven (Research & Docs)
> **Date:** 2026-03-20
> **Status:** Final

---

## Executive Summary

**Verdict: Adopt AKS Automatic as the Squad cluster platform.**

AKS Automatic eliminates the entire node-pool management layer — no cluster autoscaler tuning, no VM SKU selection, no upgrade scheduling — while shipping with KEDA already installed and SLA-backed. For the Squad workload (Ralph CronJobs + short-lived agent Jobs, all CPU-only, no exotic hardware), the constraints of Automatic are not blockers. The operational savings are immediate and material. AKS Standard + NAP is the right fallback if the squad ever needs GPU nodes, tightly controlled egress networking, or custom daemonsets on system nodes — none of which are current requirements.

---

## Table of Contents

1. [Background](#1-background)
2. [What AKS Automatic Does Automatically](#2-what-aks-automatic-does-automatically)
3. [Feature Comparison Table](#3-feature-comparison-table)
4. [KEDA Integration for the Squad Use Case](#4-keda-integration-for-the-squad-use-case)
5. [Limitations and Gotchas](#5-limitations-and-gotchas)
6. [Cost Analysis](#6-cost-analysis)
7. [Recommendation](#7-recommendation)
8. [Migration Path](#8-migration-path)
9. [References](#9-references)

---

## 1. Background

The Squad runs Ralph (AI orchestrator) and a roster of specialist agents (Picard, Seven, Data, B'Elanna, etc.) as Kubernetes workloads. Per [ADR-002](../adr-002-squad-on-kubernetes.md):

- **Ralph** → `CronJob` on a 5-minute reconciliation cycle
- **Agent sessions** → short-lived `Job` objects with TTL cleanup
- **MCP servers** → sidecars in the Ralph Pod (shared localhost)
- **No GPU requirements** for Phase 1; all inference goes to external APIs
- **No PersistentVolumes** — state lives in Git

The existing [squad-on-aks.md](../squad-on-aks.md) guide targets AKS Standard with manually configured node pools. This document evaluates whether **AKS Automatic** would reduce ops burden and improve the KEDA story, specifically for scaling Ralph pods based on incoming Copilot token/request pressure.

---

## 2. What AKS Automatic Does Automatically

AKS Automatic bundles a set of production best practices that the Standard tier leaves to the operator:

| Capability | Who manages it | Standard AKS | AKS Automatic |
|---|---|---|---|
| System node pool sizing & VM SKU | Operator vs. Azure | ✏️ Manual | ✅ Automatic |
| Node pool autoscaling | Cluster Autoscaler config | ✏️ Config required | ✅ Built-in |
| Kubernetes version upgrades | Maintenance windows | ✏️ Manual scheduling | ✅ Automatic (configurable windows) |
| Node OS patching | NodeImageUpgrade config | ✏️ Manual | ✅ Automatic |
| KEDA installation & lifecycle | Helm release + version pinning | ✏️ `az aks update --enable-keda` | ✅ Pre-installed, auto-upgraded |
| Azure Monitor / Container Insights | Manual add-on install | ✏️ Optional add-on | ✅ Enabled by default |
| Workload Identity | Manual OIDC configuration | ✏️ Separate setup | ✅ Enabled by default |
| Azure Policy / Pod Security Admission | Manual policy assignment | ✏️ Optional | ✅ Enforced baseline |
| Node provisioning (Karpenter/NAP) | NAP preview config | ✏️ Preview, manual | ✅ Managed |
| Vertical Pod Autoscaler (VPA) | Helm chart | ✏️ Optional | ✅ Pre-installed |

**Net result:** On Automatic, the squad removes ~8 ongoing operational concerns from the `docs/squad-on-aks.md` checklist before writing a single manifest.

---

## 3. Feature Comparison Table

| Feature | AKS Automatic | AKS Standard + NAP | AKS Standard + KEDA |
|---|:---:|:---:|:---:|
| **Node provisioning** | ✅ Managed (Karpenter-based) | ✅ NAP (preview, Karpenter) | ✏️ Cluster Autoscaler only |
| **KEDA** | ✅ Built-in, auto-upgraded | ✏️ Manual `--enable-keda` | ✏️ Manual Helm install |
| **Kubernetes upgrades** | ✅ Automatic | ✏️ Manual schedule | ✏️ Manual schedule |
| **OS patching** | ✅ Automatic | ✏️ NodeImageUpgrade config | ✏️ NodeImageUpgrade config |
| **Pod Security Admission** | ✅ Enforced (`restricted` profile) | ✏️ Optional | ✏️ Optional |
| **Azure Monitor / Prometheus** | ✅ Pre-wired | ✏️ Add-on config | ✏️ Add-on config |
| **Workload Identity** | ✅ Default | ✏️ `--enable-oidc-issuer` | ✏️ `--enable-oidc-issuer` |
| **Custom VM SKU for user pools** | ⚠️ Limited† | ✅ Full control | ✅ Full control |
| **GPU node pools** | ⚠️ Limited SKUs | ✅ NC/ND/NV series | ✅ NC/ND/NV series |
| **Spot instance pools** | ⚠️ Azure-managed | ✅ User-configurable | ✅ User-configurable |
| **BYO VNet / custom CNI** | ⚠️ Restricted† | ✅ Full control | ✅ Full control |
| **System node pool SSH access** | ❌ Blocked | ✅ Available | ✅ Available |
| **Convert to Standard later** | ✅ Supported | N/A | N/A |
| **SLA (control plane)** | ✅ Standard tier (required) | ✅ Standard/Premium tier | ✅ Standard/Premium tier |
| **Setup time to production-ready cluster** | ~15 min | ~45–90 min | ~45–90 min |

> † User node pools in AKS Automatic support custom VM SKUs within a curated set. BYO VNet is supported for user pools but the system node pool networking remains Azure-managed.

---

## 4. KEDA Integration for the Squad Use Case

### 4.1 Why KEDA Matters for the Squad

Ralph operates on a **bursty, event-driven** schedule. During peak Copilot usage windows (e.g., morning standup processing, end-of-day digest generation), a queue of pending GitHub issues can back up. Without event-driven scaling, Ralph either:

- Runs on a fixed replica count and wastes compute during idle periods, or
- Scales on CPU (too late — CPU spikes only after backlog is already growing)

KEDA solves this by scaling on **leading indicators** — queue depth, HTTP request rate, or custom Azure Monitor metrics — before CPU climbs.

### 4.2 KEDA on AKS Automatic vs. Standard

On **AKS Standard**, enabling KEDA requires:
```bash
az aks update --resource-group <rg> --name <cluster> --enable-keda
```
Then operators must monitor KEDA operator health, manage upgrades, and track version compatibility with the Kubernetes version.

On **AKS Automatic**, KEDA is:
- Pre-installed at cluster creation
- Auto-upgraded in lockstep with cluster Kubernetes version
- Covered by Microsoft support (not just the open-source community)

The KEDA API surface (`ScaledObject`, `ScaledJob`, `TriggerAuthentication`) is identical in both modes — no manifest changes required.

### 4.3 Scaling Ralph Pods on Copilot Token Usage

The recommended architecture for token/request-pressure scaling:

```
GitHub Copilot calls → Application Insights (token metrics)
                              ↓
                   Azure Monitor (custom metric: copilot_tokens_used_per_min)
                              ↓
                        KEDA ScaledObject
                              ↓
               Ralph CronJob Deployment replicas ↑↓
```

**Sample `ScaledObject` manifest:**

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: ralph-token-scaler
  namespace: squad
spec:
  scaleTargetRef:
    name: ralph-worker           # Deployment wrapping agent jobs
  minReplicaCount: 1
  maxReplicaCount: 8
  cooldownPeriod: 300            # 5 min — matches Ralph's reconcile cycle
  triggers:
    - type: azure-monitor
      metadata:
        resourceURI: /subscriptions/{sub}/resourceGroups/{rg}/providers/microsoft.insights/components/{appInsights}
        tenantId: "{tenantId}"
        subscriptionId: "{sub}"
        resourceGroupName: "{rg}"
        metricName: customMetrics/copilot_tokens_per_minute
        metricAggregationType: Average
        targetValue: "5000"      # scale up when avg > 5k tokens/min
      authenticationRef:
        name: azure-monitor-auth
---
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: azure-monitor-auth
  namespace: squad
spec:
  podIdentity:
    provider: azure-workload    # uses the Workload Identity already configured by AKS Automatic
```

**Alternative: GitHub issue queue depth** (simpler, no Application Insights required):

```yaml
triggers:
  - type: github
    metadata:
      owner: tamirdresher
      repo: tamresearch1
      queryString: "is:issue is:open label:pending-ralph"
      targetIssueCount: "5"     # 1 replica per 5 open pending issues
    authenticationRef:
      name: github-auth
```

### 4.4 ScaledJob for Agent Sessions

For short-lived agent jobs (Picard, Seven, etc.), use `ScaledJob` instead of `ScaledObject`:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  name: agent-session-scaler
  namespace: squad
spec:
  jobTargetRef:
    template:
      spec:
        containers:
          - name: agent
            image: squad-agent:latest
  minReplicaCount: 0            # scale to zero when queue is empty
  maxReplicaCount: 10
  triggers:
    - type: azure-servicebus
      metadata:
        queueName: squad-agent-tasks
        namespace: squad-servicebus
        messageCount: "1"
```

> **Note on CronJob:** Ralph itself is a `CronJob` per ADR-002. CronJobs cannot be targeted by `ScaledObject` directly — wrap Ralph in a lightweight `Deployment` that respawns the reconcile loop, or use `ScaledJob` against a ServiceBus queue that feeds agent tasks.

### 4.5 KEDA Operational Advantage Summary

| Concern | AKS Automatic | AKS Standard |
|---|---|---|
| KEDA version management | Azure manages | You manage |
| KEDA upgrade compatibility | Auto-tested with K8s version | Manual validation |
| Workload Identity for KEDA triggers | Pre-wired | Manual OIDC + federated credential setup |
| Support channel | Microsoft Support | Open-source community |

---

## 5. Limitations and Gotchas

### 5.1 What You Lose with AKS Automatic

| Limitation | Impact on Squad | Severity |
|---|---|---|
| **No SSH to system node pool** | Can't debug system-level issues via node shell | Low — `kubectl debug` covers most cases |
| **Pod Security Admission enforced (`restricted`)** | Pods cannot run as root, cannot use `hostPath`, cannot set `allowPrivilegeEscalation` | **Medium** — squad container images must comply; needs validation |
| **Limited VM SKU choice** | Cannot pin to specific VM families (e.g., `Standard_E` memory-optimized) | Low — squad pods are CPU+RAM general purpose |
| **No GPU node pools (full SKU list)** | NC-series / NV-series limited in Automatic | Low — no GPU workloads in Phase 1 |
| **BYO VNet restricted to user pools** | System node VNET is Azure-managed | Low — squad has no cross-vnet routing requirements today |
| **Immutable security settings** | Cannot disable Azure Policy enforcement, RBAC | Low — squad wants these on |
| **Automatic upgrade windows** | Cluster may upgrade during a scheduled window | Low — configurable maintenance windows; squad has no hard uptime SLA today |
| **Spot instances not user-configurable** | Azure picks spot vs on-demand in user pools | Low — squad does not rely on spot-only pools today |

### 5.2 Pod Security Admission — The Most Likely Gotcha

AKS Automatic enforces the **`restricted` Pod Security Standard** on all namespaces. This means squad container images must:

- Run as a non-root user (`runAsNonRoot: true`)
- Drop all Linux capabilities (`drop: ["ALL"]`)
- Not use `hostPath` volumes
- Not use `hostNetwork`, `hostPID`, `hostIPC`

**Action required:** Validate all squad container images against `restricted` PSS before deploying to Automatic. The `squad-on-aks.md` guide already sets `securityContext` — verify compliance with:

```bash
kubectl label namespace squad pod-security.kubernetes.io/enforce=restricted --dry-run=server
```

### 5.3 KEDA Add-on Customization Limits

The AKS-managed KEDA add-on does not expose all upstream Helm values. Specifically:
- Cannot change the KEDA operator's log level or replica count
- Cannot install KEDA HTTP add-on (`kedacore/http-add-on`) as a managed add-on — must deploy manually as a Helm chart

For the squad's token-usage scaling use case (Azure Monitor scaler), this is not a problem. If HTTP request-rate scaling of a squad API endpoint is needed later, the HTTP add-on would require a Helm install on top of the managed KEDA.

### 5.4 Regional Availability

AKS Automatic is not available in all Azure regions. Verify the target region supports it:

```bash
az aks get-versions --location <region> --query "values[?isPreview==null].version" -o table
```

---

## 6. Cost Analysis

### 6.1 Pricing Tiers

| Tier | AKS Automatic | AKS Standard | AKS Standard + NAP |
|---|---|---|---|
| **Control plane** | Standard tier required: **~$0.10/hr** (~$73/mo) | Standard tier: ~$0.10/hr; Free tier: $0 | Standard tier: ~$0.10/hr |
| **Node compute** | VM cost (same as Standard) | VM cost | VM cost |
| **Node management overhead** | Near-zero (Azure manages) | Engineer time | Engineer time (reduced with NAP) |
| **KEDA** | Included | Free add-on | Free add-on |
| **Monitor / Container Insights** | Included (data ingestion costs apply) | Optional; data costs if enabled | Optional |

> The Free tier ($0 control plane) is available on AKS Standard but **not on AKS Automatic** — Automatic requires Standard tier.

### 6.2 Cost Comparison for a Typical Squad Cluster

Assuming: East US region, a 2-node baseline (D4s_v5, 4 vCPU / 16 GB each), ~720 hr/month.

| Cost Item | AKS Automatic | AKS Standard (Free tier) | AKS Standard + NAP |
|---|---|---|---|
| Control plane | **$73/mo** | **$0/mo** | **$73/mo** (Standard tier required for NAP) |
| 2× D4s_v5 nodes | ~$280/mo | ~$280/mo | ~$280/mo |
| Azure Monitor data | ~$5–20/mo | $0 (not enabled) | $5–20/mo |
| Ops engineer hours | **~0** | ~2–4 hr/mo | ~1–2 hr/mo |
| **Total (infra only)** | **~$358–$373/mo** | **~$280/mo** | **~$358–$373/mo** |
| **Total (incl. eng @ $150/hr)** | **~$358–$373/mo** | **~$580–$880/mo** | **~$508–$673/mo** |

**Key insight:** AKS Automatic is $73/month more than AKS Standard Free tier in raw infra — but saves ~2–4 hours of engineering time per month. At any reasonable hourly rate, Automatic is **cheaper total cost of ownership**.

### 6.3 Bin-Packing and Right-Sizing

AKS Automatic's Karpenter-based node provisioner is better at **bin-packing** short-lived agent Jobs onto available capacity than the classic Cluster Autoscaler. This can reduce idle node hours by 15–30% for bursty workloads like the squad, partially offsetting the $73/mo Standard tier cost.

---

## 7. Recommendation

### 7.1 Verdict

**✅ Adopt AKS Automatic for the Squad cluster.**

The squad's workload profile (CPU-only, short-lived Jobs, no GPU, no exotic networking) is an excellent fit for AKS Automatic. The gains are:

1. **Immediate ops removal** — Node pool management, K8s upgrades, KEDA lifecycle, Monitor wiring, Workload Identity configuration all drop off the squad's maintenance backlog.
2. **Better KEDA story** — KEDA is pre-installed, Microsoft-supported, and upgrade-safe. Scaling Ralph based on Copilot token pressure (via Azure Monitor scaler) or GitHub issue queue depth requires only a `ScaledObject` manifest — no infrastructure setup.
3. **Security by default** — Pod Security Admission, Azure Policy, and Workload Identity are enforced from day one, not bolted on later.
4. **Path to Standard** — AKS Automatic clusters can be converted to Standard without redeploying workloads. If the squad later needs GPU nodes or custom networking, the exit path is clear.

### 7.2 Decision Matrix

| Criterion | Weight | AKS Automatic | AKS Standard + NAP | AKS Standard + KEDA |
|---|---|:---:|:---:|:---:|
| Ops simplicity | High | ⭐⭐⭐ | ⭐⭐ | ⭐ |
| KEDA readiness | High | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| GPU / specialty hardware | Low (Phase 1) | ⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| Custom networking | Low | ⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| Cost (total CoE) | Medium | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| Security posture | Medium | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| Time to first deployment | Medium | ⭐⭐⭐ | ⭐⭐ | ⭐ |

### 7.3 Recommended Next Steps

1. **[ ] Create AKS Automatic cluster** in the target subscription — follow the updated `squad-on-aks.md` guide (to be updated in a follow-on PR).
2. **[ ] Validate Pod Security Admission** — run all squad container images through PSS `restricted` compliance check before migration.
3. **[ ] Write `ScaledObject` manifests** for Ralph (Azure Monitor trigger on Copilot token usage) and agent jobs (ServiceBus or GitHub issue queue trigger).
4. **[ ] Update Helm chart** — no structural changes needed; add KEDA `ScaledObject`/`ScaledJob` templates as opt-in chart resources.
5. **[ ] Verify region availability** — confirm the deployment region supports AKS Automatic GA.
6. **[ ] Defer KEDA HTTP add-on** — not needed for current squad scaling patterns; revisit if a squad API endpoint needs HTTP-rate scaling.

---

## 8. Migration Path

If AKS Automatic proves too constrained in future phases (e.g., GPU agent pods for local inference via KAITO, or custom networking for enterprise integration), the migration path is:

```
AKS Automatic → az aks update --mode Standard → AKS Standard cluster
                 (no workload redeployment required)
```

All workload manifests, Helm charts, KEDA `ScaledObject` definitions, and Workload Identity configuration are portable between AKS Automatic and Standard without modification.

---

## 9. References

| Resource | URL |
|---|---|
| AKS Automatic introduction (Microsoft Learn) | https://learn.microsoft.com/en-us/azure/aks/intro-aks-automatic |
| AKS Standard vs. Automatic comparison (Tech Community) | https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/aks-standard-vs-aks-automatic-a-comprehensive-comparison/4264516 |
| AKS Automatic managed system node pools announcement | https://blog.aks.azure.com/2025/11/26/aks-automatic-managed-system-node-pools |
| KEDA on AKS (Microsoft Learn) | https://learn.microsoft.com/en-us/azure/aks/keda-about |
| KEDA integrations with Azure services | https://learn.microsoft.com/en-us/azure/aks/keda-integrations |
| Integrate KEDA with Azure Monitor | https://learn.microsoft.com/en-us/azure/azure-monitor/containers/integrate-keda |
| AKS pricing tiers | https://learn.microsoft.com/en-us/azure/aks/free-standard-pricing-tiers |
| Node Autoprovision (NAP) workshop | https://microsoft.github.io/k8s-on-azure-workshop/module-4/4_performance_scaling/4_node_autoprovisioner/index.html |
| Pod Security Standards | https://kubernetes.io/docs/concepts/security/pod-security-standards/ |
| ADR-002: Squad on Kubernetes | ../adr-002-squad-on-kubernetes.md |
| Squad on AKS deployment guide | ../squad-on-aks.md |

---

*Document written by Seven (Research & Docs) for issue #1136. Questions → Picard for architecture decisions, B'Elanna for infrastructure implementation.*
