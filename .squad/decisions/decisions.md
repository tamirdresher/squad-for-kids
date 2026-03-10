# Squad Decisions Log

## Active Decisions

### 2026-03-25: Seven — MCP Out-of-the-Box Capabilities Research

**Date**: 2026-03-25  
**Decision Maker**: Seven (Research & Docs)  
**Issue:** #257  
**Status**: Research Complete, Pending Team Review

**Background:** GitHub announced that Copilot CLI now ships with several default MCP servers that work WITHOUT configuration. Investigation verified 6 MCPs working out-of-the-box.

**Verified Working MCP Servers (6 Total):**
1. **GitHub MCP Server** (github-mcp-server-*) — Built-in: YES ✅
2. **Playwright MCP Server** (playwright-*) — Built-in: YES ✅
3. **Aspire MCP Server** (aspire-*) — Built-in: YES ✅
4. **Azure DevOps MCP** (azure-devops-*) — Built-in: NO (org-specific config) ✅
5. **WorkIQ MCP** (workiq-*) — Built-in: YES (EULA required) ✅
6. **EngineeringHub MCP** (enghub-*) — Built-in: YES (Microsoft internal) ✅

**Key Architecture Insights:**
- Shift from "install everything" (pre-Agency) to "built-in + extend" (post-Agency)
- Configuration Priority: Repo-level > workspace-level > user-level > CLI override
- Tool Naming: Consistent `{mcp-server-name}-{tool-name}` pattern

**Documentation Gaps Identified:**
1. `.squad/mcp-config.md` references outdated community MCP setup
2. No usage examples for common workflows
3. Configuration clutter in `.copilot/mcp-config.json`

**Recommendations (Immediate Actions):**
1. Update `.squad/mcp-config.md` with built-in vs configured MCPs
2. Cleanup `.copilot/mcp-config.json` (clarify Azure DevOps, review EXAMPLE-trello)
3. Create usage examples: GitHub automation, Playwright testing, Aspire monitoring

**Future Enhancements:**
- Team enablement session on 6 MCPs
- MCP discovery and introspection patterns
- Third-party MCP evaluation

**Positive Outcomes:**
- Reduced configuration burden (5 MCPs work without setup)
- Immediate capability access (GitHub automation, web testing, Aspire monitoring)
- Clearer separation: built-in vs configured MCPs
- Verified accuracy of Agency announcement

**Next Steps:**
1. ✅ Posted findings to issue #257
2. ✅ Labeled issue "status:pending-user"
3. ⏳ Await approval to update documentation
4. ⏳ Create MCP usage examples if approved

**Document:** `.squad/decisions/inbox/seven-mcp-out-of-box-research.md` (merged into Active Decisions)

---

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

### 2026-03-09: Data — Standalone Squad-Monitor Repository Structure

**Date:** 2026-03-09  
**Agent:** Data  
**Issue:** #229  
**Status:** ✅ IMPLEMENTED & MERGED (PR #231)

**Decision:** Create standalone repository at `squad-monitor-standalone/` with sanitized, open-source ready codebase.

**Key Architecture Decisions:**
1. **.NET 8 target** (not .NET 10) — Broader LTS compatibility
2. **AgentLogParser.cs** — New component for live agent log parsing
3. **--config-dir flag** — Configurable config directory override
4. **Cross-platform paths** — Path.Combine() throughout
5. **Full sanitization** — All Microsoft/internal references removed
6. **Dual documentation** — README.md (comprehensive) + QUICKSTART.md (5-min setup)

**Consequences:**
- ✅ Squad-monitor now shareable as open-source tool
- ✅ Live agent log parsing for real-time visibility
- ✅ Cross-platform friendly (.NET 8, Path.Combine)
- ⚠️ Agent log parsing depends on undocumented Copilot CLI log format (may break on format changes)

**Next Steps:**
1. Merge PR #231 ✅ (DONE)
2. Extract to new GitHub repo (manual, future work)
3. Add GitHub Actions CI/CD (future work)
4. Publish as NuGet package (future work)

**Artifacts:**
- `squad-monitor-standalone/` — Full standalone structure
- PR #231 — Merged to main
- Issue #229 — Auto-closed, archived

---

### 2026-03-09: Seven — Patent Email Compilation for Brady Gaster

**Date:** 2026-03-09  
**Agent:** Seven (Research & Docs)  
**Issue:** #230  
**Status:** 🔄 PENDING USER (Tamir to review & send)

**Decision:** Create draft email in Outlook Web summarizing Squad patent research findings. Leave as DRAFT (not auto-sent) for Tamir's human review before sending.

**Rationale:**
- Patent discussions involve legal/strategic implications — auto-send inappropriate
- Comprehensive synthesis required (500KB+ patent research reviewed, distilled to ~2700 words)
- Actionable next steps included (4 decision points for Brady/Tamir)

**Key Content:**
- **Verdict:** YES, Squad is patentable (narrowly: Ralph monitoring, Casting governance, Git-native state, Drop-box memory)
- **Prior Art:** NEC patent + 11+ frameworks (CrewAI, MetaGPT, gitclaw, LangGraph, etc.)
- **Cost/Timeline:** ~$3-5K, 2-4 weeks
- **Critical:** Must file BEFORE public disclosure — patent rights lost otherwise
- **Blocking Risk:** gitclaw timing investigation needed

**Artifacts Created:**
- `patent-email-for-brady.md` — Full email compilation
- `brady-patent-email-draft.png` — Outlook screenshot
- Issue #230 comment — Full context

**Communication Protocol Established:**
- Always create DRAFT for legal/strategic communications (never auto-send)
- Provide comprehensive summary doc for reference
- Screenshot evidence for verification
- Comment on originating issue with full context

**Follow-up Actions:**
- **Tamir:** Review Outlook draft, send when ready
- **Tamir/Brady:** Address 4 next-step questions (inventorship, disclosure status, gitclaw timing, strategic intent)

**Status:** Draft email ready in Outlook for Tamir's review.

---

## Archive

(None yet)
