# Keep DevBox Alive — prevents Azure Dev Box auto-hibernation
# Azure Dev Boxes hibernate after inactivity. This script simulates activity
# so long-running agent tasks (GPU jobs, builds) aren't interrupted.
#
# Usage:
#   pwsh keep-devbox-alive.ps1                   # default 4-hour window
#   pwsh keep-devbox-alive.ps1 -DurationHours 8  # 8-hour window
#
# How it works:
#   Sends a keypress every 3 minutes to prevent the idle timer from triggering.
#   Logs keepalive events so you can verify it ran.
#
# Pair with Ralph: launch this BEFORE starting Ralph on a DevBox so the box
# stays alive while Ralph works through the queue.

param(
    [int]$DurationHours = 4,
    [int]$IntervalSeconds = 180   # 3 minutes
)

$endTime = (Get-Date).AddHours($DurationHours)
$logFile = Join-Path $env:USERPROFILE ".squad\devbox-keepalive.log"

# Ensure log directory exists
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

Write-Host "🔋 DevBox Keep-Alive started" -ForegroundColor Cyan
Write-Host "   Duration: $DurationHours hours (until $($endTime.ToString('HH:mm')))" -ForegroundColor Gray
Write-Host "   Interval: every $IntervalSeconds seconds" -ForegroundColor Gray
Write-Host "   Log: $logFile" -ForegroundColor Gray
Write-Host "   Press Ctrl+C to stop early" -ForegroundColor Gray
Write-Host ""

$round = 0
while ((Get-Date) -lt $endTime) {
    $round++
    $now = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'

    # Simulate activity — move mouse 0 pixels (no visible effect)
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $pos = [System.Windows.Forms.Cursor]::Position
        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($pos.X, $pos.Y)
    } catch {
        # Fallback: just log (headless environments won't have Forms)
    }

    $remaining = [math]::Round(($endTime - (Get-Date)).TotalMinutes, 0)
    $logEntry = "[$now] keepalive round=$round remaining=${remaining}min"
    Add-Content -Path $logFile -Value $logEntry -Encoding utf8

    if ($round % 10 -eq 1) {
        Write-Host "[$now] 💓 Keepalive ping #$round ($remaining min remaining)" -ForegroundColor Green
    }

    Start-Sleep -Seconds $IntervalSeconds
}

$finalMsg = "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] DevBox keep-alive completed after $round pings"
Add-Content -Path $logFile -Value $finalMsg -Encoding utf8
Write-Host "✅ Keep-alive window expired after $DurationHours hours ($round pings)" -ForegroundColor Green
