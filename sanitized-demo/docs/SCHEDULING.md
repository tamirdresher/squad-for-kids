# Squad Scheduling System Guide

The Squad scheduling system enables automated execution of tasks on intervals or cron schedules, with support for multiple execution providers (local polling, GitHub Actions, Copilot agents).

## Overview

Squad scheduling consists of:

1. **schedule.json** — Task definitions with triggers, retries, and providers
2. **Ralph Watch** — Local polling loop that evaluates schedule and executes tasks
3. **GitHub Actions** — Workflow dispatch for schedule execution
4. **Squad Scheduler** — PowerShell module that evaluates triggers and fires tasks

## Schedule File Structure

**Location:** `.squad/schedule.json`

```json
{
  "version": 1,
  "schedules": [
    {
      "id": "unique-task-id",
      "name": "Human-Readable Name",
      "description": "What this task does",
      "enabled": true,
      "trigger": { /* trigger config */ },
      "task": { /* task config */ },
      "providers": ["local-polling", "github-actions"],
      "retry": {
        "maxAttempts": 2,
        "backoffSeconds": 60
      },
      "timeout": 600,
      "notifyOnFailure": ["teams"],
      "tags": ["monitoring", "triage"],
      "metadata": { /* optional metadata */ }
    }
  ],
  "defaults": { /* global defaults */ },
  "notificationChannels": { /* notification config */ }
}
```

## Trigger Types

### 1. Interval Trigger

Run every N seconds:

```json
{
  "trigger": {
    "type": "interval",
    "intervalSeconds": 300
  }
}
```

**Examples:**
- Every 5 minutes: `"intervalSeconds": 300`
- Every 20 minutes: `"intervalSeconds": 1200`
- Every hour: `"intervalSeconds": 3600`

### 2. Cron Trigger

Standard cron expression:

```json
{
  "trigger": {
    "type": "cron",
    "expression": "0 8 * * *",
    "timezone": "UTC"
  }
}
```

**Common Patterns:**
- Daily at 8 AM UTC: `"0 8 * * *"`
- Every Monday at 2 AM: `"0 2 * * 1"`
- Weekdays at 9 AM: `"0 9 * * 1-5"`
- Every 5 minutes: `"*/5 * * * *"`

**Timezones:** Use IANA timezone names (e.g., `America/New_York`, `Europe/London`, `Asia/Tokyo`)

## Task Types

### 1. Workflow Task

Trigger a GitHub Actions workflow:

```json
{
  "task": {
    "type": "workflow",
    "ref": ".github/workflows/squad-heartbeat.yml",
    "event": "workflow_dispatch"
  }
}
```

### 2. Script Task

Execute a local PowerShell script:

```json
{
  "task": {
    "type": "script",
    "command": ".squad/scripts/daily-briefing.ps1 -Verbose",
    "shell": "powershell"
  }
}
```

### 3. Copilot Task

Run a GitHub Copilot CLI agent:

```json
{
  "task": {
    "type": "copilot",
    "instruction": "Check Teams messages for action items and create GitHub issues if needed.",
    "scriptRef": ".squad/scripts/teams-monitor-check.ps1"
  }
}
```

## Providers

Tasks can be executed by multiple providers:

### local-polling
Ralph watch evaluates the schedule and executes tasks locally.

**Use when:**
- Running on a developer machine or VM
- Need access to local environment (WorkIQ, Copilot CLI)
- Frequent polling required (< 5 minutes)

### github-actions
GitHub Actions workflows execute the task.

**Use when:**
- Running in cloud (no local machine required)
- Task can be fully automated via GitHub API
- Longer intervals acceptable (>= 5 minutes)

### copilot-agent
GitHub Copilot CLI agent executes the task.

**Use when:**
- Task requires complex logic or decision-making
- Need access to tools (grep, edit, GitHub CLI)
- Want AI-powered execution

