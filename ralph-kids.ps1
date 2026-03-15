<#
.SYNOPSIS
    🤖 ראלף לילדים — Ralph Kids Edition
    עוזר מעקב פרויקטים לילדים, עם תמיכה בעברית

.DESCRIPTION
    Ralph is a project monitoring companion for kids.
    Responds to Hebrew commands and provides colorful, encouraging status updates.

.PARAMETER Command
    Hebrew command: תתחיל, תמשיך, סטטוס, עצור

.PARAMETER AgeGroup
    Age group for poll interval: young (30 min), builder (15 min), advanced (10 min)

.EXAMPLE
    pwsh ralph-kids.ps1 -Command "סטטוס"
    pwsh ralph-kids.ps1 -Command "תתחיל"
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = "סטטוס",

    [ValidateSet("young", "builder", "advanced")]
    [string]$AgeGroup = "builder"
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ===== Configuration =====
$script:RalphRunning = $false
$script:PollIntervals = @{
    "young"    = 1800  # 30 minutes for young kids
    "builder"  = 900   # 15 minutes
    "advanced" = 600   # 10 minutes
}

$script:ConfigPath = Join-Path $PSScriptRoot ".squad" "config.json"
$script:StateFile  = Join-Path $PSScriptRoot ".squad" "ralph-state.json"

# ===== Helper Functions =====

function Write-Ralph {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "🤖 " -NoNewline
    Write-Host $Message -ForegroundColor $Color
}

function Write-RalphBanner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║  🤖 ראלף — העוזר שלך לפרויקטים!    ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
}

function Get-ProjectStatus {
    <# Check for issues, open files, and project state #>
    $status = @{
        HasSquad      = Test-Path (Join-Path $PSScriptRoot ".squad")
        HasGit        = Test-Path (Join-Path $PSScriptRoot ".git")
        OpenIssues    = 0
        RecentFiles   = @()
        ProjectHealth = "🟢"
    }

    # Check git status
    if ($status.HasGit) {
        try {
            Push-Location $PSScriptRoot
            $gitStatus = git status --porcelain 2>$null
            $status.ModifiedFiles = ($gitStatus | Measure-Object).Count

            # Try to get GitHub issues
            $issues = gh issue list --state open --limit 5 --json title,number 2>$null | ConvertFrom-Json
            if ($issues) {
                $status.OpenIssues = $issues.Count
                $status.Issues = $issues
            }
            Pop-Location
        }
        catch {
            Pop-Location
        }
    }

    # Find recently modified files
    $recentFiles = Get-ChildItem -Path $PSScriptRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '(node_modules|\.git|\.squad)' -and $_.LastWriteTime -gt (Get-Date).AddHours(-24) } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 5

    $status.RecentFiles = $recentFiles

    return $status
}

function Show-Status {
    Write-RalphBanner

    $status = Get-ProjectStatus

    # Squad status
    if ($status.HasSquad) {
        Write-Ralph "📁 צוות: מוכן ופעיל! ✅" "Green"
    }
    else {
        Write-Ralph "📁 צוות: עדיין לא הוקם. תכתוב 'שלום' ב-Copilot Chat! 💡" "Yellow"
    }

    Write-Host ""

    # Issues
    if ($status.OpenIssues -gt 0) {
        Write-Ralph "📋 יש לך $($status.OpenIssues) משימות פתוחות:" "Cyan"
        foreach ($issue in $status.Issues) {
            $num = $issue.number
            $title = $issue.title
            Write-Host "   🔹 #$num — $title" -ForegroundColor White
        }
    }
    else {
        Write-Ralph "📋 אין משימות פתוחות — אפשר להתחיל משהו חדש! 🎉" "Green"
    }

    Write-Host ""

    # Recent files
    if ($status.RecentFiles.Count -gt 0) {
        Write-Ralph "📝 קבצים שנערכו לאחרונה:" "Cyan"
        foreach ($file in $status.RecentFiles) {
            $name = $file.Name
            $time = $file.LastWriteTime.ToString("HH:mm")
            Write-Host "   📄 $name (שעה $time)" -ForegroundColor White
        }
    }

    Write-Host ""

    # Modified files
    if ($status.ModifiedFiles -gt 0) {
        Write-Ralph "🔄 יש $($status.ModifiedFiles) קבצים שהשתנו — אל תשכח לעשות commit! 💾" "Yellow"
    }
    else {
        Write-Ralph "✅ הכל שמור — כל הכבוד! 🌟" "Green"
    }

    Write-Host ""

    # Encouraging message
    $encouragements = @(
        "🌟 אתה עושה עבודה מעולה! המשך ככה!",
        "💪 כל שורת קוד מקרבת אותך למטרה!",
        "🚀 הפרויקט שלך נראה מדהים!",
        "🎉 ראלף גאה בך! תמשיך לבנות!",
        "⭐ קוד שכתבת היום = ידע לכל החיים!",
        "🏆 מתכנתים אמיתיים לא מוותרים — ואתה מתכנת אמיתי!",
        "🌈 כל באג שתתקן הופך אותך לחזק יותר!"
    )
    $msg = $encouragements | Get-Random
    Write-Ralph $msg "Magenta"
}

