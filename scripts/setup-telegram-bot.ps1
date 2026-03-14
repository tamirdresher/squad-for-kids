<#
.SYNOPSIS
    Setup the Squad Telegram Bot — creates config, validates token.

.DESCRIPTION
    Interactive setup script for the Telegram bot.
    1. Prompts for bot token (from @BotFather)
    2. Validates it against Telegram API
    3. Saves to ~/.squad/telegram-config.json
    4. Creates mobile inbox/outbox directories
    5. Optionally locks to your chat ID for security

.EXAMPLE
    .\setup-telegram-bot.ps1
    .\setup-telegram-bot.ps1 -Token "123456:ABC-DEF..."

.NOTES
    Author: B'Elanna (Infrastructure)
#>

param(
    [string]$Token = ""
)

$ErrorActionPreference = "Stop"

$SquadDir    = Join-Path $env:USERPROFILE ".squad"
$ConfigFile  = Join-Path $SquadDir "telegram-config.json"
$InboxDir    = Join-Path $SquadDir "mobile-inbox"
$OutboxDir   = Join-Path $SquadDir "mobile-outbox"

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  Squad Telegram Bot Setup" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Get token
if (-not $Token) {
    Write-Host "You need a Telegram bot token from @BotFather." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Quick steps:" -ForegroundColor White
    Write-Host "  1. Open Telegram and search for @BotFather"
    Write-Host "  2. Send: /newbot"
    Write-Host "  3. Name it: Squad Bot (or whatever you like)"
    Write-Host "  4. Username: your_squad_bot (must end in 'bot')"
    Write-Host "  5. Copy the token BotFather gives you"
    Write-Host ""

    $Token = Read-Host "Paste your bot token here"
    $Token = $Token.Trim()
}

if (-not $Token) {
    Write-Host "ERROR: No token provided." -ForegroundColor Red
    exit 1
}

# Step 2: Validate token
Write-Host ""
Write-Host "Validating token..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$Token/getMe" -Method Get -ErrorAction Stop
    if ($response.ok) {
        $botName = $response.result.first_name
        $botUser = $response.result.username
        Write-Host "Token valid! Bot: @$botUser ($botName)" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Token validation failed." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "ERROR: Could not validate token. Check your internet connection and token." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Step 3: Create directories
Write-Host ""
Write-Host "Creating directories..." -ForegroundColor Yellow

foreach ($dir in @($SquadDir, $InboxDir, $OutboxDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor Green
    } else {
        Write-Host "  Exists:  $dir" -ForegroundColor DarkGray
    }
}

# Step 4: Save config
Write-Host ""
Write-Host "Saving configuration..." -ForegroundColor Yellow

$config = @{
    bot_token        = $Token
    bot_username     = $botUser
    bot_name         = $botName
    allowed_chat_ids = @()
    created_at       = (Get-Date -Format "o")
    notes            = "Created by setup-telegram-bot.ps1. Add your chat ID to allowed_chat_ids for security."
}

$config | ConvertTo-Json -Depth 3 | Set-Content -Path $ConfigFile -Encoding UTF8
Write-Host "  Config saved: $ConfigFile" -ForegroundColor Green

# Step 5: Set environment variable for current session
$env:TELEGRAM_BOT_TOKEN = $Token
Write-Host "  TELEGRAM_BOT_TOKEN set for this session" -ForegroundColor Green

# Step 6: Security note
Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Open Telegram and message @$botUser"
Write-Host "  2. Send /start to the bot"
Write-Host "  3. Run: .\scripts\start-telegram-bot.ps1"
Write-Host ""
Write-Host "Security tip:" -ForegroundColor Yellow
Write-Host "  Send any message to the bot, then check the log for your chat ID."
Write-Host "  Add it to 'allowed_chat_ids' in $ConfigFile to lock the bot to your account."
Write-Host ""
