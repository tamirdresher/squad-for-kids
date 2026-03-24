using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using FluentAssertions;
using Xunit;

namespace CommunityToolkit.Aspire.Hosting.Kind.Tests;

public class KindClusterBuilderExtensionsTests
{
    // ──────────────────────────────────────────────────────────────────────────
    // AddKindCluster
    // ──────────────────────────────────────────────────────────────────────────

    [Fact]
    public void AddKindCluster_AddsResourceWithCorrectName()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();

        // Act
        var clusterBuilder = builder.AddKindCluster("test-cluster");

        // Assert
        clusterBuilder.Resource.Name.Should().Be("test-cluster");
    }

    [Fact]
    public void AddKindCluster_ResourceIsRegisteredInBuilder()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();

        // Act
        var clusterBuilder = builder.AddKindCluster("my-cluster");

        // Assert
        builder.Resources.Should().ContainSingle(r => r.Name == "my-cluster");
        builder.Resources.Single(r => r.Name == "my-cluster").Should().BeOfType<KindClusterResource>();
    }

    [Fact]
    public void AddKindCluster_ThrowsOnNullBuilder()
    {
        // Arrange
        IDistributedApplicationBuilder builder = null!;

        // Act
        Action act = () => builder.AddKindCluster("test-cluster");

        // Assert
        act.Should().Throw<ArgumentNullException>()
           .WithParameterName("builder");
    }

    [Fact]
    public void AddKindCluster_ThrowsOnEmptyName()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();

        // Act
        Action act = () => builder.AddKindCluster(string.Empty);

        // Assert
        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void AddKindCluster_ThrowsOnNullName()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();

        // Act
        Action act = () => builder.AddKindCluster(null!);

        // Assert
        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void AddKindCluster_DefaultNodeCountIsOne()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();

        // Act
        var clusterBuilder = builder.AddKindCluster("defaults-cluster");

        // Assert
        clusterBuilder.Resource.NodeCount.Should().Be(1);
    }

    [Fact]
    public void AddKindCluster_DefaultKubernetesVersionIsNull()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();

        // Act
        var clusterBuilder = builder.AddKindCluster("defaults-cluster");

        // Assert
        clusterBuilder.Resource.KubernetesVersion.Should().BeNull();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // WithNodeCount
    // ──────────────────────────────────────────────────────────────────────────

    [Fact]
    public void WithNodeCount_SetsNodeCountOnResource()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();
        var clusterBuilder = builder.AddKindCluster("my-cluster");

        // Act
        clusterBuilder.WithNodeCount(3);

        // Assert
        clusterBuilder.Resource.NodeCount.Should().Be(3);
    }

    [Fact]
    public void WithNodeCount_ReturnsTheSameBuilder_ForChaining()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();
        var clusterBuilder = builder.AddKindCluster("my-cluster");

        // Act
        var returned = clusterBuilder.WithNodeCount(2);

        // Assert
        returned.Should().BeSameAs(clusterBuilder);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(-100)]
    public void WithNodeCount_ThrowsWhenNodeCountIsLessThanOne(int invalidCount)
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();
        var clusterBuilder = builder.AddKindCluster("my-cluster");

        // Act
        Action act = () => clusterBuilder.WithNodeCount(invalidCount);

        // Assert
        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void WithNodeCount_ThrowsOnNullBuilder()
    {
        // Arrange
        IResourceBuilder<KindClusterResource> clusterBuilder = null!;

        // Act
        Action act = () => clusterBuilder.WithNodeCount(2);

        // Assert
        act.Should().Throw<ArgumentNullException>();
    }

    [Fact]
    public void WithNodeCount_CanChainMultipleCalls()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();
        var clusterBuilder = builder.AddKindCluster("my-cluster");

        // Act — second call wins
        clusterBuilder.WithNodeCount(2).WithNodeCount(5);

        // Assert
        clusterBuilder.Resource.NodeCount.Should().Be(5);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // WithKubernetesVersion
    // ──────────────────────────────────────────────────────────────────────────

    [Fact]
    public void WithKubernetesVersion_SetsVersionOnResource()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();
        var clusterBuilder = builder.AddKindCluster("my-cluster");

        // Act
        clusterBuilder.WithKubernetesVersion("v1.31.0");

        // Assert
        clusterBuilder.Resource.KubernetesVersion.Should().Be("v1.31.0");
    }

    [Fact]
    public void WithKubernetesVersion_ReturnsTheSameBuilder_ForChaining()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();
        var clusterBuilder = builder.AddKindCluster("my-cluster");

        // Act
        var returned = clusterBuilder.WithKubernetesVersion("v1.30.0");

        // Assert
        returned.Should().BeSameAs(clusterBuilder);
    }

    [Fact]
    public void WithKubernetesVersion_AcceptsNull_ToUseDefault()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();
        var clusterBuilder = builder.AddKindCluster("my-cluster");
        clusterBuilder.WithKubernetesVersion("v1.30.0");

        // Act — reset to default
        clusterBuilder.WithKubernetesVersion(null);

        // Assert
        clusterBuilder.Resource.KubernetesVersion.Should().BeNull();
    }

    [Fact]
    public void WithKubernetesVersion_ThrowsOnNullBuilder()
    {
        // Arrange
        IResourceBuilder<KindClusterResource> clusterBuilder = null!;

        // Act
        Action act = () => clusterBuilder.WithKubernetesVersion("v1.30.0");

        // Assert
        act.Should().Throw<ArgumentNullException>();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Fluent chaining (AddKindCluster + WithNodeCount + WithKubernetesVersion)
    // ──────────────────────────────────────────────────────────────────────────

    [Fact]
    public void FluentChain_AllOptions_AreAppliedCorrectly()
    {
        // Arrange
        var builder = DistributedApplication.CreateBuilder();

        // Act
        var clusterBuilder = builder
            .AddKindCluster("full-cluster")
            .WithNodeCount(4)
            .WithKubernetesVersion("v1.31.0");

        // Assert
        clusterBuilder.Resource.Name.Should().Be("full-cluster");
        clusterBuilder.Resource.NodeCount.Should().Be(4);
        clusterBuilder.Resource.KubernetesVersion.Should().Be("v1.31.0");
    }
}

