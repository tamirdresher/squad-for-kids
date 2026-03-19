#Requires -Version 7.0

<#
.SYNOPSIS
Automated Digest Generator for Squad continuous learning
Generates digests from GitHub issues/PRs, orchestration logs, and decision tracking

.DESCRIPTION
Collects activity from:
- GitHub issues and pull requests
- .squad/orchestration-log/ entries (agent work)
- .squad/decisions.md changes (team decisions)

Outputs a formatted markdown digest for the specified period.

.PARAMETER Period
How many days to include: 'daily' (1), 'weekly' (7), or integer (N days)
Default: 7 (weekly)

.PARAMETER OutputPath
Directory to save digest markdown file
Default: .squad/digests/

.PARAMETER DateFrom
Start date for digest (ISO 8601 format or relative like '7 days ago')
Default: N days ago based on Period

.EXAMPLE
.\generate-digest.ps1 -Period weekly
# Generates .squad/digests/digest-2026-03-07-weekly.md

.EXAMPLE
.\generate-digest.ps1 -Period daily -OutputPath ./artifacts/
# Generates ./artifacts/digest-2026-03-07-daily.md
#>

param(
    [ValidateSet('daily', 'weekly', 7, 1)]
    [string]$Period = 'weekly',
    
    [string]$OutputPath = '.squad/digests',
    
    [string]$DateFrom
)

# ===========================
# Configuration
# ===========================

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Ensure gh uses the EMU account (tamirdresher_microsoft) — required for squad repo access
$env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"

# Map period to days
$periodDays = if ($Period -eq 'daily') { 1 } elseif ($Period -eq 'weekly') { 7 } else { [int]$Period }

# Calculate date range
$endDate = Get-Date
$startDate = $endDate.AddDays(-$periodDays)

if ($DateFrom) {
    # Support relative dates
    if ($DateFrom -match '^\d+\s+days?\s+ago$') {
        $days = [int]($DateFrom -replace '\D', '')
        $startDate = $endDate.AddDays(-$days)
    } else {
        $startDate = [DateTime]::Parse($DateFrom)
    }
}

Write-Information "Digest Generator: $periodDays-day period from $(($startDate).ToShortDateString()) to $(($endDate).ToShortDateString())"

# ===========================
# Helper Functions
# ===========================

function Get-GitHubActivity {
    param(
        [DateTime]$Since,
        [DateTime]$Until
    )
    
    $activities = @()
    $sinceStr = $Since.ToString('o')
    
    # Get issues
    try {
        $issues = gh issue list --state all --created ">=$sinceStr" --json number,title,state,author,updatedAt --limit 100 2>&1
        if ($LASTEXITCODE -eq 0 -and $issues) {
            $issuesData = $issues | ConvertFrom-Json
            foreach ($issue in $issuesData) {
                $activities += @{
                    type = 'issue'
                    id = "#$($issue.number)"
                    title = $issue.title
                    state = $issue.state
                    author = $issue.author.login
                    date = [DateTime]::Parse($issue.updatedAt)
                }
            }
        }
    } catch {
        Write-Information "Note: Could not fetch GitHub issues (gh CLI may not be configured)"
    }
    
    # Get pull requests
    try {
        $prs = gh pr list --state all --created ">=$sinceStr" --json number,title,state,author,updatedAt --limit 100 2>&1
        if ($LASTEXITCODE -eq 0 -and $prs) {
            $prsData = $prs | ConvertFrom-Json
            foreach ($pr in $prsData) {
                $activities += @{
                    type = 'pr'
                    id = "#$($pr.number)"
                    title = $pr.title
                    state = $pr.state
                    author = $pr.author.login
                    date = [DateTime]::Parse($pr.updatedAt)
                }
            }
        }
    } catch {
        Write-Information "Note: Could not fetch GitHub PRs (gh CLI may not be configured)"
    }
    
    return $activities | Sort-Object date -Descending
}

