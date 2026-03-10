# Observability & Troubleshooting

## Overview

The Squad system includes comprehensive observability features for monitoring agent activity, automation loops, and system health.

## Components

### 1. Ralph Watch Script

**Location:** `ralph-watch.ps1`

The autonomous monitoring loop that runs continuously (typically every 5 minutes via GitHub Actions or cron).

**Key Features:**
- Structured logging with timestamps
- Heartbeat file for health checks
- Metrics collection (last run time, error counts)
- Lock file to prevent duplicate instances
- Automatic retries on failures
- Teams alerts on critical errors

**Observability:**

```powershell
# Check if Ralph is running
Get-Content .squad\ralph-heartbeat.json

# View Ralph logs
Get-Content .squad\logs\ralph-watch.log -Tail 50

# Check metrics
Get-Content .squad\metrics\ralph-metrics.json
```

**Key Metrics:**
- `last_run_time` - Timestamp of last successful run
- `error_count` - Number of errors in current session
- `tasks_processed` - Number of scheduled tasks evaluated
- `issues_triaged` - Number of issues processed

### 2. Squad Monitor Dashboard

**Location:** `squad-monitor-standalone/`

Real-time monitoring dashboard built in C# (.NET 8+) for visualizing Squad activity.

**Features:**
- Real-time agent activity parsing
- Automation loop health monitoring
- GitHub integration (issues, PRs, workflow runs)
- Orchestration logs
- Cross-platform (Windows, macOS, Linux)

**Usage:**

```bash
cd squad-monitor-standalone/src/SquadMonitor
dotnet run
```

The dashboard will open in your browser at `http://localhost:5000`.

**Monitoring Views:**
- **Agent Activity** - Live view of agent actions and decisions
- **Issue Queue** - Real-time issue triage and assignment
- **Workflow Health** - GitHub Actions status and run history
- **Automation Loops** - Ralph watch status and scheduled tasks
- **Decision Log** - Team decisions with full context

### 3. GitHub Actions Workflows

**Observability Features:**

All Squad workflows include:
- Structured output with clear step names
- Error annotations for failures
- Workflow run summaries
- Artifact uploads for detailed logs

**Key Workflows:**

- `squad-heartbeat.yml` - Ralph heartbeat (every 5 min)
- `squad-triage.yml` - Issue triage logging
- `squad-daily-digest.yml` - Daily activity summary
- `drift-detection.yml` - Configuration consistency checks

**Viewing Logs:**

```bash
# View latest heartbeat runs
gh run list --workflow=squad-heartbeat.yml --limit 10

# View specific run logs
gh run view <run-id> --log

# Watch live workflow
gh run watch
```

### 4. Structured Logging

**Log Locations:**
- Ralph logs: `.squad/logs/ralph-watch.log`
- Workflow logs: GitHub Actions UI
- Agent activity: `.squad/logs/agents/<agent-name>.log`

**Log Format:**
```
[2024-01-20 14:30:00] [INFO] [Ralph] Starting watch cycle
[2024-01-20 14:30:01] [INFO] [Ralph] Checking scheduled tasks
[2024-01-20 14:30:02] [INFO] [Ralph] Task 'daily-digest' ready to run
[2024-01-20 14:30:05] [INFO] [Ralph] Successfully executed task 'daily-digest'
[2024-01-20 14:30:06] [INFO] [Ralph] Watch cycle complete
```

### 5. Heartbeat File

**Location:** `.squad/ralph-heartbeat.json`

Updated by Ralph on every successful run.

**Example:**
```json
{
  "last_run": "2024-01-20T14:30:06Z",
  "status": "healthy",
  "tasks_evaluated": 6,
  "issues_processed": 3,
  "errors": 0
}
```

**Health Check:**
```powershell
# Check if heartbeat is recent (within 10 minutes)
$heartbeat = Get-Content .squad\ralph-heartbeat.json | ConvertFrom-Json
$lastRun = [DateTime]::Parse($heartbeat.last_run)
$age = (Get-Date) - $lastRun

if ($age.TotalMinutes -gt 10) {
    Write-Warning "Ralph heartbeat is stale (last run: $lastRun)"
}
```

## Troubleshooting

### Ralph Not Running

**Symptoms:**
- Heartbeat file is stale
- No recent workflow runs
- Issues not being triaged

**Diagnosis:**
```powershell
# Check heartbeat age
Get-Content .squad\ralph-heartbeat.json

# Check recent workflow runs
gh run list --workflow=squad-heartbeat.yml --limit 5

# Check for lock file
Test-Path .squad\ralph-watch.lock
```

**Solution:**
1. Check GitHub Actions are enabled
2. Verify workflow permissions (issues: write)
3. Check for lock file (remove if stale)
4. Review workflow logs for errors

### Agent Not Processing Issues

**Symptoms:**
- Issues stay unassigned
- No agent comments on new issues

**Diagnosis:**
```bash
# Check squad labels exist
gh label list | grep squad:

# View issue triage workflow runs
gh run list --workflow=squad-triage.yml --limit 5

# Check routing configuration
cat .squad/routing.md
```

