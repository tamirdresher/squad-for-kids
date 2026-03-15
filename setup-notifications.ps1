<#
.SYNOPSIS
    🔔 הגדרת התראות — WhatsApp או Discord
    Choose WhatsApp (via Playwright) or Discord webhook for notifications

.DESCRIPTION
    Interactive setup script for Kids Squad notifications.
    WhatsApp Web (PRIMARY) — uses Playwright to open WhatsApp Web, scan QR, and send messages.
    Discord webhook (FALLBACK) — simpler, just paste a URL.

.EXAMPLE
    pwsh setup-notifications.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ConfigDir  = Join-Path $PSScriptRoot ".squad"
$ConfigFile = Join-Path $ConfigDir "notifications-config.json"

# ===== UI Helpers =====

function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  🔔 הגדרת התראות — Kids Squad           ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message, [string]$Color = "White")
    Write-Host "  → " -NoNewline -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✅ " -NoNewline -ForegroundColor Green
    Write-Host $Message -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  ⚠️ " -NoNewline -ForegroundColor Yellow
    Write-Host $Message -ForegroundColor Yellow
}

# ===== WhatsApp Setup (Playwright) =====

function Setup-WhatsApp {
    Write-Host ""
    Write-Host "📱 הגדרת WhatsApp Web" -ForegroundColor Green
    Write-Host "────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    Write-Step "WhatsApp Web דורש Playwright ודפדפן."
    Write-Step "נבדוק אם הכל מותקן..."
    Write-Host ""

    # Check if npm/npx is available
    $npmAvailable = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npmAvailable) {
        Write-Warn "npm לא נמצא. צריך Node.js מותקן."
        Write-Warn "אפשר להשתמש ב-Discord במקום (אפשרות 2)"
        return $null
    }

    # Check/install Playwright
    $playwrightInstalled = npm list playwright 2>$null | Select-String "playwright"
    if (-not $playwrightInstalled) {
        Write-Step "מתקין Playwright..." "Yellow"
        npm install playwright --save-dev 2>$null
        npx playwright install chromium 2>$null
        Write-Success "Playwright מותקן!"
    }
    else {
        Write-Success "Playwright כבר מותקן!"
    }

    Write-Host ""
    Write-Host "📲 שלבים:" -ForegroundColor Cyan
    Write-Host "   1. נפתח חלון דפדפן עם WhatsApp Web" -ForegroundColor White
    Write-Host "   2. סרוק את קוד ה-QR עם הטלפון שלך" -ForegroundColor White
    Write-Host "   3. בחר את הצ'אט שאליו תרצה לשלוח התראות" -ForegroundColor White
    Write-Host "   4. ראלף ישלח הודעה ניסיון" -ForegroundColor White
    Write-Host ""

    $chatName = Read-Host "📝 מה שם הצ'אט ב-WhatsApp? (למשל: 'אבא', 'אמא', שם הקבוצה)"

    if ([string]::IsNullOrWhiteSpace($chatName)) {
        Write-Warn "לא הוזן שם צ'אט. מדלג."
        return $null
    }

    # Create Playwright script for WhatsApp
    $whatsappScript = @"
// WhatsApp Web automation — Kids Squad notifications
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const CONFIG_PATH = path.join(__dirname, '.squad', 'whatsapp-session');

async function sendWhatsAppMessage(chatName, message) {
    // Use persistent context to keep login session
    const userDataDir = CONFIG_PATH;
    if (!fs.existsSync(userDataDir)) {
        fs.mkdirSync(userDataDir, { recursive: true });
    }

    const browser = await chromium.launchPersistentContext(userDataDir, {
        headless: false,
        args: ['--no-sandbox']
    });

    const page = browser.pages()[0] || await browser.newPage();
    await page.goto('https://web.whatsapp.com');

    // Wait for QR scan or auto-login (up to 60 seconds)
    console.log('⏳ מחכה ל-WhatsApp Web... (סרוק QR אם צריך)');
    await page.waitForSelector('[data-testid="chat-list"]', { timeout: 60000 });
    console.log('✅ WhatsApp Web מחובר!');

    // Search for chat
    const searchBox = await page.waitForSelector('[data-testid="chat-list-search"]', { timeout: 10000 });
    await searchBox.click();
    await page.keyboard.type(chatName);
    await page.waitForTimeout(2000);

    // Click first result
    const chatResult = await page.$('[data-testid="cell-frame-container"]');
    if (chatResult) {
        await chatResult.click();
        await page.waitForTimeout(1000);

        // Type and send message
        const msgBox = await page.waitForSelector('[data-testid="conversation-compose-box-input"]');
        await msgBox.click();
        await page.keyboard.type(message);
        await page.keyboard.press('Enter');

        console.log('✅ הודעה נשלחה!');
    } else {
        console.log('❌ לא מצאתי את הצ\'אט: ' + chatName);
    }

    await page.waitForTimeout(3000);
    await browser.close();
}

// Get arguments
const chatName = process.argv[2] || '$chatName';
const message = process.argv[3] || '🤖 ראלף פה! בדיקת התראות — הכל עובד! ✅';

