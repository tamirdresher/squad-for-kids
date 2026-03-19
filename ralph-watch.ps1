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

# Fix GH_CONFIG_DIR — MUST be set before any gh commands
# The system env var often points to a nonexistent path (e.g., ~/.config/gh-emu)
# Real auth lives in %APPDATA%\GitHub CLI on this DevBox
$ghConfigCandidate = "$env:APPDATA\GitHub CLI"
if (Test-Path "$ghConfigCandidate\hosts.yml") {
    $env:GH_CONFIG_DIR = $ghConfigCandidate
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
    $sentinel = Join-Path $env:USERPROFILE ".squad\ralph-stop"
    Remove-Item $sentinel -Force -ErrorAction SilentlyContinue
    if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
} | Out-Null
trap { 
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    $sentinel = Join-Path $env:USERPROFILE ".squad\ralph-stop"
    Remove-Item $sentinel -Force -ErrorAction SilentlyContinue
    if ($mutex) { try { $mutex.ReleaseMutex() } catch {} ; $mutex.Dispose() }
    break 
}

$defaultIntervalMinutes = 5
$intervalMinutes = $defaultIntervalMinutes
$roundTimeoutMinutes = 20  # Kill round if it exceeds this (prevents hangs)
$round = 0
$consecutiveFailures = 0
$maxLogEntries = 500
$maxLogBytes = 1048576  # 1MB

# Log rotation settings
$maxLogBytes = 1MB
$maxLogEntries = 500

# Throttle mode config (Issue #847)
$ralphConfigPath = Join-Path $env:USERPROFILE ".squad\ralph-config.json"
$ralphStopSentinel = Join-Path $env:USERPROFILE ".squad\ralph-stop"
$ralphThrottleSentinel = Join-Path $env:USERPROFILE ".squad\ralph-throttle"

# Create default config if it doesn't exist
if (-not (Test-Path $ralphConfigPath)) {
    $squadDir = Join-Path $env:USERPROFILE ".squad"
    if (-not (Test-Path $squadDir)) { New-Item -ItemType Directory -Path $squadDir -Force | Out-Null }
    @{ intervalSeconds = 300; throttled = $false; throttleIntervalSeconds = 900 } |
        ConvertTo-Json | Out-File $ralphConfigPath -Encoding utf8
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Created default config: $ralphConfigPath" -ForegroundColor DarkGray
}

function Read-RalphConfig {
    <#
    .SYNOPSIS
    Reads ralph-config.json and returns the effective sleep interval in minutes.
    Re-read every round so changes take effect without restart.
    Also checks for ralph-throttle sentinel file to temporarily override throttle.
    #>
    $ts = Get-Date -Format "HH:mm:ss"

    # Sentinel file override: ralph-throttle forces throttled interval for this round
    $sentinelThrottle = Test-Path $ralphThrottleSentinel

    if (-not (Test-Path $ralphConfigPath)) {
        if ($sentinelThrottle) {
            $mins = [math]::Round(900 / 60, 1)
            Write-Host "[$ts] Throttle sentinel ACTIVE (no config) — interval ${mins}m" -ForegroundColor Yellow
            return $mins
        }
        return $defaultIntervalMinutes
    }
    try {
        $cfg = Get-Content $ralphConfigPath -Raw | ConvertFrom-Json
        # Support both "throttled" (spec) and "throttleMode" (legacy)
        $isThrottled = if ($null -ne $cfg.throttled) { $cfg.throttled } elseif ($null -ne $cfg.throttleMode) { $cfg.throttleMode } else { $false }
        # Sentinel file overrides config — treat as throttled
        if ($sentinelThrottle) { $isThrottled = $true }

        if ($isThrottled -eq $true) {
            $throttleSec = if ($cfg.throttleIntervalSeconds) { $cfg.throttleIntervalSeconds } else { 900 }
            $mins = [math]::Round($throttleSec / 60, 1)
            $source = if ($sentinelThrottle) { "sentinel+config" } else { "config" }
            Write-Host "[$ts] Throttle mode ACTIVE — interval ${mins}m (source: $source)" -ForegroundColor Yellow
            return $mins
        }
        $normalSec = if ($cfg.intervalSeconds) { $cfg.intervalSeconds } else { $defaultIntervalMinutes * 60 }
        $mins = [math]::Round($normalSec / 60, 1)
        Write-Host "[$ts] Config loaded — interval ${mins}m" -ForegroundColor DarkGray
        return $mins
    } catch {
        Write-Host "[$ts] Warning: Failed to read $ralphConfigPath — using default ${defaultIntervalMinutes}m" -ForegroundColor Yellow
        return $defaultIntervalMinutes
    }
}

# -------------------------------------------------------------------
# Model Circuit Breaker (model-level fallback for rate limits)
# -------------------------------------------------------------------
# When the preferred model hits rate limits, automatically falls back
# to free-tier models, then recovers after cooldown.
# State tracked in .squad/ralph-circuit-breaker.json
# -------------------------------------------------------------------

function Get-CircuitBreakerState {
    $cbFile = Join-Path $PSScriptRoot ".squad\ralph-circuit-breaker.json"
    if (Test-Path $cbFile) {
        try {
            return Get-Content $cbFile -Raw | ConvertFrom-Json
        } catch {
            Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [model-cb] Failed to read circuit breaker state, using defaults" -ForegroundColor Yellow
        }
    }
    return [ordered]@{
        state = "closed"
        preferredModel = "claude-sonnet-4.6"
        currentModel = "claude-sonnet-4.6"
        fallbackChain = @("gpt-5.4-mini", "gpt-5-mini", "gpt-4.1")
        lastRateLimitHit = $null
        cooldownMinutes = 10
        consecutiveSuccesses = 0
        requiredSuccessesToClose = 2
        totalFallbacks = 0
        totalRecoveries = 0
    }
}

function Save-CircuitBreakerState($cb) {
    $cbFile = Join-Path $PSScriptRoot ".squad\ralph-circuit-breaker.json"
    $cbDir = Split-Path $cbFile -Parent
    if (-not (Test-Path $cbDir)) { New-Item -ItemType Directory -Path $cbDir -Force | Out-Null }
    $cb | ConvertTo-Json -Depth 5 | Set-Content $cbFile -Encoding utf8
}

