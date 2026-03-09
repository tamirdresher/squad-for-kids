# Daily BasePlatformRP Status Briefing

Automated daily status report for the BasePlatformRP project, delivered via Teams at 9:00 AM (IST/UTC+2).

## Features

- **GitHub Activity**: Open PRs, issues, recent commits, and closed PRs
- **Blockers**: Highlights critical issues with blocker/urgent/sev labels
- **Action Items**: PRs awaiting review (>3 days)
- **Adaptive Card**: Rich Teams formatting with sections and links
- **Weekend Awareness**: Skips weekends when using `-SkipWeekends` flag

## Usage

### Manual Run
```powershell
# Test with dry-run (no Teams message sent)
.\.squad\scripts\daily-rp-briefing.ps1 -DryRun

# Send actual briefing
.\.squad\scripts\daily-rp-briefing.ps1

# Skip on weekends
.\.squad\scripts\daily-rp-briefing.ps1 -SkipWeekends
```

### Scheduling Options

#### Option 1: Ralph Watch Integration (IMPLEMENTED)
The briefing runs automatically during Ralph's rounds if it's 9:00 AM on a weekday.

```powershell
# Ralph watch runs every 5 minutes and checks for 9:00 AM
.\ralph-watch.ps1
```

**How it works:**
- Ralph checks the time at the start of each round
- If current time is 9:00-9:05 AM on a weekday, it runs the briefing
- Only sends once per day (subsequent rounds in the same hour skip it)

#### Option 2: Windows Task Scheduler
```powershell
# Create a scheduled task for 9:00 AM daily
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\temp\tamresearch1\.squad\scripts\daily-rp-briefing.ps1" -SkipWeekends'

$trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd

Register-ScheduledTask -TaskName "BasePlatformRP Daily Briefing" `
    -Action $action -Trigger $trigger -Settings $settings `
    -Description "Daily 9 AM status report for BasePlatformRP"
```

#### Option 3: GitHub Actions (cron)
Create `.github/workflows/daily-briefing.yml`:

```yaml
name: Daily RP Briefing
on:
  schedule:
    - cron: '0 7 * * 1-5'  # 7:00 UTC = 9:00 AM IST (Mon-Fri)
  workflow_dispatch:

jobs:
  briefing:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Send briefing
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TEAMS_WEBHOOK_URL: ${{ secrets.TEAMS_WEBHOOK_URL }}
        run: |
          # Install gh CLI if not available
          # Run briefing script (would need to adapt for Linux)
          echo "$TEAMS_WEBHOOK_URL" > ~/.teams-webhook.url
          pwsh .squad/scripts/daily-rp-briefing.ps1 -TeamsWebhookFile ~/.teams-webhook.url
```

## Configuration

### Teams Webhook
The script expects the Teams webhook URL at:
```
$env:USERPROFILE\.squad\teams-webhook.url
```

You can override this with `-TeamsWebhookFile <path>`.

### Repository
The script targets: `mtp-microsoft/Infra.K8s.BasePlatformRP`

To change the repository, edit line 37 in `daily-rp-briefing.ps1`:
```powershell
$repo = "your-org/your-repo"
```

## Briefing Sections

1. **≡ƒÜ¿ Blockers & Critical Items** ΓÇö Issues with blocker/urgent/sev/incident labels
2. **≡ƒöä Open Pull Requests** ΓÇö All open PRs with author and age
3. **≡ƒôï Key Open Issues** ΓÇö Grouped by label
4. **≡ƒôê Yesterday's Activity** ΓÇö Commits and closed PRs from last 24h
5. **≡ƒôä Loop Doc Status** ΓÇö Placeholder (manual check link)
6. **≡ƒÆ¼ Recent RP Discussions** ΓÇö Placeholder (requires WorkIQ MCP)
7. **≡ƒôà Today's Meetings** ΓÇö Placeholder (requires WorkIQ MCP)
8. **Γ£à Action Items** ΓÇö Old PRs needing review, blockers requiring attention

## Future Enhancements

### WorkIQ Integration (Pending)
When WorkIQ MCP is available, add:
- Teams chats mentioning RP/provisioning/platform
- Emails related to BasePlatformRP
- Today's calendar events for RP meetings

### Loop Doc Integration
Add automated check for recent modifications to the Dk8sPlatform ARM RP Loop document.

### ADO Work Items
Query Azure DevOps for DK8S RP epic and related scenarios.

## Troubleshooting

### Script fails with "gh: command not found"
Install GitHub CLI: `winget install GitHub.cli`

### Teams message not received
1. Check webhook URL exists: `cat $env:USERPROFILE\.squad\teams-webhook.url`
2. Test with dry-run: `.\.squad\scripts\daily-rp-briefing.ps1 -DryRun`
3. Check for JSON syntax errors in output

### Date parsing warnings
The script may show warnings for closed PR date parsing ΓÇö this is non-fatal and doesn't affect the briefing.

## Related Files

- `.squad/scripts/daily-rp-briefing.ps1` ΓÇö Main briefing script
- `ralph-watch.ps1` ΓÇö Ralph watch loop with scheduling integration
- `$env:USERPROFILE\.squad\teams-webhook.url` ΓÇö Teams webhook URL
- `$env:USERPROFILE\.squad\ralph-watch.log` ΓÇö Ralph execution logs
