# Squad Scheduler Design — Generic, Provider-Agnostic Scheduling System

**Author:** B'Elanna (Infrastructure Expert)  
**Issue:** #199 — Can Squad have its own schedule to trigger itself automatically?  
**Status:** Design Proposal (Pending User Decision on Providers)  
**Created:** 2026-03-09

---

## Executive Summary

Squad currently uses ad-hoc scheduling mechanisms scattered across multiple providers:
- **GitHub Actions**: Cron-based workflows (squad-daily-digest.yml, squad-heartbeat.yml)
- **PowerShell**: ralph-watch.ps1 polling loop with fixed 5-minute intervals
- **Manual trigger**: workflow_dispatch for ad-hoc runs

**Problem:** Squad can forget scheduled tasks because schedules are tightly coupled to infrastructure (GitHub runners, local machine availability). There's no unified view of what Squad is supposed to do regularly.

**Solution:** A generic, provider-agnostic **Squad Scheduler** that:
1. Defines all scheduled work in a single `.squad/schedule.json` manifest
2. Abstracts provider plugins (GitHub Actions, Windows Task Scheduler, local polling, webhooks, etc.)
3. Persists across sessions—schedules survive machine restarts
4. Integrates seamlessly with ralph-watch.ps1 and existing workflows
5. Provides a clear audit trail of scheduled tasks and execution history

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Squad Scheduler Core                         │
│  • Parses .squad/schedule.json                                  │
│  • Evaluates trigger conditions (cron, interval, event)         │
│  • Executes scheduled tasks                                      │
│  • Logs execution history to .squad/scheduler.log               │
└─────────────────────────────────────────────────────────────────┘
       ▲                                      ▼
       │                            Execution Engines
       │                              │
       ├─────────────────────────────┼─────────────────────────┐
       │                             │                         │
   Scheduling Layer         Provider Adapters          Task Executors
   ┌──────────────────┐     ┌──────────────┐           ┌──────────────┐
   │ • Parse schedule │     │ • GitHub     │           │ • CLI runner │
   │ • Track state    │     │ • Win Sched  │           │ • Webhook    │
   │ • Trigger events │     │ • cron       │           │ • Function   │
   │ • De-duplicate   │     │ • HTTP poll  │           │ • Script     │
   └──────────────────┘     └──────────────┘           └──────────────┘
