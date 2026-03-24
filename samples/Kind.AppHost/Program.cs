<<<<<<< HEAD
using Aspire.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

// Minimal single-node cluster
var devCluster = builder.AddKindCluster("dev-cluster");

// Multi-node cluster with a specific Kubernetes version and port mapping for ingress
var stagingCluster = builder
    .AddKindCluster("staging-cluster")
    .WithNodeCount(2)
    .WithKubernetesVersion("v1.31.0")
    .WithPortMapping(hostPort: 80, containerPort: 80)
    .WithPortMapping(hostPort: 443, containerPort: 443)
    .WithHelmChart(
        releaseName: "ingress-nginx",
        chart: "ingress-nginx/ingress-nginx",
        @namespace: "ingress-nginx")
    .WithManifest("k8s/namespace.yaml")
    .WithWaitForReady(TimeSpan.FromMinutes(8));
=======
// samples/Kind.AppHost/Program.cs
// Demonstrates CommunityToolkit.Aspire.Hosting.Kind:
//  - Ephemeral Kind cluster with lifecycle management
//  - Integration test runner that uses the cluster kubeconfig

var builder = DistributedApplication.CreateBuilder(args);

// ─────────────────────────────────────────────────────────
// 1. Kind cluster — ephemeral, managed by Aspire lifecycle
// ─────────────────────────────────────────────────────────
var cluster = builder.AddKindCluster("demo-cluster");

// ─────────────────────────────────────────────────────────
// 2. .NET integration tests — run after cluster is ready
//    The project reads KUBECONFIG / connection-string to
//    discover the cluster.
// ─────────────────────────────────────────────────────────
builder
    .AddProject<Projects.Kind_IntegrationTests>("integration-tests")
    .WithReference(cluster);
>>>>>>> emu/main

builder.Build().Run();
