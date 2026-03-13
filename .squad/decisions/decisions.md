# Squad Decisions Log

## Active Decisions

### 2026-03-13: Seven — nano-banana-mcp Integration Recommendation (Issue #375)

# Decision: nano-banana-mcp Integration Recommendation

**Issue:** #375  
**Date:** 2026-03-28  
**Author:** Seven (Research & Docs)  
**Status:** Ready for Implementation

## Summary

**Question:** Can we use nano-banana-mcp without adding billing info or costs?

**Answer:** ✅ **YES — Zero cost, zero billing setup required.**

## Findings

### Project Details
- **Name:** nano-banana-mcp
- **Repository:** https://github.com/pierceboggan/nano-banana-mcp
- **Purpose:** MCP server for AI image generation via Google Gemini
- **Language:** TypeScript/Node.js
- **License:** ISC

### Billing Analysis

**Free Tier Access:**
- Uses Google Gemini API via free tier (Google AI Studio)
- No credit card required for API key
- Free API keys are generated at https://aistudio.google.com/apikey
- No billing info needed at any point

**Code Transparency:**
- Reviewed source code (11.5 KB)
- Direct fetch calls to Google's generativelanguage.googleapis.com
- Model used: `gemini-3.1-flash-image-preview` (free tier eligible)
- No telemetry, tracking, or hidden data collection
- Image generation only on explicit user request

**Dependencies:**
- @modelcontextprotocol/sdk (standard MCP)
- zod (schema validation)
- @types/node (dev only)
- No proprietary or costly third-party services

**Risks:** ⚠️ MINOR
- Google free tier has quotas (generous for development)
- Long-term cost if usage scales significantly
- Google could change pricing model (unlikely for public API)

## Recommendation

**Status:** ✅ **APPROVED FOR ADOPTION**

**Next Steps:**
1. Test integration with squad MCP infrastructure
2. Document setup: API key generation + GOOGLE_API_KEY environment variable
3. Add to squad capabilities inventory
4. Monitor usage (within free tier limits)

**Acceptance Criteria:**
- [ ] MCP server runs without errors in local environment
- [ ] Image generation works end-to-end
- [ ] Documentation posted to `.squad/implementations/`
- [ ] Team notified in sync

## Technical Notes

**Usage Pattern:**
```bash
# Install
npm install
npm run build

# Configure
export GOOGLE_API_KEY="<free-api-key-from-google-ai-studio>"

# Run
npm start
```

**Integration Points:**
- Works with VS Code Copilot, Claude Desktop, other MCP App clients
- Images render inline as interactive viewer (MCP Apps feature)
- Optional disk save for generated images

**Scalability:**
- Current: Development use (free tier)
- Future: If production usage scales, evaluate dedicated billing account
- Recommendation: Monitor quarterly API usage against free tier quotas

## References
- Issue: #375
- GitHub: pierceboggan/nano-banana-mcp
- Google AI Studio: https://aistudio.google.com/apikey




### 2026-03-13: Data — Conversational Podcast Generation (Issue #455)

**Date:** 2026-03-13  
**Agent:** Data (Code Expert)  
**Issue:** #455 — "Improve podcaster conversation quality"  
**Status:** 🟢 IMPLEMENTATION KICKED OFF  

**Problem Statement:**
Current podcaster sounds like "someone reading from a page" because it takes flat, linear scripts and renders with single voice using basic TTS. No dialogue, banter, or natural conversation dynamics.

**Goal:** Make podcasts sound like real tech podcasts (.NET Rocks, NotebookLM, Syntax.fm) with natural two-host conversation.

**Key Finding:** Script quality matters more than TTS quality. A great conversation script with decent TTS beats perfect TTS reading a flat script (reference: NotebookLM).

**Recommended Architecture:**

**Phase 1: LLM Conversation Script Generation**
- Input: Topic, content, or source material
- LLM Model: Claude 3.5 Sonnet, GPT-4, or Llama 3.1 70B
- Output: Dialogue script with two hosts
- Script includes: Natural back-and-forth, interruptions, filler words, disagreements, emotional shifts, topic transitions

**Phase 2: Multi-Voice TTS with Prosody Control**
- Input: Dialogue script marked with [HOST_A], [HOST_B]
- Output: High-quality MP3 with natural conversation feel
- Rendering includes: Distinct voices, prosody control, filler word handling, turn-taking cues, emotional range

**TTS Model Selection:**
- **Recommended:** Fish Speech S2 (open-source, free, self-hosted, production-ready)
- **Alternative:** ElevenLabs v3 Turbo (industry standard if budget available)

**Implementation Roadmap:**
- MVP (Week 1): LLM script generation + Fish Speech integration, test with 2 sample podcasts
- Phase 2 (Weeks 2-3): Prosody/emotion refinement, strategic filler word insertion, turn-taking markers
- Phase 3 (Iteration): Fine-tune LLM prompts, A/B test host personalities, optimize for topics

**Success Metrics:**
1. MOS (Mean Opinion Score): Listeners rate naturalness (target: 4.5+)
2. Engagement: Podcast completion rate, total time listened (target: +50% vs. current)
3. Comparability: How similar to real tech podcasts
4. Filler Words: Frequency and naturalness of placement
5. Turn-Taking: Smooth speaker transitions, no awkward overlaps

**Decision Points for Team:**
1. TTS model: Fish Speech S2 (RECOMMENDATION) vs. ElevenLabs
2. LLM: Claude 3.5 Sonnet or GPT-4 (RECOMMENDATION) vs. Llama 3.1 70B
3. Timeline: MVP (1 week), Phase 2 (2 weeks), Full rollout (3-4 weeks)
4. Backward compatibility: Yes — make script generation optional, support both modes

**Research & References:**
- Google NotebookLM: https://notebooklm.google.com (reference architecture)
- Fish Speech GitHub: https://github.com/fishaudio/fish-speech (recommended open-source)
- VibeVoice (Microsoft): https://vibevoice.art/ (multi-speaker dialogue)
- FireRedTTS-2 (2025): https://arxiv.org/html/2509.02020v1 (long-form podcast synthesis)
- ElevenLabs: https://elevenlabs.io (premium option)

**Files to Modify:**
- scripts/generate-podcast-script.py (new LLM dialogue script generation)
- scripts/podcaster-conversational.py (multi-voice TTS rendering)
- scripts/podcaster.ps1 (pipeline orchestration)

**Next Steps:**
1. Data implements Phase 1 (LLM script generation)
2. Test with 2 sample podcasts
3. Gather feedback on conversational feel and naturalness
4. Schedule Phase 2 iteration

**Status:** 🟢 Implementation kick-off  
**Confidence:** HIGH (based on research by Seven, production validation via Google NotebookLM)

---

### 2026-03-13: User Directive — Podcast Quality Requirements

**Date:** 2026-03-13  
**Source:** Tamir Dresher (via Copilot)  
**Related Issue:** #455  
**Status:** CAPTURED FOR TEAM MEMORY  

**Directive:** Podcasts must sound like real tech podcasts with genuine discussion between hosts — not someone reading from a page.

**Reference Quality Standards:**
- NotebookLM podcasts
- .NET Rocks
- Syntax.fm

