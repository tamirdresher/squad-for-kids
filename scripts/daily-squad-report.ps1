#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Daily Squad Activity Report — comprehensive email at 5 AM Israel time.

.DESCRIPTION
    Collects ALL activity across all Squad repos from the previous 24 hours:
    issues, PRs, commits, Ralph stats, decisions, research, communications.
    Sends a detailed HTML report to tamirdresher@microsoft.com via Gmail SMTP.

.NOTES
    Scheduled: 5 AM Israel (Asia/Jerusalem) = ~2-3 AM UTC depending on DST.
    Uses send-squad-email-resilient.ps1 for email delivery (Gmail primary).
    Handles repos that aren't cloned locally by using gh CLI API calls.
    Never includes private repo URLs — uses issue/PR numbers only.
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Override recipient email")]
    [string]$To = "tamirdresher@microsoft.com",

    [Parameter(HelpMessage = "Dry run — generate report but don't send")]
    [switch]$DryRun,

    [Parameter(HelpMessage = "Save report HTML to this path")]
    [string]$SaveTo
)

$ErrorActionPreference = "Continue"
$scriptRoot = $PSScriptRoot
$repoRoot = Split-Path $scriptRoot -Parent

# ============================================================================
# DEDUP / CATCH-UP LOGIC — Only one machine sends the report per day
# ============================================================================

$reportDate = (Get-Date).AddHours(-3).ToString("yyyy-MM-dd")  # Report covers "yesterday" relative to 5AM
$markerDir = Join-Path $env:USERPROFILE ".squad"
$localMarker = Join-Path $markerDir "daily-report-$reportDate.sent"
$gitMarker = Join-Path $repoRoot ".squad" "daily-report-last-sent.json"

# Check local marker first (fastest)
if (Test-Path $localMarker) {
    Write-Host "Daily report for $reportDate already sent from THIS machine. Skipping."
    exit 0
}

# Check git marker (cross-machine dedup)
Push-Location $repoRoot
git pull --ff-only --quiet 2>$null
Pop-Location

if (Test-Path $gitMarker) {
    $lastSent = Get-Content $gitMarker -Raw | ConvertFrom-Json
    if ($lastSent.date -eq $reportDate) {
        Write-Host "Daily report for $reportDate already sent by $($lastSent.machine). Skipping."
        # Write local marker so we don't check git again
        $reportDate | Out-File $localMarker -Force
        exit 0
    }
}

Write-Host "No report sent for $reportDate yet. This machine ($env:COMPUTERNAME) will generate it."

$ghOwner = "tamirdresher"
$squadRepos = @(
    "tamresearch1",
    "tamresearch1-research",
    "jellybolt-games",
    "devtools-pro",
    "techai-explained",
    "saas-finder-hub",
    "squad-tetris",
    "kids-squad-setup",
    "squad-skills",
    "squad-monitor"
)

# Time window: previous 24 hours anchored to 5 AM Israel time
$israelTz = [System.TimeZoneInfo]::FindSystemTimeZoneById("Israel Standard Time")
$nowIsrael = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $israelTz)
$todayAnchor = $nowIsrael.Date.AddHours(5)
if ($nowIsrael -lt $todayAnchor) {
    $todayAnchor = $todayAnchor.AddDays(-1)
}
$windowEnd   = $todayAnchor
$windowStart = $todayAnchor.AddDays(-1)

$sinceISO = [System.TimeZoneInfo]::ConvertTimeToUtc($windowStart, $israelTz).ToString("yyyy-MM-ddTHH:mm:ssZ")
$untilISO = [System.TimeZoneInfo]::ConvertTimeToUtc($windowEnd,   $israelTz).ToString("yyyy-MM-ddTHH:mm:ssZ")
$sinceDate = $windowStart.ToString("yyyy-MM-dd")
$reportDate = $windowEnd.ToString("yyyy-MM-dd")

Write-Host "📊 Squad Daily Report — $reportDate"
Write-Host "   Window: $($windowStart.ToString('g')) → $($windowEnd.ToString('g')) Israel"
Write-Host "   ISO: $sinceISO → $untilISO"

# ============================================================================
# HELPERS
# ============================================================================

function Invoke-GhApi {
    param([string]$Endpoint, [string]$JqFilter = ".")
    try {
        $result = gh api $Endpoint --paginate --jq $JqFilter 2>&1
        if ($LASTEXITCODE -ne 0) { return $null }
        return $result
    } catch {
        Write-Warning "API call failed: $Endpoint — $_"
        return $null
    }
}

function HtmlEncode([string]$text) {
    if (-not $text) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($text)
}

function TruncateText([string]$text, [int]$maxLen = 500) {
    if (-not $text) { return "" }
    if ($text.Length -le $maxLen) { return $text }
    return $text.Substring(0, $maxLen) + "..."
}

# ============================================================================
# DATA COLLECTION
# ============================================================================

