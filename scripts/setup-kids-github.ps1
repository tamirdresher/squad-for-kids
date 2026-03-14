<#
.SYNOPSIS
    סקריפט התקנת סביבת פיתוח ו-GitHub לילדים של תמיר דרשר
    Setup script for Tamir Dresher's kids — GitHub + coding environment

.DESCRIPTION
    סקריפט אינטראקטיבי בעברית שמתקין ומגדיר:
    - Git, VS Code, GitHub CLI, Node.js, Python
    - חשבון GitHub והגדרות Git
    - פרויקט התחלתי מותאם גיל
    - הרחבות VS Code מומלצות

.PARAMETER DryRun
    הרצה יבשה — מראה מה היה קורה בלי לבצע שינויים

.PARAMETER Help
    מציג הסבר מפורט על הסקריפט בעברית

.PARAMETER SkipPrereqs
    מדלג על בדיקת והתקנת תוכנות (שימושי להרצה חוזרת)

.EXAMPLE
    .\setup-kids-github.ps1
    .\setup-kids-github.ps1 -DryRun
    .\setup-kids-github.ps1 -Help
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Help,
    [switch]$SkipPrereqs
)

# ============================================================
# Encoding & Console Setup
# ============================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# Kid Profiles
# ============================================================
$KidProfiles = @{
    '1' = @{
        NameHe      = 'שירה דרשר'
        NameEn      = 'Shira Dresher'
        Email       = 'shira.dresher@live.biu.ac.il'
        GmailEmail  = 'dreshershira@gmail.com'
        Age         = 15
        GitHubUser  = 'shira-dresher'  # already registered
        Emoji       = '🌟'
        Languages   = @('Python', 'HTML', 'CSS', 'JavaScript')
        Extensions  = @(
            'ms-python.python',
            'ms-python.vscode-pylance',
            'ms-toolsai.jupyter',
            'esbenp.prettier-vscode',
            'formulahendry.auto-rename-tag',
            'MS-CEINTL.vscode-language-pack-he'
        )
        ProjectType = 'python'
    }
    '2' = @{
        NameHe      = 'יונתן דרשר'
        NameEn      = 'Yonatan Dresher'
        Email       = 'yonatandresher@gmail.com'
        Age         = 13
        GitHubUser  = ''
        Emoji       = '🎮'
        Languages   = @('JavaScript', 'HTML', 'CSS')
        Extensions  = @(
            'dbaeumer.vscode-eslint',
            'esbenp.prettier-vscode',
            'formulahendry.auto-rename-tag',
            'ritwickdey.LiveServer',
            'MS-CEINTL.vscode-language-pack-he'
        )
        ProjectType = 'javascript'
    }
    '3' = @{
        NameHe      = 'אייל דרשר'
        NameEn      = 'Eyal Dresher'
        Email       = 'eyaldresher@gmail.com'
        Age         = 8
        GitHubUser  = ''
        Emoji       = '🦸'
        Languages   = @('HTML', 'CSS')
        Extensions  = @(
            'formulahendry.auto-rename-tag',
            'ritwickdey.LiveServer',
            'MS-CEINTL.vscode-language-pack-he'
        )
        ProjectType = 'html'
    }
}

# ============================================================
# Helper Functions
# ============================================================

function Write-Banner {
    param([string]$Text, [string]$Color = 'Cyan')
    $line = '=' * 60
    Write-Host ""
    Write-Host $line -ForegroundColor $Color
    Write-Host "  $Text" -ForegroundColor $Color
    Write-Host $line -ForegroundColor $Color
    Write-Host ""
}

function Write-Step {
    param([int]$Number, [string]$Text)
    Write-Host ""
    Write-Host "  [$Number/8] $Text" -ForegroundColor Cyan
    Write-Host "  $('-' * 50)" -ForegroundColor DarkGray
}

function Write-Ok {
    param([string]$Text)
    Write-Host "  ✅ $Text" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host "  ⚠️  $Text" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Text)
    Write-Host "  ❌ $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "  ℹ️  $Text" -ForegroundColor Cyan
}

function Write-Doing {
    param([string]$Text)
    Write-Host "  🔄 $Text" -ForegroundColor White
}

function Ask-YesNo {
    param([string]$Question)
    while ($true) {
        Write-Host ""
        Write-Host "  $Question (כ/ל  |  y/n)" -ForegroundColor Yellow -NoNewline
        Write-Host " > " -NoNewline
        $answer = Read-Host
        switch ($answer.Trim().ToLower()) {
            { $_ -in 'כ', 'y', 'yes', 'כן' } { return $true  }
            { $_ -in 'ל', 'n', 'no', 'לא'  } { return $false }
            default { Write-Host "  הקלד/י כ (כן) או ל (לא)" -ForegroundColor DarkYellow }
        }
    }
}

function Invoke-SafeCommand {
    param(
        [string]$Description,
        [scriptblock]$Command
    )
    if ($DryRun) {
        Write-Host "  🏜️  [DRY RUN] היה מבצע: $Description" -ForegroundColor DarkYellow
        return $true
    }
    try {
        & $Command
        return $true
    } catch {
        Write-Err "שגיאה ב: $Description"
        Write-Err $_.Exception.Message
        return $false
    }
}

