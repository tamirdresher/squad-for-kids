# Cross-Machine Watcher — processes pending tasks from the git-based task queue
# See .squad/cross-machine/README.md for full documentation.
#
# Usage:
#   pwsh scripts/cross-machine-watcher.ps1            # Process tasks
#   pwsh scripts/cross-machine-watcher.ps1 -DryRun    # Validate only
#   pwsh scripts/cross-machine-watcher.ps1 -GitSync   # Pull, process, push results

param(
    [switch]$DryRun,
    [switch]$GitSync
)

$ErrorActionPreference = "Stop"

$configPath = Join-Path (Get-Location) ".squad\cross-machine\config.json"
$tasksDir   = Join-Path (Get-Location) ".squad\cross-machine\tasks"
$resultsDir = Join-Path (Get-Location) ".squad\cross-machine\results"

if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Config not found at $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
if (-not $config.enabled) {
    Write-Host "Cross-machine coordination is disabled in config." -ForegroundColor Yellow
    exit 0
}

$myAliases = $config.this_machine_aliases
$whitelist = $config.command_whitelist_patterns
$timeoutMin = $config.task_timeout_minutes

# Git sync: pull latest
if ($GitSync) {
    Write-Host "📥 Pulling latest from remote..." -ForegroundColor Gray
    git pull --rebase --quiet 2>&1 | Out-Null
}

# Find pending tasks targeting this machine
$taskFiles = Get-ChildItem -Path $tasksDir -Filter "*.yaml" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne ".gitkeep" }

$processed = 0
foreach ($taskFile in $taskFiles) {
    $content = Get-Content $taskFile.FullName -Raw

    # Simple YAML parsing (status + target_machine)
    if ($content -notmatch 'status:\s*pending') { continue }

    $targetMatch = [regex]::Match($content, 'target_machine:\s*(.+)')
    if (-not $targetMatch.Success) { continue }
    $target = $targetMatch.Groups[1].Value.Trim()

    # Check if this task targets us
    $isForUs = ($target -eq "ANY") -or ($myAliases -contains $target)
    if (-not $isForUs) { continue }

    # Extract command
    $cmdMatch = [regex]::Match($content, 'command:\s*"?([^"]+)"?')
    if (-not $cmdMatch.Success) {
        Write-Host "⚠️  Task $($taskFile.Name): no command found, skipping" -ForegroundColor Yellow
        continue
    }
    $command = $cmdMatch.Groups[1].Value.Trim()

    # Validate against whitelist
    $allowed = $false
    foreach ($pattern in $whitelist) {
        if ($command -like $pattern) { $allowed = $true; break }
    }
    if (-not $allowed) {
        Write-Host "🚫 Task $($taskFile.Name): command '$command' not in whitelist" -ForegroundColor Red
        continue
    }

    # Extract task ID
    $idMatch = [regex]::Match($content, 'id:\s*(.+)')
    $taskId = if ($idMatch.Success) { $idMatch.Groups[1].Value.Trim() } else { $taskFile.BaseName }

    if ($DryRun) {
        Write-Host "🔍 [DRY RUN] Would execute: $command (task: $taskId)" -ForegroundColor Cyan
        continue
    }

    Write-Host "▶️  Executing task $taskId : $command" -ForegroundColor Green
    $startTime = Get-Date

    try {
        $output = Invoke-Expression $command 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = 0 }
    } catch {
        $output = $_.Exception.Message
        $exitCode = 1
    }

    $endTime = Get-Date
    $status = if ($exitCode -eq 0) { "completed" } else { "failed" }

    # Write result
    $resultFile = Join-Path $resultsDir "$taskId.yaml"
    $resultContent = @"
task_id: $taskId
executing_machine: $env:COMPUTERNAME
started_at: "$($startTime.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
completed_at: "$($endTime.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
exit_code: $exitCode
status: $status
stdout: |
  $($output -replace "`n", "`n  ")
"@
    $resultContent | Out-File $resultFile -Encoding utf8 -Force

    # Update task status in-place
    $updatedContent = $content -replace 'status:\s*pending', "status: $status"
    $updatedContent | Out-File $taskFile.FullName -Encoding utf8 -Force

    $duration = [math]::Round(($endTime - $startTime).TotalSeconds, 1)
    $icon = if ($exitCode -eq 0) { "✅" } else { "❌" }
    Write-Host "$icon Task $taskId $status in ${duration}s (exit $exitCode)" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })
    $processed++
}

if ($processed -eq 0 -and -not $DryRun) {
    Write-Host "📭 No pending tasks for this machine ($($myAliases -join ', '))" -ForegroundColor Gray
}

# Git sync: commit and push results
if ($GitSync -and $processed -gt 0) {
    Write-Host "📤 Pushing results to remote..." -ForegroundColor Gray
    git add .squad/cross-machine/ 2>&1 | Out-Null
    git commit -m "chore: cross-machine task results from $env:COMPUTERNAME" --quiet 2>&1 | Out-Null
    git push --quiet 2>&1 | Out-Null
}

Write-Host "Done. Processed $processed task(s)." -ForegroundColor Cyan
