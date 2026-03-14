#Requires -Version 5.1
<#
.SYNOPSIS
    Squad setup script for Yonatan Dresher — Game Dev team.
.DESCRIPTION
    Automated setup of a personalized AI Squad system for Yonatan:
    - Prerequisites check and install (VS Code, Git, Node.js, GitHub CLI)
    - GitHub account creation guidance and authentication
    - Project structure with .squad/ directory and agent charters
    - VS Code configuration with Hebrew-friendly settings
    - Simplified ralph-watch monitor
    - Git init, first commit, and GitHub repo creation
    - Starter HTML5 Canvas game project (Space Invaders)
.PARAMETER DryRun
    Show what would be done without making changes.
.PARAMETER SkipPrereqs
    Skip prerequisite installation checks.
.EXAMPLE
    .\setup-squad-yonatan.ps1
.EXAMPLE
    .\setup-squad-yonatan.ps1 -DryRun
#>
param(
    [switch]$DryRun,
    [switch]$SkipPrereqs
)

# ── UTF-8 Support ──────────────────────────────────────────────
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
if ($PSVersionTable.PSVersion.Major -ge 7) { chcp 65001 | Out-Null }

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Configuration ──────────────────────────────────────────────
$KidName        = "יונתן"
$KidNameEn      = "Yonatan"
$GitHubUser     = "yonatan-dresher"
$GitHubEmail    = "yonatandresher@gmail.com"
$ProjectName    = "yonatan-games"
$ProjectDir     = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Projects\$ProjectName"
$TeamTheme      = "צוות פיתוח המשחקים"
$Agents         = @(
    @{ Id = "gamedev";    Name = "GameDev";    Emoji = "🎮"; Role = "מפתח משחקים";    Desc = "אני כותב קוד JavaScript למשחקים, בונה מנועי פיזיקה, ומתכנת גיימפליי. אני יודע HTML5 Canvas, אנימציות, וכל מה שקשור לפיתוח משחקים." }
    @{ Id = "artbot";     Name = "ArtBot";     Emoji = "🎨"; Role = "מעצב גרפי";      Desc = "אני יוצר עיצובים למשחקים — דמויות, רקעים, אנימציות וצבעים. כל משחק צריך להיראות מגניב!" }
    @{ Id = "bughunter";  Name = "BugHunter";  Emoji = "🐛"; Role = "בודק ומתקן באגים"; Desc = "אני מוצא באגים, בודק שהמשחק עובד כמו שצריך, ומתקן בעיות. שום באג לא בורח ממני!" }
    @{ Id = "ideaguy";    Name = "IdeaGuy";    Emoji = "💡"; Role = "מחולל רעיונות";    Desc = "אני חושב על רעיונות חדשים למשחקים, פיצ'רים מגניבים, ועיצוב שלבים. כל משחק מתחיל מרעיון!" }
)

# ── Color Palette ──────────────────────────────────────────────
$C = @{
    Title   = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Magenta"
    Step    = "White"
    Dim     = "DarkGray"
}

# ── Helper Functions ───────────────────────────────────────────
function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor $C.Title
    Write-Host "║                                                  ║" -ForegroundColor $C.Title
    Write-Host "║   🎮 יונתן — צוות פיתוח המשחקים                  ║" -ForegroundColor $C.Title
    Write-Host "║                                                  ║" -ForegroundColor $C.Title
    Write-Host "║   🎮 GameDev     |  🎨 ArtBot                    ║" -ForegroundColor $C.Title
    Write-Host "║   🐛 BugHunter   |  💡 IdeaGuy                   ║" -ForegroundColor $C.Title
    Write-Host "║                                                  ║" -ForegroundColor $C.Title
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor $C.Title
    Write-Host ""
    if ($DryRun) {
        Write-Host "  ⚠️  מצב הדגמה (DryRun) — לא יבוצעו שינויים" -ForegroundColor $C.Warning
        Write-Host ""
    }
}

function Write-Step {
    param([string]$Emoji, [string]$Text)
    Write-Host ""
    Write-Host "  $Emoji $Text" -ForegroundColor $C.Step
    Write-Host "  $('─' * 50)" -ForegroundColor $C.Dim
}

