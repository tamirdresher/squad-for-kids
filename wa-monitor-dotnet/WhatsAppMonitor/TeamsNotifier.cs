using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace WhatsAppMonitor;

/// <summary>
/// Sends WhatsApp message notifications to a Microsoft Teams channel via an incoming webhook.
/// Uses the legacy Office 365 Connector card format (supported by all Teams tenants).
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
    /// Posts a notification card to Teams for the given message.
    /// </summary>
    public async Task NotifyAsync(WhatsAppMessage message, CancellationToken ct = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        var card = BuildMessageCard(message);
        var json = JsonSerializer.Serialize(card);

        _logger.LogDebug("Posting Teams notification for message from {Contact}", message.Contact);

        using var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

        try
        {
            var response = await _http.PostAsync(_webhookUrl, content, ct);
            response.EnsureSuccessStatusCode();
            _logger.LogInformation("Teams notification sent for message from {Contact}", message.Contact);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send Teams notification for message from {Contact}", message.Contact);
            throw;
        }
    }

    /// <summary>
    /// Builds an Office 365 Connector MessageCard payload.
    /// </summary>
    private static object BuildMessageCard(WhatsAppMessage message)
    {
        return new
        {
            type = "@type",
            context = "@context",
            themeColor = "25D366",   // WhatsApp green
            summary = $"New WhatsApp message from {message.Contact}",
            title = $"📱 WhatsApp: {message.Contact}",
            sections = new[]
            {
                new
                {
                    activityTitle = message.Contact,
                    activitySubtitle = message.Timestamp.ToString("yyyy-MM-dd HH:mm:ss UTC"),
                    activityText = message.Text,
                    facts = new[]
                    {
                        new { name = "Chat", value = message.ChatTitle ?? message.Contact },
                        new { name = "Received", value = message.Timestamp.ToLocalTime().ToString("f") }
                    },
                    markdown = true
                }
            }
        };
    }

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
