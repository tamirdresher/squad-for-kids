---
name: squad-email-headless
description: Send emails from td-squad-ai-team@outlook.com headlessly via Microsoft Graph API. No browser needed after one-time setup.
---

# Squad Email - Headless Sending

## Overview
Send emails from `td-squad-ai-team@outlook.com` using Microsoft Graph API with OAuth2.
Works headlessly on any machine after one-time device code authentication.

## Quick Start

```powershell
# Send an email (after setup)
.\scripts\squad-email\Send-SquadEmail.ps1 `
  -To "recipient@example.com" `
  -Subject "Hello from Squad" `
  -Body "This is a test email"

# Send HTML email
.\scripts\squad-email\Send-SquadEmail.ps1 `
  -To "recipient@example.com" `
  -Subject "Report" `
  -Body "<h1>Report</h1><p>Details here</p>" `
  -BodyType html

# Multiple recipients + CC
.\scripts\squad-email\Send-SquadEmail.ps1 `
  -To "user1@example.com,user2@example.com" `
  -Subject "Team Update" `
  -Body "Status update" `
  -Cc "manager@example.com"
```

## First-Time Setup (per machine)

```powershell
# Run the setup script
.\scripts\squad-email\Setup-SquadEmailAuth.ps1

# It will display a code - go to https://microsoft.com/link and enter it
# Sign in with: td-squad-ai-team@outlook.com
# Password: (stored in Credential Manager key "squad-email-outlook")

# To also save the token as a GitHub Secret for cross-machine:
.\scripts\squad-email\Setup-SquadEmailAuth.ps1 -SaveToGitHubSecret
```

## Cross-Machine Setup

After running setup on one machine, you can copy the refresh token to other machines:

```powershell
# Option 1: GitHub Secret (set by -SaveToGitHubSecret flag)
# On the new machine, set the env var before running Send-SquadEmail.ps1:
$env:SQUAD_EMAIL_REFRESH_TOKEN = gh secret list -R tamirdresher_microsoft/tamresearch1

# Option 2: Run Setup-SquadEmailAuth.ps1 on each machine (simplest)
```

## How It Works

1. **Setup** (one-time): Device Code Flow → user visits microsoft.com/link → enters code → signs in
2. **Token storage**: Refresh token saved to Windows Credential Manager (`squad-email-graph-token`)
3. **Sending**: Script auto-refreshes access token using stored refresh token → sends via Graph API
4. **Token rotation**: Microsoft rotates refresh tokens; the script saves new ones automatically

## Architecture

```
Send-SquadEmail.ps1
  ├── Read refresh token from Credential Manager
  ├── POST /oauth2/v2.0/token (refresh → access token)
  ├── Save rotated refresh token
  └── POST /v1.0/me/sendMail (Graph API)
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
| `-SaveToSentItems` | No | `false` | Save copy to Sent Items |

## Troubleshooting

- **"No refresh token found"** → Run `Setup-SquadEmailAuth.ps1`
- **"Token refresh failed"** → Token expired (90 days inactive). Re-run setup
- **HTTP 403** → The app needs Mail.Send consent. Re-run setup and approve permissions
- **"authorization_pending"** → User hasn't completed the device code flow yet

## Notes

- Uses Microsoft's public client ID (Microsoft Graph CLI) - no app registration needed
- Refresh tokens last 90 days of inactivity; active use keeps them alive indefinitely
- No SMTP needed - bypasses the Outlook.com SMTP AUTH block entirely
- Works on Windows, macOS, Linux (PowerShell 7+)
