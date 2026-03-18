<#
.SYNOPSIS
    Prevents Azure Dev Box auto-stop and hibernation using the Azure CLI
    devcenter extension (delay-action / skip-action) AND local idle prevention.

.DESCRIPTION
    Issue #888 — "Devboxes still go to sleep and hibernate even though you said
    you fixed that."

    Root cause analysis:
    ────────────────────
    The legacy keep-devbox-alive.ps1 only jiggles the mouse to prevent the
    *Windows idle timer*. That stops screen-saver style lockouts but does NOT
    prevent the three server-side mechanisms that actually stop/hibernate a
    Dev Box:

      1. Auto-stop schedule — a pool-level cron that shuts down every box at a
         fixed time (e.g. 19:00 UTC). Mouse movement can't override this.
      2. Stop-on-disconnect — when an RDP/browser session disconnects, the pool
         may auto-stop after a grace period (e.g. 60 min). Mouse jiggle inside
         the VM doesn't help if the transport already closed.
      3. Idle-based hibernation — some pool configs hibernate after N minutes of
         no user input *as measured by the hypervisor*, not the guest OS.

    This script addresses ALL THREE by:
      • Periodically calling `az devcenter dev dev-box delay-action` to push
        back any pending auto-stop / hibernate action on the server side.
      • Falling back to `skip-action` if delay-action is not supported.
      • Trying both old and new Azure CLI command variants for compatibility.
      • Running the legacy mouse-jiggle as a belt-and-suspenders measure.
      • Logging everything so you can audit why a box did or didn't stay alive.

    v2.0 bug fix (2025-07):
      The --delay-time parameter requires HH:MM format (e.g. "02:00" for
      120 minutes), NOT "120m". The wrong format caused delay-action to fail
      silently, meaning devboxes were never actually being kept alive by the
      server-side mechanism.

.PARAMETER DevBoxName
    Name of the Dev Box to keep alive. Auto-detected if omitted.

.PARAMETER ProjectName
    Dev Center project name. Auto-detected if omitted.

.PARAMETER DelayMinutes
    How many minutes to push back each scheduled action (default: 120).

.PARAMETER IntervalSeconds
    How often to check and delay actions (default: 1800 = 30 min).

.PARAMETER DurationHours
    How long to run before exiting (default: 0 = indefinitely).

.PARAMETER SkipMouseJiggle
    If set, skip the local mouse-jiggle (useful for headless/SSH sessions).

.EXAMPLE
    # Auto-detect devbox, run indefinitely
    .\devbox-keep-alive.ps1

    # Explicit devbox, run for 8 hours
    .\devbox-keep-alive.ps1 -DevBoxName "tamir-dev" -ProjectName "my-proj" -DurationHours 8

    # Run as a background job
    Start-Process pwsh -ArgumentList "-NoProfile -File scripts\devbox-keep-alive.ps1" -WindowStyle Hidden

.NOTES
    Requires: Azure CLI with devcenter extension (`az extension add --name devcenter`)
    Permissions: Dev Box User role (standard user — no admin needed for delay-action)
    Related: scripts/keep-devbox-alive.ps1 (legacy mouse-only approach — DO NOT rely on it alone)
#>

[CmdletBinding()]
param(
    [string]$DevBoxName,
    [string]$ProjectName,
    [int]$DelayMinutes = 120,
    [int]$IntervalSeconds = 1800,
    [int]$DurationHours = 0,
    [switch]$SkipMouseJiggle
)

$ErrorActionPreference = "Continue"
$script:logFile = Join-Path $env:USERPROFILE ".squad\devbox-keep-alive.log"
$script:VERSION = "2.1.0"

# ── Helpers ──────────────────────────────────────────────────────────────────

function Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Write-Host $line -ForegroundColor $(switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "OK"    { "Green" }
        default { "Gray" }
    })
    $logDir = Split-Path $script:logFile -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    Add-Content -Path $script:logFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
}

function Invoke-LogRotation {
    <# Keep log file under 1 MB by trimming to the last 500 lines #>
    if (Test-Path $script:logFile) {
        $size = (Get-Item $script:logFile).Length
        if ($size -gt 1MB) {
            $lines = Get-Content $script:logFile -Tail 500
            $lines | Set-Content $script:logFile -Encoding utf8
            Log "Log rotated (was $([math]::Round($size / 1KB))KB)" "INFO"
        }
    }
}

