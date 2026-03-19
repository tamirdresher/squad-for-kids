# Decision: Ralph Self-Healing Watchdog (Issue #988)

**Author:** B'Elanna  
**Date:** 2025-07-24  
**Status:** Implemented  

## Context

Ralph kept failing for the same predictable reasons with nobody noticing for hours:
- Empty model string from circuit breaker schema mismatch (60+12 failures)
- GH_CONFIG_DIR pointing to nonexistent directory (9 failures)
- 123 orphaned agency.exe processes leaked
- CB file rewritten to wrong schema by agents on different branches

## Decision

Added two self-healing functions to `ralph-watch.ps1`:

1. **`Invoke-PreRoundHealthCheck`** — runs before every round to proactively fix:
   - CB schema normalization (nested → flat)
   - Model null/empty detection with CB reset
   - GH auth probing across known config paths
   - Orphaned agency.exe cleanup (threshold: >20)

2. **`Invoke-PostFailureRemediation`** — tiered escalation after consecutive failures:
   - Tier 1 (3-5): Reset CB + clear rate pool cooldown
   - Tier 2 (6-8): Re-probe auth + kill orphans
   - Tier 3 (9-14): Full heal including git pull
   - Tier 4 (15+): Pause 1 hour

All actions logged to `~/.squad/ralph-self-heal.log`.

## Impact

- **Ralph:** Pre-round checks should eliminate the top 3 failure modes before they cause round failures
- **All agents:** No impact — changes are isolated to ralph-watch.ps1
- **Monitoring:** New log file provides audit trail for self-healing actions
- **Ops:** Tier 4 pause prevents runaway failure loops from burning API quota

## Alternatives Considered

- External health-check service: Rejected — adds complexity, ralph-watch.ps1 already has the right context
- Restart-only approach: Rejected — most failures are fixable without restart, and restart loses round state
