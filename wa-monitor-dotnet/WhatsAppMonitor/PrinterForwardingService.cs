using System.Net;
using System.Net.Mail;
using System.Runtime.InteropServices;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Playwright;

namespace WhatsAppMonitor;

/// <summary>
/// Monitors incoming WhatsApp messages from priority contacts and automatically
/// forwards file attachments (or print-request messages) to an HP ePrint printer
/// email address when the message text contains printing-related keywords.
/// </summary>
/// <remarks>
/// <para>
/// <b>Trigger logic:</b> sender must be in <see cref="PrinterForwardingOptions.PriorityContacts"/>
/// AND the message text (or attachment file name) must contain at least one
/// <see cref="PrinterForwardingOptions.PrintKeywords"/> entry.
/// </para>
/// <para>
/// <b>Password resolution order:</b>
/// <list type="number">
///   <item>Windows Credential Manager — Generic credential whose target name is
///         <see cref="PrinterForwardingOptions.SmtpCredentialTarget"/> (<c>wa-monitor-gmail</c>).</item>
///   <item>Environment variable <see cref="PrinterForwardingOptions.SmtpPasswordEnvVar"/>
///         (<c>WA_MONITOR_SMTP_PASSWORD</c>).</item>
/// </list>
/// </para>
/// </remarks>
public sealed class PrinterForwardingService : IAsyncDisposable
{
    private readonly PrinterForwardingOptions _options;
    private readonly ILogger<PrinterForwardingService> _logger;
    private readonly TeamsNotifier? _teamsNotifier;
    private bool _disposed;

    // ── constructor ───────────────────────────────────────────────────────

    /// <param name="options">Forwarding configuration.</param>
    /// <param name="logger">Optional logger; uses NullLogger when omitted.</param>
    public PrinterForwardingService(
        PrinterForwardingOptions options,
        ILogger<PrinterForwardingService>? logger = null)
    {
        _options = options ?? throw new ArgumentNullException(nameof(options));
        _logger = logger ?? NullLogger<PrinterForwardingService>.Instance;

        if (!string.IsNullOrWhiteSpace(options.TeamsWebhookUrl))
            _teamsNotifier = new TeamsNotifier(options.TeamsWebhookUrl);
    }

    // ── public API ────────────────────────────────────────────────────────

    /// <summary>
    /// Returns <c>true</c> when the message should trigger printer forwarding.
    /// Both conditions must hold:
    /// <list type="bullet">
    ///   <item>the sender matches a <see cref="PrinterForwardingOptions.PriorityContacts"/> entry, and</item>
    ///   <item>the message text or attachment filename contains a
    ///         <see cref="PrinterForwardingOptions.PrintKeywords"/> entry.</item>
    /// </list>
    /// </summary>
    public bool ShouldForward(WhatsAppMessage message)
    {
        ArgumentNullException.ThrowIfNull(message);

        // Sender must be a priority contact (case-insensitive partial match)
        bool isPriorityContact = _options.PriorityContacts.Any(c =>
            message.Contact.Contains(c, StringComparison.OrdinalIgnoreCase));
        if (!isPriorityContact)
            return false;

        // Message text must include a print keyword
        if (ContainsPrintKeyword(message.Text))
            return true;

        // Also accept when the attachment filename contains a keyword
        if (message.AttachmentFileName is not null &&
            ContainsPrintKeyword(message.AttachmentFileName))
            return true;

        return false;
    }

    /// <summary>
    /// Handles a received message: when <see cref="ShouldForward"/> is satisfied,
    /// attempts to download the attachment (if a Playwright page is provided),
    /// emails the file to the configured printer address, and notifies Tamir via Teams.
    /// </summary>
    /// <param name="message">The incoming WhatsApp message.</param>
    /// <param name="page">
    /// Optional Playwright <see cref="IPage"/> pointing at the open WhatsApp Web tab.
    /// Required to download file attachments from the WhatsApp Web UI.
    /// When <c>null</c>, the email is sent without an attachment.
    /// </param>
    /// <param name="ct">Cancellation token.</param>
    /// <returns>
    /// <c>true</c> when forwarding was attempted; <c>false</c> when the message was skipped.
    /// </returns>
    public async Task<bool> TryForwardToPrinterAsync(
        WhatsAppMessage message,
        IPage? page = null,
        CancellationToken ct = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        if (!ShouldForward(message))
            return false;

        _logger.LogInformation(
            "Print forwarding triggered — contact: {Contact} | text: {Text} | hasAttachment: {HasAttachment}",
            message.Contact, message.Text, message.HasAttachment);

        byte[]? fileBytes = null;
        string? fileName = null;

        // Attempt attachment download when we have a live browser page
        if (message.HasAttachment && page is not null)
            (fileBytes, fileName) = await TryDownloadAttachmentAsync(message, page, ct);

        await SendToPrinterEmailAsync(message, fileBytes, fileName, ct);
        await NotifyTeamsAsync(message, fileName, ct);

        return true;
    }

