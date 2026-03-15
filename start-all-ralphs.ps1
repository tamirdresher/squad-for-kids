# Start all Ralphs - launches Ralph monitors for all research repositories
# Auto-detects repo root from script location

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$researchRoot = Join-Path (Split-Path -Parent $repoRoot) "tamresearch1-research"

Write-Host "Starting Ralph for tamresearch1..." -ForegroundColor Cyan
Start-Process pwsh.exe -ArgumentList "-NoProfile -File ralph-watch.ps1" -WorkingDirectory $repoRoot -WindowStyle Normal

if (Test-Path (Join-Path $researchRoot "ralph-watch.ps1")) {
    Write-Host "Starting Ralph for tamresearch1-research..." -ForegroundColor Cyan
    Start-Process pwsh.exe -ArgumentList "-NoProfile -File ralph-watch.ps1" -WorkingDirectory $researchRoot -WindowStyle Normal
} else {
    Write-Host "Skipping tamresearch1-research (ralph-watch.ps1 not found at $researchRoot)" -ForegroundColor Yellow
}

Write-Host "Both Ralphs started successfully." -ForegroundColor Green
Write-Host "Monitor the console windows to see their activity." -ForegroundColor Yellow