function Write-Ok    { param([string]$Text) Write-Host "    ✅ $Text" -ForegroundColor $C.Success }
function Write-Warn  { param([string]$Text) Write-Host "    ⚠️  $Text" -ForegroundColor $C.Warning }
function Write-Err   { param([string]$Text) Write-Host "    ❌ $Text" -ForegroundColor $C.Error }
function Write-Detail{ param([string]$Text) Write-Host "    $Text" -ForegroundColor $C.Info }

function Test-CommandExists { param([string]$Cmd) $null -ne (Get-Command $Cmd -ErrorAction SilentlyContinue) }

function Invoke-SafeCommand {
    param([string]$Description, [scriptblock]$Action)
    if ($DryRun) {
        Write-Detail "הדגמה: $Description"
        return
    }
    try {
        & $Action
    } catch {
        Write-Err "$Description — נכשל: $($_.Exception.Message)"
        Write-Warn "אפשר להמשיך, אבל כדאי לבדוק את הבעיה אחר כך"
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 1 — Prerequisites
# ══════════════════════════════════════════════════════════════
function Install-Prerequisites {
    Write-Step "🔧" "בדיקת תוכנות נדרשות"

    # Git
    if (Test-CommandExists "git") {
        $gitVer = git --version 2>&1
        Write-Ok "Git מותקן — $gitVer"
    } else {
        Write-Warn "Git לא מותקן"
        if (-not $DryRun) {
            Write-Detail "מתקין Git..."
            winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            if (Test-CommandExists "git") { Write-Ok "Git הותקן בהצלחה" } else { Write-Err "התקנת Git נכשלה — התקן ידנית מ-https://git-scm.com" }
        }
    }

    # VS Code
    if (Test-CommandExists "code") {
        Write-Ok "VS Code מותקן"
    } else {
        Write-Warn "VS Code לא מותקן"
        if (-not $DryRun) {
            Write-Detail "מתקין VS Code..."
            winget install --id Microsoft.VisualStudioCode -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            if (Test-CommandExists "code") { Write-Ok "VS Code הותקן בהצלחה" } else { Write-Err "התקנת VS Code נכשלה — התקן ידנית מ-https://code.visualstudio.com" }
        }
    }

    # Node.js
    if (Test-CommandExists "node") {
        $nodeVer = node --version 2>&1
        Write-Ok "Node.js מותקן — $nodeVer"
    } else {
        Write-Warn "Node.js לא מותקן"
        if (-not $DryRun) {
            Write-Detail "מתקין Node.js..."
            winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            if (Test-CommandExists "node") { Write-Ok "Node.js הותקן בהצלחה" } else { Write-Err "התקנת Node.js נכשלה — התקן ידנית מ-https://nodejs.org" }
        }
    }

    # GitHub CLI
    if (Test-CommandExists "gh") {
        Write-Ok "GitHub CLI מותקן"
    } else {
        Write-Warn "GitHub CLI לא מותקן"
        if (-not $DryRun) {
            Write-Detail "מתקין GitHub CLI..."
            winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            if (Test-CommandExists "gh") { Write-Ok "GitHub CLI הותקן בהצלחה" } else { Write-Err "התקנת GitHub CLI נכשלה — התקן ידנית מ-https://cli.github.com" }
        }
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 2 — GitHub Authentication
# ══════════════════════════════════════════════════════════════
function Initialize-GitHub {
    Write-Step "🔑" "התחברות ל-GitHub"

    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "כבר מחובר ל-GitHub"
        return
    }

    Write-Detail "אם עדיין אין לך חשבון GitHub, צור אחד כאן:"
    Write-Host "       https://github.com/signup" -ForegroundColor White
    Write-Host ""
    Write-Detail "שם משתמש מומלץ: $GitHubUser"
    Write-Detail "אימייל: $GitHubEmail"
    Write-Host ""

    if ($DryRun) {
        Write-Detail "הדגמה: הייתה מתבצעת התחברות ל-GitHub"
        return
    }

    $ready = Read-Host "    האם יש לך חשבון GitHub ואתה מוכן להתחבר? (כ/ל) [כ]"
    if ($ready -eq "ל") {
        Write-Warn "דילגת על ההתחברות — תוכל להתחבר מאוחר יותר עם: gh auth login"
        return
    }

    Write-Detail "פותח דפדפן להתחברות..."
    gh auth login --web --git-protocol https 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "התחברת ל-GitHub בהצלחה! 🎉"
    } else {
        Write-Warn "ההתחברות לא הצליחה — נסה שוב מאוחר יותר עם: gh auth login"
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 3 — Project Structure
# ══════════════════════════════════════════════════════════════
function New-ProjectStructure {
    Write-Step "📁" "יצירת תיקיית הפרויקט"

    if (Test-Path $ProjectDir) {
        Write-Warn "התיקייה כבר קיימת: $ProjectDir"
        $response = Read-Host "    להמשיך בכל זאת? (כ/ל) [כ]"
        if ($response -eq "ל") {
            Write-Detail "ביטול — לא נעשו שינויים"
            return
        }
    }

    Invoke-SafeCommand "יצירת תיקיות" {
        New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\.squad\decisions\inbox" -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\.vscode" -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\games" -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\assets\images" -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\assets\sounds" -Force | Out-Null

        foreach ($agent in $Agents) {
            New-Item -ItemType Directory -Path "$ProjectDir\.squad\agents\$($agent.Id)" -Force | Out-Null
        }
        Write-Ok "תיקיות נוצרו"
    }

    # ── team.md ─────────────────────────────────────────────
    Invoke-SafeCommand "יצירת team.md" {
        $teamRows = ($Agents | ForEach-Object { "| $($_.Name) | $($_.Emoji) $($_.Role) | ``.squad/agents/$($_.Id)/charter.md`` | ✅ פעיל |" }) -join "`n"
        @"
# $TeamTheme

> הצוות שלי ליצירת משחקים מגניבים!

## חברי הצוות

| שם | תפקיד | תקנון | סטטוס |
|----|--------|-------|-------|
$teamRows
| יונתן דרשר | 🎮 בעל הפרויקט | — | 👤 אנושי |

## איך עובדים

1. יש רעיון למשחק? פותחים Issue ב-GitHub!
2. כל סוכן עוזר בתחום שלו — קוד, עיצוב, בדיקות, רעיונות
3. כותבים קוד, בודקים שעובד, ועושים commit
4. המשחק באוויר! 🚀
"@ | Out-File -FilePath "$ProjectDir\.squad\team.md" -Encoding utf8
    }

    # ── decisions.md ────────────────────────────────────────
    Invoke-SafeCommand "יצירת decisions.md" {
        @"
# החלטות

> כאן נרשמות החלטות חשובות של הצוות.

---

_עדיין אין החלטות — הרשומה הראשונה תתווסף כשתתחיל לעבוד!_
"@ | Out-File -FilePath "$ProjectDir\.squad\decisions.md" -Encoding utf8
    }

    # ── Agent charters ──────────────────────────────────────
    foreach ($agent in $Agents) {
        Invoke-SafeCommand "יצירת charter: $($agent.Name)" {
            @"
# $($agent.Emoji) $($agent.Name) — $($agent.Role)

## מי אני

$($agent.Desc)

## מה אני יודע לעשות

- לעזור עם משימות בתחום שלי
- להציע רעיונות ופתרונות
- לבדוק קוד ולמצוא בעיות
- לעבוד ביחד עם שאר חברי הצוות

## איך מבקשים ממני עזרה

פתח Issue ב-GitHub עם תיוג ``squad:$($agent.Id)`` ואני אטפל בזה!

## הכללים שלי

- אני תמיד מסביר מה אני עושה
- אני שואל שאלות כשמשהו לא ברור
- אני לא משנה קוד בלי לספר קודם
"@ | Out-File -FilePath "$ProjectDir\.squad\agents\$($agent.Id)\charter.md" -Encoding utf8

            "# היסטוריה`n`n_עדיין ריק — כאן יירשמו פעולות שביצעתי._" |
                Out-File -FilePath "$ProjectDir\.squad\agents\$($agent.Id)\history.md" -Encoding utf8
        }
    }

    # ── README.md ───────────────────────────────────────────
    Invoke-SafeCommand "יצירת README.md" {
        @"
# 🎮 $ProjectName — $TeamTheme

> המשחקים של יונתן דרשר

## 📖 על הפרויקט

פרויקט לבניית משחקים מגניבים עם HTML5 Canvas ו-JavaScript!
מנוהל על ידי צוות של סוכני AI שעוזרים בכל שלב.

## 🤖 הצוות שלי

| סוכן | תפקיד |
|-------|--------|
$(($Agents | ForEach-Object { "| $($_.Emoji) $($_.Name) | $($_.Role) |" }) -join "`n")

## 🚀 איך להתחיל

1. פתח את ``games/space-invaders/index.html`` בדפדפן
2. השתמש בחיצים לזוז ורווח לירות!
3. שנה את הקוד ב-``game.js`` כדי להוסיף פיצ'רים

## 📂 מבנה הפרויקט

```
$ProjectName/
├── .squad/              # הגדרות הצוות
├── games/               # המשחקים
│   └── space-invaders/  # המשחק הראשון!
├── assets/              # תמונות וצלילים
└── README.md            # הקובץ הזה!
```

## 🎯 רעיונות למשחקים

- [ ] Space Invaders — המשחק הראשון! 🚀
- [ ] Snake — משחק הנחש הקלאסי 🐍
- [ ] Platformer — משחק קפיצות 🏃
- [ ] Pong — פונג עם חבר 🏓

## 📝 רישיון

פרויקט אישי של יונתן דרשר — $([datetime]::Now.Year)
"@ | Out-File -FilePath "$ProjectDir\README.md" -Encoding utf8
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 4 — VS Code Setup
# ══════════════════════════════════════════════════════════════
function Set-VSCodeConfig {
    Write-Step "💻" "הגדרת VS Code"

    Invoke-SafeCommand "יצירת settings.json" {
        @"
{
    "editor.fontFamily": "'Cascadia Code', 'FiraCode Nerd Font', Consolas, monospace",
    "editor.fontSize": 15,
    "editor.tabSize": 2,
    "editor.wordWrap": "on",
    "editor.formatOnSave": true,
    "editor.minimap.enabled": false,
    "editor.unicodeHighlight.ambiguousCharacters": false,
    "files.encoding": "utf8",
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 2000,
    "terminal.integrated.defaultProfile.windows": "PowerShell",
    "liveServer.settings.doNotShowInfoMsg": true,
    "workbench.colorTheme": "One Dark Pro",
    "workbench.startupEditor": "readme",
    "emmet.includeLanguages": { "javascript": "html" }
}
"@ | Out-File -FilePath "$ProjectDir\.vscode\settings.json" -Encoding utf8
    }

    Invoke-SafeCommand "יצירת extensions.json" {
        @"
{
    "recommendations": [
        "ritwickdey.liveserver",
        "esbenp.prettier-vscode",
        "dbaeumer.vscode-eslint",
        "zhuangtongfa.material-theme",
        "github.copilot",
        "github.copilot-chat",
        "formulahendry.code-runner",
        "eamodio.gitlens",
        "pranaygp.vscode-css-peek"
    ]
}
"@ | Out-File -FilePath "$ProjectDir\.vscode\extensions.json" -Encoding utf8
    }

    if ((Test-CommandExists "code") -and (-not $DryRun)) {
        Write-Detail "מתקין הרחבות מומלצות..."
        $extensions = @("ritwickdey.liveserver", "github.copilot", "github.copilot-chat", "esbenp.prettier-vscode", "eamodio.gitlens")
        foreach ($ext in $extensions) {
            code --install-extension $ext --force 2>&1 | Out-Null
        }
        Write-Ok "הרחבות הותקנו"
    } else {
        Write-Detail "הרחבות יותקנו כשתפתח את VS Code"
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 5 — Ralph Watch (Simplified)
# ══════════════════════════════════════════════════════════════
function New-RalphWatch {
    Write-Step "🔄" "יצירת ralph-watch — מוניטור הפרויקט"

    Invoke-SafeCommand "יצירת ralph-watch.ps1" {
        @'
# Ralph Watch — מוניטור הפרויקט של יונתן
# בודק את ה-Issues ב-GitHub כל 10 דקות
# להפעלה: pwsh ralph-watch.ps1
# לעצירה: Ctrl+C

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$intervalMinutes = 10
$round = 0

function Show-Dashboard {
    param([int]$Round, [array]$Issues, [string]$Status)
    
    Clear-Host
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║  🎮 מוניטור הפרויקט של יונתן           ║" -ForegroundColor Cyan
    Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  🕐 עדכון אחרון: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Magenta
    Write-Host "  🔄 סבב: $Round" -ForegroundColor Magenta
    Write-Host "  📡 סטטוס: $Status" -ForegroundColor Green
    Write-Host ""
    
    # Game-dev specific stats
    Write-Host "  🎮 משחקים בפיתוח:" -ForegroundColor Yellow
    $gameCount = (Get-ChildItem -Path "games" -Directory -ErrorAction SilentlyContinue).Count
    if ($gameCount -gt 0) {
        Write-Host "    🕹️  $gameCount משחקים" -ForegroundColor White
    } else {
        Write-Host "    🕹️  המשחק הראשון מחכה לך!" -ForegroundColor DarkGray
    }
    Write-Host ""
    
    if ($Issues -and $Issues.Count -gt 0) {
        Write-Host "  📋 Issues פתוחים ($($Issues.Count)):" -ForegroundColor Yellow
        Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray
        foreach ($issue in $Issues) {
            $icon = switch -Wildcard ($issue.title) {
                "*bug*"     { "🐛" }
                "*game*"    { "🎮" }
                "*feature*" { "✨" }
                "*art*"     { "🎨" }
                "*idea*"    { "💡" }
                default     { "📌" }
            }
            Write-Host "    $icon #$($issue.number): $($issue.title)" -ForegroundColor White
            if ($issue.labels) {
                $labelText = ($issue.labels | ForEach-Object { $_.name }) -join ", "
                Write-Host "       🏷️  $labelText" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "  🎉 אין Issues פתוחים — הכל מטופל!" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "  ⏱️  עדכון הבא בעוד $intervalMinutes דקות..." -ForegroundColor DarkGray
    Write-Host "  ⛔ Ctrl+C לעצירה" -ForegroundColor DarkGray
    Write-Host ""
}

# Main loop
while ($true) {
    $round++
    try {
        $issues = gh issue list --json number,title,labels --limit 20 2>$null | ConvertFrom-Json
        Show-Dashboard -Round $round -Issues $issues -Status "✅ תקין"
    } catch {
        Show-Dashboard -Round $round -Issues @() -Status "⚠️ שגיאת חיבור"
    }
    
    Start-Sleep -Seconds ($intervalMinutes * 60)
}
'@ | Out-File -FilePath "$ProjectDir\ralph-watch.ps1" -Encoding utf8
        Write-Ok "ralph-watch.ps1 נוצר"
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 6 — Git & GitHub
# ══════════════════════════════════════════════════════════════
function Initialize-GitRepo {
    Write-Step "🌿" "הגדרת Git ו-GitHub"

    Invoke-SafeCommand "יצירת .gitignore" {
        @"
# Node
node_modules/
npm-debug.log

# IDE
.vscode/.history/
*.swp

# OS
.DS_Store
Thumbs.db
desktop.ini

# Build
dist/
build/

# Squad internals
.ralph-watch.lock
"@ | Out-File -FilePath "$ProjectDir\.gitignore" -Encoding utf8
    }

    if ($DryRun) {
        Write-Detail "הדגמה: git init, commit ראשון, ויצירת repo ב-GitHub"
        return
    }

    Push-Location $ProjectDir
    try {
        if (-not (Test-Path "$ProjectDir\.git")) {
            git init 2>&1 | Out-Null
            Write-Ok "Git אותחל"
        }
        git config user.name "$KidNameEn Dresher" 2>&1 | Out-Null
        git config user.email $GitHubEmail 2>&1 | Out-Null

        git add -A 2>&1 | Out-Null
        git commit -m "🎮 התחלה: $TeamTheme" 2>&1 | Out-Null
        Write-Ok "commit ראשון נוצר"

        $repoExists = gh repo view "$GitHubUser/$ProjectName" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Detail "יוצר repo ב-GitHub..."
            gh repo create $ProjectName --private --source . --remote origin --push 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "הרפו נוצר ב-GitHub: https://github.com/$GitHubUser/$ProjectName"
            } else {
                Write-Warn "יצירת הרפו נכשלה — נסה ידנית: gh repo create $ProjectName --private --source . --remote origin --push"
            }
        } else {
            Write-Ok "הרפו כבר קיים ב-GitHub"
            git remote add origin "https://github.com/$GitHubUser/$ProjectName.git" 2>$null
            git push -u origin main 2>&1 | Out-Null
        }
    } finally {
        Pop-Location
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 7 — Starter Project (Space Invaders)
# ══════════════════════════════════════════════════════════════
function New-StarterProject {
    Write-Step "🚀" "יצירת משחק Space Invaders להתחלה"

    $gameDir = "$ProjectDir\games\space-invaders"
    Invoke-SafeCommand "יצירת תיקיית המשחק" {
        New-Item -ItemType Directory -Path $gameDir -Force | Out-Null
    }

    # index.html
    Invoke-SafeCommand "יצירת index.html" {
        @"
<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🚀 פולשי החלל — המשחק של יונתן</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: #0a0a2e;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            font-family: 'Segoe UI', Arial, sans-serif;
            color: white;
        }
        h1 {
            font-size: 2em;
            margin-bottom: 10px;
            background: linear-gradient(90deg, #00d2ff, #7b2ff7);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        #score-board {
            display: flex;
            gap: 30px;
            margin-bottom: 15px;
            font-size: 1.2em;
        }
        .stat { color: #ccc; }
        .stat span { color: #00ff88; font-weight: bold; }
        canvas {
            border: 2px solid #7b2ff7;
            border-radius: 8px;
            box-shadow: 0 0 30px rgba(123, 47, 247, 0.3);
        }
        #instructions {
            margin-top: 15px;
            color: #888;
            font-size: 0.9em;
        }
        #game-over {
            display: none;
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: rgba(0, 0, 0, 0.9);
            padding: 40px;
            border-radius: 15px;
            border: 2px solid #ff4444;
            text-align: center;
        }
        #game-over h2 { color: #ff4444; font-size: 2em; margin-bottom: 10px; }
        #game-over p { color: #ccc; margin-bottom: 20px; }
        #game-over button {
            padding: 10px 30px;
            font-size: 1.1em;
            background: #7b2ff7;
            color: white;
            border: none;
            border-radius: 8px;
            cursor: pointer;
        }
        #game-over button:hover { background: #9b4ff7; }
    </style>
</head>
<body>
    <h1>🚀 פולשי החלל</h1>
    <div id="score-board">
        <div class="stat">ניקוד: <span id="score">0</span></div>
        <div class="stat">חיים: <span id="lives">3</span></div>
        <div class="stat">שלב: <span id="level">1</span></div>
    </div>
    <canvas id="gameCanvas" width="600" height="500"></canvas>
    <p id="instructions">⬅️ ➡️ חיצים לתנועה | רווח לירי | P להשהיה</p>
    <div id="game-over">
        <h2>💥 המשחק נגמר!</h2>
        <p>ניקוד סופי: <span id="final-score">0</span></p>
        <button onclick="restartGame()">🔄 משחק חדש</button>
    </div>
    <script src="game.js"></script>
</body>
</html>
"@ | Out-File -FilePath "$gameDir\index.html" -Encoding utf8
    }

    # game.js
    Invoke-SafeCommand "יצירת game.js" {
        @'
// 🚀 Space Invaders — by Yonatan Dresher
// Built with HTML5 Canvas — no libraries needed!

const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
const scoreEl = document.getElementById('score');
const livesEl = document.getElementById('lives');
const levelEl = document.getElementById('level');
const gameOverEl = document.getElementById('game-over');
const finalScoreEl = document.getElementById('final-score');

// ── Game State ─────────────────────────────────────
let score = 0;
let lives = 3;
let level = 1;
let paused = false;
let gameRunning = true;

// ── Player ─────────────────────────────────────────
const player = {
    x: canvas.width / 2 - 25,
    y: canvas.height - 50,
    width: 50,
    height: 30,
    speed: 6,
    color: '#00ff88'
};

// ── Bullets ────────────────────────────────────────
let bullets = [];
const bulletSpeed = 7;
let canShoot = true;
let shootCooldown = 200; // ms

// ── Enemies ────────────────────────────────────────
let enemies = [];
const enemyRows = 4;
const enemyCols = 8;
const enemyWidth = 40;
const enemyHeight = 25;
let enemyDirection = 1;
let enemySpeed = 1;
let enemyDropAmount = 20;

// ── Stars (background) ────────────────────────────
const stars = [];
for (let i = 0; i < 100; i++) {
    stars.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        size: Math.random() * 2 + 0.5,
        speed: Math.random() * 0.5 + 0.1
    });
}

// ── Input ──────────────────────────────────────────
const keys = {};
document.addEventListener('keydown', (e) => {
    keys[e.key] = true;
    if (e.key === ' ') e.preventDefault();
    if (e.key === 'p' || e.key === 'P') paused = !paused;
});
document.addEventListener('keyup', (e) => { keys[e.key] = false; });

// ── Create Enemies ─────────────────────────────────
function createEnemies() {
    enemies = [];
    const colors = ['#ff6b6b', '#feca57', '#48dbfb', '#ff9ff3'];
    for (let row = 0; row < enemyRows; row++) {
        for (let col = 0; col < enemyCols; col++) {
            enemies.push({
                x: 50 + col * (enemyWidth + 15),
                y: 40 + row * (enemyHeight + 12),
                width: enemyWidth,
                height: enemyHeight,
                alive: true,
                color: colors[row % colors.length]
            });
        }
    }
}

// ── Draw Functions ─────────────────────────────────
function drawStars() {
    ctx.fillStyle = '#fff';
    for (const star of stars) {
        ctx.globalAlpha = 0.3 + Math.random() * 0.5;
        ctx.fillRect(star.x, star.y, star.size, star.size);
        star.y += star.speed;
        if (star.y > canvas.height) { star.y = 0; star.x = Math.random() * canvas.width; }
    }
    ctx.globalAlpha = 1;
}

function drawPlayer() {
    // Ship body
    ctx.fillStyle = player.color;
    ctx.beginPath();
    ctx.moveTo(player.x + player.width / 2, player.y);
    ctx.lineTo(player.x, player.y + player.height);
    ctx.lineTo(player.x + player.width, player.y + player.height);
    ctx.closePath();
    ctx.fill();
    // Engine glow
    ctx.fillStyle = '#ff8800';
    ctx.fillRect(player.x + player.width / 2 - 5, player.y + player.height, 10, 5 + Math.random() * 5);
}

function drawEnemies() {
    for (const enemy of enemies) {
        if (!enemy.alive) continue;
        ctx.fillStyle = enemy.color;
        // Alien body
        ctx.fillRect(enemy.x + 5, enemy.y, enemy.width - 10, enemy.height);
        // Eyes
        ctx.fillStyle = '#000';
        ctx.fillRect(enemy.x + 10, enemy.y + 8, 5, 5);
        ctx.fillRect(enemy.x + enemy.width - 15, enemy.y + 8, 5, 5);
        // Antennae
        ctx.fillStyle = enemy.color;
        ctx.fillRect(enemy.x + 8, enemy.y - 5, 3, 7);
        ctx.fillRect(enemy.x + enemy.width - 11, enemy.y - 5, 3, 7);
    }
}

function drawBullets() {
    ctx.fillStyle = '#00ff88';
    for (const bullet of bullets) {
        ctx.fillRect(bullet.x, bullet.y, 3, 10);
        // Glow effect
        ctx.fillStyle = 'rgba(0, 255, 136, 0.3)';
        ctx.fillRect(bullet.x - 2, bullet.y, 7, 10);
        ctx.fillStyle = '#00ff88';
    }
}

// ── Update Functions ───────────────────────────────
function updatePlayer() {
    if (keys['ArrowLeft'] && player.x > 0) player.x -= player.speed;
    if (keys['ArrowRight'] && player.x < canvas.width - player.width) player.x += player.speed;
    if (keys[' '] && canShoot) {
        bullets.push({ x: player.x + player.width / 2 - 1.5, y: player.y });
        canShoot = false;
        setTimeout(() => { canShoot = true; }, shootCooldown);
    }
}

function updateBullets() {
    bullets = bullets.filter(b => b.y > 0);
    for (const bullet of bullets) {
        bullet.y -= bulletSpeed;
    }
}

function updateEnemies() {
    let hitEdge = false;
    const aliveEnemies = enemies.filter(e => e.alive);
    
    for (const enemy of aliveEnemies) {
        enemy.x += enemySpeed * enemyDirection;
        if (enemy.x <= 0 || enemy.x + enemy.width >= canvas.width) hitEdge = true;
    }
    
    if (hitEdge) {
        enemyDirection *= -1;
        for (const enemy of aliveEnemies) {
            enemy.y += enemyDropAmount;
            // Check if enemies reached the player
            if (enemy.y + enemy.height >= player.y) {
                gameOver();
                return;
            }
        }
    }
}

function checkCollisions() {
    for (const bullet of bullets) {
        for (const enemy of enemies) {
            if (!enemy.alive) continue;
            if (bullet.x >= enemy.x && bullet.x <= enemy.x + enemy.width &&
                bullet.y >= enemy.y && bullet.y <= enemy.y + enemy.height) {
                enemy.alive = false;
                bullet.y = -10; // Remove bullet
                score += 10 * level;
                scoreEl.textContent = score;
            }
        }
    }
    
    // Check if all enemies are dead — next level!
    if (enemies.every(e => !e.alive)) {
        level++;
        levelEl.textContent = level;
        enemySpeed = 1 + (level - 1) * 0.3;
        shootCooldown = Math.max(100, 200 - level * 10);
        createEnemies();
    }
}

function gameOver() {
    gameRunning = false;
    finalScoreEl.textContent = score;
    gameOverEl.style.display = 'block';
}

function restartGame() {
    score = 0; lives = 3; level = 1;
    enemySpeed = 1; enemyDirection = 1;
    shootCooldown = 200;
    scoreEl.textContent = score;
    livesEl.textContent = lives;
    levelEl.textContent = level;
    player.x = canvas.width / 2 - 25;
    bullets = [];
    gameOverEl.style.display = 'none';
    gameRunning = true;
    createEnemies();
}

// ── Game Loop ──────────────────────────────────────
function gameLoop() {
    if (!gameRunning) return;
    if (paused) {
        ctx.fillStyle = 'rgba(0,0,0,0.5)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.fillStyle = '#fff';
        ctx.font = '30px Arial';
        ctx.textAlign = 'center';
        ctx.fillText('⏸️ השהיה — לחץ P להמשך', canvas.width / 2, canvas.height / 2);
        requestAnimationFrame(gameLoop);
        return;
    }

    // Clear
    ctx.fillStyle = '#0a0a2e';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Draw everything
    drawStars();
    drawPlayer();
    drawEnemies();
    drawBullets();

    // Update everything
    updatePlayer();
    updateBullets();
    updateEnemies();
    checkCollisions();

    requestAnimationFrame(gameLoop);
}

// ── Start! ─────────────────────────────────────────
createEnemies();
gameLoop();
'@ | Out-File -FilePath "$gameDir\game.js" -Encoding utf8
        Write-Ok "משחק Space Invaders נוצר! 🚀"
    }
}

# ══════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════
Write-Banner

if (-not $SkipPrereqs) { Install-Prerequisites }
Initialize-GitHub
New-ProjectStructure
Set-VSCodeConfig
New-RalphWatch
New-StarterProject
Initialize-GitRepo

Write-Host ""
Write-Host "  ╔════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║  🎉 ההתקנה הושלמה בהצלחה!                      ║" -ForegroundColor Green
Write-Host "  ╚════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  📂 הפרויקט שלך נמצא כאן:" -ForegroundColor Cyan
Write-Host "     $ProjectDir" -ForegroundColor White
Write-Host ""
Write-Host "  🚀 מה עכשיו?" -ForegroundColor Yellow
Write-Host "     1. פתח את הפרויקט: " -NoNewline -ForegroundColor White
Write-Host "code $ProjectDir" -ForegroundColor Cyan
Write-Host "     2. שחק במשחק: " -NoNewline -ForegroundColor White
Write-Host "פתח games\space-invaders\index.html בדפדפן" -ForegroundColor Cyan
Write-Host "     3. שנה את הקוד: " -NoNewline -ForegroundColor White
Write-Host "ערוך את game.js ב-VS Code" -ForegroundColor Cyan
Write-Host "     4. הפעל מוניטור: " -NoNewline -ForegroundColor White
Write-Host "pwsh ralph-watch.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "  🎮 GameDev | 🎨 ArtBot | 🐛 BugHunter | 💡 IdeaGuy" -ForegroundColor Cyan
Write-Host "  הצוות שלך מוכן — בהצלחה יונתן! 🎮" -ForegroundColor Cyan
Write-Host ""
