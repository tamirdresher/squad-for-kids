# Teams Message Monitor Check
# Runs as part of Ralph's scheduled loop via .squad/schedule.json
# Uses WorkIQ to scan Teams messages and surfaces actionable items to Tamir

param(
    [switch]$DryRun = $false,
    [int]$LookbackMinutes = 30
)

$ErrorActionPreference = "Stop"

# ============================================================================
# CONFIGURATION
# ============================================================================

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$logDir = Join-Path $env:USERPROFILE ".squad\monitoring"
$logFile = Join-Path $logDir "teams-monitor.log"
$stateFile = Join-Path $logDir "teams-monitor-state.json"
$teamsWebhookFile = Join-Path $env:USERPROFILE ".squad\teams-webhook.url"

# Ensure directories exist
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# ============================================================================
# LOGGING
# ============================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $entry -Encoding utf8
    
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host $entry -ForegroundColor $color
}

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

function Get-MonitorState {
    if (Test-Path $stateFile) {
        try {
            return Get-Content $stateFile -Raw | ConvertFrom-Json
        } catch {
            Write-Log "Failed to parse state file, starting fresh" -Level "WARN"
        }
    }
    
    return @{
        lastRun = $null
        processedMessages = @()
        createdIssues = @()
    }
}

function Save-MonitorState {
    param($State)
    $State | ConvertTo-Json -Depth 10 | Out-File $stateFile -Encoding utf8 -Force
}

# ============================================================================
# WORKIQ QUERIES
# ============================================================================

function Get-RecentTeamsMessages {
    param([int]$LookbackMinutes)
    
    Write-Log "Querying WorkIQ for recent Teams messages (last $LookbackMinutes minutes)..."
    
    # Build query targeting recent messages with keywords
    $queries = @(
        "What Teams messages mentioned Tamir, squad, AI agents, or action items in the last $LookbackMinutes minutes?",
        "Are there any recent Teams messages asking for reviews, decisions, or urgent attention from Tamir or the DK8S team?",
        "What Teams messages in the last $LookbackMinutes minutes mention infrastructure, Kubernetes, DK8S, or configuration that need attention?"
    )
    
    $allMessages = @()
    
    foreach ($query in $queries) {
        Write-Log "  Query: $query"
        
        # NOTE: In actual implementation, this would use workiq-ask_work_iq tool
        # For now, this is a placeholder showing the structure
        # The actual implementation would be called by Copilot CLI with WorkIQ access
        
        # Placeholder result structure
        $result = @{
            messages = @()
            query = $query
        }
        
        $allMessages += $result
    }
    
    return $allMessages
}

# ============================================================================
# MESSAGE FILTERING
# ============================================================================

function Test-ActionableMessage {
    param($Message)
    
    # Keywords indicating actionable content
    $actionKeywords = @(
        "can you", "could you", "please review", "need you to", "action item",
        "urgent", "asap", "blocking", "decision needed", "input needed",
        "waiting for", "review request", "squad", "ai agent"
    )
    
    # Check for direct mentions or action keywords
    $content = $Message.content.ToLower()
    $isTamirMentioned = $content -match "tamir|@tamir"
    $isSquadMentioned = $content -match "squad|ai\s+agent|copilot"
    $hasActionKeyword = $false
    
    foreach ($keyword in $actionKeywords) {
        if ($content -match $keyword) {
            $hasActionKeyword = $true
            break
        }
    }
    
    # Ignore automated notifications
    $isAutomated = $content -match "build (succeeded|failed)|pr #\d+|ci\/cd|automated"
    
    return ($isTamirMentioned -or ($isSquadMentioned -and $hasActionKeyword)) -and -not $isAutomated
}

function Get-ActionableMessages {
    param($Messages, $ProcessedMessages)
    
    $actionable = @()
    
    foreach ($msg in $Messages) {
        # Skip already processed
        $msgId = "$($msg.timestamp)_$($msg.sender)"
        if ($msgId -in $ProcessedMessages) {
            continue
        }
        
        if (Test-ActionableMessage -Message $msg) {
            $actionable += $msg
        }
    }
    
    Write-Log "Found $($actionable.Count) actionable messages (filtered from $($Messages.Count) total)"
    return $actionable
}

# ============================================================================
# GITHUB INTEGRATION
# ============================================================================

function Test-DuplicateIssue {
    param($MessageSummary, $RecentIssues)
    
    foreach ($issue in $RecentIssues) {
        if ($issue.title -match [regex]::Escape($MessageSummary)) {
            return $true
        }
    }
    return $false
}

