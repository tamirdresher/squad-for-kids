namespace FedRampDashboard.Api.Authorization;

/// <summary>
/// RBAC role definitions for the FedRAMP Security Dashboard.
/// Maps to Azure AD security groups.
/// </summary>
public static class RbacRoles
{
    /// <summary>
    /// Security Admin - Full access to all dashboard features, RBAC management.
    /// Azure AD Group: FedRAMP-SecurityAdmin
    /// </summary>
    public const string SecurityAdmin = "FedRAMP.SecurityAdmin";

    /// <summary>
    /// Security Engineer - Read/write access to validation data and dashboards.
    /// Azure AD Group: FedRAMP-SecurityEngineer
    /// </summary>
    public const string SecurityEngineer = "FedRAMP.SecurityEngineer";

    /// <summary>
    /// SRE - Operational dashboards, alert configuration, read-only control data.
    /// Azure AD Group: FedRAMP-SRE
    /// </summary>
    public const string SRE = "FedRAMP.SRE";

    /// <summary>
    /// Ops Viewer - Read-only access to dashboards and compliance status.
    /// Azure AD Group: FedRAMP-OpsViewer
    /// </summary>
    public const string OpsViewer = "FedRAMP.OpsViewer";

    /// <summary>
    /// Auditor - Compliance report export only, no real-time dashboard access.
    /// Azure AD Group: FedRAMP-Auditor
    /// </summary>
    public const string Auditor = "FedRAMP.Auditor";
}

/// <summary>
/// Permission matrix for RBAC roles.
/// </summary>
public static class RbacPermissions
{
    public static class Dashboard
    {
        public const string Read = "Dashboard.Read";
    }

    public static class Controls
    {
        public const string Read = "Controls.Read";
    }

    public static class Analytics
    {
        public const string Read = "Analytics.Read";
    }

    public static class Reports
    {
        public const string Export = "Reports.Export";
    }

    public static class Admin
    {
        public const string Full = "Admin.Full";
    }

    /// <summary>
    /// Gets all permissions for a given role.
    /// </summary>
    public static string[] GetPermissionsForRole(string role) => role switch
    {
        RbacRoles.SecurityAdmin => new[]
        {
            Dashboard.Read,
            Controls.Read,
            Analytics.Read,
            Reports.Export,
            Admin.Full
        },
        RbacRoles.SecurityEngineer => new[]
        {
            Dashboard.Read,
            Controls.Read,
            Analytics.Read,
            Reports.Export
        },
        RbacRoles.SRE => new[]
        {
            Dashboard.Read,
            Controls.Read,
            Analytics.Read
        },
        RbacRoles.OpsViewer => new[]
        {
            Dashboard.Read
        },
        RbacRoles.Auditor => new[]
        {
            Reports.Export
        },
        _ => Array.Empty<string>()
    };
}
