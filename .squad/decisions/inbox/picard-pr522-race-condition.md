# Decision: Race Condition Assessment — PR #522 (bradygaster/squad)

**Date:** 2026-03-23
**Author:** Picard
**Status:** Active

## Finding
Q's race condition alert on bradygaster/squad#522 was valid — `setInterval` with async callback and no overlap guard is a real bug. PR #522 addresses it correctly with `roundInProgress` boolean + `try/finally`.

## Decision
- Race condition fix: APPROVED — correct algorithm, correct tests
- PR #522: Still needs rework per bradygaster's CHANGES_REQUESTED review (full rewrite vs additive patch)
- Issue #1331: Kept OPEN until PR #522 merges

## Secondary Issues Found
1. `await saveCBState(...)` — calls `await` on a void/sync function — minor but should be fixed
2. `executeRound()` circuit breaker state transitions have zero tests — medium priority gap

## Recommendation
When PR #522 is reworked, ensure: (a) `saveCBState` is made properly async or `await` removed, (b) state machine tests added for open/half-open/closed transitions.
