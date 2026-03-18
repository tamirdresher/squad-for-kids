# Squad Family Email Pipeline

## Overview
Tamir's family can send requests to the **AI Squad** using a dedicated email address.
Emails are automatically routed based on **@keywords** in the subject line.

---

## Email Address

**📧 td-squad-ai-team@outlook.com**

---

## Quick Reference — @Keywords

| Keyword in Subject | What Happens | Example Subject |
|--------------------|-------------|-----------------|
| **@print** | 🖨️ Forwards email + attachments to home printer (HP ePrint) | `@print Yonatan homework page 5` |
| **@calendar** | 📅 Forwards to Tamir's calendar as [CALENDAR] event | `@calendar Dentist appointment Thursday 3pm` |
| **@reminder** | ⏰ Forwards to Tamir as [REMINDER] | `@reminder Pick up kids at 4pm` |
| *(no keyword)* | 📨 Forwards to Tamir as [FAMILY] general message | `Can you buy milk on the way home?` |

### Rules
- Keywords go in the **subject line** (anywhere is fine)
- Only emails from **gabrielayael@gmail.com** are routed
- For **@print**: attach the file(s) you want printed
- For **@calendar**: include date/time in the subject or body
- All emails are also forwarded to Tamir so nothing is lost

---

## Examples

### 🖨️ Print Something
```
To: td-squad-ai-team@outlook.com
Subject: @print Yonatan's school form
Body: Please print this form — it's due tomorrow.
Attachment: school-form.pdf
```
→ Forwarded to home printer automatically

### 📅 Calendar Event
```
To: td-squad-ai-team@outlook.com
Subject: @calendar Dentist Thursday 15:00
Body: Dr. Cohen, Ramat Gan clinic
```
→ Forwarded to Tamir's Microsoft calendar inbox

### ⏰ Reminder
```
To: td-squad-ai-team@outlook.com
Subject: @reminder Buy birthday cake for Yonatan
Body: From the bakery on Herzl street
```
→ Forwarded to Tamir as a reminder

### 📨 General Message
```
To: td-squad-ai-team@outlook.com
Subject: Can you check if the package arrived?
Body: The tracking number is 1234567890
```
→ Forwarded to Tamir as [FAMILY] message

---

## Privacy & Security

- Emails are processed by automated rules (no human reads them unless forwarded to Tamir)
- Do NOT share passwords or sensitive financial data via this email
- For urgent matters, call or text Tamir directly

---

## Technical Details (for Squad agents)

### Inbox Rules (on td-squad-ai-team@outlook.com)
| # | Condition | Action |
|---|-----------|--------|
| 1 | From: gabrielayael@gmail.com AND Subject contains "@print" | Forward to Dresherhome@hpeprint.com |
| 2 | From: gabrielayael@gmail.com AND Subject contains "@calendar" | Forward to tamirdresher@microsoft.com |
| 3 | From: gabrielayael@gmail.com AND Subject contains "@reminder" | Forward to tamirdresher@microsoft.com |
| 4 | From: gabrielayael@gmail.com (catch-all) | Forward to tamirdresher@microsoft.com |

Rules are processed in sequence order. Rule 1–3 have `stopProcessingRules = true` so they won't also trigger rule 4.

### Setup Script
```powershell
.\scripts\squad-email\Setup-FamilyEmailRules.ps1         # Create rules (interactive auth)
.\scripts\squad-email\Setup-FamilyEmailRules.ps1 -DryRun  # Preview without creating
.\scripts\squad-email\Setup-FamilyEmailRules.ps1 -Force   # Replace existing rules
```

### Monitoring
- Ralph checks the inbox periodically
- Kes triages and creates GitHub issues for actionable requests
- All forwarded emails land in Tamir's Microsoft inbox

---

**Last Updated**: March 2026  
**Maintained By**: Kes (Communications & Scheduling)
