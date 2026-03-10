# Invoke-SquadScheduler.ps1
# Squad Scheduler Engine v1.0
# Reads .squad/schedule.json, evaluates triggers, and dispatches tasks

param(
    [string]$ScheduleFile = ".squad/schedule.json",
    [string]$StateFile = ".squad/monitoring/schedule-state.json",
    [string]$Provider = "local-polling",
    [switch]$DryRun = $false
)

# ============================================================================
# CRON PARSER
# ============================================================================

function Test-CronExpression {
    param(
        [string]$Expression,
        [datetime]$ReferenceTime,
        [string]$Timezone = "UTC"
    )
    
    # Convert to target timezone
    try {
        $tzInfo = [System.TimeZoneInfo]::FindSystemTimeZoneById($Timezone)
        $targetTime = [System.TimeZoneInfo]::ConvertTime($ReferenceTime, $tzInfo)
    } catch {
        Write-Warning "Invalid timezone: $Timezone"
        $targetTime = $ReferenceTime
    }
    
    # Parse cron fields
    $fields = $Expression -split '\s+' | Where-Object { $_ }
    if ($fields.Count -ne 5) {
        Write-Error "Invalid cron: expected 5 fields, got $($fields.Count)"
        return $false
    }
    
    $cronMinute, $cronHour, $cronDay, $cronMonth, $cronWeekday = $fields
    
    # Test each field
    if (-not (Test-CronField -CronField $cronMinute -Value $targetTime.Minute)) { return $false }
    if (-not (Test-CronField -CronField $cronHour -Value $targetTime.Hour)) { return $false }
    if (-not (Test-CronField -CronField $cronDay -Value $targetTime.Day -MaxValue 31)) { return $false }
    if (-not (Test-CronField -CronField $cronMonth -Value $targetTime.Month -MaxValue 12)) { return $false }
    if (-not (Test-CronField -CronField $cronWeekday -Value ([int]$targetTime.DayOfWeek) -MaxValue 6)) { return $false }
    
    return $true
}

function Test-CronField {
    param(
        [string]$CronField,
        [int]$Value,
        [int]$MaxValue = 59
    )
    
    if ($CronField -eq "*") { return $true }
    
    if ($CronField -match '^\*/(\d+)$') {
        $step = [int]$matches[1]
        return ($Value % $step -eq 0)
    }
    
    if ($CronField -match ',') {
        $values = $CronField -split ','
        foreach ($v in $values) {
            if (Test-CronField -CronField $v -Value $Value -MaxValue $MaxValue) { return $true }
        }
        return $false
    }
    
    if ($CronField -match '^(\d+)-(\d+)(?:/(\d+))?$') {
        $start = [int]$matches[1]
        $end = [int]$matches[2]
        $step = if ($matches[3]) { [int]$matches[3] } else { 1 }
        
        for ($i = $start; $i -le $end; $i += $step) {
            if ($i -eq $Value) { return $true }
        }
        return $false
    }
    
    if ($CronField -match '^\d+$') {
        return [int]$CronField -eq $Value
    }
    
    return $false
}

# ============================================================================
# SCHEDULER ENGINE
# ============================================================================

