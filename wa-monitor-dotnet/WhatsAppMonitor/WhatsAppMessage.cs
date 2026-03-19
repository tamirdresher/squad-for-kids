namespace WhatsAppMonitor;

/// <summary>
/// Represents a WhatsApp message received from a contact.
/// </summary>
public sealed record WhatsAppMessage
{
    /// <summary>Display name of the sender (as shown in WhatsApp Web).</summary>
    public required string Contact { get; init; }

    /// <summary>Plain-text content of the message.</summary>
    public required string Text { get; init; }

    /// <summary>UTC timestamp when the message was detected.</summary>
    public DateTimeOffset Timestamp { get; init; } = DateTimeOffset.UtcNow;

    /// <summary>Optional: conversation/chat title (for group chats).</summary>
    public string? ChatTitle { get; init; }

    public override string ToString() =>
        $"[{Timestamp:yyyy-MM-dd HH:mm:ss}] {Contact}: {Text}";
}
