# Squad Infrastructure Setup - Complete Guide

**Created:** 2026-03-16 by B'Elanna  
**Status:** Documentation for manual completion

---

## Overview

Three infrastructure components require setup for the Squad AI team:

1. **Gumroad Product Verification** - Publish AI Agent Architecture Cheatsheet
2. **YouTube Gmail Account** - Create dedicated email for faceless channel "TechAI Explained"
3. **Squad Email SMTP** - Configure email sending capability from td-squad-ai-team@outlook.com

---

## Task 1: Verify Gumroad Product

### Objective
Verify the AI Agent Architecture Cheatsheet product on Gumroad and publish it.

### Prerequisites
- Access to td-squad-ai-team@outlook.com
- Verification email from Gumroad (should be in inbox)

### Steps

1. **Access Outlook**
   ```
   Navigate to: https://outlook.office.com
   ```
   - You should be able to use Windows Credential Manager cached credentials
   - The system has detected: User: td-squad-ai-team@outlook.com

2. **Find Gumroad Verification Email**
   - Search inbox for "Gumroad"
   - Look for email titled "Verify your Gumroad account" or similar
   - Click the verification link in the email

3. **Publish Product on Gumroad**
   ```
   Navigate to: https://app.gumroad.com
   ```
   - Log in with verified account
   - Find "AI Agent Architecture Cheatsheet" product
   - Click "Publish" to make it live

### Notes
- Credential Manager shows the account is registered
- App password may be required if 2-factor authentication is enabled
- If stuck on verification, check spam/junk folder for Gumroad email

---

## Task 2: Create YouTube Gmail Account

### Objective
Create a Gmail account for the "TechAI Explained" YouTube channel.

### Account Details
- **Email:** tdsquadai@gmail.com (or similar available variation)
- **Name:** Tech AI
- **Birthday:** 05/15/1990
- **Gender:** Select your preference during signup

### Steps

1. **Navigate to Google Signup**
   ```
   https://accounts.google.com/signup
   ```

2. **Fill in Basic Information**
   - First Name: `Tech`
   - Last Name: `AI`
   - Click "Next"

3. **Complete Birthday & Gender**
   - Birthday Month: `5` (May)
   - Birthday Day: `15`
   - Birthday Year: `1990`
   - Gender: Select preference
   - Click "Next"

4. **Create Email Address**
   - Try: `tdsquadai@gmail.com`
   - If unavailable, try variations:
     - `tdsquaidai@gmail.com`
     - `techai.squad@gmail.com`
     - `tdsquad.ai@gmail.com`

5. **Set Password**
   - Create a strong password
   - **Save this password securely** - you'll need it for YouTube channel setup

6. **Complete Phone Verification**
   - Enter phone number for verification
   - Google will send verification code

### After Account Creation
- This email becomes the channel owner for "TechAI Explained"
- Can be used for managing YouTube subscriptions and uploads
- Consider enabling 2-factor authentication for security

---

## Task 3: Squad Email SMTP Configuration

### Objective
Configure email sending from td-squad-ai-team@outlook.com using `send-squad-email.ps1` script.

### Prerequisites
- td-squad-ai-team@outlook.com account with 2-factor authentication active
- Access to https://account.microsoft.com/security

### Step 1: Generate App Password

1. **Go to Account Security**
   ```
   https://account.microsoft.com/security
   ```

2. **Enable 2-Factor Authentication (if not already enabled)**
   - Click "Two-step verification"
   - Follow prompts to enable

3. **Create App Password**
   - Click "App passwords" (or "Application passwords")
   - Select "Mail"
   - Select "Windows"
   - Click "Create"
   - Copy the 16-character password displayed

### Step 2: Store Credential

Run the setup script in PowerShell:

```powershell
cd C:\temp\tamresearch1\scripts
.\setup-squad-credentials.ps1
```

You'll be prompted to:
1. Enter the 16-character app password
2. Password will be stored in Windows Credential Manager

**Credential Details:**
- Target: `squad-email-outlook`
- Username: `td-squad-ai-team@outlook.com`
- Password: Your 16-character app password

### Step 3: Test Email Sending

Verify the setup works:

```powershell
# Send test email to yourself
.\test-squad-email.ps1

# Send test email to specific recipient
.\test-squad-email.ps1 -To "recipient@example.com"
```

### Step 4: Use in Scripts

The `send-squad-email.ps1` script is now ready for automated sending:

```powershell
.\send-squad-email.ps1 `
    -To "user@example.com" `
    -Subject "Squad Update" `
    -Body "Message content here" `
    -Verbose
```

See `send-squad-email.ps1` for full documentation and examples.

---

## Troubleshooting

### Gumroad Task
| Issue | Solution |
|-------|----------|
| Can't log into Outlook | Try clearing browser cache or using private window |
| No Gumroad email in inbox | Check spam/junk folder; resend verification from Gumroad |
| 2FA required | Use app password instead of account password |

### Gmail Task
| Issue | Solution |
|-------|----------|
| Email address unavailable | Try variations with dots: `tds.quaidai@gmail.com` |
| Phone verification fails | Use alternative phone or callback option |
| Can't complete form | Try different browser or clear cookies |

### SMTP Task
| Issue | Solution |
|-------|----------|
| "Credential not found" error | Run `setup-squad-credentials.ps1` first |
| App password not accepted | Verify you used the 16-char app password, not regular password |
| "Authentication failed" | Regenerate app password and update credential storage |
| Script not found | Ensure you're in `scripts` directory or provide full path |

---

## Helper Scripts

Located in `C:\temp\tamresearch1\scripts\`:

1. **setup-squad-credentials.ps1**
   - Interactive setup for storing app password
   - Usage: `.\setup-squad-credentials.ps1`

2. **test-squad-email.ps1**
   - Verify email sending is working
   - Usage: `.\test-squad-email.ps1` or `.\test-squad-email.ps1 -To "test@example.com"`

3. **send-squad-email.ps1**
   - Main script for sending emails from Squad account
   - See script for full parameter documentation

---

## Security Notes

- **App Passwords:** Never share your app password
- **Credential Manager:** Only accessible by your Windows user account
- **Environment Variables:** Can use `$env:SQUAD_EMAIL_PASSWORD` for CI/CD
- **2FA:** Keep 2-factor authentication enabled on Microsoft account

---

## Contact

If you encounter issues:
1. Check this guide's troubleshooting section
2. Review script error messages (run with `-Verbose` for details)
3. Verify credential exists: `cmdkey /list:squad-email-outlook`
4. Check app password is correct at https://account.microsoft.com/security

---

**Last Updated:** 2026-03-16  
**Created by:** B'Elanna, Infrastructure Engineer