function New-TeamsIssue {
    param($Message)
    
    $title = "[Teams Bridge] $($Message.summary)"
    $body = @"
**Source:** $($Message.sender) in $($Message.channel)
**Timestamp:** $($Message.timestamp)

---

$($Message.content)

---

🔗 Bridged from Teams via WorkIQ by teams-monitor skill
📅 Detected: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
    
    Write-Log "Would create GitHub issue: $title"
    
    if (-not $DryRun) {
        # In actual implementation, this would use gh CLI to create the issue
        # gh issue create --title "$title" --body "$body" --label "teams-bridge,squad:belanna"
        Write-Log "  (GitHub issue creation would happen here)" -Level "WARN"
    }
    
    return @{
        title = $title
        created = -not $DryRun
    }
}

# ============================================================================
# NOTIFICATION
# ============================================================================

function Send-TeamsNotification {
    param($ActionableCount, $IssuesCreated)
    
    if ($ActionableCount -eq 0) {
        return
    }
    
    if (-not (Test-Path $teamsWebhookFile)) {
        Write-Log "Teams webhook URL not found at $teamsWebhookFile" -Level "WARN"
        return
    }
    
    $webhookUrl = (Get-Content $teamsWebhookFile -Raw).Trim()
    
    $text = "🔔 Teams Monitor: Found $ActionableCount actionable message(s)"
    if ($IssuesCreated -gt 0) {
        $text += " — Created $IssuesCreated GitHub issue(s) for review"
    }
    
    $body = @{ text = $text } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "application/json" -Body $body | Out-Null
        Write-Log "Sent Teams notification" -Level "SUCCESS"
    } catch {
        Write-Log "Failed to send Teams notification: $($_.Exception.Message)" -Level "ERROR"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    Write-Log "=== Teams Monitor Check Started ==="
    Write-Log "Lookback: $LookbackMinutes minutes | DryRun: $DryRun"
    
    # Load state
    $state = Get-MonitorState
    $state.lastRun = Get-Date -Format "o"
    
    # Query WorkIQ for recent messages
    $queryResults = Get-RecentTeamsMessages -LookbackMinutes $LookbackMinutes
    
    # Extract and deduplicate messages
    $allMessages = @()
    foreach ($result in $queryResults) {
        $allMessages += $result.messages
    }
    
    Write-Log "Retrieved $($allMessages.Count) total messages from WorkIQ"
    
    # Filter for actionable content
    $actionableMessages = Get-ActionableMessages -Messages $allMessages -ProcessedMessages $state.processedMessages
    
    if ($actionableMessages.Count -eq 0) {
        Write-Log "No actionable messages found - all clear" -Level "SUCCESS"
        Save-MonitorState -State $state
        exit 0
    }
    
    # Create GitHub issues for actionable items (with deduplication)
    $issuesCreated = 0
    foreach ($msg in $actionableMessages) {
        $msgId = "$($msg.timestamp)_$($msg.sender)"
        
        # Check for duplicates
        if (Test-DuplicateIssue -MessageSummary $msg.summary -RecentIssues $state.createdIssues) {
            Write-Log "  Skipping duplicate: $($msg.summary)"
            continue
        }
        
        # Create issue
        $issue = New-TeamsIssue -Message $msg
        if ($issue.created) {
            $issuesCreated++
            $state.createdIssues += @{
                title = $issue.title
                created = Get-Date -Format "o"
                messageId = $msgId
            }
        }
        
        # Mark as processed
        $state.processedMessages += $msgId
    }
    
    # Keep only last 100 processed messages to prevent unbounded growth
    if ($state.processedMessages.Count -gt 100) {
        $state.processedMessages = $state.processedMessages | Select-Object -Last 100
    }
    
    # Keep only last 50 created issues
    if ($state.createdIssues.Count -gt 50) {
        $state.createdIssues = $state.createdIssues | Select-Object -Last 50
    }
    
    # Save state
    Save-MonitorState -State $state
    
    # Send notification
    Send-TeamsNotification -ActionableCount $actionableMessages.Count -IssuesCreated $issuesCreated
    
    Write-Log "=== Teams Monitor Check Complete ===" -Level "SUCCESS"
    Write-Log "Summary: $($actionableMessages.Count) actionable, $issuesCreated issues created"
    
    exit 0
    
} catch {
    Write-Log "Teams monitor check failed: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
