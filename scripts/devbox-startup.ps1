# Squad DevBox Startup — launches all persistent processes
# Place shortcut in shell:startup or register as scheduled task

$repoRoot = "C:\Users\tamirdresher\source\repos\tamresearch1"
$researchRoot = "C:\Users\tamirdresher\source\repos\tamresearch1-research"

Write-Host "Squad DevBox Startup - $(Get-Date)" -ForegroundColor Cyan

# 1. Keep-alive (prevents Dev Box auto-stop)
$keepAlive = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'keep-devbox-alive' }
if (-not $keepAlive) {
    Start-Process pwsh.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File $repoRoot\scripts\keep-devbox-alive.ps1" -WindowStyle Hidden
    Write-Host "  [OK] Keep-alive started" -ForegroundColor Green
} else {
    Write-Host "  [OK] Keep-alive already running (PID $($keepAlive.ProcessId))" -ForegroundColor Green
}

# 2. Ralph for tamresearch1
$ralph1 = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'ralph-watch' -and $_.CommandLine -match 'tamresearch1' -and $_.CommandLine -notmatch 'research' }
if (-not $ralph1) {
    Start-Process pwsh.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File ralph-watch.ps1" -WorkingDirectory $repoRoot -WindowStyle Normal
    Write-Host "  [OK] Ralph (tamresearch1) started" -ForegroundColor Green
} else {
    Write-Host "  [OK] Ralph (tamresearch1) already running (PID $($ralph1.ProcessId))" -ForegroundColor Green
}

# 3. Ralph for tamresearch1-research
if (Test-Path "$researchRoot\ralph-watch.ps1") {
    $ralph2 = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'ralph-watch' -and $_.CommandLine -match 'research' }
    if (-not $ralph2) {
        Start-Process pwsh.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File ralph-watch.ps1" -WorkingDirectory $researchRoot -WindowStyle Normal
        Write-Host "  [OK] Ralph (research) started" -ForegroundColor Green
    } else {
        Write-Host "  [OK] Ralph (research) already running (PID $($ralph2.ProcessId))" -ForegroundColor Green
    }
}

Write-Host "All processes started. This window will close." -ForegroundColor Cyan
Start-Sleep -Seconds 3
