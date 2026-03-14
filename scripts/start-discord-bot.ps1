<#
.SYNOPSIS
    Start the Squad Discord Bot.

.DESCRIPTION
    Launches the Discord bot with prerequisite checks and lock-file guard.
    Auto-installs discord.js if missing.

.PARAMETER Background
    Run the bot as a detached background process.

.PARAMETER Setup
    Run setup first if no config exists.

.EXAMPLE
    .\start-discord-bot.ps1              # Foreground (Ctrl+C to stop)
    .\start-discord-bot.ps1 -Background  # Background process
    .\start-discord-bot.ps1 -Setup       # Run setup first

.NOTES
    Author: Data (Code Expert)
#>

param(
    [switch]$Background,
    [switch]$Setup
)

$ErrorActionPreference = "Stop"

# Hebrew-friendly console output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
}

$ScriptRoot  = $PSScriptRoot
$RepoRoot    = Split-Path $ScriptRoot -Parent
$BotScript   = Join-Path $ScriptRoot "squad-discord-bot.js"
$SetupScript = Join-Path $ScriptRoot "setup-discord-bot.ps1"
$ConfigFile  = Join-Path $env:USERPROFILE ".squad\discord-config.json"
$PidFile     = Join-Path $env:USERPROFILE ".squad\discord-bot.pid"
$LockFile    = Join-Path $env:USERPROFILE ".squad\discord-bot.lock"

Write-Host ""
Write-Host "Squad Discord Bot Launcher" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

# -------------------------------------------------------
# Lock-file guard: prevent duplicate instances
# -------------------------------------------------------

if (Test-Path $LockFile) {
    try {
        $lockData = Get-Content $LockFile -Raw | ConvertFrom-Json
        $oldPid = $lockData.pid
        if ($oldPid) {
            $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
            if ($proc -and -not $proc.HasExited) {
                Write-Host "Bot already running (PID: $oldPid)" -ForegroundColor Yellow
                Write-Host "Started: $($lockData.started)" -ForegroundColor DarkGray
                Write-Host ""
                Write-Host "To stop it: Stop-Process -Id $oldPid" -ForegroundColor Yellow
                exit 0
            } else {
                Write-Host "Stale lock file found (PID $oldPid not running). Cleaning up." -ForegroundColor DarkGray
                Remove-Item $LockFile -Force
            }
        }
    } catch {
        Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    }
}

# -------------------------------------------------------
# Check Node.js
# -------------------------------------------------------

try {
    $nodeVersion = node --version 2>&1
    Write-Host "Node.js: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Node.js not found. Install Node.js 18+." -ForegroundColor Red
    exit 1
}

# -------------------------------------------------------
# Auto-install discord.js if missing
# -------------------------------------------------------

$nodeModulesDiscord = Join-Path $RepoRoot "node_modules\discord.js"
if (-not (Test-Path $nodeModulesDiscord)) {
    Write-Host "Installing discord.js..." -ForegroundColor Yellow
    Push-Location $RepoRoot
    try {
        npm install discord.js 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to install discord.js" -ForegroundColor Red
            exit 1
        }
        Write-Host "  discord.js installed successfully" -ForegroundColor Green
    } finally {
        Pop-Location
    }
} else {
    Write-Host "discord.js: installed" -ForegroundColor Green
}

# -------------------------------------------------------
# Check config / token
# -------------------------------------------------------

$hasToken = $false

if ($env:DISCORD_BOT_TOKEN -and $env:DISCORD_APP_ID) {
    Write-Host "Token: from environment variables" -ForegroundColor Green
    $hasToken = $true
} elseif (Test-Path $ConfigFile) {
    Write-Host "Token: from $ConfigFile" -ForegroundColor Green
    $hasToken = $true
}

if (-not $hasToken) {
    Write-Host "No Discord bot token found!" -ForegroundColor Red
    Write-Host ""

    if ($Setup) {
        Write-Host "Running setup..." -ForegroundColor Yellow
        & $SetupScript
        $hasToken = $true
    } else {
        Write-Host "Run setup first:" -ForegroundColor Yellow
        Write-Host "  .\scripts\setup-discord-bot.ps1" -ForegroundColor White
        Write-Host ""
        Write-Host "Or pass -Setup to this script:" -ForegroundColor Yellow
        Write-Host "  .\scripts\start-discord-bot.ps1 -Setup" -ForegroundColor White
        exit 1
    }
}

# -------------------------------------------------------
# PID file check (secondary guard)
# -------------------------------------------------------

if (Test-Path $PidFile) {
    $oldPid = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ($oldPid) {
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($proc -and -not $proc.HasExited) {
            Write-Host "Bot already running (PID: $oldPid)" -ForegroundColor Yellow
            Write-Host "Stop it first: Stop-Process -Id $oldPid" -ForegroundColor Yellow
            exit 0
        }
    }
}

# -------------------------------------------------------
# Launch
# -------------------------------------------------------

Write-Host ""

# Write lock file
$lockData = @{
    pid       = $PID
    started   = (Get-Date -Format "o")
    directory = $RepoRoot
    script    = $BotScript
} | ConvertTo-Json
Set-Content -Path $LockFile -Value $lockData -Encoding UTF8

function Remove-LockOnExit {
    if (Test-Path $LockFile) {
        Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $PidFile) {
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
}

if ($Background) {
    Write-Host "Starting bot in background..." -ForegroundColor Yellow

    $logDir = Join-Path $env:USERPROFILE ".squad"
    $process = Start-Process node -ArgumentList $BotScript `
        -WorkingDirectory $RepoRoot `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput (Join-Path $logDir "discord-bot-stdout.log") `
        -RedirectStandardError (Join-Path $logDir "discord-bot-stderr.log")

    # Update lock + PID files with actual process ID
    $process.Id | Set-Content $PidFile
    $lockData = @{
        pid       = $process.Id
        started   = (Get-Date -Format "o")
        directory = $RepoRoot
        script    = $BotScript
    } | ConvertTo-Json
    Set-Content -Path $LockFile -Value $lockData -Encoding UTF8

    Write-Host "Bot started! PID: $($process.Id)" -ForegroundColor Green
    Write-Host "Logs: ~/.squad/discord-bot.log" -ForegroundColor DarkGray
    Write-Host "Stop: Stop-Process -Id $($process.Id)" -ForegroundColor DarkGray
} else {
    Write-Host "Starting bot in foreground (Ctrl+C to stop)..." -ForegroundColor Yellow
    Write-Host ""

    try {
        node $BotScript
    } finally {
        Remove-LockOnExit
    }
}
