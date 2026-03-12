<#
.SYNOPSIS
    Calculates code churn rate metrics from git history.

.DESCRIPTION
    Analyzes git log to compute churn metrics (lines added + deleted) per file and author.
    Identifies hot spots — files with high churn that may indicate instability.

.PARAMETER StartDate
    Start of the date range (default: 30 days ago).

.PARAMETER EndDate
    End of the date range (default: today).

.PARAMETER Branch
    Git branch to analyze (default: current branch).

.PARAMETER PathFilter
    Glob pattern to filter files (e.g. "src/*.ps1").

.PARAMETER Top
    Number of top results to display (default: 20).

.PARAMETER HotSpotThreshold
    Churn rate threshold to flag a file as a hot spot (default: 2.0).

.PARAMETER ExportJson
    Path to export results as JSON.

.EXAMPLE
    .\code-churn-rate.ps1
    .\code-churn-rate.ps1 -StartDate 2025-01-01 -EndDate 2025-01-31
    .\code-churn-rate.ps1 -PathFilter "scripts/*" -ExportJson churn.json
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$StartDate,

    [Parameter()]
    [string]$EndDate,

    [Parameter()]
    [string]$Branch,

    [Parameter()]
    [string]$PathFilter,

    [Parameter()]
    [int]$Top = 20,

    [Parameter()]
    [double]$HotSpotThreshold = 2.0,

    [Parameter()]
    [string]$ExportJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Resolve date range ---
if (-not $StartDate) {
    $StartDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
}
if (-not $EndDate) {
    $EndDate = (Get-Date).ToString("yyyy-MM-dd")
}

Write-Host "`n===== Code Churn Rate Analysis =====" -ForegroundColor Cyan
Write-Host "Date range : $StartDate .. $EndDate"

# --- Build git log command ---
$gitArgs = @("log", "--numstat", "--format=commit:%H|%aN|%aI", "--after=$StartDate", "--before=$EndDate")

if ($Branch) {
    $gitArgs += $Branch
    Write-Host "Branch     : $Branch"
}

if ($PathFilter) {
    $gitArgs += "--"
    $gitArgs += $PathFilter
    Write-Host "Path filter: $PathFilter"
}

Write-Host ""

# --- Parse git log output ---
$logOutput = & git @gitArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "git log failed: $logOutput"
    exit 1
}

$fileStats = @{}      # file -> { Added, Deleted, Commits, Authors }
$authorStats = @{}    # author -> { Added, Deleted, Files }
$currentAuthor = $null

foreach ($line in $logOutput) {
    $line = $line.ToString().Trim()
    if (-not $line) { continue }

    if ($line -match '^commit:([^|]+)\|([^|]+)\|(.+)$') {
        $currentAuthor = $Matches[2]
        continue
    }

    if ($line -match '^(\d+)\t(\d+)\t(.+)$') {
        $added   = [int]$Matches[1]
        $deleted = [int]$Matches[2]
        $file    = $Matches[3]

        # Per-file stats
        if (-not $fileStats.ContainsKey($file)) {
            $fileStats[$file] = @{ Added = 0; Deleted = 0; Commits = 0; Authors = @{} }
        }
        $fileStats[$file].Added   += $added
        $fileStats[$file].Deleted += $deleted
        $fileStats[$file].Commits += 1
        if ($currentAuthor) {
            $fileStats[$file].Authors[$currentAuthor] = ($fileStats[$file].Authors[$currentAuthor] ?? 0) + $added + $deleted
        }

        # Per-author stats
        if ($currentAuthor) {
            if (-not $authorStats.ContainsKey($currentAuthor)) {
                $authorStats[$currentAuthor] = @{ Added = 0; Deleted = 0; Files = @{} }
            }
            $authorStats[$currentAuthor].Added   += $added
            $authorStats[$currentAuthor].Deleted += $deleted
            $authorStats[$currentAuthor].Files[$file] = $true
        }
    }
}

if ($fileStats.Count -eq 0) {
    Write-Host "No changes found in the specified range." -ForegroundColor Yellow
    exit 0
}