    // ── attachment download ───────────────────────────────────────────────

    /// <summary>
    /// Clicks the most-recent download button visible in the open chat pane,
    /// waits for the browser download, and returns the file bytes and suggested name.
    /// Returns <c>(null, null)</c> on any failure or timeout.
    /// </summary>
    private async Task<(byte[]? Bytes, string? FileName)> TryDownloadAttachmentAsync(
        WhatsAppMessage message,
        IPage page,
        CancellationToken ct)
    {
        try
        {
            _logger.LogDebug(
                "Attempting attachment download for message from {Contact}", message.Contact);

            // Register download handler before triggering the click
            var downloadTcs =
                new TaskCompletionSource<IDownload>(TaskCreationOptions.RunContinuationsAsynchronously);
            page.Download += (_, dl) => downloadTcs.TrySetResult(dl);

            // Inject JS to locate and click the most-recent visible download button
            bool clicked = await page.EvaluateAsync<bool>(ClickDownloadButtonScript);
            if (!clicked)
            {
                _logger.LogDebug(
                    "No download button found for attachment from {Contact}", message.Contact);
                return (null, null);
            }

            using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeoutCts.CancelAfter(TimeSpan.FromSeconds(20));

            var download = await downloadTcs.Task.WaitAsync(timeoutCts.Token);
            var path = await download.PathAsync();

            if (path is null || !File.Exists(path))
            {
                _logger.LogWarning(
                    "Download path unavailable for attachment from {Contact}", message.Contact);
                return (null, null);
            }

            var bytes = await File.ReadAllBytesAsync(path, ct);
            var name = message.AttachmentFileName
                ?? download.SuggestedFilename
                ?? $"attachment_{message.Timestamp:yyyyMMddHHmmss}";

            _logger.LogInformation(
                "Downloaded {FileName} ({Bytes} bytes) from {Contact}", name, bytes.Length, message.Contact);

            // Clean up temporary download file (best-effort)
            try { File.Delete(path); } catch { /* ignore */ }

            return (bytes, name);
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning(
                "Attachment download timed out for message from {Contact}", message.Contact);
            return (null, null);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "Could not download attachment for message from {Contact}", message.Contact);
            return (null, null);
        }
    }

    /// <summary>
    /// JavaScript that clicks the last visible download/save button in the WhatsApp Web UI.
    /// Returns <c>true</c> if a button was found and clicked.
    /// </summary>
    private const string ClickDownloadButtonScript = """
        (() => {
            const selectors = [
                '[data-icon="download"]',
                '[data-icon="download-light"]',
                'button[aria-label="Download"]',
                '[aria-label*="Download"]',
                '[aria-label*="הורד"]'
            ];
            for (const sel of selectors) {
                const buttons = document.querySelectorAll(sel);
                if (buttons.length > 0) {
                    buttons[buttons.length - 1].click();
                    return true;
                }
            }
            return false;
        })()
        """;

    // ── email ─────────────────────────────────────────────────────────────

    private async Task SendToPrinterEmailAsync(
        WhatsAppMessage message,
        byte[]? fileBytes,
        string? fileName,
        CancellationToken ct)
    {
        var password = ResolveSmtpPassword();
        if (string.IsNullOrEmpty(password))
        {
            _logger.LogError(
                "SMTP password not available. Add a Generic credential named '{Target}' in " +
                "Windows Credential Manager, or set the '{Env}' environment variable.",
                _options.SmtpCredentialTarget, _options.SmtpPasswordEnvVar);
            return;
        }

        MemoryStream? attachmentStream = null;
        try
        {
#pragma warning disable SYSLIB0021  // SmtpClient is deprecated but functional for our use-case
            using var smtp = new SmtpClient(_options.SmtpHost, _options.SmtpPort)
            {
                EnableSsl = true,
                DeliveryMethod = SmtpDeliveryMethod.Network,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(_options.SmtpUser, password)
            };
#pragma warning restore SYSLIB0021

            using var mail = new MailMessage
            {
                From = new MailAddress(_options.SmtpUser, "WA Monitor"),
                Subject = $"Print: {message.Contact}",
                Body = BuildEmailBody(message)
            };
            mail.To.Add(_options.PrinterEmailAddress);

            if (fileBytes is not null && fileName is not null)
            {
                attachmentStream = new MemoryStream(fileBytes);
                mail.Attachments.Add(new Attachment(attachmentStream, fileName));
            }

            // SmtpClient.SendMailAsync does not accept a CancellationToken on all runtimes;
            // run it on a task so it is awaitable and the caller can still cancel the outer flow.
            await Task.Run(() => smtp.SendMailAsync(mail), ct);

            _logger.LogInformation(
                "Print job emailed to {Printer} for message from {Contact} (file: {File})",
                _options.PrinterEmailAddress, message.Contact, fileName ?? "(none)");
        }
        finally
        {
            attachmentStream?.Dispose();
        }
    }

    private static string BuildEmailBody(WhatsAppMessage message) =>
        $"""
        Print request received via WhatsApp.

        From   : {message.Contact}
        Message: {message.Text}
        Chat   : {message.ChatTitle ?? message.Contact}
        Received: {message.Timestamp.ToLocalTime():f}
        """;

    // ── Teams notification ────────────────────────────────────────────────

    private async Task NotifyTeamsAsync(
        WhatsAppMessage message,
        string? fileName,
        CancellationToken ct)
    {
        if (_teamsNotifier is null) return;

        var summary = $"🖨️ Print job forwarded to `{_options.PrinterEmailAddress}`";
        if (fileName is not null)
            summary += $" | 📎 {fileName}";

        var notification = new WhatsAppMessage
        {
            Contact = message.Contact,
            Text = summary + $"\n\nOriginal message: {message.Text}",
            ChatTitle = $"Print job from {message.Contact}",
            Timestamp = message.Timestamp
        };

        try
        {
            await _teamsNotifier.NotifyAsync(notification, ct);
            _logger.LogInformation(
                "Teams notified of print job from {Contact}", message.Contact);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "Teams notification failed for print job from {Contact}", message.Contact);
        }
    }

    // ── helpers ───────────────────────────────────────────────────────────

    private bool ContainsPrintKeyword(string text) =>
        _options.PrintKeywords.Any(kw =>
            text.Contains(kw, StringComparison.OrdinalIgnoreCase));

    /// <summary>
    /// Resolves the SMTP password:
    /// 1. Windows Credential Manager (target = <see cref="PrinterForwardingOptions.SmtpCredentialTarget"/>).
    /// 2. Environment variable <see cref="PrinterForwardingOptions.SmtpPasswordEnvVar"/>.
    /// Returns <c>null</c> when neither source is configured.
    /// </summary>
    internal string? ResolveSmtpPassword()
    {
        // Try Credential Manager on Windows
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            try
            {
#pragma warning disable CA1416  // RuntimeInformation.IsOSPlatform guards the call
                var cred = CredentialManager.Read(_options.SmtpCredentialTarget);
#pragma warning restore CA1416
                if (!string.IsNullOrEmpty(cred))
                    return cred;
            }
            catch (Exception ex)
            {
                _logger.LogDebug(ex,
                    "Credential Manager read failed for target '{Target}'",
                    _options.SmtpCredentialTarget);
            }
        }

        // Fallback: environment variable
        return Environment.GetEnvironmentVariable(_options.SmtpPasswordEnvVar);
    }

    // ── IAsyncDisposable ──────────────────────────────────────────────────

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        _disposed = true;

        if (_teamsNotifier is not null)
            await _teamsNotifier.DisposeAsync();
    }
}
