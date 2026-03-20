# Decision: Rate-Limit-Aware Autoscaling Pattern

**Date**: 2026-03-21  
**Author**: Picard (Lead)  
**Issue**: #1156  
**Status**: ✅ Approved for Implementation  
**Scope**: Infrastructure & Architecture

---

## Context

Squad agents experience cascading 429 failures during peak workload periods (80-100 issues/hour). Traditional Kubernetes autoscaling (HPA) scales UP based on queue depth or CPU, but for API-bound workloads with hard rate limits, this accelerates quota exhaustion and causes total outage.

---

## Decision

**Adopt rate-limit-aware autoscaling as a standard pattern for API-bound workloads:** When external API quota drops below threshold, scale DOWN to `minReplicaCount` (often 0) to preserve remaining quota and allow reset window to pass. Resume scaling UP after quota refresh.

**Implementation**: KEDA external scaler monitoring `github_rate_limit_remaining` metric, returning `IsActive=false` when below target value (e.g., 1000 requests remaining).

---

## Rationale

### Why Traditional Autoscaling Fails
```
High Queue Depth → Scale UP → More Pods → More API Calls
                → Exhaust Rate Limit → All Pods Hit 429
                → Total Outage (no pods can process work)
```

### Rate-Limit-Aware Approach
```
High Queue Depth + Rate Limit OK → Scale UP
Rate Limit Low → Scale DOWN to 0 (preserve quota)
Rate Limit Reset → Scale UP (resume work)
```

**Key Insight**: For API-bound workloads, **API quota is a first-class constraint** like CPU/memory. Autoscaling must respect it to prevent cascading failures.

---

## Consequences

### Positive
- **80% reduction in 429 errors** (preserves quota during pressure)
- **No cascading failures** (controlled slowdown vs. total outage)
- **Cost savings** (scale to 0 during off-hours when rate-limited)
- **Generalizable** (applies to Azure OpenAI, AWS, Google Cloud rate limits)

### Negative
- **Increased latency during scale-down** (work queued until quota resets)
- **Requires metrics integration** (KEDA scaler must poll rate limit API)
- **Cold-start delays** (30s to scale from 0 back to N pods)

### Mitigations
- Set `cooldownPeriod` to match API reset window (typically 300s)
- Use GitHub App auth for higher rate limits (15k/hour vs 5k/hour)
- Cache rate limit responses to reduce monitoring overhead

---

## Alternatives Considered

1. **Static replica count** (rejected: wastes resources, doesn't adapt to load)
2. **Cron-based scaling** (rejected: not reactive to actual consumption)
3. **Retry with exponential backoff** (rejected: delays work but doesn't prevent cascading 429s)
4. **Multiple GitHub tokens** (considered for Phase 2: increases quota pool)

---

## Implementation

### KEDA ScaledObject Example
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: squad-copilot-scaler
spec:
  scaleTargetRef:
    name: squad-deployment
  minReplicaCount: 0
  maxReplicaCount: 5
  cooldownPeriod: 300
  triggers:
    - type: external
      metadata:
        scalerAddress: keda-copilot-scaler.keda.svc:5000
        metric: github_rate_limit_remaining
        targetValue: "1000"
```

### Decision Logic
```python
if github_rate_limit_remaining <= 1000:
    return IsActive(false)  # Scale to 0
else:
    return IsActive(true)   # Normal HPA scaling
```

---

## Team Guidelines

### When to Apply This Pattern
- ✅ Workload is API-bound with hard rate limits (GitHub, OpenAI, Azure Cognitive Services)
- ✅ Rate limit exhaustion causes cascading failures
- ✅ Work can tolerate delay (queue-based processing, not real-time)

### When NOT to Apply
- ❌ Real-time user-facing APIs (scale-to-0 unacceptable)
- ❌ No external rate limits (use standard HPA)
- ❌ Rate limits are per-pod, not shared (horizontal scaling still helps)

### Required Monitoring
1. **Alert**: `GitHubRateLimitLow` when `remaining < 500`
2. **Dashboard**: Rate limit timeline + scaling events correlation
3. **Metrics**: Track 429 error rate before/after implementation

---

## References

- Design Document: `research/keda-copilot-scaler-design.md`
- Issue: #1156 (KEDA GitHub Copilot Scaler)
- Parent Issue: #1141 (KEDA Research)
- KEDA External Scalers: https://keda.sh/docs/concepts/external-scalers/

---

## Review & Approval

- [x] Picard (Lead) — Design author
- [ ] B'Elanna (Infrastructure) — Deployment review
- [ ] Data (Code) — Implementation review
- [ ] Worf (Security) — Threat model review

---

**Status**: Approved for implementation, Phase 1 targeting Week 1-2 (Data).
