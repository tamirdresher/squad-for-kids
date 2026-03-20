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

    // ── Attachment metadata ────────────────────────────────────────────────

    /// <summary>
    /// <c>true</c> when the chat preview indicates a file, image, audio, or video attachment.
    /// </summary>
    public bool HasAttachment { get; init; }

    /// <summary>
    /// DOM <c>data-icon</c> value that revealed the attachment type,
    /// e.g. <c>"doc"</c>, <c>"image"</c>, <c>"audio"</c>, <c>"video"</c>, <c>"ptt"</c>.
    /// </summary>
    public string? AttachmentType { get; init; }

    /// <summary>
    /// Suggested file name extracted from the chat preview (may be null for images
    /// or voice messages that carry no explicit name).
    /// </summary>
    public string? AttachmentFileName { get; init; }

    public override string ToString() =>
        $"[{Timestamp:yyyy-MM-dd HH:mm:ss}] {Contact}: {Text}" +
        (HasAttachment ? $" [\uD83D\uDCCE {AttachmentType ?? "attachment"}]" : string.Empty);
}