function Get-OrchestrationActivity {
    param(
        [DateTime]$Since,
        [DateTime]$Until,
        [string]$LogDir
    )
    
    $activities = @()
    
    if (-not (Test-Path $LogDir)) {
        Write-Information "Orchestration log directory not found: $LogDir"
        return @()
    }
    
    $logFiles = Get-ChildItem -Path $LogDir -Filter '*.md' -File | 
        Where-Object { $_.LastWriteTime -ge $Since -and $_.LastWriteTime -le $Until }
    
    foreach ($file in $logFiles) {
        # Parse timestamp from filename (e.g., "2026-03-07T17-05-00Z-data-r1.md")
        if ($file.Name -match '^(\d{4}-\d{2}-\d{2}T[\d-]+Z)') {
            $timeStr = $matches[1] -replace '-(\d{2})Z$', ':$1Z'
            try {
                $date = [DateTime]::Parse($timeStr)
                $content = Get-Content -Path $file.FullName -Raw
                
                # Extract agent name and outcome
                $agentMatch = $content -match 'Agent routed.*\|\s*(\w+)'
                $agent = if ($agentMatch) { $matches[1] } else { 'Unknown' }
                
                $outcomeMatch = $content -match 'Outcome\s*\|\s*(\w+.*?)(?:\n|$)'
                $outcome = if ($outcomeMatch) { $matches[1].Trim() } else { 'In Progress' }
                
                $activities += @{
                    type = 'orchestration'
                    agent = $agent
                    file = $file.Name
                    outcome = $outcome
                    date = $date
                }
            } catch {
                Write-Information "Warning: Could not parse orchestration log file: $($file.Name)"
            }
        }
    }
    
    return $activities | Sort-Object date -Descending
}

function Get-DecisionsUpdated {
    param(
        [DateTime]$Since,
        [DateTime]$Until,
        [string]$DecisionsFile
    )
    
    $activities = @()
    
    if (-not (Test-Path $DecisionsFile)) {
        Write-Information "Decisions file not found: $DecisionsFile"
        return @()
    }
    
    # Get file modification time
    $fileTime = (Get-Item $DecisionsFile).LastWriteTime
    
    if ($fileTime -ge $Since -and $fileTime -le $Until) {
        $content = Get-Content -Path $DecisionsFile -Raw
        
        # Count decisions (marked by "## Decision N:")
        $decisionMatches = [regex]::Matches($content, '##\s+Decision\s+\d+:')
        $decisionCount = $decisionMatches.Count
        
        # Try to extract the most recent decision
        if ($content -match '##\s+Decision\s+(\d+):\s+(.+?)\n') {
            $lastDecisionNum = $matches[1]
            $lastDecisionTitle = $matches[2].Trim()
            
            $activities += @{
                type = 'decision'
                number = $lastDecisionNum
                title = $lastDecisionTitle
                total = $decisionCount
                date = $fileTime
            }
        }
    }
    
    return $activities
}

# ===========================
# Generate Digest Content
# ===========================

Write-Information "Collecting GitHub activity..."
$gitHubActivity = Get-GitHubActivity -Since $startDate -Until $endDate

Write-Information "Collecting orchestration logs..."
$orchestrationActivity = Get-OrchestrationActivity -Since $startDate -Until $endDate -LogDir '.squad/orchestration-log'

Write-Information "Collecting decision updates..."
$decisionsActivity = Get-DecisionsUpdated -Since $startDate -Until $endDate -DecisionsFile '.squad/decisions.md'

# ===========================
# Build Markdown Digest
# ===========================

$digest = @()
$digest += "# Squad Digest — $(Get-Date -Format 'yyyy-MM-dd') ($($Period.ToLower()))"
$digest += ""
$digest += "**Period:** $(($startDate).ToShortDateString()) → $(($endDate).ToShortDateString())"
$digest += ""

# Summary
$totalIssues = @($gitHubActivity | Where-Object { $_.type -eq 'issue' }).Count
$totalPRs = @($gitHubActivity | Where-Object { $_.type -eq 'pr' }).Count
$totalOrchestrations = @($orchestrationActivity).Count
$totalDecisions = if ($decisionsActivity) { $decisionsActivity[0].total } else { 0 }

