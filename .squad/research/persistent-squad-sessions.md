# Persistent Squad Sessions on Cloud PCs / DevBoxes

**Author:** Seven (Research & Docs)  
**Date:** 2026-07-17  
**Issue:** [#700](https://github.com/tamirdresher/tamresearch1/issues/700)  
**Related:** #615 (Keep DevBoxes always on), #346 (Multi-machine Ralph)  
**Status:** Research Complete

---

## 1. Problem Statement

### Why Sessions Die

Ralph runs as a PowerShell loop (`ralph-watch.ps1`) inside a user session on Windows Cloud PCs and DevBoxes. When that session terminates, Ralph dies. The root causes are:

| Error Code | Meaning | Trigger |
|------------|---------|---------|
| `0x3` | Remote session disconnected by server | Idle timeout policy (Intune/GPO) |
| `0x1c` | Session time limit reached | Active session duration cap |
| `0x5` | Connection replaced | Another RDP client connects to the same session |
| N/A | DevBox auto-stop | Pool-level auto-stop on disconnect (Azure portal) |
| N/A | Process tree killed | User logoff vs. disconnect confusion |

### The Kill Chain

```
User closes RDP window
  → Cloud PC detects idle (default: 15 min)
    → Intune policy disconnects session
      → DevBox auto-stop kicks in (configurable: 15 min to 12 hours)
        → VM hibernates/deallocates
          → All processes killed, including Ralph
```

### Impact on Squad

- **Zero coverage windows:** Ralph goes offline for 8-16 hours overnight
- **Missed triage:** Issues sit unprocessed until someone manually restarts
- **Stale heartbeats:** Cross-machine monitoring sees false "dead" status
- **Lost context:** Copilot CLI sessions lose state on restart
- **Duplicate work:** When multiple machines race to restart, coordination breaks

### Who Reported

Dina from the Squad team identified the pattern: Cloud PCs reliably die after ~30 minutes of idle, with error codes `0x3` and `0x1c` in Event Viewer under `Microsoft-Windows-TerminalServices-LocalSessionManager`.

---

## 2. Current Solutions — What We Already Built

We have a layered defense system. Each layer addresses a different failure mode.

### Layer 1: Keep-Alive Ping (`scripts/keep-devbox-alive.ps1`)

**What it does:** Mouse jiggle every 4 minutes + heartbeat file write.

```powershell
# Core loop — every 240 seconds
[MouseKeepAlive]::Jiggle()           # Move mouse 1px and back (P/Invoke)
Get-Date | Out-File ~/.devbox-keepalive  # Touch file for activity monitors
```

**Reliability:** ⚠️ Medium — Prevents idle detection at the RDP session level, but:
- Does NOT prevent DevBox pool-level auto-stop
- Requires an active user session to run in
- Mouse jiggling may violate enterprise IT policy (detectable by endpoint management)
- Dies if the process hosting it dies

### Layer 2: Scheduled Task Auto-Start (`scripts/devbox-autostart.ps1`)

**What it does:** Registered as `SquadAutoStart` task with `AtLogOn` + `SessionUnlock` triggers. Launches:
1. Production Ralph Watch
2. Research Ralph Watch  
3. GitHub Actions Runner
4. Agency Copilot session

**Reliability:** ✅ High for restart-after-login — The task fires on every logon and session unlock, ensuring Ralph comes back after a reboot or reconnect. But it can't prevent the machine from stopping in the first place.

### Layer 3: DevBox Startup (`scripts/devbox-startup.ps1`)

**What it does:** Loads secrets, starts keep-alive, launches Ralph for both repos. Designed for `shell:startup` shortcut or scheduled task.

**Reliability:** ✅ Solid bootstrap — but only runs when a user session starts.

### Layer 4: Ralph Watch Guard (`ralph-watch.ps1`)

**What it does:** v8 of the production loop with:
- Named mutex (`Global\RalphWatch_tamresearch1`) for single-instance
- Stale process detection and cleanup
- Lockfile with PID tracking
- 500-entry log rotation
- 20-minute round timeout
- Consecutive failure tracking with Teams alerts

**Reliability:** ✅ Excellent within a running session — But the guard itself is a user-mode process that dies with the session.

### Layer 5: Heartbeat System (`scripts/ralph-heartbeat.ps1`)

**What it does:** Writes JSON to `~/.squad/heartbeats/{COMPUTERNAME}.json` with machine name, round number, status, and UTC timestamp. Consumed by the Telegram bot `/status` command.

**Reliability:** ✅ Good observability — Stale heartbeats (>10 min) are flagged. But detection without auto-recovery is just an alarm.

### Layer 6: Self-Healing Auth (`scripts/ralph-self-heal.ps1`)

**What it does:** Detects missing GitHub OAuth scopes, runs `gh auth refresh`, uses Playwright MCP to complete the device flow automatically.

**Reliability:** ⚠️ Experimental — Requires an active Copilot session and browser context.

### Layer 7: Cross-Machine Coordination (`scripts/cross-machine-watcher.ps1`)

**What it does:** YAML task queue in `.squad/cross-machine/tasks/`. Machines pull tasks on git pull, validate against a command whitelist, execute, and push results. Auto-registers machines in config.

**Reliability:** ✅ Production-ready coordination — But doesn't address session persistence.

### Layer 8: Session Recovery (`scripts/recover-sessions.ps1`)

**What it does:** Queries the Copilot CLI session store (SQLite FTS5) to find and resume recently closed sessions.

**Reliability:** ✅ Good for manual recovery — Not automated.

### Gap Analysis

| Concern | Covered? | Gap |
|---------|----------|-----|
| Restart after login | ✅ Yes | Auto-start task |
| Restart after reboot | ✅ Yes | Scheduled task on logon |
| Prevent idle disconnect | ⚠️ Partial | Mouse jiggle works but is policy-risky |
| Survive session disconnect | ❌ No | All processes run in user session |
| Survive VM auto-stop | ❌ No | No VM-level persistence |
| Cross-machine failover | ⚠️ Design only | Multi-machine design exists but not fully deployed |
| Auto-resume Copilot sessions | ❌ No | Session recovery is manual |

---

## 3. Best Practices — Ranked by Reliability

### Tier 1: Windows Service (Most Reliable)

**Approach:** Run Ralph as a Windows Service using NSSM (Non-Sucking Service Manager).

```powershell
# Install NSSM
choco install nssm -y

# Register Ralph as a service
nssm install RalphWatch "C:\Program Files\PowerShell\7\pwsh.exe"
nssm set RalphWatch AppParameters "-NoProfile -ExecutionPolicy Bypass -File C:\Users\tamirdresher\tamresearch1\ralph-watch.ps1"
nssm set RalphWatch AppDirectory "C:\Users\tamirdresher\tamresearch1"
nssm set RalphWatch DisplayName "Squad Ralph Watch"
nssm set RalphWatch Description "AI Squad triage monitor - runs continuously"
nssm set RalphWatch Start SERVICE_AUTO_START
nssm set RalphWatch ObjectName ".\tamirdresher" "password"

# Set auto-restart on failure (via sc.exe)
sc.exe failure RalphWatch reset= 86400 actions= restart/60000/restart/120000/restart/300000
```

**Why it's best:**
- Survives user logoff, session disconnect, RDP close
- Auto-starts on boot before any user logs in
- Windows Service Control Manager handles restarts on crash
- Runs in Session 0 (isolated from user desktop)
- Enterprise-compliant — services are a standard Windows pattern

**Limitations:**
- Runs in Session 0: cannot interact with desktop/UI
- Cannot use Playwright MCP (no browser context)
- Must pre-load environment variables (`GH_TOKEN`, etc.) into service config
- NSSM requires admin to install; `choco install` may need IT approval

**Reliability:** ★★★★★

### Tier 2: Task Scheduler with "Run Whether Logged On or Not"

**Approach:** Register a scheduled task that runs Ralph independently of user sessions.

```powershell
$action = New-ScheduledTaskAction `
    -Execute "C:\Program Files\PowerShell\7\pwsh.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Users\tamirdresher\tamresearch1\ralph-watch.ps1" `
    -WorkingDirectory "C:\Users\tamirdresher\tamresearch1"

$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Days 365)

$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName "RalphWatch" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Squad Ralph Watch - persistent triage monitor"
```

**Why it's good:**
- Built into Windows — no third-party tools
- "Run whether user is logged on or not" persists across disconnects
- Can run as SYSTEM for maximum persistence
- Restart-on-failure built into task settings
- IT-friendly — Task Scheduler is standard infrastructure

**Limitations:**
- Less visibility than a service (no `services.msc` entry)
- Task Scheduler UI is clunky for monitoring
- Same Session 0 limitation for UI-dependent work
- Password storage required if running as a specific user

**Reliability:** ★★★★☆

### Tier 3: RDP Keep-Alive + GPO Configuration

**Approach:** Configure RDP to never disconnect idle sessions.

**Group Policy path:**
```
Computer Configuration
  → Administrative Templates
    → Windows Components
      → Remote Desktop Services
        → Remote Desktop Session Host
          → Session Time Limits
```

**Settings:**
| Policy | Value |
|--------|-------|
| Set time limit for active but idle RDS sessions | Never |
| Set time limit for disconnected sessions | Never |
| Set time limit for active RDS sessions | Never |
| End session when time limits are reached | Disabled |

**Keep-alive connection interval:**
```
Computer Configuration → ... → Connections
  → Configure keep-alive connection interval: 3 minutes
```

**Registry equivalent:**
```powershell
# Enable keep-alive
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" `
    -Name "KeepAliveEnable" -Value 1 -Type DWord

# Set keep-alive interval (minutes)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" `
    -Name "KeepAliveInterval" -Value 3 -Type DWord

# Disable idle timeout
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" `
    -Name "MaxIdleTime" -Value 0 -Type DWord

# Disable disconnect timeout
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" `
    -Name "MaxDisconnectionTime" -Value 0 -Type DWord
```

**Why it helps:**
- Prevents the most common failure mode (idle disconnect)
- Standard enterprise configuration
- Can be pushed via Intune for Cloud PCs

**Limitations:**
- Requires admin/IT cooperation to change
- Cloud PC policies may override local GPO
- Intune-managed devices may enforce specific timeouts
- Does not prevent DevBox pool auto-stop

**Reliability:** ★★★☆☆ (depends on IT policy)

### Tier 4: Process Detachment Patterns

**Approach:** Launch Ralph as a fully detached process.

```powershell
# Method 1: Start-Process (survives parent session close, NOT user logoff)
Start-Process pwsh.exe `
    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File ralph-watch.ps1" `
    -WindowStyle Hidden `
    -WorkingDirectory "C:\Users\tamirdresher\tamresearch1"

# Method 2: WMI (truly detached, survives more scenarios)
$cmd = 'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\tamirdresher\tamresearch1\ralph-watch.ps1"'
([wmiclass]"Win32_Process").Create($cmd, "C:\Users\tamirdresher\tamresearch1", $null)

# Method 3: PowerShell Disconnected Remoting (survives client disconnect)
$session = New-PSSession -ComputerName localhost
Invoke-Command -Session $session -ScriptBlock {
    Set-Location "C:\Users\tamirdresher\tamresearch1"
    & .\ralph-watch.ps1
} -InDisconnectedSession
```

**Why it helps:**
- Quick to implement — no admin tools needed
- WMI process creation fully detaches from parent
- Disconnected remoting is reconnectable

**Limitations:**
- `Start-Process` children die on user logoff (not just disconnect)
- WMI processes have no restart-on-failure
- Disconnected remoting adds complexity
- None of these survive VM shutdown/hibernation

**Reliability:** ★★★☆☆

### Tier 5: `tscon.exe` Console Session Preservation

**Approach:** Before disconnecting RDP, detach the session to the console.

```powershell
# Get current session ID
$sessionId = (Get-Process -Id $PID).SessionId
# Or query via quser:
# quser | Select-String $env:USERNAME

# Detach to console (requires admin)
tscon.exe $sessionId /dest:console
```

**Why it helps:**
- Session remains fully active with desktop context
- All running processes continue
- Playwright/UI automation keeps working

**Limitations:**
- Requires elevated privileges
- Must be run manually before disconnect (or scripted into RDP disconnect event)
- Does not prevent auto-stop/hibernation
- Not viable as a permanent solution

**Reliability:** ★★☆☆☆

---

## 4. Recommended Architecture — Ralph as a Resilient Service

### Target State

```
┌─────────────────────────────────────────────┐
│                Cloud PC / DevBox            │
│                                             │
│  ┌─────────────────────────────────┐        │
│  │ Windows Service: RalphWatch     │  ◄── NSSM wrapper
│  │  ├─ ralph-watch.ps1 (loop)      │        │
│  │  ├─ heartbeat writes            │        │
│  │  ├─ gh CLI operations           │        │
│  │  └─ cross-machine sync          │        │
│  └────────────┬────────────────────┘        │
│               │                             │
│  ┌────────────▼────────────────────┐        │
│  │ Scheduled Task: RalphRecovery   │  ◄── Backup: restarts if service dies
│  │  Trigger: Every 5 min           │        │
│  │  Action: Check service, restart │        │
│  └─────────────────────────────────┘        │
│                                             │
│  ┌─────────────────────────────────┐        │
│  │ User Session (optional):        │        │
│  │  ├─ Copilot CLI interactive     │  ◄── For UI/Playwright work
│  │  ├─ keep-devbox-alive.ps1       │        │
│  │  └─ devbox-autostart.ps1        │        │
│  └─────────────────────────────────┘        │
│                                             │
│  ┌─────────────────────────────────┐        │
│  │ Heartbeat File:                 │        │
│  │  ~/.squad/heartbeats/HOST.json  │  ◄── Read by Telegram/Teams bots
│  └─────────────────────────────────┘        │
└────────────┬────────────────────────────────┘
             │ git push/pull
             ▼
┌─────────────────────────────────────────────┐
│       GitHub (Coordination Layer)           │
│  ├─ Issue assignments (work claiming)       │
│  ├─ Labels (machine identity)               │
│  ├─ Cross-machine task queue (YAML)         │
│  └─ Heartbeat comments                      │
└─────────────────────────────────────────────┘
```

### Kubernetes-Inspired Probe Model for Ralph

Map K8s probe concepts directly to Ralph's monitoring:

| K8s Concept | Ralph Equivalent | Implementation |
|-------------|-----------------|----------------|
| **Liveness Probe** | Heartbeat file age check | If `heartbeats/HOST.json` is older than 10 min → restart service |
| **Readiness Probe** | `gh auth status` check | Before claiming work, verify token is valid |
| **Startup Probe** | Lock file + first-round success | Don't alert until Ralph completes at least 1 round |
| **Restart Policy** | NSSM + `sc.exe failure` | Auto-restart with exponential backoff (1m → 2m → 5m) |
| **Pod Disruption Budget** | Cross-machine coordination | Ensure at least 1 Ralph is running across all machines |
| **Health Endpoint** | Heartbeat JSON | Machine, round, status, failures, last_activity |

### Implementation: Ralph Recovery Watchdog

```powershell
# ralph-recovery.ps1 — runs as a 5-minute scheduled task
$serviceName = "RalphWatch"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if (-not $service) {
    Write-EventLog -LogName Application -Source "RalphRecovery" `
        -EventId 1001 -Message "RalphWatch service not found — skipping"
    exit 0
}