$allIssuesCreated  = @()
$allIssuesClosed   = @()
$allIssuesCommented = @()
$allPRs            = @()
$allCommits        = @()
$ralphData         = @()
$decisions         = @()
$skills            = @()
$research          = @()
$communications    = @()
$crossMachine      = @()
$blogActivity      = @()

Write-Host "`n🔍 Collecting data across $($squadRepos.Count) repos..."

foreach ($repo in $squadRepos) {
    $fullRepo = "$ghOwner/$repo"
    Write-Host "  📂 $repo..."

    # --- Issues Created in window ---
    try {
        $issuesJson = gh api "repos/$fullRepo/issues?state=all&since=$sinceISO&per_page=100&sort=created&direction=desc" `
            --paginate 2>&1
        if ($LASTEXITCODE -eq 0 -and $issuesJson) {
            $issues = $issuesJson | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($issues) {
                foreach ($issue in $issues) {
                    # Skip pull requests (GitHub API returns PRs in issues endpoint)
                    if ($issue.pull_request) { continue }

                    $createdAt = [DateTime]::Parse($issue.created_at)
                    $closedAt = if ($issue.closed_at) { [DateTime]::Parse($issue.closed_at) } else { $null }

                    if ($createdAt -ge [DateTime]::Parse($sinceISO) -and $createdAt -lt [DateTime]::Parse($untilISO)) {
                        $labels = ($issue.labels | ForEach-Object { $_.name }) -join ", "
                        $allIssuesCreated += @{
                            Repo    = $repo
                            Number  = $issue.number
                            Title   = $issue.title
                            Labels  = $labels
                            Author  = $issue.user.login
                            Body    = TruncateText $issue.body 800
                            Created = $createdAt.ToString("HH:mm")
                        }
                    }

                    if ($closedAt -and $closedAt -ge [DateTime]::Parse($sinceISO) -and $closedAt -lt [DateTime]::Parse($untilISO)) {
                        # Get last comment for resolution summary
                        $lastComment = ""
                        try {
                            $commentsJson = gh api "repos/$fullRepo/issues/$($issue.number)/comments?per_page=3&sort=created&direction=desc" 2>&1
                            if ($LASTEXITCODE -eq 0 -and $commentsJson) {
                                $comments = $commentsJson | ConvertFrom-Json -ErrorAction SilentlyContinue
                                if ($comments -and $comments.Count -gt 0) {
                                    $lastComment = TruncateText $comments[0].body 400
                                }
                            }
                        } catch {}

                        $allIssuesClosed += @{
                            Repo       = $repo
                            Number     = $issue.number
                            Title      = $issue.title
                            Labels     = ($issue.labels | ForEach-Object { $_.name }) -join ", "
                            ClosedBy   = if ($issue.closed_by) { $issue.closed_by.login } else { "unknown" }
                            Resolution = $lastComment
                            Closed     = $closedAt.ToString("HH:mm")
                        }
                    }
                }
            }
        }
    } catch {
        Write-Warning "  Issues fetch failed for $repo`: $_"
    }

    # --- Pull Requests ---
    try {
        $prsJson = gh api "repos/$fullRepo/pulls?state=all&sort=updated&direction=desc&per_page=50" 2>&1
        if ($LASTEXITCODE -eq 0 -and $prsJson) {
            $prs = $prsJson | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($prs) {
                foreach ($pr in $prs) {
                    $prCreated = [DateTime]::Parse($pr.created_at)
                    $prMerged  = if ($pr.merged_at) { [DateTime]::Parse($pr.merged_at) } else { $null }
                    $prClosed  = if ($pr.closed_at) { [DateTime]::Parse($pr.closed_at) } else { $null }
                    $prUpdated = [DateTime]::Parse($pr.updated_at)

                    $inWindow = $false
                    $status = ""

                    if ($prCreated -ge [DateTime]::Parse($sinceISO) -and $prCreated -lt [DateTime]::Parse($untilISO)) {
                        $inWindow = $true
                        $status = "Created"
                    }
                    if ($prMerged -and $prMerged -ge [DateTime]::Parse($sinceISO) -and $prMerged -lt [DateTime]::Parse($untilISO)) {
                        $inWindow = $true
                        $status = "Merged"
                    }
                    if (-not $prMerged -and $prClosed -and $prClosed -ge [DateTime]::Parse($sinceISO) -and $prClosed -lt [DateTime]::Parse($untilISO)) {
                        $inWindow = $true
                        $status = "Closed"
                    }

                    if ($inWindow) {
                        # Get files changed count
                        $filesChanged = 0
                        try {
                            $filesJson = gh api "repos/$fullRepo/pulls/$($pr.number)/files?per_page=5" --jq 'length' 2>&1
                            if ($LASTEXITCODE -eq 0) { $filesChanged = [int]$filesJson }
                        } catch {}

                        $allPRs += @{
                            Repo         = $repo
                            Number       = $pr.number
                            Title        = $pr.title
                            Status       = $status
                            Author       = $pr.user.login
                            Labels       = ($pr.labels | ForEach-Object { $_.name }) -join ", "
                            FilesChanged = $filesChanged
                            Body         = TruncateText $pr.body 400
                        }
                    }
                }
            }
        }
    } catch {
        Write-Warning "  PRs fetch failed for $repo`: $_"
    }

    # --- Commits (via API for repos we may not have cloned) ---
    try {
        $commitsJson = gh api "repos/$fullRepo/commits?since=$sinceISO&until=$untilISO&per_page=100" 2>&1
        if ($LASTEXITCODE -eq 0 -and $commitsJson) {
            $commits = $commitsJson | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($commits) {
                foreach ($c in $commits) {
                    $allCommits += @{
                        Repo    = $repo
                        SHA     = $c.sha.Substring(0, 7)
                        Message = ($c.commit.message -split "`n")[0]
                        Author  = if ($c.commit.author) { $c.commit.author.name } else { "unknown" }
                        Date    = if ($c.commit.author.date) { ([DateTime]::Parse($c.commit.author.date)).ToString("HH:mm") } else { "" }
                    }
                }
            }
        }
    } catch {
        Write-Warning "  Commits fetch failed for $repo`: $_"
    }

    Start-Sleep -Milliseconds 200  # Rate limit courtesy
}

