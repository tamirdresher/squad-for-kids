using Aspire.Hosting.ApplicationModel;
using FluentAssertions;
using Xunit;

namespace CommunityToolkit.Aspire.Hosting.Kind.Tests;

/// <summary>
/// Tests for the <see cref="KindClusterResource"/> model itself (no builder required).
/// </summary>
public class KindClusterResourceTests
{
    // ──────────────────────────────────────────────────────────────────────────
    // Constructor / Name
    // ──────────────────────────────────────────────────────────────────────────

    private static KindClusterResource CreateResource(
        string name = "cluster",
        string clusterName = "cluster",
        string kubeconfigPath = "/tmp/kind-cluster-kubeconfig.yaml") =>
        new(name, clusterName, kubeconfigPath);

    [Fact]
    public void Constructor_SetsName()
    {
        var resource = CreateResource("my-cluster", "my-cluster", "/tmp/kind-my-cluster-kubeconfig.yaml");
        resource.Name.Should().Be("my-cluster");
    }

    [Fact]
    public void ClusterName_IsSetIndependently()
    {
        var resource = CreateResource("resource-name", "kind-dev", "/tmp/kind-dev-kubeconfig.yaml");
        resource.Name.Should().Be("resource-name");
        resource.ClusterName.Should().Be("kind-dev");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Defaults
    // ──────────────────────────────────────────────────────────────────────────

    [Fact]
    public void DefaultNodeCount_IsZero()
    {
        var resource = CreateResource();
        resource.NodeCount.Should().Be(0);
    }

    [Fact]
    public void DefaultKubernetesVersion_IsNull()
    {
        var resource = CreateResource();
        resource.KubernetesVersion.Should().BeNull();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Property mutation
    // ──────────────────────────────────────────────────────────────────────────

    [Theory]
    [InlineData(1)]
    [InlineData(3)]
    [InlineData(10)]
    public void NodeCount_CanBeSet(int count)
    {
        var resource = CreateResource();
        resource.NodeCount = count;
        resource.NodeCount.Should().Be(count);
    }

    [Theory]
    [InlineData("v1.28.0")]
    [InlineData("v1.29.3")]
    [InlineData("v1.31.0")]
    public void KubernetesVersion_CanBeSet(string version)
    {
        var resource = CreateResource();
        resource.KubernetesVersion = version;
        resource.KubernetesVersion.Should().Be(version);
    }

    [Fact]
    public void KubernetesVersion_CanBeSetToNull()
    {
        var resource = CreateResource();
        resource.KubernetesVersion = "v1.30.0";

        resource.KubernetesVersion = null;

        resource.KubernetesVersion.Should().BeNull();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Resource type
    // ──────────────────────────────────────────────────────────────────────────

    [Fact]
    public void Resource_IsAspireResource()
    {
        var resource = CreateResource();
        resource.Should().BeAssignableTo<Resource>();
    }
}
