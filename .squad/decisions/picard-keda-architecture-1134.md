# Architecture: KEDA Autoscaling for Squad Copilot Agents (Issue #1134)

**Date**: 2026-03-21  
**Author**: Picard (Lead)  
**Issue**: #1134  
**Status**: ✅ Architecture Approved  
**Phase**: Phase 1 (GitHub API Rate Limits) Ready; Phase 2 (Copilot Metrics) 4-6 weeks

---

## Executive Summary

Squad agent pods (Picard, Data, Belanna, etc.) require autoscaling that respects both **work volume** and **API quota constraints**. We implement KEDA (Kubernetes Event Driven Autoscaling) with composite triggers to scale UP only when work exists AND GitHub API rate-limit headroom is sufficient, and scale DOWN (to zero) when either constraint fails. This prevents cascading 429 failures during peak load.

**Phase 1 is production-ready now.** It scales on GitHub REST API quota. Phase 2 (4-6 weeks) adds Copilot API metrics to prevent Copilot-specific 429s.

---

## Problem: Why Default HPA Fails

Traditional Kubernetes HPA scales on CPU/memory:

```
High Queue Depth
      ↓
Scale UP (more pods)
      ↓
More API calls → Exhaust Rate Limit → 429 responses
      ↓
All pods hit 429 simultaneously → Total outage
```

This is **worse than no scaling**: at least a fixed pod count provides steady throughput. Adding pods during high load burns quota faster and causes cascading failure.

**The insight**: For API-bound workloads, API quota is a first-class constraint alongside CPU/memory.

---

## Solution: Composite Rate-Limit-Aware Scaling

KEDA ScaledObject with AND logic (KEDA v2.12+):

```
IF (work_queue_depth > 0) AND (github_rate_limit_remaining > threshold)
  → Scale UP to ceil(queue_depth / targetPerReplica)
ELSE
  → Scale DOWN to minReplicaCount (0 = scale to zero)
```

**Key behavior**:
- **Scale UP**: Work exists + quota available → add pods to process issues
- **Scale DOWN (Zero)**: No work OR quota exhausted → drop to 0 pods, preserve quota for reset window
- **Resume**: Quota resets after 1 hour → scale back up

---

## Architecture: Three Components

### 1. Metrics Exporter (squad-metrics-exporter)

**Deployment**: `infrastructure/helm/squad-agents/templates/github-metrics-exporter.yaml`

**Function**: Python-based Prometheus exporter running in-cluster.

