#Requires -Version 5.1
<#
.SYNOPSIS
    Squad setup script for Eyal Dresher — Superhero Builders team.
.DESCRIPTION
    Automated setup of a personalized AI Squad system for Eyal (age 8.5):
    - Prerequisites check and install (VS Code, Git, Node.js, GitHub CLI)
    - GitHub account creation guidance and authentication
    - Project structure with .squad/ directory and Hebrew-named agents
    - VS Code configuration with kid-friendly settings
    - Fun simplified ralph-watch monitor with extra colors and emojis
    - Git init, first commit, and GitHub repo creation
    - Superhero HTML page starter project
.PARAMETER DryRun
    Show what would be done without making changes.
.PARAMETER SkipPrereqs
    Skip prerequisite installation checks.
.EXAMPLE
    .\setup-squad-eyal.ps1
.EXAMPLE
    .\setup-squad-eyal.ps1 -DryRun
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
$KidName        = "אייל"
$KidNameEn      = "Eyal"
$GitHubUser     = "eyal-dresher"
$GitHubEmail    = "eyaldresher@gmail.com"
$ProjectName    = "eyal-superheroes"
$ProjectDir     = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Projects\$ProjectName"
$TeamTheme      = "צוות בוני הגיבורים-על"
$Agents         = @(
    @{ Id = "tzayaron";   Name = "ציירון";    Emoji = "🎨"; Role = "אמן ומעצב";       Desc = "אני מצייר ציורים, בוחר צבעים יפים, ועוזר לעצב דפי אינטרנט. אני אוהב לעשות דברים יפים ושמחים!" }
    @{ Id = "cody";       Name = "קודי";      Emoji = "💻"; Role = "כותב קוד";         Desc = "אני כותב קוד HTML ו-CSS! אני עוזר לבנות דפי אינטרנט מגניבים. אני מסביר הכל בפשטות כדי שיהיה קל ללמוד." }
    @{ Id = "raayonit";   Name = "רעיונית";   Emoji = "💡"; Role = "ממציאה רעיונות";   Desc = "אני חושבת על רעיונות מגניבים לפרויקטים! גיבורי-על חדשים, כוחות מיוחדים, והרפתקאות מרגשות!" }
)

# ── Color Palette (extra fun for Eyal!) ───────────────────────
$C = @{
    Title   = "Yellow"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Cyan"
    Step    = "White"
    Dim     = "DarkGray"
    Fun     = "Magenta"
}

# ── Helper Functions ───────────────────────────────────────────
function Write-Banner {
    Write-Host ""
    Write-Host "  ⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡" -ForegroundColor $C.Fun
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor $C.Title
    Write-Host "  ║                                                  ║" -ForegroundColor $C.Title
    Write-Host "  ║   🦸 אייל — צוות בוני הגיבורים-על!               ║" -ForegroundColor $C.Title
    Write-Host "  ║                                                  ║" -ForegroundColor $C.Title
    Write-Host "  ║   🎨 ציירון — אמן ומעצב                          ║" -ForegroundColor $C.Title
    Write-Host "  ║   💻 קודי — כותב קוד                              ║" -ForegroundColor $C.Title
    Write-Host "  ║   💡 רעיונית — ממציאה רעיונות                     ║" -ForegroundColor $C.Title
    Write-Host "  ║                                                  ║" -ForegroundColor $C.Title
    Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor $C.Title
    Write-Host ""
    Write-Host "  ⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡" -ForegroundColor $C.Fun
    Write-Host ""
    if ($DryRun) {
        Write-Host "  ⚠️  מצב ניסיון (DryRun) — לא קורה שום דבר באמת" -ForegroundColor $C.Warning
        Write-Host ""
    }
}

function Write-Step {
    param([string]$Emoji, [string]$Text)
    Write-Host ""
    Write-Host "  $Emoji $Text" -ForegroundColor $C.Step
    Write-Host "  $('⭐' * 25)" -ForegroundColor $C.Fun
}

