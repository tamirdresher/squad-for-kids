#!/usr/bin/env pwsh
# ralph-adc-watch.ps1 — Linux-native one-shot Ralph patrol for ADC sandboxes
#
# ADC USAGE:
#   pwsh ./scripts/ralph-adc-watch.ps1
#
# The ADC sandbox lifecycle handles scheduling (cron / keep-alive). This script
# runs ONE patrol cycle and exits — no daemon loop, no Windows APIs.
#
# ENV VARS (all optional):
#   REPO_PATH   — path to cloned repo  (default: ~/tamresearch1)
#   GH_TOKEN    — GitHub token          (default: from existing env / gh auth)
#   PATROL_MSG  — override patrol prompt (default: auto-constructed from charter)
#
# Requires: pwsh 7+, gh CLI authenticated, gh-copilot extension installed
# Tested on: Ubuntu 24.04, PowerShell 7.6.0

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Config ──────────────────────────────────────────────────────────────────
$RepoPath  = $env:REPO_PATH  ?? (Join-Path $HOME "tamresearch1")
$LockFile  = "/tmp/ralph-adc-patrol.lock"
$LogFile   = "/tmp/ralph-adc-patrol.log"
$CharterPath = Join-Path $RepoPath ".squad/agents/ralph/charter.md"
if ($env:GH_TOKEN) { $env:GH_TOKEN = $env:GH_TOKEN }  # pass-through

# ── Logging ─────────────────────────────────────────────────────────────────
function Log([string]$msg) {
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $line = "[$ts] $msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

# ── Dedup lock (Linux file-lock, no Windows Mutex) ───────────────────────────
if (Test-Path $LockFile) {
    $lockAge = (Get-Date) - (Get-Item $LockFile).LastWriteTime
    if ($lockAge.TotalMinutes -lt 10) {
        Log "SKIP: lock file exists and is <10 min old ($LockFile). Another patrol is running."
        exit 0
    }
    Log "WARN: Stale lock file (age=$([int]$lockAge.TotalMinutes)m) — removing."
    Remove-Item $LockFile -Force
}

# Write lock; clean up on exit / error
@{ pid = $PID; started = (Get-Date -Format 'o') } | ConvertTo-Json | Set-Content $LockFile
trap { Remove-Item $LockFile -Force -ErrorAction SilentlyContinue; break }
Register-EngineEvent PowerShell.Exiting -Action { Remove-Item $LockFile -Force -ErrorAction SilentlyContinue } | Out-Null

# ── Build patrol prompt ──────────────────────────────────────────────────────
$patrolPrompt = if ($env:PATROL_MSG) {
    $env:PATROL_MSG
} elseif (Test-Path $CharterPath) {
    "You are Ralph, the Squad work monitor. Charter excerpt: $(Get-Content $CharterPath -Raw | Select-String '(?ms)## What I Own.{0,400}' | Select-Object -ExpandProperty Matches | Select-Object -First 1 -ExpandProperty Value). Run one patrol cycle: check open GitHub issues for stalls, update statuses, and report what you did."
} else {
    "You are Ralph, the Squad work monitor. Run one patrol cycle: check open GitHub issues for stalls, update statuses, and report what you did. Repo is at $RepoPath."
}

# ── Execute patrol via Copilot CLI ───────────────────────────────────────────
Log "START patrol (pid=$PID, repo=$RepoPath)"
Set-Location $RepoPath

$result = gh copilot suggest --target shell $patrolPrompt 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Log "DONE  patrol succeeded"
    $result | ForEach-Object { Log "  > $_" }
} else {
    Log "ERROR patrol exited $exitCode"
    $result | ForEach-Object { Log "  ! $_" }
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    exit $exitCode
}

Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
Log "CLEAN lock removed — patrol complete"
