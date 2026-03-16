# Squad Email SMTP Setup Guide

## Overview
This guide explains how to set up and use the Squad's direct SMTP email capability.

## The Account
- **Email:** `td-squad-ai-team@outlook.com`
- **Storage:** Windows Credential Manager (`squad-email-outlook`)
- **Use Case:** Automated emails from Squad (reports, notifications, registrations)

## Setup Steps

### Step 1: Retrieve or Generate App Password
The password for `td-squad-ai-team@outlook.com` must be stored in **Windows Credential Manager**.

**Options:**

#### Option A: Use Existing Password (if you have it)
```powershell
cmdkey /generic:squad-email-outlook /user:td-squad-ai-team@outlook.com /pass:YOUR_PASSWORD
```

#### Option B: Create App Password (Recommended for security)
1. Go to https://account.microsoft.com/security
2. Click **"App passwords"** (if 2FA is enabled)
3. Select: **Mail** → **Windows**
4. Microsoft generates a 16-character password
5. Copy it and use in Step 2

#### Option C: Create Password via Web
1. Go to https://outlook.live.com
2. Sign in as `td-squad-ai-team@outlook.com`
3. Settings → Account → Security → Two-step verification (if needed)
4. Create app password or use account password

### Step 2: Store Password in Credential Manager
```powershell
cmdkey /generic:squad-email-outlook /user:td-squad-ai-team@outlook.com /pass:YOUR_APP_PASSWORD
```

Verify it worked:
```powershell
cmdkey /list:squad-email-outlook
```

Should show:
```
Currently stored credentials for squad-email-outlook:
    Target: squad-email-outlook
    Type: Generic
    User: td-squad-ai-team@outlook.com
```

### Step 3: Test the Script
```powershell
# Navigate to scripts directory
cd C:\temp\tamresearch1

# Run test email
.\scripts\send-squad-email.ps1 `
    -To "tamir.dresher@gmail.com" `
    -Subject "🤖 Squad Email Test" `
    -Body "If you see this, SMTP is working!"
```

Should output:
```
✓ Email sent successfully from td-squad-ai-team@outlook.com
  To: tamir.dresher@gmail.com
  Subject: 🤖 Squad Email Test
```

## Alternative: Environment Variable (for CI/CD)
If you can't use Credential Manager (e.g., in GitHub Actions), set:
```powershell
$env:SQUAD_EMAIL_PASSWORD = 'your-password-here'
```

Then run the script — it will use the environment variable first.

## Troubleshooting

### "Failed to retrieve password"
1. Verify credential exists: `cmdkey /list:squad-email-outlook`
2. Re-store password: `cmdkey /generic:squad-email-outlook /user:td-squad-ai-team@outlook.com /pass:PASSWORD`
3. Set environment variable: `$env:SQUAD_EMAIL_PASSWORD = 'password'`

### "Connection refused" on port 587
- Check firewall rules
- Test connectivity: `Test-NetConnection -ComputerName smtp-mail.outlook.com -Port 587`
- Verify you're using port 587 (not 25 or 465)

### "Authentication failed"
- Verify password is correct
- Check username is `td-squad-ai-team@outlook.com` (exact match)
- If using Outlook account, ensure 2FA doesn't require interactive approval

### "Email sent but not received"
- Check spam/junk folder
- Verify recipient email is correct
- Check sender reputation (new accounts may be throttled)

## Usage Examples

### Basic Send
```powershell
.\scripts\send-squad-email.ps1 `
    -To "recipient@example.com" `
    -Subject "Notification" `
    -Body "Message content"
```

### With Attachments
```powershell
.\scripts\send-squad-email.ps1 `
    -To "recipient@example.com" `
    -Subject "Report" `
    -Body "See attached." `
    -Attachments @("C:\report.pdf", "C:\data.xlsx")
```

### Multiple Recipients
```powershell
$recipients = @("user1@example.com", "user2@example.com")
foreach ($to in $recipients) {
    .\scripts\send-squad-email.ps1 -To $to -Subject "Bulk Email" -Body "Message"
}
```

### From a Script
```powershell
# Load the send function
. .\scripts\send-squad-email.ps1

# Use it in your workflow
Send-MailMessage @{
    From = "td-squad-ai-team@outlook.com"
    To = "recipient@example.com"
    Subject = "Automated Report"
    Body = "Report generated at $(Get-Date)"
    SmtpServer = "smtp-mail.outlook.com"
    Port = 587
    UseSsl = $true
}
```

## Security Notes
- ✅ **Password stored securely** in Windows Credential Manager (encrypted)
- ✅ **Never commit passwords** to git
- ✅ **STARTTLS encryption** on all connections (port 587)
- ⚠️ **App passwords recommended** over account passwords
- ⚠️ **Rotate password** if account is compromised
- ⚠️ **Limit script access** to authorized users only

## Related Documentation
- Main skill: `.squad/skills/squad-email/SKILL.md`
- Account info: `.squad/identity/squad-email-account.md`
- Implementation: `scripts/send-squad-email.ps1`
