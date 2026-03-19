<#
.SYNOPSIS
    Ralph Content Watch — Detects new Neelix reports and triggers the content pipeline.

.DESCRIPTION
    Polls the tamresearch1 repo for new report files produced by Neelix (research reports,
    news digests, tech briefings, etc.). When new content is found, creates a GitHub issue
    with the "content-batch" label so downstream pipeline stages can process it.

    State is persisted in ~/.squad/content-watch-state.json to survive restarts.

    Designed to run as a long-lived polling loop (like ralph-watch.ps1).
    Requires PowerShell 7+ (pwsh).

.PARAMETER IntervalMinutes
    Polling interval in minutes. Default: 30.

.PARAMETER ReportDirs
    Comma-separated list of directories to scan for new reports. Relative to repo root.
    Default: "docs,research,processed"

.PARAMETER DryRun
    If set, logs what would happen without creating GitHub issues.

.PARAMETER Once
    Run a single scan then exit (useful for testing / cron).

.EXAMPLE
    pwsh scripts/ralph-watch-content.ps1
    pwsh scripts/ralph-watch-content.ps1 -IntervalMinutes 15 -Once
    pwsh scripts/ralph-watch-content.ps1 -DryRun
#>

param(
    [int]$IntervalMinutes = 30,
    [string]$ReportDirs = "docs,research,processed",
    [switch]$DryRun,
    [switch]$Once
)

# Require PowerShell 7+
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "ERROR: ralph-watch-content requires PowerShell 7+ (pwsh). Current: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    Write-Host "Launch with: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/ralph-watch-content.ps1" -ForegroundColor Yellow
    exit 1
}

# --- UTF-8 setup ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Ensure gh uses the EMU account (tamirdresher_microsoft) — required for squad repo access
$env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"

# --- Paths ---
$squadDir   = Join-Path $env:USERPROFILE ".squad"
$stateFile  = Join-Path $squadDir "content-watch-state.json"
$logFile    = Join-Path $squadDir "content-watch.log"
$repoRoot   = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

# Ensure .squad directory exists
if (-not (Test-Path $squadDir)) {
    New-Item -ItemType Directory -Path $squadDir -Force | Out-Null
}

# --- File extensions that qualify as "reports" ---
$reportExtensions = @('.md', '.txt', '.html')

# --- Logging ---
function Write-ContentLog {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
    $line = "$ts [$Level] $Message"
    Write-Host $line -ForegroundColor $(switch ($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } default { "Gray" } })
    Add-Content -Path $logFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
}

# --- Log rotation (keep last 300 entries / 512 KB) ---
function Invoke-ContentLogRotation {
    if (-not (Test-Path $logFile)) { return }
    $info = Get-Item $logFile
    if ($info.Length -gt 524288) {
        $lines = Get-Content $logFile -Encoding utf8
        $lines | Select-Object -Last 200 | Out-File $logFile -Encoding utf8 -Force
        Write-ContentLog "Log rotated — kept last 200 entries"
    }
}

# --- State management ---
function Get-WatchState {
    if (Test-Path $stateFile) {
        try {
            return Get-Content $stateFile -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
        } catch {
            Write-ContentLog "Corrupt state file — resetting" "WARN"
        }
    }
    return @{ knownFiles = @{}; lastScan = $null; batchCount = 0 }
}

function Save-WatchState {
    param([hashtable]$State)
    $State | ConvertTo-Json -Depth 5 | Out-File $stateFile -Encoding utf8 -Force
}

