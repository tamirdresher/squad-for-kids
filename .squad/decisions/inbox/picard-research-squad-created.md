# Decision: Research Squad Repository Created

**Decision ID:** TBD (Scribe will assign)  
**Date:** 2026-03-11  
**Author:** Picard  
**Issue:** #341

## Context

Tamir approved the Research Squad proposal for a dedicated research team operating in a separate repository. Key requirement: "You do all. And have a dedicated Ralph. Each should be isolated so can run in different machines. Don't give me tasks. Do it all yourself."

## Decision

Created **tamresearch1-research** repository with full Squad structure and 6-member research team.

**Repository:** `tamirdresher_microsoft/tamresearch1-research` (private)

**Team Roster:**
- Guinan — Research Lead
- Geordi — Technology Scanner
- Troi — Methodology Analyst
- Brahms — Architecture Researcher
- Scribe-R — Research Scribe
- Ralph-R — Research Ralph (isolated from Production Ralph)

## Implementation

1. **Full .squad/ Structure:**
   - Agent charters and histories (6 agents)
   - Routing rules with cross-repo label taxonomy
   - Decisions ledger (empty, ready for research decisions)
   - Ceremonies (Symposium, Backlog Review, Failed Research Review)
   - Casting policy, registry, history
   - Identity tracking

2. **Research Directories:**
   - `research/active/`, `research/completed/`, `research/failed/`
   - `research/backlog.md` with 6 initial priorities

3. **Cross-Repo Bridge:**
   - `bridge/inbound/` — Requests from production
   - `bridge/outbound/` — Findings to production

4. **Symposium Structure:**
   - `symposium/templates/` — Presentation templates
   - `symposium/sessions/` — Past symposium records

5. **Initial Research Backlog:**
   - PR review orchestrator patterns (MDE repo evaluation)
   - Reflect skill learning capture
   - AI agent development monitoring (HackerNews/arXiv)
   - Multi-squad coordination patterns
   - Agent handoff quality metrics
   - Cross-repo symposium patterns

## Consequences

**Positive:**
- Research squad fully autonomous — no production bottlenecks
- Ralph-R isolation prevents priority conflicts with Production Ralph
- Failed research is safe — separate repo means experiments don't clutter production
- Symposium ceremony enables batch findings (reduces noise)

**Trade-offs:**
- Two repos to monitor (Ralph-R handles this)
- Cross-repo issue protocol adds coordination overhead (mitigated by async communication)
- Research may produce findings that production declines (expected 30-40% adoption rate)

**Operational:**
- Ralph-R must monitor both repos for cross-repo communication
- Symposium scheduled bi-weekly after first research completes
- Research backlog requires weekly prioritization

## Status

✅ **ACTIVE** — Research squad operational as of 2026-03-11

## Related

- Issue #341 (Research Squad proposal)
- Production decisions.md Decision 15 (Production Approval Framework)
