# Squad Scheduler Design v2 — Provider-Agnostic Scheduling System

**Author:** B'Elanna (Infrastructure Expert)  
**Issue:** #199 — Generic scheduling system for Squad  
**Status:** Design Proposal (Ready for Implementation)  
**Created:** 2025-01-21  
**Supersedes:** squad-scheduler-design.md (v1)

---

## Executive Summary

Squad needs a **self-contained, provider-agnostic scheduling system** that:
1. **Never forgets tasks** — persistent state survives process crashes, machine reboots
2. **Works anywhere** — not bound to GitHub Actions, Azure DevOps, Windows Task Scheduler, or any single provider
3. **Triggers itself** — doesn't rely solely on external cron or ralph-watch.ps1
4. **Single source of truth** — all schedules in `.squad/schedule.json`
5. **Extensible** — easy to add new providers without changing core logic

**Current State:** Squad has a **hybrid scheduling system** that works but is fragmented:
- ✅ `.squad/schedule.json` defines schedules (already exists)
- ✅ `Invoke-SquadScheduler.ps1` evaluates cron expressions (242 lines, operational)
- ✅ `ralph-watch.ps1` runs every 5 minutes as daemon (493 lines, operational)
- ⚠️ GitHub Actions workflows have **hardcoded cron schedules** (not integrated with schedule.json)
- ⚠️ **No persistence** — if ralph-watch stops, tasks may be missed
- ⚠️ **No provider abstraction** — mixing local scripts, workflows, and copilot calls

**This Design:** Unifies scheduling into a **3-layer architecture**:
1. **Core Engine** — Provider-agnostic scheduler that reads schedule.json
2. **Provider Adapters** — Pluggable executors (local, GitHub, Azure, Windows Task Scheduler)
3. **Persistence Layer** — State database ensures tasks are never forgotten

---

## Problem Statement

### Current Pain Points

| Problem | Impact | Example |
|---------|--------|---------|
| **Schedules scattered across 4 locations** | Changes require editing workflows, schedule.json, scripts, and ralph-watch | To change daily digest time: edit workflow YAML + schedule.json |
| **No central visibility** | Can't answer "what's scheduled?" without checking 4 places | Team asks "when does ADR check run?" — need to grep 3 files |
| **GitHub Actions cron not integrated** | Workflows run independently, no coordination with ralph-watch | squad-daily-digest.yml has hardcoded `0 8 * * *`, not in schedule.json |
| **ralph-watch is single point of failure** | If process dies or machine reboots, tasks missed until restart | Machine updates overnight → ralph-watch killed → 5 AM briefing missed |
| **No recovery from missed tasks** | If ralph-watch was down during trigger window, task skipped forever | ralph-watch stopped from 7 AM-9 AM → 8 AM daily digest never sent |
| **Provider lock-in** | Migrating from local polling → cloud requires rewriting task executors | Moving to Azure DevOps pipelines requires new workflow files |
| **No audit trail** | Can't query "why didn't task X run?" | Team asks "did weekly sync run Monday?" — no queryable log |

### What "Not Forgetting" Means

A robust scheduler must handle:
1. **Process crashes** — ralph-watch killed by OOM, reboot, user error
2. **Missed windows** — machine was off when cron should have triggered
3. **Provider failures** — GitHub Actions runner down, workflow quota exceeded
4. **Concurrent runs** — prevent duplicate task execution if multiple providers active
5. **State recovery** — after restart, know what tasks completed, what's pending

**Example Scenario:**
```
6:00 AM — ralph-watch running, daily-rp-briefing scheduled for 7:00 AM
6:30 AM — Windows updates, machine reboots (ralph-watch killed)
8:00 AM — User logs back in, starts ralph-watch
```

**Current Behavior:** briefing never runs (missed window)  
**Required Behavior:** scheduler detects missed 7 AM task, runs it immediately (with "catch-up" flag)

---

## Architecture Design

### Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Layer 1: Core Scheduler Engine                       │
│  • Reads .squad/schedule.json (single source of truth)                  │
│  • Evaluates triggers (cron, interval, event, one-shot)                 │
│  • Manages execution state (SQLite database)                             │
│  • Coordinates provider adapters                                         │
│  • Handles retries, timeouts, notifications                              │
│  Entry point: Invoke-SquadScheduler.ps1 (enhanced)                      │
└─────────────────────────────────────────────────────────────────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                  Layer 2: Provider Abstraction Layer                     │
│  Plugin Architecture — Each provider implements ISchedulerProvider:      │
│    • CanHandle(task) → bool                                              │
│    • Execute(task, context) → result                                     │
│    • GetStatus(taskId) → status                                          │
│  Providers:                                                              │
│    • LocalPollingProvider — Direct PowerShell execution                  │
│    • GitHubActionsProvider — Dispatch workflows via gh CLI               │
│    • WindowsTaskSchedulerProvider — Register scheduled tasks             │
│    • AzureDevOpsProvider — Trigger pipelines via az CLI                  │
│    • CopilotAgentProvider — Spawn Agency sessions                        │
│    • WebhookProvider — HTTP POST to external systems                     │
└─────────────────────────────────────────────────────────────────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     Layer 3: Persistence Layer                           │
│  • SQLite database at .squad/monitoring/scheduler.db                     │
│  • Tables:                                                               │
│    - schedules (id, config, enabled, created_at)                         │
│    - executions (id, schedule_id, trigger_time, start_time, end_time,   │
│                  status, exit_code, output, provider)                    │
│    - state (schedule_id, last_run, next_run, consecutive_failures)      │
│  • Ensures tasks never forgotten (persists across process restarts)      │
│  • Queryable audit trail (SQL: "show all failed tasks last 7 days")     │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

