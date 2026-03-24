# CommunityToolkit/Aspire — Upstream Feature Request Draft

**Ready to post at:** https://github.com/CommunityToolkit/Aspire/issues/new?template=feature_proposal.yml  
**Prepared by:** Seven (Research & Docs)  
**For issue:** tamirdresher_microsoft/tamresearch1#1428  
**Status:** DRAFT — post only after Tamir decides Option A in #1432

---

## Title

```
Add CommunityToolkit.Aspire.Hosting.Kind — Kubernetes-in-Docker cluster hosting integration
```

---

## Feature Request Body

> Copy and paste the text below into the GitHub issue form

---

### What problem does this solve?

`.NET Aspire` has `Aspire.Hosting.Kubernetes` which generates Kubernetes manifests and deploys *to* existing clusters. But there is no Aspire resource for **creating ephemeral Kubernetes clusters** as part of an Aspire application.

[Kind (Kubernetes-in-Docker)](https://kind.sigs.k8s.io/) fills this gap: it creates and destroys single- or multi-node Kubernetes clusters inside Docker, with no cloud subscription or VM overhead. This is widely used for:

- **Local development** — test Kubernetes-native apps without a cloud cluster
- **CI pipelines** — per-run isolated K8s environments (used by Kubernetes itself in CI)
- **Developer sandboxes** — when Docker Compose isn't enough

### Proposed solution

Add `CommunityToolkit.Aspire.Hosting.Kind` with:

- `KindClusterResource` — an `IResourceWithConnectionString` that exposes the kubeconfig path as the connection string, allowing downstream services to discover and use the cluster
- `KindClusterLifecycleHook` — manages `kind create cluster` on app start and `kind delete cluster` on stop
- `KindBuilderExtensions` — fluent API: `AddKindCluster`, `WithNodeCount`, `WithKubernetesVersion`, `WithConfig`

**Usage:**

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var cluster = builder.AddKindCluster("dev-cluster")
    .WithNodeCount(3)
    .WithKubernetesVersion("v1.29.0");

// Downstream service receives KUBECONFIG env var pointing to the cluster
builder.AddProject<Projects.MyApi>()
       .WithReference(cluster);

builder.Build().Run();
```

### Prior art / validation

This pattern has been in production use at Microsoft in the [idk8s / Celestial](https://github.com/microsoft/celestial) platform (developed by Andrey Noskov, Craig Treasure, and the IDM Core Infrastructure team). The integration has been validated in real CI pipelines handling Kubernetes workloads.

**Co-author:** Andrey Noskov (@andreyn, Microsoft) — original architect of this pattern.

### Alternatives considered

| Alternative | Why not? |
|---|---|
| `TestContainers` for K8s | Only supports single-container setup, not multi-node |
| `minikube` / `k3d` | Different CLI interfaces; Kind is the Kubernetes project's official test tool |
| `Aspire.Hosting.Kubernetes` | Deployment only — no cluster provisioning |

### Is this integration useful beyond your own project?

Yes. Kind is used by the upstream Kubernetes project itself for E2E testing, and is one of the most common local K8s tools in the .NET ecosystem (alongside minikube and k3d). Many teams using Aspire for microservices will need local K8s testing at some point.

### Are you willing to contribute this integration?

Yes — Tamir Dresher (@tamirdresher, Microsoft) and Andrey Noskov (@andreyn, Microsoft) are ready to submit a PR following all contribution guidelines once this issue is approved.

---

## Checklist Before Posting

- [ ] Decision made on #1432 (go with CommunityToolkit)
- [ ] PR #1448 (core lifecycle) security blockers fixed and merged
- [ ] PR #1444 (docs) issues fixed and merged  
- [ ] Tamir has decided whether Andrey or Tamir forks CommunityToolkit/Aspire
- [ ] Coordinate with Maddy Montaquila (Aspire PM) for maintainer awareness

---

## Key contacts for the upstream issue

| Role | Person |
|---|---|
| Aspire PM (can accelerate review) | Maddy Montaquila |
| CommunityToolkit maintainer | Aaron Powell |
| Original author | Andrey Noskov (andreyn@microsoft.com) |