function ConvertTo-DelayTimeFormat {
    <# Convert minutes to HH:MM format required by az devcenter delay-action #>
    param([int]$Minutes)
    $hours = [math]::Floor($Minutes / 60)
    $mins = $Minutes % 60
    return "{0:D2}:{1:D2}" -f $hours, $mins
}

function Test-AzLoggedIn {
    <# Verify az CLI is logged in and has a valid token #>
    $account = az account show -o json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $account) {
        return $false
    }
    return $true
}

function Test-AzDevcenterExtension {
    $ext = az extension list --query "[?name=='devcenter']" -o json 2>$null | ConvertFrom-Json
    return ($null -ne $ext -and $ext.Count -gt 0)
}

function Get-DevBoxInfo {
    <# Auto-detect the current devbox name and project from az CLI #>
    Log "Auto-detecting Dev Box configuration..."
    try {
        $boxes = az devcenter dev dev-box list -o json 2>$null | ConvertFrom-Json
        if (-not $boxes -or $boxes.Count -eq 0) {
            Log "No Dev Boxes found for current user" "WARN"
            return $null
        }
        # Prefer running boxes; match current machine name if possible
        $running = $boxes | Where-Object { $_.powerState -eq "Running" -or $_.provisioningState -eq "Succeeded" }
        if ($running) {
            $match = $running | Where-Object { $_.name -like "*$($env:COMPUTERNAME)*" } | Select-Object -First 1
            if (-not $match) { $match = $running | Select-Object -First 1 }
        } else {
            $match = $boxes | Select-Object -First 1
        }
        Log "Detected Dev Box: $($match.name) (project: $($match.projectName))" "OK"
        return $match
    } catch {
        Log "Failed to auto-detect Dev Box: $_" "ERROR"
        return $null
    }
}

function Invoke-MouseJiggle {
    <# Move the cursor 1px and back to prevent OS-level idle detection #>
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class KeepAliveMouseHelper {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
    public static void Jiggle() {
        POINT p; GetCursorPos(out p);
        SetCursorPos(p.X + 1, p.Y);
        System.Threading.Thread.Sleep(50);
        SetCursorPos(p.X, p.Y);
    }
}
"@ -ErrorAction SilentlyContinue
        [KeepAliveMouseHelper]::Jiggle()
    } catch {
        # Headless environment — no mouse available; that's fine.
    }
}

function Get-UpcomingActions {
    <#
        Lists pending actions. Tries both old and new CLI command names
        for compatibility across devcenter extension versions.
    #>
    param([string]$BoxName, [string]$Project)

    # Try the current command name first
    $result = az devcenter dev dev-box list-action `
        --dev-box-name $BoxName `
        --project $Project `
        -o json 2>$null
    if ($LASTEXITCODE -eq 0 -and $result) {
        return ($result | ConvertFrom-Json)
    }

    # Fallback: older/newer CLI versions use different names
    $result = az devcenter dev dev-box list-upcoming-action `
        --dev-box-name $BoxName `
        --project $Project `
        -o json 2>$null
    if ($LASTEXITCODE -eq 0 -and $result) {
        return ($result | ConvertFrom-Json)
    }

    return $null
}

function Invoke-DelayAction {
    <# Delay a single action, trying multiple CLI command variants #>
    param([string]$BoxName, [string]$Project, [string]$ActionName, [string]$DelayTime)

    # Try delay-action (current)
    $result = az devcenter dev dev-box delay-action `
        --dev-box-name $BoxName `
        --project $Project `
        --action-name $ActionName `
        --delay-time $DelayTime `
        -o json 2>&1
    if ($LASTEXITCODE -eq 0) { return @{ success = $true; output = $result } }

    # Try delay-upcoming-action (alternate name)
    $result = az devcenter dev dev-box delay-upcoming-action `
        --dev-box-name $BoxName `
        --project $Project `
        --name $ActionName `
        --delay-time $DelayTime `
        -o json 2>&1
    if ($LASTEXITCODE -eq 0) { return @{ success = $true; output = $result } }

    return @{ success = $false; output = $result }
}