**1. Initialization (ralph-watch starts or manual trigger)**
```
ralph-watch.ps1
  ↓
Invoke-SquadScheduler.ps1 -Provider local-polling
  ↓
Read .squad/schedule.json
  ↓
Load state from scheduler.db
  ↓
For each enabled schedule:
  - Evaluate trigger condition (cron/interval/event)
  - Check last_run from state table
  - If trigger matches AND not recently executed → mark for execution
  - If missed previous window AND catch-up enabled → mark for catch-up
  ↓
Dispatch tasks to provider adapters (in parallel where possible)
  ↓
Update scheduler.db with execution records
```

**2. Provider Selection**
```
Schedule defines: "providers": ["local-polling", "github-actions", "windows-scheduler"]

Scheduler evaluates in priority order:
1. If running in ralph-watch → try "local-polling" first
2. If ralph-watch not running → try "windows-scheduler" or "github-actions"
3. If primary provider fails → fallback to secondary provider
4. If all providers unavailable → queue for retry

Provider Adapter Contract:
  CanHandle(task) → bool   # Can this provider execute this task type?
  Execute(task, context) → { success, exitCode, output, duration }
  GetStatus(taskId) → { status: running|completed|failed, progress }
```

**3. Execution & State Updates**
```
Provider executes task
  ↓
Insert execution record: { schedule_id, trigger_time, start_time, status: running }
  ↓
Task runs (PowerShell script, workflow dispatch, copilot session)
  ↓
Provider reports result: { exitCode, output, duration }
  ↓
Update execution record: { end_time, status: success|failed, exit_code, output }
Update state table: { last_run, next_run, consecutive_failures }
  ↓
If task failed:
  - Increment consecutive_failures counter
  - If retry policy allows → schedule retry with backoff
  - If max failures reached → send notification (Teams webhook)
  ↓
If task succeeded:
  - Reset consecutive_failures counter
  - Calculate next_run based on trigger (cron/interval)
```

---

## Core Components

### 1. Schedule Definition (`.squad/schedule.json`)

**Already exists** — this is the single source of truth. Example entry:

```json
{
  "id": "daily-rp-briefing",
  "name": "Daily BasePlatformRP Briefing",
  "description": "Generate and send comprehensive RP status report at 9 AM (local)",
  "enabled": true,
  "trigger": {
    "type": "cron",
    "expression": "0 7 * * 1-5",
    "timezone": "Asia/Jerusalem",
    "catchUp": true,
    "catchUpWindowMinutes": 120
  },
  "task": {
    "type": "script",
    "command": ".squad/scripts/daily-rp-briefing.ps1 -SkipWeekends",
    "shell": "powershell"
  },
  "providers": ["local-polling", "windows-scheduler"],
  "retry": {
    "maxAttempts": 2,
    "backoffSeconds": 60
  },
  "timeout": 600,
  "notifyOnFailure": ["teams"],
  "tags": ["monitoring", "briefing", "rp"]
}
```

**New Fields in v2:**
- `trigger.catchUp` — If scheduler was down during trigger window, run task immediately on startup
- `trigger.catchUpWindowMinutes` — Only catch up if missed window was within N minutes ago
- `task.shell` — Specify executor (powershell, bash, node, python)
- `metadata` — Free-form object for provider-specific config

### 2. Scheduler Engine (`Invoke-SquadScheduler.ps1` — Enhanced)

**Current:** 242 lines, evaluates cron/interval triggers, dispatches to local scripts  
**Enhancement Plan:**

