# Persistent Squad Sessions on Cloud PCs & DevBoxes

**Author:** Seven (Research & Docs)
**Date:** 2026-03-16
**Status:** Complete
**Issue:** #700
**Audience:** Anyone running Squad/Ralph on Windows Cloud PCs or DevBoxes

---

## Problem Statement

Ralph — the Squad automation loop — needs to run continuously (24/7) on Windows machines. On Cloud PCs and Microsoft Dev Box, sessions disconnect due to idle timeouts, RDP disconnections, and auto-stop policies. When the session disconnects, foreground processes (including Ralph) are killed, breaking the automation pipeline.

**Symptoms reported:**
- Error code `0x3` with extended error code `0x1c` (RDP protocol error / forced disconnect)
- Cloud PC locks after idle timeout → Ralph process terminated
- DevBox auto-stops after configured inactivity period → everything killed
- After reconnect, Ralph is not running — requires manual restart

**Impact:** Lost automation cycles, missed issue triage, stale heartbeats, unprocessed cross-machine tasks, and gaps in monitoring coverage.

---

## Root Causes

### 1. Windows Idle Lock Policy

Windows locks the screen after a configurable idle timeout (default: varies by GPO). On corporate Cloud PCs, Group Policy typically enforces a 10–15 minute screen lock.

```
Computer Configuration → Policies → Windows Settings → Security Settings
  → Local Policies → Security Options
    → "Interactive logon: Machine inactivity limit" = 600 seconds (10 min)
```

**What happens:** Screen locks → no input detected → Cloud PC considers session idle.

### 2. RDP Session Timeout

Remote Desktop connections have their own disconnect timers. Group Policy or local settings control:

| Setting | Registry Path | Effect |
|---------|--------------|--------|
| Idle session limit | `HKLM\...\Terminal Server\MaxIdleTime` | Disconnects after N minutes idle |
| Disconnected session limit | `HKLM\...\Terminal Server\MaxDisconnectionTime` | Terminates session after disconnect |
| Active session limit | `HKLM\...\Terminal Server\MaxConnectionTime` | Hard cap on session duration |

When an RDP session disconnects, processes launched in that session can be terminated depending on the configuration.

### 3. Cloud PC / DevBox Power Management

**DevBox auto-stop** is the primary killer. Microsoft Dev Box supports auto-stop schedules and hibernate-on-disconnect:

- **Auto-stop schedule:** DevBox powers down at a configured time (e.g., 7 PM daily)
- **Hibernate on disconnect:** When you disconnect RDP, the DevBox hibernates after a grace period
- **Idle shutdown:** Some configurations shut down after extended idle periods

**Key difference from regular VMs:** DevBox auto-stop is managed at the Dev Center level, not just local GPO. Individual users may not have permission to change it.

### 4. Process Session Binding

Processes started in an interactive RDP session are bound to that session. When the session ends:
- **Foreground window processes:** Killed immediately
- **Background processes (Start-Process):** May survive disconnect but are killed on logoff/shutdown
- **Windows Services:** Survive everything — they run in Session 0
- **Scheduled Tasks:** Run independently of any user session

---

## Our Existing Solutions

This repo already has several scripts addressing parts of this problem. Here's what exists and how it works.

### `ralph-watch.ps1` — The Core Loop

**Location:** Repository root
**Purpose:** Runs Ralph in a continuous loop with 5-minute intervals

Key resilience features already built in:

| Feature | How It Works |
|---------|-------------|
| **Single-instance guard** | Named mutex (`Global\RalphWatch_tamresearch1`) + lockfile (`.ralph-watch.lock`) + process scan prevents duplicates |
| **Stale process cleanup** | Kills any leftover ralph-watch processes for the same repo on startup |
| **Round timeout** | 20-minute kill switch per round prevents hangs (`$roundTimeoutMinutes = 20`) |
| **Heartbeat file** | Writes JSON heartbeat to `~/.squad/ralph-heartbeat-{repo}.json` every 30 seconds during rounds |
| **Log rotation** | Caps at 500 entries / 1 MB to prevent disk fill |
| **Self-restart on update** | Detects when `ralph-watch.ps1` changes via git pull and relaunches itself |
| **Consecutive failure alerting** | Sends Teams webhook after 3+ consecutive failures |
| **gh auth self-healing** | Detects and fixes broken GitHub CLI auth via `scripts/ralph-self-heal.ps1` |
| **Git conflict auto-resolution** | Accepts "theirs" on merge conflicts to avoid blocking |

