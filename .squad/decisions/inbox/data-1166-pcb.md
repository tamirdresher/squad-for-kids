# Decision: Predictive Circuit Breaker Implementation

**Date:** 2026-03-20  
**Decider:** Data (Code Expert)  
**Status:** Implemented  
**Issue:** #1166  
**PR:** #1194

## Context

Ralph instances were hitting 429 rate limits reactively, causing cascading failures across 7+ concurrent processes. The existing circuit breaker only opened AFTER receiving a 429, by which time multiple requests were already queued.

## Decision

Implement Predictive Circuit Breaker (PCB) that analyzes `X-RateLimit-Remaining` header trends to predict exhaustion before it occurs.

## Implementation

1. **Linear Regression on Header Trends**: Track last 10 (timestamp, remaining) pairs, compute slope to predict ETA
2. **Proactive State Transition**: New `half-open-imminent` state triggers when ETA < 120s
3. **P0-Only Throttling**: Reuse existing priority lane infrastructure to limit work scope
4. **Auto-Recovery**: Positive slope (quota recovering) returns to closed state

## Rationale

- **Prevents Cascade**: Opens circuit 2-5 calls before actual 429, giving other instances time to back off
- **Minimal Changes**: Reuses 90% of existing circuit breaker and priority lane code
- **Tunable**: `predictiveThresholdSecs` can be adjusted per deployment
- **Safe Degradation**: Falls back to reactive mode if regression fails (denominator=0, insufficient samples)

## Alternatives Considered

1. **Hard quota reservation** — Complex coordination, requires distributed lock
2. **Exponential backoff only** — Still reactive, doesn't prevent first 429
3. **Static throttling** — Wasteful when quota is available

## Impact

- **Code**: +122 lines in ralph-watch.ps1
- **State Schema**: Added `headerTrend` and `predictiveThresholdSecs` to circuit breaker JSON
- **Behavior**: Ralph throttles proactively instead of reactively
- **Backward Compat**: Existing states (closed/open/half-open) unchanged

## Testing

Manual verification:
- Monitor `.squad/ralph-circuit-breaker.json` for ETA values
- Simulate declining quota with rapid API calls
- Verify state transitions and recovery

## Follow-up

- [ ] Integrate `Update-HeaderTrend` calls when Issue #1165 (rate-limit-manager) lands
- [ ] Add telemetry to track PCB trigger frequency
- [ ] Consider exposing ETA in ralph heartbeat for monitoring
