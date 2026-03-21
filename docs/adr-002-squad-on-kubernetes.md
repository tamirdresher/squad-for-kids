# ADR-002: Squad on Kubernetes Architecture

**Status:** Accepted  
**Date:** 2026-03-20  
**Author:** Picard (Lead)  
**Issue:** [#1059](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1059)  
**Gates:** #1060 (AKS deployment), #1061 (DK8S integration), #1062 (Helm packaging), #1066 (K8s blog)

---

## Context

Squad currently runs as a collection of PowerShell scripts on Windows machines — primarily `ralph-watch.ps1` (the reconciliation loop), agent sessions spawned by Ralph, and MCP servers launched locally. This works on developer machines and DevBoxes, but it does not scale:

- Single machine = single point of failure
- Session-bound processes die on RDP disconnect (see `persistent-squad-sessions.md`)
- No portable, reproducible deployment unit
- No cloud-native lifecycle management (restarts, health probes, resource limits)
- Manual setup friction blocks adoption by other teams (DK8S ADR-001)

The goal of this ADR is to define the canonical Kubernetes architecture for Squad so that #1060 (AKS), #1061 (DK8S), and #1062 (Helm packaging) can be built from a single agreed design.

---

## Decision

**Run Ralph as a Kubernetes CronJob (not a Deployment). Wrap the full squad in a Helm chart with a flat sub-chart-per-component structure. Use External Secrets Operator (ESO) fed by Azure Key Vault for secrets. Implement multi-instance coordination via GitHub issue assignment (the existing design from `multi-machine-ralph-design.md`) — no shared filesystem required. Defer the Squad Operator to a future iteration; start with Helm.**

Each decision below is explained with rationale, trade-offs, and the mapping from current Squad code.

---

## 1. Kubernetes Primitives Mapping

### Current Squad Components → K8s Objects

| Squad Component | Current Form | K8s Primitive | Rationale |
|----------------|-------------|---------------|-----------|
| `ralph-watch.ps1` | Long-running PowerShell loop | **CronJob** | 5-min reconcile cycle maps naturally; see §3 |
| Picard / B'Elanna / Data agent sessions | Spawned on-demand by Ralph | **Job** (with TTL) | Short-lived, completion-oriented, disposable |
| MCP servers (`mcp-servers/`) | Local Node.js/Python processes | **Sidecar containers** in Ralph Pod | Shared localhost networking; see §4 |
| `squad.config.ts` | Checked-in TypeScript config | **ConfigMap** | Read-only config at deploy time |
| `.squad/` directory | Git-tracked state | **Git clone in init container** | State stays in git; no PV needed for config |
| `~/.squad/heartbeats/` | Filesystem JSON files | **GitHub labels** (via multi-machine protocol) | No filesystem cross-pod; see §5 |
| `~/.squad/machine-capabilities.json` | Filesystem JSON | **Pod env vars + Downward API** | Capabilities declared in `values.yaml` |
| GitHub token / API keys / webhook URLs | `.env` / Windows Credential Manager | **K8s Secret** (backed by ESO + Key Vault) | See §6 |
| `gh` CLI auth (`GH_CONFIG_DIR`) | `%APPDATA%\GitHub CLI\hosts.yml` | **Workload Identity** (OIDC → GitHub App) | No long-lived PAT; see §6 |
| Agent charter files (`.squad/agents/*/charter.md`) | Checked-in markdown | **ConfigMap** (projected from git clone) | Stays in git; mounted read-only |
| `.squad/decisions/` | Checked-in markdown | **Git** (push back on completion) | Git is the source of truth for decisions |
| Teams webhook URL | Env var / secrets | **K8s Secret** | Rotatable without redeploy |

### Objects NOT needed

- **PersistentVolume / PVC** — Squad's meaningful state lives in git. Ephemeral scratch (logs, lockfiles) is written to `emptyDir`. There is no SQLite workqueue in scope for Phase 1.
- **StatefulSet** — Ralph is stateless between rounds. CronJob is correct.
- **DaemonSet** — No per-node agents needed.

---

## 2. Agent Execution Model

### Decision: Agents as Kubernetes Jobs

When Ralph's CronJob fires, it discovers work (open GitHub issues with `squad:copilot` label) and spawns an agent for each claimed issue. In the K8s model:

```
ralph-cronjob (fires every 5 min)
  └─ Claims issue #N via GitHub assignment API (atomic)
  └─ Creates K8s Job: squad-agent-{issue-N}
       └─ container: squad-agent
            entrypoint: run-agent.sh --agent picard --issue N
            env: GH_TOKEN, ANTHROPIC_API_KEY, ISSUE_NUMBER
            ttlSecondsAfterFinished: 600
            backoffLimit: 1
```

**Why Jobs, not long-running Deployments:**

- Agent sessions are bounded: they start, do work, and exit. This is exactly what a Job models.
- Jobs provide completion semantics, restart policy (`Never` or `OnFailure`), and TTL cleanup — all needed.
- Deployments are for services that must be continuously available (API servers, MCP servers). Agents are not.
- Resource isolation: each agent gets its own resource envelope. A runaway agent doesn't starve others.

**Agent container image:**

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:9.0-noble AS base
RUN apt-get update && apt-get install -y curl git nodejs npm
RUN npm install -g @github/copilot-cli
RUN apt-get install -y gh
COPY scripts/ /app/scripts/
COPY .squad/ /app/.squad/
ENTRYPOINT ["/app/scripts/run-agent.sh"]
```

One image, parameterized by `AGENT_NAME` env var. No per-agent images in Phase 1. Agents are differentiated by their prompt/charter, not their container binary.

**Concurrency control:**

```yaml
# In the CronJob spec
spec:
  concurrencyPolicy: Forbid   # Don't start a new round if previous is still running
```

This mirrors the existing mutex (`Global\RalphWatch_tamresearch1`) in `ralph-watch.ps1`.

**Job resource limits:**

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "2"
    memory: "2Gi"
```

Agent sessions are primarily I/O-bound (API calls to Anthropic/GitHub). 2 CPU cores and 2 GiB memory is generous for a Copilot CLI session.

---

## 3. Ralph as a Kubernetes CronJob

### Decision: CronJob (not Deployment)

This is the central architectural decision. The options are:

**Option A — CronJob (CHOSEN)**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ralph-watch
  namespace: squad
spec:
  schedule: "*/5 * * * *"        # every 5 minutes — matches current ralph-watch.ps1
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 5
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 300
      backoffLimit: 0             # don't retry — next round fires in 5 min anyway
      template:
        spec:
          restartPolicy: Never
          serviceAccountName: squad-ralph
          initContainers:
            - name: git-sync
              image: registry.k8s.io/git-sync/git-sync:v4.2.1
              args:
                - --repo=https://github.com/tamirdresher_microsoft/tamresearch1
                - --depth=1
                - --one-time
                - --dest=repo
              volumeMounts:
                - name: squad-repo
                  mountPath: /git
          containers:
            - name: ralph
              image: acrsquadprod.azurecr.io/squad-ralph:latest
              command: ["/app/scripts/ralph-k8s.sh"]
              envFrom:
                - secretRef:
                    name: squad-secrets
              env:
                - name: SQUAD_REPO_PATH
                  value: /git/repo
                - name: RALPH_INSTANCE_NAME
                  valueFrom:
                    fieldRef:
                      fieldPath: spec.nodeName   # use node name as machine identity
              volumeMounts:
                - name: squad-repo
                  mountPath: /git
                - name: mcp-config
                  mountPath: /app/mcp-config.json
                  subPath: mcp-config.json
          volumes:
            - name: squad-repo
              emptyDir: {}
            - name: mcp-config
              configMap:
                name: squad-mcp-config
```

**Option B — Deployment with livenessProbe (REJECTED)**

```yaml
# Ralph as a long-running Deployment
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: ralph
          command: ["/app/ralph-watch.ps1"]    # long-running loop
          livenessProbe:
            exec:
              command: ["test", "-f", "/tmp/ralph-heartbeat"]
            initialDelaySeconds: 60
            periodSeconds: 30
```

**Rationale for rejecting Option B:**

| Concern | CronJob | Deployment |
|---------|---------|------------|
| Lifecycle clarity | Each round is a separate Job — clean start/end semantics | Long-running process accumulates state, leaks |
| Failure recovery | K8s restarts the next scheduled Job automatically | Requires livenessProbe + restart policy tuning |
| Concurrency guard | `concurrencyPolicy: Forbid` is native | Must reimplement mutex logic in-container |
| Log isolation | Each round = separate pod logs | All rounds mixed in one pod's log stream |
| Resource cleanup | TTL cleans up completed jobs | Must manage memory growth in a long-running loop |
| Cold start overhead | ~10s for git-sync init container | Negligible (already running) |
| Reaction latency | Max 5 min delay | Immediate (but Ralph's batch model doesn't need this) |

**The cold start overhead is the only real cost of CronJob, and it's acceptable.** Ralph is a batch reconciler, not a real-time event processor. The 5-minute polling interval already means up to 5 minutes of latency — a 10-second git-sync init is noise.

**Deployment is appropriate for always-on services.** Ralph is not a service. It's a reconciliation loop with a fixed cadence. CronJob is the semantically correct primitive.

### Mapping ralph-watch.ps1 features to K8s

| `ralph-watch.ps1` Feature | K8s Equivalent |
|--------------------------|----------------|
| Named mutex (`Global\RalphWatch_tamresearch1`) | `concurrencyPolicy: Forbid` on CronJob |
| Lockfile (`.ralph-watch.lock`) | Not needed — K8s tracks Job status |
| Stale process cleanup (`Get-CimInstance Win32_Process`) | Not needed — each round is a fresh container |
| Heartbeat file (`~/.squad/ralph-heartbeat.json`) | GitHub label (`ralph:machine-{nodeName}`) + comment timestamp |
| Log rotation (500 entries / 1 MB) | Not needed — container logs go to stdout → Log Analytics |
| Self-restart on `ralph-watch.ps1` update | `imagePullPolicy: Always` + `rollout restart` on new image push |
| Consecutive failure alerting (Teams webhook after 3+) | `failedJobsHistoryLimit: 5` + Prometheus alert on CronJob failure count |
| `gh` auth self-healing (`ralph-self-heal.ps1`) | Workload Identity — no auth to heal; token is OIDC-minted |
| Round timeout (20-min kill switch) | `activeDeadlineSeconds: 1200` on the Job |
| Git conflict auto-resolution | Not needed in read-only git-sync model |

---

## 4. MCP Server Architecture

### Decision: Sidecars in the Ralph Pod

MCP servers are currently launched as local processes sharing localhost with the Copilot CLI session. In Kubernetes, the natural equivalent is **sidecar containers** in the same Pod.

```yaml
containers:
  - name: ralph
    # ... main container

  - name: mcp-github
    image: acrsquadprod.azurecr.io/mcp-github:latest
    ports:
      - containerPort: 3001
    env:
      - name: GITHUB_TOKEN
        valueFrom:
          secretKeyRef:
            name: squad-secrets
            key: github-token

  - name: mcp-azure-devops
    image: acrsquadprod.azurecr.io/mcp-ado:latest
    ports:
      - containerPort: 3002

  - name: mcp-calendar
    image: acrsquadprod.azurecr.io/mcp-calendar:latest
    ports:
      - containerPort: 3003
```

The `mcp-config.json` (currently in `mcp-servers/`) maps to a ConfigMap:

```json
{
  "servers": {
    "github": { "url": "http://localhost:3001/sse" },
    "azure-devops": { "url": "http://localhost:3002/sse" },
    "calendar": { "url": "http://localhost:3003/sse" }
  }
}
```

**Why sidecars over separate Deployments:**

- MCP servers are not independently scalable — they serve exactly one Ralph instance
- Shared Pod = shared localhost networking (no Service discovery needed)
- Lifecycle coupling is correct: if Ralph's Job ends, the sidecars end too
- Simpler `mcp-config.json` — always `localhost:{port}`, no DNS to resolve

**Agent Jobs also get sidecars** — the same MCP server containers are specified in the agent Job template. Each agent instance gets its own set of MCP processes, fully isolated.

---

## 5. Multi-Machine Coordination on Kubernetes

### Problem: No Shared Filesystem for Locks

The current multi-machine coordination design (`multi-machine-ralph-design.md`) already solved this problem for the file-system-free case. The solution uses **GitHub issue assignment as a distributed lock**.

In K8s, multiple Ralph CronJob instances might run simultaneously (e.g., in multi-region deployments, or if `concurrencyPolicy` is briefly violated during a node failure). The coordination protocol is:

```
1. Ralph fires → queries GitHub for open issues with squad:copilot label and no assignee
2. For each candidate issue:
   a. POST /repos/.../issues/{N}/assignees   (atomic claim attempt)
   b. Read back assignees — if another Ralph got there first, skip
   c. On success: POST claim comment with timestamp + node identity
3. Spawn K8s Job for each claimed issue
4. After spawning Jobs: write heartbeat comment to each claimed issue
```

**K8s-specific additions to the multi-machine protocol:**

```powershell
# In ralph-k8s.sh / ralph-k8s.ps1
$machineId = $env:RALPH_INSTANCE_NAME   # = spec.nodeName via Downward API
# or use Pod name: $machineId = $env:POD_NAME (more unique per CronJob run)
```

**Stale claim recovery** is unchanged from the design in `multi-machine-ralph-design.md` — heartbeat comments older than 15 minutes trigger reclaim. No filesystem state is needed.

**Race condition window:** GitHub assignment is not perfectly atomic for concurrent writes. The existing mitigation (read-back after claim, back off if >1 assignee) applies equally on K8s.

---

## 6. Secrets Management

### Decision: External Secrets Operator (ESO) + Azure Key Vault

Secrets flow: **Azure Key Vault → ESO → K8s Secret → Pod env**

```yaml
# ExternalSecret resource (deployed by Helm)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: squad-secrets
  namespace: squad
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: squad-azure-keyvault
    kind: ClusterSecretStore
  target:
    name: squad-secrets         # K8s Secret name consumed by Pods
    creationPolicy: Owner
  data:
    - secretKey: github-token
      remoteRef:
        key: squad-github-token
    - secretKey: anthropic-api-key
      remoteRef:
        key: squad-anthropic-key
    - secretKey: teams-webhook-url
      remoteRef:
        key: squad-teams-webhook
    - secretKey: azure-devops-token
      remoteRef:
        key: squad-ado-token
```

**Why ESO over plain K8s Secrets:**

- Plain K8s Secrets are base64, not encrypted at rest (unless etcd encryption is configured)
- ESO with Azure Key Vault gives rotation without redeployment (1h refresh interval)
- Bitwarden (current desktop secret manager) has no K8s-native integration at this scale
- AKS Workload Identity → ESO with Managed Identity = no static credentials anywhere

**GitHub CLI authentication:**

The `GH_CONFIG_DIR` / `hosts.yml` approach used in `ralph-watch.ps1` does not translate to containers cleanly. Replace with:

```yaml
# AKS: Use Workload Identity federation
# GitHub App installed on the repo → OIDC token → gh auth
env:
  - name: GITHUB_TOKEN
    valueFrom:
      secretKeyRef:
        name: squad-secrets
        key: github-token
```

For DK8S: use the cluster's existing Workload Identity infrastructure (already available per `fedramp-compensating-controls-infrastructure.md`).

**Secret categories:**

| Secret | K8s Secret Key | Source |
|--------|---------------|--------|
| GitHub PAT / App token | `github-token` | Azure Key Vault |
| Anthropic API key | `anthropic-api-key` | Azure Key Vault |
| Teams webhook URL | `teams-webhook-url` | Azure Key Vault |
| Azure DevOps PAT | `azure-devops-token` | Azure Key Vault |
| Azure Speech key | `azure-speech-key` | Azure Key Vault (only on capable nodes) |

---

## 7. Helm Chart Structure

### Decision: Single top-level chart, sub-charts per component

```
charts/squad/
├── Chart.yaml
├── values.yaml                    # all defaults
├── values-aks.yaml                # AKS overrides
├── values-dk8s.yaml               # DK8S overrides
├── templates/
│   ├── namespace.yaml
│   ├── serviceaccount.yaml
│   ├── clusterrole.yaml
│   ├── clusterrolebinding.yaml
│   ├── configmap-mcp.yaml         # mcp-config.json
│   ├── configmap-squad.yaml       # squad.config.ts as JSON
│   ├── externalsecret.yaml        # squad-secrets via ESO
│   └── _helpers.tpl
└── charts/
    ├── ralph/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── cronjob.yaml       # ralph CronJob
    │       └── role.yaml          # K8s Job creation permission
    ├── agents/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       └── job-template.yaml  # Template Job (created by ralph at runtime)
    └── mcp-servers/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            └── configmap.yaml     # MCP server config (sidecars defined inline in ralph/cronjob.yaml)
```

### `values.yaml` (key sections)

```yaml
global:
  namespace: squad
  image:
    registry: acrsquadprod.azurecr.io
    tag: latest
    pullPolicy: Always
  repoUrl: https://github.com/tamirdresher_microsoft/tamresearch1

ralph:
  schedule: "*/5 * * * *"
  activeDeadlineSeconds: 1200   # 20-minute kill switch (matches ralph-watch.ps1)
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: 1
      memory: 1Gi

agents:
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 2
      memory: 2Gi
  ttlSecondsAfterFinished: 600

mcpServers:
  github:
    enabled: true
    port: 3001
  azureDevOps:
    enabled: true
    port: 3002
  calendar:
    enabled: false   # disabled by default; enable per-deployment
  playwright:
    enabled: false   # requires browser node pool

secrets:
  provider: external-secrets    # or "plain" for non-AKS environments
  keyVaultName: kv-squad-prod
  managedIdentityClientId: ""   # set per-deployment

capabilities:
  # Mirrors ~/.squad/machine-capabilities.json
  # Nodes without GPU won't get GPU-needing issues
  gpu: false
  browser: false
  azureSpeech: false
```

### Customization via values overlays

```bash
# Deploy to AKS
helm install squad ./charts/squad -f values-aks.yaml

# Deploy to DK8S (restricted, no external traffic)
helm install squad ./charts/squad -f values-dk8s.yaml --set ralph.schedule="*/10 * * * *"
```

---

## 8. CronJob vs. Operator — Final Recommendation

### Phase 1: Helm + CronJob (Now)

Deploy with Helm. Ralph = CronJob. Agents = Jobs. No custom controller.

**Rationale:**
- The Squad operator would need to watch `Squad` CRDs and reconcile → spawn Jobs, update ConfigMaps, manage CronJob schedules. This is a full Go operator (kubebuilder/controller-runtime) — 2-3 weeks of engineering.
- Helm + CronJob achieves 90% of the operational value in 2-3 days.
- The DK8S team (issue #1061) needs something they can deploy *now* to validate the approach.
- Issues #1060, #1062, and #1066 all gate on having a working Helm chart — they cannot wait for an operator.

### Phase 2: Squad Operator (Future)

Once the Helm chart is stable and adopted, graduate to an operator for:

- **Declarative team composition**: `Squad` CRD defines which agents are active, which skills are loaded, what schedule Ralph runs on
- **Auto-scaling**: Operator watches GitHub issue queue depth → adjusts Job parallelism
- **Self-healing**: Operator detects stale claims in GitHub → triggers reclaim without waiting for next CronJob fire
- **Multi-tenant**: Multiple `Squad` CRs in one cluster, each isolated in its own namespace

```yaml
# Future Squad CRD (Phase 2 — not built yet)
apiVersion: squad.ai/v1alpha1
kind: Squad
metadata:
  name: tamresearch1
  namespace: squad
spec:
  repo: tamirdresher_microsoft/tamresearch1
  ralph:
    schedule: "*/5 * * * *"
    capabilities: [browser, emu-gh, teams-mcp]
  agents:
    - name: picard
      charter: .squad/agents/picard/charter.md
    - name: belanna
      charter: .squad/agents/belanna/charter.md
  mcpServers:
    - github
    - azure-devops
  secrets:
    keyVaultRef: kv-squad-prod
```

**Decision: Do not build the operator as part of this sprint.** Helm-first, operator later.

---

## 9. Pod Topology Diagram

```
┌─────────────────────────────────────────────────────────┐
│  Namespace: squad                                        │
│                                                          │
│  ┌─────────────────── CronJob: ralph-watch ───────────┐  │
│  │  (fires every 5 min, concurrencyPolicy: Forbid)    │  │
│  │                                                     │  │
│  │  Pod: ralph-watch-{hash}                            │  │
│  │  ┌──────────────┐  ┌───────────┐  ┌─────────────┐  │  │
│  │  │ init: git-   │  │  ralph    │  │ mcp-github  │  │  │
│  │  │ sync         │  │  (main)   │  │ :3001       │  │  │
│  │  └──────────────┘  │           │  ├─────────────┤  │  │
│  │                    │  Claims   │  │ mcp-ado     │  │  │
│  │                    │  issues   │  │ :3002       │  │  │
│  │                    │  Creates  │  └─────────────┘  │  │
│  │                    │  Jobs ────┼──────────────────┐ │  │
│  │                    └───────────┘  localhost net   │ │  │
│  └────────────────────────────────────────────────── │─┘  │
│                                                       │    │
│  ┌──────── Job: squad-agent-{issue-N} ────────────── ▼ ─┐  │
│  │                                                      │  │
│  │  Pod: squad-agent-{hash}                             │  │
│  │  ┌──────────────┐  ┌───────────┐  ┌─────────────┐   │  │
│  │  │ init: git-   │  │  agent    │  │ mcp-github  │   │  │
│  │  │ sync         │  │  session  │  │ :3001       │   │  │
│  │  └──────────────┘  │ (picard/  │  ├─────────────┤   │  │
│  │                    │  belanna/ │  │ mcp-ado     │   │  │
│  │                    │  data...) │  │ :3002       │   │  │
│  │                    └───────────┘  └─────────────┘   │  │
│  │  ttlSecondsAfterFinished: 600                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                          │
│  ConfigMaps: squad-config, squad-mcp-config              │
│  Secrets: squad-secrets (managed by ESO → Key Vault)     │
│  ServiceAccount: squad-ralph (Workload Identity bound)   │
└─────────────────────────────────────────────────────────┘
                         │
                         │ GitHub API
                         ▼
              ┌─────────────────────┐
              │ Issue Board         │
              │ squad:copilot label │
              │ Issue assignment    │
              │ (distributed lock)  │
              └─────────────────────┘
```

---

## 10. Container Image Strategy

### Base Image

```dockerfile
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Runtime dependencies
RUN apt-get update && apt-get install -y \
    curl git jq nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=...] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install gh -y

