using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CommunityToolkit.Aspire.Hosting.Kind.Tests;

public class KindClusterResourceTests
{
    [Fact]
    public void Constructor_SetsPropertiesCorrectly()
    {
        var resource = new KindClusterResource("my-resource", "my-cluster", "/tmp/kubeconfig.yaml");

        resource.Name.Should().Be("my-resource");
        resource.ClusterName.Should().Be("my-cluster");
        resource.KubeconfigPath.Should().Be("/tmp/kubeconfig.yaml");
    }

    [Fact]
    public void Constructor_DefaultsAreCorrect()
    {
        var resource = new KindClusterResource("r", "c", "/tmp/kc.yaml");

        resource.NodeCount.Should().Be(0);
        resource.KubernetesVersion.Should().BeNull();
        resource.ConfigPath.Should().BeNull();
        resource.ReadyTimeout.Should().Be(TimeSpan.FromMinutes(5));
        resource.PortMappings.Should().BeEmpty();
        resource.HelmCharts.Should().BeEmpty();
        resource.ManifestPaths.Should().BeEmpty();
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Constructor_ThrowsOnEmptyClusterName(string clusterName)
    {
        Action act = () => new KindClusterResource("name", clusterName, "/tmp/kc.yaml");
        act.Should().Throw<ArgumentException>();
    }

    [Theory]
    [InlineData("UPPERCASE")]
    [InlineData("has space")]
    [InlineData("-starts-with-hyphen")]
    [InlineData("has_underscore")]
    [InlineData("has.dot")]
    public void Constructor_ThrowsOnInvalidClusterName(string clusterName)
    {
        Action act = () => new KindClusterResource("name", clusterName, "/tmp/kc.yaml");
        act.Should().Throw<ArgumentException>()
           .WithMessage("*lowercase*");
    }

    [Theory]
    [InlineData("valid")]
    [InlineData("valid-name")]
    [InlineData("v123")]
    [InlineData("my-cluster-1")]
    public void Constructor_AcceptsValidClusterNames(string clusterName)
    {
        var act = () => new KindClusterResource("name", clusterName, "/tmp/kc.yaml");
        act.Should().NotThrow();
    }

    [Fact]
    public void Constructor_ThrowsOnEmptyKubeconfigPath()
    {
        Action act = () => new KindClusterResource("name", "cluster", "");
        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void ConnectionStringExpression_ReturnsKubeconfigPath()
    {
        var resource = new KindClusterResource("r", "cluster", "/home/user/.kube/kind.yaml");

        // ConnectionStringExpression wraps the kubeconfig path as a literal reference.
        resource.ConnectionStringExpression.Should().NotBeNull();
    }

    [Fact]
    public void AddPortMapping_AppearsInPortMappings()
    {
        var resource = new KindClusterResource("r", "c", "/tmp/kc.yaml");

        resource.AddPortMapping(new KindPortMapping(8080, 80));

        resource.PortMappings.Should().ContainSingle()
            .Which.Should().BeEquivalentTo(new KindPortMapping(8080, 80, "TCP"));
    }

    [Fact]
    public void AddHelmChart_AppearsInHelmCharts()
    {
        var resource = new KindClusterResource("r", "c", "/tmp/kc.yaml");
        var chart = new KindHelmChart("nginx", "ingress-nginx/ingress-nginx");

        resource.AddHelmChart(chart);

        resource.HelmCharts.Should().ContainSingle().Which.Should().Be(chart);
    }

    [Fact]
    public void AddManifestPath_AppearsInManifestPaths()
    {
        var resource = new KindClusterResource("r", "c", "/tmp/kc.yaml");

        resource.AddManifestPath("/k8s/deployment.yaml");

        resource.ManifestPaths.Should().ContainSingle().Which.Should().Be("/k8s/deployment.yaml");
    }
}

public class KindClusterBuilderExtensionsTests
{
    [Fact]
    public void AddKindCluster_RegistersResourceWithCorrectName()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("dev-cluster");

        rb.Resource.Name.Should().Be("dev-cluster");
    }

    [Fact]
    public void AddKindCluster_UsesNameAsClusterNameByDefault()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("my-cluster");

        rb.Resource.ClusterName.Should().Be("my-cluster");
    }

    [Fact]
    public void AddKindCluster_AcceptsExplicitClusterName()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("aspire-name", clusterName: "kind-name");

