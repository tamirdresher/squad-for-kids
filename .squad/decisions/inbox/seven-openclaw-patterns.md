# Decision: Adopt OpenCLAW Pattern Templates for Squad

**Date:** 2026-03-11
**Author:** Seven (Research & Docs)
**Status:** Proposed
**Scope:** Continuous Learning System
**Issue:** #23

## Decision

Adopt four OpenCLAW production patterns via concrete template files that agents can follow directly:

1. **QMD 5-Category Extraction** — Weekly digest compaction using KEEP (decisions, commitments, pattern changes, blockers, contacts) vs DROP (routine ops, ephemeral context, repeats, simple Q&A, PR pings)
2. **Dream Routine** — Weekly cross-digest analysis detecting trends, recurring blockers, decision drift, and skill promotion candidates
3. **Issue-Triager** — Classification taxonomy (incident/decision/question/coordination) with P0-P3 priority scoring and JSONL audit trail
4. **Memory Separation** — Three-tier architecture: Transaction (raw, gitignored, 30-day retention) → Operational (QMD curated, committed, forever) → Skills (permanent, committed)

## Templates Created

- `.squad/templates/qmd-extraction.md`
- `.squad/templates/dream-routine.md`
- `.squad/templates/issue-triager.md`
- `.squad/templates/memory-separation.md`

## Adoption Order

1. **Week 1-2:** QMD Framework (foundation — all downstream patterns depend on it)
2. **Week 2-4:** Issue-Triager (immediate value — P0 incident catch within 1h)
3. **Week 5-8:** Dream Routine (requires 4+ weeks of QMD data to detect trends)

## Consequences

- ✅ Digest signal-to-noise ratio improves ~50% (QMD extracts only what matters)
- ✅ P0 incidents caught and escalated within 1 hour (Issue-Triager)
- ✅ Cross-digest trends detected automatically (Dream Routine)
- ✅ Git history stays clean — raw noise gitignored, only curated data committed
- ⚠️ Requires weekly QMD extraction discipline (manual initially, automate in Phase 2)
- ⚠️ Issue-Triager scoring rules need 2-week calibration period

## Mitigation

- QMD quality checklist prevents extraction drift
- Issue-Triager calibration process built into template (weeks 1-2 human review)
- Dream Routine guardrails prevent false pattern claims (3+ data point minimum)
