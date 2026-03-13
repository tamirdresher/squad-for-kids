# GitHub Copilot Features Evaluation for Research Squad

> **Research ID:** copilot-features-eval  
> **Researcher:** Geordi (Technology Scanner)  
> **Status:** Active  
> **Date:** 2026-07-08  
> **Issue:** [tamirdresher_microsoft/tamresearch1#385](https://github.com/tamirdresher_microsoft/tamresearch1/issues/385)

---

## Executive Summary

The GitHub Copilot platform has undergone a radical transformation in 2025–2026. What was once an autocomplete tool is now a full agentic development platform with hooks, persistent memory, cloud-based coding agents, multi-model support, and standards-based interoperability (MCP, A2A).

**The Research Squad is already ahead of the curve** in several areas — we use custom agents, MCP servers, and the CLI extensively. But there are significant new capabilities we're leaving on the table, particularly: **Copilot Hooks** for deterministic workflow enforcement, **GitHub Memory** for cross-session context, **Agentic Workflows** (GitHub Actions-powered), **Copilot Spaces** for shared project knowledge, and the **A2A protocol** for inter-agent communication.

**Bottom line:** Ralph doesn't need to "move to the cloud" wholesale — but specific Ralph responsibilities (issue triage, board reconciliation, routine scans) are prime candidates for migration to **GitHub Agentic Workflows** that run in Actions, reducing DevBox dependency and improving reliability.

---

## Feature-by-Feature Analysis

### 1. Copilot Hooks

| Dimension | Assessment |
|-----------|------------|
| **What it is** | Event-driven shell scripts that execute at lifecycle points during Copilot agent runs: `sessionStart`, `sessionEnd`, `userPromptSubmitted`, `preToolUse`, `postToolUse`, `errorOccurred` |
| **Current squad status** | ❌ Not using |
| **Applicability** | 🔴 **HIGH** |
| **Effort to adopt** | 🟢 LOW — just add `.github/hooks/hooks.json` to the repo |
| **Impact** | Deterministic enforcement of squad conventions: auto-log all sessions, block unsafe tool operations, run linters after edits, enforce branch naming conventions, inject squad context at session start |

**Squad-specific opportunities:**
- `sessionStart` hook → inject squad identity context (which agent, which repo, current round)
- `preToolUse` hook → enforce guardrails (prevent `rm -rf`, block commits to `main`)
- `postToolUse` hook → auto-run formatters, update `.squad/log` after file changes
- `errorOccurred` hook → send Teams alert on agent failures (replace manual `consecutiveFailures` tracking in `ralph-watch.ps1`)

**Recommendation:** Implement immediately. This is low-hanging fruit that adds safety and observability.

---

### 2. GitHub Memory (Persistent Memory)

| Dimension | Assessment |
|-----------|------------|
| **What it is** | Repository-scoped persistent memory that survives across sessions. Copilot remembers coding conventions, architecture decisions, preferences. Auto-expires after 28 days. Available for Pro/Pro+ users. |
| **Current squad status** | 🟡 Partial — We use `store_memory` tool and `.squad/` files for context, but each agent session starts mostly fresh |
| **Applicability** | 🔴 **HIGH** |
| **Effort to adopt** | 🟢 LOW — enable in repo settings, Copilot starts learning automatically |
| **Impact** | Eliminates the "Groundhog Day" problem where every Ralph round re-discovers the same context. Agents remember squad conventions, issue patterns, and architectural decisions across sessions. |

**Squad-specific opportunities:**
- Ralph could remember which issues were problematic, what approaches failed previously
- Geordi's tech scans would build on previous evaluations instead of starting from zero
- Reduces prompt engineering burden — less need for verbose instructions in `ralph-watch.ps1`
- Three memory scopes available: **user** (personal prefs), **repository** (shared team knowledge), **session** (current work)

**Caveat:** Memory is repo-scoped, not cross-repo. Our `tamresearch1` ↔ `tamresearch1-research` split means memories don't transfer between repos. This is a limitation to design around.

**Recommendation:** Enable immediately on both repos. Monitor what gets stored and curate actively.

---

### 3. A2A (Agent-to-Agent) Protocol

| Dimension | Assessment |
|-----------|------------|
| **What it is** | Open standard (Google/Linux Foundation) for secure agent interoperability. Agents publish "Agent Cards" (`/.well-known/agent-card.json`) describing capabilities. Supports multi-turn dialogues, task delegation, streaming over HTTP/JSON-RPC. SDKs in Python, JS, Java, Go, .NET. |
| **Current squad status** | ❌ Not using |
| **Applicability** | 🟡 **MEDIUM** |
| **Effort to adopt** | 🔴 HIGH — requires building/hosting A2A endpoints |
| **Impact** | Could enable squad agents to communicate with external agent ecosystems (Copilot Studio, Gemini, custom enterprise agents). The `a2a-copilot` adapter already exists for wrapping Copilot as A2A endpoint. |

**Squad-specific opportunities:**
- Production squad ↔ Research squad could communicate via A2A instead of GitHub issues
- Interesting for the `bridge/` system — A2A could formalize the inbound/outbound routing
- Microsoft Copilot Studio integration path for enterprise scenarios
- Multi-squad coordination (currently manual) could become protocol-driven

**Caveat:** This is an emerging protocol. The squad's current GitHub-issues-based communication is simpler and works well. A2A is overengineered for our current scale unless we're connecting to external agent systems.

**Recommendation:** Monitor and prototype when cross-system agent communication becomes a real need. Not urgent.

---

### 4. Agentic Actions & Coding Agents

| Dimension | Assessment |
|-----------|------------|
| **What it is** | Copilot can now autonomously plan, execute, and iterate on coding tasks. Assign GitHub issues to Copilot → it creates a sandbox via Actions → submits a draft PR. Agent Mode in IDEs for multi-file edits with self-correction. |
| **Current squad status** | 🟢 Heavily using — squad agents are fundamentally agentic (task tool, sub-agents) |
| **Applicability** | 🔴 **HIGH** |
| **Effort to adopt** | 🟢 LOW — we already have the architecture |
| **Impact** | The official GitHub Coding Agent (assign issues to @copilot) could supplement Ralph for simple issues. Multi-model picker lets agents choose the best LLM per task. |

**Squad-specific opportunities:**
- Simple issues (label fixes, doc updates, formatting) → assign directly to `@copilot` instead of Ralph processing them
- **Multi-model support** — use GPT-5 for complex reasoning, Haiku for fast triage, Opus for nuanced analysis
- Plan Mode for structured task decomposition before execution
- Isolated subagents for focused subtasks (we already do this with `task` tool)

**What we already do well:** Our sub-agent spawning via `task` tool is more sophisticated than the default Coding Agent because we have custom personas, MCP integrations, and domain-specific tooling.

**Recommendation:** Use GitHub's native Coding Agent for "commodity" issues. Keep custom squad agents for research-grade work.

---

### 5. GitHub Agentic Workflows (Actions-Powered)

| Dimension | Assessment |
|-----------|------------|
| **What it is** | Define automation in Markdown files. YAML frontmatter sets triggers (schedule, events, slash commands). Natural language body describes the task. Runs inside GitHub Actions sandbox. Supports chaining multiple agents. Install `gh-aw` CLI extension. |
| **Current squad status** | ❌ Not using — Ralph runs on DevBox as PowerShell loop |
| **Applicability** | 🔴 **HIGH** — This is the biggest opportunity |
| **Effort to adopt** | 🟡 MEDIUM — need to decompose Ralph's responsibilities into individual workflows |
| **Impact** | **This is the path to "booting Ralph to the cloud."** Instead of one monolithic 5-min loop on a DevBox, individual agentic workflows handle specific tasks triggered by events or schedules. |

**Squad-specific migration opportunities:**

| Current Ralph Responsibility | Agentic Workflow Replacement |
|------------------------------|------------------------------|
| Issue triage every 5 min | `on: issues` event trigger → instant triage |
| Board reconciliation | `on: schedule` (hourly) → label consistency check |
| Teams/email monitoring | `on: schedule` (every 30 min) → WorkIQ check via MCP |
| News scanning | `on: schedule` (daily 7AM) → HackerNews/arXiv scan |
| PR review routing | `on: pull_request` event → auto-review assignment |
| Heartbeat/health | GitHub Actions has built-in monitoring |

**Key advantage:** Event-driven vs. polling. Issues get triaged in seconds (on event) instead of waiting up to 5 minutes for the next Ralph round.

**Key risk:** GitHub Actions minutes consumption. Need to model costs.

**Recommendation:** Phase 1: Move issue triage and board reconciliation to Agentic Workflows. Phase 2: Migrate Teams monitoring. Phase 3: Evaluate full Ralph replacement.

---

### 6. MCP (Model Context Protocol) — Latest Developments

| Dimension | Assessment |
|-----------|------------|
| **What it is** | Open standard (Anthropic) for connecting AI agents to external tools/APIs. GitHub is deprecating App-based Copilot Extensions (Nov 2025) in favor of MCP. "Build once, use anywhere" — MCP servers work with Copilot, Claude, Copilot Studio, etc. |
| **Current squad status** | 🟢 **Already using extensively** — Teams MCP, ADO MCP, GitHub MCP, WorkIQ MCP, Aspire MCP, EnghHub MCP, ConfigGen MCP |
| **Applicability** | 🟢 Continued HIGH |
| **Effort to adopt** | Already adopted |
| **Impact** | We're well-positioned. Key action: ensure our MCP integrations work with the coding agent (remote MCP servers) and Agentic Workflows. |

**What's new in MCP (2025–2026):**
- **MCP Registry** — centralized discovery of MCP servers
- **Remote MCP for Coding Agent** — use MCP servers directly in GitHub's cloud sandbox
- **Streamable HTTP transport** — replacing SSE for better reliability
- **MCP in Copilot Studio** — enterprise-grade orchestration

**Squad-specific actions:**
- Register our custom MCP servers in the MCP Registry for discoverability
- Test which of our MCP servers work in the GitHub Coding Agent sandbox (remote MCP)
- Consider building a custom **Squad MCP Server** that exposes squad operations (triage, routing, status) as MCP tools

**Recommendation:** Continue current approach. Explore building a Squad MCP Server for reusable squad operations.

---

### 7. Copilot Spaces

| Dimension | Assessment |
|-----------|------------|
| **What it is** | GA since Sept 2025. Curated "living knowledge hubs" — gather files, issues, docs, repos into a Space so Copilot has grounded context. Supports public/private sharing. Successor to Knowledge Bases. |
| **Current squad status** | ❌ Not using — we use `.squad/` files and agent charters for context |
| **Applicability** | 🟡 **MEDIUM** |
| **Effort to adopt** | 🟢 LOW — create Space on GitHub, add relevant files |
| **Impact** | Could replace our `.squad/` context system with a more integrated, GitHub-native approach. Useful for onboarding new squad members or sharing research context across repos. |

**Squad-specific opportunities:**
- Create a "Research Squad" Space containing agent charters, routing rules, ceremonies docs
- Share context between `tamresearch1` and `tamresearch1-research` (works around Memory's repo-scope limitation)
- Public Space for open-source squad framework sharing
- Code viewer integration — add files from either repo into the Space

**Caveat:** Spaces are primarily designed for Copilot Chat context enrichment, not for agent-to-agent context sharing. May not directly help Ralph/squad operations.

**Recommendation:** Create a Research Squad Space for knowledge sharing. Evaluate whether it can supplement `.squad/` context files.

---

### 8. Custom Agents (`.github/agents/`)

| Dimension | Assessment |
|-----------|------------|
| **What it is** | Define specialized AI agents as Markdown/YAML files in `.github/agents/`. Agents have roles, tools, instructions, and context. Selectable in Copilot chat or automations. |
| **Current squad status** | 🟢 **Already using** — we have `.github/agents/squad.agent.md` and `.squad/agents/` with full charters |
| **Applicability** | 🟢 Already adopted |
| **Effort to adopt** | Already adopted |
| **Impact** | Our implementation is more sophisticated than the default. Key action: ensure our agent files conform to GitHub's latest schema for maximum platform integration. |

**Squad-specific actions:**
- Verify our `squad.agent.md` works with the latest agent file schema
- Consider creating individual agent files per squad member (`geordi.agent.md`, etc.) for direct invocation
- Leverage agent + hooks integration for deterministic squad workflows

**Recommendation:** Audit and update agent file format. Create per-member agent files.

---

### 9. Copilot Workspace (Cloud Coding Environment)

| Dimension | Assessment |
|-----------|------------|
| **What it is** | Browser-based, agentic dev environment. Describe a task in natural language → Workspace creates spec/plan → edits files → submits PR. Features self-healing builds and mobile support. Now integrated into the Copilot Coding Agent ecosystem. Available on Pro+ plans. |
| **Current squad status** | ❌ Not using — squad operates via CLI on DevBox |
| **Applicability** | 🟡 **MEDIUM** |
| **Effort to adopt** | 🟢 LOW — it's a GitHub.com feature, no setup needed |
| **Impact** | Alternative to DevBox for certain workflows. Good for ad-hoc research tasks that don't need full squad infrastructure. |

**Squad-specific consideration:**
- Could be used for quick, one-off research spikes without spinning up a DevBox
- Not suitable as a Ralph replacement — it's designed for human-initiated workflows
- Coding Agent (cloud sandbox) is the programmatic equivalent

**Recommendation:** Use opportunistically for manual research tasks. Not a priority for squad automation.

---

### 10. GitHub Copilot CLI (GA)

| Dimension | Assessment |
|-----------|------------|
| **What it is** | Full-featured terminal Copilot interface. Chat, edit files, run commands, use MCP servers — all from the command line. GA as of Feb 2026. |
| **Current squad status** | 🟢 **Core of squad operations** — this is how Ralph and all agents run |
| **Applicability** | 🟢 Already core |
| **Effort to adopt** | Already adopted |
| **Impact** | We're power users. Key action: stay on latest version for new features. |

**Recommendation:** Keep current. Monitor for new CLI-specific features.

---

## Evaluation Matrix Summary

| Feature | Status | Applicability | Effort | Priority |
|---------|--------|---------------|--------|----------|
| **Copilot Hooks** | ❌ Not using | 🔴 HIGH | 🟢 LOW | 🥇 **P0 — Do now** |
| **GitHub Memory** | 🟡 Partial | 🔴 HIGH | 🟢 LOW | 🥇 **P0 — Do now** |
| **Agentic Workflows** | ❌ Not using | 🔴 HIGH | 🟡 MED | 🥈 **P1 — Next sprint** |
| **Custom Agents audit** | 🟢 Using | 🟢 HIGH | 🟢 LOW | 🥈 **P1 — Next sprint** |
| **Copilot Spaces** | ❌ Not using | 🟡 MED | 🟢 LOW | 🥉 **P2 — Plan** |
| **MCP updates** | 🟢 Using | 🟢 HIGH | 🟢 LOW | 🥉 **P2 — Ongoing** |
| **Coding Agent (native)** | 🟡 Partial | 🔴 HIGH | 🟢 LOW | 🥉 **P2 — Plan** |
| **Copilot Workspace** | ❌ Not using | 🟡 MED | 🟢 LOW | P3 — Opportunistic |
| **A2A Protocol** | ❌ Not using | 🟡 MED | 🔴 HIGH | P3 — Monitor |

---

## "Should Ralph Move to the Cloud?" Assessment

### Short answer: **Partially yes, but not wholesale.**

### The Case FOR Cloud Ralph (Agentic Workflows)

| Factor | DevBox Ralph | Cloud Ralph (Agentic Workflows) |
|--------|-------------|-------------------------------|
| **Triggering** | Polling every 5 min | Event-driven (instant) |
| **Availability** | DevBox must be running | Always-on (GitHub Actions) |
| **Scalability** | Single instance per machine | Parallel runners per event |
| **Cost** | DevBox VM cost (fixed) | Actions minutes (usage-based) |
| **Monitoring** | Custom heartbeat/lockfile | Built-in Actions monitoring |
| **Multi-machine** | Complex coordination (Issue #346) | GitHub handles concurrency |
| **Debugging** | SSH into DevBox | Actions logs + audit trail |

### The Case AGAINST Full Cloud Migration

- **MCP server access:** Some MCP servers (Teams, WorkIQ, Outlook) require COM automation or local Windows APIs. These won't work in Actions Linux runners.
- **Stateful operations:** Ralph's `consecutiveFailures` tracking, heartbeat system, and multi-machine coordination have state that needs redesigning.
- **Cost uncertainty:** Heavy Actions usage could exceed DevBox costs. Need to model.
- **Complex prompts:** Ralph's 80-line prompt with multi-repo watch, Teams monitoring, and news scanning is sophisticated. Decomposing into individual workflows requires careful design.

### Recommended Hybrid Approach

```
┌─────────────────────────────────────────────────────┐
│                 HYBRID RALPH v9                      │
│                                                      │
│  ┌──────────────────┐   ┌──────────────────────┐    │
│  │  Cloud (Actions)  │   │  DevBox (Residual)    │    │
│  │                    │   │                        │    │
│  │  • Issue triage    │   │  • Teams/email monitor │    │
│  │  • Board reconcile │   │  • Outlook COM access  │    │
│  │  • PR review route │   │  • News scanning       │    │
│  │  • Doc updates     │   │  • WorkIQ integration  │    │
│  │  • Label cleanup   │   │  • State management    │    │
│  │                    │   │  • Emergency fallback   │    │
│  └──────────────────┘   └──────────────────────┘    │
│            ↕ GitHub API / Issues / Labels ↕           │
└─────────────────────────────────────────────────────┘
```

**Phase 1 (Now):** Add hooks + enable Memory. Zero risk, high value.

**Phase 2 (2–4 weeks):** Extract issue triage and board reconciliation into Agentic Workflows. Ralph continues for Teams/email monitoring.

**Phase 3 (1–2 months):** Evaluate full separation. If WorkIQ/Teams MCP can run in Actions, migrate those too.

**Phase 4 (Aspirational):** Ralph on DevBox becomes a thin "health check" process. All substantive work runs in Actions.

---

## Recommendations (Prioritized)

### 🥇 Do Now (P0) — Week 1

1. **Enable GitHub Memory** on both repos
   - Settings → Copilot → Enable Memory
   - Let agents build context over several rounds
   - Review stored memories weekly

2. **Add Copilot Hooks** (`.github/hooks/hooks.json`)
   - `sessionStart`: log agent identity, inject squad context
   - `preToolUse`: block dangerous operations
   - `postToolUse`: auto-format, update squad logs
   - `errorOccurred`: Teams webhook alert

### 🥈 Next Sprint (P1) — Weeks 2–4

3. **Prototype Agentic Workflow** for issue triage
   - Create `.github/agentic-workflows/issue-triage.md`
   - Trigger on `issues.opened` event
   - Agent triages, labels, assigns
   - Compare response time vs. Ralph's 5-min polling

4. **Audit Custom Agent files**
   - Verify `.github/agents/squad.agent.md` format compliance
   - Create per-member agent files for direct invocation
   - Test hooks + agents integration

### 🥉 Plan (P2) — Month 2

5. **Create Research Squad Copilot Space**
   - Add agent charters, routing rules, ceremonies docs
   - Test cross-repo context sharing

6. **Squad MCP Server** concept
   - Expose squad operations (triage, route, status) as MCP tools
   - Reusable across any Copilot-compatible agent

7. **Native Coding Agent** for commodity issues
   - Test assigning simple issues to `@copilot` directly
   - Define criteria for "commodity" vs. "research-grade" issues

### Monitor (P3)

8. **A2A Protocol** — watch for GitHub native support
9. **Project Goldeneye** — massive context windows, persistent session memory
10. **Multi-model optimization** — profile which models work best for which squad tasks

---

## Next Steps

- [ ] Create issues for P0 items in `tamresearch1-research`
- [ ] Set up `.github/hooks/hooks.json` in both repos
- [ ] Enable GitHub Memory in repository settings
- [ ] Prototype one Agentic Workflow (issue triage)
- [ ] Present at next Symposium for squad review
- [ ] Cost analysis: GitHub Actions minutes vs. DevBox for hybrid model

---

*Filed by Geordi, Technology Scanner — Research Squad*  
*"The real question isn't whether Ralph should move to the cloud. It's which parts of Ralph should. The answer: everything that's event-driven."*
