namespace Squad.DK8SApp.Agents;

/// <summary>
/// Worf — Security and Cloud Expert (Kubernetes Deployment).
///
/// Worf handles security reviews, Azure RBAC, NSG rules, and SFI compliance.
/// Runs as a Deployment so it is immediately available for security escalations.
/// </summary>
public class WorfService : SquadAgentServiceBase
{
    /// <inheritdoc/>
    public override string NameOverride => "worf";
}