```powershell
# Invoke-SquadScheduler.ps1 v2.0

param(
    [string]$ScheduleFile = ".squad/schedule.json",
    [string]$DatabaseFile = ".squad/monitoring/scheduler.db",
    [string]$Provider = "auto",  # auto-detect best provider
    [switch]$DryRun = $false,
    [switch]$CatchUp = $true  # Run missed tasks on startup
)

# Core Functions (new in v2):
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Initialize-SchedulerDatabase {
    # Create SQLite database with tables: schedules, executions, state
    # Uses System.Data.SQLite (bundled with PowerShell 7+)
}

function Get-ActiveSchedules {
    # Load schedule.json, filter enabled=true
    # Return array of schedule objects
}

function Test-TriggerCondition {
    param($Schedule, $ReferenceTime, $LastRun)
    # Evaluate cron expression or interval
    # Return: $true if should execute now, $false otherwise
}

function Find-MissedExecutions {
    # If $CatchUp enabled, check for missed trigger windows
    # Query: SELECT * FROM state WHERE next_run < NOW() AND last_run < next_run
    # Return: array of schedules that missed their window
}

function Select-Provider {
    param($Schedule, $AvailableProviders)
    # Evaluate schedule.providers in priority order
    # Check if provider adapter available (e.g., gh CLI installed for github-actions)
    # Return: ISchedulerProvider instance or $null
}

function Invoke-TaskExecution {
    param($Schedule, $Provider, $Context)
    # 1. Insert execution record (status=running)
    # 2. Call provider.Execute(task, context)
    # 3. Update execution record (status=success/failed, output, duration)
    # 4. Update state table (last_run, next_run, consecutive_failures)
    # 5. Handle retries if failed
    # 6. Send notifications if needed
}

function Send-Notification {
    param($Schedule, $Execution, $Channel)
    # Teams webhook: adaptive card with task name, status, output
    # Issue comment: post to GitHub issue if metadata.issue exists
}

# Main Loop
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Initialize-SchedulerDatabase -Path $DatabaseFile
$schedules = Get-ActiveSchedules -Path $ScheduleFile
$now = Get-Date

# Catch up on missed executions (if enabled)
if ($CatchUp) {
    $missedTasks = Find-MissedExecutions -Schedules $schedules -Now $now
    foreach ($task in $missedTasks) {
        Write-Host "⏰ Catching up: $($task.name) (missed $($task.missedTriggerTime))"
        $provider = Select-Provider -Schedule $task
        if ($provider) {
            Invoke-TaskExecution -Schedule $task -Provider $provider -Context @{ CatchUp = $true }
        }
    }
}

# Evaluate current triggers
foreach ($schedule in $schedules) {
    $lastRun = Get-LastRun -ScheduleId $schedule.id -Database $DatabaseFile
    $shouldExecute = Test-TriggerCondition -Schedule $schedule -ReferenceTime $now -LastRun $lastRun
    
    if ($shouldExecute) {
        Write-Host "▶️  Triggering: $($schedule.name)"
        $provider = Select-Provider -Schedule $schedule
        if ($provider) {
            Invoke-TaskExecution -Schedule $schedule -Provider $provider -Context @{ CatchUp = $false }
        } else {
            Write-Warning "No available provider for $($schedule.name) — queueing for retry"
            # Queue for retry when provider becomes available
        }
    }
}

Write-Host "✅ Scheduler evaluation complete"
```

### 3. Provider Adapters (`.squad/scheduler/providers/`)

**Interface Contract (PowerShell class):**

```powershell
# ISchedulerProvider.ps1

class ISchedulerProvider {
    [string] $Name
    [int] $Priority  # Lower number = higher priority
    
    # Can this provider handle this task type?
    [bool] CanHandle([hashtable]$Task) {
        throw "Not implemented"
    }
    
    # Execute the task
    [hashtable] Execute([hashtable]$Task, [hashtable]$Context) {
        throw "Not implemented"
    }
    
    # Get status of running task
    [hashtable] GetStatus([string]$TaskId) {
        throw "Not implemented"
    }
    
    # Check if provider is available (dependencies installed, auth configured)
    [bool] IsAvailable() {
        throw "Not implemented"
    }
}
```

**Provider Implementations:**

#### **LocalPollingProvider** (highest priority for ralph-watch)

```powershell
class LocalPollingProvider : ISchedulerProvider {
    LocalPollingProvider() {
        $this.Name = "local-polling"
        $this.Priority = 1
    }
    
    [bool] CanHandle([hashtable]$Task) {
        return $Task.type -in @('script', 'copilot', 'workflow')
    }
    
    [hashtable] Execute([hashtable]$Task, [hashtable]$Context) {
        $startTime = Get-Date
        
        switch ($Task.type) {
            'script' {
                $result = & $Task.shell -Command $Task.command
                $exitCode = $LASTEXITCODE
            }
            'copilot' {
                $result = agency copilot --yolo --autopilot -p $Task.instruction
                $exitCode = $LASTEXITCODE
            }
            'workflow' {
                # Dispatch workflow via gh CLI
                $result = gh workflow run $Task.ref --ref main
                $exitCode = $LASTEXITCODE
            }
        }
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        return @{
            Success = ($exitCode -eq 0)
            ExitCode = $exitCode
            Output = $result
            Duration = $duration
        }
    }
    
    [bool] IsAvailable() {
        return $true  # Always available on local machine
    }
}
```

#### **GitHubActionsProvider** (cloud-based fallback)

```powershell
class GitHubActionsProvider : ISchedulerProvider {
    GitHubActionsProvider() {
        $this.Name = "github-actions"
        $this.Priority = 2
    }
    
    [bool] CanHandle([hashtable]$Task) {
        return $Task.type -eq 'workflow'
    }
    
    [hashtable] Execute([hashtable]$Task, [hashtable]$Context) {
        # Dispatch workflow via GitHub API
        $workflowPath = $Task.ref
        $startTime = Get-Date
        
        $result = gh workflow run $workflowPath --ref main 2>&1
        $exitCode = $LASTEXITCODE
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        return @{
            Success = ($exitCode -eq 0)
            ExitCode = $exitCode
            Output = $result
            Duration = $duration
            Async = $true  # Workflow runs asynchronously
        }
    }
    
    [bool] IsAvailable() {
        # Check if gh CLI installed and authenticated
        try {
            gh auth status 2>&1 | Out-Null
            return $LASTEXITCODE -eq 0
        } catch {
            return $false
        }
    }
}
```

