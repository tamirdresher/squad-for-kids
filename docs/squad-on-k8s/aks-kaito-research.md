# AKS + KAITO Integration Research for Squad Agents

**Issue:** #997  
**Author:** Seven (Research & Docs)  
**Date:** 2026-03-20  
**Status:** Research Complete — Awaiting Architecture Review  
**Reviewers:** Picard (Lead), B'Elanna (Infrastructure)  
**Related:** #994 (Squad-on-K8s), #1059 (K8s architecture), #1060 (AKS deployment guide)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [KAITO Overview](#2-kaito-overview)
3. [Why Squad Needs a Local Inference Fallback](#3-why-squad-needs-a-local-inference-fallback)
4. [Integration Architecture](#4-integration-architecture)
5. [AKS Node Pool Design](#5-aks-node-pool-design)
6. [Model Selection](#6-model-selection)
7. [Cost Analysis](#7-cost-analysis)
8. [Answering the Research Questions](#8-answering-the-research-questions)
9. [Implementation Roadmap](#9-implementation-roadmap)
10. [Helm Integration](#10-helm-integration)
11. [Open Questions & Risks](#11-open-questions--risks)

---

## 1. Executive Summary

KAITO (Kubernetes AI Toolchain Operator) is an open-source AKS-native operator that automates
GPU node provisioning and inference server deployment using a simple `Workspace` CRD. For Squad,
it addresses one specific pain point: **what happens to background agents (Ralph, Scribe) when
the shared Copilot rate pool is exhausted?**

**Key findings:**

| Question | Answer |
|----------|--------|
| Minimum useful GPU SKU | `Standard_NC4as_T4_v3` (T4, 16 GB VRAM) — sufficient for phi-3-mini |
| Can inference endpoints be shared? | Yes — KAITO `Workspace` exposes a ClusterIP service usable by all agent pods |
| Always-on vs on-demand GPU cost | On-demand with NAP is **~70% cheaper** for sporadic fallback workloads |
| Cold-start latency | 8–15 min (node provision) + 2–4 min (model load) — mitigable with node pool warm standby |
| Best fallback model | `phi-3-mini-128k-instruct` for triage tasks; `mistral-7b-instruct` for code review fallback |
| KAITO replaces Copilot? | **No.** It is a degraded-mode fallback for P2-tier background tasks only |

**Recommendation:** Implement KAITO as Phase 2 of the Squad-on-K8s rollout, after the core
Helm deployment (#1059/#1060) is stable. Prioritize the `phi-3-mini` workspace for Ralph's
issue-triage path.

---

## 2. KAITO Overview

### What KAITO Does

[KAITO](https://github.com/Azure/kaito) is an open-source Kubernetes operator that wraps the
complexity of running LLM inference on GPU nodes into a single CRD: `Workspace`.

```yaml
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: squad-fallback-phi3
  namespace: squad
spec:
  resource:
    instanceType: Standard_NC4as_T4_v3   # T4 GPU, 4 vCPU, 28 GB RAM
    labelSelector:
      matchLabels:
        apps: squad-inference
  inference:
    preset:
      name: phi-3-mini-128k-instruct
```

Applying this YAML causes KAITO to:

1. **Provision a GPU node** via AKS Node Autoprovision (NAP) — no pre-created node pool needed
2. **Pull the model image** from a pre-built KAITO model registry (MCR-hosted, no HuggingFace token needed for supported presets)
3. **Deploy an inference server** (vLLM or HuggingFace Transformers, depending on model)
4. **Expose a ClusterIP service** at `squad-fallback-phi3.squad.svc.cluster.local:80`
5. **Monitor health** and restart on failure

### KAITO Supported Presets (relevant to Squad)

| Preset Name | Model | VRAM Required | Best For |
|-------------|-------|---------------|----------|
| `phi-3-mini-128k-instruct` | Microsoft Phi-3 Mini (3.8B) | 8 GB | Issue triage, status checks |
| `phi-3-medium-128k-instruct` | Microsoft Phi-3 Medium (14B) | 28 GB | Code summarization |
| `mistral-7b-instruct` | Mistral 7B | 16 GB | Code review fallback |
| `llama-3.1-8b-instruct` | Meta Llama 3.1 8B | 20 GB | General-purpose fallback |
| `falcon-7b-instruct` | TII Falcon 7B | 16 GB | Lightweight triage |

> **Note:** All presets above are included in KAITO's built-in model registry and do not require
> a HuggingFace API token. Models requiring gated access (Llama variants) require a separate
> `AccessMode: Private` configuration with a K8s secret containing your HF token.

### AKS AI Toolchain Integration

KAITO is an AKS add-on installed with:

```bash
az aks update \
  --resource-group rg-squad-prod \
  --name aks-squad-prod \
  --enable-ai-toolchain-operator
```

This installs the KAITO controller and configures it to use AKS Node Autoprovision (NAP) for
GPU node creation. NAP is the preferred mechanism — it creates nodes on demand and terminates
them when the `Workspace` is deleted or scaled to zero.

---

## 3. Why Squad Needs a Local Inference Fallback

### The Rate-Limiting Problem

Squad's current model chain (from `squad.config.ts`):

```
premium:  claude-opus-4.6 → claude-opus-4.6-fast → claude-opus-4.5 → claude-sonnet-4.5
standard: claude-sonnet-4.5 → gpt-5.2-codex → claude-sonnet-4 → gpt-5.2
fast:     claude-haiku-4.5 → gpt-5.1-codex-mini → gpt-4.1 → gpt-5-mini
```

All tiers consume from a **shared Copilot rate pool**. During peak periods (blog writing, large
PR reviews), premium and standard agents exhaust the pool, leaving Ralph and Scribe throttled
at the P2 tier.

The impact: Ralph's 5-minute monitoring loop is delayed, issue triage stalls, and Scribe cannot
log decisions. These background functions are **low-quality-sensitive but high-availability-sensitive**
— they don't need GPT-4-class reasoning, they need to run reliably.

### Proposed Extended Fallback Chain

```
# squad.config.ts — proposed additions

standard: copilot-sonnet → copilot-gpt → kaito-phi3-mini → kaito-mistral-7b → (degraded-no-op)
fast:     copilot-haiku  → copilot-gpt-mini → kaito-phi3-mini → (degraded-no-op)
```

The `kaito-phi3-mini` provider would be implemented as a new model provider adapter in Squad's
model routing layer, pointing to the KAITO inference endpoint at:

```
http://squad-fallback-phi3.squad.svc.cluster.local/v1/chat/completions
```

This endpoint speaks the **OpenAI API wire format** (KAITO's vLLM inference server is OpenAI-compatible),
so the existing Squad model adapter needs only a base URL override.

### What KAITO Fallback Is Good For

| Task Type | KAITO Suitable? | Notes |
|-----------|-----------------|-------|
| Issue triage (classify label, priority) | ✅ Yes | Phi-3-mini handles this well |
| Status checks ("is this issue still open?") | ✅ Yes | Trivial reasoning |
| Scribe logging (structured JSON) | ✅ Yes | Template-following task |
| Ralph's watch loop summaries | ✅ Yes | Low-complexity summarization |
| ADR writing (Picard) | ⚠️ Degraded | Mistral-7b possible, quality lower |
| Code generation (Data) | ❌ No | Quality too low for production code |
| Security review (Worf) | ❌ No | Hallucination risk unacceptable |
| Blog writing (Troi/Neelix) | ❌ No | Quality too low for publishing |

**Design principle:** KAITO is a **background-task safety net**, not a feature. Agents must
detect they are running in degraded mode and communicate this clearly in their outputs.

---

## 4. Integration Architecture

### Full System Diagram

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                           AKS Cluster (aks-squad-prod)                          ║
║                                                                                  ║
║  ┌─────────────────────────────────────────────────────────────────────────┐    ║
║  │                      Namespace: squad                                    │    ║
║  │                                                                          │    ║
║  │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐  ┌─────────────┐  │    ║
║  │  │ Ralph       │   │ Picard      │   │ Seven       │  │ Scribe      │  │    ║
║  │  │ (CronJob)   │   │ (Deployment)│   │ (Ephemeral) │  │ (Ephemeral) │  │    ║
║  │  │             │   │             │   │             │  │             │  │    ║
║  │  │ model-      │   │ model-      │   │ model-      │  │ model-      │  │    ║
║  │  │ router      │   │ router      │   │ router      │  │ router      │  │    ║
║  │  │ sidecar     │   │ sidecar     │   │ sidecar     │  │ sidecar     │  │    ║
║  │  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘  └──────┬──────┘  │    ║
║  │         │                 │                  │                │          │    ║
║  │         └─────────────────┴──────────────────┴────────────────┘          │    ║
║  │                                    │                                     │    ║
║  │                      ┌─────────────▼──────────────┐                     │    ║
║  │                      │     Model Router Service    │                     │    ║
║  │                      │  (rate-limit aware proxy)   │                     │    ║
║  │                      └──────────┬─────────┬────────┘                    │    ║
║  │                                 │         │                              │    ║
║  │              ┌──────────────────┘         └──────────────────┐          │    ║
║  │              │  Primary: Copilot API       Fallback: KAITO   │          │    ║
║  │              ▼  (rate pool OK)             (rate pool ≥ P2)  ▼          │    ║
║  │   ┌──────────────────────┐         ┌─────────────────────────────┐      │    ║
║  │   │  github.com/copilot  │         │  KAITO Workspace            │      │    ║
║  │   │  Anthropic / OpenAI  │         │  squad-fallback-phi3        │      │    ║
║  │   │  (external APIs)     │         │  squad-fallback-mistral     │      │    ║
║  │   └──────────────────────┘         │                             │      │    ║
║  │                                    │  ┌─────────────────────┐   │      │    ║
║  │                                    │  │  vLLM Inference Pod │   │      │    ║
║  │                                    │  │  (OpenAI-compatible)│   │      │    ║
║  │                                    │  └─────────────────────┘   │      │    ║
║  │                                    └─────────────────────────────┘      │    ║
║  └─────────────────────────────────────────────────────────────────────────┘    ║
║                                                                                  ║
║  ┌─────────────────────────────────────────────────────────────────────────┐    ║
║  │                    Node Pools                                            │    ║
║  │                                                                          │    ║
║  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐  │    ║
║  │  │  system          │  │  agent (Spot)    │  │  gpu-inference (NAP) │  │    ║
║  │  │  Standard_D4s_v5 │  │  Standard_B4ms   │  │  Standard_NC4as_T4_v3│  │    ║
║  │  │  2 nodes, always │  │  0-5 nodes       │  │  0-2 nodes (on-demand│  │    ║
║  │  │  on              │  │  KEDA-scaled     │  │  via KAITO NAP)      │  │    ║
║  │  └──────────────────┘  └──────────────────┘  └──────────────────────┘  │    ║
║  └─────────────────────────────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════════════════════════════╝
```

### Model Router Decision Flow

```
Agent makes LLM request
         │
         ▼
   Check rate-limit headroom
         │
   ┌─────┴──────┐
   │            │
 OK (P0/P1)   Throttled (P2+)
   │            │
   ▼            ▼
Copilot API   Check KAITO workspace status
(primary)          │
              ┌────┴────┐
              │         │
           Ready      Not ready / cold
              │         │
              ▼         ▼
         KAITO phi3   Schedule task
         inference    for retry when
         endpoint     Copilot recovers
              │         │
              └────┬────┘
                   ▼
            Return result
            + [DEGRADED MODE] flag
            in response metadata
```

### KAITO Workspace Resource

```yaml
# infrastructure/kaito/squad-fallback-phi3.yaml
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: squad-fallback-phi3
  namespace: squad
  labels:
    squad.github.com/purpose: fallback-inference
    squad.github.com/tier: p2-background
spec:
  resource:
    instanceType: Standard_NC4as_T4_v3
    count: 1
    labelSelector:
      matchLabels:
        apps: squad-inference
        kaito.sh/workspace: squad-fallback-phi3
  inference:
    preset:
      name: phi-3-mini-128k-instruct
    # Tune for triage workload: shorter max tokens, higher throughput
    config:
      VLLM_MAX_MODEL_LEN: "8192"
      VLLM_MAX_NUM_SEQS: "16"       # concurrent requests
      VLLM_ENFORCE_EAGER: "true"    # disable CUDA graphs for lower memory
---
# infrastructure/kaito/squad-fallback-mistral.yaml
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: squad-fallback-mistral
  namespace: squad
  labels:
    squad.github.com/purpose: fallback-inference
    squad.github.com/tier: p2-code-review
spec:
  resource:
    instanceType: Standard_NC8as_T4_v3   # 8 vCPU, 56 GB RAM, 1x T4
    count: 1
    labelSelector:
      matchLabels:
        apps: squad-inference
        kaito.sh/workspace: squad-fallback-mistral
  inference:
    preset:
      name: mistral-7b-instruct
```

---

## 5. AKS Node Pool Design

### Recommended Node Pool Architecture

| Pool Name | Purpose | VM SKU | Count | Scaling | Spot? | Node Labels |
|-----------|---------|--------|-------|---------|-------|-------------|
| `system` | K8s control plane, DNS, CSI | `Standard_D4s_v5` | 2 (min) | Manual | No | `kubernetes.azure.com/mode=system` |
| `monitor` | Ralph CronJob, always-on agents | `Standard_B4ms` | 1-2 | Manual | No | `squad.github.com/pool=monitor` |
| `agent` | Ephemeral agents (Seven, Troi, etc.) | `Standard_D4as_v5` | 0-10 | KEDA | **Yes (Spot)** | `squad.github.com/pool=agent` |
| `gpu-inference` | KAITO workspaces (NAP-managed) | `Standard_NC4as_T4_v3` | 0-2 | KAITO NAP | No | `squad.github.com/pool=gpu-inference` |

> **Why no Spot for GPU?** GPU spot eviction rates in `eastus2` are historically high (~30% per
> day for NC4as_T4_v3). KAITO model load time (~4 min) makes eviction recovery expensive.
> On-demand GPU nodes are preferred; the cost is justified only when the node is active.

### Node Affinity and Taints

```yaml
# GPU node taint (applied by KAITO/NAP automatically)
taints:
  - key: "nvidia.com/gpu"
    value: "true"
    effect: "NoSchedule"

# Squad agent pods DO NOT tolerate GPU taint — they run on agent pool only
# Only KAITO Workspace pods get the toleration automatically

# Monitor pool taint (applied manually for Ralph isolation)
taints:
  - key: "squad.github.com/pool"
    value: "monitor"
    effect: "NoSchedule"
```

### KEDA ScaledObject for Agent Pool

```yaml
# infrastructure/keda/picard-scaledobject.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: picard-github-issues
  namespace: squad
spec:
  scaleTargetRef:
    name: picard
  minReplicaCount: 0
  maxReplicaCount: 3
  cooldownPeriod: 300
  pollingInterval: 60
  triggers:
    - type: github-runner
      metadata:
        # Scale based on open squad:picard labelled issues
        githubApiURL: "https://api.github.com"
        owner: "tamirdresher_microsoft"
        repo: "tamresearch1"
        labels: "squad:picard"
        targetWorkflowQueueLength: "2"
      authenticationRef:
        name: keda-github-token
```

---

## 6. Model Selection

### Comparison Matrix

| Model | Parameters | VRAM | AKS SKU | Latency (first token) | Throughput | Triage Quality | Code Quality |
|-------|-----------|------|---------|----------------------|-----------|----------------|-------------|
| **phi-3-mini-128k-instruct** | 3.8B | 8 GB | NC4as_T4_v3 | ~1.2s | ~45 tok/s | ★★★★☆ | ★★☆☆☆ |
| phi-3-medium-128k-instruct | 14B | 28 GB | NC8as_T4_v3 | ~3.1s | ~18 tok/s | ★★★★★ | ★★★☆☆ |
| **mistral-7b-instruct** | 7B | 16 GB | NC4as_T4_v3 | ~1.8s | ~32 tok/s | ★★★★☆ | ★★★☆☆ |
| llama-3.1-8b-instruct | 8B | 20 GB | NC8as_T4_v3 | ~2.2s | ~28 tok/s | ★★★★☆ | ★★★☆☆ |
| falcon-7b-instruct | 7B | 16 GB | NC4as_T4_v3 | ~1.6s | ~35 tok/s | ★★★☆☆ | ★★☆☆☆ |

**Recommended Squad fallback stack:**

1. **Tier 1 (phi-3-mini):** Default KAITO fallback. Fits on the cheapest T4 GPU SKU. Sufficient
   for Ralph's classification tasks, Scribe's structured logging, and Kes's scheduling lookups.
   Cost-optimal.

2. **Tier 2 (mistral-7b):** Optional second workspace for code-adjacent tasks (Seven's research
   summaries, Q's fact-checking). Only provisioned when phi-3-mini is insufficient and Copilot
   remains throttled >30 minutes.

**Not recommended:**
- `llama-3.1-8b-instruct`: Requires HuggingFace gated access (Meta license acceptance), adds
  ops overhead for no meaningful quality gain over Mistral-7B for Squad's use cases.
- `phi-3-medium`: Cost 2.5x more than phi-3-mini. Upgrade path if phi-3-mini proves insufficient,
  not day-one recommendation.

### Model Caching and Cold-Start Mitigation

KAITO model images are large (phi-3-mini ≈ 8 GB OCI layer). Two strategies reduce cold-start:

**Option A: Node Image Pre-cache (recommended)**
```bash
# Apply a DaemonSet that pre-pulls the model image to all GPU-capable nodes
# KAITO provides this via the NodeClaim / NAP integration
az aks nodepool add \
  --cluster-name aks-squad-prod \
  --name gpustandby \
  --node-count 1 \
  --node-vm-size Standard_NC4as_T4_v3 \
  --node-taints "nvidia.com/gpu=true:NoSchedule" \
  --labels "squad.github.com/pool=gpu-inference" \
  --mode User
# Keep 1 warm node — pre-caches model image, ready in ~2 min instead of ~15 min
```
Cost: ~$0.90/hr for one always-warm T4 node. Justified if fallback SLA < 5 minutes matters.

**Option B: Accept cold-start (cheaper)**
Scale GPU nodes to zero between fallback events. Cold-start: 8–15 min (node provision) + 2–4 min
(model load) = 10–19 minutes total. For background tasks (Ralph triage), this is acceptable
— triage tasks are queued, not user-facing.

**Recommendation:** Start with Option B (no warm node). Add warm node only if monitoring shows
>5 fallback cold-start events per day.

---

## 7. Cost Analysis

### Azure VM Pricing (East US 2, as of 2026-Q1)

| VM SKU | vCPU | RAM | GPU | Price/hr (On-Demand) | Price/hr (1-yr Reserved) |
|--------|------|-----|-----|---------------------|--------------------------|
| Standard_B4ms | 4 | 16 GB | — | ~$0.17 | ~$0.10 |
| Standard_D4as_v5 | 4 | 16 GB | — | ~$0.19 | ~$0.12 |
| Standard_D4s_v5 | 4 | 16 GB | — | ~$0.19 | ~$0.12 |
| Standard_NC4as_T4_v3 | 4 | 28 GB | 1x T4 (16 GB) | ~$0.53 | ~$0.33 |
| Standard_NC8as_T4_v3 | 8 | 56 GB | 1x T4 (16 GB) | ~$0.75 | ~$0.47 |

### Scenario Comparison

#### Scenario A: No KAITO (current state equivalent)
- Cost: $0 additional
- Outcome: Background agents stall during rate-limiting events

#### Scenario B: Always-On GPU Node (1x NC4as_T4_v3)
- Monthly cost: `$0.53 × 24 × 30 = ~$382/month`
- Model always warm, ~2 min response on fallback
- **Overkill for sporadic fallback.** GPU idle >95% of time.

#### Scenario C: On-Demand via KAITO NAP (recommended)
- Assumption: fallback events 2×/day, each lasting 30 min average
- Active GPU time: `2 × 0.5 hr × 30 days = 30 hr/month`
- Cost: `30 × $0.53 = ~$16/month`
- Plus 1 warm standby node (Option A): `$0.53 × 24 × 30 = ~$382/month` — too expensive
- **NAP without warm node: ~$16/month. Accept cold-start.**

#### Scenario D: 1-yr Reserved GPU Node (partial commitment)
- 1 x NC4as_T4_v3 reserved: `$0.33 × 24 × 30 = ~$238/month`
- Justified only if fallback events average >18 hr/day — unlikely for Squad

### Total Monthly Cost Estimate (full Squad-on-K8s + KAITO)

| Component | SKU | Qty | Hrs/mo | $/hr | Monthly |
|-----------|-----|-----|--------|------|---------|
| System pool | Standard_D4s_v5 | 2 | 720 | $0.19 | $274 |
| Monitor pool | Standard_B4ms | 1 | 720 | $0.17 | $122 |
| Agent pool (Spot, avg 30% active) | Standard_D4as_v5 | 3 avg | 216 | $0.07 (spot) | $45 |
| GPU fallback (on-demand, sporadic) | Standard_NC4as_T4_v3 | ~30 hr/mo | 30 | $0.53 | $16 |
| AKS management fee | — | 1 cluster | 720 | ~$0.10 | $72 |
| ACR (Standard) | — | — | — | — | $10 |
| Key Vault operations | — | — | — | — | $5 |
| Log Analytics (ingestion) | — | — | — | ~5 GB/mo | $12 |
| **Total** | | | | | **~$556/month** |

> This is significantly cheaper than running 5+ Windows DevBoxes as dedicated agent machines
> (equivalent compute would cost ~$800–$1,200/month without Spot pricing and with idle time).

---

## 8. Answering the Research Questions

### Q1: Minimum GPU SKU for Useful Local Inference

**Answer: `Standard_NC4as_T4_v3`** (4 vCPU, 28 GB RAM, 1× NVIDIA T4 16 GB VRAM)

- phi-3-mini-128k-instruct requires ~8 GB VRAM → fits comfortably with room for vLLM overhead
- mistral-7b-instruct requires ~16 GB VRAM → fits in T4 with quantization (INT4 via `bitsandbytes`)
- Quantized mistral on T4: ~5% quality degradation, acceptable for fallback triage

The smaller `Standard_NC2as_T4_v3` (2 vCPU) is **not recommended** — insufficient CPU for vLLM
tokenization overhead at Squad's concurrency levels (up to 5 concurrent agent requests).

For Mistral-7B without quantization, `Standard_NC8as_T4_v3` is required (same T4 GPU, more
CPU/RAM buffer). The cost difference is modest ($0.22/hr) and worth the operational simplicity
of not managing quantization settings.

### Q2: Can KAITO Endpoints Be Shared Across Multiple Squad Teams?

**Answer: Yes, with caveats.**

A KAITO `Workspace` exposes a standard ClusterIP Kubernetes Service. Any pod in the `squad`
namespace (or with appropriate NetworkPolicy rules) can call it. This means:

- All Squad agent pods (Ralph, Picard, Seven, Scribe) can share one `squad-fallback-phi3` workspace
- Cross-namespace sharing requires an additional Service or Ingress — possible but adds complexity
- For multi-team Squad deployments (e.g., separate namespace per project), a **shared KAITO
  workspace in a `squad-inference` namespace** with cross-namespace NetworkPolicy is the right pattern

```yaml
# NetworkPolicy to allow squad namespace to reach squad-inference namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-squad-to-inference
  namespace: squad-inference
spec:
  podSelector:
    matchLabels:
      kaito.sh/workspace: squad-fallback-phi3
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: squad
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: squad-team2
```

**Shared endpoint consideration:** vLLM supports concurrent requests, but phi-3-mini on T4
handles ~16 concurrent sequences. If >3 Squad teams share one workspace during a rate-limit
event, throughput degrades. Solution: KAITO supports `count: 2` (multiple inference pods)
behind the same Service for horizontal scaling.

### Q3: Cost Profile — Always-On vs On-Demand

See [Section 7](#7-cost-analysis) for full analysis. Summary:

| Mode | Monthly Cost | Cold-Start Latency | Recommendation |
|------|-------------|-------------------|----------------|
| Always-on (1 GPU node) | ~$382 | ~2 min | Only if >18 hr/day fallback usage |
| On-demand via NAP | ~$16–$50 | 10–19 min | **Recommended start** |
| Warm standby (1 node, pre-cached) | ~$398 | ~2 min | Consider after 3 months of data |
| 1-yr Reserved | ~$238 | ~2 min | Break-even at ~11 hr/day active usage |

**Decision:** Start with on-demand NAP. Add Application Insights alert when cold-start events
exceed 5/day and reassess at the 3-month mark.

### Q4: KAITO Model Caching and Cold-Start Mitigation

KAITO's model caching operates at two levels:

**Level 1: OCI Image Layer Caching**
KAITO model images are hosted in Microsoft Container Registry (MCR). Once pulled to a node,
layers are cached in the node's container image cache. If NAP provisions the same VM size,
Docker layer cache is warm from the previous node's image (AKS VHD base). However, model
weights are stored in image layers unique to each model — a fresh node has no cache.

**Level 2: Node-Level Warm Cache (explicit)**
Apply a 1-node "standby" node pool with the GPU VM pre-provisioned. KAITO will schedule
model pre-warm Pods to this node. When a fallback event occurs, model load time drops from
`15 min` to `2–3 min` (model weights already in GPU VRAM or RAM).

```bash
# Pre-warm: keep 1 GPU node always running with model loaded
kubectl apply -f - <<EOF
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: squad-fallback-phi3-warm
  namespace: squad
  annotations:
    kaito.sh/warmup: "true"   # Pre-load model, accept zero requests
spec:
  resource:
    instanceType: Standard_NC4as_T4_v3
    count: 1
    ...
  inference:
    preset:
      name: phi-3-mini-128k-instruct
EOF
```

**KAITO does not yet have a native "standby" mode** (as of v0.3.x). The workaround is keeping
the Workspace active with `minReplicas: 1` in the backing Deployment, which keeps the pod
running even with zero requests — effectively keeping the model in VRAM.

---

## 9. Implementation Roadmap

### Phase 1 (Weeks 1–4): Foundation — Squad on AKS (No KAITO)
*Prerequisite for KAITO integration. Covered by #1059/#1060.*

- [ ] Deploy AKS cluster with system + monitor + agent node pools
- [ ] Configure Workload Identity for GitHub auth
- [ ] Deploy Ralph CronJob + Picard Deployment via Helm chart
- [ ] Establish baseline monitoring (Log Analytics, Azure Monitor alerts)
- [ ] **Success metric:** Ralph's 5-min loop running on AKS with zero manual intervention for 7 days

### Phase 2 (Weeks 5–8): KAITO Integration — phi-3-mini Fallback
*Core of this research document.*

- [ ] Enable AKS AI Toolchain Operator add-on
- [ ] Apply `squad-fallback-phi3` Workspace CRD
- [ ] Implement `kaito-phi3` model provider adapter in Squad's model router
- [ ] Add rate-limit detection middleware to model router (read X-RateLimit headers from Copilot API)
- [ ] Wire fallback chain: `copilot → kaito-phi3` for Ralph and Scribe
- [ ] Add `[DEGRADED MODE]` metadata flag to all KAITO-served responses
- [ ] Instrument cold-start latency in Application Insights
- [ ] **Success metric:** Ralph continues triaging issues during simulated Copilot rate-limit event

### Phase 3 (Weeks 9–12): Mistral-7B for Code-Adjacent Fallback
*Only if Phase 2 data shows phi-3-mini insufficient for some tasks.*

- [ ] Apply `squad-fallback-mistral` Workspace CRD
- [ ] Extend fallback chain for Seven and Q agents
- [ ] Load test: 5 concurrent Squad agents × Mistral-7B on NC8as_T4_v3
- [ ] Document quality benchmarks vs Copilot baseline (BLEU/ROUGE scores on triage tasks)

### Phase 4 (Weeks 13–16): Operational Hardening
*Productionize the KAITO integration.*

- [ ] GitOps: Move KAITO Workspace manifests to `infrastructure/kaito/` in this repo
- [ ] KEDA ScaledObject for KAITO inference pods (scale based on pending request queue)
- [ ] Cost alerting: Azure Budget alert at $100/month for GPU compute
- [ ] Runbook: "KAITO Workspace not ready" incident response
- [ ] Decision: warm standby node (based on 3-month cold-start telemetry)

### Phase 5 (Future): Multi-Team KAITO
*When Squad is deployed for >1 team.*

- [ ] Dedicated `squad-inference` namespace for shared KAITO workspaces
- [ ] NetworkPolicy for cross-namespace access
- [ ] Autoscaling KAITO replicas based on combined demand across teams

---

## 10. Helm Integration

### Values Changes Required

The existing `infrastructure/helm/squad-agents/values.yaml` needs a `kaito` section:

```yaml
# -- KAITO fallback inference (add to squad-agents/values.yaml)
kaito:
  enabled: false   # Set to true after Phase 2 deployment

  # Primary fallback workspace
  phi3:
    enabled: true
    workspaceName: "squad-fallback-phi3"
    namespace: "squad"
    serviceURL: "http://squad-fallback-phi3.squad.svc.cluster.local/v1"
    # Model identifier for OpenAI-compatible API
    modelId: "phi-3-mini-128k-instruct"
    # Max tokens to request (keep low for triage tasks)
    maxTokens: 2048
    contextWindow: 8192

  # Secondary fallback workspace (code-adjacent tasks)
  mistral:
    enabled: false
    workspaceName: "squad-fallback-mistral"
    serviceURL: "http://squad-fallback-mistral.squad.svc.cluster.local/v1"
    modelId: "mistral-7b-instruct"
    maxTokens: 4096
    contextWindow: 32768

  # Model router configuration
  router:
    # Copilot rate-limit threshold: switch to KAITO at this HTTP status code
    rateLimitStatusCode: 429
    # Or switch at this X-RateLimit-Remaining header value
    rateLimitHeadroomTokens: 100
    # Add [DEGRADED MODE] to KAITO responses
    annotateResponses: true
    # Timeout for KAITO requests (longer than Copilot due to local inference latency)
    timeoutSeconds: 120
```

### ConfigMap Injection

```yaml
# infrastructure/helm/squad-agents/templates/configmap.yaml (addition)
{{- if .Values.kaito.enabled }}
KAITO_ENABLED: "true"
KAITO_PHI3_URL: {{ .Values.kaito.phi3.serviceURL | quote }}
KAITO_MISTRAL_URL: {{ .Values.kaito.mistral.serviceURL | quote }}
KAITO_RATE_LIMIT_STATUS_CODE: {{ .Values.kaito.router.rateLimitStatusCode | quote }}
KAITO_RATE_LIMIT_HEADROOM: {{ .Values.kaito.router.rateLimitHeadroomTokens | quote }}
KAITO_ANNOTATE_RESPONSES: {{ .Values.kaito.router.annotateResponses | quote }}
{{- end }}
```

---

## 11. Open Questions & Risks

### Open Questions

| # | Question | Owner | Target |
|---|----------|-------|--------|
| OQ-1 | Does Squad's model router abstraction support base URL override per provider? | Data | Phase 2 kickoff |
| OQ-2 | What headers does the Copilot API return for rate-limit state? Need to verify `X-RateLimit-*` header names. | Data | Phase 2 kickoff |
| OQ-3 | Is `kaito.sh/v1alpha1` the current API version, or has it graduated to v1beta1/v1? | B'Elanna | Phase 2 kickoff |
| OQ-4 | KAITO NAP integration: does it require AKS Automatic, or does it work with standard AKS + NAP add-on? | B'Elanna | Phase 2 Week 1 |
| OQ-5 | What is the phi-3-mini quality score on Squad's actual triage prompts? Need benchmark before committing. | Seven | Phase 2 Week 2 |

### Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| phi-3-mini quality too low for Ralph's triage labels | Medium | Medium | Benchmark in Phase 2 Week 2; fall back to mistral-7b if needed |
| KAITO cold-start (10–19 min) unacceptable for use case | Low | Medium | Keep 1 warm GPU node if P50 fallback latency exceeds 5 min |
| GPU node pool provisioning failures in `eastus2` | Low | High | Add `westus2` as backup region in NAP config |
| vLLM memory leak on long-running Squad inference | Low | Medium | Set KAITO Workspace pod memory limit; configure periodic restart |
| KAITO Workspace CRD version mismatch after AKS upgrade | Medium | Low | Pin KAITO operator version in Helm; test in staging on AKS upgrades |
| Squad agents don't detect KAITO degraded mode correctly | Medium | Medium | Integration test: simulate 429 from Copilot mock, verify KAITO path |

---

## References

- [KAITO GitHub Repository](https://github.com/Azure/kaito)
- [AKS AI Toolchain Operator Documentation](https://learn.microsoft.com/en-us/azure/aks/ai-toolchain-operator)
- [AKS Automatic Overview](https://learn.microsoft.com/en-us/azure/aks/intro-aks-automatic)
- [AKS Node Autoprovision (NAP)](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision)
- [KEDA GitHub Scaler](https://keda.sh/docs/latest/scalers/github-runner/)
- [vLLM OpenAI-Compatible Server](https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html)
- [Azure NC4as T4 v3 Pricing](https://azure.microsoft.com/en-us/pricing/details/virtual-machines/linux/)
- [Existing Squad-on-AKS Guide](../squad-on-aks.md) (related: #1060)
- [Squad Kubernetes Architecture](../squad-on-kubernetes-architecture.md) (related: #1059)
- [Squad ADR-002: Squad on Kubernetes](../adr-002-squad-on-kubernetes.md)

---

*Authored by Seven. If the docs are wrong, the product is wrong.*
