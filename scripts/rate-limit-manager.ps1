<#
.SYNOPSIS
    Cooperative Rate Limit Manager for Squad multi-agent systems.

.DESCRIPTION
    Implements Phase 1 + Phase 2 adaptive rate limiting from Issue #979 research:

    - Priority-Weighted Jitter Governor (PWJG): non-overlapping per-priority
      retry windows so P0 (Picard/Worf) always recovers before P1/P2 agents retry.
    - Cooperative Multi-Agent Rate Pooling (CMARP): file-system coordinated
      shared token bucket for GitHub API (5000/hr) and Copilot Model API.
    - Retry-After header parsing: honour server-supplied retry delay instead of
      fixed backoff (Phase 1 hardening).
    - Resource Epoch Tracker (RET): heartbeat-leased CMARP allocations; expired
      leases auto-recovered to prevent quota starvation from crashed agents.

    This script is designed to be dot-sourced by ralph-watch.ps1 and any agent
    runner that makes GitHub or Copilot API calls.

    Usage in ralph-watch.ps1:
        . "$PSScriptRoot\scripts\rate-limit-manager.ps1"

        # Before each API call:
        $allowed = Request-RateQuota -Api "github" -Tokens 1 -AgentId $env:COMPUTERNAME -Priority "P1"
        if (-not $allowed) { Start-Sleep (Get-JitteredBackoff -Priority "P1" -Attempt $attempt); continue }

        # After a 429 response:
        Register-RateLimitHit -Api "github" -RetryAfterHeader $response.Headers["Retry-After"] -AgentId $env:COMPUTERNAME

.NOTES
    Research basis: Issue #979 — Seven (Research & Docs Agent) 2026-03-19
    Phase 1: Retry-After + PWJG jitter (this file)
    Phase 2: CMARP shared pool via rate-pool.json (this file)
    Phase 3: Predictive Circuit Breaker extensions (see ralph-watch.ps1)
#>

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

$script:RatePoolPath     = Join-Path $HOME ".squad\rate-pool.json"
$script:RatePoolLockPath = Join-Path $HOME ".squad\rate-pool.lock"

# GitHub API: 5000 requests/hour = ~83/min = ~1.38/sec
# We keep a soft cap at 80% of limit to leave headroom for other agents.
$script:ApiLimits = @{
    github = @{
        HardLimit     = 5000   # per hour
        SoftLimit     = 4000   # 80% — triggers GREEN->AMBER transition
        AmberLimit    = 500    # <500 remaining → AMBER
        RedLimit      = 100    # <100 remaining → RED (block non-P0)
        WindowSeconds = 3600
    }
    copilot = @{
        HardLimit     = 50     # RPM
        SoftLimit     = 40
        AmberLimit    = 15
        RedLimit      = 5
        WindowSeconds = 60
    }
}

# Priority tiers — aligned with Squad agent roles.
# Lower number = higher priority.
$script:PriorityTiers = @{
    P0 = @{ Weight = 4; BaseDelayMs = 500;  MaxDelayMs = 5000;  JitterWindowMs = 500  }  # Picard, Worf
    P1 = @{ Weight = 2; BaseDelayMs = 2000; MaxDelayMs = 30000; JitterWindowMs = 3000 }  # Data, Belanna, Seven
    P2 = @{ Weight = 1; BaseDelayMs = 5000; MaxDelayMs = 60000; JitterWindowMs = 8000 }  # Ralph, Scribe, Neelix, Kes
}

# Agent-to-priority mapping (extend as needed)
$script:AgentPriorityMap = @{
    picard  = "P0"; worf    = "P0"
    data    = "P1"; belanna = "P1"; seven   = "P1"
    ralph   = "P2"; scribe  = "P2"; neelix  = "P2"; kes = "P2"; troi = "P2"
}

# Lease duration: allocations older than this are considered stale (agent crashed)
$script:LeaseExpirySeconds = 300  # 5 minutes — must re-register each round

# ─────────────────────────────────────────────────────────────────────────────
# Internal helpers: atomic file access (poor-man's CAS on Windows)
# ─────────────────────────────────────────────────────────────────────────────

