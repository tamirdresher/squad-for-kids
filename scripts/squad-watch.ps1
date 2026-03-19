#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Squad Watch — Cross-platform persistent agent loop for squad-based issue triage.

.DESCRIPTION
    Runs in a loop, checking for actionable GitHub issues on a configurable schedule.
    Designed for upstream contribution to bradygaster/squad.
    
    Features:
    - Cross-platform (PowerShell Core on Windows, macOS, Linux)
    - Configurable via .squad/watch-config.json
    - Heartbeat system (.squad/heartbeat.json)
    - Multi-instance mutex via lock files
    - Self-healing: gh auth checks, retry with exponential backoff
    - Log rotation with configurable retention
    - Graceful shutdown on Ctrl+C

.PARAMETER ConfigPath
    Path to watch-config.json. Defaults to .squad/watch-config.json in the repo root.

.PARAMETER DryRun
    If set, lists issues but does not invoke agents or modify state.

.PARAMETER Once
    Run a single check cycle then exit (useful for cron/scheduled tasks).

.EXAMPLE
    pwsh scripts/squad-watch.ps1
    pwsh scripts/squad-watch.ps1 -DryRun
    pwsh scripts/squad-watch.ps1 -Once
#>

[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$DryRun,
    [switch]$Once
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# Ensure gh uses the EMU account (tamirdresher_microsoft) — required for squad repo access
$env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"

# --- Require PowerShell 7+ ---
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "ERROR: squad-watch requires PowerShell 7+ (pwsh). Current: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    Write-Host "Install: https://aka.ms/powershell-release?tag=stable" -ForegroundColor Yellow
    exit 1
}

# --- UTF-8 output ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
if ($IsWindows) {
    try { chcp 65001 | Out-Null } catch {}
}

# --- Resolve paths ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$SquadDir = Join-Path $RepoRoot '.squad'
$LogDir = Join-Path $SquadDir 'logs'

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $SquadDir 'watch-config.json'
}