function Test-Command {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-IfMissing {
    param(
        [string]$CommandName,
        [string]$DisplayNameHe,
        [string]$WingetId,
        [bool]$Required = $true
    )

    if (Test-Command $CommandName) {
        Write-Ok "$DisplayNameHe כבר מותקן"
        return $true
    }

    Write-Warn "$DisplayNameHe לא נמצא במחשב"

    if (-not (Test-Command 'winget')) {
        Write-Err "winget לא מותקן — צריך להתקין את $DisplayNameHe ידנית"
        if ($Required) {
            Write-Info "אפשר להוריד מהאתר הרשמי ולהריץ את הסקריפט שוב"
        }
        return (-not $Required)
    }

    if (Ask-YesNo "רוצה שאתקין $DisplayNameHe אוטומטית?") {
        Write-Doing "מתקין $DisplayNameHe..."
        $success = Invoke-SafeCommand "התקנת $DisplayNameHe" {
            winget install --id $WingetId --accept-package-agreements --accept-source-agreements -e 2>&1 | Out-Null
        }
        if ($success) {
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            if (Test-Command $CommandName) {
                Write-Ok "$DisplayNameHe הותקן בהצלחה! 🎉"
                return $true
            } else {
                Write-Warn "$DisplayNameHe הותקן — ייתכן שצריך לסגור ולפתוח את הטרמינל"
                return $true
            }
        } else {
            Write-Err "ההתקנה נכשלה — נסה/י להתקין ידנית"
            return (-not $Required)
        }
    } else {
        if ($Required) {
            Write-Err "$DisplayNameHe נדרש כדי להמשיך"
            return $false
        }
        return $true
    }
}

# ============================================================
# -Help
# ============================================================
if ($Help) {
    Write-Banner "📖 עזרה — סקריפט הגדרת סביבת פיתוח"

    Write-Host @"
  מה הסקריפט הזה עושה?
  ========================
  הסקריפט הזה מכין את המחשב שלך לתכנות!

  🔧 שלב 1: בודק שכל התוכנות הנדרשות מותקנות
     (Git, VS Code, GitHub CLI, ועוד)

  ⚙️  שלב 2: מגדיר את Git עם השם והמייל שלך

  🔑 שלב 3: מתחבר לחשבון GitHub שלך

  📁 שלב 4: יוצר פרויקט ראשון מותאם אישית

  🚀 שלב 5: מעלה את הפרויקט ל-GitHub

  💻 שלב 6: מתקין הרחבות שימושיות ב-VS Code

  איך מריצים?
  ============
  הרצה רגילה:     .\setup-kids-github.ps1
  הרצה יבשה:      .\setup-kids-github.ps1 -DryRun
  דילוג על תוכנות: .\setup-kids-github.ps1 -SkipPrereqs
  עזרה:           .\setup-kids-github.ps1 -Help

  בטוח להריץ כמה פעמים — הסקריפט לא ישבור דברים! ✅
"@ -ForegroundColor White

    return
}

# ============================================================
# STEP 1 — Welcome & Kid Selection
# ============================================================
Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║                                                        ║" -ForegroundColor Magenta
Write-Host "  ║    🚀  !ברוכים הבאים לעולם התכנות                      ║" -ForegroundColor Magenta
Write-Host "  ║                                                        ║" -ForegroundColor Magenta
Write-Host "  ║    הסקריפט הזה יכין לך סביבת פיתוח מושלמת            ║" -ForegroundColor Magenta
Write-Host "  ║    עם GitHub, VS Code, וכל מה שצריך! 💻               ║" -ForegroundColor Magenta
Write-Host "  ║                                                        ║" -ForegroundColor Magenta
Write-Host "  ║                         🤖 — Data ,מאת אבא ו          ║" -ForegroundColor Magenta
Write-Host "  ║                                                        ║" -ForegroundColor Magenta
Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

if ($DryRun) {
    Write-Host "  🏜️  מצב הרצה יבשה — לא יבוצעו שינויים אמיתיים" -ForegroundColor DarkYellow
    Write-Host ""
}

Write-Host "  מי את/ה? בחר/י מספר:" -ForegroundColor Yellow
Write-Host ""
Write-Host "    [1] 🌟 שירה  (15)  — Python, אתרים, מדע נתונים" -ForegroundColor White
Write-Host "    [2] 🎮 יונתן (13)  — JavaScript, משחקים, אתרים" -ForegroundColor White
Write-Host "    [3] 🦸 אייל  (8.5) — HTML, דפי אינטרנט צבעוניים" -ForegroundColor White
Write-Host ""

$selectedKid = $null
while (-not $selectedKid) {
    Write-Host "  הקלד/י 1, 2, או 3 > " -ForegroundColor Yellow -NoNewline
    $choice = Read-Host
    if ($KidProfiles.ContainsKey($choice.Trim())) {
        $selectedKid = $KidProfiles[$choice.Trim()]
    } else {
        Write-Host "  אופס! הקלד/י רק 1, 2, או 3 😊" -ForegroundColor Red
    }
}

$kidName   = $selectedKid.NameHe
$kidNameEn = $selectedKid.NameEn
$kidEmail  = $selectedKid.Email
$kidAge    = $selectedKid.Age
$kidEmoji  = $selectedKid.Emoji

Write-Host ""
Write-Host "  $kidEmoji שלום $kidName! בואי/בוא נתחיל! $kidEmoji" -ForegroundColor Green
Write-Host ""

# Workspace folder
$wsRoot = "$env:USERPROFILE\Documents\GitHub"
$projectName = "my-first-project"
$projectPath = Join-Path $wsRoot $projectName

# ============================================================
# STEP 2 — Prerequisites
# ============================================================
Write-Step 1 "🔧 בדיקת תוכנות נדרשות"

if (-not $SkipPrereqs) {

    $allGood = $true

    # Git
    if (-not (Install-IfMissing 'git' 'Git (ניהול גרסאות)' 'Git.Git' $true)) {
        $allGood = $false
    }

    # VS Code
    if (-not (Install-IfMissing 'code' 'VS Code (עורך קוד)' 'Microsoft.VisualStudioCode' $true)) {
        $allGood = $false
    }

    # GitHub CLI
    if (-not (Install-IfMissing 'gh' 'GitHub CLI (כלי GitHub)' 'GitHub.cli' $true)) {
        $allGood = $false
    }

    # Node.js — for Yonatan and Shira
    if ($kidAge -ge 13) {
        if (-not (Install-IfMissing 'node' 'Node.js (הרצת JavaScript)' 'OpenJS.NodeJS.LTS' $false)) {
            Write-Warn "Node.js לא הותקן — חלק מהדוגמאות עלולות לא לעבוד"
        }
    }

    # Python — for Shira
    if ($kidAge -ge 15) {
        if (-not (Install-IfMissing 'python' 'Python (שפת תכנות)' 'Python.Python.3.12' $false)) {
            # Try python3 alias
            if (Test-Command 'python3') {
                Write-Ok "Python 3 נמצא (כ-python3)"
            } else {
                Write-Warn "Python לא הותקן — חלק מהדוגמאות עלולות לא לעבוד"
            }
        }
    }

    if (-not $allGood) {
        Write-Err "חלק מהתוכנות הנדרשות חסרות. נסה/י להתקין אותן ולהריץ שוב."
        Write-Host ""
        if (-not (Ask-YesNo "רוצה להמשיך בכל זאת?")) {
            Write-Host "  👋 להתראות! תתקין/י את מה שחסר ותריץ/י שוב" -ForegroundColor Cyan
            return
        }
    }

    Write-Ok "בדיקת תוכנות הושלמה!"
} else {
    Write-Info "דילוג על בדיקת תוכנות (SkipPrereqs-)"
}

# ============================================================
# STEP 3 — Git Configuration
# ============================================================
Write-Step 2 "⚙️ הגדרת Git"

$currentName  = git config --global user.name 2>$null
$currentEmail = git config --global user.email 2>$null

if ($currentName -eq $kidNameEn -and $currentEmail -eq $kidEmail) {
    Write-Ok "Git כבר מוגדר עם השם והמייל שלך!"
} else {
    if ($currentName -and $currentName -ne $kidNameEn) {
        Write-Warn "Git מוגדר כרגע עם השם: $currentName"
        if (-not (Ask-YesNo "לשנות ל-$($kidNameEn)?")) {
            Write-Info "משאיר את ההגדרה הקיימת"
        } else {
            Invoke-SafeCommand "הגדרת שם ב-Git" { git config --global user.name $kidNameEn }
            Write-Ok "השם עודכן ל-$kidNameEn"
        }
    } else {
        Invoke-SafeCommand "הגדרת שם ב-Git" { git config --global user.name $kidNameEn }
        Write-Ok "השם הוגדר: $kidNameEn"
    }

    if ($currentEmail -ne $kidEmail) {
        Invoke-SafeCommand "הגדרת מייל ב-Git" { git config --global user.email $kidEmail }
        Write-Ok "המייל הוגדר: $kidEmail"
    }
}

# Set good defaults
Invoke-SafeCommand "הגדרת ברירות מחדל" {
    git config --global init.defaultBranch main
    git config --global credential.helper manager
    git config --global core.autocrlf true
    git config --global core.editor "code --wait"
}
Write-Ok "ברירות מחדל של Git הוגדרו (ענף ראשי: main)"

# ============================================================
# STEP 4 — GitHub Authentication
# ============================================================
Write-Step 3 "🔑 התחברות ל-GitHub"

$ghAuthed = $false
if (Test-Command 'gh') {
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "כבר מחובר/ת ל-GitHub! 🎉"
        $ghAuthed = $true
    } else {
        Write-Info "צריך להתחבר ל-GitHub"
        Write-Host ""
        Write-Host "  📋 הוראות:" -ForegroundColor Yellow
        Write-Host "  1. אם אין לך חשבון GitHub — היכנס/י ל https://github.com/signup" -ForegroundColor White
        Write-Host "     והירשם/י עם המייל: $kidEmail" -ForegroundColor White
        Write-Host "  2. אחרי שיש חשבון, נתחבר דרך הטרמינל" -ForegroundColor White
        Write-Host ""

        if (Ask-YesNo "יש לך כבר חשבון GitHub?") {
            Write-Host ""
            Write-Host "  מעולה! עכשיו נתחבר. עקוב/עקבי אחרי ההוראות:" -ForegroundColor Cyan
            Write-Host "  👉 בחר/י: GitHub.com" -ForegroundColor White
            Write-Host "  👉 בחר/י: HTTPS" -ForegroundColor White
            Write-Host "  👉 בחר/י: Login with a web browser" -ForegroundColor White
            Write-Host "  👉 הדפדפן ייפתח — היכנס/י לחשבון GitHub שלך" -ForegroundColor White
            Write-Host ""

            if (-not $DryRun) {
                Write-Host "  לוחץ/ת Enter כשמוכן/ה..." -ForegroundColor Yellow -NoNewline
                Read-Host

                gh auth login --hostname github.com --git-protocol https --web 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "התחברת ל-GitHub בהצלחה! 🎉"
                    $ghAuthed = $true
                } else {
                    Write-Warn "ההתחברות לא הצליחה — אפשר לנסות שוב אחר כך עם: gh auth login"
                }
            } else {
                Write-Host "  🏜️  [DRY RUN] היה מריץ: gh auth login" -ForegroundColor DarkYellow
            }
        } else {
            Write-Host ""
            Write-Host "  🌐 פותח את דף ההרשמה של GitHub..." -ForegroundColor Cyan
            if (-not $DryRun) {
                Start-Process "https://github.com/signup"
            }
            Write-Host ""
            Write-Host "  אחרי שנרשמת, הריצ/י את הסקריפט שוב כדי להתחבר 😊" -ForegroundColor Yellow
            Write-Host "  👋 להתראות!" -ForegroundColor Cyan
            return
        }
    }
} else {
    Write-Warn "GitHub CLI לא מותקן — דילוג על התחברות"
    Write-Info "אחרי שתתקין gh, הריצ/י את הסקריפט שוב"
}

