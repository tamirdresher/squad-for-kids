using ConfigurationGeneration.Infra.K8S;
using ConfigurationGeneration.Infra.K8S.Secrets;
using ConfigurationGeneration.Interfaces;

namespace Squad.DK8SApp.Agents;

/// <summary>
/// Static helper that centralises all configuration values shared by every
/// Squad agent, regardless of workload type (Deployment or CronJob).
///
/// Both <see cref="SquadAgentServiceBase"/> (Deployment agents) and
/// <see cref="RalphService"/> (CronJob agent) delegate to this class to
/// avoid repeating common values.
/// </summary>
public static class SquadAgentDefaults
{
    /// <summary>Kubernetes namespace all Squad agents are deployed into.</summary>
    public const string Namespace = "squad";

    /// <summary>Default node pool label used for pod scheduling.</summary>
    public const string AgentNodePool = "agent";

    /// <summary>Container image name (without ACR login-server prefix).</summary>
    public const string ImageName = "squad-agents";

    /// <summary>Default image tag — override per-environment at deploy time.</summary>
    public const string ImageTag = "latest";

    /// <summary>Default compute resources for a long-lived Deployment agent.</summary>
    public static K8sComputeResources DefaultDeploymentResources =>
        new K8sComputeResources(
            cpuRequestMillicores: 500,
            cpuLimitMillicores: 2000,
            memoryRequestMiB: 512,
            memoryLimitMiB: 2048);

    /// <summary>Lightweight compute resources for the Ralph CronJob agent.</summary>
    public static K8sComputeResources RalphCronJobResources =>
        new K8sComputeResources(
            cpuRequestMillicores: 250,
            cpuLimitMillicores: 1000,
            memoryRequestMiB: 128,
            memoryLimitMiB: 512);

    /// <summary>
    /// Builds the standard set of environment variables injected into every
    /// Squad agent container.
    /// </summary>
    /// <param name="agentType">The agent role name (e.g. "picard", "ralph").</param>
    public static Func<IEnvironment, IDataCenterInfo, IEnumerable<(string Name, string Value)>>
        BuildEnvVarsCreator(string agentType) =>
        (env, dc) =>
        [
            ("SQUAD_CONFIG_PATH",  "/app/squad.config.ts"),
            ("SQUAD_AGENT_TYPE",   agentType),
            ("SQUAD_REPOSITORY",   "tamirdresher_microsoft/tamresearch1"),
            ("SQUAD_ENV",          env.Alias),
        ];

    /// <summary>
    /// Builds the Key Vault secret store that mounts the GitHub token and
    /// Copilot API key as a Kubernetes secret via the CSI driver.
    /// </summary>
    public static Func<IEnvironment, IDataCenterInfo,
        Dictionary<string, KeyVault>> BuildSecretStoreCreator() =>
        (env, dc) => new Dictionary<string, KeyVault>
        {
            ["squad-runtime-secrets"] = new KeyVault
            {
                Secrets = new[]
                {
                    new BasicSecret { SecretName = "squad-gh-token",        ObjectName = "squad-gh-token" },
                    new BasicSecret { SecretName = "squad-copilot-api-key", ObjectName = "squad-copilot-api-key" },
                }
            }
        };
}
