# Ralph Watch v8 - Runs agency copilot with Squad agent every interval
# Launches a full Copilot session that can do actual work
# To stop: Ctrl+C
# 
# Observability Features (v8 — aligned with squad-monitor v2):
# - Structured logging to $env:USERPROFILE\.squad\ralph-watch.log
# - Heartbeat file at $env:USERPROFILE\.squad\ralph-heartbeat.json
# - Teams alerts on consecutive failures (>3)
# - Exit code, duration, and round tracking
# - Lockfile prevents duplicate instances per directory
#   → Written BEFORE round (status=running) and AFTER (status=idle/error)
#   → Includes pid, status, round, lastRun, exitCode, consecutiveFailures
# - Log rotation: capped at 500 entries / 1MB

# Fix UTF-8 rendering in Windows PowerShell console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Set window title so you know this is Ralph
$Host.UI.RawUI.WindowTitle = "🔄 Ralph Watch — tamresearch1"

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

$prompt = @'
Ralph, Go! MAXIMIZE PARALLELISM: For every round, identify ALL actionable issues and spawn agents for ALL of them simultaneously as background tasks — do NOT work on issues one at a time. If there are 5 actionable issues, spawn 5 agents in one turn. PR comments, new issues, merges — do as much as possible in parallel per round.

CRITICAL: Read .squad/skills/github-project-board/SKILL.md BEFORE starting — you MUST update the GitHub Project board status for every issue you touch (use gh project item-add and gh project item-edit commands from the skill). BOARD WORKFLOW: BEFORE spawning an agent for an issue, FIRST move that issue to "In Progress" (option 238ff87a) on the board. When the agent completes and PR is merged, move to "Done" (4830e3e3). When blocked, move to "Blocked" (c6316ca6). The board must reflect what is CURRENTLY being worked on in real-time.

TEAMS & EMAIL MONITORING (do this EVERY round):
1. Use the workiq-ask_work_iq tool to check: "What Teams messages in the last 30 minutes mention Tamir, squad, DK8S, reviews, action items, or urgent requests?"
2. Use workiq-ask_work_iq to check: "Any emails sent to Tamir in the last hour that need a response or contain action items?"
3. For each actionable item found: decide if Tamir needs to act. If yes — create a GitHub issue with label "teams-bridge" and a short summary, OR comment on an existing related issue. If it is just informational — skip it silently.
4. Do NOT create duplicate issues for things already tracked. Check existing open issues first.
5. Do NOT spam — only surface items that genuinely need Tamir's attention.

DONE ITEMS ARCHIVING: Check the project board for items in "Done" status that have been done for more than 3 days. Close the GitHub issue if still open and add a comment summarizing what was accomplished.

NEWS REPORTER (Neelix): When you find important updates worth reporting (PRs merged, issues completed, Teams messages needing attention, blockers resolved), send a styled Teams message via the webhook at $env:USERPROFILE\.squad\teams-webhook.url. Format it like a news broadcast — use emoji, bold headers, and make it scannable. Read .squad/agents/neelix/charter.md for the style guide. Only send when there is genuinely newsworthy activity — not every round.

IMPORTANT: Only send a Teams message if there are important changes that require my attention — such as new issues needing my decision, PRs ready for review or merged, CI failures, completed work I should know about, or items requiring user action. Do NOT send a Teams message for routine board status checks with no actionable changes.
'@

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
    
    # Step 0: Run scheduled tasks via Squad Scheduler
    # The scheduler reads .squad/schedule.json and evaluates all triggers
    Write-Host "[$timestamp] Evaluating Squad schedule..." -ForegroundColor Yellow
    $schedulerPath = Join-Path (Get-Location) ".squad\scripts\Invoke-SquadScheduler.ps1"
    if (Test-Path $schedulerPath) {
        try {
            # Run scheduler for local-polling provider
            $scheduleResult = & $schedulerPath -ScheduleFile ".\.squad\schedule.json" -StateFile ".\.squad\monitoring\schedule-state.json" -Provider "local-polling"
            
            if ($scheduleResult.tasksFired -gt 0) {
                Write-Host "[$timestamp] Squad scheduler fired $($scheduleResult.tasksFired) task(s)" -ForegroundColor Green
            }
        } catch {
            Write-Host "[$timestamp] Warning: Squad scheduler error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[$timestamp] Warning: Squad scheduler not found at $schedulerPath" -ForegroundColor Yellow
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
    
    # Step 1.5: Teams message monitoring (every 3rd round, weekdays only)
    if (($round % 3) -eq 1) {
        $dow = (Get-Date).DayOfWeek
        if ($dow -ne 'Saturday' -and $dow -ne 'Sunday') {
            $teamsMonitorScript = Join-Path (Get-Location) ".squad\scripts\teams-monitor-check.ps1"
            if (Test-Path $teamsMonitorScript) {
                Write-Host "[$timestamp] Running Teams message monitor..." -ForegroundColor Yellow
                try {
                    & $teamsMonitorScript -LookbackMinutes 30
                    Write-Host "[$timestamp] Teams monitor check completed" -ForegroundColor Green
                } catch {
                    Write-Host "[$timestamp] Warning: Teams monitor failed: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
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
        # PS 5.1 converts native stderr to NativeCommandError exceptions.
        # Agency writes emoji banners to stderr, causing false failures.
        # Fix: suppress stderr-to-error conversion with ErrorAction SilentlyContinue
        # and call agency without pipes so $LASTEXITCODE is preserved.
        $ErrorActionPreference_saved = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        agency copilot --yolo --autopilot --agent squad -p $prompt
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $ErrorActionPreference_saved
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
