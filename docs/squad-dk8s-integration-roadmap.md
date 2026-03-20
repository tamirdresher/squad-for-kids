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

### 2.7 Authentication for K8s Pods (#998)

> **Design source:** [#998](https://github.com/tamirdresher_microsoft/tamresearch1/issues/998) — Design: GitHub Copilot Authentication for K8s Pods  
> **Related:** [#979](https://github.com/tamirdresher_microsoft/tamresearch1/issues/979) — Rate limit research (defines priority tiers)

Squad agents running as K8s pods need authenticated access to GitHub Copilot APIs. Today, each DevBox has a local `gh auth login` session. In K8s, we need a scalable, secure, and automatable auth mechanism that works across N pods potentially sharing a single Copilot license quota.

#### Option A: GitHub PAT / Copilot Token via K8s Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: squad-github-creds
type: Opaque
data:
  GITHUB_TOKEN: <base64-encoded PAT>
  COPILOT_TOKEN: <base64-encoded token>
```

**Pros:** Simple, works immediately, no external dependencies.  
**Cons:** Static tokens expire and must be rotated manually. PATs have broad scope. No audit trail per-pod. Operationally painful at scale.

#### Option B: Azure Workload Identity → GitHub App (Recommended)

```
Pod → Workload Identity (federated credential)
   → Azure AD token
   → Exchange for GitHub App installation token
   → Use installation token for Copilot API
```

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

**Pros:** No static secrets. Automatic token rotation. Per-pod identity via ServiceAccount. Azure-native audit trail. GitHub App scoping limits blast radius.  
**Cons:** Requires AKS Workload Identity setup. GitHub App must be configured with Copilot API permissions. More complex initial setup.

#### Option C: Sidecar Auth Proxy

A sidecar container in each agent pod handles all GitHub/Copilot auth:

```yaml
containers:
  - name: squad-agent
    image: ghcr.io/tamirdresher/squad-agent:latest
    env:
      - name: COPILOT_ENDPOINT
        value: "http://localhost:8081"  # points to sidecar
  - name: auth-proxy
    image: ghcr.io/tamirdresher/squad-auth-proxy:latest
    ports:
      - containerPort: 8081
```

**Pros:** Agent code has zero auth logic. Proxy handles token refresh, rate limit headers, retry-after. Single implementation shared across all agent types. Can implement circuit breaker pattern.  
**Cons:** Additional container per pod. Network hop latency (localhost, minimal). More images to maintain.

#### **Recommended: Option B + C Combined** (from #998)

Use **Workload Identity** for credential sourcing (no static secrets), and an **auth-proxy sidecar** for token management, rate limiting, and circuit breaking. The sidecar obtains tokens via the pod's Workload Identity, caches them, and presents a simple HTTP endpoint to the agent container.

This approach satisfies both the security requirement (no long-lived secrets in pods) and the operational requirement (agents don't need to implement auth logic).

#### Token Rotation and Secret Management

| Credential | TTL | Rotation Mechanism |
|---|---|---|
| Workload Identity tokens | 1 hour | Auto-rotated by Azure AD (kubelet handles refresh) |
| GitHub App installation tokens | 1 hour | Auth-proxy refreshes 5 minutes before expiry |
| Static fallback secrets (Phase 1 only) | 90 days | External Secrets Operator (ESO) syncs from Azure Key Vault |

**Secret Store options:**
- **External Secrets Operator (ESO):** Syncs secrets from Azure Key Vault into K8s Secrets. Best for static credentials during Phase 1.
- **Secret Store CSI Driver:** Mounts Key Vault secrets directly as files in pods. Lower overhead than ESO for read-heavy patterns.

#### Rate Limit Coordination Across N Pods

The current `rate-pool.json` file-based approach doesn't work in K8s (no shared filesystem). Recommendation from #998:

**Redis** — Central rate-pool store. Each auth-proxy sidecar reads/writes quotas via Redis sorted sets. The three-tier priority system from #979 (P0: Picard/Worf, P1: Data/Seven, P2: Ralph/Scribe) maps directly to Redis sorted sets for priority-aware quota allocation.

```yaml
# Redis ScaledObject for rate pool
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: squad-rate-pool-redis
spec:
  scaleTargetRef:
    name: squad-rate-pool
  triggers:
  - type: redis
    metadata:
      address: squad-redis:6379
      listName: squad:priority:queue
      listLength: "5"
```

#### Security Posture

- **Network policies:** Agent pods can only reach auth-proxy on `localhost` and rate-pool Redis on cluster IP — no direct egress to GitHub
- **Pod Security Standards:** Restricted profile — no privilege escalation, read-only root filesystem
- **Secrets encryption at rest:** AKS etcd encryption enabled for the `squad` namespace
- **Audit trail:** All GitHub API calls via the proxy, logged to Azure Monitor

#### Kubernetes Service Account Setup

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

- [ ] `charts/squad/` Helm chart deployed to dev cluster (ref: [#1000](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1000))
- [ ] Ralph runs as a persistent Deployment, processing issues from cluster
- [ ] Capability Discovery DaemonSet deployed; nodes labelled with `squad.io/capability-*` (ref: [#999](https://github.com/tamirdresher_microsoft/tamresearch1/issues/999))
- [ ] Agent Job templates inject `nodeSelector` from `needs:*` issue labels
- [ ] KEDA `ScaledObject` scales agent jobs 0→N based on issue queue depth
- [ ] ArgoCD `Application` manages Squad lifecycle (sync, rollback)
- [ ] Workload Identity configured — zero secrets in pod specs (ref: [#998](https://github.com/tamirdresher_microsoft/tamresearch1/issues/998))
- [ ] Auth-proxy sidecar handles all GitHub/Copilot token management
- [ ] Redis rate pool operational; three-tier priority respected across N pods
- [ ] ConfigGen generates Squad Helm values (no hand-editing values.yaml) (ref: [#1038](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1038))
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
- [`docs/adr-002-squad-on-kubernetes.md`](docs/adr-002-squad-on-kubernetes.md) — Architecture Decision Record: Squad on Kubernetes
- [`docs/squad-on-kubernetes-architecture.md`](docs/squad-on-kubernetes-architecture.md) — Detailed K8s architecture design
- [`docs/squad-on-aks.md`](docs/squad-on-aks.md) — Azure-native AKS deployment guide
- [`docs/squad-on-dk8s-internal.md`](docs/squad-on-dk8s-internal.md) — Internal DK8S deployment design
- [Issue #994](https://github.com/tamirdresher_microsoft/tamresearch1/issues/994) — Architecture: Squad-on-Kubernetes (pod-per-agent model, CRD design)
- [Issue #998](https://github.com/tamirdresher_microsoft/tamresearch1/issues/998) — Design: GitHub Copilot Authentication for K8s Pods
- [Issue #999](https://github.com/tamirdresher_microsoft/tamresearch1/issues/999) — Design: K8s-Native Capability Routing (node labels)
- [Issue #1000](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1000) — Prototype: Squad Helm Chart — Deploy Agents to AKS
- [Issue #1038](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1038) — ConfigGen support (Belanna)
- [Issue #1059](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1059) — Squad on Kubernetes architecture design
- [Issue #1061](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1061) — Squad on DK8S internal deployment (Belanna + Picard)
- [Issue #1064](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1064) — ADC integration evaluation
- [Issue #752](https://github.com/tamirdresher_microsoft/tamresearch1/issues/752) — Ralph on ADC (in progress)
