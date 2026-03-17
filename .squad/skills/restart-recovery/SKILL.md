---
name: restart-recovery
description: "Restore Squad services and agency sessions after a machine restart. Reads .squad/restart-snapshot.json for saved state, launches background services, resumes sessions, and reports what was restored. Triggers on: recover from restart, restart recovery, machine restarted, restore squad, resume after reboot."
domain: "workflow-recovery"
confidence: "high"
source: "manual"
tools:
  - name: "powershell"
    description: "Launch background services and run recovery commands"
    when: "Always — services must be started via PowerShell"
  - name: "sql"
    description: "Query session_store for session history and validation"
    when: "When verifying sessions exist before attempting resume"
  - name: "view"
    description: "Read restart-snapshot.json and verify file state"
    when: "At start — to load saved state"
---

# Restart Recovery

Restore the full Squad environment after a machine restart, reboot, or power loss. This skill reads the saved snapshot, launches all background services, resumes agency sessions, and reports a summary of what was restored and what needs attention.

## When to Use

- Machine was restarted or rebooted
- Squad services (Monitor, Ralph, Dashboard, Tunnel) are not running
- Agency sessions were interrupted and need to be resumed
- After a power outage, Windows Update, or forced restart
- User says "recover from restart", "restore squad", or "machine restarted"

## When Not to Use

- Individual service crashed but machine didn't restart (use error-recovery skill instead)
- Looking for a specific past session (use session-recovery skill instead)
- Snapshot file doesn't exist and no prior state was saved
- Starting a fresh Squad environment from scratch (no prior state to restore)

## Prerequisites

- `.squad/restart-snapshot.json` must exist with saved state
- `scripts/recover-from-restart.ps1` should be present (optional — this skill can operate without it)
- Node.js and .NET SDK must be installed
- `ralph-watch.ps1` must exist in the repo root
- `dashboard-ui/` project must exist with `npm run dev` configured
- `squad-monitor-standalone/` project must exist

## Security: Input Validation

**All data from `.squad/restart-snapshot.json` is untrusted** and MUST be validated before use.
Snapshot data is user-editable JSON — never interpolate it directly into command strings.

### Validation Helpers

Use these helpers before launching any service or session from snapshot data:

