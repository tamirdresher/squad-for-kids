<#
.SYNOPSIS
    Squad for Kids — One-command setup wizard for Windows.
.DESCRIPTION
    Walks a parent through forking, installing tools, creating a student
    profile, and launching VS Code so their child can start learning with
    GitHub Copilot.
.PARAMETER language
    UI language: 'en' (English, default) or 'he' (Hebrew).
.PARAMETER skip_profile
    Skip the interactive student-profile questionnaire.
.EXAMPLE
    .\setup.ps1
    .\setup.ps1 -language he
    .\setup.ps1 -skip_profile
#>
[CmdletBinding()]
param(
    [ValidateSet('en', 'he')]
    [string]$language = '',
    [switch]$skip_profile
)

# ── Strict mode & encoding ──────────────────────────────────────────────
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ── Translation dictionary ──────────────────────────────────────────────
$T = @{
    # Banner / general
    'welcome'              = @{ en = 'Welcome to Squad for Kids!'; he = '!Squad for Kids -ברוכים הבאים ל' }
    'subtitle'             = @{ en = 'AI-powered learning platform for curious kids'; he = 'פלטפורמת למידה מבוססת בינה מלאכותית לילדים סקרנים' }
    'lang_prompt'          = @{ en = 'Choose language / בחר שפה  [en/he]'; he = 'Choose language / בחר שפה  [en/he]' }
    'step'                 = @{ en = 'Step'; he = 'שלב' }
    'of'                   = @{ en = 'of'; he = 'מתוך' }
    'done'                 = @{ en = 'Done'; he = 'בוצע' }
    'skipped'              = @{ en = 'Skipped'; he = 'דולג' }
    'yes_no'               = @{ en = '(y/n)'; he = '(y/n)' }
    'press_enter'          = @{ en = 'Press Enter to continue...'; he = '...לחץ Enter להמשך' }

    # Fork detection
    'fork_title'           = @{ en = 'Checking your copy of the project'; he = 'בדיקת העותק שלך של הפרויקט' }
    'fork_ok'              = @{ en = 'Great — you are working in your own copy (fork).'; he = '.מצוין — אתה עובד בעותק שלך (פורק)' }
    'fork_direct'          = @{ en = "It looks like you cloned the original project directly.`nTo save your child's progress you need your own copy (a 'fork')."; he = "נראה ששכפלת את הפרויקט המקורי ישירות.`nכדי לשמור את ההתקדמות של ילדך צריך עותק משלך ('פורק')." }
    'fork_open'            = @{ en = 'Open the fork page in your browser now?'; he = '?לפתוח את דף הפורק בדפדפן' }
    'fork_url'             = @{ en = 'After forking, clone YOUR copy and run this script again.'; he = '.אחרי הפורק, שכפל את העותק שלך והרץ את הסקריפט שוב' }
    'fork_no_git'          = @{ en = 'Not inside a Git repository — we will set one up later.'; he = '.לא בתוך מאגר Git — נגדיר אחד מאוחר יותר' }

    # Prerequisites
    'prereq_title'         = @{ en = 'Installing tools your child needs'; he = 'התקנת כלים שילדך צריך' }
    'git_desc'             = @{ en = 'Git — the tool that saves every version of your child''s work (like "undo" for the whole project).'; he = '.Git — הכלי ששומר כל גרסה של עבודת ילדך (כמו "בטל" לכל הפרויקט)' }
    'node_desc'            = @{ en = 'Node.js — the engine that runs the learning activities and mini-games.'; he = '.Node.js — המנוע שמריץ את פעילויות הלמידה ומשחקונים' }
    'vscode_desc'          = @{ en = 'Visual Studio Code — a free, friendly code editor (think: a smart notebook for code).'; he = '.Visual Studio Code — עורך קוד חינמי וידידותי (כמו מחברת חכמה לקוד)' }
    'ghcli_desc'           = @{ en = 'GitHub CLI — lets us connect to GitHub (where the project lives) from this window.'; he = '.GitHub CLI — מאפשר לנו להתחבר ל-GitHub (שם הפרויקט חי) מהחלון הזה' }
    'copilot_ext_desc'     = @{ en = 'GitHub Copilot extension — your child''s AI learning buddy inside VS Code.'; he = '.תוסף GitHub Copilot — חבר הלמידה AI של ילדך בתוך VS Code' }
    'tool_found'           = @{ en = 'found'; he = 'נמצא' }
    'tool_missing'         = @{ en = 'not found — installing now...'; he = '...לא נמצא — מתקין כעת' }
    'tool_install_q'       = @{ en = 'Install it now?'; he = '?להתקין עכשיו' }
    'tool_install_ok'      = @{ en = 'Installed successfully!'; he = '!הותקן בהצלחה' }
    'tool_install_fail'    = @{ en = 'Installation had a problem. You may need to install manually.'; he = '.ההתקנה נתקלה בבעיה. ייתכן שתצטרך להתקין ידנית' }
    'tool_skipped'         = @{ en = 'Skipped — you can install it later.'; he = '.דולג — תוכל להתקין מאוחר יותר' }

    # GitHub login
    'gh_login_title'       = @{ en = 'Connecting to GitHub'; he = 'התחברות ל-GitHub' }
    'gh_login_ok'          = @{ en = 'You are logged in to GitHub.'; he = '.אתה מחובר ל-GitHub' }
    'gh_login_needed'      = @{ en = "You need to sign in to GitHub so your child's work is saved online.`nA browser window will open — just follow the steps."; he = "עליך להתחבר ל-GitHub כדי שעבודת ילדך תישמר.`n.חלון דפדפן ייפתח — פשוט עקוב אחרי השלבים" }
    'gh_login_start'       = @{ en = 'Starting GitHub login...'; he = '...מתחיל התחברות ל-GitHub' }

    # Student profile
    'profile_title'        = @{ en = 'Creating your child''s learning profile'; he = 'יצירת פרופיל הלמידה של ילדך' }
    'profile_name'         = @{ en = 'Child''s first name'; he = 'שם פרטי של הילד/ה' }
    'profile_age'          = @{ en = 'Age (6-18)'; he = '(6-18) גיל' }
    'profile_age_invalid'  = @{ en = 'Please enter a number between 6 and 18.'; he = '.אנא הכנס מספר בין 6 ל-18' }
    'profile_grade'        = @{ en = 'Grade (suggested: {0}) — press Enter to accept or type a different one'; he = 'כיתה (מוצע: {0}) — לחץ Enter לאישור או הקלד אחרת' }
    'profile_lang'         = @{ en = 'Preferred learning language'; he = 'שפת לימוד מועדפת' }
    'profile_lang_opts'    = @{ en = '1) English  2) Hebrew  3) Arabic'; he = '1) אנגלית  2) עברית  3) ערבית' }
    'profile_interests'    = @{ en = 'What does your child enjoy? Pick numbers separated by commas:'; he = ':מה ילדך אוהב? בחר מספרים מופרדים בפסיקים' }
    'profile_saved'        = @{ en = 'Profile saved!'; he = '!הפרופיל נשמר' }

    # Extensions
    'ext_title'            = @{ en = 'Setting up VS Code extensions'; he = 'התקנת תוספים ל-VS Code' }

    # Final
    'final_title'          = @{ en = 'All set! 🎉'; he = '!הכל מוכן 🎉' }
    'final_open_vscode'    = @{ en = 'Opening VS Code now...'; he = '...פותח את VS Code כעת' }
    'final_next'           = @{ en = "Next steps:`n  1. In VS Code, open Copilot Chat (click the chat icon on the left).`n  2. Type @squad and say hi!`n  3. Your child can ask Squad anything — it will guide them step by step."; he = "צעדים הבאים:`n  .VS Code-ב ,Copilot Chat פתח את .1`n  !squad@ הקלד ותגיד שלום .2`n  .Squad-ילדך יכול לשאול את  — הוא ידריך צעד אחרי צעד .3" }
    'final_have_fun'       = @{ en = 'Have fun learning! 🚀'; he = '!בהצלחה בלמידה 🚀' }

    # Errors
    'err_generic'          = @{ en = 'Something went wrong. Here are the details:'; he = ':משהו השתבש. הנה הפרטים' }
    'err_winget'           = @{ en = "The Windows package manager (winget) was not found.`nPlease install the tool manually or update Windows to a recent version."; he = "מנהל החבילות של Windows (winget) לא נמצא.`n.אנא התקן את הכלי ידנית או עדכן את Windows לגרסה עדכנית" }
}

