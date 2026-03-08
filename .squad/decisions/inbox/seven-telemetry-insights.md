# Decision: Ralph 5-Minute Interval Suboptimal

**Date**: 2026-03-08  
**Author**: Seven (Research & Docs)  
**Status**: Proposed  
**Scope**: Ralph Automation & Scheduling  
**Related**: Issue #152

## Summary

Ralph telemetry analysis from the 15:00 UTC gate window reveals that the current **5-minute polling interval is suboptimal** for Ralph's actual execution characteristics.

## Context

Ralph was configured with a 5-minute interval but telemetry data shows high variability in round duration:
- Initial rounds (cold start): 20–22 minutes each
- Subsequent rounds (warm cache): 4.6 minutes each
- Total observation: 4 rounds over 78.5 minutes
- Failure rate: 0% (perfect stability)

## Findings

### 1. Cold Start Penalty
Ralph's first execution round takes ~20 minutes, indicating deep repository scanning, indexing, or initial enumeration of all issues/PRs. This suggests Ralph is building internal state that persists across runs.

### 2. Efficient Caching
Subsequent rounds complete in ~4.6 minutes with zero change detection, showing Ralph has implemented effective incremental scanning and caching strategy.

### 3. Mismatch: Design vs. Reality
- **Design assumption**: 5-minute interval = 12 rounds/hour
- **Observed reality**: 3 rounds/hour due to cold start penalty and longer-than-expected initial scans
- **Implication**: 5-minute interval is too aggressive and conflicts with Ralph's execution model

## Recommendations

### Primary: Increase Default Interval to 15 Minutes
- Provides headroom for cold-start scanning (20–22 min peaks)
- Reduces scheduling pressure during warm cache operation
- Balances responsiveness (still detects changes within 15 min) with efficiency

### Secondary: Implement Exponential Backoff
- After cold start stabilizes (first 2 hours), increase intervals to 30–60 minutes
- If repository shows no changes for 3+ consecutive rounds, extend to 1-hour intervals
- Reduces unnecessary polling when repository activity is low

### Tertiary: Duration Monitoring
- Cap max round execution at 25–30 minutes to prevent timeout accumulation
- Alert if a single round exceeds 30 min (indicates indexing regression or repository growth)
- Track cache effectiveness quarterly

## Consequences

**Positive:**
- ✅ Aligns scheduling with Ralph's actual performance characteristics
- ✅ Reduces resource utilization (fewer unnecessary 5-min cycles)
- ✅ Maintains high responsiveness (15-min vs. 5-min is still fast)
- ✅ Prevents timeout issues from aggressive scheduling

**Risk Mitigation:**
- ⚠️ Change detection window increases from 5 to 15 minutes — acceptable for a background agent
- ⚠️ Requires configuration update to ralph-watch.ps1 — low risk, tested against live telemetry

## Next Steps

1. Update ralph-watch.ps1 interval from 5 to 15 minutes
2. Monitor for 1 week to confirm cache hit rate and actual round duration
3. If stable, implement exponential backoff logic
4. Document final scheduling strategy in ralph-watch documentation

## Related Decisions

- None currently; first telemetry-based scheduling decision for Ralph