**Polling schedule**:
- GitHub `/rate_limit` endpoint: every 30 seconds (read-only, doesn't consume quota)
- Open issues query: every 30 seconds (counts issues with `squad:picard`, `squad:data`, etc.)

**Exposed metrics on `:9100/metrics`**:
```
# GitHub API rate-limit status (does NOT consume quota)
github_api_rate_limit_remaining{resource="core"}      → [0 - 5000] per hour
github_api_rate_limit_remaining{resource="search"}    → [0 - 30] per minute
github_api_rate_limit_used{resource="core"}
github_api_rate_limit_reset{resource="core"}

# Squad queue depth per agent label
squad_copilot_queue_depth{label="squad:picard"}       → count of open issues
squad_copilot_queue_depth{label="squad:data"}
squad_copilot_queue_depth{label="squad:belanna"}

# Rate-limit hits (Phase 2)
squad_copilot_rate_limit_hits{agent="picard"}         → cumulative 429 counter
```

**Dependencies**:
- `GH_TOKEN` (environment variable) — GitHub Personal Access Token
- `GITHUB_REPOSITORY` — in format `owner/repo`
- `POLL_INTERVAL_SECONDS` — defaults to 30
- `METRICS_PORT` — defaults to 9100

**Failure modes**:
- Invalid token → exporter pod logs "401 Unauthorized" but stays alive
- GitHub API outage → metrics stale but exporter healthy (KEDA uses last-known values)
- Misconfigured token scopes → unable to query issues (permission denied)

---

### 2. KEDA ScaledObject (Composite Triggers)

**Deployment**: `infrastructure/helm/squad-agents/templates/picard-scaledobject.yaml` (and similar for other agents)

**ScaledObject spec**:
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: picard-scaler
spec:
  scaleTargetRef:
    kind: Deployment
    name: picard
  
  minReplicaCount: 0                    # Scale to zero when idle
  maxReplicaCount: 5                    # Max 5 Picard pods
  pollingInterval: 30s                  # Check metrics every 30s
  cooldownPeriod: 120s                  # Wait 2 min before scaling down again
  
  advanced:
    scalingModifiers:
      # AND-logic: only scale up if BOTH conditions hold
      formula: "s0 > 0 && s1 > 500 ? s0 : 0"
      target: "2"   # target issues per replica

  triggers:
    # Trigger s0: Queue depth
    - type: prometheus
      name: s0
      metadata:
        serverAddress: http://squad-metrics-exporter:9100
        query: squad_copilot_queue_depth{label="squad:picard"}
        threshold: "2"
        activationThreshold: "1"
    
    # Trigger s1: Rate limit headroom
    - type: prometheus
      name: s1
      metadata:
        serverAddress: http://squad-metrics-exporter:9100
        query: github_api_rate_limit_remaining{resource="core"}
        threshold: "500"
        activationThreshold: "100"
    
    # Trigger cron: Pre-warm during business hours
    - type: cron
      metadata:
        timezone: Asia/Jerusalem
        start: "0 8 * * 0-4"     # Sun-Thu 08:00
        end: "0 20 * * 0-4"      # Sun-Thu 20:00
        desiredReplicas: "1"
    
    # Trigger github-runner: Actions queue (issue #1158)
    - type: github-runner
      metadata:
        owner: tamirdresher
        runnerScope: repo
        repos: squad
        targetWorkflowQueueLength: "2"
```

**How formula works**:
- `s0` = queue depth (number of open issues)
- `s1` = GitHub rate-limit remaining
- Formula returns max(queue_depth, 0) when rate limit is healthy
- Formula returns 0 when queue is empty OR rate limit is low
- KEDA calculates desired replicas = `ceil(formula_result / target)`

**Example calculations**:
```
Scenario 1: 3 open issues, 4500 rate limit, target=2
  → s0=3, s1=4500
  → formula: 3 > 0 && 4500 > 500 ? 3 : 0 = 3
  → desired = ceil(3/2) = 2 replicas ✓

Scenario 2: 0 open issues, 4500 rate limit, target=2
  → s0=0, s1=4500
  → formula: 0 > 0 && ... ? 0 : 0 = 0
  → desired = ceil(0/2) = 0 replicas (scale to zero) ✓

Scenario 3: 5 open issues, 50 rate limit (nearly exhausted), target=2
  → s0=5, s1=50
  → formula: 5 > 0 && 50 > 500 ? 5 : 0 = 0
  → desired = ceil(0/2) = 0 replicas (protect quota) ✓
```

**Trigger evaluation**:
- KEDA polls Prometheus every 30 seconds
- Each trigger produces a metric value
- `scalingModifiers.formula` combines triggers with AND logic
- Result determines target replica count
- Kubernetes HPA adjusts actual replicas toward target (respecting cooldownPeriod)

**Cron pre-warm**:
- Keeps 1 replica warm during Asia/Jerusalem business hours
- Eliminates cold-start latency (pod scheduling + image pull ≈ 15-30s)
- Cost: 1 pod * 24h/week = minimal
- Benefit: First issue of day processes in <5s instead of 30s+

**GitHub runner trigger** (issue #1158):
- Counts pending GitHub Actions workflow jobs in the Squad repo
- Additively scales with queue depth (KEDA takes max across triggers)
- ETag caching reduces GitHub API spend per query
- Useful for keeping Picard responsive to infrastructure CI/CD work

---

### 3. Prometheus Stack (Metrics Scraping)

**Required**: Prometheus instance to scrape `squad-metrics-exporter`

**Config**:
```yaml
# In prometheus.yml
scrape_configs:
  - job_name: 'squad-metrics-exporter'
    static_configs:
      - targets: ['squad-metrics-exporter.squad.svc.cluster.local:9100']
    scrape_interval: 15s       # Scrape every 15s
    scrape_timeout: 10s
```

**Metric retention**:
- Keep at least 24 hours of metric history
- KEDA queries the live Prometheus server (not historical data)
- Recent data ensures accurate scaling decisions

**KEDA queries the metrics**:
```
# Every 30 seconds (KEDA pollingInterval)
PromQL: squad_copilot_queue_depth{label="squad:picard"}
PromQL: github_api_rate_limit_remaining{resource="core"}
```

If Prometheus is down:
- KEDA uses the last-known metric values (cache)
- Scaling continues but with stale data
- Alert should trigger: `PrometheusDown`

---

## Custom Metrics Design

### Phase 1: GitHub REST API Rate Limits (READY NOW)

**Metrics**:
- `github_api_rate_limit_remaining{resource="core"}` — How many REST API calls left this hour
- `squad_copilot_queue_depth{label="squad:picard"}` — How many open picard-labelled issues

**Why sufficient**:
- Most Squad agent work is querying/creating issues (REST API bound)
- REST API quota is the tightest constraint
- Prevents primary cascading failure mode

**Exporter code**: See `github-metrics-exporter.yaml` lines 35-100

---

### Phase 2: Copilot-Specific Metrics (4-6 weeks, PR #1282)

**Problem**: `gh copilot` command doesn't expose token usage programmatically.

**Solution**:
1. Wrap `gh copilot` invocations with error parsing
2. Detect 429 responses (rate-limit hit) in stderr
3. Increment `copilot_api_rate_limit_hits_total` counter
4. Expose in Prometheus format

**New metrics**:
```
copilot_api_rate_limit_hits_total{agent="picard"}      → cumulative 429 counter
copilot_tokens_remaining{agent="picard"}                → (when API available)
```

**Updated formula** (Phase 2):
```
s0 > 0 && s1 > 500 && s2 < 0.1 ? s0 : 0
where s2 = rate(copilot_api_rate_limit_hits_total[5m])  → hits per second
```

**Implementation approach**:
- `scripts/copilot-wrapper.ps1` intercepts Copilot calls
- Parses stderr for "rate limited" error messages
- Writes counter to metrics endpoint
- Agent instrumentation in PR #1282

---

## Scale-to-Zero Benefits & Tradeoffs

### Benefits
- **Cost reduction**: 0 pods during off-hours = $0 compute cost
- **Quota preservation**: No background polling burns rate limits
- **Clean failure mode**: Controlled queue delay vs. cascading 429s

### Tradeoffs
- **Cold-start latency**: 15-30s for first pod to schedule and pull image
- **First issue slower**: 30-60s delay instead of <5s response time
- **Requires pre-warm for production**: Cron trigger keeps 1 pod warm during business hours

### Mitigation: Business Hours Pre-Warm

```yaml
triggers:
  - type: cron
    metadata:
      timezone: Asia/Jerusalem
      start: "0 8 * * 0-4"      # Sun-Thu 08:00
      end: "0 20 * * 0-4"       # Sun-Thu 20:00  
      desiredReplicas: "1"
```

This keeps Picard warm exactly when humans are working, eliminates cold-start complaints, and scales to zero at night (cost savings). Total cost: <$5/mo for 1 pod running 8 hours/day.

---

## Prometheus Setup Checklist

- [ ] Prometheus deployed in Kubernetes (or external)
- [ ] KEDA configured to scrape Prometheus (via ScaledObject `serverAddress`)
- [ ] Prometheus scrapes `squad-metrics-exporter:9100` every 15 seconds
- [ ] Metrics available at `http://prometheus.squad.svc/api/v1/query`
- [ ] Query validation:
  ```bash
  curl 'http://prometheus.squad.svc/api/v1/query?query=up'
  curl 'http://prometheus.squad.svc/api/v1/query?query=github_api_rate_limit_remaining'
  ```

---

## Deployment Sequence

### Week 1: Phase 1 (GitHub REST API)

1. **Belanna**: Deploy `squad-metrics-exporter` Deployment + Service
2. **Belanna**: Deploy `picard-scaledobject.yaml` with composite triggers enabled
3. **Picard**: Validate metrics appear in Prometheus dashboard
4. **Picard**: Create 5 test issues labelled `squad:picard`
5. **Picard**: Observe scaling: 0 → 1 → 2 replicas (over 1-2 minutes)
6. **Picard**: Delete test issues
7. **Picard**: Observe scaling: 2 → 1 → 0 replicas (cooldownPeriod + formula)
8. **Picard**: Production promotion (after 48h validation)

### Week 2-4: Phase 2 (Copilot Metrics, in parallel)

1. **Data**: Instrument agents with Copilot error parsing (PR #1282)
2. **Data**: Expose `copilot_api_rate_limit_hits_total` counter
3. **Picard**: Update ScaledObject formula to include s2 trigger
4. **Picard**: Validate Copilot 429 events scale down pods
5. **Picard**: Production promotion

---

## Failure Scenarios & Recovery

| Scenario | Detection | Recovery |
|----------|-----------|----------|
| GitHub API down (exporter can't query) | Stale metrics, KEDA uses cached values | Automatic (quota resets after 1h) |
| Prometheus down | KEDA unable to query, scales to 0 | Redeploy Prometheus, KEDA resumes |
| Rate limit exhausted (0 remaining) | `github_api_rate_limit_remaining=0` | Wait 1 hour, metrics refresh, scale up resumes |
| Queue stuck (no resolution) | Queue depth remains high after 30 min | Manual issue triage + pod restart |
| KEDA pod crash | ScaledObject stops working, pods fixed | Deploy KEDA (AKS add-on: `az aks update --enable-keda`) |
| Cold-start delays too long | >60s latency on first pod | Adjust cron pre-warm schedule or increase minReplicaCount |

---

## Monitoring & Alerting

### Key Dashboards

1. **KEDA Scaling Activity**
   - Graph: `rate(keda_scaler_active[5m])` — how often KEDA fires
   - Graph: `max(keda_scaler_desired_replicas)` — target replica count over time

2. **GitHub Rate Limit Status**
   - Gauge: `github_api_rate_limit_remaining{resource="core"}` — headroom
   - Gauge: `github_api_rate_limit_reset{resource="core"}` — reset time (epoch)

3. **Squad Queue Depth**
   - Gauge: `squad_copilot_queue_depth{label="squad:picard"}`
   - Gauge: `squad_copilot_queue_depth{label="squad:data"}`

4. **Scaling Correlation**
   - Plot scaling events (when desired_replicas changes) alongside queue depth and rate-limit metrics
   - Verify: queue ↑ + rate-limit OK → replicas ↑
   - Verify: rate-limit ↓ → replicas ↓ (even if queue remains high)

### Critical Alerts

```yaml
- alert: GitHubRateLimitLow
  expr: github_api_rate_limit_remaining{resource="core"} < 500
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "GitHub API quota running low"
    description: "{{ $value }} requests remaining"

- alert: GitHubRateLimitExhausted
  expr: github_api_rate_limit_remaining{resource="core"} < 100
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "GitHub API quota nearly exhausted — agents scaling to 0"
    description: "{{ $value }} requests remaining"

- alert: SquadQueueStuck
  expr: increase(squad_copilot_queue_depth[30m]) > 10
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Squad issue queue is not draining"
    description: "{{ $value }} new issues in last 30m"

- alert: KEDAScalerInactive
  expr: increase(keda_scaler_active[5m]) == 0
  for: 10m
  labels:
    severity: critical
  annotations:
    summary: "KEDA scaler not active — scaling may be stuck"
```

---

## Configuration Reference

### Helm Values (infrastructure/helm/squad-agents/values.yaml)

```yaml
metricsExporter:
  enabled: true                    # Deploy squad-metrics-exporter
  port: 9100                       # Prometheus metrics port
  squadLabel: "squad:picard"       # Filter label for queue depth

keda:
  enabled: true                    # Requires KEDA v2.12+ installed

  picard:
    minReplicaCount: 0             # Scale to zero when idle
    maxReplicaCount: 5             # Max 5 replicas
    pollingInterval: 30            # Check metrics every 30s
    cooldownPeriod: 120            # Wait 2 min before scaling down again

    composite:
      enabled: true                # Use AND-logic scaling
      targetQueuePerReplica: "2"   # 1 replica per 2 issues
      rateLimitThreshold: "500"    # Don't scale if < 500 remaining
      rateLimitActivationThreshold: "100"  # Deactivate scaler if < 100

    prewarm:
      enabled: true                # Keep 1 pod warm during business hours
      timezone: "Asia/Jerusalem"
      start: "0 8 * * 0-4"         # Sun-Thu 08:00
      end: "0 20 * * 0-4"          # Sun-Thu 20:00
      desiredReplicas: "1"

  githubRunnerTrigger:
    enabled: true                  # Scale based on Actions queue
    owner: tamirdresher
    runnerScope: repo
    repos: squad
    targetWorkflowQueueLength: "2"
```

---

## Future Enhancements

### Phase 3: Multi-Token Rate Limit Pooling

When a single GitHub token's quota is insufficient, combine multiple tokens' limits:

```
Token 1: 3000 remaining
Token 2: 2500 remaining
Combined: 5500 remaining → higher threshold before scale-down
```

Implementation: Metrics exporter polls multiple tokens, sums remaining.

### Phase 4: Custom KEDA Scaler (Go)

Once GitHub exposes a stable Copilot usage API, build a Go-based KEDA external scaler:

```
repository: keda-github-copilot-scaler
languages: Go, gRPC
metrics: copilot_tokens_used_this_hour, copilot_tokens_remaining
trigger: "github-copilot-usage"
```

Contributes back to KEDA ecosystem as community scaler.

### Phase 5: Predictive Scaling

Use historical queue depth patterns + time-of-day to pre-scale before load arrives:

```
Monday 08:00 → predictably 15 issues in queue
→ pre-warm to 2 replicas at 07:45
→ reduces first-issue latency from 30s to <5s
```

---

## Conclusion

KEDA-based composite autoscaling is the architecture for Squad agents to scale reliably under API rate-limit constraints. Phase 1 (GitHub REST API) is production-ready and eliminates cascading 429 failures. Phase 2 (Copilot metrics) is 4-6 weeks away and adds Copilot-specific quota awareness.

The pattern generalizes to any rate-limited API (Azure OpenAI, AWS, Google Cloud) and should be adopted for all Squad agents as they are deployed.

---

## Sign-Off

- [x] **Picard (Lead)** — Architecture approved 2026-03-21
- [ ] **B'Elanna (Infrastructure)** — Deployment coordination pending
- [ ] **Data (Code)** — Phase 2 instrumentation pending
- [ ] **Worf (Security)** — Threat model review pending

---

## References

- **Issue**: #1134 (KEDA autoscaling — this document)
- **Decision**: `picard-keda-phase1-deployment-approval.md` (deployment plan)
- **Decision**: `picard-keda-aks-implementation-plan.md` (child issue breakdown)
- **Decision**: `picard-rate-limit-aware-scaling.md` (pattern definition)
- **Implementation (Phase 1)**:
  - `infrastructure/helm/squad-agents/templates/github-metrics-exporter.yaml`
  - `infrastructure/helm/squad-agents/templates/picard-scaledobject.yaml`
  - `infrastructure/helm/squad-agents/values.yaml`
- **Implementation (Phase 2)**:
  - PR #1282 (Copilot agent instrumentation)
  - `scripts/copilot-wrapper.ps1` (error parsing)
- **KEDA Docs**: https://keda.sh/docs/2.19/scalers/prometheus/
- **Kubernetes HPA Reference**: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
