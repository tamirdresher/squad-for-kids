# CommunityToolkit.Aspire.Hosting.Kind

An [Aspire](https://learn.microsoft.com/en-us/dotnet/aspire/get-started/aspire-overview) hosting integration for [Kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker) clusters.

## Overview

Kind (Kubernetes in Docker) lets you run local Kubernetes clusters using Docker containers as nodes. This integration allows you to declaratively provision and manage Kind clusters as part of your Aspire distributed application.

## Prerequisites

- [.NET 9 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)
- [Aspire 9.x workload](https://learn.microsoft.com/en-us/dotnet/aspire/fundamentals/setup-tooling)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or compatible container runtime)
- [kind CLI](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) installed and available on `PATH`

## Usage

### Add the NuGet package

```shell
dotnet add package CommunityToolkit.Aspire.Hosting.Kind
```

### Register a Kind cluster in your AppHost

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var cluster = builder.AddKindCluster("my-cluster");

builder.Build().Run();
```

## Configuration

> **Note:** Full configuration options (cluster config file, Kubernetes version, image registry, etc.) will be added in subsequent issues.

## Contributing

See the [contribution guide](https://github.com/CommunityToolkit/Aspire/blob/main/CONTRIBUTING.md) for the CommunityToolkit.Aspire project.

## License

[MIT](https://github.com/CommunityToolkit/Aspire/blob/main/LICENSE)