# --- Compute churn rates ---
# Get current line counts for each file to calculate relative churn
$fileResults = @()
foreach ($file in $fileStats.Keys) {
    $stats = $fileStats[$file]
    $totalChanges = $stats.Added + $stats.Deleted

    # Try to get current file size in lines
    $totalLines = 0
    if (Test-Path $file) {
        $totalLines = (Get-Content $file -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
    }

    # Churn rate: total changes relative to file size (use changes as denominator if file missing)
    $denominator = if ($totalLines -gt 0) { $totalLines } else { [Math]::Max($stats.Added, 1) }
    $churnRate = [Math]::Round($totalChanges / $denominator, 2)

    # Top contributor for this file
    $topContributor = ($stats.Authors.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
    if (-not $topContributor) { $topContributor = "unknown" }

    $fileResults += [PSCustomObject]@{
        File           = $file
        LinesAdded     = $stats.Added
        LinesDeleted   = $stats.Deleted
        TotalChanges   = $totalChanges
        CurrentLines   = $totalLines
        ChurnRate      = $churnRate
        Commits        = $stats.Commits
        TopContributor = $topContributor
        IsHotSpot      = $churnRate -ge $HotSpotThreshold
    }
}

$fileResults = $fileResults | Sort-Object ChurnRate -Descending

# --- Display file churn table ---
Write-Host "--- File Churn Summary (top $Top) ---" -ForegroundColor Green
$fileResults | Select-Object -First $Top |
    Format-Table @(
        @{ Label = "File";           Expression = { $_.File } },
        @{ Label = "Added";          Expression = { $_.LinesAdded };    Alignment = "Right" },
        @{ Label = "Deleted";        Expression = { $_.LinesDeleted };  Alignment = "Right" },
        @{ Label = "Total";          Expression = { $_.TotalChanges };  Alignment = "Right" },
        @{ Label = "Lines";          Expression = { $_.CurrentLines };  Alignment = "Right" },
        @{ Label = "Churn";          Expression = { $_.ChurnRate };     Alignment = "Right" },
        @{ Label = "Commits";        Expression = { $_.Commits };       Alignment = "Right" },
        @{ Label = "Top Contributor"; Expression = { $_.TopContributor } },
        @{ Label = "Hot?";           Expression = { if ($_.IsHotSpot) { "🔥" } else { "" } } }
    ) -AutoSize

# --- Hot spots ---
$hotSpots = $fileResults | Where-Object { $_.IsHotSpot }
if ($hotSpots.Count -gt 0) {
    Write-Host "`n--- Hot Spots (churn rate >= $HotSpotThreshold) ---" -ForegroundColor Red
    $hotSpots | ForEach-Object {
        Write-Host "  🔥 $($_.File)  churn=$($_.ChurnRate)  changes=$($_.TotalChanges)  by $($_.TopContributor)" -ForegroundColor Yellow
    }
} else {
    Write-Host "`nNo hot spots detected (threshold: $HotSpotThreshold)." -ForegroundColor Green
}

# --- Author summary ---
Write-Host "`n--- Author Summary ---" -ForegroundColor Green
$authorResults = foreach ($author in $authorStats.Keys) {
    $s = $authorStats[$author]
    [PSCustomObject]@{
        Author       = $author
        LinesAdded   = $s.Added
        LinesDeleted = $s.Deleted
        TotalChanges = $s.Added + $s.Deleted
        FilesTouched = $s.Files.Count
    }
}
$authorResults | Sort-Object TotalChanges -Descending |
    Format-Table Author, LinesAdded, LinesDeleted, TotalChanges, FilesTouched -AutoSize

# --- JSON export ---
if ($ExportJson) {
    $exportData = @{
        DateRange = @{ Start = $StartDate; End = $EndDate }
        Branch    = if ($Branch) { $Branch } else { "current" }
        Files     = $fileResults
        Authors   = $authorResults
        HotSpots  = @($hotSpots | Select-Object File, ChurnRate, TotalChanges, TopContributor)
    }
    $exportData | ConvertTo-Json -Depth 5 | Set-Content -Path $ExportJson -Encoding UTF8
    Write-Host "`nResults exported to $ExportJson" -ForegroundColor Cyan
}

Write-Host "`nTotal files analyzed: $($fileResults.Count)" -ForegroundColor Cyan
Write-Host "===== Analysis Complete =====`n" -ForegroundColor Cyan
