# GitHub Rate Limit Exporter for KEDA Scaling

**Issue:** #1155 — Tier 2: Deploy github-exporter Prometheus bridge  
**Status:** Production-ready

## Overview

Prometheus exporter for GitHub API rate limits, enabling KEDA to make intelligent scaling decisions based on quota availability. Uses [kalgurn/github-rate-limits-prometheus-exporter](https://github.com/kalgurn/github-rate-limits-prometheus-exporter).

## Quick Start

```bash
# Option 1: Standalone manifests
kubectl apply -f k8s/deployment.yaml

# Option 2: Helm chart
helm install github-rate-limit-exporter ./helm \
  --namespace squad \
  --set github.secretName=squad-runtime-secrets
```

## Metrics Exposed

- `github_rate_limit_remaining{resource="core|search|graphql"}`
- `github_rate_limit_limit{resource}`  
- `github_rate_limit_reset_unix{resource}`
- `github_rate_limit_remaining_ratio`

## KEDA Integration

Enables KEDA Trigger 2 in `infrastructure/keda/squad-scaledobject.yaml`:

```yaml
- type: prometheus
  metadata:
    query: min(github_rate_limit_remaining{resource="core"} / github_rate_limit_limit{resource="core"})
    threshold: "0.1"
```

When ratio ≤ 10%, KEDA scales Squad pods to zero (backoff until reset).

## Documentation

- [INSTALL.md](./INSTALL.md) — Deployment guide
- [../docs/squad-on-k8s/keda-autoscaling.md](../docs/squad-on-k8s/keda-autoscaling.md) — Full KEDA architecture
- [Upstream Exporter](https://github.com/kalgurn/github-rate-limits-prometheus-exporter)