if ($service.Status -ne 'Running') {
    Write-EventLog -LogName Application -Source "RalphRecovery" `
        -EventId 1002 -Message "RalphWatch service not running (Status: $($service.Status)). Restarting..."
    Start-Service -Name $serviceName
    exit 0
}

# Liveness check: is the heartbeat fresh?
$heartbeatFile = Join-Path $env:USERPROFILE ".squad\heartbeats\$env:COMPUTERNAME.json"
if (Test-Path $heartbeatFile) {
    $heartbeat = Get-Content $heartbeatFile | ConvertFrom-Json
    $lastActivity = [DateTime]::Parse($heartbeat.last_activity)
    $staleness = (Get-Date).ToUniversalTime() - $lastActivity

    if ($staleness.TotalMinutes -gt 15) {
        Write-EventLog -LogName Application -Source "RalphRecovery" `
            -EventId 1003 -Message "RalphWatch heartbeat stale ($($staleness.TotalMinutes) min). Restarting..."
        Restart-Service -Name $serviceName
    }
}
```

---

## 5. Cloud PC / DevBox Specific Configuration

### Microsoft Dev Box Auto-Stop

Dev Box auto-stop is configured at the **pool level** in the Azure portal:

| Setting | Location | Options |
|---------|----------|---------|
| Stop on disconnect | Dev Center → Projects → Pools → Settings | Enabled/Disabled |
| Delay before stop | Same | 15 min, 30 min, 1h, 2h, 4h, 8h, 12h |
| Stop on no connect | Same | After scheduled start, if no one connects |

**To disable auto-stop:**
1. Azure Portal → Dev Centers → [your center] → Projects → [project]
2. Select the Dev Box pool
3. Under **Auto-stop**, set to **Disabled** or maximum delay (12 hours)
4. Under **Stop on disconnect**, set to **Disabled**

> ⚠️ **Note:** Disabling auto-stop increases costs. A running E8 DevBox costs ~$0.50/hour = $360/month if always on.

### Windows 365 Cloud PC

Idle timeout is configured via **Intune configuration profiles**:

1. Intune → Devices → Configuration profiles → Create profile
2. Platform: Windows 10 and later
3. Profile type: Settings catalog
4. Add setting: "Set time limit for active but idle Remote Desktop Services session"
5. Set to desired value or "Never"

**Key Intune policies:**

| Policy | Path | Recommended |
|--------|------|-------------|
| Idle session timeout | Admin Templates → RDS → Session Time Limits | Never (for Ralph machines) |
| Disconnect timeout | Same | Never |
| Active session limit | Same | Never |
| Keep-alive interval | Admin Templates → RDS → Connections | 3 minutes |

### Hibernation Behavior

Both DevBox and Windows 365 support **hibernation** (since late 2024):
- VM state is saved to disk, then deallocated
- On resume, all processes are restored from the saved state
- Ralph survives hibernation transparently if it was running

**Key insight:** Hibernation is the best-case "stop" scenario. Push for hibernation over hard stop in pool configuration.

### Cost Optimization

| Strategy | Monthly Cost (E8) | Ralph Uptime |
|----------|--------------------|--------------|
| Always-on (no auto-stop) | ~$360 | 24/7 |
| Auto-stop with hibernate (12h delay) | ~$180 | ~12h/day |
| Auto-stop (1h delay) + service restart | ~$90 | Coverage depends on manual wake |
| GitHub Actions fallback | ~$0-10 (GH runner minutes) | Complement local Ralph |

**Recommended:** Hibernate with 4-8h delay + Windows Service for auto-restart on wake.

---

## 6. Quick Start Guide — Setting Up Persistent Ralph

### Prerequisites

- Windows Cloud PC or DevBox with admin access
- PowerShell 7+ (`pwsh.exe`) installed
- `gh` CLI authenticated
- Repository cloned to `C:\Users\<you>\tamresearch1`
- Chocolatey installed (for NSSM)

### Step 1: Install NSSM

```powershell
# Option A: Via Chocolatey (recommended)
choco install nssm -y