Write-Host "  📂 tamirdresher.github.io (blog)..."
try {
    $blogCommits = gh api "repos/$ghOwner/tamirdresher.github.io/commits?since=$sinceISO&until=$untilISO&per_page=20" 2>&1
    if ($LASTEXITCODE -eq 0 -and $blogCommits) {
        $bc = $blogCommits | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($bc) {
            foreach ($c in $bc) {
                $blogActivity += @{
                    SHA     = $c.sha.Substring(0, 7)
                    Message = ($c.commit.message -split "`n")[0]
                    Author  = if ($c.commit.author) { $c.commit.author.name } else { "unknown" }
                }
            }
        }
    }
} catch {}

# --- Ralph Heartbeat Data ---
Write-Host "  🔄 Ralph heartbeat data..."
$ralphDir = Join-Path $env:USERPROFILE ".squad"
foreach ($repo in $squadRepos) {
    $hbFile = Join-Path $ralphDir "ralph-heartbeat-$repo.json"
    if (Test-Path $hbFile) {
        try {
            $hb = Get-Content $hbFile -Raw | ConvertFrom-Json
            $ralphData += @{
                Repo          = $repo
                RoundsTotal   = if ($hb.roundsCompleted) { $hb.roundsCompleted } else { 0 }
                Failures      = if ($hb.failures) { $hb.failures } else { 0 }
                LastRound     = if ($hb.lastRoundAt) { $hb.lastRoundAt } else { "unknown" }
                Status        = if ($hb.status) { $hb.status } else { "unknown" }
                AvgDuration   = if ($hb.avgDurationSeconds) { "$($hb.avgDurationSeconds)s" } else { "N/A" }
            }
        } catch {
            Write-Warning "  Could not parse heartbeat for $repo"
        }
    }
}

# Also check ralph-watch logs
$ralphWatchLog = Join-Path $repoRoot ".squad" "ralph-email-monitor.log"
if (Test-Path $ralphWatchLog) {
    try {
        $logLines = Get-Content $ralphWatchLog -Tail 200
        $recentLines = $logLines | Where-Object {
            if ($_ -match '^\d{4}-\d{2}-\d{2}') {
                try {
                    $lineDate = [DateTime]::Parse(($_ -split '\s')[0])
                    $lineDate -ge [DateTime]::Parse($sinceISO)
                } catch { $false }
            } else { $false }
        }
        if ($recentLines) {
            $communications += @{
                Type    = "Ralph Email Monitor"
                Count   = $recentLines.Count
                Summary = "$(($recentLines | Select-Object -Last 3) -join ' | ')"
            }
        }
    } catch {}
}

# --- Decisions ---
Write-Host "  📝 Decisions..."
$decisionsDir = Join-Path $repoRoot ".squad" "decisions"
if (Test-Path $decisionsDir) {
    try {
        $recentDecisionFiles = git -C $repoRoot log --since=$sinceISO --name-only --pretty=format: -- ".squad/decisions*" 2>&1 |
            Where-Object { $_ -and $_.Trim() } | Sort-Object -Unique
        foreach ($df in $recentDecisionFiles) {
            $fullPath = Join-Path $repoRoot $df
            if (Test-Path $fullPath) {
                $content = Get-Content $fullPath -Raw -ErrorAction SilentlyContinue
                $decisions += @{
                    File    = Split-Path $df -Leaf
                    Content = TruncateText $content 600
                }
            }
        }
    } catch {}
}