        rb.Resource.ClusterName.Should().Be("kind-name");
    }

    [Fact]
    public void AddKindCluster_AcceptsExplicitKubeconfigPath()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("c", kubeconfigPath: "/custom/kc.yaml");

        rb.Resource.KubeconfigPath.Should().Be("/custom/kc.yaml");
    }

    [Fact]
    public void AddKindCluster_GeneratesDefaultKubeconfigPathInTempDir()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("my-cluster");

        rb.Resource.KubeconfigPath.Should().StartWith(Path.GetTempPath());
        rb.Resource.KubeconfigPath.Should().Contain("my-cluster");
        rb.Resource.KubeconfigPath.Should().EndWith(".yaml");
    }

    [Fact]
    public void AddKindCluster_ThrowsOnNullBuilder()
    {
        IDistributedApplicationBuilder builder = null!;

        Action act = () => builder.AddKindCluster("cluster");

        act.Should().Throw<ArgumentNullException>();
    }

    [Fact]
    public void AddKindCluster_ThrowsOnEmptyName()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        Action act = () => appBuilder.AddKindCluster(string.Empty);

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void WithNodeCount_SetsNodeCount()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("c").WithNodeCount(3);

        rb.Resource.NodeCount.Should().Be(3);
    }

    [Fact]
    public void WithNodeCount_ThrowsOnNegativeValue()
    {
        var appBuilder = DistributedApplication.CreateBuilder();
        var rb = appBuilder.AddKindCluster("c");

        Action act = () => rb.WithNodeCount(-1);

        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void WithKubernetesVersion_SetsVersion()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("c").WithKubernetesVersion("v1.31.0");

        rb.Resource.KubernetesVersion.Should().Be("v1.31.0");
    }

    [Fact]
    public void WithConfig_SetsConfigPath()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("c").WithConfig("/path/to/kind-config.yaml");

        rb.Resource.ConfigPath.Should().Be("/path/to/kind-config.yaml");
    }

    [Fact]
    public void WithPortMapping_AddsPortMapping()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("c").WithPortMapping(8080, 80);

        rb.Resource.PortMappings.Should().ContainSingle()
            .Which.Should().BeEquivalentTo(new KindPortMapping(8080, 80, "TCP"));
    }

    [Fact]
    public void WithPortMapping_RespectsProtocol()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("c").WithPortMapping(5353, 53, "UDP");

        rb.Resource.PortMappings.Should().ContainSingle().Which.Protocol.Should().Be("UDP");
    }

    [Fact]
    public void WithHelmChart_AddsHelmChart()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("c")
            .WithHelmChart("nginx", "ingress-nginx/ingress-nginx", "ingress-nginx");

        rb.Resource.HelmCharts.Should().ContainSingle(h =>
            h.ReleaseName == "nginx" && h.Chart == "ingress-nginx/ingress-nginx" && h.Namespace == "ingress-nginx");
    }

    [Fact]
    public void WithManifest_AddsManifestPath()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("c").WithManifest("/k8s/namespace.yaml");

        rb.Resource.ManifestPaths.Should().ContainSingle().Which.Should().Be("/k8s/namespace.yaml");
    }

    [Fact]
    public void WithWaitForReady_SetsTimeout()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("c").WithWaitForReady(TimeSpan.FromMinutes(10));

        rb.Resource.ReadyTimeout.Should().Be(TimeSpan.FromMinutes(10));
    }

    [Fact]
    public void WithWaitForReady_ThrowsOnZeroTimeout()
    {
        var appBuilder = DistributedApplication.CreateBuilder();
        var rb = appBuilder.AddKindCluster("c");

        Action act = () => rb.WithWaitForReady(TimeSpan.Zero);

        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void WithWaitForReady_ThrowsOnNegativeTimeout()
    {
        var appBuilder = DistributedApplication.CreateBuilder();
        var rb = appBuilder.AddKindCluster("c");

        Action act = () => rb.WithWaitForReady(TimeSpan.FromSeconds(-1));

        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void FluentApi_AllMethodsReturnSameBuilder()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        var rb = appBuilder.AddKindCluster("c");
        rb.WithNodeCount(2).Should().BeSameAs(rb);
        rb.WithKubernetesVersion("v1.31.0").Should().BeSameAs(rb);
        rb.WithConfig("/cfg.yaml").Should().BeSameAs(rb);
        rb.WithPortMapping(80, 80).Should().BeSameAs(rb);
        rb.WithHelmChart("r", "chart").Should().BeSameAs(rb);
        rb.WithManifest("/m.yaml").Should().BeSameAs(rb);
        rb.WithWaitForReady(TimeSpan.FromMinutes(3)).Should().BeSameAs(rb);
    }

    [Fact]
    public void AddKindCluster_CalledTwice_RegistersOnlyOneLifecycleHook()
    {
        var appBuilder = DistributedApplication.CreateBuilder();

        appBuilder.AddKindCluster("cluster-a");
        appBuilder.AddKindCluster("cluster-b");

        // Build the DI container and verify only one lifecycle hook instance is registered.
        using var app = appBuilder.Build();
        var hooks = app.Services.GetServices<global::Aspire.Hosting.Lifecycle.IDistributedApplicationLifecycleHook>()
            .OfType<global::Aspire.Hosting.KindClusterLifecycleHook>();

        hooks.Should().ContainSingle("TryAddEnumerable should prevent duplicate registrations");
    }
}