# --- Scan for report files ---
function Find-NewReports {
    param([hashtable]$State)

    $dirs = $ReportDirs -split ','
    $newFiles = [System.Collections.Generic.List[string]]::new()

    foreach ($dir in $dirs) {
        $fullDir = Join-Path $repoRoot $dir.Trim()
        if (-not (Test-Path $fullDir)) {
            Write-ContentLog "Scan directory not found: $dir" "WARN"
            continue
        }

        $files = Get-ChildItem -Path $fullDir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $reportExtensions -contains $_.Extension.ToLower() }

        foreach ($f in $files) {
            $relPath = $f.FullName.Replace($repoRoot, '').TrimStart('\', '/')
            $fileKey = $relPath.Replace('\', '/')
            $modifiedStr = $f.LastWriteTimeUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')

            if (-not $State.knownFiles.ContainsKey($fileKey)) {
                $newFiles.Add($fileKey)
                $State.knownFiles[$fileKey] = $modifiedStr
            }
        }
    }

    return $newFiles
}

# --- Create a GitHub issue for the batch ---
function New-ContentBatchIssue {
    param(
        [string[]]$NewReports,
        [int]$BatchNumber
    )

    $batchId = "batch-$(Get-Date -Format 'yyyy-MM-dd')-$BatchNumber"
    $reportList = ($NewReports | ForEach-Object { "- ``$_``" }) -join "`n"

    $body = @"
## Content Batch: $batchId

**Detected:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC
**Source:** ralph-watch-content (automated)
**Reports found:** $($NewReports.Count)

### New Reports
$reportList

### Editorial Priority
> _Auto-detected batch. Review reports and assign priority._

### Pipeline Checklist
- [ ] **Phase 2 — Enrichment:** Extract key themes, generate summaries
- [ ] **Phase 3 — Blog Draft:** Troi generates blog post draft
- [ ] **Phase 4 — Review & Polish:** Human review, Seven refines
- [ ] **Phase 5 — Publish:** Push to tamirdresher.github.io
- [ ] **Phase 6 — Distribute:** Podcast, Teams notification, social

### Labels
content-batch, squad, squad:neelix

---
_Created by ralph-watch-content.ps1 • See [Content Pipeline Overview](../docs/content-pipeline-overview.md) • Issue #770_
"@

    if ($DryRun) {
        Write-ContentLog "[DRY RUN] Would create issue: 'Content Batch: $batchId' with $($NewReports.Count) reports"
        return
    }

    try {
        $result = gh issue create `
            --title "Content Batch: $batchId" `
            --body $body `
            --label "content-batch" `
            2>&1
        Write-ContentLog "Created issue: $result"
    } catch {
        Write-ContentLog "Failed to create GitHub issue: $_" "ERROR"
    }
}

# --- Main loop ---
Write-ContentLog "=== Ralph Content Watch started ==="
Write-ContentLog "Repo root: $repoRoot"
Write-ContentLog "Scan dirs: $ReportDirs"
Write-ContentLog "Interval:  $IntervalMinutes min"
Write-ContentLog "Dry run:   $DryRun"
Write-ContentLog "One-shot:  $Once"

$round = 0

do {
    $round++
    $scanStart = Get-Date
    Write-ContentLog "--- Round $round ---"

    try {
        # Pull latest changes (non-interactive)
        git pull --ff-only --quiet 2>$null

        $state = Get-WatchState
        $newReports = Find-NewReports -State $state

        if ($newReports.Count -gt 0) {
            Write-ContentLog "Found $($newReports.Count) new report(s)"
            $state.batchCount++
            New-ContentBatchIssue -NewReports $newReports -BatchNumber $state.batchCount
        } else {
            Write-ContentLog "No new reports detected"
        }

        $state.lastScan = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Save-WatchState -State $state
        Invoke-ContentLogRotation

        $elapsed = ((Get-Date) - $scanStart).TotalSeconds
        Write-ContentLog "Round $round complete in $([math]::Round($elapsed, 1))s"
    } catch {
        Write-ContentLog "Round $round failed: $_" "ERROR"
    }

    if (-not $Once) {
        Write-ContentLog "Sleeping $IntervalMinutes minutes..."
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    }
} while (-not $Once)

Write-ContentLog "=== Ralph Content Watch stopped ==="
