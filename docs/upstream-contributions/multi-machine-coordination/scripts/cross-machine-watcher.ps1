<#
.SYNOPSIS
    Cross-Machine Task Watcher — polls for pending tasks and executes them.

.DESCRIPTION
    Watches .squad/cross-machine/tasks/ for YAML task files targeted at this
    machine, validates them against the command whitelist, executes approved
    commands, writes results to .squad/cross-machine/results/, and optionally
    syncs via git.

    This is a skeleton implementation. Integrate it into your agent's watch
    cycle (e.g., Ralph) or run it standalone via cron / scheduled task.

.PARAMETER ConfigPath
    Path to the cross-machine config.json file.
    Default: .squad/cross-machine/config.json

.PARAMETER DryRun
    Validate tasks without executing them.

.PARAMETER GitSync
    Pull before processing and push results after.

.PARAMETER Once
    Run one cycle and exit (default). Use -Loop for continuous mode.

.PARAMETER Loop
    Run continuously, sleeping between cycles.

.EXAMPLE
    pwsh scripts/cross-machine-watcher.ps1 -ConfigPath .squad/cross-machine/config.json
    pwsh scripts/cross-machine-watcher.ps1 -DryRun
    pwsh scripts/cross-machine-watcher.ps1 -GitSync -Loop
#>

[CmdletBinding()]
param(
    [string]$ConfigPath = ".squad/cross-machine/config.json",
    [switch]$DryRun,
    [switch]$GitSync,
    [switch]$Loop,
    [switch]$Once
)

$ErrorActionPreference = "Stop"

# ─── Helpers ───────────────────────────────────────────────────────────────

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] [$Level] $Message"
}

function Read-YamlSimple {
    <#
    .SYNOPSIS
        Minimal YAML key-value parser (flat + one level of nesting).
        For production use, replace with powershell-yaml module.
    #>
    param([string]$Path)
    $result = @{}
    $currentSection = $null
    foreach ($line in (Get-Content $Path -ErrorAction Stop)) {
        if ($line -match '^\s*#' -or $line.Trim() -eq '') { continue }
        if ($line -match '^(\w[\w_]*):\s*$') {
            $currentSection = $Matches[1]
            $result[$currentSection] = @{}
        }
        elseif ($line -match '^(\w[\w_]*):\s*(.+)$') {
            $key = $Matches[1]
            $val = $Matches[2].Trim().Trim('"').Trim("'")
            $currentSection = $null
            $result[$key] = $val
        }
        elseif ($currentSection -and $line -match '^\s+(\w[\w_]*):\s*(.+)$') {
            $key = $Matches[1]
            $val = $Matches[2].Trim().Trim('"').Trim("'")
            $result[$currentSection][$key] = $val
        }
    }
    return $result
}