**Limitation:** Ralph-watch runs as a foreground PowerShell process. If the session ends, it dies.

### `scripts/keep-devbox-alive.ps1` — Idle Prevention

**Location:** `scripts/keep-devbox-alive.ps1`
**Purpose:** Prevents DevBox auto-stop by simulating activity

```powershell
# Runs every 4 minutes:
# 1. Moves mouse 1 pixel and back (user32.dll P/Invoke)
# 2. Touches a heartbeat file (~/.devbox-keepalive)
```

**How to deploy:**
```powershell
Start-Process pwsh -ArgumentList "-NoProfile -File scripts/keep-devbox-alive.ps1" -WindowStyle Hidden
```

**Limitation:** Only prevents idle detection — doesn't survive session disconnect or machine shutdown.

### `scripts/devbox-startup.ps1` — Startup Orchestrator

**Location:** `scripts/devbox-startup.ps1`
**Purpose:** Launches all persistent processes on DevBox boot

Starts (in order):
1. Keep-alive script (hidden window)
2. Ralph for `tamresearch1` (normal window)
3. Ralph for `tamresearch1-research` (normal window, if repo exists)

**Limitation:** Must be manually triggered or placed in shell:startup. Does not handle reconnect scenarios.

### `scripts/devbox-autostart.ps1` — Scheduled Task Auto-Start

**Location:** `scripts/devbox-autostart.ps1`
**Purpose:** Designed to run as a Windows Scheduled Task on logon + session unlock

Key behaviors:
- Checks for existing lockfiles before starting duplicate processes
- Starts Ralph for both production and research repos
- Starts GitHub Actions runner (if installed)
- Starts Agency Copilot session
- Logs everything to `~/.squad/devbox-autostart.log`

**Registration command (from the script comments):**
```powershell
# Register as "SquadAutoStart" scheduled task with AtLogOn + SessionUnlock triggers
```

**Limitation:** The script references hardcoded paths. Session unlock trigger is the right idea but the Task Scheduler registration command isn't included in the script itself.

### `scripts/ralph-heartbeat.ps1` — Cross-Machine Heartbeat

**Location:** `scripts/ralph-heartbeat.ps1`
**Purpose:** Writes machine-specific heartbeat for cross-machine monitoring

Writes to `~/.squad/heartbeats/{COMPUTERNAME}.json`. The Telegram bot's `/status` command reads these to show which Ralphs are alive. Heartbeats older than 10 minutes are considered stale.

### `scripts/cross-machine-watcher.ps1` — Cross-Machine Task Queue

**Location:** `scripts/cross-machine-watcher.ps1`
**Purpose:** Git-based task queuing between machines

Called by Ralph each cycle. Reads YAML task files from `.squad/cross-machine/tasks/`, executes whitelisted commands, writes results to `.squad/cross-machine/results/`. Auto-registers the machine hostname in the config.

### `start-all-ralphs.ps1` — Multi-Repo Launcher

**Location:** Repository root
**Purpose:** Launches Ralph for both `tamresearch1` and `tamresearch1-research`

Simple launcher — spawns `pwsh.exe` with `Start-Process` for each repo's `ralph-watch.ps1`.

### `scripts/ralph-self-heal.ps1` — Auth Recovery

**Location:** `scripts/ralph-self-heal.ps1`
**Purpose:** Detects and fixes broken GitHub CLI auth

