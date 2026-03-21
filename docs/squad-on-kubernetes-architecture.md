# Squad on Kubernetes — Architecture Design

**Issue:** #1059  
**Author:** Picard (Architecture Lead)  
**Date:** 2026-03-20  
**Status:** Design Document — v1.0  
**Reviewers:** B'Elanna (Infrastructure), Data (Implementation)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State](#2-current-state)
3. [Core Concepts: Agent-to-Workload Mapping](#3-core-concepts-agent-to-workload-mapping)
4. [Container Image Strategy](#4-container-image-strategy)
5. [Secrets Management](#5-secrets-management)
6. [Networking: Agent Communication & MCP Servers](#6-networking-agent-communication--mcp-servers)
7. [Scaling Strategy](#7-scaling-strategy)
8. [Scheduling Model](#8-scheduling-model)
9. [State Management](#9-state-management)
10. [Multi-Tenant Architecture](#10-multi-tenant-architecture)
11. [GitOps Deployment Model](#11-gitops-deployment-model)
12. [Helm Chart Structure](#12-helm-chart-structure)
13. [Squad Operator: CRD Model](#13-squad-operator-crd-model)
14. [Phased Implementation Plan](#14-phased-implementation-plan)
15. [Architecture Decision Records](#15-architecture-decision-records)
16. [Appendix: Component Diagrams](#16-appendix-component-diagrams)

---

## 1. Executive Summary

Squad agents today run as PowerShell scripts on Windows DevBoxes — one machine per agent, mutex-based
concurrency, heartbeat files, and manual restarts. This works for development but does not scale.

**The goal:** Lift Squad into Kubernetes so that:

- Every agent is a pod with defined resources, health probes, and automatic restart
- Scaling happens by adjusting `replicas`, not by provisioning more DevBoxes
- Auth tokens never touch developer machines — they live in Key Vault, mounted via CSI driver
- A Squad "team" is a Kubernetes resource, deployed with `helm install` or `kubectl apply`
- Ralph's 5-minute polling loop becomes a CronJob (or a Deployment with a liveness loop — ADR below)

**Decision summary** (full ADRs in §15):

| Question | Decision |
|----------|----------|
| Pod-per-agent vs sidecar | **Pod-per-agent** — isolated lifecycle, independent scaling |
| Ralph: CronJob vs Deployment | **Deployment with liveness probe** — faster reaction, richer observability |
| MCP servers: sidecar vs separate Deployment | **Sidecar** for per-agent MCPs, **shared Deployment** for team-wide MCPs |
| Helm vs Operator (day-1) | **Helm-first** — ship faster, graduate to Operator in Phase 3 |
| State: PV vs Git | **Git-primary** for decisions/config, **PVC (Azure Files)** for session state |
| Auth: K8s Secrets vs Workload Identity | **K8s Secrets for Phase 1**, **Workload Identity for Phase 2+** |

---

## 2. Current State

```
Developer Machine (Windows DevBox)
│
├── ralph-watch.ps1          ← PowerShell 7 loop, runs every 5 min
│   ├── Mutex guard          ← prevents duplicate instances
│   ├── Heartbeat JSON       ← ~/.squad/ralph-heartbeat.json
│   ├── Lockfile             ← .ralph-watch.lock
│   └── Spawns: gh copilot agent (Copilot CLI) for each issue
│
├── .squad/                  ← All state (decisions, agent history, tasks)
│   ├── decisions.md
│   ├── routing.md
│   ├── watch-config.json
│   └── cross-machine/       ← Coordination between DevBoxes (file-based)
│
├── squad.config.ts          ← Model routing, casting, governance
└── mcp-servers/             ← MCP server binaries/configs (per-machine)
```

**Pain points:**
- Agent crashes require manual intervention (no auto-restart)
- Scaling requires provisioning another DevBox and repeating setup
- `cross-machine/` file-based coordination is fragile across machines
- GitHub tokens stored in machine credential stores (inconsistent)
- No resource limits — runaway agents can starve the machine

---

## 3. Core Concepts: Agent-to-Workload Mapping

### 3.1 The Pod-per-Agent Model

Each named agent (Ralph, Picard, Seven, B'Elanna, Data, Scribe, Worf) maps to exactly one
Kubernetes workload type. Agents are **not** co-located in a single pod — they are independent
pods with their own resource limits, restart policies, and scheduling constraints.

```
┌─────────────────────────────────────────────────────────────────┐
│  AKS Cluster — namespace: squad-system                           │
│                                                                  │
│  ┌─────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │  ralph           │  │  picard        │  │  scribe        │   │
│  │  Deployment/1    │  │  Deployment/1  │  │  Deployment/1  │   │
│  │  (long-running)  │  │  (always-on)   │  │  (always-on)   │   │
│  └────────┬─────────┘  └───────┬────────┘  └───────┬────────┘  │
│           │                    │                    │           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Agent Job Pool (spawned on demand)          │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │   │
│  │  │  Job:    │  │  Job:    │  │  Job:    │  ...          │   │
│  │  │  data-   │  │  seven-  │  │  worf-   │              │   │
│  │  │  issue42 │  │  issue87 │  │  issue99 │              │   │
│  │  └──────────┘  └──────────┘  └──────────┘              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Shared Services                                          │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐ │   │
│  │  │  Redis       │  │  ConfigMap   │  │  PVC           │ │   │
│  │  │  (rate pool) │  │  (routing)   │  │  (squad state) │ │   │
│  │  └──────────────┘  └──────────────┘  └────────────────┘ │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Workload Type Decision Matrix

| Agent | K8s Workload | Replicas | Reason |
|-------|-------------|----------|--------|
| **Ralph** | `Deployment` | 1–3 | Long-running watch loop; StatefulSet if stable pod names needed for leader election |
| **Picard** | `Deployment` | 1 | Always-on architect; singleton is appropriate |
| **Scribe** | `Deployment` | 1 | Session logger; singleton, must not run concurrently |
| **Seven** | `Deployment` | 1–2 | Research agent; can run multiple instances for different research tracks |
| **B'Elanna** | `Deployment` | 1 | Infrastructure lead; singleton (infra changes are sequential) |
| **Data** | `Deployment` | 1–4 | Code agent; most parallelizable — each instance works a separate issue |
| **Worf** | `Deployment` | 1 | Security agent; singleton (security reviews are sequential) |
| **Troi** | `Deployment` | 1 | Content agent; singleton |
| **Neelix** | `Deployment` | 1 | Reporter; singleton |
| **Agent Jobs** | `Job` (TTL 1h) | Per-issue | Spawned by Ralph for specific issues; auto-cleanup via `ttlSecondsAfterFinished` |
| **Scheduled Tasks** | `CronJob` | — | Daily digests, weekly reports, scheduled triage runs |

### 3.3 Ralph as Deployment (not CronJob)

Ralph's current `ralph-watch.ps1` is a **long-running reconciliation loop** — not a one-shot
job. It holds a mutex, maintains heartbeat, tracks consecutive failures, and accumulates round
history in-process. A CronJob would lose this in-process state on every invocation.

```
Deployment (Ralph)          vs          CronJob (Ralph)
─────────────────────────────────────────────────────────
✅ Persistent in-process state           ❌ Cold start every 5 min
✅ Liveness probe → auto-restart         ❌ No self-healing between runs
✅ Fast reaction to new issues           ❌ Maximum reaction time = schedule interval
✅ Leader election across replicas       ⚠️  Concurrency requires external lock
✅ Streaming logs                        ❌ Logs only on completion
❌ Slightly more complex lifecycle       ✅ Simpler lifecycle
```

**Decision: Ralph as Deployment** with `replicas: 1` (Phase 1), scaled with
leader-election (Phase 2), or StatefulSet for stable pod names across restarts.

### 3.4 On-Demand Agent Jobs

When Ralph claims an issue, it spawns a Kubernetes `Job` for the appropriate agent:

```yaml
# Spawned by Ralph's reconciliation loop
apiVersion: batch/v1
kind: Job
metadata:
  name: data-issue-42-r7
  labels:
    squad.github.com/agent: data
    squad.github.com/issue: "42"
    squad.github.com/round: "7"
spec:
  ttlSecondsAfterFinished: 3600    # Auto-cleanup after 1 hour
  backoffLimit: 2
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: data
        image: ghcr.io/tamirdresher/squad-agent:latest
        env:
        - name: SQUAD_AGENT_NAME
          value: data
        - name: SQUAD_ISSUE_NUMBER
          value: "42"
        - name: GITHUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: squad-credentials
              key: gh-token
```

This replaces the current `gh copilot agent` subprocess spawning with a proper
K8s Job that is visible in `kubectl get jobs`, has its own logs, and cleans up automatically.

---

## 4. Container Image Strategy

### 4.1 Image Hierarchy

```
ghcr.io/tamirdresher/squad-base:latest
  ├── Ubuntu 22.04 LTS
  ├── PowerShell 7.4+
  ├── Node.js 20 LTS
  ├── GitHub CLI (gh)
  ├── Copilot CLI extension (gh-copilot)
  ├── jq, curl, git
  └── Non-root user: squad

ghcr.io/tamirdresher/squad-ralph:latest  (extends base)
  └── ralph-watch.ps1 entrypoint

ghcr.io/tamirdresher/squad-agent:latest  (extends base)
  └── Agent runner entrypoint (SQUAD_AGENT_NAME env var selects agent)

ghcr.io/tamirdresher/squad-agent-browser:latest  (extends agent)
  └── Chromium, Playwright — for needs:browser workloads

ghcr.io/tamirdresher/squad-agent-gpu:latest  (extends agent)
  └── CUDA runtime — for needs:gpu workloads (voice, ML inference)
```

### 4.2 Single Image vs Per-Agent Images

**Decision: Single `squad-agent` image, agent selected via `SQUAD_AGENT_NAME` env var.**

Rationale:
- All agents share the same runtime (PowerShell 7, gh CLI, Node.js)
- Agent identity is determined by the charter file and agent name, not by binaries
- Smaller surface area to maintain (1 image vs 8 images)
- Specialized capabilities (browser, GPU) use derived images only when needed

```
Image             → Use case
─────────────────────────────────────────────────────────────
squad-base        → Foundation layer; never run directly
squad-ralph       → Ralph watcher only (different entrypoint/logic)
squad-agent       → All named agents (Data, Picard, Seven, etc.)
squad-agent-browser → Agents requiring Playwright/browser automation
squad-agent-gpu   → Agents requiring GPU (voice gen, ML inference)
```

### 4.3 Image Build Pipeline

```yaml
# .github/workflows/build-squad-images.yml
on:
  push:
    paths:
      - 'infrastructure/k8s/Dockerfile.*'
      - 'ralph-watch.ps1'
      - '.squad/agents/**'
    branches: [main]

jobs:
  build:
    strategy:
      matrix:
        image: [base, ralph, agent, agent-browser]
    steps:
      - uses: docker/build-push-action@v5
        with:
          file: infrastructure/k8s/Dockerfile.${{ matrix.image }}
          tags: ghcr.io/tamirdresher/squad-${{ matrix.image }}:${{ github.sha }}
          push: true
```

Images are tagged with commit SHA (immutable) and `latest` (rolling). Helm charts
reference SHA tags for production, `latest` for development.

---

## 5. Secrets Management

### 5.1 Secret Inventory

| Secret | Description | Consumers |
|--------|-------------|-----------|
| `gh-token` | GitHub PAT (repo, issues, pull_requests, read:org) | All agents, Ralph |
| `copilot-api-key` | GitHub Copilot CLI authentication | All agents |
| `azure-client-id` | Azure Service Principal (for Workload Identity) | B'Elanna, Worf |
| `azure-tenant-id` | Azure tenant for MSI | B'Elanna, Worf |
| `ado-token` | Azure DevOps PAT (for ADO MCP server) | Picard, Data |
| `teams-webhook` | Microsoft Teams incoming webhook | Neelix, Scribe |
| `redis-password` | Rate-pool Redis auth | Ralph, all agents |

### 5.2 Phase 1: Kubernetes Secrets (Bootstrap)

For initial deployment, secrets are created manually or via CI:

```bash
kubectl create secret generic squad-credentials \
  --namespace squad-system \
  --from-literal=gh-token="${GH_TOKEN}" \
  --from-literal=copilot-api-key="${COPILOT_API_KEY}" \
  --from-literal=redis-password="${REDIS_PASSWORD}"
```

Secrets are referenced in pod specs via `secretKeyRef` or `envFrom`. They are
**never** committed to Git (`.gitignore` enforced in the Helm chart).

### 5.3 Phase 2: Azure Key Vault + CSI Driver (Production)

```
Azure Key Vault (squad-kv)
   ├── secret/gh-token
   ├── secret/copilot-api-key
   └── secret/ado-token
         │
         │  (CSI SecretProviderClass)
         ▼
AKS Pod Volume → /mnt/secrets/gh-token
                  /mnt/secrets/copilot-api-key
```

```yaml
# SecretProviderClass for squad namespace
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: squad-secrets
  namespace: squad-system
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    clientID: "${MANAGED_IDENTITY_CLIENT_ID}"
    keyvaultName: "squad-kv"
    objects: |
      array:
        - |
          objectName: gh-token
          objectType: secret
        - |
          objectName: copilot-api-key
          objectType: secret
  secretObjects:
  - secretName: squad-credentials
    type: Opaque
    data:
    - objectName: gh-token
      key: gh-token
    - objectName: copilot-api-key
      key: copilot-api-key
```

### 5.4 Per-Agent MCP Server Credentials

Each MCP server has its own credentials. These are stored as separate K8s Secrets,
scoped per agent where possible:

```yaml
# Only mounted in B'Elanna pods
apiVersion: v1
kind: Secret
metadata:
  name: squad-belanna-credentials
  namespace: squad-system
data:
  azure-client-id: <base64>
  azure-tenant-id: <base64>
  azure-subscription-id: <base64>
```

This principle of least privilege ensures that a compromise of one agent's pod
does not expose all credentials.

---

## 6. Networking: Agent Communication & MCP Servers

### 6.1 Network Topology

```
Internet
    │
    │  HTTPS/443 (egress only)
    ▼
NetworkPolicy: allow-squad-egress
    │
    ├── api.github.com
    ├── copilot-proxy.githubusercontent.com
    ├── management.azure.com
    └── *.microsoft.com (ADO, Teams, Entra)

    ┌─── squad-system namespace ───────────────────────────────┐
    │                                                           │
    │  ralph-0 ──→ [ClusterIP: squad-redis:6379] (rate pool)   │
    │                                                           │
    │  ralph-0 ──→ Kubernetes API (spawn Jobs)                 │
    │              [ServiceAccount: squad-controller]           │
    │                                                           │
    │  Each Agent Pod                                           │
    │  ┌─────────────────────────────────────┐                 │
    │  │  main container: squad-agent        │                 │
    │  │  sidecar: mcp-github                │                 │
    │  │  sidecar: mcp-ado (if needed)       │                 │
    │  │                                     │                 │
    │  │  Communication: localhost:PORT      │                 │
    │  └─────────────────────────────────────┘                 │
    │                                                           │
    │  Shared MCP Services (team-wide):                         │
    │  ┌──────────────┐  ┌──────────────┐                      │
    │  │  mcp-calendar│  │  mcp-teams   │                      │
    │  │  Deployment  │  │  Deployment  │                      │
    │  │  ClusterIP   │  │  ClusterIP   │                      │
    │  └──────────────┘  └──────────────┘                      │
    └───────────────────────────────────────────────────────────┘
```

### 6.2 MCP Server Placement Strategy

MCP servers are categorized into two deployment patterns:

**Pattern A — Sidecar (per-agent MCP)**

Used when: The MCP server is only needed by one agent type, or when the server
must share filesystem state with the agent.

```yaml
# Example: Picard pod with ADO MCP sidecar
spec:
  containers:
  - name: picard                    # Main agent container
    image: squad-agent:latest
    env:
    - name: SQUAD_AGENT_NAME
      value: picard
    - name: MCP_ADO_URL
      value: "http://localhost:3001"
  - name: mcp-ado                   # Sidecar — shares localhost
    image: ghcr.io/tamirdresher/mcp-ado:latest
    ports:
    - containerPort: 3001
    env:
    - name: ADO_TOKEN
      valueFrom:
        secretKeyRef:
          name: squad-picard-credentials
          key: ado-token
```

**Pattern B — Shared Deployment (team-wide MCP)**

Used when: Multiple agents need the same MCP server (GitHub, Calendar, Teams).

```yaml
# Shared GitHub MCP server
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-github-shared
  namespace: squad-system
spec:
  replicas: 2                       # HA for shared service
  selector:
    matchLabels:
      app: mcp-github-shared
  template:
    spec:
      containers:
      - name: mcp-github
        image: ghcr.io/tamirdresher/mcp-github:latest
        env:
        - name: GITHUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: squad-credentials
              key: gh-token
---
apiVersion: v1
kind: Service
metadata:
  name: mcp-github-shared
  namespace: squad-system
spec:
  selector:
    app: mcp-github-shared
  ports:
  - port: 3000
    targetPort: 3000
```

### 6.3 MCP Placement Decision Table

| MCP Server | Pattern | Reason |
|------------|---------|--------|
| `mcp-github` | Shared Deployment | Used by all agents; expensive to run per-pod |
| `mcp-ado` | Sidecar (Picard, Data) | Only used by 2 agents; ADO token scoped to those pods |
| `mcp-calendar` | Shared Deployment | Used by Kes and scheduling workflows |
| `mcp-teams` | Shared Deployment | Used by Neelix, Scribe for notifications |
| `mcp-aspire` | Sidecar (Data, B'Elanna) | Only dev/infra agents need Aspire dashboard access |
| `mcp-dotnet-inspect` | Sidecar (Data) | Code agent only |
| `mcp-workiq` | Shared Deployment | Workplace intelligence; multiple agents query it |
| `playwright-cli` | Sidecar (needs:browser) | Only browser-capable pods; requires Chromium |

### 6.4 NetworkPolicy

All Squad pods operate under a strict NetworkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: squad-agent-netpol
  namespace: squad-system
spec:
  podSelector:
    matchLabels:
      squad.github.com/component: agent
  policyTypes:
  - Ingress
  - Egress
  egress:
  # Allow GitHub API
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except: [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16]
    ports:
    - protocol: TCP
      port: 443
  # Allow intra-namespace (Redis, shared MCP services)
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 6379   # Redis
    - protocol: TCP
      port: 3000   # MCP servers
  ingress: []      # Agents accept no inbound traffic
```

---

## 7. Scaling Strategy

### 7.1 Horizontal Scaling by Agent Type

| Agent | Min Replicas | Max Replicas | Scaling Trigger | Strategy |
|-------|-------------|-------------|-----------------|----------|
| Ralph | 1 | 3 | Issue queue depth (via KEDA) | StatefulSet with leader election |
| Data | 1 | 8 | Claimed issue count | HPA on custom metric |
| Seven | 1 | 2 | Research backlog depth | Manual or KEDA |
| Picard | 1 | 1 | Singleton (architecture decisions are serial) | Fixed |
| Scribe | 1 | 1 | Singleton (session logging must be ordered) | Fixed |
| B'Elanna | 1 | 1 | Singleton (infra changes are sequential) | Fixed |
| Worf | 1 | 1 | Singleton (security reviews must be consistent) | Fixed |

### 7.2 KEDA Autoscaling for Ralph and Data

KEDA (Kubernetes Event-Driven Autoscaling) enables scaling Ralph workers based on the
number of open Squad issues:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: ralph-scaler
  namespace: squad-system
spec:
  scaleTargetRef:
    name: ralph
    kind: StatefulSet
  minReplicaCount: 1
  maxReplicaCount: 3
  triggers:
  - type: external
    metadata:
      scalerAddress: squad-issue-scaler:8080   # Custom KEDA scaler
      # Returns queue depth = open squad-labeled issues not yet claimed
      metricName: squad_open_issues
      targetValue: "5"   # Scale up if >5 unclaimed issues per Ralph instance
```

The custom KEDA scaler queries the GitHub API for open, unclaimed Squad issues and
returns the count. Ralph instances scale proportionally.

### 7.3 Rate Limit Pool Coordination

Multiple Ralph replicas must coordinate their GitHub API rate limit consumption.
This is handled via Redis:

```
Ralph-0  ─┐
Ralph-1  ──┼──→ Redis:6379 → Shared rate-pool bucket
Ralph-2  ─┘     (token bucket algorithm, 5000 req/hr GitHub limit)
```

Each Ralph instance checks `RATE_POOL_REDIS` before making GitHub API calls, same
as the current `~/.squad/rate-pool.json` but now shared across pods.

---

## 8. Scheduling Model

### 8.1 Agent Scheduling Summary

```
Always-on (Deployment, long-running loop):
  ├── ralph          — poll GitHub every 5 min, spawn Jobs for claimed issues
  ├── picard         — available for architecture questions, PR reviews
  ├── scribe         — session logging, decision tracking
  └── belanna        — infrastructure monitoring, alert response

On-demand (Job, spawned by Ralph):
  ├── data           — code implementation, spawned per issue
  ├── seven          — research tasks, spawned per issue
  ├── worf           — security review, spawned per PR
  └── troi           — content generation, spawned per content task

Scheduled (CronJob):
  ├── daily-digest   — 0 8 * * *   (daily standup report)
  ├── weekly-report  — 0 9 * * 1   (weekly metrics)
  └── triage-sweep   — */30 * * * * (triage uncategorized issues every 30 min)
```

### 8.2 Ralph Pod Scheduling Details

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ralph
  namespace: squad-system
spec:
  replicas: 1
  strategy:
    type: Recreate          # Ensure no two Ralphs overlap during rollout
  selector:
    matchLabels:
      app: ralph
  template:
    metadata:
      labels:
        app: ralph
        squad.github.com/component: monitor
    spec:
      serviceAccountName: squad-controller  # Needs K8s API access to spawn Jobs
      containers:
      - name: ralph
        image: ghcr.io/tamirdresher/squad-ralph:latest
        env:
        - name: RALPH_MACHINE_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name      # pod name = ralph-abc123
        - name: RALPH_INTERVAL_SECONDS
          value: "300"
        - name: SQUAD_REPO
          value: "tamirdresher/tamresearch1"
        - name: GITHUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: squad-credentials
              key: gh-token
        - name: RATE_POOL_REDIS
          value: "redis://:$(REDIS_PASSWORD)@squad-redis:6379"
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: squad-credentials
              key: redis-password
        - name: K8S_SPAWN_JOBS
          value: "true"           # Enables K8s Job spawning (vs subprocess)
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: "1"
            memory: 1Gi
        livenessProbe:
          exec:
            command:
            - pwsh
            - -Command
            - |
              $heartbeat = Get-Content /squad-state/ralph-heartbeat.json | ConvertFrom-Json
              $age = (Get-Date) - [DateTime]$heartbeat.lastRound
              if ($age.TotalMinutes -gt 15) { exit 1 }
          initialDelaySeconds: 60
          periodSeconds: 60
          failureThreshold: 3
        readinessProbe:
          exec:
            command: [pwsh, -Command, "Test-Path /squad-state/ralph-heartbeat.json"]
          initialDelaySeconds: 30
          periodSeconds: 30
        volumeMounts:
        - name: squad-state
          mountPath: /squad-state
        - name: squad-config
          mountPath: /app/.squad
          readOnly: true
      volumes:
      - name: squad-state
        persistentVolumeClaim:
          claimName: squad-state-pvc
      - name: squad-config
        configMap:
          name: squad-config
```

### 8.3 CronJob Templates (Scheduled Tasks)

```yaml
# Daily digest CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: squad-daily-digest
  namespace: squad-system
spec:
  schedule: "0 8 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 86400
      template:
        spec:
          restartPolicy: OnFailure
          serviceAccountName: squad-agent
          containers:
          - name: neelix
            image: ghcr.io/tamirdresher/squad-agent:latest
            env:
            - name: SQUAD_AGENT_NAME
              value: neelix
            - name: SQUAD_TASK
              value: daily-digest
```

---

## 9. State Management

### 9.1 State Classification

| State Type | Current Location | K8s Location | Rationale |
|------------|-----------------|-------------|-----------|
| Team decisions | `.squad/decisions.md` | Git (unchanged) | Source of truth; auditable |
| Agent charters | `.squad/agents/*/charter.md` | Git (unchanged) | Version-controlled config |
| Squad config | `squad.config.ts` | ConfigMap + Git | Runtime config in ConfigMap, source in Git |
| Routing rules | `.squad/routing.md` | ConfigMap | Reloaded on change without pod restart |
| Session state | `~/.squad/sessions/` | PVC (Azure Files) | Per-session history; shared across Ralph replicas |
| Heartbeat | `~/.squad/ralph-heartbeat.json` | PVC (Azure Files) | Liveness probe reads this |
| Round history | In-memory + log | PVC + SquadRound CRDs | Persisted for audit; queryable via kubectl |
| Rate pool | `~/.squad/rate-pool.json` | Redis | Shared across replicas; low-latency |
| Cross-machine tasks | `~/.squad/cross-machine/` | Redis (pub/sub) | Replace file-based coordination |
| Workqueue | GitHub issues (labels) | GitHub issues (unchanged) | Single source of truth for work |

### 9.2 PersistentVolumeClaim Configuration

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: squad-state-pvc
  namespace: squad-system
spec:
  accessModes:
  - ReadWriteMany              # Multiple Ralph pods read/write concurrently
  storageClassName: azurefile-csi-premium   # Azure Files Premium for IOPS
  resources:
    requests:
      storage: 10Gi
```

`ReadWriteMany` (RWX) is required because multiple Ralph replicas and agent pods
must access the shared state directory simultaneously. Azure Files (SMB) provides
RWX on AKS. Azure Disk (RWO) is not suitable for multi-pod scenarios.

### 9.3 ConfigMap for Squad Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: squad-config
  namespace: squad-system
data:
  routing.md: |
    # Routing Rules
    (contents of .squad/routing.md)
  watch-config.json: |
    {
      "checkIntervalMinutes": 5,
      "issueLabel": "squad",
      "maxConcurrentAgents": 4,
      "roundTimeoutMinutes": 30
    }
  squad-config.json: |
    {
      "defaultModel": "claude-sonnet-4.5",
      "defaultTier": "standard",
      "eagerByDefault": true
    }
```

Changes to this ConfigMap (via `kubectl apply` or GitOps) propagate to all pods
within 60 seconds without requiring a restart.

---

## 10. Multi-Tenant Architecture

### 10.1 Namespace-per-Team Model

Each Squad team (for a different repository or organization) gets its own namespace:

```
cluster
├── namespace: squad-tamresearch1     ← Squad for tamresearch1
├── namespace: squad-dk8s-platform    ← Squad for DK8S platform repo
├── namespace: squad-myproject        ← Squad for another team
└── namespace: squad-system           ← Shared operator, shared MCP services
```

This provides:
- **Isolation**: credentials, state, and rate limits are per-team
- **Independent scaling**: each team's Ralph can scale independently
- **RBAC isolation**: each team's ServiceAccount only has access to its namespace
- **Cost attribution**: namespace-level resource quotas enable chargeback

### 10.2 Shared vs Per-Team Resources

| Resource | Scope | Reason |
|----------|-------|--------|
| Squad Operator | Cluster-wide | One operator manages all SquadTeam CRs |
| Redis (rate pool) | Per-namespace | Rate limits are per-GitHub-token, per-team |
| PVC (state) | Per-namespace | State isolation between teams |
| MCP servers (GitHub, Calendar) | Per-namespace | Credentials differ per team |
| Image registry | Cluster-wide | All teams use the same base images |
| Container builds (CI/CD) | Cluster-wide | Central build pipeline |

### 10.3 SquadTeam CRD for Multi-Tenant Onboarding

```yaml
apiVersion: squad.github.com/v1alpha1
kind: SquadTeam
metadata:
  name: tamresearch1
  namespace: squad-tamresearch1
spec:
  repository: tamirdresher/tamresearch1
  credentialsSecretRef: squad-credentials
  
  agents:
  - name: ralph
    type: monitor
    replicas: 1
    schedule:
      type: continuous
      intervalSeconds: 300
  - name: data
    type: coder
    maxParallelJobs: 4
  - name: picard
    type: lead
    replicas: 1
  - name: seven
    type: researcher
    replicas: 1
  
  models:
    defaultModel: claude-sonnet-4.5
    defaultTier: standard
    fallbackChains:
      premium: [claude-opus-4.6, claude-sonnet-4.5]
      standard: [claude-sonnet-4.5, gpt-5.2-codex]
      fast: [claude-haiku-4.5, gpt-4.1]
  
  ratePool:
    enabled: true
    redisRef: squad-redis
  
  persistence:
    enabled: true
    storageClass: azurefile-csi-premium
    size: 10Gi
```

A new team onboards by:
1. Creating a namespace: `kubectl create namespace squad-myteam`
2. Creating credentials: `kubectl create secret generic squad-credentials -n squad-myteam ...`
3. Applying a SquadTeam CR
4. The operator creates all necessary Deployments, ConfigMaps, PVCs, and Jobs automatically

### 10.4 Resource Quotas per Namespace

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: squad-team-quota
  namespace: squad-tamresearch1
spec:
  hard:
    pods: "20"                # Max 20 pods (all agents + jobs)
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    count/jobs.batch: "10"   # Max 10 concurrent agent jobs
```

---

## 11. GitOps Deployment Model

### 11.1 Architecture Overview

```
GitHub Repository (tamresearch1)
  ├── infrastructure/helm/squad/     ← Helm chart source
  ├── .squad/                        ← Squad config (becomes ConfigMap)
  └── squad.config.ts                ← Model/routing config

         │ push to main
         ▼

GitHub Actions (CI/CD)
  ├── Build & push images to GHCR
  ├── Lint & validate Helm chart
  └── Trigger ArgoCD sync

         │ sync
         ▼

ArgoCD (GitOps controller in cluster)
  └── Watches: github.com/tamirdresher/tamresearch1:main/infrastructure/
      Applies: helm upgrade squad ./infrastructure/helm/squad

         │ applies
         ▼

AKS Cluster (squad-system namespace)
```

### 11.2 ArgoCD Application Definition

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: squad-tamresearch1
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/tamirdresher/tamresearch1
    targetRevision: main
    path: infrastructure/helm/squad
    helm:
      valueFiles:
      - values.yaml
      - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: squad-tamresearch1
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### 11.3 Squad Config Changes → GitOps Flow

When an agent updates `.squad/decisions.md` or `routing.md`:

1. Agent commits changes to a branch and opens a PR
2. PR is reviewed and merged to `main`
3. ArgoCD detects the change in `infrastructure/` or `.squad/` (if watched)
4. ArgoCD syncs: `kubectl apply` updates the ConfigMap
5. Pod volumes referencing the ConfigMap refresh within 60 seconds
6. No pod restarts required for config-only changes

For config changes that require a restart (e.g., new env vars), use a rolling update
strategy with `strategy: RollingUpdate` on the Deployment.

### 11.4 GitHub Actions Pipeline

```yaml
# .github/workflows/deploy-squad.yml
name: Deploy Squad

on:
  push:
    branches: [main]
    paths:
      - 'infrastructure/helm/squad/**'
      - '.squad/routing.md'
      - '.squad/watch-config.json'
      - 'squad.config.ts'

jobs:
  build-images:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: docker/login-action@v3
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    - uses: docker/build-push-action@v5
      with:
        file: infrastructure/k8s/Dockerfile.ralph
        tags: ghcr.io/tamirdresher/squad-ralph:${{ github.sha }}
        push: true

  sync-argocd:
    needs: build-images
    runs-on: ubuntu-latest
    steps:
    - uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    - uses: azure/aks-set-context@v4
      with:
        cluster-name: squad-cluster
        resource-group: squad-rg
    - name: Trigger ArgoCD sync
      run: |
        argocd app sync squad-tamresearch1 \
          --server ${{ secrets.ARGOCD_SERVER }} \
          --auth-token ${{ secrets.ARGOCD_TOKEN }}
```

---

## 12. Helm Chart Structure

The existing skeleton in `infrastructure/helm/squad/` is extended into a complete chart:

```
infrastructure/helm/squad/
├── Chart.yaml
├── values.yaml                         # Defaults
├── values-dev.yaml                     # Dev overrides
├── values-prod.yaml                    # Production overrides
├── templates/
│   ├── _helpers.tpl                    # Shared template helpers
│   ├── namespace.yaml                  # Namespace (optional)
│   ├── serviceaccount.yaml             # SA + RBAC
│   ├── rbac.yaml                       # Role + RoleBinding for Job spawning
│   ├── secret.yaml                     # Squad credentials (if no existingSecret)
│   ├── configmap-squad-config.yaml     # squad.config.ts equivalent
│   ├── configmap-agent-charters.yaml   # Agent charter files
│   ├── ralph-deployment.yaml           # Ralph watcher
│   ├── picard-deployment.yaml          # Picard lead agent
│   ├── scribe-deployment.yaml          # Scribe session logger
│   ├── agent-job-template.yaml         # Template for on-demand agent Jobs
│   ├── cronjob-daily-digest.yaml       # Neelix daily digest
│   ├── cronjob-triage-sweep.yaml       # Scheduled triage
│   ├── redis-deployment.yaml           # Rate-pool Redis
│   ├── redis-service.yaml              # Redis ClusterIP
│   ├── pvc-squad-state.yaml            # PVC for .squad/ state
│   ├── networkpolicy.yaml              # Egress restrictions
│   └── hpa-data.yaml                   # HPA for Data agent (Phase 2)
```

### 12.1 Key values.yaml Sections

```yaml
global:
  repository: "tamirdresher/tamresearch1"
  namespace: "squad-tamresearch1"
  imageRegistry: "ghcr.io/tamirdresher"
  imageTag: "latest"               # Pin to SHA in prod

ralph:
  enabled: true
  replicaCount: 1
  intervalSeconds: 300
  image: squad-ralph
  resources:
    requests: { cpu: 250m, memory: 256Mi }
    limits: { cpu: "1", memory: 1Gi }

agents:
  picard:
    enabled: true
    replicaCount: 1
  scribe:
    enabled: true
    replicaCount: 1
  data:
    enabled: true
    maxParallelJobs: 4             # Max concurrent Data Jobs
  seven:
    enabled: true
    replicaCount: 1
  belanna:
    enabled: true
    replicaCount: 1

mcpServers:
  github:
    enabled: true
    shared: true                   # Single shared Deployment
  ado:
    enabled: true
    shared: false                  # Sidecar per agent (Picard, Data)
  calendar:
    enabled: true
    shared: true
  teams:
    enabled: true
    shared: true

ratePool:
  enabled: true
  redis:
    image: redis:7-alpine
    resources:
      requests: { cpu: 100m, memory: 128Mi }

persistence:
  enabled: true
  storageClass: azurefile-csi-premium
  size: 10Gi
  accessMode: ReadWriteMany

credentials:
  existingSecret: ""
  ghToken: ""
  copilotApiKey: ""
  redisPassword: ""

serviceAccount:
  create: true
  annotations: {}
  # AKS Workload Identity (Phase 2):
  # azure.workload.identity/client-id: "<managed-identity-client-id>"

scheduling:
  dailyDigest:
    enabled: true
    schedule: "0 8 * * *"
  triageSweep:
    enabled: true
    schedule: "*/30 * * * *"
```

---

## 13. Squad Operator: CRD Model

The CRD definitions already exist in `infrastructure/k8s/crds/`. This section
documents the graduation path from Helm to Operator.

### 13.1 Why an Operator (Phase 3 Decision)

A Helm chart is declarative but static — it applies what you tell it. An Operator
is dynamic — it watches CRDs and reconciles the actual state to the desired state.

**Helm is sufficient when:**
- Team composition changes rarely
- No dynamic job spawning from K8s (Ralph spawns via subprocess/CLI)
- Single cluster, single team

**Operator is needed when:**
- Ralph needs to spawn K8s Jobs programmatically (not via CLI)
- Multi-tenant: dozens of SquadTeam CRs across many namespaces
- Auto-healing: operator detects stale agents and replaces them
- Metrics: operator exposes custom metrics for KEDA to consume

### 13.2 CRD Schemas

**SquadTeam** — top-level team definition

```yaml
apiVersion: squad.github.com/v1alpha1
kind: SquadTeam
metadata:
  name: tamresearch1
  namespace: squad-tamresearch1
spec:
  repository: tamirdresher/tamresearch1
  agents: [...]           # Agent list (see §10.3)
  models: {...}           # Model config
  ratePool: {...}
  persistence: {...}
status:
  phase: Running          # Pending, Running, Degraded, Failed
  lastRound: "142"
  activeAgents: 3
  conditions: [...]
```

**SquadAgent** — individual agent pod

```yaml
apiVersion: squad.github.com/v1alpha1
kind: SquadAgent
metadata:
  name: ralph-0
  namespace: squad-tamresearch1
spec:
  teamRef: tamresearch1
  agentType: ralph
  capabilities: [work-monitoring, issue-triage]
  modelTier: standard
  schedule:
    type: continuous
    intervalSeconds: 300
  nodeSelector:
    squad.github.com/workload: monitor
status:
  phase: Running
  currentRound: 142
  lastHeartbeat: "2026-03-20T08:42:00Z"
  consecutiveFailures: 0
```

**SquadRound** — execution round (audit trail)

```yaml
apiVersion: squad.github.com/v1alpha1
kind: SquadRound
metadata:
  name: round-142
  namespace: squad-tamresearch1
spec:
  teamRef: tamresearch1
  roundNumber: 142
  startedAt: "2026-03-20T08:40:00Z"
status:
  phase: Completed        # Pending, Running, Completed, Failed
  endedAt: "2026-03-20T08:42:30Z"
  durationSeconds: 150
  issuesProcessed:
  - number: 1059
    action: claimed
    agentJob: data-issue-1059-r142
  - number: 1042
    action: skipped
    reason: already-claimed
```

### 13.3 Operator Reconciliation Logic (Pseudocode)

```
On SquadTeam create/update:
  → Create namespace (if not exists)
  → Create/update ServiceAccount + RBAC
  → Create/update Secrets (or SecretProviderClass)
  → Create/update ConfigMaps (routing, squad config)
  → For each agent in spec.agents:
      → Reconcile Deployment (create if missing, update if changed)
  → Reconcile PVC (if persistence.enabled)
  → Reconcile Redis Deployment (if ratePool.enabled)
  → Update SquadTeam.status

On SquadRound create (spawned by Ralph pod):
  → Validate round ownership
  → Create SquadAgent Job for each claimed issue
  → Update SquadRound.status as Jobs complete

On SquadAgent status change:
  → If consecutiveFailures > threshold: alert via Teams webhook
  → If phase == Failed: trigger restart (delete pod, Deployment reconciles)
```

---

## 14. Phased Implementation Plan

### Phase 1 — Basic K8s (Now → 4 weeks)

**Goal:** Ralph running in K8s, connecting to GitHub, completing one full round.

| Task | Owner | Status |
|------|-------|--------|
| Dockerfile.ralph (single-stage, functional) | B'Elanna | ✅ Done (#996) |
| docker-compose.yml for local testing | B'Elanna | ✅ Done (#996) |
| Helm chart skeleton | B'Elanna | ✅ Done (#996) |
| CRD definitions | Picard | ✅ Done (#996) |
| CI: build & push ralph image to GHCR | Data | 🔜 Next |
| `ralph-watch.ps1` adaptation for K8s env | Data | 🔜 Next |
| Deploy to AKS (dev cluster) | B'Elanna | 🔜 Next |
| K8s Secrets for GitHub token | B'Elanna | 🔜 Next |
| Liveness/readiness probes wired to heartbeat | Data | 🔜 Next |
| PVC for `.squad/` state (Azure Files) | B'Elanna | 🔜 Next |
| End-to-end smoke test: Ralph claims one issue | Picard | 🔜 Next |

**Success criteria:** `kubectl logs -f deployment/ralph -n squad-tamresearch1` shows Ralph
completing a round, and the GitHub issue shows the claim comment from a K8s pod.

### Phase 2 — Full Agent Support (4–10 weeks)

**Goal:** All named agents running as K8s Deployments; on-demand Jobs for issue work.

| Task | Owner |
|------|-------|
| squad-agent base image (all named agents) | Data |
| `K8S_SPAWN_JOBS=true` mode in ralph-watch.ps1 | Data |
| Agent Job spawning via K8s API (ServiceAccount RBAC) | Data |
| Per-agent Deployments (Picard, Scribe, Seven, B'Elanna) | B'Elanna |
| Shared MCP server Deployments (GitHub, Calendar, Teams) | B'Elanna |
| Sidecar MCP servers (ADO, Aspire, dotnet-inspect) | Data |
| Redis rate-pool integration | Data |
| Workload Identity + Azure Key Vault CSI (replace K8s Secrets) | Worf |
| NetworkPolicy for all agent pods | Worf |
| ArgoCD GitOps pipeline | B'Elanna |
| SquadRound CR creation by Ralph (audit trail) | Data |

**Success criteria:** Ralph spawns a Data Job for an issue; Data completes the work
and commits a PR; the SquadRound CR reflects the completed round.

### Phase 3 — Cloud-Native Autoscaling (10–20 weeks)

**Goal:** Production-grade deployment with autoscaling, multi-tenant, and Squad Operator.

| Task | Owner |
|------|-------|
| KEDA scaler for Ralph (GitHub issue queue depth) | B'Elanna |
| HPA for Data agent (CPU-based, then custom metric) | B'Elanna |
| Multi-tenant namespace model (SquadTeam CRD → multiple namespaces) | Picard |
| Squad Operator (Go controller, kubebuilder) | Data |
| Resource quotas per namespace | B'Elanna |
| KAITO integration for local model inference (GPU nodes) | B'Elanna |
| Prometheus + Grafana dashboards for Squad metrics | B'Elanna |
| SLO/SLA definitions for Squad availability | Picard |
| Automated node capability labeling (DaemonSet) | B'Elanna |
| Open-source packaging (Helm chart on Artifact Hub) | Seven |

**Success criteria:** A new team can onboard to Squad-on-K8s by applying a single
`SquadTeam` CR and their agents start running within 5 minutes.

---

## 15. Architecture Decision Records

### ADR-001: Pod-per-Agent vs Sidecar Model

**Status:** Accepted  
**Decision:** Pod-per-agent  
**Rationale:** Each agent (Ralph, Data, Picard) has independent resource requirements,
scheduling constraints, failure modes, and scaling needs. Co-locating agents in a single
pod creates a shared failure domain and couples scaling decisions. Pod-per-agent maps
directly to our existing model where each agent is an independent unit of work.

### ADR-002: Ralph as Deployment vs CronJob

**Status:** Accepted  
**Decision:** Deployment with liveness probe  
**Rationale:** Ralph's existing `ralph-watch.ps1` is a long-running reconciliation loop
with in-process state (consecutive failure tracking, mutex, heartbeat). A CronJob would
lose this state between invocations and introduce cold-start latency on every poll cycle.
A Deployment with `livenessProbe` pointing at the heartbeat file provides automatic
restart without sacrificing the stateful loop design.  
**Trade-off accepted:** Slightly more complex lifecycle than CronJob; mitigated by
`strategy: Recreate` to prevent concurrent Ralph pods during rollouts.

### ADR-003: MCP Servers — Sidecar vs Shared Deployment

**Status:** Accepted  
**Decision:** Sidecar for per-agent MCPs; Shared Deployment for team-wide MCPs  
**Rationale:** The MCP GitHub server is used by all agents — running it as a shared
Deployment with `ClusterIP` reduces resource consumption and simplifies credential
management (one token for all agents). Per-agent MCPs (ADO, Aspire) carry agent-specific
credentials and should be co-located as sidecars to avoid credential leakage to other pods.

### ADR-004: State Backend — PVC vs Pure Git

**Status:** Accepted  
**Decision:** Git-primary for team config and decisions; PVC for runtime state  
**Rationale:** Team decisions, routing rules, and agent charters are version-controlled
in Git — this is a feature, not a limitation. Runtime state (heartbeats, session logs,
round history) changes too frequently for Git commits and requires file-system semantics.
Azure Files PVC (RWX) is the correct backend for runtime state shared across Ralph replicas.

### ADR-005: Helm-First vs Operator-First

**Status:** Accepted  
**Decision:** Helm-first (Phase 1–2), graduate to Operator in Phase 3  
**Rationale:** An Operator requires significant engineering investment (Go controller,
kubebuilder, CRD reconciliation logic). A Helm chart achieves the same goal for Phase 1–2
with a fraction of the effort. The CRD schemas already exist; the Operator is an automation
layer on top. Ship Helm now, build the Operator once we understand the operational patterns
from real production usage.

### ADR-006: Secrets Backend — K8s Secrets vs Azure Key Vault

**Status:** Accepted  
**Decision:** K8s Secrets for Phase 1; Azure Key Vault + CSI driver for Phase 2  
**Rationale:** K8s Secrets are sufficient for a dev/staging deployment and allow rapid
iteration. For production, secrets must never be stored as base64 in etcd — Azure Key Vault
with the CSI driver injects secrets as mounted files, never as env vars in the pod spec.
Workload Identity eliminates service principal credentials entirely.

---

## 16. Appendix: Component Diagrams

### 16.1 Full System Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  GitHub.com                                                                   │
│  ├── Repository: tamirdresher/tamresearch1                                   │
│  ├── Issues (workqueue): squad-labeled, needs:* labels                       │
│  └── Actions (CI/CD): build images, trigger ArgoCD                           │
└─────────────────────────────┬────────────────────────────────────────────────┘
                              │ HTTPS (443)
┌─────────────────────────────▼────────────────────────────────────────────────┐
│  AKS Cluster — region: eastus                                                │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  namespace: squad-tamresearch1                                        │   │
│  │                                                                        │   │
│  │  ┌─────────────────┐   ┌─────────────────┐   ┌──────────────────┐   │   │
│  │  │  ralph           │   │  picard          │   │  scribe          │   │   │
│  │  │  Deployment/1    │   │  Deployment/1    │   │  Deployment/1    │   │   │
│  │  │                  │   │  + mcp-ado sidecar│   │                  │   │   │
│  │  │  ↕ PVC (state)   │   │                  │   │  ↕ PVC (state)   │   │   │
│  │  └────────┬─────────┘   └─────────────────┘   └──────────────────┘   │   │
│  │           │                                                             │   │
│  │           │ spawns K8s Jobs                                            │   │
│  │           ▼                                                             │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │   │
│  │  │  Agent Job Pool                                                   │  │   │
│  │  │  data-issue-42  · seven-issue-87  · worf-pr-23  · troi-task-5  │  │   │
│  │  │  (TTL: 1h, auto-cleanup)                                         │  │   │
│  │  └─────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                        │   │
│  │  ┌────────────────────────────────────────────────────────────────┐   │   │
│  │  │  Shared Services                                                │   │   │
│  │  │  Redis (rate-pool)  │  mcp-github  │  mcp-teams  │  mcp-cal   │   │   │
│  │  │  PVC (Azure Files)  │  ConfigMaps  │  Secrets     │            │   │   │
│  │  └────────────────────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  namespace: argocd                                                    │   │
│  │  ArgoCD — watches github.com/tamirdresher/tamresearch1:main          │   │
│  │           applies infrastructure/helm/squad/ on change               │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  Azure Services                                                       │   │
│  │  Key Vault (squad-kv)  │  Azure Files (PVC backend)  │  ACR          │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 16.2 Ralph Round Flow (K8s-native)

```
Ralph Pod (Deployment)
│
├── [every 300s] Poll GitHub: GET /issues?labels=squad&state=open
│
├── For each unclaimed issue:
│   ├── Check Redis rate pool (available tokens?)
│   ├── Claim issue (POST comment + label)
│   ├── Create SquadRound CR (status: running)
│   └── Spawn K8s Job:
│       kubectl create job data-issue-42-r142 \
│         --from=cronjob/squad-agent-template \
│         --set SQUAD_AGENT_NAME=data \
│         --set SQUAD_ISSUE_NUMBER=42
│
└── [on Job completion]:
    ├── Update SquadRound CR (status: completed)
    └── Update heartbeat: /squad-state/ralph-heartbeat.json
```

### 16.3 Secrets Flow (Phase 2 — Workload Identity)

```
Azure Managed Identity (squad-mi)
  └── federated credential → AKS ServiceAccount: squad-agent
        │
        │  (OIDC token exchange)
        ▼
Azure Key Vault (squad-kv)
  ├── secret/gh-token         → mounted at /mnt/secrets/gh-token
  ├── secret/copilot-api-key  → mounted at /mnt/secrets/copilot-api-key
  └── secret/ado-token        → mounted at /mnt/secrets/ado-token
        │
        │  (CSI SecretProviderClass)
        ▼
Pod Volume (read-only tmpfs)
  └── /mnt/secrets/
      ├── gh-token
      ├── copilot-api-key
      └── ado-token
```

---

*Document maintained by Picard. For infrastructure implementation, see B'Elanna.*  
*For code implementation (Ralph adaptation, operator), see Data.*  
*Next review: when Phase 1 deployment is complete.*
