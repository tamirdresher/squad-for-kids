# Squad-on-Kubernetes — Cloud-Native Agent Orchestration

> **Issues:** #994 (primary), #1059 (architecture design), #999 (capability routing)  
> **Authors:** Seven (Research & Docs), Picard (Architecture Lead), B'Elanna (Infrastructure)  
> **Date:** 2026-03-20  
> **Status:** Approved — v1.0  
> **Relates to:** `docs/squad-on-aks.md`, `docs/adr-002-squad-on-kubernetes.md`, `docs/squad-on-k8s/capability-routing.md`

---

## Table of Contents

1. [Vision](#1-vision)
2. [Full Architecture Diagram](#2-full-architecture-diagram)
3. [Core Mapping: Agent → K8s Workload](#3-core-mapping-agent--k8s-workload)
4. [CRD Design: SquadTeam, SquadAgent, SquadRound](#4-crd-design-squadteam-squadagent-squadround)
5. [Node Capability Routing](#5-node-capability-routing)
6. [Scheduling Model](#6-scheduling-model)
7. [Storage Architecture](#7-storage-architecture)
8. [Auth and Secrets](#8-auth-and-secrets)
9. [Networking: Agent-to-Agent Communication](#9-networking-agent-to-agent-communication)
10. [K8s-Native Capability Routing (satisfies #999)](#10-k8s-native-capability-routing-satisfies-999)
11. [Migration Path: PowerShell/DevBox → Kubernetes](#11-migration-path-powershelldevbox--kubernetes)
12. [Appendix: Key Design Decisions](#12-appendix-key-design-decisions)

---

## 1. Vision

Squad-on-Kubernetes transforms our multi-agent orchestration from PowerShell scripts running on
Windows DevBoxes into cloud-native, K8s-scheduled workloads.

**The three core ideas:**

| Concept | PowerShell/DevBox | Kubernetes |
|---------|------------------|------------|
| **Agent** | `ralph-watch.ps1` running as a process | A **Pod** — isolated, health-probed, auto-restarting |
| **Team** | Agents manually launched per-machine | A **Deployment** — declarative replica set per agent role |
| **Squad Round** | Poll loop inside `ralph-watch.ps1` | A **Job** — discrete execution unit with TTL cleanup |

**What this unlocks:**

- `replicas: 3` for Ralph instead of provisioning three DevBoxes
- GitHub tokens never touch developer machines — mounted from Key Vault via CSI driver
- `needs:gpu` issues automatically routed to GPU-equipped nodes via `nodeSelector`
- A Squad "team" is a K8s resource: `kubectl apply -f squad-team.yaml`
- Crashed agents restart automatically; liveness probes catch infinite loops
- KAITO serves as an in-cluster LLM fallback when cloud API rate limits are hit

---

## 2. Full Architecture Diagram

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  AKS Cluster — namespace: squad-system                                       ║
║                                                                              ║
║  ┌─────────────────────────────────────────────────────────────────────┐    ║
║  │  Control Plane Components                                            │    ║
║  │                                                                      │    ║
║  │  ┌──────────────────┐   ┌──────────────────┐   ┌────────────────┐  │    ║
║  │  │  Squad Operator   │   │  Rate Pool Redis  │   │  Capability    │  │    ║
║  │  │  (Deployment/1)   │   │  (StatefulSet/1)  │   │  DaemonSet     │  │    ║
║  │  │                   │   │                   │   │  (per node)    │  │    ║
║  │  │ Watches CRDs      │   │ Shared token pool │   │ Labels nodes   │  │    ║
║  │  │ Reconciles state  │   │ for rate limits   │   │ squad.io/cap-* │  │    ║
║  │  └──────────────────┘   └──────────────────┘   └────────────────┘  │    ║
║  └─────────────────────────────────────────────────────────────────────┘    ║
║                                                                              ║
║  ┌─────────────────────────────────────────────────────────────────────┐    ║
║  │  Orchestrator Layer                                                  │    ║
║  │                                                                      │    ║
║  │  ┌─────────────────────────────────────────────┐                   │    ║
║  │  │  Ralph — Deployment (replicas: 2)            │                   │    ║
║  │  │  ┌───────────────────────────────────────┐  │                   │    ║
║  │  │  │  ralph-worker-0  │  ralph-worker-1   │  │                   │    ║
║  │  │  │  ┌────────────┐  │  ┌────────────┐  │  │                   │    ║
║  │  │  │  │ ralph-loop │  │  │ ralph-loop │  │  │                   │    ║
║  │  │  │  │ (main)     │  │  │ (main)     │  │  │                   │    ║
║  │  │  │  ├────────────┤  │  ├────────────┤  │  │                   │    ║
║  │  │  │  │ gh-cli     │  │  │ gh-cli     │  │  │                   │    ║
║  │  │  │  │ (sidecar)  │  │  │ (sidecar)  │  │  │                   │    ║
║  │  │  └───────────────────────────────────────┘  │                   │    ║
║  │  └─────────────────────────────────────────────┘                   │    ║
║  └─────────────────────────────────────────────────────────────────────┘    ║
║                                                                              ║
║  ┌─────────────────────────────────────────────────────────────────────┐    ║
║  │  On-Demand Agent Layer (Jobs, TTL=1h after completion)               │    ║
║  │                                                                      │    ║
║  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │    ║
║  │  │ picard-job   │  │ seven-job    │  │ data-job     │             │    ║
║  │  │ #994 work    │  │ #994 docs    │  │ #994 impl    │  ...        │    ║
║  │  └──────────────┘  └──────────────┘  └──────────────┘             │    ║
║  └─────────────────────────────────────────────────────────────────────┘    ║
║                                                                              ║
║  ┌─────────────────────────────────────────────────────────────────────┐    ║
║  │  Node Pools (AKS)                                                    │    ║
║  │                                                                      │    ║
║  │  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────────┐  │    ║
║  │  │  general-pool     │  │  gpu-pool         │  │  browser-pool   │  │    ║
║  │  │  Standard_D4s_v5  │  │  NC4as_T4_v3      │  │  Standard_D8s   │  │    ║
║  │  │  squad.io/cap-    │  │  nvidia.com/gpu:  │  │  squad.io/cap-  │  │    ║
║  │  │  general=true     │  │  true             │  │  browser=true   │  │    ║
║  │  │  (min:1, max:10)  │  │  (min:0, max:3)   │  │  (min:0, max:5) │  │    ║
║  │  └──────────────────┘  └──────────────────┘  └─────────────────┘  │    ║
║  └─────────────────────────────────────────────────────────────────────┘    ║
║                                                                              ║
║  ┌─────────────────────────────────────────────────────────────────────┐    ║
║  │  Shared Services                                                     │    ║
║  │                                                                      │    ║
║  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │    ║
║  │  │ squad-config │  │  gh-secret  │  │ session-pvc  │  │  KAITO   │ │    ║
║  │  │ ConfigMap    │  │  Secret     │  │  Azure Files │  │  Service │ │    ║
║  │  │ .squad/ →    │  │  GH_TOKEN   │  │  /session    │  │  llm-    │ │    ║
║  │  │ K8s CM       │  │  mounted    │  │  state       │  │  fallback│ │    ║
║  │  └─────────────┘  └─────────────┘  └─────────────┘  └──────────┘ │    ║
║  └─────────────────────────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════════════════════════╝
                 │                              │
                 ▼                              ▼
    ┌────────────────────┐          ┌──────────────────────┐
    │  GitHub API         │          │  Azure Key Vault       │
    │  Issues, PRs, Labels│          │  GH_TOKEN, API keys    │
    │  rate: 5000/hr      │          │  CSI driver mount      │
    └────────────────────┘          └──────────────────────┘
```

---

## 3. Core Mapping: Agent → K8s Workload

### 3.1 Workload Type by Agent Role

Each agent maps to a specific K8s workload pattern based on its execution model:

| Agent | Workload Type | Replicas | Rationale |
|-------|--------------|----------|-----------|
| **Ralph** | `Deployment` | 2–5 | Long-running reconciliation loop; needs stable identity, fast restarts |
| **Picard** | `Job` (on-demand) | 1 | Architecture decisions are discrete work units |
| **Seven** | `Job` (on-demand) | 1 | Research/docs tasks are bounded, one-at-a-time |
| **Data** | `Job` (on-demand) | 1 | Code tasks are bounded; multiple parallel allowed |
| **B'Elanna** | `Job` (on-demand) | 1 | Infrastructure work is discrete and sequential |
| **Worf** | `Job` (on-demand) | 1 | Security reviews are bounded |
| **Troi** | `Job` (on-demand) | 1 | Blog writing tasks are discrete |
| **Neelix** | `CronJob` | 1 | Scheduled news briefings (daily/weekly) |
| **Scribe** | `Job` (sidecar option) | 1 | Logging runs alongside other agents |
| **KAITO** | `Deployment` (shared) | 1 | Model server — always-on fallback LLM |

### 3.2 Pod-per-Agent Model

Every named agent runs in its own pod:

```
┌─────── Ralph Pod ────────┐
│  Container: ralph-loop   │  ← main process (PowerShell/Node.js)
│  Container: gh-sidecar   │  ← gh CLI helper (local HTTP)
│  Container: mcp-tools    │  ← Tool servers (local sockets)
│  Volume: session-pvc     │  ← /session state mount
│  Volume: squad-config    │  ← /squad/.squad/ (ConfigMap)
│  Volume: gh-secret       │  ← /run/secrets/github-token
└──────────────────────────┘

┌─────── Seven Job Pod ─────┐
│  Container: seven-agent  │  ← main agent (Copilot CLI)
│  Container: gh-sidecar   │  ← gh CLI helper
│  Volume: session-pvc     │  ← /session (read/write)
│  Volume: squad-config    │  ← /squad (read-only)
│  Volume: gh-secret       │  ← /run/secrets/github-token
└──────────────────────────┘
```

**Why Pod-per-Agent wins over sidecar model:**

| Concern | Pod-per-Agent | Sidecar/All-in-One |
|---------|--------------|-------------------|
| Isolation | Full memory/CPU isolation | Shared failure domain |
| Independent scaling | `replicas: 3` per agent | Coupled scaling |
| Resource limits | Per-agent `requests/limits` | Shared pool |
| Scheduling | Per-agent `nodeSelector` for `needs:*` | Single scheduling decision |
| Restart | Agent restart without disrupting others | Sidecar restart ripples |

---

## 4. CRD Design: SquadTeam, SquadAgent, SquadRound

The Squad Operator watches three CRDs. The full CRD YAML specs are in
`infrastructure/k8s/crds/`.

### 4.1 SquadTeam

Defines the team composition — which agents belong together and how they route work.

```yaml
apiVersion: squad.github.com/v1alpha1
kind: SquadTeam
metadata:
  name: tamresearch1-squad
  namespace: squad-system
spec:
  repository: tamirdresher_microsoft/tamresearch1
  configRef: squad-config          # ConfigMap holding .squad/ equivalent

  agents:
    - ralph
    - picard
    - seven
    - data
    - belanna
    - worf
    - troi
    - neelix

  routingRules:
    - label: squad:picard
      agent: picard
      priority: 10
    - label: squad:seven
      agent: seven
      priority: 10
    - label: squad:belanna
      agent: belanna
      priority: 10
    - label: squad:data
      agent: data
      priority: 10
    - label: research
      agent: seven
      priority: 50
    - label: infrastructure
      agent: belanna
      priority: 50

  circuitBreaker:
    enabled: true
    failureThreshold: 5
    resetAfterSeconds: 300

status:
  agentCount: 8
  circuitState: Closed
```

### 4.2 SquadAgent

Defines a single agent's capabilities, model, and resource profile.

```yaml
apiVersion: squad.github.com/v1alpha1
kind: SquadAgent
metadata:
  name: seven
  namespace: squad-system
spec:
  role: seven
  model: claude-sonnet-4.5          # primary model
  fallbackModel: kaito-mistral      # KAITO fallback when rate-limited

  needsLabels:
    - squad:seven
    - research
    - documentation

  maxRoundsPerHour: 20

  # Node scheduling — maps from needs:* issue labels
  nodeRequirements:
    required:                        # nodeSelector
      squad.io/capability-general: "true"
    preferred:                       # nodeAffinity preferredDuring...
      - key: squad.io/capability-browser
        weight: 30

  image:
    repository: acrsquadprod.azurecr.io/squad/seven
    tag: "1.2.0"
    pullPolicy: IfNotPresent

  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"

status:
  lastRound: 142
  totalRoundsToday: 7
  modelUsage:
    primaryCalls: 45
    fallbackCalls: 3
```

### 4.3 SquadRound

Records a single execution round — the audit trail for every agent action.

```yaml
apiVersion: squad.github.com/v1alpha1
kind: SquadRound
metadata:
  name: ralph-round-142
  namespace: squad-system
spec:
  agentRef: ralph
  roundNumber: 142
  triggeredBy: scheduled             # scheduled | manual | webhook | retry
  repository: tamirdresher_microsoft/tamresearch1

status:
  phase: completed                   # pending | running | completed | failed | skipped
  startTime: "2026-03-20T14:30:00Z"
  completionTime: "2026-03-20T14:31:47Z"
  durationSeconds: 107
  issueCount: 3
  prsCreated: 1
  issuesProcessed:
    - issueNumber: 994
      title: "Architecture: Squad-on-Kubernetes"
      action: assigned
      assignedTo: seven
    - issueNumber: 999
      title: "K8s-Native Capability Routing"
      action: routed
      assignedTo: belanna
```

### 4.4 CRD Relationship Diagram

```
SquadTeam
  tamresearch1-squad
    │
    ├── refs SquadAgent: ralph
    │     └── creates → Deployment: ralph
    │           └── creates → SquadRound: ralph-round-N (each poll cycle)
    │
    ├── refs SquadAgent: seven
    │     └── creates → Job: seven-job-{issue-number}
    │           └── creates → SquadRound: seven-round-N
    │
    └── refs SquadAgent: picard
          └── creates → Job: picard-job-{issue-number}
                └── creates → SquadRound: picard-round-N
```

---

## 5. Node Capability Routing

The `needs:*` label system on GitHub issues maps directly to K8s node labels. This is the bridge
between the work (issue requirements) and the infrastructure (node capabilities).

### 5.1 Label Mapping Table

| GitHub Issue Label | K8s Node Label | Node Pool | Source |
|-------------------|---------------|-----------|--------|
| `needs:gpu` | `nvidia.com/gpu: "true"` | `gpu-pool` | NVIDIA device plugin (automatic) |
| `needs:browser` | `squad.io/capability-browser: "true"` | `browser-pool` | Capability DaemonSet |
| `needs:high-memory` | `squad.io/memory-tier: "high"` | `highmem-pool` | Node pool configuration |
| `needs:whatsapp` | `squad.io/capability-whatsapp: "true"` | Any | Capability DaemonSet |
| `needs:azure-speech` | `squad.io/capability-azure-speech: "true"` | Any | Capability DaemonSet |
| `needs:personal-gh` | `squad.io/capability-personal-gh: "true"` | Any | Capability DaemonSet |
| `needs:teams-mcp` | `squad.io/capability-teams-mcp: "true"` | Any | Capability DaemonSet |
| `needs:onedrive` | `squad.io/capability-onedrive: "true"` | Any | Capability DaemonSet |
| *(no needs label)* | *(any node)* | `general-pool` | Default scheduling |

### 5.2 Pod Spec Examples

**Issue with `needs:gpu`:**
```yaml
spec:
  nodeSelector:
    nvidia.com/gpu: "true"
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  containers:
    - name: agent
      resources:
        limits:
          nvidia.com/gpu: "1"
```

**Issue with `needs:browser`:**
```yaml
spec:
  nodeSelector:
    squad.io/capability-browser: "true"
  containers:
    - name: agent
      resources:
        requests:
          cpu: "1000m"
          memory: "2Gi"
```

**Issue with `needs:high-memory`:**
```yaml
spec:
  nodeSelector:
    squad.io/memory-tier: "high"
  containers:
    - name: agent
      resources:
        requests:
          memory: "8Gi"
        limits:
          memory: "16Gi"
```

**Issue with multiple needs (`needs:gpu` + `needs:browser`):**
```yaml
spec:
  nodeSelector:
    nvidia.com/gpu: "true"
    squad.io/capability-browser: "true"
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
```

> **Detailed design** (including DaemonSet, soft preferences, AKS node pool CLI commands):
> see `docs/squad-on-k8s/capability-routing.md` (satisfies issue #999)

---

## 6. Scheduling Model

### 6.1 Ralph: Deployment with Liveness Probe

Ralph runs as a long-lived `Deployment`, not a `CronJob`. The rationale: a Deployment provides
faster reaction time, richer health monitoring, and maps naturally to Ralph's existing
reconciliation loop.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ralph
  namespace: squad-system
spec:
  replicas: 2                        # two workers for redundancy
  selector:
    matchLabels:
      squad.io/agent: ralph
  template:
    metadata:
      labels:
        squad.io/agent: ralph
    spec:
      serviceAccountName: squad-agent
      containers:
        - name: ralph-loop
          image: acrsquadprod.azurecr.io/squad/ralph:latest
          args: ["--watch", "--interval=300"]
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 60
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /readyz
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 30
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "2Gi"
          env:
            - name: GH_TOKEN
              valueFrom:
                secretKeyRef:
                  name: squad-github-token
                  key: token
            - name: SQUAD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          volumeMounts:
            - name: squad-config
              mountPath: /squad
              readOnly: true
            - name: session-storage
              mountPath: /session
      volumes:
        - name: squad-config
          configMap:
            name: squad-config
        - name: session-storage
          persistentVolumeClaim:
            claimName: squad-session-pvc
```

**CronJob comparison:**

| | Deployment (chosen) | CronJob |
|-|---------------------|---------|
| Reaction time | Immediate (running loop) | Up to 5 min delay |
| Health monitoring | Liveness/readiness probes | No runtime health checks |
| Restart on failure | Automatic (K8s controller) | Next schedule window |
| Leader election | Needed (KEDA or lease API) | Implicit (one pod per schedule) |
| Observability | Metrics server, HPA | Job history only |

### 6.2 Neelix: CronJob (Scheduled Reports)

Neelix generates news briefings on a fixed schedule — a natural `CronJob` fit:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: neelix-daily-briefing
  namespace: squad-system
spec:
  schedule: "0 8 * * *"             # 08:00 UTC daily
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 3600
      template:
        spec:
          restartPolicy: OnFailure
          serviceAccountName: squad-agent
          containers:
            - name: neelix
              image: acrsquadprod.azurecr.io/squad/neelix:latest
              args: ["--mode=daily-briefing"]
```

### 6.3 On-Demand Agents: Job per Issue

When Ralph routes an issue to Picard, Seven, Data, etc., the operator creates a
`Job` — a single-purpose, self-cleaning pod:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: seven-job-994
  namespace: squad-system
  labels:
    squad.io/agent: seven
    squad.io/issue: "994"
    squad.io/round: "142"
spec:
  ttlSecondsAfterFinished: 3600     # auto-delete 1h after completion
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: squad-agent
      # nodeSelector injected by operator based on issue needs:* labels
      containers:
        - name: seven-agent
          image: acrsquadprod.azurecr.io/squad/seven:latest
          args: ["--issue=994", "--repo=tamirdresher_microsoft/tamresearch1"]
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "2000m"
              memory: "4Gi"
```

### 6.4 Squad Operator Scheduling Logic

```
GitHub Issue Created/Labeled
           │
           ▼
    Ralph Poll Cycle (5 min)
           │
           ├─ Issue has needs:* labels?
           │       │
           │       ├── Yes → Build nodeSelector map
           │       └── No  → Use default node pool
           │
           ├─ Which agent handles this label? (routingRules)
           │
           └─ Create SquadRound CR
                    │
                    ▼
           Squad Operator reconciles SquadRound
                    │
                    └─ Creates Job with:
                         - correct image (agent role)
                         - nodeSelector (from needs:* mapping)
                         - GH_TOKEN secret mount
                         - session PVC mount
                         - TTL=3600
```

---

## 7. Storage Architecture

### 7.1 Storage Components

| Data | Storage Type | K8s Resource | Persistence |
|------|-------------|-------------|-------------|
| `.squad/` config (routing, team, decisions) | ConfigMap | `squad-config` | Version-controlled in Git |
| Session state (agent working memory) | Azure Files PVC | `squad-session-pvc` | Durable, shared read/write |
| Rate pool (token counters) | Redis | `rate-pool` StatefulSet | In-memory + AOF persistence |
| Agent logs | Azure Monitor | Log Analytics | 30-day retention |
| SquadRound audit trail | etcd (via CRD) | `SquadRound` CRs | K8s etcd, 90-day history |

### 7.2 ConfigMap: Squad Config

The `.squad/` directory becomes a K8s ConfigMap, keeping the same structure:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: squad-config
  namespace: squad-system
data:
  routing.md: |
    # Routing Rules
    ...  (content of .squad/routing.md)
  team.md: |
    # Team
    ...  (content of .squad/team.md)
  decisions.md: |
    # Decisions
    ...  (content of .squad/decisions.md)
  watch-config.json: |
    {
      "interval": 300,
      "repo": "tamirdresher_microsoft/tamresearch1",
      "maxConcurrentAgents": 5
    }
```

**Sync strategy:** A GitHub Actions workflow rebuilds the ConfigMap whenever `.squad/*.md` changes:

```yaml
# .github/workflows/sync-squad-config.yml
on:
  push:
    paths: ['.squad/**']
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          kubectl create configmap squad-config \
            --from-file=.squad/ \
            --dry-run=client -o yaml | kubectl apply -f -
```

### 7.3 PersistentVolumeClaim: Session State

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: squad-session-pvc
  namespace: squad-system
spec:
  accessModes:
    - ReadWriteMany                  # Multiple agents need concurrent access
  storageClassName: azurefile-csi    # Azure Files for RWX in AKS
  resources:
    requests:
      storage: 50Gi
```

Mounted at `/session` in every agent pod. Structure mirrors the current DevBox layout:

```
/session/
├── agents/
│   ├── seven/
│   │   └── sessions/              # Seven's session logs
│   └── picard/
│       └── sessions/
├── cross-agent/                   # Replaces ~/.squad/cross-machine/
│   ├── tasks/
│   └── decisions/inbox/
└── heartbeats/                    # Agent heartbeat files
    ├── ralph.json
    └── seven.json
```

---

## 8. Auth and Secrets

### 8.1 Phase 1: K8s Secrets

GitHub token stored as a K8s Secret, mounted as environment variable:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: squad-github-token
  namespace: squad-system
type: Opaque
stringData:
  token: "ghp_..."                  # Never commit; inject via CI or Key Vault
```

Pod reference:
```yaml
env:
  - name: GH_TOKEN
    valueFrom:
      secretKeyRef:
        name: squad-github-token
        key: token
```

### 8.2 Phase 2: Azure Key Vault + Workload Identity (recommended for production)

```
Azure AD App Registration
         │
         │  Federated credential (OIDC)
         ▼
AKS Workload Identity
         │
         │  RBAC: Key Vault Secrets User
         ▼
Azure Key Vault
  ├── secret: squad-github-token
  ├── secret: squad-copilot-key
  └── secret: squad-teams-webhook
         │
         │  CSI SecretProviderClass
         ▼
Pod volume mount: /run/secrets/
  ├── github-token
  └── copilot-key
```

```yaml
# SecretProviderClass for Azure Key Vault
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: squad-keyvault-secrets
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    clientID: "${WORKLOAD_IDENTITY_CLIENT_ID}"
    keyvaultName: kv-squad-prod
    tenantId: "${AZURE_TENANT_ID}"
    objects: |
      array:
        - |
          objectName: squad-github-token
          objectType: secret
          objectVersion: ""
        - |
          objectName: squad-copilot-key
          objectType: secret
```

### 8.3 KAITO as LLM Fallback

KAITO (Kubernetes AI Toolchain Operator) runs a local LLM inference server inside the cluster.
Agents fall back to KAITO when primary cloud API rate limits are hit or when network-isolated
work is preferred:

```yaml
# Agent model routing logic (pseudo-code in squad.config.ts equivalent)
model:
  primary: claude-sonnet-4.5         # Copilot / Anthropic API
  fallback: kaito-mistral-7b         # In-cluster KAITO deployment
  fallbackConditions:
    - rateLimitHit: true
    - primaryUnavailable: true
    - issueLabel: needs:offline
```

KAITO Service endpoint: `http://kaito-llm-service.squad-system.svc.cluster.local:8080`

---

## 9. Networking: Agent-to-Agent Communication

### 9.1 K8s Service Topology

Every long-running agent and shared service gets a K8s Service. Job-based agents
communicate via the shared services, not directly to each other.

```
squad-system namespace
│
├── Service: ralph-service          → Ralph Deployment pods
│   ClusterIP: 10.0.0.10:8080
│   Endpoint: /health, /metrics, /trigger
│
├── Service: rate-pool-service      → Redis StatefulSet
│   ClusterIP: 10.0.0.20:6379
│   Used by: all agents for token rate limiting
│
├── Service: kaito-llm-service      → KAITO Deployment
│   ClusterIP: 10.0.0.30:8080
│   Used by: all agents for LLM fallback
│
└── Service: squad-operator-service → Squad Operator
    ClusterIP: 10.0.0.40:9443
    Webhook endpoint for CRD admission
```

### 9.2 Agent Communication Patterns

**Ralph → Agent Job (trigger):**
Ralph doesn't call agents directly. It creates a `SquadRound` CR, and the Squad Operator
creates the appropriate Job. This is the K8s-native "fan-out" pattern.

```
Ralph → creates SquadRound CR → Operator watches → creates Job
```

**Agent → Shared Services:**
All agents consume shared services via DNS names (no hardcoded IPs):

```bash
# Rate pool access (from any agent pod)
redis-cli -h rate-pool-service.squad-system.svc.cluster.local -p 6379

# KAITO LLM fallback
curl http://kaito-llm-service.squad-system.svc.cluster.local:8080/v1/completions

# Health check another agent
curl http://ralph-service.squad-system.svc.cluster.local:8080/health
```

**Cross-agent collaboration (inbox pattern):**
When agents need to pass work to each other, they use the session PVC's `cross-agent/` directory
or write to the `squad-config` ConfigMap inbox — the same pattern as the current
`.squad/decisions/inbox/` filesystem approach, but on a shared Azure Files mount.

### 9.3 Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: squad-agent-policy
  namespace: squad-system
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/part-of: squad
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: squad-system
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: squad-system
    - to: []                         # Allow external (GitHub API, Copilot)
      ports:
        - port: 443
          protocol: TCP
```

---

## 10. K8s-Native Capability Routing (satisfies #999)

> This section provides the design summary. The full detailed spec lives in
> `docs/squad-on-k8s/capability-routing.md`.

### 10.1 The Problem

Current system: `discover-machine-capabilities.ps1` runs on each DevBox, probes hardware/software,
and writes `~/.squad/machine-capabilities.json`. Ralph's `Test-MachineCapability` checks this
before claiming an issue with a `needs:*` label.

In K8s, there are no DevBoxes — the equivalent is **node labels**.

### 10.2 Design Overview

```
GitHub Issue Label        K8s Mechanism              Result
──────────────────        ─────────────────          ──────
needs:gpu            →    nodeSelector +             Pod lands on GPU node
                          toleration

needs:browser        →    nodeSelector               Pod lands on browser-
                          squad.io/capability-       capable node
                          browser: "true"

needs:high-memory    →    nodeSelector               Pod lands on high-
                          squad.io/memory-           memory node
                          tier: "high"
```

### 10.3 Squad Operator Injection

When the operator creates a Job for an issue, it reads the issue's `needs:*` labels and injects
the corresponding `nodeSelector` into the Job's pod spec:

```go
// pseudo-code: operator reconciliation
func injectCapabilityScheduling(issue Issue, jobSpec *batchv1.Job) {
    nodeSelector := map[string]string{}

    for _, label := range issue.Labels {
        if mapping, ok := capabilityMapping[label]; ok {
            for k, v := range mapping.NodeSelector {
                nodeSelector[k] = v
            }
            jobSpec.Spec.Template.Spec.Tolerations = append(
                jobSpec.Spec.Template.Spec.Tolerations,
                mapping.Tolerations...,
            )
        }
    }

    jobSpec.Spec.Template.Spec.NodeSelector = nodeSelector
}

var capabilityMapping = map[string]CapabilitySpec{
    "needs:gpu":          {NodeSelector: {"nvidia.com/gpu": "true"}, ...},
    "needs:browser":      {NodeSelector: {"squad.io/capability-browser": "true"}},
    "needs:high-memory":  {NodeSelector: {"squad.io/memory-tier": "high"}},
    "needs:whatsapp":     {NodeSelector: {"squad.io/capability-whatsapp": "true"}},
}
```

### 10.4 Capability DaemonSet

A DaemonSet runs on every node, probes installed tools, and patches node labels:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: squad-capability-discovery
  namespace: squad-system
spec:
  selector:
    matchLabels:
      app: squad-capability-discovery
  template:
    metadata:
      labels:
        app: squad-capability-discovery
    spec:
      serviceAccountName: capability-discoverer   # needs node/patch RBAC
      containers:
        - name: discoverer
          image: acrsquadprod.azurecr.io/squad/capability-discoverer:latest
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: PROBE_INTERVAL_SECONDS
              value: "300"
          securityContext:
            privileged: false
            capabilities:
              drop: ["ALL"]
```

The discoverer probes for: Playwright/Chromium, WhatsApp session files, Azure Speech SDK,
mounted secrets (personal-gh, emu-gh, OneDrive FUSE), GPU device availability.

---

## 11. Migration Path: PowerShell/DevBox → Kubernetes

### 11.1 Current vs Future Comparison

| Dimension | Current (PowerShell/DevBox) | Future (K8s/AKS) |
|-----------|----------------------------|------------------|
| **Agent execution** | `ralph-watch.ps1` per machine | K8s Deployment + liveness probe |
| **Capability detection** | `discover-machine-capabilities.ps1` | Capability DaemonSet → node labels |
| **Issue routing** | `Test-MachineCapability` function | Squad Operator + nodeSelector injection |
| **Scaling** | Provision more DevBoxes manually | `kubectl scale deployment/ralph --replicas=5` |
| **Rate limiting** | Shared file `~/.squad/rate-pool.json` | Redis Service |
| **State** | Local filesystem `.squad/` | ConfigMap (config) + PVC (session) |
| **Auth** | Local `gh auth login` per machine | K8s Secret or Workload Identity |
| **Cross-agent coordination** | `.squad/cross-machine/` files | Session PVC `cross-agent/` + CRD inbox |
| **Monitoring** | Ralph self-reporting heartbeats | Azure Monitor + Prometheus |
| **Recovery** | Manual restart or watch script | K8s liveness probes + auto-restart |
| **Deployment** | Manual PS1 execution | `helm upgrade --install squad ./squad-chart` |
| **Team config** | `.squad/team.md` (local) | `SquadTeam` CRD + ConfigMap |

### 11.2 Phased Migration

```
Phase 1 — Containerization (Weeks 1-4)
────────────────────────────────────────
├── Build Docker images for each agent (ralph, seven, picard, data, ...)
├── Run agents locally with docker-compose (validate logic without K8s)
├── Migrate .squad/ to ConfigMap structure
└── Acceptance: All agents run in containers, same behavior as PS1 scripts

Phase 2 — K8s Basics (Weeks 5-8)
──────────────────────────────────
├── Deploy Ralph as Deployment on AKS
├── Deploy shared services: Redis (rate pool), squad-config ConfigMap
├── K8s Secrets for GH_TOKEN
├── On-demand Jobs for Seven, Picard, Data
└── Acceptance: Ralph polls GitHub, routes to agent Jobs, Jobs complete

Phase 3 — Capability Routing (Weeks 9-12)
───────────────────────────────────────────
├── Deploy Capability DaemonSet
├── Create AKS node pools: gpu-pool, browser-pool, highmem-pool
├── Squad Operator: inject nodeSelector from needs:* labels
└── Acceptance: needs:gpu issue lands on GPU node automatically

Phase 4 — Production Hardening (Weeks 13-16)
──────────────────────────────────────────────
├── Workload Identity (replace K8s Secrets)
├── KAITO LLM fallback deployment
├── Network policies, RBAC, pod security admission
├── Azure Monitor dashboards + alerts
└── Acceptance: Zero manual interventions needed for 2-week run

Phase 5 — Operator Graduation (Weeks 17-20)
──────────────────────────────────────────────
├── Full Squad Operator with SquadTeam/SquadAgent/SquadRound CRDs
├── Replace Helm-templated resources with Operator reconciliation
├── GitOps via ArgoCD or Flux
└── Acceptance: `kubectl apply -f squad-team.yaml` deploys the full team
```

### 11.3 DevBox Parallel Run

During migration, DevBox and K8s can run in parallel:

```
DevBox (existing)              AKS (new)
ralph-watch.ps1 ──────────────► Ralph Deployment
                               (same GitHub repo, different claim prefix)

DevBox claims: "DEVBOX-"       K8s claims: "K8S-"
```

This prevents double-claiming of issues and allows gradual confidence-building before
deprecating the DevBox setup.

---

## 12. Appendix: Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Pod-per-agent vs sidecar | **Pod-per-agent** | Independent lifecycle, scaling, resource limits |
| Ralph: CronJob vs Deployment | **Deployment** | Faster reaction (5-min window → immediate); richer probes |
| MCP servers | **Sidecar** per-agent | Localhost networking; no service discovery overhead |
| Helm vs Operator (Phase 1) | **Helm-first** | Ship sooner; graduate to Operator in Phase 5 |
| State: PV vs Git | **Git (config) + PVC (session)** | Config is version-controlled; session state needs RWX |
| Auth: Secrets vs Workload Identity | **Secrets (Phase 1) → WI (Phase 2+)** | Fast start; production-grade in Phase 2 |
| KAITO role | **LLM fallback** | Cost + latency buffer; not primary execution path |
| Capability detection | **DaemonSet → node labels** | Replaces `discover-machine-capabilities.ps1`; K8s-native |
| Rate limiting | **Redis** | Shared across all replicas; atomic operations; existing rate-pool patterns |

---

## Related Documents

| Document | Purpose |
|----------|---------|
| `docs/squad-on-k8s/capability-routing.md` | Detailed capability routing design (closes #999) |
| `docs/squad-on-aks.md` | AKS-specific deployment guide (Azure infrastructure) |
| `docs/adr-002-squad-on-kubernetes.md` | Architecture Decision Record |
| `docs/squad-on-kubernetes-architecture.md` | Extended architecture (predecessor, issue #1059) |
| `infrastructure/k8s/crds/` | CRD YAML definitions (SquadTeam, SquadAgent, SquadRound) |
| `infrastructure/helm/squad/` | Helm chart (values.yaml, templates) |

---

*Document authored by Seven (Research & Docs) · Issue #994 · 2026-03-20*
