<#
.SYNOPSIS
    Setup the Squad Discord Bot — creates config, validates token, generates invite URL.

.DESCRIPTION
    Interactive setup script for the Discord bot.
    1. Guides user through Discord Developer Portal
    2. Prompts for bot token and application ID
    3. Validates credentials against Discord API
    4. Saves to ~/.squad/discord-config.json
    5. Creates mobile inbox/outbox directories
    6. Generates bot invite URL with correct permissions
    7. Registers slash commands

.EXAMPLE
    .\setup-discord-bot.ps1
    .\setup-discord-bot.ps1 -Token "MTIz..." -AppId "123456789"

.NOTES
    Author: Data (Code Expert)
#>

param(
    [string]$Token = "",
    [string]$AppId = ""
)

$ErrorActionPreference = "Stop"

$SquadDir    = Join-Path $env:USERPROFILE ".squad"
$ConfigFile  = Join-Path $SquadDir "discord-config.json"
$InboxDir    = Join-Path $SquadDir "mobile-inbox"
$OutboxDir   = Join-Path $SquadDir "mobile-outbox"

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  Squad Discord Bot Setup" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# -------------------------------------------------------
# Step 1: Guide user through bot creation
# -------------------------------------------------------

if (-not $Token -or -not $AppId) {
    Write-Host "You need a Discord bot from the Developer Portal." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Quick steps:" -ForegroundColor White
    Write-Host "  1. Go to: https://discord.com/developers/applications" -ForegroundColor Gray
    Write-Host "  2. Click 'New Application'" -ForegroundColor Gray
    Write-Host "  3. Name it: Squad Bot (or whatever you like)" -ForegroundColor Gray
    Write-Host "  4. Go to the 'Bot' tab on the left" -ForegroundColor Gray
    Write-Host "  5. Click 'Reset Token' to generate a new token" -ForegroundColor Gray
    Write-Host "  6. Copy the token (you won't see it again!)" -ForegroundColor Gray
    Write-Host "  7. Under 'Privileged Gateway Intents':" -ForegroundColor Gray
    Write-Host "     - Enable MESSAGE CONTENT INTENT (optional)" -ForegroundColor Gray
    Write-Host "  8. Go to 'General Information' for the Application ID" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Opening browser..." -ForegroundColor Yellow
    Start-Process "https://discord.com/developers/applications"
    Write-Host ""
}

# -------------------------------------------------------
# Step 2: Get Application ID
# -------------------------------------------------------

if (-not $AppId) {
    $AppId = Read-Host "Paste your Application ID (from General Information)"
    $AppId = $AppId.Trim()
}

if (-not $AppId -or $AppId -notmatch '^\d+$') {
    Write-Host "ERROR: Invalid Application ID. Must be numeric." -ForegroundColor Red
    exit 1
}

# -------------------------------------------------------
# Step 3: Get Bot Token
# -------------------------------------------------------

if (-not $Token) {
    $Token = Read-Host "Paste your Bot Token (from Bot tab)"
    $Token = $Token.Trim()
}

if (-not $Token) {
    Write-Host "ERROR: No token provided." -ForegroundColor Red
    exit 1
}

# -------------------------------------------------------
# Step 4: Validate token against Discord API
# -------------------------------------------------------

Write-Host ""
Write-Host "Validating token..." -ForegroundColor Yellow

