# ADC Integration for Squad — Research Report

> **Issue:** [#1064](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1064)
> **Relates to:** [#752](https://github.com/tamirdresher_microsoft/tamresearch1/issues/752) (POC: Run Ralph on ADC)
> **Author:** Picard (Lead)
> **Date:** 2026-03-20
> **Status:** Research Complete — Awaiting Decision

---

## Table of Contents

1. [What ADC Is](#1-what-adc-is)
2. [What DTS Is (and Why It Matters)](#2-what-dts-is-and-why-it-matters)
3. [Current Squad Deployment Landscape](#3-current-squad-deployment-landscape)
4. [Use Cases: What Problems Would ADC Solve?](#4-use-cases-what-problems-would-adc-solve)
5. [Key Questions from Issue #1064](#5-key-questions-from-issue-1064)
6. [Integration Architecture Options](#6-integration-architecture-options)
7. [Recommended Approach](#7-recommended-approach)
8. [Dependencies and Prerequisites](#8-dependencies-and-prerequisites)
9. [Implementation Steps](#9-implementation-steps)
10. [Risk Register](#10-risk-register)
11. [Decision Required](#11-decision-required)

---

## 1. What ADC Is

**ADC (Agent Dev Compute)** is Microsoft's managed sandboxed compute platform for AI agents, available at
[portal.agentdevcompute.io](http://portal.agentdevcompute.io/). It provides:

- **Isolated sandbox environments** purpose-built for AI agent workloads
- **No idle-timeout** — unlike DevBoxes and Cloud PCs, ADC sessions are designed to run continuously
- **Managed provisioning** — no cluster administration; Microsoft manages the underlying infrastructure
- **Agent-first design** — built around the assumption that code runs autonomously, not interactively

ADC is Microsoft-internal infrastructure. It was brought to Tamir's attention by **Anirudh** (context from
issue #613): *"with DTS and ADC you will get a lot of help. ADC is the raw sandboxed compute and DTS basically
creates queues and spawns work on your behalf — all the orchestration."*

### ADC vs. Other Compute Options

| Dimension | Local DevBox | AKS | DK8S | ADC |
|-----------|-------------|-----|------|-----|
| Session persistence | ❌ Idle timeouts | ✅ Always-on | ✅ Always-on | ✅ Agent-native |
| Managed infrastructure | ❌ Self-managed | ⚠️ Partial (AKS managed plane) | ⚠️ DK8S tenant | ✅ Fully managed |
| K8s expertise required | No | Yes | Yes | No |
| Agent-oriented design | ❌ Generic compute | ❌ Generic K8s | ❌ Generic K8s | ✅ Yes |
| Cost model | DevBox SKU (always-on) | AKS node pool (always-on) | DK8S tenant allocation | Consumption-based (likely) |
| GitHub auth | Manual PAT / Workload Identity | Workload Identity + Key Vault | DK8S SA | TBD — research needed |
| MCP server support | ✅ Native | ✅ Sidecar containers | ✅ Sidecar containers | ❓ Unknown — key risk |
| Multi-agent scaling | Manual orchestration | K8s Jobs/Deployments | Same | DTS orchestration |

---

## 2. What DTS Is (and Why It Matters)

**DTS (Developer Task Service)** is the orchestration layer that sits above ADC. DTS:

- Creates task queues for agent workloads
- Spawns ADC compute sessions on-demand for queued tasks
- Routes work items to available agent compute
- Handles session lifecycle: create → run → terminate

**Why this matters for Squad:** DTS is essentially a managed version of what Ralph does today. Ralph's
reconciliation loop polls GitHub issues and spawns agents. DTS could replace or augment this pattern with:

- Cloud-native queue-based dispatching (no polling)
- On-demand scaling (spin up N ADC sessions for N parallel tasks)
- Managed retries and dead-letter queues

The combination of **ADC + DTS** maps neatly onto Squad's existing architecture:

```
Current Squad:             ADC + DTS equivalent:
─────────────────────────  ─────────────────────────────────────
Ralph (poll loop)       →  DTS (queue + spawn)
DevBox compute          →  ADC session
Git as state store      →  Git as state store (unchanged)
MCP servers (local)     →  MCP servers in ADC (TBD)
cross-machine tasks/    →  DTS task queue
heartbeats/             →  DTS session health API
```

---

## 3. Current Squad Deployment Landscape

Squad's deployment story is actively being defined across several parallel issues:

| Target | Issue | Status | Notes |
|--------|-------|--------|-------|
| Local DevBox | — | ✅ Current | Session disconnect problem (#700), not scalable |
| AKS | #1060 | 🔵 Research | Docs written (`docs/squad-on-aks.md`), needs implementation |
| DK8S | #1061 | 🔵 Research | Internal Microsoft deployment, ConfigGen + EV2 |
| ADC | **#1064** | 🔵 Research | **This issue** |
| Open-source K8s packaging | #1062 | 🔵 Research | For external users |

The missing piece across all targets is the **deployment target abstraction**: ideally
`squad deploy --target adc`, `--target aks`, `--target dk8s`, `--target local`.

ADC would be the first **non-K8s, Microsoft-managed** deployment target — a fundamentally different
category from the others, and the lowest-friction path for new Squad adopters inside Microsoft.

---

## 4. Use Cases: What Problems Would ADC Solve?

### 4.1 Session Persistence (Critical)

**Problem:** The #1 operational pain point for Squad (see #700). DevBoxes idle-timeout. Cloud PCs lock.
Ralph dies. Agents lose context. This has driven extensive workarounds: keep-alive scripts, Windows Task
Scheduler, `ralph-watch.ps1`, heartbeat monitoring, cross-machine failover patterns.

**ADC solution:** ADC sessions are designed to run agent workloads indefinitely without idle-disconnect.
Ralph on ADC would be permanently alive — no keep-alive hacks required.

**Impact: HIGH** — Eliminates an entire class of operational toil.

---

### 4.2 Zero Infrastructure Management

**Problem:** Running Squad on AKS or DK8S requires owning a cluster, a DK8S tenant, ArgoCD config,
ConfigGen C# code, EV2 rollout specs, Helm charts, and ongoing maintenance. High barrier to adoption.

**ADC solution:** ADC handles all infrastructure. A squad operator only needs to configure the agent
and submit it — no K8s expertise required.

**Impact: HIGH** — Dramatically lowers adoption barrier, especially for non-platform DK8S teams.
Critical for the [DK8S Squad Usage Standard](dk8s-squad-usage-standard.md) where not every engineer
wants to own a K8s tenant.

---

### 4.3 On-Demand Multi-Agent Scaling

**Problem:** Spinning up multiple Squad agents today requires multiple DevBoxes or K8s Jobs.
Cross-agent coordination relies on cross-machine state files and heartbeat files — fragile and manual.

**ADC + DTS solution:** DTS can spawn N ADC sessions for N parallel tasks. Each Squad agent becomes an
independent ADC session coordinated by DTS queues. Scaling is instantaneous and fully managed.

**Impact: MEDIUM** — Enables true parallel agent execution without K8s expertise.

---

### 4.4 Cost Efficiency for Intermittent Workloads

**Problem:** AKS and DK8S clusters are always-on. Even when no agents are actively doing work
(waiting for issues, overnight), you're paying for idle compute. DevBoxes are also always-on.

**ADC solution:** If ADC is consumption-based (likely), you pay only for active agent compute time.
For a Squad that does most of its work in short bursts (issue triage, PR review, research tasks),
this could be significantly cheaper than always-on K8s.

**Impact: MEDIUM** — Depends on ADC pricing model (must be validated).

---

### 4.5 Enabling the DK8S Squad Usage Standard at Scale

**Problem:** The [DK8S Squad Usage Standard](dk8s-squad-usage-standard.md) defines a three-tier
hierarchy (Org Squad → Swimlane Squad → Personal Squad). Deploying each swimlane's Squad on DK8S
requires per-swimlane K8s expertise and cluster resources.

**ADC solution:** If ADC supports multi-tenant or per-team sessions, DK8S teams could run their
swimlane Squad on ADC without owning K8s infrastructure. ADC becomes the standard compute layer
for Squad across the DK8S org.

**Impact: HIGH** — Directly enables the DK8S Squad Usage Standard at org scale.

---

## 5. Key Questions from Issue #1064

### 5.1 ADC as a First-Class Deployment Target

**Question:** Can `squad deploy --target adc` be a first-class option?

**Assessment:** Yes, technically feasible. It would require:
- An ADC session manifest format (analogous to K8s Pod spec or Helm values)
- A DTS queue configuration (instead of K8s manifests)
- An ADC-specific Ralph bootstrap (connecting to DTS instead of polling GitHub directly)
- A `target: "adc"` type added to `squad.config.ts`

The `squad.config.ts` abstraction already supports the concept of targets. Adding `adc` is architecturally
clean and does not require K8s changes.

**Confidence:** High that it's feasible; ADC API specifics depend on #752 POC results.

---

### 5.2 Session Persistence for Squad State

**Question:** ADC solves DevBox disconnect, but how does Squad state persist across ADC sessions?

**Current model:** Squad state lives in git:
- `.squad/decisions.md` — architecture decisions
- `.squad/decisions/inbox/` — pending decisions
- `.squad/research/` — research files
- `.squad/monitoring/` — monitoring state

**This is already portable.** No ADC-specific state management needed for git-backed state.

**Cross-session state NOT in git today:**

| State type | Current location | ADC equivalent |
|-----------|-----------------|----------------|
| Heartbeats | `~/.squad/heartbeats/` | DTS session health API |
| Cross-machine tasks | `~/.squad/cross-machine/tasks/` | DTS task queue |
| MCP server state | In-memory (ephemeral) | Same — restart per session |

**Assessment:** Squad's git-centric state model is an **accidental advantage for ADC**. Unlike K8s
(which needs PersistentVolumes for session state), ADC sessions can pull the git repo fresh and resume
from committed state. **No fundamental changes to state management required.**

---

### 5.3 Cost Model

**Question:** ADC consumption vs. AKS always-on vs. DevBox for 24/7 Squad operation.

**Rough analysis:**

| Scenario | AKS/DevBox | ADC (consumption model) |
|----------|-----------|------------------------|
| Ralph monitor loop (24/7, lightweight) | Full node cost ($200-400/mo) | Near-zero CPU → cheap |
| Agent spike (10 parallel issues) | Needs pre-scaled pool or slow Job scheduling | DTS spins up N sessions instantly |
| Overnight idle (8h) | Full cost | Near-zero if no active sessions |
| Monthly (rough estimate) | ~$200-400/mo (Standard_D4s_v5 node) | Unknown — needs ADC pricing |

**Hypothesis:** ADC is cheaper for Squad's bursty workload pattern. Squad is not compute-intensive
between tasks; the expensive part is the agent work itself, which is short-lived.

**Action required:** Get ADC pricing from portal.agentdevcompute.io before making a cost decision.

---

### 5.4 Multi-Agent on ADC

**Question:** One session per Squad, or one session per agent task?

**Three models:**

| Model | Description | Assessment |
|-------|-------------|-----------|
| **A — Monolithic** | All agents share one ADC session | Simple, doesn't leverage DTS scaling. Same as DevBox. |
| **B — Per-task sessions** | DTS spawns an ADC session per work item | Maximum scalability, highest DTS complexity. |
| **C — Hybrid (recommended)** | Ralph = persistent session; task agents = ephemeral sessions via DTS | Matches current architecture naturally. |

**Recommendation: Hybrid (Option C)**

Ralph's reconciliation loop stays persistent (lightweight, always-on ADC session). When Ralph picks up
an issue, it submits to DTS, which spawns an ephemeral ADC session running the specialized agent
(Picard, B'Elanna, Data, etc.). The agent completes, commits to git, and the session terminates.

This matches Squad's current architecture: Ralph orchestrates, agents are spawned per task.

---

### 5.5 MCP Servers on ADC

**Question:** Are MCP servers available inside ADC's sandboxed environment?

**This is the highest-risk unknown for Squad on ADC.**

Squad's MCP servers are critical for most agent capabilities:

| MCP Server | Used by | Criticality |
|-----------|---------|------------|
| `github` | All agents (issues, PRs, code search) | Critical |
| `azure-devops` | B'Elanna, Data, Worf | High |
| `teams` | Kes, Neelix | Medium |
| `calendar` | Kes | Medium |
| `mail` | Kes | Medium |
| `configgen` | Data, B'Elanna | Medium |

**Risk scenarios:**

1. **ADC allows outbound HTTPS** → MCP servers work as-is ✅ (best case)
2. **ADC has a plugin model** → register MCP servers as ADC plugins ✅ (workable)
3. **ADC has sidecar support** → run MCP servers as co-located processes ✅ (workable)
4. **ADC restricts outbound networking** → Squad limited to git-only operations ❌ (unacceptable for full Squad)

**Required action:** The #752 POC **must** test MCP server compatibility as a first-class test case.
Start with the `github` MCP (lowest friction: just HTTPS to api.github.com) before investing further.

---

### 5.6 GitHub API Authentication on ADC

**Question:** How does ADC handle GitHub token management and rotation?

**Options by security level:**

| Option | Security | Complexity | When to use |
|--------|---------|-----------|------------|
| PAT as environment variable | Low | Minimal | POC only |
| PAT in ADC secret store | Medium | Low | Early production |
| GitHub App + ADC managed identity | High | Medium | Production |
| GitHub Workload Identity (OIDC) | Highest | High | Enterprise production |

**For #752 POC:** Use PAT as environment variable.
**For production:** Worf to investigate whether ADC exposes a managed identity or secret management API
equivalent to Azure Key Vault CSI driver (used in `docs/squad-on-aks.md`).

---

## 6. Integration Architecture Options

### Option A: ADC Replaces DevBox (Full Migration)

```
DTS Queue ──→ ADC Session (Ralph, persistent)
                    │
                    ├──→ DTS ──→ ADC Session (Agent 1, ephemeral)
                    ├──→ DTS ──→ ADC Session (Agent 2, ephemeral)
                    └──→ DTS ──→ ADC Session (Agent N, ephemeral)
                                        │
                                        └──→ git (commit results)
```

All Squad compute runs on ADC. No DevBox dependency.

| | |
|--|--|
| **Pros** | Clean architecture, no DevBox, cloud-native, maximum scalability |
| **Cons** | MCP availability unknown (highest risk), requires full #752 POC validation |

---

### Option B: ADC as Overflow / Scale Layer

```
DevBox (Ralph) ──→ GitHub polling
DevBox (Ralph) ──→ DTS Queue ──→ ADC Sessions (compute-heavy agent tasks)
DevBox (Ralph) ──→ DevBox Agents (tasks needing local capabilities)
```

Ralph stays on DevBox, but submits parallelizable tasks to DTS/ADC.

| | |
|--|--|
| **Pros** | Low risk, incremental adoption, DevBox stays as proven fallback |
| **Cons** | Hybrid complexity, two compute environments to maintain, doesn't solve session persistence |

---

### Option C: ADC as Primary, DevBox for Capability Tasks (Recommended)

```
ADC Session (Ralph, persistent) ──→ triage issues
        │
        ├── most tasks ──→ DTS ──→ ADC Sessions (agents)
        │                                │
        │                                └──→ git (commit results)
        │
        └── needs:browser / needs:gpu / needs:whatsapp
                    │
                    └──→ DevBox (via existing needs:* label routing)
```

Ralph lives in ADC permanently. Most agent tasks run in ADC sessions. Tasks requiring hardware
capabilities (`needs:browser`, `needs:gpu`, `needs:whatsapp`) route to DevBox machines via the
existing `needs:*` label system in `.squad/routing.md`.

| | |
|--|--|
| **Pros** | Solves session persistence, low infrastructure burden, leverages existing `needs:*` routing, incremental migration path |
| **Cons** | Still needs DevBox for some tasks, DTS/ADC-specific Ralph changes required |

---

## 7. Recommended Approach

### Phase 1: POC Validation (Issue #752 — currently in progress)

Complete #752 POC with these specific test cases, in priority order:

| # | Test | Why |
|---|------|-----|
| 1 | Ralph minimal loop starts on ADC | Foundation test — can ADC run PowerShell/Node.js? |
| 2 | `github` MCP server starts inside ADC session | Highest-risk unknown |
| 3 | State commit from ADC session → git push succeeds | Squad's core data flow |
| 4 | ADC session persists for 24h without idle-timeout | Core assumption validation |
| 5 | ADC pricing data from portal | Business case validation |

### Phase 2: Architecture Decision (1 week after POC results)

Decide between Options A, B, C based on POC results.

**Decision matrix:**

| POC outcome | Recommended option |
|-------------|-------------------|
| MCP works + no idle-timeout + competitive cost | Option A (Full Migration) |
| MCP works + no idle-timeout + cost unknown | Option C (Hybrid) |
| MCP blocked, all else works | Option B (Overflow only) |
| Session persistence fails | No ADC investment — revisit when ADC matures |

### Phase 3: `squad deploy --target adc` (2-3 weeks post-decision)

If Option A or C is selected:

1. Define ADC session manifest schema → `infrastructure/adc/session-manifest.json`
2. Add `target: "adc"` to `squad.config.ts`
3. Write `scripts/deploy-ralph-adc.ps1` — bootstraps Ralph in an ADC session
4. Write `scripts/configure-dts-queue.ps1` — creates Squad DTS task queue
5. Write agent ADC session template (includes: Copilot CLI, gh CLI, Node.js, MCP servers)
6. Update `.squad/routing.md` — document ADC capability routing + DevBox fallback
7. Write `infrastructure/adc/README.md` deployment guide
8. Update `docs/dk8s-squad-usage-standard.md` — add ADC as recommended deployment target

---

### Summary Recommendation

> **Pursue Option C (ADC as Primary + DevBox for capability tasks), contingent on #752 POC validating:**
>
> 1. MCP servers work inside ADC sessions (or equivalent extension point exists)
> 2. ADC sessions have no idle-timeout over 24h
> 3. ADC cost is competitive with DevBox/AKS for Squad's bursty workload pattern
>
> **If MCP servers work → upgrade to Option A (Full Migration).**
> **If any condition fails → fall back to Option B (ADC as overflow/scale layer only).**

**Rationale:** ADC simultaneously solves Squad's top two pain points: session persistence (no keep-alive hacks)
and infrastructure management (no K8s expertise required). That combination makes it the most accessible
deployment target for new Squad users — particularly valuable for the DK8S usage standard where not every
engineer wants to own a K8s tenant. The git-centric state model means ADC integration is cheaper than it
would be for stateful agents.

**Do not invest further in ADC until #752 POC validates MCP compatibility.** That is the single gate.

---

## 8. Dependencies and Prerequisites

| Dependency | Status | Owner | Notes |
|-----------|--------|-------|-------|
| #752 POC: Ralph on ADC | 🔵 In Progress | B'Elanna | Foundational — completes before #1064 |
| ADC portal access | ❓ Unknown | Tamir | Verify access to portal.agentdevcompute.io |
| DTS queue provisioning API | ❓ Unknown | B'Elanna | Research in #752 scope |
| ADC pricing data | ❓ Unknown | Tamir | Get from ADC portal or Anirudh's team |
| MCP server compatibility on ADC | ❓ Unknown | Data | Highest-risk unknown — gate on this |
| GitHub auth model for ADC | ❓ Unknown | Worf | PAT for POC, secure model for prod |
| `squad.config.ts` target abstraction | ✅ Exists | Data | Already supports target concept |
| `needs:*` label routing | ✅ Exists | — | Already in `.squad/routing.md` — reuse for ADC routing |
| DK8S usage standard update | 🔵 In Progress | Picard | Add ADC once validated (#771) |

---

## 9. Implementation Steps

### 9.1 Pre-Implementation Gates (Block on these)

- [ ] Get access to portal.agentdevcompute.io (Tamir)
- [ ] Complete #752 POC with all five test cases (Section 7, Phase 1)
- [ ] Get ADC pricing model from portal or Anirudh's team
- [ ] Confirm MCP server compatibility inside ADC sandbox — **hard gate**

### 9.2 Option C Implementation (if POC succeeds)

**Week 1: Configuration and Bootstrap**
- [ ] Define ADC session manifest schema → `infrastructure/adc/session-manifest.json`
- [ ] Write `scripts/deploy-ralph-adc.ps1` — bootstraps Ralph in persistent ADC session
- [ ] Write `scripts/configure-dts-queue.ps1` — creates Squad DTS task queue
- [ ] Test: Ralph starts in ADC, checks in via heartbeat, picks up one test issue

**Week 2: Agent Task Dispatch via DTS**
- [ ] Implement DTS task submission in Ralph's reconciliation loop
- [ ] Write agent ADC session template (Copilot CLI + gh CLI + Node.js + MCP servers)
- [ ] Test: End-to-end — GitHub issue → Ralph (ADC) → DTS → Agent session → git commit → PR

**Week 3: Routing and Capability Integration**
- [ ] Add `target: "adc"` to `squad.config.ts`
- [ ] Update `.squad/routing.md` — ADC tasks + DevBox fallback for `needs:*` labels
- [ ] Update `scripts/discover-machine-capabilities.ps1` — detect ADC environment
- [ ] Write `infrastructure/adc/README.md` deployment guide

**Week 4: DK8S Integration**
- [ ] Update `docs/dk8s-squad-usage-standard.md` — ADC as preferred target for swimlane squads
- [ ] Verify ADC deployment works in DK8S org context (tenant/identity constraints)
- [ ] Document cost comparison: ADC vs. DevBox vs. AKS for representative Squad workloads

### 9.3 Issue #1064 Acceptance Criteria Checklist

- [ ] Decision: ADC as primary, secondary, or not viable
- [ ] If viable: deployment script/config (`infrastructure/adc/`)
- [ ] Cost comparison: ADC vs. AKS vs. local DevBox
- [ ] Identified limitations (Squad features that don't work on ADC)
- [ ] Issue #752 updated with findings from this research

---

## 10. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| MCP servers blocked in ADC sandbox | Medium | High | Test in #752 POC early; Option B fallback |
| ADC has its own idle-timeout | Low | High | Verify in #752 24h persistence test |
| ADC pricing not competitive | Low | Medium | Get pricing before committing to Option A |
| GitHub auth model is complex in ADC | Medium | Medium | PAT for POC; Worf investigates secure model post-POC |
| ADC API unstable (Microsoft-internal, pre-GA) | Medium | Medium | Build thin abstraction layer in `infrastructure/adc/` |
| DTS learning curve delays POC | Medium | Low | Anirudh's video is primary resource; escalate if blocked |
| ADC not broadly available to all DK8S engineers | Medium | High | Confirm ADC access scope before adopting as standard |
| Network egress costs from ADC (GitHub API calls) | Low | Low | Monitor — Squad is not high-volume API consumer |

---

## 11. Decision Required

The research is complete. The key decision point is:

> **"Should Squad invest in ADC as a deployment target, and if so, as primary (replacing DevBox),
> secondary (complementing K8s targets), or not at all?"**

**This decision is blocked on #752 POC results.** Specifically, the MCP server compatibility test
is the hard gate — if MCP servers cannot run inside ADC sessions, Squad's value proposition on ADC
drops from "full Squad" to "git-only agent" (much less useful).

**Recommended action sequence:**

1. ✅ This research is done
2. 🔵 Complete #752 POC (B'Elanna leads)
3. 🔵 Tamir reviews POC findings + this report → makes deployment target decision
4. 🔵 If green: proceed with Option C implementation (Section 9.2)

**My recommendation stands as Option C** — ADC as primary with DevBox fallback for capability tasks —
contingent on the MCP compatibility gate passing.

---

*Report authored by Picard (Lead) · Issue [#1064](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1064) · 2026-03-20*