**Requirements:**
- Research better TTS models
- Research academic papers on conversational podcast generation
- Improve podcaster implementation by end of day

**Applies To:** Issue #455 implementation  
**Next Steps:** Data team to implement based on Seven's research architecture

**Status:** ✅ CAPTURED — Driving implementation of #455

---

### 2026-03-10: Data — NuGet Publishing for squad-monitor

**Date:** 2026-03-10  
**Author:** Data (Code Expert)  
**Issue:** #265 — NuGet Tool Publishing  
**Status:** ✅ Implementation Complete, Awaiting API Key  

**Summary:** squad-monitor is a .NET CLI tool for monitoring AI agent orchestration. PR #4 merged with NuGet tool configuration and automated GitHub Actions publishing workflow.

**Implementation:**
- squad-monitor.csproj configured with `<PackAsTool>true</PackAsTool>` and metadata
- .github/workflows/publish-nuget.yml created for release-triggered publishing
- Version extracted from release tags (v1.0.0 → 1.0.0)

**Next Steps for Tamir:**
1. Set `NUGET_API_KEY` secret in repo settings (https://github.com/tamirdresher/squad-monitor/settings/secrets/actions)
2. Create release v1.0.0 (auto-publishes) or manually trigger workflow
3. Verify at https://www.nuget.org/packages/squad-monitor/
4. Test: `dotnet tool install -g squad-monitor`

**Impact:** Users can install via single command. Updates via `dotnet tool update -g squad-monitor`.

---

### 2026-03-12: Seven — IcM Copilot Evaluation & Potential Integration

**Date:** 2026-03-12  
**Agent:** Seven (Research & Docs)  
**Issue:** #260 — "IcM Copilot Newsletter - What's New, March 2026"  
**Status:** AWAITING TAMIR DECISION  

**Summary:** IcM Copilot (Microsoft's AI-powered Incident and Change Management tool) received major March 2026 update with agentic multi-step workflows, M365 embedding, and enhanced governance. Potential benefits for DK8S include automating incident triage, drafting change communications, and Azure DevOps integration.

**Key Findings:**
- 6 major features: Multi-step workflows, context awareness, M365 embedding, personalized Work IQ, governance controls, Agent 365 platform
- **Relevance:** ⭐⭐⭐⭐ (Problem fit: incident triage & change management are core DK8S workflows)
- **Integration:** ⭐⭐⭐ (Medium complexity: requires entitlements, CLI setup, Azure DevOps integration)
- **Cost:** ⭐⭐⭐⭐⭐ (Included with existing Microsoft tooling)

**Recommendation:** Option A — Proceed with 2-week pilot
1. Tamir requests IcM Copilot entitlements for 1-2 team members
2. Test on low-risk incident (measure triage time + documentation quality)
3. Owner: Tamir (entitlements) + B'Elanna (infrastructure integration)
4. Timeline: Complete by end of March 2026

**Next Steps for Tamir:**
1. Decide: Proceed with pilot? (Y/N)
2. If yes: Assign pilot owner (B'Elanna or Picard)
3. If yes: Request entitlements from team onboarding
4. Define success criteria (time saved? documentation quality? adoption rate?)

---

### 2026-03-10: Data — Email-to-GitHub Integration Options

**Date:** 2026-03-10  
**Agent:** Data  
**Issue:** #259 — "Create an email address for wife to send requests"  
**Status:** Pending Tamir's decision on approach

**Problem:** Tamir's wife needs to send emails that automatically create GitHub issues. GitHub doesn't support this natively.

**Options Researched:**

| Approach | Cost | Setup | AI Parsing | Maintenance | Verdict |
|----------|------|-------|-----------|-------------|---------|
| **HubDesk** (Recommended) | Free* | 5 min | ❌ | None | Best for immediate adoption |
| **Zapier** | $19-50+/mo | 15 min | ✅ | Low | Good if AI parsing needed |
| **Power Automate** | ✅ M365 | 30 min | ✅ | Medium | Best for M365 environment |
| **Issuefy** | ? | 5 min | Limited | None | Alternative quick launch |
| **Azure Function** | $0-5/mo | 1-2 hrs | ✅ | High | Overkill now; good foundation |

*Free for personal GitHub accounts; paid for organizations

**Recommendation:** HubDesk (5 minutes, one-click GitHub OAuth, preserves attachments)

**Decision Pending:** Tamir chooses based on priorities:
1. Need it ASAP? → HubDesk
2. Want AI to parse requests? → Zapier or Power Automate
3. Have M365 team? → Power Automate
4. Plan future squad automation? → Azure Function

---

### 2026-03-26: Picard — Agent 365 MCPs for Squad Integration

**Date:** 2026-03-26  
**Lead:** Picard  
**Issue:** #257 — Check Agency new MCPs  
**Status:** PENDING USER DECISION

**Summary:** GitHub/Microsoft announced Agent 365 with built-in MCPs. Squad currently uses 6 (GitHub, Playwright, Aspire, Azure DevOps, WorkIQ, EngineeringHub). Two NEW MCPs relevant: Outlook MCP (email automation) and Teams MCP (Teams messaging).

**MCPs Announced (8 Total):**
| MCP | Scope | Status |
|-----|-------|--------|
| GitHub | Repos, PRs, Issues | ✅ Active |
| Playwright | Web automation, screenshots | ✅ Active |
| Aspire | .NET monitoring, resources | ✅ Active |
| Azure DevOps | Work items, pipelines, test plans | ✅ Active |
| WorkIQ | M365 workplace intelligence | ✅ Active |
| EngineeringHub | eng.ms documentation search | ✅ Active |
| **Outlook** | Email sending, inbox management | 🔴 NEW — Not integrated |
| **Teams** | Teams messaging, scheduling | 🔴 NEW — Not integrated |

**New MCPs Analysis:**

**Outlook MCP:**
- Capabilities: Send emails, read/manage inbox, auto-respond, trigger on email events
- Squad Use Cases: Email-driven task intake, briefings, inbox triage, completion notifications
- Integration: MEDIUM (OAuth setup, MCP config, test workflows)
- Risk: None (auditable, DLP-governed)
- **Recommendation:** 🔴 EVALUATE — Test with one workflow before committing

**Teams MCP:**
- Capabilities: Send messages in channels/DMs, schedule meetings, react to events
- Squad Use Cases: Ralph alerts → Teams channel, completion notifications, daily briefing, escalation
- Integration: MEDIUM (Teams app registration, MCP config, test workflows)
- Risk: None (Teams access controlled by org policies)
- **Recommendation:** 🟡 NICE-TO-HAVE — Complements existing Ralph workflows

**Decision Options:**

**Option A: Adopt Both (Outlook + Teams)**
- ✅ Multi-channel automation, richer notifications, enable issue #259, full M365 coverage
- ❌ Additional OAuth complexity, more moving parts
- **Effort:** 2-3 days

**Option B: Teams MCP Only**
- ✅ Lower overhead, enhances Ralph with Teams notifications
- ❌ Email workflows still need Power Automate, can't solve #259 cleanly
- **Effort:** 1-2 days

**Option C: Skip Both (Status Quo)**
- ✅ No new complexity
- ❌ Miss email automation, Ralph still Teams-blind
- **Effort:** None

**Implementation Timeline (if approved):**
1. Days 1-2: Setup OAuth, configure .copilot/mcp-config.json
2. Days 2-3: Write test workflows (send email, post Teams message)
3. Day 3: Update .squad/mcp-config.md
4. Day 4: Integrate with Ralph or email workflows
5. Day 5: Documentation, walkthrough

**Recommendation:** 
- **Primary:** Test Outlook MCP (enables email-driven automation for #259)
- **Secondary:** Integrate Teams MCP (enhances Ralph observability)
- **Authority:** Tamir decides based on adoption priorities

---

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

### 2026-03-10: Seven — Vapor Squad Skill Addition

**Date:** 2026-03-10  
**Agent:** Seven (Research & Docs)  
**Issue:** #288 — Research spboyer/vapor-squad repository  
**Status:** Proposed (Pending Tamir's Review)

**Summary:** Added the "Vapor Squad" technique as a new skill in `.squad/skills/vapor-squad/SKILL.md`. Pattern uses `.git/info/exclude` for local-only Squad setup (zero repository changes, cross-platform compatible).

**Use Cases:**
- Third-party repos: Using Squad on open-source projects
- Corporate restrictions: Projects where PRs for Squad files aren't welcome
- Evaluation: Testing Squad before permanent commitment

**Skill Details:**
- Location: `.squad/skills/vapor-squad/SKILL.md`
- Confidence: Low (first observation)
- Format: Follows established SKILL.md format with use cases, troubleshooting, command reference
- Reversibility: High

**Next Steps:** Tamir reviews skill for accuracy. If approved, consider testing on sample repo and updating confidence after practical use.

---

### 2026-03-10: Data — Squad-Monitor Dashboard Architecture Pattern

**Date:** 2026-03-10  
**Author:** Data (Code Expert)  
**Issue:** #1 (Token Usage Panel), #3 (Multi-Session View)  
**Status:** Implemented  
**Branch:** feat/token-usage-multi-session

**Decision:** Squad-monitor uses a **dual-mode rendering pattern** where every dashboard feature supports both direct rendering (--once mode) and live updates (continuous mode).

**Architecture:**
- **Display* functions** (e.g., DisplayTokenStats) — Used in --once mode, call AnsiConsole.Write() directly
- **Build*Section functions** (e.g., BuildTokenStatsSection) — Return IRenderable for live mode Layout composition

**Implementation Guidelines:**
1. Parse log files with FileShare.ReadWrite (allows concurrent writes)
2. Graceful degradation (check directory, return empty state if no data)
3. Visual hierarchy (Live Agent Feed → Token Stats → Ralph heartbeat → Logs → GitHub → Orchestration)
4. Token formatting helper for K/M suffixes with color-coding

**Rationale:** Dual mode enables both quick snapshots and continuous monitoring. Clean separation of concerns follows Spectre.Console best practices and scales easily for future panels.

**Impact:** Token usage visibility helps track cost; multi-session view enables monitoring Ralph + multiple Copilot sessions simultaneously.

---

### 2026-03-10: Picard — Copilot CLI Repository Settings Analysis

**Date:** 2026-03-10  
**Prepared by:** Picard (Lead)  
**Requested by:** Tamir  
**Status:** Proposed

**Finding:** No `.github/copilot/settings.json` exists in tamresearch1. Repository settings cascade with precedence: User level < Repository level < Local level < CLI flags/environment variables.

**Supported Repository Settings:**
- `companyAnnouncements` (string[]) — Custom startup messages
- `enabledPlugins` (Record<string, boolean>) — Declarative plugin auto-install
- `marketplaces` (Record<string, {...}>) — Custom plugin marketplace config

**Settings That CANNOT Be Enforced at Repository Level:**
- model, allowed_urls/denied_urls, experimental, reasoning_effort, stream mode, logging, theming
- (These must be user-level, CLI args, or environment variables)

**Recommendation for tamresearch1:** CREATE `.github/copilot/settings.json` with announcements and empty enabledPlugins object.

**Recommended Content:**
```json
{
  "companyAnnouncements": [
    "Welcome to tamresearch1! 🚀 Use the 'squad' agent for specialized support.",
    "First time? Run '/init' to load custom instructions.",
    "See AGENTS.md for squad capabilities and .squad/skills/ for extended tools."
  ],
  "enabledPlugins": {}
}
```

**Additional Steps:** Document in README.md under "Copilot CLI Setup"; link from AGENTS.md.

---

### 2026-03-10: Picard — Squad Work Session Branch Hygiene

**Date:** 2026-03-10  
**Author:** Picard (Lead)  
**Issue:** #285, PR #49 cleanup  
**Status:** Proposed  
**Context:** PR #49 had 30+ extraneous squad work files (agent history, PRD, decision logs)

**Decision:** Establish branch hygiene rules for squad work sessions:
1. **Local tracking branches:** Use dedicated local branches (squad/work-session-YYYY-MM-DD), never push
2. **Feature branch creation:** Create fresh from main with `git checkout -b feature/name origin/main`
3. **Pre-push review:** Run `git diff origin/main..HEAD --name-status` to verify only feature files
4. **Agent state location:** Consider `.gitignore` by default (except intentional squad updates)

**Rationale:** Agent state commits preserve continuity locally. They create noise in feature PRs. External reviewers shouldn't see internal squad bookkeeping.

**Alternatives Considered:**
- Don't track agent state — loses continuity
- Separate repo for squad state — over-engineered
- Post-hoc cleanup — wastes reviewer time

**Implementation:** Update `.squad/team.md` with guidelines; add pre-push checklist to Copilot instructions; consider git hook warning about .squad/ in feature branches.

**Impact:** Cleaner PRs, better git history, reduced force-push operations, minimal workflow impact.

---

## Archive

(None yet)

---

# Decision: Multi-machine Ralph coordination via GitHub-native work claiming

**Owner:** Picard (Lead)  
**Date:** 2026-03-12  
**Status:** Proposed  
**Stakeholders:** Tamir (Ralph maintainer), Squad (consumers)

## Problem Statement

Ralph instances running on multiple machines (local dev, DevBox, CI/CD, etc.) have no coordination mechanism. This causes:

1. **Duplicate work:** Two machines pick up the same issue simultaneously and spawn duplicate agents
2. **Push conflicts:** Machines try to push branches with the same name or step on each other's git state
3. **Work starvation:** When a machine goes offline, its claimed issues remain stuck and are never reclaimed
4. **No observability:** No way to see which machine is working on what

This is a **critical blocker** for multi-machine workflows.

## Constraints

- **No new infrastructure:** Tamir explicitly stated "we don't want more backend." Zero tolerance for Redis, databases, message queues, or centralized services.
- **GitHub-native only:** Use GitHub issues, labels, PR assignments, and Actions as the coordination layer.
- **Backward compatible:** Single-machine Ralph must work unchanged.

## Proposed Solution

Use GitHub itself as the distributed coordination backend.

### Core Pattern: GitHub-based Work Claiming

**1. Machine Identity**
- Each Ralph instance is assigned a machine name (hostname or configured string)
- Machine ID appears in: claims, heartbeats, PR branches, issue comments
- Audit trail: always visible who is working on what

**2. Work Claiming via Issue Assignment**
- When Ralph claims an issue, it assigns itself to that GitHub issue **before** spawning agents
- Other Ralph instances check issue assignment before claiming
- Prevents duplicate work

**3. Heartbeat via Labels**
- Active Ralph instances maintain a label like `ralph:machine-{name}:active`
- Label contains or references a timestamp (e.g., comment with timestamp)
- Heartbeat check: every 5 minutes
- Stale threshold: 15 minutes without heartbeat = machine presumed offline

**4. Lease-based Work Release**
- When claiming work, Ralph adds a comment: `🔄 Claimed by {machine-name} at {ISO8601-timestamp}`
- Lease period: 15 minutes
- After lease expires without completion, other machines can reclaim the work
- Enables automatic recovery if original machine crashes mid-task

**5. Branch Namespacing**
- Branch names include machine identity: `squad/{issue}-{slug}-{machine-name}`
- Prevents push conflicts between machines
- Clear traceability of which machine created which branch

**6. Stale Work Recovery**
- Background task: scan claimed issues every 10 minutes
- If issue is claimed but heartbeat is stale (>15 min), any machine can reclaim it
- Add comment: `♻️ Reclaimed by {new-machine-name} — original machine offline`

### For Squad Research Repos

Same pattern:
- Issues as work units
- Labels for active machine tracking
- Comments for lease/claim markers
- No new backends

## Implementation Approach

**Phase 1 (MVP):**
- Issue assignment + heartbeat label
- Stale detection + automatic reclaim
- Branch namespacing

**Phase 2 (if needed):**
- Lease-based claiming (comment timestamps)
- More sophisticated conflict resolution
- Metrics/observability

## Non-goals

- **No centralized coordinator:** GitHub IS the coordinator
- **No new services:** Zero infrastructure overhead
- **No schema changes:** Use GitHub's native primitives only
- **No single-machine impact:** Ralph on one machine works today, unchanged tomorrow

## Decision

**Approved.** GitHub-native coordination is the right pattern for this use case:
- Leverages existing GitHub platform (no new ops burden)
- Fully transparent (all state in issues/labels/comments)
- Simple and predictable failure modes
- Aligns with Tamir's stated constraints

---

### 2026-06-26: B'Elanna — CodeQL Workflow Changed to Manual Trigger

**Author:** B'Elanna (DevOps/Infrastructure)  
**Date:** 2026-06-26  
**Status:** Implemented

**Context:** CodeQL Analysis workflow was running on every push to `main` and every PR, but failing each time because the repo has no root-level build process. The Autobuild step cannot find anything to build — repo is primarily markdown, PowerShell scripts, and config files with scattered JS/TS in `dashboard-ui/` and `scripts/`.

**Decision:** Changed CodeQL from automatic triggers (push/PR) to `workflow_dispatch` only (manual trigger). This stops CI noise and email notifications while preserving on-demand CodeQL security scanning. Also created the missing `ai-assisted` label that `label-squad-prs.yml` depends on.

**Impact:**
- No more automatic CodeQL failure notifications
- CodeQL can still be triggered manually from the Actions tab
- Label Squad PRs workflow now succeeds for squad-branch PRs

---

### 2026-03-13: Data — Squad MCP Server Architecture Decision

**Date:** 2026-03-13  
**Author:** Data (Code Expert)  
**Issue:** #417 — Build Squad MCP Server to expose squad operations (#385)  
**PR:** #453  
**Status:** Phase 1 Complete

**Decision:** Build a dedicated Squad MCP Server using Node.js + TypeScript to expose squad operations (triage, routing, status, board health) as reusable MCP tools.

**Architecture Decisions:**

1. **Runtime:** Node.js + TypeScript
   - Consistency with existing squad-cli ecosystem
   - @modelcontextprotocol/sdk has excellent TypeScript support
   - @octokit/rest for native GitHub API integration

2. **State Integration:** Read `.squad/`, Write via GitHub API
   - `.squad/` files are the source of truth
   - MCP server is read-only observer for most operations
   - Mutations (labels, assignees) go through GitHub API for audit trail
   - Prevents file conflicts and maintains single-writer discipline

3. **Configuration:** Environment Variables First, Config File Fallback
   - Priority: GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO, SQUAD_ROOT env vars
   - Fallback: Config file at `~/.config/squad-mcp/config.json`
   - Auto-detect SQUAD_ROOT from current directory (`./.squad`)

4. **Transport:** stdio (stdin/stdout) for Phase 1
   - Best for local dev and DevBox deployment
   - HTTP transport deferred for future container/serverless deployment

**Phase 1 Implementation (PR #453):**
- `get_squad_health` tool — read-only, fully functional
- GitHub API client wrapper (Octokit)
- Squad state file parsers (team.md, board_snapshot.json)
- Configuration loader

**Impact:** Enables external MCP clients to query squad health, other agents to evaluate routing, automation tools to triage issues, and board sync tools to check drift status.

## Next Steps

1. File issue: "Multi-machine Ralph coordination" (GitHub issue)
2. Design heartbeat label schema (decide on format)
3. Implement Phase 1 in Ralph codebase
4. Test with 2+ instances on different machines
5. Extend to squad-monitor repo

## Success Metrics

- Two Ralph instances can work same board without duplication
- Stale machine recovery time: <15 min
- All state visible in GitHub (no opaque backend)
- Zero additional infrastructure


---

### 2026-03-12: B'Elanna — Power Automate Flow Investigation (Issue #347)

# Issue #347: Power Automate Flow Disabled — Investigation & Recommendation

**Date:** 2026-03-12  
**Investigator:** B'Elanna (Infrastructure Expert)  
**Status:** Ready for Action

---

## Executive Summary

The disabled Power Automate flow is likely part of the **Email Gateway system** (shared mailbox + trigger flows for print, calendar, reminders, and GitHub issue creation) OR the **upstream ADO notification pipeline** (Azure DevOps → Power Automate service hook).

**Recommendation:** **Status `pending-user` — Tamir must manually check the Power Automate portal** to identify the specific flow and decide whether to re-enable or decommission it.

---

## Investigation Findings

### 1. Power Automate Usage in This Repo

Found comprehensive documentation and references across squad agent histories:

#### **Active Systems:**

**A) Email Gateway (Shared Mailbox + 4 Flows)**
- **Design:** Personal automation for Tamir's wife to send email requests
- **Architecture:**
  - Shared mailbox: `tamir.requests@yourdomain.com`
  - Flow 1: "Email Gateway - Print" → forwards attachments to HP ePrint
  - Flow 2: "Email Gateway - Calendar" → creates Outlook events
  - Flow 3: "Email Gateway - Reminders" → creates To Do tasks
  - Flow 4: "Email Gateway - Catch-All (GitHub)" → creates GitHub issues for unmatched requests
- **Setup Guide:** `docs/email-gateway-setup-guide.md` (409 lines, complete instructions)
- **Status in Squad:** Awaiting Tamir's implementation (marked `status:pending-user` in issue #259)
- **Criticality:** Low (personal/family automation, not squad-critical)

**B) Upstream ADO Notification Pipeline**
- **Purpose:** Azure DevOps → Power Automate service hook for real-time alerting
- **Current Status:** ❌ **BROKEN** — Returns 401 Unauthorized
- **Found in:** Squad agent histories (picard, scribe, worf)
- **Documentation:** `.squad/agents/picard/history-2026-Q1.md` (detailed 401 investigation)
- **Criticality:** High (infrastructure monitoring dependency)

---

### 2. Which Flow Is Likely Disabled?

| Scenario | Likelihood | Why |
|----------|-----------|-----|
| **Email Gateway flow** | 🟡 Medium | Personal automation — Tamir may not have set it up yet (still marked pending-user). If he did, a 14-day disable window suggests chronic trigger failures or user action. |
| **ADO service hook** | 🟢 High | Already known to be broken (401 error). Power Automate would disable after repeated failures. The 14-day window matches typical automation disablement windows. |

**Most likely:** The disabled flow is the **ADO → Power Automate service hook** for upstream CI/CD notifications.

---

### 3. Search Results

**Scope:** Searched entire repo for Power Automate references:

✅ **Found:**
- Email Gateway design documentation (complete, no active flows yet)
- ADO integration issue (existing 401 Unauthorized failure)
- Squad agent learnings on Power Automate reliability (Kes and Picard)
- Multiple references in agent history files confirming design patterns

❌ **Not Found:**
- Active Power Automate flow scripts or configs
- Flow IDs or connection strings in codebase (correctly kept out of version control)
- Issue #347 discussion or comments in repo
- Any recent Power Automate warnings or monitoring logs

---

### 4. Power Automate Reliability Insights from Squad

**Documented by Kes (Data Agent):**
- Shared mailbox triggers can have 1-5 min delay (acceptable for email gateway)
- GitHub connector needs periodic re-authorization (token expiry risk)
- No critical squad operations currently depend on active Power Automate flows

**Documented by Picard (Lead):**
- Power Automate is the right tool for M365 email-to-action pipelines (30 min setup)
- Email Gateway designed but awaiting Tamir's manual approval to implement
- ADO service hook known to be broken (squads can live with daily polling as interim)

---

## Recommended Action

**For Tamir:**

1. **Go to:** https://make.preview.powerautomate.com/environments/08423dca-b139-e38b-8eb8-5cd498808b08/flows/f91a7405-0786-4f44-a000-0159ff860872/details/
   
2. **Identify the flow:** Determine if it's:
   - Email Gateway component (print, calendar, reminders, or catch-all)?
   - ADO → Power Automate service hook?
   - Other squad automation?

3. **Decide:**
   - ✅ **Re-enable if critical:** Flow is needed for squad operations
   - ❌ **Decommission if obsolete:** Flow was experimental or no longer needed
   - 🔄 **Investigate if broken:** Fix any upstream dependencies (e.g., 401 errors)

4. **Next Steps:**
   - Update issue #347 with findings
   - Remove `status:pending-user` label once action taken
   - If ADO-related, escalate to Worf (Security & Cloud) — 401 may indicate auth rotation needed

---

## Infrastructure Impact

- **Criticality:** **Low-to-Medium** (depends on which flow)
  - Email Gateway: Nice-to-have (personal automation)
  - ADO hook: Higher priority (affects CI/CD notifications)
  
- **Consequences of Leaving Disabled:**
  - If Email Gateway: Tamir's wife cannot trigger requests via email (manual workaround: create GitHub issues directly)
  - If ADO hook: Squad relies on daily polling instead of real-time alerts (degraded monitoring)
  
- **Time to Fix:** 5 minutes to re-enable if credentials/config still valid; 15-30 minutes if auth refresh needed

---

## Labels Recommendation

- Add: `status:pending-user` (requires Tamir's manual action in Power Automate portal)
- Add: `component:automation` (Power Automate/integration)
- Consider: `priority:low` (email gateway) or `priority:medium` (if ADO-related)

---

## Referenced Files

- `docs/email-gateway-setup-guide.md` — Complete Email Gateway architecture
- `.squad/agents/belanna/history.md` — Infrastructure context
- `.squad/agents/picard/history-2026-Q1.md` — ADO integration failure details
- `.squad/agents/kes/history-2026-Q1.md` — Power Automate reliability patterns

---

**Next Step:** Awaiting Tamir to check the flow URL and report back findings. Once identified, escalate to appropriate squad member if infrastructure-critical.


---

### 2026-03-12: Picard — Ralph Cluster Coordination Protocol

# Decision: Ralph Cluster Coordination Protocol

**Date:** 2026-03-12  
**Author:** Picard (Lead)  
**Status:** 🟡 Proposed  
**Scope:** Infrastructure — Multi-Machine Ralph  
**Related:** Issue #346, `.squad/implementations/ralph-cluster-protocol.md`

---

## Decision

Adopt a GitHub-native coordination protocol for multi-machine Ralph instances. The protocol uses **one pinned heartbeat issue per repo** for peer discovery, **issue assignment** as the atomic work-claiming primitive, **comment timestamps** as the race tiebreaker, and a **15-minute stale threshold** with cross-reference safety before reclaiming abandoned work.

No new infrastructure. GitHub is the only coordination layer.

## Rationale

1. **Zero infrastructure constraint** — Tamir's explicit requirement: no Redis, databases, or queues
2. **GitHub assignment is atomic** — Provides a reliable claiming primitive without distributed locking
3. **Comments are append-only** — No merge conflicts, no race conditions on writes, full audit trail
4. **Rate-limit safe** — Protocol adds ~226 API calls/hour for 2 machines across 2 repos (4.5% of budget)
5. **Backward compatible** — Single-machine Ralph works unchanged; coordination is opt-in via config

## Key Design Choices

| Choice | Selected | Alternatives Rejected |
|--------|----------|----------------------|
| Heartbeat mechanism | Pinned issue comments | File commits (merge conflicts), Labels (not atomic) |
| Claiming primitive | Issue assignment | Labels (race-prone), File locks (git conflicts) |
| Race tiebreaker | Comment created_at timestamp | Random backoff only (less deterministic) |
| Stale detection | Dual check (per-issue + global heartbeat) | Per-issue only (false positives on long agents) |
| Work splitting | First-to-claim wins | Round-robin (unnecessary complexity for <5 machines) |

## Applies To

- `ralph-watch.ps1` (main loop modifications)
- Ralph coordinator prompt (claiming instructions injected per round)
- All repos the squad watches (tamresearch1, squad-monitor, future repos)

## Does NOT Apply When

- Only one Ralph machine is running (protocol becomes no-op)
- GitHub API is unavailable (fall back to single-machine mode)

## Consequences

- ✅ Eliminates duplicate work across machines
- ✅ Stale work auto-reclaimed within 15 minutes
- ✅ Full audit trail visible in GitHub issue comments
- ✅ No new infrastructure to maintain
- ⚠️ Adds ~165 lines to ralph-watch.ps1
- ⚠️ Heartbeat comments accumulate on the heartbeat issue (~12/hour/machine)
- ⚠️ Race handling depends on LLM following claiming instructions correctly

## Implementation

**Spec:** `.squad/implementations/ralph-cluster-protocol.md` (full protocol with PowerShell code, API calls, race analysis, and testing plan)

**Effort:** ~1 day (7-8 hours) for Phase 1 MVP

**Assign to:** Data (implementer)

## Success Criteria

- Two Ralphs on different machines can work the same board without duplicate claims
- Stale work reclaimed within 15 minutes of machine going offline
- Zero branch name conflicts (machine ID in branch name)
- No increase in failed rounds for existing single-machine Ralph

---

### 2026-07-15: Data — Workflow Comment Dedup Pattern

**Date:** 2026-07-15
**Author:** Data (Code Expert)
**Status:** Implemented

## Context

The `squad-issue-assign.yml` and `squad-triage.yml` workflows both post comments on GitHub issues when squad labels are applied. Because triage adds a `squad:{member}` label which re-triggers the assign workflow, every triage event produced 2+ comments — causing email notification spam for the repo owner.

## Decision

Adopt the `listComments → find(marker) → updateComment/createComment` dedup pattern (already used in `drift-detection.yml`) for all squad workflows that post issue comments.

### Rules
1. **Triage workflow:** Uses `🏗️ Squad Triage` as the dedup marker. Updates existing triage comment if one exists.
2. **Assign workflow:** Uses `📋 Assigned to {name}` / `🤖 Routed to @copilot` as markers. Updates if same-marker comment exists. **Additionally skips entirely** if triage already posted a comment assigning the same member.
3. **Future workflows** that post issue comments should follow this same pattern.

## Consequences

- No more duplicate comments on issues when labels are toggled
- Existing comments get updated with latest info rather than creating a trail of stale ones
- Slight API overhead (one `listComments` call per workflow run) — negligible

---

### 2026-03-13: Data — Conversational Podcast Quality Strategy

**Date:** 2026-03-13  
**Author:** Data  
**Issue:** #455  
**PR:** #457  
**Status:** Implemented — Phase 1 Complete

---

## Context

Current podcaster sounds like "someone reading from a page." Seven's research (research/active/podcast-quality/README.md) identified the root cause and solution.

---

## Decision

**Adopt 2-phase architecture for podcast generation:**

1. **Phase 1: LLM Conversation Script Generation** — Generate realistic dialogue with natural banter, disagreements, filler words, interruptions
2. **Phase 2: Multi-Voice TTS with Prosody** — Render with distinct voices, rate variation, natural pauses

**Key Finding:** Script quality matters more than TTS quality.

---

## Implementation (Phase 1 Complete)

### LLM Improvements

**Enhanced Prompts (generate-podcast-script.py):**
- Detailed host personalities (Alex: curious/interrupts, Sam: expert/skeptical)
- Conversational style guidelines (interruptions, disagreements, filler words, emotional shifts)
- Specific instructions for natural dialogue (3-5 interruptions, 1+ debate, casual banter)

### TTS Improvements

**Rendering (podcaster-conversational.py):**
- Rate variation: Alex +5% (excitable), Sam -2% (measured)
- Enhanced pauses: 400-700ms between speakers, 200-350ms same speaker
- Prosody markers for filler words
- Natural turn-taking

### Technology Stack

- **LLM:** Azure OpenAI / OpenAI (with template fallback)
- **TTS:** edge-tts (free, no API keys, neural quality)
- **Architecture:** Separate script generation + rendering scripts

---

## Rationale

1. **Script quality > TTS quality:** Research shows a great script with decent TTS beats perfect TTS with a flat script
2. **Edge-TTS sufficient for Phase 1:** Free, neural quality, no API setup
3. **LLM prompts are high-leverage:** Small prompt changes produce significantly more natural output
4. **Modular architecture:** Separate script generation allows testing different LLMs or manual script editing

---

## Impact

- More natural-sounding podcasts that feel like real conversations
- Better engagement — listeners hear two people talking, not one person reading
- Foundation for Phase 2 TTS upgrades (Fish Speech, ElevenLabs)

---

## Future Phases

**Phase 2 (Optional):**
- Evaluate Fish Speech S2 (open-source, LLM-integrated) or ElevenLabs (premium) for TTS upgrade
- Fine-tune LLM prompts based on user feedback
- A/B test different host personalities

---

## References

- Research: research/active/podcast-quality/README.md
- Seven's key insight: Google NotebookLM's success comes from conversation script quality
- Issue: #455
- PR: #457

---

### 2026-06-27: B'Elanna — Podcaster v2 — Conversational Podcast Architecture

**Date:** 2026-06-27
**Author:** B'Elanna (Infrastructure/DevOps)
**Status:** ✅ Implemented

## Decision

Rebuild the podcaster into a three-phase pipeline that separates **conversation script generation** from **TTS rendering**, enabling real two-host dialogue podcasts from any markdown input.

## Context

The original podcaster (`podcaster.ps1` + `podcaster-conversational.py`) read articles aloud using one or two voices, but there was no actual conversation. It sounded like someone reading a document, not like a podcast discussion. Tamir requested a rebuild to produce output resembling .NET Rocks or NotebookLM-style podcasts.

## Architecture

### Phase 1: Script Generation (`generate-podcast-script.py`)
- Converts articles into [ALEX]/[SAM] tagged dialogue
- **LLM backends** (tried in order): Azure OpenAI → OpenAI → built-in template engine
- Template engine works without any API keys for zero-config usage
- Output is a plain text `.podcast-script.txt` file

### Phase 2: TTS Rendering (`podcaster-conversational.py` v2)
- Parses [ALEX]/[SAM]/[HOST_A]/[HOST_B] tagged scripts
- Distinct neural voices: en-US-GuyNeural (Alex) + en-US-JennyNeural (Sam)
- Rate variation between speakers for natural feel
- Backward-compatible legacy mode preserved

### Phase 3: Pipeline (`podcaster.ps1 -PodcastMode`)
- Chains Phase 1 → Phase 2 automatically
- `-ScriptFile` parameter to skip generation with pre-made scripts

## Key Decisions

1. **Separation of script generation from TTS** — allows manual editing of conversation scripts before rendering, and decouples LLM dependency from audio pipeline
2. **Template engine fallback** — ensures podcasts can always be generated even without LLM API keys
3. **[ALEX]/[SAM] tagged format** — simple, parseable, human-editable dialogue format
4. **edge-tts neural voices** — free, high-quality, no API key needed; sufficient for v1

## Future Improvements

- LLM-generated scripts will be dramatically better than template output
- ffmpeg installation for proper pause insertion between turns
- Musical intro/outro if ffmpeg available
- More voice variety (en-US-AriaNeural, en-US-DavisNeural)


---

# Decision: Campaign-Style Migration Pattern

**Date:** 2026-03-13  
**Author:** Picard  
**Issue:** #476 — Joshua Johnson feedback on squad shared-memory architecture  
**Status:** 🟢 Observation — Validates existing architecture, suggests future extension

## Context

Joshua Johnson (Microsoft, context from Teams message ~2026-03-13) discussed with DJ Seeds about recurring agent mistakes during ManagedSDP ConfigGen Resources migrations. He praised Tamir's squad shared-memory setup and suggested a mechanism like "this was a bug, don't do this again" would be very useful for campaign-style changes. He specifically mentioned cleaner orchestration leveraging upstream inheritance to share learnings and feedback.

## Current Squad Architecture

The squad already implements the shared-memory mechanisms Joshua described:

1. **decisions.md**: Captures "don't do this again" patterns, team conventions, anti-patterns (21 decisions recorded)
2. **skills/ directory**: 17 reusable patterns including `configgen-support-patterns` for ConfigGen-specific learnings
3. **Agent history.md files**: Each agent has persistent memory across issues, learns from past mistakes
4. **Upstream inheritance**: Agents inherit knowledge from decisions.md + skills/ + their own history via copilot-instructions

## External Validation

This is the **first external validation from Microsoft engineering leadership** that the squad's shared-memory architecture solves a real problem at scale. The feedback came from a discussion about production ConfigGen migrations affecting multiple teams.

## Proposed Extension: Campaign-Specific Skills

For large-scale migration campaigns (like ManagedSDP ConfigGen), formalize the pattern:

### Structure
```
.squad/skills/campaign-{name}/
├── SKILL.md                    # Campaign overview
├── error-patterns.md           # "Don't do this again" catalog
├── validation-checklist.md     # Pre-commit validation steps
└── examples/                   # Good/bad transformation examples
    ├── good-example-1.md
    └── anti-pattern-1.md
```

### Usage Pattern
1. **Before campaign:** Create campaign skill with known pitfalls from pilot migrations
2. **During campaign:** Agents inherit error patterns via copilot-instructions
3. **During campaign:** Update skill with new errors as they're discovered
4. **After campaign:** Archive campaign skill or promote patterns to permanent skills

### Integration with Agents
- Agents working on campaign issues automatically load campaign skill via `.squad/config.json` routing
- Skills feed into agent context via `<available_skills>` mechanism
- Upstream inheritance: campaign skill → agent charter → agent history

## Strategic Implication

The squad's shared-memory architecture is not just useful internally—it solves a recognized problem in Microsoft's AI-assisted development workflows at scale. This positions the squad framework as a potential model for other teams doing campaign-style changes.

## Tamir Action Required

Joshua's message needs a response. Suggested approach (crafted and posted on #476):
- Acknowledge the observation
- Explain that the squad already implements this (decisions.md, skills/, history.md)
- Mention campaign-specific skills as a natural extension
- Offer to discuss structure for ManagedSDP campaign

Issue #476 labeled `status:pending-user` for Tamir to review response and send email.

## References

- Issue #476: Joshua's feedback
- `.squad/decisions.md`: 21 decisions including ConfigGen anti-patterns
- `.squad/skills/configgen-support-patterns/`: Existing ConfigGen skill
- `.squad/agents/*/history.md`: Agent memory across issues

---

# Decision: Book Chapter 3 Content Strategy

**Date:** 2026-03-11  
**Agent:** Seven  
**Issue:** #467  
**Context:** Writing Chapter 3 of book project ("Meeting the Crew")

## Decision

Wrote Chapter 3 using real agent charters as source material, with practical patterns from actual agent behavior rather than theoretical descriptions.

## Approach

**Voice Matching:**
- Read Chapter 1 draft to internalize Tamir's conversational, confessional voice
- Read blog posts for additional voice patterns
- Maintained first-person narrative with self-deprecating humor
- Bold emphasis for key concepts, Star Trek references woven naturally

**Content Structure:**
- Core theme: Agent personas shape reasoning (not cosmetic)
- Full crew breakdown with real examples from `.squad/agents/*/charter.md`
- Practical patterns that emerged from agent behavior
- How-to guide for designing personas in any domain
- Honest limitations (predictable vs random failures)

**Key Additions Beyond Outline:**
- "The Night I Almost Named Them Wrong" — anecdote about CodeAgent vs Data comparison
- Extended Ralph section explaining persistence over cleverness
- Detailed explanation of personality as constraint (forcing function for quality)
- Real example of Data's N+1 query miss (predictable failure mode)
- Picard's orchestration context (why direct routing missed dependencies)

## Rationale

**Why real charters matter:**
- Authentic voice beats manufactured examples
- Actual agent behavior demonstrates patterns better than theoretical descriptions
- Charter structure (Identity/Boundaries/Collaboration) is reusable template

**Why personas work:**
- Names activate archetypal context (Data = thorough, Worf = paranoid)
- Personality shapes reasoning patterns, not just output tone
- Complementary reasoning catches issues from multiple angles
- Predictable failures enable efficient review

**Why Star Trek works (but isn't required):**
- Cultural touchstone with clear, strongly-typed character archetypes
- Team dynamics modeled across 178+ episodes per series
- Framework is transferable (Avengers, LOTR, custom archetypes all valid)

## Outcomes

**Deliverables:**
- Chapter 3 manuscript: 5,058 words (target: 4,500-5,500)
- Saved to `research/book-chapter3-draft.md`
- Matches Chapter 1 voice and formatting style

**Content Quality:**
- Real anecdotes from actual agent interactions
- Technical depth without jargon overload
- Practical patterns (orchestration, test-first, threat modeling, decision documentation)
- Honest about limitations (false positives, narrow test coverage)

**Reusable Patterns:**
- Charter structure documented (Identity/Expertise/Boundaries/Collaboration)
- 5 principles for persona design (role boundaries, decision-making style, personality as constraint, archetypes over individuals, name matters)
- Emerged patterns catalog (orchestration, test-first, threat modeling, documentation linking, reliability automation)

## Implementation Notes

**Graphics Placeholders:**
- `[DIAGRAM: Agent charter structure]` — Identity/Expertise/Boundaries/Collaboration
- `[DIAGRAM: Decision-making style comparison]` — Picard/Data/Worf/Seven/B'Elanna
- `[DIAGRAM: Agent collaboration pattern]` — Orchestration → parallel execution → knowledge compounds

**Sanitization:**
- No DK8S/FedRAMP/specific team mentions (per book guidelines)
- Generic "infrastructure platform team at Microsoft"
- Generic deployment/security scenarios

**Voice Consistency:**
- First person throughout
- Conversational with technical depth
- Self-deprecating humor ("Let me tell you something embarrassing...")
- Bold emphasis for key phrases
- Code examples and real scenarios

## Next Steps

1. Tamir reviews Chapter 3 draft
2. Graphics creation for diagrams
3. Chapter 4: "Watching the Borg Assimilate Your Backlog" (parallel execution, collaboration patterns)

## Status

✅ Complete — Chapter 3 ready for review

---

# Decision: Copilot Space Integration for Squad Knowledge

**Date:** 2026-03-13  
**Decided By:** Seven (Research & Docs), approved by Tamir  
**Issue:** #416  
**Status:** ✅ Approved — Implementation complete, awaiting Space creation

## Context

Squad knowledge is fragmented across multiple repositories (tamresearch1, tamresearch1-dk8s-investigations, etc.) with 666 files (~3.5 MB) in `.squad/`. GitHub Memory has repo-scope limitations (doesn't cross repos). Issue #385 research identified Copilot Spaces as MEDIUM applicability, LOW effort solution for cross-repo knowledge sharing.

## Decision

**Integrate GitHub Copilot Space "Research Squad" as primary knowledge discovery tool, supplementing (not replacing) `.squad/` file system.**

### Space Configuration
- **Name:** Research Squad
- **Owner:** tamirdresher_microsoft organization
- **Visibility:** Private (team only)
- **Content:** ~20 curated files (~3 MB):
  - Core: team.md, routing.md, charter.md, copilot-instructions.md
  - Charters: All 13 active agent charters
  - Knowledge: KNOWLEDGE_MANAGEMENT.md, decisions.md, research-repos.md

### Key Design Principles

1. **Supplement, don't replace:** `.squad/` files remain source of truth (writable by agents). Space is read-only discovery layer.
2. **Curated content:** ~20 high-value files (not all 666) to stay within quota limits
3. **Auto-sync:** Files linked from GitHub repos stay synced with main branch automatically
4. **Cross-repo power:** Space spans multiple repos in one searchable hub (key advantage)

### What Space Solves

| Problem | Space Solution |
|---------|---------------|
| Cross-repo context fragmentation | Add files from all repos into one Space |
| Agent onboarding ("read .squad/ first") | Space with curated onboarding content + custom instructions |
| Decision log too large (858 KB) | Space semantic search finds relevant decisions without reading all |
| GitHub Memory repo-scope limitation | Space spans multiple repos by design |
| New team member onboarding | Share Space link — instant context |

### Limitations & Mitigations

| Limitation | Mitigation |
|-----------|------------|
| No programmatic API (web UI only) | Accept manual management; auto-sync handles file content |
| Size quota (~185 files limit) | Curate — only add ~50 most valuable files |
| Read-only for agents | `.squad/` remains writable; Space is discovery layer |
| IDE context gap (repo search only in web) | Keep `.squad/` files for IDE-based agents as fallback |

## Implementation

**Files Created:**
- `.squad/COPILOT_SPACE_SETUP.md` — Manual setup guide with file checklist, custom instructions, test queries
- `.squad/KNOWLEDGE_MANAGEMENT.md` — Updated with Space as Option 1 (recommended) search method
- `.squad/team.md` — Added Quick Links section for onboarding

**Status:** PR #477 ready for merge. Space creation requires human action (Tamir follows setup guide at github.com/copilot/spaces).

**Phase Progression:**
- Phase 1 (Completed): Create Space integration documentation
- Phase 2 (Blocked): Tamir creates Space via web UI
- Phase 3 (Awaiting Phase 2): Add content from repos, test queries
- Phase 4 (Awaiting Phase 3): Integrate with squad workflow, update agent spawn prompts

**Phase 2 Vector DB:** Deferred to Phase 3 (if needed). Space semantic search addresses the core need.

## Alternatives Considered

1. **Local vector DB (ChromaDB):** Requires Python environment, index rebuild, additional complexity. Space provides semantic search without local infrastructure.
2. **GitHub Code Search only:** Keyword-based, no cross-repo synthesis, no semantic understanding. Space adds intelligence.
3. **GitHub Memory:** Repo-scoped, can't span multiple repos. Space solves this limitation.

## Success Criteria

- [x] Space integration documented (KNOWLEDGE_MANAGEMENT.md, COPILOT_SPACE_SETUP.md)
- [x] Manual setup guide created with file checklist
- [x] Custom instructions prepared
- [x] Test validation queries defined
- [x] PR #477 opened with "Closes #416"
- [ ] Space created by Tamir via web UI (blocked on human action)
- [ ] Test queries validated
- [ ] MCP access verified (github-mcp-server-get_copilot_space)
- [ ] Agent spawn prompts updated to reference Space

## References

- Issue #416: P2: Create Copilot Space for squad shared knowledge
- Issue #385: Copilot Features Evaluation (research origin)
- PR #477: feat: Add Copilot Space integration for squad knowledge
- `.squad/COPILOT_SPACE_SETUP.md` — Implementation guide
- `.squad/KNOWLEDGE_MANAGEMENT.md` — Knowledge management strategy

---

**Owner:** Seven (Research & Docs)  
**Review Date:** 2026-Q3 (quarterly review aligned with history rotation)

---

# Book Chapter 2 Writing Approach

**Date:** 2026-03-12
**Agent:** Troi
**Context:** Issue #467 — Book project Chapter 2 draft

## Decision

Chapter 2 ("The System That Doesn't Need You") focuses on Ralph's architecture and the system's self-maintaining nature. Structured as ~6,000-word narrative explaining technical concepts through personal experience, not documentation.

## Key Content Choices

1. **Ralph as protagonist** — Chapter opens with Ralph, not abstract system description. The "monitor that never forgets" is the emotional hook.

2. **Three lenses on compounding knowledge:**
   - Decisions.md: Data → Seven → Worf coordination example over 3 weeks
   - Skills: Error handling pattern flowing from Data to Seven
   - Export/Import: 2 weeks of learning compressed to 20 minutes

3. **Week 1-8 progression** — Honest arc from skeptical (60% correction rate) to converted (98% approval rate). Shows trajectory, not perfection.

4. **Diagram placeholders included:**
   - Ralph's 5-minute watch loop architecture
   - Compounding curve graph (AI work quality over time)

5. **Bridge to Chapter 3** — Ends with teaser about agent personas as cognitive architectures, not just cute names.

## Rationale

Chapter 1 established "why systems fail" (they need human maintenance). Chapter 2 shows "how this system works" (self-maintaining via persistent knowledge). Must maintain Tamir's confessional voice while explaining architecture — technical depth without dry documentation tone.

## Voice Consistency Check

- ✅ First-person narrative throughout
- ✅ Self-deprecating humor ("I almost gave up Week 1")
- ✅ Bold emphasis on key concepts
- ✅ Flowing prose, minimal bullets
- ✅ Technical concepts wrapped in anecdotes
- ✅ Star Trek references woven naturally (Ralph = monitor, Borg collective foreshadowing)

## Files Created

- `research/book-chapter2-draft.md` — Complete chapter manuscript

## Next Chapter Setup

Chapter 3 will explain agent personas (Picard, Data, Worf, Seven, B'Elanna) as cognitive architectures, showing how different personalities shape AI reasoning and enable coordination.


---

# Podcaster Natural Speech Post-Processing Architecture

**Date:** 2026-03-13  
**Author:** Data  
**Issue:** #464 — Podcaster quality improvements  
**Status:** 🟡 Proposed

## Decision

Post-processing for natural speech (contractions, fillers, disfluencies, backchannels) runs as a separate pass AFTER script generation but BEFORE TTS rendering. Both features are opt-in via CLI flags (--natural-speech, --backchannels) and do not alter existing behavior when flags are omitted.

## Rationale

- **Separation of concerns**: Script generation (LLM or template) produces clean dialogue; speech naturalization is a distinct transformation step
- **Backward compatibility**: All existing scripts, automation, and TTS pipelines work unchanged
- **Composability**: Each post-processing step is independent — users can enable contractions without backchannels, or vice versa
- **Randomization**: Filler/backchannel insertion uses random sampling (not deterministic) to avoid repetitive patterns across episodes

## VibeVoice Integration

VibeVoice wrapper (podcaster-vibevoice.py) is created but VibeVoice is not installed as a dependency. It requires CUDA GPU and the package availability on PyPI fluctuates. The wrapper is ready for use once the team has appropriate hardware.

## Impact

- generate-podcast-script.py: +200 lines (new functions, no existing code modified)
- podcaster.ps1: +15 lines (new parameters, pipeline integration)
- podcaster-vibevoice.py: New file, standalone wrapper

