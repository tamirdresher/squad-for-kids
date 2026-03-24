# CommunityToolkit.Aspire.Hosting.Kind

[![NuGet](https://img.shields.io/nuget/v/CommunityToolkit.Aspire.Hosting.Kind.svg)](https://www.nuget.org/packages/CommunityToolkit.Aspire.Hosting.Kind)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Aspire hosting extension for [Kind (Kubernetes in Docker)](https://kind.sigs.k8s.io/) — spin up ephemeral local Kubernetes clusters as first-class Aspire resources in your distributed application.

---

## Why use this?

| Scenario | Without Kind resource | With Kind resource |
|---|---|---|
| Local K8s testing | Manual `kind create cluster`, separate kubeconfig management | `builder.AddKindCluster("my-cluster")` — fully lifecycle-managed |
| Dev/test parity | Separate shell scripts per developer | Aspire AppHost defines the cluster alongside your services |
| CI ephemeral clusters | Bespoke YAML pipelines | Single AppHost, same code locally and in CI |
| Helm chart validation | `helm install` before running tests | Reference the cluster from integration tests — cluster is ready before tests run |

**CommunityToolkit.Aspire.Hosting.Kind creates ephemeral Kind clusters _as_ Aspire resources.** This is different from `Aspire.Hosting.Kubernetes`, which deploys your Aspire application _to_ an existing cluster. Both complement each other.

---

## Prerequisites

| Tool | Minimum Version | Install |
|---|---|---|
| Docker Desktop / Engine | 24.x | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Kind CLI | 0.23+ | `go install sigs.k8s.io/kind@latest` or `winget install Kubernetes.kind` |
| kubectl | 1.29+ | [kubernetes.io/docs](https://kubernetes.io/docs/tasks/tools/) |
| .NET SDK | 9.0+ | [dotnet.microsoft.com](https://dotnet.microsoft.com/download) |

> **Note:** The Kind CLI and Docker must be on `PATH` (or configured with explicit paths). The resource will fail fast with a clear message if they are missing.

---

## Getting Started

### 1. Install the NuGet package

```bash
dotnet add package CommunityToolkit.Aspire.Hosting.Kind
```

### 2. Add a Kind cluster to your AppHost

```csharp
// AppHost/Program.cs
var builder = DistributedApplication.CreateBuilder(args);

var cluster = builder.AddKindCluster("dev-cluster");

// Your services can reference the cluster's kubeconfig
var api = builder.AddProject<Projects.MyApi>("api")
    .WithReference(cluster);

builder.Build().Run();
```

### 3. Run the AppHost

```bash
dotnet run --project AppHost
```

Aspire starts the Kind cluster, waits for it to be ready, and makes the kubeconfig available to downstream resources. The Aspire dashboard shows cluster health.

---

## Configuration Options

### Parameters

`AddKindCluster` accepts two optional parameters for customization:

```csharp
builder.AddKindCluster(
    name: "dev-cluster",
    // Override the Kind cluster name (defaults to the Aspire resource name)
    clusterName: "my-custom-kind-cluster",
    // Override the kubeconfig path (defaults to a temp directory path)
    kubeconfigPath: "/tmp/my-cluster.yaml");
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `KIND_PATH` | `kind` (on PATH) | Explicit path to the Kind binary |
| `KUBECTL_PATH` | `kubectl` (on PATH) | Explicit path to kubectl |
| `KUBECONFIG_DIR` | temp directory | Directory where kubeconfig files are written |

---

## API Reference

### `IDistributedApplicationBuilder` extensions

#### `AddKindCluster(string name, string? clusterName = null, string? kubeconfigPath = null)`

Creates a new Kind cluster resource.

```csharp
IResourceBuilder<KindClusterResource> AddKindCluster(
    this IDistributedApplicationBuilder builder,
    string name,
    string? clusterName = null,
    string? kubeconfigPath = null)
```

**Parameters:**

| Parameter | Description |
|---|---|
| `name` | Logical name for the cluster in the Aspire application model. |
| `clusterName` | Name passed to `kind create/delete cluster --name`. Defaults to `name`. |
| `kubeconfigPath` | Absolute path where the kubeconfig file will be written. Defaults to a temp directory path. |

**Returns:** `IResourceBuilder<KindClusterResource>`

---
---

### `KindClusterResource`

Represents a Kind cluster in the Aspire application model.

| Property | Type | Description |
|---|---|---|
| `Name` | `string` | Cluster name |
| `KubeconfigPath` | `string` | Path to the generated kubeconfig file |
| `ConnectionString` | `string` | Kubeconfig path, usable as a connection string |

---

## Connection String

The Kind cluster exposes its kubeconfig path as a connection string. Downstream resources can access it via standard Aspire connection string APIs:

```csharp
// In your service project
var kubeconfig = builder.Configuration.GetConnectionString("dev-cluster");
// kubeconfig = "/tmp/aspire-kind-dev-cluster.kubeconfig"
```

---

## Lifecycle

```
AppHost starts
    │
    ▼
kind create cluster --name dev-cluster --kubeconfig <path>
    │
    ▼
kubectl --kubeconfig <path> get nodes   ← health check
    │ (nodes Ready)
    ▼
Aspire dashboard shows cluster as Running
    │
    ▼ (AppHost stops / Ctrl+C)
kind delete cluster --name dev-cluster
```

---

## Examples

### Minimal — single-node cluster

```csharp
var builder = DistributedApplication.CreateBuilder(args);
builder.AddKindCluster("test");
builder.Build().Run();
```

### Web API integration test environment

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var cluster = builder.AddKindCluster("test-cluster");

// Integration test runner picks up the cluster via the Aspire connection string
builder.AddProject<Projects.IntegrationTests>("integration-tests")
    .WithReference(cluster);

builder.Build().Run();
```

### CI pipeline (GitHub Actions)

```yaml
- name: Run Aspire AppHost (with Kind)
  run: dotnet run --project ./AppHost -- --publisher manifest
  env:
    DOTNET_ENVIRONMENT: Testing
```

> Kind requires Docker. Use a runner with Docker available (e.g., `ubuntu-latest` with `runs-on: ubuntu-latest` and Docker pre-installed).

---

## Troubleshooting

### `kind: command not found`

Set `KIND_PATH` to the full path of the Kind binary, or ensure Kind is on `PATH`.

### Cluster creation times out

Kind clusters can take a few minutes to start. Consider pre-pulling the Kind node image:

```bash
docker pull kindest/node:v1.30.0
```

### Port already in use

Check for existing Kind clusters with `kind get clusters` and delete stale ones if needed.

---

## Contributing

This package is part of the [.NET Aspire Community Toolkit](https://github.com/CommunityToolkit/Aspire).

- File issues at [CommunityToolkit/Aspire](https://github.com/CommunityToolkit/Aspire/issues)
- See [`CONTRIBUTING.md`](https://github.com/CommunityToolkit/Aspire/blob/main/CONTRIBUTING.md)

---

## License

MIT — see [LICENSE](../../LICENSE).