function Write-Ok    { param([string]$Text) Write-Host "    ✅ $Text" -ForegroundColor $C.Success }
function Write-Warn  { param([string]$Text) Write-Host "    ⚠️  $Text" -ForegroundColor $C.Warning }
function Write-Err   { param([string]$Text) Write-Host "    ❌ $Text" -ForegroundColor $C.Error }
function Write-Detail{ param([string]$Text) Write-Host "    $Text" -ForegroundColor $C.Info }
function Write-Fun   { param([string]$Text) Write-Host "    🌟 $Text" -ForegroundColor $C.Fun }

function Test-CommandExists { param([string]$Cmd) $null -ne (Get-Command $Cmd -ErrorAction SilentlyContinue) }

function Invoke-SafeCommand {
    param([string]$Description, [scriptblock]$Action)
    if ($DryRun) {
        Write-Detail "ניסיון: $Description"
        return
    }
    try {
        & $Action
    } catch {
        Write-Err "$Description — לא הצליח: $($_.Exception.Message)"
        Write-Warn "זה בסדר! נמשיך הלאה ונתקן אחר כך"
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 1 — Prerequisites
# ══════════════════════════════════════════════════════════════
function Install-Prerequisites {
    Write-Step "🔧" "בודק שהכל מוכן..."

    # Git
    if (Test-CommandExists "git") {
        Write-Ok "Git מותקן — מעולה!"
    } else {
        Write-Warn "Git חסר — בוא נתקין!"
        if (-not $DryRun) {
            Write-Detail "מתקין Git..."
            winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            if (Test-CommandExists "git") { Write-Ok "Git הותקן! 🎉" } else { Write-Err "Git לא הותקן — תבקש מאבא עזרה" }
        }
    }

    # VS Code
    if (Test-CommandExists "code") {
        Write-Ok "VS Code מותקן — מעולה!"
    } else {
        Write-Warn "VS Code חסר — בוא נתקין!"
        if (-not $DryRun) {
            Write-Detail "מתקין VS Code..."
            winget install --id Microsoft.VisualStudioCode -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            if (Test-CommandExists "code") { Write-Ok "VS Code הותקן! 🎉" } else { Write-Err "VS Code לא הותקן — תבקש מאבא עזרה" }
        }
    }

    # Node.js
    if (Test-CommandExists "node") {
        $nodeVer = node --version 2>&1
        Write-Ok "Node.js מותקן — $nodeVer"
    } else {
        Write-Warn "Node.js חסר — בוא נתקין!"
        if (-not $DryRun) {
            Write-Detail "מתקין Node.js..."
            winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            if (Test-CommandExists "node") { Write-Ok "Node.js הותקן! 🎉" } else { Write-Err "Node.js לא הותקן — תבקש מאבא עזרה" }
        }
    }

    # GitHub CLI
    if (Test-CommandExists "gh") {
        Write-Ok "GitHub CLI מותקן — מעולה!"
    } else {
        Write-Warn "GitHub CLI חסר — בוא נתקין!"
        if (-not $DryRun) {
            Write-Detail "מתקין GitHub CLI..."
            winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            if (Test-CommandExists "gh") { Write-Ok "GitHub CLI הותקן! 🎉" } else { Write-Err "GitHub CLI לא הותקן — תבקש מאבא עזרה" }
        }
    }

    Write-Fun "הכל מוכן — יאללה קדימה!"
}

# ══════════════════════════════════════════════════════════════
#  STEP 2 — GitHub Authentication
# ══════════════════════════════════════════════════════════════
function Initialize-GitHub {
    Write-Step "🔑" "התחברות ל-GitHub"

    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "כבר מחובר ל-GitHub! מגניב!"
        return
    }

    Write-Host ""
    Write-Host "    🦸 בוא נתחבר ל-GitHub!" -ForegroundColor $C.Fun
    Write-Host ""
    Write-Detail "אם עדיין אין לך חשבון, אבא יעזור לך ליצור אחד כאן:"
    Write-Host "       https://github.com/signup" -ForegroundColor White
    Write-Host ""
    Write-Detail "שם משתמש מומלץ: $GitHubUser"
    Write-Detail "אימייל: $GitHubEmail"
    Write-Host ""

    if ($DryRun) {
        Write-Detail "ניסיון: הייתה מתבצעת התחברות ל-GitHub"
        return
    }

    $ready = Read-Host "    אבא עזר לך ליצור חשבון? מוכן להתחבר? (כ/ל) [כ]"
    if ($ready -eq "ל") {
        Write-Warn "בסדר! תתחבר מאוחר יותר עם אבא. הפקודה: gh auth login"
        return
    }

    Write-Detail "פותח דפדפן..."
    gh auth login --web --git-protocol https 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "התחברת ל-GitHub! 🦸‍♂️ גיבור-על אמיתי!"
    } else {
        Write-Warn "לא הצליח — תבקש מאבא עזרה!"
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 3 — Project Structure
# ══════════════════════════════════════════════════════════════
function New-ProjectStructure {
    Write-Step "📁" "בונה את בסיס הגיבורים-על!"

    if (Test-Path $ProjectDir) {
        Write-Warn "התיקייה כבר קיימת: $ProjectDir"
        $response = Read-Host "    להמשיך בכל זאת? (כ/ל) [כ]"
        if ($response -eq "ל") {
            Write-Detail "ביטול"
            return
        }
    }

    Invoke-SafeCommand "יצירת תיקיות" {
        New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\.squad\decisions\inbox" -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\.vscode" -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\heroes" -Force | Out-Null
        New-Item -ItemType Directory -Path "$ProjectDir\images" -Force | Out-Null

        foreach ($agent in $Agents) {
            New-Item -ItemType Directory -Path "$ProjectDir\.squad\agents\$($agent.Id)" -Force | Out-Null
        }
        Write-Ok "תיקיות נוצרו!"
        Write-Fun "הבסיס מוכן!"
    }

    # ── team.md ─────────────────────────────────────────────
    Invoke-SafeCommand "יצירת team.md" {
        $teamRows = ($Agents | ForEach-Object { "| $($_.Emoji) $($_.Name) | $($_.Role) | ``.squad/agents/$($_.Id)/charter.md`` | ✅ פעיל |" }) -join "`n"
        @"
# $TeamTheme

> הצוות שלי לבניית דפי אינטרנט של גיבורי-על! 🦸

## חברי הצוות

| שם | תפקיד | תקנון | סטטוס |
|----|--------|-------|-------|
$teamRows
| אייל דרשר | 🦸 בעל הפרויקט | — | 👤 אנושי |

## איך עובדים

1. 💡 חושבים על רעיון לגיבור-על חדש
2. 🎨 מעצבים איך הוא ייראה
3. 💻 כותבים קוד HTML שמראה אותו
4. 🌟 שומרים ומראים לכולם!
"@ | Out-File -FilePath "$ProjectDir\.squad\team.md" -Encoding utf8
    }

    # ── decisions.md ────────────────────────────────────────
    Invoke-SafeCommand "יצירת decisions.md" {
        @"
# החלטות

> כאן נרשמות ההחלטות של הצוות.

---

_עדיין אין החלטות — ההחלטה הראשונה שלך מחכה!_
"@ | Out-File -FilePath "$ProjectDir\.squad\decisions.md" -Encoding utf8
    }

    # ── Agent charters (Hebrew names!) ──────────────────────
    foreach ($agent in $Agents) {
        Invoke-SafeCommand "יצירת charter: $($agent.Name)" {
            @"
# $($agent.Emoji) $($agent.Name) — $($agent.Role)

## מי אני

$($agent.Desc)

## מה אני יודע לעשות

- לעזור לך עם הפרויקט
- להציע רעיונות מגניבים
- לעזור כשמשהו לא עובד
- לעבוד ביחד עם שאר הצוות

## איך מבקשים ממני עזרה

תכתוב ב-GitHub Issue ותוסיף את השם שלי: ``$($agent.Name)``

## הכללים שלי

- אני תמיד מסביר מה אני עושה — בקלות!
- אני שואל אם משהו לא ברור
- אני עושה דברים בצעדים קטנים
"@ | Out-File -FilePath "$ProjectDir\.squad\agents\$($agent.Id)\charter.md" -Encoding utf8

            "# היסטוריה`n`n_עדיין ריק — כאן יירשמו דברים שעשיתי._" |
                Out-File -FilePath "$ProjectDir\.squad\agents\$($agent.Id)\history.md" -Encoding utf8
        }
    }

    # ── README.md ───────────────────────────────────────────
    Invoke-SafeCommand "יצירת README.md" {
        @"
# 🦸 $ProjectName — $TeamTheme

> הפרויקט של אייל דרשר!

## 📖 מה זה?

פרויקט שבו אני בונה דפי אינטרנט של גיבורי-על!
כל גיבור מקבל דף משלו עם צבעים, כוחות מיוחדים, וסיפור.

## 🤖 הצוות שלי

| סוכן | מה הוא עושה |
|-------|-------------|
$(($Agents | ForEach-Object { "| $($_.Emoji) $($_.Name) | $($_.Role) |" }) -join "`n")

## 🚀 איך מתחילים

1. פתח את ``heroes/index.html`` בדפדפן
2. תראה את דף הגיבור-על!
3. שנה את הטקסט ב-VS Code כדי ליצור גיבור משלך!

## 🌟 רעיונות לגיבורים

- [ ] SuperEyal — גיבור-על עם כוח קוד! 💻
- [ ] FlameGirl — גיבורת אש! 🔥
- [ ] IceKing — מלך הקרח! ❄️
- [ ] ThunderBoy — ילד הרעם! ⚡

## 📝 של אייל דרשר — $([datetime]::Now.Year)
"@ | Out-File -FilePath "$ProjectDir\README.md" -Encoding utf8
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 4 — VS Code Setup
# ══════════════════════════════════════════════════════════════
function Set-VSCodeConfig {
    Write-Step "💻" "מכין את VS Code בשבילך"

    Invoke-SafeCommand "יצירת settings.json" {
        @"
{
    "editor.fontFamily": "'Cascadia Code', 'Comic Sans MS', Consolas, monospace",
    "editor.fontSize": 18,
    "editor.tabSize": 2,
    "editor.wordWrap": "on",
    "editor.formatOnSave": true,
    "editor.minimap.enabled": false,
    "editor.cursorBlinking": "expand",
    "editor.cursorStyle": "block",
    "editor.unicodeHighlight.ambiguousCharacters": false,
    "files.encoding": "utf8",
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "terminal.integrated.defaultProfile.windows": "PowerShell",
    "liveServer.settings.doNotShowInfoMsg": true,
    "workbench.colorTheme": "One Dark Pro",
    "workbench.startupEditor": "readme",
    "workbench.iconTheme": "material-icon-theme",
    "breadcrumbs.enabled": true,
    "editor.bracketPairColorization.enabled": true
}
"@ | Out-File -FilePath "$ProjectDir\.vscode\settings.json" -Encoding utf8
    }

    Invoke-SafeCommand "יצירת extensions.json" {
        @"
{
    "recommendations": [
        "ritwickdey.liveserver",
        "zhuangtongfa.material-theme",
        "pkief.material-icon-theme",
        "github.copilot",
        "github.copilot-chat",
        "formulahendry.code-runner",
        "eamodio.gitlens",
        "vincaslt.highlight-matching-tag"
    ]
}
"@ | Out-File -FilePath "$ProjectDir\.vscode\extensions.json" -Encoding utf8
    }

    if ((Test-CommandExists "code") -and (-not $DryRun)) {
        Write-Detail "מתקין הרחבות..."
        $extensions = @("ritwickdey.liveserver", "github.copilot", "github.copilot-chat", "pkief.material-icon-theme")
        foreach ($ext in $extensions) {
            code --install-extension $ext --force 2>&1 | Out-Null
        }
        Write-Ok "הרחבות הותקנו!"
        Write-Fun "VS Code מוכן!"
    } else {
        Write-Detail "הרחבות יותקנו כשתפתח את VS Code"
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 5 — Ralph Watch (Extra Fun for Eyal!)
# ══════════════════════════════════════════════════════════════
function New-RalphWatch {
    Write-Step "🔄" "יצירת מוניטור הגיבורים-על!"

    Invoke-SafeCommand "יצירת ralph-watch.ps1" {
        @'
# 🦸 מוניטור הגיבורים-על של אייל!
# בודק את הפרויקט כל 30 דקות
# להפעלה: pwsh ralph-watch.ps1
# לעצירה: Ctrl+C

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$intervalMinutes = 30
$round = 0

# Random hero facts for fun!
$heroFacts = @(
    "🦸 ספיידרמן הומצא ב-1962 — הוא כבר בן 60+!",
    "⚡ הפלאש יכול לרוץ מהר יותר מאור!",
    "🦇 לבאטמן אין כוחות-על — רק אימון ומוח!",
    "🕷️ ספיידרמן יכול להרים 10 טון!",
    "🛡️ המגן של קפטן אמריקה עשוי מוויברניום!",
    "💚 האלק הופך יותר חזק ככל שהוא יותר כועס!",
    "🔨 רק מי שראוי יכול להרים את הפטיש של תור!",
    "🐙 דוקטור אוקטופוס הוא מדען שהפך לנבל!",
    "🦅 וונדר וומן היא אמזונית מאי פרדייז!",
    "🕸️ קורי העכביש של ספיידרמן חזקים יותר מפלדה!"
)

function Show-Dashboard {
    param([int]$Round, [array]$Issues, [string]$Status)
    
    Clear-Host
    
    # Fun animated-looking header
    $colors = @("Red", "Yellow", "Green", "Cyan", "Magenta")
    $headerColor = $colors[$Round % $colors.Count]
    
    Write-Host ""
    Write-Host "  ⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡" -ForegroundColor $headerColor
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "  ║   🦸 מוניטור הגיבורים-על של אייל!         ║" -ForegroundColor Yellow
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡" -ForegroundColor $headerColor
    Write-Host ""
    Write-Host "  🕐 עדכון אחרון: $(Get-Date -Format 'HH:mm')" -ForegroundColor Cyan
    Write-Host "  🔄 סבב מספר: $Round" -ForegroundColor Cyan
    Write-Host "  📡 מצב: $Status" -ForegroundColor Green
    Write-Host ""
    
    # Hero count
    $heroCount = (Get-ChildItem -Path "heroes" -Filter "*.html" -ErrorAction SilentlyContinue).Count
    if ($heroCount -gt 0) {
        Write-Host "  🦸 גיבורים שבנית: $heroCount" -ForegroundColor Yellow
        Write-Host "     " -NoNewline
        for ($i = 0; $i -lt $heroCount; $i++) { Write-Host "⭐" -NoNewline -ForegroundColor Yellow }
        Write-Host ""
    } else {
        Write-Host "  🦸 בוא נבנה את הגיבור הראשון!" -ForegroundColor Magenta
    }
    Write-Host ""
    
    if ($Issues -and $Issues.Count -gt 0) {
        Write-Host "  📋 משימות ($($Issues.Count)):" -ForegroundColor Yellow
        Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray
        foreach ($issue in $Issues) {
            $icon = switch -Wildcard ($issue.title) {
                "*hero*"    { "🦸" }
                "*color*"   { "🎨" }
                "*bug*"     { "🐛" }
                "*idea*"    { "💡" }
                default     { "⭐" }
            }
            Write-Host "    $icon $($issue.title)" -ForegroundColor White
        }
    } else {
        Write-Host "  🎉 אין משימות — הכל מעולה!" -ForegroundColor Green
    }
    
    # Random fun fact!
    Write-Host ""
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray
    $fact = $heroFacts[(Get-Random -Maximum $heroFacts.Count)]
    Write-Host "  💬 עובדה מגניבה:" -ForegroundColor Magenta
    Write-Host "     $fact" -ForegroundColor White
    Write-Host ""
    Write-Host "  ⏱️  בדיקה הבאה בעוד $intervalMinutes דקות..." -ForegroundColor DarkGray
    Write-Host "  ⛔ Ctrl+C לעצירה" -ForegroundColor DarkGray
    Write-Host ""
}

# Main loop
while ($true) {
    $round++
    try {
        $issues = gh issue list --json number,title,labels --limit 10 2>$null | ConvertFrom-Json
        Show-Dashboard -Round $round -Issues $issues -Status "✅ הכל עובד!"
    } catch {
        Show-Dashboard -Round $round -Issues @() -Status "⚠️ אין חיבור — בסדר!"
    }
    
    Start-Sleep -Seconds ($intervalMinutes * 60)
}
'@ | Out-File -FilePath "$ProjectDir\ralph-watch.ps1" -Encoding utf8
        Write-Ok "ralph-watch.ps1 נוצר!"
        Write-Fun "המוניטור שלך מוכן — הוא ממש מגניב!"
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 6 — Git & GitHub
# ══════════════════════════════════════════════════════════════
function Initialize-GitRepo {
    Write-Step "🌿" "שומר הכל ב-GitHub"

    Invoke-SafeCommand "יצירת .gitignore" {
        @"
# IDE
.vscode/.history/
*.swp

# OS
.DS_Store
Thumbs.db
desktop.ini

# Squad internals
.ralph-watch.lock
"@ | Out-File -FilePath "$ProjectDir\.gitignore" -Encoding utf8
    }

    if ($DryRun) {
        Write-Detail "ניסיון: שמירה ב-Git ויצירת repo ב-GitHub"
        return
    }

    Push-Location $ProjectDir
    try {
        if (-not (Test-Path "$ProjectDir\.git")) {
            git init 2>&1 | Out-Null
            Write-Ok "Git מוכן!"
        }
        git config user.name "$KidNameEn Dresher" 2>&1 | Out-Null
        git config user.email $GitHubEmail 2>&1 | Out-Null

        git add -A 2>&1 | Out-Null
        git commit -m "🦸 התחלה: $TeamTheme" 2>&1 | Out-Null
        Write-Ok "נשמר! commit ראשון!"
        Write-Fun "הקוד שלך שמור בבטחה!"

        $repoExists = gh repo view "$GitHubUser/$ProjectName" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Detail "יוצר מקום ב-GitHub..."
            gh repo create $ProjectName --private --source . --remote origin --push 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "הפרויקט באינטרנט! 🌐"
            } else {
                Write-Warn "לא הצליח — תבקש מאבא עזרה"
            }
        } else {
            Write-Ok "הפרויקט כבר ב-GitHub!"
            git remote add origin "https://github.com/$GitHubUser/$ProjectName.git" 2>$null
            git push -u origin main 2>&1 | Out-Null
        }
    } finally {
        Pop-Location
    }
}

# ══════════════════════════════════════════════════════════════
#  STEP 7 — Starter Project (Superhero Page!)
# ══════════════════════════════════════════════════════════════
function New-StarterProject {
    Write-Step "🦸" "בונה דף גיבור-על מגניב!"

    Invoke-SafeCommand "יצירת דף הגיבור" {
        @"
<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🦸 הגיבורים-על של אייל!</title>
    <style>
        /* ── צבעים וגופנים ── */
        @import url('https://fonts.googleapis.com/css2?family=Rubik:wght@400;700;900&display=swap');
        
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Rubik', 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #0c0c3a 0%, #1a1a4e 50%, #2d1b69 100%);
            min-height: 100vh;
            color: white;
            overflow-x: hidden;
        }

        /* ── כוכבים ברקע ── */
        body::before {
            content: '';
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background-image: 
                radial-gradient(2px 2px at 20px 30px, #eee, transparent),
                radial-gradient(2px 2px at 40px 70px, #fff, transparent),
                radial-gradient(1px 1px at 90px 40px, #ddd, transparent),
                radial-gradient(2px 2px at 160px 120px, #fff, transparent),
                radial-gradient(1px 1px at 200px 60px, #eee, transparent),
                radial-gradient(2px 2px at 300px 150px, #fff, transparent),
                radial-gradient(1px 1px at 400px 80px, #ddd, transparent),
                radial-gradient(2px 2px at 500px 200px, #fff, transparent);
            background-size: 550px 250px;
            animation: twinkle 5s ease-in-out infinite alternate;
            z-index: 0;
        }
        @keyframes twinkle { from { opacity: 0.5; } to { opacity: 1; } }

        /* ── כותרת ── */
        header {
            position: relative;
            z-index: 1;
            text-align: center;
            padding: 40px 20px;
        }
        h1 {
            font-size: 3em;
            font-weight: 900;
            background: linear-gradient(90deg, #ff6b6b, #feca57, #48dbfb, #ff9ff3);
            background-size: 300% 300%;
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            animation: rainbow 3s ease infinite;
            text-shadow: 0 0 30px rgba(255, 255, 255, 0.1);
        }
        @keyframes rainbow {
            0% { background-position: 0% 50%; }
            50% { background-position: 100% 50%; }
            100% { background-position: 0% 50%; }
        }
        .subtitle {
            font-size: 1.3em;
            color: #b8b8ff;
            margin-top: 10px;
        }

        /* ── כרטיס גיבור ── */
        .heroes-grid {
            position: relative;
            z-index: 1;
            display: flex;
            flex-wrap: wrap;
            justify-content: center;
            gap: 30px;
            padding: 20px 40px 60px;
        }
        .hero-card {
            background: rgba(255, 255, 255, 0.08);
            backdrop-filter: blur(10px);
            border: 2px solid rgba(255, 255, 255, 0.15);
            border-radius: 20px;
            padding: 30px;
            width: 280px;
            text-align: center;
            transition: all 0.3s ease;
            cursor: pointer;
        }
        .hero-card:hover {
            transform: translateY(-10px) scale(1.03);
            border-color: #feca57;
            box-shadow: 0 20px 40px rgba(254, 202, 87, 0.2);
        }
        .hero-emoji {
            font-size: 5em;
            margin-bottom: 10px;
            display: block;
            animation: float 3s ease-in-out infinite;
        }
        @keyframes float {
            0%, 100% { transform: translateY(0px); }
            50% { transform: translateY(-10px); }
        }
        .hero-card:nth-child(2) .hero-emoji { animation-delay: 0.5s; }
        .hero-card:nth-child(3) .hero-emoji { animation-delay: 1s; }
        
        .hero-name {
            font-size: 1.8em;
            font-weight: 900;
            margin-bottom: 8px;
        }
        .hero-power {
            font-size: 1em;
            color: #b8b8ff;
            margin-bottom: 15px;
        }
        .power-bar {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            height: 12px;
            overflow: hidden;
            margin: 5px 0;
        }
        .power-fill {
            height: 100%;
            border-radius: 10px;
            transition: width 1s ease;
        }
        .power-label {
            display: flex;
            justify-content: space-between;
            font-size: 0.85em;
            color: #aaa;
        }

        /* ── צבעי גיבורים ── */
        .hero-card.fire { --hero-color: #ff6b6b; }
        .hero-card.ice { --hero-color: #48dbfb; }
        .hero-card.thunder { --hero-color: #feca57; }
        .hero-card .hero-name { color: var(--hero-color); }
        .hero-card .power-fill { background: linear-gradient(90deg, var(--hero-color), white); }

        /* ── כפתור ── */
        .add-hero {
            position: relative;
            z-index: 1;
            display: block;
            margin: 0 auto 60px;
            padding: 15px 40px;
            font-size: 1.3em;
            font-family: 'Rubik', sans-serif;
            font-weight: 700;
            background: linear-gradient(135deg, #7b2ff7, #ff6b6b);
            color: white;
            border: none;
            border-radius: 50px;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        .add-hero:hover {
            transform: scale(1.1);
            box-shadow: 0 10px 30px rgba(123, 47, 247, 0.4);
        }

        footer {
            position: relative;
            z-index: 1;
            text-align: center;
            padding: 20px;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <header>
        <h1>🦸 הגיבורים-על של אייל!</h1>
        <p class="subtitle">כל גיבור-על יוצר את הכוח שלו</p>
    </header>

    <div class="heroes-grid">
        <!-- 🔥 גיבור 1: SuperEyal -->
        <div class="hero-card fire">
            <span class="hero-emoji">🦸‍♂️</span>
            <h2 class="hero-name">SuperEyal</h2>
            <p class="hero-power">⚡ כוח הקוד — בונה דברים מדהימים!</p>
            <div class="power-label"><span>כוח</span><span>95%</span></div>
            <div class="power-bar"><div class="power-fill" style="width: 95%"></div></div>
            <div class="power-label"><span>מהירות</span><span>88%</span></div>
            <div class="power-bar"><div class="power-fill" style="width: 88%"></div></div>
            <div class="power-label"><span>חוכמה</span><span>99%</span></div>
            <div class="power-bar"><div class="power-fill" style="width: 99%"></div></div>
        </div>

        <!-- ❄️ גיבור 2: IcePrincess -->
        <div class="hero-card ice">
            <span class="hero-emoji">❄️</span>
            <h2 class="hero-name">IcePrincess</h2>
            <p class="hero-power">🌨️ כוח הקרח — מקפיאה נבלים!</p>
            <div class="power-label"><span>כוח</span><span>80%</span></div>
            <div class="power-bar"><div class="power-fill" style="width: 80%"></div></div>
            <div class="power-label"><span>מהירות</span><span>92%</span></div>
            <div class="power-bar"><div class="power-fill" style="width: 92%"></div></div>
            <div class="power-label"><span>חוכמה</span><span>85%</span></div>
            <div class="power-bar"><div class="power-fill" style="width: 85%"></div></div>
        </div>

        <!-- ⚡ גיבור 3: ThunderBoy -->
        <div class="hero-card thunder">
            <span class="hero-emoji">⚡</span>
            <h2 class="hero-name">ThunderBoy</h2>
            <p class="hero-power">🌩️ כוח הרעם — מהיר כמו ברק!</p>
            <div class="power-label"><span>כוח</span><span>90%</span></div>
            <div class="power-bar"><div class="power-fill" style="width: 90%"></div></div>
            <div class="power-label"><span>מהירות</span><span>99%</span></div>
            <div class="power-bar"><div class="power-fill" style="width: 99%"></div></div>
            <div class="power-label"><span>חוכמה</span><span>75%</span></div>
            <div class="power-bar"><div class="power-fill" style="width: 75%"></div></div>
        </div>
    </div>

    <button class="add-hero" onclick="alert('🦸 בקרוב תוכל להוסיף גיבורים חדשים!')">
        ✨ הוסף גיבור חדש!
    </button>

    <footer>
        <p>🦸 נבנה על ידי אייל דרשר — $([datetime]::Now.Year) 🦸</p>
    </footer>

    <script>
        // 🎉 Make hero cards bounce when clicked!
        document.querySelectorAll('.hero-card').forEach(card => {
            card.addEventListener('click', () => {
                card.style.animation = 'none';
                card.offsetHeight; // trigger reflow
                card.style.animation = 'bounce 0.5s ease';
            });
        });

        // Add bounce animation
        const style = document.createElement('style');
        style.textContent = '@keyframes bounce { 0%,100% { transform: scale(1); } 50% { transform: scale(1.1) rotate(2deg); } }';
        document.head.appendChild(style);

        // Console message for Eyal!
        console.log('🦸 ברוך הבא, אייל! אתה גיבור-על של קוד!');
        console.log('💡 טיפ: תנסה לשנות את הטקסטים ב-HTML כדי ליצור גיבורים חדשים!');
    </script>
</body>
</html>
"@ | Out-File -FilePath "$ProjectDir\heroes\index.html" -Encoding utf8
        Write-Ok "דף הגיבורים-על נוצר! 🦸"
        Write-Fun "פתח אותו בדפדפן ותראה משהו מגניב!"
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
Write-Host "  ⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡" -ForegroundColor Magenta
Write-Host ""
Write-Host "  ╔════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║  🎉 הכל מוכן!!! 🦸                              ║" -ForegroundColor Green
Write-Host "  ╚════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  ⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡" -ForegroundColor Magenta
Write-Host ""
Write-Host "  📂 הפרויקט שלך נמצא כאן:" -ForegroundColor Cyan
Write-Host "     $ProjectDir" -ForegroundColor White
Write-Host ""
Write-Host "  🚀 מה עכשיו?" -ForegroundColor Yellow
Write-Host ""
Write-Host "     1. 💻 פתח את הפרויקט: " -NoNewline -ForegroundColor White
Write-Host "code $ProjectDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "     2. 🦸 תראה את הגיבורים: " -NoNewline -ForegroundColor White
Write-Host "פתח heroes\index.html בדפדפן" -ForegroundColor Cyan
Write-Host ""
Write-Host "     3. ✏️  שנה את הגיבורים: " -NoNewline -ForegroundColor White
Write-Host "ערוך את index.html ב-VS Code" -ForegroundColor Cyan
Write-Host ""
Write-Host "     4. 🔄 הפעל מוניטור: " -NoNewline -ForegroundColor White
Write-Host "pwsh ralph-watch.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "  🎨 ציירון | 💻 קודי | 💡 רעיונית" -ForegroundColor Yellow
Write-Host "  הצוות שלך מוכן — אתה גיבור-על, אייל! 🦸⚡" -ForegroundColor Yellow
Write-Host ""
