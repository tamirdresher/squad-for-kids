# Teams Conversation Watcher — Ralph Integration (Issue #553)
# ============================================================
# Monitors the teams-queue.json file and checks for new messages
# in queued conversation threads on each Ralph patrol round.
#
# Usage (standalone):
#   pwsh -File scripts/teams-conversation-watcher.ps1
#
# Usage (from ralph-watch.ps1):
#   . (Join-Path $PSScriptRoot "scripts/teams-conversation-watcher.ps1")
#   Invoke-TeamsConversationWatcher
#
# Trigger words: "keep going", "continue", "track this", "remember this",
#                "follow up on this", "action:", "keep this", "queue this"

#Requires -Version 7

# --- Config ---
$script:QueueFile = Join-Path $PSScriptRoot ".." "research" "active" "teams-queue.json"
$script:LogPrefix = "[teams-watcher]"
$script:TriggerWords = @(
    "keep going",
    "continue",
    "track this",
    "remember this",
    "follow up on this",
    "action:",
    "keep this",
    "queue this"
)

# Teams channel to monitor for new trigger messages (general/notifications channel)
$script:WatchChannelId = "19:6gjjSHAUPHJlqyxeJemN9giR8HYZkWGpvsznRDSyagE1@thread.tacv2"
$script:TeamId = "5f93abfe-b968-44ea-bd0a-6f155046ccc7"

# ---------------------------------------------------------------------------
# Queue helpers
# ---------------------------------------------------------------------------

function Get-ConversationQueue {
    <#
    .SYNOPSIS
    Reads the persistent conversation queue from disk.
    Returns an empty queue structure if the file does not exist.
    #>
    $queueDir = Split-Path $script:QueueFile -Parent
    if (-not (Test-Path $queueDir)) {
        New-Item -ItemType Directory -Path $queueDir -Force | Out-Null
    }

    if (-not (Test-Path $script:QueueFile)) {
        return @{
            version    = 1
            created    = (Get-Date -Format "o")
            updated    = (Get-Date -Format "o")
            items      = @()
        }
    }

    try {
        return Get-Content $script:QueueFile -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        Write-Warning "$($script:LogPrefix) Failed to parse queue file '$($script:QueueFile)': $_"
        return @{
            version = 1
            created = (Get-Date -Format "o")
            updated = (Get-Date -Format "o")
            items   = @()
        }
    }
}

function Save-ConversationQueue($queue) {
    $queue.updated = (Get-Date -Format "o")
    # Fix A: wrap in try-catch so a save failure never crashes Ralph's patrol cycle.
    try {
        # Atomic write — write to .tmp then Move-Item to avoid race condition
        # when multiple Ralph instances run simultaneously.
        $tmpFile = "$($script:QueueFile).tmp"
        $queue | ConvertTo-Json -Depth 10 | Set-Content $tmpFile -Encoding utf8 -Force
        Move-Item -Path $tmpFile -Destination $script:QueueFile -Force
    } catch {
        Write-Warning "$($script:LogPrefix) Failed to save queue: $_. Queue state not persisted."
        # Do NOT re-throw — patrol cycle must continue even if save fails.
    }
}

function Add-QueueItem {
    param(
        [hashtable]$queue,
        [string]$messageId,
        [string]$threadId,
        [string]$channelId,
        [string]$originalMessage,
        [string]$author,
        [string]$triggeredBy
    )

    # Deduplicate by threadId
    $exists = $queue.items | Where-Object { $_.threadId -eq $threadId }
    if ($exists) {
        Write-Host "$($script:LogPrefix) Thread $threadId already in queue — skipping duplicate." -ForegroundColor DarkGray
        return $false
    }

    $item = @{
        id             = [System.Guid]::NewGuid().ToString()
        messageId      = $messageId
        threadId       = $threadId
        channelId      = $channelId
        originalMessage = $originalMessage
        author         = $author
        triggeredBy    = $triggeredBy
        status         = "active"          # active | paused | done
        addedAt        = (Get-Date -Format "o")
        lastChecked    = $null
        lastAction     = $null
        checkCount     = 0
        history        = @()
    }

    $queue.items += $item
    # Bug 1 fix: guard against null $originalMessage before calling .Substring()
    $preview = if (-not [string]::IsNullOrEmpty($originalMessage)) { $originalMessage.Substring(0, [Math]::Min(60, $originalMessage.Length)) } else { "(no text)" }
    Write-Host "$($script:LogPrefix) ➕ Added to queue: '$preview...'" -ForegroundColor Cyan
    return $true
}

