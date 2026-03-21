using ConfigurationGeneration.Infra;
using ConfigurationGeneration.Interfaces;
using Squad.DK8SApp.Agents;
using Squad.DK8SApp.Environments;

namespace Squad.DK8SApp;

/// <summary>
/// Topology definition for deploying Squad AI agents to DK8S clusters.
///
/// Squad is an AI agent framework that runs inside Kubernetes.
/// Each agent is deployed as a DK8SApplication:
///   - Picard    → Deployment  (lead, always-on, coordinates other agents)
///   - B'Elanna  → Deployment  (infrastructure expert: K8s, Helm, ArgoCD)
///   - Worf      → Deployment  (security and cloud expert)
///   - Ralph     → CronJob     (work-queue monitor, runs every 5 minutes)
///
/// Environments:
///   - DEV  (integration / CI cluster)
///   - STG  (pre-production / staging)
///   - PRD  (production)
/// </summary>
public class SquadTopology : TopologyBase
{
    /// <summary>Squad short name used in naming conventions.</summary>
    public override string SquadName => "squad";

    /// <summary>Repository name shown in Ev2 ServiceGroup names.</summary>
    public override string RepositoryName => "tamresearch1";

    /// <summary>Owner contact e-mail for IcM notifications.</summary>
    public override string OwnerGroupContactEmail => "squad-team@microsoft.com";

    // -------------------------------------------------------------------------
    // Environments
    // -------------------------------------------------------------------------

    private readonly SquadIntEnvironment _int = new();
    private readonly SquadPpeEnvironment _ppe = new();
    private readonly SquadProdEnvironment _prod = new();

    // -------------------------------------------------------------------------
    // Agent services (shared definitions reused across all DcSettings)
    // -------------------------------------------------------------------------

    /// <summary>Picard lead agent — Deployment.</summary>
    public PicardService Picard { get; } = new();

    /// <summary>B'Elanna infrastructure agent — Deployment.</summary>
    public BelannaService Belanna { get; } = new();

    /// <summary>Worf security agent — Deployment.</summary>
    public WorfService Worf { get; } = new();

    /// <summary>Ralph work-monitor agent — CronJob.</summary>
    public RalphService Ralph { get; } = new();

    // -------------------------------------------------------------------------
    // TopologyBase overrides
    // -------------------------------------------------------------------------

    public override EnvironmentBase[] GetAllEnironmentsSettings() =>
        [_int, _ppe, _prod];

    public override DcSettings CreateDcSettings(IEnvironment env, IDataCenterInfo dc)
    {
        var settings = base.CreateDcSettings(env, dc);

        // Register all Squad agent services into every DC
        settings
            .AddService(Picard)
            .AddService(Belanna)
            .AddService(Worf)
            .AddService(Ralph);

        return settings;
    }
}