function Write-YamlResult {
    param([hashtable]$Data, [string]$Path)
    $lines = @()
    foreach ($key in $Data.Keys | Sort-Object) {
        $val = $Data[$key]
        if ($val -is [hashtable]) {
            $lines += "${key}:"
            foreach ($subKey in $val.Keys | Sort-Object) {
                $lines += "  ${subKey}: `"$($val[$subKey])`""
            }
        } else {
            $lines += "${key}: `"$val`""
        }
    }
    $lines | Set-Content -Path $Path -Encoding UTF8
}

function Test-CommandWhitelist {
    param([string]$Command, [string[]]$Patterns)
    foreach ($pattern in $Patterns) {
        # Convert glob pattern to regex
        $regex = "^" + [regex]::Escape($pattern).Replace("\*", ".*") + "$"
        if ($Command -match $regex) { return $true }
    }
    return $false
}

function Test-PathTraversal {
    param([string]$Command)
    if ($Command -match '\.\.[/\\]') { return $true }
    if ($Command -match '[;&|`$]') { return $true }
    return $false
}

# ─── Main Logic ────────────────────────────────────────────────────────────

function Invoke-WatchCycle {
    param([hashtable]$Config)

    $taskDir = ".squad/cross-machine/tasks"
    $resultDir = ".squad/cross-machine/results"
    $myAliases = @($Config.this_machine_aliases)
    $whitelist = @($Config.command_whitelist_patterns)
    $timeout = [int]($Config.task_timeout_minutes ?? 60)

    # Ensure directories exist
    if (-not (Test-Path $taskDir)) {
        Write-Log "Task directory not found: $taskDir" "WARN"
        return
    }
    New-Item -ItemType Directory -Force -Path $resultDir | Out-Null

    # Git pull if requested
    if ($GitSync) {
        Write-Log "Pulling latest from origin..."
        git pull origin main --rebase 2>&1 | Out-Null
    }

    # Find pending tasks
    $taskFiles = Get-ChildItem -Path $taskDir -Filter "*.yaml" -ErrorAction SilentlyContinue
    $processed = 0

    foreach ($file in $taskFiles) {
        try {
            $task = Read-YamlSimple -Path $file.FullName
        } catch {
            Write-Log "Failed to parse $($file.Name): $_" "ERROR"
            continue
        }

        # Skip non-pending tasks
        if ($task.status -ne "pending") { continue }

        # Check if task targets this machine
        $targetMachine = $task.target_machine
        $isForMe = ($targetMachine -eq "ANY") -or ($myAliases -contains $targetMachine)
        if (-not $isForMe) { continue }

        Write-Log "Found task: $($task.id) (target: $targetMachine, type: $($task.task_type))"

        # ── Validation ──
        # Required fields
        $requiredFields = @("id", "source_machine", "target_machine", "status")
        $missing = $requiredFields | Where-Object { -not $task.ContainsKey($_) }
        if ($missing) {
            Write-Log "Task $($task.id) missing fields: $($missing -join ', ')" "ERROR"
            continue
        }

        # Extract command
        $command = if ($task.payload -is [hashtable]) { $task.payload.command } else { $null }
        if (-not $command) {
            Write-Log "Task $($task.id) has no payload.command" "ERROR"
            continue
        }

        # Path traversal check
        if (Test-PathTraversal -Command $command) {
            Write-Log "Task $($task.id) REJECTED: suspicious characters in command" "SECURITY"
            continue
        }

        # Whitelist check
        if (-not (Test-CommandWhitelist -Command $command -Patterns $whitelist)) {
            Write-Log "Task $($task.id) REJECTED: command not whitelisted: $command" "SECURITY"
            continue
        }

        Write-Log "Task $($task.id) validated ✅"

        if ($DryRun) {
            Write-Log "[DRY RUN] Would execute: $command"
            continue
        }

        # ── Execution ──
        $startTime = Get-Date
        Write-Log "Executing: $command (timeout: ${timeout}m)"

        $result = @{
            task_id            = $task.id
            executing_machine  = $env:COMPUTERNAME
            started_at         = $startTime.ToString("o")
            status             = "failed"
            exit_code          = -1
            stdout             = ""
            stderr             = ""
            duration_seconds   = 0
        }

        try {
            $taskTimeout = if ($task.payload.expected_duration_min) {
                [int]$task.payload.expected_duration_min
            } else { $timeout }

            $proc = Start-Process -FilePath "pwsh" -ArgumentList "-Command", $command `
                -NoNewWindow -Wait -PassThru `
                -RedirectStandardOutput "$env:TEMP\squad-stdout.tmp" `
                -RedirectStandardError "$env:TEMP\squad-stderr.tmp" `
                -ErrorAction Stop

            # Note: Start-Process -Wait doesn't support timeout natively.
            # For production, use a job with Wait-Job -Timeout instead.

            $result.exit_code = $proc.ExitCode
            $result.stdout = (Get-Content "$env:TEMP\squad-stdout.tmp" -Raw -ErrorAction SilentlyContinue) ?? ""
            $result.stderr = (Get-Content "$env:TEMP\squad-stderr.tmp" -Raw -ErrorAction SilentlyContinue) ?? ""
            $result.status = if ($proc.ExitCode -eq 0) { "completed" } else { "failed" }
        }
        catch {
            $result.stderr = $_.Exception.Message
            $result.status = "failed"
        }
        finally {
            $endTime = Get-Date
            $result.completed_at = $endTime.ToString("o")
            $result.duration_seconds = [math]::Round(($endTime - $startTime).TotalSeconds)

            # Clean up temp files
            Remove-Item "$env:TEMP\squad-stdout.tmp" -ErrorAction SilentlyContinue
            Remove-Item "$env:TEMP\squad-stderr.tmp" -ErrorAction SilentlyContinue
        }

        # ── Write Result ──
        $resultPath = Join-Path $resultDir "$($task.id).yaml"
        Write-YamlResult -Data $result -Path $resultPath
        Write-Log "Result written: $resultPath (status: $($result.status))"

        # Update task status in-place
        $taskContent = Get-Content $file.FullName -Raw
        $taskContent = $taskContent -replace 'status:\s*pending', "status: $($result.status)"
        $taskContent | Set-Content $file.FullName -Encoding UTF8

        $processed++
    }

    # Git push if requested and we processed tasks
    if ($GitSync -and $processed -gt 0) {
        Write-Log "Pushing $processed result(s) to origin..."
        git add .squad/cross-machine/ 2>&1 | Out-Null
        git commit -m "Cross-machine: $processed task(s) completed [$env:COMPUTERNAME]" 2>&1 | Out-Null
        git push origin main 2>&1 | Out-Null
    }

    Write-Log "Cycle complete. Processed $processed task(s)."
}

# ─── Entry Point ───────────────────────────────────────────────────────────

# Load config
if (-not (Test-Path $ConfigPath)) {
    Write-Log "Config not found: $ConfigPath" "ERROR"
    Write-Log "Copy templates/config.json to $ConfigPath and configure it."
    exit 1
}

$configRaw = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$config = @{
    enabled                  = $configRaw.enabled
    poll_interval_seconds    = $configRaw.poll_interval_seconds ?? 300
    this_machine_aliases     = @($configRaw.this_machine_aliases)
    max_concurrent_tasks     = $configRaw.max_concurrent_tasks ?? 2
    task_timeout_minutes     = $configRaw.task_timeout_minutes ?? 60
    command_whitelist_patterns = @($configRaw.command_whitelist_patterns)
    result_ttl_days          = $configRaw.result_ttl_days ?? 30
}

if (-not $config.enabled) {
    Write-Log "Cross-machine coordination is disabled in config." "WARN"
    exit 0
}

Write-Log "Cross-Machine Watcher starting"
Write-Log "Machine aliases: $($config.this_machine_aliases -join ', ')"
Write-Log "Whitelist patterns: $($config.command_whitelist_patterns.Count)"
Write-Log "Mode: $(if ($DryRun) {'DRY RUN'} elseif ($GitSync) {'GIT SYNC'} else {'LOCAL'})"

if ($Loop) {
    while ($true) {
        Invoke-WatchCycle -Config $config
        $sleepSec = $config.poll_interval_seconds
        Write-Log "Sleeping $sleepSec seconds..."
        Start-Sleep -Seconds $sleepSec
    }
} else {
    Invoke-WatchCycle -Config $config
}
