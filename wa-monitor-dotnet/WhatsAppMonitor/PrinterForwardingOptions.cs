namespace WhatsAppMonitor;

/// <summary>
/// Configuration for <see cref="PrinterForwardingService"/>.
/// </summary>
public sealed class PrinterForwardingOptions
{
    /// <summary>
    /// Email address of the HP ePrint printer that receives forwarded files.
    /// Default: dresherhome@hpeprint.com
    /// </summary>
    public string PrinterEmailAddress { get; init; } = "dresherhome@hpeprint.com";

    /// <summary>
    /// Contacts whose messages can trigger print forwarding (case-insensitive partial match).
    /// </summary>
    public IReadOnlyList<string> PriorityContacts { get; init; } =
        ["Gabi", "Yonatan Dresher", "Shira Dresher"];

    /// <summary>
    /// Keywords in message text or attachment filename that trigger forwarding.
    /// Supports both English and Hebrew printing terms.
    /// </summary>
    public IReadOnlyList<string> PrintKeywords { get; init; } =
        ["print", "הדפסה", "מדפסת", "תדפיס", "להדפיס"];

    /// <summary>SMTP relay host. Default: smtp.gmail.com.</summary>
    public string SmtpHost { get; init; } = "smtp.gmail.com";

    /// <summary>SMTP port. Default: 587 (STARTTLS).</summary>
    public int SmtpPort { get; init; } = 587;

    /// <summary>Gmail address used as the sender.</summary>
    public string SmtpUser { get; init; } = "tdsquadai@gmail.com";

    /// <summary>
    /// Windows Credential Manager target name that holds the Gmail app password.
    /// The credential blob must be stored as a UTF-16 string (the default when saved
    /// via the Credential Manager UI or <c>cmdkey /add</c>).
    /// </summary>
    public string SmtpCredentialTarget { get; init; } = "wa-monitor-gmail";

    /// <summary>
    /// Environment variable name used as a fallback when Credential Manager is
    /// unavailable (e.g., running on Linux/macOS or inside a container).
    /// </summary>
    public string SmtpPasswordEnvVar { get; init; } = "WA_MONITOR_SMTP_PASSWORD";

    /// <summary>
    /// Optional Microsoft Teams incoming webhook URL.
    /// When set, a notification card is posted to Teams after each successful print job.
    /// </summary>
    public string? TeamsWebhookUrl { get; init; }
}
