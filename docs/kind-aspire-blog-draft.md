# Spin Up Kubernetes Clusters as Aspire Resources with CommunityToolkit.Aspire.Hosting.Kind

> **Status:** Draft — for .NET Blog / dev.to announcement  
> **Audience:** .NET developers using Aspire who want local Kubernetes testing  
> **Word count target:** 600+ words with code examples

---

## TL;DR

We're contributing a new integration to the [.NET Aspire Community Toolkit](https://github.com/CommunityToolkit/Aspire): `CommunityToolkit.Aspire.Hosting.Kind`. It lets you declare an ephemeral [Kind (Kubernetes in Docker)](https://kind.sigs.k8s.io/) cluster directly in your Aspire `AppHost`, with full lifecycle management — no shell scripts, no manual kubeconfig wrangling.

```csharp
var cluster = builder.AddKindCluster("dev-cluster")
    .WithHelm("my-api", "./charts/my-api")
    .WithPortForward(8080, 80);
```

That's it. Aspire creates the cluster, deploys your Helm chart, and tears it down when you stop the AppHost.

---

## The Gap This Fills

.NET Aspire is excellent at modeling distributed applications — containers, databases, message buses, cloud services. The missing piece for Kubernetes-native teams was **local cluster lifecycle**.

Today you have two options in the Aspire ecosystem:

- **`Aspire.Hosting.Kubernetes`** — publishes your Aspire application _to_ an existing Kubernetes cluster (manifest generation / GitOps flow)
- **Manual Kind setup** — `kind create cluster` before `dotnet run`, `kind delete cluster` on cleanup; kubeconfig paths differ per developer

`CommunityToolkit.Aspire.Hosting.Kind` fills the gap: it creates ephemeral Kind clusters _as_ Aspire resources, on the same lifecycle as your containers and services.

---

## Origin Story

This started from a meeting in March 2026 between the .NET Aspire team and engineers from the idk8s (Celestial) platform team at Microsoft. Andrey Noskov had already built an internal Kind resource inside the Celestial infrastructure repo — battle-tested across dozens of engineers running ephemeral clusters for service integration tests. The question was: how do we give this to the broader .NET community?

The answer: extract the generic cluster lifecycle, strip out Celestial-specific internals, and contribute it to the Aspire Community Toolkit as `CommunityToolkit.Aspire.Hosting.Kind`.

---

## How It Works

### Cluster lifecycle

When the AppHost starts, the resource:

1. Runs `kind create cluster --name <name> --config <generated-or-custom> --kubeconfig <path>`
2. Polls `kubectl --kubeconfig <path> get nodes` until all nodes report `Ready`
3. Optionally runs `helm install` for any charts configured with `.WithHelm(...)`
4. Reports the cluster as healthy to the Aspire dashboard

When the AppHost stops (or is interrupted):

5. Runs `kind delete cluster --name <name>`

The kubeconfig path is exposed as a connection string so downstream resources can discover it automatically.

### The AppHost integration

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Ephemeral Kind cluster — single node, K8s 1.30
var cluster = builder
    .AddKindCluster("test-cluster")
    .WithKubernetesVersion("v1.30.0")
    .WithHelm("sample-api", "./charts/sample-api", valuesFile: "./values.test.yaml")
    .WithPortForward(hostPort: 8080, clusterPort: 80)
    .WithWaitForReady(TimeSpan.FromMinutes(3));

// Integration test project references the cluster
builder
    .AddProject<Projects.IntegrationTests>("integration-tests")
    .WithReference(cluster);

builder.Build().Run();
```

Your integration test project reads the connection string the usual Aspire way:

```csharp
// In IntegrationTests/Program.cs or test setup
var kubeconfig = builder.Configuration.GetConnectionString("test-cluster");
// → "/tmp/aspire-kind-test-cluster.kubeconfig"
```

Pass it to your Kubernetes client of choice (official `k8s-client`, `KubernetesClient` NuGet, or run `kubectl --kubeconfig <path>` in shell steps).

### Custom cluster topology

Need multiple workers or a specific network config?

```csharp
builder.AddKindCluster("multi-node")
    .WithNodeCount(3)          // 1 control-plane + 2 workers
    .WithKubernetesVersion("v1.29.4");
```

Or drop in a full Kind config file:

```csharp
builder.AddKindCluster("custom")
    .WithKindConfig("./kind-ha.yaml");
```

---

## Why Not Just Use docker-compose or TestContainers?

Good question. Here's the breakdown:

| Need | docker-compose | TestContainers | Kind+Aspire |
|---|---|---|---|
| Container orchestration | ✅ | ✅ | ✅ |
| Kubernetes API (CRDs, Operators, Ingress) | ❌ | ⚠️ via Testcontainers.K3s | ✅ full Kind cluster |
| Aspire dashboard visibility | ❌ | ❌ | ✅ |
| Helm chart deployment | ❌ | ❌ | ✅ `.WithHelm()` |
| Shared kubeconfig for services | manual | manual | ✅ connection string |

If you're testing against real Kubernetes primitives — CRDs, admission webhooks, Ingress controllers, RBAC — you need a real cluster, and Kind is the best local option. Wrapping it in Aspire means all your team members get the same experience with zero setup friction.

---

## Prerequisites

- Docker Desktop (or Docker Engine on Linux)
- Kind CLI: `winget install Kubernetes.kind` or `go install sigs.k8s.io/kind@latest`
- kubectl
- .NET 9 SDK

---

## Getting Started

```bash
dotnet add package CommunityToolkit.Aspire.Hosting.Kind
```

Minimal AppHost:

```csharp
var builder = DistributedApplication.CreateBuilder(args);
builder.AddKindCluster("local");
builder.Build().Run();
```

The Aspire dashboard will show the cluster resource. Done.

---

## What's Next

- **`kubectl apply` support** — apply raw manifests alongside Helm charts
- **Multi-cluster** — multiple named clusters in one AppHost
- **Cluster reuse** — optional flag to skip teardown for faster dev iterations
- **Aspire 9+ resource health** — rich status reporting in the dashboard

We're tracking the public contribution at [CommunityToolkit/Aspire #1428](https://github.com/CommunityToolkit/Aspire/issues/1428).

---

## Try It Out

The package is in development. To track progress or contribute:

- Source: [github.com/CommunityToolkit/Aspire](https://github.com/CommunityToolkit/Aspire)
- This PR: _(link to be added at submission time)_
- Issues / feedback: tag `area: Hosting.Kind`

We'd love to hear how you're using Kind in your .NET testing workflows — drop a comment or open an issue!

---

*Built by the .NET Aspire Community — contributions welcome.*
