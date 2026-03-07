# Ralph Watch v5 - Runs agency copilot with Squad agent every interval
# Launches a full Copilot session that can do actual work
# To stop: Ctrl+C

$intervalMinutes = 5
$round = 0

$prompt = 'Ralph, Go! make sure the PR comments are also taken care of and then merge the PRs when they are ready and open new issues if needed. dont forget to update me in teams if needed'

while ($true) {
    $round++
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "[$timestamp] Ralph Round $round - launching agency" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    try {
        agency copilot --yolo --agent squad -p $prompt
        Write-Host "[$timestamp] Round $round completed" -ForegroundColor Green
    } catch {
        Write-Host "[$timestamp] Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "[$timestamp] Next round in $intervalMinutes minutes..." -ForegroundColor DarkGray
    Start-Sleep -Seconds ($intervalMinutes * 60)
}
