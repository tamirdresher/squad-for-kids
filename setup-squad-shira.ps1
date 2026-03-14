#Requires -Version 5.1
<#
.SYNOPSIS
    Squad setup script for Shira Dresher — Study/Research team.
.DESCRIPTION
    Automated setup of a personalized AI Squad system for Shira:
    - Prerequisites check and install (VS Code, Git, Python, GitHub CLI)
    - GitHub authentication (account already exists: shira-dresher)
    - Project structure with .squad/ directory and agent charters
    - VS Code configuration with Hebrew-friendly settings
    - Simplified ralph-watch monitor
    - Git init, first commit, and GitHub repo creation
    - Starter Python data-analysis project
.PARAMETER DryRun
    Show what would be done without making changes.
.PARAMETER SkipPrereqs
    Skip prerequisite installation checks.
.EXAMPLE
    .\setup-squad-shira.ps1
.EXAMPLE
    .\setup-squad-shira.ps1 -DryRun
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
$KidName        = "שירה"
$KidNameEn      = "Shira"
$GitHubUser     = "shira-dresher"
$GitHubEmail    = "dreshershira@gmail.com"
$ProjectName    = "shira-research"
$ProjectDir     = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Projects\$ProjectName"
$TeamTheme      = "צוות המחקר שלי"
$Agents         = @(
    @{ Id = "study-buddy"; Name = "Study-Buddy";  Emoji = "📚"; Role = "חוקר ועוזר למידה"; Desc = "אני עוזר לך למצוא מידע, לסכם מאמרים, ולהבין נושאים חדשים. אני המומחה שלך למחקר אקדמי." }
    @{ Id = "code-pro";    Name = "Code-Pro";     Emoji = "💻"; Role = "מפתח Python";      Desc = "אני כותב קוד Python, עוזר עם ספריות כמו pandas ו-matplotlib, ומתקן באגים. הקוד שלך בידיים טובות." }
    @{ Id = "design-eye";  Name = "Design-Eye";   Emoji = "🎨"; Role = "מעצב קריאייטיבי";  Desc = "אני עוזר עם עיצוב ויזואלי, גרפים יפים, ופרזנטציות. כל פרויקט צריך להיראות מעולה." }
    @{ Id = "data-viz";    Name = "Data-Viz";     Emoji = "📊"; Role = "אנליסט נתונים";    Desc = "אני מנתח נתונים, יוצר גרפים, ומוצא תובנות מעניינות. תני לי טבלה ואני אהפוך אותה לסיפור." }
)

# ── Color Palette ──────────────────────────────────────────────
$C = @{
    Title   = "Magenta"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Cyan"
    Step    = "White"
    Dim     = "DarkGray"
}

