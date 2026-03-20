# Squad × DK8S Integration Roadmap

> **Issue:** [#1039](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1039)
> **Author:** Picard (Lead)
> **Date:** 2026-03-20
> **Status:** Proposed
> **Related Issues:** [#1061](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1061) (Squad on DK8S internal), [#1038](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1038) (ConfigGen support), [#1064](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1064) (ADC integration), [#752](https://github.com/tamirdresher_microsoft/tamresearch1/issues/752) (Ralph on ADC)

---

## Executive Summary

Squad is already the DK8S team's operational nervous system — handling issues, writing runbooks, reviewing PRs, and producing research. The next step is to stop running Squad *alongside* DK8S and start running Squad *inside* DK8S as a first-class platform capability.

This roadmap defines three phases: managing DK8S work (Phase 1, nearly complete), running on DK8S clusters (Phase 2), and offering Squad as a platform capability to every DK8S tenant team (Phase 3).

---

## Why Squad + DK8S Is a Natural Fit

The pairing is not accidental. It follows from four structural alignments:

**1. Same team, same context.**  
The DK8S engineering team built the platform and runs it. Squad agents running in the same team repository already know DK8S conventions, tooling, and vocabulary. There is no onboarding gap.

**2. Shared Kubernetes substrate.**  
Squad's target runtime is Kubernetes. DK8S *is* a managed Kubernetes platform. Running Squad on DK8S is the same as running any other workload there — the operational model is identical.

**3. Existing DK8S tooling aligns with Squad's needs.**  
Squad needs: GitOps-driven deployment (ArgoCD ✓), event-driven scaling (KEDA ✓), typed configuration management (ConfigGen ✓), and CI/CD (OneBranch/ADO Pipelines ✓). These are already first-class DK8S platform capabilities.

**4. Dogfooding drives quality.**  
The platform team operating their own tooling is the strongest possible feedback loop. Squad surfacing DK8S platform gaps via real usage is more valuable than any synthetic benchmark.

---

## Current State

Before the phases, a snapshot of where things stand today:

| Capability | Status |
|---|---|
| Squad manages DK8S GitHub issues | ✅ Active — Picard, Belanna, Worf routing issues daily |
| Squad writes runbooks and docs | ✅ Active — see `docs/dk8s-stability-runbook-tier1-consolidated.md` |
| Squad reviews PRs | ✅ Active — code-review agent used on DK8S repos |
| Squad runs **on** DK8S clusters | ❌ Not started |
| ConfigGen schema for Squad config | ❌ Not started |
| ArgoCD app definition for Squad | ❌ Not started |
| EV2 service model for Squad | ❌ Not started |
| Other DK8S teams can use Squad | ❌ Not started |

---

## Phase 1: Squad Manages DK8S Work (Current → Q2 2026)

**Goal:** Complete the operational integration so Squad handles 50%+ of DK8S team work with no manual routing overhead.

### What "Complete" Looks Like

- Every GitHub issue with a `squad` label is automatically triaged, assigned to the right agent, and has a first response within 15 minutes
- Belanna handles all infra/Helm/ArgoCD issues autonomously
- Worf handles security alerts, CVE triage, and FedRAMP compliance questions
- Data (the code agent) reviews all PRs without being explicitly asked
- Picard makes architecture calls and writes ADRs when a decision is needed
- Ralph monitors the DK8S issue queue as a persistent background worker

### Key Issues to Close

| Issue | Owner | Status |
|---|---|---|
| [#771](https://github.com/tamirdresher_microsoft/tamresearch1/issues/771) DK8S Squad Usage Standard | Picard | In progress |
| [#752](https://github.com/tamirdresher_microsoft/tamresearch1/issues/752) Ralph on ADC | Belanna + Picard | In progress |
| ADR-001 finalization | Picard | Needs review |

### Success Criteria — Phase 1

- [ ] DK8S Squad Usage Standard (`docs/dk8s-squad-usage-standard.md`) adopted by team
- [ ] Ralph runs as a persistent worker monitoring DK8S issue queue with <15m first-response SLA
- [ ] 50% of DK8S GitHub issues resolved or materially advanced by Squad agents with no human intervention
- [ ] All five core agents (Picard, Belanna, Worf, Data, Ralph) have DK8S-specific routing and knowledge loaded

---

## Phase 2: Squad Runs ON DK8S (Q2–Q3 2026)

**Goal:** Deploy Squad agents as Kubernetes workloads in a DK8S cluster, replacing local DevBox / ADC execution with managed, observable, scalable compute.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  DK8S Cluster (dev / prod)                                      │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  squad namespace                                         │   │
│  │                                                          │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │   │
│  │  │  ralph      │  │  picard      │  │  belanna       │  │   │
│  │  │  (monitor)  │  │  (lead)      │  │  (infra)       │  │   │
│  │  │  Deployment │  │  Job/Batch   │  │  Job/Batch     │  │   │
│  │  └──────┬──────┘  └──────┬───────┘  └───────┬────────┘  │   │
│  │         │                │                   │           │   │
│  │  ┌──────▼────────────────▼───────────────────▼────────┐  │   │
│  │  │  KEDA ScaledObject → GitHub issue queue depth      │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │                                                          │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │  squad-config ConfigMap (generated by ConfigGen)   │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Deployed via ArgoCD app-of-apps                                 │
│  Helm chart: charts/squad/                                       │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 ConfigGen Integration (#1038)

ConfigGen is DK8S's typed configuration generation framework. It replaces YAML ad-hoc authoring with C# code that generates valid, schema-checked configuration.

**How Squad maps to ConfigGen:**

| Squad concept | ConfigGen representation |
|---|---|
| `squad.config.ts` agent roster | `SquadConfiguration` C# class |
| `.squad/team.md` | Generated from `SquadTeamConfig` |
| `.squad/routing.md` | Generated from `SquadRoutingConfig` |
| `.squad/ceremonies.md` | Generated from `SquadCeremoniesConfig` |
| Per-agent model assignments | `AgentModelConfig` typed builder |
| MCP server registrations | `McpServerConfig` registry |

**Proposed ConfigGen schema:**

```csharp
// ConfigurationGeneration.Squad (proposed package)

public class SquadConfiguration : DK8SAppConfiguration
{
    public SquadTeamConfig Team { get; set; }
    public SquadRoutingConfig Routing { get; set; }
    public SquadCeremoniesConfig Ceremonies { get; set; }
    public IList<AgentConfig> Agents { get; set; }
    public IList<McpServerConfig> McpServers { get; set; }
    public SquadIdentityConfig Identity { get; set; }
}

public class AgentConfig
{
    public string Name { get; set; }         // "picard"
    public string Role { get; set; }         // "Lead"
    public string Model { get; set; }        // "claude-sonnet-4"
    public string CharterPath { get; set; }  // ".squad/agents/picard/"
    public IList<string> Labels { get; set; } // ["squad:picard"]
}
```

ConfigGen generates:
- Helm `values.yaml` for the Squad deployment
- `.squad/team.md` and `.squad/routing.md` from the typed config
- Kubernetes `ConfigMap` with agent configuration
- ArgoCD `Application` manifest

**Acceptance criteria:**
- [ ] `ConfigurationGeneration.Squad` package defined and schema reviewed
- [ ] `SquadConfiguration` generates valid Helm values
- [ ] `.squad/routing.md` auto-generated from config (no manual edits)
- [ ] Deployed to dev cluster via ConfigGen → Helm pipeline

### 2.2 Helm Chart

Squad's Helm chart lives at `charts/squad/` in the DK8S Squad repo. Structure:

```
charts/squad/
├── Chart.yaml
├── values.yaml           # defaults (model, replicas, resources)
├── values.schema.json    # JSON Schema for values validation
└── templates/
    ├── deployment-ralph.yaml      # Ralph persistent monitor
    ├── job-agent.yaml             # Generic agent job template
    ├── configmap-squad.yaml       # squad.config + team.md + routing.md
    ├── serviceaccount.yaml        # Workload Identity SA
    ├── secret-external.yaml       # ExternalSecret for GitHub token
    ├── keda-scaledobject.yaml     # KEDA autoscaling
    └── NOTES.txt
```

**Key design decisions:**
- Ralph runs as a `Deployment` (persistent, long-lived)
- All other agents (Picard, Belanna, Worf, Data) run as `Job` resources, spawned on demand by Ralph or KEDA
- ConfigMap holds the resolved Squad configuration; agents mount it read-only

### 2.3 KEDA Autoscaling

Squad agents are event-driven by nature — they respond to GitHub issue queue depth. KEDA's GitHub scaler makes this native:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: squad-agents
spec:
  scaleTargetRef:
    name: squad-agent-pool
  triggers:
  - type: github-runner        # or custom GitHub API scaler
    metadata:
      owner: tamirdresher_microsoft
      repo: tamresearch1
      labels: "status:in-progress"
      targetIssueCount: "3"   # 1 agent pod per 3 open issues
  minReplicaCount: 0           # scale to zero when idle
  maxReplicaCount: 5
```

When the DK8S issue queue grows (>3 open `status:in-progress` items), KEDA spawns additional agent pods. When the queue drains, pods scale back to zero. This makes Squad cost-proportional to actual workload.

### 2.4 ArgoCD GitOps Deployment

Squad is deployed and updated through ArgoCD, same as every other DK8S workload:

```yaml
# argocd/applications/squad.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: squad
  namespace: argocd
spec:
  project: dk8s-platform
  source:
    repoURL: https://github.com/microsoft-mtp/dk8s-squad
    targetRevision: HEAD
    path: charts/squad
    helm:
      valueFiles:
        - values.yaml
        - values-prod.yaml  # generated by ConfigGen
  destination:
    server: https://kubernetes.default.svc
    namespace: squad
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Updating Squad (new model, new agent, config change) becomes a PR to `dk8s-squad` → ArgoCD detects drift → auto-syncs → agents restart with new config. No manual `kubectl apply`.

### 2.5 Identity: How Agents Authenticate

Squad agents need to call external APIs (GitHub, Azure DevOps, Microsoft Graph, Azure OpenAI). On DK8S, authentication uses **Workload Identity** — no secrets stored in pods, no token rotation overhead.

| Service | Auth mechanism | Notes |
|---|---|---|
| Azure OpenAI | Workload Identity → managed identity | RBAC: `Cognitive Services User` on AOI resource |
| GitHub API | GitHub App installation token | Stored in `ExternalSecret` from Azure Key Vault |
| Azure DevOps | Workload Identity → AAD token | Uses MSAL with federated credentials |
| Microsoft Graph | Workload Identity → AAD app | Requires `User.Read`, `Mail.Send` etc. |

**Kubernetes service account setup:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: squad-agent
  namespace: squad
  annotations:
    azure.workload.identity/client-id: "<managed-identity-client-id>"
    azure.workload.identity/tenant-id: "<tenant-id>"
```

The managed identity is provisioned via DK8S's standard identity model. Squad agents inherit DK8S's existing RBAC posture — they are not a special case.

### 2.6 EV2 Deployment

For production DK8S deployments, EV2 is the rollout mechanism. Squad follows the standard DK8S service rollout pattern:

1. **Canary rollout** — deploy to one dev cluster first
2. **Regional rollout** — promote to staging cluster after 48h soak
3. **Global rollout** — promote to all production clusters

EV2 service model for Squad:
- Service name: `dk8s-squad`
- Rollout spec: `canary → regional → global`
- Health check: Ralph `/healthz` endpoint returning `{"status": "running", "issuesMonitored": N}`
- Rollback trigger: Ralph pod not ready within 5m, or >3 consecutive health check failures

### Success Criteria — Phase 2

- [ ] `charts/squad/` Helm chart deployed to dev cluster
- [ ] Ralph runs as a persistent Deployment, processing issues from cluster
- [ ] KEDA `ScaledObject` scales agent jobs 0→N based on issue queue depth
- [ ] ArgoCD `Application` manages Squad lifecycle (sync, rollback)
- [ ] Workload Identity configured — zero secrets in pod specs
- [ ] ConfigGen generates Squad Helm values (no hand-editing values.yaml)
- [ ] EV2 service model registered and canary rollout tested

---

## Phase 3: Squad as DK8S Platform Capability (Q3–Q4 2026)

**Goal:** Any DK8S tenant team can provision a Squad instance for their own repo with a single PR to the DK8S inventory. Squad becomes a platform service, not a team's personal tooling.

### Self-Service Provisioning

A tenant team requesting Squad adds an entry to the DK8S inventory:

```yaml
# inventory/tenants/my-team/squad.yaml
squad:
  enabled: true
  tier: standard          # standard | premium (premium = dedicated compute)
  repo: microsoft-mtp/my-team-repo
  agents:
    - picard              # included in all tiers
    - belanna             # infra teams
    - worf                # security-sensitive teams
  githubApp: squad-bot    # shared GitHub App installation
  identity:
    managedIdentityName: squad-my-team
```

This triggers:
1. ConfigGen generates Squad configuration for the tenant
2. ArgoCD creates a new `Application` in the tenant's namespace
3. Helm deploys a Squad instance scoped to the tenant's repo
4. GitHub App is installed on the tenant repo

### Multi-Tenancy Model

**Decision needed (#1061):** Single-tenant vs. shared-tenant per Squad instance.

| Model | Pros | Cons |
|---|---|---|
| **One Squad per namespace** | Strong isolation, independent scaling | Higher resource overhead per tenant |
| **Shared Squad with per-team config** | Lower overhead, easier to manage | Agents share context → potential confusion |
| **Shared Ralph, per-team agent jobs** | Balanced — one monitor, isolated workers | More complex routing logic |

**Recommendation (Picard):** Start with **one Squad per namespace** for isolation and operational simplicity. Revisit shared Ralph when tenant count exceeds 10.

### Squad as a CRD Resource

In Phase 3, Squad becomes a Kubernetes resource. A `SquadAgent` CRD allows teams to declaratively manage agents:

```yaml
apiVersion: squad.dk8s.microsoft.com/v1alpha1
kind: SquadAgent
metadata:
  name: belanna
  namespace: my-team
spec:
  role: infrastructure
  model: claude-sonnet-4
  charter: .squad/agents/belanna/charter.md
  labels:
    routes: ["squad:belanna"]
  resources:
    requests: { cpu: "100m", memory: "256Mi" }
    limits:   { cpu: "500m", memory: "1Gi" }
```

A Squad operator (Go controller using controller-runtime) watches `SquadAgent` resources and reconciles the desired state — creating Jobs, updating ConfigMaps, applying RBAC.

### Observability Integration

Squad integrates with DK8S's existing Prometheus + Grafana stack:

| Metric | Description |
|---|---|
| `squad_issues_processed_total` | Issues handled, by agent and outcome |
| `squad_agent_job_duration_seconds` | P50/P95/P99 agent execution time |
| `squad_queue_depth` | Current GitHub issue queue depth (KEDA also reads this) |
| `squad_model_tokens_total` | Token consumption by model and agent |
| `squad_errors_total` | Errors by type and agent |

Alerts:
- `SquadRalphDown` — Ralph pod not ready for >5m
- `SquadQueueBacklog` — queue depth >20 for >30m (possible agent failure)
- `SquadModelErrors` — >5 model API errors per minute (quota or outage)

### Istio (Optional)

If the DK8S cluster uses Istio, Squad inter-agent communication (Ralph dispatching to specialist agents) can use mTLS service mesh. This is not required for functionality — agents communicate via the GitHub API as a message bus — but Istio adds network-level audit trails for compliance.

### Success Criteria — Phase 3

- [ ] `SquadAgent` CRD defined, controller implemented
- [ ] DK8S inventory supports `squad: enabled: true` for tenant self-service
- [ ] First external tenant team (not the platform team) running Squad on DK8S
- [ ] Prometheus metrics dashboard showing Squad health across all tenants
- [ ] DK8S platform team uses Squad for 50%+ of internal work (dogfooding target)
- [ ] Squad on DK8S documented in DK8S onboarding guide

---

## ADC Integration (#1064) — Parallel Track

ADC (Agent Dev Compute) is a parallel deployment target, not a replacement for DK8S. The two serve different use cases:

| Dimension | DK8S (K8s) | ADC |
|---|---|---|
| **Persistence** | Deployment + PVC, survives restarts | Session-based, may need external state |
| **Scaling** | KEDA-driven, 0→N | Session-per-agent model |
| **Cost** | Always-on cluster overhead | Consumption-based |
| **Auth** | Workload Identity (native) | Token management TBD |
| **Use case** | 24/7 Ralph, production agents | Burst compute, short-lived agent tasks |

**Recommendation:** Use DK8S as the primary runtime for persistent Squad agents (Ralph, Picard), and evaluate ADC for ephemeral burst tasks (one-off research, large PR reviews). Issue #752 (Ralph on ADC) will inform whether ADC becomes a first-class target.

---

## Dependency Map

Which DK8S components Squad depends on, by phase:

```
Phase 1 (issue management)
  └─ GitHub API (already working)
  └─ ADO MCP (already working)
  └─ Microsoft Graph (already working)

Phase 2 (running on DK8S)
  └─ DK8S AKS cluster (dev)
      └─ Workload Identity
      └─ KEDA
      └─ ArgoCD
      └─ ExternalSecrets Operator
  └─ Azure Key Vault (GitHub App token)
  └─ Azure OpenAI (model endpoint)
  └─ ConfigGen (ConfigurationGeneration.Squad)
  └─ EV2 (rollout, prod only)

Phase 3 (platform capability)
  └─ DK8S inventory (cluster manifest)
  └─ Squad operator (new: Go controller)
  └─ Prometheus / Grafana (metrics)
  └─ DK8S onboarding pipeline (tenant provisioning)
  └─ Istio (optional: mTLS for inter-agent)
```

---

## GitHub Milestones

| Milestone | Target | Key deliverables |
|---|---|---|
| **Phase 1 Complete** | 2026-05-01 | DK8S Squad Usage Standard adopted; Ralph persistent; 50% issue coverage |
| **Squad on DK8S Dev** | 2026-07-01 | Helm chart + ArgoCD + KEDA + Workload Identity in dev cluster |
| **Squad on DK8S Prod** | 2026-09-01 | EV2 rollout; ConfigGen integration; production SLA |
| **Squad Platform GA** | 2026-12-01 | CRD-based self-service; first external tenant; Prometheus dashboards |

---

## What "First-Class Citizen" Looks Like

The integration is complete when all of the following are true:

1. **Zero manual steps to deploy Squad.** A PR to `dk8s-squad` triggers ArgoCD sync; agents are running within minutes.
2. **Zero secrets in pods.** All authentication through Workload Identity or ExternalSecrets from Key Vault.
3. **Squad configuration is typed.** No one edits `values.yaml` by hand; ConfigGen generates it from C# configuration.
4. **Ralph never goes down.** Squad monitor runs as a DK8S Deployment with health checks and EV2 rollout protection.
5. **Any DK8S team can get Squad** by adding 10 lines to the inventory. No platform team involvement required.
6. **Squad's health is visible** on the same Grafana dashboard as every other DK8S service.
7. **The DK8S platform team uses Squad for real work** — not as a demo, but as the primary way issues are handled.

---

## Open Decisions

| Decision | Options | Recommended | Status |
|---|---|---|---|
| Single-tenant vs. multi-tenant | Per-namespace vs. shared | Per-namespace (Phase 2), revisit at 10+ tenants | **Needs decision** |
| GitHub App vs. PAT for agent auth | GitHub App (preferred) vs. PAT per agent | GitHub App (shared installation) | **Needs decision** |
| ADC as primary or secondary target | Primary / secondary / not viable | Secondary (pending #752 findings) | **Blocked on #752** |
| Squad operator: custom vs. off-shelf | Custom Go controller vs. Helm operator | Custom (matches DK8S operator patterns) | **Needs decision** |
| Istio for inter-agent comms | Required / optional / skip | Optional (enable if cluster already has Istio) | **Recommended** |

---

## Related Documents

- [`docs/dk8s-squad-usage-standard.md`](docs/dk8s-squad-usage-standard.md) — How DK8S teams use Squad today
- [`docs/adr/ADR-001-dk8s-squad-usage-standard.md`](docs/adr/ADR-001-dk8s-squad-usage-standard.md) — Architecture decision record
- [Issue #1038](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1038) — ConfigGen support (Belanna)
- [Issue #1061](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1061) — Squad on DK8S internal deployment (Belanna + Picard)
- [Issue #1064](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1064) — ADC integration evaluation
- [Issue #752](https://github.com/tamirdresher_microsoft/tamresearch1/issues/752) — Ralph on ADC (in progress)
