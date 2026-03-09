# Daily ADR Channel Check — IDP ADR Notifications Monitor
# Issue: #198
# Owner: Picard (Lead)
#
# ⚠️ READ-ONLY: This script NEVER posts to the ADR channel or comments on ADRs.
# It queries the channel via WorkIQ, identifies actionable items, and reports
# findings privately to Tamir via Teams webhook.
#
# Execution modes:
#   1. Copilot agent mode: ralph-watch invokes a Copilot session that uses WorkIQ
#   2. Standalone: Can be called directly for testing with -DryRun
#
# Schedule: Daily at 07:00 UTC (10:00 AM Israel time) on weekdays

param(
    [string]$TeamsWebhookFile = "$env:USERPROFILE\.squad\teams-webhook.url",
    [switch]$DryRun,
    [switch]$SkipWeekends,
    [int]$LookbackHours = 24
)

# Fix UTF-8 encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Continue"

# Skip weekends if requested
if ($SkipWeekends) {
    $dayOfWeek = (Get-Date).DayOfWeek
    if ($dayOfWeek -eq 'Saturday' -or $dayOfWeek -eq 'Sunday') {
        Write-Host "Skipping ADR check on weekend" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "📋 Running Daily ADR Channel Check..." -ForegroundColor Cyan
Write-Host "  Lookback: ${LookbackHours}h | Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })" -ForegroundColor Gray

# State file to track last check timestamp
$stateDir = Join-Path (Get-Location) ".squad\monitoring"
$stateFile = Join-Path $stateDir "adr-check-state.json"

# Ensure monitoring directory exists
if (-not (Test-Path $stateDir)) {
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
}

# Load previous state
$lastCheckTime = $null
if (Test-Path $stateFile) {
    try {
        $state = Get-Content $stateFile -Raw | ConvertFrom-Json
        $lastCheckTime = $state.lastCheck
        Write-Host "  Last check: $lastCheckTime" -ForegroundColor Gray
    } catch {
        Write-Host "  ⚠️  Could not read state file, running fresh scan" -ForegroundColor Yellow
    }
}

$scanFrom = (Get-Date).AddHours(-$LookbackHours).ToString("yyyy-MM-dd HH:mm")
$scanTo = (Get-Date).ToString("yyyy-MM-dd HH:mm")

Write-Host "  Scan window: $scanFrom → $scanTo" -ForegroundColor Gray

# ==================== WORKIQ QUERIES ====================
# NOTE: When run via Copilot agent, these queries are executed through
# the workiq-ask_work_iq MCP tool. This script generates the prompts
# and processes the results.
#
# The actual WorkIQ integration happens in the Copilot session that
# ralph-watch spawns. This script serves as:
# 1. Documentation of what queries to run
# 2. The Teams notification sender for results
# 3. State tracking (last check timestamp)

$queries = @(
    @{
        name = "New and Updated ADRs"
        query = "What new messages or notifications were posted in the IDP ADR Notifications channel between $scanFrom and $scanTo? Include the sender name, timestamp, and full message content. Focus on new ADR proposals, ADR status changes, review requests, and decisions made."
    },
    @{
        name = "Pending Reviews and Decisions"
        query = "Are there any ADR review requests, pending decisions, or calls for feedback in the IDP ADR Notifications channel from the last $LookbackHours hours? Who is being asked to review, what is the deadline, and what is the ADR about?"
    },
    @{
        name = "Blockers and Escalations"
        query = "Were there any blockers, concerns, escalations, or objections raised about any ADRs in the IDP ADR Notifications channel in the last $LookbackHours hours? Include who raised the concern, which ADR it relates to, and what the issue is."
    }
)

Write-Host "`n  WorkIQ Queries to execute:" -ForegroundColor Cyan
foreach ($q in $queries) {
    Write-Host "    → $($q.name)" -ForegroundColor Gray
}

# ==================== RESULTS PROCESSING ====================
# This section formats the results into a Teams Adaptive Card.
# When run standalone, it generates a placeholder.
# When run via Copilot agent, the agent populates $findings.

# Placeholder for findings — populated by Copilot agent session
$findings = @{
    newADRs = @()        # New ADR proposals or notifications
    reviewRequests = @() # ADRs needing review
    decisions = @()      # Decisions made
    blockers = @()       # Blockers or concerns raised
    deadlines = @()      # Upcoming deadlines
    summary = "No new ADR activity detected in the last ${LookbackHours}h."
    hasActionableItems = $false
}

# ==================== TEAMS NOTIFICATION ====================

function Send-ADRSummary {
    param(
        [hashtable]$Findings,
        [string]$WebhookUrl
    )

    # Only send if there are actionable items
    if (-not $Findings.hasActionableItems) {
        Write-Host "`n  ℹ️  No actionable ADR items — skipping Teams notification" -ForegroundColor Gray
        return
    }

    # Build notification sections
    $sections = @()

    # Header
    $sections += @{
        type = "TextBlock"
        text = "📋 **Daily ADR Channel Summary**"
        weight = "Bolder"
        size = "Large"
        wrap = $true
    }

    $sections += @{
        type = "FactSet"
        facts = @(
            @{ title = "Channel"; value = "IDP ADR Notifications" },
            @{ title = "Scan Window"; value = "$scanFrom → $scanTo" },
            @{ title = "Generated"; value = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " UTC" }
        )
    }

    # New ADRs
    if ($Findings.newADRs.Count -gt 0) {
        $adrText = ($Findings.newADRs | ForEach-Object { "• $_" }) -join "`n"
        $sections += @{
            type = "TextBlock"
            text = "**🆕 New ADR Activity**"
            weight = "Bolder"
            size = "Medium"
            wrap = $true
            separator = $true
        }
        $sections += @{
            type = "TextBlock"
            text = $adrText
            wrap = $true
        }
    }

    # Review Requests
    if ($Findings.reviewRequests.Count -gt 0) {
        $reviewText = ($Findings.reviewRequests | ForEach-Object { "• $_" }) -join "`n"
        $sections += @{
            type = "TextBlock"
            text = "**👀 Review Requests (Action Needed)**"
            weight = "Bolder"
            size = "Medium"
            wrap = $true
            separator = $true
        }
        $sections += @{
            type = "TextBlock"
            text = $reviewText
            wrap = $true
            color = "attention"
        }
    }

    # Decisions
    if ($Findings.decisions.Count -gt 0) {
        $decisionText = ($Findings.decisions | ForEach-Object { "• $_" }) -join "`n"
        $sections += @{
            type = "TextBlock"
            text = "**✅ Decisions Made**"
            weight = "Bolder"
            size = "Medium"
            wrap = $true
            separator = $true
        }
        $sections += @{
            type = "TextBlock"
            text = $decisionText
            wrap = $true
        }
    }

    # Blockers
    if ($Findings.blockers.Count -gt 0) {
        $blockerText = ($Findings.blockers | ForEach-Object { "• $_" }) -join "`n"
        $sections += @{
            type = "TextBlock"
            text = "**🚨 Blockers & Concerns**"
            weight = "Bolder"
            size = "Medium"
            wrap = $true
            separator = $true
        }
        $sections += @{
            type = "TextBlock"
            text = $blockerText
            wrap = $true
            color = "attention"
        }
    }

    # Footer
    $sections += @{
        type = "TextBlock"
        text = "_This is a read-only scan. Squad does not post to the ADR channel._"
        wrap = $true
        isSubtle = $true
        separator = $true
    }

    # Build Adaptive Card
    $card = @{
        type = "message"
        attachments = @(
            @{
                contentType = "application/vnd.microsoft.card.adaptive"
                content = @{
                    type = "AdaptiveCard"
                    '$schema' = "http://adaptivecards.io/schemas/adaptive-card.json"
                    version = "1.4"
                    body = $sections
                    msteams = @{
                        width = "Full"
                    }
                }
            }
        )
    }

    if ($DryRun) {
        Write-Host "`n  ✅ Dry run — card generated:" -ForegroundColor Green
        $card | ConvertTo-Json -Depth 20
        return
    }

    # Send to Teams
    try {
        $body = $card | ConvertTo-Json -Depth 20 -Compress
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $body -ContentType "application/json; charset=utf-8" | Out-Null
        Write-Host "`n  ✅ ADR summary sent to Teams" -ForegroundColor Green
    } catch {
        Write-Host "`n  ❌ Failed to send ADR summary: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ==================== STATE UPDATE ====================

# Update state file
$newState = @{
    lastCheck = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    scanFrom = $scanFrom
    scanTo = $scanTo
    hasActionableItems = $findings.hasActionableItems
    queriesRun = $queries.Count
}

$newState | ConvertTo-Json | Out-File $stateFile -Encoding utf8 -Force
Write-Host "`n  State saved to $stateFile" -ForegroundColor Gray

# ==================== WEBHOOK SEND ====================

# Load webhook URL
if (-not $DryRun) {
    if (-not (Test-Path $TeamsWebhookFile)) {
        Write-Host "  ⚠️  Teams webhook not found at $TeamsWebhookFile — skipping notification" -ForegroundColor Yellow
    } else {
        $webhookUrl = Get-Content -Path $TeamsWebhookFile -Raw -Encoding utf8 | ForEach-Object { $_.Trim() }
        if (-not [string]::IsNullOrWhiteSpace($webhookUrl)) {
            Send-ADRSummary -Findings $findings -WebhookUrl $webhookUrl
        }
    }
}

Write-Host "`n✅ Daily ADR check complete" -ForegroundColor Green
exit 0