# Copilot CLI (GitHub Copilot agent runner)
RUN npm install -g @github/copilot-cli

# PowerShell 7 (for script compatibility with ralph-watch.ps1 patterns)
RUN apt-get install -y powershell

# Squad scripts
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

ENV SQUAD_REPO_PATH=/git/repo
WORKDIR /app
```

**One image per role:**

| Image | Tag | Contents |
|-------|-----|----------|
| `squad-ralph` | `latest` | Base + ralph-k8s.sh (replaces ralph-watch.ps1) |
| `squad-agent` | `latest` | Base + run-agent.sh (spawns Copilot CLI session) |
| `squad-mcp-github` | `latest` | Node.js + GitHub MCP server |
| `squad-mcp-ado` | `latest` | Node.js + Azure DevOps MCP server |

All images built from the same repo via GitHub Actions, pushed to ACR.

---

## 11. Identified Blockers

| Blocker | Affects | Owner | Resolution |
|---------|---------|-------|------------|
| `ralph-watch.ps1` is Windows-specific (mutex, CimInstance) | Container image | Data | Write `ralph-k8s.sh` (Linux bash equivalent) — #1060 acceptance criteria |
| Copilot CLI runs on Windows/macOS; Linux container support TBD | Agent Job image | Data + B'Elanna | Test `@github/copilot-cli` on Ubuntu 24.04; confirm Linux support |
| Workload Identity setup (AKS) | Secrets | B'Elanna + Worf | Bicep template in `infrastructure/bicep/squad-aks.bicep` (#1060) |
| ESO install on DK8S | Secrets | B'Elanna | DK8S clusters may already have ESO; verify per #1061 |
| `needs:*` capability labels in K8s | Issue routing | Ralph | Pod affinity rules or node labels can map to capability keys |
| MCP server images don't exist yet | Sidecars | Data | Build images from `mcp-servers/` directory configs |
| git-sync init container needs GITHUB_TOKEN or SSH | Git access | Worf | Use the same Workload Identity token; configure git-sync auth |

---

## 12. Out of Scope (This ADR)

- **KAITO / LLM inference on K8s** — Covered separately (see `docs/squad-on-aks.md` §11)
- **Multi-cluster federation** — Single cluster first
- **Squad Operator / CRD** — Phase 2; explicitly deferred
- **Istio / service mesh** — Not needed for sidecar MCP model
- **HPA for agent Jobs** — Future; depends on queue depth metrics from GitHub
- **DK8S-specific policy restrictions** — #1061 scope

---

## Consequences

### Positive

- Squad deployable on any CNCF-conformant cluster in < 30 minutes with `helm install`
- Multi-machine coordination works without shared filesystem — pure GitHub API
- Secrets rotation without redeployment (ESO 1h refresh)
- Full observability: container logs → Log Analytics; CronJob metrics → Prometheus
- Phase 2 operator path is clear and non-disruptive (Helm can coexist with operator)

### Negative

- 10-second cold start per Ralph round (git-sync init container)
- Linux-only containers require rewriting `ralph-watch.ps1` patterns in bash/Python
- ESO dependency adds operational complexity (ESO must be installed on target cluster)
- Agent Job image must include Copilot CLI — verify Linux support before committing

### Risks

- **Copilot CLI Linux support:** If `@github/copilot-cli` doesn't run on Ubuntu containers, the agent Job model needs revision (potentially Deployment per agent with Windows nodes)
- **GitHub API rate limits:** Multiple Ralph instances + heartbeat comments could exhaust the 5000/hour quota; mitigate with label-based heartbeats instead of comments (already documented in `multi-machine-ralph-design.md`)
- **Helm chart complexity creep:** Sub-charts add overhead; keep it flat until complexity demands nesting

---

## References

- Issue #1059: Squad on Kubernetes — Architecture Design
- Issue #1060: AKS deployment
- Issue #1061: DK8S integration  
- Issue #1062: Helm packaging
- Issue #1066: K8s blog
- `ralph-watch.ps1` — current reconciliation loop implementation
- `.squad/research/multi-machine-ralph-design.md` — GitHub-native distributed coordination
- `.squad/research/persistent-squad-sessions.md` — session lifecycle patterns
- `docs/squad-on-aks.md` — AKS-specific deployment guide (prerequisite reading for #1060)
- `docs/adr/ADR-001-dk8s-squad-usage-standard.md` — upstream ADR for DK8S adoption
- CNCF: [git-sync](https://github.com/kubernetes/git-sync) — init container for repo cloning
- CNCF: [External Secrets Operator](https://external-secrets.io/) — secrets sync from Key Vault