#### **WindowsTaskSchedulerProvider** (persistent across reboots)

```powershell
class WindowsTaskSchedulerProvider : ISchedulerProvider {
    WindowsTaskSchedulerProvider() {
        $this.Name = "windows-scheduler"
        $this.Priority = 3
    }
    
    [bool] CanHandle([hashtable]$Task) {
        return $Task.type -eq 'script'
    }
    
    [hashtable] Execute([hashtable]$Task, [hashtable]$Context) {
        # Register Windows Scheduled Task
        $taskName = "Squad_$($Task.id)"
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File $($Task.command)"
        
        if ($Task.trigger.type -eq 'cron') {
            # Convert cron to Windows trigger
            $trigger = Convert-CronToWindowsTrigger -Expression $Task.trigger.expression
        } else {
            # Interval trigger
            $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Seconds $Task.trigger.intervalSeconds)
        }
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Force
        
        return @{
            Success = $true
            ExitCode = 0
            Output = "Registered Windows Scheduled Task: $taskName"
            Duration = 0
            Persistent = $true  # Task survives ralph-watch restarts
        }
    }
    
    [bool] IsAvailable() {
        return $IsWindows
    }
}
```

#### **CopilotAgentProvider** (for copilot-driven tasks)

```powershell
class CopilotAgentProvider : ISchedulerProvider {
    CopilotAgentProvider() {
        $this.Name = "copilot-agent"
        $this.Priority = 1
    }
    
    [bool] CanHandle([hashtable]$Task) {
        return $Task.type -eq 'copilot'
    }
    
    [hashtable] Execute([hashtable]$Task, [hashtable]$Context) {
        $startTime = Get-Date
        
        # Spawn Agency Copilot session with specific instruction
        $prompt = $Task.instruction
        if ($Task.scriptRef) {
            $prompt += "`n`nScript reference: $($Task.scriptRef)"
        }
        
        $result = agency copilot --yolo --autopilot -p $prompt 2>&1
        $exitCode = $LASTEXITCODE
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        return @{
            Success = ($exitCode -eq 0)
            ExitCode = $exitCode
            Output = $result
            Duration = $duration
        }
    }
    
    [bool] IsAvailable() {
        # Check if agency CLI available
        return (Get-Command agency -ErrorAction SilentlyContinue) -ne $null
    }
}
```

### 4. Persistence Layer (`scheduler.db`)

**SQLite Database Schema:**

```sql
-- schedules table (mirrors schedule.json for auditability)
CREATE TABLE schedules (
    id TEXT PRIMARY KEY,
    config TEXT NOT NULL,  -- JSON serialization of schedule object
    enabled INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- executions table (audit trail of all task runs)
CREATE TABLE executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    schedule_id TEXT NOT NULL,
    trigger_time TIMESTAMP NOT NULL,  -- When scheduler decided to run this
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    status TEXT NOT NULL,  -- running|success|failed|timeout
    exit_code INTEGER,
    output TEXT,
    provider TEXT,
    duration_seconds REAL,
    context TEXT,  -- JSON: { catchUp: true, retryAttempt: 2, ... }
    FOREIGN KEY (schedule_id) REFERENCES schedules(id)
);

-- state table (stateful tracking per schedule)
CREATE TABLE state (
    schedule_id TEXT PRIMARY KEY,
    last_run TIMESTAMP,
    next_run TIMESTAMP,
    consecutive_failures INTEGER DEFAULT 0,
    last_failure_reason TEXT,
    total_executions INTEGER DEFAULT 0,
    total_successes INTEGER DEFAULT 0,
    total_failures INTEGER DEFAULT 0,
    FOREIGN KEY (schedule_id) REFERENCES schedules(id)
);

-- Create indexes for performance
CREATE INDEX idx_executions_schedule_id ON executions(schedule_id);
CREATE INDEX idx_executions_trigger_time ON executions(trigger_time);
CREATE INDEX idx_executions_status ON executions(status);
```

**Querying Examples:**

```powershell
# Show all failed tasks in last 7 days
$query = @"
SELECT s.id, s.config->>'name' as name, e.trigger_time, e.exit_code, e.output
FROM executions e
JOIN schedules s ON e.schedule_id = s.id
WHERE e.status = 'failed' AND e.trigger_time > datetime('now', '-7 days')
ORDER BY e.trigger_time DESC
"@

# Find tasks that haven't run in 24h (potential stuck/missed tasks)
$query = @"
SELECT s.id, s.config->>'name' as name, st.last_run, st.next_run
FROM state st
JOIN schedules s ON st.schedule_id = s.id
WHERE st.last_run < datetime('now', '-24 hours')
  AND s.enabled = 1
"@

# Show task with highest failure rate
$query = @"
SELECT schedule_id, total_executions, total_failures,
       ROUND(100.0 * total_failures / total_executions, 2) as failure_rate_pct
FROM state
WHERE total_executions > 0
ORDER BY failure_rate_pct DESC
LIMIT 10
"@
```

---

## Integration with ralph-watch.ps1

