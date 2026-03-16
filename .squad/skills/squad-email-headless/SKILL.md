---
name: squad-email-headless
description: Send emails headlessly with auto-routing — Graph API for @microsoft.com, Gmail SMTP for external. No browser needed.
---

# Squad Email - Headless Sending (Unified)

## Overview
Send emails headlessly with automatic backend routing:
- **@microsoft.com** recipients → Graph API via `td-squad-ai-team@outlook.com`
- **External** recipients → Gmail SMTP via `tdsquadai@gmail.com`

⛔ **NEVER use Outlook COM or tamirdresher@microsoft.com to send email.**

## Quick Start

```powershell
# Internal recipient → auto-routes to Outlook Graph API
.\scripts\squad-email\Send-SquadEmail.ps1 `
  -To "colleague@microsoft.com" `
  -Subject "Hello from Squad" `
  -Body "Internal message" `
  -CallerIdentity "tamirdresher@microsoft.com"

# External recipient → auto-routes to Gmail SMTP
.\scripts\squad-email\Send-SquadEmail.ps1 `
  -To "user@example.com" `
  -Subject "Hello from Squad" `
  -Body "External message" `
  -CallerIdentity "tamir.dresher@gmail.com"

# Force a specific route
.\scripts\squad-email\Send-SquadEmail.ps1 `
  -To "anyone@anywhere.com" `
  -Subject "Report" `
  -Body "<h1>Report</h1>" -BodyType html `
  -Via gmail `
  -CallerIdentity "tamir.dresher@gmail.com"

# Multiple recipients + CC
.\scripts\squad-email\Send-SquadEmail.ps1 `
  -To "user1@example.com,user2@example.com" `
  -Subject "Team Update" `
  -Body "Status update" `
  -Cc "manager@example.com" `
  -CallerIdentity "tamirdresher@microsoft.com"
```

## First-Time Setup (per machine)

### Outlook (Graph API) — for @microsoft.com recipients
```powershell
# Run the setup script
.\scripts\squad-email\Setup-SquadEmailAuth.ps1

# It will display a code - go to https://microsoft.com/link and enter it
# Sign in with: td-squad-ai-team@outlook.com
# Password: (stored in Credential Manager key "squad-email-outlook")

# To also save the token as a GitHub Secret for cross-machine:
.\scripts\squad-email\Setup-SquadEmailAuth.ps1 -SaveToGitHubSecret
```

### Gmail SMTP — for external recipients
```powershell
# Store Gmail app password in Windows Credential Manager
cmdkey /generic:squad-email-gmail /user:tdsquadai@gmail.com /pass:<APP_PASSWORD>

# Or set environment variable (for CI/containers)
$env:SQUAD_GMAIL_APP_PASSWORD = "<APP_PASSWORD>"
```

Gmail app password lookup order:
1. Credential Manager key `squad-email-gmail`
2. Env var `SQUAD_GMAIL_APP_PASSWORD`
3. GitHub Secret check via `gh secret list -R tamirdresher/squad-personal-demo`

## Cross-Machine Setup

After running setup on one machine, you can copy tokens to other machines:

```powershell
# Outlook: GitHub Secret (set by -SaveToGitHubSecret flag)
$env:SQUAD_EMAIL_REFRESH_TOKEN = gh secret list -R tamirdresher_microsoft/tamresearch1

# Gmail: Set credential on each machine
cmdkey /generic:squad-email-gmail /user:tdsquadai@gmail.com /pass:<APP_PASSWORD>

# Or run Setup-SquadEmailAuth.ps1 on each machine (simplest for Outlook)
```

## How It Works

1. **Route determination**: Checks recipient domain(s) — all `@microsoft.com` → Outlook, otherwise → Gmail
2. **Security gate**: Validates caller identity against authorized list
3. **Send**: Uses appropriate backend (Graph API or Gmail SMTP)
4. **Log**: Records every send to `.squad/ralph-email-monitor.log`

## Architecture

```
Send-SquadEmail.ps1
  ├── Assert-AuthorizedCaller (security gate)
  ├── Get-EmailRoute (domain-based auto-routing or -Via override)
  ├── Route: outlook
  │     ├── Read refresh token from Credential Manager
  │     ├── POST /oauth2/v2.0/token (refresh → access token)
  │     ├── Save rotated refresh token
  │     └── POST /v1.0/me/sendMail (Graph API)
  └── Route: gmail
        ├── Get app password (Credential Manager → env var → GitHub Secret)
        └── SMTP send via smtp.gmail.com:587 (STARTTLS)
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-To` | Yes | - | Recipient(s), comma-separated |
| `-Subject` | Yes | - | Email subject |
| `-Body` | Yes | - | Email body content |
| `-BodyType` | No | `text` | `text` or `html` |
| `-Cc` | No | - | CC recipients |
| `-Bcc` | No | - | BCC recipients |
| `-Importance` | No | `normal` | `low`, `normal`, `high` |
| `-Via` | No | auto | Force route: `outlook` or `gmail` |
| `-CallerIdentity` | No | - | Caller email (for auth gate) |
| `-SaveToSentItems` | No | `false` | Save copy to Sent Items (Outlook only) |

## Troubleshooting

- **"SECURITY: Unauthorized caller"** → Provide `-CallerIdentity` with an authorized email
- **"No refresh token found"** → Run `Setup-SquadEmailAuth.ps1`
- **"Token refresh failed"** → Token expired (90 days inactive). Re-run setup
- **"Gmail app password not found"** → Set via `cmdkey` or env var (see setup above)
- **HTTP 403** → The app needs Mail.Send consent. Re-run setup and approve permissions

## Notes

- Uses Microsoft's public client ID (Microsoft Graph CLI) - no app registration needed
- Refresh tokens last 90 days of inactivity; active use keeps them alive indefinitely
- Gmail uses App Passwords (requires 2FA on the Google account)
- All sends logged to `.squad/ralph-email-monitor.log`
- Works on Windows, macOS, Linux (PowerShell 7+)
