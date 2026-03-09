# Ralph Watch v8 - Autonomous Squad Agent Monitor
# Launches a full Copilot session that can do actual work
# To stop: Ctrl+C
# 
# Observability Features (v8):
# - Structured logging to $env:USERPROFILE\.squad\ralph-watch.log
# - Heartbeat file at $env:USERPROFILE\.squad\ralph-heartbeat.json
# - Teams alerts on consecutive failures (>3)
# - Exit code, duration, and round tracking
# - Lockfile prevents duplicate instances per directory
# - Log rotation: capped at 500 entries / 1MB

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

$prompt = @'
Ralph, Go! MAXIMIZE PARALLELISM: For every round, identify ALL actionable issues and spawn agents for ALL of them simultaneously as background tasks — do NOT work on issues one at a time. If there are 5 actionable issues, spawn 5 agents in one turn. PR comments, new issues, merges — do as much as possible in parallel per round.

CRITICAL: Read .squad/skills/github-project-board/SKILL.md BEFORE starting — you MUST update the GitHub Project board status for every issue you touch (use gh project item-add and gh project item-edit commands from the skill). BOARD WORKFLOW: BEFORE spawning an agent for an issue, FIRST move that issue to "In Progress" on the board. When the agent completes and PR is merged, move to "Done". When blocked, move to "Blocked". The board must reflect what is CURRENTLY being worked on in real-time.

TEAMS & EMAIL MONITORING (do this EVERY round):
1. Use the workiq-ask_work_iq tool to check: "What Teams messages in the last 30 minutes mention {project-owner}, squad, urgent requests?"
2. Use workiq-ask_work_iq to check: "Any emails sent to {project-owner} in the last hour that need a response or contain action items?"
3. For each actionable item found: decide if action is needed. If yes — create a GitHub issue with label "teams-bridge" and a short summary, OR comment on an existing related issue.
4. Do NOT create duplicate issues for things already tracked. Check existing open issues first.
5. Do NOT spam — only surface items that genuinely need attention.

DONE ITEMS ARCHIVING: Check the project board for items in "Done" status that have been done for more than 3 days. Close the GitHub issue if still open and add a comment summarizing what was accomplished.

NEWS REPORTER: When you find important updates worth reporting (PRs merged, issues completed, Teams messages needing attention, blockers resolved), send a styled Teams message via the webhook at $env:USERPROFILE\.squad\teams-webhook.url. Format it like a news broadcast — use emoji, bold headers, and make it scannable. Only send when there is genuinely newsworthy activity — not every round.

IMPORTANT: Only send a Teams message if there are important changes that require attention — such as new issues needing decision, PRs ready for review or merged, CI failures, completed work, or items requiring user action. Do NOT send a Teams message for routine board status checks with no actionable changes.
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
        foreach ($key in $Metrics.Keys) {
            $metricsParts += "$key=$($Metrics[$key])"
        }
        $metricsStr = " " + ($metricsParts -join " ")
    }
    
    $logEntry = "[$Timestamp] round=$Round status=$Status exitCode=$ExitCode duration=$([math]::Round($DurationSeconds, 1))s consecutiveFailures=$ConsecutiveFailures$metricsStr"
    Add-Content -Path $logFile -Value $logEntry -Encoding utf8
    
    # Rotate log if needed
    if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt $maxLogBytes)) {
        $entries = Get-Content $logFile | Select-Object -Last $maxLogEntries
        $entries | Out-File $logFile -Encoding utf8 -Force
    }
}

# Function to update heartbeat file
function Update-Heartbeat {
    param(
        [string]$Status,
        [int]$Round,
        [int]$ConsecutiveFailures
    )
    
    $heartbeat = [ordered]@{
        lastRun = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        status = $Status
        round = $Round
        consecutiveFailures = $ConsecutiveFailures
        pid = $PID
    }
    
    $heartbeat | ConvertTo-Json | Out-File $heartbeatFile -Encoding utf8 -Force
}

# Function to send Teams alert
function Send-TeamsAlert {
    param([string]$Message)
    
    if (Test-Path $teamsWebhookFile) {
        $webhookUrl = Get-Content $teamsWebhookFile -Raw | ForEach-Object { $_.Trim() }
        if ($webhookUrl) {
            $body = @{ text = $Message } | ConvertTo-Json
            try {
                Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null
            } catch {
                Write-Host "Failed to send Teams alert: $_" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host "🤖 Ralph Watch v8 Starting..." -ForegroundColor Cyan
Write-Host "   Interval: $intervalMinutes minutes" -ForegroundColor Gray
Write-Host "   Log: $logFile" -ForegroundColor Gray
Write-Host "   Heartbeat: $heartbeatFile" -ForegroundColor Gray
Write-Host "   Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

while ($true) {
    $round++
    $startTime = Get-Date
    $timestamp = $startTime.ToString('yyyy-MM-ddTHH:mm:ss')
    
    Write-Host "[$timestamp] 🔄 Round $round starting..." -ForegroundColor Green
    
    try {
        # Run GitHub Copilot CLI with Ralph's prompt
        $result = gh copilot $prompt
        $exitCode = $LASTEXITCODE
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        if ($exitCode -eq 0) {
            $consecutiveFailures = 0
            $status = "OK"
            Write-RalphLog -Round $round -Timestamp $timestamp -ExitCode $exitCode -DurationSeconds $duration -ConsecutiveFailures $consecutiveFailures -Status $status
            Update-Heartbeat -Status "healthy" -Round $round -ConsecutiveFailures $consecutiveFailures
            Write-Host "[$($endTime.ToString('yyyy-MM-ddTHH:mm:ss'))] ✅ Round $round complete ($([math]::Round($duration, 1))s)" -ForegroundColor Green
        } else {
            $consecutiveFailures++
            $status = "FAIL"
            Write-RalphLog -Round $round -Timestamp $timestamp -ExitCode $exitCode -DurationSeconds $duration -ConsecutiveFailures $consecutiveFailures -Status $status
            Update-Heartbeat -Status "unhealthy" -Round $round -ConsecutiveFailures $consecutiveFailures
            Write-Host "[$($endTime.ToString('yyyy-MM-ddTHH:mm:ss'))] ❌ Round $round failed with exit code $exitCode ($([math]::Round($duration, 1))s)" -ForegroundColor Red
            
            if ($consecutiveFailures -ge 3) {
                $alertMsg = "🚨 Ralph Watch Alert: $consecutiveFailures consecutive failures (round $round, exit code $exitCode)"
                Send-TeamsAlert -Message $alertMsg
                Write-Host "   Sent Teams alert for consecutive failures" -ForegroundColor Yellow
            }
        }
    } catch {
        $consecutiveFailures++
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        Write-RalphLog -Round $round -Timestamp $timestamp -ExitCode -1 -DurationSeconds $duration -ConsecutiveFailures $consecutiveFailures -Status "ERROR"
        Update-Heartbeat -Status "error" -Round $round -ConsecutiveFailures $consecutiveFailures
        Write-Host "[$($endTime.ToString('yyyy-MM-ddTHH:mm:ss'))] ⚠️  Round $round exception: $_" -ForegroundColor Red
        
        if ($consecutiveFailures -ge 3) {
            $alertMsg = "🚨 Ralph Watch Alert: $consecutiveFailures consecutive failures (round $round, exception: $_)"
            Send-TeamsAlert -Message $alertMsg
        }
    }
    
    Write-Host "   Next round in $intervalMinutes minutes..." -ForegroundColor Gray
    Write-Host ""
    Start-Sleep -Seconds ($intervalMinutes * 60)
}
