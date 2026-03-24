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

    [Fact]
    public void Constructor_SetsName()
    {
        var resource = new KindClusterResource("my-cluster");
        resource.Name.Should().Be("my-cluster");
    }

    [Fact]
    public void ClusterName_EqualsName()
    {
        var resource = new KindClusterResource("kind-dev");
        resource.ClusterName.Should().Be(resource.Name);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Defaults
    // ──────────────────────────────────────────────────────────────────────────

    [Fact]
    public void DefaultNodeCount_IsOne()
    {
        var resource = new KindClusterResource("cluster");
        resource.NodeCount.Should().Be(1);
    }

    [Fact]
    public void DefaultKubernetesVersion_IsNull()
    {
        var resource = new KindClusterResource("cluster");
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
        var resource = new KindClusterResource("cluster") { NodeCount = count };
        resource.NodeCount.Should().Be(count);
    }

    [Theory]
    [InlineData("v1.28.0")]
    [InlineData("v1.29.3")]
    [InlineData("v1.31.0")]
    public void KubernetesVersion_CanBeSet(string version)
    {
        var resource = new KindClusterResource("cluster") { KubernetesVersion = version };
        resource.KubernetesVersion.Should().Be(version);
    }

    [Fact]
    public void KubernetesVersion_CanBeSetToNull()
    {
        var resource = new KindClusterResource("cluster")
        {
            KubernetesVersion = "v1.30.0"
        };

        resource.KubernetesVersion = null;

        resource.KubernetesVersion.Should().BeNull();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Resource type
    // ──────────────────────────────────────────────────────────────────────────

    [Fact]
    public void Resource_IsAspireResource()
    {
        var resource = new KindClusterResource("cluster");
        resource.Should().BeAssignableTo<Resource>();
    }
}
