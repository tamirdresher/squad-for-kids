# B'Elanna Infrastructure Findings — DK8S Knowledge Consolidation

**Date:** 2026-03-06  
**Issue:** #2 — Consolidate DK8S platform knowledge  
**Author:** B'Elanna Torres (Infrastructure Expert)

## Key Infrastructure Findings

### 1. Two Distinct Kubernetes Platforms Documented

- **Celestial (idk8s-infrastructure)**: Identity division's fleet management platform — 18 prod clusters, 7 sovereign clouds, 19 tenants, EV2-driven deployments, Component Deployer pattern
- **DK8S (Defender Kubernetes)**: Defender platform — ArgoCD-driven GitOps, ConfigGen manifest expansion, shared Helm charts

### 2. Critical Architecture Differences

| Aspect | Celestial | DK8S |
|--------|-----------|------|
| Deployment model | EV2 + Component Deployer | EV2 + ArgoCD GitOps |
| Chart strategy | Single shared chart (Celestial) | Per-component charts |
| ACR | 12 registries (multi-cloud) | Single `wcdprodacr` |
| Pipeline templates | OneBranch (self-contained) | OneBranch + shared PipelineTemplates |
| Config expansion | Fleet Manager SDK | ConfigGen tool |

### 3. Infrastructure Gaps Requiring Action

1. **ACR naming migration** — `iamkubernetes*` → `idk8sacr*` incomplete (Celestial)
2. **No default-deny NetworkPolicies** documented for either platform
3. **Skylarc container silently swallows bootstrapper failures** (commented-out exit)
4. **SDP Ring 2 blast radius** — 8 clusters deployed simultaneously
5. **Certificate rotation** remains manual for some KeyVault TLS certs

### 4. Local Repos Are Plugin Hubs

Both `Dk8sCodingAI-1` and `Dk8sCodingAIgithub` are AI plugin/documentation repos — no actual Helm charts, K8s manifests, or infrastructure code. They codify DK8S patterns as 12-15 skills for AI agents.

## Recommendation

The infrastructure inventory (`dk8s-infrastructure-inventory.md`) consolidates both platforms into a single reference. Future work should focus on:
1. Getting direct access to DK8S cluster inventory (`ClustersInventory_DK8S.json`) for concrete cluster enumeration
2. Comparing Celestial vs DK8S deployment patterns for cross-pollination opportunities
3. Addressing shared security gaps (NetworkPolicies, cert automation)
