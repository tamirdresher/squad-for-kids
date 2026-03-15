<#
.SYNOPSIS
    Cross-Machine Task Watcher for Squad coordination.
    Reads pending YAML tasks, validates, executes, and writes results.

.DESCRIPTION
    Called by Ralph each cycle to process cross-machine tasks.
    Tasks are YAML files in .squad/cross-machine/tasks/ with status: pending.
    Results are written to .squad/cross-machine/results/{task-id}.yaml.

.PARAMETER ConfigPath
    Path to config.json. Defaults to .squad/cross-machine/config.json

.PARAMETER DryRun
    If set, validates tasks but does not execute commands.

.PARAMETER GitSync
    If set, commits and pushes result files after processing.
#>
param(
    [string]$ConfigPath = "",
    [switch]$DryRun,
    [switch]$GitSync
)

$ErrorActionPreference = "Continue"
$Script:RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $Script:RepoRoot) {
    $Script:RepoRoot = (Get-Location).Path
}
$Script:RepoRoot = $Script:RepoRoot.Trim()

$Script:TaskDir = Join-Path $Script:RepoRoot ".squad\cross-machine\tasks"
$Script:ResultDir = Join-Path $Script:RepoRoot ".squad\cross-machine\results"
$Script:DefaultConfigPath = Join-Path $Script:RepoRoot ".squad\cross-machine\config.json"

# --- Logging ---
function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] [$Level] $Message"
}

# --- Simple YAML parser (line-based, handles flat + one-level nested) ---
function Read-SimpleYaml {
    param([string]$Path)
    $result = @{}
    $currentSection = $null
    try {
        $lines = Get-Content -Path $Path -ErrorAction Stop
    } catch {
        Write-Log "ERROR" "Failed to read file: $Path - $_"
        return $null
    }

    foreach ($line in $lines) {
        # Skip empty lines and comments
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }

        # Nested key (indented with spaces)
        if ($line -match '^\s{2,}(\w[\w_-]*):\s*(.*)$' -and $currentSection) {
            $key = $Matches[1]
            $value = $Matches[2].Trim().Trim('"').Trim("'")
            if (-not $result[$currentSection]) {
                $result[$currentSection] = @{}
            }
            # Try to parse numeric values
            if ($value -match '^\d+$') {
                $result[$currentSection][$key] = [int]$value
            } else {
                $result[$currentSection][$key] = $value
            }
            continue
        }

        # Top-level key
        if ($line -match '^(\w[\w_-]*):\s*(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim().Trim('"').Trim("'")

            if ($value -eq '' -or $value -eq $null) {
                # This is a section header (like payload:)
                $currentSection = $key
                $result[$key] = @{}
            } else {
                $currentSection = $null
                $result[$key] = $value
            }
        }
    }
    return $result
}

