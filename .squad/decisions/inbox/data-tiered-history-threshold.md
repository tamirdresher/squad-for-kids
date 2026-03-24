### 2026-07-24: Tiered History Hot/Cold Pattern — Threshold Adopted

**By:** Data

**What:** Adopted the 15 KB / 20-entry threshold for agent history.md hot/cold tiering (Issue #1470).
- Hot layer: history.md capped at ~20 entries + Core Context + Active Context
- Cold layer: history-archive.md — summarized older entries, loaded on demand only
- Trim-AgentHistory.ps1 automates enforcement; Scribe runs it post-orchestration-round
- All 16 agent charters updated with History Reading Protocol section
- routing.md updated with Context Loading Conventions table

**Why:** history.md files grew unbounded (up to 74 KB per agent, ~18K tokens). 
This resolves the pending decision from history-summarization-status.md (deferred since 2026-03-11).
Estimated 73% token reduction per orchestration round (55K → 15K tokens for 4-agent rounds).

**PR:** tamirdresher_microsoft/tamresearch1#1475