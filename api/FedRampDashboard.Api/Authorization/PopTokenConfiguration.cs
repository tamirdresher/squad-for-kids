namespace FedRampDashboard.Api.Authorization;

/// <summary>
/// Configuration for PoP (Proof-of-Possession) token validation per MISE V2 standards.
/// Defines MetaRP Tenant IDs for each cloud environment.
/// </summary>
public class PopTokenConfiguration
{
    public const string SectionName = "PopTokenValidation";

    /// <summary>
    /// Enable PoP token validation.
    /// When true, all incoming tokens must be PoP tokens.
    /// When false, falls back to standard Bearer tokens.
    /// </summary>
    public bool Enabled { get; set; } = true;

    /// <summary>
    /// Require PoP tokens (no fallback to Bearer).
    /// </summary>
    public bool Required { get; set; } = true;

    /// <summary>
    /// MetaRP Tenant IDs per cloud environment.
    /// Maps cloud names to their corresponding Azure AD tenant IDs.
    /// </summary>
    public Dictionary<string, string> MetaRpTenantIds { get; set; } = new()
    {
        { "dogfood", "ea8a4392-515e-481f-879e-6571ff2a8a36" },
        { "public", "33e01921-4d64-4f8c-a055-5bdaffd5e33d" },
        { "ame", "33e01921-4d64-4f8c-a055-5bdaffd5e33d" }, // Public/AME (Azure Multi-cloud for Enterprise)
        { "fairfax", "cab8a31a-1906-4287-a0d8-4eef66b95f6e" },
        { "mooncake", "a55a4d5b-9241-49b1-b4ff-befa8db00269" }
    };

    /// <summary>
    /// Current cloud environment (defaults to public).
    /// </summary>
    public string CurrentCloud { get; set; } = "public";

    /// <summary>
    /// Get the MetaRP Tenant ID for the current cloud.
    /// </summary>
    public string GetCurrentMetaRpTenantId()
    {
        var cloud = CurrentCloud.ToLowerInvariant();
        return MetaRpTenantIds.TryGetValue(cloud, out var tenantId)
            ? tenantId
            : throw new InvalidOperationException($"Cloud '{CurrentCloud}' not configured in MetaRP Tenant IDs");
    }
}
