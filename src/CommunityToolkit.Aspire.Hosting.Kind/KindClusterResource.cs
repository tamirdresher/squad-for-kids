namespace Aspire.Hosting.ApplicationModel;

/// <summary>
/// A resource that represents a Kind (Kubernetes in Docker) cluster.
/// </summary>
/// <param name="name">The name of the resource.</param>
public sealed class KindClusterResource(string name) : Resource(name)
{
    /// <summary>
    /// Gets the name of the Kind cluster.
    /// </summary>
    public string ClusterName => Name;
}
