<#
.SYNOPSIS
    Trims a Squad agent's history.md to the hot/cold tier pattern.

.DESCRIPTION
    When history.md exceeds MaxEntries dated entries (### {date}:) or MaxKB kilobytes,
    moves the oldest entries to history-archive.md as condensed summaries, keeping only
    the last MaxEntries entries plus Core Context and Active Context sections in history.md.

    This script is invoked by Scribe after orchestration rounds.

.PARAMETER Agent
    Agent name (folder under .squad/agents/{Agent}/).

.PARAMETER RepoRoot
    Absolute path to the repo root. Defaults to git rev-parse --show-toplevel.

.PARAMETER MaxEntries
    Maximum number of dated entries (### YYYY-...) to keep in history.md. Default: 20.

.PARAMETER MaxKB
    Maximum kilobytes for history.md before archival is triggered. Default: 15.

.PARAMETER WhatIf
    Show what would be archived without making changes.

.EXAMPLE
    ./.squad/scripts/Trim-AgentHistory.ps1 -Agent seven
    ./.squad/scripts/Trim-AgentHistory.ps1 -Agent worf -MaxEntries 15
    ./.squad/scripts/Trim-AgentHistory.ps1 -Agent picard -WhatIf
#>
param(
    [Parameter(Mandatory)]
    [string]$Agent,

    [string]$RepoRoot = "",

    [int]$MaxEntries = 20,

    [int]$MaxKB = 15,

    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve repo root
if (-not $RepoRoot) {
    $RepoRoot = (git rev-parse --show-toplevel 2>$null).Trim()
    if (-not $RepoRoot) {
        throw "Could not determine repo root. Pass -RepoRoot explicitly."
    }
}

$agentDir   = Join-Path $RepoRoot ".squad\agents\$Agent"
$historyPath = Join-Path $agentDir "history.md"
$archivePath = Join-Path $agentDir "history-archive.md"

if (-not (Test-Path $historyPath)) {
    Write-Error "history.md not found: $historyPath"
    exit 1
}

# ------------------------------------------------------------------
# Read and parse history.md
# ------------------------------------------------------------------
$raw = Get-Content $historyPath -Raw -Encoding utf8

# Split into logical blocks. We identify:
#   - "Core Context" block  (## Core Context ... next ##)
#   - "Current Quarter" header
#   - "Active Context" block (## Active Context ... next ##)
#   - Dated entries (### YYYY-...:)
# Strategy: split on lines starting with ### that look like date entries
$lines = $raw -split "`r?`n"

$coreLines       = [System.Collections.Generic.List[string]]::new()
$activeLines     = [System.Collections.Generic.List[string]]::new()
$headerLines     = [System.Collections.Generic.List[string]]::new()  # file header before Core Context
$entries         = [System.Collections.Generic.List[hashtable]]::new()

$mode = "header"
$currentEntry = $null

foreach ($line in $lines) {
    if ($mode -eq "header" -and $line -match "^## Core Context") {
        $mode = "core"
        $coreLines.Add($line) | Out-Null
        continue
    }

    if ($mode -eq "header") {
        $headerLines.Add($line) | Out-Null
        continue
    }

    if ($mode -eq "core" -and $line -match "^## (?!Core)") {
        $mode = "between"
        # fall through to handle this line in between/active modes
    } elseif ($mode -eq "core") {
        $coreLines.Add($line) | Out-Null
        continue
    }

    if ($mode -eq "between" -and $line -match "^## Active Context") {
        $mode = "active"
        $activeLines.Add($line) | Out-Null
        continue
    }

    if ($mode -eq "active" -and $line -match "^### \d{4}") {
        $mode = "entries"
        # fall through
    } elseif ($mode -eq "active") {
        $activeLines.Add($line) | Out-Null
        continue
    }

    # Current Quarter and other ## headers between sections
    if ($mode -eq "between" -and $line -match "^## ") {
        $headerLines.Add($line) | Out-Null
        continue
    }
    if ($mode -eq "between" -and $line -match "^### \d{4}") {
        $mode = "entries"
        # fall through
    } elseif ($mode -eq "between") {
        $headerLines.Add($line) | Out-Null
        continue
    }

    # Dated entries
    if ($line -match "^### (\d{4}[^#].*)$") {
        if ($null -ne $currentEntry) {
            $entries.Add($currentEntry) | Out-Null
        }
        $currentEntry = @{ header = $line; lines = [System.Collections.Generic.List[string]]::new() }
        continue
    }

    if ($null -ne $currentEntry) {
        $currentEntry.lines.Add($line) | Out-Null
    } else {
        # Lines before first dated entry (e.g., "## Learnings" section header)
        $headerLines.Add($line) | Out-Null
    }
}
if ($null -ne $currentEntry) {
    $entries.Add($currentEntry) | Out-Null
}

$totalEntries = $entries.Count
$fileSizeKB   = [math]::Round((Get-Item $historyPath).Length / 1024, 1)

Write-Host "Agent: $Agent"
Write-Host "history.md: $fileSizeKB KB, $totalEntries dated entries"

# ------------------------------------------------------------------
# Check if trimming is needed
# ------------------------------------------------------------------
if ($totalEntries -le $MaxEntries -and $fileSizeKB -le $MaxKB) {
    Write-Host "No trimming needed (within $MaxEntries entries / $MaxKB KB limits)."
    exit 0
}

if ($totalEntries -le $MaxEntries -and $fileSizeKB -gt $MaxKB) {
    # File is large but entry count is within limits — entries themselves are verbose.
    # Archive the oldest half of entries to bring the file down.
    Write-Warning "history.md is $fileSizeKB KB but only $totalEntries entries. Entries are unusually large."
    Write-Warning "Will archive oldest $([math]::Floor($totalEntries / 2)) entries to reduce file size."
}

$toArchiveCount = if ($totalEntries -gt $MaxEntries) {
    [math]::Max(0, $totalEntries - $MaxEntries)
} elseif ($fileSizeKB -gt $MaxKB -and $totalEntries -gt 4) {
    # KB-only trigger: archive oldest half
    [math]::Floor($totalEntries / 2)
} else {
    0
}
Write-Host "Will archive $toArchiveCount oldest entries (keeping last $MaxEntries)."

if ($WhatIf) {
    Write-Host "[WhatIf] Would archive entries:"
    for ($i = 0; $i -lt $toArchiveCount; $i++) {
        Write-Host "  - $($entries[$i].header)"
    }
    exit 0
}

# ------------------------------------------------------------------
# Build archive summaries for entries being moved
# ------------------------------------------------------------------
$archiveSummaries = [System.Text.StringBuilder]::new()

for ($i = 0; $i -lt $toArchiveCount; $i++) {
    $entry = $entries[$i]
    $entryTitle = $entry.header -replace "^### ", ""
    $entryText  = $entry.lines -join "`n"

    # Extract key metadata from common patterns in entry text
    $outcome = "Completed work on $entryTitle"
    if ($entryText -match "(?m)^\*\*Outcome[:\*]+\*?\*?\s*(.+)$") { $outcome = $Matches[1].Trim() }
    elseif ($entryText -match "(?m)^.*✅\s+(.+)$") { $outcome = $Matches[1].Trim() }

    $filesChanged = "see git history"
    if ($entryText -match "(?m)^\*\*Files?[:\*]+\*?\*?\s*(.+)$") { $filesChanged = $Matches[1].Trim() }

    $archiveSummaries.AppendLine("") | Out-Null
    $archiveSummaries.AppendLine("### $entryTitle (archived)") | Out-Null
    $archiveSummaries.AppendLine("**Outcome:** $outcome") | Out-Null
    $archiveSummaries.AppendLine("**Key learnings:** See full entry in git history or quarterly archive") | Out-Null
    $archiveSummaries.AppendLine("**Files changed:** $filesChanged") | Out-Null
}

# ------------------------------------------------------------------
# Write to history-archive.md
# ------------------------------------------------------------------
if (Test-Path $archivePath) {
    $archiveContent = Get-Content $archivePath -Raw -Encoding utf8
} else {
    $archiveContent = "# $Agent — History Archive`n`nSummarized older entries. Recent activity tracked in history.md.`n`n## Learnings`n"
}

$newArchive = $archiveContent.TrimEnd() + "`n" + $archiveSummaries.ToString()
Set-Content -Path $archivePath -Value $newArchive -Encoding utf8 -NoNewline
Write-Host "Wrote $toArchiveCount summary entries to history-archive.md"

# ------------------------------------------------------------------
# Rebuild history.md with only last MaxEntries entries
# ------------------------------------------------------------------
$keepEntries = $entries | Select-Object -Last $MaxEntries

$sb = [System.Text.StringBuilder]::new()

# File header
foreach ($l in $headerLines) { $sb.AppendLine($l) | Out-Null }

# Core Context
foreach ($l in $coreLines) { $sb.AppendLine($l) | Out-Null }

# Active Context (if any)
if ($activeLines.Count -gt 0) {
    foreach ($l in $activeLines) { $sb.AppendLine($l) | Out-Null }
}

# A note about archived entries
$sb.AppendLine("") | Out-Null
$sb.AppendLine("> **History cap enforced:** $toArchiveCount older entries moved to history-archive.md. Hot layer capped at $MaxEntries entries.") | Out-Null
$sb.AppendLine("") | Out-Null

# Keep entries
foreach ($entry in $keepEntries) {
    $sb.AppendLine($entry.header) | Out-Null
    foreach ($l in $entry.lines) { $sb.AppendLine($l) | Out-Null }
}

Set-Content -Path $historyPath -Value $sb.ToString().TrimEnd() -Encoding utf8 -NoNewline
Write-Host "Rewrote history.md — now contains $($keepEntries.Count) dated entries."
Write-Host ""
Write-Host "Done. Commit suggestion:"
Write-Host "  chore(scribe): archive $toArchiveCount entries for $Agent — history.md at threshold"