# --- Load configuration ---
function Get-WatchConfig {
    $defaults = @{
        checkIntervalMinutes  = 15
        issueLabel            = 'squad'
        repo                  = ''
        maxConcurrentAgents   = 1
        healthCheckUrl        = $null
        logRetentionDays      = 7
        roundTimeoutMinutes   = 30
        maxConsecutiveFailures = 5
        retryBackoffBaseSeconds = 10
    }

    if (Test-Path $ConfigPath) {
        try {
            $loaded = Get-Content -Path $ConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
            foreach ($key in @($defaults.Keys)) {
                $val = $loaded.PSObject.Properties[$key]
                if ($val) { $defaults[$key] = $val.Value }
            }
            Write-Host "[config] Loaded from $ConfigPath" -ForegroundColor DarkGray
        } catch {
            Write-Host "[config] WARNING: Failed to parse $ConfigPath — using defaults. $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[config] No config at $ConfigPath — using defaults" -ForegroundColor Yellow
    }

    # Auto-detect repo from git remote if not configured
    if (-not $defaults.repo) {
        try {
            $remote = git -C $RepoRoot remote get-url origin 2>$null
            if ($remote -match 'github\.com[:/](.+?)(?:\.git)?$') {
                $defaults.repo = $Matches[1]
                Write-Host "[config] Auto-detected repo: $($defaults.repo)" -ForegroundColor DarkGray
            }
        } catch {}
    }

    if (-not $defaults.repo) {
        Write-Host "ERROR: No repo configured and could not detect from git remote." -ForegroundColor Red
        Write-Host "Set 'repo' in $ConfigPath or run from a git repository." -ForegroundColor Yellow
        exit 1
    }

    return $defaults
}

# --- Ensure directories ---
foreach ($dir in @($SquadDir, $LogDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# --- Machine identity ---
$MachineId = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } elseif ($env:HOSTNAME) { $env:HOSTNAME } else { (hostname) }

# --- Logging ---
function Get-LogFilePath {
    $date = Get-Date -Format 'yyyy-MM-dd'
    return Join-Path $LogDir "watch-$date.log"
}

function Write-WatchLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
    $entry = "$ts [$Level] $Message"
    $logPath = Get-LogFilePath

    try {
        Add-Content -Path $logPath -Value $entry -Encoding utf8 -ErrorAction SilentlyContinue
    } catch {}

    switch ($Level) {
        'ERROR' { Write-Host $entry -ForegroundColor Red }
        'WARN'  { Write-Host $entry -ForegroundColor Yellow }
        'DEBUG' { Write-Host $entry -ForegroundColor DarkGray }
        default { Write-Host $entry -ForegroundColor Cyan }
    }
}

function Invoke-LogRetention {
    param([int]$RetentionDays)
    if (-not (Test-Path $LogDir)) { return }
    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    Get-ChildItem -Path $LogDir -Filter 'watch-*.log' | Where-Object { $_.LastWriteTime -lt $cutoff } | ForEach-Object {
        Write-WatchLog "Removing old log: $($_.Name)" -Level DEBUG
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
    }
}

# --- Heartbeat ---
function Update-Heartbeat {
    param(
        [int]$Round,
        [string]$Status,
        [int]$ExitCode = 0,
        [double]$DurationSeconds = 0,
        [int]$ConsecutiveFailures = 0,
        [int]$IssuesFound = 0
    )
    $heartbeatPath = Join-Path $SquadDir 'heartbeat.json'
    $heartbeat = [ordered]@{
        machine            = $MachineId
        pid                = $PID
        lastHeartbeat      = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        round              = $Round
        status             = $Status
        exitCode           = $ExitCode
        durationSeconds    = [math]::Round($DurationSeconds, 2)
        consecutiveFailures = $ConsecutiveFailures
        issuesFound        = $IssuesFound
        repo               = $script:Config.repo
    }
    try {
        $heartbeat | ConvertTo-Json -Depth 3 | Out-File -FilePath $heartbeatPath -Encoding utf8 -Force
    } catch {
        Write-WatchLog "Failed to write heartbeat: $_" -Level WARN
    }
}

# --- Lock file (multi-instance guard) ---
$LockFilePath = Join-Path $SquadDir "ralph-$MachineId.lock"

function Test-LockFile {
    if (-not (Test-Path $LockFilePath)) { return $false }
    try {
        $lock = Get-Content -Path $LockFilePath -Raw -Encoding utf8 | ConvertFrom-Json
        # Check if the PID is still running
        $proc = Get-Process -Id $lock.pid -ErrorAction SilentlyContinue
        if ($proc -and $proc.Id -eq $lock.pid) {
            return $true  # Another instance is alive
        }
        # PID is gone — stale lock
        Write-WatchLog "Removing stale lock (PID $($lock.pid) not running)" -Level WARN
        Remove-Item $LockFilePath -Force -ErrorAction SilentlyContinue
        return $false
    } catch {
        # Corrupt lock file — remove
        Remove-Item $LockFilePath -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Set-LockFile {
    $lock = [ordered]@{
        pid       = $PID
        machine   = $MachineId
        started   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        directory = $RepoRoot
    }
    $lock | ConvertTo-Json | Out-File -FilePath $LockFilePath -Encoding utf8 -Force
}

function Remove-LockFile {
    if (Test-Path $LockFilePath) {
        Remove-Item $LockFilePath -Force -ErrorAction SilentlyContinue
    }
}

# --- gh CLI health checks ---
function Test-GhAuth {
    try {
        $result = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) { return $true }
        Write-WatchLog "gh auth check failed: $result" -Level WARN
        return $false
    } catch {
        Write-WatchLog "gh not found or errored: $_" -Level ERROR
        return $false
    }
}

function Wait-ForGhAuth {
    param([int]$MaxRetries = 3, [int]$BackoffBase = 10)
    for ($i = 1; $i -le $MaxRetries; $i++) {
        if (Test-GhAuth) { return $true }
        $wait = $BackoffBase * [math]::Pow(2, $i - 1)
        Write-WatchLog "gh auth retry $i/$MaxRetries — waiting ${wait}s" -Level WARN
        Start-Sleep -Seconds $wait
    }
    return $false
}

# --- Issue discovery ---
function Get-ActionableIssues {
    param(
        [string]$Repo,
        [string]$Label
    )
    try {
        $args_list = @('issue', 'list', '--repo', $Repo, '--state', 'open', '--json', 'number,title,labels,assignees,updatedAt', '--limit', '50')
        if ($Label) {
            $args_list += @('--label', $Label)
        }
        $raw = & gh @args_list 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-WatchLog "gh issue list failed: $raw" -Level ERROR
            return @()
        }
        $issues = $raw | ConvertFrom-Json
        return $issues
    } catch {
        Write-WatchLog "Issue discovery error: $_" -Level ERROR
        return @()
    }
}

# --- Agent invocation placeholder ---
function Invoke-AgentForIssue {
    param(
        [object]$Issue,
        [string]$Repo
    )
    $num = $Issue.number
    $title = $Issue.title

    if ($DryRun) {
        Write-WatchLog "[DRY RUN] Would process issue #$num — $title" -Level INFO
        return 0
    }

    Write-WatchLog "Processing issue #$num — $title" -Level INFO

    # This is the extensibility point. Downstream consumers override this
    # function or replace this block with their agent invocation.
    # Default: log the issue and return success.
    #
    # Example integration:
    #   gh copilot agent run --repo $Repo --issue $num --prompt "Triage and work on this issue"
    #
    # For now, just log that we would process it.
    Write-WatchLog "Issue #$num ready for agent processing (no agent configured)" -Level WARN
    return 0
}

# --- Health check ping ---
function Send-HealthCheckPing {
    param([string]$Url)
    if (-not $Url) { return }
    try {
        Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 10 | Out-Null
        Write-WatchLog "Health check ping sent to $Url" -Level DEBUG
    } catch {
        Write-WatchLog "Health check ping failed: $_" -Level WARN
    }
}

# --- Graceful shutdown ---
$script:ShutdownRequested = $false

# Register Ctrl+C handler
$null = Register-EngineEvent PowerShell.Exiting -Action {
    $script:ShutdownRequested = $true
    Remove-LockFile
} -ErrorAction SilentlyContinue

trap {
    Write-WatchLog "Caught termination signal — shutting down" -Level WARN
    Update-Heartbeat -Round $script:Round -Status 'stopped' -ConsecutiveFailures $script:ConsecutiveFailures
    Remove-LockFile
    break
}

# Handle Ctrl+C via console
try {
    [Console]::TreatControlCAsInput = $false
    [Console]::CancelKeyPress.Add({
        param($sender, $e)
        $e.Cancel = $true
        $script:ShutdownRequested = $true
    }) | Out-Null
} catch {
    # Not all platforms support CancelKeyPress; trap will handle it
}

# =====================================================================
# MAIN LOOP
# =====================================================================

# Pre-flight checks
if (Test-LockFile) {
    Write-Host "ERROR: Another squad-watch instance is already running on $MachineId" -ForegroundColor Red
    Write-Host "Lock file: $LockFilePath" -ForegroundColor Yellow
    Write-Host "Remove it manually if the other instance is gone." -ForegroundColor Yellow
    exit 1
}

$script:Config = Get-WatchConfig
Set-LockFile

Write-WatchLog "=== Squad Watch started ===" -Level INFO
Write-WatchLog "Machine: $MachineId | PID: $PID | Repo: $($Config.repo)" -Level INFO
Write-WatchLog "Interval: $($Config.checkIntervalMinutes)m | Label: $($Config.issueLabel) | Max agents: $($Config.maxConcurrentAgents)" -Level INFO
Write-WatchLog "DryRun: $DryRun | Once: $Once" -Level INFO

# Set window title if on Windows
if ($IsWindows) {
    try {
        $title = "Squad Watch — $($Config.repo)"
        $Host.UI.RawUI.WindowTitle = $title
        [Console]::Title = $title
    } catch {}
}

# Verify gh auth
if (-not (Wait-ForGhAuth -MaxRetries 3 -BackoffBase $Config.retryBackoffBaseSeconds)) {
    Write-WatchLog "FATAL: Cannot authenticate with gh CLI after retries. Exiting." -Level ERROR
    Remove-LockFile
    exit 1
}

$script:Round = 0
$script:ConsecutiveFailures = 0

# Run log retention on startup
Invoke-LogRetention -RetentionDays $Config.logRetentionDays

while (-not $script:ShutdownRequested) {
    $script:Round++
    $roundStart = Get-Date
    Write-WatchLog "--- Round $($script:Round) starting ---" -Level INFO

    Update-Heartbeat -Round $script:Round -Status 'checking'

    # Re-verify gh auth periodically (self-healing)
    if ($script:Round % 10 -eq 0) {
        if (-not (Test-GhAuth)) {
            Write-WatchLog "gh auth lost — attempting recovery" -Level WARN
            if (-not (Wait-ForGhAuth -MaxRetries 2 -BackoffBase $Config.retryBackoffBaseSeconds)) {
                Write-WatchLog "gh auth recovery failed — skipping round" -Level ERROR
                $script:ConsecutiveFailures++
                Update-Heartbeat -Round $script:Round -Status 'auth-failure' -ConsecutiveFailures $script:ConsecutiveFailures
                if ($script:ConsecutiveFailures -ge $Config.maxConsecutiveFailures) {
                    Write-WatchLog "FATAL: $($script:ConsecutiveFailures) consecutive failures. Exiting." -Level ERROR
                    break
                }
                Start-Sleep -Seconds ($Config.checkIntervalMinutes * 60)
                continue
            }
        }
    }

    # Discover issues
    $issues = Get-ActionableIssues -Repo $Config.repo -Label $Config.issueLabel
    $issueCount = if ($issues) { $issues.Count } else { 0 }
    Write-WatchLog "Found $issueCount open issue(s) with label '$($Config.issueLabel)'" -Level INFO

    $roundExitCode = 0
    $processedCount = 0

    if ($issues -and $issues.Count -gt 0) {
        # Process issues up to maxConcurrentAgents
        $toProcess = $issues | Select-Object -First $Config.maxConcurrentAgents

        foreach ($issue in $toProcess) {
            if ($script:ShutdownRequested) { break }

            $agentResult = Invoke-AgentForIssue -Issue $issue -Repo $Config.repo
            $processedCount++
            if ($agentResult -ne 0) {
                $roundExitCode = $agentResult
            }
        }
    }

    # Calculate round duration
    $roundDuration = ((Get-Date) - $roundStart).TotalSeconds

    # Update state based on results
    if ($roundExitCode -eq 0) {
        $script:ConsecutiveFailures = 0
        Update-Heartbeat -Round $script:Round -Status 'idle' -ExitCode 0 -DurationSeconds $roundDuration -IssuesFound $issueCount
        Write-WatchLog "Round $($script:Round) complete (${roundDuration}s, $processedCount processed)" -Level INFO
    } else {
        $script:ConsecutiveFailures++
        Update-Heartbeat -Round $script:Round -Status 'error' -ExitCode $roundExitCode -DurationSeconds $roundDuration -ConsecutiveFailures $script:ConsecutiveFailures -IssuesFound $issueCount
        Write-WatchLog "Round $($script:Round) failed (exit=$roundExitCode, failures=$($script:ConsecutiveFailures))" -Level ERROR

        if ($script:ConsecutiveFailures -ge $Config.maxConsecutiveFailures) {
            Write-WatchLog "FATAL: $($script:ConsecutiveFailures) consecutive failures reached threshold. Exiting." -Level ERROR
            break
        }
    }

    # Health check ping
    Send-HealthCheckPing -Url $Config.healthCheckUrl

    # Log rotation (once per day, check every 100 rounds)
    if ($script:Round % 100 -eq 0) {
        Invoke-LogRetention -RetentionDays $Config.logRetentionDays
    }

    # Exit if --Once mode
    if ($Once) {
        Write-WatchLog "Single-run mode (--Once) — exiting after round $($script:Round)" -Level INFO
        break
    }

    # Sleep until next check
    Write-WatchLog "Sleeping $($Config.checkIntervalMinutes) minutes until next check..." -Level DEBUG
    $sleepSeconds = $Config.checkIntervalMinutes * 60
    $sleptSoFar = 0
    while ($sleptSoFar -lt $sleepSeconds -and -not $script:ShutdownRequested) {
        $chunk = [math]::Min(10, $sleepSeconds - $sleptSoFar)
        Start-Sleep -Seconds $chunk
        $sleptSoFar += $chunk

        # Update heartbeat timestamp during sleep (every 2 minutes)
        if ($sleptSoFar % 120 -eq 0) {
            Update-Heartbeat -Round $script:Round -Status 'sleeping' -ConsecutiveFailures $script:ConsecutiveFailures
        }
    }
}

# --- Cleanup ---
Write-WatchLog "=== Squad Watch stopped (round $($script:Round)) ===" -Level INFO
Update-Heartbeat -Round $script:Round -Status 'stopped' -ConsecutiveFailures $script:ConsecutiveFailures
Remove-LockFile
exit 0