function Invoke-SquadScheduler {
    param(
        [string]$ScheduleFile,
        [string]$StateFile,
        [string]$Provider,
        [bool]$DryRun
    )
    
    if (-not (Test-Path $ScheduleFile)) {
        Write-Error "Schedule file not found: $ScheduleFile"
        return @{ success = $false; tasksRun = 0; tasksFired = 0; errors = @() }
    }
    
    try {
        $schedule = Get-Content $ScheduleFile -Raw | ConvertFrom-Json
    } catch {
        Write-Error "Failed to parse schedule file: $_"
        return @{ success = $false; tasksRun = 0; tasksFired = 0; errors = @() }
    }
    
    # Load state
    $state = @{}
    if (Test-Path $StateFile) {
        try {
            $json = Get-Content $StateFile -Raw | ConvertFrom-Json
            foreach ($prop in $json.PSObject.Properties) {
                $state[$prop.Name] = $prop.Value
            }
        } catch {
            # State file corrupted or empty - start fresh
        }
    }
    
    # Ensure state dir exists
    $stateDir = Split-Path $StateFile -Parent
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    
    $results = @{
        success = $true
        tasksRun = 0
        tasksFired = 0
        tasksFailed = 0
        errors = @()
        firedTasks = @()
    }
    
    $currentTime = Get-Date
    $newState = @{}
    
    # Evaluate each task
    foreach ($task in $schedule.schedules) {
        $results.tasksRun++
        
        if ($task.enabled -eq $false) { continue }
        
        # Check provider
        if ($task.providers -and $Provider -notin $task.providers) { continue }
        
        $shouldFire = $false
        $fireReason = ""
        
        switch ($task.trigger.type) {
            "interval" {
                $lastRun = $null
                if ($state.ContainsKey($task.id) -and $state[$task.id].lastRun) {
                    $lastRun = [datetime]$state[$task.id].lastRun
                }
                
                if ($lastRun -eq $null) {
                    $shouldFire = $true
                    $fireReason = "first run"
                } elseif (($currentTime - $lastRun).TotalSeconds -ge $task.trigger.intervalSeconds) {
                    $shouldFire = $true
                    $fireReason = "interval elapsed"
                }
            }
            "cron" {
                $tz = $task.trigger.timezone
                if (-not $tz) { $tz = "UTC" }
                
                if (Test-CronExpression -Expression $task.trigger.expression -ReferenceTime $currentTime -Timezone $tz) {
                    $lastRun = $null
                    if ($state.ContainsKey($task.id) -and $state[$task.id].lastRun) {
                        $lastRun = [datetime]$state[$task.id].lastRun
                    }
                    
                    if ($lastRun -eq $null -or ($currentTime - $lastRun).TotalMinutes -ge 1) {
                        $shouldFire = $true
                        $fireReason = "cron matched"
                    }
                }
            }
        }
        
        if ($shouldFire) {
            Write-Host ("Task FIRED: " + $task.id + " - " + $task.name + " [" + $fireReason + "]") -ForegroundColor Green
            $results.tasksFired++
            $results.firedTasks += $task.id
            
            if (-not $DryRun) {
                # ============================================================
                # EXECUTE THE TASK
                # ============================================================
                $taskResult = "success"
                $taskError = $null
                
                try {
                    switch ($task.task.type) {
                        "script" {
                            # Run a PowerShell script directly
                            $cmd = $task.task.command
                            Write-Host "  Executing script: $cmd" -ForegroundColor Yellow
                            $scriptOutput = Invoke-Expression $cmd 2>&1
                            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                                $taskResult = "failed"
                                $taskError = "Exit code $LASTEXITCODE"
                            }
                            Write-Host "  Script completed ($taskResult)" -ForegroundColor $(if ($taskResult -eq "success") { "Green" } else { "Red" })
                        }
                        "workflow" {
                            # Trigger a GitHub Actions workflow
                            $ref = $task.task.ref
                            Write-Host "  Triggering workflow: $ref" -ForegroundColor Yellow
                            gh workflow run (Split-Path $ref -Leaf) 2>&1 | Out-Null
                            if ($LASTEXITCODE -ne 0) {
                                $taskResult = "failed"
                                $taskError = "Workflow trigger failed"
                            }
                        }
                        "copilot" {
                            # Run via copilot agent (needs to be inside a copilot session)
                            # When called from ralph-watch, this runs inside the agency session
                            # so WorkIQ and MCP tools are available
                            $scriptRef = $task.task.scriptRef
                            if ($scriptRef -and (Test-Path $scriptRef)) {
                                Write-Host "  Executing copilot script: $scriptRef" -ForegroundColor Yellow
                                & $scriptRef 2>&1 | Out-Null
                                if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                                    $taskResult = "failed"
                                    $taskError = "Script exit code $LASTEXITCODE"
                                }
                            } else {
                                # No script ref — log the instruction for the copilot session to pick up
                                Write-Host "  Copilot task queued: $($task.task.instruction.Substring(0, [Math]::Min(80, $task.task.instruction.Length)))..." -ForegroundColor Cyan
                            }
                        }
                        default {
                            Write-Host "  Unknown task type: $($task.task.type)" -ForegroundColor Yellow
                            $taskResult = "skipped"
                        }
                    }
                } catch {
                    $taskResult = "failed"
                    $taskError = $_.Exception.Message
                    Write-Host "  Task failed: $taskError" -ForegroundColor Red
                    $results.tasksFailed++
                    $results.errors += "$($task.id): $taskError"
                }
                
                $newState[$task.id] = @{
                    lastRun = $currentTime.ToUniversalTime().ToString("o")
                    result = $taskResult
                    error = $taskError
                    provider = $Provider
                }
            }
        }
    }
    
    # Merge and save state
    foreach ($key in $newState.Keys) {
        $state[$key] = $newState[$key]
    }
    
    if (-not $DryRun) {
        $state | ConvertTo-Json | Out-File $StateFile -Encoding utf8 -Force
    }
    
    return $results
}

# ============================================================================
# ENTRY POINT
# ============================================================================

$result = Invoke-SquadScheduler -ScheduleFile $ScheduleFile -StateFile $StateFile -Provider $Provider -DryRun $DryRun

Write-Host ""
Write-Host "Schedule Evaluation Summary:" -ForegroundColor Cyan
Write-Host ("  Tasks Evaluated: " + $result.tasksRun)
Write-Host ("  Tasks Fired:     " + $result.tasksFired)
Write-Host ("  Tasks Failed:    " + $result.tasksFailed)

if ($result.firedTasks.Count -gt 0) {
    Write-Host ("  Fired Tasks:     " + ($result.firedTasks -join ", ")) -ForegroundColor Green
}

if ($result.errors.Count -gt 0) {
    Write-Host "  Errors:"
    foreach ($err in $result.errors) {
        Write-Host ("    - " + $err) -ForegroundColor Red
    }
}

if ($result.success) { exit 0 } else { exit 1 }
