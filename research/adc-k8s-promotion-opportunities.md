# ADC & K8s Promotion Opportunities for Squad

> **Author:** Seven (Research & Docs)
> **Date:** 2026-07-14
> **Status:** Actionable Roadmap
> **Context:** Anirudh (ADC/DTS), Ramaprakash (DK8S), prior Dapr Agents research, existing AKS production deployment

---

## TL;DR

Squad has a unique position: it already runs on AKS in production with battle-tested Helm charts, KEDA autoscaling, and Workload Identity. The next move is to expand into two adjacent spaces — **ADC for ephemeral agent compute** and **Dapr Agents for durable orchestration** — while promoting what's already working (KEDA Copilot Scaler, pod-per-agent CRDs, Ralph CronJob pattern). This document maps what to build, what to demo, and what's blocking each path.

---

## 1. ADC Opportunities to Promote

### 1a. Ephemeral Agent Sandboxes (vs. Always-On AKS Pods)

**What it is:** Run Squad agents as short-lived ADC sandboxes that spin up per-task, do work, and auto-destroy — instead of maintaining always-on AKS pods or CronJobs.

**Why it matters:**
- AKS nodes burn cost even when idle. ADC sandboxes are consumption-based — you pay only when an agent is working.
- ADC has **no idle timeout** (unlike DevBox, which disconnects). Agents can run multi-hour tasks without session management.
- The `executeShellCommand` API means agents run arbitrary code in isolation without K8s RBAC complexity.

**Current state:**
- ADC sandbox CRUD works via API (`POST /sandboxes`, `DELETE /sandboxes/{id}`)
- Shell execution confirmed via `POST /sandboxes/{id}/executeShellCommand`
- File storage available via Volumes API (`/volumes/{id}/files`)
- Port exposure works with Entra ID auth + IP ACLs
- Auth model: API key (portal-generated) — Entra token flow not yet clean

**Promotion angle:** "Squad agents don't need a cluster. They need a sandbox, a task, and a way out."

### 1b. DTS Orchestration Layer (Replaces Ralph's Polling)

**What it is:** Developer Task Service sits above ADC. It creates task queues, spawns ADC sessions on demand, and manages lifecycle. This is essentially a managed version of what Ralph does today.

**Architecture mapping:**

| Current Squad | ADC + DTS Equivalent |
|---|---|
| Ralph polling loop (every 15 min) | DTS queue-based dispatch (event-driven) |
| DevBox / AKS pod compute | ADC sandbox session |
| Git issues as work queue | DTS task queue + Git issues |
| PowerShell mutex/lock scripts | DTS managed concurrency |
| Manual retry on failure | DTS dead-letter queue + managed retries |

**Why it matters:**
- Ralph's CronJob pattern works but is fundamentally poll-based. DTS is event-driven — lower latency, no wasted cycles.
- DTS handles multi-agent fan-out natively: queue N tasks → spawn N sandboxes → collect results.
- Managed retries and dead-letter queues replace the 37-failure scenarios documented in blog Part 4.

**Current state:** No public API documentation. Anirudh (ADC/DTS team) offered a walkthrough. This is the **#1 next action** for ADC integration.

### 1c. ADC + Agent Identity for Per-Agent Entra ID Isolation

**What it is:** Each Squad agent gets its own Entra Agent Identity — a purpose-built service account (not a regular service principal). Combined with ADC sandbox isolation, each agent runs with its own identity, own permissions, own audit trail.

**Why it matters:**
- Current AKS setup uses a single Workload Identity for all agents. If one agent is compromised, all have the same access.
- Agent Identity Blueprints allow granular permission sets: Ralph gets `repo` scope, Seven gets `read-only`, Worf gets `security` scopes.
- Entra audit logs show *which agent* did what — not just "the squad service principal."

