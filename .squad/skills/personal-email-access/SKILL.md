# Personal Email Access — Skill Guide

## Overview

Programmatic access to a personal Gmail account for automation tasks such as:
- Reading verification codes (e.g., from Hilan, Azure, GitHub)
- Monitoring alert emails
- Extracting OTPs for automated flows

> **Security note:** Never store credentials in source code or plain-text files.
> Use Windows Credential Manager or GitHub Secrets exclusively.

---

## Option 1: IMAP with App Passwords (Recommended for Scripts)

This is the simplest path and works well for PowerShell automation.

### Setup Steps

1. **Enable IMAP in Gmail:**
   - Go to [Gmail Settings → Forwarding and POP/IMAP](https://mail.google.com/mail/u/0/#settings/fwdandpop)
   - Under "IMAP access", select **Enable IMAP**
   - Save changes

2. **Enable 2-Step Verification** (required for App Passwords):
   - Go to [Google Account → Security](https://myaccount.google.com/security)
   - Under "Signing in to Google", enable **2-Step Verification**

3. **Generate an App Password:**
   - Go to [Google Account → App Passwords](https://myaccount.google.com/apppasswords)
   - Select app: **Mail**
   - Select device: **Windows Computer**
   - Click **Generate**
   - Copy the 16-character password (spaces are cosmetic, strip them)

4. **Store credentials securely:**
   ```powershell
   # Run the setup script (interactive — prompts for password)
   pwsh scripts/setup-email-credentials.ps1
   ```

5. **Test access:**
   ```powershell
   pwsh scripts/check-personal-email.ps1 -Last 5
   ```

### How IMAP Works

PowerShell connects to `imap.gmail.com:993` over SSL using `System.Net.Mail` /
`MailKit` (if available) or raw `System.Net.Sockets.TcpClient`. The script
authenticates with the App Password (not the real Google password).

---

## Option 2: Gmail API with OAuth2 (Best for Long-Lived Integrations)

More complex setup, but provides fine-grained scopes and token refresh.

### Setup Steps

1. **Create a Google Cloud Project:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project (e.g., "Squad Automation")

2. **Enable the Gmail API:**
   - Go to **APIs & Services → Library**
   - Search for "Gmail API" and **Enable** it

3. **Create OAuth2 Credentials:**
   - Go to **APIs & Services → Credentials**
   - Click **Create Credentials → OAuth client ID**
   - Application type: **Desktop app**
   - Download the `credentials.json` file

4. **First-Time Authorization:**
   ```powershell
   # Install the Google API client (Python example)
   pip install google-auth google-auth-oauthlib google-api-python-client

   # Run the auth flow (opens browser)
   python scripts/gmail-api-auth.py
   ```

5. **Use the token:**
   - After authorization, a `token.json` is saved locally
   - Subsequent runs use the refresh token automatically
   - Add `token.json` to `.gitignore` immediately

### Sample Python Code (Gmail API)

```python
import os
import base64
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']

def get_gmail_service():
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        with open('token.json', 'w') as token:
            token.write(creds.to_json())
    return build('gmail', 'v1', credentials=creds)

def list_recent_messages(service, max_results=5, query=''):
    results = service.users().messages().list(
        userId='me', maxResults=max_results, q=query
    ).execute()
    messages = results.get('messages', [])
    for msg in messages:
        txt = service.users().messages().get(userId='me', id=msg['id']).execute()
        headers = {h['name']: h['value'] for h in txt['payload']['headers']}
        print(f"From: {headers.get('From', '?')}")
        print(f"Subject: {headers.get('Subject', '?')}")
        print(f"Date: {headers.get('Date', '?')}")
        print("---")

if __name__ == '__main__':
    service = get_gmail_service()
    list_recent_messages(service, max_results=5)
```

---

## Option 3: Google Apps Script (Web-Based)

Good for scheduled tasks that run in Google's cloud.

1. Go to [script.google.com](https://script.google.com/)
2. Create a new project
3. Use `GmailApp.search()` and `GmailApp.getInboxThreads()`
4. Set up a time-based trigger for polling

This option doesn't require local credentials but can't easily integrate with
local Squad scripts.

---

## Credential Storage

### Windows Credential Manager (Preferred for Local)

```powershell
# Store (via setup script)
pwsh scripts/setup-email-credentials.ps1

# Credentials are stored as "GmailAutomation" in Windows Credential Manager
# Viewable via: Control Panel → Credential Manager → Windows Credentials
```

### Environment Variables (CI/CD)

```powershell
# Set for current session
$env:GMAIL_USER = "your-email@gmail.com"
$env:GMAIL_APP_PASSWORD = "xxxx xxxx xxxx xxxx"
```

### GitHub Secrets (for GitHub Actions)

```yaml
# In .github/workflows/your-workflow.yml
env:
  GMAIL_USER: ${{ secrets.GMAIL_USER }}
  GMAIL_APP_PASSWORD: ${{ secrets.GMAIL_APP_PASSWORD }}
```

---

## Security Checklist

- [ ] App Password generated (not your real Google password)
- [ ] 2-Step Verification enabled on Google Account
- [ ] Credentials stored in Credential Manager (not in files)
- [ ] `token.json` and `credentials.json` added to `.gitignore`
- [ ] No passwords committed to git history
- [ ] App Password can be revoked at any time from Google Account

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Less secure apps" error | Use App Passwords instead (requires 2FA) |
| Connection refused on port 993 | Check firewall / VPN settings |
| Authentication failed | Regenerate App Password; check for typos |
| "IMAP is disabled" | Enable IMAP in Gmail settings |
| Token expired (API) | Delete `token.json` and re-authorize |

---

## Related Scripts

| Script | Purpose |
|--------|---------|
| `scripts/setup-email-credentials.ps1` | Store Gmail credentials in Windows Credential Manager |
| `scripts/check-personal-email.ps1` | Read recent emails, search for patterns |
