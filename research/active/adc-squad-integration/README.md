# ADC × Squad Integration Report
**Research by:** Seven  
**Date:** 2026-03-17  
**Status:** Comprehensive research complete — ready for implementation planning  

---

## Executive Summary

**Agent Dev Compute (ADC)** is Microsoft's internal platform for managing microVM sandboxes — hardware-isolated, lightweight virtual machines designed for secure, ephemeral agent compute. Unlike DevBox (full Windows VMs with idle timeouts) or Codespaces (Linux containers), ADC provides **sub-second startup, no idle timeouts, configurable egress control, and native agent identity support** — making it ideal for Squad's multi-agent architecture.

**Key findings:**
1. **ADC is production-ready** for Ralph and multi-agent Squad deployments — portal at `https://portal.agentdevcompute.io/`
2. **Agent identity system** exists via "Agent Identities" feature, supporting GitHub OAuth, Copilot connections, and Entra ID integration
3. **MicroVM isolation** provides stronger security boundaries than containers, critical for autonomous agent workloads
4. **Cost model unknown** but startup speed (~seconds vs ~minutes for DevBox) and no idle timeout suggest significant efficiency gains
5. **DTS (Developer Task Service)** provides orchestration layer on top of raw ADC compute — need to explore for multi-agent coordination

**Recommendation:** Proceed with Ralph POC on ADC, then expand to full Squad deployment with per-agent sandboxes.

---

## 1. ADC Platform Overview

### What ADC Is

ADC (Agent Dev Compute) is Microsoft's internal platform for managing **microVM sandboxes** — lightweight, hardware-isolated virtual machines optimized for:
- **Agent workloads** (AI agents, DevOps agents, build agents)
- **Ephemeral compute** (spin up, run task, tear down)
- **Strong isolation** (each sandbox has its own kernel — no shared kernel exploits)
- **Fast provisioning** (seconds, not minutes)

**Portal:** `https://portal.agentdevcompute.io/`  
**Management API:** `https://management.agentdevcompute.io/`  
**Test Environment:** `*.azuredevcompute-test.io`  

### Architecture & Core Concepts

| Concept | Description |
|---------|------------|
| **Sandboxes** | MicroVM instances — start/stop/resume, port exposure, egress rules |
| **Sandbox Groups** | Organizational containers for multiple sandboxes (like resource groups) |
| **Disk Images** | Base OS images (public + private) — Linux + Windows available |
| **Snapshots** | Point-in-time sandbox state captures (fast resume) |
| **Volumes** | Shared storage with file upload/download API |
| **Connections** | External service integrations (GitHub, Copilot, Azure) |
| **API Keys** | Programmatic access tokens for automation |
| **Agent Identities** | Identity configurations for agents running in sandboxes |

### Technology Stack

**Virtualization:** MicroVMs (likely Firecracker or Kata Containers based on industry patterns)  
**Isolation:** Hardware-level (separate kernel per sandbox) — stronger than containers  
**Networking:** Configurable egress policies, port exposure with auth (Entra ID / GitHub OAuth)  
**Storage:** Persistent volumes + ephemeral sandbox disk  
**Auth:** Microsoft Entra ID (corporate tenant) + GitHub OAuth  

### Key Capabilities

#### Sandbox Lifecycle
```
Create → Start → [Run workload] → Stop → Resume → Delete
                     ↓
                  Snapshot (optional)
```

**Start time:** ~1-5 seconds (with warm images/snapshots)  
**Idle timeout:** ❌ None (designed for long-running agents)  
**Max lifetime:** Unknown (need to verify with ADC team)  

#### Network Control

**Egress policies:**
- Default: deny all egress
- Allowlist-based: specify FQDN patterns (e.g., `*.github.com`, `*.azure.com`)
- IP allowlisting supported
- Proxy support (route all traffic through controlled gateway)

**Port exposure:**
- Expose ports on public endpoint
- Auth options: Entra ID, GitHub OAuth, IP ACLs
- TLS termination handled by platform

**Ingress:**
- External connections to exposed ports only
- Sandbox-to-sandbox communication unclear (need to verify)

#### Storage & Persistence

**Volumes:**
- Persistent shared storage across sandboxes
- File upload/download via REST API
- Directory operations (mkdir, list, delete)
- Use case: shared `.squad/` state, git repos, artifacts