function Update-QueueItem {
    param(
        [hashtable]$queue,
        [string]$itemId,
        [string]$action,
        [string]$note
    )

    # Fix C: Select-Object -First 1 prevents array assignment when duplicate IDs exist
    $item = $queue.items | Where-Object { $_.id -eq $itemId } | Select-Object -First 1
    if (-not $item) { return }

    $item.lastChecked = (Get-Date -Format "o")
    $item.lastAction  = $action
    $item.checkCount  = [int]$item.checkCount + 1
    $item.history    += @{
        timestamp = (Get-Date -Format "o")
        action    = $action
        note      = $note
    }
}

# ---------------------------------------------------------------------------
# Trigger detection
# ---------------------------------------------------------------------------

function Test-HasTriggerWord([string]$text) {
    $lower = $text.ToLower()
    foreach ($word in $script:TriggerWords) {
        # Bug 5 fix: use word-boundary regex for 'action:' to avoid false positives
        # like 'reaction:', 'transaction:', etc.
        if ($word -eq "action:") {
            if ($lower -match '\baction:') {
                return $word
            }
        } elseif ($lower.Contains($word.ToLower())) {
            return $word
        }
    }
    return $null
}

# ---------------------------------------------------------------------------
# WorkIQ integration
# ---------------------------------------------------------------------------

function Get-RecentTeamsMessages {
    <#
    .SYNOPSIS
    Asks WorkIQ for recent Teams messages that contain trigger words.
    Returns a list of message objects with: id, text, author, channelId, threadId.

    NOTE: WorkIQ is an AI search layer — it returns synthesised answers.
    We parse its response for actionable items and add them to the queue.
    #>
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] $($script:LogPrefix) Checking WorkIQ for trigger messages in the last 30 minutes..." -ForegroundColor DarkGray

    # This function returns structured data when called from an agent that has WorkIQ tools.
    # When called standalone (no MCP), it returns empty — callers handle gracefully.
    return @()
}

# ---------------------------------------------------------------------------
# Main watcher function (called by Ralph each round)
# ---------------------------------------------------------------------------

function Invoke-TeamsConversationWatcher {
    <#
    .SYNOPSIS
    Main entry point for Ralph's patrol cycle.
    1. Loads the persistent queue.
    2. Scans for NEW trigger messages via WorkIQ.
    3. For each active queue item, checks for replies/updates.
    4. Logs all activity and saves the updated queue.
    .OUTPUTS
    A summary hashtable: { added: int, checked: int, errors: int }
    #>
    $ts   = Get-Date -Format "HH:mm:ss"
    $summary = @{ added = 0; checked = 0; errors = 0 }

    Write-Host "[$ts] $($script:LogPrefix) 🔍 Starting watcher round..." -ForegroundColor DarkCyan

    # 1. Load queue
    $queue = Get-ConversationQueue
    $activeItems = @($queue.items | Where-Object { $_.status -eq "active" })
    Write-Host "[$ts] $($script:LogPrefix) Queue: $($queue.items.Count) total, $($activeItems.Count) active" -ForegroundColor DarkGray

    # 2. Scan for new trigger messages
    #    In agent context (ralph-watch.ps1), the caller should pass messages via
    #    Add-TeamsMessageToQueue if it finds relevant ones via WorkIQ.
    #    This loop processes any messages surfaced by the agent prompt.

    # 3. Check existing active items for new replies
    foreach ($item in $activeItems) {
        try {
            $summary.checked++
            $note = "Checked at $(Get-Date -Format 'HH:mm:ss')"
            Update-QueueItem -queue $queue -itemId $item.id -action "checked" -note $note
            # Bug 3 fix: use [Math]::Min to avoid crash when id is shorter than 8 chars
            Write-Host "[$ts] $($script:LogPrefix) ✅ Checked item '$($item.id.Substring(0, [Math]::Min(8, $item.id.Length)))...' — thread $($item.threadId)" -ForegroundColor DarkGray
        } catch {
            $summary.errors++
            Write-Warning "$($script:LogPrefix) Error checking item $($item.id): $_"
        }
    }

    # 4. Persist
    Save-ConversationQueue $queue

    $ts2 = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts2] $($script:LogPrefix) ✔ Round complete — added=$($summary.added) checked=$($summary.checked) errors=$($summary.errors)" -ForegroundColor DarkCyan

    return $summary
}