function Get-CurrentModel {
    $cb = Get-CircuitBreakerState
    $ts = Get-Date -Format "HH:mm:ss"

    switch ($cb.state) {
        "closed" { return $cb.preferredModel }
        "open" {
            if ($cb.lastRateLimitHit) {
                $elapsed = (Get-Date) - [datetime]$cb.lastRateLimitHit
                if ($elapsed.TotalMinutes -ge $cb.cooldownMinutes) {
                    $cb.state = "half-open"
                    $cb.currentModel = $cb.preferredModel
                    Save-CircuitBreakerState $cb
                    Write-Host "[$ts] [model-cb] HALF-OPEN: Testing preferred model $($cb.preferredModel)" -ForegroundColor Yellow
                    return $cb.preferredModel
                }
            }
            return $cb.currentModel
        }
        "half-open" { return $cb.preferredModel }
    }
    return $cb.preferredModel
}

function Update-CircuitBreakerOnSuccess {
    $cb = Get-CircuitBreakerState
    $ts = Get-Date -Format "HH:mm:ss"

    if ($cb.state -eq "half-open") {
        $cb.consecutiveSuccesses = [int]$cb.consecutiveSuccesses + 1
        if ([int]$cb.consecutiveSuccesses -ge [int]$cb.requiredSuccessesToClose) {
            $cb.state = "closed"
            $cb.currentModel = $cb.preferredModel
            $cb.consecutiveSuccesses = 0
            $cb.totalRecoveries = [int]$cb.totalRecoveries + 1
            Write-Host "[$ts] [model-cb] CLOSED: Recovered to preferred model $($cb.preferredModel)" -ForegroundColor Green
        } else {
            Write-Host "[$ts] [model-cb] HALF-OPEN: Success $($cb.consecutiveSuccesses)/$($cb.requiredSuccessesToClose) toward recovery" -ForegroundColor Yellow
        }
        Save-CircuitBreakerState $cb
    }
    # If closed or open-on-fallback, no state change needed
}

function Update-CircuitBreakerOnRateLimit {
    $cb = Get-CircuitBreakerState
    $ts = Get-Date -Format "HH:mm:ss"
    $cb.state = "open"
    $cb.lastRateLimitHit = (Get-Date).ToString("o")
    $cb.consecutiveSuccesses = 0
    $cb.totalFallbacks = [int]$cb.totalFallbacks + 1

    # Pick first available fallback model
    $fallbacks = @($cb.fallbackChain)
    if ($fallbacks.Count -gt 0) {
        $cb.currentModel = $fallbacks[0]
    } else {
        $cb.currentModel = "gpt-4.1"
    }

    Write-Host "[$ts] [model-cb] OPEN: Rate limited! Falling back to $($cb.currentModel)" -ForegroundColor Red
    Save-CircuitBreakerState $cb
}

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