```

### Key Components

1. **Schedule Definition** (`.squad/schedule.json`)
   - Declarative, JSON-based task definitions
   - Support for cron, interval, event-based, and one-shot triggers
   - Task metadata: name, description, provider(s), retry policy, timeout

2. **Scheduler Engine** (`.squad/scheduler/engine.ts` or `.ps1`)
   - Evaluates trigger conditions
   - Manages execution state and history
   - Coordinates provider adapters
   - Handles retries and error reporting

3. **Provider Abstraction Layer** (`.squad/scheduler/providers/`)
   - Plugin architecture for different execution environments
   - Each provider: GitHub Actions, Windows Task Scheduler, local polling, webhooks
   - Clean interface: `canExecute()`, `execute()`, `getStatus()`

4. **Execution History** (`.squad/scheduler.log`)
   - Structured JSON lines log
   - Tracks: task ID, trigger time, execution status, duration, output
   - Enables alerting on repeated failures

---

## Schedule Definition Format

### File: `.squad/schedule.json`

```json
{
  "version": 1,
  "schedules": [
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
    },
    {
      "id": "ralph-heartbeat",
      "name": "Ralph Heartbeat",
      "description": "Run Squad triage every 5 minutes",
      "enabled": true,
      "trigger": {
        "type": "interval",
        "intervalSeconds": 300
      },
      "task": {
        "type": "script",
        "command": "gh workflow run squad-heartbeat.yml",
        "cwd": ".github/workflows"
      },
      "providers": ["local-polling", "github-actions"],
      "retry": {
        "maxAttempts": 2,
        "backoffSeconds": 30
      },
      "timeout": 600,
      "notifyOnFailure": ["teams"],
      "tags": ["triage", "ralph"]
    },
    {
      "id": "weekly-upstream-sync",
      "name": "Weekly Upstream Sync",
      "description": "Sync upstream repos every Monday at 2 AM UTC",
      "enabled": true,
      "trigger": {
        "type": "cron",
        "expression": "0 2 * * 1",
        "timezone": "UTC"
      },
      "task": {
        "type": "copilot",
        "instruction": "Sync all upstream repos: check for new issues, PRs, discussions"
      },
      "providers": ["copilot-agent"],
      "retry": {
        "maxAttempts": 1,
        "backoffSeconds": 0
      },
      "timeout": 3600,
      "notifyOnFailure": ["teams", "issue-comment"],
      "tags": ["sync", "upstream"]
    },
    {
      "id": "health-check",
      "name": "Infrastructure Health Check",
      "description": "Daily infrastructure validation at 6 AM UTC",
      "enabled": true,
      "trigger": {
        "type": "cron",
        "expression": "0 6 * * *",
        "timezone": "UTC"
      },
      "task": {
        "type": "webhook",
        "url": "${SQUAD_HEALTH_CHECK_WEBHOOK}",
        "method": "POST",
        "payload": {
          "action": "health-check",
          "timestamp": "$NOW"
        }
      },
      "providers": ["http-webhook"],
      "retry": {
        "maxAttempts": 3,
        "backoffSeconds": 120
      },
      "timeout": 300,
      "notifyOnFailure": ["teams", "pagerduty"],
      "tags": ["infrastructure", "monitoring"]
    },
    {
      "id": "clean-up-logs",
      "name": "Clean Old Logs",
      "description": "Archive logs older than 30 days (one-shot on startup)",
      "enabled": true,
      "trigger": {
        "type": "startup",
        "condition": "once-per-day"
      },
      "task": {
        "type": "script",
        "command": "Remove-Item .squad/log/*.log -Filter {$_.LastWriteTime -lt (Get-Date).AddDays(-30)}",
        "shell": "powershell"
      },
      "providers": ["local-script"],
      "retry": {
        "maxAttempts": 1,
        "backoffSeconds": 0
      },
      "timeout": 300,
      "tags": ["maintenance"]
    }
  ],
  "defaults": {
    "retryMaxAttempts": 2,
    "retryBackoffSeconds": 60,
    "timeout": 1800,
    "notifyOnFailure": ["teams"]
  },
  "notificationChannels": {
    "teams": {
      "webhookUrl": "${TEAMS_WEBHOOK_URL}",
      "format": "adaptive-card"
    },
    "pagerduty": {
      "integrationKey": "${PAGERDUTY_KEY}",
      "severity": "critical"
    },
    "issue-comment": {
      "repo": "tamirdresher_microsoft/tamresearch1",
      "labels": ["squad:ralph", "automation"]
    }
  }
}
```

### Trigger Types

| Type | Expression | Example | Use Case |
|------|-----------|---------|----------|
| `cron` | POSIX cron | `0 8 * * *` | Daily at 8 AM UTC |
| `interval` | Seconds | `300` | Every 5 minutes |
| `event` | GitHub event | `pull_request.opened` | On PR created |
| `startup` | Condition | `once-per-day` | On Squad start (once daily) |
| `webhook` | HTTP POST | Received at Squad webhook endpoint | External trigger |

### Task Types

| Type | Config | Execution | Use Case |
|------|--------|-----------|----------|
| `workflow` | `ref` + `event` | Dispatch GitHub workflow | Squad heartbeat, triage |
| `script` | `command` + `shell` | Local shell execution | Cleanup, validation |
| `copilot` | `instruction` | Copilot agent session | Complex work (sync, research) |
| `webhook` | `url` + `method` + `payload` | HTTP request | Remote triggers |
| `function` | `functionName` | TypeScript/Node.js function | Programmatic tasks |

---

## Provider Abstraction Layer

### Interface (TypeScript)

```typescript
interface ScheduleProvider {
  /**
   * Can this provider execute on this platform right now?
   */
  canExecute(schedule: Schedule, context: ExecutionContext): Promise<boolean>;

  /**
   * Execute the task synchronously or queue it
   */
  execute(schedule: Schedule, task: Task, context: ExecutionContext): Promise<ExecutionResult>;

  /**
   * Get current status of this provider (available, degraded, unavailable)
   */
  getStatus(): Promise<ProviderStatus>;

  /**
   * Cleanup/validation on provider startup
   */
  validate(): Promise<void>;
}

