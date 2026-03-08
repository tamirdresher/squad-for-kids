# Ralph Watch v7 - Runs agency copilot with Squad agent every interval
# Launches a full Copilot session that can do actual work
# To stop: Ctrl+C
# 
# Observability Features:
# - Structured logging to $env:USERPROFILE\.squad\ralph-watch.log
# - Heartbeat file at $env:USERPROFILE\.squad\ralph-heartbeat.json
# - Teams alerts on consecutive failures (>3)
# - Exit code, duration, and round tracking

$intervalMinutes = 5
$round = 0
$consecutiveFailures = 0

$prompt = 'Ralph, Go! make sure the PR comments are also taken care of and then merge the PRs when they are ready and open new issues if needed. IMPORTANT: Only send a Teams message if there are important changes that require my attention — such as new issues needing my decision, PRs ready for review or merged, CI failures, completed work I should know about, or items requiring user action. Do NOT send a Teams message for routine board status checks with no actionable changes.'

# Initialize observability paths
$squadDir = Join-Path $env:USERPROFILE ".squad"
$logFile = Join-Path $squadDir "ralph-watch.log"
$heartbeatFile = Join-Path $squadDir "ralph-heartbeat.json"
$teamsWebhookFile = Join-Path $squadDir "teams-webhook.url"

# Ensure .squad directory exists
if (-not (Test-Path $squadDir)) {
    New-Item -ItemType Directory -Path $squadDir -Force | Out-Null
}

# Initialize log file if it doesn't exist
if (-not (Test-Path $logFile)) {
    "# Ralph Watch Log - Started $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')" | Out-File -FilePath $logFile -Encoding utf8
}

# Function to write structured log entry
function Write-RalphLog {
    param(
        [int]$Round,
        [string]$Timestamp,
        [int]$ExitCode,
        [double]$DurationSeconds,
        [int]$ConsecutiveFailures,
        [string]$Status
    )
    
    $logEntry = "$Timestamp | Round=$Round | ExitCode=$ExitCode | Duration=${DurationSeconds}s | Failures=$ConsecutiveFailures | Status=$Status"
    Add-Content -Path $logFile -Value $logEntry -Encoding utf8
}

# Function to rotate log file (keep last $maxLogEntries entries, or rotate at $maxLogBytes)
function Invoke-LogRotation {
    if (-not (Test-Path $logFile)) { return }
    
    $fileInfo = Get-Item $logFile
    $needsRotation = $false
    
    # Check size threshold
    if ($fileInfo.Length -gt $maxLogBytes) {
        $needsRotation = $true
    }
    
    # Check entry count
    if (-not $needsRotation) {
        $lineCount = (Get-Content -Path $logFile -Encoding utf8 | Measure-Object -Line).Lines
        if ($lineCount -gt $maxLogEntries) {
            $needsRotation = $true
        }
    }
    
    if ($needsRotation) {
        $allLines = Get-Content -Path $logFile -Encoding utf8
        # Keep header + last ($maxLogEntries - 1) entries
        $header = $allLines | Select-Object -First 1
        $kept = $allLines | Select-Object -Last ($maxLogEntries - 1)
        $rotatedHeader = "# Ralph Watch Log - Rotated $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') (kept last $($maxLogEntries - 1) entries)"
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
        [int]$ConsecutiveFailures = 0
    )
    
    $heartbeat = [ordered]@{
        lastRun = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        round = $Round
        status = $Status
        exitCode = $ExitCode
        durationSeconds = [math]::Round($DurationSeconds, 2)
        consecutiveFailures = $ConsecutiveFailures
        pid = $PID
    }
    
    $heartbeat | ConvertTo-Json | Out-File -FilePath $heartbeatFile -Encoding utf8 -Force
}

