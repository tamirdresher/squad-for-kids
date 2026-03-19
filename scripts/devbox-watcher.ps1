<#
.SYNOPSIS
    Azure Dev Box Watcher — monitors the devbox from a local machine and wakes it
    when it goes to sleep, stops, or hibernates.

.DESCRIPTION
    Issue #978 — "The devbox keeps going to sleep."

    This script runs on your LOCAL machine (not inside the Dev Box). It polls
    the Dev Box power state every 30 minutes using the Azure CLI. If the box
    is found to be stopped or hibernated it automatically issues a start or
    restart command to wake it back up.

    Why a separate watcher vs the existing devbox-keep-alive.ps1?
    ─────────────────────────────────────────────────────────────
    • devbox-keep-alive.ps1 runs INSIDE the Dev Box and delays scheduled
      auto-stop actions *before* they fire (prevention).
    • devbox-watcher.ps1 runs on your LOCAL machine and RECOVERS the box
      after it has already stopped or hibernated (recovery).

    They complement each other:
      Local watcher → detects and restarts a stopped/hibernated box
      In-box keep-alive → delays the scheduled stop so it rarely happens

    Power states handled:
    ─────────────────────
    • Running       — healthy, no action needed
    • Hibernated    — `az devcenter dev dev-box restart`
    • Stopped       — `az devcenter dev dev-box start`
    • Deallocated   — `az devcenter dev dev-box start`
    • Starting      — already waking, wait and re-check
    • Stopping      — just going down, wait and re-check next round

    After waking, the script optionally makes a lightweight SSH connection
    to confirm the box is actually reachable (use -ConnectAfterWake).

.PARAMETER DevBoxName
    Name of the Dev Box to watch. Auto-detected from `az devcenter dev dev-box list`
    if omitted.

.PARAMETER ProjectName
    Dev Center project name. Auto-detected if omitted.

.PARAMETER DevCenterName
    Dev Center endpoint name (e.g. "mydevcenter"). Auto-detected if omitted.

.PARAMETER IntervalMinutes
    How often to poll the devbox status (default: 30 minutes).

.PARAMETER DurationHours
    How many hours to run before exiting (default: 0 = run forever).

.PARAMETER MaxRetries
    How many times to retry a start/restart command before giving up for
    that round (default: 3).

.PARAMETER RetryDelaySeconds
    Seconds to wait between retries (default: 30).

.PARAMETER ConnectAfterWake
    If set, make a test SSH connection after successfully waking the box to
    confirm it is fully alive. Requires SSH host configured in ~/.ssh/config
    or -SshHost to be specified.

.PARAMETER SshHost
    SSH host/alias to connect to for the post-wake connectivity check.
    If omitted, uses the devbox name as the SSH host alias.

.PARAMETER LogFile
    Path to the log file (default: logs/devbox-watcher.log relative to
    script location, or fallback to $env:USERPROFILE\.squad\devbox-watcher.log).

.PARAMETER DryRun
    Log what would be done without actually issuing start/restart commands.

.EXAMPLE
    # Run with auto-detection, indefinitely
    .\scripts\devbox-watcher.ps1

.EXAMPLE
    # Dry-run to test detection logic
    .\scripts\devbox-watcher.ps1 -DryRun

.EXAMPLE
    # Explicit names, 8-hour window, connect via SSH after wake
    .\scripts\devbox-watcher.ps1 -DevBoxName "tamir-dev" -ProjectName "my-proj" `
        -DurationHours 8 -ConnectAfterWake -SshHost "tamir-devbox"

.EXAMPLE
    # Run hidden in background from Task Scheduler or startup
    Start-Process pwsh -ArgumentList "-NoProfile -WindowStyle Hidden -File `"$PSScriptRoot\devbox-watcher.ps1`"" -WindowStyle Hidden

.NOTES
    Requires:
      • Azure CLI  (`winget install Microsoft.AzureCLI`)
      • devcenter extension  (`az extension add --name devcenter`)
      • Dev Box User or Contributor role in Dev Center project

    Related scripts:
      • scripts/devbox-keep-alive.ps1  — in-box prevention (run INSIDE the Dev Box)
      • scripts/keep-devbox-alive.ps1  — legacy mouse-jiggle (insufficient alone)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$DevBoxName,
    [string]$ProjectName,
    [string]$DevCenterName,
    [int]$IntervalMinutes   = 30,
    [int]$DurationHours     = 0,
    [int]$MaxRetries        = 3,
    [int]$RetryDelaySeconds = 30,
    [switch]$ConnectAfterWake,
    [string]$SshHost,
    [string]$LogFile,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$script:VERSION = "1.0.0"