function Invoke-SkipAction {
    <# Skip a single action, trying multiple CLI command variants #>
    param([string]$BoxName, [string]$Project, [string]$ActionName)

    # Try skip-action (current)
    $result = az devcenter dev dev-box skip-action `
        --dev-box-name $BoxName `
        --project $Project `
        --action-name $ActionName 2>&1
    if ($LASTEXITCODE -eq 0) { return @{ success = $true; output = $result } }

    # Try skip-upcoming-action (alternate name)
    $result = az devcenter dev dev-box skip-upcoming-action `
        --dev-box-name $BoxName `
        --project $Project `
        --name $ActionName 2>&1
    if ($LASTEXITCODE -eq 0) { return @{ success = $true; output = $result } }

    return @{ success = $false; output = $result }
}

function Invoke-DelayScheduledActions {
    param([string]$BoxName, [string]$Project, [int]$Minutes)
    <#
        Lists pending actions (auto-stop, hibernate) and delays each one.
        Returns $true if at least one action was delayed/skipped, $false otherwise.
    #>
    $actioned = $false
    $delayTime = ConvertTo-DelayTimeFormat -Minutes $Minutes

    try {
        $actions = Get-UpcomingActions -BoxName $BoxName -Project $Project

        if (-not $actions -or $actions.Count -eq 0) {
            Log "No pending actions found for '$BoxName'" "INFO"
            return $false
        }

        foreach ($action in $actions) {
            $actionName = if ($action.name) { $action.name } else { $action.actionName }
            $actionType = if ($action.actionType) { $action.actionType } else { $action.type }
            $scheduledAt = if ($action.scheduledTime) { $action.scheduledTime } else { $action.sourceId }
            Log "Found action: $actionName (type=$actionType, scheduled=$scheduledAt)"

            # Try delay-action first (format: HH:MM)
            $delayResult = Invoke-DelayAction -BoxName $BoxName -Project $Project `
                -ActionName $actionName -DelayTime $delayTime

            if ($delayResult.success) {
                $parsed = $delayResult.output | ConvertFrom-Json -ErrorAction SilentlyContinue
                $newTime = if ($parsed.scheduledTime) { $parsed.scheduledTime } else { $parsed.nextScheduledTime }
                Log "Delayed '$actionName' by ${Minutes}min (${delayTime}) -> new time: $newTime" "OK"
                $actioned = $true
            } else {
                Log "delay-action failed for '$actionName' (tried HH:MM='$delayTime'), trying skip-action..." "WARN"

                $skipResult = Invoke-SkipAction -BoxName $BoxName -Project $Project -ActionName $actionName

                if ($skipResult.success) {
                    Log "Skipped action '$actionName'" "OK"
                    $actioned = $true
                } else {
                    Log "skip-action also failed for '$actionName': $($skipResult.output)" "ERROR"
                }
            }
        }
    } catch {
        Log "Error querying/delaying actions: $_" "ERROR"
    }
    return $actioned
}

# ── Main ─────────────────────────────────────────────────────────────────────

Invoke-LogRotation

Log "================================================================"
Log "  Dev Box Keep-Alive v$($script:VERSION) -- Issue #888 fix"
Log "  Machine: $env:COMPUTERNAME"
Log "  PID: $PID"
Log "================================================================"

# Check Azure CLI login status
if (-not (Test-AzLoggedIn)) {
    Log "Azure CLI is not logged in. Run 'az login' first." "ERROR"
    Log "Without az CLI auth, only mouse-jiggle is available (insufficient for server-side auto-stop)." "ERROR"
    if ($SkipMouseJiggle) {
        Log "Mouse jiggle also disabled. Nothing to do. Exiting." "ERROR"
        exit 1
    }
}

# Check prerequisites
$hasExtension = Test-AzDevcenterExtension
if (-not $hasExtension) {
    Log "Azure CLI devcenter extension not installed" "WARN"
    Log "Attempting install: az extension add --name devcenter ..."
    az extension add --name devcenter --yes 2>&1 | Out-Null
    $hasExtension = Test-AzDevcenterExtension
    if (-not $hasExtension) {
        Log "Could not install devcenter extension. Falling back to mouse-jiggle only." "ERROR"
        Log "To fix: run 'az extension add --name devcenter' manually, or ask a Dev Center admin" "ERROR"
        Log "to disable auto-stop and stop-on-disconnect for your pool." "ERROR"
    }
}

# Resolve Dev Box identity
$useAzCli = $false
if ($hasExtension) {
    if (-not $DevBoxName -or -not $ProjectName) {
        $info = Get-DevBoxInfo
        if ($info) {
            if (-not $DevBoxName)  { $DevBoxName  = $info.name }
            if (-not $ProjectName) { $ProjectName = $info.projectName }
        }
    }
    if ($DevBoxName -and $ProjectName) {
        $useAzCli = $true
        Log "Will delay/skip scheduled actions for: $DevBoxName (project: $ProjectName)" "OK"
    } else {
        Log "Could not determine DevBoxName/ProjectName. CLI action-delay disabled." "WARN"
    }
}

$mouseMode = if ($SkipMouseJiggle) { "DISABLED" } else { "ENABLED" }
Log "Mouse jiggle: $mouseMode"

$endTime = if ($DurationHours -gt 0) { (Get-Date).AddHours($DurationHours) } else { $null }
$durationStr = if ($endTime) { "$DurationHours hours (until $($endTime.ToString('HH:mm')))" } else { "indefinite (Ctrl+C to stop)" }
Log "Duration: $durationStr"
Log "Interval: every $IntervalSeconds seconds ($([math]::Round($IntervalSeconds / 60, 1)) min)"
Log "Delay amount: $DelayMinutes minutes ($(ConvertTo-DelayTimeFormat -Minutes $DelayMinutes) HH:MM) per action"
Log "Log file: $script:logFile"
Log "----------------------------------------------------------------"

$round = 0
$consecutiveFailures = 0
$maxConsecutiveFailures = 5

while ($true) {
    if ($endTime -and (Get-Date) -ge $endTime) {
        Log "Duration expired after $round rounds. Exiting." "OK"
        break
    }

    $round++

    # 1. Server-side: delay/skip scheduled actions
    if ($useAzCli) {
        try {
            $delayed = Invoke-DelayScheduledActions -BoxName $DevBoxName -Project $ProjectName -Minutes $DelayMinutes
            if ($delayed) {
                Log "Round ${round}: server-side actions delayed/skipped" "OK"
                $consecutiveFailures = 0
            } else {
                Log "Round ${round}: no server-side actions to delay (box may not have auto-stop configured)" "INFO"
                $consecutiveFailures = 0
            }
        } catch {
            $consecutiveFailures++
            Log "Round ${round}: error during delay attempt ($consecutiveFailures consecutive failures): $_" "ERROR"
            if ($consecutiveFailures -ge $maxConsecutiveFailures) {
                Log "Too many consecutive failures ($maxConsecutiveFailures). Re-checking az login status..." "WARN"
                if (-not (Test-AzLoggedIn)) {
                    Log "Azure CLI session expired. Run 'az login' to restore server-side keep-alive." "ERROR"
                }
                $consecutiveFailures = 0
            }
        }
    }

    # 2. Client-side: mouse jiggle
    if (-not $SkipMouseJiggle) {
        Invoke-MouseJiggle
    }

    # 3. Heartbeat file (for monitoring/debugging)
    $heartbeat = Join-Path $env:USERPROFILE ".devbox-keepalive"
    @{
        version   = $script:VERSION
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        round     = $round
        devbox    = $DevBoxName
        project   = $ProjectName
        useAzCli  = $useAzCli
        pid       = $PID
    } | ConvertTo-Json | Out-File $heartbeat -Force

    # 4. Periodic status log (every ~6 hours at 30-min intervals = every 12 rounds)
    if ($round % 12 -eq 1) {
        $remaining = if ($endTime) { "$([math]::Round(($endTime - (Get-Date)).TotalMinutes, 0)) min remaining" } else { "running indefinitely" }
        Log "Keepalive round $round -- $remaining" "OK"
        Invoke-LogRotation
    }

    Start-Sleep -Seconds $IntervalSeconds
}

Log "Dev Box Keep-Alive v$($script:VERSION) exited after $round rounds."