# Function to send Teams alert
function Send-TeamsAlert {
    param(
        [int]$Round,
        [int]$ConsecutiveFailures,
        [int]$ExitCode
    )
    
    if (-not (Test-Path $teamsWebhookFile)) {
        Write-Host "[$timestamp] Warning: Teams webhook URL not found at $teamsWebhookFile" -ForegroundColor Yellow
        return
    }
    
    $webhookUrl = Get-Content -Path $teamsWebhookFile -Raw -Encoding utf8 | ForEach-Object { $_.Trim() }
    
    if ([string]::IsNullOrWhiteSpace($webhookUrl)) {
        Write-Host "[$timestamp] Warning: Teams webhook URL is empty" -ForegroundColor Yellow
        return
    }
    
    $message = @{
        "@type" = "MessageCard"
        "@context" = "https://schema.org/extensions"
        summary = "Ralph Watch Alert: $ConsecutiveFailures Consecutive Failures"
        themeColor = "FF0000"
        title = "⚠️ Ralph Watch Alert"
        sections = @(
            @{
                activityTitle = "Ralph watch has experienced $ConsecutiveFailures consecutive failures"
                facts = @(
                    @{
                        name = "Round"
                        value = $Round
                    },
                    @{
                        name = "Consecutive Failures"
                        value = $ConsecutiveFailures
                    },
                    @{
                        name = "Last Exit Code"
                        value = $ExitCode
                    },
                    @{
                        name = "Timestamp"
                        value = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    }
                )
            }
        )
    }
    
    try {
        $body = $message | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json" | Out-Null
        Write-Host "[$timestamp] Teams alert sent successfully" -ForegroundColor Yellow
    } catch {
        Write-Host "[$timestamp] Failed to send Teams alert: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

while ($true) {
    $round++
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $startTime = Get-Date
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "[$timestamp] Ralph Round $round - launching agency" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    # Write heartbeat BEFORE round (status: running)
    Update-Heartbeat -Round $round -Status "running" -ConsecutiveFailures $consecutiveFailures
    
    # Step 1: Update the repo to ensure we have the latest code
    Write-Host "[$timestamp] Pulling latest changes..." -ForegroundColor Yellow
    try {
        # Fetch latest changes
        git fetch 2>$null | Out-Null
        
        # Check if there are uncommitted changes
        $gitStatus = git status --porcelain
        if ($gitStatus) {
            Write-Host "[$timestamp] Local changes detected, stashing..." -ForegroundColor Yellow
            git stash save "ralph-watch-auto-stash-$timestamp" 2>$null | Out-Null
            $stashed = $true
        } else {
            $stashed = $false
        }
        
        # Pull latest changes
        $pullResult = git pull 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[$timestamp] Repository updated successfully" -ForegroundColor Green
        } else {
            Write-Host "[$timestamp] Warning: git pull failed: $pullResult" -ForegroundColor Yellow
        }
        
        # Restore stashed changes if any
        if ($stashed) {
            Write-Host "[$timestamp] Restoring local changes..." -ForegroundColor Yellow
            git stash pop 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[$timestamp] Warning: Could not restore stashed changes. Use 'git stash list' to recover." -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "[$timestamp] Warning: Failed to update repository: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "[$timestamp] Continuing with existing code..." -ForegroundColor Yellow
    }
    
    # Step 2: Run the agency copilot and capture exit code
    $exitCode = 0
    $roundStatus = "idle"
    try {
        agency copilot --yolo --autopilot --agent squad -p $prompt
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-Host "[$timestamp] Round $round completed successfully" -ForegroundColor Green
            $consecutiveFailures = 0
            $roundStatus = "idle"
            $logStatus = "SUCCESS"
        } else {
            Write-Host "[$timestamp] Round $round completed with exit code $exitCode" -ForegroundColor Yellow
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
    }
    
    # Calculate duration
    $endTime = Get-Date
    $durationSeconds = ($endTime - $startTime).TotalSeconds
    
    # Write structured log entry
    Write-RalphLog -Round $round -Timestamp $timestamp -ExitCode $exitCode -DurationSeconds $durationSeconds -ConsecutiveFailures $consecutiveFailures -Status $logStatus
    
    # Write heartbeat AFTER round (status: idle or error)
    Update-Heartbeat -Round $round -Status $roundStatus -ExitCode $exitCode -DurationSeconds $durationSeconds -ConsecutiveFailures $consecutiveFailures
    
    # Rotate log if needed
    Invoke-LogRotation
    
    # Send Teams alert if 3+ consecutive failures
    if ($consecutiveFailures -ge 3) {
        Write-Host "[$timestamp] Consecutive failures threshold reached ($consecutiveFailures), sending Teams alert..." -ForegroundColor Yellow
        Send-TeamsAlert -Round $round -ConsecutiveFailures $consecutiveFailures -ExitCode $exitCode
    }
    
    Write-Host "[$timestamp] Next round in $intervalMinutes minutes..." -ForegroundColor DarkGray
    Write-Host "[$timestamp] Duration: $([math]::Round($durationSeconds, 2))s | Exit: $exitCode | Failures: $consecutiveFailures" -ForegroundColor DarkGray
    Start-Sleep -Seconds ($intervalMinutes * 60)
}
