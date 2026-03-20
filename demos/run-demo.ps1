<#
.SYNOPSIS
    Sets up and runs the Squad for Kids demo environment.

.DESCRIPTION
    Prepares a clean demo environment for recording the 5-min or 10-min demo.
    Handles profile loading, environment cleanup, and provides prompts to copy-paste.

.PARAMETER Mode
    - Fresh    : Removes student profile so onboarding triggers (default)
    - Preloaded: Loads the Yoav grade-2 profile to skip onboarding
    - Grade3   : Loads the grade-3 transition profile for Scene 11
    - Reset    : Full cleanup — removes all generated files

.EXAMPLE
    .\demos\run-demo.ps1 -Mode Fresh
    .\demos\run-demo.ps1 -Mode Preloaded
    .\demos\run-demo.ps1 -Mode Grade3
    .\demos\run-demo.ps1 -Mode Reset
#>

param(
    [ValidateSet("Fresh", "Preloaded", "Grade3", "Reset")]
    [string]$Mode = "Fresh"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Set-Location $repoRoot

$profilePath = Join-Path $repoRoot ".squad\student-profile.json"
$teachingPlanPath = Join-Path $repoRoot ".squad\teaching-plan.md"
$reportsDir = Join-Path $repoRoot ".squad\reports"
$demosDir = Join-Path $repoRoot "demos"
$logFile = Join-Path $demosDir "demo-output.log"

function Write-DemoHeader {
    param([string]$Text)
    $line = "=" * 60
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor White
    Write-Host $line -ForegroundColor Cyan
    Write-Host ""
}

function Remove-DemoArtifacts {
    # Remove student profile
    if (Test-Path $profilePath) {
        Remove-Item $profilePath -Force
        Write-Host "  [x] Removed student-profile.json" -ForegroundColor Yellow
    }

    # Remove teaching plan (generated during onboarding)
    if (Test-Path $teachingPlanPath) {
        Remove-Item $teachingPlanPath -Force
        Write-Host "  [x] Removed teaching-plan.md" -ForegroundColor Yellow
    }

    # Remove generated reports
    if (Test-Path $reportsDir) {
        $reports = Get-ChildItem $reportsDir -Filter "weekly-*.md" -ErrorAction SilentlyContinue
        foreach ($r in $reports) {
            Remove-Item $r.FullName -Force
            Write-Host "  [x] Removed report: $($r.Name)" -ForegroundColor Yellow
        }
    }

    # Remove demo output log
    if (Test-Path $logFile) {
        Remove-Item $logFile -Force
        Write-Host "  [x] Removed demo-output.log" -ForegroundColor Yellow
    }
}

function Show-DemoPrompts {
    param([string]$DemoType)

    Write-Host ""
    Write-Host "  Prompts to type during the demo:" -ForegroundColor Green
    Write-Host "  --------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    if ($DemoType -eq "5min") {
        Write-Host '  1. hi' -ForegroundColor White
        Write-Host '  2. Yoav' -ForegroundColor White
        Write-Host '  3. March 12, 2018' -ForegroundColor White
        Write-Host '  4. 2nd grade' -ForegroundColor White
        Write-Host '  5. Rishon LeZion' -ForegroundColor White
        Write-Host '  6. English please' -ForegroundColor White
        Write-Host '  7. Harry Potter' -ForegroundColor White
        Write-Host '  8. Let''s do some math!' -ForegroundColor White
        Write-Host '  9. 15' -ForegroundColor White
        Write-Host '  10. Show me the parent report' -ForegroundColor White
        Write-Host '  11. Thanks, bye!' -ForegroundColor White
    }
    elseif ($DemoType -eq "10min") {
        Write-Host '  1-11. (same as 5-min demo above)' -ForegroundColor DarkGray
        Write-Host '  12. I want to play a game!' -ForegroundColor White
        Write-Host '  13. 18' -ForegroundColor White
        Write-Host '  14. 28' -ForegroundColor White
        Write-Host '  15. Can I stop for now?' -ForegroundColor White
        Write-Host '  16. George, can you explain why it rains?' -ForegroundColor White
        Write-Host '  17. Evaporation!' -ForegroundColor White
        Write-Host '  18. this is hard, I can''t do math' -ForegroundColor White
        Write-Host '  19. let''s play a game with Fred' -ForegroundColor White
        Write-Host '  --- pause recording, load grade3 profile ---' -ForegroundColor Red
        Write-Host '  20. hi' -ForegroundColor White
        Write-Host '  --- switch to parent-squad directory ---' -ForegroundColor Red
        Write-Host '  21. How is Yoav doing?' -ForegroundColor White
        Write-Host '  --- switch back to main repo ---' -ForegroundColor Red
        Write-Host '  22. switch to Hebrew' -ForegroundColor White
        Write-Host '  23. בוא נעשה חשבון' -ForegroundColor White
        Write-Host '  24. תודה, להתראות!' -ForegroundColor White
    }
    Write-Host ""
}

# --- Main ---

switch ($Mode) {
    "Fresh" {
        Write-DemoHeader "Squad for Kids Demo — FRESH MODE"
        Write-Host "  Cleaning up for a fresh onboarding experience..." -ForegroundColor Cyan
        Remove-DemoArtifacts
        Write-Host ""
        Write-Host "  [OK] Environment is clean. No student profile exists." -ForegroundColor Green
        Write-Host "  [OK] Onboarding will trigger on first 'hi'." -ForegroundColor Green
        Show-DemoPrompts -DemoType "5min"
        Write-Host "  Ready to record! Start Copilot CLI with:" -ForegroundColor Cyan
        Write-Host '  copilot' -ForegroundColor White
        Write-Host ""
    }

    "Preloaded" {
        Write-DemoHeader "Squad for Kids Demo — PRELOADED MODE"
        Write-Host "  Loading Yoav grade-2 profile (skip onboarding)..." -ForegroundColor Cyan
        Remove-DemoArtifacts

        $sourceProfile = Join-Path $demosDir "profiles\yoav-grade2.json"
        Copy-Item $sourceProfile $profilePath -Force
        Write-Host "  [OK] Student profile loaded: Yoav, Grade 2, Harry Potter" -ForegroundColor Green
        Write-Host "  [OK] Session will start in Learning Mode." -ForegroundColor Green
        Write-Host ""
        Write-Host "  Ready to record! Start Copilot CLI with:" -ForegroundColor Cyan
        Write-Host '  copilot' -ForegroundColor White
        Write-Host ""
    }

    "Grade3" {
        Write-DemoHeader "Squad for Kids Demo — GRADE 3 TRANSITION"
        Write-Host "  Loading Yoav grade-3 transition profile..." -ForegroundColor Cyan

        $sourceProfile = Join-Path $demosDir "profiles\yoav-grade3-transition.json"
        Copy-Item $sourceProfile $profilePath -Force
        Write-Host "  [OK] Grade-3 profile loaded (simulates September transition)" -ForegroundColor Green
        Write-Host "  [OK] Ralph will detect grade transition on next session." -ForegroundColor Green
        Write-Host ""
    }

    "Reset" {
        Write-DemoHeader "Squad for Kids Demo — FULL RESET"
        Write-Host "  Removing ALL demo artifacts..." -ForegroundColor Cyan
        Remove-DemoArtifacts
        Write-Host ""
        Write-Host "  [OK] Full cleanup complete." -ForegroundColor Green
        Write-Host ""
    }
}
