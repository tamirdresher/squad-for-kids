# Start all Ralphs - launches Ralph monitors for all research repositories

Write-Host "Starting Ralph for tamresearch1..." -ForegroundColor Cyan
Start-Process pwsh.exe -ArgumentList "-NoProfile -File ralph-watch.ps1" -WorkingDirectory "C:\temp\tamresearch1" -WindowStyle Normal

Write-Host "Starting Ralph for tamresearch1-research..." -ForegroundColor Cyan
Start-Process pwsh.exe -ArgumentList "-NoProfile -File ralph-watch.ps1" -WorkingDirectory "C:\temp\tamresearch1-research" -WindowStyle Normal

Write-Host "Both Ralphs started successfully." -ForegroundColor Green
Write-Host "Monitor the console windows to see their activity." -ForegroundColor Yellow
