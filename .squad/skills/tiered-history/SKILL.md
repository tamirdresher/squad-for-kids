# Tiered History Retrieval

**Confidence:** Low (first observation — instrumentation needed)  
**Author:** Data  
**Date:** 2026-07-22  
**Status:** Prototype — awaiting instrumentation results

---

## Problem

Agent `history.md` files range from 0.2KB to 72KB. Six agents exceed the 12KB Scribe summarization threshold (squad.agent.md line 728). At spawn, every agent reads its full history.md (squad.agent.md line 644), consuming up to ~18K tokens for the largest files.

Measured impact (agents >12KB):

| Agent | Total KB | Est Tokens | Structured KB | Unstructured KB |
|-------|----------|------------|---------------|-----------------|
| Seven | 71.9 | 18,413 | 36.9 | 35.0 |
| Picard | 70.7 | 18,094 | 43.2 | 27.5 |
| Data | 66.3 | 16,979 | 29.7 | 36.6 |
| B'Elanna | 54.4 | 13,915 | 43.5 | 10.8 |
| Worf | 34.2 | 8,753 | 26.4 | 7.8 |
| Troi | 19.5 | 4,982 | 3.5 | 15.9 |

## Hot/Cold Pattern

### Hot Layer (always loaded at spawn)
- `## Core Context` section (2–3 KB per agent)
- `## Learnings` entries tagged with currently-open issues
- All entries from current quarter less than 30 days old
- A `## See Also` pointer: "Full history in history-archive.md"

### Cold Layer (loaded on-demand)
- Unstructured work reports (session notes, issue closures)
- Learnings entries older than 30 days with no open-issue tags
- Archived quarterly content (history-2026-Q1.md etc.)

### When to Read Cold
- Agent is assigned an issue that references archived work
- Agent encounters a pattern it cannot resolve from hot context
- Explicit cross-reference from another agent's decision

## Scribe Maintenance Rules

1. **At summarization time** (history.md >12KB): Move unstructured work reports to `history-worklog.md`. Keep Core Context + tagged Learnings in main file.
2. **Do NOT create a second archival dimension.** This works WITH quarterly rotation, not alongside it. The hot file IS the quarterly history.md; the cold file is the worklog overflow.
3. **Tag entries**: When writing Learnings, include issue numbers: `### Issue #NNN — description`. This enables relevance-based retrieval instead of arbitrary "last N" cutoffs.
4. **Agents <10KB**: Exempt. No splitting needed — full file is already within budget.

## Addressing Known Risks

### Entry format inconsistency (Q's concern)
Use issue-number tags, not positional "last N". Seven has 13 issue-based blocks, Picard has 15 date-based sections — tagging by issue number works for both formats.

### Unknown unknowns cliff (Q's concern)
The `## See Also` pointer ensures agents know cold context exists. Combined with issue-tag retrieval, agents working on related issues automatically pull relevant cold entries.

### Redundancy with quarterly rotation (Q's concern)
This is NOT a second archival layer. It's an intra-quarter optimization that splits structured knowledge (hot) from work reports (cold). Quarterly rotation continues as-is.

## Instrumentation Needed (Before Implementation)

1. Count how many spawn cycles per week load the full history.md (estimate: all of them per line 644)
2. Measure actual token consumption per spawn via Copilot event logs
3. Track whether agents reference history entries by issue number or by recency
4. Baseline: one week of unmodified operation, then one week with hot-only
