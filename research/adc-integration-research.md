# ADC Integration Research — Squad Infrastructure Analysis
**Issue:** #1064 | **Author:** B'Elanna (Infrastructure Expert) | **Date:** 2026-03-20
**Relates to:** #752 (POC: Run Ralph on ADC)

---

## Executive Summary

- **ADC replaces K8s entirely for Squad's compute needs.** MicroVM sandboxes with no idle-timeout, configurable egress, and native GitHub/Copilot connections cover everything Squad currently gets from AKS — without a cluster to manage.
- **Session state is a non-issue.** Squad's git-centric model (`.squad/decisions.md`, inbox, research files) maps perfectly to ADC's ephemeral sandboxes: every session starts with `git pull`, ends with `git push`. No PersistentVolumes, no StatefulSets, no etcd.
- **MCP compatibility is the single hard gate.** All other questions have clear answers. MCP server startup inside an ADC sandbox must be verified in the #752 POC before any deployment investment. If MCP works, ADC becomes Squad's primary compute target.

---

## Background: What ADC + DTS Are

| Component | Description |
|-----------|-------------|
| **ADC** — Agent Dev Compute | Microsoft's managed microVM platform for AI agents. Portal at `portal.agentdevcompute.io`, REST API at `management.agentdevcompute.io`. Hardware-isolated sandboxes with configurable networking. |
| **DTS** — Developer Task Service | Orchestration layer on top of ADC. Creates task queues and spawns ADC sessions on demand. The "serverless" layer — you submit work, DTS provisions the sandbox. |
| **Sandboxes** | MicroVM instances. Start/stop/resume. Port exposure with Entra/GitHub auth. Configurable egress policies. |
| **Volumes** | Shared storage. File upload/download, mkdir, list via REST API. Survives sandbox stop/resume. |
| **Connections** | First-class GitHub and Copilot connections built into the platform. |
| **Snapshots** | Point-in-time state captures for sandbox persistence. |

**Auth:** Entra token works (`az account get-access-token --resource 8bdf6603-4e80-4b34-856c-4ee02dfe8df3`), but the management API uses cookie-based sessions. Programmatic access requires an API key generated via the portal.

---

## Key Questions

### Q1: Can `squad deploy --target adc` be a first-class option?

**Yes. Recommended as the primary deployment path.**

ADC is a better fit for Squad than K8s/AKS in almost every way:

| Dimension | K8s/AKS | ADC |
|-----------|---------|-----|
| Infrastructure ownership | You manage cluster, nodes, upgrades | Zero — Microsoft managed |
| Agent lifecycle | Deployment + CronJob YAML | `PUT /sandboxes` + `POST /executeShellCommand` |
| Scaling | HPA, node pools | Spin up N sandboxes via DTS |
| Networking | Ingress controller, Services, NetworkPolicy | Egress policies + port exposure per sandbox |
| Storage | PersistentVolumeClaims | Git repo (for state) + Volumes API (for files) |
| DK8S dependency | Yes — tenant, ConfigGen, ArgoCD | None |

`squad deploy --target adc` would:
1. Authenticate to ADC management API (API key from portal)
2. Create a sandbox group for the Squad
3. Upload agent scripts via volumes API
4. Configure egress (GitHub, Copilot endpoints)
5. Execute `ralph-watch.ps1` or equivalent via `executeShellCommand`
6. Optionally expose a health port for monitoring

The implementation is simpler than the K8s Helm chart (`infrastructure/helm/squad-agents/`) — no ConfigGen C# code, no ArgoCD, no DK8S tenant needed.

---

### Q2: How does Squad state persist across ADC sessions?

**Not a problem. Squad state already lives in git.**

Squad's state model is an accidental advantage for ADC:

```
ADC Session starts:
  git clone/pull https://github.com/tamirdresher_microsoft/tamresearch1
  → reads .squad/decisions.md
  → reads .squad/routing.md
  → reads inbox files

Agent does work...

ADC Session ends / is stopped:
  git add .
  git commit -m "..."
  git push
  → state preserved in git
```

