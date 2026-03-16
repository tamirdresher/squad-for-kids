# Start All Ralphs — launches Ralph monitors for multiple repositories
# Each Ralph runs in its own window and watches a separate repo.
#
# Usage:
#   pwsh start-all-ralphs.ps1
#
# Why: When your Squad spans multiple repos (e.g., main project + research),
# each repo needs its own Ralph instance. This script launches them all.

param(
    [string[]]$ExtraRepoPaths = @()   # Additional repo paths to monitor
)

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── Primary repo (this repo) ──
Write-Host "🚀 Starting Ralph for primary repo..." -ForegroundColor Cyan
Write-Host "   Directory: $repoRoot" -ForegroundColor Gray
Start-Process pwsh.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File ralph-watch.ps1" `
    -WorkingDirectory $repoRoot -WindowStyle Normal

# ── Sibling repos (auto-detect repos in parent directory) ──
$parentDir = Split-Path -Parent $repoRoot
$siblingRepos = Get-ChildItem -Path $parentDir -Directory |
    Where-Object {
        $_.FullName -ne $repoRoot -and
        (Test-Path (Join-Path $_.FullName "ralph-watch.ps1"))
    }

foreach ($sibling in $siblingRepos) {
    Write-Host "🚀 Starting Ralph for $($sibling.Name)..." -ForegroundColor Cyan
    Write-Host "   Directory: $($sibling.FullName)" -ForegroundColor Gray
    Start-Process pwsh.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File ralph-watch.ps1" `
        -WorkingDirectory $sibling.FullName -WindowStyle Normal
}

# ── Extra repos (passed explicitly) ──
foreach ($extra in $ExtraRepoPaths) {
    if (Test-Path (Join-Path $extra "ralph-watch.ps1")) {
        Write-Host "🚀 Starting Ralph for $extra..." -ForegroundColor Cyan
        Start-Process pwsh.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File ralph-watch.ps1" `
            -WorkingDirectory $extra -WindowStyle Normal
    } else {
        Write-Host "⚠️  Skipping $extra (ralph-watch.ps1 not found)" -ForegroundColor Yellow
    }
}

$totalCount = 1 + $siblingRepos.Count + $ExtraRepoPaths.Count
Write-Host ""
Write-Host "✅ Launched $totalCount Ralph instance(s)." -ForegroundColor Green
Write-Host "   Each runs in its own window. Close windows to stop." -ForegroundColor Gray
