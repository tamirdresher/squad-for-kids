<#
.SYNOPSIS
    Send notifications via Discord, Telegram, or WhatsApp.

.DESCRIPTION
    Unified notification sender supporting multiple channels:
    - Discord (via webhook - simplest, no bot needed)
    - Telegram (via bot token)
    - WhatsApp (via free API, if available)
    
    All output is Hebrew-friendly (UTF-8 encoded).

.PARAMETER Channel
    Notification channel: 'discord', 'telegram', or 'whatsapp'.

.PARAMETER Message
    Notification message content.

.PARAMETER WebhookUrl
    Discord webhook URL.

.PARAMETER BotToken
    Telegram bot token (from @BotFather).

.PARAMETER ChatId
    Telegram chat ID.

.PARAMETER Title
    Optional message title (used for Discord embeds).

.EXAMPLE
    # Discord notification
    .\Send-Notification.ps1 -Channel discord `
        -Message "תוכנית הלימוד ליום חדש" `
        -WebhookUrl "https://discordapp.com/api/webhooks/..."

.EXAMPLE
    # Telegram notification
    .\Send-Notification.ps1 -Channel telegram `
        -Message "תוכנית הלימוד ליום חדש" `
        -BotToken "123456:ABC..." `
        -ChatId "987654321"

.NOTES
    - Discord: Webhook is simplest (URL only, no bot setup needed)
    - Telegram: Requires bot token from @BotFather and chat ID
    - WhatsApp: Requires Twilio account (optional, not implemented yet)
    - All scripts use UTF-8 encoding for Hebrew support
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('discord', 'telegram', 'whatsapp')]
    [string]$Channel,
    
    [Parameter(Mandatory = $true)]
    [string]$Message,
    
    [Parameter()]
    [string]$Title = "",
    
    [Parameter()]
    [string]$WebhookUrl = "",
    
    [Parameter()]
    [string]$BotToken = "",
    
    [Parameter()]
    [string]$ChatId = "",
    
    [Parameter()]
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Ensure UTF-8 encoding
[System.Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "Process")

function Send-DiscordNotification {
    param(
        [string]$Message,
        [string]$Title,
        [string]$WebhookUrl
    )
    
    if (-not $WebhookUrl) {
        throw "Discord webhook URL not provided. Set -WebhookUrl parameter."
    }
    
    if (-not ($WebhookUrl -match "^https://")) {
        throw "Invalid Discord webhook URL format."
    }
    
    $payload = @{
        content = $Message
    } | ConvertTo-Json -Encoding UTF8
    
    if ($Title) {
        $payload = @{
            embeds = @(
                @{
                    title       = $Title
                    description = $Message
                    color       = 3447003  # Blue
                    timestamp   = (Get-Date -Format "o")
                }
            )
        } | ConvertTo-Json -Encoding UTF8
    }
    
    try {
        $response = Invoke-WebRequest -Uri $WebhookUrl `
            -Method Post `
            -ContentType "application/json" `
            -Body $payload `
            -ErrorAction Stop
        
        Write-Host "✓ Discord notification sent successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to send Discord notification: $_"
        return $false
    }
}

function Send-TelegramNotification {
    param(
        [string]$Message,
        [string]$BotToken,
        [string]$ChatId
    )
    
    if (-not $BotToken -or -not $ChatId) {
        throw "Telegram bot token and chat ID required. Set -BotToken and -ChatId parameters."
    }
    
    $telegramApiUrl = "https://api.telegram.org/bot$BotToken/sendMessage"
    
    $payload = @{
        chat_id = $ChatId
        text    = $Message
    } | ConvertTo-Json -Encoding UTF8
    
    try {
        $response = Invoke-WebRequest -Uri $telegramApiUrl `
            -Method Post `
            -ContentType "application/json" `
            -Body $payload `
            -ErrorAction Stop
        
        Write-Host "✓ Telegram notification sent successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to send Telegram notification: $_"
        return $false
    }
}

function Send-WhatsAppNotification {
    param(
        [string]$Message
    )
    
    Write-Warning "WhatsApp notifications not yet implemented. Use Telegram or Discord instead."
    return $false
}

# Main logic
switch ($Channel.ToLower()) {
    "discord" {
        Send-DiscordNotification -Message $Message -Title $Title -WebhookUrl $WebhookUrl
    }
    "telegram" {
        Send-TelegramNotification -Message $Message -BotToken $BotToken -ChatId $ChatId
    }
    "whatsapp" {
        Send-WhatsAppNotification -Message $Message
    }
    default {
        throw "Unknown notification channel: $Channel"
    }
}