**Current ralph-watch flow:**
```powershell
while ($true) {
    git pull
    Invoke-SquadScheduler  # ← Evaluates schedule.json
    agency copilot --autopilot -p "Ralph, Go!"
    Start-Sleep -Seconds 300
}
```

**Enhanced ralph-watch flow (v2):**
```powershell
param(
    [int]$IntervalSeconds = 300,
    [switch]$EnableWindowsScheduler = $false
)

# One-time setup: register Windows Scheduled Tasks for persistence
if ($EnableWindowsScheduler) {
    Write-Host "🔧 Registering Windows Scheduled Tasks for persistence..."
    Invoke-SquadScheduler -Provider windows-scheduler -RegisterOnly
    Write-Host "✅ Tasks registered — schedules will survive machine reboots"
}

# Main loop
$round = 0
while ($true) {
    $round++
    Write-Host "━━━ Round $round $(Get-Date -Format 'HH:mm:ss') ━━━"
    
    # Evaluate schedules (with catch-up)
    Invoke-SquadScheduler -Provider local-polling -CatchUp
    
    # Update repository
    git pull --quiet
    
    # Spawn Agency Copilot for dynamic work
    agency copilot --yolo --autopilot -p "Ralph, Go! MAXIMIZE PARALLELISM..."
    
    # Log metrics
    Write-RalphLog -Round $round ...
    
    Start-Sleep -Seconds $IntervalSeconds
}
```

**Key Enhancements:**
1. **One-time setup flag** — `ralph-watch.ps1 -EnableWindowsScheduler` registers all tasks in Windows Task Scheduler for persistence
2. **Catch-up on startup** — If ralph-watch was down, scheduler detects missed tasks and runs them
3. **Provider priority** — ralph-watch uses `local-polling` provider by default, fallback to `github-actions` if local fails
4. **State database** — Replaces `schedule-state.json` with SQLite for queryable audit trail

---

## Migration Plan: v1 → v2 (6 Phases)

### Phase 1: Persistence Layer (Week 1)
**Goal:** Add SQLite database, migrate state tracking from JSON to database

**Deliverables:**
- [ ] Create `.squad/monitoring/scheduler.db` with tables: schedules, executions, state
- [ ] Migrate existing `schedule-state.json` data to database (one-time import)
- [ ] Update `Invoke-SquadScheduler.ps1` to read/write database instead of JSON
- [ ] Add helper functions: `Initialize-SchedulerDatabase`, `Get-ExecutionHistory`, `Get-ScheduleState`

**Testing:**
```powershell
# Verify database created and populated
Invoke-SquadScheduler -Initialize
sqlite3 .squad/monitoring/scheduler.db "SELECT COUNT(*) FROM schedules;"  # Should show 5 schedules

# Run scheduler, verify executions logged
Invoke-SquadScheduler -Provider local-polling
sqlite3 .squad/monitoring/scheduler.db "SELECT * FROM executions ORDER BY trigger_time DESC LIMIT 5;"
```

**Risk Mitigation:**
- Keep `schedule-state.json` as fallback for Phase 1 (dual-write)
- If database fails to initialize, fall back to JSON-based state

---

### Phase 2: Provider Abstraction (Week 2)
**Goal:** Refactor provider logic into pluggable adapters

**Deliverables:**
- [ ] Create `.squad/scheduler/providers/` directory
- [ ] Implement `ISchedulerProvider` base class
- [ ] Implement providers:
  - `LocalPollingProvider.ps1` (existing inline logic extracted)
  - `GitHubActionsProvider.ps1` (workflow dispatch via gh CLI)
  - `CopilotAgentProvider.ps1` (agency copilot spawning)
- [ ] Update `Invoke-SquadScheduler.ps1` to use provider abstraction
- [ ] Add provider selection logic: `Select-Provider -Schedule $schedule -Providers @('local-polling', 'github-actions')`

**Testing:**
```powershell
# Test local-polling provider
Invoke-SquadScheduler -Provider local-polling -TaskId daily-rp-briefing -DryRun

# Test GitHub Actions provider
Invoke-SquadScheduler -Provider github-actions -TaskId daily-digest -DryRun

# Test provider fallback (disable local, ensure GitHub used)
Invoke-SquadScheduler -Provider auto -TaskId daily-digest
# Verify: execution record shows provider='github-actions'
```

---

### Phase 3: Catch-Up Logic (Week 3)
**Goal:** Implement missed task detection and catch-up execution

**Deliverables:**
- [ ] Add `trigger.catchUp` and `trigger.catchUpWindowMinutes` fields to schedule.json schema
- [ ] Implement `Find-MissedExecutions` function in scheduler engine
- [ ] On ralph-watch startup, detect tasks that missed their window
- [ ] Execute missed tasks with `context.catchUp = true` flag
- [ ] Update state table to track missed vs. on-time executions

**Testing Scenario:**
```powershell
# Simulate missed execution
# 1. Edit daily-rp-briefing trigger time to 5 minutes ago
# 2. Stop ralph-watch for 10 minutes
# 3. Start ralph-watch with -CatchUp flag
# 4. Verify briefing runs immediately with catch-up flag
# 5. Check database: execution record has context='{"catchUp":true}'
```

