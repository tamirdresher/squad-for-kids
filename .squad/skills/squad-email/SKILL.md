---
name: squad-email
description: Squad's own email account for registrations, newsletters, service signups, and external communications. Use whenever the squad needs an email address for any purpose.
triggers: ["register", "sign up", "newsletter", "subscribe", "email account", "create account", "verification email"]
confidence: high
---

# Squad Email Account

## Account Details

| Field | Value |
|-------|-------|
| **Email** | td-squad-ai-team@outlook.com |
| **Display Name** | Squad AI Team |
| **Provider** | Outlook.com (Microsoft Account) |
| **Credentials** | Windows Credential Manager → key: `squad-email-outlook` |

## When to Use

✅ **USE THIS EMAIL FOR:**
- Signing up to services, tools, newsletters, APIs
- Receiving verification codes or confirmation emails
- Any registration that requires an email address
- Newsletter subscriptions (tech news, AI updates, etc.)
- GitHub account registrations (if needed)
- Service notifications and alerts

❌ **DO NOT USE FOR:**
- Internal Microsoft communications (use Tamir's work email)
- Anything requiring Microsoft corporate identity
- Communications that should come from Tamir personally

## How to Access

### Read emails (via Playwright)
```
1. Navigate to https://outlook.live.com
2. Sign in with td-squad-ai-team@outlook.com
3. Use credential from Windows Credential Manager
```

### Read emails (via Outlook COM — if added to Outlook desktop)
```powershell
# Add as secondary account in Outlook, then:
$outlook = New-Object -ComObject Outlook.Application
$namespace = $outlook.GetNamespace("MAPI")
# Find the squad account's inbox
$squadStore = $namespace.Stores | Where-Object { $_.DisplayName -match "squad" }
$inbox = $squadStore.GetDefaultFolder(6)  # olFolderInbox
$inbox.Items | Select-Object -First 10 | ForEach-Object { $_.Subject }
```

### Retrieve password programmatically
```powershell
# From Windows Credential Manager
cmdkey /list:squad-email-outlook
# Or use CredentialManager module
# Install-Module CredentialManager
# Get-StoredCredential -Target squad-email-outlook
```

## Security Rules

1. **NEVER** commit the password to any file in the repository
2. **NEVER** include the password in agent spawn prompts, history.md, or decisions.md
3. Always retrieve credentials from Windows Credential Manager at runtime
4. If the password needs to be rotated, update Credential Manager and notify Tamir
5. Monitor the inbox regularly for verification emails and important notifications

## Monitoring

Agents should periodically check the inbox for:
- Verification codes needed for signups
- Newsletter content relevant to research
- Service notifications or alerts
- Expiring trial notifications
