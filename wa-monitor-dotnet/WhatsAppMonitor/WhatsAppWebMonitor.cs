using Microsoft.Extensions.Logging;
using Microsoft.Playwright;

namespace WhatsAppMonitor;

/// <summary>
/// Configuration options for <see cref="WhatsAppWebMonitor"/>.
/// </summary>
public sealed class WhatsAppMonitorOptions
{
    /// <summary>
    /// Contact display names to monitor (case-insensitive partial match).
    /// If empty, all messages are surfaced.
    /// </summary>
    public IReadOnlyList<string> ContactFilter { get; init; } = [];

    /// <summary>How long to wait for QR scan before giving up. Default: 5 minutes.</summary>
    public TimeSpan QrScanTimeout { get; init; } = TimeSpan.FromMinutes(5);

    /// <summary>Polling interval for checking new messages. Default: 2 seconds.</summary>
    public TimeSpan PollingInterval { get; init; } = TimeSpan.FromSeconds(2);

    /// <summary>
    /// Run browser in headless mode. Set to false (default) so user can scan QR code.
    /// </summary>
    public bool Headless { get; init; } = false;

    /// <summary>Optional path to a persistent browser user data directory (retains QR auth between runs).</summary>
    public string? UserDataDir { get; init; }

    /// <summary>Teams webhook URL. When set, notifications are posted automatically.</summary>
    public string? TeamsWebhookUrl { get; init; }
}

/// <summary>
/// Event args for a received WhatsApp message.
/// </summary>
public sealed class MessageReceivedEventArgs(WhatsAppMessage message) : EventArgs
{
    public WhatsAppMessage Message { get; } = message;
}

/// <summary>
/// Monitors WhatsApp Web for incoming messages from specific contacts using Playwright browser automation.
/// </summary>
/// <remarks>
/// No protocol reverse-engineering is performed. The library controls a standard Chromium browser
/// and reads the WhatsApp Web DOM — the same interface a human user would see.
/// </remarks>
public sealed class WhatsAppWebMonitor : IAsyncDisposable
{
    // ── public API ────────────────────────────────────────────────────────────

    /// <summary>Raised on the thread-pool whenever a matching message is detected.</summary>
    public event EventHandler<MessageReceivedEventArgs>? MessageReceived;

    // ── private state ────────────────────────────────────────────────────────

    private readonly WhatsAppMonitorOptions _options;
    private readonly ILogger<WhatsAppWebMonitor> _logger;
    private readonly TeamsNotifier? _notifier;

    private IPlaywright? _playwright;
    private IBrowser? _browser;
    private IBrowserContext? _context;
    private IPage? _page;

    private CancellationTokenSource? _cts;
    private Task? _pollTask;
    private bool _disposed;

    // Track messages we have already surfaced to avoid duplicates.
    // Key = "{contact}|{text}" (truncated for memory efficiency).
    private readonly HashSet<string> _seenKeys = new(StringComparer.Ordinal);

    // ── WhatsApp Web selectors (as of 2024 – may need updating) ──────────────

    // The QR code canvas is present on the login screen
    private const string QrSelector = "canvas[aria-label='Scan me!'], [data-ref]";
    // After login, the chat list pane is visible
    private const string ChatListSelector = "#pane-side";
    // Unread badge on a chat row
    private const string UnreadChatSelector = "span[data-icon='unread-count'], span[aria-label*='unread']";

    // ── constructor ───────────────────────────────────────────────────────────

    /// <param name="options">Monitor configuration.</param>
    /// <param name="logger">Optional logger.</param>
    public WhatsAppWebMonitor(
        WhatsAppMonitorOptions options,
        ILogger<WhatsAppWebMonitor>? logger = null)
    {
        _options = options ?? throw new ArgumentNullException(nameof(options));
        _logger = logger ?? Microsoft.Extensions.Logging.Abstractions.NullLogger<WhatsAppWebMonitor>.Instance;

        if (!string.IsNullOrWhiteSpace(options.TeamsWebhookUrl))
            _notifier = new TeamsNotifier(options.TeamsWebhookUrl, null);
    }