# Option B: Manual download
# Download from https://nssm.cc/download → extract nssm.exe to C:\Tools\
```

### Step 2: Register Ralph as a Windows Service

```powershell
$repoRoot = "$env:USERPROFILE\tamresearch1"
$pwsh = (Get-Command pwsh).Source

nssm install RalphWatch $pwsh
nssm set RalphWatch AppParameters "-NoProfile -ExecutionPolicy Bypass -File $repoRoot\ralph-watch.ps1"
nssm set RalphWatch AppDirectory $repoRoot
nssm set RalphWatch DisplayName "Squad Ralph Watch"
nssm set RalphWatch Description "AI Squad triage monitor"
nssm set RalphWatch Start SERVICE_AUTO_START

# Logging
nssm set RalphWatch AppStdout "$env:USERPROFILE\.squad\ralph-service-stdout.log"
nssm set RalphWatch AppStderr "$env:USERPROFILE\.squad\ralph-service-stderr.log"
nssm set RalphWatch AppRotateFiles 1
nssm set RalphWatch AppRotateBytes 1048576

# Environment variables (critical for gh CLI)
$ghToken = (gh auth token 2>&1).Trim()
nssm set RalphWatch AppEnvironmentExtra "GH_TOKEN=$ghToken" "HOME=$env:USERPROFILE" "USERPROFILE=$env:USERPROFILE"
```

### Step 3: Set Service Recovery Policy

```powershell
# Restart after 1 min, 2 min, then 5 min on consecutive failures
sc.exe failure RalphWatch reset= 86400 actions= restart/60000/restart/120000/restart/300000
```

### Step 4: Start the Service

```powershell
Start-Service RalphWatch
Get-Service RalphWatch | Format-List Name, Status, StartType
```

### Step 5: Register Recovery Watchdog

```powershell
$action = New-ScheduledTaskAction `
    -Execute "pwsh.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"& { `$svc = Get-Service RalphWatch -EA SilentlyContinue; if (`$svc -and `$svc.Status -ne 'Running') { Start-Service RalphWatch } }`""

$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "RalphRecovery" -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Description "Ensures RalphWatch service stays running"
```

