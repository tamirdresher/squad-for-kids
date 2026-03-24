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
}
