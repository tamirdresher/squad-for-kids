#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Set up the Windows Task Scheduler entry for the Squad Daily Report (5 AM Israel).

.DESCRIPTION
    Creates a scheduled task named "SquadDailyReport" that fires at 3:00 AM UTC
    every day (= 5 AM Israel Standard Time / 6 AM Israel Daylight Time).
    The script itself handles exact timezone alignment — the scheduler just needs
    to fire in the right ballpark.

    Run once per machine with -Install, or use -Uninstall to remove the task.

.PARAMETER Install
    Install (or update) the scheduled task. Default action when no switch given.

.PARAMETER Uninstall
    Remove the scheduled task from Windows Task Scheduler.

.PARAMETER WhatIf
    Print the task XML that would be registered, but don't register it.

.EXAMPLE
    .\schedule-daily-report.ps1 -Install
    .\schedule-daily-report.ps1 -Uninstall
    .\schedule-daily-report.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$taskName   = "SquadDailyReport"
$taskDesc   = "Squad Daily Report — comprehensive morning summary at 5 AM Israel time. Sends email + Teams card."

# Resolve the actual script path
$scriptDir  = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent }
$reportScript = Join-Path $scriptDir "daily-squad-report.ps1"

if (-not (Test-Path $reportScript)) {
    Write-Error "Cannot find daily-squad-report.ps1 at: $reportScript"
    exit 1
}

# Default to -Install if neither switch was given
if (-not $Install -and -not $Uninstall -and -not $DryRun) {
    $Install = $true
}

# ============================================================================
# UNINSTALL
# ============================================================================

if ($Uninstall) {
    Write-Host "🗑️  Removing scheduled task '$taskName'..."
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Host "✅ Task '$taskName' removed."
    } catch {
        if ($_.Exception.Message -match "cannot find") {
            Write-Warning "Task '$taskName' not found — nothing to remove."
        } else {
            throw
        }
    }
    exit 0
}

# ============================================================================
# BUILD TASK DEFINITION
# ============================================================================

# Trigger: daily at 03:00 UTC  (= 5 AM IST / 6 AM IDT)
# The report script itself re-checks Israel time and skips if outside window.
$triggerTime = "03:00:00"

# Action: pwsh.exe -NonInteractive -File <script>
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
if (-not $pwsh) {
    $pwsh = (Get-Command powershell -ErrorAction SilentlyContinue)?.Source
}
if (-not $pwsh) {
    Write-Error "PowerShell executable (pwsh or powershell) not found in PATH."
    exit 1
}

$taskArgs = "-NonInteractive -NoProfile -ExecutionPolicy Bypass -File `"$reportScript`""

# Principal: run as current user, only when logged on (no UAC elevation needed)
$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERDOMAIN\$env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

$trigger = New-ScheduledTaskTrigger -Daily -At $triggerTime

$action  = New-ScheduledTaskAction `
    -Execute $pwsh `
    -Argument $taskArgs `
    -WorkingDirectory (Split-Path $reportScript -Parent)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew `
    -WakeToRun:$false

# ScheduledTask object (not yet registered)
$task = New-ScheduledTask `
    -Action   $action `
    -Trigger  $trigger `
    -Principal $principal `
    -Settings  $settings `
    -Description $taskDesc

# ============================================================================
# WHATIF / DRY RUN
# ============================================================================

if ($DryRun) {
    Write-Host "`n📋 DryRun — Task definition (not registering):"
    Write-Host "  Name       : $taskName"
    Write-Host "  Description: $taskDesc"
    Write-Host "  Trigger    : Daily at $triggerTime UTC"
    Write-Host "  Executable : $pwsh"
    Write-Host "  Arguments  : $taskArgs"
    Write-Host "  WorkingDir : $(Split-Path $reportScript -Parent)"
    Write-Host ""
    Write-Host "(Re-run without -DryRun to register the task)"
    exit 0
}

# ============================================================================
# INSTALL / UPDATE
# ============================================================================

Write-Host "⏰ Installing scheduled task '$taskName'..."
Write-Host "   Trigger  : Daily at $triggerTime UTC (≈ 5–6 AM Israel)"
Write-Host "   Script   : $reportScript"
Write-Host "   Shell    : $pwsh"

# Check if task already exists
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "   (Task already exists — updating...)"
    Set-ScheduledTask -TaskName $taskName `
        -Action   $action `
        -Trigger  $trigger `
        -Principal $principal `
        -Settings  $settings `
        -Description $taskDesc | Out-Null
    Write-Host "✅ Task '$taskName' updated."
} else {
    Register-ScheduledTask `
        -TaskName   $taskName `
        -InputObject $task | Out-Null
    Write-Host "✅ Task '$taskName' registered."
}

# Verify
$registered = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($registered) {
    $nextRun = (Get-ScheduledTaskInfo -TaskName $taskName).NextRunTime
    Write-Host ""
    Write-Host "📅 Task registered successfully."
    Write-Host "   Next run : $nextRun"
    Write-Host ""
    Write-Host "Tip: Run manually to test:"
    Write-Host "   pwsh -NonInteractive -File `"$reportScript`" -DryRun"
    Write-Host ""
    Write-Host "To remove:"
    Write-Host "   .\schedule-daily-report.ps1 -Uninstall"
} else {
    Write-Error "Task registration may have failed — '$taskName' not found after install."
    exit 1
}
