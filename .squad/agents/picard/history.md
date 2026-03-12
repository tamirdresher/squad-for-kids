# Picard — History

## Core Context

### Squad Leadership & Architecture

**Role:** Lead architect and coordinator for multi-agent Squad orchestration, Ralph cluster protocol design, production approval workflows, cross-team integration

**Technologies & Domains:** Azure DevOps (multi-org, repository strategy), GitHub (Copilot CLI, skill/agent architecture), Kubernetes (Ralph cluster protocol), PowerShell scripting, AI/ML coordination (multiple squads), incident response

**Recurring Patterns:**
- **Multi-Agent Orchestration:** Parallel agent dispatch for specialized tasks (Issue #340 — MDE team uses 6-agent PR review pattern, validates Squad's architecture)
- **Ralph Cluster Coordination:** Machine ID strategy with branch namespacing (`squad/{issue}-{slug}-{machineid}`); supports distributed work claiming across local + DevBox (Issue #346/350)
- **Research-to-Decision Pipeline:** Complex research → Decision record → Team adoption (Issues #321, #340, #341)
- **Cross-Squad Collaboration:** Inventory-as-Code coordination, production approval frameworks, multi-squad routing

**Key Architecture Decisions:**
- **Production Approval Path:** Framework for Brady/external stakeholders to review/approve production changes (Decision #15, Issue #294)
- **Ralph Multi-Machine Support:** Stable hostnames for machine ID strategy; EMU auth constraints documented; branch namespacing with machine scope (Issues #346, #350)
- **Agent Repository Pattern:** `.github/agents/*.agent.md` structure validated against Microsoft Defender team production use (Issue #340)
- **Knowledge Management Phase 1:** Quarterly history rotation → archives; GitHub search + ripgrep queryability; no custom indexing needed yet (Decision #16, Issue #321)

**Key Files & Conventions:**
- `.squad/decisions.md` — Authoritative decision log (multi-org, Ralph protocol, approval framework, knowledge management)
- `.squad/implementations/ralph-cluster-protocol.md` — Multi-machine coordination spec
- `.squad/scripts/Claim-Issue.ps1` — Squad work claiming automation
- `.squad/agents/` — Agent charters and histories (quarterly archives)

**Cross-Agent Dependencies:**
- Manages overall Squad coordination; works with all agents for design reviews and work routing

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

TBD - Q2 work incoming

