# Decision: Family Email Pipeline via Squad Email

**Date:** 2026-03-18  
**Agent:** Kes (Communications & Scheduling)  
**Issue:** #259  
**Status:** Pending activation (Tamir action required)

## Context

Issue #259 requested a way for Tamir's wife (Gabi) to send requests to the squad — print jobs, calendar events, reminders — via email. The issue was stuck for 8 days due to:
- M365 admin access blocked (can't create shared mailbox)
- Gmail signup blocked by phone verification
- Multiple Ralph automation rounds failed on CAPTCHAs

## Decision

**Reuse the existing squad email** (`td-squad-ai-team@outlook.com`) as the family request inbox, with Graph API inbox rules for automatic routing based on @keywords in the subject line.

### Why This Over Alternatives

| Option | Outcome |
|--------|---------|
| New M365 shared mailbox | ❌ Blocked by admin policies |
| New Gmail account | ❌ Blocked by phone verification CAPTCHA |
| New Outlook.com account | ❌ Blocked by PerimeterX CAPTCHA |
| **Reuse existing squad email** | ✅ Already authenticated, Graph API available |

### Routing Rules

| # | Trigger | Action |
|---|---------|--------|
| 1 | From Gabi + subject "@print" | Forward to Dresherhome@hpeprint.com |
| 2 | From Gabi + subject "@calendar" | Forward to tamirdresher@microsoft.com |
| 3 | From Gabi + subject "@reminder" | Forward to tamirdresher@microsoft.com |
| 4 | From Gabi (catch-all) | Forward to tamirdresher@microsoft.com |

## Deliverables

- [x] `scripts/squad-email/Setup-FamilyEmailRules.ps1` — Graph API rule creation script
- [x] `.squad/email-pipeline/FAMILY_EMAIL_GUIDE.md` — Updated with @keyword routing docs
- [x] Issue #259 commented with activation instructions
- [ ] Rules activated (requires Tamir to run setup script once)

## Activation

Tamir runs once:
```powershell
pwsh scripts/squad-email/Setup-FamilyEmailRules.ps1
```
This does device code auth + creates all 4 inbox rules automatically.

## Risks & Mitigations

- **Risk:** Squad email gets spam → Gabi's emails buried  
  **Mitigation:** Rules trigger on `fromContains: gabrielayael@gmail.com` specifically

- **Risk:** @keyword forgotten → email still forwarded  
  **Mitigation:** Rule 4 catches all Gabi emails as [FAMILY] general

- **Risk:** Graph API token expires  
  **Mitigation:** Setup script handles token refresh; re-run if needed
