using Aspire.Hosting;
using FluentAssertions;
using Xunit;

namespace CommunityToolkit.Aspire.Hosting.Kind.Tests;

/// <summary>
/// Integration tests for the full Kind cluster lifecycle.
///
/// These tests require Docker and the <c>kind</c> CLI to be installed on the
/// test runner. They are skipped by default and are designed to run manually
/// or in a CI job with Docker-in-Docker support (see
/// <c>.github/workflows/kind-aspire-ci.yml</c> for the integration-test job).
///
/// To run locally:
/// <code>
/// dotnet test --filter "Category=Integration"
/// </code>
/// </summary>
[Trait("Category", "Integration")]
public class KindClusterLifecycleIntegrationTests
{
    // ──────────────────────────────────────────────────────────────────────────
    // Lifecycle stubs
    // ──────────────────────────────────────────────────────────────────────────

    [Fact(Skip = "requires-docker: Docker and kind CLI must be available")]
    public async Task AddKindCluster_StartsClusterSuccessfully()
    {
        // INTEGRATION STUB
        // TODO: When this test runs for real:
        //   1. Build + start the DistributedApplication.
        //   2. Assert the Kind cluster is created (run `kind get clusters` and check output).
        //   3. Dispose the app and assert the cluster is deleted.
        //
        // Example scaffolding (fill in when hooking up lifecycle hooks):
        //
        //   var appBuilder = DistributedApplication.CreateBuilder();
        //   appBuilder.AddKindCluster("integration-cluster");
        //   await using var app = appBuilder.Build();
        //   await app.StartAsync();
        //   // Assert cluster exists via kind CLI or kubeconfig
        //   await app.StopAsync();

        await Task.CompletedTask; // placeholder
        true.Should().BeTrue("stub must be replaced with a real assertion");
    }

    [Fact(Skip = "requires-docker: Docker and kind CLI must be available")]
    public async Task AddKindCluster_WithNodeCount_StartsCorrectNumberOfNodes()
    {
        // INTEGRATION STUB
        // TODO:
        //   1. Build + start the app with `.WithNodeCount(3)`.
        //   2. Run `kubectl get nodes --kubeconfig <path>` and assert 3 nodes are Ready.
        //   3. Dispose.

        await Task.CompletedTask;
        true.Should().BeTrue("stub must be replaced with a real assertion");
    }

    [Fact(Skip = "requires-docker: Docker and kind CLI must be available")]
    public async Task AddKindCluster_WithKubernetesVersion_UsesSpecifiedVersion()
    {
        // INTEGRATION STUB
        // TODO:
        //   1. Build + start the app with `.WithKubernetesVersion("v1.31.0")`.
        //   2. Run `kubectl version --kubeconfig <path>` and assert server version is v1.31.0.
        //   3. Dispose.

        await Task.CompletedTask;
        true.Should().BeTrue("stub must be replaced with a real assertion");
    }

    [Fact(Skip = "requires-docker: Docker and kind CLI must be available")]
    public async Task DisposeApp_DeletesKindCluster()
    {
        // INTEGRATION STUB
        // TODO:
        //   1. Build + start the app.
        //   2. Capture cluster name.
        //   3. Dispose the app.
        //   4. Run `kind get clusters` and assert the cluster is gone.

        await Task.CompletedTask;
        true.Should().BeTrue("stub must be replaced with a real assertion");
    }

    [Fact(Skip = "requires-docker: Docker and kind CLI must be available")]
    public async Task AddKindCluster_KubeconfigIsAccessible()
    {
        // INTEGRATION STUB
        // TODO:
        //   1. Build + start the app.
        //   2. Assert the kubeconfig file / connection string surfaced by the resource
        //      allows a successful `kubectl get namespaces` call.
        //   3. Dispose.

        await Task.CompletedTask;
        true.Should().BeTrue("stub must be replaced with a real assertion");
    }
}