No PersistentVolumes needed. No StatefulSets. No database. The git repo IS the persistent store.

For larger files (audio, PDFs, research artifacts), ADC Volumes provide sandbox-level storage. These can be mounted across sessions if needed.

**Snapshots** can capture full VM state for expensive-to-rebuild sandboxes (e.g., one with all MCP servers pre-installed).

| State type | Where it lives | ADC strategy |
|------------|---------------|--------------|
| Squad decisions, routing, inbox | Git | `git pull` on start, `git push` on end |
| Research docs, reports | Git | Same |
| Large binary files (audio, PDFs) | ADC Volumes | Upload/download via volumes API |
| MCP server state | Ephemeral in session | Re-connect on each session start |
| Agent identity / auth tokens | ADC Connections (GitHub, Copilot) | Configured once in portal |

---

### Q3: Cost model — ADC vs AKS for 24/7 Squad operation

**ADC is likely cheaper. AKS baseline cost is high; ADC is consumption-based.**

AKS cost floor for Squad:
- Minimum: 2 × Standard_D2s_v3 nodes = ~$140/month (always-on)
- With system nodepool + agent nodepool: ~$200-300/month
- Plus: load balancer, managed disks, egress — **~$250-400/month total**
- Plus: DK8S onboarding overhead (ConfigGen, ArgoCD, engineer time)

