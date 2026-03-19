# Decision: Adaptive Rate Limit Research Complete (Issue #979)

**Author:** Seven
**Date:** 2026-03-19
**Issue:** #979
**Status:** Research Done → awaiting team review

## Summary

Comprehensive academic-quality research report produced for issue #979:
`research/rate-limit-multi-agent-research.md`

## Architectural Decision

**Six novel contributions** are proposed as the rate limiting architecture for Squad:

1. **RAAS** (Rate-Aware Agent Scheduling) — proactive GREEN/AMBER/RED throttling from response headers
2. **CMARP** (Cooperative Multi-Agent Rate Pooling) — shared `~/.squad/rate-pool.json` with priority caps and donation register
3. **PCB** (Predictive Circuit Breaker) — extends existing `ralph-circuit-breaker.json` with pre-emptive opening
4. **CDD** (Cascade Dependency Detector) — workflow DAG + BFS backpressure propagation
5. **RET** (Resource Epoch Tracker) — heartbeat-leased allocations using existing `ralph-heartbeat.ps1`
6. **PWJG** (Priority-Weighted Jitter Governor) — non-overlapping per-priority retry windows (P0 recovers before P1/P2 retry)

## Recommendation to Picard/B'Elanna

- Phase 1 (1 week): Add Retry-After header parsing + PWJG to `ralph-watch.ps1` immediately
- Phase 2 (2–3 weeks): Implement CMARP shared pool + RAAS zone enforcement
- Phase 3 (1 month): PCB predictive opening + CDD cascade detection + metrics dashboard

## Publication Target

ICSE / ASE 2026 or NeurIPS Agents Workshop — experimental validation plan included in report §12.