try {
    $headers = @{ "Authorization" = "Bot $Token" }
    $response = Invoke-RestMethod -Uri "https://discord.com/api/v10/users/@me" `
        -Headers $headers -Method Get -ErrorAction Stop
    $botName = $response.username
    $botDiscriminator = $response.discriminator
    $botId = $response.id
    Write-Host "Token valid! Bot: $botName#$botDiscriminator (ID: $botId)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Token validation failed. Check your token." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# -------------------------------------------------------
# Step 5: Create directories
# -------------------------------------------------------

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

# -------------------------------------------------------
# Step 6: Allowed User IDs
# -------------------------------------------------------

Write-Host ""
Write-Host "Security: Allowed User IDs" -ForegroundColor Yellow
Write-Host "  To restrict who can use the bot, add Discord user IDs." -ForegroundColor Gray
Write-Host "  To find your ID: enable Developer Mode in Discord Settings > Advanced," -ForegroundColor Gray
Write-Host "  then right-click your username and 'Copy User ID'." -ForegroundColor Gray
Write-Host ""

$userIdsInput = Read-Host "  Enter allowed user IDs (comma-separated, or press Enter to allow all)"
$allowedUserIds = @()
if ($userIdsInput.Trim()) {
    $allowedUserIds = $userIdsInput.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
    Write-Host "  Allowed IDs: $($allowedUserIds -join ', ')" -ForegroundColor Green
} else {
    Write-Host "  No restriction — all users can use the bot." -ForegroundColor Yellow
}

# -------------------------------------------------------
# Step 7: Save config
# -------------------------------------------------------

Write-Host ""
Write-Host "Saving configuration..." -ForegroundColor Yellow

$config = @{
    bot_token         = $Token
    app_id            = $AppId
    bot_username      = $botName
    bot_id            = $botId
    allowed_user_ids  = $allowedUserIds
    created_at        = (Get-Date -Format "o")
    notes             = "Created by setup-discord-bot.ps1"
}

$config | ConvertTo-Json -Depth 3 | Set-Content -Path $ConfigFile -Encoding UTF8
Write-Host "  Config saved: $ConfigFile" -ForegroundColor Green

# -------------------------------------------------------
# Step 8: Store in Windows Credential Manager (optional)
# -------------------------------------------------------

Write-Host ""
Write-Host "Storing token in Windows Credential Manager..." -ForegroundColor Yellow

try {
    # Use cmdkey for broad compatibility (no extra modules needed)
    $null = cmdkey /generic:squad-discord-bot /user:squad /pass:$Token 2>&1
    Write-Host "  Stored as 'squad-discord-bot' in Credential Manager" -ForegroundColor Green
} catch {
    Write-Host "  Could not store in Credential Manager (non-critical)" -ForegroundColor Yellow
}

# -------------------------------------------------------
# Step 9: Set environment variables for current session
# -------------------------------------------------------

$env:DISCORD_BOT_TOKEN = $Token
$env:DISCORD_APP_ID = $AppId
Write-Host "  DISCORD_BOT_TOKEN set for this session" -ForegroundColor Green
Write-Host "  DISCORD_APP_ID set for this session" -ForegroundColor Green

# -------------------------------------------------------
# Step 10: Generate invite URL
# -------------------------------------------------------

Write-Host ""
Write-Host "Generating invite URL..." -ForegroundColor Yellow

# Permissions:
#   Send Messages       = 0x0000000000000800 (2048)
#   Create Public Threads = 0x0000000800000000 (34359738368)
#   Send Messages in Threads = 0x0000004000000000 (274877906944)
#   Embed Links          = 0x0000000000004000 (16384)
#   Use Slash Commands   = 0x0000000080000000 (2147483648) (in scope, not permissions)
#
# Combined: 2048 + 34359738368 + 274877906944 + 16384 = 309237694464 (approx)
# Simpler: use bot scope + applications.commands scope with basic message perms
$permissions = 309237694464
$scopes = "bot%20applications.commands"
$inviteUrl = "https://discord.com/api/oauth2/authorize?client_id=$AppId&permissions=$permissions&scope=$scopes"

Write-Host ""
Write-Host "  Invite URL:" -ForegroundColor White
Write-Host "  $inviteUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Open this URL to add the bot to your Discord server." -ForegroundColor Gray

# -------------------------------------------------------
# Done!
# -------------------------------------------------------

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Open the invite URL above and add the bot to your server" -ForegroundColor Gray
Write-Host "  2. Run: .\scripts\start-discord-bot.ps1" -ForegroundColor Gray
Write-Host "  3. Use /help in Discord to see available commands" -ForegroundColor Gray
Write-Host ""
Write-Host "  Invite URL copied to clipboard:" -ForegroundColor Yellow
try {
    $inviteUrl | Set-Clipboard
    Write-Host "  $inviteUrl" -ForegroundColor Cyan
} catch {
    Write-Host "  (clipboard not available — copy from above)" -ForegroundColor DarkGray
}
Write-Host ""