**Example:**
```json
{
  "providers": ["local-polling", "github-actions"],
}
```

Ralph will try `local-polling` first, fall back to `github-actions` if local execution fails.

## Retry and Timeout

```json
{
  "retry": {
    "maxAttempts": 3,
    "backoffSeconds": 60
  },
  "timeout": 1800
}
```

- **maxAttempts** — Retry failed tasks N times
- **backoffSeconds** — Wait N seconds between retries
- **timeout** — Kill task if it runs longer than N seconds

## Notifications

Send alerts when tasks fail:

```json
{
  "notifyOnFailure": ["teams", "issue-comment"]
}
```

**Channels:**
- `teams` — Send to Teams webhook (defined in `notificationChannels.teams.webhookUrl`)
- `issue-comment` — Post comment on a tracking issue

**Configure Teams Webhook:**
```json
{
  "notificationChannels": {
    "teams": {
      "webhookUrl": "${TEAMS_WEBHOOK_URL}",
      "format": "adaptive-card"
    }
  }
}
```

Store the webhook URL in `~/.squad/teams-webhook.url` (local file, not in git).

## Task Metadata

Store additional context about tasks:

```json
{
  "metadata": {
    "issue": "#198",
    "owner": "Lead",
    "readOnly": true,
    "neverComment": true
  }
}
```

Use metadata to:
- Link tasks to tracking issues
- Document ownership
- Store configuration flags
- Add custom properties

## Example Schedule: Daily Digest

```json
{
  "id": "daily-digest",
  "name": "Daily Digest",
  "description": "Send team digest of yesterday's activity",
  "enabled": true,
  "trigger": {
    "type": "cron",
    "expression": "0 8 * * *",
    "timezone": "UTC"
  },
  "task": {
    "type": "workflow",
    "ref": ".github/workflows/squad-daily-digest.yml",
    "event": "workflow_dispatch"
  },
  "providers": ["github-actions", "local-fallback"],
  "retry": {
    "maxAttempts": 3,
    "backoffSeconds": 60
  },
  "timeout": 1800,
  "notifyOnFailure": ["teams"],
  "tags": ["monitoring", "digest"]
}
```

## Example Schedule: Teams Monitor

```json
{
  "id": "teams-message-monitor",
  "name": "Teams Message Monitor",
  "description": "Monitor Teams channels for actionable messages",
  "enabled": true,
  "trigger": {
    "type": "interval",
    "intervalSeconds": 1200
  },
  "task": {
    "type": "copilot",
    "instruction": "Use WorkIQ to scan Teams messages from the last 30 minutes. Focus on: direct mentions, review requests, action items, urgent items. Only create a GitHub issue if YourName needs to act.",
    "scriptRef": ".squad/scripts/teams-monitor-check.ps1"
  },
  "providers": ["local-polling"],
  "retry": {
    "maxAttempts": 2,
    "backoffSeconds": 60
  },
  "timeout": 600,
  "notifyOnFailure": ["teams"],
  "tags": ["monitoring", "teams", "communication"],
  "metadata": {
    "issue": "#215",
    "owner": "Infrastructure",
    "checkInterval": "20 minutes",
    "smartFiltering": true,
    "silentReview": true
  }
}
```

## Ralph Watch Integration

Ralph watch evaluates the schedule every round (every 5 minutes by default):

**How it works:**
1. Ralph loads `schedule.json`
2. For each enabled schedule:
   - Check trigger (has interval elapsed? is cron time reached?)
   - If trigger fires:
     - Execute task via configured provider
     - Record result (success/failure, duration, exit code)
     - Retry on failure (if configured)
     - Send notification on failure (if configured)
3. Write schedule state to `.squad/monitoring/schedule-state.json`

**Schedule State:**
```json
{
  "tasks": {
    "daily-digest": {
      "lastRun": "2024-01-15T08:00:00Z",
      "lastResult": "success",
      "nextRun": "2024-01-16T08:00:00Z",
      "consecutiveFailures": 0
    }
  }
}
```

