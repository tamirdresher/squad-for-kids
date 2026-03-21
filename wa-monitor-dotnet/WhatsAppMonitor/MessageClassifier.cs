namespace WhatsAppMonitor;

/// <summary>
/// The routing category assigned to an incoming message.
/// </summary>
public enum MessageCategory
{
    /// <summary>Sender is a priority contact (Gabi, Yonatan, Shira, Eyal) — notify immediately.</summary>
    Priority,

    /// <summary>
    /// Sender is a general contact but the message is urgent, mentions Tamir,
    /// or is a question directed at him — notify immediately with an alert indicator.
    /// </summary>
    UrgentGeneral,

    /// <summary>
    /// Ordinary message from a general contact — batch into hourly summary,
    /// do not interrupt Tamir.
    /// </summary>
    General
}

/// <summary>
/// Pure, stateless classifier that routes WhatsApp messages based on sender and content.
/// </summary>
/// <remarks>
/// Urgency detection uses simple keyword matching (no ML). Extend keyword lists as needed.
/// </remarks>
public static class MessageClassifier
{
    // ── priority contact aliases (Decision 46) ────────────────────────────────

    private static readonly string[] DefaultPriorityContactAliases =
    [
        "Gabi", "גבי", "גביק",
        "Yonatan", "יונתן",
        "Shira", "שירה",
        "Eyal", "אייל"
    ];

    // ── urgency signals ───────────────────────────────────────────────────────

    private static readonly string[] UrgencyKeywords =
    [
        // English
        "urgent", "urgently", "asap", "emergency", "immediately", "right now",
        "important", "critical", "help me", "please help", "call me", "call now",
        // Hebrew
        "דחוף", "מדחוף", "דחופי", "חשוב", "עזרה", "תעזור", "תעזרי",
        "תתקשר", "תתקשרי", "מיידי"
    ];

    private static readonly string[] TamirNames = ["תמיר", "tamir"];

    // ── public API ────────────────────────────────────────────────────────────

    /// <summary>
    /// Classifies a message using the configured priority contact list.
    /// When <paramref name="priorityContacts"/> is empty the built-in defaults are used.
    /// </summary>
    public static MessageCategory Classify(
        WhatsAppMessage message,
        IReadOnlyList<string> priorityContacts)
    {
        var contacts = priorityContacts.Count > 0
            ? priorityContacts
            : DefaultPriorityContactAliases;

        if (IsPriorityContact(message.Contact, contacts))
            return MessageCategory.Priority;

        if (IsUrgentOrRelevant(message.Text))
            return MessageCategory.UrgentGeneral;

        return MessageCategory.General;
    }

    /// <summary>Returns true when <paramref name="contact"/> matches any priority alias.</summary>
    public static bool IsPriorityContact(string contact, IReadOnlyList<string> priorityContacts)
        => priorityContacts.Any(p => contact.Contains(p, StringComparison.OrdinalIgnoreCase));

    /// <summary>Returns true when the message text is urgent OR mentions Tamir OR is a question.</summary>
    public static bool IsUrgentOrRelevant(string text)
        => IsUrgent(text) || MentionsTamir(text) || IsQuestion(text);

    /// <summary>Returns true when the text contains urgency keywords.</summary>
    public static bool IsUrgent(string text)
        => UrgencyKeywords.Any(k => text.Contains(k, StringComparison.OrdinalIgnoreCase));

    /// <summary>Returns true when the text explicitly names Tamir.</summary>
    public static bool MentionsTamir(string text)
        => TamirNames.Any(n => text.Contains(n, StringComparison.OrdinalIgnoreCase));

    /// <summary>Returns true when the text appears to be a question directed at Tamir.</summary>
    public static bool IsQuestion(string text)
        => text.TrimEnd().EndsWith('?');
}