# ── Log file resolution ───────────────────────────────────────────────────────

if (-not $LogFile) {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $logsDir  = Join-Path $repoRoot "logs"
    if (-not (Test-Path $logsDir)) {
        try { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null } catch {}
    }
    $LogFile = if (Test-Path $logsDir) {
        Join-Path $logsDir "devbox-watcher.log"
    } else {
        Join-Path $env:USERPROFILE ".squad\devbox-watcher.log"
    }
}

$logDir = Split-Path $LogFile -Parent
if (-not (Test-Path $logDir)) {
    try { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } catch {}
}

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","OK","WARN","ERROR","DRY")]
        [string]$Level = "INFO"
    )
    $ts   = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "OK"    { "Green" }
        "DRY"   { "Cyan" }
        default { "Gray" }
    }
    Write-Host $line -ForegroundColor $color
    try { Add-Content -Path $LogFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue } catch {}
}

function Invoke-LogRotation {
    if (Test-Path $LogFile) {
        $size = (Get-Item $LogFile).Length
        if ($size -gt 2MB) {
            $lines = Get-Content $LogFile -Tail 1000
            $lines | Set-Content $LogFile -Encoding utf8
            Write-Log "Log rotated (was $([math]::Round($size/1KB))KB, kept last 1000 lines)"
        }
    }
}

function Test-AzLoggedIn {
    $out = az account show -o json 2>$null
    return ($LASTEXITCODE -eq 0 -and $out)
}

function Test-AzDevcenterExtension {
    $ext = az extension list --query "[?name=='devcenter']" -o json 2>$null | ConvertFrom-Json
    return ($null -ne $ext -and $ext.Count -gt 0)
}

function Resolve-DevBoxInfo {
    <# Auto-detect devbox name, project, and dev-center from CLI #>
    Write-Log "Auto-detecting Dev Box configuration..."
    try {
        $boxes = az devcenter dev dev-box list -o json 2>$null | ConvertFrom-Json
        if (-not $boxes -or $boxes.Count -eq 0) {
            Write-Log "No Dev Boxes found for the current user." "WARN"
            return $null
        }
        # Prefer a box whose name contains this machine's name; otherwise first
        $match = $boxes | Where-Object { $_.name -like "*$($env:COMPUTERNAME.ToLower().Replace('-',''))*" } | Select-Object -First 1
        if (-not $match) { $match = $boxes | Select-Object -First 1 }
        Write-Log "Detected: devbox='$($match.name)'  project='$($match.projectName)'" "OK"
        return $match
    } catch {
        Write-Log "Auto-detect failed: $_" "ERROR"
        return $null
    }
}

function Get-DevBoxPowerState {
    <#
        Returns a hashtable:
          .PowerState  — string like "Running", "Stopped", "Hibernated", "Starting", etc.
          .Raw         — the full JSON object from az
          .Error       — error message if call failed
    #>
    param([string]$Name, [string]$Project)

    try {
        $json = az devcenter dev dev-box show `
            --dev-box-name $Name `
            --project       $Project `
            -o json 2>&1

        if ($LASTEXITCODE -ne 0) {
            return @{ PowerState = $null; Raw = $null; Error = ($json -join " ") }
        }

        $obj = $json | ConvertFrom-Json
        # powerState field name varies slightly across CLI versions
        $ps = if ($obj.powerState)    { $obj.powerState }
           elseif ($obj.PowerState)   { $obj.PowerState }
           elseif ($obj.actionState)  { $obj.actionState }
           else                       { "Unknown" }

        return @{ PowerState = $ps; Raw = $obj; Error = $null }
    } catch {
        return @{ PowerState = $null; Raw = $null; Error = $_.ToString() }
    }
}

function Invoke-StartDevBox {
    param([string]$Name, [string]$Project, [int]$Retries, [int]$RetryDelay)
    for ($i = 1; $i -le $Retries; $i++) {
        Write-Log "Attempt $i/$Retries: az devcenter dev dev-box start --dev-box-name $Name --project $Project"
        $out = az devcenter dev dev-box start `
            --dev-box-name $Name `
            --project       $Project `
            --no-wait `
            -o json 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Start command accepted on attempt $i." "OK"
            return $true
        }
        Write-Log "Start attempt $i failed: $($out -join ' ')" "WARN"
        if ($i -lt $Retries) { Start-Sleep -Seconds $RetryDelay }
    }
    Write-Log "All $Retries start attempts failed." "ERROR"
    return $false
}

function Invoke-RestartDevBox {
    param([string]$Name, [string]$Project, [int]$Retries, [int]$RetryDelay)
    for ($i = 1; $i -le $Retries; $i++) {
        Write-Log "Attempt $i/$Retries: az devcenter dev dev-box restart --dev-box-name $Name --project $Project"
        $out = az devcenter dev dev-box restart `
            --dev-box-name $Name `
            --project       $Project `
            --no-wait `
            -o json 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Restart command accepted on attempt $i." "OK"
            return $true
        }
        Write-Log "Restart attempt $i failed: $($out -join ' ')" "WARN"
        if ($i -lt $Retries) { Start-Sleep -Seconds $RetryDelay }
    }
    Write-Log "All $Retries restart attempts failed." "ERROR"
    return $false
}

function Test-SshConnectivity {
    param([string]$Host, [int]$TimeoutSeconds = 15)
    Write-Log "Testing SSH connectivity to '$Host' (timeout ${TimeoutSeconds}s)..."
    try {
        $result = ssh -o ConnectTimeout=$TimeoutSeconds `
                      -o BatchMode=yes `
                      -o StrictHostKeyChecking=no `
                      $Host "echo devbox-alive" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match "devbox-alive") {
            Write-Log "SSH connectivity confirmed: '$Host' is alive." "OK"
            return $true
        }
        Write-Log "SSH check returned exit $LASTEXITCODE. Output: $result" "WARN"
        return $false
    } catch {
        Write-Log "SSH connectivity check failed: $_" "WARN"
        return $false
    }
}

