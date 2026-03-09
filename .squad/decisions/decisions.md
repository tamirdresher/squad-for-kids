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
**Decision Inbox:** `.squad/decisions/inbox/belanna-scheduler-design.md`

---

## Archive

(None yet)