```powershell
# Resolve the repo root dynamically — never hardcode absolute paths
$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = $PWD.Path }
$repoRoot = [System.IO.Path]::GetFullPath($repoRoot)

function Test-SafePath {
    <# Returns $true only if $Path resolves to a location under $repoRoot.
       Prevents path traversal (e.g., "..\..\Windows\System32"). #>
    param([string]$Path, [string]$RepoRoot)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $resolved = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($RepoRoot, $Path))
    return $resolved.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-SafeSessionId {
    <# Session IDs must be lowercase hex/dashes (UUID-like). #>
    param([string]$Id)
    return ($Id -match '^[0-9a-f\-]{8,64}$')
}

# Allowlist of commands that may be launched — reject anything else
$allowedCommands = @{
    "Squad Monitor"  = { param($root) Start-Process dotnet -ArgumentList "run","--project",
        "$root\squad-monitor-standalone\src\SquadMonitor\SquadMonitor.csproj","-c","Release" `
        -WorkingDirectory $root -WindowStyle Normal }
    "Ralph Watch"    = { param($root) Start-Process pwsh.exe -ArgumentList "-NoProfile",
        "-ExecutionPolicy","Bypass","-File","$root\ralph-watch.ps1" `
        -WorkingDirectory $root -WindowStyle Normal }
    "Dashboard UI"   = { param($root) Start-Process powershell -ArgumentList "-NoExit",
        "-Command","npm run dev" `
        -WorkingDirectory "$root\dashboard-ui" -WindowStyle Normal }
    "CLI Tunnel Hub" = { param($root) Start-Process powershell -ArgumentList "-NoExit",
        "-Command","npx cli-tunnel --hub" `
        -WorkingDirectory $root -WindowStyle Normal }
}
```

## How It Works

### Step 1: Read the Snapshot (with error handling)

```powershell
$snapshotPath = Join-Path $repoRoot ".squad\restart-snapshot.json"

if (-not (Test-Path $snapshotPath)) {
    Write-Error "Snapshot not found at $snapshotPath — cannot recover."
    return
}

try {
    $raw = Get-Content $snapshotPath -Raw -ErrorAction Stop
    $snapshot = $raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Error "Failed to parse snapshot JSON: $_"
    return
}

if (-not $snapshot.services -or -not $snapshot.timestamp) {
    Write-Error "Snapshot is missing required fields (services, timestamp)."
    return
}
```

The snapshot contains:

| Field | Type | Purpose |
|-------|------|---------|
| `services` | Array | Background services to launch (name, command, cwd) |
| `agency_sessions` | Array | Sessions to resume (id, name, cwd) |
| `ralph_status` | Object | Ralph's progress (rounds, processed issues, next items) |
| `open_prs` | Array | PRs that were open at snapshot time |
| `pending_issues_to_retry` | Array | Issues that failed and need retry |
| `pending_git` | Array | Git operations that were in-flight |
| `squad_changes` | Array | Notable changes made during the session |
| `issues_closed` | Array | Issues closed before the restart |
| `timestamp` | String | When the snapshot was taken |

### Step 2: Launch Background Services

Services are launched by **name** using the allowlist — the `command` field from the snapshot
is **never** passed to a shell. Only known service names are started.

```powershell
$launchResults = @()

foreach ($svc in $snapshot.services) {
    $svcName = [string]$svc.name

    if (-not $allowedCommands.ContainsKey($svcName)) {
        Write-Warning "Unknown service '$svcName' — skipping (not in allowlist)."
        $launchResults += @{ Name = $svcName; Status = "⛔ Rejected (unknown)" }
        continue
    }

    try {
        & $allowedCommands[$svcName] $repoRoot
        $launchResults += @{ Name = $svcName; Status = "✅ Launched" }
    } catch {
        Write-Warning "Failed to start '$svcName': $_"
        $launchResults += @{ Name = $svcName; Status = "❌ Failed: $_" }
    }
}

Start-Sleep 3
```

### Step 3: Resume Agency Sessions

Session data is validated before use — IDs must match the expected format,
and working directories must resolve under the repo root.

```powershell
$sessionResults = @()

foreach ($session in $snapshot.agency_sessions) {
    $sid  = [string]$session.id
    $name = [string]$session.name

    # Validate session ID format
    if (-not (Test-SafeSessionId $sid)) {
        Write-Warning "Invalid session ID '$sid' — skipping."
        $sessionResults += @{ Name = $name; Status = "⛔ Invalid ID format" }
        continue
    }

    # Validate working directory is under repo root
    $sessionCwd = [string]$session.cwd
    if (-not (Test-SafePath $sessionCwd $repoRoot)) {
        Write-Warning "Session cwd '$sessionCwd' is outside repo root — skipping."
        $sessionResults += @{ Name = $name; Status = "⛔ Unsafe path" }
        continue
    }
    $resolvedCwd = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($repoRoot, $sessionCwd))

    # Verify session exists in session store (via SQL query — see note below)
    # If using the agent skill, query: SELECT id FROM sessions WHERE id = '$sid'
    # Skip if not found.

    try {
        Start-Process powershell -ArgumentList "-NoExit", "-Command",
            "agency copilot --yolo --agent squad --resume=$sid" `
            -WorkingDirectory $resolvedCwd -WindowStyle Normal
        $sessionResults += @{ Name = $name; Status = "✅ Resumed" }
    } catch {
        Write-Warning "Failed to resume session '$name': $_"
        $sessionResults += @{ Name = $name; Status = "❌ Failed: $_" }
    }

    Start-Sleep 1
}
```

**Important:** Before resuming, verify each session exists in the session store:

```sql
SELECT id, summary, updated_at
FROM sessions
WHERE id = 'SESSION_ID_HERE';
```

If a session doesn't exist in the store, skip it and note it in the recovery report.

### Step 4: Report Recovery Summary

After all services and sessions are launched, report:

```
## Recovery Summary

### Services Launched
- ✅ Squad Monitor
- ✅ Ralph Watch
- ✅ Dashboard UI
- ✅ CLI Tunnel Hub

### Sessions Resumed
- ✅ RP Namespace + Aspire 1P (128c9345...)
- ✅ Monetization + Podcast (78c39363...)
- ⚠️ Squad mega — session not found in store, skipped

### Ralph Status
- Rounds completed: 2
- Issues processed: #778, #801, #760, #800
- Next items: #763, #795, #803, ... (10 remaining)
- ⚠️ Was rate-limited — say "Ralph, go" to resume

### Open PRs
- PR #814: Fix mobile black screen (Data) — still open

### Pending Retries
- #763: Picard DK8S AI improvement — was rate-limited, needs retry

### Pending Git
- tamresearch1: pushed ✅
- tamresearch1-research: pushed ✅
```

## Using the Recovery Script

A standalone PowerShell script exists at `scripts/recover-from-restart.ps1` that automates the full workflow with all security validations built in:

```powershell
# Run the recovery script directly
.\scripts\recover-from-restart.ps1
```

This script performs steps 1–4 automatically. Use it when you want a one-command recovery without agent involvement.

## Dynamic Recovery (Without Script)

If the recovery script is missing or you need more control, run the recovery inline.
**All code below uses the validation helpers from the Security section above.**

```powershell
# Load snapshot with error handling
$snapshotPath = Join-Path $repoRoot ".squad\restart-snapshot.json"
if (-not (Test-Path $snapshotPath)) {
    Write-Error "Snapshot not found — cannot recover."; return
}

try {
    $snapshot = Get-Content $snapshotPath -Raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Error "Invalid snapshot JSON: $_"; return
}