    // ── public methods ────────────────────────────────────────────────────────

    /// <summary>
    /// Launches the browser, navigates to WhatsApp Web, waits for authentication,
    /// and starts monitoring for new messages.
    /// </summary>
    public async Task StartAsync(CancellationToken ct = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        _logger.LogInformation("Starting WhatsApp Web Monitor…");

        _playwright = await Playwright.CreateAsync();

        // Launch persistent context so the user only needs to scan QR once
        // if UserDataDir is specified.
        if (!string.IsNullOrWhiteSpace(_options.UserDataDir))
        {
            _context = await _playwright.Chromium.LaunchPersistentContextAsync(
                _options.UserDataDir,
                new BrowserTypeLaunchPersistentContextOptions
                {
                    Headless = _options.Headless,
                    Channel = "chrome", // prefer installed Chrome if available
                    Args = ["--no-sandbox", "--disable-setuid-sandbox"]
                });
            _page = _context.Pages.FirstOrDefault() ?? await _context.NewPageAsync();
        }
        else
        {
            _browser = await _playwright.Chromium.LaunchAsync(new BrowserTypeLaunchOptions
            {
                Headless = _options.Headless,
                Channel = "chrome",
                Args = ["--no-sandbox", "--disable-setuid-sandbox"]
            });
            _context = await _browser.NewContextAsync();
            _page = await _context.NewPageAsync();
        }

        await _page.GotoAsync("https://web.whatsapp.com", new PageGotoOptions
        {
            WaitUntil = WaitUntilState.DOMContentLoaded,
            Timeout = 30_000
        });

        await WaitForAuthenticationAsync(ct);

        _logger.LogInformation("Authentication confirmed. Starting message polling.");

        _cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        _pollTask = PollForMessagesAsync(_cts.Token);
    }

    /// <summary>
    /// Stops monitoring and closes the browser.
    /// </summary>
    public async Task StopAsync()
    {
        if (_cts is not null)
        {
            await _cts.CancelAsync();
            try { if (_pollTask is not null) await _pollTask; }
            catch (OperationCanceledException) { /* expected */ }
        }
        _logger.LogInformation("WhatsApp Web Monitor stopped.");
    }

    // ── authentication ────────────────────────────────────────────────────────

    private async Task WaitForAuthenticationAsync(CancellationToken ct)
    {
        _logger.LogInformation("Waiting for WhatsApp Web QR scan (timeout: {Timeout})…", _options.QrScanTimeout);

        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeoutCts.CancelAfter(_options.QrScanTimeout);

        // Wait until the chat list appears (meaning user has authenticated)
        try
        {
            await _page!.WaitForSelectorAsync(ChatListSelector,
                new PageWaitForSelectorOptions
                {
                    Timeout = (float)_options.QrScanTimeout.TotalMilliseconds,
                    State = WaitForSelectorState.Visible
                });
        }
        catch (TimeoutException)
        {
            throw new TimeoutException(
                $"WhatsApp Web authentication timed out after {_options.QrScanTimeout}. " +
                "Ensure the browser opened and the QR code was scanned.");
        }

        _logger.LogInformation("WhatsApp Web authenticated successfully.");
    }

    // ── polling ────────────────────────────────────────────────────────────────