### Step 6: Configure DevBox Auto-Stop (Azure Portal)

1. Go to Azure Portal → Dev Centers → Your Center → Projects → Pool
2. Set **Stop on disconnect** to **Disabled** or **12 hours**
3. Enable **Hibernate** instead of hard stop if available

### Step 7: Keep User Session Auto-Start (Backup)

The existing `devbox-autostart.ps1` scheduled task should remain as a backup layer. It handles:
- Copilot CLI sessions (require user session)
- Playwright browser automation
- GitHub Actions runner
- Keep-alive ping (for machines where the service approach isn't available)

### Verification

```powershell
# Check service status
Get-Service RalphWatch

# Check heartbeat
Get-Content "$env:USERPROFILE\.squad\heartbeats\$env:COMPUTERNAME.json" | ConvertFrom-Json

# Check service logs
Get-Content "$env:USERPROFILE\.squad\ralph-service-stderr.log" -Tail 20

# Simulate disconnect survival
# 1. Start service
# 2. Close RDP window (don't log off!)
# 3. Wait 30 minutes
# 4. Reconnect
# 5. Check: Get-Service RalphWatch → should still be "Running"

# Check scheduled task
Get-ScheduledTask -TaskName "RalphRecovery" | Get-ScheduledTaskInfo
```

---

## Appendix A: Decision Matrix

| Approach | Survives Disconnect | Survives Logoff | Survives Reboot | Survives VM Stop | Enterprise Friendly | Setup Effort |
|----------|--------------------|-----------------|-----------------|-----------------|--------------------|-------------|
| Keep-alive jiggle | No (prevents trigger) | No | No | No | ⚠️ Risky | Low |
| Task Scheduler (user) | ⚠️ Depends | No | Yes (AtLogon) | No | ✅ Yes | Low |
| Task Scheduler (SYSTEM) | ✅ Yes | ✅ Yes | ✅ Yes | No | ✅ Yes | Medium |
| Windows Service (NSSM) | ✅ Yes | ✅ Yes | ✅ Yes | No | ✅ Yes | Medium |
| GPO idle timeout = Never | N/A (prevents trigger) | N/A | N/A | N/A | ✅ Yes | Low (if admin) |
| DevBox auto-stop disabled | N/A | N/A | N/A | ✅ Yes | ✅ Yes | Low (portal) |
| Detached process | ✅ Yes | ❌ No | ❌ No | ❌ No | ✅ Yes | Low |
| GH Actions fallback | N/A | N/A | N/A | N/A | ✅ Yes | Medium |

## Appendix B: Related Research

- **Multi-Machine Ralph Design:** `.squad/research/multi-machine-ralph-design.md` — Covers work claiming, branch coordination, and heartbeat via GitHub labels/comments
- **Issue #615:** "Find a way to keep the DevBoxes always on even at night and execute it" (Closed)
- **Schedule Configuration:** `.squad/schedule.json` — Ralph heartbeat interval (5 min), daily briefings, Teams monitoring

## Appendix C: References

- [Microsoft: Configure Dev Box stop on disconnect](https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/dev-box/how-to-configure-stop-on-disconnect.md)
- [Microsoft: Windows 365 Frontline session time limits](https://learn.microsoft.com/en-us/windows-365/enterprise/frontline-cloud-pc-session-time-limits)
- [Microsoft: PowerShell Disconnected Sessions](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_remote_disconnected_sessions)
- [NSSM — Non-Sucking Service Manager](https://nssm.cc/usage)
- [4sysops: PowerShell as Windows Service](https://4sysops.com/archives/how-to-run-a-powershell-script-as-a-windows-service/)
- [Microsoft: RDP keep-alive troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-server/remote/rdp-client-disconnects-cannot-reconnect-same-session)
- [Kubernetes: Configure Liveness, Readiness, Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Microsoft: PowerToys Awake](https://learn.microsoft.com/en-us/windows/powertoys/awake)