# ── Helper Functions ───────────────────────────────────────────
function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor $C.Title
    Write-Host "║                                                  ║" -ForegroundColor $C.Title
    Write-Host "║   🌟 שירה — צוות המחקר שלי                       ║" -ForegroundColor $C.Title
    Write-Host "║                                                  ║" -ForegroundColor $C.Title
    Write-Host "║   📚 Study-Buddy  |  💻 Code-Pro                 ║" -ForegroundColor $C.Title
    Write-Host "║   🎨 Design-Eye   |  📊 Data-Viz                 ║" -ForegroundColor $C.Title
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
            if (Test-CommandExists "git") { Write-Ok "Git הותקן בהצלחה" } else { Write-Err "התקנת Git נכשלה — התקיני ידנית מ-https://git-scm.com" }
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
            if (Test-CommandExists "code") { Write-Ok "VS Code הותקן בהצלחה" } else { Write-Err "התקנת VS Code נכשלה — התקיני ידנית מ-https://code.visualstudio.com" }
        }
    }

    # Python
    if (Test-CommandExists "python") {
        $pyVer = python --version 2>&1
        Write-Ok "Python מותקן — $pyVer"
    } elseif (Test-CommandExists "python3") {
        $pyVer = python3 --version 2>&1
        Write-Ok "Python מותקן — $pyVer"
    } else {
        Write-Warn "Python לא מותקן"
        if (-not $DryRun) {
            Write-Detail "מתקין Python..."
            winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            if (Test-CommandExists "python") { Write-Ok "Python הותקן בהצלחה" } else { Write-Err "התקנת Python נכשלה — התקיני ידנית מ-https://python.org" }
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
            if (Test-CommandExists "gh") { Write-Ok "GitHub CLI הותקן בהצלחה" } else { Write-Err "התקנת GitHub CLI נכשלה — התקיני ידנית מ-https://cli.github.com" }
        }
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 2 — GitHub Authentication
# ══════════════════════════════════════════════════════════════
function Initialize-GitHub {
    Write-Step "🔑" "התחברות ל-GitHub"
    Write-Detail "החשבון שלך כבר קיים: $GitHubUser"

    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "כבר מחוברת ל-GitHub"
        return
    }

    if ($DryRun) {
        Write-Detail "הדגמה: הייתה מתבצעת התחברות ל-GitHub"
        return
    }

    Write-Detail "פותח דפדפן להתחברות..."
    Write-Detail "השתמשי בחשבון: $GitHubUser ($GitHubEmail)"
    gh auth login --web --git-protocol https 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "התחברת ל-GitHub בהצלחה! 🎉"
    } else {
        Write-Warn "ההתחברות לא הצליחה — נסי שוב מאוחר יותר עם: gh auth login"
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
        # Main dirs
        New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\.squad\decisions\inbox" -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\.vscode" -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\data" -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\notebooks" -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\output" -Force | Out-Null

        # Agent directories
        foreach ($agent in $Agents) {
            $agentDir = "$ProjectDir\.squad\agents\$($agent.Id)"
            New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
        }
        Write-Ok "תיקיות נוצרו"
    }

    # ── team.md ─────────────────────────────────────────────
    Invoke-SafeCommand "יצירת team.md" {
        $teamRows = ($Agents | ForEach-Object { "| $($_.Name) | $($_.Emoji) $($_.Role) | ``.squad/agents/$($_.Id)/charter.md`` | ✅ פעיל |" }) -join "`n"
        @"
# $TeamTheme

> הצוות שלי לפרויקטים של מחקר, קוד, ועיצוב.

## חברי הצוות

| שם | תפקיד | תקנון | סטטוס |
|----|--------|-------|-------|
$teamRows
| שירה דרשר | 👩‍🎓 בעלת הפרויקט | — | 👤 אנושי |

## איך עובדים

1. פותחים Issue ב-GitHub עם תיאור המשימה
2. הסוכנים עוזרים — כל אחד בתחום שלו
3. עושים Pull Request ובודקים את הקוד
4. ממזגים ל-main — סיום! 🎉
"@ | Out-File -FilePath "$ProjectDir\.squad\team.md" -Encoding utf8
    }

    # ── decisions.md ────────────────────────────────────────
    Invoke-SafeCommand "יצירת decisions.md" {
        @"
# החלטות

> כאן נרשמות החלטות חשובות של הצוות.

---

_עדיין אין החלטות — הרשומה הראשונה תתווסף כשתתחילי לעבוד!_
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

פתחי Issue ב-GitHub עם תיוג ``squad:$($agent.Id)`` ואני אטפל בזה!

## הכללים שלי

- אני תמיד מסביר מה אני עושה
- אני שואל שאלות כשמשהו לא ברור
- אני לא משנה קוד בלי לספר קודם
"@ | Out-File -FilePath "$ProjectDir\.squad\agents\$($agent.Id)\charter.md" -Encoding utf8

            # Empty history
            "# היסטוריה`n`n_עדיין ריק — כאן יירשמו פעולות שביצעתי._" |
                Out-File -FilePath "$ProjectDir\.squad\agents\$($agent.Id)\history.md" -Encoding utf8
        }
    }

    # ── README.md ───────────────────────────────────────────
    Invoke-SafeCommand "יצירת README.md" {
        @"
# 🌟 $ProjectName — $TeamTheme

> פרויקט המחקר של שירה דרשר

## 📖 על הפרויקט

פרויקט לניתוח נתונים, מחקר, ויצירת ויזואליזציות ב-Python.
מנוהל על ידי צוות של סוכני AI שעוזרים בכל שלב.

## 🤖 הצוות שלי

| סוכן | תפקיד |
|-------|--------|
$(($Agents | ForEach-Object { "| $($_.Emoji) $($_.Name) | $($_.Role) |" }) -join "`n")

## 🚀 איך להתחיל

```bash
# התקנת ספריות Python
pip install -r requirements.txt

# הרצת ניתוח לדוגמה
python notebooks/analysis_starter.py
```

## 📂 מבנה הפרויקט

```
$ProjectName/
├── .squad/          # הגדרות הצוות
├── data/            # קבצי נתונים
├── notebooks/       # סקריפטים לניתוח
├── output/          # תוצרים וגרפים
├── requirements.txt # ספריות Python
└── README.md        # הקובץ הזה!
```

## 📝 רישיון

פרויקט אישי של שירה דרשר — $([datetime]::Now.Year)
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
    "editor.tabSize": 4,
    "editor.wordWrap": "on",
    "editor.formatOnSave": true,
    "editor.minimap.enabled": false,
    "editor.unicodeHighlight.ambiguousCharacters": false,
    "files.encoding": "utf8",
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 2000,
    "terminal.integrated.defaultProfile.windows": "PowerShell",
    "python.defaultInterpreterPath": "python",
    "python.analysis.typeCheckingMode": "basic",
    "jupyter.askForKernelRestart": false,
    "workbench.colorTheme": "One Dark Pro",
    "workbench.startupEditor": "readme"
}
"@ | Out-File -FilePath "$ProjectDir\.vscode\settings.json" -Encoding utf8
    }

    Invoke-SafeCommand "יצירת extensions.json" {
        @"
{
    "recommendations": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "ms-toolsai.jupyter",
        "zhuangtongfa.material-theme",
        "github.copilot",
        "github.copilot-chat",
        "formulahendry.code-runner",
        "mechatroner.rainbow-csv",
        "eamodio.gitlens"
    ]
}
"@ | Out-File -FilePath "$ProjectDir\.vscode\extensions.json" -Encoding utf8
    }

    # Install extensions
    if ((Test-CommandExists "code") -and (-not $DryRun)) {
        Write-Detail "מתקין הרחבות מומלצות..."
        $extensions = @("ms-python.python", "ms-toolsai.jupyter", "github.copilot", "github.copilot-chat", "eamodio.gitlens")
        foreach ($ext in $extensions) {
            code --install-extension $ext --force 2>&1 | Out-Null
        }
        Write-Ok "הרחבות הותקנו"
    } else {
        Write-Detail "הרחבות יותקנו כשתפתחי את VS Code"
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 5 — Ralph Watch (Simplified)
# ══════════════════════════════════════════════════════════════
function New-RalphWatch {
    Write-Step "🔄" "יצירת ralph-watch — מוניטור הפרויקט"

    Invoke-SafeCommand "יצירת ralph-watch.ps1" {
        @'
# Ralph Watch — מוניטור הפרויקט של שירה
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
    Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "  ║  📚 מוניטור הפרויקט של שירה            ║" -ForegroundColor Magenta
    Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  🕐 עדכון אחרון: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "  🔄 סבב: $Round" -ForegroundColor Cyan
    Write-Host "  📡 סטטוס: $Status" -ForegroundColor Green
    Write-Host ""
    
    if ($Issues -and $Issues.Count -gt 0) {
        Write-Host "  📋 Issues פתוחים ($($Issues.Count)):" -ForegroundColor Yellow
        Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray
        foreach ($issue in $Issues) {
            $icon = switch -Wildcard ($issue.title) {
                "*bug*"     { "🐛" }
                "*feature*" { "✨" }
                "*data*"    { "📊" }
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
# Python
__pycache__/
*.py[cod]
*.egg-info/
dist/
build/
.eggs/
*.egg
.venv/
venv/

# Jupyter
.ipynb_checkpoints/

# IDE
.vscode/.history/
*.swp

# OS
.DS_Store
Thumbs.db
desktop.ini

# Output
output/*.png
output/*.csv

# Squad internals
.ralph-watch.lock
"@ | Out-File -FilePath "$ProjectDir\.gitignore" -Encoding utf8
    }

    Invoke-SafeCommand "requirements.txt" {
        @"
pandas>=2.0
matplotlib>=3.7
seaborn>=0.12
numpy>=1.24
"@ | Out-File -FilePath "$ProjectDir\requirements.txt" -Encoding utf8
    }

    if ($DryRun) {
        Write-Detail "הדגמה: git init, commit ראשון, ויצירת repo ב-GitHub"
        return
    }

    Push-Location $ProjectDir
    try {
        # Git init
        if (-not (Test-Path "$ProjectDir\.git")) {
            git init 2>&1 | Out-Null
            Write-Ok "Git אותחל"
        }
        git config user.name "$KidNameEn Dresher" 2>&1 | Out-Null
        git config user.email $GitHubEmail 2>&1 | Out-Null

        # First commit
        git add -A 2>&1 | Out-Null
        git commit -m "🚀 התחלה: $TeamTheme" 2>&1 | Out-Null
        Write-Ok "commit ראשון נוצר"

        # Create GitHub repo
        $repoExists = gh repo view "$GitHubUser/$ProjectName" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Detail "יוצר repo ב-GitHub..."
            gh repo create $ProjectName --private --source . --remote origin --push 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "הרפו נוצר ב-GitHub: https://github.com/$GitHubUser/$ProjectName"
            } else {
                Write-Warn "יצירת הרפו נכשלה — נסי ידנית: gh repo create $ProjectName --private --source . --remote origin --push"
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
#  STEP 7 — Starter Project
# ══════════════════════════════════════════════════════════════
function New-StarterProject {
    Write-Step "🐍" "יצירת פרויקט Python להתחלה"

    # Sample CSV data
    Invoke-SafeCommand "יצירת קובץ נתונים לדוגמה" {
        @"
שם,גיל,ציון_מתמטיקה,ציון_אנגלית,ציון_מדעים,עיר
דנה,16,92,88,95,תל אביב
יוסי,15,78,91,82,חיפה
מיכל,16,95,85,90,ירושלים
אורי,15,88,72,87,באר שבע
נועה,17,90,94,92,רעננה
איתי,16,75,80,78,הרצליה
שירה,15,98,92,96,תל אביב
עמית,16,82,77,85,נתניה
ליאת,15,91,89,88,חיפה
רון,17,86,83,91,ירושלים
"@ | Out-File -FilePath "$ProjectDir\data\grades_sample.csv" -Encoding utf8
        Write-Ok "קובץ נתונים לדוגמה נוצר"
    }

    # Python analysis starter
    Invoke-SafeCommand "יצירת סקריפט ניתוח לדוגמה" {
        @'
"""
📊 ניתוח ציונים — פרויקט התחלתי
================================
סקריפט שמנתח קובץ ציונים ויוצר גרפים.
נוצר אוטומטית על ידי הצוות של שירה!
"""

import pandas as pd
import matplotlib.pyplot as plt
import os

# ── הגדרות ──────────────────────────────────────
plt.rcParams['font.family'] = 'Arial'
plt.rcParams['axes.unicode_minus'] = False

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'output')
DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data')
os.makedirs(OUTPUT_DIR, exist_ok=True)


def load_data():
    """טוענת את קובץ הנתונים"""
    csv_path = os.path.join(DATA_DIR, 'grades_sample.csv')
    df = pd.read_csv(csv_path, encoding='utf-8')
    print(f"📋 נטענו {len(df)} רשומות")
    print(f"📊 עמודות: {', '.join(df.columns)}")
    return df


def analyze_grades(df):
    """מנתחת ציונים ומציגה סטטיסטיקות"""
    print("\n📈 סטטיסטיקות ציונים:")
    print("=" * 40)
    
    grade_cols = ['ציון_מתמטיקה', 'ציון_אנגלית', 'ציון_מדעים']
    
    for col in grade_cols:
        subject = col.replace('ציון_', '')
        avg = df[col].mean()
        best = df[col].max()
        best_student = df.loc[df[col].idxmax(), 'שם']
        print(f"  {subject}: ממוצע={avg:.1f}, הכי גבוה={best} ({best_student})")
    
    # Overall average per student
    df['ממוצע_כללי'] = df[grade_cols].mean(axis=1)
    top = df.nlargest(3, 'ממוצע_כללי')[['שם', 'ממוצע_כללי']]
    print(f"\n🏆 שלושת הראשונים:")
    for _, row in top.iterrows():
        print(f"  ⭐ {row['שם']}: {row['ממוצע_כללי']:.1f}")
    
    return df


def create_chart(df):
    """יוצרת גרף ציונים"""
    grade_cols = ['ציון_מתמטיקה', 'ציון_אנגלית', 'ציון_מדעים']
    
    fig, axes = plt.subplots(1, 2, figsize=(14, 6))
    
    # Bar chart — averages by subject
    avgs = [df[c].mean() for c in grade_cols]
    labels = ['Math', 'English', 'Science']
    colors = ['#FF6B6B', '#4ECDC4', '#45B7D1']
    axes[0].bar(labels, avgs, color=colors, edgecolor='white', linewidth=2)
    axes[0].set_title('Average Grades by Subject', fontsize=14, fontweight='bold')
    axes[0].set_ylim(70, 100)
    axes[0].grid(axis='y', alpha=0.3)
    
    # Scatter — Math vs Science
    axes[1].scatter(df['ציון_מתמטיקה'], df['ציון_מדעים'], 
                    c='#6C5CE7', s=100, edgecolors='white', linewidth=2, alpha=0.8)
    axes[1].set_xlabel('Math Grade', fontsize=12)
    axes[1].set_ylabel('Science Grade', fontsize=12)
    axes[1].set_title('Math vs Science Correlation', fontsize=14, fontweight='bold')
    axes[1].grid(alpha=0.3)
    
    plt.tight_layout()
    chart_path = os.path.join(OUTPUT_DIR, 'grades_analysis.png')
    plt.savefig(chart_path, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"\n📊 גרף נשמר ב: {chart_path}")


def main():
    print("🌟 ניתוח ציונים — פרויקט של שירה")
    print("=" * 45)
    
    df = load_data()
    df = analyze_grades(df)
    
    try:
        create_chart(df)
        print("\n✅ הניתוח הושלם בהצלחה! בדקי את תיקיית output/")
    except ImportError:
        print("\n⚠️ matplotlib לא מותקן — הריצי: pip install matplotlib")
    except Exception as e:
        print(f"\n⚠️ שגיאה ביצירת גרף: {e}")
        print("הניתוח הטקסטואלי הושלם בהצלחה!")


if __name__ == "__main__":
    main()
'@ | Out-File -FilePath "$ProjectDir\notebooks\analysis_starter.py" -Encoding utf8
        Write-Ok "סקריפט ניתוח נתונים נוצר"
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
Write-Host "     1. פתחי את הפרויקט: " -NoNewline -ForegroundColor White
Write-Host "code $ProjectDir" -ForegroundColor Cyan
Write-Host "     2. התקיני ספריות: " -NoNewline -ForegroundColor White
Write-Host "pip install -r requirements.txt" -ForegroundColor Cyan
Write-Host "     3. הריצי את הניתוח: " -NoNewline -ForegroundColor White
Write-Host "python notebooks/analysis_starter.py" -ForegroundColor Cyan
Write-Host "     4. הפעילי מוניטור: " -NoNewline -ForegroundColor White
Write-Host "pwsh ralph-watch.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "  📚 Study-Buddy | 💻 Code-Pro | 🎨 Design-Eye | 📊 Data-Viz" -ForegroundColor Magenta
Write-Host "  הצוות שלך מוכן — בהצלחה שירה! 🌟" -ForegroundColor Magenta
Write-Host ""
