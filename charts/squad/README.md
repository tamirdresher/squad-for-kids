# Squad Helm Chart

Deploys Squad AI agents to Kubernetes (AKS). This is a prototype implementation of the pod-per-agent architecture for Squad-on-Kubernetes.

## Overview

This chart deploys:
- **Ralph StatefulSet**: Work monitor that claims GitHub issues and spawns agent Jobs
- **Picard Deployment** (optional, KEDA mode): Continuously-running Picard agent scaled by KEDA
- **Agent Job Template**: On-demand agent pods spawned per issue
- **Rate Pool (Redis)**: Shared rate limiting across Ralph replicas
- **Persistent Storage**: Azure Files for `.squad/` state (decisions, histories, round state)
- **KEDA Autoscaling** (optional): Token-aware autoscaling for Picard deployment
- **Metrics Exporters** (optional): Prometheus exporters for GitHub rate limits and Copilot token usage

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- Azure Files CSI driver (for ReadWriteMany PVC)
- GitHub Personal Access Token with repo scope
- **KEDA 2.12+** (optional, for autoscaling) - Enable with `az aks update --enable-keda`
- **Prometheus** (optional, for KEDA metrics) - Required if `keda.enabled=true`

## Installation

### 1. Create GitHub Token Secret

```bash
kubectl create namespace squad-system
kubectl create secret generic squad-github-token \
  --from-literal=token=YOUR_GITHUB_PAT \
  -n squad-system
```

### 2. Install Chart

```bash
helm install squad ./charts/squad \
  --namespace squad-system \
  --set squad.repository=your-org/your-repo
```

### 3. Verify Deployment

```bash
kubectl get statefulsets -n squad-system
kubectl get pods -n squad-system
kubectl logs -n squad-system squad-ralph-0 -f
```

## Configuration

Key `values.yaml` settings:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `squad.repository` | GitHub repository (owner/repo) | `tamirdresher_microsoft/tamresearch1` |
| `ralph.replicas` | Number of Ralph instances | `1` |
| `ralph.image` | Ralph container image | `ghcr.io/tamirdresher/squad-ralph:latest` |
| `agent.image` | Agent container image | `ghcr.io/tamirdresher/squad-agent:latest` |
| `ratePool.enabled` | Enable shared Redis rate limiting | `true` |
| `persistence.storageClass` | Storage class for PVC | `azurefile-csi` |
| `github.workloadIdentity.enabled` | Use Azure Workload Identity | `false` |
| `keda.enabled` | Enable KEDA autoscaling (deploys Picard Deployment) | `false` |
| `keda.tokenScaler.enabled` | Enable token-aware scaling triggers | `false` |
| `keda.tokenScaler.maxReplicaCount` | Maximum Picard replicas | `5` |
| `metricsExporter.enabled` | Deploy Prometheus metrics exporters | `false` |

## Architecture

### Pod-Per-Agent Model

Each agent runs as a Kubernetes Job spawned by Ralph:
- **Isolation**: Agents don't interfere with each other
- **Resources**: Per-agent CPU/memory limits
- **Scheduling**: Capability-based node selection (e.g., GPU)
- **Lifecycle**: Jobs auto-delete after 1 hour (ttlSecondsAfterFinished)

### Ralph StatefulSet

Ralph is a StatefulSet with stable pod names (`ralph-0`, `ralph-1`, etc.):
- Enables machine ID strategy for work claiming
- Multiple replicas share work via GitHub issue assignments
- Round interval: 5 minutes (configurable)

### Shared State

`.squad/` directory persisted as Azure Files PVC:
- **ReadWriteMany**: All Ralph replicas + agent Jobs access concurrently
- **Contents**: decisions.md, agent histories, round state
- **Size**: 5Gi default

### Rate Limiting

Redis deployment for distributed rate limiting:
- Shared across Ralph replicas and agent Jobs
- Prevents GitHub API rate limit exhaustion
- ClusterIP service: `squad-rate-pool:6379`

## Capability-Based Scheduling

Agents can declare capabilities (e.g., `needs:gpu`) for specialized hardware:

```yaml
scheduling:
  capabilityNodes:
    enabled: true
    gpuNodeSelector:
      capability.squad.io/gpu: "true"
```

Label nodes:
```bash
kubectl label nodes aks-gpu-pool-12345 capability.squad.io/gpu=true
```

## Security

- **Network Policy**: Restricts egress to GitHub API + Redis only
- **RBAC**: ServiceAccount with minimal Job creation permissions
- **Secrets**: GitHub PAT stored in Kubernetes Secret
- **Workload Identity** (future): Azure AD integration for GitHub auth

## Upgrade

```bash
helm upgrade squad ./charts/squad \
  --namespace squad-system \
  --reuse-values
```

## Uninstall

```bash
helm uninstall squad -n squad-system
kubectl delete namespace squad-system
```

## Troubleshooting

### Ralph not starting

```bash
kubectl describe pod -n squad-system squad-ralph-0
kubectl logs -n squad-system squad-ralph-0
```

Check GitHub token validity and network connectivity.

### Agent Jobs failing

```bash
kubectl get jobs -n squad-system
kubectl logs -n squad-system job/squad-agent-picard-123
```

Verify agent image, resource limits, and PVC mount.

### Rate pool connection issues

```bash
kubectl get pods -n squad-system -l app.kubernetes.io/component=rate-pool
kubectl exec -it -n squad-system squad-rate-pool-xxx -- redis-cli ping
```

## Roadmap

- **P0**: Ralph pod starts, connects to GitHub, reads issues ✅
- **P1**: Ralph spawns agent Job for claimed issue, agent completes work
- **P2**: Rate-pool tracks API usage across replicas
- **P3**: Capability-based scheduling (GPU nodes)
- **P4**: Workload Identity for GitHub auth (no PAT)
- **P5**: KEDA autoscaling with token-aware scaling (see #1134) ✅

## KEDA Autoscaling (Experimental)

Enable token-aware autoscaling for the Picard agent:

```bash
# 1. Enable KEDA on AKS
az aks update --resource-group rg-squad --name aks-squad --enable-keda

# 2. Install Prometheus (if not already installed)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

# 3. Install Squad with KEDA enabled
helm install squad ./charts/squad \
  --namespace squad-system \
  --set keda.enabled=true \
  --set keda.tokenScaler.enabled=true \
  --set metricsExporter.enabled=true
```

This deploys:
- **Picard Deployment**: Continuously-running Picard agent (0-5 replicas)
- **KEDA ScaledObject**: Scales Picard based on:
  - Queue depth (`squad:picard` labeled issues)
  - Copilot token availability
  - GitHub API rate limit headroom
- **Metrics Exporters**: Expose Prometheus metrics for KEDA triggers

**Scale-to-zero**: When no work is queued OR tokens are exhausted OR rate limits are hit, Picard scales to 0 replicas and waits for conditions to clear.

For detailed setup and troubleshooting, see [docs/keda-token-scaler-implementation.md](../../docs/keda-token-scaler-implementation.md).

## Links

- [Squad Framework](https://github.com/tamirdresher_microsoft/tamresearch1)
- [Helm Documentation](https://helm.sh/docs/)
- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