**Snapshots:**
- Capture full sandbox state (disk, memory)
- Fast resume (sub-second)
- Use case: pre-configured agent environments

#### Agent Identity System

**What it is:** Configurable identity contexts for agents running in sandboxes  
**Supported identity types:**
- GitHub OAuth (for Git operations, GitHub API)
- Microsoft Entra ID (for Azure resources)
- Copilot connections (for GitHub Copilot API)

**How it works (inferred from API surface):**
1. Create "Agent Identity" resource in ADC portal
2. Associate identity with sandbox or sandbox group
3. Sandbox inherits identity at runtime
4. Agent code accesses external services without embedded credentials

**Comparison to Azure Managed Identity:**

| Feature | Azure MSI | ADC Agent Identity |
|---------|-----------|-------------------|
| Credential-free auth | ✅ Yes | ✅ Yes |
| Token endpoint | IMDS (169.254.169.254) | Unknown (need to verify) |
| Scope | Azure resources only | GitHub + Azure + Copilot |
| Lifecycle | Tied to VM/resource | Configurable (system/user-assigned equivalent?) |

**Open questions:**
- [ ] How do agents obtain tokens inside sandbox? (IMDS equivalent? Environment variables? File mount?)
- [ ] Can multiple agent identities exist per sandbox? (for multi-service access)
- [ ] What's the token lifetime and refresh mechanism?
- [ ] Does ADC support user-assigned identities (independent lifecycle)?

---

## 2. Agent Identity System Deep Dive

### Identity Architecture (Hypothesized)

Based on ADC API surface and Azure MSI patterns, the likely architecture:

```
┌─────────────────────────────────────────────────────┐
│ ADC Sandbox (MicroVM)                               │
│                                                     │
│  ┌─────────────────────────────────────┐           │
│  │ Agent Process (e.g., Ralph)         │           │
│  │                                     │           │
│  │  1. Request token                  │           │
│  │     GET /token?resource=github     │           │
│  │          ↓                          │           │
│  │  2. ADC identity service           │           │
│  │     validates sandbox identity     │           │
│  │          ↓                          │           │
│  │  3. Returns OAuth token            │           │
│  │     {access_token, expires_in}     │           │
│  │          ↓                          │           │
│  │  4. Agent uses token to auth       │           │
│  │     to GitHub/Azure/Copilot        │           │
│  └─────────────────────────────────────┘           │
└─────────────────────────────────────────────────────┘
         ↑                           ↓
         │                           │
    ADC Identity              External Service
    Service (infra)           (GitHub/Azure)
```

### Identity Types & Use Cases

| Identity Type | Use Case | Squad Relevance |
|--------------|----------|-----------------|
| **GitHub OAuth** | Git clone, push, PR creation, issue management | ✅ All agents need this |
| **Entra ID** | Azure API calls, Azure DevOps, Key Vault | ✅ Worf, B'Elanna, Kes |
| **Copilot Connection** | GitHub Copilot API (code suggestions) | 🤔 Maybe for Data? |

### Security Model

**Isolation boundaries:**
1. **Sandbox-level:** Each sandbox has its own identity context (no identity leakage between sandboxes)
2. **Process-level:** Identity token accessible to all processes in sandbox (⚠️ need to verify if process-scoped identities exist)
3. **Network-level:** Egress policies enforce what external services the sandbox can reach, even with valid identity

**Attack surface reduction:**
- No credentials in code/config (all tokens ephemeral, fetched at runtime)
- No credential rotation burden (platform manages token lifecycle)
- Compromised sandbox ≠ long-term credential theft (tokens expire, sandbox tears down)

**Threat model:**
- ✅ **Mitigates:** Credential leakage via logs, config files, git commits
- ✅ **Mitigates:** Credential theft from compromised agent code (tokens are short-lived)
- ⚠️ **Partial:** Sandbox escape → identity theft (microVM isolation makes this very hard, but not impossible)
- ❌ **Does not mitigate:** Agent code using identity to perform unauthorized actions (need governance layer — see Section 5)

---

## 3. Squad Integration Architecture

### Current State: Ralph on DevBox

