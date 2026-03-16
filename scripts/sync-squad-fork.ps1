<#
.SYNOPSIS
    Syncs tamirdresher/squad fork with upstream bradygaster/squad.

.DESCRIPTION
    Uses gh repo sync to pull latest changes from bradygaster/squad into
    tamirdresher/squad. Syncs both dev and main branches.

    Requires: gh CLI authenticated with an account that has push access
    to tamirdresher/squad (the personal tamirdresher account, not EMU).

.EXAMPLE
    .\scripts\sync-squad-fork.ps1
    .\scripts\sync-squad-fork.ps1 -Branch dev
    .\scripts\sync-squad-fork.ps1 -DryRun
#>
param(
    [ValidateSet('dev', 'main', 'all')]
    [string]$Branch = 'all',

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$fork     = 'tamirdresher/squad'
$upstream = 'bradygaster/squad'

function Sync-Branch {
    param([string]$BranchName)

    Write-Host "`n--- Syncing branch: $BranchName ---" -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "[DRY RUN] Would run: gh repo sync $fork --source $upstream --branch $BranchName" -ForegroundColor Yellow
        return $true
    }

    try {
        $output = gh repo sync $fork --source $upstream --branch $BranchName 2>&1
        Write-Host $output -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "FAILED to sync $BranchName : $_" -ForegroundColor Red
        return $false
    }
}

# Verify gh auth — need an account with push access to the fork
Write-Host "Checking gh auth status..." -ForegroundColor Gray
$authStatus = gh auth status 2>&1 | Out-String
if ($authStatus -notmatch 'Logged in') {
    Write-Error "Not logged in to GitHub CLI. Run 'gh auth login' first."
    exit 1
}
Write-Host "Auth OK" -ForegroundColor Gray

$branches = if ($Branch -eq 'all') { @('dev', 'main') } else { @($Branch) }
$results  = @{}

foreach ($b in $branches) {
    $results[$b] = Sync-Branch -BranchName $b
}

# Summary
Write-Host "`n=== Sync Summary ===" -ForegroundColor Cyan
foreach ($b in $results.Keys) {
    $status = if ($results[$b]) { 'OK' } else { 'FAILED' }
    $color  = if ($results[$b]) { 'Green' } else { 'Red' }
    Write-Host "  $b : $status" -ForegroundColor $color
}

if ($results.Values -contains $false) {
    Write-Host "`nSome branches failed to sync. Check output above." -ForegroundColor Red
    exit 1
}

Write-Host "`nAll branches synced successfully." -ForegroundColor Green
