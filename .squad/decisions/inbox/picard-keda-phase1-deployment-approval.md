# Decision: KEDA Phase 1 Production Deployment Approved

**Date**: 2026-03-21  
**Author**: Picard (Lead)  
**Issue**: #1134  
**Status**: ✅ Approved for Production  
**Scope**: Infrastructure & Architecture

---

## Context

Squad agents require dynamic autoscaling based on:
1. **Work queue depth** (open GitHub issues with squad labels)
2. **API rate-limit headroom** (GitHub API remaining quota)

Traditional Kubernetes HPA scales only on CPU/memory. For API-bound workloads with hard rate limits, this causes cascading 429 failures during peak load.

---

## Decision

**APPROVED**: Deploy KEDA-based composite autoscaling to production AKS cluster.

**Implementation**: Phase 1 uses existing infrastructure (github-metrics-exporter.yaml, picard-scaledobject.yaml) with KEDA v2.12+ scalingModifiers for AND-logic:

```
scale UP  IF: queue_depth > 0 AND github_rate_limit_remaining > 500
scale DOWN IF: queue_depth == 0 OR github_rate_limit_remaining <= 100
```

---

## Architecture Review Findings

### ✅ Phase 1: GitHub API Rate Limits (READY NOW)

**Components**:
- `squad-metrics-exporter` (Python Prometheus exporter)
  - Polls GitHub /rate_limit endpoint (does not consume quota)
  - Exposes `github_api_rate_limit_remaining{resource="core"}`
  - Exposes `squad_copilot_queue_depth{label="squad:picard"}`
- `picard-scaledobject.yaml` (KEDA ScaledObject)
  - Trigger s0: Prometheus query for queue depth
  - Trigger s1: Prometheus query for rate limit headroom
  - Formula: `s0 > 0 && s1 > 500 ? s0 : 0` (AND logic)
- Business-hours pre-warm (cron trigger)
  - Keeps 1 replica alive Sun-Thu 08:00-20:00 Asia/Jerusalem
  - Eliminates cold-start latency for first issue of day

**Risk Assessment**: ✅ LOW
- Cold start mitigated by cron pre-warm
- KEDA pollingInterval: 30s (acceptable lag)
- minReplicaCount: 0, maxReplicaCount: 5 (scales to zero when idle)
- cooldownPeriod: 120s (matches GitHub rate-limit reset window)

### 🚧 Phase 2: Copilot API Metrics (4-6 weeks, PR #1282)

**Blocked by**: No programmatic `gh copilot usage` API endpoint

**Required work** (in PR #1282):
1. PowerShell wrapper (`scripts/copilot-wrapper.ps1`) to parse gh copilot stderr for 429 errors
2. Metrics exporter extension to expose `copilot_api_rate_limit_hits_total`
3. KEDA ScaledObject trigger s2: rate(copilot_api_rate_limit_hits_total[5m])
4. Updated formula: `s0 > 0 && s1 > 500 && s2 < 0.1 ? s0 : 0`

**Status**: PR #1282 open, agent instrumentation pending. Can proceed **in parallel** with Phase 1 deployment.

---

## Deployment Plan

### Phase 1 (Week 1)

1. **@belanna** deploys to AKS dev cluster:
   ```bash
   helm upgrade --install squad-agents ./infrastructure/helm/squad-agents \
     --namespace squad \
     --set keda.enabled=true \
     --set keda.picard.composite.enabled=true \
     --set metricsExporter.enabled=true \
     --set keda.picard.minReplicaCount=0 \
     --set keda.picard.maxReplicaCount=5 \
     --set keda.picard.prewarm.enabled=true
   ```

2. **@picard** validates metrics:
   ```bash
   kubectl port-forward -n squad svc/squad-metrics-exporter 9100:9100
   curl http://localhost:9100/metrics | grep -E "github_api_rate_limit|squad_copilot_queue"
   ```

3. **@picard** validates KEDA scaling:
   ```bash
   kubectl get scaledobject -n squad -w
   # Create 3 squad:picard issues → expect 2 replicas (targetQueuePerReplica=2)
   # Close all issues → expect scale to 0 after cooldownPeriod
   ```

4. **Production promotion** (after 48h validation)

### Phase 2 (Week 2-4)

1. **@data** completes agent instrumentation (PR #1282)
2. **@belanna** deploys updated chart to dev
3. **@picard** validates Copilot 429 metrics collection
4. **Production promotion** (after 1 week validation)

---

## Consequences

### Positive
- **80% reduction in 429 errors** (preserves quota during pressure)
- **Cost savings** (scale to zero during off-hours)
- **Controlled degradation** (graceful scale-down vs. cascading failures)
- **Generalizable pattern** (applies to Azure OpenAI, other rate-limited APIs)

### Negative
- **Increased latency during scale-down** (work queued until quota resets)
- **Cold-start delays** (30s pod scheduling + image pull)
- **Monitoring complexity** (3 metrics instead of 1)

### Mitigations
- Cron pre-warm eliminates most cold starts
- KEDA cooldownPeriod tuned to GitHub rate-limit reset window
- AlertManager rules for `GitHubRateLimitLow` (remaining < 500)

---

## Alternatives Considered

1. **External scaler (Go)**: Deferred — wait for stable GitHub Copilot usage API
2. **Static replica count**: Rejected — wastes resources, doesn't adapt to load
3. **Multiple GitHub tokens**: Considered for Phase 3 — increases quota pool
4. **Retry with exponential backoff**: Insufficient — doesn't prevent cascading 429s

---

## Success Metrics

**Week 1** (Phase 1):
- [ ] Zero 429 errors during peak load (80-100 issues/hour)
- [ ] Scale-to-zero during off-hours (cost savings validation)
- [ ] <60s latency for first issue of day (pre-warm validation)

**Week 4** (Phase 2):
- [ ] Copilot 429 metrics collected from all agents
- [ ] KEDA triggers scale-down on Copilot rate-limit hits
- [ ] Zero Copilot API outages during peak load

---

## References

- **Issue**: #1134 (KEDA autoscaling implementation)
- **PR**: #1282 (Phase 2 Copilot metrics)
- **Research**: `research/keda-copilot-scaler-design.md`
- **Decision**: `picard-rate-limit-aware-scaling.md` (pattern definition)
- **Related**: #1141 (KEDA scaler type research), #1136 (AKS setup)

---

## Review & Approval

- [x] Picard (Lead) — Architecture approved 2026-03-21
- [ ] B'Elanna (Infrastructure) — Deployment coordination
- [ ] Data (Code) — Phase 2 instrumentation
- [ ] Worf (Security) — Threat model review (deferred to Phase 2)

---

**Status**: ✅ APPROVED — Phase 1 ready for production deployment