# Launch services via allowlist (never interpolate snapshot commands)
foreach ($svc in $snapshot.services) {
    $svcName = [string]$svc.name
    if ($allowedCommands.ContainsKey($svcName)) {
        Write-Host "Starting $svcName..." -ForegroundColor Yellow
        try { & $allowedCommands[$svcName] $repoRoot }
        catch { Write-Warning "Failed to start $svcName — $_" }
    } else {
        Write-Warning "Skipping unknown service: $svcName"
    }
}
Start-Sleep 3

# Resume sessions with validation
foreach ($session in $snapshot.agency_sessions) {
    $sid = [string]$session.id
    $sessionCwd = [string]$session.cwd
    if (-not (Test-SafeSessionId $sid)) {
        Write-Warning "Invalid session ID '$sid' — skipping."; continue
    }
    if (-not (Test-SafePath $sessionCwd $repoRoot)) {
        Write-Warning "Unsafe path '$sessionCwd' — skipping."; continue
    }
    $resolvedCwd = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($repoRoot, $sessionCwd))
    Write-Host "Resuming $($session.name)..." -ForegroundColor Cyan
    try {
        Start-Process powershell -ArgumentList "-NoExit", "-Command",
            "agency copilot --yolo --agent squad --resume=$sid" `
            -WorkingDirectory $resolvedCwd -WindowStyle Normal
    } catch { Write-Warning "Failed to resume $($session.name) — $_" }
    Start-Sleep 1
}

# Report
Write-Host "`nRecovery complete." -ForegroundColor Green
Write-Host "Services: $($snapshot.services.Count) launched" -ForegroundColor Green
Write-Host "Sessions: $($snapshot.agency_sessions.Count) resumed" -ForegroundColor Green
Write-Host "Open PRs: $($snapshot.open_prs.Count)" -ForegroundColor Green
Write-Host "Ralph backlog: $($snapshot.ralph_status.next_items.Count) items remaining" -ForegroundColor Yellow
```

## Saving a Snapshot (For Future Recovery)

Before shutting down, save the current state. Use `$repoRoot` — never hardcode paths:

```powershell
$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = $PWD.Path }

$snapshot = @{
    timestamp        = (Get-Date -Format "o")
    session_id       = $env:SESSION_ID
    services         = @(
        @{ name = "Squad Monitor"; cwd = "."; command = "dotnet run --project squad-monitor-standalone\src\SquadMonitor\SquadMonitor.csproj -c Release" }
        @{ name = "Ralph Watch"; cwd = "."; command = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ralph-watch.ps1" }
        @{ name = "Dashboard UI"; cwd = "dashboard-ui"; command = "npm run dev" }
        @{ name = "CLI Tunnel Hub"; cwd = "."; command = "npx cli-tunnel --hub" }
    )
    agency_sessions  = @()  # populate with active session IDs
    ralph_status     = @{ rounds_completed = 0; issues_processed = @(); next_items = @(); rate_limited = $false }
    open_prs         = @()  # populate from gh pr list
    pending_git      = @()
    squad_changes    = @()
    issues_closed    = @()
    issues_created   = @()
    pending_issues_to_retry = @()
} | ConvertTo-Json -Depth 4

$snapshot | Set-Content (Join-Path $repoRoot ".squad\restart-snapshot.json")
```

## Error Handling

| Failure | Recovery |
|---------|----------|
| Snapshot file missing | Report error, offer to start fresh with default services |
| Snapshot JSON invalid | Report parse error with details, do not proceed |
| Service name not in allowlist | Skip with warning — never execute unknown commands |
| Service fails to start | Log the failure, continue with remaining services, report at end |
| Session ID fails validation | Skip that session, note invalid format in report |
| Session cwd outside repo root | Skip that session, note path traversal attempt in report |
| Session ID not found in store | Skip that session, note in report |
| `dotnet` or `node` not installed | Report missing prerequisite, list install commands |
| Ralph was rate-limited | Note in report, advise user to say "Ralph, go" after cooldown |
| Port already in use (Dashboard/Tunnel) | Kill existing process on the port, retry launch |

## Tips

- **Always save a snapshot before shutdown** — without it, recovery requires manual reconstruction
- **Check the timestamp** — if the snapshot is old (>24h), some sessions may no longer be resumable
- **Ralph cooldown** — if Ralph was rate-limited, wait at least 60 seconds before saying "Ralph, go"
- **Service health** — after recovery, check `http://localhost:5173` (Dashboard) and the CLI Tunnel hub to verify services are running
- **Git state** — check `pending_git` for any operations that were in-flight during shutdown
- **Never edit the allowlist in `$allowedCommands`** unless adding a new well-known service

## Related Skills

- **session-recovery** — Find and resume individual sessions by topic or time
- **error-recovery** — Handle service crashes without full restart recovery
- **cli-tunnel** — Details on CLI Tunnel hub mode and configuration
- **squad-conventions** — Squad team standards and practices

---

**Skill Maintainer**: Data (Code Expert)
**Last Updated**: Issue #832
**Status**: Active