# --- Skills ---
Write-Host "  🛠️ Skills..."
try {
    $recentSkillFiles = git -C $repoRoot log --since=$sinceISO --name-only --pretty=format: -- ".squad/skills/" 2>&1 |
        Where-Object { $_ -and $_.Trim() } | Sort-Object -Unique
    foreach ($sf in $recentSkillFiles) {
        $skills += @{ File = $sf }
    }
} catch {}

# --- Research ---
Write-Host "  🔬 Research..."
try {
    $recentResearch = git -C $repoRoot log --since=$sinceISO --name-only --pretty=format: -- ".squad/research/" "research/" 2>&1 |
        Where-Object { $_ -and $_.Trim() } | Sort-Object -Unique
    foreach ($rf in $recentResearch) {
        $research += @{ File = $rf }
    }
} catch {}

# --- Cross-Machine Tasks ---
Write-Host "  🌐 Cross-machine tasks..."
$crossDir = Join-Path $repoRoot ".squad" "cross-machine"
if (Test-Path $crossDir) {
    $taskDirs = @("tasks", "responses")
    foreach ($td in $taskDirs) {
        $dp = Join-Path $crossDir $td
        if (Test-Path $dp) {
            $recentFiles = Get-ChildItem $dp -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTimeUtc -ge [DateTime]::Parse($sinceISO) }
            foreach ($f in $recentFiles) {
                $crossMachine += @{
                    Type = $td
                    File = $f.Name
                    Time = $f.LastWriteTimeUtc.ToString("HH:mm")
                }
            }
        }
    }
}

# ============================================================================
# BUILD HTML REPORT
# ============================================================================

Write-Host "`n📝 Building HTML report..."

$totalIssuesCreated = $allIssuesCreated.Count
$totalIssuesClosed  = $allIssuesClosed.Count
$totalPRs           = $allPRs.Count
$totalCommits       = $allCommits.Count
$totalRalphRounds   = ($ralphData | ForEach-Object { $_.RoundsTotal } | Measure-Object -Sum).Sum
$totalFailures      = ($ralphData | ForEach-Object { $_.Failures } | Measure-Object -Sum).Sum
$mergedPRs          = ($allPRs | Where-Object { $_.Status -eq "Merged" }).Count

