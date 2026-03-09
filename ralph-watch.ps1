# Ralph Watch v8 - Runs agency copilot with Squad agent every interval
# Launches a full Copilot session that can do actual work
# To stop: Ctrl+C
# 
# Observability Features:
# - Structured logging to $env:USERPROFILE\.squad\ralph-watch.log
# - Heartbeat file at $env:USERPROFILE\.squad\ralph-heartbeat.json
# - Teams alerts on consecutive failures (>3)
# - Exit code, duration, and round tracking
# - Lockfile prevents duplicate instances per directory

# Fix UTF-8 rendering in Windows PowerShell console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# --- Single-instance lockfile ---
$lockFile = Join-Path (Get-Location) ".ralph-watch.lock"
if (Test-Path $lockFile) {
    $lockContent = Get-Content $lockFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($lockContent -and $lockContent.pid) {
        $existing = Get-Process -Id $lockContent.pid -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "ERROR: Ralph watch is already running in this directory (PID $($lockContent.pid), started $($lockContent.started))" -ForegroundColor Red
            Write-Host "Kill it first: Stop-Process -Id $($lockContent.pid) -Force" -ForegroundColor Yellow
            exit 1
        }
    }
    # Stale lock — previous process died without cleanup
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

# Log rotation settings
$maxLogBytes = 1MB
$maxLogEntries = 500

$prompt = 'Ralph, Go! MAXIMIZE PARALLELISM: For every round, identify ALL actionable issues and spawn agents for ALL of them simultaneously as background tasks — do NOT work on issues one at a time. If there are 5 actionable issues, spawn 5 agents in one turn. PR comments, new issues, merges — do as much as possible in parallel per round. CRITICAL: Read .squad/skills/github-project-board/SKILL.md BEFORE starting — you MUST update the GitHub Project board status for every issue you touch (use gh project item-add and gh project item-edit commands from the skill). Move issues to Todo/In Progress/Done/Blocked/Pending User columns as appropriate. IMPORTANT: Only send a Teams message if there are important changes that require my attention — such as new issues needing my decision, PRs ready for review or merged, CI failures, completed work I should know about, or items requiring user action. Do NOT send a Teams message for routine board status checks with no actionable changes.'

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
        [string]$Status,
        [hashtable]$Metrics = @{}
    )
    
    $metricsStr = ""
    if ($Metrics.Count -gt 0) {
        $metricsParts = @()
        if ($Metrics.ContainsKey("issuesClosed")) { $metricsParts += "Issues=$($Metrics.issuesClosed)" }
        if ($Metrics.ContainsKey("prsMerged")) { $metricsParts += "PRs=$($Metrics.prsMerged)" }
        if ($Metrics.ContainsKey("agentActions")) { $metricsParts += "Actions=$($Metrics.agentActions)" }
        if ($metricsParts.Count -gt 0) {
            $metricsStr = " | " + ($metricsParts -join " | ")
        }
    }
    
    $logEntry = "$Timestamp | Round=$Round | ExitCode=$ExitCode | Duration=${DurationSeconds}s | Failures=$ConsecutiveFailures | Status=$Status$metricsStr"
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

# Function to update just the lastHeartbeat timestamp in heartbeat file
function Update-HeartbeatTimestamp {
    if (-not (Test-Path $heartbeatFile)) { return }
    
    try {
        $heartbeat = Get-Content -Path $heartbeatFile -Raw -Encoding utf8 | ConvertFrom-Json
        $heartbeat.lastHeartbeat = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        $heartbeat | ConvertTo-Json | Out-File -FilePath $heartbeatFile -Encoding utf8 -Force
    } catch {
        # Silently fail if file is locked or corrupted
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
        $heartbeat["metrics"] = [ordered]@{
            issuesClosed = if ($Metrics.ContainsKey("issuesClosed")) { $Metrics.issuesClosed } else { 0 }
            prsMerged = if ($Metrics.ContainsKey("prsMerged")) { $Metrics.prsMerged } else { 0 }
            agentActions = if ($Metrics.ContainsKey("agentActions")) { $Metrics.agentActions } else { 0 }
        }
    }
    
    $heartbeat | ConvertTo-Json | Out-File -FilePath $heartbeatFile -Encoding utf8 -Force
}

