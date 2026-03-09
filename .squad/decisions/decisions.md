# Squad Decisions Log

## Active Decisions

### 2026-03-09: B'Elanna — Squad Scheduler Architecture

**Issue:** #199  
**Type:** Architecture Design Proposal  
**Status:** Pending User Decision  

**Proposal:** Provider-agnostic scheduling system with schedule.json manifest. Five built-in providers (local-polling, github-actions, windows-scheduler, http-webhook, copilot-agent). Ralph integration for low-latency execution. 7-phase rollout (7-11 weeks).

**Awaiting:**
1. Primary provider strategy
2. Implementation scope (MVP vs. full)
3. Persistence requirements
4. Notification strategy
5. Timeline

**Document:** `.squad/implementations/squad-scheduler-design.md`  

---

### 2026-03-09: B'Elanna — Teams Monitor Integration Architecture

**Issue:** #215 — Teams Message Monitoring  
**Type:** Architecture Design Proposal  
**Status:** Approved for Implementation  

**Proposal:** Wire WorkIQ-based Teams monitoring into Ralph's loop using a 3-layer architecture:
1. Schedule entry in `.squad/schedule.json` — declarative config for monitoring task
2. Ralph loop hook — runs every 3rd round (~15 min) during business hours on weekdays
3. Standalone script at `.squad/scripts/teams-monitor-check.ps1` — follows `daily-adr-check.ps1` pattern

**Rationale:** Consistency with established ADR check pattern, rate limiting prevents WorkIQ abuse while maintaining 15-min responsiveness, smart filtering ensures only actionable items reach Tamir.

**Impact:**
- ralph-watch.ps1: ~20 lines added
- schedule.json: 1 new entry
- New script: ~200 lines

**Approved By:** B'Elanna (Infrastructure Expert)  
**Date:** 2026-03-09  
**Status:** Ready for Implementation

---

### 2026-03-15: B'Elanna — Microsoft 365 Office Automation Integration

**Issue:** #183 — Office Automation (Email/Calendar/Teams)  
**Type:** Architecture Design Proposal  
**Status:** Design Complete — Awaiting Implementation  

**Problem:** Tamir cannot create Azure AD app registrations due to corporate policy. WorkIQ provides read-only access but cannot send emails, create events, or post to Teams.

**Solution:** Three-layer architecture:

1. **Layer 1: WorkIQ Intelligence (Immediate — No Blockers)**
   - Already available: read/search emails, access calendar, query Teams messages, search documents
   - Create Squad skills: office-intelligence, meeting-to-issue, email-digest
   - No blockers; works today with existing WorkIQ MCP

2. **Layer 2: Admin-Provisioned MCP Server (Weeks 1-2)**
   - Workaround: Request IT admin to provision credentials centrally
   - Two options: Microsoft MCP Server for Enterprise (preferred) or Shared Service Principal (fallback)
   - Enables: Send emails, create/update calendar events, post to Teams, find meeting times

3. **Layer 3: Business Process Automation (Weeks 3-4)**
   - Meeting → Issue automation
   - Email alert & triage
   - Calendar guard (day 2 operations)

**Security Model:** WorkIQ read-only; Admin-provisioned MCP with minimal scopes (Mail.Send, Calendars.ReadWrite, Teams.ReadWrite); immutable audit logging.

**Implementation Timeline:** Phase 1 (Week 1) starts immediately; Phases 2-4 contingent on admin coordination.

**Approved By:** B'Elanna (Infrastructure Expert)  
**Date:** 2026-03-15  
**Status:** Design Ready for Implementation  
**Next Review:** After Phase 1 completion (Week 1 end) or admin response (Week 2 mid)

---

### 2026-03-09: Picard — Cross-Squad Orchestration Architecture

**Issue:** #197 — Cross-Squad Orchestration  
**Type:** Architecture Design Proposal  
**Status:** Proposed  

**Problem:** Squad supports vertical inheritance and horizontal partitioning, but lacks lateral collaboration — ability for independent squads to coordinate work, share runtime state, and delegate tasks.

**Decision:** Extend existing Squad primitives rather than building a parallel federation system.

Three extensions to existing infrastructure:
1. **Bidirectional Upstreams** — Extend `upstream.json` with `mode: "collaborate"` and `trust` levels
2. **Delegation via GitHub Issues** — Use structured GitHub Issues as delegation contracts with `squad-delegation` label
3. **Context Projection** — Accept delegation by creating read-only snapshot of source squad context

**Key Principles:**
- Squads are autonomous services
- GitHub-native mechanisms first
- Extend, don't replace existing patterns
- Phase 1 requires zero tooling (manual delegation via Issues works today)

**Phased Rollout:**
| Phase | What | Effort |
|-------|------|--------|
| Phase 0 | File 3 upstream issues on bradygaster/squad | 1 day |
| Phase 1 | Manual cross-squad delegation via Issues | Now |
| Phase 2 | `squad delegation send/accept/complete` CLI | 2-4 weeks |
| Phase 3 | Bidirectional upstream mode | 4-6 weeks |
| Phase 4 | Meta-hub implementation (Tier 3) | 8-12 weeks |

**Proposed Issues for bradygaster/squad:**
1. Bidirectional Upstream Mode
2. Cross-Squad Delegation via GitHub Issues
3. Meta-Hub Implementation (Tier 3)

**Approved By:** Picard (Lead)  
**Date:** 2026-03-09  
**Status:** Proposed

---

## Archive

(None yet)