**Solution:**
1. Ensure squad labels are synced (`sync-squad-labels.yml` workflow)
2. Verify routing rules match issue patterns
3. Check agent charters are up to date
4. Review triage workflow logs

### Teams Notifications Not Working

**Symptoms:**
- No Teams messages for closed issues
- Daily digest not posting

**Diagnosis:**
```bash
# Check workflow runs
gh run list --workflow=squad-daily-digest.yml --limit 5
gh run list --workflow=squad-issue-notify.yml --limit 5

# View workflow logs
gh run view <run-id> --log
```

**Solution:**
1. Verify Teams webhook URL is configured (repository secrets)
2. Check webhook is active in Teams channel
3. Test webhook with curl:
   ```bash
   curl -X POST <webhook-url> -H "Content-Type: application/json" -d '{"text":"Test"}'
   ```
4. Review workflow logs for HTTP errors

### Scheduled Tasks Not Running

**Symptoms:**
- Expected tasks don't execute
- Schedule.json changes not taking effect

**Diagnosis:**
```powershell
# Check schedule configuration
Get-Content .squad\schedule.json | ConvertFrom-Json

# View recent Ralph runs
Get-Content .squad\logs\ralph-watch.log -Tail 100

# Check task execution logs
gh run list --workflow=squad-heartbeat.yml
```

**Solution:**
1. Verify schedule.json syntax is valid JSON
2. Check task conditions (day of week, time of day)
3. Ensure Ralph is running on schedule
4. Review Ralph logs for task evaluation

### Drift Detection Failures

**Symptoms:**
- Drift detection workflow fails
- Configuration inconsistency warnings

**Diagnosis:**
```bash
# Run drift detection manually
gh workflow run drift-detection.yml

# View latest run
gh run list --workflow=drift-detection.yml --limit 1

# Check for drift issues
gh issue list --label drift-detection
```

**Solution:**
1. Review drift detection issue for details
2. Check agent charters have required sections (Role, Style)
3. Ensure all skills have SKILL.md files
4. Verify core configuration files exist (team.md, routing.md, schedule.json)

## Monitoring Best Practices

### 1. Set Up Alerts

Configure alerts for critical failures:

**GitHub Actions:**
- Enable workflow failure notifications in repository settings
- Use Slack/Teams webhooks for real-time alerts

**Ralph Watch:**
- Monitor heartbeat file age
- Alert if heartbeat is stale (>10 minutes)

### 2. Regular Health Checks

Weekly checks:
- [ ] Review drift detection issues
- [ ] Check Ralph heartbeat is current
- [ ] Verify all workflows are running
- [ ] Review agent activity logs
- [ ] Check Teams notifications are posting

### 3. Log Rotation

Prevent log files from growing indefinitely:

```powershell
# Rotate logs weekly
Get-ChildItem .squad\logs -Filter *.log | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
    Compress-Archive -DestinationPath .squad\logs\archive\logs-$(Get-Date -Format 'yyyy-MM-dd').zip
```

### 4. Metrics Collection

Track key metrics over time:
- Issue response time
- Task completion rate
- Agent utilization
- Workflow success rate

### 5. Dashboard Monitoring

Keep Squad Monitor running during active development:
```bash
cd squad-monitor-standalone/src/SquadMonitor
dotnet run
```

Access dashboard at `http://localhost:5000` for real-time observability.

## Performance Optimization

### Reduce Workflow Run Time

1. Use `--quiet` and `--no-pager` flags in git commands
2. Cache dependencies in workflows
3. Limit GitHub API calls with pagination
4. Use conditional execution for expensive steps

### Reduce Log Volume

1. Set appropriate log levels (INFO for production, DEBUG for troubleshooting)
2. Rotate logs regularly
3. Archive old logs to external storage
4. Use structured logging for easier filtering

### Improve Ralph Performance

1. Optimize scheduled task frequency
2. Use WorkIQ filters to reduce API calls
3. Implement caching for GitHub data
4. Batch issue processing

## Advanced Debugging

### Enable Debug Logging

**Ralph Watch:**
```powershell
# Set debug level in ralph-watch.ps1
$DebugPreference = "Continue"
.\ralph-watch.ps1
```

**GitHub Actions:**
```yaml
- name: Enable debug logging
  run: |
    echo "ACTIONS_STEP_DEBUG=true" >> $GITHUB_ENV
    echo "ACTIONS_RUNNER_DEBUG=true" >> $GITHUB_ENV
```

### Trace Agent Decisions

View decision log in Squad Monitor or:
```bash
# View recent decisions
cat .squad/decisions.md | tail -50

# Search for specific decision
grep -i "scheduler" .squad/decisions.md
```

### Monitor API Rate Limits

```bash
# Check GitHub API rate limit
gh api rate_limit

# View rate limit in workflow
gh api rate_limit --jq '.resources.core'
```

## Support

For persistent issues, create an issue with:
- Relevant log excerpts
- Heartbeat file contents
- Workflow run links
- Configuration files

Label: `squad:picard` for observability issues.