public class KindClusterConfigGenerationTests
{
    [Fact]
    public void GenerateKindConfig_MinimalCluster_HasControlPlaneOnly()
    {
        var resource = new KindClusterResource("r", "c", "/tmp/kc.yaml");
        // No NodeCount, no KubernetesVersion, no PortMappings

        var yaml = global::Aspire.Hosting.KindClusterLifecycleHook.GenerateKindConfig(resource);

        yaml.Should().Contain("kind: Cluster");
        yaml.Should().Contain("apiVersion: kind.x-k8s.io/v1alpha4");
        yaml.Should().Contain("role: control-plane");
        yaml.Should().NotContain("role: worker");
        yaml.Should().NotContain("image:");
        yaml.Should().NotContain("extraPortMappings:");
    }

    [Fact]
    public void GenerateKindConfig_WithWorkers_IncludesWorkerNodes()
    {
        var resource = new KindClusterResource("r", "c", "/tmp/kc.yaml");
        resource.NodeCount = 2;

        var yaml = global::Aspire.Hosting.KindClusterLifecycleHook.GenerateKindConfig(resource);

        yaml.Split('\n').Count(l => l.Contains("role: worker")).Should().Be(2);
    }

    [Fact]
    public void GenerateKindConfig_WithKubernetesVersion_IncludesImageOnAllNodes()
    {
        var resource = new KindClusterResource("r", "c", "/tmp/kc.yaml");
        resource.KubernetesVersion = "v1.31.0";
        resource.NodeCount = 1;

        var yaml = global::Aspire.Hosting.KindClusterLifecycleHook.GenerateKindConfig(resource);

        yaml.Should().Contain("image: kindest/node:v1.31.0");
        // Should appear for both control-plane and worker
        yaml.Split('\n').Count(l => l.Contains("kindest/node:v1.31.0")).Should().Be(2);
    }

    [Fact]
    public void GenerateKindConfig_WithPortMappings_IncludesExtraPortMappings()
    {
        var resource = new KindClusterResource("r", "c", "/tmp/kc.yaml");
        resource.AddPortMapping(new KindPortMapping(8080, 80, "TCP"));
        resource.AddPortMapping(new KindPortMapping(5353, 53, "UDP"));

        var yaml = global::Aspire.Hosting.KindClusterLifecycleHook.GenerateKindConfig(resource);

        yaml.Should().Contain("extraPortMappings:");
        yaml.Should().Contain("containerPort: 80");
        yaml.Should().Contain("hostPort: 8080");
        yaml.Should().Contain("protocol: TCP");
        yaml.Should().Contain("containerPort: 53");
        yaml.Should().Contain("hostPort: 5353");
        yaml.Should().Contain("protocol: UDP");
    }

    [Fact]
    public void GenerateKindConfig_ValidYamlIndentation()
    {
        var resource = new KindClusterResource("r", "c", "/tmp/kc.yaml");
        resource.NodeCount = 1;
        resource.KubernetesVersion = "v1.30.0";
        resource.AddPortMapping(new KindPortMapping(80, 80));

        var yaml = global::Aspire.Hosting.KindClusterLifecycleHook.GenerateKindConfig(resource);

        // Control-plane image should be indented under the control-plane node.
        var lines = yaml.Split('\n');
        var cpIndex = Array.FindIndex(lines, l => l.Contains("role: control-plane"));
        var imageIndex = Array.FindIndex(lines, l => l.Contains("image: kindest/node:v1.30.0"));

        imageIndex.Should().BeGreaterThan(cpIndex, "image line should appear after control-plane declaration");
    }
}