sendWhatsAppMessage(chatName, message).catch(console.error);
"@

    $scriptPath = Join-Path $PSScriptRoot "scripts" "whatsapp-notify.js"
    $scriptsDir = Join-Path $PSScriptRoot "scripts"
    if (-not (Test-Path $scriptsDir)) {
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    }
    $whatsappScript | Set-Content -Path $scriptPath -Encoding UTF8

    Write-Host ""
    Write-Step "שומר הגדרות WhatsApp..." "Cyan"

    $config = @{
        type     = "whatsapp"
        chatName = $chatName
        script   = "scripts/whatsapp-notify.js"
        setupAt  = (Get-Date).ToString("o")
    }

    return $config
}

# ===== Discord Setup =====

function Setup-Discord {
    Write-Host ""
    Write-Host "💬 הגדרת Discord Webhook" -ForegroundColor Blue
    Write-Host "────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "📋 איך לקבל Webhook URL:" -ForegroundColor Cyan
    Write-Host "   1. פתח את Discord" -ForegroundColor White
    Write-Host "   2. לחץ ימני על הערוץ שתרצה" -ForegroundColor White
    Write-Host '   3. בחר "Edit Channel" → "Integrations" → "Webhooks"' -ForegroundColor White
    Write-Host "   4. צור Webhook חדש והעתק את ה-URL" -ForegroundColor White
    Write-Host "   5. הדבק אותו כאן 👇" -ForegroundColor White
    Write-Host ""

    $webhookUrl = Read-Host "🔗 הדבק את ה-Webhook URL"

    if ([string]::IsNullOrWhiteSpace($webhookUrl)) {
        Write-Warn "לא הוזן URL. מדלג."
        return $null
    }

    # Validate URL format
    if ($webhookUrl -notmatch '^https://discord\.com/api/webhooks/') {
        Write-Warn "ה-URL לא נראה כמו Discord Webhook."
        Write-Warn "הוא צריך להתחיל ב: https://discord.com/api/webhooks/"
        $confirm = Read-Host "להמשיך בכל זאת? (כ/ל)"
        if ($confirm -ne "כ" -and $confirm -ne "y") {
            return $null
        }
    }

    # Test the webhook
    Write-Step "שולח הודעת בדיקה..." "Yellow"

    $testPayload = @{
        content  = "🤖 ראלף פה! בדיקת התראות — הכל עובד! ✅"
        username = "🎓 Kids Squad"
    } | ConvertTo-Json -Depth 3

    try {
        $response = Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $testPayload -ContentType "application/json; charset=utf-8"
        Write-Success "הודעת בדיקה נשלחה בהצלחה!"
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 204 -or $_.Exception.Response.StatusCode -eq 200) {
            Write-Success "הודעת בדיקה נשלחה בהצלחה!"
        }
        else {
            Write-Warn "לא הצלחתי לשלוח — בדוק את ה-URL"
            Write-Warn "שגיאה: $($_.Exception.Message)"
        }
    }

    $config = @{
        type       = "discord"
        webhookUrl = $webhookUrl
        setupAt    = (Get-Date).ToString("o")
    }

    return $config
}

# ===== Main Flow =====

Write-Banner

# Check for existing config
if (Test-Path $ConfigFile) {
    $existing = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    Write-Host "  ℹ️ יש כבר הגדרות: $($existing.type)" -ForegroundColor Yellow
    $override = Read-Host "  להגדיר מחדש? (כ/ל)"
    if ($override -ne "כ" -and $override -ne "y") {
        Write-Host "  👍 משתמש בהגדרות הקיימות." -ForegroundColor Green
        exit 0
    }
}

Write-Host "  איך תרצה לקבל התראות?" -ForegroundColor White
Write-Host ""
Write-Host "  1️⃣  📱 WhatsApp Web (מומלץ!)" -ForegroundColor Green
Write-Host "      → שולח הודעות ישירות ל-WhatsApp שלך" -ForegroundColor DarkGray
Write-Host "      → צריך לסרוק QR פעם אחת" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2️⃣  💬 Discord (פשוט יותר)" -ForegroundColor Blue
Write-Host "      → שולח הודעות לערוץ Discord" -ForegroundColor DarkGray
Write-Host "      → רק צריך URL של Webhook" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  3️⃣  ⏭️ אחר כך (דלג)" -ForegroundColor DarkGray
Write-Host ""

$choice = Read-Host "  בחר (1/2/3)"

$config = switch ($choice) {
    "1" { Setup-WhatsApp }
    "2" { Setup-Discord }
    "3" { $null }
    default {
        Write-Warn "בחירה לא תקינה. מדלג."
        $null
    }
}

if ($config) {
    # Save config
    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    $config | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigFile -Encoding UTF8

    Write-Host ""
    Write-Success "הגדרות נשמרו ב: $ConfigFile"
    Write-Host ""
    Write-Host "  💡 לשליחת התראה ידנית:" -ForegroundColor Cyan

    if ($config.type -eq "whatsapp") {
        Write-Host '     node scripts/whatsapp-notify.js "שם-צ''אט" "ההודעה שלך"' -ForegroundColor White
    }
    else {
        Write-Host '     ראלף ישלח התראות אוטומטית! 🤖' -ForegroundColor White
    }
}
else {
    Write-Host ""
    Write-Host "  👍 אפשר להגדיר אחר כך עם:" -ForegroundColor Yellow
    Write-Host "     pwsh setup-notifications.ps1" -ForegroundColor White
}

Write-Host ""