## Squad Scheduler Script

**Location:** `.squad/scripts/Invoke-SquadScheduler.ps1`

Run the scheduler manually:

```powershell
.\.squad\scripts\Invoke-SquadScheduler.ps1 `
  -ScheduleFile ".\.squad\schedule.json" `
  -StateFile ".\.squad\monitoring\schedule-state.json" `
  -Provider "local-polling"
```

**Parameters:**
- `-ScheduleFile` — Path to schedule.json
- `-StateFile` — Path to state file (tracks last run times)
- `-Provider` — Provider to use (local-polling, github-actions, copilot-agent)

**Returns:**
```powershell
@{
  tasksFired = 2
  results = @(
    @{ id = "daily-digest"; result = "success"; duration = 12.5 },
    @{ id = "teams-monitor"; result = "success"; duration = 8.3 }
  )
}
```

## Best Practices

### 1. Use Interval for Frequent Checks
If you need to check something every 5-20 minutes, use interval triggers. They're simpler than cron and easier to adjust.

### 2. Use Cron for Daily/Weekly Tasks
For tasks that run daily, weekly, or on specific days, use cron. It's more readable and handles timezone conversions.

### 3. Set Reasonable Timeouts
- Quick checks: 300-600 seconds (5-10 minutes)
- Data processing: 900-1800 seconds (15-30 minutes)
- Long-running jobs: 3600+ seconds (1+ hour)

### 4. Configure Retries for Flaky Tasks
If a task fails occasionally due to network issues or API rate limits, configure 2-3 retries with backoff.

### 5. Tag Tasks for Easy Filtering
Use tags like `monitoring`, `digest`, `triage`, `sync` to categorize tasks. Useful for reporting and filtering.

### 6. Document Ownership in Metadata
Add `owner` field to metadata so you know who to ask about a task.

### 7. Test Locally Before Scheduling
Run tasks manually first to verify they work:
```powershell
.\.squad\scripts\teams-monitor-check.ps1 -LookbackMinutes 30
```

### 8. Monitor Schedule State
Check `.squad/monitoring/schedule-state.json` to see last run times and failure counts.

## Troubleshooting

### Task Not Firing
- Check `enabled: true` in schedule.json
- Verify trigger time/interval is correct
- Check schedule state file for `lastRun` timestamp
- Verify provider is available (e.g., local-polling requires Ralph watch running)

### Task Failing Repeatedly
- Check task logs (Ralph watch log, GitHub Actions log)
- Verify credentials (GitHub token, Teams webhook, WorkIQ)
- Test task manually: `.squad/scripts/<script>.ps1`
- Increase timeout if task is slow
- Add retries with backoff

### Teams Notifications Not Sent
- Verify webhook URL in `~/.squad/teams-webhook.url`
- Test webhook: `curl -X POST -H 'Content-Type: application/json' -d '{"text":"Test"}' <webhook-url>`
- Check `notifyOnFailure` includes `"teams"`

### Cron Time Not Matching
- Check timezone setting (use IANA names)
- Verify cron expression: https://crontab.guru/
- Remember: GitHub Actions schedules run in UTC

## Advanced: Custom Task Types

You can extend the scheduler to support custom task types by modifying `Invoke-SquadScheduler.ps1`:

```powershell
switch ($task.task.type) {
  "workflow" { /* existing code */ }
  "script" { /* existing code */ }
  "copilot" { /* existing code */ }
  "custom" {
    # Your custom task execution logic
    & ".\custom-handler.ps1" -TaskConfig $task.task
  }
}
```

## Additional Resources

- [Cron Expression Reference](https://crontab.guru/)
- [IANA Timezone Database](https://www.iana.org/time-zones)
- [PowerShell Scheduling](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/start-job)
- [GitHub Actions Scheduling](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule)