# ── Wake logic for a single check round ──────────────────────────────────────

function Invoke-WatchRound {
    param([string]$Name, [string]$Project, [int]$Round)

    Write-Log "--- Round $Round | Checking power state of '$Name' ---"

    $state = Get-DevBoxPowerState -Name $Name -Project $Project

    if ($state.Error) {
        Write-Log "Failed to query Dev Box state: $($state.Error)" "ERROR"
        return
    }

    $ps = $state.PowerState
    Write-Log "Power state: $ps"

    switch -Wildcard ($ps) {
        "Running" {
            Write-Log "Dev Box is running normally. No action needed." "OK"
        }

        "Hibernated" {
            Write-Log "Dev Box is HIBERNATED. Issuing restart to wake it up..." "WARN"
            if ($DryRun) {
                Write-Log "[DRY-RUN] Would run: az devcenter dev dev-box restart --dev-box-name $Name --project $Project --no-wait" "DRY"
            } else {
                $ok = Invoke-RestartDevBox -Name $Name -Project $Project `
                        -Retries $MaxRetries -RetryDelay $RetryDelaySeconds
                if ($ok) {
                    Write-Log "Restart issued. Box will be available in a few minutes." "OK"
                    if ($ConnectAfterWake) { Invoke-PostWakeConnect -Name $Name }
                }
            }
        }

        "Stopped" {
            Write-Log "Dev Box is STOPPED. Issuing start..." "WARN"
            if ($DryRun) {
                Write-Log "[DRY-RUN] Would run: az devcenter dev dev-box start --dev-box-name $Name --project $Project --no-wait" "DRY"
            } else {
                $ok = Invoke-StartDevBox -Name $Name -Project $Project `
                        -Retries $MaxRetries -RetryDelay $RetryDelaySeconds
                if ($ok) {
                    Write-Log "Start issued. Box will be available in a few minutes." "OK"
                    if ($ConnectAfterWake) { Invoke-PostWakeConnect -Name $Name }
                }
            }
        }

        "Deallocated" {
            # Deallocated is a deeper form of stopped — same treatment
            Write-Log "Dev Box is DEALLOCATED. Issuing start..." "WARN"
            if ($DryRun) {
                Write-Log "[DRY-RUN] Would run: az devcenter dev dev-box start (deallocated)" "DRY"
            } else {
                $ok = Invoke-StartDevBox -Name $Name -Project $Project `
                        -Retries $MaxRetries -RetryDelay $RetryDelaySeconds
                if ($ok) {
                    Write-Log "Start issued for deallocated box." "OK"
                    if ($ConnectAfterWake) { Invoke-PostWakeConnect -Name $Name }
                }
            }
        }

        "Starting" {
            Write-Log "Dev Box is already starting up. Will re-check next round." "INFO"
        }

        "Stopping" {
            Write-Log "Dev Box is stopping right now. Will attempt recovery next round." "WARN"
        }

        "Provisioning*" {
            Write-Log "Dev Box is in provisioning state ($ps). No action needed." "INFO"
        }

        default {
            Write-Log "Unknown or unhandled power state: '$ps'. No action taken." "WARN"
        }
    }
}

function Invoke-PostWakeConnect {
    param([string]$Name)
    # Wait a bit for the box to finish booting before trying SSH
    Write-Log "Waiting 60s for Dev Box to boot before SSH check..."
    Start-Sleep -Seconds 60

    $host = if ($SshHost) { $SshHost } else { $Name }
    Test-SshConnectivity -Host $host | Out-Null
}

# ── Pre-flight checks ─────────────────────────────────────────────────────────

Invoke-LogRotation

Write-Log "============================================================"
Write-Log "  Dev Box Watcher v$($script:VERSION)  (Issue #978)"
Write-Log "  Machine : $env:COMPUTERNAME"
Write-Log "  PID     : $PID"
if ($DryRun) { Write-Log "  *** DRY-RUN MODE — no changes will be made ***" "DRY" }
Write-Log "============================================================"

# Verify az CLI
if (-not (Test-AzLoggedIn)) {
    Write-Log "Azure CLI is not logged in. Run 'az login' first and restart this script." "ERROR"
    exit 1
}
Write-Log "Azure CLI: authenticated OK" "OK"

# Verify devcenter extension
if (-not (Test-AzDevcenterExtension)) {
    Write-Log "Azure CLI devcenter extension not installed. Installing..." "WARN"
    az extension add --name devcenter --yes 2>&1 | Out-Null
    if (-not (Test-AzDevcenterExtension)) {
        Write-Log "Could not install devcenter extension. Run 'az extension add --name devcenter' manually." "ERROR"
        exit 1
    }
    Write-Log "devcenter extension installed." "OK"
}
Write-Log "devcenter extension: OK" "OK"

# Resolve devbox identity
if (-not $DevBoxName -or -not $ProjectName) {
    $info = Resolve-DevBoxInfo
    if ($info) {
        if (-not $DevBoxName)  { $DevBoxName  = $info.name }
        if (-not $ProjectName) { $ProjectName = $info.projectName }
    }
}

if (-not $DevBoxName -or -not $ProjectName) {
    Write-Log "Could not determine DevBoxName / ProjectName. Pass them explicitly as parameters." "ERROR"
    exit 1
}

$endTime     = if ($DurationHours -gt 0) { (Get-Date).AddHours($DurationHours) } else { $null }
$intervalSec = $IntervalMinutes * 60
$durationStr = if ($endTime) { "$DurationHours hours (until $($endTime.ToString('HH:mm')))" } else { "indefinite (Ctrl+C to stop)" }

Write-Log "Dev Box  : $DevBoxName"
Write-Log "Project  : $ProjectName"
Write-Log "Interval : every $IntervalMinutes minutes"
Write-Log "Duration : $durationStr"
Write-Log "Log file : $LogFile"
Write-Log "------------------------------------------------------------"

# ── Main loop ─────────────────────────────────────────────────────────────────

$round = 0

while ($true) {
    if ($endTime -and (Get-Date) -ge $endTime) {
        Write-Log "Duration limit reached. Exiting after $round rounds." "OK"
        break
    }

    $round++

    try {
        Invoke-WatchRound -Name $DevBoxName -Project $ProjectName -Round $round
    } catch {
        Write-Log "Unhandled error in round ${round}: $_" "ERROR"
    }

    # Write heartbeat marker for external monitoring
    $heartbeatFile = Join-Path $env:USERPROFILE ".devbox-watcher-heartbeat"
    @{
        version    = $script:VERSION
        timestamp  = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        round      = $round
        devbox     = $DevBoxName
        project    = $ProjectName
        dryRun     = [bool]$DryRun
        pid        = $PID
    } | ConvertTo-Json | Out-File $heartbeatFile -Force

    if ($endTime -and (Get-Date).AddSeconds($intervalSec) -ge $endTime) {
        Write-Log "Next check would be after duration limit. Exiting." "OK"
        break
    }

    Write-Log "Next check in $IntervalMinutes minutes at $((Get-Date).AddMinutes($IntervalMinutes).ToString('HH:mm:ss'))."
    Start-Sleep -Seconds $intervalSec
}

Write-Log "Dev Box Watcher v$($script:VERSION) finished after $round rounds."
