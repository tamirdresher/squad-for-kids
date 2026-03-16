# 🧠 AI Agent Architecture Cheatsheet

**The Squad Pattern: Multi-Agent Orchestration That Actually Ships Code**

> *By Tamir Dresher | tamirdresher.com*

---

## The Squad Architecture at a Glance

```
                        ┌──────────────────────────────────────────┐
                        │           ORCHESTRATION LAYER            │
                        │                                          │
                        │   "Team:" prefix → Picard activates      │
                        │   Picard decomposes → parallel streams   │
                        │   Each agent gets clear ownership        │
                        │                                          │
                        └──────────────┬───────────────────────────┘
                                       │
              ┌────────────────────────┼────────────────────────┐
              │                        │                        │
    ┌─────────▼─────────┐   ┌─────────▼─────────┐   ┌─────────▼─────────┐
    │   SPECIALIST       │   │   SPECIALIST       │   │   SPECIALIST       │
    │   AGENTS           │   │   AGENTS           │   │   AGENTS           │
    │                    │   │                    │   │                    │
    │ Data (Code)        │   │ Worf (Security)    │   │ B'Elanna (Infra)   │
    │ Seven (Research)   │   │ Neelix (News)      │   │ Podcaster (Audio)  │
    └────────┬───────────┘   └────────┬───────────┘   └────────┬───────────┘
             │                        │                        │
    ┌────────▼────────────────────────▼────────────────────────▼───────────┐
    │                        MEMORY LAYER                                  │
    │                                                                      │
    │  Scribe Agent → .squad/decisions.md (institutional memory)          │
    │  Every decision logged with: context, reasoning, outcome            │
    │  All agents READ decisions.md before starting work                  │
    │                                                                      │
    └──────────────────────────────────┬───────────────────────────────────┘
                                       │
    ┌──────────────────────────────────▼───────────────────────────────────┐
    │                        CONTINUOUS LOOP                               │
    │                                                                      │
    │  Ralph Agent → runs every 5 minutes, 24/7                           │
    │  Watches: GitHub Issues, PR status, test results                    │
    │  Actions: Merge passing PRs, open issues, escalate blockers         │
    │  Result: "Work happens while you sleep"                             │
    │                                                                      │
    └─────────────────────────────────────────────────────────────────────┘
```

---

## The 9 Agent Roles

| Agent | Role | Specialty | When It Activates |
|-------|------|-----------|-------------------|
| 🎖️ **Picard** | Lead / Orchestrator | Architecture, task decomposition | "Team:" prefix or complex multi-part tasks |
| 🤖 **Data** | Code Expert | C#, Go, .NET, deep code analysis | Code changes, reviews, test writing |
| 🛡️ **Worf** | Security & Cloud | Auth, secrets, network, compliance | Security reviews, Azure config, FedRAMP |
| 📚 **Seven** | Research & Docs | Analysis, documentation, synthesis | Research tasks, docs, presentations |
| 🔧 **B'Elanna** | Infrastructure | K8s, Helm, CI/CD, ArgoCD | Infra changes, pipeline work, deployments |
| 🎙️ **Podcaster** | Audio Content | TTS, two-voice format | Content summaries, podcast generation |
| 📰 **Neelix** | News & Trends | Ecosystem scanning, trends | Tech news, integration opportunities |
| 🔄 **Ralph** | Queue Monitor | 24/7 watching, PR merging | Always running (every 5 min) |
| 📝 **Scribe** | Memory Keeper | Decision logging, context sharing | Every significant decision |

---

## Key Pattern: Routing

```
                    Incoming Work
                         │
                    ┌────▼────┐
                    │ Router  │
                    └────┬────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
    │ Simple  │    │ Medium  │    │ Complex │
    │ (Auto)  │    │ (Squad) │    │ (Human) │
    └────┬────┘    └────┬────┘    └────┬────┘
         │               │               │
    Bug fixes       Feature work     Architecture
    Dep updates     Multi-file       Security-critical
    Test additions  Refactoring      Design decisions
         │               │               │
    Auto-merge      PR + Review     Human approval
                                    gate required
```

**Routing Rules:**
- 🟢 **Auto:** Bug fixes, dependency updates, test additions → merge on green CI
- 🟡 **Squad:** Features with clear specs, multi-file changes → PR + squad review
- 🔴 **Human:** Architecture, security, design decisions → human approval required

---

## Key Pattern: decisions.md

