#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Parent setup script for Squad for Kids fork.
.DESCRIPTION
    Checks if this repo is a fork, sets up upstream remote,
    creates student-profile.json template, and prints welcome message.
#>

param(
    [switch]$SkipUpstream,
    [switch]$Force
)

$ErrorActionPreference = "Continue"

# ─── Colors & Helpers ───────────────────────────────────────────────

function Write-Step {
    param([string]$Emoji, [string]$Message)
    Write-Host ""
    Write-Host "  $Emoji  $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "     ✅ $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "     ⚠️  $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "     ❌ $Message" -ForegroundColor Red
}

# ─── Banner ─────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  🎓 ══════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  🎓   Squad for Kids — Parent Setup                  " -ForegroundColor Magenta
Write-Host "  🎓   סקוואד לילדים — הקמה להורים                    " -ForegroundColor Magenta
Write-Host "  🎓 ══════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

# ─── Step 1: Check if git repo ──────────────────────────────────────

Write-Step "📁" "Checking repository..."

$isGitRepo = git rev-parse --is-inside-work-tree 2>$null
if ($isGitRepo -ne "true") {
    Write-Err "Not inside a git repository. Please run this from the squad-for-kids folder."
    exit 1
}
Write-Ok "Inside a git repository"

# ─── Step 2: Check if this is a fork ────────────────────────────────

Write-Step "🍴" "Checking if this is a fork..."

$originUrl = git remote get-url origin 2>$null
$isFork = $false

if ($originUrl -and ($originUrl -notmatch "tamirdresher/squad-for-kids")) {
    $isFork = $true
    Write-Ok "This looks like a fork! Origin: $originUrl"
} elseif ($originUrl -match "tamirdresher/squad-for-kids") {
    Write-Warn "This appears to be the ORIGINAL repo, not a fork."
    Write-Warn "For the best experience, fork the repo first:"
    Write-Host "     1. Go to https://github.com/tamirdresher/squad-for-kids" -ForegroundColor White
    Write-Host "     2. Click 'Fork' button (top-right)" -ForegroundColor White
    Write-Host "     3. Clone YOUR fork and run this script there" -ForegroundColor White
    Write-Host ""

    if (-not $Force) {
        Write-Host "     Run with -Force to continue anyway." -ForegroundColor Gray
        exit 0
    }
    Write-Warn "Continuing with -Force flag..."
} else {
    Write-Warn "Could not determine origin URL. Continuing..."
}

# ─── Step 3: Set up upstream remote ─────────────────────────────────

if (-not $SkipUpstream) {
    Write-Step "🔗" "Setting up upstream remote..."

    $existingUpstream = git remote get-url upstream 2>$null
    if ($existingUpstream) {
        Write-Ok "Upstream already configured: $existingUpstream"
    } else {
        git remote add upstream "https://github.com/tamirdresher/squad-for-kids.git" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Upstream remote added: https://github.com/tamirdresher/squad-for-kids.git"
        } else {
            Write-Warn "Could not add upstream remote (may already exist with different name)"
        }
    }

    Write-Host ""
    Write-Host "     To sync updates later:" -ForegroundColor Gray
    Write-Host "       git fetch upstream" -ForegroundColor Gray
    Write-Host "       git merge upstream/main" -ForegroundColor Gray
    Write-Host "       git push origin main" -ForegroundColor Gray
}

# ─── Step 4: Create student-profile.json template ───────────────────

Write-Step "📄" "Checking student profile..."

$profilePath = Join-Path $PWD "student-profile.json"

if (Test-Path $profilePath) {
    Write-Ok "student-profile.json already exists — not overwriting"
} else {
    $profileTemplate = @{
        "_comment" = "This file will be populated by the Squad during the child's first session"
        "name" = ""
        "age" = $null
        "grade" = ""
        "country" = ""
        "curriculum" = ""
        "language" = ""
        "interests" = @()
        "universe" = ""
        "xp" = 0
        "level" = 1
        "badges" = @()
        "streak" = 0
        "created_at" = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        "last_session" = $null
    }

    $profileTemplate | ConvertTo-Json -Depth 3 | Set-Content -Path $profilePath -Encoding UTF8
    Write-Ok "Created student-profile.json template"
    Write-Host "     The Squad will fill this in during your child's first session!" -ForegroundColor Gray
}

# ─── Step 5: Ensure .squad directories exist ─────────────────────────

Write-Step "📁" "Checking .squad directories..."

$dirs = @(
    ".squad/reports"
)

foreach ($dir in $dirs) {
    $dirPath = Join-Path $PWD $dir
    if (-not (Test-Path $dirPath)) {
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        Write-Ok "Created $dir/"
    } else {
        Write-Ok "$dir/ already exists"
    }
}

# ─── Welcome Message ────────────────────────────────────────────────

Write-Host ""
Write-Host "  ═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  🎉 Setup complete! You're ready to go!" -ForegroundColor Green
Write-Host "  🎉 ההקמה הושלמה! אתם מוכנים!" -ForegroundColor Green
Write-Host ""
Write-Host "  ═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  📝 Next steps:" -ForegroundColor White
Write-Host "     1. Open Copilot Chat (💬 icon or Ctrl+Alt+I)" -ForegroundColor White
Write-Host "     2. Select the 'squad' agent from the dropdown" -ForegroundColor White
Write-Host "     3. Click 'Autopilot (Preview)'" -ForegroundColor White
Write-Host "     4. Let your child type: היי!" -ForegroundColor White
Write-Host ""
Write-Host "  📖 Parent guide: docs/parent-guide.md" -ForegroundColor Gray
Write-Host "  📖 מדריך להורים: docs/parent-guide-he.md" -ForegroundColor Gray
Write-Host ""
Write-Host "  🔄 To sync updates from the original repo:" -ForegroundColor Gray
Write-Host "     Click 'Sync fork' on your GitHub fork page" -ForegroundColor Gray
Write-Host "     Or run: git fetch upstream && git merge upstream/main" -ForegroundColor Gray
Write-Host ""

if ($isFork) {
    Write-Host "  🔒 Your child's progress stays in YOUR fork." -ForegroundColor Cyan
    Write-Host "     Only you can see it. Safe and private." -ForegroundColor Cyan
} else {
    Write-Host "  💡 Tip: Fork this repo for the best experience!" -ForegroundColor Yellow
    Write-Host "     Your child gets a personal copy with private progress tracking." -ForegroundColor Yellow
}

Write-Host ""