**Current state:** ❌ **Blocked** — `AADSTS90094` admin consent error. The `AgentIdentityBlueprint.Create` scope requires tenant admin consent in the Microsoft tenant. See [Blockers section](#4-open-questions--blockers) for resolution paths.

### 1d. Cost Comparison

| Platform | Monthly Cost (Est.) | Model | Idle Cost | Startup | Best For |
|---|---|---|---|---|---|
| **AKS Standard Free** | ~$55–80 | Node pool (B2s Spot) | Nodes always on | ~2 min | Dev/staging, cost-sensitive |
| **AKS Automatic** | ~$150–200 | Managed node pool | Nodes always on | ~2 min | Production, zero-ops |
| **ADC (projected)** | ~$80–150 | Consumption per sandbox | $0 when idle | ~seconds | Burst workloads, per-task agents |
| **DK8S Tenant** | Internal allocation | Tenant quota | Tenant always allocated | ~minutes | Microsoft-internal teams |
| **Local DevBox** | ~$0.50–2/hr | Always-on RDP | ⚠️ Idle timeout disconnects | ~minutes | Developer interactive use |

**Key insight:** ADC's projected cost beats AKS Automatic for bursty workloads (agents that run 4 min/hour, idle 56 min/hour). AKS wins for always-on, high-utilization agents. The optimal architecture is **hybrid: AKS for Ralph + KEDA (always monitoring), ADC for task agents (ephemeral work).**

### 1e. The "Serverless K8s for Agents" Narrative

**Positioning:** ADC is to AI agents what Azure Functions is to HTTP handlers — you write the logic, the platform handles the compute. No clusters to manage, no node pools to size, no KEDA to configure.

**Why this narrative works:**
- Platform teams resist giving AI agents cluster access. ADC sidesteps this entirely.
- Security teams prefer sandboxed isolation over shared-cluster multi-tenancy.
- ADC's egress rules (allow/deny external domains) give security teams the control they want without network policies.

**Counterpoint to address:** ADC is not GA, has no public docs, and the auth story isn't clean yet. Don't oversell — position as "emerging compute for agents" alongside proven AKS path.

---

## 2. K8s / AKS Opportunities

### 2a. Dapr Agents Integration (Durable Workflows, Virtual Actors, Scale-to-Zero)

**What it is:** Dapr Agents v1.0 GA (March 2026, KubeCon Europe) is a production-grade framework for resilient multi-agent AI systems on Kubernetes.

**Key capabilities relevant to Squad:**

| Dapr Agents Feature | Squad Equivalent Today | Upgrade Path |
|---|---|---|
| Durable workflows (automatic retry/recovery) | Ralph retry logic (fragile) | Durable task orchestration across pod restarts |
| Virtual Actors (scale-to-zero, <10ms startup) | CronJob (cold start ~30s) | Thousands of agents on single core, instant activation |
| Pub/sub coordination | Git-based state (polling) | Event-driven agent-to-agent messaging |
| MCP integration (stdio, SSE, streamable HTTP) | MCP servers as sidecars | Native MCP within Dapr runtime |
| OpenTelemetry tracing | Manual logging | Distributed tracing across agent interactions |
| 50+ data bindings (Redis, Cosmos, Kafka, Service Bus) | GitHub API only | Enterprise data source integration |

**Language gap:** Dapr Agents is **Python-only** (≥3.11). Squad is Node.js/TypeScript. Options:
1. **Bridge pattern:** Dapr sidecar handles orchestration; Squad agents run as TypeScript containers invoked via Dapr service-to-service calls.
2. **Wait for .NET/Go SDK** — announced for 2025+ (now late 2026 at earliest).
3. **Prototype in Python** — build a Dapr Agents quickstart that mimics Squad's Ralph→Agent→Result flow.

**Promotion angle:** Dapr Agents provides the durable infrastructure that Squad's blog Part 4 (37 consecutive failures) shows is needed. "Squad provides the agent team model. Dapr provides the cloud-native runtime guarantees."

### 2b. KEDA Copilot Scaler (Already Deployed — Promote as Open Source)

**What it is:** A KEDA external scaler (gRPC) that scales K8s pods based on GitHub issue queue depth AND API rate limit headroom. Composite AND logic — only scales up when work exists AND API headroom allows it.

**Current state:** ✅ Production-ready, MIT licensed, Helm chart + Kustomize deployment.

**Repository:** `keda-copilot-scaler/` in this repo. Includes:
- gRPC server implementing KEDA external scaler spec
- `IsActive` → true when issues exist AND rate limit > threshold
- `GetMetrics` → returns issue queue depth (or 0 if rate-limited)
- Docker build, CI/CD workflow, example `ScaledObject`

**Promotion actions:**
1. **Extract to standalone repo** (`tamirdresher/keda-copilot-scaler`) — it's already self-contained.
2. **Submit to KEDA external scaler catalog** — the official list at `keda.sh/docs/scalers/`.
3. **Blog post:** "Scaling AI Agents with KEDA: Rate-Limit-Aware Autoscaling for GitHub Copilot Workloads."
4. **KubeCon lightning talk proposal** — 5 min demo of issue → scale-up → agent work → scale-down.

### 2c. K8s Capability Routing DaemonSet (PR #1290 / Issue #999)

**What it is:** A DaemonSet that probes each node for capabilities (GPU, browser, WhatsApp session, Azure Speech SDK) and applies K8s labels. The Squad operator then schedules agent pods to nodes that match the issue's `needs:*` labels.

**Label mapping:**

| GitHub Label | K8s Node Label | Discovery |
|---|---|---|
| `needs:gpu` | `nvidia.com/gpu` | NVIDIA device plugin |
| `needs:browser` | `squad.io/capability-browser` | Playwright probe |
| `needs:whatsapp` | `squad.io/capability-whatsapp` | Session file detection |
| `needs:azure-speech` | `squad.io/capability-azure-speech` | SDK + secret check |

**Why promote this:** It demonstrates K8s-native intelligence — the scheduler matches work to infrastructure without manual assignment. This is the bridge between "AI agent" and "platform engineering."

### 2d. Squad-on-AKS Reference Architecture

**What exists:**
- **Two deployment paths** documented in `docs/squad-on-aks.md`:
  - AKS Standard Free (~$55–80/mo) — dev/staging
  - AKS Automatic (~$150–200/mo) — production, zero-ops
- **Helm charts** in `infrastructure/helm/squad-agents/` with Workload Identity, RBAC, NetworkPolicy, KEDA ScaledObjects
- **Bicep IaC** in `infrastructure/aks-automatic-squad.bicep`
- **CRD definitions**: `SquadTeam`, `SquadAgent`, `SquadRound`
- **Ralph CronJob** pattern (concurrencyPolicy: Forbid replaced 300 lines of mutex logic)
- **Pod-per-agent model**: each agent has independent lifecycle, resources, node affinity

**Promotion actions:**
1. **Public repo:** `tamirdresher/squad-on-aks` — ensure it mirrors latest Helm charts and Bicep.
2. **Azure Architecture Center submission** — reference architecture for multi-agent AI on AKS.
3. **Blog Part 6 series** — already written, ready for cross-posting (Dev.to, Hashnode, LinkedIn).
4. **Workshop:** "Build Your Own AI Squad on Kubernetes" — 90-min hands-on (draft exists at `docs/workshop-build-your-own-squad.md`).

---

## 3. What to Demo / Showcase Next

### Demo 1: ADC Ephemeral Task Agent (Priority: HIGH)

**Flow:**
1. GitHub issue opened with `squad:copilot` label
2. Ralph detects issue → calls ADC API to create sandbox
3. ADC sandbox boots (~seconds), clones repo, runs Squad agent
4. Agent completes work, pushes PR, comments on issue
5. ADC sandbox auto-destroys

**What it proves:** Agents don't need persistent infrastructure. Compute is ephemeral. Only the work product (git commits, issue comments) persists.

**Prerequisites:** DTS API access (from Anirudh), clean auth flow for ADC API.

### Demo 2: Dapr Agents Multi-Agent K8s Quickstart (Priority: MEDIUM)

**Flow:**
1. Python Dapr Agent "Ralph" watches pub/sub topic for new issues
2. Ralph publishes task to "work" topic
3. Dapr Agent "Data" (virtual actor) activates from zero, picks up task
4. Data completes code review, publishes result to "results" topic
5. Ralph collects result, comments on GitHub issue
6. Data scales back to zero

**What it proves:** Scale-to-zero agent teams with durable orchestration. No CronJob polling. No wasted compute.

**Prerequisites:** Dapr installed on AKS cluster, Python prototype of Ralph + Data agent pair.

### Demo 3: KEDA Auto-Scaling Agents by Queue Depth (Priority: HIGH)

**Flow:**
1. 5 issues opened simultaneously with `squad:copilot` label
2. KEDA Copilot Scaler detects queue depth = 5
3. KEDA scales Ralph deployment from 1 → 5 pods (rate limit permitting)
4. 5 Ralph pods process issues in parallel
5. Issues resolved → queue depth = 0 → KEDA scales to 1

**What it proves:** AI agent teams scale like any other K8s workload. Rate limiting is a first-class scaling signal.

**Prerequisites:** Already deployed. Needs a clean recording and blog post.

### Demo 4: Cross-Platform Squad (Priority: LOW — wait for ADC maturity)

**Flow:** Same `squad.config.ts` deploys agents to:
- AKS (production monitoring via Ralph CronJob)
- ADC (burst task agents via DTS)
- DevBox (developer interactive sessions)

**What it proves:** Squad is platform-agnostic. The agent team model is independent of the compute substrate.

**Prerequisites:** ADC + DTS integration complete, config abstraction layer.

---

## 4. Open Questions / Blockers

### Blocker 1: Agent Identity Admin Consent (`AADSTS90094`)

**Impact:** Blocks per-agent Entra ID isolation (section 1c).

**Root cause:** `AgentIdentityBlueprint.Create` is admin-consent-only in the Microsoft tenant. Every auth method tried (az CLI, device code, OAuth auth code + PKCE, portal broker refresh) fails.

**Resolution paths:**
| Path | Effort | Likelihood |
|---|---|---|
| Request admin consent from tenant admin (IT helpdesk ticket) | Low | Medium — policy may prevent |
| Use a different Entra tenant where user IS admin | Medium | High — creates test environment |
| Wait for "ADC-Owned Shared Blueprint" (avoids BYOAI) | Zero | Unknown timeline |
| Helper app `squad-agent-identity-helper` (App ID: `a0ae7a27-...`) already created — needs admin to grant application permissions | Low | Medium |

**Next step:** File IT helpdesk ticket requesting admin consent for `squad-agent-identity-helper` app's `AgentIdentityBlueprint.Create` permission.

### Blocker 2: MCP Server Compatibility Inside ADC Sandboxes

**Impact:** Blocks running Squad's 7 MCP servers (squad-mcp, Bitwarden, ICM, Kusto, Learn, security-context) inside ADC.

**Unknown:** Can ADC sandboxes run MCP servers as sidecar processes? Do egress rules allow the necessary API calls?

**Testing plan:**
1. Create ADC sandbox → install Node.js → run `squad-mcp` server → verify gRPC connectivity
2. Test Bitwarden agent-access MCP (requires E2E tunnel back to trusted device)
3. Test egress to GitHub API, Azure Management API, Kusto endpoints

**Next step:** Anirudh walkthrough should cover sandbox networking model.

### Blocker 3: DTS Availability and API Access

**Impact:** Blocks event-driven orchestration (section 1b) and Demo 1.

**Current state:** No public API documentation. Internal Microsoft tool.

**Next step:** Schedule DTS API walkthrough with Anirudh. Key questions:
- What's the DTS API surface? (queue CRUD, task lifecycle, webhook callbacks)
- Is there a DTS SDK or is it REST-only?
- Can DTS trigger on GitHub webhook events directly?
- What's the auth model? (Entra token, API key, managed identity)

### Blocker 4: Dapr Agents Language Gap

**Impact:** Dapr Agents is Python-only. Squad is Node.js/TypeScript. No direct integration path today.

**Options:**
1. **Bridge pattern (recommended):** Dapr sidecar handles orchestration (pub/sub, state, workflows). Squad agents remain TypeScript containers. Dapr invokes them via HTTP/gRPC service-to-service calls. The "glue" is a thin Python Dapr Agent that delegates to TypeScript containers.
2. **TypeScript Dapr SDK:** Dapr has a JavaScript SDK for basic building blocks (pub/sub, state, bindings) but NOT for the Agents framework (workflows, virtual actors). Could build a partial integration.
3. **Wait:** .NET/Go Dapr Agents SDKs announced but no timeline. TypeScript not mentioned.

**Next step:** Build a bridge-pattern prototype — Python Dapr Agent "Ralph-bridge" that watches pub/sub and invokes TypeScript Squad agents via HTTP.

### Open Question: Ramaprakash's Scoping Guidance

**Context:** "Clusters should be scoped to single service tree leaf nodes." This means Squad should have its own dedicated cluster, not share with other workloads.

**Implication for AKS path:** The current `squad-aks` deployment may need its own cluster (not a namespace in a shared cluster). This affects cost — a dedicated AKS cluster has a minimum baseline cost even at Standard Free tier.

**Implication for ADC path:** ADC sidesteps this entirely — sandboxes are inherently isolated. No cluster scoping needed.

---

## 5. Prioritized Next Steps

| # | Action | Owner | Depends On | Target |
|---|---|---|---|---|
| 1 | **Schedule DTS API walkthrough with Anirudh** | Tamir | — | This week |
| 2 | **Extract KEDA Copilot Scaler to standalone repo** | Data | — | This week |
| 3 | **Record Demo 3 (KEDA auto-scaling)** | Seven | #2 | Next week |
| 4 | **File IT ticket for Agent Identity admin consent** | Worf | — | This week |
| 5 | **Test MCP server in ADC sandbox** | Belanna | #1 (networking info) | After walkthrough |
| 6 | **Build Dapr Agents bridge-pattern prototype** | Data | Dapr on AKS cluster | 2 weeks |
| 7 | **Sync squad-on-aks public repo** with latest Helm charts | Belanna | — | This week |
| 8 | **Submit KEDA scaler to external scaler catalog** | Tamir | #2 | After extraction |
| 9 | **Build ADC ephemeral agent demo (Demo 1)** | Belanna + Data | #1, #5 | After DTS access |
| 10 | **Draft Azure Architecture Center submission** | Seven | #7 | 3 weeks |

---

## 6. Summary: What to Say When Asked

**"What's Squad doing with ADC?"**
> We're evaluating ADC as ephemeral compute for task agents — sandboxes that spin up per-issue, do the work, and auto-destroy. Combined with DTS for queue-based orchestration, this replaces our CronJob polling pattern with event-driven dispatch. We're scheduling a DTS API walkthrough with the ADC team.

**"What's Squad doing with K8s?"**
> Squad already runs in production on AKS with pod-per-agent Helm charts, KEDA autoscaling, and Workload Identity. We've built a KEDA external scaler that's rate-limit-aware — it only scales agents when work exists AND API headroom allows. We're extracting it as an open-source tool for the KEDA community. Next: Dapr Agents integration for durable workflows and scale-to-zero.

**"What should I look at first?"**
> The KEDA Copilot Scaler demo — it's working today, it's novel (rate-limit-aware autoscaling for AI agents), and it's a clean 5-minute story.

---

*Last updated: 2026-07-14 by Seven*