# ============================================================
# STEP 5 — Create Starter Project
# ============================================================
Write-Step 4 "📁 יצירת פרויקט ראשון"

# Create workspace directory
if (-not (Test-Path $wsRoot)) {
    Invoke-SafeCommand "יצירת תיקיית GitHub" {
        New-Item -Path $wsRoot -ItemType Directory -Force | Out-Null
    }
    Write-Ok "תיקיית GitHub נוצרה: $wsRoot"
}

if (Test-Path $projectPath) {
    Write-Warn "תיקיית הפרויקט כבר קיימת: $projectPath"
    if (-not (Ask-YesNo "ליצור פרויקט חדש? (הקיים לא יימחק, השם ישתנה)")) {
        Write-Info "משתמש בפרויקט הקיים"
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $projectName = "my-first-project-$timestamp"
        $projectPath = Join-Path $wsRoot $projectName
    }
}

if (-not (Test-Path $projectPath)) {
    Invoke-SafeCommand "יצירת תיקיית פרויקט" {
        New-Item -Path $projectPath -ItemType Directory -Force | Out-Null
    }
}

# Initialize git repo
if (-not $DryRun) {
    Push-Location $projectPath
    if (-not (Test-Path ".git")) {
        git init --initial-branch=main 2>$null | Out-Null
        Write-Ok "מאגר Git אותחל"
    }
}

# ---- Create project files based on age ----

switch ($selectedKid.ProjectType) {

    'html' {
        # ===== EYAL (8.5) — Fun HTML page =====
        Write-Doing "יוצר דף אינטרנט צבעוני ומגניב... 🎨"

        $indexHtml = @'
<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🦸 העמוד של אייל</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>🦸 שלום! אני אייל! 🦸</h1>
            <p class="subtitle">!ברוכים הבאים לעמוד שלי</p>
        </header>

        <section class="about-me">
            <h2>🌟 קצת עליי</h2>
            <div class="info-card">
                <p>👦 <strong>שם:</strong> אייל דרשר</p>
                <p>🎂 <strong>גיל:</strong> 8.5</p>
                <p>🎮 <strong>תחביבים:</strong> משחקי מחשב, לגו, ספורט</p>
                <p>🍕 <strong>אוכל אהוב:</strong> פיצה!</p>
            </div>
        </section>

        <section class="fun-stuff">
            <h2>🎨 דברים שאני אוהב</h2>
            <div class="emoji-grid">
                <div class="emoji-card" onclick="this.classList.toggle('flip')">🎮</div>
                <div class="emoji-card" onclick="this.classList.toggle('flip')">⚽</div>
                <div class="emoji-card" onclick="this.classList.toggle('flip')">🧱</div>
                <div class="emoji-card" onclick="this.classList.toggle('flip')">🍕</div>
                <div class="emoji-card" onclick="this.classList.toggle('flip')">🎬</div>
                <div class="emoji-card" onclick="this.classList.toggle('flip')">📚</div>
                <div class="emoji-card" onclick="this.classList.toggle('flip')">🏀</div>
                <div class="emoji-card" onclick="this.classList.toggle('flip')">🎵</div>
            </div>
        </section>

        <section class="color-changer">
            <h2>🌈 שנה צבע רקע!</h2>
            <div class="buttons">
                <button onclick="document.body.style.background='#FFE5E5'" style="background:#FFE5E5">🩷</button>
                <button onclick="document.body.style.background='#E5F0FF'" style="background:#E5F0FF">💙</button>
                <button onclick="document.body.style.background='#E5FFE5'" style="background:#E5FFE5">💚</button>
                <button onclick="document.body.style.background='#FFF5E5'" style="background:#FFF5E5">🧡</button>
                <button onclick="document.body.style.background='#F0E5FF'" style="background:#F0E5FF">💜</button>
                <button onclick="document.body.style.background='#FFFDE5'" style="background:#FFFDE5">💛</button>
            </div>
        </section>

        <footer>
            <p>נבנה על ידי אייל דרשר 🚀 — הפרויקט הראשון שלי!</p>
        </footer>
    </div>
</body>
</html>
'@

        $styleCss = @'
/* הסגנון של העמוד של אייל */

* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Arial, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    transition: background 0.5s ease;
}

.container {
    max-width: 700px;
    margin: 0 auto;
    padding: 20px;
}

header {
    text-align: center;
    padding: 40px 20px;
    background: rgba(255, 255, 255, 0.95);
    border-radius: 20px;
    margin-bottom: 20px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.1);
}

