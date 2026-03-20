using ConfigurationGeneration.Environments.Public;

namespace Squad.DK8SApp.Environments;

/// <summary>
/// Production environment (PROD).
/// Derived from <see cref="ProductionBase"/> which maps to PRD constants and
/// the public Production data centers.
/// </summary>
public class SquadProdEnvironment : ProductionBase
{
    /// <summary>Human-readable display name for this environment.</summary>
    public override string FullName => "Squad Production";
}