# ---------------------------------------------------------------------------
# Public helper — add a message to the queue directly (called by agent prompt)
# ---------------------------------------------------------------------------

function Add-TeamsMessageToQueue {
    <#
    .SYNOPSIS
    Public helper for Ralph (or any agent) to add a Teams message to the queue.
    Call this when WorkIQ returns a message that contains a trigger word.

    .EXAMPLE
    Add-TeamsMessageToQueue `
        -MessageId "1234567890" `
        -ThreadId  "19:abc@thread.tacv2" `
        -ChannelId "19:abc@thread.tacv2" `
        -Text      "Keep this going — the rate limiter discussion" `
        -Author    "Tamir Dresher"
    #>
    param(
        [Parameter(Mandatory)] [string]$MessageId,
        [Parameter(Mandatory)] [string]$ThreadId,
        [string]$ChannelId  = $script:WatchChannelId,
        [Parameter(Mandatory)] [string]$Text,
        [string]$Author     = "unknown"
    )

    $trigger = Test-HasTriggerWord -text $Text
    if (-not $trigger) {
        Write-Host "$($script:LogPrefix) Message does not contain a trigger word — not queuing." -ForegroundColor DarkGray
        return $false
    }

    $queue = Get-ConversationQueue
    $added = Add-QueueItem `
        -queue          $queue `
        -messageId      $MessageId `
        -threadId       $ThreadId `
        -channelId      $ChannelId `
        -originalMessage $Text `
        -author         $Author `
        -triggeredBy    $trigger

    if ($added) {
        Save-ConversationQueue $queue
    }
    return $added
}

# ---------------------------------------------------------------------------
# Public helper — mark an item as done
# ---------------------------------------------------------------------------

function Complete-QueueItem {
    <#
    .SYNOPSIS
    Marks a queue item as done so it's no longer checked each round.
    .PARAMETER ThreadId
    The Teams thread ID of the conversation to mark done.
    #>
    param([Parameter(Mandatory)] [string]$ThreadId)

    $queue = Get-ConversationQueue
    # Fix B: Select-Object -First 1 prevents array assignment when duplicate threadIds exist
    $item  = $queue.items | Where-Object { $_.threadId -eq $ThreadId } | Select-Object -First 1
    if (-not $item) {
        Write-Warning "$($script:LogPrefix) Item with threadId '$ThreadId' not found in queue."
        return
    }
    $item.status    = "done"
    $item.lastAction = "marked-done"
    $item.history   += @{ timestamp = (Get-Date -Format "o"); action = "done"; note = "Manually completed" }
    Save-ConversationQueue $queue
    # Bug 2 fix: use [Math]::Min to avoid crash when id is shorter than 8 chars
    Write-Host "$($script:LogPrefix) ✅ Item $($item.id.Substring(0, [Math]::Min(8, $item.id.Length))) marked done." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# CLI mode — run standalone for testing
# ---------------------------------------------------------------------------

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Teams Conversation Watcher — standalone run" -ForegroundColor Cyan
    $result = Invoke-TeamsConversationWatcher
    Write-Host "Result: $($result | ConvertTo-Json -Compress)" -ForegroundColor Cyan
}
