<#
.SYNOPSIS
    Recovers Squad services and agency sessions after a machine restart.
.DESCRIPTION
    Reads .squad/restart-snapshot.json, validates all inputs, launches background
    services via an allowlist, resumes agency sessions with validated IDs and paths,
    and prints a recovery summary.
.NOTES
    All snapshot data is treated as untrusted. Commands are never constructed from
    snapshot fields — only known service names trigger pre-defined launch logic.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Resolve repo root dynamically
# ---------------------------------------------------------------------------
$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = $PWD.Path }
$repoRoot = [System.IO.Path]::GetFullPath($repoRoot)

Write-Host "Repo root: $repoRoot" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------
function Test-SafePath {
    param([string]$Path, [string]$RepoRoot)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    try {
        $resolved = [System.IO.Path]::GetFullPath(
            [System.IO.Path]::Combine($RepoRoot, $Path))
        return $resolved.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)
    } catch {
        return $false
    }
}

function Test-SafeSessionId {
    param([string]$Id)
    # Strict UUID v4 format, case-sensitive match
    return ($Id -cmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
}

# ---------------------------------------------------------------------------
# Service allowlist — only these names can be launched
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Step 1: Read and validate snapshot
# ---------------------------------------------------------------------------
$snapshotPath = Join-Path $repoRoot ".squad\restart-snapshot.json"

if (-not (Test-Path $snapshotPath)) {
    Write-Error "Snapshot not found at $snapshotPath — cannot recover."
    exit 1
}

try {
    $raw = Get-Content $snapshotPath -Raw -ErrorAction Stop
    $snapshot = $raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Error "Failed to parse snapshot JSON: $_"
    exit 1
}

if (-not $snapshot.services -or -not $snapshot.timestamp) {
    Write-Error "Snapshot is missing required fields (services, timestamp)."
    exit 1
}

Write-Host "`nSnapshot loaded (taken: $($snapshot.timestamp))" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Step 2: Launch background services via allowlist
# ---------------------------------------------------------------------------
Write-Host "`n--- Launching Services ---" -ForegroundColor Cyan
$launchResults = @()

foreach ($svc in $snapshot.services) {
    $svcName = [string]$svc.name

    if (-not $allowedCommands.ContainsKey($svcName)) {
        Write-Warning "Unknown service '$svcName' — skipping (not in allowlist)."
        $launchResults += [PSCustomObject]@{ Name = $svcName; Status = "Rejected (unknown)" }
        continue
    }

    try {
        & $allowedCommands[$svcName] $repoRoot
        Write-Host "  Started: $svcName" -ForegroundColor Green
        $launchResults += [PSCustomObject]@{ Name = $svcName; Status = "Launched" }
    } catch {
        Write-Warning "Failed to start '$svcName': $_"
        $launchResults += [PSCustomObject]@{ Name = $svcName; Status = "Failed: $_" }
    }
}

Start-Sleep 3

# ---------------------------------------------------------------------------
# Step 3: Resume agency sessions with validation
# ---------------------------------------------------------------------------
Write-Host "`n--- Resuming Sessions ---" -ForegroundColor Cyan
$sessionResults = @()

if ($snapshot.agency_sessions) {
    foreach ($session in $snapshot.agency_sessions) {
        $sid  = [string]$session.id
        $name = [string]$session.name

        if (-not (Test-SafeSessionId $sid)) {
            Write-Warning "Invalid session ID '$sid' — skipping."
            $sessionResults += [PSCustomObject]@{ Name = $name; Status = "Invalid ID format" }
            continue
        }

        $sessionCwd = [string]$session.cwd
        if (-not (Test-SafePath $sessionCwd $repoRoot)) {
            Write-Warning "Session cwd '$sessionCwd' is outside repo root — skipping."
            $sessionResults += [PSCustomObject]@{ Name = $name; Status = "Unsafe path" }
            continue
        }

        $resolvedCwd = [System.IO.Path]::GetFullPath(
            [System.IO.Path]::Combine($repoRoot, $sessionCwd))

        try {
            Start-Process powershell -ArgumentList "-NoExit", "-Command",
                "agency copilot --yolo --agent squad --resume=$sid" `
                -WorkingDirectory $resolvedCwd -WindowStyle Normal
            Write-Host "  Resumed: $name ($sid)" -ForegroundColor Green
            $sessionResults += [PSCustomObject]@{ Name = $name; Status = "Resumed" }
        } catch {
            Write-Warning "Failed to resume session '$name': $_"
            $sessionResults += [PSCustomObject]@{ Name = $name; Status = "Failed: $_" }
        }

        Start-Sleep 1
    }
} else {
    Write-Host "  No agency sessions to resume." -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Step 4: Recovery summary
# ---------------------------------------------------------------------------
Write-Host "`n========== Recovery Summary ==========" -ForegroundColor White

Write-Host "`nServices:" -ForegroundColor Cyan
foreach ($r in $launchResults) {
    $icon = if ($r.Status -eq "Launched") { "+" } else { "!" }
    Write-Host "  [$icon] $($r.Name) — $($r.Status)"
}

Write-Host "`nSessions:" -ForegroundColor Cyan
foreach ($r in $sessionResults) {
    $icon = if ($r.Status -eq "Resumed") { "+" } else { "!" }
    Write-Host "  [$icon] $($r.Name) — $($r.Status)"
}

if ($snapshot.ralph_status) {
    Write-Host "`nRalph Status:" -ForegroundColor Cyan
    $rs = $snapshot.ralph_status
    if ($rs.rounds_completed) { Write-Host "  Rounds completed: $($rs.rounds_completed)" }
    if ($rs.issues_processed) { Write-Host "  Issues processed: $($rs.issues_processed -join ', ')" }
    if ($rs.next_items)       { Write-Host "  Next items: $($rs.next_items.Count) remaining" -ForegroundColor Yellow }
    if ($rs.rate_limited)     { Write-Host "  Was rate-limited — say 'Ralph, go' to resume" -ForegroundColor Yellow }
}

if ($snapshot.open_prs) {
    Write-Host "`nOpen PRs: $($snapshot.open_prs.Count)" -ForegroundColor Cyan
}

if ($snapshot.pending_issues_to_retry) {
    Write-Host "`nPending Retries: $($snapshot.pending_issues_to_retry.Count)" -ForegroundColor Yellow
}

Write-Host "`n======================================" -ForegroundColor White
Write-Host "Recovery complete." -ForegroundColor Green