# ── Helpers ──────────────────────────────────────────────────────────────

function Get-Msg ([string]$key) {
    if ($T.ContainsKey($key)) { return $T[$key][$script:lang] }
    return $key
}

function Show-Step ([int]$num, [int]$total, [string]$titleKey) {
    $label = "$(Get-Msg 'step') $num $(Get-Msg 'of') $total"
    Write-Host ''
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "  🎯 $label — $(Get-Msg $titleKey)" -ForegroundColor Magenta
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
}

function Ask-YesNo ([string]$prompt) {
    Write-Host "  $prompt $(Get-Msg 'yes_no') " -ForegroundColor Yellow -NoNewline
    $answer = Read-Host
    return ($answer -match '^[yY]')
}

function Test-Command ([string]$cmd) {
    try { $null = Get-Command $cmd -ErrorAction Stop; return $true }
    catch { return $false }
}

function Install-Tool ([string]$wingetId, [string]$descKey, [string]$testCmd) {
    Write-Host ''
    Write-Host "  💡 $(Get-Msg $descKey)" -ForegroundColor Cyan
    if (Test-Command $testCmd) {
        Write-Host "  ✅ $testCmd $(Get-Msg 'tool_found')" -ForegroundColor Green
        return $true
    }
    Write-Host "  ❌ $testCmd $(Get-Msg 'tool_missing')" -ForegroundColor Yellow
    if (-not (Ask-YesNo (Get-Msg 'tool_install_q'))) {
        Write-Host "  ⏭️  $(Get-Msg 'tool_skipped')" -ForegroundColor DarkYellow
        return $false
    }
    if (-not (Test-Command 'winget')) {
        Write-Host "  ❌ $(Get-Msg 'err_winget')" -ForegroundColor Red
        return $false
    }
    try {
        Write-Host "  ⏳ Installing $wingetId ..." -ForegroundColor Cyan
        $proc = Start-Process winget -ArgumentList "install --id $wingetId -e --accept-source-agreements --accept-package-agreements" `
                    -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -eq 0) {
            Write-Host "  ✅ $(Get-Msg 'tool_install_ok')" -ForegroundColor Green
            # Refresh PATH so the new tool is visible in this session
            $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                        [System.Environment]::GetEnvironmentVariable('Path', 'User')
            return $true
        } else {
            Write-Host "  ⚠️  $(Get-Msg 'tool_install_fail')" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "  ⚠️  $(Get-Msg 'tool_install_fail')" -ForegroundColor Yellow
        Write-Host "     $($_.Exception.Message)" -ForegroundColor DarkYellow
        return $false
    }
}

function Install-VSCodeExtension ([string]$extId) {
    if (-not (Test-Command 'code')) {
        Write-Host "  ⏭️  VS Code not found — skipping $extId" -ForegroundColor DarkYellow
        return
    }
    $installed = & code --list-extensions 2>$null
    if ($installed -and ($installed -match [regex]::Escape($extId))) {
        Write-Host "  ✅ $extId $(Get-Msg 'tool_found')" -ForegroundColor Green
    } else {
        Write-Host "  ⏳ Installing $extId ..." -ForegroundColor Cyan
        & code --install-extension $extId --force 2>$null | Out-Null
        Write-Host "  ✅ $extId $(Get-Msg 'tool_install_ok')" -ForegroundColor Green
    }
}

# ── Interest list (bilingual) ───────────────────────────────────────────
$InterestList = @(
    @{ en = 'Games 🎮';    he = '🎮 משחקים';    id = 'games'   }
    @{ en = 'Science 🔬';  he = '🔬 מדע';       id = 'science' }
    @{ en = 'Art 🎨';      he = '🎨 אמנות';     id = 'art'     }
    @{ en = 'Music 🎵';    he = '🎵 מוזיקה';    id = 'music'   }
    @{ en = 'Sports ⚽';   he = '⚽ ספורט';     id = 'sports'  }
    @{ en = 'Animals 🐾';  he = '🐾 חיות';      id = 'animals' }
    @{ en = 'Space 🚀';    he = '🚀 חלל';       id = 'space'   }
    @{ en = 'Coding 💻';   he = '💻 תכנות';     id = 'coding'  }
    @{ en = 'Cooking 🍳';  he = '🍳 בישול';     id = 'cooking' }
    @{ en = 'Reading 📚';  he = '📚 קריאה';     id = 'reading' }
)

# ========================================================================
#  MAIN
# ========================================================================
try {

# ── 0. Language selection ────────────────────────────────────────────────
Write-Host ''
Write-Host '  ╔═══════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '  ║                                                       ║' -ForegroundColor Cyan
Write-Host '  ║   ███████  ██████  ██    ██  █████  ██████            ║' -ForegroundColor Magenta
Write-Host '  ║   ██      ██    ██ ██    ██ ██   ██ ██   ██           ║' -ForegroundColor Magenta
Write-Host '  ║   ███████ ██    ██ ██    ██ ███████ ██   ██           ║' -ForegroundColor Yellow
Write-Host '  ║        ██ ██ ▄▄ ██ ██    ██ ██   ██ ██   ██           ║' -ForegroundColor Yellow
Write-Host '  ║   ███████  ██████   ██████  ██   ██ ██████            ║' -ForegroundColor Green
Write-Host '  ║               ▀▀                                      ║' -ForegroundColor Green
Write-Host '  ║          🧒  f o r   K i d s  👧                     ║' -ForegroundColor Cyan
Write-Host '  ║                                                       ║' -ForegroundColor Cyan
Write-Host '  ╚═══════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

if ($language -eq '') {
    Write-Host "  🌐 Choose language / בחר שפה  [en/he] " -ForegroundColor Yellow -NoNewline
    $langInput = Read-Host
    if ($langInput -match '^he') { $language = 'he' } else { $language = 'en' }
}
$script:lang = $language

Write-Host ''
Write-Host "  🎉 $(Get-Msg 'welcome')" -ForegroundColor Green
Write-Host "  $(Get-Msg 'subtitle')" -ForegroundColor Cyan
Write-Host ''

$totalSteps = if ($skip_profile) { 6 } else { 7 }

# ── Step 1: Fork detection ──────────────────────────────────────────────
Show-Step 1 $totalSteps 'fork_title'

$isInsideGit = $false
try {
    $gitRemote = & git remote get-url origin 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitRemote) { $isInsideGit = $true }
} catch { }

if ($isInsideGit) {
    if ($gitRemote -match 'tamirdresher/squad-for-kids') {
        Write-Host "  ⚠️  $(Get-Msg 'fork_direct')" -ForegroundColor Yellow
        Write-Host ''
        if (Ask-YesNo (Get-Msg 'fork_open')) {
            Start-Process 'https://github.com/tamirdresher/squad-for-kids/fork'
            Write-Host "  🌐 $(Get-Msg 'fork_url')" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  ✅ $(Get-Msg 'fork_ok')" -ForegroundColor Green
    }
} else {
    Write-Host "  ℹ️  $(Get-Msg 'fork_no_git')" -ForegroundColor Cyan
}

# ── Step 2: Prerequisites ───────────────────────────────────────────────
Show-Step 2 $totalSteps 'prereq_title'

Install-Tool 'Git.Git'                  'git_desc'    'git'
Install-Tool 'OpenJS.NodeJS.LTS'        'node_desc'   'node'
Install-Tool 'Microsoft.VisualStudioCode' 'vscode_desc' 'code'
Install-Tool 'GitHub.cli'               'ghcli_desc'  'gh'

# Copilot extension (handled separately — needs VS Code to be present)
Write-Host ''
Write-Host "  💡 $(Get-Msg 'copilot_ext_desc')" -ForegroundColor Cyan
Install-VSCodeExtension 'GitHub.copilot'

# ── Step 3: GitHub login ────────────────────────────────────────────────
Show-Step 3 $totalSteps 'gh_login_title'

$ghLoggedIn = $false
if (Test-Command 'gh') {
    $null = & gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ $(Get-Msg 'gh_login_ok')" -ForegroundColor Green
        $ghLoggedIn = $true
    }
}
if (-not $ghLoggedIn) {
    if (Test-Command 'gh') {
        Write-Host "  ℹ️  $(Get-Msg 'gh_login_needed')" -ForegroundColor Yellow
        Write-Host ''
        Write-Host "  🔑 $(Get-Msg 'gh_login_start')" -ForegroundColor Cyan
        & gh auth login -w -p https
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ $(Get-Msg 'gh_login_ok')" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Login did not complete — you can try again later with: gh auth login" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ⏭️  GitHub CLI not installed — skipping login." -ForegroundColor DarkYellow
    }
}

# ── Step 4: Student profile ─────────────────────────────────────────────
$currentStep = 4
if (-not $skip_profile) {
    Show-Step $currentStep $totalSteps 'profile_title'

    # Name
    Write-Host "  📝 $(Get-Msg 'profile_name'): " -ForegroundColor Yellow -NoNewline
    $childName = Read-Host
    while ([string]::IsNullOrWhiteSpace($childName)) {
        Write-Host "  📝 $(Get-Msg 'profile_name'): " -ForegroundColor Yellow -NoNewline
        $childName = Read-Host
    }

    # Age
    $childAge = 0
    while ($childAge -lt 6 -or $childAge -gt 18) {
        Write-Host "  📝 $(Get-Msg 'profile_age'): " -ForegroundColor Yellow -NoNewline
        $ageInput = Read-Host
        if ($ageInput -match '^\d+$') {
            $childAge = [int]$ageInput
        }
        if ($childAge -lt 6 -or $childAge -gt 18) {
            Write-Host "  ❌ $(Get-Msg 'profile_age_invalid')" -ForegroundColor Red
        }
    }

    # Grade suggestion: Israeli school system — age minus 5 is roughly the grade
    $suggestedGrade = [Math]::Max(1, [Math]::Min(12, $childAge - 5))
    $gradePrompt = (Get-Msg 'profile_grade') -f $suggestedGrade
    Write-Host "  📝 $gradePrompt`: " -ForegroundColor Yellow -NoNewline
    $gradeInput = Read-Host
    if ([string]::IsNullOrWhiteSpace($gradeInput)) {
        $childGrade = $suggestedGrade
    } else {
        $childGrade = [int]$gradeInput
    }

    # Learning language
    Write-Host "  📝 $(Get-Msg 'profile_lang'):" -ForegroundColor Yellow
    Write-Host "     $(Get-Msg 'profile_lang_opts')" -ForegroundColor Cyan
    Write-Host "     > " -NoNewline
    $langChoice = Read-Host
    $learningLang = switch ($langChoice) {
        '1' { 'English' }
        '2' { 'Hebrew'  }
        '3' { 'Arabic'  }
        default { 'English' }
    }

    # Interests
    Write-Host "  📝 $(Get-Msg 'profile_interests')" -ForegroundColor Yellow
    for ($i = 0; $i -lt $InterestList.Count; $i++) {
        Write-Host "     $($i + 1)) $($InterestList[$i][$script:lang])" -ForegroundColor Cyan
    }
    Write-Host "     > " -NoNewline
    $interestInput = Read-Host
    $selectedInterests = @()
    foreach ($token in ($interestInput -split '[,\s]+')) {
        $idx = 0
        if ([int]::TryParse($token.Trim(), [ref]$idx) -and $idx -ge 1 -and $idx -le $InterestList.Count) {
            $selectedInterests += $InterestList[$idx - 1].id
        }
    }
    if ($selectedInterests.Count -eq 0) { $selectedInterests = @('coding') }

    # Build & save profile
    $profile = [ordered]@{
        name             = $childName
        age              = $childAge
        grade            = $childGrade
        learningLanguage = $learningLang
        interests        = $selectedInterests
        createdAt        = (Get-Date -Format 'o')
    }

    $profilePath = Join-Path $PSScriptRoot 'student-profile.json'
    $profile | ConvertTo-Json -Depth 4 | Set-Content -Path $profilePath -Encoding UTF8

    Write-Host ''
    Write-Host "  ✅ $(Get-Msg 'profile_saved')  ($profilePath)" -ForegroundColor Green
    $currentStep++
} else {
    Write-Host ''
    Write-Host "  ⏭️  $(Get-Msg 'skipped') (--skip-profile)" -ForegroundColor DarkYellow
    # currentStep stays 4; next step is 5 either way
    $currentStep++
}

# ── Step N-2: VS Code extensions ────────────────────────────────────────
Show-Step $currentStep $totalSteps 'ext_title'

$extensions = @('GitHub.copilot', 'GitHub.copilot-chat')
foreach ($ext in $extensions) {
    Install-VSCodeExtension $ext
}
$currentStep++

# ── Step N-1: Open VS Code ──────────────────────────────────────────────
Show-Step $currentStep $totalSteps 'final_title'

if (Test-Command 'code') {
    Write-Host "  🚀 $(Get-Msg 'final_open_vscode')" -ForegroundColor Cyan
    & code $PSScriptRoot
}

Write-Host ''
Write-Host '  ╔═══════════════════════════════════════════════════════╗' -ForegroundColor Green
Write-Host '  ║                                                       ║' -ForegroundColor Green
Write-Host '  ║   ✅  S E T U P   C O M P L E T E !                  ║' -ForegroundColor Green
Write-Host '  ║                                                       ║' -ForegroundColor Green
Write-Host '  ╚═══════════════════════════════════════════════════════╝' -ForegroundColor Green
Write-Host ''
Write-Host "  $(Get-Msg 'final_next')" -ForegroundColor Cyan
Write-Host ''
Write-Host "  $(Get-Msg 'final_have_fun')" -ForegroundColor Magenta
Write-Host ''

} catch {
    Write-Host '' 
    Write-Host "  ❌ $(Get-Msg 'err_generic')" -ForegroundColor Red
    Write-Host "     $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "     $($_.ScriptStackTrace)" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host "  💡 Need help? Open an issue: https://github.com/tamirdresher/squad-for-kids/issues" -ForegroundColor Yellow
    Write-Host ''
}
