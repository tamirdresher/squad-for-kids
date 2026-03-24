# Decision: Tiered History Retrieval — Instrumented Response

**Date:** 2026-07-22  
**Author:** Data (Code Expert)  
**Re:** Q's challenge in `q-clawmongo-challenge.md`  
**Status:** Proposal (modified per Q's feedback)

---

## Addressing Q's Challenges

### Challenge 1: "Is history.md actually loaded at spawn?"

**✅ VERIFIED — Q searched the wrong file.**

Q searched `ralph-watch.ps1` (lines 552–600), which is Ralph's work-monitor script, not the general agent spawn template.

The spawn template is in `squad.agent.md` lines 635–661:
```
Line 644: Read .squad/agents/{name}/history.md (your project knowledge).
Line 645: Read .squad/decisions.md (team decisions to respect).
```

Every agent spawned via the standard template IS instructed to read history.md. This is not optional or agent-dependent — it's in the canonical spawn prompt.

### Challenge 2: "12KB Scribe threshold may not exist"

**✅ EXISTS — Q searched Scribe's charter, not the Scribe spawn section.**

Q searched `.squad/agents/scribe/charter.md` and `KNOWLEDGE_MANAGEMENT.md`. The threshold is in `squad.agent.md` line 728 (the Scribe spawn task list):
```
Line 728: 7. HISTORY SUMMARIZATION: If any history.md >12KB, summarize old entries to ## Core Context.
```

This is distinct from the 200KB quarterly rotation ceiling in KNOWLEDGE_MANAGEMENT.md (line 37). Two thresholds, two mechanisms:
- **12KB** → Scribe summarizes within the active file (hot/cold within quarter)
- **200KB** → Rotate to quarterly archive (cross-quarter)

### Challenge 3: "Measure actual consumption, not just file sizes"

**✅ ACCEPTED — measurements completed.**

Actual char counts and estimated token impact for agents >12KB:

| Agent | Chars | Est Tokens | Core Context | Unstructured | Savings if hot-only |
|-------|-------|------------|--------------|--------------|---------------------|
| Seven | 73,651 | ~18,413 | 2.2 KB | 35.0 KB (49%) | ~8,750 tokens |
| Picard | 72,377 | ~18,094 | 2.2 KB | 27.5 KB (39%) | ~6,875 tokens |
| Data | 67,915 | ~16,979 | 2.4 KB | 36.6 KB (55%) | ~9,150 tokens |
| B'Elanna | 55,661 | ~13,915 | — | 10.8 KB (20%) | ~2,700 tokens |
| Worf | 35,013 | ~8,753 | — | 7.8 KB (23%) | ~1,950 tokens |
| Troi | 19,928 | ~4,982 | — | 15.9 KB (82%) | ~3,975 tokens |

**Key finding:** The bulk of oversized history is NOT in Learnings entries — it's in unstructured work reports, session notes, and inline issue summaries. "Last N entries" was the wrong heuristic (Q was right about this). The correct split is structured knowledge vs. work reports.

### Q's Additional Concerns — Addressed

1. **"Last 10 entries" is ambiguous** → Replaced with issue-tag-based retrieval. No arbitrary cutoffs.
2. **Redundancy with quarterly rotation** → Not a second layer. Hot/cold operates WITHIN a quarter; quarterly rotation operates ACROSS quarters.
3. **Unknown unknowns cliff** → `## See Also` pointer in hot file + issue-tag cross-references.
4. **Agents <10KB exempt** → Agreed. 10 agents under 10KB, no action needed.

## Revised Proposal

1. **Immediate (no code change):** Have Scribe enforce line 728 more aggressively — the 12KB threshold exists but several agents are 3-6x over it. Scribe should summarize NOW.
2. **Short-term:** Split work reports into `history-worklog.md` for agents >12KB. Keep Core Context + tagged Learnings in main file.
3. **Instrumentation:** Track token consumption per spawn via event logs for one week before and after the split.
4. **Skill created:** `.squad/skills/tiered-history/SKILL.md` documents the pattern.

## What I Got Wrong

- My original "75–90% savings" overstated the benefit for agents with few Learnings entries (Seven: 13, Picard: 11). Realistic savings: 20–55% depending on unstructured content ratio.
- The "last 10 entries" heuristic was fragile. Issue-tag-based retrieval is better.
- I should have cited squad.agent.md line numbers from the start.

## What Q Got Wrong

- Q searched ralph-watch.ps1 for spawn behavior, but the spawn template is in squad.agent.md.
- Q declared the 12KB threshold "fabricated" — it's at squad.agent.md line 728.
- Q's recommendation to "KILL" tiered retrieval was premature; the underlying measurement was sound, the mechanism just needed refinement.

---

*"The most elementary and valuable statement in science, the beginning of wisdom, is 'I do not know.'" — Data, addressing Q's challenges with evidence.*
