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

    /// <summary>
    /// Gets or sets the number of worker nodes in the cluster. Defaults to 1.
    /// </summary>
    public int NodeCount { get; set; } = 1;

    /// <summary>
    /// Gets or sets the Kubernetes version to use for the cluster.
    /// When <see langword="null"/> the default version bundled with the Kind image is used.
    /// </summary>
    public string? KubernetesVersion { get; set; }
}