---

### Phase 4: Windows Task Scheduler Integration (Week 4)
**Goal:** Persistent scheduling across machine reboots

**Deliverables:**
- [ ] Implement `WindowsTaskSchedulerProvider.ps1`
- [ ] Add `-RegisterOnly` flag to `Invoke-SquadScheduler.ps1` for one-time setup
- [ ] Create helper: `Convert-CronToWindowsTrigger` (cron → Windows trigger object)
- [ ] Update `ralph-watch.ps1` with `-EnableWindowsScheduler` setup flag
- [ ] Document: "After machine reboot, Windows Scheduled Tasks will trigger even if ralph-watch isn't running"

**Testing:**
```powershell
# One-time setup: register all tasks
ralph-watch.ps1 -EnableWindowsScheduler

# Verify tasks registered
Get-ScheduledTask -TaskName "Squad_*" | Format-Table TaskName, State, NextRunTime

# Simulate reboot: kill ralph-watch, wait for scheduled trigger
# Verify: Windows Scheduled Task executes script, updates database
```

**Limitations:**
- Windows-only (Linux/Mac use cron integration in Phase 5)
- Requires local machine to be on (not for cloud-only scenarios)

---

### Phase 5: GitHub Actions Integration (Week 5)
**Goal:** Unify GitHub Actions cron workflows with central schedule.json

**Current Problem:** Workflows have hardcoded cron schedules, not synced with schedule.json  
**Solution:** Generate workflow files from schedule.json, or have workflows read schedule dynamically

**Option A: Generate Workflows (Recommended)**
```powershell
# .squad/scripts/Sync-WorkflowSchedules.ps1
# Reads schedule.json, regenerates workflow files with correct cron expressions

$schedules = Get-Content .squad/schedule.json | ConvertFrom-Json
foreach ($schedule in $schedules.schedules) {
    if ($schedule.task.type -eq 'workflow') {
        $workflowPath = $schedule.task.ref
        $cronExpr = $schedule.trigger.expression
        
        # Update workflow YAML with correct cron schedule
        Update-WorkflowCron -Path $workflowPath -Cron $cronExpr
    }
}
```

**Option B: Dynamic Workflow Dispatch (Simpler)**
```yaml
# squad-scheduler-dispatch.yml (single workflow for all scheduled tasks)
name: Squad Scheduler Dispatch

on:
  schedule:
    - cron: '*/5 * * * *'  # Every 5 minutes
  workflow_dispatch:

jobs:
  evaluate-schedules:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - name: Evaluate schedules
        run: |
          pwsh .squad/scripts/Invoke-SquadScheduler.ps1 -Provider github-actions
```

**Deliverables:**
- [ ] Choose Option A or B (recommend Option B for simplicity)
- [ ] Implement workflow generation script if Option A
- [ ] Update existing workflows to use `workflow_dispatch` only (remove hardcoded cron)
- [ ] Document: "All cron schedules now centralized in schedule.json"

---

### Phase 6: Observability Dashboard (Week 6)
**Goal:** Web UI to view scheduled tasks, execution history, and trigger next runs

**Deliverables:**
- [ ] Create `.squad/dashboard/scheduler.html` (static HTML page)
- [ ] JavaScript queries `scheduler.db` via API endpoint or direct file read (if SQLite WASM)
- [ ] Display:
  - All schedules (id, name, next run time, last run status)
  - Execution history (last 50 runs, filterable by schedule/status)
  - Failed tasks (with retry count, failure reason)
  - "Trigger Now" button for manual execution
- [ ] Integrate with existing Squad Dashboard

