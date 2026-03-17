# Ralph Watch v8 - Runs agency copilot with Squad agent every interval
# Launches a full Copilot session that can do actual work
# To stop: Ctrl+C
# IMPORTANT: Must be launched with pwsh (PowerShell 7+), NOT powershell.exe (5.1)
#   PS 5.1 mangles multi-line strings passed to native executables, breaking agency prompts.
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

# Set window/tab title (works in Windows Terminal, cmd, and pwsh)
$ralphTitle = "Ralph Watch - tamresearch1"
$Host.UI.RawUI.WindowTitle = $ralphTitle
[Console]::Title = $ralphTitle
Write-Host "`e]0;$ralphTitle`a" -NoNewline  # OSC escape sequence for Windows Terminal tabs

# --- Single-instance guard (mutex + lockfile + process scan) ---

# 1. System-wide named mutex — prevents ANY duplicate across the machine
$mutexName = "Global\RalphWatch_tamresearch1"
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
$acquired = $false
try { $acquired = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $acquired = $true }
if (-not $acquired) {
    Write-Host "ERROR: Another Ralph instance is already running on this machine (mutex: $mutexName)" -ForegroundColor Red
    Write-Host "Use Get-CimInstance Win32_Process | Where-Object { `$_.CommandLine -match 'ralph-watch' } to find it" -ForegroundColor Yellow
    exit 1
}

# 2. Process scan — kill any stale ralph-watch processes for THIS repo only (not us, not other repos)
$thisRepoDir = (Get-Location).Path.Replace('\', '\\')
$staleRalphs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'ralph-watch' -and $_.CommandLine -match [regex]::Escape($thisRepoDir) -and $_.ProcessId -ne $PID }
foreach ($stale in $staleRalphs) {
    Write-Host "WARNING: Killing stale Ralph instance PID $($stale.ProcessId) for this repo" -ForegroundColor Yellow
    Stop-Process -Id $stale.ProcessId -Force -ErrorAction SilentlyContinue
}

