using ConfigurationGeneration.Infra.K8S;

namespace Squad.DK8SApp.Agents;

/// <summary>
/// Picard — Lead Agent (Kubernetes Deployment).
///
/// Picard handles architecture decisions, ADR writing, and coordinates
/// specialist agents.  It runs as an always-on Deployment so it can
/// respond immediately to GitHub events without cold-start latency.
///
/// Resources are sized for sustained reasoning workloads (2 vCPU / 4 GiB).
/// </summary>
public class PicardService : SquadAgentServiceBase
{
    /// <inheritdoc/>
    public override string NameOverride => "picard";

    /// <inheritdoc/>
    /// <remarks>
    /// Picard is always present — min 1 replica even when idle —
    /// so it can immediately respond to architecture questions.
    /// </remarks>
    public override K8sComputeResources ComputeResourceSettings =>
        new K8sComputeResources(
            cpuRequestMillicores: 500,
            cpuLimitMillicores: 2000,
            memoryRequestMiB: 512,
            memoryLimitMiB: 4096);
}