**UI Mockup:**
```
┌─────────────────────────────────────────────────────────────────┐
│ Squad Scheduler Dashboard                                       │
├─────────────────────────────────────────────────────────────────┤
│ Schedules (5 active)                                            │
│ ┌────────────────┬───────────────────────┬──────────┬─────────┐ │
│ │ Name           │ Next Run              │ Status   │ Actions │ │
│ ├────────────────┼───────────────────────┼──────────┼─────────┤ │
│ │ Ralph Heartbt  │ 2025-01-21 10:05 UTC  │ ✅ OK     │ [Run]   │ │
│ │ Daily Digest   │ 2025-01-22 08:00 UTC  │ ✅ OK     │ [Run]   │ │
│ │ RP Briefing    │ 2025-01-22 07:00 Asia │ ⚠️ Failed │ [Run]   │ │
│ │ ADR Check      │ 2025-01-22 07:00 UTC  │ ✅ OK     │ [Run]   │ │
│ │ Upstream Sync  │ 2025-01-27 02:00 UTC  │ ⏸️ Idle   │ [Run]   │ │
│ └────────────────┴───────────────────────┴──────────┴─────────┘ │
│                                                                 │
│ Recent Executions (last 24h)                                    │
│ ┌──────────────┬────────────────┬──────────┬──────┬──────────┐ │
│ │ Time         │ Schedule       │ Provider │ Exit │ Duration │ │
│ ├──────────────┼────────────────┼──────────┼──────┼──────────┤ │
│ │ 10:00:03 UTC │ Ralph Heartbt  │ local    │ 0    │ 45s      │ │
│ │ 09:55:01 UTC │ Ralph Heartbt  │ local    │ 0    │ 52s      │ │
│ │ 09:50:02 UTC │ Ralph Heartbt  │ local    │ 0    │ 48s      │ │
│ │ 08:00:15 UTC │ Daily Digest   │ gh-actns │ 0    │ 12s      │ │
│ │ 07:00:22 UTC │ RP Briefing    │ local    │ 1    │ 8s       │ │
│ └──────────────┴────────────────┴──────────┴──────┴──────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Provider Decision Matrix

**When to use which provider?**

| Scenario | Recommended Provider | Why |
|----------|---------------------|-----|
| ralph-watch running locally | `local-polling` | Fastest execution, no API rate limits |
| Machine must survive reboots | `windows-scheduler` | Persistent, runs even if ralph-watch stopped |
| Cloud-only execution (no local machine) | `github-actions` | Runs on GitHub runners, no local dependency |
| Copilot-driven tasks (ADR checks, complex queries) | `copilot-agent` | Leverages Agency Copilot sessions |
| External system triggers (webhooks) | `webhook` | HTTP endpoint receives POST, triggers task |
| Multi-provider redundancy | `["local-polling", "github-actions"]` | Fallback if primary fails |

**Provider Priority Order (default):**
1. `local-polling` (if ralph-watch running)
2. `windows-scheduler` (if Windows and task registered)
3. `github-actions` (fallback for workflows)
4. `copilot-agent` (for copilot-driven tasks)
5. `webhook` (for external triggers)

---

## Security Considerations

### Secrets Management
**Problem:** Schedules may need API keys, tokens, webhook URLs  
**Solution:** Use environment variables, never hardcode in schedule.json

```json
{
  "id": "send-metrics",
  "task": {
    "type": "script",
    "command": ".squad/scripts/send-metrics.ps1 -ApiKey $env:METRICS_API_KEY"
  }
}
```

**Best Practices:**
- Store secrets in `$env:USERPROFILE\.squad\secrets.env` (gitignored)
- Source secrets file in ralph-watch.ps1: `. .squad/secrets.env`
- For GitHub Actions: use repository secrets, reference via `${{ secrets.API_KEY }}`

### Execution Sandboxing
**Problem:** Malicious schedule could execute arbitrary code  
**Solution:** Validate schedule.json schema, restrict task types

```powershell
# In Invoke-SquadScheduler.ps1
function Test-ScheduleSecurity {
    param($Schedule)
    
    # Only allow approved task types
    $allowedTypes = @('script', 'workflow', 'copilot')
    if ($Schedule.task.type -notin $allowedTypes) {
        throw "Invalid task type: $($Schedule.task.type)"
    }
    
    # Script paths must be within .squad/ directory
    if ($Schedule.task.type -eq 'script') {
        $scriptPath = Resolve-Path $Schedule.task.command -ErrorAction SilentlyContinue
        if (-not $scriptPath.Path.StartsWith((Resolve-Path .squad).Path)) {
            throw "Script path must be within .squad/ directory"
        }
    }
    
    # No privilege escalation
    if ($Schedule.task.command -match 'runas|sudo|su ') {
        throw "Privilege escalation not allowed in scheduled tasks"
    }
}
```

### Audit Trail
**Requirement:** Every task execution must be logged for accountability  
**Implementation:** SQLite database ensures immutable audit trail

```sql
-- Query: Who triggered task X at time Y?
SELECT e.id, e.schedule_id, e.trigger_time, e.provider, e.context
FROM executions e
WHERE e.schedule_id = 'daily-rp-briefing' AND e.trigger_time = '2025-01-21 07:00:00';