WHATSAPP FAMILY MONITORING (every 3rd round):
1. Use Playwright to check WhatsApp Web (https://web.whatsapp.com) for new messages from contact "gabi"
2. Look for action keywords in her messages: print, calendar, reminder, buy, todo
3. For print requests: forward attachment/content to Dresherhome@hpeprint.com using Send-SquadEmail.ps1
4. For calendar/reminder requests: create a GitHub issue titled "📅 Family: {summary}" with labels "squad,family-request" and include date/time details
5. For buy/todo/general requests: create a GitHub issue titled "🏠 Family: {summary}" with labels "squad,family-request"
6. After processing, send Tamir a brief Teams notification (CHANNEL: general) summarizing what was handled
7. Do NOT create duplicate issues — check existing open issues with label "family-request" first
8. If WhatsApp Web is not connected or requires QR scan, log a warning and skip — do NOT block the round

MACHINE CAPABILITY ROUTING (Issue #987): Before picking up ANY issue, check its labels for `needs:*` prefixes.
The file ~/.squad/machine-capabilities.json lists what this machine supports. The `capabilities` array contains strings like "browser", "gpu", "whatsapp", "personal-gh", "emu-gh", "teams-mcp", "onedrive", "azure-speech".
For every `needs:X` label on an issue, verify that `X` is in the capabilities array. If ANY required capability is missing, SKIP the issue silently — another Ralph instance on a capable machine will handle it. Log: "[cap-check] Skipping issue #N — missing: X, Y".
This prevents wasted rounds on issues this machine cannot complete.

IMPORTANT: Only send a Teams message if there are important changes that require my attention — such as new issues needing my decision, PRs ready for review or merged, CI failures, completed work I should know about, or items requiring user action. Do NOT send a Teams message for routine board status checks with no actionable changes.
'@

# Initialize observability paths (per-repo to avoid collisions when running multiple ralphs)
$squadDir = Join-Path $env:USERPROFILE ".squad"
$repoName = Split-Path (Get-Location).Path -Leaf
$logFile = Join-Path $squadDir "ralph-watch-$repoName.log"
$heartbeatFile = Join-Path $squadDir "ralph-heartbeat-$repoName.json"
$teamsWebhookFile = Join-Path $squadDir "teams-webhook.url"
$teamsWebhooksDir = Join-Path $squadDir "teams-webhooks"

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

# ─────────────────────────────────────────────────────────────────────────────
# Invoke-RalphHealthCheck  (Issue #988)
# Pre-round watchdog — auto-detects and fixes the 5 most common Ralph failures:
#   1. CB file schema corruption (nested vs flat)  → convert to flat + reset
#   2. Empty / null model string                   → reset CB to safe defaults
#   3. GH_CONFIG_DIR wrong or gh unauthenticated   → probe known paths, fix in-process
#   4. Orphaned agency.exe / node processes (>5)   → kill extras
#   5. Branch drift (not on expected branch)       → warn operator
# Returns: [PSCustomObject]@{ Healed=[string[]]; Warnings=[string[]] }
# ─────────────────────────────────────────────────────────────────────────────
function Invoke-RalphHealthCheck {
    param(
        [int]$Round,
        [string]$ExpectedBranch = "main"
    )
    $ts       = Get-Date -Format 'HH:mm:ss'
    $healed   = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    # ── Check 1 & 2: CB file schema + model sanity ────────────────────────────
    $cbFile = Join-Path (Get-Location) ".squad/ralph-circuit-breaker.json"
    if (Test-Path $cbFile) {
        try {
            $cb = Get-Content $cbFile -Raw | ConvertFrom-Json
            # Nested schema (model_fallback wrapper) → convert to flat
            if (-not $cb.preferredModel -and $cb.model_fallback) {
                $flat = [ordered]@{
                    state                    = "closed"
                    preferredModel           = $cb.model_fallback.preferred
                    currentModel             = $cb.model_fallback.preferred
                    fallbackChain            = $cb.model_fallback.fallback_chain
                    lastRateLimitHit         = $null
                    cooldownMinutes          = 10
                    consecutiveSuccesses     = 0
                    requiredSuccessesToClose = 2
                    totalFallbacks           = 0
                    totalRecoveries          = 0
                }
                $flat | ConvertTo-Json -Depth 3 | Set-Content $cbFile -Encoding utf8
                $healed.Add("CB schema: converted nested->flat")
                Write-Host "[$ts] [health] CB schema fixed: nested->flat (was missing preferredModel)" -ForegroundColor Yellow
            }
        } catch {
            $warnings.Add("CB parse error: $($_.Exception.Message)")
            Write-Host "[$ts] [health] WARNING: CB file could not be parsed — $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # Empty model string → --model "" causes instant exit code 1; reset to safe defaults
    $model = Get-CurrentModel
    if ([string]::IsNullOrWhiteSpace($model)) {
        $safeDefaults = [ordered]@{
            state                    = "closed"
            preferredModel           = "claude-sonnet-4.6"
            currentModel             = "claude-sonnet-4.6"
            fallbackChain            = @("claude-sonnet-4.5","gpt-5.4-mini","gpt-5-mini","gpt-4.1")
            lastRateLimitHit         = $null
            cooldownMinutes          = 10
            consecutiveSuccesses     = 0
            requiredSuccessesToClose = 2
            totalFallbacks           = 0
            totalRecoveries          = 0
        }
        $safeDefaults | ConvertTo-Json -Depth 3 | Set-Content $cbFile -Encoding utf8
        $healed.Add("Model null/empty — CB reset to claude-sonnet-4.6")
        Write-Host "[$ts] [health] Model was null/empty — CB reset to claude-sonnet-4.6 (fixes --model '' exit-1)" -ForegroundColor Yellow
    }

    # ── Check 2b: Copilot config CB validator — verify preferredModel key exists ──
    # Checks the Copilot config file (not the ralph-circuit-breaker.json) for a
    # preferredModel key. If missing or null, logs warning and resets to default.
    $copilotConfigPaths = @(
        (Join-Path $env:USERPROFILE ".copilot\copilot.json"),
        (Join-Path $env:APPDATA    "GitHub Copilot\copilot.json")
    )
    foreach ($cfPath in $copilotConfigPaths) {
        if (Test-Path $cfPath) {
            try {
                $cfContent = Get-Content $cfPath -Raw -Encoding utf8 | ConvertFrom-Json
                if ($null -eq $cfContent.preferredModel -or
                    [string]::IsNullOrWhiteSpace($cfContent.preferredModel)) {
                    $warnings.Add("Copilot config '$cfPath' missing/null preferredModel — resetting to claude-sonnet-4.6")
                    Write-Host "[$ts] [health] WARNING: Copilot config '$cfPath' missing preferredModel — resetting to claude-sonnet-4.6" -ForegroundColor Yellow
                    $cfContent | Add-Member -NotePropertyName "preferredModel" `
                                            -NotePropertyValue "claude-sonnet-4.6" -Force
                    $cfContent | ConvertTo-Json -Depth 5 | Set-Content $cfPath -Encoding utf8
                    $healed.Add("Copilot config preferredModel reset to claude-sonnet-4.6 at '$cfPath'")
                } else {
                    Write-Host "[$ts] [health] Copilot config OK: preferredModel=$($cfContent.preferredModel)" -ForegroundColor DarkGray
                }
            } catch {
                $warnings.Add("Copilot config parse error at '$cfPath': $($_.Exception.Message)")
                Write-Host "[$ts] [health] WARNING: Could not parse Copilot config '$cfPath': $($_.Exception.Message)" -ForegroundColor Yellow
            }
            break  # Only inspect the first path that exists
        }
    }

    # ── Check 3: GH_CONFIG_DIR — validate dir exists AND gh is authenticated ──
    $ghAuthOk = $false
    if (-not [string]::IsNullOrWhiteSpace($env:GH_CONFIG_DIR) -and (Test-Path $env:GH_CONFIG_DIR)) {
        $probe = & gh api user --jq '.login' 2>&1
        $ghAuthOk = ($LASTEXITCODE -eq 0)
    }
    if (-not $ghAuthOk) {
        # Primary fallback: %APPDATA%\GitHub CLI (canonical Windows path for both EMU + personal)
        $canonicalDir = "$env:APPDATA\GitHub CLI"
        $env:GH_CONFIG_DIR = $canonicalDir
        $probe = & gh api user --jq '.login' 2>&1
        if ($LASTEXITCODE -eq 0) {
            $healed.Add("GH_CONFIG_DIR set to '$canonicalDir' (login: $($probe.Trim()))")
            Write-Host "[$ts] [health] GH_CONFIG_DIR fixed -> '$canonicalDir' (login: $($probe.Trim()))" -ForegroundColor Yellow
            $ghAuthOk = $true
        } else {
            # Try additional fallback paths — gh-emu first, then personal gh
            foreach ($path in @("$HOME\.config\gh-emu", "$HOME\.config\gh")) {
                if (Test-Path "$path\hosts.yml") {
                    $env:GH_CONFIG_DIR = $path
                    $retry = & gh api user --jq '.login' 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $healed.Add("GH_CONFIG_DIR set to '$path' (login: $($retry.Trim()))")
                        Write-Host "[$ts] [health] GH_CONFIG_DIR fixed -> '$path' (login: $($retry.Trim()))" -ForegroundColor Yellow
                        $ghAuthOk = $true
                        break
                    }
                }
            }
        }
        if (-not $ghAuthOk) {
            $warnings.Add("GH auth: gh is NOT authenticated — all config paths failed")
            Write-Host "[$ts] [health] WARNING: gh is NOT authenticated — run 'gh auth login'" -ForegroundColor Red
        }
    }

    # ── Check 4: Orphaned agency.exe / node processes — kill oldest if >10 are >30min old ──
    # Collect agency/node processes that are NOT our children and are older than 30 minutes.
    # If the stale-orphan count exceeds 10, kill the oldest ones (keep the 10 newest).
    $myPid           = $PID
    $myChildren      = @((Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
                         Where-Object { $_.ParentProcessId -eq $myPid }).ProcessId)
    $orphanAgeMin    = 30
    $orphanKillLimit = 10
    $staleOrphans    = [System.Collections.Generic.List[object]]::new()
    foreach ($procName in @('agency', 'node')) {
        foreach ($proc in @(Get-Process -Name $procName -ErrorAction SilentlyContinue)) {
            try {
                $ageMin = ((Get-Date) - $proc.StartTime).TotalMinutes
                $ppid   = (Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" `
                           -ErrorAction SilentlyContinue).ParentProcessId
                if ($ageMin -gt $orphanAgeMin -and
                    $ppid -ne $myPid -and $ppid -notin $myChildren) {
                    $staleOrphans.Add($proc)
                }
            } catch {}
        }
    }
    $orphanCount = 0
    if ($staleOrphans.Count -gt $orphanKillLimit) {
        # Kill the oldest, keeping the $orphanKillLimit newest alive
        $toKill = $staleOrphans | Sort-Object StartTime | Select-Object -First ($staleOrphans.Count - $orphanKillLimit)
        foreach ($proc in $toKill) {
            try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue; $orphanCount++ } catch {}
        }
        $healed.Add("Killed $orphanCount orphaned agency/node processes (>$orphanAgeMin min old, threshold >$orphanKillLimit)")
        Write-Host "[$ts] [health] Killed $orphanCount orphaned agency.exe/node processes ($($staleOrphans.Count) found >$orphanAgeMin min old; kept $orphanKillLimit newest)" -ForegroundColor Yellow
    } elseif ($staleOrphans.Count -gt 0) {
        Write-Host "[$ts] [health] $($staleOrphans.Count) stale orphan(s) found (threshold $orphanKillLimit — no kill needed)" -ForegroundColor DarkGray
    }

    # ── Check 5: Branch drift — warn if not on expected branch ───────────────
    try {
        $currentBranch = (& git rev-parse --abbrev-ref HEAD 2>&1).Trim()
        if (-not [string]::IsNullOrWhiteSpace($currentBranch) -and $currentBranch -ne $ExpectedBranch) {
            $warnings.Add("Branch drift: on '$currentBranch' (expected '$ExpectedBranch')")
            Write-Host "[$ts] [health] WARNING: Branch drift — running on '$currentBranch', expected '$ExpectedBranch'" -ForegroundColor Magenta
            Write-Host "[$ts] [health]   Fixes from $ExpectedBranch may be missing. Consider: git checkout $ExpectedBranch" -ForegroundColor DarkMagenta
        }
    } catch {
        $warnings.Add("Branch check failed: $($_.Exception.Message)")
    }

    # ── Structured self-heal log ──────────────────────────────────────────────
    if ($healed.Count -gt 0 -or $warnings.Count -gt 0) {
        $logDir = Join-Path $env:USERPROFILE ".squad"
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $logFile = Join-Path $logDir "ralph-self-heal.log"
        $entry = "$(Get-Date -Format 'o') | Round=$Round | HEALED=[$($healed -join '; ')] | WARNINGS=[$($warnings -join '; ')]"
        Add-Content -Path $logFile -Value $entry
    }

    return [PSCustomObject]@{
        Healed   = $healed.ToArray()
        Warnings = $warnings.ToArray()
    }
}

# Backward-compat shim (callers using old name still work)
function Invoke-PreRoundHealthCheck {
    param([int]$Round)
    return Invoke-RalphHealthCheck -Round $Round
}

# Self-healing watchdog: post-failure remediation (Issue #988)
# Tiered response based on consecutive failure count
function Invoke-PostFailureRemediation {
    param([int]$ConsecutiveFailures, [int]$Round)
    $ts = Get-Date -Format 'HH:mm:ss'
    $actions = @()

    if ($ConsecutiveFailures -ge 3 -and $ConsecutiveFailures -lt 6) {
        # Tier 1: Reset CB + clear rate pool cooldown
        $cbFile = Join-Path (Get-Location) ".squad/ralph-circuit-breaker.json"
        @{
            state = "closed"; preferredModel = "claude-sonnet-4.6"; currentModel = "claude-sonnet-4.6"
            fallbackChain = @("claude-sonnet-4.5","gpt-5.4-mini","gpt-5-mini","gpt-4.1")
            lastRateLimitHit = $null; cooldownMinutes = 10; consecutiveSuccesses = 0
            requiredSuccessesToClose = 2; totalFallbacks = 0; totalRecoveries = 0
        } | ConvertTo-Json -Depth 3 | Set-Content $cbFile -Encoding utf8

        $ratePool = "$env:USERPROFILE\.squad\rate-pool.json"
        if (Test-Path $ratePool) {
            $pool = Get-Content $ratePool -Raw | ConvertFrom-Json
            $pool.cooldown_until = $null
            $pool | ConvertTo-Json -Depth 5 | Set-Content $ratePool -Encoding utf8
        }
        $actions += "Tier1: Reset CB + cleared rate pool cooldown"
        Write-Host "[$ts] [self-heal] 🔧 Self-heal: reset cooldown (Tier 1 — $ConsecutiveFailures consecutive failures)" -ForegroundColor Yellow
    }

    if ($ConsecutiveFailures -ge 6 -and $ConsecutiveFailures -lt 9) {
        # Tier 2: Re-probe auth + kill orphans
        $env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"
        $ghCheck = & gh api user --jq '.login' 2>&1
        if ($LASTEXITCODE -ne 0) {
            $actions += "Tier2: GH auth still broken after re-probe"
        } else {
            $actions += "Tier2: GH auth OK ($ghCheck)"
        }

        # Kill orphans
        $allAgency = Get-Process -Name agency -ErrorAction SilentlyContinue
        $killed = 0
        foreach ($proc in $allAgency) {
            $parent = (Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" -ErrorAction SilentlyContinue).ParentProcessId
            if ($parent -ne $PID) {
                try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue; $killed++ } catch {}
            }
        }
        $actions += "Tier2: Killed $killed orphaned processes"
        Write-Host "[$ts] [self-heal] Tier 2 remediation: auth re-probe + orphan cleanup ($killed killed)" -ForegroundColor Yellow
    }

    if ($ConsecutiveFailures -ge 9 -and $ConsecutiveFailures -lt 15) {
        # Tier 3: Full heal — all of above + git pull latest
        $actions += "Tier3: Full self-heal attempted"
        Write-Host "[$ts] [self-heal] Tier 3: Full self-heal -- resetting everything" -ForegroundColor Red
        # Pull latest from remote (non-destructive)
        git stash 2>$null
        git pull --rebase origin (git rev-parse --abbrev-ref HEAD) 2>$null
        git stash pop 2>$null
    }

    if ($ConsecutiveFailures -ge 15) {
        # Tier 4: Post Teams alert + pause 30 minutes
        $actions += "Tier4: Posting Teams alert + pausing 30 minutes after $ConsecutiveFailures failures"
        Write-Host "[$ts] [self-heal] Tier 4: CRITICAL — $ConsecutiveFailures failures, alerting Teams and pausing 30 minutes" -ForegroundColor Red

        # Post Teams alert via the squad webhook file
        $webhookFile = Join-Path $env:USERPROFILE ".squad\teams-webhook.url"
        if (Test-Path $webhookFile) {
            try {
                $webhookUrl = (Get-Content $webhookFile -Raw -Encoding utf8).Trim()
                if (-not [string]::IsNullOrWhiteSpace($webhookUrl)) {
                    $alertBody = @{
                        "@type"    = "MessageCard"
                        "@context" = "https://schema.org/extensions"
                        summary    = "🚨 Ralph Self-Heal: $ConsecutiveFailures consecutive failures on $env:COMPUTERNAME"
                        themeColor = "FF0000"
                        title      = "🚨 Ralph Self-Heal Alert — $env:COMPUTERNAME"
                        sections   = @(@{
                            activityTitle = "Ralph has hit $ConsecutiveFailures consecutive failures and is pausing 30 minutes"
                            facts = @(
                                @{ name = "Machine";              value = $env:COMPUTERNAME },
                                @{ name = "Round";                value = $Round },
                                @{ name = "Consecutive Failures"; value = $ConsecutiveFailures },
                                @{ name = "Timestamp";            value = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') },
                                @{ name = "Action";               value = "Pausing 30 minutes, then resuming" }
                            )
                        })
                    } | ConvertTo-Json -Depth 10
                    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $alertBody `
                        -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
                    $actions += "Tier4: Teams alert sent via $webhookFile"
                    Write-Host "[$ts] [self-heal] Teams alert sent to webhook" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "[$ts] [self-heal] Warning: Failed to send Teams alert: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[$ts] [self-heal] Teams webhook file not found at $webhookFile — skipping alert" -ForegroundColor Yellow
        }

        Start-Sleep -Seconds 1800  # 30 minutes
    }

    # Log
    if ($actions.Count -gt 0) {
        $logFile = "$env:USERPROFILE\.squad\ralph-self-heal.log"
        $entry = "$(Get-Date -Format 'o') | REMEDIATION | Round=$Round | Failures=$ConsecutiveFailures | $($actions -join '; ')"
        Add-Content -Path $logFile -Value $entry
    }

    return $actions
}


# Function to test if this machine can handle an issue's needs:* labels (Issue #987)
function Test-MachineCapability {
    param(
        [string[]]$IssueLabels
    )

    $capFile = Join-Path $env:USERPROFILE ".squad\machine-capabilities.json"
    if (-not (Test-Path $capFile)) {
        # No manifest yet — optimistic: assume capable
        return @{ CanHandle = $true; Reason = "No capability manifest found — assuming capable" }
    }

    try {
        $manifest = Get-Content $capFile -Raw -Encoding utf8 | ConvertFrom-Json
    } catch {
        return @{ CanHandle = $true; Reason = "Could not parse capability manifest — assuming capable" }
    }

    $machineCaps = @($manifest.capabilities)
    $needsLabels = $IssueLabels | Where-Object { $_ -match '^needs:' }

    if (-not $needsLabels -or $needsLabels.Count -eq 0) {
        # Issue has no needs:* labels — any machine can handle it
        return @{ CanHandle = $true; Reason = "No needs:* labels on issue" }
    }

    $missingCaps = [System.Collections.Generic.List[string]]::new()
    foreach ($label in $needsLabels) {
        $capName = $label -replace '^needs:', ''
        if ($capName -notin $machineCaps) {
            $missingCaps.Add($capName)
        }
    }

    if ($missingCaps.Count -eq 0) {
        return @{ CanHandle = $true; Reason = "All required capabilities present" }
    } else {
        return @{
            CanHandle = $false
            Reason    = "Missing capabilities: $($missingCaps -join ', ')"
        }
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

# -------------------------------------------------------------------
# Cross-Machine Rate Coordination (Issue #825)
# -------------------------------------------------------------------
# Shared rate pool at ~/.squad/rate-pool.json allows multiple Ralph
# instances to coordinate API budget. Includes circuit breaker,
# budget tracking, and priority lanes.
# -------------------------------------------------------------------

$ratePoolPath = Join-Path $env:USERPROFILE ".squad\rate-pool.json"
$ratePoolWindowMinutes = 60  # Budget window resets every hour
$circuitBreakerThreshold = 3  # Consecutive 429s to trip breaker
$baseCooldownMinutes = 5       # Initial cooldown (doubles each trip)

function New-RatePool {
    <#
    .SYNOPSIS
    Creates a fresh rate-pool.json with default budgets.
    #>
    return [ordered]@{
        window_start = (Get-Date).ToUniversalTime().ToString("o")
        requests = [ordered]@{
            premium  = [ordered]@{ count = 0; limit = 50 }
            standard = [ordered]@{ count = 0; limit = 200 }
            fast     = [ordered]@{ count = 0; limit = 500 }
        }
        last_429 = $null
        cooldown_until = $null
        circuit_breaker = [ordered]@{
            consecutive_429s = 0
            state = "closed"
            opened_at = $null
        }
        machines = [ordered]@{}
    }
}

function Read-RatePool {
    <#
    .SYNOPSIS
    Reads rate-pool.json with retry logic for cross-machine file locking.
    Returns the parsed pool object, or a fresh default if file is missing/corrupt.
    #>
    if (-not (Test-Path $ratePoolPath)) {
        $pool = New-RatePool
        Write-RatePool -Pool $pool
        return $pool
    }

    $maxRetries = 3
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            $raw = [System.IO.File]::ReadAllText($ratePoolPath)
            $pool = $raw | ConvertFrom-Json

            # Check if window has expired and reset counters
            $windowStart = [datetime]::Parse($pool.window_start).ToUniversalTime()
            $elapsed = ((Get-Date).ToUniversalTime() - $windowStart).TotalMinutes
            if ($elapsed -ge $ratePoolWindowMinutes) {
                Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [rate-pool] Window expired (${elapsed}m) — resetting counters" -ForegroundColor DarkCyan
                $pool.window_start = (Get-Date).ToUniversalTime().ToString("o")
                $pool.requests.premium.count = 0
                $pool.requests.standard.count = 0
                $pool.requests.fast.count = 0
                $pool.circuit_breaker.consecutive_429s = 0
                $pool.circuit_breaker.state = "closed"
                $pool.circuit_breaker.opened_at = $null
                $pool.last_429 = $null
                $pool.cooldown_until = $null
                Write-RatePool -Pool $pool
            }
            return $pool
        } catch {
            if ($i -lt ($maxRetries - 1)) {
                Start-Sleep -Milliseconds (200 * ($i + 1))
            } else {
                Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [rate-pool] Failed to read after $maxRetries retries, creating fresh pool" -ForegroundColor Yellow
                $pool = New-RatePool
                Write-RatePool -Pool $pool
                return $pool
            }
        }
    }
}

function Write-RatePool {
    <#
    .SYNOPSIS
    Atomically writes rate-pool.json using exclusive file lock.
    Writes to a temp file first, then renames for crash safety.
    #>
    param([object]$Pool)

    $dir = Split-Path $ratePoolPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $tempFile = "$ratePoolPath.tmp.$PID"
    $maxRetries = 3
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            $json = $Pool | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($tempFile, $json)
            # Atomic rename (overwrites target on Windows with Move-Item -Force)
            Move-Item -Path $tempFile -Destination $ratePoolPath -Force
            return
        } catch {
            if ($i -lt ($maxRetries - 1)) {
                Start-Sleep -Milliseconds (200 * ($i + 1))
            } else {
                Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [rate-pool] Failed to write after $maxRetries retries: $($_.Exception.Message)" -ForegroundColor Yellow
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Update-RatePool {
    <#
    .SYNOPSIS
    Atomically increments the request count for a given model tier
    and updates this machine's heartbeat in the pool.
    .PARAMETER Tier
    One of: premium, standard, fast
    .PARAMETER Got429
    Set to $true if the request resulted in a 429 response.
    #>
    param(
        [string]$Tier = "standard",
        [bool]$Got429 = $false
    )

    $pool = Read-RatePool

    # Increment request count for the tier
    if ($pool.requests.$Tier) {
        $pool.requests.$Tier.count = [int]$pool.requests.$Tier.count + 1
    }

    # Update machine entry
    if (-not $pool.machines) {
        $pool | Add-Member -NotePropertyName "machines" -NotePropertyValue ([ordered]@{}) -Force
    }
    $pool.machines | Add-Member -NotePropertyName $machineId -NotePropertyValue ([ordered]@{
        last_active = (Get-Date).ToUniversalTime().ToString("o")
        pid = $PID
        round = $round
    }) -Force

    # Handle 429 tracking
    if ($Got429) {
        $pool.last_429 = (Get-Date).ToUniversalTime().ToString("o")
        $pool.circuit_breaker.consecutive_429s = [int]$pool.circuit_breaker.consecutive_429s + 1
        $consecutive = [int]$pool.circuit_breaker.consecutive_429s

        if ($consecutive -ge $circuitBreakerThreshold) {
            $pool.circuit_breaker.state = "open"
            $pool.circuit_breaker.opened_at = (Get-Date).ToUniversalTime().ToString("o")
            # Exponential backoff: 5min * 2^(trips-1), capped at 60min
            $tripCount = [math]::Floor(($consecutive - $circuitBreakerThreshold) / $circuitBreakerThreshold) + 1
            $cooldownMin = [math]::Min($baseCooldownMinutes * [math]::Pow(2, $tripCount - 1), 60)
            $pool.cooldown_until = (Get-Date).ToUniversalTime().AddMinutes($cooldownMin).ToString("o")
            Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [rate-pool] CIRCUIT BREAKER OPEN — $consecutive consecutive 429s, cooldown ${cooldownMin}m" -ForegroundColor Red
        }
    } else {
        # Successful request resets the consecutive 429 counter
        if ([int]$pool.circuit_breaker.consecutive_429s -gt 0) {
            Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [rate-pool] Successful request — resetting 429 counter" -ForegroundColor Green
        }
        $pool.circuit_breaker.consecutive_429s = 0
        if ($pool.circuit_breaker.state -eq "open") {
            $pool.circuit_breaker.state = "closed"
            $pool.circuit_breaker.opened_at = $null
            $pool.cooldown_until = $null
            Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [rate-pool] Circuit breaker CLOSED after successful request" -ForegroundColor Green
        }
    }

    Write-RatePool -Pool $pool
}

function Test-CircuitBreaker {
    <#
    .SYNOPSIS
    Returns $true if the circuit breaker is OPEN and cooldown has not expired.
    Returns $false if safe to proceed.
    #>
    $pool = Read-RatePool
    $ts = Get-Date -Format "HH:mm:ss"

    if ($pool.circuit_breaker.state -ne "open") {
        return $false
    }

    # Check if cooldown has expired
    if ($pool.cooldown_until) {
        $cooldownEnd = [datetime]::Parse($pool.cooldown_until).ToUniversalTime()
        $now = (Get-Date).ToUniversalTime()
        if ($now -ge $cooldownEnd) {
            Write-Host "[$ts] [rate-pool] Cooldown expired — transitioning to half-open" -ForegroundColor Yellow
            # Transition to half-open: allow one request through
            $pool.circuit_breaker.state = "half-open"
            Write-RatePool -Pool $pool
            return $false
        } else {
            $remaining = ($cooldownEnd - $now).TotalMinutes
            Write-Host "[$ts] [rate-pool] Circuit breaker OPEN — $([math]::Round($remaining, 1))m remaining in cooldown" -ForegroundColor Red
            return $true
        }
    }

    return $true
}

function Test-BudgetAvailable {
    <#
    .SYNOPSIS
    Checks remaining budget across all tiers.
    Returns a hashtable with:
      - Available: $true/$false (whether any spawning is allowed)
      - MaxParallelism: suggested max agents to spawn (1 when low, 0 when exhausted)
      - HighPriorityOnly: $true when budget < 20%, only high-priority work
      - BudgetPct: lowest budget percentage across all tiers
    #>
    $pool = Read-RatePool
    $ts = Get-Date -Format "HH:mm:ss"

    $result = @{
        Available = $true
        MaxParallelism = 5  # Default max parallelism
        HighPriorityOnly = $false
        BudgetPct = 100.0
    }

    # Calculate lowest budget percentage across tiers
    $lowestPct = 100.0
    foreach ($tier in @("premium", "standard", "fast")) {
        if ($pool.requests.$tier) {
            $count = [int]$pool.requests.$tier.count
            $limit = [int]$pool.requests.$tier.limit
            if ($limit -gt 0) {
                $remaining = [math]::Max(0, $limit - $count)
                $pct = ($remaining / $limit) * 100
                if ($pct -lt $lowestPct) {
                    $lowestPct = $pct
                }
            }
        }
    }
    $result.BudgetPct = [math]::Round($lowestPct, 1)

    if ($lowestPct -lt 5) {
        $result.Available = $false
        $result.MaxParallelism = 0
        $result.HighPriorityOnly = $true
        Write-Host "[$ts] [rate-pool] BUDGET EXHAUSTED ($($result.BudgetPct)% remaining) — skipping agent spawn" -ForegroundColor Red
    } elseif ($lowestPct -lt 20) {
        $result.MaxParallelism = 1
        $result.HighPriorityOnly = $true
        Write-Host "[$ts] [rate-pool] Budget LOW ($($result.BudgetPct)% remaining) — parallelism=1, high-priority only" -ForegroundColor Yellow
    } else {
        Write-Host "[$ts] [rate-pool] Budget OK ($($result.BudgetPct)% remaining)" -ForegroundColor DarkGray
    }

    return $result
}

function Get-IssuePriority {
    <#
    .SYNOPSIS
    Classifies an issue's priority based on its labels.
    Returns: "high", "medium", or "low"
    - High: CI failures, bugs, security (labels: ci-failure, type:bug, squad:worf)
    - Medium: Feature work, improvements
    - Low: Research, docs, content
    #>
    param(
        [string[]]$Labels = @()
    )

    $highLabels = @("ci-failure", "type:bug", "bug", "squad:worf", "security", "security-alert",
                     "github-alert", "deploy-failure", "critical", "urgent", "p0", "hotfix")
    $lowLabels  = @("squad:seven", "research", "documentation", "docs", "content", "blog",
                     "tech-news", "podcast", "enhancement:docs")

    foreach ($label in $Labels) {
        $lbl = $label.ToLower().Trim()
        if ($highLabels -contains $lbl) { return "high" }
    }
    foreach ($label in $Labels) {
        $lbl = $label.ToLower().Trim()
        if ($lowLabels -contains $lbl) { return "low" }
    }

    return "medium"
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

# Function to send Teams alert (uses per-channel webhook — Issue #821)
function Send-TeamsAlert {
    param(
        [int]$Round,
        [int]$ConsecutiveFailures,
        [int]$ExitCode,
        [hashtable]$Metrics = @{}
    )
    
    # Resolve webhook URL: alerts channel → general → legacy fallback
    . "$PSScriptRoot\scripts\Get-ChannelWebhookUrl.ps1"
    $webhookUrl = Get-ChannelWebhookUrl -ChannelKey "alerts"
    
    if (-not $webhookUrl) {
        # Fallback: try the legacy file directly (in case dot-source fails)
        if (Test-Path $teamsWebhookFile) {
            $webhookUrl = (Get-Content -Path $teamsWebhookFile -Raw -Encoding utf8).Trim()
        }
    }
    
    if ([string]::IsNullOrWhiteSpace($webhookUrl)) {
        Write-Host "[$timestamp] Warning: No Teams webhook URL found for alerts channel" -ForegroundColor Yellow
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
    # Graceful shutdown sentinel (Issue #847)
    if (Test-Path $ralphStopSentinel) {
        $ts = Get-Date -Format "HH:mm:ss"
        Write-Host "[$ts] Graceful shutdown requested (sentinel: $ralphStopSentinel)" -ForegroundColor Yellow
        Remove-Item $ralphStopSentinel -Force -ErrorAction SilentlyContinue
        break
    }

    # Re-read config every round for hot-reload of interval/throttle settings
    $intervalMinutes = Read-RalphConfig

    $round++
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $displayTime = Get-Date -Format "HH:mm:ss"
    $startTime = Get-Date

    # --- Graceful shutdown sentinel check (#847) ---
    $stopSentinel = Join-Path $env:USERPROFILE ".squad\ralph-stop"
    if (Test-Path $stopSentinel) {
        Write-Host "[$displayTime] [ralph] Stop sentinel detected — exiting gracefully after this round" -ForegroundColor Yellow
        Remove-Item $stopSentinel -Force -ErrorAction SilentlyContinue
        $shouldExitAfterRound = $true
    } else {
        $shouldExitAfterRound = $false
    }

    # --- Throttle mode: read interval from config (#847) ---
    $configPath = Join-Path $env:USERPROFILE ".squad\ralph-config.json"
    if (Test-Path $configPath) {
        try {
            $ralphConfig = Get-Content $configPath -Raw | ConvertFrom-Json
            if ($ralphConfig.intervalMinutes -and $ralphConfig.intervalMinutes -gt 0) {
                $intervalMinutes = [int]$ralphConfig.intervalMinutes
                Write-Host "[$displayTime] [ralph] Throttle mode: interval set to $intervalMinutes minutes" -ForegroundColor DarkYellow
            }
        } catch {
            Write-Host "[$displayTime] [ralph] Warning: could not parse ralph-config.json, using default interval ($intervalMinutes min)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "[$displayTime] Ralph Round $round started" -ForegroundColor Cyan
    try { $Host.UI.RawUI.WindowTitle = "Ralph Watch - Round $round"; Write-Host "`e]0;Ralph Watch - Round $round`a" -NoNewline } catch {}
    Write-Host "============================================" -ForegroundColor Cyan
    
    # Write heartbeat BEFORE round (status: running)
    Update-Heartbeat -Round $round -Status "running" -ConsecutiveFailures $consecutiveFailures
    
    # ── Step -1: Pre-round health check (Issue #988) ──────────────────────────
    # Runs at the TOP of every round — auto-detects and fixes the 5 common failure modes
    # before any agency work starts. This is the canonical entry point for Ralph self-healing.
    $healthResult = Invoke-RalphHealthCheck -Round $round
    if ($healthResult.Healed.Count -gt 0) {
        Write-Host "[$displayTime] [health] Healed $($healthResult.Healed.Count) issue(s): $($healthResult.Healed -join ' | ')" -ForegroundColor Yellow
    }
    if ($healthResult.Warnings.Count -gt 0) {
        Write-Host "[$displayTime] [health] $($healthResult.Warnings.Count) warning(s): $($healthResult.Warnings -join ' | ')" -ForegroundColor Magenta
    }

    # Step -0.5: Machine capability discovery (Issue #987 — run once per startup, then every 50 rounds)
    $capDiscoveryScript = Join-Path (Get-Location) "scripts\discover-machine-capabilities.ps1"
    if (($round -eq 1 -or $round % 50 -eq 0) -and (Test-Path $capDiscoveryScript)) {
        Write-Host "[$timestamp] [cap-discover] Running machine capability scan..." -ForegroundColor Cyan
        try {
            & $capDiscoveryScript | Out-Null
            $capFile = Join-Path $env:USERPROFILE ".squad\machine-capabilities.json"
            if (Test-Path $capFile) {
                $capManifest = Get-Content $capFile -Raw -Encoding utf8 | ConvertFrom-Json
                Write-Host "[$timestamp] [cap-discover] Capabilities: $($capManifest.capabilities -join ', ')" -ForegroundColor Green
                if ($capManifest.missing.Count -gt 0) {
                    Write-Host "[$timestamp] [cap-discover] Missing: $($capManifest.missing -join ', ')" -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host "[$timestamp] [cap-discover] Warning: capability scan failed: $($_.Exception.Message)" -ForegroundColor Yellow
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
    
    # -------------------------------------------------------------------
    # Rate Coordination Guards (Issue #825)
    # Check circuit breaker and budget BEFORE spawning any agents.
    # -------------------------------------------------------------------
    $skipRound = $false

    # Guard 1: Circuit breaker — if open and cooling down, skip this round
    if (Test-CircuitBreaker) {
        Write-Host "[$displayTime] [rate-pool] Skipping round $round — circuit breaker is OPEN" -ForegroundColor Red
        Write-RalphLog -Round $round -Timestamp $timestamp -ExitCode 0 -DurationSeconds 0 -ConsecutiveFailures $consecutiveFailures -Status "CIRCUIT_BREAKER" -Metrics @{ issuesClosed = 0; prsMerged = 0; agentActions = 0 }
        Update-Heartbeat -Round $round -Status "circuit_breaker" -ConsecutiveFailures $consecutiveFailures
        $skipRound = $true
    }

    # Guard 2: Budget check — adjust parallelism or skip if exhausted
    $budgetStatus = $null
    if (-not $skipRound) {
        $budgetStatus = Test-BudgetAvailable
        if (-not $budgetStatus.Available) {
            Write-Host "[$displayTime] [rate-pool] Skipping round $round — budget exhausted ($($budgetStatus.BudgetPct)%)" -ForegroundColor Red
            Write-RalphLog -Round $round -Timestamp $timestamp -ExitCode 0 -DurationSeconds 0 -ConsecutiveFailures $consecutiveFailures -Status "BUDGET_EXHAUSTED" -Metrics @{ issuesClosed = 0; prsMerged = 0; agentActions = 0 }
            Update-Heartbeat -Round $round -Status "budget_exhausted" -ConsecutiveFailures $consecutiveFailures
            $skipRound = $true
        }
    }

    if ($skipRound) {
        # Still sleep and continue to next round
        $endTime = Get-Date
        $durationSeconds = ($endTime - $startTime).TotalSeconds
        $endDisplayTime = Get-Date -Format "HH:mm:ss"
        $nextRoundTime = (Get-Date).AddSeconds($intervalMinutes * 60)
        Write-Host "[$endDisplayTime] Next round at $($nextRoundTime.ToString('HH:mm:ss')) (in $intervalMinutes minutes)" -ForegroundColor DarkGray
        Start-Sleep -Seconds ($intervalMinutes * 60)
        continue
    }

    # Log budget + priority info for this round
    $ratePoolInfo = ""
    if ($budgetStatus) {
        $ratePoolInfo = " | Budget=$($budgetStatus.BudgetPct)% MaxPar=$($budgetStatus.MaxParallelism)"
        if ($budgetStatus.HighPriorityOnly) { $ratePoolInfo += " [HIGH-PRI-ONLY]" }
    }
    Write-Host "[$displayTime] [rate-pool] Round $round proceeding$ratePoolInfo" -ForegroundColor DarkCyan

    # Update rate pool: register this machine's activity for the round
    Update-RatePool -Tier "standard" -Got429 $false

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

        # Priority lane injection (Issue #825): when budget is low, add constraints to prompt
        $effectivePrompt = $prompt
        if ($budgetStatus -and $budgetStatus.HighPriorityOnly) {
            $priorityDirective = @"

RATE LIMIT ACTIVE (Budget: $($budgetStatus.BudgetPct)%): Only work on HIGH PRIORITY issues this round.
High priority = labels: ci-failure, type:bug, bug, squad:worf, security, security-alert, critical, urgent, p0, hotfix.
Skip research, docs, content, blog, podcast, and general feature work.
Max parallelism: $($budgetStatus.MaxParallelism) agent(s).
"@
            $effectivePrompt = $prompt + "`n" + $priorityDirective
            Write-Host "[$displayTime] [rate-pool] Priority lane ACTIVE — injected high-priority constraint into prompt" -ForegroundColor Yellow
        }

        [System.IO.File]::WriteAllText($promptFile, $effectivePrompt, [System.Text.Encoding]::UTF8)
        
        # Model circuit breaker: select model based on rate-limit state
        $modelForRound = Get-CurrentModel
        if ([string]::IsNullOrWhiteSpace($modelForRound)) {
            $modelForRound = "claude-sonnet-4.6"
            Write-Host "[$displayTime] [model-cb] WARNING: model was null/empty, falling back to $modelForRound" -ForegroundColor Yellow
        }
        Write-Host "[$displayTime] [model-cb] Using model: $modelForRound (state: $((Get-CircuitBreakerState).state))" -ForegroundColor DarkCyan
        
        # Create a thin wrapper script that reads the prompt from file and calls agency
        # This avoids ALL Start-Process argument quoting issues
        $wrapperScript = Join-Path $env:TEMP "ralph-round-$round.ps1"
        @"
`$p = [System.IO.File]::ReadAllText('$($promptFile.Replace("'","''"))')
agency copilot --yolo --autopilot --agent squad --mcp mail --mcp calendar --model $modelForRound -p `$p --resume=$roundSessionId
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

        # Rate pool: detect 429s and update pool (Issue #825)
        # Exit code 29 is our convention for 429/rate-limit, but also check for
        # common exit codes that signal API rate limiting (exit code 1 with
        # rate-limit patterns in agency logs)
        $got429 = $false
        if ($exitCode -eq 29) {
            $got429 = $true
        } elseif ($exitCode -ne 0) {
            # Check recent agency logs for 429 indicators
            $latestLogDir = Get-ChildItem "$env:USERPROFILE\.agency\logs" -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latestLogDir) {
                $latestLog = Get-ChildItem $latestLogDir.FullName -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($latestLog) {
                    $tail = Get-Content $latestLog.FullName -Tail 50 -ErrorAction SilentlyContinue
                    if ($tail -match "429|rate.?limit|too.?many.?requests|quota.?exceeded") {
                        $got429 = $true
                        Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [rate-pool] Detected 429/rate-limit in agency logs" -ForegroundColor Yellow
                    }
                }
            }
        }
        Update-RatePool -Tier "standard" -Got429 $got429

        # Model circuit breaker: update state based on rate limit detection
        if ($got429) {
            Update-CircuitBreakerOnRateLimit
        } elseif ($exitCode -eq 0) {
            Update-CircuitBreakerOnSuccess
        }

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

    # Self-healing remediation based on failure tier (Issue #988)
    if ($consecutiveFailures -ge 3) {
        Invoke-PostFailureRemediation -ConsecutiveFailures $consecutiveFailures -Round $round
    }
    
    # --- Graceful shutdown: exit after round if sentinel was detected (#847) ---
    if ($shouldExitAfterRound) {
        Write-Host "[$endDisplayTime] [ralph] Graceful shutdown complete after round $round" -ForegroundColor Yellow
        Update-Heartbeat -Round $round -Status "stopped" -ExitCode $exitCode -DurationSeconds $durationSeconds -ConsecutiveFailures $consecutiveFailures -Metrics $metrics
        break
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
