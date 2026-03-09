# Orchestration: B'Elanna #199 Squad Scheduler Design

**Session:** Ralph Round 2  
**Timestamp:** 2026-03-09T07:05:00Z  
**Agent:** B'Elanna (Infrastructure Expert)  
**Mode:** background  

---

## Task

Design a provider-agnostic scheduling system for Squad autonomous task execution (Issue #199).

---

## Work Completed

### Deliverable
- **File:** `.squad/implementations/squad-scheduler-design.md` (18 KB)
- **Design:** Provider-agnostic Squad Scheduler with schedule.json manifest

### Key Design Decisions

1. **Architecture:** Declarative schedule manifest (`.squad/schedule.json`) with pluggable provider abstraction
2. **Providers:** 5 built-in providers (local-polling, github-actions, windows-scheduler, http-webhook, copilot-agent)
3. **Ralph Integration:** Enhanced ralph-watch.ps1 to load and evaluate schedules on each heartbeat
4. **State Management:** `.squad/scheduler-state.json` for idempotency + `.squad/scheduler.log` for observability
5. **Implementation Phases:** 7-phase roadmap (7-11 weeks depending on scope)

### Success Criteria Met
- ✅ Single source of truth (schedule.json)
- ✅ Multi-provider abstraction (swap backends without task changes)
- ✅ Persistent state (survives restarts with appropriate provider)
- ✅ Ralph integration (low-latency execution + observability)
- ✅ Observable (execution history, structured logging)

### User Decisions Requested
1. Primary provider strategy (GitHub Actions, local polling, or Windows Task Scheduler)
2. Scope (MVP vs. full implementation)
3. Persistence requirements across reboots
4. Notification strategy (Teams, PagerDuty)
5. Timeline preferences

---

## Outcomes

- **Issue Status:** Moved to `pending-user` (awaiting Tamir's architectural decisions)
- **Comment Posted:** Design proposal posted on Issue #199 with link to full document
- **Next Step:** User selects primary provider and scope → B'Elanna implements Phase 1-2

---

## Artifacts

- **Design Document:** `.squad/implementations/squad-scheduler-design.md`
- **Decision File:** `.squad/decisions/inbox/belanna-scheduler-design.md`
- **Issue Reference:** #199 (Comment + pending-user label)