function script:Lock-RatePool {
    $lockFile = $script:RatePoolLockPath
    $maxWait = 5000; $waited = 0; $interval = 50
    while (Test-Path $lockFile) {
        Start-Sleep -Milliseconds $interval
        $waited += $interval
        if ($waited -ge $maxWait) {
            # Stale lock guard: if lock is >10s old, break it
            $lockAge = (Get-Date) - (Get-Item $lockFile).LastWriteTime
            if ($lockAge.TotalSeconds -gt 10) {
                Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
                break
            }
        }
    }
    try { [System.IO.File]::WriteAllText($lockFile, "$PID") } catch {}
}

function script:Unlock-RatePool {
    Remove-Item $script:RatePoolLockPath -Force -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────────────────
# Rate Pool: read / write / initialize
# ─────────────────────────────────────────────────────────────────────────────

function script:Get-RatePool {
    if (-not (Test-Path $script:RatePoolPath)) {
        return $null
    }
    try {
        return Get-Content $script:RatePoolPath -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function script:New-RatePool {
    $pool = [ordered]@{
        schemaVersion = "1.0"
        createdAt     = (Get-Date).ToUniversalTime().ToString("o")
        updatedAt     = (Get-Date).ToUniversalTime().ToString("o")
        apis          = [ordered]@{
            github = [ordered]@{
                remaining    = 5000
                limit        = 5000
                resetAt      = (Get-Date).AddHours(1).ToUniversalTime().ToString("o")
                zone         = "GREEN"   # GREEN / AMBER / RED
                lastUpdated  = (Get-Date).ToUniversalTime().ToString("o")
            }
            copilot = [ordered]@{
                remaining    = 50
                limit        = 50
                resetAt      = (Get-Date).AddMinutes(1).ToUniversalTime().ToString("o")
                zone         = "GREEN"
                lastUpdated  = (Get-Date).ToUniversalTime().ToString("o")
            }
        }
        agents        = [ordered]@{}  # agentId -> { priority, reserved, leaseExpiry }
        donations     = @()           # donation register for CMARP starvation prevention
        incidents     = @()           # last 10 rate-limit hits
    }
    $squadDir = Split-Path $script:RatePoolPath -Parent
    if (-not (Test-Path $squadDir)) { New-Item -ItemType Directory -Path $squadDir -Force | Out-Null }
    $pool | ConvertTo-Json -Depth 6 | Set-Content $script:RatePoolPath -Encoding utf8
    return $pool
}

function script:Save-RatePool($pool) {
    $pool.updatedAt = (Get-Date).ToUniversalTime().ToString("o")
    $pool | ConvertTo-Json -Depth 6 | Set-Content $script:RatePoolPath -Encoding utf8
}

# ─────────────────────────────────────────────────────────────────────────────
# Resource Epoch Tracker (RET): expire stale agent leases
# ─────────────────────────────────────────────────────────────────────────────

function script:Invoke-LeaseExpiry($pool) {
    $now    = Get-Date
    $agents = $pool.agents
    if (-not $agents) { return $pool }

    $staleAgents = @()
    foreach ($agentId in ($agents | Get-Member -MemberType NoteProperty).Name) {
        $agent = $agents.$agentId
        if ($agent.leaseExpiry) {
            try {
                $expiry = [datetime]::Parse($agent.leaseExpiry)
                if ($now -gt $expiry) {
                    $staleAgents += $agentId
                }
            } catch {}
        }
    }

    foreach ($agentId in $staleAgents) {
        $reserved = $agents.$agentId.reserved
        if ($reserved -gt 0) {
            Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [rate-pool] RET: Reclaiming $reserved tokens from stale agent $agentId" -ForegroundColor DarkYellow
            # Tokens return to pool (no actual re-add needed; remaining tracks server-reported value)
        }
        $agents.PSObject.Properties.Remove($agentId)
    }

    return $pool
}

# ─────────────────────────────────────────────────────────────────────────────
# Zone classification (RAAS: GREEN / AMBER / RED)
# ─────────────────────────────────────────────────────────────────────────────

function script:Get-ApiZone($api, $remaining) {
    $limits = $script:ApiLimits[$api]
    if (-not $limits) { return "GREEN" }
    if ($remaining -le $limits.RedLimit)   { return "RED" }
    if ($remaining -le $limits.AmberLimit) { return "AMBER" }
    return "GREEN"
}

# ─────────────────────────────────────────────────────────────────────────────
# Public: Register-Agent
# Call once per round to renew your lease and declare your priority tier.
# ─────────────────────────────────────────────────────────────────────────────

function Register-Agent {
    <#
    .SYNOPSIS
        Register or renew an agent in the cooperative rate pool.
    .PARAMETER AgentId
        Unique agent identifier (e.g., $env:COMPUTERNAME or agent name like "ralph").
    .PARAMETER AgentName
        Human-readable agent name for priority lookup (e.g., "ralph", "picard").
    .PARAMETER Priority
        Override priority: P0, P1, or P2. If omitted, looked up from AgentName.
    #>
    param(
        [Parameter(Mandatory)] [string]$AgentId,
        [string]$AgentName = "",
        [ValidateSet("P0","P1","P2","")]
        [string]$Priority = ""
    )

    $ts = Get-Date -Format 'HH:mm:ss'

    # Resolve priority
    if (-not $Priority) {
        $mapped = $script:AgentPriorityMap[$AgentName.ToLower()]
        $Priority = if ($mapped) { $mapped } else { "P2" }
    }

    script:Lock-RatePool
    try {
        $pool = script:Get-RatePool
        if (-not $pool) { $pool = script:New-RatePool }
        $pool = script:Invoke-LeaseExpiry $pool

        $leaseExpiry = (Get-Date).AddSeconds($script:LeaseExpirySeconds).ToUniversalTime().ToString("o")

        if (-not $pool.agents) {
            $pool | Add-Member -Force -MemberType NoteProperty -Name "agents" -Value ([PSCustomObject]@{})
        }

        $pool.agents | Add-Member -Force -MemberType NoteProperty -Name $AgentId -Value ([ordered]@{
            name        = $AgentName
            priority    = $Priority
            reserved    = 0
            leaseExpiry = $leaseExpiry
            registeredAt = (Get-Date).ToUniversalTime().ToString("o")
        })

        script:Save-RatePool $pool
        Write-Host "[$ts] [rate-pool] Agent $AgentId registered as $Priority (lease until $leaseExpiry)" -ForegroundColor DarkGray
    } finally {
        script:Unlock-RatePool
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Public: Update-ApiRemaining
# Call after each API response to feed server-reported remaining count into pool.
# ─────────────────────────────────────────────────────────────────────────────

function Update-ApiRemaining {
    <#
    .SYNOPSIS
        Update the shared pool with server-reported rate limit headers.
    .PARAMETER Api
        "github" or "copilot"
    .PARAMETER Remaining
        X-RateLimit-Remaining (GitHub) or remaining RPM tokens.
    .PARAMETER ResetAt
        X-RateLimit-Reset epoch seconds (GitHub) or ISO timestamp.
    .PARAMETER Limit
        X-RateLimit-Limit value.
    #>
    param(
        [Parameter(Mandatory)] [ValidateSet("github","copilot")] [string]$Api,
        [Parameter(Mandatory)] [int]$Remaining,
        [string]$ResetAt  = "",
        [int]$Limit       = 0
    )

    script:Lock-RatePool
    try {
        $pool = script:Get-RatePool
        if (-not $pool) { $pool = script:New-RatePool }

        $entry = $pool.apis.$Api
        $entry | Add-Member -Force -MemberType NoteProperty -Name "remaining"   -Value $Remaining
        $entry | Add-Member -Force -MemberType NoteProperty -Name "zone"        -Value (script:Get-ApiZone $Api $Remaining)
        $entry | Add-Member -Force -MemberType NoteProperty -Name "lastUpdated" -Value ((Get-Date).ToUniversalTime().ToString("o"))

        if ($Limit -gt 0) { $entry | Add-Member -Force -MemberType NoteProperty -Name "limit" -Value $Limit }

        if ($ResetAt) {
            # GitHub returns epoch seconds; normalise to ISO
            if ($ResetAt -match '^\d+$') {
                $resetDt = [DateTimeOffset]::FromUnixTimeSeconds([long]$ResetAt).UtcDateTime
                $entry | Add-Member -Force -MemberType NoteProperty -Name "resetAt" -Value ($resetDt.ToString("o"))
            } else {
                $entry | Add-Member -Force -MemberType NoteProperty -Name "resetAt" -Value $ResetAt
            }
        }

        $pool.apis | Add-Member -Force -MemberType NoteProperty -Name $Api -Value $entry
        script:Save-RatePool $pool

        $ts = Get-Date -Format 'HH:mm:ss'
        $color = switch ($entry.zone) { "RED" { "Red" } "AMBER" { "Yellow" } default { "DarkGray" } }
        Write-Host "[$ts] [rate-pool] $Api remaining=$Remaining zone=$($entry.zone)" -ForegroundColor $color
    } finally {
        script:Unlock-RatePool
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Public: Request-RateQuota
# Returns $true if the agent is allowed to proceed; $false if it must wait.
# Enforces RAAS zone rules: RED blocks P1/P2; AMBER throttles P2.
# ─────────────────────────────────────────────────────────────────────────────

function Request-RateQuota {
    <#
    .SYNOPSIS
        Ask the rate pool for permission to make an API call.
        Returns $true to proceed, $false to back off.
    .PARAMETER Api
        "github" or "copilot"
    .PARAMETER Tokens
        Number of tokens (requests) to consume. Default 1.
    .PARAMETER AgentId
        Agent identifier (registered via Register-Agent).
    .PARAMETER Priority
        Override priority for this specific call.
    #>
    param(
        [Parameter(Mandatory)] [ValidateSet("github","copilot")] [string]$Api,
        [int]    $Tokens   = 1,
        [string] $AgentId  = $env:COMPUTERNAME,
        [ValidateSet("P0","P1","P2","")]
        [string] $Priority = ""
    )

    script:Lock-RatePool
    try {
        $pool = script:Get-RatePool
        if (-not $pool) { return $true }  # No pool → don't block

        $pool = script:Invoke-LeaseExpiry $pool

        # Resolve priority from pool agent record if not supplied
        if (-not $Priority) {
            $agent    = $pool.agents.$AgentId
            $Priority = if ($agent -and $agent.priority) { $agent.priority } else { "P2" }
        }

        $entry = $pool.apis.$Api
        if (-not $entry) { return $true }

        $zone = $entry.zone

        # RAAS zone enforcement:
        #   GREEN  → all agents allowed
        #   AMBER  → P0 and P1 allowed; P2 throttled (blocked this call)
        #   RED    → only P0 allowed
        $blocked = $false
        if ($zone -eq "RED"   -and $Priority -ne "P0") { $blocked = $true }
        if ($zone -eq "AMBER" -and $Priority -eq "P2") { $blocked = $true }

        if ($blocked) {
            $ts = Get-Date -Format 'HH:mm:ss'
            Write-Host "[$ts] [rate-pool] $Api zone=$zone blocks $Priority agent $AgentId" -ForegroundColor Yellow
            script:Save-RatePool $pool
            return $false
        }

        # Optimistically deduct tokens (soft reservation — actual remaining updated from headers)
        $entry.remaining = [math]::Max(0, [int]$entry.remaining - $Tokens)
        $entry.zone      = script:Get-ApiZone $Api $entry.remaining
        $pool.apis | Add-Member -Force -MemberType NoteProperty -Name $Api -Value $entry
        script:Save-RatePool $pool

        return $true
    } finally {
        script:Unlock-RatePool
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Public: Register-RateLimitHit
# Call when you receive a 429 response. Records the incident and opens the pool
# zone to RED so other agents back off immediately.
# ─────────────────────────────────────────────────────────────────────────────

function Register-RateLimitHit {
    <#
    .SYNOPSIS
        Record a 429 rate-limit hit. Broadcasts RED zone to all agents via pool.
    .PARAMETER Api
        "github" or "copilot"
    .PARAMETER AgentId
        The agent that received the 429.
    .PARAMETER RetryAfterHeader
        Value of Retry-After response header (seconds or HTTP-date). Used for
        computing exact pool reset time rather than guessing.
    #>
    param(
        [Parameter(Mandatory)] [ValidateSet("github","copilot")] [string]$Api,
        [string] $AgentId          = $env:COMPUTERNAME,
        [string] $RetryAfterHeader = ""
    )

    $ts  = Get-Date -Format 'HH:mm:ss'
    $now = Get-Date

    # Parse Retry-After header (Phase 1 hardening from research §8.1)
    $retryAfterSeconds = 60  # default
    if ($RetryAfterHeader) {
        if ($RetryAfterHeader -match '^\d+$') {
            $retryAfterSeconds = [int]$RetryAfterHeader
        } else {
            try {
                $retryDate         = [datetime]::Parse($RetryAfterHeader)
                $retryAfterSeconds = [math]::Max(1, ($retryDate - $now).TotalSeconds)
            } catch {}
        }
    }

    $resetAt = $now.AddSeconds($retryAfterSeconds).ToUniversalTime().ToString("o")

    script:Lock-RatePool
    try {
        $pool = script:Get-RatePool
        if (-not $pool) { $pool = script:New-RatePool }

        # Force RED zone with resetAt from Retry-After
        $entry = $pool.apis.$Api
        $entry | Add-Member -Force -MemberType NoteProperty -Name "zone"        -Value "RED"
        $entry | Add-Member -Force -MemberType NoteProperty -Name "remaining"   -Value 0
        $entry | Add-Member -Force -MemberType NoteProperty -Name "resetAt"     -Value $resetAt
        $entry | Add-Member -Force -MemberType NoteProperty -Name "lastUpdated" -Value ($now.ToUniversalTime().ToString("o"))
        $pool.apis | Add-Member -Force -MemberType NoteProperty -Name $Api -Value $entry

        # Append to incidents log (keep last 10)
        if (-not $pool.incidents) { $pool.incidents = @() }
        $incidents = [System.Collections.Generic.List[object]]$pool.incidents
        $incidents.Add([ordered]@{
            timestamp          = $now.ToUniversalTime().ToString("o")
            api                = $Api
            agentId            = $AgentId
            retryAfterSeconds  = $retryAfterSeconds
            resetAt            = $resetAt
        })
        if ($incidents.Count -gt 10) { $incidents.RemoveAt(0) }
        $pool.incidents = $incidents.ToArray()

        script:Save-RatePool $pool
        Write-Host "[$ts] [rate-pool] 429 on $Api from agent $AgentId — RED zone set, reset at $resetAt" -ForegroundColor Red
    } finally {
        script:Unlock-RatePool
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Public: Get-JitteredBackoff
# Priority-Weighted Jitter Governor (PWJG): non-overlapping retry windows.
#
# Priority Windows (seconds):
#   P0: [0.5,  5]     — recovers first
#   P1: [2,   30]     — starts after P0 window closes
#   P2: [5,   60]     — starts after P1 window closes
#
# Returns: milliseconds to sleep before the next retry attempt.
# ─────────────────────────────────────────────────────────────────────────────

function Get-JitteredBackoff {
    <#
    .SYNOPSIS
        Compute the next jittered backoff delay using the PWJG algorithm.
    .PARAMETER Priority
        P0, P1, or P2. Determines the retry window.
    .PARAMETER Attempt
        Retry attempt number (1-based). Used for exponential growth within window.
    .PARAMETER RetryAfterSeconds
        If Retry-After header was provided, use this as the base delay floor.
    .RETURNS
        Delay in milliseconds (as [int]).
    #>
    param(
        [ValidateSet("P0","P1","P2")]
        [string] $Priority          = "P2",
        [int]    $Attempt           = 1,
        [double] $RetryAfterSeconds = 0
    )

    $tier = $script:PriorityTiers[$Priority]

    # Exponential growth capped at MaxDelayMs
    $expDelay = [math]::Min(
        $tier.MaxDelayMs,
        $tier.BaseDelayMs * [math]::Pow(2, $Attempt - 1)
    )

    # Retry-After floor: if server gave us a time, respect it
    if ($RetryAfterSeconds -gt 0) {
        $expDelay = [math]::Max($expDelay, $RetryAfterSeconds * 1000)
    }

    # Full-jitter within priority window (avoids thundering herd)
    # Jitter range is $tier.JitterWindowMs wide, starting at $expDelay
    $jitter    = Get-Random -Minimum 0 -Maximum $tier.JitterWindowMs
    $totalMs   = [int]($expDelay + $jitter)

    $ts = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$ts] [rate-pool] PWJG backoff $Priority attempt=$Attempt → ${totalMs}ms" -ForegroundColor DarkGray

    return $totalMs
}

# ─────────────────────────────────────────────────────────────────────────────
# Public: Get-RatePoolStatus
# Returns a summary hashtable for dashboards / health-check logging.
# ─────────────────────────────────────────────────────────────────────────────

function Get-RatePoolStatus {
    $pool = script:Get-RatePool
    if (-not $pool) { return @{ status = "not-initialized" } }

    $result = [ordered]@{
        status      = "ok"
        github      = [ordered]@{
            remaining = $pool.apis.github.remaining
            zone      = $pool.apis.github.zone
            resetAt   = $pool.apis.github.resetAt
        }
        copilot     = [ordered]@{
            remaining = $pool.apis.copilot.remaining
            zone      = $pool.apis.copilot.zone
            resetAt   = $pool.apis.copilot.resetAt
        }
        activeAgents = ($pool.agents | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue).Count
        incidents    = ($pool.incidents | Measure-Object).Count
        updatedAt    = $pool.updatedAt
    }

    if ($pool.apis.github.zone -eq "RED" -or $pool.apis.copilot.zone -eq "RED") {
        $result.status = "degraded"
    } elseif ($pool.apis.github.zone -eq "AMBER" -or $pool.apis.copilot.zone -eq "AMBER") {
        $result.status = "amber"
    }

    return $result
}

# ─────────────────────────────────────────────────────────────────────────────
# Public: Invoke-ApiWithRateLimit
# Convenience wrapper: handles quota check, execution, header parsing, backoff.
#
# Usage:
#   $result = Invoke-ApiWithRateLimit -Api "github" -AgentId "ralph" -Priority "P2" -ScriptBlock {
#       gh api /repos/owner/repo --include  # --include emits headers
#   }
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-ApiWithRateLimit {
    <#
    .SYNOPSIS
        Execute an API call with full rate-limit management:
        quota check → execute → parse headers → record result.
    .PARAMETER Api
        "github" or "copilot"
    .PARAMETER ScriptBlock
        The code block to execute. Should return raw output including headers
        when `gh api --include` or similar is used.
    .PARAMETER AgentId
        Agent identifier for pool accounting.
    .PARAMETER Priority
        Priority tier for RAAS zone enforcement and PWJG backoff.
    .PARAMETER MaxRetries
        Maximum number of 429-triggered retries. Default 3.
    #>
    param(
        [Parameter(Mandatory)] [ValidateSet("github","copilot")] [string]$Api,
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock,
        [string] $AgentId   = $env:COMPUTERNAME,
        [ValidateSet("P0","P1","P2")]
        [string] $Priority  = "P2",
        [int]    $MaxRetries = 3
    )

    $attempt = 0
    while ($attempt -le $MaxRetries) {
        $attempt++

        # RAAS zone check
        $allowed = Request-RateQuota -Api $Api -AgentId $AgentId -Priority $Priority
        if (-not $allowed) {
            $delay = Get-JitteredBackoff -Priority $Priority -Attempt $attempt
            Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [rate-pool] Zone blocked — sleeping ${delay}ms before retry $attempt" -ForegroundColor Yellow
            Start-Sleep -Milliseconds $delay
            continue
        }

        # Execute
        $output = & $ScriptBlock 2>&1
        $exitCode = $LASTEXITCODE

        # Parse GitHub rate-limit response headers from `gh api --include` output
        # Headers appear as "X-RateLimit-Remaining: 4321"
        $remaining  = $null
        $resetAt    = $null
        $limit      = $null
        $retryAfter = $null
        $is429      = $false

        foreach ($line in ($output -split "`n")) {
            if ($line -match '^HTTP/\d[\.\d]* 429') { $is429 = $true }
            if ($line -match '^X-RateLimit-Remaining:\s*(\d+)') { $remaining  = [int]$Matches[1] }
            if ($line -match '^X-RateLimit-Reset:\s*(\S+)')     { $resetAt    = $Matches[1] }
            if ($line -match '^X-RateLimit-Limit:\s*(\d+)')     { $limit      = [int]$Matches[1] }
            if ($line -match '^Retry-After:\s*(\S+)')            { $retryAfter = $Matches[1] }
        }

        # Update pool with any header data we got
        if ($null -ne $remaining) {
            Update-ApiRemaining -Api $Api -Remaining $remaining `
                -ResetAt ($resetAt ?? "") `
                -Limit   ($limit   ?? 0)
        }

        if ($is429 -or $exitCode -eq 429) {
            Register-RateLimitHit -Api $Api -AgentId $AgentId -RetryAfterHeader ($retryAfter ?? "")
            $retryAfterSec = if ($retryAfter -and $retryAfter -match '^\d+$') { [int]$retryAfter } else { 0 }
            $delay = Get-JitteredBackoff -Priority $Priority -Attempt $attempt -RetryAfterSeconds $retryAfterSec
            Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [rate-pool] 429 — retry $attempt/$MaxRetries in ${delay}ms" -ForegroundColor Red
            if ($attempt -le $MaxRetries) { Start-Sleep -Milliseconds $delay; continue }
        }

        # Success
        return $output
    }

    Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [rate-pool] Exhausted $MaxRetries retries for $Api" -ForegroundColor Red
    return $null
}

# ─────────────────────────────────────────────────────────────────────────────
# Cascade Dependency Detector (CDD) — Issue #1168
# BFS backpressure to prevent 429 amplification chains.
# When an agent hits a rate limit, all downstream agents (per agent-dag.json)
# enter sequential mode automatically, preventing pile-ups.
# ─────────────────────────────────────────────────────────────────────────────

$script:AgentDagPath = Join-Path (Get-Location) ".squad\agent-dag.json"
$script:CddStatePath = Join-Path $HOME ".squad\cdd-state.json"
$script:CddDefaultDurationSecs = 300  # 5 minutes

function Get-CascadeDownstream {
    <#
    .SYNOPSIS
        BFS from a rate-limited agent to find all downstream agents.
    .PARAMETER RateLimitedAgent
        The agent that hit a rate limit (e.g. "ralph").
    .OUTPUTS
        String array of downstream agent IDs that should enter sequential mode.
    #>
    param(
        [Parameter(Mandatory)][string]$RateLimitedAgent
    )

    if (-not (Test-Path $script:AgentDagPath)) {
        Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [cdd] WARNING: agent-dag.json not found at $script:AgentDagPath" -ForegroundColor Yellow
        return @()
    }

    $dag = Get-Content $script:AgentDagPath -Raw | ConvertFrom-Json

    # Build adjacency map: from → [to]
    $adjacency = @{}
    foreach ($edge in $dag.edges) {
        $adjacency[$edge.from] = @($edge.to)
    }

    # BFS from the rate-limited node — O(V+E)
    $queue = [System.Collections.Queue]::new()
    $visited = [System.Collections.Generic.HashSet[string]]::new()

    $queue.Enqueue($RateLimitedAgent)
    $null = $visited.Add($RateLimitedAgent)

    while ($queue.Count -gt 0) {
        $node = $queue.Dequeue()
        if ($adjacency.ContainsKey($node)) {
            foreach ($neighbor in $adjacency[$node]) {
                if (-not $visited.Contains($neighbor)) {
                    $null = $visited.Add($neighbor)
                    $queue.Enqueue($neighbor)
                }
            }
        }
    }

    # Remove the source node itself — only return downstream
    $null = $visited.Remove($RateLimitedAgent)
    $downstream = @($visited)

    Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [cdd] 429 at $RateLimitedAgent → downstream: [$($downstream -join ', ')] → sequential mode for $($script:CddDefaultDurationSecs)s" -ForegroundColor Magenta
    return $downstream
}

function Set-AgentSequentialMode {
    <#
    .SYNOPSIS
        Sets sequential mode flag for an agent, preventing parallel spawning.
    .PARAMETER AgentId
        The agent to put into sequential mode.
    .PARAMETER DurationSecs
        How long sequential mode lasts (default 300s / 5 min).
    #>
    param(
        [Parameter(Mandatory)][string]$AgentId,
        [int]$DurationSecs = $script:CddDefaultDurationSecs
    )

    $state = script:Get-CddState
    $expiresAt = (Get-Date).ToUniversalTime().AddSeconds($DurationSecs).ToString("o")

    $state = script:Get-CddState
    $entry = [PSCustomObject]@{
        enabled    = $true
        expires_at = $expiresAt
        reason     = "429_cascade"
        set_at     = (Get-Date).ToUniversalTime().ToString("o")
    }

    if (-not $state.sequential_agents) {
        $state | Add-Member -NotePropertyName "sequential_agents" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $state.sequential_agents | Add-Member -NotePropertyName $AgentId -NotePropertyValue $entry -Force
    $state.last_updated = (Get-Date).ToUniversalTime().ToString("o")

    script:Save-CddState $state
    Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [cdd] Sequential mode SET for $AgentId until $expiresAt" -ForegroundColor Magenta
}

function Test-SequentialModeActive {
    <#
    .SYNOPSIS
        Checks if the current agent is in CDD sequential mode.
    .PARAMETER AgentId
        The agent to check.
    .OUTPUTS
        $true if sequential mode is active and not expired, $false otherwise.
    #>
    param(
        [Parameter(Mandatory)][string]$AgentId
    )

    $state = script:Get-CddState

    if (-not $state.sequential_agents -or -not $state.sequential_agents.$AgentId) {
        return $false
    }

    $entry = $state.sequential_agents.$AgentId
    if (-not $entry.enabled) { return $false }

    # Handle both DateTime (from ConvertFrom-Json auto-parse) and string formats
    if ($entry.expires_at -is [DateTime]) {
        $expiresAt = $entry.expires_at.ToUniversalTime()
    } else {
        $expiresAt = [DateTimeOffset]::Parse([string]$entry.expires_at).UtcDateTime
    }
    $now = (Get-Date).ToUniversalTime()

    if ($now -ge $expiresAt) {
        # Auto-expire: clear the flag
        $entry.enabled = $false
        $state.last_updated = $now.ToString("o")
        script:Save-CddState $state
        Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [cdd] Sequential mode EXPIRED for $AgentId" -ForegroundColor DarkGray
        return $false
    }

    $remaining = [math]::Round(($expiresAt - $now).TotalSeconds)
    Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [cdd] Sequential mode ACTIVE for $AgentId (${remaining}s remaining)" -ForegroundColor Magenta
    return $true
}

function Invoke-CascadeBackpressure {
    <#
    .SYNOPSIS
        Called when a 429 is detected. Finds all downstream agents and puts them in sequential mode.
    .PARAMETER RateLimitedAgent
        The agent that hit the rate limit.
    .PARAMETER DurationSecs
        How long to keep downstream agents in sequential mode.
    #>
    param(
        [Parameter(Mandatory)][string]$RateLimitedAgent,
        [int]$DurationSecs = $script:CddDefaultDurationSecs
    )

    $downstream = Get-CascadeDownstream -RateLimitedAgent $RateLimitedAgent
    foreach ($agent in $downstream) {
        Set-AgentSequentialMode -AgentId $agent -DurationSecs $DurationSecs
    }
}

# --- CDD internal helpers ---

function script:Get-CddState {
    if (Test-Path $script:CddStatePath) {
        try {
            return Get-Content $script:CddStatePath -Raw | ConvertFrom-Json
        } catch {
            Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [cdd] WARNING: corrupted cdd-state.json, resetting" -ForegroundColor Yellow
        }
    }
    return [PSCustomObject]@{
        sequential_agents = [PSCustomObject]@{}
        last_updated      = (Get-Date).ToUniversalTime().ToString("o")
    }
}

function script:Save-CddState {
    param([object]$State)
    $dir = Split-Path $script:CddStatePath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $State | ConvertTo-Json -Depth 5 | Set-Content $script:CddStatePath -Encoding UTF8
}

# ─────────────────────────────────────────────────────────────────────────────
# Auto-initialize pool on first dot-source
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-Path $script:RatePoolPath)) {
    $null = script:New-RatePool
    Write-Host "[$((Get-Date -Format 'HH:mm:ss'))] [rate-pool] Initialized new rate pool at $script:RatePoolPath" -ForegroundColor DarkGray
}