$html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body { font-family: 'Segoe UI', Tahoma, Arial, sans-serif; color: #333; max-width: 900px; margin: 0 auto; padding: 20px; background: #f5f5f5; }
  .container { background: #fff; border-radius: 8px; padding: 30px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
  h1 { color: #1a1a2e; border-bottom: 3px solid #4361ee; padding-bottom: 10px; }
  h2 { color: #4361ee; margin-top: 30px; border-bottom: 1px solid #e0e0e0; padding-bottom: 8px; }
  .summary-table { width: 100%; border-collapse: collapse; margin: 15px 0; }
  .summary-table td { padding: 10px 15px; border-bottom: 1px solid #eee; }
  .summary-table td:first-child { font-weight: 600; color: #555; width: 200px; }
  .summary-table td:last-child { font-size: 1.2em; font-weight: 700; color: #4361ee; }
  .item { background: #f8f9fa; border-left: 4px solid #4361ee; padding: 12px 16px; margin: 10px 0; border-radius: 0 6px 6px 0; }
  .item-header { font-weight: 700; color: #1a1a2e; margin-bottom: 6px; }
  .item-meta { font-size: 0.85em; color: #888; margin-bottom: 4px; }
  .item-body { font-size: 0.9em; color: #555; white-space: pre-wrap; word-break: break-word; margin-top: 8px; background: #fff; padding: 8px; border-radius: 4px; }
  .badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 0.75em; font-weight: 600; margin-right: 4px; }
  .badge-created { background: #e3f2fd; color: #1565c0; }
  .badge-merged { background: #e8f5e9; color: #2e7d32; }
  .badge-closed { background: #fce4ec; color: #c62828; }
  .badge-label { background: #f3e5f5; color: #7b1fa2; }
  .repo-tag { background: #fff3e0; color: #e65100; padding: 2px 6px; border-radius: 4px; font-size: 0.8em; font-weight: 600; }
  .empty-section { color: #aaa; font-style: italic; padding: 10px; }
  .ralph-table { width: 100%; border-collapse: collapse; margin: 10px 0; }
  .ralph-table th, .ralph-table td { padding: 8px 12px; border: 1px solid #e0e0e0; text-align: left; }
  .ralph-table th { background: #f0f0f0; font-weight: 600; }
  .footer { margin-top: 30px; padding-top: 15px; border-top: 1px solid #e0e0e0; font-size: 0.8em; color: #aaa; text-align: center; }
</style>
</head>
<body>
<div class="container">

<h1>🏗️ Squad Daily Report — $reportDate</h1>
<p><em>Covering all Squad activity from $($windowStart.ToString("MMM d, yyyy h:mm tt")) to $($windowEnd.ToString("MMM d, yyyy h:mm tt")) Israel time</em></p>

<h2>📊 Summary</h2>
<table class="summary-table">
  <tr><td>Issues Created</td><td>$totalIssuesCreated</td></tr>
  <tr><td>Issues Closed</td><td>$totalIssuesClosed</td></tr>
  <tr><td>PRs (Total / Merged)</td><td>$totalPRs / $mergedPRs</td></tr>
  <tr><td>Commits</td><td>$totalCommits</td></tr>
  <tr><td>Ralph Rounds (total)</td><td>$totalRalphRounds</td></tr>
  <tr><td>Failures</td><td>$totalFailures</td></tr>
  <tr><td>Repos Scanned</td><td>$($squadRepos.Count + 1)</td></tr>
</table>
"@

# --- Issues Created Section ---
$html += "`n<h2>📋 Issues Created ($totalIssuesCreated)</h2>`n"
if ($allIssuesCreated.Count -eq 0) {
    $html += '<p class="empty-section">No issues created in this window.</p>'
} else {
    foreach ($issue in $allIssuesCreated) {
        $labelsHtml = ""
        if ($issue.Labels) {
            foreach ($l in ($issue.Labels -split ", ")) {
                $labelsHtml += "<span class='badge badge-label'>$(HtmlEncode $l)</span>"
            }
        }
        $bodyHtml = if ($issue.Body) { "<div class='item-body'>$(HtmlEncode $issue.Body)</div>" } else { "" }
        $html += @"
<div class="item">
  <div class="item-header"><span class="repo-tag">$($issue.Repo)</span> #$($issue.Number) — $(HtmlEncode $issue.Title)</div>
  <div class="item-meta">Created by <strong>$($issue.Author)</strong> at $($issue.Created) $labelsHtml</div>
  $bodyHtml
</div>
"@
    }
}

# --- Issues Closed Section ---
$html += "`n<h2>✅ Issues Closed ($totalIssuesClosed)</h2>`n"
if ($allIssuesClosed.Count -eq 0) {
    $html += '<p class="empty-section">No issues closed in this window.</p>'
} else {
    foreach ($issue in $allIssuesClosed) {
        $resHtml = if ($issue.Resolution) { "<div class='item-body'><strong>Resolution:</strong> $(HtmlEncode $issue.Resolution)</div>" } else { "" }
        $html += @"
<div class="item">
  <div class="item-header"><span class="repo-tag">$($issue.Repo)</span> #$($issue.Number) — $(HtmlEncode $issue.Title)</div>
  <div class="item-meta">Closed by <strong>$($issue.ClosedBy)</strong> at $($issue.Closed)</div>
  $resHtml
</div>
"@
    }
}

# --- Pull Requests Section ---
$html += "`n<h2>🔀 Pull Requests ($totalPRs)</h2>`n"
if ($allPRs.Count -eq 0) {
    $html += '<p class="empty-section">No PR activity in this window.</p>'
} else {
    foreach ($pr in $allPRs) {
        $statusClass = switch ($pr.Status) {
            "Merged"  { "badge-merged" }
            "Closed"  { "badge-closed" }
            default   { "badge-created" }
        }
        $labelsHtml = ""
        if ($pr.Labels) {
            foreach ($l in ($pr.Labels -split ", ")) {
                $labelsHtml += "<span class='badge badge-label'>$(HtmlEncode $l)</span>"
            }
        }
        $bodyHtml = if ($pr.Body) { "<div class='item-body'>$(HtmlEncode $pr.Body)</div>" } else { "" }
        $html += @"
<div class="item">
  <div class="item-header"><span class="repo-tag">$($pr.Repo)</span> #$($pr.Number) — $(HtmlEncode $pr.Title)</div>
  <div class="item-meta"><span class="badge $statusClass">$($pr.Status)</span> by <strong>$($pr.Author)</strong> · $($pr.FilesChanged) files $labelsHtml</div>
  $bodyHtml
</div>
"@
    }
}

# --- Commits Section ---
$html += "`n<h2>💾 Key Commits ($totalCommits)</h2>`n"
if ($allCommits.Count -eq 0) {
    $html += '<p class="empty-section">No commits in this window.</p>'
} else {
    # Group by repo
    $commitsByRepo = $allCommits | Group-Object { $_.Repo }
    foreach ($group in $commitsByRepo) {
        $html += "<h3><span class='repo-tag'>$($group.Name)</span> ($($group.Count) commits)</h3>`n"
        foreach ($c in $group.Group | Select-Object -First 20) {
            $html += @"
<div class="item">
  <div class="item-header"><code>$($c.SHA)</code> $(HtmlEncode $c.Message)</div>
  <div class="item-meta">by <strong>$($c.Author)</strong> at $($c.Date)</div>
</div>
"@
        }
        if ($group.Count -gt 20) {
            $html += "<p class='item-meta'>... and $($group.Count - 20) more commits</p>"
        }
    }
}

# --- Ralph Activity Section ---
$html += "`n<h2>🔄 Ralph Activity</h2>`n"
if ($ralphData.Count -eq 0) {
    $html += '<p class="empty-section">No Ralph heartbeat data found.</p>'
} else {
    $html += @"
<table class="ralph-table">
  <tr><th>Repo</th><th>Rounds</th><th>Failures</th><th>Status</th><th>Avg Duration</th><th>Last Round</th></tr>
"@
    foreach ($r in $ralphData) {
        $html += "<tr><td>$($r.Repo)</td><td>$($r.RoundsTotal)</td><td>$($r.Failures)</td><td>$($r.Status)</td><td>$($r.AvgDuration)</td><td>$($r.LastRound)</td></tr>`n"
    }
    $html += "</table>"
}

# --- Decisions Section ---
$html += "`n<h2>📝 Decisions Made ($($decisions.Count))</h2>`n"
if ($decisions.Count -eq 0) {
    $html += '<p class="empty-section">No new decisions recorded.</p>'
} else {
    foreach ($d in $decisions) {
        $html += @"
<div class="item">
  <div class="item-header">$($d.File)</div>
  <div class="item-body">$(HtmlEncode $d.Content)</div>
</div>
"@
    }
}

# --- Research & Skills Section ---
$html += "`n<h2>🔬 Research &amp; Skills</h2>`n"
$hasResearchOrSkills = ($research.Count + $skills.Count) -gt 0
if (-not $hasResearchOrSkills) {
    $html += '<p class="empty-section">No research reports or skill changes.</p>'
} else {
    if ($research.Count -gt 0) {
        $html += "<h3>Research ($($research.Count) files)</h3>`n"
        foreach ($r in $research) {
            $html += "<div class='item'><div class='item-header'>$($r.File)</div></div>`n"
        }
    }
    if ($skills.Count -gt 0) {
        $html += "<h3>Skills ($($skills.Count) files)</h3>`n"
        foreach ($s in $skills) {
            $html += "<div class='item'><div class='item-header'>$($s.File)</div></div>`n"
        }
    }
}

# --- Communications Section ---
$html += "`n<h2>📬 Communications</h2>`n"
if ($communications.Count -eq 0) {
    $html += '<p class="empty-section">No communications logged.</p>'
} else {
    foreach ($c in $communications) {
        $html += @"
<div class="item">
  <div class="item-header">$($c.Type) ($($c.Count) entries)</div>
  <div class="item-body">$(HtmlEncode $c.Summary)</div>
</div>
"@
    }
}

# --- Cross-Machine Section ---
$html += "`n<h2>🌐 Cross-Machine ($($crossMachine.Count))</h2>`n"
if ($crossMachine.Count -eq 0) {
    $html += '<p class="empty-section">No cross-machine activity.</p>'
} else {
    foreach ($cm in $crossMachine) {
        $html += @"
<div class="item">
  <div class="item-header"><span class="badge badge-created">$($cm.Type)</span> $($cm.File)</div>
  <div class="item-meta">at $($cm.Time) UTC</div>
</div>
"@
    }
}

# --- Blog Activity Section ---
if ($blogActivity.Count -gt 0) {
    $html += "`n<h2>📰 Blog Activity ($($blogActivity.Count))</h2>`n"
    foreach ($b in $blogActivity) {
        $html += @"
<div class="item">
  <div class="item-header"><code>$($b.SHA)</code> $(HtmlEncode $b.Message)</div>
  <div class="item-meta">by <strong>$($b.Author)</strong></div>
</div>
"@
    }
}

# --- Footer ---
$html += @"

<div class="footer">
  Generated by Squad Daily Report at $($nowIsrael.ToString("MMM d, yyyy h:mm:ss tt")) Israel time<br>
  Repos scanned: $($squadRepos -join ", "), tamirdresher.github.io
</div>

</div>
</body>
</html>
"@

# ============================================================================
# SAVE / SEND REPORT
# ============================================================================

# Save report if requested
if ($SaveTo) {
    $html | Out-File $SaveTo -Encoding utf8
    Write-Host "💾 Report saved to: $SaveTo"
}

# Always save a copy for the record
$reportArchiveDir = Join-Path $env:USERPROFILE ".squad" "daily-reports"
if (-not (Test-Path $reportArchiveDir)) {
    New-Item $reportArchiveDir -ItemType Directory -Force | Out-Null
}
$archivePath = Join-Path $reportArchiveDir "squad-daily-report-$reportDate.html"
$html | Out-File $archivePath -Encoding utf8
Write-Host "📁 Archived to: $archivePath"

if ($DryRun) {
    Write-Host "🏃 DRY RUN — skipping email and Teams send."
    Write-Host "   Report contains: $totalIssuesCreated issues created, $totalIssuesClosed closed, $totalPRs PRs, $totalCommits commits"
    exit 0
}

# ============================================================================
# SEND TEAMS WEBHOOK — Adaptive Card summary
# ============================================================================

$teamsWebhookFile = Join-Path $env:USERPROFILE ".squad" "teams-webhook.url"
if (Test-Path $teamsWebhookFile) {
    Write-Host "`n📨 Sending Teams summary card..."
    try {
        $teamsWebhookUrl = (Get-Content $teamsWebhookFile -Raw -Encoding utf8).Trim()

        if (-not [string]::IsNullOrWhiteSpace($teamsWebhookUrl)) {
            # Build compact adaptive-card sections
            $cardSections = @()

            # Header
            $cardSections += @{
                type   = "TextBlock"
                text   = "🏗️ **Squad Daily Report — $reportDate**"
                size   = "Large"
                weight = "Bolder"
                wrap   = $true
            }
            $cardSections += @{
                type  = "TextBlock"
                text  = "_$($windowStart.ToString("MMM d HH:mm")) → $($windowEnd.ToString("MMM d HH:mm")) Israel_"
                isSubtle = $true
                wrap  = $true
            }

            # Summary stats (FactSet)
            $facts = @(
                @{ title = "Issues Created";  value = "$totalIssuesCreated" }
                @{ title = "Issues Closed";   value = "$totalIssuesClosed" }
                @{ title = "PRs (Total/Merged)"; value = "$totalPRs / $mergedPRs" }
                @{ title = "Commits";          value = "$totalCommits" }
                @{ title = "Repos Scanned";    value = "$($squadRepos.Count + 1)" }
            )
            if ($totalFailures -gt 0) {
                $facts += @{ title = "⚠️ Ralph Failures"; value = "$totalFailures" }
            }
            $cardSections += @{
                type  = "FactSet"
                facts = $facts
            }

            # Issues Created highlights (top 5)
            if ($allIssuesCreated.Count -gt 0) {
                $cardSections += @{ type = "TextBlock"; text = "**📋 Issues Created**"; weight = "Bolder"; wrap = $true }
                $top5 = $allIssuesCreated | Select-Object -First 5
                $issueLines = $top5 | ForEach-Object { "• [$($_.Repo)#$($_.Number)] $($_.Title)" }
                if ($allIssuesCreated.Count -gt 5) { $issueLines += "  _…and $($allIssuesCreated.Count - 5) more_" }
                $cardSections += @{ type = "TextBlock"; text = ($issueLines -join "`n"); wrap = $true; spacing = "None" }
            }

            # Issues Closed highlights (top 5)
            if ($allIssuesClosed.Count -gt 0) {
                $cardSections += @{ type = "TextBlock"; text = "**✅ Issues Closed**"; weight = "Bolder"; wrap = $true }
                $top5c = $allIssuesClosed | Select-Object -First 5
                $closedLines = $top5c | ForEach-Object { "• [$($_.Repo)#$($_.Number)] $($_.Title)" }
                if ($allIssuesClosed.Count -gt 5) { $closedLines += "  _…and $($allIssuesClosed.Count - 5) more_" }
                $cardSections += @{ type = "TextBlock"; text = ($closedLines -join "`n"); wrap = $true; spacing = "None" }
            }

            # PRs highlights
            if ($allPRs.Count -gt 0) {
                $cardSections += @{ type = "TextBlock"; text = "**🔀 Pull Requests**"; weight = "Bolder"; wrap = $true }
                $prLines = $allPRs | Select-Object -First 5 | ForEach-Object {
                    $icon = switch ($_.Status) { "Merged" { "🟢" } "Closed" { "🔴" } default { "🔵" } }
                    "$icon [$($_.Repo)#$($_.Number)] $($_.Title)"
                }
                if ($allPRs.Count -gt 5) { $prLines += "  _…and $($allPRs.Count - 5) more_" }
                $cardSections += @{ type = "TextBlock"; text = ($prLines -join "`n"); wrap = $true; spacing = "None" }
            }

            # Decisions
            if ($decisions.Count -gt 0) {
                $cardSections += @{ type = "TextBlock"; text = "**📝 New Decisions: $($decisions.Count)**"; weight = "Bolder"; wrap = $true }
                $decLines = $decisions | ForEach-Object { "• $($_.File)" }
                $cardSections += @{ type = "TextBlock"; text = ($decLines -join "`n"); wrap = $true; spacing = "None" }
            }

            # Ralph failures warning
            if ($totalFailures -gt 0) {
                $cardSections += @{
                    type            = "TextBlock"
                    text            = "⚠️ **$totalFailures Ralph failure(s) require attention!**"
                    color           = "Attention"
                    weight          = "Bolder"
                    wrap            = $true
                }
            }

            # Build Adaptive Card payload
            $teamsCard = @{
                type        = "message"
                attachments = @(
                    @{
                        contentType = "application/vnd.microsoft.card.adaptive"
                        content     = @{
                            type      = "AdaptiveCard"
                            '$schema' = "http://adaptivecards.io/schemas/adaptive-card.json"
                            version   = "1.4"
                            body      = $cardSections
                            msteams   = @{ width = "Full" }
                        }
                    }
                )
            }

            $teamsBody = $teamsCard | ConvertTo-Json -Depth 20 -Compress
            $teamsResp = Invoke-RestMethod -Uri $teamsWebhookUrl -Method Post `
                -Body $teamsBody -ContentType "application/json; charset=utf-8" -ErrorAction Stop
            Write-Host "✅ Teams card sent successfully."
        } else {
            Write-Warning "Teams webhook URL file is empty — skipping Teams notification."
        }
    } catch {
        Write-Warning "⚠ Teams webhook send failed: $_  (email will still be sent)"
    }
} else {
    Write-Warning "Teams webhook file not found at $teamsWebhookFile — skipping Teams notification."
}

# Send via Gmail SMTP directly (body is too large for command-line args)
$subject = "Squad Daily Report — $reportDate"
Write-Host "`n📧 Sending report to $To via Gmail SMTP..."

try {
    # Get Gmail credentials from Credential Manager
    $credCode = @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public class CredReaderReport
{
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool CredRead(
        string target,
        uint type, int flags, out IntPtr CredentialPtr);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern void CredFree(IntPtr cred);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL
    {
        public UInt32 Flags;
        public UInt32 Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize;
        public IntPtr CredentialBlob;
        public UInt32 Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    public static string GetPassword(string targetName)
    {
        IntPtr credPtr = IntPtr.Zero;
        try
        {
            if (CredRead(targetName, 1, 0, out credPtr))
            {
                CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
                if (cred.CredentialBlobSize > 0)
                {
                    byte[] buffer = new byte[cred.CredentialBlobSize];
                    Marshal.Copy(cred.CredentialBlob, buffer, 0, (int)cred.CredentialBlobSize);
                    return Encoding.Unicode.GetString(buffer);
                }
            }
            return null;
        }
        finally
        {
            if (credPtr != IntPtr.Zero) CredFree(credPtr);
        }
    }
}
'@
    try { Add-Type -TypeDefinition $credCode -Language CSharp -ErrorAction Stop } catch {}

    $gmailPassword = $null
    # Try env var first
    if (Test-Path env:SQUAD_GMAIL_PASSWORD) {
        $gmailPassword = $env:SQUAD_GMAIL_PASSWORD
    } else {
        $gmailPassword = [CredReaderReport]::GetPassword("squad-email-gmail")
    }

    if (-not $gmailPassword) {
        Write-Error "❌ No Gmail credentials found (key: squad-email-gmail)"
        exit 1
    }

    $gmailUser = "tdsquadai@gmail.com"
    $secPass = ConvertTo-SecureString $gmailPassword -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($gmailUser, $secPass)

    $mailParams = @{
        SmtpServer  = "smtp.gmail.com"
        Port        = 587
        UseSsl      = $true
        Credential  = $cred
        From        = "Squad Daily Report <$gmailUser>"
        To          = $To
        Subject     = $subject
        Body        = $html
        BodyAsHtml  = $true
    }

    $maxRetries = 3
    $sent = $false
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            Send-MailMessage @mailParams -ErrorAction Stop
            $sent = $true
            Write-Host "✅ Report sent successfully to $To (attempt $attempt)"
            break
        } catch {
            Write-Warning "⚠ Send attempt $attempt failed: $_"
            if ($attempt -lt $maxRetries) {
                $delay = [Math]::Pow(2, $attempt)
                Write-Host "   Retrying in ${delay}s..."
                Start-Sleep -Seconds $delay
            }
        }
    }

    if (-not $sent) {
        Write-Error "❌ All send attempts failed"
        exit 1
    }
} catch {
    Write-Error "❌ Email send failed: $_"
    exit 1
}

# ============================================================================
# WRITE DEDUP MARKERS (after successful send)
# ============================================================================

# Local marker — prevents this machine from re-sending
$reportDate | Out-File $localMarker -Force
Write-Host "Local marker written: $localMarker"

# Git marker — prevents other machines from sending
$gitMarkerContent = @{
    date = $reportDate
    machine = $env:COMPUTERNAME
    sentAt = (Get-Date -Format "o")
} | ConvertTo-Json

$gitMarkerContent | Out-File $gitMarker -Force -Encoding utf8

Push-Location $repoRoot
try {
    git add ".squad/daily-report-last-sent.json" 2>$null
    git commit -m "chore: daily report sent for $reportDate by $env:COMPUTERNAME" --quiet 2>$null
    git push --quiet 2>$null
    Write-Host "Git marker pushed — other machines will skip this report."
} catch {
    Write-Warning "Could not push git marker: $_. Other machines may also send."
}
Pop-Location

Write-Host "✅ Daily Squad Report complete for $reportDate"
