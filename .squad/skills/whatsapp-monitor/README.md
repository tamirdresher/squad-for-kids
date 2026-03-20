# WhatsApp Monitor Skill

## Overview
The WhatsApp Monitor (`wa-monitor-dotnet`) is a .NET 8 companion device that connects to WhatsApp Web via the multi-device protocol, decrypts E2E encrypted messages using Signal protocol, and watches for messages from configured family contacts.

## What It Does
- **Contact monitoring**: Watches messages from Gabi, Yonatan, Shira, and Eyal Dresher
- **File-to-printer forwarding**: When a watched contact sends a file (image/document), downloads it and emails to `dresherhome@hpeprint.com` via Gmail SMTP
- **Notifications**: Sends alerts via Teams webhook when watched contacts send messages
- **Call detection**: Logs incoming WhatsApp calls (not yet forwarded to notifications)

## Repo & Location
- **Source**: `C:\Users\tamirdresher\wa-monitor-dotnet` (GitHub: `tamirdresher/wa-monitor-dotnet`)
- **Session data**: `C:\Users\tamirdresher\.whatsapp-monitor\session-data\` (device keys, prekeys, sessions — **DO NOT DELETE**)
- **Webhook URLs**: `C:\Users\tamirdresher\.whatsapp-monitor\webhooks\*.url`
- **Config**: `wa-monitor-dotnet/src/WaMonitor/appsettings.json`

## How to Start the Monitor
```powershell
cd C:\Users\tamirdresher\wa-monitor-dotnet\src\WaMonitor
dotnet run 2>&1 | Tee-Object -FilePath C:\Users\tamirdresher\wa-monitor-live.log
```

## How to Check Monitor Status
```powershell
# Is it running?
Get-Process WaMonitor -ErrorAction SilentlyContinue | Select-Object Id, StartTime

# Check recent activity
Get-Content "C:\Users\tamirdresher\wa-monitor-live.log" -Tail 30

# Check for messages from watched contacts
Get-Content "C:\Users\tamirdresher\wa-monitor-live.log" | Select-String -Pattern "Unread messages|Notification sent|Failed to decrypt"
```

## How to Send Notifications via Webhook
**IMPORTANT: NEVER post to Teams chats directly. ALWAYS use webhooks.**

```powershell
$webhookUrl = Get-Content "C:\Users\tamirdresher\.whatsapp-monitor\webhooks\default.url"
$body = @{
    "@type" = "MessageCard"
    "@context" = "http://schema.org/extensions"
    "themeColor" = "FF0000"
    "summary" = "WhatsApp Alert"
    "sections" = @(@{
        "activityTitle" = "WhatsApp Monitor Alert"
        "facts" = @(@{ "name" = "Contact"; "value" = "Message details here" })
        "markdown" = $true
    })
} | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json"
```

## Watched Contacts
| Contact | Aliases | Phone | Priority |
|---------|---------|-------|----------|
| Gabi | גבי, גביק | TBD | Urgent |
| Yonatan Dresher | יונתן | +972-55-931-2474 | Normal |
| Shira Dresher | שירה | TBD | Normal |
| Eyal Dresher | אייל | TBD | Normal |

## Notification Routes
1. **Family Urgent** — Gabi only, urgent priority
2. **Family Print Jobs** — All 4 contacts, file attachments forwarded to printer email
3. **Family Monitoring** — Yonatan/Shira/Eyal, general messages
4. **General Monitoring** — All other chats, catch-all

## Key Technical Details
- **Contact matching**: Uses WhatsApp `notify` attribute (push name) matched against contact aliases. No phone numbers required.
- **Proto field mapping**: Image=3, Document=7, Audio=8, Video=9, Sticker=13, ExtendedText=6
- **Printer email**: Gmail SMTP via `tdsquadai@gmail.com`, password from Windows Credential Manager target `wa-monitor-gmail`
- **Signal sessions**: Restarting the monitor can break existing sessions. First message after restart may fail decryption; subsequent messages re-establish the session.
- **Session sharing**: All machines share the same WhatsApp connection via session data in `.whatsapp-monitor/session-data/`. Only ONE instance can run at a time (WhatsApp allows max 4 linked devices).

## Credential Setup (required per machine)
```powershell
# Store Gmail app password for printer forwarding
cmdkey /generic:wa-monitor-gmail /user:tdsquadai@gmail.com /pass:<APP_PASSWORD>
```

## Git Auth
The wa-monitor-dotnet repo is on personal GitHub (tamirdresher), not EMU:
```powershell
$env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"
gh auth switch --user tamirdresher
```

## Troubleshooting
- **"Unknown enc type: skmsg"** — SenderKey group messages; decryption not yet implemented
- **"Failed to decrypt"** — Session state mismatch after restart; will self-heal on next message
- **No notifications** — Check webhook URLs exist in `.whatsapp-monitor/webhooks/`
- **Monitor won't start** — Check if another instance is running: `Get-Process WaMonitor`
