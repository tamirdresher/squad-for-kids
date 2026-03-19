# WhatsApp Web Monitor (.NET)

A clean, secure .NET 8 library for monitoring WhatsApp Web messages from specific contacts and sending notifications to Microsoft Teams.

## How It Works

| Component | Technology | Purpose |
|-----------|------------|---------|
| Browser automation | **Microsoft.Playwright** | Controls a real Chromium/Edge browser |
| WhatsApp interface | **WhatsApp Web** (web.whatsapp.com) | Standard web UI — no protocol hacking |
| Message detection | **DOM polling** (JS injection) | Reads unread badges from the chat list |
| Notifications | **Teams Incoming Webhook** | Posts a formatted card to a Teams channel |

> **Security note:** No protocol reverse-engineering, no unofficial APIs, no third-party packages with unknown security posture. Everything happens through a standard browser window the user controls.

---

## Quick Start

### Prerequisites

- .NET 8 SDK
- A Microsoft Teams channel with an **Incoming Webhook** connector (optional — only needed for notifications)

### 1. Install Playwright browsers

```bash
cd wa-monitor-dotnet
dotnet build
pwsh WhatsAppMonitor.Demo/bin/Debug/net8.0/playwright.ps1 install chromium
```

### 2. Run the demo

```bash
# Optional: set your Teams webhook and contacts to watch
$env:TEAMS_WEBHOOK_URL = "https://outlook.office.com/webhook/..."
$env:WATCH_CONTACTS    = "Alice,Bob"       # comma-separated, case-insensitive partial match

cd WhatsAppMonitor.Demo
dotnet run
```

A Chromium browser window opens. **Scan the QR code** with your phone's WhatsApp. The monitor starts polling every 2 seconds. When a message arrives from a watched contact, you'll see it in the console and (if configured) in Teams.

### 3. Persist authentication

Set `UserDataDir` in `WhatsAppMonitorOptions` (or the demo picks `%LOCALAPPDATA%\WhatsAppMonitor\profile` automatically). This saves the browser session so you only scan QR once per machine.

---

## Library Usage

```csharp
using WhatsAppMonitor;

await using var monitor = new WhatsAppWebMonitor(new WhatsAppMonitorOptions
{
    ContactFilter    = ["Alice", "Support Team"],
    TeamsWebhookUrl  = Environment.GetEnvironmentVariable("TEAMS_WEBHOOK_URL"),
    UserDataDir      = @"C:\WhatsAppProfile",   // persist QR auth
    PollingInterval  = TimeSpan.FromSeconds(2),
    Headless         = false                     // must be false for QR scan
});

monitor.MessageReceived += (_, e) =>
{
    Console.WriteLine($"📨 {e.Message.Contact}: {e.Message.Text}");
};

await monitor.StartAsync();          // opens browser, waits for QR
await Task.Delay(Timeout.Infinite);  // keep running
```

---

## Architecture

```
WhatsAppWebMonitor
├─ Launches Chromium via Microsoft.Playwright
├─ Navigates to https://web.whatsapp.com
├─ Waits for #pane-side (auth confirmed)
├─ Polls every N seconds:
│   └─ Injects JS → reads unread chat rows from DOM
│       └─ Filters by ContactFilter list
│           └─ Raises MessageReceived event
│               └─ TeamsNotifier.NotifyAsync() → HTTP POST to webhook
└─ Graceful shutdown via CancellationToken + IAsyncDisposable
```

---

## Configuration Reference

| Option | Default | Description |
|--------|---------|-------------|
| `ContactFilter` | `[]` (all) | Display names to watch. Empty = watch everyone |
| `QrScanTimeout` | 5 min | How long to wait for QR scan before failing |
| `PollingInterval` | 2 s | How often to check for new messages |
| `Headless` | `false` | Must be false so user can scan QR |
| `UserDataDir` | `null` | Persist browser session between runs |
| `TeamsWebhookUrl` | `null` | Teams incoming webhook URL |

---

## Running Tests

```bash
cd wa-monitor-dotnet
dotnet test
```

Tests cover:
- `WhatsAppMessage` model (construction, equality, formatting)
- `WhatsAppMonitorOptions` defaults
- `TeamsNotifier` HTTP payload validation (using a mock handler)
- Contact filter case-insensitive matching logic

---

## Security Considerations

- **No protocol hacking.** We use a real browser; WhatsApp sees a normal web session.
- **QR auth is local.** The browser profile stays on your machine; credentials are never transmitted to this library.
- **Webhook URL is a secret.** Pass it via environment variable, not source code.
- **Minimal permissions.** The library reads DOM text; it does not send messages or access contacts.

---

## Limitations

- WhatsApp Web DOM selectors may change when WhatsApp deploys updates. If monitoring stops working, update the selectors in `WhatsAppWebMonitor.cs` (`ExtractUnreadMessagesScript`).
- Only surfaces the **preview text** from the chat list (not full message history). This is intentional — reading the full history would require clicking into each chat, causing WhatsApp to mark messages as read.
- Group messages are reported with the group name as `Contact` and `ChatTitle`.

---

## License

MIT