-- Result shows: triggered by ralph-watch via local-polling provider
```

---

## Success Criteria

| Requirement | Implementation | Verification |
|-------------|----------------|--------------|
| ✅ **Single source of truth** | All schedules in `.squad/schedule.json` | `grep -r "cron:" .github/workflows/` returns 0 hardcoded schedules |
| ✅ **Never forgets tasks** | SQLite database persists state | Kill ralph-watch, restart → missed tasks caught up |
| ✅ **Provider-agnostic** | Plugin architecture, clean interface | Add Azure DevOps provider without changing engine code |
| ✅ **Triggers itself** | Windows Scheduled Tasks + GitHub Actions cron | Machine reboot → tasks still execute |
| ✅ **Persistent** | Database survives process restarts | `scheduler.db` contains execution history from 30 days ago |
| ✅ **Observable** | Dashboard + queryable database | Ask "why didn't X run?" → query `executions` table shows failure reason |
| ✅ **Secure** | Schema validation, sandboxed execution | Malicious schedule rejected by `Test-ScheduleSecurity` |

---

## Rollout Strategy

### Option A: Phased Migration (Recommended for production)
- Phase 1-3: Add features without breaking existing workflows
- Phase 4-6: Migrate workflows to central scheduler
- Keep ralph-watch.ps1 as primary driver during transition
- Full cutover after 6 weeks of testing

### Option B: Big Bang (Fast track for dev environments)
- Implement all 6 phases in parallel
- Replace ralph-watch.ps1 with new scheduler engine
- Higher risk, faster delivery (2-3 weeks)

### Option C: Hybrid (Best of both)
- Deploy persistence layer (Phase 1) immediately
- Run existing ralph-watch.ps1 with database backend
- Add providers incrementally (Phase 2-4) over 4 weeks
- Dashboard (Phase 6) can be skipped if CLI tools sufficient

**Recommendation:** **Option C (Hybrid)** — minimizes disruption, enables iterative improvements, delivers value quickly

---

## Alternative Designs Considered

### Alternative 1: Use Existing Orchestrators (Airflow, Temporal, Prefect)
**Pros:** Battle-tested, rich features (DAGs, retries, observability)  
**Cons:** Heavy dependencies, overkill for Squad's needs, not provider-agnostic  
**Decision:** Rejected — Squad needs lightweight, embeddable scheduler

### Alternative 2: Cloud-Only (GitHub Actions Cron Only)
**Pros:** No local machine dependency, fully managed  
**Cons:** Rate limits, runner quotas, can't trigger on local events  
**Decision:** Rejected — Squad runs in hybrid environments (local + cloud)

### Alternative 3: Cron + Systemd (Unix-style)
**Pros:** Standard Unix tools, well-understood  
**Cons:** Not Windows-compatible, no central control  
**Decision:** Rejected — Squad targets Windows + cross-platform

### Alternative 4: Build on Top of Quartz.NET
**Pros:** Enterprise-grade .NET scheduler, persistent job store  
**Cons:** .NET dependency, learning curve, not PowerShell-native  
**Decision:** Rejected for v1, consider for v3 if scaling issues arise

---

## Open Questions & User Decisions Needed

### Decision Point 1: Primary Provider Strategy
**Question:** Should Squad rely primarily on local polling (ralph-watch) or persistent scheduling (Windows Task Scheduler)?

**Options:**
- **A. Local Polling Primary** — ralph-watch.ps1 runs continuously, Windows Scheduler as backup
- **B. Persistent Primary** — Windows Scheduled Tasks run all schedules, ralph-watch optional
- **C. Hybrid** — Critical tasks use Windows Scheduler, dynamic tasks use ralph-watch

**Recommendation:** **Option C (Hybrid)** — Best of both worlds

### Decision Point 2: GitHub Actions Workflow Sync
**Question:** How to unify GitHub Actions cron schedules with schedule.json?

**Options:**
- **A. Generate Workflows** — Script reads schedule.json, writes workflow YAML files
- **B. Single Dispatcher** — One workflow calls Invoke-SquadScheduler.ps1 every 5 minutes
- **C. Keep Separate** — GitHub Actions workflows remain independent, schedule.json for local only

**Recommendation:** **Option B (Single Dispatcher)** — Simpler, less brittle

### Decision Point 3: Database Choice
**Question:** SQLite vs. JSON files for state management?

**Options:**
- **A. SQLite** — Queryable, ACID transactions, schema validation
- **B. JSON Files** — Simple, no dependencies, human-readable
- **C. Hybrid** — SQLite for audit trail, JSON for current state

**Recommendation:** **Option A (SQLite)** — Better for long-term reliability

---

## Next Steps

### Immediate Actions (This PR)
1. ✅ Document design (this file)
2. ⬜ Get user feedback on decision points
3. ⬜ Create SQLite schema file (`.squad/scheduler/schema.sql`)
4. ⬜ Prototype Phase 1 (persistence layer) in separate branch
5. ⬜ Update `.squad/schedule.json` with catchUp fields

### Week 1 (Phase 1 Implementation)
1. Implement `Initialize-SchedulerDatabase` function
2. Migrate `schedule-state.json` to SQLite
3. Update `Invoke-SquadScheduler.ps1` to use database
4. Test on tamresearch1 repository with existing schedules

### Week 2-6 (Remaining Phases)
Follow migration plan outlined in Phase 2-6 sections above

---

## References

- **Issue #199:** Can Squad have its own schedule?  
  https://github.com/tamirdresher_microsoft/tamresearch1/issues/199

- **Related Files:**
  - `.squad/schedule.json` — Current schedule definitions
  - `.squad/scripts/Invoke-SquadScheduler.ps1` — Existing scheduler engine (v1)
  - `ralph-watch.ps1` — Polling daemon that triggers scheduler
  - `.squad/implementations/squad-scheduler-design.md` — Original design doc (v1)

- **Squad Documentation:**
  - `.squad/decisions.md` — Team decision log
  - `.squad/agents/belanna/history.md` — Infrastructure learnings
  - `.squad/agents/belanna/charter.md` — B'Elanna's role and responsibilities

---

**Status:** Design complete, awaiting user decisions on:
1. Primary provider strategy (local vs. persistent vs. hybrid)
2. GitHub Actions integration approach (generate workflows vs. dispatcher)
3. Approval to begin Phase 1 implementation

**Estimated Effort:** 6 weeks for full implementation (all 6 phases)  
**Estimated Effort (MVP):** 2 weeks for Phases 1-3 (persistence + catch-up + provider abstraction)

---

*— B'Elanna*  
*Infrastructure Expert, Squad Team*  
*"If it ships, it ships reliably. Automates everything twice."*