Can even use Playwright browser automation to complete OAuth device flows unattended. Designed for environments where Ralph needs to fix its own auth without human intervention.

### `scripts/recover-sessions.ps1` — Session Discovery

**Location:** `scripts/recover-sessions.ps1`
**Purpose:** Finds and resumes recently closed Copilot CLI sessions

Queries the session store database for recent sessions and offers to resume them. Useful after unexpected disconnects.

---

## Solution Approaches (Ranked by Reliability)

### Tier 1: Windows Scheduled Task (★★★★★ — Recommended)

**Reliability:** Highest. Survives session disconnect, logoff, and machine reboot.
**Complexity:** Low. No extra software needed.

A Scheduled Task runs in the Task Scheduler service (Session 0 or the user's session, depending on configuration). It can be triggered on logon, session unlock, and at recurring intervals.

#### Recipe: Register Ralph as a Scheduled Task

```powershell
# Register Ralph as a Scheduled Task that:
# - Starts on logon
# - Restarts on session unlock (reconnect)
# - Auto-restarts on failure
# - Runs whether user is logged on or not

$repoRoot = "C:\Users\tamirdresher\source\repos\tamresearch1"
$taskName = "SquadRalph-tamresearch1"

# Create the action
$action = New-ScheduledTaskAction `
    -Execute "pwsh.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$repoRoot\ralph-watch.ps1`"" `
    -WorkingDirectory $repoRoot

# Create triggers
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
$triggerStartup = New-ScheduledTaskTrigger -AtStartup

# Settings: restart on failure, don't stop on idle, run whether logged on or not
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -DontStopOnIdleEnd `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Days 365)

# Register the task
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger @($triggerLogon, $triggerStartup) `
    -Settings $settings `
    -Description "Squad Ralph automation loop for tamresearch1" `
    -RunLevel Highest

Write-Host "Task '$taskName' registered. Ralph will start on logon and machine startup."
```

#### Add Session Unlock Trigger (Reconnect Resilience)

The `New-ScheduledTaskTrigger` cmdlet doesn't directly support session unlock, but you can add it via XML or COM:

```powershell
# Add SessionUnlock trigger via COM (runs on reconnect after RDP disconnect)
$taskName = "SquadRalph-tamresearch1"
$scheduler = New-Object -ComObject Schedule.Service
$scheduler.Connect()
$folder = $scheduler.GetFolder('\')
$task = $folder.GetTask($taskName)
$definition = $task.Definition

# Create SessionUnlock trigger (type 11 = SessionStateChange)
$trigger = $definition.Triggers.Create(11)  # TASK_TRIGGER_SESSION_STATE_CHANGE
$trigger.StateChange = 8  # TASK_SESSION_UNLOCK
$trigger.UserId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$trigger.Enabled = $true

# Also add SessionConnect trigger (type 11, state 3) for new RDP connections
$connectTrigger = $definition.Triggers.Create(11)
$connectTrigger.StateChange = 3  # TASK_SESSION_CONNECT (remote connect)
$connectTrigger.UserId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$connectTrigger.Enabled = $true

$folder.RegisterTaskDefinition($taskName, $definition, 6, $null, $null, 3)
Write-Host "SessionUnlock + SessionConnect triggers added to '$taskName'"
```

#### Recipe: Register Keep-Alive as a Scheduled Task

```powershell
$repoRoot = "C:\Users\tamirdresher\source\repos\tamresearch1"
$taskName = "SquadKeepAlive"

$action = New-ScheduledTaskAction `
    -Execute "pwsh.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$repoRoot\scripts\keep-devbox-alive.ps1`"" `
    -WorkingDirectory $repoRoot

$trigger = New-ScheduledTaskTrigger -AtLogOn

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -DontStopOnIdleEnd `
    -RestartCount 5 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Days 365)

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Prevents DevBox idle timeout by simulating activity"

Write-Host "Task '$taskName' registered."
```

#### Complete Setup Script

```powershell
# One-shot setup: Register all Squad scheduled tasks
# Run this ONCE on each machine

$repoRoot = "C:\Users\tamirdresher\source\repos\tamresearch1"

# 1. Ralph automation loop
& "$repoRoot\scripts\devbox-autostart.ps1"  # or use the recipe above

# 2. Keep-alive
# (use recipe above)

# 3. Verify
Get-ScheduledTask | Where-Object { $_.TaskName -match "Squad" } |
    Format-Table TaskName, State, @{N='Triggers';E={$_.Triggers.Count}}
```

### Tier 2: Windows Service via NSSM (★★★★☆)

**Reliability:** Very high. Runs as a true Windows service in Session 0.
**Complexity:** Medium. Requires NSSM installation.

[NSSM (Non-Sucking Service Manager)](https://nssm.cc/) wraps any executable as a Windows service with automatic restart, logging, and dependency management.

#### Recipe: Install Ralph as a Windows Service

```powershell
# 1. Install NSSM
winget install nssm

# 2. Register Ralph as a service
$repoRoot = "C:\Users\tamirdresher\source\repos\tamresearch1"
nssm install SquadRalph "pwsh.exe" "-NoProfile -ExecutionPolicy Bypass -File `"$repoRoot\ralph-watch.ps1`""
nssm set SquadRalph AppDirectory "$repoRoot"
nssm set SquadRalph Description "Squad Ralph automation loop"
nssm set SquadRalph Start SERVICE_AUTO_START

# 3. Configure restart behavior
nssm set SquadRalph AppExit Default Restart
nssm set SquadRalph AppRestartDelay 60000  # 60 seconds between restarts

# 4. Configure logging
nssm set SquadRalph AppStdout "$env:USERPROFILE\.squad\ralph-service-stdout.log"
nssm set SquadRalph AppStderr "$env:USERPROFILE\.squad\ralph-service-stderr.log"
nssm set SquadRalph AppRotateFiles 1
nssm set SquadRalph AppRotateBytes 1048576  # 1 MB

# 5. Set environment (important: gh CLI needs PATH and HOME)
nssm set SquadRalph AppEnvironmentExtra "HOME=$env:USERPROFILE" "GH_TOKEN=$env:GH_TOKEN"

# 6. Start the service
nssm start SquadRalph
```

**Caveats:**
- Services run in Session 0 — no GUI interaction, no desktop access
- `keep-devbox-alive.ps1` mouse jiggle won't work from Session 0 (no desktop)
- Environment variables need explicit configuration
- `gh auth` token must be set via `GH_TOKEN` env var, not interactive login

### Tier 3: PowerShell Background Job with Detached Process (★★★☆☆)

**Reliability:** Medium. Survives window close but not logoff/reboot.
**Complexity:** Low. No installation needed.

```powershell
# Start Ralph as a detached process that survives the terminal closing
$repoRoot = "C:\Users\tamirdresher\source\repos\tamresearch1"
Start-Process pwsh.exe `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$repoRoot\ralph-watch.ps1" `
    -WorkingDirectory $repoRoot `
    -WindowStyle Hidden

# Verify it's running
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'ralph-watch' } |
    Select-Object ProcessId, @{N='Started';E={$_.CreationDate}}, CommandLine
```

**When to use:** Quick one-off sessions where you don't need reboot survival. This is what `start-all-ralphs.ps1` and `devbox-startup.ps1` already do.

### Tier 4: Wrapper with Auto-Restart (★★★☆☆)

**Reliability:** Medium. Adds crash recovery around the process.
**Complexity:** Low.

```powershell
# ralph-guardian.ps1 — Restarts ralph-watch.ps1 if it exits unexpectedly
$repoRoot = "C:\Users\tamirdresher\source\repos\tamresearch1"
$maxRestarts = 10
$restartDelay = 30  # seconds

$restartCount = 0
while ($restartCount -lt $maxRestarts) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Starting Ralph (attempt $($restartCount + 1))..." -ForegroundColor Cyan

    $process = Start-Process pwsh.exe `
        -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$repoRoot\ralph-watch.ps1" `
        -WorkingDirectory $repoRoot `
        -PassThru -Wait

    $exitCode = $process.ExitCode
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Ralph exited with code $exitCode" -ForegroundColor Yellow

    if ($exitCode -eq 0) {
        Write-Host "Ralph exited cleanly. Not restarting." -ForegroundColor Green
        break
    }

    $restartCount++
    Write-Host "Restarting in $restartDelay seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds $restartDelay
}

if ($restartCount -ge $maxRestarts) {
    Write-Host "Max restarts ($maxRestarts) reached. Giving up." -ForegroundColor Red
}
```

---

## DevBox-Specific Guidance

### Auto-Stop Schedule Configuration

DevBox auto-stop is configured at the **Dev Center project level** by an administrator. Individual developers typically cannot change it. However:

#### Check Current Auto-Stop Settings

```powershell
# Via Azure CLI (requires contributor access to the Dev Center)
az devcenter dev dev-box show --dev-box-name <name> --project <project> --query "provisioningState"
```

#### Request Auto-Stop Exemption

If Ralph needs to run 24/7, work with your Dev Center admin to:
1. Create a separate Dev Box pool with auto-stop disabled
2. Set auto-stop to a very late hour (e.g., 2 AM) with auto-start at 6 AM
3. Use the keep-alive script to prevent idle-triggered stops during working hours

#### DevBox Hibernate vs Shutdown

| Event | Process Behavior | Ralph Impact |
|-------|-----------------|--------------|
| **Hibernate** | Processes frozen to disk, restored on wake | ✅ Ralph survives (resumes where it left off) |
| **Shutdown** | All processes terminated | ❌ Ralph dies — needs auto-restart mechanism |
| **Auto-stop** | Depends on config: hibernate or deallocate | Check your pool config |

**Check your pool's stop behavior:**
```powershell
# If your DevBox hibernates on auto-stop, Ralph will resume automatically.
# If it deallocates, you need a startup trigger (Scheduled Task).
az devcenter admin pool show --pool-name <pool> --project <project> --dev-center <center> --query "stopOnDisconnect"
```

### Prevent Auto-Stop Without Violating IT Policy

The `keep-devbox-alive.ps1` approach (mouse jiggle) is the simplest and generally acceptable:

1. It only moves the mouse 1 pixel and back — invisible to the user
2. It touches a local file — no network traffic generated
3. It runs every 4 minutes — well within any idle timeout

**If your IT policy prohibits simulated input**, alternatives:
- Request a longer idle timeout from your Dev Center admin
- Use a Scheduled Task with a 4-minute repeating trigger to touch a file (no mouse jiggle)
- Configure the DevBox pool for hibernate-on-disconnect instead of deallocate

### DevBox Auto-Start on Boot

```powershell
# Register the devbox-autostart.ps1 as a Scheduled Task
$repoRoot = "C:\Users\tamirdresher\source\repos\tamresearch1"

$action = New-ScheduledTaskAction `
    -Execute "pwsh.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$repoRoot\scripts\devbox-autostart.ps1`""

$triggers = @(
    (New-ScheduledTaskTrigger -AtLogOn),
    (New-ScheduledTaskTrigger -AtStartup)
)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -DontStopOnIdleEnd `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask `
    -TaskName "SquadDevBoxAutoStart" `
    -Action $action `
    -Trigger $triggers `
    -Settings $settings `
    -Description "Starts all Squad processes on DevBox boot/logon"
```

---

## Recommended Architecture

For a production-grade persistent Ralph deployment, combine these layers:

```
┌─────────────────────────────────────────────────────────┐
│                    Machine Boot / Logon                   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Scheduled Task: SquadDevBoxAutoStart             │   │
│  │ Triggers: AtStartup, AtLogon, SessionUnlock      │   │
│  │ Action: devbox-autostart.ps1                      │   │
│  └───────────────┬──────────────────────────────────┘   │
│                  │                                       │
│         ┌────────┼─────────┐                             │
│         ▼        ▼         ▼                             │
│  ┌──────────┐ ┌──────┐ ┌────────────┐                   │
│  │ Ralph    │ │ Keep │ │ GH Actions │                   │
│  │ Watch    │ │Alive │ │ Runner     │                   │
│  │ (pwsh)   │ │(pwsh)│ │ (optional) │                   │
│  └────┬─────┘ └──────┘ └────────────┘                   │
│       │                                                  │
│  ┌────┴──────────────────────────────────────────────┐  │
│  │ Per-Round Actions:                                 │  │
│  │  • Self-heal gh auth (ralph-self-heal.ps1)        │  │
│  │  • Cross-machine tasks (cross-machine-watcher.ps1)│  │
│  │  • Heartbeat updates (ralph-heartbeat.ps1)        │  │
│  │  • Stale work reclamation                         │  │
│  │  • Agency copilot execution                       │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Monitoring:                                       │   │
│  │  • Heartbeat JSON (~/.squad/ralph-heartbeat-*.json│   │
│  │  • Log file (~/.squad/ralph-watch-*.log)          │   │
│  │  • Lockfile (.ralph-watch.lock)                   │   │
│  │  • Teams webhook alerts on 3+ failures            │   │
│  │  • Telegram bot /status reads heartbeats          │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Layer Summary

| Layer | Script | Survives Disconnect? | Survives Reboot? | Purpose |
|-------|--------|---------------------|------------------|---------|
| **Trigger** | Scheduled Task | ✅ Yes | ✅ Yes | Starts everything |
| **Keep-alive** | `keep-devbox-alive.ps1` | ❌ No (needs restart) | ❌ No | Prevents idle timeout |
| **Ralph loop** | `ralph-watch.ps1` | ❌ No (needs restart) | ❌ No | Core automation |
| **Instance guard** | Named mutex + lockfile | N/A | N/A | Prevents duplicates |
| **Self-healing** | `ralph-self-heal.ps1` | N/A | N/A | Fixes auth issues |
| **Heartbeat** | `ralph-heartbeat.ps1` | N/A | N/A | Cross-machine visibility |
| **Stale detection** | Built into ralph-watch | N/A | N/A | Reclaims abandoned work |
| **Session recovery** | `recover-sessions.ps1` | N/A | N/A | Manual resume tool |

**The Scheduled Task is the linchpin.** Without it, everything else requires manual restart after a disconnect.

---

## Operational Runbook

### First-Time Setup on a New Machine

```powershell
# 1. Clone the repo
git clone https://github.com/tamirdresher_microsoft/tamresearch1
cd tamresearch1

# 2. Set up GitHub CLI auth
gh auth login

# 3. Load secrets
.\scripts\setup-secrets.ps1

# 4. Register Scheduled Tasks
.\scripts\devbox-autostart.ps1  # or run the Tier 1 recipes above

# 5. Verify Ralph is running
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'ralph-watch' }
Get-Content "$env:USERPROFILE\.squad\ralph-heartbeat-tamresearch1.json" | ConvertFrom-Json
```

### Check Ralph Health

```powershell
# Is Ralph running?
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'ralph-watch' } |
    Select-Object ProcessId, @{N='Uptime';E={(Get-Date) - $_.CreationDate}}, CommandLine

# Read heartbeat
$hb = Get-Content "$env:USERPROFILE\.squad\ralph-heartbeat-tamresearch1.json" | ConvertFrom-Json
$hb | Format-List

# Check scheduled task status
Get-ScheduledTask -TaskName "Squad*" | Format-Table TaskName, State, LastRunTime, LastTaskResult

# Read recent log entries
Get-Content "$env:USERPROFILE\.squad\ralph-watch-tamresearch1.log" -Tail 20

# Check lockfile
Get-Content ".ralph-watch.lock" | ConvertFrom-Json
```

### Recover After Unexpected Disconnect

```powershell
# 1. Check if Ralph restarted automatically (Scheduled Task)
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'ralph-watch' }

# 2. If not running, start manually
pwsh -NoProfile -File ralph-watch.ps1

# 3. Find and resume interrupted Copilot sessions
.\scripts\recover-sessions.ps1 -Hours 4

# 4. Check for orphaned claims on issues
gh issue list --label "ralph:$env:COMPUTERNAME:active" --json number,title
```

### Force Restart Ralph

```powershell
# 1. Find and stop existing Ralph
$ralph = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'ralph-watch' }
if ($ralph) { Stop-Process -Id $ralph.ProcessId -Force }

# 2. Clean up lockfile
Remove-Item ".ralph-watch.lock" -Force -ErrorAction SilentlyContinue

# 3. Restart
pwsh -NoProfile -ExecutionPolicy Bypass -File ralph-watch.ps1
```

---

## Monitoring & Alerting Checklist

| Check | Tool | Frequency | Action on Failure |
|-------|------|-----------|------------------|
| Ralph process alive | `ralph-watch.lock` / Process scan | Every round | Scheduled Task restarts |
| Heartbeat fresh (<10 min) | `ralph-heartbeat-*.json` | Telegram bot `/status` | Alert + investigate |
| Consecutive failures <3 | `ralph-watch.ps1` internal | Every round | Teams webhook alert |
| gh auth valid | `ralph-self-heal.ps1` | Every round | Auto-heal via Playwright |
| Cross-machine tasks processed | `cross-machine-watcher.ps1` | Every round | Logged, non-blocking |
| Scheduled Task enabled | `Get-ScheduledTask` | Manual / weekly | Re-register if missing |

---

## Decision Log

| Decision | Rationale |
|----------|-----------|
| **Scheduled Task over Windows Service** | Lower complexity, doesn't require NSSM, works with user-session tools (gh auth, mouse jiggle). Services run in Session 0 which limits GUI and auth tooling. |
| **Keep-alive via mouse jiggle** | Most reliable idle prevention. File-touch alone doesn't always prevent idle detection on Cloud PCs. |
| **Heartbeat via JSON file** | Simple, no infrastructure needed. Telegram bot and Squad Monitor already read these files. |
| **Git-based cross-machine coordination** | No new infrastructure (Redis, queues). Git is already the shared state. Trade-off: eventual consistency (~5 min). |
| **Named mutex for single-instance** | System-wide, survives process crashes (auto-released by OS). Lockfile alone has race conditions. |

---

## Known Limitations

1. **Scheduled Task requires admin to register** — First-time setup needs elevated privileges
2. **Keep-alive doesn't work from Session 0** — If running as a pure service, mouse jiggle fails
3. **DevBox auto-stop may override keep-alive** — If the Dev Center enforces a hard stop schedule, no amount of mouse jiggling prevents it
4. **gh auth tokens expire** — Self-heal handles scope issues but can't fix expired tokens without human intervention for the initial device flow
5. **Git conflicts during cross-machine coordination** — Ralph auto-resolves by accepting "theirs" but this can lose local changes

---

## References

| Resource | Location |
|----------|----------|
| Ralph Watch script | `ralph-watch.ps1` |
| DevBox startup | `scripts/devbox-startup.ps1` |
| DevBox auto-start | `scripts/devbox-autostart.ps1` |
| Keep-alive script | `scripts/keep-devbox-alive.ps1` |
| Ralph heartbeat | `scripts/ralph-heartbeat.ps1` |
| Ralph self-heal | `scripts/ralph-self-heal.ps1` |
| Cross-machine watcher | `scripts/cross-machine-watcher.ps1` |
| Session recovery | `scripts/recover-sessions.ps1` |
| Multi-machine design | `.squad/research/multi-machine-ralph-design.md` |
| Cross-machine README | `.squad/cross-machine/README.md` |
| Squad Monitor | `squad-monitor-standalone/README.md` |
| Start all Ralphs | `start-all-ralphs.ps1` |
