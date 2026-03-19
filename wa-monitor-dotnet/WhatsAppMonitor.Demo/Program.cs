using Microsoft.Extensions.Logging;
using WhatsAppMonitor;

// ── Configure logging ─────────────────────────────────────────────────────────
using var loggerFactory = LoggerFactory.Create(builder =>
    builder.AddConsole().SetMinimumLevel(LogLevel.Information));

var logger = loggerFactory.CreateLogger<Program>();

// ── Configuration ─────────────────────────────────────────────────────────────
// Read from environment variables so secrets are never hard-coded.
var teamsWebhook = Environment.GetEnvironmentVariable("TEAMS_WEBHOOK_URL");
var contacts = (Environment.GetEnvironmentVariable("WATCH_CONTACTS") ?? "")
    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

// Persist QR auth so you only scan once per machine.
var userDataDir = Path.Combine(
    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
    "WhatsAppMonitor", "profile");
Directory.CreateDirectory(userDataDir);

var options = new WhatsAppMonitorOptions
{
    // Filter to specific contacts — empty = watch everyone
    ContactFilter = contacts.Length > 0
        ? contacts
        : ["Alice", "Bob"],              // ← replace with real names for your test

    TeamsWebhookUrl = teamsWebhook,
    UserDataDir = userDataDir,
    PollingInterval = TimeSpan.FromSeconds(2),
    QrScanTimeout = TimeSpan.FromMinutes(5),
    Headless = false   // must be false so you can scan the QR code
};

// ── Create monitor ────────────────────────────────────────────────────────────
await using var monitor = new WhatsAppWebMonitor(
    options,
    loggerFactory.CreateLogger<WhatsAppWebMonitor>());

// ── Subscribe to events ───────────────────────────────────────────────────────
monitor.MessageReceived += (_, e) =>
{
    var msg = e.Message;
    Console.ForegroundColor = ConsoleColor.Green;
    Console.WriteLine($"\n📨  New message from {msg.Contact}");
    Console.ResetColor();
    Console.WriteLine($"    {msg.Text}");
    Console.WriteLine($"    Received: {msg.Timestamp.ToLocalTime():f}");
    Console.WriteLine();
};

// ── Graceful shutdown ─────────────────────────────────────────────────────────
using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) =>
{
    e.Cancel = true;
    logger.LogInformation("Shutdown requested…");
    cts.Cancel();
};

Console.WriteLine("WhatsApp Web Monitor — Demo");
Console.WriteLine("================================");
if (contacts.Length > 0)
    Console.WriteLine($"Watching contacts: {string.Join(", ", contacts)}");
else
    Console.WriteLine("Watching: Alice, Bob  (set WATCH_CONTACTS env var to customise)");

if (string.IsNullOrWhiteSpace(teamsWebhook))
    Console.WriteLine("ℹ  Set TEAMS_WEBHOOK_URL to enable Teams notifications.");

Console.WriteLine("\nStarting browser… A Chromium window will open.");
Console.WriteLine("Scan the QR code to authenticate, then leave it running.");
Console.WriteLine("Press Ctrl+C to stop.\n");

// ── Start ─────────────────────────────────────────────────────────────────────
try
{
    await monitor.StartAsync(cts.Token);
    logger.LogInformation("Monitor running. Waiting for messages…");

    // Keep alive until Ctrl+C
    await Task.Delay(Timeout.Infinite, cts.Token);
}
catch (OperationCanceledException)
{
    // Normal shutdown
}
catch (Exception ex)
{
    logger.LogCritical(ex, "Fatal error");
    Environment.ExitCode = 1;
}

logger.LogInformation("Goodbye.");
