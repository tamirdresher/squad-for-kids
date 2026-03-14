#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Posts GitHub Project Board snapshot to Teams channel as Adaptive Card
.DESCRIPTION
    Fetches the current state of GitHub Project Board and posts a visual
    dashboard to Teams webhook with column-grouped issues.
.PARAMETER WebhookUrlFile
    Path to file containing Teams webhook URL (default: $env:USERPROFILE\.squad\teams-webhook.url)
.PARAMETER ProjectOwner
    GitHub project owner (default: tamirdresher_microsoft)
.PARAMETER ProjectNumber
    GitHub project number (default: 1)
.EXAMPLE
    .\teams-board-dashboard.ps1
    Posts current board snapshot to Teams
#>

[CmdletBinding()]
param(
    [string]$WebhookUrlFile = "$env:USERPROFILE\.squad\teams-webhook.url",
    [string]$ProjectOwner = "tamirdresher_microsoft",
    [int]$ProjectNumber = 1
)

$ErrorActionPreference = "Stop"

# Read webhook URL
if (-not (Test-Path $WebhookUrlFile)) {
    Write-Error "Webhook URL file not found: $WebhookUrlFile"
    exit 1
}

$webhookUrl = (Get-Content $WebhookUrlFile -Raw).Trim()
Write-Host "📡 Fetching board state from GitHub..."

# Fetch project board data using gh CLI
try {
    $projectData = gh project item-list $ProjectNumber --owner $ProjectOwner --format json | ConvertFrom-Json
} catch {
    Write-Error "Failed to fetch project data. Ensure gh CLI is authenticated: $_"
    exit 1
}

Write-Host "✅ Found $($projectData.Count) items on the board"

# Column emoji mapping
$columnEmoji = @{
    "Todo" = "📋"
    "In Progress" = "🔨"
    "Review" = "👀"
    "Done" = "✅"
    "Blocked" = "🚫"
    "Pending User" = "⏳"
}

# Group items by status
$grouped = $projectData | Group-Object -Property status | Sort-Object -Property Name

# Build Adaptive Card
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$boardUrl = "https://github.com/users/$ProjectOwner/projects/$ProjectNumber"

# Build column sections
$columnSections = @()

foreach ($group in $grouped) {
    $statusName = if ([string]::IsNullOrEmpty($group.Name)) { "No Status" } else { $group.Name }
    $emoji = $columnEmoji[$statusName]
    if (-not $emoji) { $emoji = "📌" }
    
    $count = $group.Count
    $title = "$emoji **$statusName** ($count)"
    
    # Build issue list
    $issueList = $group.Group | ForEach-Object {
        $issueNumber = $_.content
        $issueTitle = $_.title
        $issueUrl = "https://github.com/$($_.repository)/issues/$issueNumber"
        "- [#$issueNumber]($issueUrl) $issueTitle"
    }
    
    $columnSections += @{
        type = "TextBlock"
        text = $title
        weight = "Bolder"
        size = "Medium"
        wrap = $true
    }
    
    $columnSections += @{
        type = "TextBlock"
        text = ($issueList -join "`n")
        wrap = $true
        spacing = "Small"
    }
    
    $columnSections += @{
        type = "TextBlock"
        text = " "
        isSubtle = $true
        spacing = "Small"
    }
}

$adaptiveCard = @{
    type = "message"
    attachments = @(
        @{
            contentType = "application/vnd.microsoft.card.adaptive"
            contentUrl = $null
            content = @{
                '$schema' = "http://adaptivecards.io/schemas/adaptive-card.json"
                type = "AdaptiveCard"
                version = "1.4"
                body = @(
                    @{
                        type = "TextBlock"
                        text = "📊 GitHub Project Board"
                        weight = "Bolder"
                        size = "ExtraLarge"
                        color = "Accent"
                    }
                    @{
                        type = "TextBlock"
                        text = "**tamresearch1** • Updated: $timestamp"
                        isSubtle = $true
                        spacing = "None"
                        wrap = $true
                    }
                    @{
                        type = "TextBlock"
                        text = "_Point-in-time snapshot • Run script again to refresh_"
                        isSubtle = $true
                        size = "Small"
                        spacing = "Small"
                        wrap = $true
                    }
                ) + $columnSections
                actions = @(
                    @{
                        type = "Action.OpenUrl"
                        title = "🔗 View Full Board"
                        url = $boardUrl
                    }
                )
            }
        }
    )
}

# Convert to JSON and post to Teams
$json = $adaptiveCard | ConvertTo-Json -Depth 20 -Compress

Write-Host "📤 Posting board snapshot to Teams..."

try {
    $response = Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $json -ContentType "application/json"
    Write-Host "✅ Board snapshot posted successfully to Teams!"
    Write-Host "🔗 View board: $boardUrl"
} catch {
    Write-Error "Failed to post to Teams webhook: $_"
    exit 1
}
