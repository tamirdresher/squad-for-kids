# Automation Watch v1.0 - Generic GitHub Copilot Agent Automation Loop
# Launches a Copilot session periodically to perform automated tasks
# To stop: Ctrl+C
# 
# Observability Features:
# - Structured logging to $env:USERPROFILE\.squad\automation-watch.log
# - Heartbeat file at $env:USERPROFILE\.squad\automation-heartbeat.json
# - Optional Teams/Slack webhook alerts on consecutive failures (>3)
# - Exit code, duration, and round tracking
# - Lockfile prevents duplicate instances per directory
# - Log rotation: capped at 500 entries / 1MB

# Fix UTF-8 rendering in Windows PowerShell console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# --- Single-instance lockfile ---
$lockFile = Join-Path (Get-Location) ".automation-watch.lock"
if (Test-Path $lockFile) {
    $lockContent = Get-Content $lockFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($lockContent -and $lockContent.pid) {
        $existing = Get-Process -Id $lockContent.pid -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "ERROR: Automation watch is already running in this directory (PID $($lockContent.pid), started $($lockContent.started))" -ForegroundColor Red
            Write-Host "Kill it first: Stop-Process -Id $($lockContent.pid) -Force" -ForegroundColor Yellow
            exit 1
        }
    }
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}