```markdown
# .squad/decisions.md

## Decision: Use Managed Identity for All Azure Services
- **Date:** 2026-03-01
- **Context:** FedRAMP compliance requires no connection strings in code
- **Decision:** All Azure service connections use Managed Identity exclusively
- **Reasoning:** Eliminates secret rotation, reduces attack surface,
                 satisfies SC-8 and AC-3 controls
- **Outcome:** Deployed to production, passing compliance audit
- **Revisit:** If non-Azure services need integration
```

**Why This Matters:**
1. New team members (human or AI) understand *why*, not just *what*
2. Prevents re-litigating settled decisions
3. Creates audit trail for compliance
4. Knowledge survives personnel changes (the #1 knowledge management problem)

---

## Key Pattern: The Ralph Loop

```
    ┌────────────────────────────────────────┐
    │           RALPH CYCLE (5 min)          │
    │                                        │
    │  1. Check GitHub Issues (new work?)    │
    │     └─ Label: squad:copilot → pick up  │
    │                                        │
    │  2. Check Open PRs (tests passing?)    │
    │     └─ All green → auto-merge          │
    │     └─ Failing → investigate/fix       │
    │                                        │
    │  3. Check Stale Work (blocked?)        │
    │     └─ No activity 24h → escalate      │
    │                                        │
    │  4. Report Status                      │
    │     └─ Update board, notify if needed  │
    │                                        │
    │  5. Sleep 5 minutes                    │
    │     └─ Repeat forever                  │
    └────────────────────────────────────────┘
```

**Result:** 14 PRs merged in 48 hours. Zero manual prompts from human.

---

## Key Pattern: Human-AI Hybrid Teams

```
    ┌─────────────────────────────────────────────┐
    │         HUMANS ARE SQUAD MEMBERS TOO         │
    │                                              │
    │  Brady (Human)  → Architecture approval      │
    │  Tamir (Human)  → AI integration lead        │
    │  Picard (AI)    → Orchestration              │
    │  Data (AI)      → Code implementation        │
    │  Worf (AI)      → Security review            │
    │                                              │
    │  Same routing rules apply to everyone.       │
    │  Humans just have different "tools" (Outlook, │
    │  meetings, executive judgment).               │
    └─────────────────────────────────────────────┘
```

**The Insight:** Don't build AI teams separate from human teams. Make them one team with shared routing, shared decisions.md, and shared accountability.

---

## MCP Server Integration

```
    ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
    │ Squad Health  │     │ Data Query   │     │ Docs         │
    │ MCP Server    │     │ MCP Server   │     │ MCP Server   │
    │               │     │              │     │              │
    │ • triage_issue│     │ • query_data │     │ • search     │
    │ • board_status│     │ • list_tables│     │ • get_article│
    │ • health check│     │ • get_schema │     │ • code_sample│
    └──────┬───────┘     └──────┬───────┘     └──────┬───────┘
           │                    │                    │
           └────────────────────┼────────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │   AI Agent (any)      │
                    │   Auto-discovers all  │
                    │   available tools     │
                    └──────────────────────┘
```

**Each MCP server is a "USB port" for AI capabilities.**

---

## Quick Reference: Model Selection

| Tier | Models | Use For | Cost |
|------|--------|---------|------|
| 🏆 Premium | Opus 4.6 → Opus 4.5 | Architecture, complex reasoning | $$$ |
| ⚡ Standard | Sonnet 4.5 → GPT-5.2 | Day-to-day code, reviews | $$ |
| 🚀 Fast | Haiku 4.5 → GPT-5 mini | Exploration, quick searches | $ |

**Strategy:** Use fast models for exploration, standard for code, premium only for architecture decisions.

---

## Getting Started Checklist

- [ ] Define 3-4 specialist agents with clear, non-overlapping roles
- [ ] Create `.squad/decisions.md` — start logging from day one
- [ ] Set up routing rules (auto / squad review / human approval)
- [ ] Implement Ralph loop for continuous monitoring
- [ ] Register MCP servers for your team's key services
- [ ] Add humans to the squad with their own "tools" and routing
- [ ] Enable fallback chains (if primary model fails, try secondary)

---

## Proven Results

| Metric | Before Squad | With Squad |
|--------|-------------|------------|
| PRs/Day | 2-3 (manual) | 7+ (automated) |
| Security Reviews | Weekly batch | Every PR, real-time |
| Knowledge Loss (turnover) | High | Near-zero (decisions.md) |
| After-Hours Work | None | 24/7 (Ralph) |
| Decision Archaeology | "Ask Steve" | `grep decisions.md` |

---

📧 **Want the full guide?** Subscribe at **tamirdresher.com** for the complete Squad implementation walkthrough, MCP server templates, and enterprise deployment patterns.

*© 2026 Tamir Dresher. Share freely with attribution.*
