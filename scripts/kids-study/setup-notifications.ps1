<#
.SYNOPSIS
    Interactive setup script for notification channels (Hebrew UI).

.DESCRIPTION
    Guides users through setting up Discord webhooks and Telegram bots,
    then saves configuration to notification-config.yaml.
    
    All prompts in Hebrew for ease of use.

.EXAMPLE
    .\setup-notifications.ps1

.NOTES
    - Discord: Simplest option - just a URL, no bot needed
    - Telegram: Requires bot token from @BotFather
    - Output saved to notification-config.yaml in same directory
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ConfigPath = "$PSScriptRoot\notification-config.yaml"

Write-Host @"

╔═════════════════════════════════════════════════╗
║   הגדרות התראות - Notification Setup        ║
║   ההגדרה הקלה ביותר: Discord!                ║
╚═════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Load existing config if available
$config = @{
    discord = @{ webhook_url = "" }
    telegram = @{ bot_token = ""; chat_id = "" }
}

if (Test-Path $ConfigPath) {
    Write-Host "📂 קובץ הגדרות קיים, טוען..." -ForegroundColor Yellow
    try {
        # Load YAML config
        $yamlContent = Get-Content -Path $ConfigPath -Raw
        
        # Simple YAML parser for our use case
        if ($yamlContent -match "webhook_url:\s*[`"`"]?([^`"`"]+)[`"`"]?") {
            $config.discord.webhook_url = $matches[1].Trim()
        }
        if ($yamlContent -match "bot_token:\s*[`"`"]?([^`"`"]+)[`"`"]?") {
            $config.telegram.bot_token = $matches[1].Trim()
        }
        if ($yamlContent -match "chat_id:\s*[`"`"]?([^`"`"]+)[`"`"]?") {
            $config.telegram.chat_id = $matches[1].Trim()
        }
    }
    catch {
        Write-Warning "⚠️  לא ניתן לטעון את קובץ ההגדרות הקיים. מתחילים מחדש..."
    }
}

Write-Host @"

📱 בחרו איזה ערוץ להגדיר:
   1️⃣  Discord (המלצה! - הקל ביותר, רק URL)
   2️⃣  Telegram (דורש token מ-@BotFather)
   3️⃣  שניהם
   0️⃣  יציאה

"@ -ForegroundColor White

$choice = Read-Host "בחירה (0-3)"

function Setup-Discord {
    Write-Host @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔵 Discord Webhook Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

הוראות:
1. פתחו את שרת ה-Discord שלכם
2. לחצו על הגדרות (⚙️) 
3. עברו לـ "Integrations" (אינטגרציות)
4. בחרו "Webhooks"
5. לחצו "New Webhook"
6. בחרו את הערוץ שבו רוצים התראות
7. לחצו "Copy Webhook URL"
8. הדביקו את ה-URL כאן

"@ -ForegroundColor Green

    $webhook = Read-Host "הדביקו את ה-Discord Webhook URL"
    
    if ([string]::IsNullOrWhiteSpace($webhook)) {
        Write-Host "❌ לא הוזן URL תקין" -ForegroundColor Red
        return $false
    }
    
    if (-not ($webhook -match "^https://")) {
        Write-Host "❌ URL חייב להתחיל ב- https://" -ForegroundColor Red
        return $false
    }
    
    $config.discord.webhook_url = $webhook
    Write-Host "✅ Discord webhook שמור!" -ForegroundColor Green
    return $true
}

function Setup-Telegram {
    Write-Host @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔵 Telegram Bot Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

שלב 1: יצירת Bot ב-@BotFather
────────────────────────────
1. פתחו Telegram
2. חפשו @BotFather
3. שלחו /newbot
4. בחרו שם לבוט (למשל: MyStudyBot)
5. בחרו username לבוט (צריך להסתיים ב-bot)
6. BotFather יתן לכם TOKEN - העתיקו אותו!

"@ -ForegroundColor Green

    $botToken = Read-Host "הדביקו את ה-Telegram Bot Token"
    
    if ([string]::IsNullOrWhiteSpace($botToken)) {
        Write-Host "❌ לא הוזן token תקין" -ForegroundColor Red
        return $false
    }
    
    Write-Host @"

שלב 2: קבלת Chat ID
────────────────────────────
1. השלחו הודעה כלשהי לבוט שיצרתם
2. בקליק זה: https://api.telegram.org/bot$botToken/getUpdates
3. חפשו את "chat": {"id": <THIS_NUMBER>}
4. העתיקו את המספר!

"@ -ForegroundColor Cyan

    $chatId = Read-Host "הדביקו את ה-Chat ID"
    
    if ([string]::IsNullOrWhiteSpace($chatId)) {
        Write-Host "❌ לא הוזן Chat ID תקין" -ForegroundColor Red
        return $false
    }
    
    $config.telegram.bot_token = $botToken
    $config.telegram.chat_id = $chatId
    Write-Host "✅ Telegram הודעות מוגדרות!" -ForegroundColor Green
    return $true
}

function Save-Config {
    $yamlContent = @"
# הגדרות התראות - Notification Configuration
# ==========================================

discord:
  webhook_url: "$($config.discord.webhook_url)"

telegram:
  bot_token: "$($config.telegram.bot_token)"
  chat_id: "$($config.telegram.chat_id)"

whatsapp:
  account_sid: ""
  auth_token: ""
  phone_number: ""

# המלצה: השתמשו ב-Discord (הפשוט ביותר!)
# Recommendation: Use Discord (simplest!)
"@
    
    Set-Content -Path $ConfigPath -Value $yamlContent -Encoding UTF8
    Write-Host "✅ הגדרות נשמרו ל: $ConfigPath" -ForegroundColor Green
}

# Main logic
switch ($choice) {
    "1" {
        Setup-Discord
        Save-Config
    }
    "2" {
        Setup-Telegram
        Save-Config
    }
    "3" {
        Setup-Discord
        Setup-Telegram
        Save-Config
    }
    "0" {
        Write-Host "👋 יציאה" -ForegroundColor Yellow
        exit 0
    }
    default {
        Write-Host "❌ בחירה לא תקינה" -ForegroundColor Red
        exit 1
    }
}

Write-Host @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✨ סיום ההגדרות
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

להתחלה עם התראות, השתמשו ב:
.\Start-DailyStudyRoutine.ps1 -NotifyDiscord
או
.\Start-DailyStudyRoutine.ps1 -NotifyTelegram

"@ -ForegroundColor Cyan