$digest += "## Summary"
$digest += ""
$digest += "- **GitHub Issues:** $totalIssues"
$digest += "- **Pull Requests:** $totalPRs"
$digest += "- **Agent Operations:** $totalOrchestrations"
$digest += "- **Team Decisions:** $totalDecisions"
$digest += ""

# GitHub Activity
if ($gitHubActivity) {
    $digest += "## GitHub Activity"
    $digest += ""
    
    $issues = $gitHubActivity | Where-Object { $_.type -eq 'issue' }
    if ($issues) {
        $digest += "### Issues ($($issues.Count))"
        $digest += ""
        foreach ($issue in $issues) {
            $digest += "- **$($issue.id)** — $($issue.title)"
            $digest += "  - **State:** $($issue.state) | **Author:** $($issue.author)"
            $digest += "  - **Updated:** $(($issue.date).ToShortDateString())"
        }
        $digest += ""
    }
    
    $prs = $gitHubActivity | Where-Object { $_.type -eq 'pr' }
    if ($prs) {
        $digest += "### Pull Requests ($($prs.Count))"
        $digest += ""
        foreach ($pr in $prs) {
            $digest += "- **$($pr.id)** — $($pr.title)"
            $digest += "  - **State:** $($pr.state) | **Author:** $($pr.author)"
            $digest += "  - **Updated:** $(($pr.date).ToShortDateString())"
        }
        $digest += ""
    }
}

# Orchestration Activity
if ($orchestrationActivity) {
    $digest += "## Agent Operations"
    $digest += ""
    $digest += "Automated squad agent work:"
    $digest += ""
    
    foreach ($activity in $orchestrationActivity) {
        $backtick = '`'
        $digest += "- **$($activity.agent)** — $backtick$($activity.file)$backtick"
        $digest += "  - **Outcome:** $($activity.outcome)"
        $digest += "  - **Timestamp:** $(($activity.date).ToString('yyyy-MM-dd HH:mm:ss'))"
    }
    $digest += ""
}

# Decisions
if ($decisionsActivity) {
    $digest += "## Team Decisions"
    $digest += ""
    $digest += "- **Decision #$($decisionsActivity[0].number):** $($decisionsActivity[0].title)"
    $digest += "- **Total tracked decisions:** $($decisionsActivity[0].total)"
    $digest += ""
}

# Insights
$digest += "## Insights"
$digest += ""

if ($totalIssues -gt 0 -or $totalPRs -gt 0) {
    $totalGHActivity = $totalIssues + $totalPRs
    $digest += "- GitHub saw **$totalGHActivity activity items** this period"
    if ($totalPRs -gt 0) {
        $prPercent = [math]::Round(($totalPRs / $totalGHActivity) * 100)
        $digest += "- **$prPercent%** of activity was pull request work (development phase)"
    }
}

if ($totalOrchestrations -gt 0) {
    $digest += "- Squad agents executed **$totalOrchestrations operations**"
    
    # Try to identify the most active agent
    $agentCounts = $orchestrationActivity | Group-Object agent | Sort-Object Count -Descending
    if ($agentCounts) {
        $digest += "- **Most active agent:** $($agentCounts[0].Name) ($($agentCounts[0].Count) operations)"
    }
}

if ($decisionsActivity) {
    $digest += "- Team made **$(1)** new decision(s) this period"
    $digest += "- **Total team decisions tracked:** $($decisionsActivity[0].total)"
}

$digest += ""

# Footer
$digest += "---"
$digest += ""
$digest += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss Z')"
$digest += ""
$digest += "_This digest is auto-generated from GitHub, orchestration logs, and team decisions._"
$digest += "_For detailed insights, review individual activity and decision traces._"

# ===========================
# Write Output
# ===========================

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    Write-Information "Creating output directory: $OutputPath"
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$fileName = "digest-$(Get-Date -Format 'yyyy-MM-dd')-$Period.md"
$filePath = Join-Path $OutputPath $fileName

# Write digest
$digest -join "`n" | Out-File -FilePath $filePath -Encoding UTF8

Write-Information "✅ Digest generated: $filePath"
Write-Information ""
Write-Information "Digest preview:"
Write-Information ($digest -join "`n")

# Return the file path for programmatic use
Write-Output $filePath
