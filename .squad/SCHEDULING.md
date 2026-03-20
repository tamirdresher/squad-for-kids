# Squad Scheduling Guide

> Reference for all scheduled tasks. Canonical config is `.squad/schedule.json`.  
> All times listed in Israel time (IST = UTC+2, IDT = UTC+3 in summer).

---

## Scheduled Tasks

| ID | Name | Schedule (Israel) | Script / Task | Owner |
|----|------|--------------------|---------------|-------|
| `daily-squad-report` | Daily Squad Report | **5:00 AM daily** | `scripts/daily-squad-report.ps1` | picard |
| `daily-rp-briefing` | BasePlatformRP Briefing | 9:00 AM Mon–Fri | `.squad/scripts/daily-rp-briefing.ps1` | picard |
| `daily-adr-check` | ADR Channel Monitor | 10:00 AM Mon–Fri UTC | Copilot agent | picard |
| `ralph-heartbeat` | Ralph Heartbeat | Every 5 min | `.github/workflows/squad-heartbeat.yml` | ralph |
| `tech-news-scan` | Tech News Scanner | 10:00 AM Mon–Fri | `scripts/tech-news-scanner.js` | neelix |
| `birthday-check` | Team Birthday Check | 11:00 AM Mon–Fri | `scripts/birthday-checker.ps1` | kes |
| `weekly-upstream-sync` | Upstream Sync | Mon 5:00 AM UTC | Copilot agent | scribe |
| `weekly-squad-retro` | Weekly Retrospective | Fri 4:00 PM | Picard agent | picard |
| `whatsapp-check` | WhatsApp Family Check | Every 2h weekdays | Kes agent | kes |

---

## Daily Squad Report — 5 AM Israel

**Script:** `scripts/daily-squad-report.ps1`  
**Issue:** [#1056](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1056)

### What it covers (previous 24 hours)

- Issues created, closed, commented across all Squad repos
- Pull Requests created, merged, closed (with file change counts)
- Commits across all repos
- Ralph heartbeat — rounds, failures, duration, status per repo
- Decisions — new entries in `.squad/decisions/`
- Skills — created or updated
- Research — new reports generated
- Communications — Teams messages, email monitor activity
- Cross-machine — tasks and responses
- Blog — commits to tamirdresher.github.io

### Repos scanned

`tamresearch1`, `tamresearch1-research`, `jellybolt-games`, `devtools-pro`,
`techai-explained`, `saas-finder-hub`, `squad-tetris`, `kids-squad-setup`,
`squad-skills`, `squad-monitor`, `tamirdresher.github.io`

### Delivery

- **Recipient:** tamirdresher@microsoft.com
- **Sender:** tdsquadai@gmail.com (Gmail SMTP)
- **Archive:** `~/.squad/daily-reports/squad-daily-report-YYYY-MM-DD.html`

### Deduplication (multi-machine)

Two-layer dedup prevents duplicate sends when multiple machines are running:

1. **Local marker:** `~/.squad/daily-report-{date}.sent` — fastest check, per-machine
2. **Git marker:** `.squad/daily-report-last-sent.json` — cross-machine; first machine to write and push wins

On startup, `start-all-ralphs.ps1` calls the report script so it catches up if the scheduled time was missed.

### Testing

```powershell
# Dry run — generate report but don't send
pwsh scripts/daily-squad-report.ps1 -DryRun

# Save HTML to file without sending
pwsh scripts/daily-squad-report.ps1 -SaveTo C:\temp\report-preview.html

# Send to a different address
pwsh scripts/daily-squad-report.ps1 -To test@example.com -DryRun
```

### GitHub Actions

The workflow `.github/workflows/squad-daily-report.yml` triggers at 03:00 UTC (5 AM IST)
on a self-hosted runner with access to email credentials.

---

## Setting Up the 5 AM Schedule

### Windows Task Scheduler (local machine)

Run once from a PowerShell admin window:

```powershell
# Register the daily report task
$action = New-ScheduledTaskAction `
    -Execute "pwsh.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\temp\tamresearch1\scripts\daily-squad-report.ps1`"" `
    -WorkingDirectory "C:\temp\tamresearch1"

$trigger = New-ScheduledTaskTrigger -Daily -At "05:00AM"

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) `
    -StartWhenAvailable `
    -WakeToRun

Register-ScheduledTask `
    -TaskName "Squad Daily Report" `
    -TaskPath "\Squad\" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -RunLevel Highest `
    -Description "Daily Squad activity report — sent to tamirdresher@microsoft.com at 5 AM Israel time"

Write-Host "✅ Squad Daily Report scheduled task registered"
```

### GitHub Actions (remote trigger)

See `.github/workflows/squad-daily-report.yml` — scheduled at `0 3 * * *` UTC.

---

## How `start-all-ralphs.ps1` Integrates

`start-all-ralphs.ps1` calls `scripts/daily-squad-report.ps1` in a background job on startup.
The script's built-in dedup logic ensures it only sends if no report has been sent today yet.
This means: if the machine was off at 5 AM, the report still gets sent at next startup.

---

## Credential Requirements

| Task | Credential | Store |
|------|-----------|-------|
| Daily Squad Report (send) | `squad-email-gmail` | Windows Credential Manager |
| Outlook send | `squad-email-outlook` | Windows Credential Manager |

To store Gmail credentials:
```powershell
cmdkey /generic:squad-email-gmail /user:tdsquadai@gmail.com /pass:YOUR_APP_PASSWORD
```