header h1 {
    font-size: 2.5em;
    color: #6c5ce7;
    margin-bottom: 10px;
    animation: bounce 2s ease infinite;
}

@keyframes bounce {
    0%, 100% { transform: translateY(0); }
    50% { transform: translateY(-10px); }
}

.subtitle {
    font-size: 1.3em;
    color: #888;
}

section {
    background: rgba(255, 255, 255, 0.95);
    border-radius: 20px;
    padding: 30px;
    margin-bottom: 20px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.1);
}

section h2 {
    font-size: 1.6em;
    color: #6c5ce7;
    margin-bottom: 15px;
    text-align: center;
}

.info-card {
    background: #f8f9ff;
    border-radius: 15px;
    padding: 20px;
    font-size: 1.2em;
    line-height: 2;
}

.emoji-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 15px;
    justify-items: center;
}

.emoji-card {
    font-size: 3em;
    cursor: pointer;
    transition: transform 0.3s ease;
    padding: 10px;
    border-radius: 15px;
    background: #f0f0ff;
}

.emoji-card:hover {
    transform: scale(1.3) rotate(10deg);
}

.emoji-card.flip {
    transform: scale(1.3) rotate(360deg);
}

.buttons {
    display: flex;
    justify-content: center;
    gap: 10px;
    flex-wrap: wrap;
}

.buttons button {
    font-size: 2em;
    padding: 15px 20px;
    border: 3px solid #ddd;
    border-radius: 50%;
    cursor: pointer;
    transition: transform 0.2s ease;
}

.buttons button:hover {
    transform: scale(1.2);
    border-color: #6c5ce7;
}

footer {
    text-align: center;
    padding: 20px;
    color: white;
    font-size: 1em;
}
'@

        $readme = @"
# 🦸 העמוד של אייל

## מה יש כאן?
זה הפרויקט הראשון שלי! עמוד אינטרנט צבעוני וכיפי.

## 📁 קבצים
| קובץ | מה הוא עושה |
|------|------------|
| ``index.html`` | העמוד הראשי — כאן כתוב התוכן |
| ``style.css`` | עיצוב — הצבעים, הגדלים, והאנימציות |

## 🚀 איך לפתוח?
1. לחץ לחיצה כפולה על ``index.html``
2. או: פתח ב-VS Code ולחץ על **Go Live** (בפינה הימנית למטה)

## 🎨 מה אפשר לשנות?
- שנה את השם, הגיל והתחביבים ב-``index.html``
- שנה צבעים ב-``style.css``
- הוסף עוד אימוג'ים!

