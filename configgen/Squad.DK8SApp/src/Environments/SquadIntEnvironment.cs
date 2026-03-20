using ConfigurationGeneration.Environments.Public;

namespace Squad.DK8SApp.Environments;

/// <summary>
/// Integration environment (INT) — CI cluster, non-production.
/// Derived from <see cref="DevelopmentBase"/> which maps to DEV constants and
/// the public Development data centers.
/// </summary>
public class SquadIntEnvironment : DevelopmentBase
{
    /// <summary>Human-readable display name for this environment.</summary>
    public override string FullName => "Squad Integration";
}
