<#
.SYNOPSIS
    Bulk provision multiple Microsoft Dev Box instances.

.DESCRIPTION
    Creates multiple Dev Boxes in parallel or sequentially, with automatic naming
    and configuration cloning. Designed for team environments or ephemeral testing.

.PARAMETER Count
    Number of Dev Boxes to create. Must be between 1 and 20.

.PARAMETER NamePrefix
    Prefix for generated Dev Box names. Names will be: prefix-001, prefix-002, etc.
    Default: "devbox"

.PARAMETER Names
    Explicit array of names for Dev Boxes. If provided, Count is ignored.

.PARAMETER SourceDevBoxName
    Name of the source Dev Box to clone configuration from. If not specified,
    auto-detects the first available Dev Box.

.PARAMETER Sequential
    If set, creates Dev Boxes one at a time. Default: parallel creation (up to 5 concurrent)

.PARAMETER MaxConcurrent
    Maximum number of concurrent provisioning operations. Default: 5
    Only used when Sequential is $false.

.PARAMETER TimeoutMinutes
    Maximum time to wait for each Dev Box provisioning (minutes). Default: 30

.EXAMPLE
    .\bulk-provision.ps1 -Count 3
    Creates 3 Dev Boxes: devbox-001, devbox-002, devbox-003

.EXAMPLE
    .\bulk-provision.ps1 -Count 5 -NamePrefix "sprint-42" -Sequential
    Creates 5 Dev Boxes sequentially: sprint-42-001, sprint-42-002, etc.

.EXAMPLE
    .\bulk-provision.ps1 -Names @("alice-dev", "bob-dev", "charlie-dev")
    Creates 3 Dev Boxes with explicit names

.NOTES
    File Name  : bulk-provision.ps1
    Author     : B'Elanna (Infrastructure Expert)
    Issue      : #63 (Phase 2)
    Requires   : Azure CLI with devcenter extension
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 20)]
    [int]$Count = 3,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9-]{1,50}$')]
    [string]$NamePrefix = "devbox",

    [Parameter(Mandatory = $false)]
    [string[]]$Names = @(),

    [Parameter(Mandatory = $false)]
    [string]$SourceDevBoxName = "",

    [Parameter(Mandatory = $false)]
    [switch]$Sequential = $false,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$MaxConcurrent = 5,

    [Parameter(Mandatory = $false)]
    [int]$TimeoutMinutes = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================================