# --- Write YAML (flat + one-level nested) ---
function Write-SimpleYaml {
    param([hashtable]$Data, [string]$Path)
    $lines = @()
    # Write top-level scalar fields first, then nested
    $scalarKeys = @()
    $nestedKeys = @()
    foreach ($key in $Data.Keys) {
        if ($Data[$key] -is [hashtable]) {
            $nestedKeys += $key
        } else {
            $scalarKeys += $key
        }
    }

    # Preferred key ordering for readability
    $preferredOrder = @('id', 'source_machine', 'target_machine', 'priority',
                        'created_at', 'task_type', 'description', 'status',
                        'started_at', 'completed_at', 'executing_machine')
    $orderedScalars = @()
    foreach ($k in $preferredOrder) {
        if ($k -in $scalarKeys) { $orderedScalars += $k }
    }
    foreach ($k in $scalarKeys) {
        if ($k -notin $orderedScalars) { $orderedScalars += $k }
    }

    foreach ($key in $orderedScalars) {
        $val = $Data[$key]
        if ($val -match '[\s:#{}\[\],&*?|>!%@`]' -or $val -match '^[''"]') {
            $lines += "${key}: `"$val`""
        } else {
            $lines += "${key}: $val"
        }
    }

    foreach ($key in $nestedKeys) {
        $lines += "${key}:"
        $nested = $Data[$key]
        foreach ($nk in $nested.Keys) {
            $nv = $nested[$nk]
            if ($nv -match '[\s:#{}\[\],&*?|>!%@`]' -or $nv -match '^[''"]') {
                $lines += "  ${nk}: `"$nv`""
            } else {
                $lines += "  ${nk}: $nv"
            }
        }
    }

    $lines | Set-Content -Path $Path -Encoding UTF8
}

# --- Load configuration ---
function Get-WatcherConfig {
    $cfgPath = if ($ConfigPath) { $ConfigPath } else { $Script:DefaultConfigPath }
    if (-not (Test-Path $cfgPath)) {
        Write-Log "WARN" "Config not found at $cfgPath, using defaults"
        return @{
            enabled = $true
            this_machine_aliases = @($env:COMPUTERNAME)
            max_concurrent_tasks = 2
            task_timeout_minutes = 60
            command_whitelist_patterns = @(
                "python scripts/*", "node scripts/*", "pwsh scripts/*",
                "gh *", "git *"
            )
            result_ttl_days = 30
        }
    }
    try {
        $config = Get-Content -Path $cfgPath -Raw | ConvertFrom-Json
        return $config
    } catch {
        Write-Log "ERROR" "Failed to parse config: $_"
        return $null
    }
}

# --- Validate task schema ---
function Test-TaskSchema {
    param([hashtable]$Task, [string]$FilePath)
    $requiredFields = @('id', 'source_machine', 'target_machine')
    foreach ($field in $requiredFields) {
        if (-not $Task[$field]) {
            Write-Log "WARN" "Task in $FilePath missing required field: $field"
            return $false
        }
    }
    if (-not $Task['payload'] -or -not $Task['payload']['command']) {
        Write-Log "WARN" "Task $($Task['id']) missing payload.command"
        return $false
    }
    return $true
}

# --- Check if task targets this machine ---
function Test-TaskTargetsThisMachine {
    param([hashtable]$Task, $Config)
    $target = $Task['target_machine']
    if ($target -eq 'ANY') { return $true }

    $aliases = @($env:COMPUTERNAME)
    if ($Config.this_machine_aliases) {
        $aliases += @($Config.this_machine_aliases)
    }
    $aliases = $aliases | ForEach-Object { $_.ToLower() }

    return ($target.ToLower() -in $aliases)
}

# --- Validate command against whitelist ---
function Test-CommandWhitelist {
    param([string]$Command, $Config)
    $patterns = $Config.command_whitelist_patterns
    if (-not $patterns -or $patterns.Count -eq 0) {
        Write-Log "WARN" "No whitelist patterns configured, denying all commands"
        return $false
    }

    foreach ($pattern in $patterns) {
        # Convert glob pattern to regex
        $regex = '^' + [regex]::Escape($pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
        if ($Command -match $regex) {
            return $true
        }
    }

    Write-Log "WARN" "Command not in whitelist: $Command"
    return $false
}

# --- Execute a task ---
function Invoke-Task {
    param([hashtable]$Task, [string]$TaskFilePath, $Config)

    $taskId = $Task['id']
    $command = $Task['payload']['command']
    $timeoutMin = $Config.task_timeout_minutes
    if ($Task['payload']['expected_duration_min']) {
        $timeoutMin = [int]$Task['payload']['expected_duration_min']
    }

    Write-Log "INFO" "Executing task $taskId : $command (timeout: ${timeoutMin}m)"

    # Update task status to executing
    $Task['status'] = 'executing'
    $Task['started_at'] = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $Task['executing_machine'] = $env:COMPUTERNAME
    Write-SimpleYaml -Data $Task -Path $TaskFilePath

    # Execute the command
    $result = @{
        task_id = $taskId
        executing_machine = $env:COMPUTERNAME
        started_at = $Task['started_at']
        exit_code = "-1"
        stdout = ""
        stderr = ""
        status = "failed"
    }

    try {
        $tempOut = [System.IO.Path]::GetTempFileName()
        $tempErr = [System.IO.Path]::GetTempFileName()

        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $command" `
            -RedirectStandardOutput $tempOut -RedirectStandardError $tempErr `
            -PassThru -NoNewWindow -Wait:$false

        $timeoutMs = $timeoutMin * 60 * 1000
        $finished = $proc.WaitForExit($timeoutMs)

        if (-not $finished) {
            Write-Log "WARN" "Task $taskId timed out after ${timeoutMin} minutes"
            try { $proc.Kill() } catch {}
            $result['stderr'] = "TIMEOUT: Task exceeded ${timeoutMin} minute limit"
            $result['status'] = "failed"
            $result['exit_code'] = "-1"
        } else {
            $result['exit_code'] = $proc.ExitCode.ToString()
            $result['stdout'] = (Get-Content -Path $tempOut -Raw -ErrorAction SilentlyContinue) ?? ""
            $result['stderr'] = (Get-Content -Path $tempErr -Raw -ErrorAction SilentlyContinue) ?? ""
            $result['status'] = if ($proc.ExitCode -eq 0) { "completed" } else { "failed" }
        }

        # Cleanup temp files
        Remove-Item -Path $tempOut -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tempErr -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Log "ERROR" "Task $taskId execution error: $_"
        $result['stderr'] = $_.ToString()
        $result['status'] = "failed"
    }

    $result['completed_at'] = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    # Write result YAML
    $resultPath = Join-Path $Script:ResultDir "$taskId.yaml"
    Write-SimpleYaml -Data $result -Path $resultPath
    Write-Log "INFO" "Result written to $resultPath (status: $($result['status']))"

    # Update task file status
    $Task['status'] = $result['status']
    $Task['completed_at'] = $result['completed_at']
    Write-SimpleYaml -Data $Task -Path $TaskFilePath

    return $result
}

# --- Clean up old results ---
function Remove-OldResults {
    param($Config)
    $ttlDays = if ($Config.result_ttl_days) { $Config.result_ttl_days } else { 30 }
    $cutoff = (Get-Date).AddDays(-$ttlDays)

    Get-ChildItem -Path $Script:ResultDir -Filter "*.yaml" -ErrorAction SilentlyContinue | Where-Object {
        $_.LastWriteTime -lt $cutoff
    } | ForEach-Object {
        Write-Log "INFO" "Removing old result: $($_.Name)"
        Remove-Item $_.FullName -Force
    }
}

# --- Git sync (optional) ---
function Sync-ResultsToGit {
    if (-not $GitSync) { return }
    try {
        Push-Location $Script:RepoRoot
        git add ".squad/cross-machine/results/*" ".squad/cross-machine/tasks/*" 2>$null
        $status = git status --porcelain ".squad/cross-machine/" 2>$null
        if ($status) {
            git commit -m "chore: cross-machine task results update [automated]" --no-verify 2>$null
            git push 2>$null
            Write-Log "INFO" "Results synced to git"
        }
    } catch {
        Write-Log "WARN" "Git sync failed: $_"
    } finally {
        Pop-Location
    }
}

# --- Main entry point ---
function Start-TaskWatcher {
    Write-Log "INFO" "Cross-machine task watcher starting..."

    # Load config
    $config = Get-WatcherConfig
    if (-not $config) {
        Write-Log "ERROR" "Failed to load configuration, exiting"
        return
    }

    if ($config.enabled -eq $false) {
        Write-Log "INFO" "Watcher is disabled in config, exiting"
        return
    }

    # Ensure directories exist
    if (-not (Test-Path $Script:TaskDir)) {
        Write-Log "ERROR" "Task directory not found: $Script:TaskDir"
        return
    }
    if (-not (Test-Path $Script:ResultDir)) {
        New-Item -ItemType Directory -Path $Script:ResultDir -Force | Out-Null
    }

    # Clean old results
    Remove-OldResults -Config $config

    # Pull latest changes so tasks pushed from other machines are picked up
    try {
        Push-Location $Script:RepoRoot
        git pull --ff-only 2>$null | Out-Null
        Write-Log "INFO" "Git pull completed before task scan"
        Pop-Location
    } catch {
        Write-Log "WARN" "Git pull failed before task scan: $_"
        try { Pop-Location } catch {}
    }

    # Find pending task files
    $taskFiles = Get-ChildItem -Path $Script:TaskDir -Filter "*.yaml" -ErrorAction SilentlyContinue
    if (-not $taskFiles -or $taskFiles.Count -eq 0) {
        Write-Log "INFO" "No task files found"
        return
    }

    $executedCount = 0
    $maxConcurrent = if ($config.max_concurrent_tasks) { $config.max_concurrent_tasks } else { 2 }

    foreach ($taskFile in $taskFiles) {
        if ($executedCount -ge $maxConcurrent) {
            Write-Log "INFO" "Reached max concurrent tasks ($maxConcurrent), stopping"
            break
        }

        Write-Log "INFO" "Reading task file: $($taskFile.Name)"

        # Parse YAML
        $task = Read-SimpleYaml -Path $taskFile.FullName
        if (-not $task) {
            Write-Log "WARN" "Skipping invalid YAML: $($taskFile.Name)"
            continue
        }

        # Check status
        if ($task['status'] -ne 'pending') {
            Write-Log "INFO" "Skipping $($taskFile.Name) (status: $($task['status']))"
            continue
        }

        # Check target machine
        if (-not (Test-TaskTargetsThisMachine -Task $task -Config $config)) {
            Write-Log "INFO" "Skipping $($task['id']) (not targeting this machine)"
            continue
        }

        # Validate schema
        if (-not (Test-TaskSchema -Task $task -FilePath $taskFile.Name)) {
            Write-Log "WARN" "Skipping $($taskFile.Name) (schema validation failed)"
            continue
        }

        # Validate command whitelist
        $command = $task['payload']['command']
        if (-not (Test-CommandWhitelist -Command $command -Config $config)) {
            Write-Log "WARN" "Skipping $($task['id']) (command not whitelisted: $command)"
            continue
        }

        if ($DryRun) {
            Write-Log "INFO" "[DRY RUN] Would execute task $($task['id']): $command"
            continue
        }

        # Execute
        $result = Invoke-Task -Task $task -TaskFilePath $taskFile.FullName -Config $config
        $executedCount++
    }

    # Sync to git if requested
    Sync-ResultsToGit

    Write-Log "INFO" "Watcher cycle complete. Executed $executedCount task(s)."
}

# Run
Start-TaskWatcher
