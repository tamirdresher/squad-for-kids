#!/usr/bin/env pwsh
# .squad/scripts/notes-read.ps1
# Read squad notes for a commit across all (or specified) namespaces.
# Useful for humans and for agents querying context.
#
# Usage:
#   .squad/scripts/notes-read.ps1 -CommitSha <sha>                    # all namespaces
#   .squad/scripts/notes-read.ps1 -CommitSha <sha> -Agent data         # one namespace
#   .squad/scripts/notes-read.ps1 -CommitSha <sha> -Format json        # machine-readable
#   .squad/scripts/notes-read.ps1 -CommitSha HEAD                      # resolve HEAD

param(
    [Parameter(Mandatory)][string]$CommitSha,
    [string]$Agent = "",         # empty = all namespaces
    [ValidateSet("human","json")][string]$Format = "human"
)

# Resolve symbolic refs (HEAD, ORIG_HEAD, etc.)
if ($CommitSha -notmatch '^[0-9a-f]{40}$') {
    $resolved = git rev-parse $CommitSha 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Cannot resolve '$CommitSha': $resolved"
        exit 1
    }
    $CommitSha = $resolved.Trim()
}

$namespaces = if ($Agent) { @($Agent) } else {
    @('data','worf','belanna','picard','q','scribe','ralph')
}

$allEntries = @()

foreach ($ns in $namespaces) {
    $blob = git notes --ref="squad/$ns" show $CommitSha 2>&1
    if ($LASTEXITCODE -ne 0) { continue }

    # Parse JSONL
    $blob -split "`n" | Where-Object { $_.Trim() } | ForEach-Object {
        try {
            $entry = $_ | ConvertFrom-Json -ErrorAction Stop
            $entry | Add-Member -NotePropertyName '_namespace' -NotePropertyValue "squad/$ns" -Force
            $allEntries += $entry
        } catch {
            Write-Warning "Malformed note in squad/$ns: $_"
        }
    }
}

if ($allEntries.Count -eq 0) {
    if ($Format -eq "json") {
        Write-Output "[]"
    } else {
        Write-Host "No squad notes found for $($CommitSha.Substring(0,8))" -ForegroundColor DarkGray
    }
    exit 0
}

# Sort by timestamp
$allEntries = $allEntries | Sort-Object { $_.timestamp }

if ($Format -eq "json") {
    $allEntries | ConvertTo-Json -Depth 10
    exit 0
}

# Human-readable output
Write-Host ""
Write-Host "Squad notes for commit $($CommitSha.Substring(0,8))" -ForegroundColor Cyan
Write-Host ("─" * 60) -ForegroundColor DarkGray

foreach ($entry in $allEntries) {
    $promotedFlag = if ($entry.content.promotionCandidate) { " [PROMOTE]" } else { "" }
    $severityFlag = if ($entry.content.severity) { " [$($entry.content.severity.ToUpper())]" } else { "" }

    Write-Host ""
    Write-Host "[$($entry.timestamp.Substring(0,19))] $($entry._namespace) ($($entry.instanceId))$promotedFlag$severityFlag" -ForegroundColor Yellow
    Write-Host "Type: $($entry.type) | Confidence: $($entry.content.confidence)" -ForegroundColor DarkGray
    Write-Host $entry.content.summary -ForegroundColor White

    if ($entry.content.reasoning) {
        Write-Host ""
        Write-Host $entry.content.reasoning -ForegroundColor Gray
    }

    if ($entry.content.alternatives -and $entry.content.alternatives.Count -gt 0) {
        Write-Host ""
        Write-Host "Alternatives:" -ForegroundColor DarkGray
        $entry.content.alternatives | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkGray }
    }

    if ($entry.tags -and $entry.tags.Count -gt 0) {
        Write-Host "Tags: $($entry.tags -join ', ')" -ForegroundColor DarkGray
    }

    if ($entry.refs.prNumber) {
        Write-Host "PR: #$($entry.refs.prNumber)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host ("─" * 60) -ForegroundColor DarkGray
Write-Host "$($allEntries.Count) note entries across $($namespaces.Count) namespace(s)" -ForegroundColor DarkGray
