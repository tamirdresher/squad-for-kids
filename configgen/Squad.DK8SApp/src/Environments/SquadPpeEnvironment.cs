using ConfigurationGeneration.Environments.Public;

namespace Squad.DK8SApp.Environments;

/// <summary>
/// Pre-production environment (PPE) — staging cluster.
/// Derived from <see cref="StagingBase"/> which maps to staging constants and
/// the public Staging data centers.
/// </summary>
public class SquadPpeEnvironment : StagingBase
{
    /// <summary>Human-readable display name for this environment.</summary>
    public override string FullName => "Squad Pre-Production";
}