# Function to parse agency output for metrics
function Parse-AgencyMetrics {
    param(
        [string]$Output
    )
    
    $metrics = @{
        issuesClosed = 0
        prsMerged = 0
        agentActions = 0
    }
    
    if ([string]::IsNullOrWhiteSpace($Output)) {
        return $metrics
    }
    
    # Parse for closed issues - patterns like "closed issue #123", "close #45", "closing issue 67"
    $issueMatches = [regex]::Matches($Output, '(?i)(clos(e|ed|ing)|fix(ed)?|resolv(e|ed|ing))\s+(issue\s+)?#?\d+')
    $uniqueIssues = @{}
    foreach ($match in $issueMatches) {
        $issueNumber = [regex]::Match($match.Value, '\d+').Value
        if ($issueNumber) {
            $uniqueIssues[$issueNumber] = $true
        }
    }
    $metrics.issuesClosed = $uniqueIssues.Count
    
    # Parse for merged PRs - patterns like "merged PR #456", "merge pull request #78"
    $prMatches = [regex]::Matches($Output, '(?i)merg(e|ed|ing)\s+(pr|pull\s+request)\s+#?\d+')
    $uniquePRs = @{}
    foreach ($match in $prMatches) {
        $prNumber = [regex]::Match($match.Value, '\d+').Value
        if ($prNumber) {
            $uniquePRs[$prNumber] = $true
        }
    }
    $metrics.prsMerged = $uniquePRs.Count
    
    # Parse for agent actions - patterns like agent names followed by action verbs
    # Common agent names: squad, ralph, data, seven, picard, worf, etc.
    $agentActionMatches = [regex]::Matches($Output, '(?i)(squad|ralph|data|seven|picard|worf|troi|crusher|geordi|riker)\s+(created?|updated?|fixed?|merged?|closed?|opened?|added?|removed?|modified?)')
    $metrics.agentActions = $agentActionMatches.Count
    
    return $metrics
}

