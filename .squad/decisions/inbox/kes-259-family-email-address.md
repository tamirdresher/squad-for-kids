# Decision: Family Email Address Pipeline (Issue #259)

**Date:** 2026-03-20  
**Author:** Kes (Communications & Scheduling)  
**Status:** ✅ IMPLEMENTED  
**Issue:** #259  

## Problem Statement

Tamir's wife (Gabi) needed a simple way to send requests to the Squad for automated handling:
- Print documents → forward to HP ePrint
- Add calendar events → forward to Tamir's calendar
- Set reminders → notify Tamir
- General messages → forward to Tamir

## Solution

**Email Address:** `td-squad-ai-team@outlook.com`

Reuse existing Squad account with Microsoft Graph API **inbox rules** that automatically route emails based on **@keyword** in subject line.

### Why This Approach?

| Option | Status | Reason |
|--------|--------|--------|
| Create new Outlook.com account | ❌ BLOCKED | PerimeterX CAPTCHA cannot be automated |
| Create new Gmail account | ❌ BLOCKED | QR-code phone verification blocks automation |
| Create M365 account | ❌ BLOCKED | Tenant admin restrictions (no license) |
| **Reuse existing account + Graph rules** | ✅ APPROVED | Graph API enables programmatic rule creation; no CAPTCHA required |

## Implementation

### Email Rules (4 rules in sequence)

| # | Condition | Action | StopRules |
|---|-----------|--------|-----------|
| 1 | From: `gabrielayael@gmail.com` AND Subject contains `@print` | Forward to `Dresherhome@hpeprint.com` | ✅ Yes |
| 2 | From: `gabrielayael@gmail.com` AND Subject contains `@calendar` | Forward to `tamirdresher@microsoft.com` with `[CALENDAR]` prefix | ✅ Yes |
| 3 | From: `gabrielayael@gmail.com` AND Subject contains `@reminder` | Forward to `tamirdresher@microsoft.com` with `[REMINDER]` prefix | ✅ Yes |
| 4 | From: `gabrielayael@gmail.com` (catch-all) | Forward to `tamirdresher@microsoft.com` with `[FAMILY]` prefix | ✅ Yes |

### Setup Script

**Location:** `scripts/squad-email/Setup-FamilyEmailRules.ps1`

**Features:**
- Interactive auth via Microsoft device code flow (no stored passwords)
- Idempotent: `-Force` flag replaces existing rules
- `-DryRun` flag previews without creating
- Stores refresh token securely in Windows Credential Manager

**Usage:**
```powershell
.\scripts\squad-email\Setup-FamilyEmailRules.ps1                # First run (interactive)
.\scripts\squad-email\Setup-FamilyEmailRules.ps1 -DryRun        # Preview
.\scripts\squad-email\Setup-FamilyEmailRules.ps1 -Force         # Replace existing rules
```

### User Documentation

**Location:** `.squad/email-pipeline/FAMILY_EMAIL_GUIDE.md`

- Simple @keyword reference table
- Examples for each keyword type
- Privacy & security notes
- Technical details for agents

## Activation Steps (for Tamir)

1. Run setup script on Windows machine with Outlook installed
2. Authenticate with `td-squad-ai-team@outlook.com` credentials
3. Rules are created via Microsoft Graph API
4. Test by sending email from `gabrielayael@gmail.com` with `@print`, `@calendar`, or `@reminder` in subject

## Integration Points

- **Ralph monitor:** Monitors `td-squad-ai-team` inbox for @print requests, creates GitHub issues
- **Kes:** Triages emails and handles calendar/reminder routing
- **Graph API:** Programmatic rule management (no web UI required)

## Key Learnings

1. **Email account creation cannot be automated** — Both Microsoft and Google block automation via CAPTCHA/phone verification. This is intentional design.
2. **Reusing accounts with API-based rules is the workaround** — Graph API `mailFolders/inbox/messageRules` endpoint allows rule creation without UI.
3. **StopProcessingRules prevents duplicate forwarding** — Setting `stopProcessingRules: true` on rules 1–3 prevents rule 4 from also firing.
4. **Device code flow + Credential Manager = secure, interactive auth** — No passwords stored; token refreshes transparently.

## Related Decisions

- **Decision 46 (WhatsApp Monitoring):** Parallel channel for family requests via WhatsApp Web (complementary to email)
- **Printing Rule:** Files from Gabi → `Dresherhome@hpeprint.com` (applies to both email and WhatsApp)

---

**Next Steps:**
- Tamir runs setup script (one-time)
- Test with sample email from Gabi
- Monitor Ralph logs for successful @print forwarding
- Extend to WhatsApp monitoring if needed (see Decision 46)
