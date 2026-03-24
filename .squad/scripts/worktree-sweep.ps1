# worktree-sweep.ps1
# Ralph's periodic worktree health sweep.
# Detects stale worktrees (>7 days), auto-removes those whose PR is merged,
# and appends results to .squad/worktree-log.md.
#
# Exit codes:
#   0 = all worktrees healthy (or none found)
#   1 = stale worktrees found (some may have been auto-removed)
#
# Usage:
#   .\.squad\scripts\worktree-sweep.ps1
#   .\.squad\scripts\worktree-sweep.ps1 -DryRun         # report only, no removals
#   .\.squad\scripts\worktree-sweep.ps1 -StaleThresholdDays 3

[CmdletBinding()]
param(
    [int]$StaleThresholdDays = 7,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Resolve paths ────────────────────────────────────────────────────────────
$repoRoot   = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) { Write-Error "Not inside a git repo."; exit 1 }
$repoRoot   = $repoRoot.Replace('/', '\')
$repoParent = Split-Path $repoRoot -Parent
$logFile    = Join-Path $repoRoot ".squad\worktree-log.md"

# ── Ensure audit log exists ──────────────────────────────────────────────────
if (-not (Test-Path $logFile)) {
    $header = @"
# Worktree Audit Log

Automatically maintained by `.squad/scripts/worktree-sweep.ps1`.

| Date | Issue | Action | Path | Agent |
|------|-------|--------|------|-------|
"@
    Set-Content -Path $logFile -Value $header -Encoding UTF8
}

# ── Helper: append a row to the audit log ───────────────────────────────────
function Write-AuditRow {
    param([string]$Issue, [string]$Action, [string]$Path, [string]$Agent = "ralph-sweep")
    $date = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    $row  = "| $date | $Issue | $Action | ``$Path`` | $Agent |"
    Add-Content -Path $logFile -Value $row -Encoding UTF8
}

# ── Helper: check if a PR for an issue is merged via gh CLI ─────────────────
function Test-IssueHasMergedPR {
    param([string]$IssueNumber)
    try {
        $prs = gh pr list --search "closes:#$IssueNumber is:merged" --json number,merged --limit 5 2>$null | ConvertFrom-Json
        return ($prs | Where-Object { $_.merged -eq $true }).Count -gt 0
    } catch {
        # Also try by branch pattern
        try {
            $prs = gh pr list --state merged --head "squad/$IssueNumber-" --json number --limit 5 2>$null | ConvertFrom-Json
            return $prs.Count -gt 0
        } catch {
            return $false
        }
    }
}

# ── Parse git worktree list ──────────────────────────────────────────────────
Write-Host "🔍 Scanning git worktrees..." -ForegroundColor Cyan
$rawList = git worktree list --porcelain 2>$null
if (-not $rawList) {
    Write-Host "No worktrees found." -ForegroundColor Green
    exit 0
}

# Parse porcelain output into objects
$worktrees = @()
$current   = $null
foreach ($line in $rawList) {
    if ($line -match '^worktree (.+)$') {
        if ($current) { $worktrees += $current }
        $current = [PSCustomObject]@{
            Path   = $Matches[1].Trim()
            HEAD   = ""
            Branch = ""
            Bare   = $false
        }
    } elseif ($line -match '^HEAD (.+)$'   -and $current) { $current.HEAD   = $Matches[1] }
    elseif ($line -match '^branch (.+)$'   -and $current) { $current.Branch = $Matches[1] }
    elseif ($line -eq 'bare'               -and $current) { $current.Bare   = $true }
}
if ($current) { $worktrees += $current }

# Skip the main worktree (first entry / repo root itself)
$squadWorktrees = $worktrees | Where-Object {
    -not $_.Bare -and
    $_.Path -ne $repoRoot -and
    $_.Path -notlike $repoRoot
}

if (-not $squadWorktrees) {
    Write-Host "✅ No squad worktrees found — nothing to sweep." -ForegroundColor Green
    exit 0
}

Write-Host "Found $($squadWorktrees.Count) squad worktree(s)." -ForegroundColor Cyan

$staleFound    = $false
$now           = Get-Date
$threshold     = $now.AddDays(-$StaleThresholdDays)

foreach ($wt in $squadWorktrees) {
    $wtPath = $wt.Path.Replace('/', '\')

    # Extract issue number from path or branch
    $issueNumber = $null
    if ($wtPath -match 'tamresearch1-wt-(\d+)') {
        $issueNumber = $Matches[1]
    } elseif ($wt.Branch -match 'squad/(\d+)-') {
        $issueNumber = $Matches[1]
    }

    # Determine age via directory mtime
    $age        = $null
    $isStale    = $false
    if (Test-Path $wtPath) {
        $dirInfo = Get-Item $wtPath
        $age     = $now - $dirInfo.LastWriteTime
        $isStale = $dirInfo.LastWriteTime -lt $threshold
    } else {
        Write-Warning "Worktree path not found on disk: $wtPath — may have been manually removed."
        Write-AuditRow -Issue ($issueNumber ?? "unknown") -Action "missing-on-disk" -Path $wtPath
        continue
    }

    $ageDays = [math]::Round($age.TotalDays, 1)
    $label   = if ($issueNumber) { "#$issueNumber" } else { "unknown" }

    if (-not $isStale) {
        Write-Host "  ✅ $wtPath  (issue $label, ${ageDays}d old — fresh)" -ForegroundColor Green
        continue
    }

    # Stale worktree found
    $staleFound = $true
    Write-Warning "⚠️  STALE: $wtPath  (issue $label, ${ageDays}d old)"

    # Check if PR is merged
    $isMerged = $false
    if ($issueNumber) {
        Write-Host "     Checking GitHub for merged PR on issue $label..." -ForegroundColor Yellow
        $isMerged = Test-IssueHasMergedPR -IssueNumber $issueNumber
    }

    if ($isMerged) {
        if ($DryRun) {
            Write-Host "     [DRY RUN] Would auto-remove (PR merged): $wtPath" -ForegroundColor Magenta
            Write-AuditRow -Issue $label -Action "dry-run-would-remove" -Path $wtPath
        } else {
            Write-Host "     🗑️  Auto-removing (PR is merged): $wtPath" -ForegroundColor Red
            try {
                git worktree remove $wtPath --force 2>&1 | Out-Null
                Write-Host "     ✅ Removed." -ForegroundColor Green
                Write-AuditRow -Issue $label -Action "auto-removed" -Path $wtPath
            } catch {
                Write-Warning "     Failed to remove $wtPath: $_"
                Write-AuditRow -Issue $label -Action "remove-failed" -Path $wtPath
            }
        }
    } else {
        Write-Host "     ⚠️  PR not merged — logging as stale, not removing." -ForegroundColor Yellow
        Write-AuditRow -Issue $label -Action "stale-warned" -Path $wtPath
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host ""
if ($staleFound) {
    Write-Host "🚨 Sweep complete — stale worktrees were found. Check $logFile for details." -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ Sweep complete — all worktrees are healthy." -ForegroundColor Green
    exit 0
}
