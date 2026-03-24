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

builder.Build().Run();
