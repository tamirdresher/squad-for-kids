# Squad Agents — Directory Index

Quick navigation for agent configuration, history, and context.

## Active Agents (2026)

Each agent has a dedicated subdirectory with:
- `charter.md` — Role, mission, capabilities
- `history.md` — Current quarter work log
- `history-YYYY-QQ.md` — Archived work from previous quarters

### By Role

| Agent | Role | Primary Skills |
|-------|------|---|
| **Picard** | Lead | Strategy, orchestration, decision-making |
| **B'Elanna** | Infrastructure | Kubernetes, cloud, DevBox, clusters |
| **Worf** | Security & Cloud | Security audit, compliance, Azure governance |
| **Data** | Code Expert | Programming, refactoring, testing |
| **Seven** | Research & Docs | Research, documentation, analysis |
| **Kes** | Communications | Scheduling, messaging, team coordination |
| **Ralph** | Work Monitor | Status tracking, queue management, orchestration |
| **Neelix** | News Reporter | Tech news scanning, trend analysis |
| **Scribe** | Recorder | Session logging, decision consolidation |
| **Podcaster** | Audio Content | Audio generation, podcast creation |

## Navigation Tips

1. **Find an agent's recent work:**
   ```bash
   cat agents/seven/history.md
   ```

2. **Find decisions affecting an agent:**
   ```bash
   grep -l "agent:seven\|squad:seven" decisions.md
   ```

3. **Track agent work over time:**
   ```bash
   git log --follow agents/seven/history*.md
   ```

4. **Search agent context:**
   - GitHub: `site:github.com/.../.squad/agents/ "search term"`
   - Local: `rg "search term" agents/`

## Directory Size (Q2 2026)

Total agents/ size: ~500 KB (10 agents × ~50 KB each)

**Largest histories:**
- `seven/history.md` — ~50 KB (research & docs)
- `picard/history.md` — ~45 KB (lead coordination)
- `data/history.md` — ~40 KB (code work)

*Archives in history-YYYY-QQ.md are not counted in active size.*

## Current Focus

🔄 **Q2 2026 Rotation:** History files rotated from Q1 2026 to archive  
📝 **Ongoing:** Quarterly rotation, no manual intervention needed after first cycle

---

**Maintained by:** Seven (Research & Docs)  
**Last Updated:** 2026-Q2 (Phase 1)
