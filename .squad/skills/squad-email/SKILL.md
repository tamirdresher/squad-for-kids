---
name: squad-email
description: Unified Squad email with auto-routing. Gmail (tdsquadai@gmail.com) for external, Outlook (td-squad-ai-team@outlook.com) for Microsoft internal.
triggers: ["register", "sign up", "newsletter", "subscribe", "email account", "create account", "verification email", "send email"]
confidence: high
---

# Squad Email — Unified Auto-Routing

## ⛔ CRITICAL RULE
**NEVER send email from `tamirdresher@microsoft.com` via Outlook COM or any other method.**
Only use the two Squad-owned addresses below.

## Accounts

| Route | Email | Method | When |
|-------|-------|--------|------|
| **Internal** | td-squad-ai-team@outlook.com | Graph API (OAuth2) | Recipient is `@microsoft.com` |
| **External** | tdsquadai@gmail.com | Gmail SMTP | All other recipients |

Auto-routing is handled by `Send-SquadEmail.ps1` — just call it and the script picks the right backend based on recipient domain. Use `-Via outlook` or `-Via gmail` to force a specific route.

## Quick Start

```powershell
# Auto-routes to Outlook (recipient is @microsoft.com)
.\scripts\squad-email\Send-SquadEmail.ps1 `
  -To "someone@microsoft.com" `
  -Subject "Hello" -Body "Internal message" `
  -CallerIdentity "tamirdresher@microsoft.com"

# Auto-routes to Gmail (external recipient)
.\scripts\squad-email\Send-SquadEmail.ps1 `
  -To "user@example.com" `
  -Subject "Hello" -Body "External message" `
  -CallerIdentity "tamir.dresher@gmail.com"

# Force Gmail for a Microsoft recipient
.\scripts\squad-email\Send-SquadEmail.ps1 `
  -To "someone@microsoft.com" `
  -Subject "Test" -Body "Forced Gmail" `
  -Via gmail -CallerIdentity "tamir.dresher@gmail.com"
```

## Credential Setup (per machine)

### Outlook (Graph API) — for internal
```powershell
# One-time device code auth
.\scripts\squad-email\Setup-SquadEmailAuth.ps1
# Stores refresh token in Credential Manager key: squad-email-graph-token
```

### Gmail SMTP — for external
```powershell
# Store Gmail app password in Credential Manager
cmdkey /generic:squad-email-gmail /user:tdsquadai@gmail.com /pass:<APP_PASSWORD>

# Or set environment variable
$env:SQUAD_GMAIL_APP_PASSWORD = "<APP_PASSWORD>"

# Get app password from GitHub Secret (if stored)
# gh secret list -R tamirdresher/squad-personal-demo
```

### Credential lookup order (Gmail)
1. Windows Credential Manager → key `squad-email-gmail`
2. Environment variable `SQUAD_GMAIL_APP_PASSWORD`
3. GitHub Secret check (prints setup instructions if found)

## Security

- **Authorized callers only**: `tamir.dresher@gmail.com`, `tamirdresher@microsoft.com`
- All emails logged to `.squad/ralph-email-monitor.log` with timestamp, from, to, subject
- Credentials never committed to source control
- **NEVER use Outlook COM or tamirdresher@microsoft.com**

## Monitoring

- Check `.squad/ralph-email-monitor.log` for send history
- Check Outlook inbox at https://outlook.live.com for verification emails
- Check Gmail inbox at https://mail.google.com for external replies

## Reading Emails

### Outlook inbox (via Playwright)
```
1. Navigate to https://outlook.live.com
2. Sign in with td-squad-ai-team@outlook.com
3. Use credential from Credential Manager key: squad-email-outlook
```

### Gmail inbox (via Playwright)
```
1. Navigate to https://mail.google.com
2. Sign in with tdsquadai@gmail.com
3. Use credential from Credential Manager key: squad-email-gmail
```
