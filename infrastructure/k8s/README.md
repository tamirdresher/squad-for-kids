# Squad-on-K8s — Running AI Agents in Kubernetes

> **Status:** POC (Issue #996) · Not production-ready

## Vision

Run Squad agents as independent Kubernetes pods, each with its own lifecycle,
scaling, and credential management. The **pod-per-agent** model gives each agent
(Ralph, Picard, Data, etc.) an isolated container with defined resource limits,
scheduled execution, and observable round history via Custom Resources.

```
┌─────────────────────────────────────────────────┐
│                AKS Cluster                       │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │  Ralph   │  │  Scribe  │  │  Data    │ ...   │
│  │  (pod)   │  │  (pod)   │  │  (pod)   │       │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘       │
│       │              │              │             │
│  ┌────┴──────────────┴──────────────┴────┐       │
│  │         K8s Secrets / ConfigMaps       │       │
│  │    (GH_TOKEN, squad.config, routing)   │       │
│  └───────────────────────────────────────┘       │
│                                                  │
│  CRDs: SquadTeam · SquadAgent · SquadRound       │
└─────────────────────────────────────────────────┘
         │
         ▼
   GitHub API (Issues, PRs, Copilot CLI)
```

## Repository Layout

```
infrastructure/
├── k8s/
│   ├── Dockerfile.ralph          # Ralph container image
│   ├── docker-compose.yml        # Local multi-agent testing
│   ├── README.md                 # This file
│   └── crds/
│       ├── squadteam.yaml        # SquadTeam CRD definition
│       ├── squadagent.yaml       # SquadAgent CRD definition
│       └── squadround.yaml       # SquadRound CRD definition
└── helm/
    └── squad/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── _helpers.tpl
            ├── deployment.yaml
            ├── service.yaml
            ├── configmap.yaml
            └── secret.yaml
```

## Getting Started Locally

### Prerequisites

- Docker Desktop (with Kubernetes enabled), **or** [kind](https://kind.sigs.k8s.io/), **or** [minikube](https://minikube.sigs.k8s.io/)
- `kubectl` CLI
- `helm` v3+
- A GitHub PAT with `repo`, `issues`, `pull_requests` scopes

### 1. Build the Ralph Image

```bash
# From repository root
docker build -f infrastructure/k8s/Dockerfile.ralph -t squad-ralph:latest .
```

### 2. Quick Test with Docker Compose

```bash
# Create .env with your credentials
cat > .env << 'EOF'
GH_TOKEN=ghp_your_token_here
GITHUB_REPOSITORY=tamirdresher/tamresearch1
RALPH_INTERVAL_SECONDS=300
EOF

# Start Ralph
docker compose -f infrastructure/k8s/docker-compose.yml up --build

# Stop
docker compose -f infrastructure/k8s/docker-compose.yml down
```

### 3. Deploy with Helm (local K8s)

```bash
# Create namespace
kubectl create namespace squad

# Install (provide your token)
helm install squad ./infrastructure/helm/squad \
  --namespace squad \
  --set credentials.ghToken="ghp_your_token_here" \
  --set global.repository="tamirdresher/tamresearch1"

# Check status
kubectl get pods -n squad
kubectl logs -f deployment/squad-ralph -n squad

# Upgrade after changes
helm upgrade squad ./infrastructure/helm/squad --namespace squad

# Uninstall
helm uninstall squad --namespace squad
```

### 4. Apply CRDs (Optional — for future operator work)

```bash
kubectl apply -f infrastructure/k8s/crds/

# Verify
kubectl get crd | grep squad
# squadteams.squad.github.com
# squadagents.squad.github.com
# squadrounds.squad.github.com

# Create a sample SquadAgent CR
kubectl apply -f - <<EOF
apiVersion: squad.github.com/v1alpha1
kind: SquadAgent
metadata:
  name: ralph
  namespace: squad
spec:
  name: ralph
  role: monitor
  image: squad-ralph:latest
  capabilities:
    - work-monitoring
    - issue-triage
  modelTier: standard
  schedule:
    type: interval
    intervalSeconds: 300
EOF

kubectl get squadagents -n squad
```

## CRD Overview

### SquadTeam

Defines a team with its agents and routing rules. Maps the `.squad/team.md` and
`squad.config.ts` concepts to a Kubernetes-native resource.

| Field | Description |
|-------|-------------|
| `spec.repository` | GitHub `owner/repo` |
| `spec.agents[]` | List of agent references with roles |
| `spec.routing.rules[]` | Work type → agent routing (maps `needs:*` labels) |
| `spec.models` | Model tier configuration |

### SquadAgent

Defines an individual agent. Each SquadAgent maps to one pod (pod-per-agent model).

| Field | Description |
|-------|-------------|
| `spec.role` | Agent function: monitor, lead, coder, etc. |
| `spec.capabilities[]` | Maps to `needs:*` labels for work routing |
| `spec.modelTier` | premium / standard / fast |
| `spec.schedule` | interval, cron, or continuous execution |
| `spec.nodeSelector` | Maps `needs:*` to K8s node affinity |

### SquadRound

Represents a single execution round (one Ralph poll cycle). Provides audit trail.

| Field | Description |
|-------|-------------|
| `spec.roundNumber` | Sequential round counter |
| `status.phase` | pending → running → completed/failed |
| `status.issuesProcessed[]` | Issues handled with actions taken |
| `status.durationSeconds` | Round execution time |

## Credential Management

### Current (POC): K8s Secrets

```bash
kubectl create secret generic squad-credentials \
  --from-literal=gh-token='ghp_...' \
  --namespace squad
```

### Future: Workload Identity (AKS)

```yaml
# values.yaml
serviceAccount:
  annotations:
    azure.workload.identity/client-id: "<managed-identity-client-id>"
```

Secrets stored in Azure Key Vault, injected via CSI driver — no tokens in cluster.

## Future Roadmap

| Phase | Goal | Status |
|-------|------|--------|
| **P0** | Dockerfile + docker-compose for Ralph | ✅ This PR |
| **P0** | Helm chart skeleton | ✅ This PR |
| **P0** | CRD definitions | ✅ This PR |
| **P1** | CI pipeline: build & push image to ACR | 🔜 Next |
| **P1** | GitHub App (non-human user) for agent auth | 🔜 Next |
| **P2** | AKS deployment with Workload Identity | 📋 Planned |
| **P2** | Squad Operator (reconcile CRDs → pods) | 📋 Planned |
| **P3** | KAITO integration for local model inference | 📋 Planned |
| **P3** | Multi-repo support (one operator, many teams) | 📋 Planned |
| **P4** | Auto-scaling based on issue queue depth | 💡 Future |
| **P4** | GitOps (ArgoCD/Flux) for agent deployment | 💡 Future |

## Design Decisions

- **Pod-per-agent** (not sidecar): Each agent is independently deployable,
  scalable, and observable. Avoids shared-process failure domains.
- **CRDs over ConfigMaps**: SquadTeam/Agent/Round CRDs provide typed schema,
  kubectl integration, and a path toward a reconciliation operator.
- **Cloud-agnostic core**: Helm chart runs on any K8s. AKS-specific features
  (Workload Identity, KAITO) are opt-in via values overrides.
- **Credentials via Secrets**: Simple starting point. Production path is
  Workload Identity + Key Vault, eliminating token storage in the cluster.
