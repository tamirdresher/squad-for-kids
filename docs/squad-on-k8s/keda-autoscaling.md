# KEDA Autoscaling for Squad Agents

> **Status:** Draft · Issue [#1134](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1134)  
> **Author:** B'Elanna (Infrastructure Expert)  
> **Related:** [#1059](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1059) Squad on K8s architecture · [#979](https://github.com/tamirdresher_microsoft/tamresearch1/issues/979) Rate limit research · [squad-on-aks.md](../squad-on-aks.md)

---

## Table of Contents

1. [Why Autoscaling Matters for Squad](#1-why-autoscaling-matters-for-squad)
2. [KEDA Overview and AKS Integration](#2-keda-overview-and-aks-integration)
3. [Trigger Architecture](#3-trigger-architecture)
4. [Custom Scaler Design: GitHub Rate Limits](#4-custom-scaler-design-github-rate-limits)
5. [Copilot Token Usage Scaler](#5-copilot-token-usage-scaler)
6. [Scale-to-Zero Strategy](#6-scale-to-zero-strategy)
7. [HPA vs KEDA Comparison](#7-hpa-vs-keda-comparison)
8. [Deployment Guide](#8-deployment-guide)
9. [Observability and Alerts](#9-observability-and-alerts)
10. [Known Limitations and Future Work](#10-known-limitations-and-future-work)

---

## 1. Why Autoscaling Matters for Squad

Squad agents are **bursty by nature**. Activity follows GitHub issue flow:

- A batch of issues gets labelled `squad:active` → all agents need to run simultaneously
- Nothing happens for hours → zero pods are needed
- A Copilot API rate limit is hit → running more pods makes things _worse_, not better

The original Helm chart kept `replicaCount: 1` as a static value. This works for a single-agent
prototype but breaks under real workloads:

| Scenario | Static replica | KEDA scaling |
|---|---|---|
| 10 open issues labelled `squad:active` | 1 pod (bottleneck) | Up to 5 pods (parallel work) |
| No open issues | 1 pod (wasted cost, idle CPU) | 0 pods (scale to zero) |
| GitHub rate limit at 4% remaining | 1 pod (hammers API, gets 429s) | 0 pods (back off until reset) |
| Copilot 429 spike | 1 pod (retries → worse) | 0 pods (backoff cooldown) |

### The real bottleneck: rate limits, not queue depth

The previous KEDA config (`picard-deployment.yaml`) scaled solely on **open issue count**. This
ignores the actual constraint that limits agent throughput: the GitHub API rate limit and the
Copilot token budget.

```
GitHub Core API:    5,000 requests/hour per authenticated user
GitHub Search API:  30 requests/minute per authenticated user
Copilot Free tier:  ~50 completions/month (hard cap)
Copilot Pro:        ~unlimited, but subject to per-minute throttling
```

When multiple pods share a single token (`GH_TOKEN`) they share the same rate limit bucket.
Spinning up more pods when headroom is low accelerates token exhaustion and causes cascading
429 failures across all pods.

---

## 2. KEDA Overview and AKS Integration

[KEDA](https://keda.sh) (Kubernetes Event-Driven Autoscaler) is a CNCF graduated project that
extends the standard Horizontal Pod Autoscaler (HPA) with **event-source triggers**. Rather
than scaling on CPU/memory, KEDA can scale on GitHub issue count, queue depth, Prometheus
metrics, HTTP request rates, and dozens of other sources.

### Installing KEDA on AKS

Microsoft ships KEDA as a managed AKS add-on (no Helm install needed):

```bash
# Enable KEDA add-on (idempotent)
az aks update \
  --resource-group rg-squad-prod \
  --name aks-squad-prod \
  --enable-keda

# Verify
kubectl get pods -n kube-system -l app=keda-operator
# Expected: keda-operator-xxx   Running
```

The managed add-on is kept up to date by AKS, receives security patches automatically, and
integrates with Azure Monitor for KEDA-specific metrics.

### How KEDA works with the Squad Helm chart

```
GitHub Issues
  label: squad:active         ─────────────────┐
  (open count)                                  │
                                                ▼
GitHub /rate_limit             ──────► KEDA ScaledObject ──► HPA ──► Deployment replicas
  remaining/limit ratio                         │
                                                │        picard (0–5 pods)
Prometheus metrics             ──────────────────┘
  copilot_429_responses_total
```

KEDA evaluates each trigger every `pollingInterval` seconds (30s in our config). It sets the
HPA `externalMetric` target value based on trigger output, and the HPA adjusts replica count.

---

## 3. Trigger Architecture

The Squad ScaledObject (`infrastructure/keda/squad-scaledobject.yaml`) uses three triggers
working together to implement **intelligent, rate-aware scaling**.

### Trigger 1: Active issue queue depth (GitHub built-in scaler)

```yaml
- type: github
  metadata:
    owner: "tamirdresher_microsoft"
    repo:  "tamresearch1"
    labels: "squad:active"
    state:  "open"
    targetIssueCount: "2"   # 1 replica per 2 open issues
```

**Behaviour:**
- 0 issues → 0 replicas (scale to zero)
- 1–2 issues → 1 replica
- 3–4 issues → 2 replicas
- 9–10 issues → 5 replicas (capped at `maxReplicaCount`)

This trigger uses the KEDA GitHub scaler which calls the GitHub REST API with the
`github-rate-trigger-auth` TriggerAuthentication (PAT sourced from Azure Key Vault).

### Trigger 2: GitHub API rate-limit headroom (Prometheus)

```yaml
- type: prometheus
  metadata:
    serverAddress: "http://prometheus-operated.monitoring.svc.cluster.local:9090"
    metricName: github_rate_limit_remaining_ratio
    threshold: "0.1"
    query: >
      min(github_rate_limit_remaining{resource="core"}
          / github_rate_limit_limit{resource="core"})
    ignoreNullValues: "true"
```

**Behaviour:**
- When ratio > 0.1 (> 10% remaining): trigger is "inactive" — no scale-down
- When ratio ≤ 0.1 (≤ 500 requests remaining): trigger returns 0 → enables cooldown
  → if no other triggers are active, pods scale to zero

**Key insight:** This trigger doesn't _add_ replicas; it removes the floor that keeps pods
alive. By returning 0 when rate-limited, it allows KEDA's `minReplicaCount: 0` + `cooldownPeriod`
to drain the deployment, giving the rate limit window time to reset (max 1 hour for Core API).

### Trigger 3: Copilot 429 backoff (Prometheus, optional)

```yaml
- type: prometheus
  metadata:
    metricName: copilot_rate_limit_hit_rate
    threshold: "5"          # > 5 per minute = aggressive scale-down signal
    query: >
      sum(rate(copilot_429_responses_total{namespace="squad"}[1m])) * 60
    ignoreNullValues: "true"
```

**Behaviour:**
- 0–5 429s/min: trigger inactive
- > 5 429s/min: trigger returns metric / threshold > 1 → KEDA scales down
- `ignoreNullValues: "true"`: if squad-metrics-exporter isn't deployed yet, this trigger
  is skipped cleanly — it never accidentally triggers a scale-down

---

## 4. Custom Scaler Design: GitHub Rate Limits

The KEDA `prometheus` trigger for rate limits requires a Prometheus endpoint that exposes
the GitHub rate limit state. This is provided by the **squad-rate-limit-exporter** — a
small sidecar or standalone Deployment.

### Exporter design

```
┌─────────────────────────────────────────────┐
│  squad-rate-limit-exporter                  │
│                                             │
│  every 30s:                                 │
│    GET https://api.github.com/rate_limit    │
│    Authorization: Bearer $GH_TOKEN          │
│                                             │
│  exposes :9091/metrics                      │
│    github_rate_limit_remaining{resource}    │
│    github_rate_limit_limit{resource}        │
│    github_rate_limit_reset_unix{resource}   │
│    github_rate_limit_remaining_ratio        │
└─────────────────────────────────────────────┘
         │
         ▼ scrape (every 30s)
  Prometheus (Azure Monitor Managed Prometheus
              or cluster-local kube-prometheus-stack)
         │
         ▼ PromQL query
  KEDA ScaledObject Trigger 2
```

### Exporter metrics

| Metric | Type | Description |
|---|---|---|
| `github_rate_limit_remaining` | Gauge | Requests remaining in current window |
| `github_rate_limit_limit` | Gauge | Total requests allowed per window |
| `github_rate_limit_reset_unix` | Gauge | Unix timestamp when window resets |
| `github_rate_limit_remaining_ratio` | Gauge | `remaining / limit` (0.0–1.0) |
| `github_rate_limit_window_seconds` | Gauge | Seconds until reset |

### Alternative: header-based tracking (no sidecar)

If deploying the exporter is too heavy, agent pods can expose metrics directly by reading
the `X-RateLimit-Remaining` and `X-RateLimit-Reset` response headers from GitHub API calls
and pushing them to a Prometheus Pushgateway:

```python
# Pseudocode in agent pod
response = requests.get("https://api.github.com/repos/.../issues", headers=auth)
remaining = int(response.headers.get("X-RateLimit-Remaining", 5000))
prometheus_gauge.labels(resource="core").set(remaining)
pushgateway.push_to_gateway(...)
```

---

## 5. Copilot Token Usage Scaler

Copilot API usage is harder to measure than GitHub REST API rate limits because:
1. The Copilot API does not reliably return rate limit headers on every call
2. Token budget tracking is per-billing-period, not per-hour
3. Throttle responses (`429 Too Many Requests`) are the first observable signal

### Tracking 429 responses

The squad-metrics-exporter intercepts HTTP responses from Copilot API calls and counts 429s:

```
copilot_429_responses_total{model="gpt-4o",agent="picard"} 3
```

Combined with KEDA Trigger 3, this drives rapid scale-down when throttling is detected,
allowing the backoff window to clear before new pods attempt API calls.

### Copilot rate limit reset

Unlike GitHub Core API (1-hour window), Copilot per-minute throttling resets in 60 seconds.
The `cooldownPeriod: 300` (5 minutes) in the ScaledObject exceeds this, ensuring pods stay
down long enough for throttling to fully clear before the next scale-up event.

---

## 6. Scale-to-Zero Strategy

Scale-to-zero is KEDA's headline feature for cost management. Squad agents are a perfect
use case: they are **reactive** (triggered by GitHub events) rather than always-on services.

### Flow: issue arrives → pods spin up

```
1. GitHub issue labelled "squad:active"
2. KEDA polls GitHub API (pollingInterval: 30s)
3. Trigger 1 returns count > 0
4. KEDA sets HPA desired = ceil(count / targetIssueCount)
5. HPA creates pod(s)
6. Pod cold-start: pull image (~15s), init (~5s), agent ready (~10s)
   Total: ~30–40s until first agent action
7. Agent works the issue, closes it, removes label
8. KEDA polls again: count = 0
9. cooldownPeriod: 300s begins
10. After 300s with no active triggers → replicas = 0
```

### Cold-start optimisation

To minimise the ~30–40s cold-start latency:
- Use `imagePullPolicy: IfNotPresent` with pre-pulled images on spot node pools
- Configure `scaleDown.stabilizationWindowSeconds: 120` to avoid premature scale-down
  during short pauses between consecutive agent tasks
- Consider a single "warm" pod with `minReplicaCount: 1` during business hours (at the
  cost of always-on compute); revert to 0 outside working hours via a KEDA cron trigger

### Workload Identity and scale-to-zero compatibility

The Azure Workload Identity webhook injects credentials at pod creation time. Scale-to-zero
is fully compatible — each new pod gets fresh federated credentials automatically. No
token refresh issues: OIDC-based federated credentials are re-issued on every pod start.

---

## 7. HPA vs KEDA Comparison

| Capability | Kubernetes HPA | KEDA |
|---|---|---|
| Scale trigger source | CPU, memory, custom metrics (via adapter) | 50+ event sources (GitHub, Prometheus, queues, HTTP...) |
| Scale to zero | ❌ Minimum 1 replica | ✅ `minReplicaCount: 0` |
| Composite triggers | ❌ Single metric per HPA | ✅ Multiple triggers (OR semantics) |
| GitHub issue count | ❌ Requires custom metrics pipeline | ✅ Built-in scaler |
| Prometheus queries | ⚠️ Requires prometheus-adapter + HPA | ✅ Native Prometheus trigger |
| AKS managed add-on | ✅ `--enable-cluster-autoscaler` | ✅ `az aks update --enable-keda` |
| CNCF status | Kubernetes core (GA) | Graduated (2023) |
| Cooldown semantics | `scaleDown.stabilizationWindow` only | `cooldownPeriod` + HPA behaviour combined |
| GitOps friendly | ✅ | ✅ |

**Verdict for Squad agents:** KEDA is the right choice. The ability to scale to zero based
on GitHub issue labels — without maintaining a custom metrics adapter — is the primary driver.
Rate-limit-aware scaling via Prometheus triggers is not achievable with standard HPA.

### Using HPA behaviour inside KEDA

KEDA creates an HPA internally; they co-exist. The standard HPA `behavior` section is
surfaced via KEDA's `advanced.horizontalPodAutoscalerConfig` field, which is exactly what
the `advanced` block in `squad-scaledobject.yaml` uses to tune scale-up/scale-down speed.

---

## 8. Deployment Guide

### Prerequisites

```bash
# 1. Enable KEDA on AKS
az aks update \
  --resource-group rg-squad-prod \
  --name aks-squad-prod \
  --enable-keda

# 2. Ensure squad-runtime-secrets exists (from squad-agents Helm chart)
kubectl get secret squad-runtime-secrets -n squad

# 3. (Optional) Deploy Prometheus for Trigger 2 & 3
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.enabled=false   # disable if using Azure Monitor Managed Grafana
```

### Apply KEDA resources

```bash
# Apply TriggerAuthentication first (Trigger 1 auth)
kubectl apply -f infrastructure/keda/github-rate-scaler.yaml

# Apply ScaledObject
kubectl apply -f infrastructure/keda/squad-scaledobject.yaml

# Verify
kubectl get scaledobject -n squad
# NAME                        SCALETARGETKIND   SCALETARGETNAME   MIN   MAX   READY
# squad-agents-token-scaler   Deployment        picard            0     5     True

kubectl get triggerauthentication -n squad
# NAME                      PODIDENTITY   SECRET   ENV   READY
# github-rate-trigger-auth                    True

kubectl describe scaledobject squad-agents-token-scaler -n squad
```

### Validate scale-to-zero

```bash
# Terminal 1: watch replicas
kubectl get deployment picard -n squad -w

# Terminal 2: trigger scale-up by labelling an issue
gh issue edit <ISSUE_NUMBER> --add-label "squad:active" \
  --repo tamirdresher_microsoft/tamresearch1

# After ~30s: picard should show 1 replica
# Close the issue and wait cooldownPeriod (300s): back to 0
gh issue close <ISSUE_NUMBER> --repo tamirdresher_microsoft/tamresearch1
```

---

## 9. Observability and Alerts

### KEDA-native metrics

KEDA exposes its own Prometheus metrics from the `keda-operator` pod:

```promql
# Current metric value for each trigger
keda_scaler_metrics_value{scaler="github",scaledObject="squad-agents-token-scaler"}

# Is the scaler active (trigger firing)?
keda_scaler_active{scaler="prometheus",scaledObject="squad-agents-token-scaler"}

# Is the ScaledObject paused?
keda_scaled_object_paused{name="squad-agents-token-scaler"}
```

### Recommended PrometheusRule alerts

```yaml
groups:
  - name: squad-keda
    rules:
      # Warn when rate limit headroom is low (before KEDA scales to zero)
      - alert: GitHubRateLimitLow
        expr: github_rate_limit_remaining_ratio < 0.1
        for: 2m
        labels:
          severity: warning
          team: squad
        annotations:
          summary: "GitHub rate limit below 10% — Squad pods will scale down"
          description: >
            github_rate_limit_remaining_ratio = {{ $value | humanizePercentage }}.
            KEDA will scale picard to 0 until the reset window (check
            github_rate_limit_reset_unix for exact time).

      # Alert on Copilot 429 spike
      - alert: CopilotRateLimited
        expr: rate(copilot_429_responses_total[5m]) > 0
        for: 1m
        labels:
          severity: warning
          team: squad
        annotations:
          summary: "Copilot API returning 429s — token budget exhausted or throttled"

      # Critical: scaled to zero while active issues exist
      - alert: SquadScaledToZeroWithActiveIssues
        expr: |
          kube_deployment_spec_replicas{deployment="picard",namespace="squad"} == 0
          and on()
          github_issues_open_count{label="squad:active"} > 0
        for: 5m
        labels:
          severity: critical
          team: squad
        annotations:
          summary: "Picard at 0 replicas but active issues exist"
          description: >
            Likely cause: rate limit hit. Check github_rate_limit_remaining_ratio
            and copilot_429_responses_total. Pods will auto-recover after cooldown.
```

---

## 10. Known Limitations and Future Work

### Current limitations

1. **Trigger 2 and 3 require squad-rate-limit-exporter** — this component does not exist
   yet. `ignoreNullValues: "true"` ensures the ScaledObject is safe to apply before the
   exporter is deployed — Triggers 2/3 are silently skipped when metrics are absent.

2. **Shared GH_TOKEN rate limit bucket** — multiple pods sharing one token draw from the
   same 5,000 req/hr bucket. Horizontal scaling does not increase throughput against the
   API; it only parallelises work _between_ API calls. True throughput scaling requires
   per-pod token rotation via a GitHub App with installation tokens (see #998).

3. **Copilot token budget not programmatically queryable** — there is no public API to
   check remaining Copilot completions. The 429-rate proxy metric is an approximation;
   the actual budget exhaustion may occur without a 429 burst.

4. **Cold-start latency ~30–40s** — acceptable for async issue processing; not suitable
   for interactive (sub-second response) use cases.

### Future work

| Item | Priority | Depends on |
|---|---|---|
| Implement `squad-rate-limit-exporter` sidecar (Go) | High | — |
| Per-pod GitHub App token rotation (eliminate shared PAT) | High | #998 |
| Copilot usage API integration when available | Medium | GitHub roadmap |
| Helm-template `squad-scaledobject.yaml` (values in `values.yaml`) | Medium | — |
| Multi-namespace ClusterTriggerAuthentication rollout | Low | — |
| Azure Managed Prometheus integration | Low | `squad-on-aks.md` §Monitoring |
| Cron-based scale-up warm-up (keep 1 replica during business hours) | Low | — |
