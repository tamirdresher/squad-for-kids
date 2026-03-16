# Ralph Watch v9 - Autonomous Squad Agent Monitor
# Launches a full Copilot session that can do actual work
# To stop: Ctrl+C
# IMPORTANT: Must be launched with pwsh (PowerShell 7+), NOT powershell.exe (5.1)
#   PS 5.1 mangles multi-line strings passed to native executables, breaking prompts.
# 
# Observability Features (v9):
# - Structured logging to $env:USERPROFILE\.squad\ralph-watch.log
# - Per-machine heartbeat: $env:USERPROFILE\.squad\ralph-heartbeat-{COMPUTERNAME}.json
# - Teams alerts on consecutive failures (>3)
# - Exit code, duration, and round tracking
# - System-wide mutex prevents duplicate instances per repo
# - Lockfile for external tools (monitor dashboard) to read status
# - Log rotation: capped at 500 entries / 1MB
# - Machine-specific branch naming for multi-machine coordination

# Require PowerShell 7+ — PS 5.1 breaks multi-line native command arguments
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "ERROR: Ralph Watch requires PowerShell 7+ (pwsh). Current: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    Write-Host "Launch with: pwsh -NoProfile -ExecutionPolicy Bypass -File ralph-watch.ps1" -ForegroundColor Yellow
    exit 1
}

# Fix UTF-8 rendering in Windows PowerShell console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Set window/tab title for easy identification in multi-Ralph setups
$repoName = Split-Path (Get-Location) -Leaf
$ralphTitle = "Ralph Watch - $repoName"
$Host.UI.RawUI.WindowTitle = $ralphTitle
[Console]::Title = $ralphTitle
Write-Host "`e]0;$ralphTitle`a" -NoNewline  # OSC escape for Windows Terminal tabs

# --- Single-instance guard (system-wide mutex + lockfile) ---

# 1. System-wide named mutex — prevents ANY duplicate for this repo across the machine
$mutexName = "Global\RalphWatch_$repoName"
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
$acquired = $false
try { $acquired = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $acquired = $true }
if (-not $acquired) {
    Write-Host "ERROR: Another Ralph instance is already running for this repo (mutex: $mutexName)" -ForegroundColor Red
    Write-Host "Use Get-CimInstance Win32_Process | Where-Object { `$_.CommandLine -match 'ralph-watch' } to find it" -ForegroundColor Yellow
    exit 1
}

# 2. Lockfile (for external tools like the squad-monitor dashboard to read)
$lockFile = Join-Path (Get-Location) ".ralph-watch.lock"
if (Test-Path $lockFile) {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}
[ordered]@{ pid = $PID; started = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'); directory = (Get-Location).Path; machine = $env:COMPUTERNAME } | ConvertTo-Json | Out-File $lockFile -Encoding utf8 -Force

# Clean up on exit
Register-EngineEvent PowerShell.Exiting -Action {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
} | Out-Null
trap {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    if ($mutex) { try { $mutex.ReleaseMutex() } catch {} ; $mutex.Dispose() }
    break
}

$intervalMinutes = 5
$round = 0
$consecutiveFailures = 0
$maxLogEntries = 500
$maxLogBytes = 1048576  # 1MB

# Multi-machine coordination settings
$machineId = $env:COMPUTERNAME

$prompt = @'
Ralph, Go! MAXIMIZE PARALLELISM: For every round, identify ALL actionable issues and spawn agents for ALL of them simultaneously as background tasks — do NOT work on issues one at a time. If there are 5 actionable issues, spawn 5 agents in one turn. PR comments, new issues, merges — do as much as possible in parallel per round.

MULTI-MACHINE COORDINATION: Before spawning an agent for ANY issue, check if it's already assigned:
1. Use `gh issue view <number> --json assignees` to check if issue is assigned
2. If assigned to someone else — SKIP IT, another Ralph instance is working on it
3. If NOT assigned — claim it: `gh issue edit <number> --add-assignee "@me"`
4. Use branch naming: `squad/{issue}-{slug}-$env:COMPUTERNAME` for machine-specific branches
5. This prevents duplicate work across multiple Ralph instances on different machines

CROSS-MACHINE TASKS: Each round, also run `pwsh scripts/cross-machine-watcher.ps1 -GitSync` to process any pending tasks in the cross-machine task queue (.squad/cross-machine/tasks/).

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
# Per-machine heartbeat: each machine writes its own heartbeat file
$heartbeatFile = Join-Path $squadDir "ralph-heartbeat-$machineId.json"
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
        machine = $machineId
        repo = $repoName
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

Write-Host "🤖 Ralph Watch v9 Starting..." -ForegroundColor Cyan
Write-Host "   Machine: $machineId" -ForegroundColor Gray
Write-Host "   Repo: $repoName" -ForegroundColor Gray
Write-Host "   Mutex: $mutexName" -ForegroundColor Gray
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
