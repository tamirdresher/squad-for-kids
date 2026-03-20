using Microsoft.Extensions.Logging;

namespace WhatsAppMonitor;

/// <summary>
/// Accumulates general (non-urgent) WhatsApp messages and flushes them as a
/// single summary Teams notification on a configurable interval.
/// </summary>
/// <remarks>
/// Thread-safe: <see cref="Add"/> and <see cref="FlushAsync"/> may be called
/// concurrently from the polling loop and the timer thread.
/// </remarks>
public sealed class GeneralMessageBatcher : IAsyncDisposable
{
    private readonly TeamsNotifier _notifier;
    private readonly ILogger _logger;
    private readonly List<WhatsAppMessage> _pending = [];
    private readonly object _lock = new();
    private readonly System.Threading.Timer _flushTimer;
    private bool _disposed;

    /// <param name="notifier">Teams notifier used to deliver the summary.</param>
    /// <param name="summaryInterval">How often the batch is flushed. Default: 1 hour.</param>
    /// <param name="logger">Optional logger.</param>
    public GeneralMessageBatcher(
        TeamsNotifier notifier,
        TimeSpan summaryInterval,
        ILogger? logger = null)
    {
        _notifier = notifier ?? throw new ArgumentNullException(nameof(notifier));
        _logger = logger ?? Microsoft.Extensions.Logging.Abstractions.NullLogger.Instance;

        _flushTimer = new System.Threading.Timer(
            OnTimerElapsed,
            state: null,
            dueTime: summaryInterval,
            period: summaryInterval);
    }

    /// <summary>Adds a message to the pending batch.</summary>
    public void Add(WhatsAppMessage message)
    {
        lock (_lock)
            _pending.Add(message);

        _logger.LogDebug(
            "Batched general message from {Contact} (pending: {Count})",
            message.Contact,
            _pending.Count);
    }

    /// <summary>Returns the current number of pending messages (for diagnostics).</summary>
    public int PendingCount
    {
        get { lock (_lock) return _pending.Count; }
    }

    // ── flush ─────────────────────────────────────────────────────────────────

    private void OnTimerElapsed(object? _)
        => _ = FlushAsync();

    /// <summary>
    /// Flushes the current batch as a summary notification.
    /// No-ops when the batch is empty.
    /// </summary>
    public async Task FlushAsync(CancellationToken ct = default)
    {
        List<WhatsAppMessage> batch;

        lock (_lock)
        {
            if (_pending.Count == 0)
                return;

            batch = new List<WhatsAppMessage>(_pending);
            _pending.Clear();
        }

        _logger.LogInformation(
            "Flushing {Count} general messages as summary notification", batch.Count);

        try
        {
            await _notifier.NotifySummaryAsync(batch, ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send summary notification");
        }
    }

    // ── IAsyncDisposable ──────────────────────────────────────────────────────

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        _disposed = true;

        await _flushTimer.DisposeAsync();

        // Final flush — send anything still in the queue
        try
        {
            await FlushAsync();
        }
        catch
        {
            // Best-effort on disposal
        }
    }
}
