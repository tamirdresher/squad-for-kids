using ConfigurationGeneration.Infra.K8S;
using ConfigurationGeneration.Interfaces;

namespace Squad.DK8SApp.Agents;

/// <summary>
/// Ralph — Work Monitor Agent (Kubernetes CronJob).
///
/// Ralph polls GitHub issues on a schedule and dispatches work to specialist
/// agents.  It runs as a CronJob (every 5 minutes) rather than a Deployment
/// to mirror the existing <c>ralph-watch.ps1</c> scheduled-task pattern and
/// to avoid burning compute when there are no pending issues.
///
/// Key properties:
///   - Schedule: every 5 minutes ("*/5 * * * *")
///   - ConcurrencyPolicy: Forbid (mirrors the mutex lock in ralph-watch.ps1)
///   - BackoffLimit: 2 (retries on transient failures within the same run)
///   - ActiveDeadlineSeconds: 240 (kill the job if it hangs beyond 4 min)
/// </summary>
public class RalphService : K8SCronJob
{
    // -----------------------------------------------------------------------
    // K8SServiceBase abstract overrides
    // -----------------------------------------------------------------------

    /// <inheritdoc/>
    public override string NameOverride => "ralph";

    /// <inheritdoc/>
    /// <remarks>Ralph is lightweight — it only polls GitHub and dispatches requests.</remarks>
    public override DockerImage Image =>
        new DockerImage(SquadAgentDefaults.ImageName, SquadAgentDefaults.ImageTag);

    /// <inheritdoc/>
    public override K8sComputeResources ComputeResourceSettings =>
        SquadAgentDefaults.RalphCronJobResources;

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

    // -----------------------------------------------------------------------
    // K8SCronJob-specific overrides
    // -----------------------------------------------------------------------

    /// <summary>Cron schedule — run every 5 minutes.</summary>
    public override string Schedule => "*/5 * * * *";

    /// <summary>
    /// Forbid overlapping runs to mirror the mutex behaviour in ralph-watch.ps1.
    /// </summary>
    public override CronJobConcurrencyPolicy? ConcurrencyPolicy =>
        CronJobConcurrencyPolicy.Forbid;

    /// <summary>Retain the last 3 successful job completions for debugging.</summary>
    public override uint? SuccessfulJobsHistoryLimit => 3;

    /// <summary>Retain the last failed job for triage.</summary>
    public override uint? FailedJobsHistoryLimit => 1;
}