function Start-RalphWatch {
    $interval = $script:PollIntervals[$AgeGroup]
    $intervalMin = $interval / 60

    Write-RalphBanner
    Write-Ralph "🚀 ראלף מתחיל לעקוב! (בודק כל $intervalMin דקות)" "Green"
    Write-Ralph "💡 כדי לעצור: pwsh ralph-kids.ps1 -Command עצור" "Yellow"
    Write-Ralph "   או לחץ Ctrl+C" "Yellow"
    Write-Host ""

    # Save state
    $state = @{
        Running   = $true
        StartedAt = (Get-Date).ToString("o")
        AgeGroup  = $AgeGroup
        PID       = $PID
    }

    $squadDir = Join-Path $PSScriptRoot ".squad"
    if (-not (Test-Path $squadDir)) {
        New-Item -ItemType Directory -Path $squadDir -Force | Out-Null
    }
    $state | ConvertTo-Json | Set-Content -Path $script:StateFile -Encoding UTF8

    $script:RalphRunning = $true
    $checkCount = 0

    while ($script:RalphRunning) {
        $checkCount++
        $now = Get-Date -Format "HH:mm"

        Write-Host ""
        Write-Host "───────────────────────────────" -ForegroundColor DarkGray
        Write-Ralph "🔍 בדיקה #$checkCount (שעה $now)" "Cyan"

        Show-Status

        Write-Ralph "⏰ הבדיקה הבאה בעוד $intervalMin דקות..." "DarkGray"

        # Wait with ability to break
        for ($i = 0; $i -lt $interval; $i++) {
            Start-Sleep -Seconds 1
            if (-not $script:RalphRunning) { break }
        }
    }
}

function Stop-Ralph {
    Write-RalphBanner
    Write-Ralph "👋 ראלף הולך לנוח. להתראות!" "Yellow"
    Write-Ralph "💡 להפעלה מחדש: pwsh ralph-kids.ps1 -Command תתחיל" "Cyan"

    if (Test-Path $script:StateFile) {
        $state = Get-Content $script:StateFile -Raw | ConvertFrom-Json
        $state.Running = $false
        $state | ConvertTo-Json | Set-Content -Path $script:StateFile -Encoding UTF8

        # Try to stop running Ralph process
        if ($state.PID -and $state.PID -ne $PID) {
            try {
                Stop-Process -Id $state.PID -Force -ErrorAction SilentlyContinue
                Write-Ralph "✅ ראלף נעצר בהצלחה!" "Green"
            }
            catch {
                Write-Ralph "ℹ️ ראלף כבר לא רץ" "Yellow"
            }
        }
    }
}

function Resume-Ralph {
    Write-RalphBanner
    Write-Ralph "🔄 ראלף חוזר לפעולה!" "Green"
    Start-RalphWatch
}

# ===== Main — Command Router =====

# Normalize Hebrew command
$normalizedCommand = switch -Regex ($Command) {
    '(תתחיל|start|התחל)'       { "start" }
    '(תמשיך|continue|המשך)'    { "continue" }
    '(סטטוס|status|מצב)'       { "status" }
    '(עצור|stop|תעצור)'        { "stop" }
    default                     { "status" }
}

switch ($normalizedCommand) {
    "start"    { Start-RalphWatch }
    "continue" { Resume-Ralph }
    "status"   { Show-Status }
    "stop"     { Stop-Ralph }
}