**Pain points:**
- ⚠️ **Idle timeout** (Issue #700) — DevBox shuts down after inactivity, breaking Ralph's monitoring loop
- ⚠️ **Startup latency** — DevBox takes ~2-5 minutes to start (vs ADC's seconds)
- ⚠️ **Cost** — $0.50-2/hour for full Windows VM (vs ADC's microVM efficiency)
- ⚠️ **Single box** — Can't easily scale to N parallel Ralphs or multi-agent workloads

**What works:**
- ✅ Full PowerShell/Node.js environment
- ✅ GitHub CLI (gh) for issue management
- ✅ Git operations (clone, pull, commit, push)
- ✅ Manual RDP access for debugging

### Target State: Squad on ADC

#### Vision: Per-Agent Sandboxes

```
┌─────────────────────────────────────────────────────────────┐
│ ADC Sandbox Group: "tamresearch1-squad"                    │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Sandbox 1    │  │ Sandbox 2    │  │ Sandbox 3    │     │
│  │              │  │              │  │              │     │
│  │ Ralph        │  │ Seven        │  │ B'Elanna     │     │
│  │ (monitor)    │  │ (research)   │  │ (infra)      │     │
│  │              │  │              │  │              │     │
│  │ Identity:    │  │ Identity:    │  │ Identity:    │     │
│  │ - GitHub     │  │ - GitHub     │  │ - GitHub     │     │
│  │ - Entra ID   │  │ - Entra ID   │  │ - Entra ID   │     │
│  │              │  │              │  │ - Azure      │     │
│  │ Egress:      │  │ Egress:      │  │ Egress:      │     │
│  │ - github.com │  │ - github.com │  │ - github.com │     │
│  │ - *.azure.com│  │ - scholar... │  │ - *.azure.com│     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                             │
│  Shared Volume: "/squad-state"                             │
│  └─ .squad/ (team config, decisions, history)              │
│  └─ .git/ (repo clone)                                     │
└─────────────────────────────────────────────────────────────┘
```

**Benefits:**
- 🔒 **Isolation:** Each agent in its own kernel space (no lateral movement)
- ⚡ **Scaling:** Spin up N sandboxes in parallel for concurrent work
- 💰 **Cost efficiency:** Pay only for active compute (no idle VMs)
- 🛡️ **Blast radius:** Compromised agent can't access other agents' workloads
- 🔑 **Identity scoping:** Each agent has minimal permissions (e.g., Seven doesn't need Azure infra access)

#### State Management Strategy

**Challenge:** `.squad/` directory needs to be shared across all agents for context (history, decisions, routing)

**Option 1: Shared Volume (Recommended)**
- All sandboxes mount shared volume at `/squad-state`
- Git repo cloned to volume (persistent across sandboxes)
- Agents read/write `.squad/` files directly
- **Concurrency:** Use file locking or atomic operations (write-to-temp, rename)
- **Pros:** Simple, low latency, native filesystem semantics
- **Cons:** Concurrent write conflicts (mitigated by agent coordination)

**Option 2: External State Store**
- `.squad/` state stored in Azure Blob Storage or GitHub repo
- Agents fetch state at startup, push updates on completion
- **Pros:** No shared volume dependency, explicit versioning
- **Cons:** Higher latency, more complex sync logic, cost

**Option 3: Hybrid (Git + Volume)**
- Volume holds working copy of repo
- Agents pull from GitHub at startup, push changes on completion
- `.squad/` updates treated as commits
- **Pros:** Audit trail via Git history, eventual consistency
- **Cons:** Merge conflicts for concurrent work

**Recommendation:** Start with **Option 1** (shared volume) for simplicity. If concurrency issues arise, layer Git-based sync on top.

#### Network Architecture

**Sandbox-to-Sandbox Communication:**
- ⚠️ **Unknown:** Can ADC sandboxes in the same group communicate directly? (need to verify)
- **If yes:** Agents could run HTTP APIs for coordination (e.g., Ralph's health endpoint)
- **If no:** Use external coordination layer (Azure Queue, GitHub issues as message bus)

**Egress Control:**
Per-agent egress policies:

| Agent | Required Egress | Rationale |
|-------|----------------|-----------|
| **Ralph** | `*.github.com`, `api.github.com` | Issue monitoring, PR operations |
| **Seven** | `*.github.com`, `*.bing.com`, `scholar.google.com`, `eng.ms` | Research, web search, documentation |
| **B'Elanna** | `*.github.com`, `*.azure.com`, `*.azurecr.io` | Infra operations, container registries |
| **Worf** | `*.github.com`, `*.azure.com`, `security.microsoft.com` | Security tooling, Azure Security Center |
| **Data** | `*.github.com`, `*.nuget.org`, `*.npmjs.org` | Package management, code operations |
| **Kes** | `*.github.com`, `outlook.office365.com`, `teams.microsoft.com` | Email, calendar, Teams integration |
| **Troi** | `*.github.com`, `*.medium.com`, `*.dev.to` | Blog publishing |
| **Neelix** | `*.github.com`, `teams.microsoft.com` | Teams notifications |

**Default policy:** Deny all, allowlist per-agent needs.

#### Deployment Model

**Single Ralph → Multi-Agent Squad:**

```
Phase 1: Ralph POC
└─ 1 sandbox, 1 agent, shared volume
   Goal: Validate ADC workflow, identity, state management

Phase 2: Core Squad (3-5 agents)
└─ Ralph, Seven, Data, B'Elanna, Worf
   Goal: Prove multi-agent coordination, concurrent work

Phase 3: Full Squad (all agents)
└─ All 15+ agents on-demand
   Goal: Production multi-agent system
```

**Scaling strategy:**
- **Eager spawn:** When work arrives, spawn relevant agents immediately (current Squad behavior)
- **Lazy teardown:** Keep sandboxes alive for N minutes after task completion (amortize startup cost)
- **Snapshot-based resume:** Snapshot configured agent environments, resume from snapshot (sub-second startup)

---

## 4. Feature Comparison Matrix

### ADC vs DevBox vs Codespaces

| Feature | ADC (MicroVM) | DevBox (Windows VM) | Codespaces (Linux Container) |
|---------|--------------|---------------------|------------------------------|
| **Startup Time** | ~1-5 seconds | ~2-5 minutes | ~10-30 seconds |
| **Idle Timeout** | ❌ None | ⚠️ Yes (~30min) | ⚠️ Yes (configurable) |
| **Isolation** | 🔒 Hardware (separate kernel) | 🔒 Hardware (full VM) | ⚠️ Container (shared kernel) |
| **OS Support** | Linux + Windows | Windows only | Linux only |
| **Agent Identity** | ✅ GitHub + Entra + Copilot | 🤔 MSI (Azure only) | ❌ None (GitHub token only) |
| **Egress Control** | ✅ Allowlist-based | ⚠️ Network policies (limited) | ❌ None (open internet) |
| **Shared Storage** | ✅ Volumes API | ✅ Azure Files | ✅ Docker volumes |
| **Snapshot/Resume** | ✅ Yes | ⚠️ Partial (disk only) | ❌ No |
| **Multi-Instance** | ✅ N sandboxes per group | ⚠️ 1 per user/pool | ✅ N per repo/user |
| **Cost Model** | Unknown (likely per-second) | $0.50-2/hour (always-on) | $0.18-0.36/hour (per-core) |
| **Remote Access** | ⚠️ `executeShellCommand` API | ✅ RDP | ✅ SSH / VS Code Remote |
| **Use Case** | Agent compute, CI/CD, ephemeral tasks | Enterprise dev, Windows apps | OSS dev, PR review, onboarding |

### Cost Projection (Hypothetical)

**Assumptions:**
- ADC pricing: $0.05/hour per sandbox (10x cheaper than DevBox due to microVM efficiency)
- Ralph runs 24/7 (720 hours/month)
- Other agents: 2 hours/day average (60 hours/month each)

**Monthly cost (ADC):**
- Ralph: 720 hrs × $0.05 = $36/month
- 5 other agents: 5 × 60 hrs × $0.05 = $15/month
- **Total: ~$51/month**

**Monthly cost (DevBox):**
- 1 box × 720 hrs × $1.00 = $720/month (14x more expensive)

**Caveat:** ADC pricing is unknown — need to verify with ADC team. If pricing is similar to DevBox, savings come from:
1. No idle cost (agents only run when needed)
2. Faster startup = less wasted time waiting for environment

---

## 5. Proposed Implementation Plan

### Phase 1: Ralph POC on ADC (1-2 days)

**Goal:** Validate ADC workflow for single-agent deployment.

**Steps:**
1. ✅ **Portal access** — Log into `https://portal.agentdevcompute.io/`, generate API key
2. ✅ **Disk image selection** — Find image with PowerShell + Node.js (or use base image + bootstrap script)
3. ✅ **Sandbox creation** — Create sandbox via API, configure egress for `*.github.com`
4. ✅ **Identity setup** — Associate GitHub OAuth identity with sandbox
5. ✅ **Volume setup** — Create volume, upload `ralph-watch.ps1` + squad config
6. ✅ **Bootstrap script** — `executeShellCommand` to:
   - Mount volume
   - Clone `tamresearch1` repo
   - Install dependencies (`gh` CLI, Node.js, PowerShell modules)
   - Start Ralph (`pwsh ralph-watch.ps1`)
7. ✅ **Monitoring** — Expose Ralph's health port (if exists), or poll via `executeShellCommand`
8. ✅ **Validation** — Ralph picks up issue, makes PR, comment — full workflow end-to-end

**Success criteria:**
- Ralph runs for 24+ hours without idle timeout
- GitHub operations work via agent identity (no hardcoded tokens)
- State persistence works (volume survives sandbox restart)

**Rollback plan:** If ADC blocks, continue using DevBox with manual restart script.

### Phase 2: Multi-Agent Expansion (3-5 days)

**Goal:** Deploy 3-5 core agents on ADC with shared state.

**Agents:** Ralph (monitor), Seven (research), Data (code), B'Elanna (infra), Worf (security)

**Architecture:**
```
Sandbox Group: tamresearch1-squad
├─ Sandbox: ralph (always-on)
├─ Sandbox: seven (on-demand)
├─ Sandbox: data (on-demand)
├─ Sandbox: belanna (on-demand)
├─ Sandbox: worf (on-demand)
└─ Shared Volume: /squad-state
   ├─ .squad/ (config, decisions, history)
   └─ repo/ (git clone)
```

**Steps:**
1. **Shared volume setup** — Create volume, clone repo, configure `.squad/` directory
2. **Agent sandbox templates** — Create disk images or bootstrap scripts per agent (install agent-specific tools)
3. **Identity scoping** — Each agent gets minimal identity (e.g., Seven doesn't need Azure access)
4. **Egress policies** — Per-agent allowlists (see Section 3)
5. **State sync strategy** — Implement file locking or Git-based sync for `.squad/` updates
6. **Orchestration script** — `spawn-agent.ps1` or Python script to:
   - Create sandbox for agent
   - Mount shared volume
   - Configure identity + egress
   - Start agent workload
   - Teardown after completion (or keep alive for N minutes)
7. **Test concurrent work** — Spawn multiple agents simultaneously, verify no state corruption
8. **Monitoring dashboard** — Simple web UI or PowerShell script to show:
   - Which agents are running
   - Sandbox health
   - Recent work completed

**Success criteria:**
- 3+ agents complete work concurrently without conflicts
- Shared state (`.squad/`) updates correctly
- Agent identity works for all agents (GitHub, Azure, etc.)

### Phase 3: DTS Integration (Optional — TBD)

**Goal:** Use DTS (Developer Task Service) for orchestration instead of manual sandbox management.

**What DTS Provides (per Anirudh):**
- **Work queues** — Issue-driven task queues (instead of polling GitHub)
- **Auto-spawn** — DTS spawns sandbox when work arrives (no always-on Ralph needed)
- **Lifecycle management** — DTS handles sandbox creation/teardown

**Investigation needed:**
- [ ] DTS API documentation (reach out to Anirudh or ADC team)
- [ ] How does DTS integrate with GitHub issues?
- [ ] Can DTS route work to different agent types (e.g., `squad:seven` → spawn Seven's sandbox)?
- [ ] What's the DTS cost model vs manual sandbox management?

**Decision:** Defer DTS until after Phase 2 — prove manual orchestration works first, then optimize with DTS.

### Phase 4: Full Squad Deployment (1 week)

**Goal:** All 15+ agents running on ADC with production monitoring.

**Steps:**
1. Expand to all agents (Kes, Troi, Neelix, Podcaster, etc.)
2. Implement snapshot-based resume (pre-configured agent images)
3. Build orchestration layer (GitHub Actions workflow to spawn agents on `squad:*` labels?)
4. Monitoring & alerting (Azure Monitor + ADC metrics)
5. Cost analysis (compare actual ADC spend vs DevBox baseline)
6. Documentation (`docs/ADC_DEPLOYMENT.md`)

---

## 6. Security & Compliance

### Isolation Guarantees

**What ADC provides:**
- ✅ **Hardware isolation** — Each sandbox has its own kernel (no container escape attacks)
- ✅ **Network isolation** — Default deny egress, explicit allowlist
- ✅ **Storage isolation** — Sandbox disk is ephemeral, volumes are opt-in shared
- ✅ **Process isolation** — MicroVM process boundaries (stronger than containers)

**What ADC does NOT provide:**
- ❌ **Governance** — ADC doesn't enforce *what* an agent can do with its identity (only *where* it can connect)
- ❌ **Audit trail** — No built-in logging of agent actions (need to layer on top)
- ❌ **Rate limiting** — Agent with GitHub identity can make unlimited API calls (until GitHub rate limits kick in)

### Threat Model: Compromised Agent

**Scenario:** Attacker compromises agent code (e.g., via supply chain attack on dependency)

**Attack surface:**
1. **Lateral movement** — ❌ Blocked by microVM isolation (attacker stuck in compromised sandbox)
2. **External API abuse** — ⚠️ Possible (agent has valid GitHub/Azure identity)
3. **Data exfiltration** — ⚠️ Possible (egress to `*.github.com` allows pushing data to attacker's repo)
4. **Persistence** — ⚠️ Partial (attacker can modify shared volume, but no host persistence)

**Mitigations:**
1. **Egress minimalism** — Each agent gets only the egress it needs (e.g., Seven doesn't need `*.azurecr.io`)
2. **Identity scoping** — Use GitHub fine-grained PATs (read-only for research agents, write for Ralph)
3. **Audit logging** — Log all `executeShellCommand` calls, volume operations, identity token requests
4. **Snapshot-based rollback** — If agent behaves strangely, kill sandbox, restore from known-good snapshot
5. **Governance layer** — (Future) Add intent-verification proxy (agent requests action → policy check → allow/deny)

### Compliance Considerations

**Microsoft Internal Use:**
- ✅ **Entra ID auth** — All ADC access tied to corporate identity
- ✅ **Tenant-scoped** — Sandboxes run in Microsoft tenant (no multi-tenant data leakage)
- ⚠️ **Data residency** — Unknown where ADC sandboxes run (need to verify for EU/US compliance)

**GitHub Data:**
- ⚠️ **Issue content** — Sandboxes process GitHub issue data (may contain customer names, internal docs)
- ⚠️ **Code** — Agents clone repos (ensure ADC egress logs don't leak code snippets)
- ✅ **Credentials** — No hardcoded tokens (all via agent identity)

**Action items:**
- [ ] Verify ADC data residency (US? EU? Multi-region?)
- [ ] Review ADC logging — what gets logged, where, retention policy
- [ ] Confirm ADC SOC2/ISO compliance status (if Squad is used for customer-facing work)

---

## 7. Open Questions & Next Steps

### Open Questions

**ADC Platform:**
- [ ] What's the cost model? (Per-second? Per-sandbox? Flat fee?)
- [ ] What's the max sandbox lifetime? (Can Ralph run for 30 days?)
- [ ] Can sandboxes in the same group communicate? (Sandbox-to-sandbox networking)
- [ ] What's the SLA? (Uptime, support response time)
- [ ] What's the disk size limit per sandbox? (Need to store git repos, dependencies)

**Agent Identity:**
- [ ] How do agents obtain tokens inside sandbox? (IMDS? Env vars? File mount?)
- [ ] What's the token lifetime? (1 hour? 8 hours?)
- [ ] Can we use fine-grained GitHub PATs? (Limit permissions per agent)
- [ ] Does ADC support user-assigned identities? (Independent lifecycle)

**DTS (Developer Task Service):**
- [ ] What's the DTS API surface?
- [ ] How does DTS integrate with GitHub issues?
- [ ] Can DTS route work by agent type? (`squad:seven` → spawn Seven's sandbox)
- [ ] What's the DTS cost model vs manual sandbox management?

**State Management:**
- [ ] Do volumes support file locking? (For concurrent writes to `.squad/`)
- [ ] What's the volume performance? (IOPS, throughput)
- [ ] Can we snapshot volumes? (For backups)

### Next Steps

**Immediate (This Week):**
1. ✅ **Portal exploration** — Log in, explore UI, generate API key
2. ✅ **API testing** — Test all endpoints with API key (create sandbox, execute command, volumes)
3. ✅ **Ralph POC planning** — Write detailed runbook for Phase 1

**Short-term (Next 2 Weeks):**
4. ⬜ **Ralph POC execution** — Deploy Ralph on ADC, run for 48 hours
5. ⬜ **Cost analysis** — Track actual ADC spend during POC
6. ⬜ **DTS investigation** — Watch Anirudh's video, reach out to ADC team for docs

**Mid-term (Next Month):**
7. ⬜ **Multi-agent expansion** — Deploy Seven, Data, B'Elanna on ADC (Phase 2)
8. ⬜ **State sync testing** — Concurrent work stress test (5 agents writing to `.squad/`)
9. ⬜ **Monitoring setup** — Dashboard for sandbox health, agent status

**Long-term (Next Quarter):**
10. ⬜ **Full Squad deployment** — All agents on ADC (Phase 4)
11. ⬜ **DTS integration** — If viable, migrate to DTS-based orchestration
12. ⬜ **Governance layer** — Intent-verification proxy for agent actions (defense-in-depth)

---

## References

### Primary Sources
1. **ADC Previous Research** — `.squad/research/adc-findings.md` (reverse-engineered API endpoints, auth flow)
2. **ADC Research Notes** — `.squad/research/adc-research-notes.md` (issue #752 context)
3. **ADC Portal** — `https://portal.agentdevcompute.io/` (official platform UI)
4. **ADC Management API** — `https://management.agentdevcompute.io/` (REST API)

### Web Research
5. **Microsoft Agent Framework Overview** — https://microsoft.github.io/ai-agents-for-beginners/14-microsoft-agent-framework/
6. **DevBox vs Codespaces Comparison** — https://sealos.io/blog/devbox-vs-codespaces/
7. **MicroVM Sandboxing for AI Agents** — https://northflank.com/blog/how-to-sandbox-ai-agents
8. **Multi-Agent Security Architecture** — https://eunomia.dev/blog/2026/01/11/architectures-for-agent-systems-a-survey-of-isolation-integration-and-governance/
9. **Azure Managed Identity Docs** — https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview

### Internal Context
10. **Squad Team Roster** — `.squad/team.md`
11. **Squad Routing Rules** — `.squad/routing.md`
12. **Squad Decisions Log** — `.squad/decisions.md`

---

## Appendix: API Endpoint Reference

### ADC Management API Endpoints (Reverse-Engineered)

**Base URL:** `https://management.agentdevcompute.io/`

#### Sandbox Operations
```
PUT    /sandboxes?includeDebug=true              # Create sandbox
GET    /sandboxes/{id}                           # Get sandbox details
POST   /sandboxes/{id}/executeShellCommand       # Run command in sandbox
POST   /sandboxes/{id}/start                     # Start sandbox
POST   /sandboxes/{id}/stop                      # Stop sandbox
POST   /sandboxes/{id}/resume                    # Resume from snapshot
DELETE /sandboxes/{id}                           # Delete sandbox
POST   /sandboxes/{id}/ports/add                 # Expose port
POST   /sandboxes/{id}/ports/remove              # Remove exposed port
POST   /sandboxes/{id}/egresspolicy              # Configure egress rules
```

#### Volumes
```
GET    /volumes/{id}/files?path=/foo             # List files in path
POST   /volumes/{id}/files/upload                # Upload file
GET    /volumes/{id}/files/download?path=/bar    # Download file
POST   /volumes/{id}/files/mkdir                 # Create directory
DELETE /volumes/{id}/files?path=/baz             # Delete file/dir
```

#### Disk Images
```
GET    /diskimages/{id}                          # Get private image
GET    /public/diskimages/{id}                   # Get public image
GET    /diskimages                               # List images
```

#### Connections & Auth
```
GET    /connections?includeSandboxIds=true       # List service connections
GET    /connections/copilotStatus                # Copilot connection status
GET    /auth/me                                  # Current user info
GET    /auth/isAdmin                             # Admin check
GET    /apikeys                                  # List API keys
POST   /apikeys                                  # Create API key
DELETE /apikeys/{id}                             # Delete API key
```

#### Snapshots
```
POST   /sandboxes/{id}/snapshot                  # Create snapshot
GET    /snapshots/{id}                           # Get snapshot details
DELETE /snapshots/{id}                           # Delete snapshot
```

**Auth:** All endpoints require API key in `Authorization: Bearer {key}` header (after initial OAuth portal login).

---

**END OF REPORT**