# Functions
# ============================================================================

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-InfoMessage {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-SuccessMessage {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Generate-DevBoxNames {
    param([int]$Count, [string]$Prefix)
    
    $names = @()
    for ($i = 1; $i -le $Count; $i++) {
        $suffix = "{0:D3}" -f $i  # Zero-padded 3 digits: 001, 002, etc.
        $names += "$Prefix-$suffix"
    }
    
    return $names
}

function Test-NameUniqueness {
    param([string[]]$Names)
    
    Write-InfoMessage "Checking for name conflicts..."
    
    try {
        $existingDevBoxes = az devcenter dev dev-box list --output json 2>&1 | ConvertFrom-Json
        
        if ($LASTEXITCODE -ne 0) {
            Write-WarningMessage "Could not list existing Dev Boxes. Skipping uniqueness check."
            return $true
        }
        
        $existingNames = $existingDevBoxes | ForEach-Object { $_.name }
        $conflicts = @()
        
        foreach ($name in $Names) {
            if ($existingNames -contains $name) {
                $conflicts += $name
            }
        }
        
        if ($conflicts.Count -gt 0) {
            Write-ErrorMessage "Name conflicts detected: $($conflicts -join ', ')"
            return $false
        }
        
        Write-InfoMessage "All names are unique."
        return $true
    }
    catch {
        Write-WarningMessage "Error checking uniqueness: $_"
        return $true
    }
}

function Invoke-SequentialProvisioning {
    param([string[]]$DevBoxNames, [string]$SourceName)
    
    Write-Header "Sequential Provisioning"
    Write-InfoMessage "Creating $($DevBoxNames.Count) Dev Boxes sequentially..."
    
    $results = @()
    $succeeded = 0
    $failed = 0
    
    foreach ($name in $DevBoxNames) {
        Write-Host ""
        Write-InfoMessage "[$($succeeded + $failed + 1)/$($DevBoxNames.Count)] Creating: $name"
        
        try {
            $cloneScript = Join-Path $PSScriptRoot "clone-devbox.ps1"
            
            & $cloneScript `
                -NewDevBoxName $name `
                -SourceDevBoxName $SourceName `
                -WaitForCompletion $true `
                -TimeoutMinutes $TimeoutMinutes
            
            if ($LASTEXITCODE -eq 0) {
                Write-SuccessMessage "Completed: $name"
                $succeeded++
                $results += [PSCustomObject]@{
                    Name = $name
                    Status = "Success"
                }
            }
            else {
                Write-ErrorMessage "Failed: $name"
                $failed++
                $results += [PSCustomObject]@{
                    Name = $name
                    Status = "Failed"
                }
            }
        }
        catch {
            Write-ErrorMessage "Exception creating $name: $_"
            $failed++
            $results += [PSCustomObject]@{
                Name = $name
                Status = "Failed"
            }
        }
    }
    
    return [PSCustomObject]@{
        Total = $DevBoxNames.Count
        Succeeded = $succeeded
        Failed = $failed
        Results = $results
    }
}

function Invoke-ParallelProvisioning {
    param([string[]]$DevBoxNames, [string]$SourceName, [int]$MaxConcurrent)
    
    Write-Header "Parallel Provisioning"
    Write-InfoMessage "Creating $($DevBoxNames.Count) Dev Boxes (max $MaxConcurrent concurrent)..."
    
    $cloneScript = Join-Path $PSScriptRoot "clone-devbox.ps1"
    $jobs = @()
    $results = @()
    
    # Start jobs in batches
    $batchIndex = 0
    while ($batchIndex -lt $DevBoxNames.Count) {
        $batchSize = [Math]::Min($MaxConcurrent, $DevBoxNames.Count - $batchIndex)
        $batch = $DevBoxNames[$batchIndex..($batchIndex + $batchSize - 1)]
        
        Write-InfoMessage "Starting batch: $($batch -join ', ')"
        
        foreach ($name in $batch) {
            $job = Start-Job -ScriptBlock {
                param($Script, $Name, $Source, $Timeout)
                
                & $Script `
                    -NewDevBoxName $Name `
                    -SourceDevBoxName $Source `
                    -WaitForCompletion $true `
                    -TimeoutMinutes $Timeout
                
                return [PSCustomObject]@{
                    Name = $Name
                    ExitCode = $LASTEXITCODE
                }
            } -ArgumentList $cloneScript, $name, $SourceName, $TimeoutMinutes
            
            $jobs += [PSCustomObject]@{
                Name = $name
                Job = $job
            }
        }
        
        $batchIndex += $batchSize
        
        # Wait for batch to complete before starting next batch
        if ($batchIndex -lt $DevBoxNames.Count) {
            Write-InfoMessage "Waiting for batch to complete..."
            $jobs | ForEach-Object { $_.Job } | Wait-Job | Out-Null
        }
    }
    
    # Wait for all jobs to complete
    Write-InfoMessage "Waiting for all provisioning operations to complete..."
    $jobs | ForEach-Object { $_.Job } | Wait-Job | Out-Null
    
    # Collect results
    $succeeded = 0
    $failed = 0
    
    foreach ($jobInfo in $jobs) {
        $result = Receive-Job -Job $jobInfo.Job
        Remove-Job -Job $jobInfo.Job
        
        if ($result.ExitCode -eq 0) {
            Write-SuccessMessage "Completed: $($jobInfo.Name)"
            $succeeded++
            $results += [PSCustomObject]@{
                Name = $jobInfo.Name
                Status = "Success"
            }
        }
        else {
            Write-ErrorMessage "Failed: $($jobInfo.Name)"
            $failed++
            $results += [PSCustomObject]@{
                Name = $jobInfo.Name
                Status = "Failed"
            }
        }
    }
    
    return [PSCustomObject]@{
        Total = $DevBoxNames.Count
        Succeeded = $succeeded
        Failed = $failed
        Results = $results
    }
}

function Show-Summary {
    param($Summary)
    
    Write-Header "Bulk Provisioning Summary"
    
    Write-Host "Total Requested:   " -NoNewline
    Write-Host $Summary.Total -ForegroundColor Yellow
    
    Write-Host "Succeeded:         " -NoNewline
    Write-Host $Summary.Succeeded -ForegroundColor Green
    
    Write-Host "Failed:            " -NoNewline
    $failedColor = if ($Summary.Failed -gt 0) { "Red" } else { "Gray" }
    Write-Host $Summary.Failed -ForegroundColor $failedColor
    
    Write-Host ""
    Write-Host "Details:" -ForegroundColor Cyan
    
    foreach ($result in $Summary.Results) {
        $statusColor = if ($result.Status -eq "Success") { "Green" } else { "Red" }
        $statusSymbol = if ($result.Status -eq "Success") { "✓" } else { "✗" }
        
        Write-Host "  $statusSymbol $($result.Name)" -ForegroundColor $statusColor
    }
    
    Write-Host ""
}

# ============================================================================
# Main Script
# ============================================================================

Write-Header "Bulk Dev Box Provisioning"

# Determine names to create
$targetNames = @()

if ($Names.Count -gt 0) {
    Write-InfoMessage "Using explicit names: $($Names -join ', ')"
    $targetNames = $Names
}
else {
    Write-InfoMessage "Generating $Count names with prefix: $NamePrefix"
    $targetNames = Generate-DevBoxNames -Count $Count -Prefix $NamePrefix
    Write-InfoMessage "Generated names: $($targetNames -join ', ')"
}

# Check for name conflicts
if (-not (Test-NameUniqueness -Names $targetNames)) {
    Write-ErrorMessage "Aborting due to name conflicts."
    exit 1
}

# Confirm action
Write-Host ""
Write-Host "Ready to create $($targetNames.Count) Dev Boxes:" -ForegroundColor Yellow
foreach ($name in $targetNames) {
    Write-Host "  - $name" -ForegroundColor Cyan
}
Write-Host ""

$confirm = Read-Host "Proceed with bulk provisioning? (Y/N)"
if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-WarningMessage "Bulk provisioning cancelled."
    exit 0
}

# Execute provisioning
$summary = $null

if ($Sequential) {
    $summary = Invoke-SequentialProvisioning -DevBoxNames $targetNames -SourceName $SourceDevBoxName
}
else {
    $summary = Invoke-ParallelProvisioning -DevBoxNames $targetNames -SourceName $SourceDevBoxName -MaxConcurrent $MaxConcurrent
}

# Show results
Show-Summary -Summary $summary

# Exit with error if any failed
if ($summary.Failed -gt 0) {
    Write-ErrorMessage "Bulk provisioning completed with failures."
    exit 1
}

Write-SuccessMessage "All Dev Boxes provisioned successfully!"