# 3. Lockfile (for external tools like the monitor to read)
$lockFile = Join-Path (Get-Location) ".ralph-watch.lock"
if (Test-Path $lockFile) {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}
[ordered]@{ pid = $PID; started = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'); directory = (Get-Location).Path } | ConvertTo-Json | Out-File $lockFile -Encoding utf8 -Force

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
$roundTimeoutMinutes = 20  # Kill round if it exceeds this (prevents hangs)
$round = 0
$consecutiveFailures = 0
$maxLogEntries = 500
$maxLogBytes = 1048576  # 1MB

# Log rotation settings
$maxLogBytes = 1MB
$maxLogEntries = 500

# Multi-machine coordination settings (Issue #346)
$machineId = $env:COMPUTERNAME
$heartbeatIntervalSeconds = 120  # 2 minutes
$staleThresholdMinutes = 15
$lastHeartbeatTime = Get-Date

$prompt = @'
Ralph, Go! MAXIMIZE PARALLELISM: For every round, identify ALL actionable issues and spawn agents for ALL of them simultaneously as background tasks — do NOT work on issues one at a time. If there are 5 actionable issues, spawn 5 agents in one turn. PR comments, new issues, merges — do as much as possible in parallel per round.

MULTI-MACHINE COORDINATION (Issue #346): Before spawning an agent for ANY issue, check if it's already assigned:
1. Use `gh issue view <number> --json assignees` to check if issue is assigned
2. If assigned to someone else — SKIP IT, another Ralph instance is working on it
3. If NOT assigned — claim it: `gh issue edit <number> --add-assignee "@me"` and add comment: "🔄 Claimed by **$env:COMPUTERNAME** at {timestamp}"
4. Use branch naming: `squad/{issue}-{slug}-$env:COMPUTERNAME` for machine-specific branches
5. This prevents duplicate work across multiple Ralph instances on different machines

MULTI-REPO WATCH: In addition to tamresearch1, also scan tamirdresher/squad-monitor for actionable issues. Use "gh issue list --repo tamirdresher/squad-monitor --search 'is:open'" to discover them. Apply the same triage rules: if actionable (not blocked, not waiting, clearly defined), spawn agents to work on it. You may need to clone squad-monitor in a temp directory to run certain operations, or use 'gh' remote repo commands directly. The goal is to get all three squad-monitor issues (#1 token usage, #2 NuGet publish, #3 multi-session) assigned and in progress.

CRITICAL: Read .squad/skills/github-project-board/SKILL.md BEFORE starting — you MUST update the GitHub Project board status for every issue you touch (use gh project item-add and gh project item-edit commands from the skill). BOARD WORKFLOW: BEFORE spawning an agent for an issue, FIRST move that issue to "In Progress" (option 238ff87a) on the board. When the agent completes and PR is merged, move to "Done" (4830e3e3). When blocked, move to "Blocked" (c6316ca6). The board must reflect what is CURRENTLY being worked on in real-time. Note: squad-monitor may not have a project board; in that case, just use issue labels for tracking ("in-progress", "done", "blocked").

TEAMS & EMAIL MONITORING (do this EVERY round):
1. Use the workiq-ask_work_iq tool to check: "What Teams messages in the last 30 minutes mention Tamir, squad, DK8S, reviews, action items, or urgent requests?"
2. Use workiq-ask_work_iq to check: "Any emails sent to Tamir in the last hour that need a response or contain action items?"
3. For each actionable item found: decide if Tamir needs to act. If yes — create a GitHub issue with label "teams-bridge" and a short summary, OR comment on an existing related issue. If it is just informational — skip it silently.
4. Do NOT create duplicate issues for things already tracked. Check existing open issues first.
5. Do NOT spam — only surface items that genuinely need Tamir's attention.

GITHUB ERROR EMAIL MONITORING (do this EVERY round):
1. Use workiq-ask_work_iq to check: "Any emails to Tamir in the last hour from GitHub about: workflow failures, Dependabot alerts, security vulnerabilities, code scanning alerts, secret scanning, deployment failures, or branch protection violations?"
2. For each GitHub alert email found:
   a. Determine the alert type: ci-failure, dependency-vuln, security-alert, deploy-failure, or branch-protection
   b. Check if a GitHub issue with labels 'squad,github-alert,{type}' already exists (use gh issue list --label)
   c. If NO existing issue: create one with title '[Alert Type] YYYY-MM-DD — Detected by Ralph Email Monitor' and labels 'squad,github-alert,{type}'
   d. If existing issue: add a comment with the new alert details
3. For ci-failure alerts: attempt auto-remediation by re-running the failed workflow (gh run rerun)
4. For security-alert or dependency-vuln: these need human review — mention in Teams notification that human decision is needed
5. Log all findings to the console with prefix [email-monitor]
6. Do NOT create duplicate issues — always check for existing ones first

DONE ITEMS ARCHIVING: Check the project board for items in "Done" status that have been done for more than 3 days. Close the GitHub issue if still open and add a comment summarizing what was accomplished.

BOARD RECONCILIATION (every round): After triaging issues, do a quick board health check. List all project items with `gh project item-list 1 --owner tamirdresher_microsoft --format json` and for any item where the issue is CLOSED but the board column is NOT "Done", move it to Done (4830e3e3). For any item where the issue is OPEN but the board column is "Done", move it to Todo (0de780a1). Log how many mismatches you fixed. This prevents board drift.

NEWS REPORTER (Neelix): When you find important updates worth reporting (PRs merged, issues completed, Teams messages needing attention, blockers resolved), send a styled Teams message via the webhook at $env:USERPROFILE\.squad\teams-webhook.url. Format it like a news broadcast — use emoji, bold headers, and make it scannable. Read .squad/agents/neelix/charter.md for the style guide. Only send when there is genuinely newsworthy activity — not every round.

CHANNEL ROUTING: We have dedicated Teams channels under the "squads" team (see .squad/teams-channels.json for the full map). When composing a notification, prefix the message category so it can be routed to the right channel:
  - "CHANNEL: wins" — for closed issues, merged PRs, milestones, birthdays
  - "CHANNEL: pr-code" — for PRs opened, reviews needed, CI failures
  - "CHANNEL: ralph-alerts" — for Ralph errors, stalls, restarts
  - "CHANNEL: tech-news" — for daily tech briefings and industry news
  - "CHANNEL: research" — for research outputs and paper summaries
  - "CHANNEL: general" — catch-all / fallback
The webhook currently always goes to the general channel. When running as an agent with Teams MCP tools, post directly to the correct channel using the channelId from .squad/teams-channels.json and teamId 5f93abfe-b968-44ea-bd0a-6f155046ccc7.

PODCASTER: After any agent completes a significant deliverable (research report, blog draft, design doc, architecture proposal, or any document >500 words), run the podcaster to generate an audio version. Use: pwsh scripts/podcaster.ps1 -InputFile <path-to-deliverable>. The audio file will be saved next to the source file with -audio.wav suffix. Mention the audio file in the Teams notification so Tamir knows it's available to listen to. Read .squad/agents/podcaster/charter.md for details.

TECH NEWS SCANNING (once per day, morning round only): On the first round after 7:00 AM local time, run: node scripts/tech-news-scanner.js. It scans HackerNews and Reddit for AI, .NET, Kubernetes, and developer tools news. If it finds relevant stories, create a GitHub issue titled "Tech News Digest: {date}" with label "squad,squad:seven" summarizing the top stories. Include links. Neelix should then send a Teams notification with the highlights (use CHANNEL: tech-news for routing).

IMPORTANT: Only send a Teams message if there are important changes that require my attention — such as new issues needing my decision, PRs ready for review or merged, CI failures, completed work I should know about, or items requiring user action. Do NOT send a Teams message for routine board status checks with no actionable changes.
'@

# Initialize observability paths (per-repo to avoid collisions when running multiple ralphs)
$squadDir = Join-Path $env:USERPROFILE ".squad"
$repoName = Split-Path (Get-Location).Path -Leaf
$logFile = Join-Path $squadDir "ralph-watch-$repoName.log"
$heartbeatFile = Join-Path $squadDir "ralph-heartbeat-$repoName.json"
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

# Function to check if issue is already assigned (multi-machine coordination)
function Test-IssueAlreadyAssigned {
    param(
        [string]$IssueNumber
    )
    
    try {
        $issueData = gh issue view $IssueNumber --json assignees 2>$null | ConvertFrom-Json
        if ($issueData.assignees -and $issueData.assignees.Count -gt 0) {
            return $true
        }
    } catch {
        # If we can't check, assume not assigned to avoid blocking
        return $false
    }
    
    return $false
}

# Function to claim issue for this machine
function Invoke-IssueClaim {
    param(
        [string]$IssueNumber,
        [string]$MachineId
    )
    
    try {
        # Assign to self
        gh issue edit $IssueNumber --add-assignee "@me" 2>$null | Out-Null
        
        # Add claim comment
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $claimMessage = "🔄 Claimed by **$MachineId** at $timestamp"
        gh issue comment $IssueNumber --body $claimMessage 2>$null | Out-Null
        
        return $true
    } catch {
        Write-Host "Warning: Failed to claim issue #$IssueNumber - $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Function to update heartbeat for claimed issues
function Update-IssueHeartbeat {
    param(
        [string]$IssueNumber,
        [string]$MachineId
    )
    
    try {
        # Check if issue has our machine's active label
        $labelName = "ralph:${MachineId}:active"
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Add or update label (gh will update if exists)
        gh issue edit $IssueNumber --add-label $labelName 2>$null | Out-Null
        
        # Add heartbeat comment
        $heartbeatMessage = "💓 Heartbeat from **$MachineId** at $timestamp"
        gh issue comment $IssueNumber --body $heartbeatMessage 2>$null | Out-Null
        
        return $true
    } catch {
        Write-Host "Warning: Failed to update heartbeat for issue #$IssueNumber - $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Function to check for stale work from other machines
function Get-StaleIssues {
    param(
        [string]$MachineId,
        [int]$StaleThresholdMinutes
    )
    
    $staleIssues = @()
    
    try {
        # Get all open issues with ralph:*:active labels
        $issues = gh issue list --json number,labels,comments --limit 100 2>$null | ConvertFrom-Json
        
        foreach ($issue in $issues) {
            # Find ralph:*:active labels from other machines
            $ralphLabels = $issue.labels | Where-Object { $_.name -match '^ralph:(.+):active$' -and $Matches[1] -ne $MachineId }
            
            if ($ralphLabels) {
                # Check last comment timestamp for heartbeat
                $lastHeartbeat = $null
                foreach ($comment in ($issue.comments | Sort-Object -Property createdAt -Descending)) {
                    if ($comment.body -match '💓 Heartbeat from \*\*(.+)\*\* at (.+)') {
                        $lastHeartbeat = [datetime]::Parse($Matches[2])
                        break
                    }
                }
                
                if ($lastHeartbeat) {
                    $ageMinutes = ((Get-Date) - $lastHeartbeat).TotalMinutes
                    if ($ageMinutes -gt $StaleThresholdMinutes) {
                        $staleIssues += @{
                            number = $issue.number
                            staleMachine = $Matches[1]
                            ageMinutes = [math]::Round($ageMinutes, 1)
                        }
                    }
                }
            }
        }
    } catch {
        Write-Host "Warning: Failed to check for stale issues - $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    return $staleIssues
}

# Function to reclaim stale work
function Invoke-StaleWorkReclaim {
    param(
        [string]$IssueNumber,
        [string]$StaleMachine,
        [string]$MachineId,
        [double]$AgeMinutes
    )
    
    try {
        # Remove old machine's label
        $oldLabel = "ralph:${StaleMachine}:active"
        gh issue edit $IssueNumber --remove-label $oldLabel 2>$null | Out-Null
        
        # Claim for this machine
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $reclaimMessage = "⚠️ Reclaimed by **$MachineId** at $timestamp (previous owner **$StaleMachine** was stale for $([math]::Round($AgeMinutes, 1)) minutes)"
        gh issue comment $IssueNumber --body $reclaimMessage 2>$null | Out-Null
        
        # Assign to self
        gh issue edit $IssueNumber --add-assignee "@me" 2>$null | Out-Null
        
        # Add our label
        $newLabel = "ralph:${MachineId}:active"
        gh issue edit $IssueNumber --add-label $newLabel 2>$null | Out-Null
        
        return $true
    } catch {
        Write-Host "Warning: Failed to reclaim stale issue #$IssueNumber - $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# -------------------------------------------------------------------
# Channel Routing Strategy for Teams Notifications
# -------------------------------------------------------------------
# WEBHOOK (current):
#   The incoming webhook URL (stored in $USERPROFILE\.squad\teams-webhook.url)
#   always posts to the "tamir-squads-notifications" channel (general/catch-all).
#   This is the fallback and works today for all alert types.
#
# AGENT MODE (future — Neelix with Teams MCP tools):
#   When Neelix runs as a proper agent with Teams MCP, it should post directly
#   to the correct channel via channelId using the Teams MCP PostChannelMessage tool.
#   The channel routing map lives at: .squad/teams-channels.json
#
# Channel routing map (key → channel):
#   general      → tamir-squads-notifications  (catch-all)
#   tech-news    → Tech News                   (daily tech briefings)
#   ralph-alerts → Ralph Alerts                (errors, stalls, health)
#   wins         → Wins and Celebrations       (closed issues, merges, birthdays)
#   pr-code      → PR and Code                 (PRs, reviews, CI)
#   research     → Research Updates            (research outputs)
#   roy          → Roy - Wizard                (Roy's dedicated channel)
#
# Neelix should include "CHANNEL: <key>" in its output so messages can be
# routed to the right channel. The Send-TeamsAlert function below uses the
# webhook (always general channel) as the reliable fallback.
# -------------------------------------------------------------------

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
        title = "⚠️ Ralph Watch Alert — $env:COMPUTERNAME ($(Split-Path (Get-Location) -Leaf))"
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
    try { $Host.UI.RawUI.WindowTitle = "Ralph Watch - Round $round"; Write-Host "`e]0;Ralph Watch - Round $round`a" -NoNewline } catch {}
    Write-Host "============================================" -ForegroundColor Cyan
    
    # Write heartbeat BEFORE round (status: running)
    Update-Heartbeat -Round $round -Status "running" -ConsecutiveFailures $consecutiveFailures
    
    # Step -1: Self-healing — set GH_CONFIG_DIR for this process based on repo remote
    # Isolates entire gh config (auth, cache, prefs) per-account without global state mutation
    try {
        $remoteUrl = & git remote get-url origin 2>&1 | Out-String
        $env:GH_CONFIG_DIR = if ($remoteUrl -match "tamirdresher_microsoft") {
            "$HOME\.config\gh-emu"
        } else {
            "$HOME\.config\gh-public"
        }
        Write-Host "[$timestamp] gh auth: GH_CONFIG_DIR set to $($env:GH_CONFIG_DIR) (full config isolation)" -ForegroundColor Green
    } catch {
        Write-Host "[$timestamp] Warning: gh auth check failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    $selfHealScript = Join-Path (Get-Location) "scripts\ralph-self-heal.ps1"
    if (Test-Path $selfHealScript) {
        Write-Host "[$timestamp] Running gh auth self-healing check..." -ForegroundColor Yellow
        try {
            $ghHealthOutput = & gh api user 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[$timestamp] gh CLI error detected — invoking self-heal..." -ForegroundColor Yellow
                . $selfHealScript
                $healResult = Invoke-SelfHeal
                if ($healResult.Healed) {
                    Write-Host "[$timestamp] Self-heal: $($healResult.Details)" -ForegroundColor Green
                } else {
                    Write-Host "[$timestamp] Self-heal could not fix: $($healResult.Details)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "[$timestamp] gh CLI health check passed" -ForegroundColor Green
            }
        } catch {
            Write-Host "[$timestamp] Warning: Self-heal check failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

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
        # Capture hash of this script BEFORE pull (for self-restart detection)
        $scriptPath = $MyInvocation.MyCommand.Path
        $preUpdateHash = if ($scriptPath -and (Test-Path $scriptPath)) { (Get-FileHash $scriptPath -Algorithm SHA256).Hash } else { "" }

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
            # Auto-resolve merge conflicts by accepting theirs (remote wins)
            $unmerged = git diff --name-only --diff-filter=U 2>$null
            if ($unmerged) {
                Write-Host "[$timestamp] Auto-resolving merge conflicts (accepting theirs)..." -ForegroundColor Yellow
                foreach ($file in $unmerged) {
                    git checkout --theirs $file 2>$null
                    git add $file 2>$null
                    Write-Host "[$timestamp]   Resolved: $file" -ForegroundColor DarkYellow
                }
                git commit -m "auto-resolve merge conflict [ralph-watch]" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[$timestamp] Merge conflicts resolved and committed" -ForegroundColor Green
                } else {
                    Write-Host "[$timestamp] Warning: Could not commit merge resolution" -ForegroundColor Yellow
                }
            }
        }
        
        # Restore stashed changes if any
        if ($stashed) {
            Write-Host "[$timestamp] Restoring local changes..." -ForegroundColor Yellow
            git stash pop 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[$timestamp] Warning: Could not restore stashed changes. Use 'git stash list' to recover." -ForegroundColor Yellow
            }
        }

        # Self-restart: if ralph-watch.ps1 changed, relaunch with new code
        $postUpdateHash = if ($scriptPath -and (Test-Path $scriptPath)) { (Get-FileHash $scriptPath -Algorithm SHA256).Hash } else { "" }
        if ($preUpdateHash -and $postUpdateHash -and ($preUpdateHash -ne $postUpdateHash)) {
            Write-Host "[$timestamp] ralph-watch.ps1 updated! Restarting with new code..." -ForegroundColor Magenta
            Write-RalphLog -Round $round -Timestamp $timestamp -ExitCode 0 -DurationSeconds 0 -ConsecutiveFailures 0 -Status "SELF-RESTART" -Metrics @{ issuesClosed = 0; prsMerged = 0; agentActions = 0 }
            # Clean up lockfile and mutex before restart
            Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
            if ($mutex) { try { $mutex.ReleaseMutex() } catch {} ; $mutex.Dispose() }
            # Relaunch self in a new window
            Start-Process pwsh.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath -WorkingDirectory (Get-Location).Path -WindowStyle Normal
            Write-Host "[$timestamp] New Ralph instance launched. This instance exiting." -ForegroundColor Magenta
            exit 0
        }

        # Also update start-all-ralphs.ps1 and other scripts automatically via the pull
        # (already handled by git pull above — scripts are tracked in git)
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
    
    # Process cross-machine tasks
    $crossMachineWatcher = Join-Path $PSScriptRoot "scripts/cross-machine-watcher.ps1"
    if (Test-Path $crossMachineWatcher) {
        try {
            Write-Host "[$timestamp] 🔄 Processing cross-machine tasks..." -ForegroundColor Yellow
            & $crossMachineWatcher -GitSync
            Write-Host "[$timestamp] ✅ Cross-machine watcher completed" -ForegroundColor Green
        } catch {
            Write-Host "[$timestamp] ⚠️ Cross-machine watcher failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # Step 1.6: Multi-machine coordination check (Issue #346)
    Write-Host "[$timestamp] Multi-machine coordination: Checking for stale work..." -ForegroundColor Yellow
    $staleIssues = Get-StaleIssues -MachineId $machineId -StaleThresholdMinutes $staleThresholdMinutes
    if ($staleIssues.Count -gt 0) {
        Write-Host "[$timestamp] Found $($staleIssues.Count) stale issue(s) from other machines" -ForegroundColor Yellow
        foreach ($staleItem in $staleIssues) {
            Write-Host "[$timestamp]   - Issue #$($staleItem.number) from $($staleItem.staleMachine) (stale for $($staleItem.ageMinutes) min)" -ForegroundColor Yellow
            $reclaimed = Invoke-StaleWorkReclaim -IssueNumber $staleItem.number -StaleMachine $staleItem.staleMachine -MachineId $machineId -AgeMinutes $staleItem.ageMinutes
            if ($reclaimed) {
                Write-Host "[$timestamp]   ✓ Successfully reclaimed issue #$($staleItem.number)" -ForegroundColor Green
            }
        }
    }
    
    # Update heartbeat for any issues we're actively working on
    $timeSinceLastHeartbeat = ((Get-Date) - $lastHeartbeatTime).TotalSeconds
    if ($timeSinceLastHeartbeat -ge $heartbeatIntervalSeconds) {
        Write-Host "[$timestamp] Multi-machine coordination: Updating heartbeats..." -ForegroundColor Yellow
        try {
            # Find issues with our machine's label
            $myLabel = "ralph:${machineId}:active"
            $myIssues = gh issue list --label $myLabel --json number --limit 50 2>$null | ConvertFrom-Json
            foreach ($issue in $myIssues) {
                Update-IssueHeartbeat -IssueNumber $issue.number -MachineId $machineId
            }
            if ($myIssues.Count -gt 0) {
                Write-Host "[$timestamp]   ✓ Updated heartbeat for $($myIssues.Count) issue(s)" -ForegroundColor Green
            }
        } catch {
            Write-Host "[$timestamp] Warning: Failed to update heartbeats - $($_.Exception.Message)" -ForegroundColor Yellow
        }
        $lastHeartbeatTime = Get-Date
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
        # Fresh session per round to prevent history accumulation (causes 400 Bad Request)
        $roundSessionId = [guid]::NewGuid().ToString()
        
        # Write prompt to temp file to avoid Start-Process argument splitting
        # (embedded flags like -R in prompt text get misinterpreted as CLI args)
        $promptFile = Join-Path $env:TEMP "ralph-prompt-$round.txt"
        [System.IO.File]::WriteAllText($promptFile, $prompt, [System.Text.Encoding]::UTF8)
        
        # Create a thin wrapper script that reads the prompt from file and calls agency
        # This avoids ALL Start-Process argument quoting issues
        $wrapperScript = Join-Path $env:TEMP "ralph-round-$round.ps1"
        @"
`$p = [System.IO.File]::ReadAllText('$($promptFile.Replace("'","''"))')
agency copilot --yolo --autopilot --agent squad --mcp mail --mcp calendar -p `$p --resume=$roundSessionId
exit `$LASTEXITCODE
"@ | Out-File -FilePath $wrapperScript -Encoding utf8 -Force
        
        # Launch the wrapper script with timeout guard
        $agencyProc = Start-Process -FilePath "pwsh" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $wrapperScript) `
            -PassThru -NoNewWindow
        $timedOut = $false
        $timeoutMs = $roundTimeoutMinutes * 60 * 1000
        if (-not $agencyProc.WaitForExit($timeoutMs)) {
            $timedOut = $true
            Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] TIMEOUT: Round $round exceeded ${roundTimeoutMinutes}m limit — killing agency process (PID $($agencyProc.Id))" -ForegroundColor Red
            # Kill the agency process and its children
            try {
                $childProcs = Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $agencyProc.Id }
                foreach ($child in $childProcs) {
                    Stop-Process -Id $child.ProcessId -Force -ErrorAction SilentlyContinue
                }
                Stop-Process -Id $agencyProc.Id -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Host "  Warning: Could not kill all child processes: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        $exitCode = if ($timedOut) { 124 } else { $agencyProc.ExitCode }
        $ErrorActionPreference = $ErrorActionPreference_saved
        $agencyOutput = ""  # Can't capture without pipes — but that's OK
        
        if ($timedOut) {
            $consecutiveFailures++

    # Self-escalation: if Ralph keeps failing, log it for visibility
    if ($consecutiveFailures -ge 3 -and ($consecutiveFailures % 3) -eq 0) {
        Write-Host "[$timestamp] WARNING: $consecutiveFailures consecutive failures! Logging escalation..." -ForegroundColor Red
        Write-RalphLog -Round $round -Timestamp $timestamp -ExitCode $exitCode -DurationSeconds 0 -ConsecutiveFailures $consecutiveFailures -Status "ESCALATION" -Metrics @{ issuesClosed = 0; prsMerged = 0; agentActions = 0 }
    }
            $roundStatus = "timeout"
            $logStatus = "TIMEOUT"
        } elseif ($exitCode -eq 0) {
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
    
    # Write cross-machine heartbeat for Telegram bot visibility (Issue #606)
    $ralphHeartbeatScript = Join-Path $PSScriptRoot "scripts\ralph-heartbeat.ps1"
    if (Test-Path $ralphHeartbeatScript) {
        try {
            & $ralphHeartbeatScript -Round $round -Status $roundStatus -Failures $consecutiveFailures -Repo (Get-Location).Path | Out-Null
        } catch {
            Write-Host "[$timestamp] Warning: Failed to update Telegram heartbeat: $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }
    
    # Rotate log if needed
    Invoke-LogRotation
    
    # Send Teams alert if 3+ consecutive failures or on timeout
    if ($consecutiveFailures -ge 3 -or $logStatus -eq "TIMEOUT") {
        $reason = if ($logStatus -eq "TIMEOUT") { "TIMEOUT (round exceeded ${roundTimeoutMinutes}m)" } else { "Consecutive failures threshold ($consecutiveFailures)" }
        Write-Host "[$timestamp] $reason — sending Teams alert..." -ForegroundColor Yellow
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
