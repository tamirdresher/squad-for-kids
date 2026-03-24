using Aspire.Hosting.ApplicationModel;

namespace Aspire.Hosting;

/// <summary>
/// Provides extension methods for adding Kind (Kubernetes in Docker) cluster resources
/// to an <see cref="IDistributedApplicationBuilder"/>.
/// </summary>
public static class KindClusterBuilderExtensions
{
    /// <summary>
    /// Adds a Kind cluster resource to the distributed application.
    /// </summary>
    /// <param name="builder">The <see cref="IDistributedApplicationBuilder"/>.</param>
    /// <param name="name">
    /// The name of the resource. This name will be used as the Kind cluster name
    /// when referenced in a dependency.
    /// </param>
    /// <returns>A reference to the <see cref="IResourceBuilder{KindClusterResource}"/>.</returns>
    /// <example>
    /// <code lang="csharp">
    /// var builder = DistributedApplication.CreateBuilder(args);
    ///
    /// var cluster = builder.AddKindCluster("my-cluster");
    ///
    /// builder.Build().Run();
    /// </code>
    /// </example>
    public static IResourceBuilder<KindClusterResource> AddKindCluster(
        this IDistributedApplicationBuilder builder,
        [ResourceName] string name)
    {
        ArgumentNullException.ThrowIfNull(builder);
        ArgumentException.ThrowIfNullOrEmpty(name);

        var resource = new KindClusterResource(name);
        return builder.AddResource(resource);
    }

    /// <summary>
    /// Sets the number of worker nodes in the Kind cluster.
    /// </summary>
    /// <param name="builder">The resource builder.</param>
    /// <param name="nodeCount">The number of worker nodes (must be at least 1).</param>
    /// <returns>The same <see cref="IResourceBuilder{KindClusterResource}"/> for chaining.</returns>
    public static IResourceBuilder<KindClusterResource> WithNodeCount(
        this IResourceBuilder<KindClusterResource> builder,
        int nodeCount)
    {
        ArgumentNullException.ThrowIfNull(builder);
        ArgumentOutOfRangeException.ThrowIfLessThan(nodeCount, 1);

        builder.Resource.NodeCount = nodeCount;
        return builder;
    }

    /// <summary>
    /// Sets the Kubernetes version to use when creating the Kind cluster.
    /// </summary>
    /// <param name="builder">The resource builder.</param>
    /// <param name="kubernetesVersion">
    /// The Kubernetes version string (e.g. <c>"v1.31.0"</c>).
    /// Pass <see langword="null"/> to use the default version bundled with the Kind image.
    /// </param>
    /// <returns>The same <see cref="IResourceBuilder{KindClusterResource}"/> for chaining.</returns>
    public static IResourceBuilder<KindClusterResource> WithKubernetesVersion(
        this IResourceBuilder<KindClusterResource> builder,
        string? kubernetesVersion)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.Resource.KubernetesVersion = kubernetesVersion;
        return builder;
    }
}
