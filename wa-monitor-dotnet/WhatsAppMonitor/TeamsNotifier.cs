using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;

namespace WhatsAppMonitor;

/// <summary>
/// Sends WhatsApp message notifications to a Microsoft Teams channel via an incoming webhook.
/// Uses the legacy Office 365 Connector MessageCard format (supported by all Teams tenants).
/// </summary>
public class TeamsNotifier : IAsyncDisposable
{
    private readonly HttpClient _http;
    private readonly string _webhookUrl;
    private readonly ILogger<TeamsNotifier> _logger;
    private bool _disposed;

    /// <param name="webhookUrl">Teams incoming webhook URL.</param>
    /// <param name="logger">Optional logger; if null a no-op logger is used.</param>
    /// <param name="httpHandler">Optional HTTP handler (useful for testing).</param>
    public TeamsNotifier(
        string webhookUrl,
        ILogger<TeamsNotifier>? logger = null,
        HttpMessageHandler? httpHandler = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(webhookUrl);
        _webhookUrl = webhookUrl;
        _http = httpHandler is not null
            ? new HttpClient(httpHandler) { Timeout = TimeSpan.FromSeconds(15) }
            : new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
        _logger = logger ?? Microsoft.Extensions.Logging.Abstractions.NullLogger<TeamsNotifier>.Instance;
    }

    /// <summary>
    /// Posts an immediate notification card to Teams for a priority contact message.
    /// </summary>
    public Task NotifyAsync(WhatsAppMessage message, CancellationToken ct = default)
        => PostCardAsync(BuildPriorityCard(message), $"message from {message.Contact}", ct);

    /// <summary>
    /// Posts an alert card to Teams for a general contact that sent something urgent or relevant.
    /// Uses a yellow theme colour to distinguish from priority-contact notifications.
    /// </summary>
    public Task NotifyAlertAsync(WhatsAppMessage message, CancellationToken ct = default)
        => PostCardAsync(BuildAlertCard(message), $"urgent alert from {message.Contact}", ct);

    /// <summary>
    /// Posts a summary card batching multiple general messages that were not individually urgent.
    /// No-ops when <paramref name="messages"/> is empty.
    /// </summary>
    public Task NotifySummaryAsync(
        IReadOnlyList<WhatsAppMessage> messages,
        CancellationToken ct = default)
    {
        if (messages.Count == 0) return Task.CompletedTask;
        return PostCardAsync(BuildSummaryCard(messages), $"{messages.Count} batched messages", ct);
    }

    // ── internal HTTP helper ──────────────────────────────────────────────────

    private async Task PostCardAsync(object card, string description, CancellationToken ct)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        var json = JsonSerializer.Serialize(card, _jsonOptions);

        _logger.LogDebug("Posting Teams notification: {Description}", description);

        using var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

        try
        {
            var response = await _http.PostAsync(_webhookUrl, content, ct);
            response.EnsureSuccessStatusCode();
            _logger.LogInformation("Teams notification sent: {Description}", description);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send Teams notification: {Description}", description);
            throw;
        }
    }

    private static readonly JsonSerializerOptions _jsonOptions = new()
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    // ── card builders ─────────────────────────────────────────────────────────

    /// <summary>Builds a green "priority contact" message card.</summary>
    private static Dictionary<string, object> BuildPriorityCard(WhatsAppMessage message)
        => BuildBaseCard(
            themeColor: "25D366",   // WhatsApp green — priority
            title: $"📱 WhatsApp: {message.Contact}",
            summary: $"New message from {message.Contact}",
            activityTitle: message.Contact,
            activitySubtitle: message.Timestamp.ToLocalTime().ToString("f"),
            activityText: message.Text,
            chatLabel: message.ChatTitle ?? message.Contact);

    /// <summary>Builds a yellow "urgent general" alert card.</summary>
    private static Dictionary<string, object> BuildAlertCard(WhatsAppMessage message)
        => BuildBaseCard(
            themeColor: "FFC107",   // amber — needs attention but not top priority
            title: $"⚠️ WhatsApp alert: {message.Contact}",
            summary: $"Urgent message from {message.Contact}",
            activityTitle: message.Contact,
            activitySubtitle: message.Timestamp.ToLocalTime().ToString("f"),
            activityText: message.Text,
            chatLabel: message.ChatTitle ?? message.Contact);

    /// <summary>Builds a blue summary card for batched non-urgent messages.</summary>
    private static Dictionary<string, object> BuildSummaryCard(IReadOnlyList<WhatsAppMessage> messages)
    {
        var lines = messages
            .Select(m => $"**{EscapeMarkdown(m.Contact)}**: {EscapeMarkdown(m.Text.Length > 80 ? m.Text[..77] + "…" : m.Text)}")
            .ToList();

        var card = new Dictionary<string, object>
        {
            ["@type"]    = "MessageCard",
            ["@context"] = "http://schema.org/extensions",
            ["themeColor"] = "0078D4",   // Teams blue — informational
            ["summary"]    = $"WhatsApp summary: {messages.Count} messages",
            ["title"]      = $"📊 WhatsApp Summary — {messages.Count} message{(messages.Count == 1 ? "" : "s")}",
            ["sections"] = new[]
            {
                new Dictionary<string, object>
                {
                    ["activityTitle"]    = $"{messages.Count} message{(messages.Count == 1 ? "" : "s")} in the last period",
                    ["activitySubtitle"] = DateTimeOffset.Now.ToString("f"),
                    ["activityText"]     = string.Join("  \n", lines),
                    ["markdown"]         = true
                }
            }
        };

        return card;
    }

    private static Dictionary<string, object> BuildBaseCard(
        string themeColor, string title, string summary,
        string activityTitle, string activitySubtitle, string activityText,
        string chatLabel)
    {
        return new Dictionary<string, object>
        {
            ["@type"]    = "MessageCard",
            ["@context"] = "http://schema.org/extensions",
            ["themeColor"] = themeColor,
            ["summary"]    = summary,
            ["title"]      = title,
            ["sections"] = new[]
            {
                new Dictionary<string, object>
                {
                    ["activityTitle"]    = activityTitle,
                    ["activitySubtitle"] = activitySubtitle,
                    ["activityText"]     = activityText,
                    ["facts"] = new[]
                    {
                        new Dictionary<string, string> { ["name"] = "Chat",     ["value"] = chatLabel },
                        new Dictionary<string, string> { ["name"] = "Received", ["value"] = activitySubtitle }
                    },
                    ["markdown"] = true
                }
            }
        };
    }

    private static string EscapeMarkdown(string text)
        => text.Replace("*", "\\*").Replace("_", "\\_").Replace("`", "\\`");

    public async ValueTask DisposeAsync()
    {
        if (!_disposed)
        {
            _disposed = true;
            _http.Dispose();
        }
        await ValueTask.CompletedTask;
    }
}
