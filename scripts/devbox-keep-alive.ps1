<#
.SYNOPSIS
    Prevents Azure Dev Box auto-stop and hibernation using the Azure CLI
    devcenter extension (delay-action / skip-action) AND local idle prevention.

.DESCRIPTION
    Issue #888 — "Devboxes still go to sleep and hibernate even though you said
    you fixed that."

    Root cause analysis:
    ────────────────────
    The existing keep-devbox-alive.ps1 only jiggles the mouse to prevent the
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
      • Running the legacy mouse-jiggle as a belt-and-suspenders measure.
      • Logging everything so you can audit why a box did or didn't stay alive.

.PARAMETER DevBoxName
    Name of the Dev Box to keep alive. Auto-detected if omitted.

.PARAMETER ProjectName
    Dev Center project name. Auto-detected if omitted.

.PARAMETER DelayMinutes
    How many minutes to push back each scheduled action (default: 120).

.PARAMETER IntervalSeconds
    How often to check and delay actions (default: 300 = 5 min).

.PARAMETER DurationHours
    How long to run before exiting (default: 0 = indefinitely).

.PARAMETER SkipMouseJiggle
    If set, skip the local mouse-jiggle (useful for headless/SSH sessions).

.EXAMPLE
    # Auto-detect devbox, run indefinitely
    .\devbox-keep-alive.ps1

    # Explicit devbox, run for 8 hours
    .\devbox-keep-alive.ps1 -DevBoxName "tamir-dev" -ProjectName "my-proj" -DurationHours 8

.NOTES
    Requires: Azure CLI with devcenter extension (`az extension add --name devcenter`)
    Permissions: Dev Box User role (standard user — no admin needed for delay-action)
    Related: scripts/keep-devbox-alive.ps1 (legacy mouse-only approach)
#>

[CmdletBinding()]
param(
    [string]$DevBoxName,
    [string]$ProjectName,
    [int]$DelayMinutes = 120,
    [int]$IntervalSeconds = 300,
    [int]$DurationHours = 0,
    [switch]$SkipMouseJiggle
)

$ErrorActionPreference = "Continue"
$script:logFile = Join-Path $env:USERPROFILE ".squad\devbox-keep-alive.log"

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

function Invoke-DelayScheduledActions {
    param([string]$BoxName, [string]$Project, [int]$Minutes)
    <#
        Lists pending actions (auto-stop, hibernate) and delays each one.
        Returns $true if at least one action was delayed, $false otherwise.
    #>
    $actioned = $false
    try {
        $actions = az devcenter dev dev-box list-action `
            --dev-box-name $BoxName `
            --project $Project `
            -o json 2>$null | ConvertFrom-Json

        if (-not $actions -or $actions.Count -eq 0) {
            Log "No pending actions found for '$BoxName'" "INFO"
            return $false
        }

        foreach ($action in $actions) {
            $actionName = $action.name
            $actionType = $action.actionType
            $scheduledAt = $action.scheduledTime
            Log "Found action: $actionName (type=$actionType, scheduled=$scheduledAt)"

            # Try delay-action first
            $delayResult = az devcenter dev dev-box delay-action `
                --dev-box-name $BoxName `
                --project $Project `
                --action-name $actionName `
                --delay-time "$($Minutes)m" `
                -o json 2>&1

            if ($LASTEXITCODE -eq 0) {
                $newTime = ($delayResult | ConvertFrom-Json -ErrorAction SilentlyContinue).scheduledTime
                Log "Delayed '$actionName' by ${Minutes}min → new time: $newTime" "OK"
                $actioned = $true
            } else {
                Log "delay-action failed for '$actionName', trying skip-action..." "WARN"
                $skipResult = az devcenter dev dev-box skip-action `
                    --dev-box-name $BoxName `
                    --project $Project `
                    --action-name $actionName 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Log "Skipped action '$actionName'" "OK"
                    $actioned = $true
                } else {
                    Log "skip-action also failed for '$actionName': $skipResult" "ERROR"
                }
            }
        }
    } catch {
        Log "Error querying/delaying actions: $_" "ERROR"
    }
    return $actioned
}

# ── Main ─────────────────────────────────────────────────────────────────────

Log "═══════════════════════════════════════════════════════════════"
Log "  Dev Box Keep-Alive v2.0 — Issue #888 fix"
Log "  Machine: $env:COMPUTERNAME"
Log "═══════════════════════════════════════════════════════════════"

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
Log "Interval: every $IntervalSeconds seconds"
Log "Delay amount: $DelayMinutes minutes per action"
Log "Log file: $script:logFile"
Log "─────────────────────────────────────────────────────────────"

$round = 0
while ($true) {
    if ($endTime -and (Get-Date) -ge $endTime) {
        Log "Duration expired after $round rounds. Exiting." "OK"
        break
    }

    $round++

    # 1. Server-side: delay/skip scheduled actions
    if ($useAzCli) {
        $delayed = Invoke-DelayScheduledActions -BoxName $DevBoxName -Project $ProjectName -Minutes $DelayMinutes
        if ($delayed) {
            Log "Round ${round}: server-side actions delayed ✓" "OK"
        } else {
            Log "Round ${round}: no server-side actions to delay" "INFO"
        }
    }

    # 2. Client-side: mouse jiggle
    if (-not $SkipMouseJiggle) {
        Invoke-MouseJiggle
    }

    # 3. Heartbeat file (for monitoring/debugging)
    $heartbeat = Join-Path $env:USERPROFILE ".devbox-keepalive"
    @{
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        round     = $round
        devbox    = $DevBoxName
        project   = $ProjectName
        useAzCli  = $useAzCli
    } | ConvertTo-Json | Out-File $heartbeat -Force

    # 4. Periodic status log
    if ($round % 12 -eq 1) {
        $remaining = if ($endTime) { "$([math]::Round(($endTime - (Get-Date)).TotalMinutes, 0)) min remaining" } else { "running indefinitely" }
        Log "💓 Keepalive round $round — $remaining" "OK"
    }

    Start-Sleep -Seconds $IntervalSeconds
}

Log "Dev Box Keep-Alive v2.0 exited after $round rounds."