ADC cost model (from issue #752 research — ADC pricing not yet public):
- Consumption-based: pay per sandbox-second
- Sandboxes can be **stopped** when agents are idle (vs always-on K8s nodes)
- MicroVMs are lighter than full K8s nodes

**Estimated comparison:**

| Scenario | AKS | ADC |
|----------|-----|-----|
| 24/7 always-on Squad (3 agents) | ~$280/month | ~$80-150/month (est.) |
| Business hours only (8h/day) | ~$280/month (nodes run 24/7) | ~$25-50/month (est.) |
| Burst scaling (10 agents) | ~$600+/month | ~$200-300/month (est.) |
| Zero-ops overhead | ❌ High (DK8S, ConfigGen) | ✅ None |

> **Note:** ADC pricing is not yet publicly documented. The #752 POC must include cost measurement. These estimates assume ADC pricing is comparable to Azure Container Instances (~$0.0001/vCore/sec).

**AKS wins nothing here.** The only reason to keep AKS would be if ADC has a hard limitation (e.g., no MCP support), which is the gate condition in Q5.

---

### Q4: Can each Squad agent be a separate ADC session? Or whole Squad in one?

**Separate sessions per agent is the right architecture. DTS enables this.**

**Option A — One sandbox per agent (recommended):**
```
DTS Queue: squad-tasks
  ├── Task: picard-review-pr-456  → ADC sandbox #1 (Picard agent)
  ├── Task: belanna-helm-fix      → ADC sandbox #2 (B'Elanna agent)
  ├── Task: ralph-watch           → ADC sandbox #3 (persistent Ralph)
  └── Task: seven-research-1064  → ADC sandbox #4 (Seven agent)
```
- Independent failure domains
- Scale out: N parallel tasks = N sandboxes
- Ralph can run in a persistent sandbox; task agents are ephemeral (spun up by DTS, terminated when done)

**Option B — One monolithic sandbox:**
- All agents share one VM
- Simpler but no isolation, no independent scaling
- Same as running on a DevBox — defeats the purpose

**Recommended hybrid:**
- **Ralph**: persistent ADC sandbox (long-running, monitors issues/PRs via `ralph-watch.ps1`)
- **Task agents (Picard, B'Elanna, Seven, etc.)**: ephemeral ADC sandboxes spun up by DTS per task, terminated on completion
- **Coordinator**: runs inside the Ralph sandbox or as a lightweight DTS dispatcher

This matches DTS's design intent: "DTS creates queues and spawns work on your behalf."

```
┌─────────────────────────────────────────────────────┐
│                    DTS Layer                         │
│  squad-tasks queue → spawn sandbox → run → terminate │
└──────────────────────┬──────────────────────────────┘
                       │ spawns
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │  Ralph   │  │  Picard  │  │ B'Elanna │  ... task agents
  │ sandbox  │  │ sandbox  │  │ sandbox  │
  │(persist) │  │(ephemeral│  │(ephemeral│
  └──────────┘  └──────────┘  └──────────┘
         │             │             │
         └─────────────┴─────────────┘
                       │ git push/pull
                       ▼
              ┌─────────────────┐
              │  GitHub Repo    │
              │ (Squad state)   │
              └─────────────────┘
```

---

### Q5: Are MCP servers available in ADC's sandboxed environment?

**Unknown — this is the single hard gate. Must be validated in #752 POC.**

What we know:
- ADC sandboxes run Linux-based microVMs with configurable egress
- MCP servers (e.g., `github`, `azure-devops`) run as local processes inside the agent environment
- **The question is whether Node.js/npm packages can be installed and run inside an ADC sandbox**

What needs to be tested (from the #752 POC):

| Test | Command | Pass Criteria |
|------|---------|---------------|
| Node.js available | `node --version` | Returns version |
| npm install works | `npm install -g @github/mcp-server` | Installs successfully |
| MCP server starts | `npx @github/mcp-server` | Process starts, no sandbox policy block |
| MCP connects to Copilot CLI | Start agent + tool call | Tool response received |
| Egress to GitHub | `curl https://api.github.com` | 200 OK (with egress policy configured) |

**If MCP works:** ADC becomes Squad's primary compute target → implement `squad deploy --target adc`.
**If MCP blocked:** ADC is limited to git-only agents (Ralph-style watch loops, no Copilot CLI tools) → ADC is useful for scaling but not for full Squad agents.

**Mitigation if MCP is blocked:** Request ADC egress policy for `*.npmjs.com` and file an issue with the ADC team to support MCP server tooling. MicroVMs should be configurable enough to allow this.

---

### Q6: GitHub API access in ADC?

**Supported via ADC Connections. Token management handled by the platform.**

From the ADC API research (`.squad/research/adc-findings.md`):
- ADC has first-class **GitHub Connection** support: `/connections?includeSandboxIds=true`
- Connections are configured once in the portal, scoped to sandbox groups
- `copilotStatus` endpoint confirms Copilot connectivity

**Token management strategy:**

| Approach | Pros | Cons |
|----------|------|------|
| ADC GitHub Connection (recommended) | Managed by ADC, no secret storage | Portal setup required; token rotation by ADC |
| GitHub PAT via ADC Volume | Simple, works today | Manual rotation, secret in volume |
| GitHub App installation token | Best for automation | Setup complexity, requires GitHub App |

**Recommended:** Use ADC's built-in GitHub Connection for agent identity. This aligns with ADC's "Agent Identities" concept — agent gets a managed identity scoped to the sandbox, not a human PAT.

For egress, configure sandbox with:
```
POST /sandboxes/{id}/egresspolicy
{
  "allowedHosts": ["*.github.com", "api.github.com", "*.npmjs.com", "*.githubusercontent.com"]
}
```

---

## Architecture: ADC vs Current K8s

### Current State (K8s/AKS)
```
┌─────────────────────────────────────────────────────────────┐
│                    AKS Cluster                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ Ralph CronJob│  │ Picard Deploy│  │ B'Elanna Deploy  │  │
│  │  (values.yaml│  │  (Deployment │  │  (Deployment     │  │
│  │   +ConfigGen)│  │   YAML)      │  │   YAML)          │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
│  Requires: DK8S tenant, ConfigGen C#, ArgoCD, Helm, nginx   │
└─────────────────────────────────────────────────────────────┘
        ↕ PersistentVolumeClaims (or git)
```

### Target State (ADC Primary + DevBox Fallback)
```
┌──────────────────────────────────────────────────────────────┐
│                 DTS (Developer Task Service)                  │
│         Task queue → auto-spawn ADC sandboxes                 │
├──────────────┬──────────────┬──────────────┬─────────────────┤
│ Ralph        │ Picard       │ B'Elanna     │ [Other agents]  │
│ Persistent   │ Ephemeral    │ Ephemeral    │ Ephemeral        │
│ ADC sandbox  │ ADC sandbox  │ ADC sandbox  │ ADC sandbox      │
│              │ (per PR/task)│ (per K8s job)│                  │
├──────────────┴──────────────┴──────────────┴─────────────────┤
│              ADC Volumes (large files, artifacts)             │
├───────────────────────────────────────────────────────────────┤
│   ADC Connections: GitHub ✅  Copilot ✅  (first-class)       │
└───────────────────────────────────────────────────────────────┘
         ↕ git pull/push (all agent state)
┌──────────────────────────────────────────────────────────────┐
│              GitHub Repo (tamresearch1)                       │
│    .squad/decisions.md  .squad/routing.md  inbox/            │
└──────────────────────────────────────────────────────────────┘
         ↕ DevBox fallback for needs:* tasks
┌──────────────────────────────────────────────────────────────┐
│   DevBox / Local  (needs:browser, needs:gpu, needs:whatsapp) │
└──────────────────────────────────────────────────────────────┘
```

---

## Recommendation

**ADC as primary compute target — conditional on MCP POC passing.**

| Option | Description | Verdict |
|--------|-------------|---------|
| **A — ADC Primary** ✅ | Ralph + task agents on ADC; DevBox for `needs:*` tasks | **Recommended** |
| B — ADC Overflow | Ralph stays on DevBox; ADC only for burst scaling | Safe but doesn't solve session persistence |
| C — Keep K8s | AKS/DK8S for Squad | Not recommended — high operational overhead, no benefit over ADC |

**Decision gate:** Complete #752 POC with MCP server compatibility test. If `npx @github/mcp-server` starts inside an ADC sandbox with GitHub egress configured → proceed with ADC primary implementation.

---

## Cost Comparison

| Scenario | K8s (AKS) | ADC | DevBox |
|----------|-----------|-----|--------|
| Infrastructure setup | High (DK8S, ConfigGen) | Zero | Low |
| 24/7 Ralph (persistent) | ~$100/month (node share) | ~$20-40/month est. | ~$60-150/month |
| Per-task agent (1h/day) | Included in node cost | ~$1-5/month est. | N/A (can't scale) |
| 10 parallel agents | ~$600+/month | ~$60-100/month est. | Not practical |
| Idle cost | High (nodes always run) | Zero (sandboxes stop) | Medium |
| Ops cost (engineer time) | High (DK8S expertise) | Zero | Low |

> ADC pricing TBD — cost validation is a required step in #752 POC.

---

## Next Steps

1. **#752 POC first:** Run the five MCP compatibility tests in an ADC sandbox (see Q5 table above).
2. **API key auth:** Log into portal, generate API key, verify it works against all endpoints.
3. **Watch Anirudh's video** on DTS to understand task queue setup and pricing.
4. **If POC passes:** Implement `squad deploy --target adc` script:
   - ADC sandbox creation + egress config
   - Upload `ralph-watch.ps1` via volumes API
   - Execute via `POST /executeShellCommand`
5. **Cost measurement:** Run Ralph on ADC for 1 week, compare actual cost to AKS baseline.
6. **Deprecate K8s Helm chart** (`infrastructure/helm/squad-agents/`) once ADC is stable.

---

## References

- Issue #752: POC: Run Ralph on ADC — https://github.com/tamirdresher_microsoft/tamresearch1/issues/752
- `.squad/research/adc-findings.md` — API endpoint inventory, auth findings
- PR #1085: Picard's architecture analysis — https://github.com/tamirdresher_microsoft/tamresearch1/pull/1085
- ADC Portal: https://portal.agentdevcompute.io/
- ADC Management API: https://management.agentdevcompute.io/
- Anirudh's DTS video: https://microsoft-my.sharepoint-df.com/:v:/p/torosent/IQDzSQG9dfcTQaRmO7gdHoKqAbT3JzVDvFvfaAKdCspY9oU
