# Email Monitoring & Triage Script

This script monitors the td-squad-ai-team@outlook.com inbox for new family emails
and creates GitHub issues for actionable requests.

## Usage

```powershell
./squad-email-monitor.ps1 -CheckInterval 300 -MaxItems 10
```

**Parameters:**
- `-CheckInterval`: Seconds between inbox checks (default: 300 = 5 min)
- `-MaxItems`: Max emails to process per cycle (default: 10)
- `-CreateGitHubIssues`: If $true, create GitHub issues for family requests

## Setup

1. Configure the squad email in Outlook (already done: td-squad-ai-team@outlook.com)
2. Set up a category in Outlook called "Family Request" (optional)
3. Run script in background: `Start-Process PowerShell -ArgumentList "-NoExit", "-File ./squad-email-monitor.ps1"`

## Integration with Ralph

Ralph (Work Monitor) should:
1. Call this script periodically
2. Check for new GitHub issues tagged with `[family-request]`
3. Display in the Squad dashboard
4. Flag urgent requests for Tamir

---

**Next Steps:**
- [ ] Test email delivery to td-squad-ai-team@outlook.com
- [ ] Confirm Outlook is monitoring the squad email account
- [ ] Set up GitHub issue creation from new emails
- [ ] Share FAMILY_EMAIL_GUIDE.md with Tamir's wife