# Function to send Teams alert
function Send-TeamsAlert {
    param(
        [int]$Round,
        [int]$ConsecutiveFailures,
        [int]$ExitCode,
        [hashtable]$Metrics = @{}
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
    
    $facts = @(
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
    
    if ($Metrics.Count -gt 0) {
        if ($Metrics.ContainsKey("issuesClosed") -and $Metrics.issuesClosed -gt 0) {
            $facts += @{ name = "Issues Closed"; value = $Metrics.issuesClosed }
        }
        if ($Metrics.ContainsKey("prsMerged") -and $Metrics.prsMerged -gt 0) {
            $facts += @{ name = "PRs Merged"; value = $Metrics.prsMerged }
        }
        if ($Metrics.ContainsKey("agentActions") -and $Metrics.agentActions -gt 0) {
            $facts += @{ name = "Agent Actions"; value = $Metrics.agentActions }
        }
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
                facts = $facts
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
    $displayTime = Get-Date -Format "HH:mm:ss"
    $startTime = Get-Date
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "[$displayTime] Ralph Round $round started" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    # Write heartbeat BEFORE round (status: running)
    Update-Heartbeat -Round $round -Status "running" -ConsecutiveFailures $consecutiveFailures
    
    # Step 0: Run scheduled tasks (cache reviews, etc.)
    Write-Host "[$timestamp] Checking scheduled tasks..." -ForegroundColor Yellow
    $scheduledScriptPath = Join-Path (Get-Location) "scripts\scheduled-cache-review.ps1"
    if (Test-Path $scheduledScriptPath) {
        try {
            & $scheduledScriptPath
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[$timestamp] Scheduled tasks completed" -ForegroundColor Green
            }
        } catch {
            Write-Host "[$timestamp] Warning: Scheduled task failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Daily RP Briefing at 9:00 AM (workdays only)
    $currentHour = (Get-Date).Hour
    $currentMinute = (Get-Date).Minute
    $dayOfWeek = (Get-Date).DayOfWeek
    $briefingTime = ($currentHour -eq 9 -and $currentMinute -lt $intervalMinutes)
    $isWeekday = ($dayOfWeek -ne 'Saturday' -and $dayOfWeek -ne 'Sunday')
    
    if ($briefingTime -and $isWeekday) {
        Write-Host "[$timestamp] Running daily BasePlatformRP briefing..." -ForegroundColor Cyan
        $briefingScriptPath = Join-Path (Get-Location) "scripts/daily-rp-briefing.ps1"
        if (Test-Path $briefingScriptPath) {
            try {
                & $briefingScriptPath -SkipWeekends
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[$timestamp] Daily briefing sent successfully" -ForegroundColor Green
                } else {
                    Write-Host "[$timestamp] Warning: Daily briefing failed with exit code $LASTEXITCODE" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "[$timestamp] Warning: Daily briefing error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[$timestamp] Warning: Daily briefing script not found at $briefingScriptPath" -ForegroundColor Yellow
        }
    }
    
    # Daily ADR Channel Check at 10:00 AM Israel time (~07:00 UTC on weekdays)
    # Issue #198 — Read-only monitoring of IDP ADR Notifications channel
    $adrCheckHourUTC = 7  # 07:00 UTC ≈ 10:00 AM Israel
    $adrCheckTime = ($currentHour -eq $adrCheckHourUTC -and $currentMinute -lt $intervalMinutes)
    
    if ($adrCheckTime -and $isWeekday) {
        Write-Host "[$timestamp] Running daily ADR channel check (Issue #198)..." -ForegroundColor Cyan
        $adrCheckScript = Join-Path (Get-Location) ".squad\scripts\daily-adr-check.ps1"
        if (Test-Path $adrCheckScript) {
            try {
                & $adrCheckScript -SkipWeekends
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[$timestamp] ADR channel check completed" -ForegroundColor Green
                } else {
                    Write-Host "[$timestamp] Warning: ADR check exited with code $LASTEXITCODE" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "[$timestamp] Warning: ADR check error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[$timestamp] Warning: ADR check script not found at $adrCheckScript" -ForegroundColor Yellow
        }
    }
    
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
    
    # Step 2: Run the agency copilot and capture exit code + output
    $exitCode = 0
    $roundStatus = "idle"
    $agencyOutput = ""
    $metrics = @{
        issuesClosed = 0
        prsMerged = 0
        agentActions = 0
    }
    
    # Start background activity monitor — tails agency session log + prints elapsed time
    $roundStartTime = Get-Date
    $activityRunspace = [PowerShell]::Create()
    $activityRunspace.AddScript({
        param($RoundNum, $HeartbeatFile, $AgencyLogDir, $RoundStart)
        $lastLogSize = 0
        $seenLines = @{}
        while ($true) {
            Start-Sleep -Seconds 30
            $elapsed = (Get-Date) - $RoundStart
            $elapsedStr = "{0}m {1:00}s" -f [math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds
            $ts = Get-Date -Format "HH:mm:ss"
            
            # Find latest agency session log
            $latestSession = Get-ChildItem $AgencyLogDir -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $activity = ""
            if ($latestSession) {
                $logFiles = Get-ChildItem $latestSession.FullName -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($logFiles -and $logFiles.Length -gt $lastLogSize) {
                    $newContent = Get-Content $logFiles.FullName -Tail 20 -ErrorAction SilentlyContinue
                    foreach ($line in $newContent) {
                        if (-not $seenLines.ContainsKey($line) -and $line -match "(spawn|agent|merge|close|commit|push|label|comment|issue|PR|triage)") {
                            $short = $line.Trim()
                            if ($short.Length -gt 100) { $short = $short.Substring(0, 100) + "..." }
                            $activity = $short
                            $seenLines[$line] = $true
                        }
                    }
                    $lastLogSize = $logFiles.Length
                }
            }
            
            # Print status line
            if ($activity) {
                [Console]::ForegroundColor = 'DarkCyan'
                [Console]::WriteLine("  [$ts] Round $RoundNum ($elapsedStr) | $activity")
                [Console]::ResetColor()
            } else {
                [Console]::ForegroundColor = 'DarkGray'
                [Console]::WriteLine("  [$ts] Round $RoundNum running... ($elapsedStr elapsed)")
                [Console]::ResetColor()
            }
            
            # Update heartbeat
            if (Test-Path $HeartbeatFile) {
                try {
                    $hb = Get-Content -Path $HeartbeatFile -Raw -Encoding utf8 | ConvertFrom-Json
                    $hb | Add-Member -NotePropertyName "lastHeartbeat" -NotePropertyValue (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') -Force
                    $hb | ConvertTo-Json | Out-File -FilePath $HeartbeatFile -Encoding utf8 -Force
                } catch {}
            }
        }
    }).AddArgument($round).AddArgument($heartbeatFile).AddArgument("$env:USERPROFILE\.agency\logs").AddArgument($roundStartTime) | Out-Null
    $activityHandle = $activityRunspace.BeginInvoke()
    
    try {
        # Call agency DIRECTLY — no pipes, no Start-Process, no cmd /c
        # This is the only approach that reliably returns control
        agency copilot --yolo --autopilot --agent squad -p $prompt
        $exitCode = $LASTEXITCODE
        $agencyOutput = ""  # Can't capture without pipes — but that's OK
        # Display output after completion
        # No file cleanup needed — output streamed to console directly
        
        if ($exitCode -eq 0) {
            $consecutiveFailures = 0
            $roundStatus = "idle"
            $logStatus = "SUCCESS"
        } else {
            $consecutiveFailures++
            $roundStatus = "error"
            $logStatus = "FAILED"
        }
        
        # Parse metrics from output
        $metrics = Parse-AgencyMetrics -Output $agencyOutput
        
    } catch {
        Write-Host "[$timestamp] Error: $($_.Exception.Message)" -ForegroundColor Red
        $exitCode = 1
        $consecutiveFailures++
        $roundStatus = "error"
        $logStatus = "ERROR"
    } finally {
        # Stop activity monitor runspace
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
    
    # Write structured log entry with metrics
    Write-RalphLog -Round $round -Timestamp $timestamp -ExitCode $exitCode -DurationSeconds $durationSeconds -ConsecutiveFailures $consecutiveFailures -Status $logStatus -Metrics $metrics
    
    # Write heartbeat AFTER round (status: idle or error) with metrics
    Update-Heartbeat -Round $round -Status $roundStatus -ExitCode $exitCode -DurationSeconds $durationSeconds -ConsecutiveFailures $consecutiveFailures -Metrics $metrics
    
    # Rotate log if needed
    Invoke-LogRotation
    
    # Send Teams alert if 3+ consecutive failures
    if ($consecutiveFailures -ge 3) {
        Write-Host "[$timestamp] Consecutive failures threshold reached ($consecutiveFailures), sending Teams alert..." -ForegroundColor Yellow
        Send-TeamsAlert -Round $round -ConsecutiveFailures $consecutiveFailures -ExitCode $exitCode -Metrics $metrics
    }
    
    # Calculate next round time
    $nextRoundTime = (Get-Date).AddSeconds($intervalMinutes * 60)
    $nextRoundDisplayTime = $nextRoundTime.ToString("HH:mm:ss")
    Write-Host "[$endDisplayTime] Next round at $nextRoundDisplayTime (in $intervalMinutes minutes)" -ForegroundColor DarkGray
    
    if ($metrics.issuesClosed -gt 0 -or $metrics.prsMerged -gt 0 -or $metrics.agentActions -gt 0) {
        Write-Host "[$endDisplayTime] Metrics: Issues closed: $($metrics.issuesClosed), PRs merged: $($metrics.prsMerged), Agent actions: $($metrics.agentActions)" -ForegroundColor DarkGray
    }
    Start-Sleep -Seconds ($intervalMinutes * 60)
}