# Write lock
[ordered]@{ pid = $PID; started = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'); directory = (Get-Location).Path } | ConvertTo-Json | Out-File $lockFile -Encoding utf8 -Force

# Clean up lock on exit
Register-EngineEvent PowerShell.Exiting -Action { Remove-Item $lockFile -Force -ErrorAction SilentlyContinue } | Out-Null
trap { Remove-Item $lockFile -Force -ErrorAction SilentlyContinue; break }

$intervalMinutes = 5
$round = 0
$consecutiveFailures = 0
$maxLogEntries = 500
$maxLogBytes = 1048576  # 1MB

# Customize this prompt for your agent and workflow
$prompt = @'
You are an automated agent. Your job is to:
1. Check for open issues labeled "automation" in the GitHub repository
2. Review pull requests that need attention
3. Perform any automated tasks defined in .squad/automation-tasks.md
4. Report status and any actions taken

IMPORTANT: Work in parallel where possible. If there are multiple actionable items, spawn agents for all of them simultaneously as background tasks.
'@

# Initialize observability paths
$squadDir = Join-Path $env:USERPROFILE ".squad"
$logFile = Join-Path $squadDir "automation-watch.log"
$heartbeatFile = Join-Path $squadDir "automation-heartbeat.json"
$webhookFile = Join-Path $squadDir "webhook.url"  # Optional: Teams/Slack webhook URL

# Ensure .squad directory exists
if (-not (Test-Path $squadDir)) {
    New-Item -ItemType Directory -Path $squadDir -Force | Out-Null
}

# Initialize log file if it doesn't exist
if (-not (Test-Path $logFile)) {
    "# Automation Watch Log - Started $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')" | Out-File -FilePath $logFile -Encoding utf8
}

# Function to write structured log entry
function Write-AutomationLog {
    param(
        [int]$Round,
        [string]$Timestamp,
        [int]$ExitCode,
        [double]$DurationSeconds,
        [int]$ConsecutiveFailures,
        [string]$Status,
        [hashtable]$Metrics = @{}
    )
    
    $metricsStr = ""
    if ($Metrics.Count -gt 0) {
        $metricsParts = @()
        foreach ($key in $Metrics.Keys) {
            $metricsParts += "$key=$($Metrics[$key])"
        }
        if ($metricsParts.Count -gt 0) {
            $metricsStr = " | " + ($metricsParts -join " | ")
        }
    }
    
    $logEntry = "$Timestamp | Round=$Round | ExitCode=$ExitCode | Duration=${DurationSeconds}s | Failures=$ConsecutiveFailures | Status=$Status$metricsStr"
    Add-Content -Path $logFile -Value $logEntry -Encoding utf8
}

# Function to rotate log file
function Invoke-LogRotation {
    if (-not (Test-Path $logFile)) { return }
    
    $fileInfo = Get-Item $logFile
    $needsRotation = $false
    
    if ($fileInfo.Length -gt $maxLogBytes) {
        $needsRotation = $true
    }
    
    if (-not $needsRotation) {
        $lineCount = (Get-Content -Path $logFile -Encoding utf8 | Measure-Object -Line).Lines
        if ($lineCount -gt $maxLogEntries) {
            $needsRotation = $true
        }
    }
    
    if ($needsRotation) {
        $allLines = Get-Content -Path $logFile -Encoding utf8
        $header = $allLines | Select-Object -First 1
        $kept = $allLines | Select-Object -Last ($maxLogEntries - 1)
        $rotatedHeader = "# Automation Watch Log - Rotated $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') (kept last $($maxLogEntries - 1) entries)"
        @($rotatedHeader) + $kept | Out-File -FilePath $logFile -Encoding utf8 -Force
    }
}

# Function to update heartbeat file
function Update-Heartbeat {
    param(
        [int]$Round,
        [string]$Status,
        [int]$ExitCode = 0,
        [double]$DurationSeconds = 0,
        [int]$ConsecutiveFailures = 0,
        [hashtable]$Metrics = @{}
    )
    
    $heartbeat = [ordered]@{
        lastRun = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        lastHeartbeat = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        round = $Round
        status = $Status
        exitCode = $ExitCode
        durationSeconds = [math]::Round($DurationSeconds, 2)
        consecutiveFailures = $ConsecutiveFailures
        pid = $PID
    }
    
    if ($Metrics.Count -gt 0) {
        $heartbeat["metrics"] = $Metrics
    }
    
    $heartbeat | ConvertTo-Json | Out-File -FilePath $heartbeatFile -Encoding utf8 -Force
}

# Function to send webhook alert (Teams/Slack)
function Send-WebhookAlert {
    param(
        [int]$Round,
        [int]$ConsecutiveFailures,
        [int]$ExitCode
    )
    
    if (-not (Test-Path $webhookFile)) {
        return
    }
    
    $webhookUrl = Get-Content -Path $webhookFile -Raw -Encoding utf8 | ForEach-Object { $_.Trim() }
    
    if ([string]::IsNullOrWhiteSpace($webhookUrl)) {
        return
    }
    
    # Generic webhook payload (adjust for your platform)
    $message = @{
        text = "⚠️ Automation Watch Alert: $ConsecutiveFailures consecutive failures (Round $Round, Exit Code: $ExitCode)"
    }
    
    try {
        $body = $message | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json" | Out-Null
        Write-Host "Webhook alert sent successfully" -ForegroundColor Yellow
    } catch {
        Write-Host "Failed to send webhook alert: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

while ($true) {
    $round++
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $displayTime = Get-Date -Format "HH:mm:ss"
    $startTime = Get-Date
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "[$displayTime] Automation Round $round started" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    # Write heartbeat BEFORE round
    Update-Heartbeat -Round $round -Status "running" -ConsecutiveFailures $consecutiveFailures
    
    # Optional: Pull latest changes from git
    Write-Host "[$timestamp] Checking for repository updates..." -ForegroundColor Yellow
    try {
        git fetch 2>$null | Out-Null
        
        $gitStatus = git status --porcelain
        if ($gitStatus) {
            Write-Host "[$timestamp] Local changes detected, skipping pull..." -ForegroundColor Yellow
        } else {
            $pullResult = git pull 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[$timestamp] Repository updated successfully" -ForegroundColor Green
            } else {
                Write-Host "[$timestamp] Warning: git pull failed" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "[$timestamp] Warning: Failed to update repository: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Run the copilot agent
    $exitCode = 0
    $roundStatus = "idle"
    $metrics = @{}
    
    # Start background heartbeat updater
    $roundStartTime = Get-Date
    $activityRunspace = [PowerShell]::Create()
    $activityRunspace.AddScript({
        param($RoundNum, $HeartbeatFile, $RoundStart)
        while ($true) {
            Start-Sleep -Seconds 30
            $elapsed = (Get-Date) - $RoundStart
            $elapsedStr = "{0}m {1:00}s" -f [math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds
            $ts = Get-Date -Format "HH:mm:ss"
            
            [Console]::ForegroundColor = 'DarkGray'
            [Console]::WriteLine("  [$ts] Round $RoundNum running... ($elapsedStr elapsed)")
            [Console]::ResetColor()
            
            # Update heartbeat
            if (Test-Path $HeartbeatFile) {
                try {
                    $hb = Get-Content -Path $HeartbeatFile -Raw -Encoding utf8 | ConvertFrom-Json
                    $hb | Add-Member -NotePropertyName "lastHeartbeat" -NotePropertyValue (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') -Force
                    $hb | ConvertTo-Json | Out-File -FilePath $HeartbeatFile -Encoding utf8 -Force
                } catch {}
            }
        }
    }).AddArgument($round).AddArgument($heartbeatFile).AddArgument($roundStartTime) | Out-Null
    $activityHandle = $activityRunspace.BeginInvoke()
    
    try {
        # Run GitHub Copilot CLI
        # Adjust the agent name and parameters as needed
        $ErrorActionPreference_saved = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        gh copilot --agent automation -p $prompt
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $ErrorActionPreference_saved
        
        if ($exitCode -eq 0) {
            $consecutiveFailures = 0
            $roundStatus = "idle"
            $logStatus = "SUCCESS"
        } else {
            $consecutiveFailures++
            $roundStatus = "error"
            $logStatus = "FAILED"
        }
        
    } catch {
        Write-Host "[$timestamp] Error: $($_.Exception.Message)" -ForegroundColor Red
        $exitCode = 1
        $consecutiveFailures++
        $roundStatus = "error"
        $logStatus = "ERROR"
    } finally {
        if ($activityRunspace) {
            $activityRunspace.Stop()
            $activityRunspace.Dispose()
        }
    }
    
    # Calculate duration
    $endTime = Get-Date
    $durationSeconds = ($endTime - $startTime).TotalSeconds
    $durationMinutes = [math]::Floor($durationSeconds / 60)
    $durationSecs = [math]::Floor($durationSeconds % 60)
    $durationStr = "${durationMinutes}m ${durationSecs}s"
    $endDisplayTime = Get-Date -Format "HH:mm:ss"
    
    # Show round completion
    if ($exitCode -eq 0) {
        Write-Host "[$endDisplayTime] Round $round completed in $durationStr (exit: $exitCode)" -ForegroundColor Green
    } else {
        Write-Host "[$endDisplayTime] Round $round completed in $durationStr (exit: $exitCode)" -ForegroundColor Yellow
    }
    
    # Write structured log entry
    Write-AutomationLog -Round $round -Timestamp $timestamp -ExitCode $exitCode -DurationSeconds $durationSeconds -ConsecutiveFailures $consecutiveFailures -Status $logStatus -Metrics $metrics
    
    # Write heartbeat AFTER round
    Update-Heartbeat -Round $round -Status $roundStatus -ExitCode $exitCode -DurationSeconds $durationSeconds -ConsecutiveFailures $consecutiveFailures -Metrics $metrics
    
    # Rotate log if needed
    Invoke-LogRotation
    
    # Send webhook alert if 3+ consecutive failures
    if ($consecutiveFailures -ge 3) {
        Write-Host "[$timestamp] Consecutive failures threshold reached ($consecutiveFailures), sending alert..." -ForegroundColor Yellow
        Send-WebhookAlert -Round $round -ConsecutiveFailures $consecutiveFailures -ExitCode $exitCode
    }
    
    # Calculate next round time
    $nextRoundTime = (Get-Date).AddSeconds($intervalMinutes * 60)
    $nextRoundDisplayTime = $nextRoundTime.ToString("HH:mm:ss")
    Write-Host "[$endDisplayTime] Next round at $nextRoundDisplayTime (in $intervalMinutes minutes)" -ForegroundColor DarkGray
    
    Start-Sleep -Seconds ($intervalMinutes * 60)
}
