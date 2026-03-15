# Ralph Watch Kids — גרסת ילדים 🚀
# מריץ את ראלף (הסוכן האוטומטי) כל כמה דקות לבדוק אם יש עבודה חדשה
# להפסקה: Ctrl+C
# חשוב: להריץ עם pwsh (PowerShell 7+)
#
# תכונות:
# - הודעות בעברית 🇮🇱
# - עובד על Windows ו-Linux (Codespace)
# - לא צריך Teams webhook
# - הודעות ידידותיות לילדים

# בדיקת גרסת PowerShell
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "❌ ראלף צריך PowerShell 7+ (pwsh). גרסה נוכחית: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    Write-Host "הריצו עם: pwsh -NoProfile -ExecutionPolicy Bypass -File ralph-watch-kids.ps1" -ForegroundColor Yellow
    exit 1
}

# תיקון UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
if ($IsWindows) {
    chcp 65001 | Out-Null
}

# כותרת חלון
$ralphTitle = "🤖 ראלף - שומר על הפרויקט"
try {
    $Host.UI.RawUI.WindowTitle = $ralphTitle
    [Console]::Title = $ralphTitle
} catch {
    # Linux/Codespace might not support window title
}
Write-Host "`e]0;$ralphTitle`a" -NoNewline

# --- מניעת הפעלה כפולה ---

$lockFile = Join-Path (Get-Location) ".ralph-watch.lock"
if (Test-Path $lockFile) {
    $lockData = Get-Content $lockFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($lockData -and $lockData.pid) {
        $existingProcess = Get-Process -Id $lockData.pid -ErrorAction SilentlyContinue
        if ($existingProcess) {
            Write-Host "⚠️ ראלף כבר רץ! (PID: $($lockData.pid))" -ForegroundColor Yellow
            Write-Host "אם אתם רוצים להפעיל מחדש, מחקו את הקובץ .ralph-watch.lock" -ForegroundColor Yellow
            exit 1
        }
    }
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}

# כתיבת lockfile
[ordered]@{
    pid     = $PID
    started = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
    directory = (Get-Location).Path
} | ConvertTo-Json | Out-File $lockFile -Encoding utf8 -Force

# ניקוי ביציאה
Register-EngineEvent PowerShell.Exiting -Action {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
} | Out-Null
trap {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    break
}

# --- הגדרות ---

$intervalMinutes = 5
$round = 0
$consecutiveFailures = 0

# נתיב לקובץ לוג
$logDir = if ($IsWindows) {
    Join-Path $env:USERPROFILE ".squad"
} else {
    Join-Path $HOME ".squad"
}
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "ralph-watch-kids.log"

# --- פונקציות עזר ---

function Write-RalphLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $entry -Encoding utf8 -ErrorAction SilentlyContinue
}

function Show-KidFriendlyStatus {
    param([string]$Status, [int]$Round)
    $emojis = @("🚀", "⭐", "🎯", "💪", "🔥", "✨", "🎮", "🏆")
    $emoji = $emojis[$Round % $emojis.Length]
    Write-Host ""
    Write-Host "$emoji ראלף סיבוב #$Round — $Status" -ForegroundColor Cyan
    Write-Host ("─" * 50) -ForegroundColor DarkGray
}

# --- פרומפט לראלף ---

$prompt = @'
Ralph, Go! Check for actionable issues and work on them.

RULES FOR KIDS REPO:
1. Check open issues with `gh issue list --search "is:open"`
2. For each issue that needs work — create a branch, make changes, open a PR
3. Be EXTRA careful with code quality — kids are learning from this!
4. Add helpful comments in Hebrew where possible
5. Keep changes small and educational
6. If an issue is a question — answer it with a helpful comment
7. If an issue is a bug — fix it and explain what was wrong
8. If an issue is a feature request — implement it simply

IMPORTANT:
- Use simple, clear code that kids can understand
- Add comments explaining what the code does
- Test everything before creating a PR
- Be encouraging in PR descriptions! Use emojis 🎉
'@

# --- לולאה ראשית ---

Write-Host ""
Write-Host "🤖 ראלף מתעורר! שלום לכולם!" -ForegroundColor Green
Write-Host "📋 בודק את הפרויקט כל $intervalMinutes דקות" -ForegroundColor Cyan
Write-Host "⏹️  להפסקה: Ctrl+C" -ForegroundColor DarkGray
Write-Host ""

while ($true) {
    $round++
    Show-KidFriendlyStatus "מתחיל לעבוד..." $round

    $startTime = Get-Date
    Write-RalphLog "סיבוב $round מתחיל"

    # עדכון lockfile
    [ordered]@{
        pid              = $PID
        started          = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        directory        = (Get-Location).Path
        status           = "running"
        round            = $round
        lastRun          = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
    } | ConvertTo-Json | Out-File $lockFile -Encoding utf8 -Force

    try {
        # הפעלת Copilot CLI עם הפרומפט
        $result = gh copilot suggest "$prompt" 2>&1
        $exitCode = $LASTEXITCODE

        $duration = ((Get-Date) - $startTime).TotalSeconds

        if ($exitCode -eq 0) {
            $consecutiveFailures = 0
            Write-Host "✅ ראלף סיים בהצלחה! (${duration}s)" -ForegroundColor Green
            Write-RalphLog "סיבוב $round הצליח (${duration}s)"
        } else {
            $consecutiveFailures++
            Write-Host "⚠️ ראלף נתקל בבעיה (ניסיון $consecutiveFailures)" -ForegroundColor Yellow
            Write-RalphLog "סיבוב $round נכשל (ניסיון $consecutiveFailures)" "WARN"

            if ($consecutiveFailures -ge 5) {
                Write-Host "😴 ראלף עייף מנסיונות... מנסה שוב בעוד $($intervalMinutes * 2) דקות" -ForegroundColor Yellow
                Start-Sleep -Seconds ($intervalMinutes * 2 * 60)
                $consecutiveFailures = 0
                continue
            }
        }
    } catch {
        $consecutiveFailures++
        Write-Host "❌ שגיאה: $($_.Exception.Message)" -ForegroundColor Red
        Write-RalphLog "שגיאה בסיבוב ${round}: $($_.Exception.Message)" "ERROR"
    }

    # עדכון lockfile אחרי סיום
    [ordered]@{
        pid                  = $PID
        started              = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        directory            = (Get-Location).Path
        status               = "idle"
        round                = $round
        lastRun              = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        exitCode             = $exitCode
        consecutiveFailures  = $consecutiveFailures
    } | ConvertTo-Json | Out-File $lockFile -Encoding utf8 -Force

    # המתנה לסיבוב הבא
    $nextRun = (Get-Date).AddMinutes($intervalMinutes).ToString("HH:mm")
    Write-Host "💤 ראלף נח... סיבוב הבא ב-$nextRun" -ForegroundColor DarkGray
    Start-Sleep -Seconds ($intervalMinutes * 60)
}
