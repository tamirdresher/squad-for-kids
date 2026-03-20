namespace Squad.DK8SApp.Agents;

/// <summary>
/// B'Elanna Torres — Infrastructure Expert (Kubernetes Deployment).
///
/// B'Elanna handles K8s, Helm, ArgoCD, and cloud-native infrastructure work.
/// Runs as a Deployment for low-latency response to infra issues.
/// </summary>
public class BelannaService : SquadAgentServiceBase
{
    /// <inheritdoc/>
    public override string NameOverride => "belanna";
}
