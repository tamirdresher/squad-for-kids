<#
.SYNOPSIS
    Start the Squad Telegram Bot.

.DESCRIPTION
    Launches the Telegram bot as a background process or in the foreground.
    Checks prerequisites before starting.

.PARAMETER Background
    Run the bot as a detached background process.

.PARAMETER Setup
    Run setup first if no config exists.

.EXAMPLE
    .\start-telegram-bot.ps1              # Foreground (Ctrl+C to stop)
    .\start-telegram-bot.ps1 -Background  # Background process

.NOTES
    Author: B'Elanna (Infrastructure)
#>

param(
    [switch]$Background,
    [switch]$Setup
)

$ErrorActionPreference = "Stop"

$ScriptRoot  = $PSScriptRoot
$RepoRoot    = Split-Path $ScriptRoot -Parent
$BotScript   = Join-Path $ScriptRoot "squad-telegram-bot.py"
$SetupScript = Join-Path $ScriptRoot "setup-telegram-bot.ps1"
$ConfigFile  = Join-Path $env:USERPROFILE ".squad\telegram-config.json"
$PidFile     = Join-Path $env:USERPROFILE ".squad\telegram-bot.pid"

Write-Host ""
Write-Host "Squad Telegram Bot Launcher" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan
Write-Host ""

# Check Python
try {
    $pyVersion = python --version 2>&1
    Write-Host "Python: $pyVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Python not found. Install Python 3.8+." -ForegroundColor Red
    exit 1
}

# Check requests module
$reqCheck = pip show requests 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing 'requests' module..." -ForegroundColor Yellow
    pip install requests
}

# Check config / token
$hasToken = $false

if ($env:TELEGRAM_BOT_TOKEN) {
    Write-Host "Token: from environment variable" -ForegroundColor Green
    $hasToken = $true
} elseif (Test-Path $ConfigFile) {
    Write-Host "Token: from $ConfigFile" -ForegroundColor Green
    $hasToken = $true
}

if (-not $hasToken) {
    Write-Host "No Telegram bot token found!" -ForegroundColor Red
    Write-Host ""

    if ($Setup) {
        Write-Host "Running setup..." -ForegroundColor Yellow
        & $SetupScript
    } else {
        Write-Host "Run setup first:" -ForegroundColor Yellow
        Write-Host "  .\scripts\setup-telegram-bot.ps1" -ForegroundColor White
        Write-Host ""
        Write-Host "Or pass -Setup to this script:" -ForegroundColor Yellow
        Write-Host "  .\scripts\start-telegram-bot.ps1 -Setup" -ForegroundColor White
        exit 1
    }
}

# Check for existing bot process
if (Test-Path $PidFile) {
    $oldPid = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ($oldPid) {
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "Bot already running (PID: $oldPid)" -ForegroundColor Yellow
            Write-Host "Stop it first: Stop-Process -Id $oldPid" -ForegroundColor Yellow
            exit 0
        }
    }
}

# Launch
Write-Host ""
if ($Background) {
    Write-Host "Starting bot in background..." -ForegroundColor Yellow

    $process = Start-Process python -ArgumentList $BotScript `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput (Join-Path $env:USERPROFILE ".squad\telegram-bot-stdout.log") `
        -RedirectStandardError (Join-Path $env:USERPROFILE ".squad\telegram-bot-stderr.log")

    $process.Id | Set-Content $PidFile
    Write-Host "Bot started! PID: $($process.Id)" -ForegroundColor Green
    Write-Host "Logs: ~/.squad/telegram-bot.log" -ForegroundColor DarkGray
    Write-Host "Stop:  Stop-Process -Id $($process.Id)" -ForegroundColor DarkGray
} else {
    Write-Host "Starting bot in foreground (Ctrl+C to stop)..." -ForegroundColor Yellow
    Write-Host ""
    python $BotScript
}