    private async Task PollForMessagesAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                await CheckForNewMessagesAsync(ct);
                await Task.Delay(_options.PollingInterval, ct);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error during message poll; will retry.");
                await Task.Delay(TimeSpan.FromSeconds(5), ct);
            }
        }
    }

    /// <summary>
    /// Reads unread chats from the DOM and raises events for matching contacts.
    /// </summary>
    private async Task CheckForNewMessagesAsync(CancellationToken ct)
    {
        if (_page is null) return;

        // Use JavaScript to extract unread chat summaries from the DOM.
        // This avoids fragile CSS selectors and works across WhatsApp Web versions.
        var messages = await _page.EvaluateAsync<WhatsAppMessageDto[]>(ExtractUnreadMessagesScript);

        if (messages is null || messages.Length == 0) return;

        foreach (var dto in messages)
        {
            if (string.IsNullOrWhiteSpace(dto.Contact) || string.IsNullOrWhiteSpace(dto.Text))
                continue;

            // Apply contact filter
            if (_options.ContactFilter.Count > 0)
            {
                bool matched = _options.ContactFilter.Any(f =>
                    dto.Contact.Contains(f, StringComparison.OrdinalIgnoreCase));
                if (!matched) continue;
            }

            var key = $"{dto.Contact}|{dto.Text[..Math.Min(100, dto.Text.Length)]}";
            if (_seenKeys.Contains(key)) continue;

            _seenKeys.Add(key);
            // Trim cache to avoid unbounded growth
            if (_seenKeys.Count > 2000)
                _seenKeys.Clear();

            var msg = new WhatsAppMessage
            {
                Contact = dto.Contact,
                Text = dto.Text,
                ChatTitle = dto.ChatTitle
            };

            _logger.LogInformation("New message from {Contact}: {Text}", msg.Contact, msg.Text);

            RaiseMessageReceived(msg);

            if (_notifier is not null)
            {
                try { await _notifier.NotifyAsync(msg, ct); }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Teams notification failed for message from {Contact}", msg.Contact);
                }
            }
        }
    }

    private void RaiseMessageReceived(WhatsAppMessage message)
    {
        var handler = MessageReceived;
        if (handler is null) return;

        // Fire on thread-pool so subscribers can't block the poll loop
        _ = Task.Run(() =>
        {
            try { handler(this, new MessageReceivedEventArgs(message)); }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception in MessageReceived handler");
            }
        });
    }

    // ── JS extraction script ──────────────────────────────────────────────────

    /// <summary>
    /// JavaScript injected into WhatsApp Web to extract unread message data from the DOM.
    /// Returns an array of { contact, text, chatTitle } objects.
    /// 
    /// Approach: reads aria-labels and visible text nodes — no API calls, no undocumented endpoints.
    /// </summary>
    private const string ExtractUnreadMessagesScript = """
        (() => {
            const results = [];
            // Chat rows in the left pane
            const chatRows = document.querySelectorAll('#pane-side [role="listitem"]');
            for (const row of chatRows) {
                // Unread indicator
                const unreadBadge = row.querySelector('span[data-icon="unread-count"], [aria-label*="unread"]');
                if (!unreadBadge) continue;

                // Contact/group name — first strong or title span
                const nameEl = row.querySelector('span[title], ._ao3e, span[dir="auto"] span');
                const contact = nameEl?.getAttribute('title') || nameEl?.textContent?.trim() || '';

                // Last message preview text
                const msgEl = row.querySelector('span[class*="last-msg"], ._ao3f, span[dir="ltr"]');
                const text = msgEl?.textContent?.trim() || '';

                if (contact && text) {
                    results.push({ contact, text, chatTitle: contact });
                }
            }
            return results;
        })()
        """;

    // ── DTO for JS deserialization ─────────────────────────────────────────────

    private sealed class WhatsAppMessageDto
    {
        public string Contact { get; set; } = string.Empty;
        public string Text { get; set; } = string.Empty;
        public string? ChatTitle { get; set; }
    }

    // ── IAsyncDisposable ──────────────────────────────────────────────────────

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        _disposed = true;

        await StopAsync();

        if (_notifier is not null)
            await _notifier.DisposeAsync();

        if (_page is not null)
            await _page.CloseAsync();

        if (_context is not null)
            await _context.CloseAsync();

        if (_browser is not null)
            await _browser.CloseAsync();

        _playwright?.Dispose();
        _cts?.Dispose();
    }
}
