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

### 2026-03-12: Issue #347 — Power Automate Flow Disabled (Investigation Complete)

**Assignment:** Investigate disabled Power Automate flow (f91a7405-0786-4f44-a000-0159ff860872) that auto-disabled after 14 days of trigger failures.

**Findings:**
1. Flow is NOT actively integrated into Squad automation
2. Two possible contexts identified:
   - **Email Gateway System** (Issue #259): Personal/family email-to-action automation via shared mailbox + 4 flows (print, calendar, reminders, GitHub issues). Setup guide complete but flows not yet deployed by Tamir.
   - **ADO Service Hook** (Infrastructure): Upstream CI/CD notifications via Power Automate. Known to have 401 auth failures; auto-disable matches typical Power Automate reliability pattern.
3. **Most likely:** ADO service hook (higher criticality + documented failures)

**Scope Search:** Entire repo, .squad/ directory, config.json, schedule.json, squad agent histories—no active Power Automate flow secrets or deployment configs found (correct security posture).

**Recommendation:** Tamir must manually check Power Automate portal via provided URL to identify the specific flow. Once identified, decide: re-enable with new connection, delete, or reconfigure. No critical Squad operations depend on active Power Automate flows.

**Status:** Investigation complete. Issue comment posted with findings. Awaiting Tamir's manual action (status: `pending-user`).

---

## 2026-03-12 Round 1 Team Updates

**Data (Code Expert):** Successfully completed multi-machine Ralph coordination (#346 PR #353). GitHub-native coordination using issue assignments, labels, and heartbeat comments. 15-minute stale threshold, 2-minute heartbeat interval. Machine-specific branch naming pattern: `squad/{issue}-{slug}-{machine}`. Decision recorded in decisions.md. PR awaiting review.

**Troi (Writer):** Completed blog part 2 refresh (#313). Content updated with Tamir's voice, all DK8S/FedRAMP references removed, narrative arc focused on human squad members as bridge from personal playground to real work team. Continues series progression after part 1 refresh.

**Neelix (Comms):** Teams morning briefing sent covering 3 urgent items, 8 pending items, squad progress. Board state synchronized. Tech news already scanned today.

**Board State:** Issues #344–#349 added. #344, #345, #348, #349 → Pending User. #346, #347 → In Progress. #346 moved to Review (post-PR). Board reconciliation clean.

