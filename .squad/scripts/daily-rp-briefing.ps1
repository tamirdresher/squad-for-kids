# Daily BasePlatformRP Status Briefing
# Generates and sends a comprehensive status report to Teams at 9:00 AM
# Can be invoked manually or scheduled via ralph-watch.ps1, GitHub Actions, or Task Scheduler

param(
    [string]$TeamsWebhookFile = "$env:USERPROFILE\.squad\teams-webhook.url",
    [switch]$DryRun,
    [switch]$SkipWeekends
)

# Fix UTF-8 encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Continue"

# Check if it's a weekend
if ($SkipWeekends) {
    $dayOfWeek = (Get-Date).DayOfWeek
    if ($dayOfWeek -eq 'Saturday' -or $dayOfWeek -eq 'Sunday') {
        Write-Host "Skipping briefing on weekend" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "🔍 Generating BasePlatformRP Daily Briefing..." -ForegroundColor Cyan

# ==================== DATA COLLECTION ====================

# GitHub repository
$repo = "mtp-microsoft/Infra.K8s.BasePlatformRP"

# 1. Open PRs
Write-Host "  → Fetching open PRs..." -ForegroundColor Gray
$openPRsJson = gh pr list --repo $repo --json number,title,author,createdAt,url --limit 50 2>&1
$openPRs = @()
if ($LASTEXITCODE -eq 0) {
    try {
        $openPRs = $openPRsJson | ConvertFrom-Json
    } catch {
        Write-Host "    ⚠️  Failed to parse PRs: $_" -ForegroundColor Yellow
    }
}

# 2. Open Issues (grouped by labels)
Write-Host "  → Fetching open issues..." -ForegroundColor Gray
$openIssuesJson = gh issue list --repo $repo --json number,title,labels,createdAt,url --limit 50 2>&1
$openIssues = @()
if ($LASTEXITCODE -eq 0) {
    try {
        $openIssues = $openIssuesJson | ConvertFrom-Json
    } catch {
        Write-Host "    ⚠️  Failed to parse issues: $_" -ForegroundColor Yellow
    }
}

# 3. Recent Activity (last 24h commits)
Write-Host "  → Fetching recent commits..." -ForegroundColor Gray
$since = (Get-Date).AddDays(-1).ToString("yyyy-MM-ddTHH:mm:ss")
$recentCommitsJson = gh api "/repos/$repo/commits?since=$since&per_page=50" 2>&1
$recentCommits = @()
if ($LASTEXITCODE -eq 0) {
    try {
        $recentCommits = $recentCommitsJson | ConvertFrom-Json
    } catch {
        Write-Host "    ⚠️  Failed to parse commits: $_" -ForegroundColor Yellow
    }
}

# 4. Recently closed PRs (last 24h)
Write-Host "  → Fetching recently closed PRs..." -ForegroundColor Gray
$closedPRsJson = gh pr list --repo $repo --state closed --json number,title,author,closedAt,url,mergedAt --limit 20 2>&1
$recentClosedPRs = @()
if ($LASTEXITCODE -eq 0) {
    try {
        $allClosed = $closedPRsJson | ConvertFrom-Json
        $yesterday = (Get-Date).AddDays(-1)
        $recentClosedPRs = $allClosed | Where-Object { 
            $closedDate = $null
            $dateStr = if ($_.mergedAt) { $_.mergedAt } else { $_.closedAt }
            if ($dateStr -and [datetime]::TryParse($dateStr, [ref]$closedDate)) {
                $closedDate -gt $yesterday
            } else {
                $false
            }
        }
    } catch {
        Write-Host "    ⚠️  Failed to parse closed PRs: $_" -ForegroundColor Yellow
    }
}

# ==================== FORMAT ADAPTIVE CARD ====================

Write-Host "  → Formatting Teams card..." -ForegroundColor Gray

# Build sections
$sections = @()

# Header Section
$headerFacts = @(
    @{
        title = "Repository"
        value = "[$repo](https://github.com/$repo)"
    },
    @{
        title = "Generated"
        value = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " (UTC+2)"
    }
)

$sections += @{
    type = "FactSet"
    facts = $headerFacts
}

# Section 1: Blockers
$blockerText = "No active blockers detected"
$blockerColor = "good"
# Check for issues with 'blocker' or 'urgent' labels
$blockers = $openIssues | Where-Object { 
    $_.labels | Where-Object { $_.name -match "blocker|urgent|sev|incident" }
}
if ($blockers.Count -gt 0) {
    $blockerColor = "attention"
    $blockerItems = $blockers | ForEach-Object { "• [#$($_.number) — $($_.title)]($($_.url))" }
    $blockerText = ($blockerItems -join "`n")
}

$sections += @{
    type = "TextBlock"
    text = "**🚨 Blockers & Critical Items**"
    weight = "Bolder"
    size = "Medium"
    wrap = $true
}
$sections += @{
    type = "TextBlock"
    text = $blockerText
    wrap = $true
    color = $blockerColor
}

# Section 2: Open PRs
$sections += @{
    type = "TextBlock"
    text = "**🔄 Open Pull Requests ($($openPRs.Count))**"
    weight = "Bolder"
    size = "Medium"
    wrap = $true
    separator = $true
}

if ($openPRs.Count -gt 0) {
    $prText = ($openPRs | ForEach-Object {
        $age = [math]::Round(((Get-Date) - [datetime]$_.createdAt).TotalDays)
        "• [#$($_.number) — $($_.title)]($($_.url))  " +
        "_by $($_.author.login), ${age}d old_"
    }) -join "`n`n"
    $sections += @{
        type = "TextBlock"
        text = $prText
        wrap = $true
    }
} else {
    $sections += @{
        type = "TextBlock"
        text = "_No open PRs_"
        wrap = $true
        isSubtle = $true
    }
}

# Section 3: Open Issues (grouped by labels)
$sections += @{
    type = "TextBlock"
    text = "**📋 Key Open Issues ($($openIssues.Count))**"
    weight = "Bolder"
    size = "Medium"
    wrap = $true
    separator = $true
}

if ($openIssues.Count -gt 0) {
    # Group by primary label
    $grouped = $openIssues | Group-Object -Property { 
        if ($_.labels.Count -gt 0) { $_.labels[0].name } else { "unlabeled" }
    }
    
    $issueText = ($grouped | ForEach-Object {
        $label = $_.Name
        $items = $_.Group | Select-Object -First 5 | ForEach-Object {
            "  • [#$($_.number) — $($_.title)]($($_.url))"
        }
        "**$label** ($($_.Count)):`n" + ($items -join "`n")
    }) -join "`n`n"
    
    $sections += @{
        type = "TextBlock"
        text = $issueText
        wrap = $true
    }
} else {
    $sections += @{
        type = "TextBlock"
        text = "_No open issues_"
        wrap = $true
        isSubtle = $true
    }
}

# Section 4: Yesterday's Activity
$sections += @{
    type = "TextBlock"
    text = "**📈 Yesterday's Activity**"
    weight = "Bolder"
    size = "Medium"
    wrap = $true
    separator = $true
}

$activityItems = @()

# Recent commits
if ($recentCommits.Count -gt 0) {
    $commitList = ($recentCommits | Select-Object -First 5 | ForEach-Object {
        $shortSha = $_.sha.Substring(0, 7)
        $message = $_.commit.message -split "`n" | Select-Object -First 1
        "  • [$shortSha]($($_.html_url)) — $message _by $($_.commit.author.name)_"
    }) -join "`n"
    $activityItems += "**Commits ($($recentCommits.Count)):**`n$commitList"
} else {
    $activityItems += "**Commits:** _None in last 24h_"
}

# Recently closed/merged PRs
if ($recentClosedPRs.Count -gt 0) {
    $prList = ($recentClosedPRs | ForEach-Object {
        $status = if ($_.mergedAt) { "merged" } else { "closed" }
        "  • [#$($_.number) — $($_.title)]($($_.url)) _($status)_"
    }) -join "`n"
    $activityItems += "`n`n**PRs closed/merged ($($recentClosedPRs.Count)):**`n$prList"
}

if ($activityItems.Count -eq 0) {
    $activityItems += "_No significant activity in last 24h_"
}

$sections += @{
    type = "TextBlock"
    text = ($activityItems -join "`n")
    wrap = $true
}

# Section 5: Loop Doc Status (placeholder)
$sections += @{
    type = "TextBlock"
    text = "**📄 Loop Doc Status**"
    weight = "Bolder"
    size = "Medium"
    wrap = $true
    separator = $true
}
$sections += @{
    type = "TextBlock"
    text = "📌 [Check Dk8sPlatform ARM RP Loop Doc manually](https://microsoft.sharepoint.com) — _WorkIQ integration pending_"
    wrap = $true
    isSubtle = $true
}

# Section 6: Teams/Email Discussions (placeholder)
$sections += @{
    type = "TextBlock"
    text = "**💬 Recent RP Discussions**"
    weight = "Bolder"
    size = "Medium"
    wrap = $true
    separator = $true
}
$sections += @{
    type = "TextBlock"
    text = "_WorkIQ integration pending — Teams chats, emails, and calendar will be added when WorkIQ MCP is available_"
    wrap = $true
    isSubtle = $true
}

# Section 7: Today's Meetings (placeholder)
$sections += @{
    type = "TextBlock"
    text = "**📅 Today's Meetings**"
    weight = "Bolder"
    size = "Medium"
    wrap = $true
    separator = $true
}
$sections += @{
    type = "TextBlock"
    text = "_Calendar integration pending — will show RP/provisioning/platform meetings_"
    wrap = $true
    isSubtle = $true
}

# Section 8: Action Items
$sections += @{
    type = "TextBlock"
    text = "**✅ Action Items**"
    weight = "Bolder"
    size = "Medium"
    wrap = $true
    separator = $true
}

$actionItems = @()
# PRs needing review (open for >3 days)
$oldPRs = $openPRs | Where-Object { 
    ((Get-Date) - [datetime]$_.createdAt).TotalDays -gt 3 
}
if ($oldPRs.Count -gt 0) {
    $actionItems += "**PRs awaiting review (>3 days):** $($oldPRs.Count) — [View open PRs](https://github.com/$repo/pulls)"
}

# Blockers need attention
if ($blockers.Count -gt 0) {
    $actionItems += "**Critical issues require attention:** $($blockers.Count) blocker(s)"
}

if ($actionItems.Count -eq 0) {
    $actionItems += "_No urgent action items_"
}

$sections += @{
    type = "TextBlock"
    text = ($actionItems -join "`n`n")
    wrap = $true
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

# ==================== SEND TO TEAMS ====================

if ($DryRun) {
    Write-Host "`n✅ Dry run — card generated successfully" -ForegroundColor Green
    Write-Host "Card JSON:" -ForegroundColor Cyan
    $card | ConvertTo-Json -Depth 20
    exit 0
}

# Send to Teams
if (-not (Test-Path $TeamsWebhookFile)) {
    Write-Host "❌ Teams webhook URL not found at $TeamsWebhookFile" -ForegroundColor Red
    exit 1
}

$webhookUrl = Get-Content -Path $TeamsWebhookFile -Raw -Encoding utf8 | ForEach-Object { $_.Trim() }

if ([string]::IsNullOrWhiteSpace($webhookUrl)) {
    Write-Host "❌ Teams webhook URL is empty" -ForegroundColor Red
    exit 1
}

try {
    $body = $card | ConvertTo-Json -Depth 20 -Compress
    $response = Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json; charset=utf-8"
    Write-Host "✅ Daily briefing sent successfully to Teams" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "❌ Failed to send briefing to Teams: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Response: $($_.Exception.Response)" -ForegroundColor Yellow
    exit 1
}
