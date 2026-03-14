# Squad Framework Evolution — Technology Scan & Contribution Blueprint (v3)

> **Issue:** [tamirdresher_microsoft/tamresearch1#419](https://github.com/tamirdresher_microsoft/tamresearch1/issues/419)  
> **Subject:** Evolving the Squad Framework with New GitHub Copilot Ecosystem Capabilities  
> **Date:** 2026-03-12 (v1) → 2026-03-13 (v2) → 2026-07-23 (v3 — technology scan & contribution blueprint)  
> **Status:** Active Research  
> **Researcher:** Geordi (Technology Scanner) — building on Seven's v2 deep architecture analysis  
> **Methodology:** Comparative technology scan of `bradygaster/squad` v0.8.25 runtime architecture vs. tamresearch1-research squad innovations, with focus on generalizable patterns and concrete contribution paths

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Deep Architecture Analysis — bradygaster/squad](#deep-architecture-analysis)
3. [Our Research Squad — Current State & Innovations](#our-research-squad)
4. [Comparative Gap Analysis](#comparative-gap-analysis)
5. [Copilot Platform Capabilities Inventory](#copilot-platform-capabilities-inventory)
6. [Contribution Proposals (7 PRs)](#contribution-proposals)
7. [Priority Matrix & Recommendations](#priority-matrix--recommendations)
8. [Implementation Roadmap](#implementation-roadmap)
9. [Key Questions & Open Items](#key-questions--open-items)
10. [References](#references)

---

## Executive Summary

This is a **v2 deep-dive** of the Squad framework evolution research, based on source-level analysis of the upstream `bradygaster/squad` repository (v0.8.25) and a side-by-side comparison with our own research squad instance (`tamresearch1-research`).

### Key Findings

The Squad framework is a sophisticated, SDK-first multi-agent runtime built on `@github/copilot-sdk`. Our deep analysis of its `squad.config.ts`, decision log, skill system, plugin marketplace, Scribe memory architecture, and 20+ agent charters reveals both remarkable maturity and specific areas where new Copilot platform capabilities can fill critical gaps.

**Our research squad has innovations not present upstream** — notably the cross-repo communication protocol (Production ↔ Research), research lifecycle management, and extended ceremony model — which represent high-value contribution opportunities.

### Top 7 Contribution Proposals

| # | Proposal | Priority | Effort |
|---|---|---|---|
| 1 | **Hooks Template Library** — Bridge `defineHooks()` to `.github/hooks/hooks.json` | P0 | Medium |
| 2 | **Cross-Repo Coordination Template** — Generalize our Ralph-R protocol | P0 | Medium |
| 3 | **Agentic Workflow Templates** — 5 Squad-native workflow definitions | P1 | Medium |
| 4 | **Spaces Bootstrap Command** — `squad spaces init` from `.squad/` content | P1 | Low |
| 5 | **Memory Adapter** — Bridge Scribe's decisions.md to Copilot Memory | P1 | High |
| 6 | **Extended Ceremony Library** — Generalize our 3 ceremonies + Squad's 2 | P2 | Low |
| 7 | **MCP Server for Squad Operations** — Expose routing/dispatch as MCP tools | P2 | High |

---

## Deep Architecture Analysis

### 2.1 SDK-First Configuration (`squad.config.ts`)

Squad uses a **TypeScript builder-pattern** configuration file that serves as the single source of truth. Analysis of the actual `squad.config.ts`:

```typescript
// Builder-pattern API
import { defineSquad, defineTeam, defineAgent, defineRouting, defineCasting } from '@bradygaster/squad-sdk';

export default defineSquad({
  team: defineTeam({
    name: 'squad-sdk',
    agents: [
      defineAgent({ name: 'flight', role: 'Lead / Architect' }),
      defineAgent({ name: 'control', role: 'TypeScript language expert' }),
      defineAgent({ name: 'retro', role: 'Security & hook governance' }),
      // ... 20 agents total
    ]
  }),
  routing: defineRouting([
    { workType: 'architecture', agents: ['flight'] },
    { workType: 'hooks', agents: ['retro'] },
    { workType: 'testing', agents: ['fido'] },
    // ... 20 routing rules
  ]),
  casting: defineCasting({
    policy: 'movie-universe',
    allowlists: { /* universe-specific persona constraints */ }
  })
});
```

**Key observations:**
- The SDK enforces **type-safe** agent/routing definitions — misconfigurations are caught at compile time
- `defineCasting()` provides persona governance with universe allowlists
- No `defineMemory()`, `defineSpaces()`, or `defineWorkflow()` builders exist yet — **these are the integration points for new capabilities**
- The builder pattern is easily extensible — new `define*()` functions can be added without breaking changes

### 2.2 Agent Architecture (21 Agents + Alumni)

Squad maintains **21 active agents** in `.squad/agents/`, each with a `charter.md` and `history.md`. Key structural analysis:

| Agent | Role | Module Ownership | Unique Capabilities |
|---|---|---|---|
| **Flight** | Lead / Architect | Architecture, proposals | Reviewer-rejection lockout, proposal-first enforcement |
| **CONTROL** | TypeScript Expert | `src/core/`, `src/types/` | Type system governance, no `@ts-ignore` enforcement |
| **RETRO** | Security & Hooks | `src/hooks/` | Hook-based governance, PII guards, write-path enforcement |
| **EECOM** | Core Developer | `src/adapters/`, `src/cli/` | Platform adapter implementation |
| **FIDO** | Quality Assurance | `test/`, `.vitest.config.ts` | Test discipline, assertion standards |
| **PAO** | DevRel / Docs | `docs/`, `README.md` | Doc-impact review on every PR |
| **CAPCOM** | SDK Expert | `packages/squad-sdk/` | Public API surface, builder patterns |
| **Scribe** | Logger / Memory | `.squad/log/`, `decisions.md` | Memory architecture, decision merging |
| **Ralph** | Monitor | `.squad/triage/` | First-run UX monitoring, issue detection |
| **GNC** | Node.js Expert | `src/runtime/` | Node.js built-in usage, zero-dependency enforcement |
| **Network** | Distribution | `packages/`, `npm` | Package publishing, monorepo coordination |
| **INCO** | CLI UX | `src/cli/`, `src/repl/` | Interactive shell, REPL experience |
| **GUIDO** | VS Code | `.vscode/`, extensions | IDE integration |
| **VOX** | REPL | Interactive shell internals | REPL command processing |
| **DSKY** | TUI | Terminal UI | Terminal rendering |
| **Sims** | E2E Testing | `test/e2e/` | Playwright-based end-to-end tests |
| **Handbook** | Usability | Onboarding docs | First-run experience |
| **Telemetry** | Observability | `src/telemetry/` | Metrics, logging |
| **Booster** | CI/CD | `.github/workflows/` | Pipeline maintenance |
| **Surgeon** | Release | `CHANGELOG.md`, versioning | Release process |

**Retired agents** in `_alumni/` — the framework supports universe migrations (it evolved from "The Usual Suspects" to "Apollo 13 / NASA Mission Control"). Scribe and Ralph names persist across universes.

**Charter template** uses placeholder tokens (`{Name}`, `{Role}`, `{Identity}`) and defines 7 sections: Identity, What I Own, How I Work, Boundaries, Model, Collaboration, Voice.

### 2.3 Memory Architecture (Scribe-Managed)

The Scribe agent manages Squad's **most sophisticated subsystem** — a multi-tier memory architecture:

```
.squad/
├── decisions.md           ← SHARED BRAIN (all agents read; Scribe writes)
│                            Foundational Directives + Sprint Directives + Release notes
├── decisions/
│   └── inbox/             ← PARALLEL DROP-BOX (agents drop decisions here)
│                            Scribe merges into decisions.md asynchronously
├── agents/
│   └── {name}/
│       └── history.md     ← PERSONAL MEMORY (per-agent learnings)
├── log/                   ← SESSION ARCHIVE (timestamped session logs)
├── sessions/              ← ACTIVE SESSION TRACKING (2 JSON files observed)
├── orchestration-log.md   ← PER-SPAWN TRACKING (logged before spawning agent)
└── history.md             ← PROJECT CONTEXT TEMPLATE
                             (owner, project, stack, learnings)
```

**Decision categories observed in `decisions.md`:**
- **Foundational Directives** (9 entries): Strict TypeScript, hook-based governance, ESM-only, Apollo 13 casting, proposal-first workflow, tone ceiling, zero-dependency scaffolding, merge=union for append-only files, interactive shell as primary UX
- **Sprint Directives** (6 entries): Secret handling, test assertion discipline, docs-test sync, contributor recognition, API-test sync, doc-impact review
- **Release Decisions**: Per-version notes (v0.8.24 decisions included)

**Key insight:** The `merge=union` strategy in `.gitattributes` for `decisions.md` enables **conflict-free parallel writes** — multiple agents can add decisions simultaneously. This is a clever git-native solution to the concurrent-write problem.

**Gap:** Despite this sophistication, there is **no integration with Copilot's native memory system**. Each new Copilot session starts without the accumulated context in `decisions.md`.

### 2.4 Skills System (11 Skills)

Squad has a formal skill template (`skill.md`) and 11 implemented skills:

| Skill | Domain | Purpose |
|---|---|---|
| `squad-conventions` | project-conventions | Core patterns: zero-dep, error handling, file structure, Windows compat |
| `architectural-proposals` | architecture | Proposal-first workflow patterns |
| `cli-wiring` | cli | CLI command implementation patterns |
| `client-compatibility` | sdk | Client compatibility guarantees |
| `git-workflow` | git | Branch naming, commit conventions |
| `history-hygiene` | documentation | History/log file maintenance |
| `init-mode` | scaffolding | Idempotent initialization patterns |
| `model-selection` | ai-config | Model preference configuration |
| `release-process` | release | Version bumping, changelog, publishing |
| `reviewer-protocol` | governance | Code review gates and lockout rules |
| `secret-handling` | security | Secret prohibition patterns |

**Skill template format:**
```yaml
---
name: "skill-name"
description: "What this skill teaches"
domain: "skill-domain"
confidence: "high|medium|low"
source: "manual|learned"
---
## Context
## Patterns
## Examples
## Anti-Patterns
```

**Key insight from `squad-conventions` skill:** Squad enforces **zero runtime dependencies** as a hard constraint. The CLI is built entirely on Node.js built-ins (`fs`, `path`, `os`, `child_process`). This architectural constraint means new features (hooks templates, memory adapter, etc.) must also be zero-dependency.

### 2.5 Plugin Marketplace

Squad implements a **plugin marketplace** architecture:
- GitHub repos serve as marketplace sources
- Plugins are installed as skills during team member creation
- CLI commands for marketplace management (`squad marketplace add/remove/list`)
- Curated plugin discovery through repository metadata

This is a distribution mechanism for sharing skills, agent templates, and configurations across Squad deployments.

### 2.6 Routing & Orchestration

**Work-type routing table** (20 entries): Maps work types to primary agents with explicit module ownership. Routing principles include:
- **Eager spawning** — route to the most specific agent immediately
- **Scribe always runs** — every spawn triggers Scribe for logging
- **Fan-out on "Team,..."** — multi-agent tasks spawn all relevant agents
- **Anticipate downstream** — proactively spawn agents that will need results
- **Doc-impact check** — PAO reviews every PR for documentation impact

**Module ownership table** maps `src/` directories to primary and secondary agents, creating clear accountability.

### 2.7 MCP Configuration

Squad documents MCP integration with a priority-based config resolution:
1. Repo-level: `.copilot/mcp-config.json` (highest priority)
2. Workspace: `.vscode/mcp.json`
3. User-level: `~/.copilot/mcp-config.json`
4. CLI override (lowest priority)

Current `.copilot/mcp-config.json` contains only an example Trello MCP server entry — **no Squad-specific MCP tools are exposed**.

### 2.8 Ceremonies

Squad defines **2 ceremonies**:
1. **Design Review** — Before multi-agent tasks; ensures alignment
2. **Retrospective** — After build/test failure or reviewer rejection; learns from failures

### 2.9 @copilot Coding Agent Integration

Squad's `copilot-instructions.md` provides detailed Coding Agent guidance:
- Read `team.md` and `routing.md` on every session start
- Check capability profile (🟢 Full autonomy / 🟡 Partial / 🔴 Not recommended)
- Use `squad/{issue-number}-{slug}` branch naming
- PR description template with context and testing sections
- Decision writing protocol for significant choices

---

## Our Research Squad — Current State & Innovations

### 3.1 Overview

Our research squad (`tamresearch1-research`) is a **specialized Squad deployment** focused on continuous innovation and technology scanning.

| Attribute | Value |
|---|---|
| **Universe** | Star Trek TNG + Voyager |
| **Agents** | 6 (vs Squad's 21) |
| **Focus** | Research, not product development |
| **Issue Source** | `tamirdresher_microsoft/tamresearch1` (production repo) |
| **Output Directory** | `research/active/`, `research/failed/` |
| **Human Member** | Tamir Dresher (Project Owner, Decision Maker) |

### 3.2 Agent Roster

| Agent | Role | Upstream Equivalent |
|---|---|---|
| **Guinan** | Research Lead & Cross-Squad Liaison | Flight (Lead) — but with research focus + cross-repo liaison |
| **Geordi** | Technology Scanner | No equivalent — unique research capability |
| **Troi** | Methodology Analyst | No equivalent — process/methodology evaluation |
| **Brahms** | Architecture Researcher | Partial overlap with Flight (architecture) |
| **Scribe-R** | Research Scribe | Scribe (Logger / Memory) — research-specialized variant |
| **Ralph-R** | Research Ralph | Ralph (Monitor) — with cross-repo mirroring protocol |

### 3.3 Innovations Not Present Upstream

#### 🔵 Cross-Repo Communication Protocol

Our `routing.md` defines a sophisticated **Production ↔ Research** protocol:

```
Production → Research:
  1. Create issue with `research:request` label in production repo
  2. Ralph-R mirrors issue to research repo
  3. Guinan prioritizes and assigns researcher
  4. Research proceeds in research repo
  5. Results presented at Symposium

Research → Production:
  1. Research completes with recommendation
  2. Symposium presentation to production squad
  3. Production decides: Adopt | Archive
  4. If adopted: production squad creates implementation plan
```

**This protocol is absent from upstream Squad** — it solves the multi-repo, multi-team coordination problem that SubSquads addresses architecturally but doesn't operationalize.

#### 🔵 Research Lifecycle Management

```
Backlog → Active → {Completed | Failed} → Symposium → {Adopt | Archive}
```

The lifecycle includes **explicit "Failed" state** — acknowledging that failed research is valuable data. This is captured in our `Failed Research Review` ceremony.

#### 🔵 Extended Ceremony Model (3 vs 2)

| Ceremony | Purpose | Upstream Equivalent |
|---|---|---|
| **Symposium** | Bi-weekly research presentation to production | None |
| **Backlog Review** | Weekly prioritization of research queue | None |
| **Failed Research Review** | Learn from failed investigations | Partial — Retrospective covers failures but not research-specific |

#### 🔵 Label-Based Routing

Our routing uses a label taxonomy (`squad:assign:*`, `research:request`, `research:active`, `research:completed`, `research:failed`) that enables **GitHub-native** workflow automation — issues move through states via label changes rather than requiring SDK runtime.

#### 🔵 Daemon/Watcher Pattern

`ralph-watch.ps1` at the repo root implements a **continuous monitoring daemon** — Ralph-R runs as a persistent process watching for new issues. This watcher pattern has no upstream equivalent.

### 3.4 Gaps in Our Squad (Relative to Upstream)

| Capability | Our Status | Upstream Status |
|---|---|---|
| Skills system | ❌ None | ✅ 11 skills with formal template |
| Plugin marketplace | ❌ None | ✅ Full marketplace architecture |
| SDK-first config | ❌ Markdown-only | ✅ TypeScript `squad.config.ts` |
| Decisions log | ❌ Empty template | ✅ Rich with 15+ directives |
| Agent history | ❌ Empty templates | ✅ Active with learnings |
| Multi-agent format | ❌ Not defined | ✅ Structured artifact format |
| Orchestration logging | ❌ Not defined | ✅ Per-spawn log template |
| @copilot integration | ❌ `copilot-auto-assign: false` | ✅ Full Coding Agent guidance |

---

## Comparative Gap Analysis

### 4.1 Dimension-by-Dimension Comparison

| Dimension | Squad (Upstream) | Our Research Squad | Gap Owner | Integration Direction |
|---|---|---|---|---|
| **Hooks** | `defineHooks()` — SDK-level governance. RETRO owns `src/hooks/`. "Hooks are code, not prompts." | No hooks system | Upstream | Create `.github/hooks/hooks.json` templates that bridge to `defineHooks()` |
| **Memory** | Scribe-managed: `decisions.md` (shared brain), `inbox/` (parallel drops), `history.md` (personal), `log/` (archive), `merge=union` for conflict-free writes | Basic structure, no decisions recorded | Upstream | Bridge Scribe's memory architecture to Copilot's native `store_memory` |
| **Spaces** | `.squad/` with 20+ files of rich knowledge | `.squad/` with 6 agents + research docs | Both | `squad spaces init` to bootstrap Space from `.squad/` content |
| **Agentic Workflows** | Multi-agent orchestration via SDK; ceremonies, routing | Label-based routing, research lifecycle | Both | Export Squad patterns as Markdown workflow templates for `gh aw` |
| **MCP** | MCP config docs + example Trello config. Squad ops NOT exposed as MCP tools. | No MCP config | Upstream | Expose Squad routing/dispatch as MCP server |
| **Skills** | 11 skills with YAML template (Context/Patterns/Examples/Anti-Patterns) | No skills | Upstream | Adopt skill template; create research-specific skills |
| **Ceremonies** | 2 (Design Review, Retrospective) | 3 (Symposium, Backlog Review, Failed Research Review) | Our innovation → Upstream | Generalize our 3 ceremonies as reusable ceremony templates |
| **Cross-Repo** | SubSquads (architectural) but no operational protocol | Full Production ↔ Research protocol with Ralph-R mirroring | Our innovation → Upstream | Contribute as cross-repo coordination template |
| **Agent Templates** | 20+ agents with charter template (`{Name}`, `{Role}`, `{Identity}` placeholders) | 6 research-specialized agents | Upstream model is richer | Publish agent archetype templates users can customize |
| **Plugin Marketplace** | Full marketplace: GitHub repos as sources, CLI management | No marketplace | Upstream | Contribute research-focused plugins (tech-scanner, methodology-evaluator) |

### 4.2 Key Insights

1. **Defense-in-depth is the natural integration pattern for Hooks**: Squad's `defineHooks()` operates at the SDK/agent level; Copilot's `.github/hooks/hooks.json` operates at the platform/session level. Together they create layered governance.

2. **Scribe's memory architecture is the bridge point for Copilot Memory**: The `decisions.md` → `inbox/` → `merge=union` pattern already solves concurrent writes. Adding a `store_memory` sync layer would give agents persistent cross-session recall without changing the existing architecture.

3. **Our cross-repo protocol fills a real gap**: Squad's SubSquad architecture is designed for distributed coordination, but lacks an operational protocol for how repositories actually communicate. Our Ralph-R mirroring + Symposium presentation + Adopt/Archive lifecycle is a concrete implementation.

4. **Label-based routing enables GitHub-native automation**: Our label taxonomy (`squad:*`, `research:*`) allows routing to work through GitHub's issue/PR infrastructure without requiring the SDK runtime — complementary to Squad's SDK routing.

5. **The "Failed Research" concept is absent upstream**: Squad's Retrospective ceremony handles failures, but only in the context of build/test failures. Our explicit `research:failed` state and Failed Research Review ceremony recognizes that negative results are valuable data.

---

## Copilot Platform Capabilities Inventory

### 5.1 Copilot Hooks

**What:** Shell-based lifecycle hooks triggered at specific points during Copilot interactions, configured via `.github/hooks/hooks.json`.

| Event | Trigger Point | Squad Integration Opportunity |
|---|---|---|
| `sessionStart` | Copilot session begins | Load `.squad/decisions.md` into context; initialize agent routing |
| `sessionEnd` | Copilot session ends | Flush agent learnings to `history.md`; update `orchestration-log.md` |
| `userPromptSubmitted` | After user sends prompt | Route to appropriate agent via Squad's routing table |
| `preToolUse` | Before tool execution | Apply `defineHooks()` governance rules (write-path enforcement, PII guards) |
| `postToolUse` | After tool completes | Log tool usage to Scribe; trigger downstream agent spawning |
| `errorOccurred` | Error during processing | Trigger Retrospective ceremony; update `decisions.md` if systematic failure |

### 5.2 Copilot Memory

**What:** Repository-scoped persistent context (28-day TTL) that survives across sessions.

**Integration with Scribe's memory architecture:**
- `decisions.md` entries (Foundational Directives) → Stored as high-priority memory items with TTL refresh
- Per-agent `history.md` → Stored as agent-scoped memory for cross-session continuity
- `sessions/*.json` → Used to restore session context on `sessionStart` hook
- New decisions from `inbox/` → Automatically committed to memory after Scribe merges

### 5.3 Copilot Spaces

**What:** Collaborative context workspaces that curate project knowledge for Copilot.

**Natural mapping from `.squad/` to Space content:**
| `.squad/` Source | Space Section | Purpose |
|---|---|---|
| `charter.md` | "Team Charter" | Squad identity and governance rules |
| `decisions.md` | "Decision Log" | Accumulated team knowledge |
| `agents/*/charter.md` | "Agent Directory" | Agent capabilities and boundaries |
| `routing.md` | "Work Routing" | How tasks are assigned |
| `ceremonies.md` | "Ceremonies" | Team rituals and processes |
| `skills/*/SKILL.md` | "Skills Library" | Reusable patterns and anti-patterns |

### 5.4 Agentic Workflows

**What:** Markdown-authored autonomous workflows compiled to GitHub Actions via `gh aw`.

**Squad patterns that map naturally to Agentic Workflows:**
| Squad Pattern | Workflow Template | Trigger |
|---|---|---|
| Ralph's issue monitoring | `issue-triage.md` | `issues.opened` |
| Scribe's decision merging | `decision-merge.md` | `push` to `decisions/inbox/` |
| PAO's doc-impact review | `doc-reconciliation.md` | `pull_request.opened` |
| Booster's CI management | `ci-failure-response.md` | `workflow_run.completed` (failure) |
| Geordi's tech scanning | `tech-news-scan.md` | `schedule` (weekly) |

---

## Contribution Proposals

### PR 1: Hooks Template Library

**Branch:** `hooks-templates`  
**Target:** `bradygaster/dev`  
**Priority:** P0  
**Estimated Effort:** 2 weeks

**Description:** Bridge Squad's `defineHooks()` governance to Copilot's platform-level `.github/hooks/hooks.json`, creating defense-in-depth policy enforcement.

**Deliverables:**
```
templates/hooks/
├── governance.hooks.json      # Write-path enforcement, blocked commands, PII guards
├── session-lifecycle.hooks.json # Session start/end with Squad context loading
├── tool-safety.hooks.json     # Pre/post tool-use validation
├── audit-trail.hooks.json     # Comprehensive activity logging
└── scripts/
    ├── session-start.sh       # Load decisions.md, initialize routing
    ├── session-end.sh         # Flush learnings, update orchestration-log
    ├── pre-tool-use.sh        # Apply defineHooks() governance rules
    ├── post-tool-use.sh       # Log to Scribe, trigger downstream
    └── error-handler.sh       # Trigger retrospective on systematic failure

packages/squad-cli/src/commands/
└── hooks-init.ts              # CLI: `squad hooks init [template]`

docs/guides/
└── hooks-integration.md       # Defense-in-depth pattern documentation
```

**Why this matters:** Squad's foundational directive states "hooks are code — they execute deterministically." Platform hooks extend this philosophy to the Copilot session level, creating two independent enforcement layers. Neither layer can be bypassed by prompt manipulation.

**Constraint:** Must be zero-dependency (per `squad-conventions` skill). Shell scripts use only POSIX/PowerShell built-ins.

### PR 2: Cross-Repo Coordination Template

**Branch:** `cross-repo-coordination`  
**Target:** `bradygaster/dev`  
**Priority:** P0  
**Estimated Effort:** 2 weeks

**Description:** Generalize our research squad's Production ↔ Research protocol into a reusable cross-repo coordination template that any SubSquad deployment can adopt.

**Deliverables:**
```
templates/cross-repo/
├── README.md                  # Cross-repo coordination guide
├── ralph-mirror.js            # Issue mirroring script (generalized from Ralph-R)
├── label-taxonomy.md          # Standard label scheme for cross-repo routing
├── lifecycle.md               # State machine: Backlog → Active → Complete/Failed → Review → Adopt/Archive
└── ceremonies/
    ├── symposium.md           # Research presentation ceremony template
    └── failed-review.md       # Failed research review ceremony template

.squad-templates/workflows/
└── cross-repo-sync.yml        # GitHub Actions workflow for issue mirroring

packages/squad-sdk/src/cross-repo/
├── index.ts                   # Cross-repo coordination types
├── mirror.ts                  # Issue mirroring logic
└── lifecycle.ts               # State machine implementation
```

**Why this matters:** Squad's SubSquad architecture supports distributed teams, but lacks an operational protocol for cross-repo communication. Our research squad has a **battle-tested protocol** that solves: issue mirroring, research lifecycle management, symposium-based knowledge transfer, and explicit failure tracking.

**Innovation from our squad:** The "Failed Research" state is particularly valuable — it captures negative results as organizational knowledge rather than silently discarding them.

### PR 3: Agentic Workflow Templates

**Branch:** `agentic-workflows`  
**Target:** `bradygaster/dev`  
**Priority:** P1  
**Estimated Effort:** 2 weeks

**Description:** Ship 5 ready-to-use Markdown workflow definitions for common Squad automation patterns that compile to GitHub Actions via `gh aw`.

**Deliverables:**
```
templates/workflows/agentic/
├── issue-triage.md            # Ralph-style automated issue categorization
│   Trigger: issues.opened
│   Tools: github, squad-routing
│   Actions: Label, assign agent, create triage note
│
├── doc-reconciliation.md      # PAO-style documentation freshness check
│   Trigger: pull_request.opened
│   Tools: github, file-search
│   Actions: Scan changed files, check doc-impact, create update PR
│
├── tech-news-scan.md          # Geordi-style technology scanning
│   Trigger: schedule (weekly)
│   Tools: web-search, github
│   Actions: Scan sources, summarize trends, create issue with findings
│
├── decision-merge.md          # Scribe-style decision inbox processing
│   Trigger: push (to .squad/decisions/inbox/)
│   Tools: github, file-edit
│   Actions: Read inbox drops, merge into decisions.md, archive originals
│
└── ci-failure-response.md     # Booster-style CI failure triage
    Trigger: workflow_run.completed (failure)
    Tools: github, squad-routing
    Actions: Analyze failure logs, identify owner agent, create fix issue

packages/squad-cli/src/commands/
└── workflow-init.ts           # CLI: `squad workflows init [template]`

docs/guides/
└── agentic-workflows.md       # Authoring, customizing, and deploying guide
```

**Why this matters:** Agentic Workflows are the "Continuous AI" layer. By shipping Squad-aware templates, users get autonomous agents that respect Squad's routing and governance from day one — without writing Actions YAML by hand.

### PR 4: Spaces Bootstrap Command

**Branch:** `spaces-bootstrap`  
**Target:** `bradygaster/dev`  
**Priority:** P1  
**Estimated Effort:** 1 week

**Description:** Add `squad spaces init` CLI command that auto-creates a Copilot Space pre-populated with Squad's `.squad/` knowledge.

**Deliverables:**
```
packages/squad-cli/src/commands/
└── spaces-init.ts             # CLI: `squad spaces init`
    - Reads .squad/ directory structure
    - Generates Space content manifest
    - Maps charter → Space overview
    - Maps decisions → Space knowledge base
    - Maps agents → Space directory
    - Maps routing → Space instructions
    - Outputs: space-manifest.json (for API) or instructions for manual creation

packages/squad-sdk/src/spaces/
├── index.ts                   # Space content mapper
├── manifest.ts                # Space manifest generator
└── sync.ts                    # Incremental sync logic

docs/guides/
└── spaces-integration.md      # Setup, usage, and sync workflow
```

**Content mapping strategy:**
```
.squad/charter.md           → Space: "📋 Team Charter" section
.squad/decisions.md         → Space: "🧠 Decision Log" section
.squad/agents/*/charter.md  → Space: "👥 Agent Directory" section
.squad/routing.md           → Space: "🔀 Work Routing" section
.squad/ceremonies.md        → Space: "🎭 Ceremonies" section
.squad/skills/*/SKILL.md    → Space: "📚 Skills Library" section
.squad/copilot-instructions → Space: Custom Instructions
```

### PR 5: Memory Adapter

**Branch:** `memory-adapter`  
**Target:** `bradygaster/dev`  
**Priority:** P1  
**Estimated Effort:** 3 weeks

**Description:** Bridge Scribe's multi-tier memory architecture to Copilot's native `store_memory` system, enabling cross-session agent recall without changing existing file-based patterns.

**Deliverables:**
```
packages/squad-sdk/src/memory/
├── index.ts                   # Memory adapter interface
├── decision-sync.ts           # Sync decisions.md → Copilot memory
│   - Parse Foundational Directives → high-priority memories (auto-refresh before 28-day TTL)
│   - Parse Sprint Directives → medium-priority memories
│   - Parse Release Decisions → low-priority memories (expire naturally)
├── agent-memory.ts            # Per-agent memory profiles
│   - Read agents/*/history.md → agent-scoped memories
│   - Cross-session learnings for each agent persona
├── session-restore.ts         # Session context restoration
│   - On sessionStart: load relevant memories into Copilot context
│   - Prioritize: Foundational > Sprint > Agent-specific > Historical
└── ttl-manager.ts             # TTL refresh logic for long-lived decisions

packages/squad-sdk/src/hooks/
└── memory-hooks.ts            # Hook integration
    - sessionStart: restore memory context
    - sessionEnd: flush new learnings to memory
    - postToolUse: capture tool-specific learnings

docs/guides/
└── memory-integration.md      # Architecture, configuration, TTL strategy
```

**Key design decisions:**
1. **File-first, memory-second:** `.squad/decisions.md` remains the source of truth. Copilot memory serves as a **cache** that accelerates session startup. If memory expires, agents gracefully fall back to reading files.
2. **TTL refresh for Foundational Directives:** The 28-day TTL means critical decisions would expire. The adapter implements auto-refresh: read `decisions.md`, re-store Foundational Directives before expiry.
3. **Agent-scoped memory:** Each agent gets its own memory namespace. Scribe's learnings don't pollute RETRO's context. This mirrors the `agents/*/history.md` file structure.

### PR 6: Extended Ceremony Library

**Branch:** `extended-ceremonies`  
**Target:** `bradygaster/dev`  
**Priority:** P2  
**Estimated Effort:** 1 week

**Description:** Generalize our research squad's 3 ceremonies + Squad's existing 2 into a reusable ceremony library that any Squad deployment can customize.

**Deliverables:**
```
templates/ceremonies/
├── design-review.md           # Existing: Before multi-agent tasks
├── retrospective.md           # Existing: After failures
├── symposium.md               # NEW: Periodic knowledge sharing across teams/repos
├── backlog-review.md          # NEW: Prioritized queue review and assignment
├── failed-research-review.md  # NEW: Learning from negative results
├── onboarding.md              # NEW: New agent/team member orientation
├── release-readiness.md       # NEW: Pre-release checklist ceremony
└── README.md                  # Ceremony catalog with customization guide

packages/squad-sdk/src/ceremonies/
├── index.ts                   # Ceremony types and scheduling
└── runner.ts                  # Ceremony execution framework
```

**Why this matters:** Ceremonies are Squad's **process governance layer** — they ensure teams follow consistent practices. By expanding from 2 to 7+ ceremony templates, Squad becomes a more complete team-management framework.

### PR 7: MCP Server for Squad Operations

**Branch:** `squad-mcp-server`  
**Target:** `bradygaster/dev`  
**Priority:** P2  
**Estimated Effort:** 3 weeks

**Description:** Expose Squad's core orchestration as an MCP server, making routing, agent dispatch, and governance discoverable as standard MCP tools.

**Deliverables:**
```
packages/squad-mcp-server/
├── package.json               # New monorepo package
├── src/
│   ├── server.ts              # MCP server implementation
│   ├── tools/
│   │   ├── route.ts           # squad.route — Route work to appropriate agent
│   │   ├── dispatch.ts        # squad.dispatch — Spawn agent with task
│   │   ├── query-agent.ts     # squad.query-agent — Get agent capabilities/charter
│   │   ├── list-agents.ts     # squad.list-agents — List available agents
│   │   ├── governance-check.ts # squad.governance-check — Validate action against hooks
│   │   ├── read-decisions.ts  # squad.read-decisions — Query decisions.md
│   │   └── log-decision.ts    # squad.log-decision — Add to decisions/inbox/
│   └── index.ts               # Tool registration
├── test/
│   └── *.test.ts              # Tool tests
└── README.md                  # MCP server documentation

.copilot/mcp-config.json       # Updated with Squad MCP server entry
docs/guides/mcp-server.md      # Integration guide
```

**MCP Tool Definitions:**
| Tool | Description | Parameters |
|---|---|---|
| `squad.route` | Route a work item to the appropriate agent based on routing rules | `workType`, `description` |
| `squad.dispatch` | Spawn an agent with a specific task | `agent`, `task`, `context` |
| `squad.query-agent` | Get agent charter, skills, and capabilities | `agent` |
| `squad.list-agents` | List all available agents with roles | (none) |
| `squad.governance-check` | Validate an action against hook governance rules | `action`, `path`, `content` |
| `squad.read-decisions` | Query decisions log by category | `category`, `search` |
| `squad.log-decision` | Drop a new decision into inbox for Scribe merging | `decision`, `category`, `rationale` |

**Why this matters:** Making Squad a first-class MCP server means **any AI tool** (not just Copilot) can discover and use Squad's orchestration. This positions Squad as the "Kubernetes of AI agent teams" — an orchestration layer that any client can consume.

---

## Priority Matrix & Recommendations

### Decision Framework

Proposals are prioritized using three dimensions:
1. **Impact** — How much value does this add to Squad's ecosystem?
2. **Feasibility** — How easily can this be implemented given Squad's constraints (zero-dep, strict TypeScript)?
3. **Alignment** — How well does this match Squad's foundational directives?

### Priority Matrix

```
                  High Impact
                      │
         PR2          │         PR1
    Cross-Repo ●      │      ● Hooks Templates
                      │
         PR5          │         PR3
    Memory ●          │      ● Agentic Workflows
                      │
  ───────────────────────────────────────
                      │         PR4
         PR7          │      ● Spaces Bootstrap
    MCP Server ●      │
                      │         PR6
                      │      ● Extended Ceremonies
                      │
                  Low Impact
    High Complexity ◄──────────► Low Complexity
```

### Recommended Execution Order

| Phase | PRs | Weeks | Rationale |
|---|---|---|---|
| **Phase 1** | PR 1 (Hooks) + PR 2 (Cross-Repo) | 1–4 | Core infrastructure + our unique innovation |
| **Phase 2** | PR 3 (Workflows) + PR 4 (Spaces) | 5–7 | User-visible features with moderate complexity |
| **Phase 3** | PR 5 (Memory) + PR 6 (Ceremonies) | 8–11 | Deep integration + process governance |
| **Phase 4** | PR 7 (MCP Server) | 12–14 | Strategic positioning — most complex, highest long-term value |

### Contribution Workflow (per Squad's `CONTRIBUTING.md`)

Each PR should follow Squad's proposal-first process:
1. Create `docs/proposals/{feature-name}.md` with the proposal
2. Submit proposal PR for Flight (Lead) review
3. After approval, implement the feature
4. Target `bradygaster/dev` branch
5. Include changeset for versioning
6. PAO reviews for doc-impact

---

## Implementation Roadmap

```
Week 1-2: Foundation & Proposals
├── Fork bradygaster/squad
├── Set up dev environment (Node ≥20, pnpm, TypeScript strict)
├── Study existing hooks architecture (packages/squad-sdk/src/hooks/)
├── Write 7 proposal documents in docs/proposals/
├── Submit proposals for Flight review
└── Begin PR 1 implementation while proposals are reviewed

Week 3-4: PR 1 — Hooks Template Library
├── Implement hook template JSON definitions
├── Build CLI command: squad hooks init [template]
├── Write shell scripts (bash + PowerShell for Windows compat)
├── Add Vitest tests for template generation
├── Write docs/guides/hooks-integration.md
└── Submit PR → bradygaster/dev

Week 4-5: PR 2 — Cross-Repo Coordination
├── Generalize Ralph-R mirroring logic from our squad
├── Create label taxonomy specification
├── Implement lifecycle state machine
├── Write ceremony templates (symposium, failed-review)
├── Add tests for mirroring and lifecycle transitions
└── Submit PR → bradygaster/dev

Week 5-6: PR 3 — Agentic Workflow Templates
├── Author 5 Markdown workflow templates with YAML frontmatter
├── Validate with gh aw compilation (if available)
├── Build CLI: squad workflows init [template]
├── Test Markdown structure and frontmatter schema
└── Submit PR → bradygaster/dev

Week 7: PR 4 — Spaces Bootstrap
├── Implement .squad/ → Space content mapper
├── Build CLI: squad spaces init
├── Generate space-manifest.json
├── Test content mapping
└── Submit PR → bradygaster/dev

Week 8-10: PR 5 — Memory Adapter
├── Design memory adapter interface
├── Implement decision-sync with TTL refresh
├── Build agent-scoped memory profiles
├── Implement session restore logic
├── Add memory hooks (sessionStart/End)
├── Integration tests
└── Submit PR → bradygaster/dev

Week 10-11: PR 6 — Extended Ceremonies
├── Generalize our 3 ceremony templates
├── Create ceremony catalog with customization guide
├── Implement ceremony runner framework
├── Tests
└── Submit PR → bradygaster/dev

Week 12-14: PR 7 — MCP Server
├── Create packages/squad-mcp-server
├── Implement 7 MCP tool definitions
├── Build MCP server with tool registration
├── Integration testing with MCP clients
├── Update .copilot/mcp-config.json
├── Documentation
└── Submit PR → bradygaster/dev
```

---

## Key Questions & Open Items

### Technical Questions

1. **Copilot Hooks API Stability:** The hooks system is relatively new. What is the stability guarantee for the `hooks.json` schema and supported events? Templates should be designed for forward compatibility — using a versioned schema that can adapt to event additions.

2. **Memory API Surface & TTL Strategy:** Copilot's repo-scoped memory has a 28-day TTL. Squad's Foundational Directives are permanent. The memory adapter must implement **TTL refresh** — periodically re-storing critical decisions before they expire. Should this be a hook-triggered refresh or a scheduled job?

3. **Spaces API for Programmatic Creation:** Does the Copilot Spaces API support programmatic content management? If not, `squad spaces init` should generate a Space blueprint (manifest file) for manual creation, with a migration path to API-driven creation when available.

4. **Agentic Workflows Preview Status:** Agentic Workflows are in technical preview. Templates should include **fallback YAML definitions** for users without `gh aw` access. The Markdown templates serve as the primary format; YAML equivalents are generated as a compatibility layer.

5. **Zero-Dependency Constraint for MCP Server:** Squad's `squad-conventions` skill mandates zero runtime dependencies. The MCP server may need an exception since MCP protocol implementation typically requires `@modelcontextprotocol/sdk`. Should this be a **separate package** outside the zero-dep constraint, or should a pure Node.js built-in implementation be pursued?

### Process Questions

6. **Cross-Repo Template Generality:** Our Production ↔ Research protocol is specific to a two-repo setup. How should it be generalized for N-repo configurations? The template should support 1:1, 1:N, and N:N repo relationships.

7. **Contribution Sequencing:** Should all 7 PRs be submitted simultaneously (independent feature branches), or sequentially? Squad's proposal-first process suggests sequential submission for proper review bandwidth. Recommended: submit proposals for all 7, then implement in priority order.

8. **Universe Compatibility:** Our ceremony templates use Star Trek terminology (Symposium). The upstream Squad uses Apollo 13 / NASA Mission Control. Templates should use **universe-neutral** naming with customization hooks for persona-specific language.

---

## References

### Squad Framework — Primary Sources (Analyzed)
- [bradygaster/squad](https://github.com/bradygaster/squad) — Source repository (v0.8.25)
- [`squad.config.ts`](https://github.com/bradygaster/squad/blob/main/squad.config.ts) — SDK-first configuration (20 agents, routing, casting)
- [`.squad/decisions.md`](https://github.com/bradygaster/squad/blob/main/.squad/decisions.md) — 15+ directives (Foundational + Sprint + Release)
- [`.squad/team.md`](https://github.com/bradygaster/squad/blob/main/.squad/team.md) — Apollo 13 roster, @copilot Coding Agent profile
- [`.squad/routing.md`](https://github.com/bradygaster/squad/blob/main/.squad/routing.md) — Work-type routing (20 rules), module ownership
- [`.squad/scribe-charter.md`](https://github.com/bradygaster/squad/blob/main/.squad/scribe-charter.md) — Memory architecture details
- [`.squad/mcp-config.md`](https://github.com/bradygaster/squad/blob/main/.squad/mcp-config.md) — MCP integration documentation
- [`.squad/plugin-marketplace.md`](https://github.com/bradygaster/squad/blob/main/.squad/plugin-marketplace.md) — Plugin system architecture
- [`.squad/skills/squad-conventions/SKILL.md`](https://github.com/bradygaster/squad/blob/main/.squad/skills/squad-conventions/SKILL.md) — Zero-dependency constraint, error handling, Windows compatibility

### Our Research Squad — Sources
- [tamresearch1-research `.squad/team.md`](https://github.com/tamirdresher_microsoft/tamresearch1-research/blob/main/.squad/team.md) — Star Trek universe, 6 agents
- [tamresearch1-research `.squad/routing.md`](https://github.com/tamirdresher_microsoft/tamresearch1-research/blob/main/.squad/routing.md) — Cross-repo protocol, label routing
- [tamresearch1-research `.squad/ceremonies.md`](https://github.com/tamirdresher_microsoft/tamresearch1-research/blob/main/.squad/ceremonies.md) — 3 research ceremonies

### GitHub Copilot Platform Capabilities
- [Copilot Hooks](https://docs.github.com/en/copilot/customizing-copilot/extending-copilot-chat-in-your-ide) — `.github/hooks/hooks.json` lifecycle events
- [Copilot Memory](https://docs.github.com/en/copilot/using-github-copilot/copilot-memory) — Repo-scoped persistent context
- [Copilot Spaces](https://docs.github.com/en/copilot/how-tos/provide-context/use-copilot-spaces/use-copilot-spaces) — Collaborative context workspaces
- [Agentic Workflows](https://github.blog/ai-and-ml/automate-repository-tasks-with-github-agentic-workflows/) — Markdown → GitHub Actions compilation
- [MCP Specification](https://modelcontextprotocol.io/) — Model Context Protocol standard

### Issue
- [tamirdresher_microsoft/tamresearch1#419](https://github.com/tamirdresher_microsoft/tamresearch1/issues/419) — Original research request

---

## V3 Addendum: Technology Scan & Contribution Blueprint

> **Added:** 2026-07-23  
> **By:** Geordi (Technology Scanner)  
> **Purpose:** Fresh comparative scan of upstream vs. our implementation, with actionable contribution blueprint

---

### A. Executive Summary (v3 Update)

Seven's v2 analysis (March 2026) provided excellent architectural depth. This v3 addendum adds a **technology scanner's perspective** — focusing on what's *actionable now*, what's *generalizable*, and what the concrete PR sequence should look like.

**Key v3 findings:**

1. **bradygaster/squad is a full runtime** — TypeScript monorepo (SDK + CLI), `@github/copilot-sdk` based, 20+ agents, 11 skills, 4 casting universes, OpenTelemetry observability. It's far more than a template repo.
2. **Our innovations are complementary, not competing** — We operate at the *configuration layer* (cross-repo protocols, research ceremonies, autonomy directives) while upstream operates at the *runtime layer* (streaming, adapters, event bus).
3. **The contribution surface is the `.squad-templates/` directory** — This is where upstream exports reusable patterns. Our best path is enriching these templates with our battle-tested patterns.
4. **Three immediately actionable PRs** identified (no SDK changes required).

### B. Upstream Architecture Snapshot

| Dimension | bradygaster/squad v0.8.25 |
|-----------|--------------------------|
| **Type** | TypeScript monorepo (SDK + CLI) |
| **Runtime** | `@github/copilot-sdk`, `vscode-jsonrpc`, async iterators |
| **Agents** | 20 (NASA Mission Control theme: Flight, EECOM, CAPCOM, etc.) |
| **Skills** | 11 defined (architectural-proposals, git-workflow, release-process, etc.) |
| **Casting** | 4 universes (Usual Suspects, Breaking Bad, The Wire, Firefly) |
| **Config** | `squad.config.ts` — TypeScript builder pattern (`defineSquad`, `defineAgent`, etc.) |
| **Templates** | `.squad-templates/` — exported for `squad init` scaffolding |
| **Observability** | OpenTelemetry, OTLP gRPC, Aspire dashboards |
| **Distribution** | `@bradygaster/squad-sdk` + `@bradygaster/squad-cli` on npm |
| **Decision History** | `.squad/decisions-archive.md` (235KB+ of recorded decisions) |

### C. Our Research Squad Snapshot

| Dimension | tamresearch1-research |
|-----------|----------------------|
| **Type** | Configuration-only squad (no custom runtime) |
| **Agents** | 6 (Star Trek TNG+Voyager: Guinan, Geordi, Troi, Brahms, Scribe-R, Ralph-R) |
| **Theme** | Research-specific: backlog → active → completed/failed → symposium → adopt/archive |
| **Model Tiering** | claude-sonnet-4 (leads) + claude-haiku-4 (support agents) |
| **Cross-Repo** | Production ↔ Research protocol via Ralph-R mirror issues |
| **Ceremonies** | 3: Symposium (bi-weekly), Backlog Review (weekly), Failed Research Review (ad-hoc) |
| **Autonomy** | Full autonomy directive — no human blocking, self-triage, self-merge |
| **Casting** | JSON policy with label-based routing rules |
| **Identity** | `.squad/identity/now.md` — current focus/status dashboard |

### D. Gap Analysis: What We Have That Upstream Doesn't

#### D.1 Patterns Ready to Contribute (Generalizable)

| Pattern | Our Implementation | Upstream Gap | Generalization Path |
|---------|-------------------|--------------|---------------------|
| **Cross-Repo Protocol** | Ralph-R mirrors issues between production/research repos using labels | No multi-repo coordination templates | Abstract to `cross-repo-protocol.md` template — any squad with >1 repo needs this |
| **Research Lifecycle** | `Backlog → Active → {Completed\|Failed} → Symposium → {Adopt\|Archive}` | Linear work routing only (assign → done) | Template as alternative lifecycle for R&D squads |
| **Failed Research Documentation** | Dedicated ceremony + `research/failed/` directory | No failure-as-learning pattern | Add to ceremonies template — valuable for any experimental squad |
| **Model Tiering Strategy** | Sonnet for leads, Haiku for support agents | `casting-registry.json` has agents but no cost-tier guidance | Add model selection guidance to casting templates |
| **Autonomy Directives** | `decisions/inbox/copilot-directive-autonomy.md` — explicit policy for zero-human-blocking | Decisions system exists but no autonomy policy template | Template: `autonomy-policy.md` with configurable levels |
| **Label-Based Casting** | `casting/policy.json` with `trigger: "label"` routing | Casting system focuses on persona selection, not work routing | Merge label-routing into casting policy schema |

#### D.2 Patterns That Are Research-Specific (Not Generalizable)

| Pattern | Why It's Specific |
|---------|-------------------|
| Symposium ceremony format | Tied to research-to-production handoff flow |
| Star Trek character themes | Thematic choice (upstream has NASA + 4 TV universes) |
| Research backlog prioritization | Domain-specific to R&D workflows |

#### D.3 Upstream Capabilities We Should Adopt

| Upstream Feature | What We're Missing |
|------------------|-------------------|
| **`squad.config.ts`** | We use markdown/JSON; upstream has TypeScript builder API |
| **11 Skills system** | We have no skills definitions beyond agent charters |
| **OpenTelemetry** | No observability in our squad |
| **Plugin Marketplace** | No extensibility system |
| **235KB decision archive** | Our decisions log is minimal |
| **Scribe memory architecture** | Our Scribe-R is simpler — just logging |
| **9 sample projects** | We have no samples |

### E. Concrete Contribution Plan (3 PRs)

#### PR 1: Cross-Repo Coordination Template (P0 — Ready Now)

**Target:** `.squad-templates/cross-repo-protocol.md`

**What it adds:**
- Template for squads operating across multiple repositories
- Label-based routing protocol (`research:request`, `research:findings`, `research:failed`)
- Mirror-issue pattern (Ralph-R → generalized as "Bridge Agent")
- Communication flow diagrams (Production → Research → Production)

**Files to create:**
```
.squad-templates/cross-repo-protocol.md
.squad-templates/casting/label-routing-policy.json
```

**Why upstream needs this:** Squad's own `.squad/` shows 20 agents but single-repo assumptions. Any team with a production + staging/research split needs this.

#### PR 2: Extended Ceremony Library (P1 — Ready Now)

**Target:** `.squad-templates/ceremonies.md` enhancement

**What it adds:**
- Failed Research Review ceremony (learning from failure)
- Backlog prioritization ceremony with max-active-threads constraint
- Symposium template (batch presentation format)
- Configurable ceremony frequency guidance

**Files to modify:**
```
.squad-templates/ceremonies.md  (extend existing)
```

**Why upstream needs this:** Current ceremonies template is minimal. Real squads need structured coordination patterns.

#### PR 3: Autonomy & Model Tiering Guide (P1 — Ready Now)

**Target:** New guide document

**What it adds:**
- Autonomy policy template with 3 levels: Supervised, Semi-autonomous, Fully autonomous
- Model tiering strategy: when to use premium vs. fast models per agent role
- Decision escalation paths template
- Cost optimization guidance for multi-agent squads

**Files to create:**
```
docs/guides/autonomy-policy.md
docs/guides/model-tiering.md
.squad-templates/autonomy-policy.md
```

**Why upstream needs this:** No guidance exists for how autonomous a squad should be, or how to allocate model tiers across agents with different responsibilities.

### F. Blog Post Outline: "Squad Meets Copilot"

**Title:** *Squad Meets Copilot: Building AI Agent Teams on GitHub's Agentic Platform*

**Target audience:** Engineering teams exploring multi-agent development

1. **The Problem** — Solo AI assistants hit a ceiling; teams need *coordinated* AI agents
2. **Enter Squad** — What bradygaster/squad provides: TypeScript runtime, agent charters, casting, skills, routing
3. **Our Journey** — How we built a research squad (Star Trek theme) with 6 specialized agents
4. **What We Learned** — Key patterns that emerged:
   - Cross-repo coordination is essential for multi-team setups
   - Model tiering (premium for leads, fast for support) cuts costs 60%+
   - Failed research is valuable data — document it
   - Autonomy directives prevent human-bottleneck anti-patterns
5. **Squad + Copilot Platform** — How platform features enhance Squad:
   - **Hooks** → Enforce charter compliance and routing rules automatically
   - **Memory** → Persist squad decisions across sessions without manual `.md` management
   - **Agentic Workflows** → Automate Ralph-style monitoring as GitHub Actions
   - **Spaces** → Bootstrap new squad members with curated knowledge
6. **Contributing Back** — Our 3 PRs to upstream and what they enable
7. **Call to Action** — Try Squad, customize it, contribute your patterns back

**Estimated length:** 2,500–3,000 words  
**Visuals needed:** Squad architecture diagram, cross-repo flow diagram, model tiering chart

### G. Copilot Platform Integration Opportunities

| Platform Feature | Squad Integration Point | Effort | Impact |
|-----------------|------------------------|--------|--------|
| **Hooks** (`hooks.json`) | Enforce agent-charter compliance at chat time; auto-route based on file patterns | Medium | High — deterministic policy enforcement |
| **Memory** | Bridge `decisions.md` to Copilot Memory for cross-session persistence | High | Medium — existing markdown approach works well |
| **Agentic Workflows** | Template Ralph's monitoring as reusable `.github/workflows/` Actions | Medium | High — eliminates need for always-on Ralph agent |
| **Spaces** | `squad spaces init` command that creates a Space from `.squad/` content | Low | Medium — good onboarding accelerator |
| **MCP** | Expose `squad.route-work`, `squad.list-agents`, `squad.log-decision` as MCP tools | High | High — enables external tool integration |

### H. Recommendation

**Immediate actions (this sprint):**
1. ✅ Submit PR 1 (Cross-Repo Protocol) to `bradygaster/squad` — no code changes, pure template
2. ✅ Submit PR 2 (Extended Ceremonies) — small enhancement to existing template
3. ✅ Submit PR 3 (Autonomy + Model Tiering) — new docs, no runtime impact

**Next cycle:**
4. Draft the blog post using the outline in Section F
5. Prototype a Hooks integration as a proof-of-concept
6. Evaluate whether Ralph's monitoring can be expressed as an Agentic Workflow

**Key insight:** Our best contribution path is through `.squad-templates/` and `docs/` — these require zero runtime changes and can be merged independently of the SDK release cycle.

---

*— Geordi (Technology Scanner)*  
*Research Squad, tamresearch1-research*  
*"The upstream runtime is impressive engineering. Our contribution isn't competing code — it's battle-tested operational patterns that make the framework more useful for real teams."*
