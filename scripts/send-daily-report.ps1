#!/usr/bin/env pwsh
# Squad Fleet Daily Report — sends summary of all sub-company squads via Teams webhook
# Scheduled to run daily at 8:00 AM Israel time

param(
    [switch]$DryRun,
    [string]$WebhookUrlFile = "$env:USERPROFILE\.squad\teams-webhook.url",
    [string]$ReportDir = "$env:USERPROFILE\.squad\daily-reports"
)

$ErrorActionPreference = "Continue"
$date = Get-Date -Format "yyyy-MM-dd"
$yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-ddT00:00:00Z")
$today = (Get-Date).ToString("yyyy-MM-ddT00:00:00Z")

# All sub-company repos
$repos = @(
    @{ Name = "HQ (tamresearch1)";      Repo = "tamirdresher_microsoft/tamresearch1";    Auth = "tamirdresher_microsoft" }
    @{ Name = "JellyBolt Games";         Repo = "tamirdresher/jellybolt-games";           Auth = "tamirdresher" }
    @{ Name = "Content Empire";          Repo = "tamirdresher/content-empire";            Auth = "tamirdresher" }
    @{ Name = "Ventures & IP";           Repo = "tamirdresher/ventures-ip";               Auth = "tamirdresher" }
    @{ Name = "Research Squad";          Repo = "tamirdresher/tamresearch1-research";     Auth = "tamirdresher" }
    @{ Name = "Squad Monitor";           Repo = "tamirdresher/squad-monitor-standalone";  Auth = "tamirdresher" }
    @{ Name = "Squad on AKS";            Repo = "tamirdresher/squad-on-aks";              Auth = "tamirdresher" }
)

Write-Host "📊 Generating Squad Fleet Daily Report — $date"

$sections = @()
$totalIssuesCreated = 0
$totalIssuesClosed = 0
$totalPRs = 0
$totalCommits = 0

foreach ($r in $repos) {
    $name = $r.Name
    $repo = $r.Repo
    
    Write-Host "  Scanning $name..."
    
    # Switch auth if needed
    $currentAuth = (gh auth status 2>&1 | Select-String "Logged in to github.com account" | ForEach-Object { $_ -replace '.*account\s+(\S+).*','$1' }) 
    if ($currentAuth -ne $r.Auth) {
        gh auth switch --user $r.Auth 2>&1 | Out-Null
    }
    
    # Issues created in last 24h
    $created = @()
    try {
        $created = gh issue list --repo $repo --state all --search "created:>=$($yesterday.Substring(0,10))" --json number,title,state,labels --limit 50 2>$null | ConvertFrom-Json
    } catch {}
    
    # Issues closed in last 24h
    $closed = @()
    try {
        $closed = gh issue list --repo $repo --state closed --search "closed:>=$($yesterday.Substring(0,10))" --json number,title --limit 50 2>$null | ConvertFrom-Json
    } catch {}
    
    # PRs merged in last 24h
    $prs = @()
    try {
        $prs = gh pr list --repo $repo --state merged --search "merged:>=$($yesterday.Substring(0,10))" --json number,title --limit 20 2>$null | ConvertFrom-Json
    } catch {}
    
    $issueCount = if ($created) { $created.Count } else { 0 }
    $closedCount = if ($closed) { $closed.Count } else { 0 }
    $prCount = if ($prs) { $prs.Count } else { 0 }
    
    $totalIssuesCreated += $issueCount
    $totalIssuesClosed += $closedCount
    $totalPRs += $prCount
    
    # Build facts for this repo
    $facts = @(
        @{ name = "Issues Created"; value = "$issueCount" }
        @{ name = "Issues Closed"; value = "$closedCount" }
        @{ name = "PRs Merged"; value = "$prCount" }
    )
    
    # Add top issue titles
    if ($created -and $created.Count -gt 0) {
        $topIssues = ($created | Select-Object -First 5 | ForEach-Object { "#$($_.number) $($_.title)" }) -join "`n"
        $facts += @{ name = "Recent Issues"; value = $topIssues }
    }
    
    $sections += @{
        activityTitle = "📦 $name"
        facts = $facts
    }
}

# Check Ralph fleet status
$ralphPids = @(7224, 28136, 132796, 34908, 141280, 100744)
$ralphNames = @("Main", "JellyBolt", "Squad Monitor", "Content Empire", "Research", "Ventures")
$aliveCount = 0
$ralphStatus = @()
for ($i = 0; $i -lt $ralphPids.Count; $i++) {
    $alive = Get-Process -Id $ralphPids[$i] -ErrorAction SilentlyContinue
    if ($alive) {
        $aliveCount++
        $ralphStatus += "✅ $($ralphNames[$i])"
    } else {
        $ralphStatus += "❌ $($ralphNames[$i]) (PID $($ralphPids[$i]) dead)"
    }
}

$sections += @{
    activityTitle = "🔄 Ralph Fleet Status ($aliveCount/$($ralphPids.Count) alive)"
    facts = @(
        @{ name = "Status"; value = ($ralphStatus -join ", ") }
    )
}

# Build Teams MessageCard
$message = @{
    "@type" = "MessageCard"
    "@context" = "https://schema.org/extensions"
    summary = "Squad Fleet Daily Report — $date"
    themeColor = "0078D4"
    title = "📊 Squad Fleet Daily Report — $date"
    sections = @(
        @{
            activityTitle = "📈 Fleet Summary"
            facts = @(
                @{ name = "Total Issues Created"; value = "$totalIssuesCreated" }
                @{ name = "Total Issues Closed"; value = "$totalIssuesClosed" }
                @{ name = "Total PRs Merged"; value = "$totalPRs" }
                @{ name = "Squads Scanned"; value = "$($repos.Count)" }
                @{ name = "Ralphs Alive"; value = "$aliveCount / $($ralphPids.Count)" }
            )
        }
    ) + $sections
}

$body = $message | ConvertTo-Json -Depth 10

# Save report locally
if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null }
$reportFile = Join-Path $ReportDir "squad-fleet-report-$date.json"
$body | Out-File $reportFile -Encoding utf8
Write-Host "📄 Report saved to $reportFile"

# Send via webhook
if ($DryRun) {
    Write-Host "🏃 DRY RUN — not sending to Teams"
    Write-Host $body
} else {
    if (Test-Path $WebhookUrlFile) {
        $webhookUrl = (Get-Content $WebhookUrlFile -Raw).Trim()
        try {
            Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json; charset=utf-8"
            Write-Host "✅ Report sent to Teams!"
        } catch {
            Write-Host "❌ Failed to send to Teams: $_"
        }
    } else {
        Write-Host "⚠️ No webhook URL found at $WebhookUrlFile — report saved locally only"
    }
}

Write-Host "Done! 🎉"
