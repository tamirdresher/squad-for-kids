using ConfigurationGeneration.Infra.K8S;
using ConfigurationGeneration.Interfaces;

namespace Squad.DK8SApp.Agents;

/// <summary>
/// Abstract base for all Squad Deployment agent K8S services.
///
/// Extends <see cref="K8SService"/> (→ Kubernetes Deployment) and delegates
/// shared configuration to <see cref="SquadAgentDefaults"/>.
///
/// Used by: Picard, B'Elanna, Worf (long-lived, always-on agents).
/// Ralph uses <see cref="K8SCronJob"/> instead (see <c>RalphService.cs</c>).
/// </summary>
public abstract class SquadAgentServiceBase : K8SService
{
    // -----------------------------------------------------------------------
    // K8SServiceBase abstract / virtual overrides
    // -----------------------------------------------------------------------

    /// <inheritdoc/>
    public override DockerImage Image =>
        new DockerImage(SquadAgentDefaults.ImageName, SquadAgentDefaults.ImageTag);

    /// <summary>
    /// Agent-specific name that becomes the Kubernetes Deployment name and
    /// Helm release name suffix (e.g. "picard", "belanna", "worf").
    /// </summary>
    public abstract override string NameOverride { get; }

    /// <inheritdoc/>
    public override K8sComputeResources ComputeResourceSettings =>
        SquadAgentDefaults.DefaultDeploymentResources;

    /// <inheritdoc/>
    public override bool UseCSIDriver => true;

    /// <inheritdoc/>
    public override string NodeSelectorResource => SquadAgentDefaults.AgentNodePool;

    /// <inheritdoc/>
    public override Func<IEnvironment, IDataCenterInfo, IEnumerable<(string Name, string Value)>>
        EnvironmentVariablesCreator =>
        SquadAgentDefaults.BuildEnvVarsCreator(NameOverride);

    /// <inheritdoc/>
    public override Func<IEnvironment, IDataCenterInfo,
        Dictionary<string, KeyVault>> SecretStoreCreator =>
        SquadAgentDefaults.BuildSecretStoreCreator();
}
