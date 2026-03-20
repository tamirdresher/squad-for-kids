# Picard Decision: Squad-on-Kubernetes Architecture

**Date:** 2026-03-20  
**Issue:** #1059  
**Author:** Picard (Architecture Lead)  
**Document:** `docs/squad-on-kubernetes-architecture.md`

## Key Decisions Made

1. **Pod-per-agent** (not sidecar): Each agent is an independent pod with isolated lifecycle, resources, and scaling.

2. **Ralph as Deployment** (not CronJob): Ralph's long-running reconciliation loop with in-process state maps to a Deployment with a heartbeat-based liveness probe, not a CronJob.

3. **MCP Servers**: Sidecar pattern for per-agent MCPs (ADO, Aspire); Shared Deployment for team-wide MCPs (GitHub, Teams, Calendar).

4. **Helm-first, Operator later**: Ship Helm chart (Phase 1–2), graduate to Squad Operator with CRDs in Phase 3.

5. **State**: Git-primary for config/decisions (unchanged); Azure Files PVC (RWX) for runtime state shared across Ralph replicas.

6. **Secrets**: K8s Secrets for Phase 1 (dev/staging); Azure Key Vault + CSI driver + Workload Identity for Phase 2 (production).

## Phased Plan
- **Phase 1** (now): Ralph in K8s, Helm chart, GitHub token via K8s Secret
- **Phase 2** (4–10 weeks): All agents, on-demand Jobs, MCP servers, ArgoCD GitOps
- **Phase 3** (10–20 weeks): KEDA autoscaling, multi-tenant, Squad Operator

## Related Work
- Issue #994: Architecture vision (confirmed and expanded)
- Issue #996: Dockerfile.ralph + Helm skeleton (Phase 1 deliverables)  
- Issue #1000: Helm chart prototype (extended into full chart spec)
