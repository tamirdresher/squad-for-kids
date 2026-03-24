using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using FluentAssertions;

namespace CommunityToolkit.Aspire.Hosting.Kind.Tests;

public class KindClusterBuilderExtensionsTests
{
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
    public void AddKindCluster_ThrowsOnNullBuilder()
    {
        // Arrange
        IDistributedApplicationBuilder builder = null!;

        // Act
        Action act = () => builder.AddKindCluster("test-cluster");

        // Assert
        act.Should().Throw<ArgumentNullException>();
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
}