interface ExecutionResult {
  success: boolean;
  executedAt: string;
  completedAt: string;
  durationMs: number;
  output?: string;
  error?: string;
  nextRetry?: string;
}
```

### Built-in Providers

#### 1. Local Polling (`local-polling`)
- **Platform:** Any (Windows, macOS, Linux with PowerShell)
- **Mechanism:** ralph-watch.ps1 evaluates schedule.json every polling cycle
- **Reliability:** Depends on ralph-watch running; survives machine restarts if scheduled as Windows Task
- **Best for:** Frequent tasks (< 5 min intervals), development, fallback

#### 2. GitHub Actions (`github-actions`)
- **Platform:** GitHub-based repos
- **Mechanism:** Create dynamic workflow + dispatch OR schedule external runner
- **Reliability:** GitHub infrastructure; scheduled runs are reliable
- **Best for:** Critical recurring tasks (daily digests, weekly syncs)

#### 3. Windows Task Scheduler (`windows-scheduler`)
- **Platform:** Windows only
- **Mechanism:** Register persistent tasks via `New-ScheduledTask`
- **Reliability:** OS-level reliability; survives reboots
- **Best for:** Persistent maintenance tasks on dedicated Squad agent

#### 4. HTTP Webhook (`http-webhook`)
- **Platform:** Any (requires Squad webhook endpoint)
- **Mechanism:** External service posts to Squad's webhook URL
- **Reliability:** Depends on caller; can implement signature validation
- **Best for:** Event-driven scheduling from external systems

#### 5. Copilot Agent (`copilot-agent`)
- **Platform:** Any (via Copilot CLI)
- **Mechanism:** Dispatch new Copilot session with task instruction
- **Reliability:** Depends on Squad agent availability
- **Best for:** Complex work requiring reasoning (upstream sync, research)

---

## Integration with Existing Systems

### Ralph Watch Integration

**Current behavior:** ralph-watch.ps1 runs every 5 minutes, dispatches Copilot triage session.

**New behavior:**
1. ralph-watch.ps1 loads `.squad/schedule.json`
2. On each heartbeat (5-min interval), evaluates ALL schedules
3. For each due schedule:
   - If provider is `local-polling` or `local-script`, execute immediately
   - If provider is `github-actions`, dispatch workflow (non-blocking)
   - If provider is `copilot-agent`, queue for next Copilot session
4. Log execution to `.squad/scheduler.log`

**Key code addition to ralph-watch.ps1:**
```powershell
function Invoke-ScheduledTasks {
    param([string]$ScheduleFile)
    $schedules = Get-Content $ScheduleFile | ConvertFrom-Json
    foreach ($schedule in $schedules.schedules) {
        if (-not $schedule.enabled) { continue }
        if (Test-ScheduleDue -Schedule $schedule) {
            Invoke-ScheduleTask -Schedule $schedule
        }
    }
}
```

### Squad Heartbeat Workflow Integration

**Current behavior:** Manually triggered or scheduled via GitHub Actions cron.

**New behavior:**
1. .squad/schedule.json declares heartbeat schedule (e.g., every 5 min)
2. ralph-watch.ps1 (local polling) or GitHub Actions (cloud fallback) executes it
3. Scheduler logs execution and failure/success metrics
4. If both fail consecutively (3+ times), alert ops

---

## Migration Path from Current Ad-Hoc Scheduling

### Phase 1: Define All Known Schedules (Week 1)
- List all current recurring tasks:
  - squad-daily-digest.yml: 8 AM UTC daily
  - squad-heartbeat.yml: on-demand (triggered by ralph-watch.ps1 every 5 min)
  - Any manual weekly/monthly sync tasks
  - Maintenance: log cleanup, cache invalidation
- Translate to `.squad/schedule.json`

### Phase 2: Implement Scheduler Engine (Week 2-3)
- Create `.squad/scheduler/engine.ts` or `.ps1`
- Implement core scheduling logic: cron parsing, interval tracking, trigger evaluation
- Add provider adapters: local-polling, github-actions (required); others optional
- Add execution logging to `.squad/scheduler.log`

### Phase 3: Integrate with ralph-watch.ps1 (Week 3-4)
- Modify ralph-watch.ps1 to call scheduler engine
- Load and evaluate `.squad/schedule.json` on each heartbeat
- Execute local tasks; dispatch remote tasks
- Maintain backward compatibility (ralph-watch still works standalone)

### Phase 4: Migrate GitHub Actions Workflows (Week 4-5)
- Remove hardcoded cron schedules from individual workflows
- Keep workflows as task executors; let scheduler dispatch them
- Update squad-heartbeat.yml to be callable from scheduler

### Phase 5: Add Optional Providers (Week 5-6)
- Windows Task Scheduler registration (for persistent agents)
- Webhook endpoint for external triggers
- Copilot agent integration for complex tasks

### Phase 6: Observability & Dashboards (Week 6-7)
- Dashboard showing all scheduled tasks, next run times, recent failures
- Metrics: execution counts, success rates, average duration
- Alerts on repeated failures or missed schedules

---

## Decision Points for Tamir (User Input Required)

1. **Primary Provider Strategy:**
   - **Option A:** GitHub Actions as primary (scalable, reliable), local polling as fallback
   - **Option B:** Local polling as primary (always available), GitHub Actions for scale-out
   - **Option C:** Windows Task Scheduler as primary (persistent on agent machine), GitHub Actions for cloud

2. **Complexity vs. Features:**
   - **Option A:** Minimal MVP (cron + interval only, local polling + GitHub Actions)
   - **Option B:** Full-featured (all trigger types, all providers, webhook support, observability)

3. **Notification Channels:**
   - Required: Teams alerts on repeated failures?
   - Optional: PagerDuty integration? Issue comments?

4. **Persistence Requirements:**
   - Must schedules survive machine reboots? (affects provider choice)
   - Must we support multiple Squad agents running simultaneously?

5. **Timeline:**
   - Deliver MVP in 1 week (Phase 1-2)?
   - Full implementation over 6 weeks?
   - Phased rollout (heartbeat → digests → syncs)?

---

## Implementation Notes

### State Management
- Scheduler maintains `.squad/scheduler-state.json` with last execution timestamps
- Prevents duplicate runs if scheduler restarts mid-cycle
- Enables tracking of due-but-not-yet-executed schedules

### Error Handling & Retry
- Exponential backoff: 60s, 120s, 240s for retries
- Max 3 attempts by default (configurable per schedule)
- Failed executions logged with full error context
- Alerts after consecutive failures (threshold configurable)

### Concurrency & De-duplication
- Lock file `.squad/scheduler.lock` prevents concurrent scheduler instances
- De-duplication by schedule ID: if task already running, skip next trigger
- Critical for ralph-watch (5-min interval) and heartbeat (dispatch-based)

### Security
- Schedule definitions stored in repo (no secrets)
- Sensitive data (webhooks, API keys) via environment variables
- Task instructions audited in `.squad/scheduler.log`
- No privilege escalation—runs with current user/agent permissions

---

## Success Criteria

1. ✅ Single source of truth: all scheduled tasks in `.squad/schedule.json`
2. ✅ No forgotten tasks: scheduler maintains execution history and alerts on failures
3. ✅ Provider-agnostic: can swap local polling ↔ GitHub Actions ↔ Windows Task Scheduler
4. ✅ Persistent: schedules survive session restarts and machine reboots (with Windows Task Scheduler)
5. ✅ Integrated: ralph-watch.ps1 uses scheduler engine by default
6. ✅ Observable: dashboard + logs show all scheduled tasks and execution history

---

## Appendix: Example `.squad/schedule.json` (Minimal MVP)

```json
{
  "version": 1,
  "schedules": [
    {
      "id": "ralph-heartbeat",
      "name": "Ralph Heartbeat",
      "enabled": true,
      "trigger": {
        "type": "interval",
        "intervalSeconds": 300
      },
      "task": {
        "type": "workflow",
        "ref": ".github/workflows/squad-heartbeat.yml"
      },
      "providers": ["local-polling", "github-actions"]
    },
    {
      "id": "daily-digest",
      "name": "Daily Digest",
      "enabled": true,
      "trigger": {
        "type": "cron",
        "expression": "0 8 * * *"
      },
      "task": {
        "type": "workflow",
        "ref": ".github/workflows/squad-daily-digest.yml"
      },
      "providers": ["github-actions"]
    }
  ]
}
```

---

## References

- Issue #199: Can Squad have its own schedule?
- ralph-watch.ps1: Current 5-min polling loop
- squad-heartbeat.yml: Current triage workflow
- squad-daily-digest.yml: Daily digest workflow
- .squad/: Squad configuration directory