## 📚 ללמוד עוד
- [HTML בעברית — קוד קוד](https://www.codecode.co.il/html)
- [CSS — צעדים ראשונים](https://www.codecode.co.il/css)

---
נבנה באהבה 💜 על ידי אייל דרשר
"@

        if (-not $DryRun) {
            $indexHtml | Out-File -FilePath (Join-Path $projectPath "index.html") -Encoding utf8
            $styleCss  | Out-File -FilePath (Join-Path $projectPath "style.css")  -Encoding utf8
            $readme    | Out-File -FilePath (Join-Path $projectPath "README.md")  -Encoding utf8
        }

        Write-Ok "נוצרו: index.html, style.css, README.md"
    }

    'javascript' {
        # ===== YONATAN (13) — JavaScript Games =====
        Write-Doing "יוצר פרויקט משחקים ב-JavaScript... 🎮"

        $indexHtml = @'
<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🎮 המשחקים של יונתן</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>🎮 מרכז המשחקים של יונתן</h1>
            <p>בחר משחק ותתחיל לשחק!</p>
        </header>

        <nav class="game-nav">
            <button onclick="showGame('guess')" class="active">🔢 נחש את המספר</button>
            <button onclick="showGame('tictactoe')">❌⭕ איקס עיגול</button>
            <button onclick="showGame('memory')">🧠 משחק זיכרון</button>
        </nav>

        <!-- Guess the Number -->
        <div id="game-guess" class="game-panel">
            <h2>🔢 נחש את המספר</h2>
            <p>בחרתי מספר בין 1 ל-100. נסה לנחש!</p>
            <div class="game-area">
                <input type="number" id="guessInput" min="1" max="100" placeholder="הקלד מספר...">
                <button onclick="checkGuess()">נחש!</button>
                <p id="guessResult" class="result"></p>
                <p id="guessCount"></p>
                <button onclick="resetGuess()" class="reset-btn">משחק חדש 🔄</button>
            </div>
        </div>

        <!-- Tic Tac Toe -->
        <div id="game-tictactoe" class="game-panel" style="display:none">
            <h2>❌⭕ איקס עיגול</h2>
            <p id="tttStatus">תור: ❌</p>
            <div class="ttt-board" id="tttBoard">
                <div class="ttt-cell" onclick="tttMove(0)"></div>
                <div class="ttt-cell" onclick="tttMove(1)"></div>
                <div class="ttt-cell" onclick="tttMove(2)"></div>
                <div class="ttt-cell" onclick="tttMove(3)"></div>
                <div class="ttt-cell" onclick="tttMove(4)"></div>
                <div class="ttt-cell" onclick="tttMove(5)"></div>
                <div class="ttt-cell" onclick="tttMove(6)"></div>
                <div class="ttt-cell" onclick="tttMove(7)"></div>
                <div class="ttt-cell" onclick="tttMove(8)"></div>
            </div>
            <button onclick="resetTTT()" class="reset-btn">משחק חדש 🔄</button>
        </div>

        <!-- Memory Game -->
        <div id="game-memory" class="game-panel" style="display:none">
            <h2>🧠 משחק זיכרון</h2>
            <p>מצא את כל הזוגות! <span id="memoryMoves">מהלכים: 0</span></p>
            <div class="memory-board" id="memoryBoard"></div>
            <button onclick="resetMemory()" class="reset-btn">משחק חדש 🔄</button>
        </div>

        <footer>
            <p>נבנה על ידי יונתן דרשר 🚀 | JavaScript + HTML + CSS</p>
        </footer>
    </div>

    <script src="games.js"></script>
</body>
</html>
'@

        $styleCss = @'
* { margin: 0; padding: 0; box-sizing: border-box; }

body {
    font-family: 'Segoe UI', Arial, sans-serif;
    background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
    color: white;
    min-height: 100vh;
}

.container { max-width: 800px; margin: 0 auto; padding: 20px; }

header { text-align: center; padding: 30px; }
header h1 { font-size: 2.2em; margin-bottom: 10px; }
header p { color: #aaa; font-size: 1.1em; }

.game-nav {
    display: flex; gap: 10px; justify-content: center;
    margin: 20px 0; flex-wrap: wrap;
}

.game-nav button {
    background: rgba(255,255,255,0.1); color: white;
    border: 2px solid rgba(255,255,255,0.2); padding: 12px 24px;
    border-radius: 12px; font-size: 1.1em; cursor: pointer;
    transition: all 0.3s ease;
}

.game-nav button:hover, .game-nav button.active {
    background: rgba(108, 92, 231, 0.6);
    border-color: #6c5ce7;
}

.game-panel {
    background: rgba(255,255,255,0.05); border-radius: 20px;
    padding: 30px; text-align: center;
    border: 1px solid rgba(255,255,255,0.1);
}

.game-panel h2 { font-size: 1.5em; margin-bottom: 10px; }
.game-panel p { color: #ccc; margin-bottom: 15px; }

.game-area input {
    padding: 12px; font-size: 1.2em; border-radius: 10px;
    border: 2px solid #6c5ce7; background: rgba(255,255,255,0.1);
    color: white; text-align: center; width: 150px;
}

.game-area button, .reset-btn {
    padding: 12px 24px; font-size: 1em; border-radius: 10px;
    border: none; background: #6c5ce7; color: white;
    cursor: pointer; margin: 10px;
    transition: background 0.3s;
}

.game-area button:hover, .reset-btn:hover { background: #5b4cdb; }

.result { font-size: 1.3em; margin-top: 15px; min-height: 30px; }

/* Tic Tac Toe */
.ttt-board {
    display: grid; grid-template-columns: repeat(3, 100px);
    gap: 5px; justify-content: center; margin: 20px auto;
}

.ttt-cell {
    width: 100px; height: 100px; font-size: 2.5em;
    display: flex; align-items: center; justify-content: center;
    background: rgba(255,255,255,0.1); border-radius: 10px;
    cursor: pointer; transition: background 0.2s;
}

.ttt-cell:hover { background: rgba(255,255,255,0.2); }

/* Memory */
.memory-board {
    display: grid; grid-template-columns: repeat(4, 80px);
    gap: 10px; justify-content: center; margin: 20px auto;
}

.memory-card {
    width: 80px; height: 80px; font-size: 2em;
    display: flex; align-items: center; justify-content: center;
    background: rgba(108, 92, 231, 0.4); border-radius: 10px;
    cursor: pointer; transition: all 0.3s; user-select: none;
}

.memory-card.flipped, .memory-card.matched {
    background: rgba(255,255,255,0.2);
}

.memory-card.matched { opacity: 0.6; cursor: default; }

footer { text-align: center; padding: 20px; color: #666; }
'@

        $gamesJs = @'
// ====== נחש את המספר ======
let secretNumber = Math.floor(Math.random() * 100) + 1;
let guessAttempts = 0;

function checkGuess() {
    const input = document.getElementById('guessInput');
    const result = document.getElementById('guessResult');
    const count = document.getElementById('guessCount');
    const guess = parseInt(input.value);

    if (isNaN(guess) || guess < 1 || guess > 100) {
        result.textContent = '⚠️ הקלד מספר בין 1 ל-100';
        result.style.color = '#ffd700';
        return;
    }

    guessAttempts++;
    count.textContent = `ניסיונות: ${guessAttempts}`;

    if (guess === secretNumber) {
        result.textContent = `🎉 מצאת! המספר הוא ${secretNumber}! (${guessAttempts} ניסיונות)`;
        result.style.color = '#00ff88';
    } else if (guess < secretNumber) {
        result.textContent = '⬆️ גבוה יותר!';
        result.style.color = '#ff6b6b';
    } else {
        result.textContent = '⬇️ נמוך יותר!';
        result.style.color = '#ff6b6b';
    }

    input.value = '';
    input.focus();
}

function resetGuess() {
    secretNumber = Math.floor(Math.random() * 100) + 1;
    guessAttempts = 0;
    document.getElementById('guessResult').textContent = '';
    document.getElementById('guessCount').textContent = '';
    document.getElementById('guessInput').value = '';
}

// ====== איקס עיגול ======
let tttBoard = Array(9).fill('');
let tttCurrent = '❌';
let tttGameOver = false;

function tttMove(index) {
    if (tttBoard[index] || tttGameOver) return;

    tttBoard[index] = tttCurrent;
    document.getElementById('tttBoard').children[index].textContent = tttCurrent;

    const winner = checkWin();
    const status = document.getElementById('tttStatus');

    if (winner) {
        status.textContent = `🎉 ${winner} ניצח!`;
        tttGameOver = true;
    } else if (tttBoard.every(cell => cell)) {
        status.textContent = '🤝 תיקו!';
        tttGameOver = true;
    } else {
        tttCurrent = tttCurrent === '❌' ? '⭕' : '❌';
        status.textContent = `תור: ${tttCurrent}`;
    }
}

function checkWin() {
    const lines = [
        [0,1,2], [3,4,5], [6,7,8],
        [0,3,6], [1,4,7], [2,5,8],
        [0,4,8], [2,4,6]
    ];
    for (const [a, b, c] of lines) {
        if (tttBoard[a] && tttBoard[a] === tttBoard[b] && tttBoard[a] === tttBoard[c]) {
            return tttBoard[a];
        }
    }
    return null;
}

function resetTTT() {
    tttBoard = Array(9).fill('');
    tttCurrent = '❌';
    tttGameOver = false;
    document.getElementById('tttStatus').textContent = 'תור: ❌';
    document.querySelectorAll('.ttt-cell').forEach(cell => cell.textContent = '');
}

// ====== משחק זיכרון ======
const memoryEmojis = ['🐶','🐱','🐸','🦁','🐵','🐼','🐧','🦄'];
let memoryCards = [];
let memoryFlipped = [];
let memoryMatched = [];
let memoryMoves = 0;

function initMemory() {
    const doubled = [...memoryEmojis, ...memoryEmojis];
    memoryCards = doubled.sort(() => Math.random() - 0.5);
    memoryFlipped = [];
    memoryMatched = [];
    memoryMoves = 0;
    document.getElementById('memoryMoves').textContent = 'מהלכים: 0';

    const board = document.getElementById('memoryBoard');
    board.innerHTML = '';
    memoryCards.forEach((emoji, i) => {
        const card = document.createElement('div');
        card.className = 'memory-card';
        card.textContent = '❓';
        card.onclick = () => flipCard(i, card);
        board.appendChild(card);
    });
}

function flipCard(index, element) {
    if (memoryFlipped.length >= 2 || memoryMatched.includes(index) || memoryFlipped.find(f => f.index === index)) return;

    element.textContent = memoryCards[index];
    element.classList.add('flipped');
    memoryFlipped.push({ index, element });

    if (memoryFlipped.length === 2) {
        memoryMoves++;
        document.getElementById('memoryMoves').textContent = `מהלכים: ${memoryMoves}`;

        const [first, second] = memoryFlipped;
        if (memoryCards[first.index] === memoryCards[second.index]) {
            first.element.classList.add('matched');
            second.element.classList.add('matched');
            memoryMatched.push(first.index, second.index);
            memoryFlipped = [];

            if (memoryMatched.length === memoryCards.length) {
                setTimeout(() => alert(`🎉 ניצחת! סיימת ב-${memoryMoves} מהלכים!`), 300);
            }
        } else {
            setTimeout(() => {
                first.element.textContent = '❓';
                second.element.textContent = '❓';
                first.element.classList.remove('flipped');
                second.element.classList.remove('flipped');
                memoryFlipped = [];
            }, 800);
        }
    }
}

function resetMemory() { initMemory(); }

// ====== Navigation ======
function showGame(name) {
    document.querySelectorAll('.game-panel').forEach(p => p.style.display = 'none');
    document.querySelectorAll('.game-nav button').forEach(b => b.classList.remove('active'));
    document.getElementById('game-' + name).style.display = 'block';
    event.target.classList.add('active');

    if (name === 'memory' && memoryCards.length === 0) initMemory();
}

// Init memory on first load if visible
document.addEventListener('DOMContentLoaded', () => initMemory());
'@

        $readme = @"
# 🎮 מרכז המשחקים של יונתן

## מה יש כאן?
שלושה משחקים שכתבתי ב-JavaScript!

### 🔢 נחש את המספר
המחשב בוחר מספר בין 1 ל-100, ואתה מנסה לנחש.
הוא יגיד לך אם לנחש גבוה יותר או נמוך יותר.

### ❌⭕ איקס עיגול
המשחק הקלאסי — שני שחקנים, מי שעושה שורה מנצח!

### 🧠 משחק זיכרון
הפוך קלפים ומצא את הזוגות. נסה לסיים בכמה שפחות מהלכים!

## 📁 מבנה הפרויקט
| קובץ | תפקיד |
|------|--------|
| ``index.html`` | המבנה של הדף — כפתורים, שדות, לוח משחק |
| ``style.css`` | העיצוב — צבעים, גדלים, אנימציות |
| ``games.js`` | הלוגיקה — הקוד שגורם למשחקים לעבוד |

## 🚀 איך לשחק?
1. פתח את ``index.html`` בדפדפן (לחיצה כפולה)
2. או: פתח ב-VS Code ולחץ על **Go Live**

## 🛠️ איך לשנות?
- רוצה לשנות טווח מספרים? שנה ``Math.random() * 100`` ב-``games.js``
- רוצה אימוג'ים אחרים בזיכרון? שנה את ``memoryEmojis``
- רוצה צבעים אחרים? שנה ב-``style.css``

## 📚 ללמוד עוד
- [JavaScript למתחילים — קוד קוד](https://www.codecode.co.il/javascript)
- [MDN Web Docs בעברית](https://developer.mozilla.org/he/)
- [FreeCodeCamp](https://www.freecodecamp.org/) — קורס חינמי מעולה

---
נבנה באהבה 💜 על ידי יונתן דרשר
"@

        $vsCodeSettings = @'
{
    "liveServer.settings.donotShowInfoMsg": true,
    "editor.fontSize": 16,
    "editor.tabSize": 2,
    "editor.formatOnSave": true,
    "emmet.includeLanguages": {
        "javascript": "html"
    }
}
'@

        $vsCodeExtensions = @'
{
    "recommendations": [
        "ritwickdey.LiveServer",
        "esbenp.prettier-vscode",
        "formulahendry.auto-rename-tag",
        "dbaeumer.vscode-eslint",
        "MS-CEINTL.vscode-language-pack-he"
    ]
}
'@

        if (-not $DryRun) {
            $indexHtml | Out-File -FilePath (Join-Path $projectPath "index.html")  -Encoding utf8
            $styleCss  | Out-File -FilePath (Join-Path $projectPath "style.css")   -Encoding utf8
            $gamesJs   | Out-File -FilePath (Join-Path $projectPath "games.js")    -Encoding utf8
            $readme    | Out-File -FilePath (Join-Path $projectPath "README.md")   -Encoding utf8

            $vscodePath = Join-Path $projectPath ".vscode"
            New-Item -Path $vscodePath -ItemType Directory -Force | Out-Null
            $vsCodeSettings   | Out-File -FilePath (Join-Path $vscodePath "settings.json")   -Encoding utf8
            $vsCodeExtensions | Out-File -FilePath (Join-Path $vscodePath "extensions.json") -Encoding utf8
        }

        Write-Ok "נוצרו: index.html, style.css, games.js, README.md"
    }

    'python' {
        # ===== SHIRA (15) — Python Projects =====
        Write-Doing "יוצרת פרויקט Python מגניב... 🐍"

        $mainPy = @'
#!/usr/bin/env python3
"""
🌟 הפרויקט הראשון של שירה
============================
אוסף דוגמאות מגניבות ב-Python!

הריצי: python main.py
"""

import random


def greeting():
    """ברכה אישית — שנה את הפרטים!"""
    name = "שירה"
    hobbies = ["תכנות", "מוזיקה", "קריאה"]
    print(f"\n🌟 שלום! אני {name}!")
    print(f"🎯 התחביבים שלי: {', '.join(hobbies)}")
    print(f"🐍 אני לומדת Python!")


def number_guessing_game():
    """משחק ניחוש מספרים"""
    print("\n🔢 משחק נחש את המספר!")
    print("=" * 30)

    secret = random.randint(1, 50)
    attempts = 0

    while True:
        try:
            guess = int(input("נחשי מספר בין 1 ל-50: "))
            attempts += 1

            if guess == secret:
                print(f"🎉 מצאת! המספר הוא {secret} ({attempts} ניסיונות)")
                break
            elif guess < secret:
                print("⬆️ יותר גבוה!")
            else:
                print("⬇️ יותר נמוך!")
        except ValueError:
            print("⚠️ הקלידי מספר בבקשה")


def text_analyzer():
    """ניתוח טקסט — סופרת מילים, אותיות ועוד"""
    print("\n📝 מנתח טקסט")
    print("=" * 30)

    text = input("הקלידי משפט לניתוח: ")

    words = text.split()
    chars = len(text)
    chars_no_spaces = len(text.replace(" ", ""))
    unique_words = len(set(w.lower() for w in words))

    print(f"\n📊 תוצאות:")
    print(f"  📏 אורך: {chars} תווים ({chars_no_spaces} בלי רווחים)")
    print(f"  📝 מילים: {len(words)} (מתוכן {unique_words} ייחודיות)")
    print(f"  🔤 המילה הארוכה ביותר: {max(words, key=len)}")

    # Frequency
    word_freq = {}
    for w in words:
        w_lower = w.lower()
        word_freq[w_lower] = word_freq.get(w_lower, 0) + 1

    if len(word_freq) > 1:
        most_common = max(word_freq, key=word_freq.get)
        print(f"  🏆 המילה הנפוצה ביותר: '{most_common}' ({word_freq[most_common]} פעמים)")


def password_generator():
    """מחולל סיסמאות חזקות"""
    import string

    print("\n🔐 מחולל סיסמאות")
    print("=" * 30)

    try:
        length = int(input("אורך סיסמה רצוי (8-30): "))
        length = max(8, min(30, length))
    except ValueError:
        length = 12

    chars = string.ascii_letters + string.digits + "!@#$%^&*"
    password = ''.join(random.choice(chars) for _ in range(length))

    strength = "חלשה 😟"
    if length >= 12 and any(c.isupper() for c in password) and any(c.isdigit() for c in password):
        strength = "חזקה 💪"
    elif length >= 10:
        strength = "בינונית 🤔"

    print(f"\n🔑 הסיסמה שלך: {password}")
    print(f"💪 חוזק: {strength}")
    print("⚠️ שמרי אותה במקום בטוח!")


def simple_calculator():
    """מחשבון עם היסטוריה"""
    print("\n🧮 מחשבון חכם")
    print("=" * 30)
    print("הקלידי חישוב (למשל: 2 + 3) או 'יציאה' לסיום")

    history = []

    while True:
        expr = input("\n🧮 > ")
        if expr.strip() in ('יציאה', 'exit', 'q'):
            if history:
                print(f"\n📋 היסטוריה ({len(history)} חישובים):")
                for h in history[-5:]:
                    print(f"   {h}")
            break
        try:
            # Safe eval — only math operations
            allowed = set('0123456789+-*/.() ')
            if all(c in allowed for c in expr):
                result = eval(expr)
                print(f"   = {result}")
                history.append(f"{expr} = {result}")
            else:
                print("⚠️ אפשר להשתמש רק במספרים ופעולות חשבון")
        except Exception:
            print("❌ ביטוי לא תקין — נסי שוב")


def main():
    """תפריט ראשי"""
    greeting()

    menu = {
        '1': ('🔢 משחק ניחוש מספרים', number_guessing_game),
        '2': ('📝 מנתח טקסט', text_analyzer),
        '3': ('🔐 מחולל סיסמאות', password_generator),
        '4': ('🧮 מחשבון חכם', simple_calculator),
    }

    while True:
        print("\n" + "=" * 30)
        print("📋 בחרי פעילות:")
        for key, (name, _) in menu.items():
            print(f"  [{key}] {name}")
        print("  [0] יציאה 👋")
        print("=" * 30)

        choice = input("\nבחירה > ").strip()

        if choice == '0':
            print("\n👋 להתראות שירה! המשיכי לתכנת! 🚀")
            break
        elif choice in menu:
            menu[choice][1]()
        else:
            print("⚠️ בחירה לא תקינה — נסי שוב")


if __name__ == '__main__':
    main()
'@

        $datavizPy = @'
#!/usr/bin/env python3
"""
📊 דוגמה לוויזואליזציית נתונים
================================
דוגמה שמראה איך ליצור גרפים ב-Python!

הריצי: python data_viz_example.py
(צריך להתקין קודם: pip install matplotlib)
"""


def create_charts():
    """יוצרת כמה גרפים לדוגמה"""
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print("❌ matplotlib לא מותקנת")
        print("💡 התקיני עם: pip install matplotlib")
        return

    # נתונים לדוגמה
    subjects = ['מתמטיקה', 'אנגלית', 'מדעים', 'היסטוריה', 'תכנות']
    grades = [92, 88, 95, 85, 98]
    colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A', '#98D8C8']

    # Bar chart — ציונים
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))

    axes[0].bar(subjects, grades, color=colors, edgecolor='white', linewidth=2)
    axes[0].set_title('📊 הציונים שלי', fontsize=16, fontweight='bold')
    axes[0].set_ylim(70, 100)
    axes[0].set_ylabel('ציון')
    for i, v in enumerate(grades):
        axes[0].text(i, v + 0.5, str(v), ha='center', fontweight='bold')

    # Pie chart — חלוקת זמן
    activities = ['לימודים', 'ספורט', 'חברים', 'תכנות', 'קריאה']
    hours = [5, 2, 3, 3, 1]
    axes[1].pie(hours, labels=activities, colors=colors, autopct='%1.0f%%',
                startangle=90, textprops={'fontsize': 11})
    axes[1].set_title('⏰ איך אני מבלה את היום', fontsize=16, fontweight='bold')

    plt.tight_layout()
    plt.savefig('my_charts.png', dpi=100, bbox_inches='tight')
    print("✅ הגרפים נשמרו ב-my_charts.png")
    plt.show()


if __name__ == '__main__':
    print("📊 יוצרת גרפים...")
    create_charts()
'@

        $requirementsTxt = @'
# דרישות הפרויקט של שירה
# התקנה: pip install -r requirements.txt

matplotlib>=3.7.0    # לגרפים ותרשימים
requests>=2.28.0     # לעבודה עם אתרים ו-API
'@

        $readme = @"
# 🌟 הפרויקט הראשון של שירה

## מה יש כאן?
אוסף כלים ומשחקים שכתבתי ב-Python!

## 🚀 התחלה מהירה

1. **פתחי טרמינל** (Terminal) ב-VS Code
2. **התקיני ספריות:**
   ``````
   pip install -r requirements.txt
   ``````
3. **הריצי:**
   ``````
   python main.py
   ``````

## 📁 קבצים בפרויקט

| קובץ | מה הוא עושה |
|------|-------------|
| ``main.py`` | תוכנית ראשית — משחקים וכלים |
| ``data_viz_example.py`` | דוגמה ליצירת גרפים |
| ``requirements.txt`` | רשימת ספריות נדרשות |

## 🎮 מה יש בתוכנית הראשית?

- 🔢 **משחק ניחוש מספרים** — המחשב בוחר, את מנחשת
- 📝 **מנתח טקסט** — מספר מילים, אותיות, ומציג סטטיסטיקות
- 🔐 **מחולל סיסמאות** — יוצר סיסמאות חזקות
- 🧮 **מחשבון חכם** — מחשבון עם היסטוריה

## 📊 ויזואליזציית נתונים
הריצי ``python data_viz_example.py`` כדי ליצור גרפים צבעוניים!

## 🛣️ מסלול למידה

### שלב 1: בסיס (שבוע 1-2)
- [x] הריצי את ``main.py`` ושחקי עם הכלים
- [ ] שני את הפרטים ב-``greeting()``
- [ ] הוסיפי משחק חדש לתפריט

### שלב 2: ביניים (שבוע 3-4)
- [ ] נסי ליצור גרפים משלך ב-``data_viz_example.py``
- [ ] למדי על ``requests`` — קבלת נתונים מהאינטרנט
- [ ] בני תוכנית שבודקת מזג אוויר

### שלב 3: מתקדם (חודש 2+)
- [ ] למדי Django/Flask — בניית אתרים
- [ ] נסי Data Science עם pandas
- [ ] בני פרויקט משלך!

## 📚 משאבים ללמידה
- [Python בעברית — Py4E](https://www.py4e.com/)
- [Automate the Boring Stuff](https://automatetheboringstuff.com/) — ספר חינמי
- [Real Python](https://realpython.com/) — מדריכים מעולים
- [Kaggle](https://www.kaggle.com/learn) — Data Science

## 🔧 הרחבות VS Code מומלצות
- Python (Microsoft)
- Pylance
- Jupyter
- Prettier

---
נבנה באהבה 💜 על ידי שירה דרשר
"@

        $vsCodeSettings = @'
{
    "python.defaultInterpreterPath": "python",
    "python.terminal.activateEnvironment": true,
    "editor.fontSize": 15,
    "editor.tabSize": 4,
    "editor.formatOnSave": true,
    "[python]": {
        "editor.defaultFormatter": "ms-python.python"
    }
}
'@

        $vsCodeExtensions = @'
{
    "recommendations": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "ms-toolsai.jupyter",
        "esbenp.prettier-vscode",
        "MS-CEINTL.vscode-language-pack-he"
    ]
}
'@

        if (-not $DryRun) {
            $mainPy          | Out-File -FilePath (Join-Path $projectPath "main.py")              -Encoding utf8
            $datavizPy       | Out-File -FilePath (Join-Path $projectPath "data_viz_example.py")  -Encoding utf8
            $requirementsTxt | Out-File -FilePath (Join-Path $projectPath "requirements.txt")     -Encoding utf8
            $readme          | Out-File -FilePath (Join-Path $projectPath "README.md")            -Encoding utf8

            $vscodePath = Join-Path $projectPath ".vscode"
            New-Item -Path $vscodePath -ItemType Directory -Force | Out-Null
            $vsCodeSettings   | Out-File -FilePath (Join-Path $vscodePath "settings.json")   -Encoding utf8
            $vsCodeExtensions | Out-File -FilePath (Join-Path $vscodePath "extensions.json") -Encoding utf8
        }

        Write-Ok "נוצרו: main.py, data_viz_example.py, requirements.txt, README.md"
    }
}

# .gitignore for all
$gitignore = @'
# Dependencies
node_modules/
__pycache__/
*.pyc
.env

# IDE
.vscode/settings.json
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Build outputs
dist/
build/
*.egg-info/
'@

if (-not $DryRun) {
    $gitignore | Out-File -FilePath (Join-Path $projectPath ".gitignore") -Encoding utf8
}

Write-Ok "פרויקט ראשון נוצר בהצלחה! 🎉"
Write-Info "מיקום: $projectPath"

# ============================================================
# STEP 6 — Git commit & Push to GitHub
# ============================================================
Write-Step 5 "🚀 העלאה ל-GitHub"

if (-not $DryRun) {
    # Stage and commit
    git add -A 2>$null
    git commit -m "🎉 הפרויקט הראשון שלי! First commit by $kidNameEn" 2>$null | Out-Null
    Write-Ok "הקבצים נשמרו ב-Git (commit)"

    if ($ghAuthed -and (Test-Command 'gh')) {
        Write-Doing "יוצר מאגר (repository) ב-GitHub..."

        $repoVisibility = "public"
        if ($kidAge -lt 13) {
            $repoVisibility = "private"
            Write-Info "המאגר יהיה פרטי (private) כי את/ה מתחת לגיל 13"
        }

        $ghResult = gh repo create $projectName --$repoVisibility --source=. --remote=origin --push 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "המאגר נוצר ב-GitHub והקבצים הועלו! 🚀"

            # Open in browser
            Write-Doing "פותח את המאגר בדפדפן..."
            gh browse 2>$null
        } else {
            # Maybe repo already exists
            if ($ghResult -match "already exists") {
                Write-Warn "מאגר בשם הזה כבר קיים ב-GitHub"
                Write-Info "אפשר ליצור עם שם אחר או להשתמש בקיים"
            } else {
                Write-Warn "לא הצלחתי ליצור מאגר ב-GitHub"
                Write-Info "אפשר ליצור ידנית ב: https://github.com/new"
                Write-Info "שגיאה: $ghResult"
            }
        }
    } else {
        Write-Warn "לא מחובר ל-GitHub — הקבצים נשמרו מקומית בלבד"
        Write-Info "אחרי שתתחבר/י, תריצ/י: gh repo create $projectName --public --source=. --push"
    }
} else {
    Write-Host "  🏜️  [DRY RUN] היה מבצע: git add, commit, gh repo create" -ForegroundColor DarkYellow
}

# ============================================================
# STEP 7 — VS Code Extensions
# ============================================================
Write-Step 6 "💻 הגדרת VS Code"

if (Test-Command 'code') {
    Write-Doing "מתקין הרחבות מומלצות..."

    foreach ($ext in $selectedKid.Extensions) {
        Invoke-SafeCommand "התקנת $ext" {
            code --install-extension $ext --force 2>$null | Out-Null
        }
    }
    Write-Ok "הרחבות VS Code הותקנו!"

    # Open project in VS Code
    if (-not $DryRun) {
        Write-Doing "פותח את הפרויקט ב-VS Code..."
        code $projectPath 2>$null
        Write-Ok "VS Code נפתח עם הפרויקט שלך!"
    }
} else {
    Write-Warn "VS Code לא נמצא — דלג על התקנת הרחבות"
}

# ============================================================
# STEP 8 — Summary
# ============================================================
if (-not $DryRun) {
    Pop-Location -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║                                                        ║" -ForegroundColor Green
Write-Host "  ║    🎉 !ההגדרה הושלמה בהצלחה                            ║" -ForegroundColor Green
Write-Host "  ║                                                        ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  $kidEmoji  $kidName — הנה מה שהוגדר:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ✅ Git מוגדר עם השם והמייל שלך" -ForegroundColor White
if ($ghAuthed) {
    Write-Host "  ✅ מחובר/ת ל-GitHub" -ForegroundColor White
} else {
    Write-Host "  ⚠️ עדיין לא מחובר/ת ל-GitHub" -ForegroundColor Yellow
}
Write-Host "  ✅ פרויקט ראשון נוצר: $projectName" -ForegroundColor White
Write-Host "  ✅ מיקום: $projectPath" -ForegroundColor White
Write-Host "  ✅ הרחבות VS Code הותקנו" -ForegroundColor White
Write-Host ""

# Age-specific next steps
Write-Host "  📋 צעדים הבאים:" -ForegroundColor Yellow

switch ($selectedKid.ProjectType) {
    'html' {
        Write-Host "  1. 🌐 פתח את index.html בדפדפן — תראה את העמוד שלך!" -ForegroundColor White
        Write-Host "  2. ✏️ שנה את הטקסט ב-VS Code ורענן את הדפדפן" -ForegroundColor White
        Write-Host "  3. 🎨 נסה לשנות צבעים ב-style.css" -ForegroundColor White
        Write-Host "  4. 🚀 למד עוד HTML ב: https://www.codecode.co.il" -ForegroundColor White
    }
    'javascript' {
        Write-Host "  1. 🎮 פתח index.html — שחק במשחקים!" -ForegroundColor White
        Write-Host "  2. 🔧 פתח games.js ב-VS Code — תראה איך הם עובדים" -ForegroundColor White
        Write-Host "  3. 🆕 נסה להוסיף משחק חדש" -ForegroundColor White
        Write-Host "  4. 📚 למד JavaScript ב: https://www.freecodecamp.org" -ForegroundColor White
    }
    'python' {
        Write-Host "  1. 🐍 הריצי בטרמינל: python main.py" -ForegroundColor White
        Write-Host "  2. 📊 הריצי: python data_viz_example.py" -ForegroundColor White
        Write-Host "  3. ✏️ שני את הפרטים ב-main.py" -ForegroundColor White
        Write-Host "  4. 📚 המשיכי ללמוד ב: https://www.py4e.com" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "  💡 טיפ: כל שינוי שתעשה, שמור עם:" -ForegroundColor DarkCyan
Write-Host "     git add -A && git commit -m 'תיאור השינוי' && git push" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  $kidEmoji  !בהצלחה $kidName! אבא גאה בך" -ForegroundColor Magenta
Write-Host ""
