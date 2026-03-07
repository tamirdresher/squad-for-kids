<#
.SYNOPSIS
    Provision a new Microsoft Dev Box instance.

.DESCRIPTION
    Creates a new Dev Box in the specified project and pool using Azure CLI.
    Supports configuration override and wait-for-completion functionality.

.PARAMETER DevBoxName
    Name for the new Dev Box instance. Must be 3-63 characters, alphanumeric and hyphens.

.PARAMETER DevCenterName
    Name of the Dev Center resource. If not specified, uses default from script.

.PARAMETER ProjectName
    Name of the Dev Center Project. If not specified, uses default from script.

.PARAMETER PoolName
    Name of the Dev Box Pool to provision from. If not specified, uses default from script.

.PARAMETER WaitForCompletion
    If set, script will wait for Dev Box provisioning to complete before exiting.
    Default: $true

.PARAMETER TimeoutMinutes
    Maximum time to wait for provisioning completion (minutes).
    Default: 30

.EXAMPLE
    .\provision.ps1 -DevBoxName "my-devbox"
    Creates a Dev Box using default configuration values.

.EXAMPLE
    .\provision.ps1 -DevBoxName "feature-x" -ProjectName "MyProject" -PoolName "MyPool" -WaitForCompletion
    Creates a Dev Box with specific project and pool, waits for completion.

.NOTES
    File Name  : provision.ps1
    Author     : B'Elanna (Infrastructure Expert)
    Issue      : #35
    Requires   : Azure CLI with devcenter extension
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9-]{3,63}$')]
    [string]$DevBoxName,

    [Parameter(Mandatory = $false)]
    [string]$DevCenterName = "",

    [Parameter(Mandatory = $false)]
    [string]$ProjectName = "",

    [Parameter(Mandatory = $false)]
    [string]$PoolName = "",

    [Parameter(Mandatory = $false)]
    [bool]$WaitForCompletion = $true,

    [Parameter(Mandatory = $false)]
    [int]$TimeoutMinutes = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================================
# Configuration
# ============================================================================

# Default values - UPDATE THESE with your Dev Center configuration
$DefaultDevCenterName = "YOUR-DEVCENTER-NAME"    # TODO: Update after discovery
$DefaultProjectName = "YOUR-PROJECT-NAME"        # TODO: Update after discovery
$DefaultPoolName = "YOUR-POOL-NAME"              # TODO: Update after discovery

# Use provided values or fall back to defaults
$EffectiveDevCenterName = if ($DevCenterName) { $DevCenterName } else { $DefaultDevCenterName }
$EffectiveProjectName = if ($ProjectName) { $ProjectName } else { $DefaultProjectName }
$EffectivePoolName = if ($PoolName) { $PoolName } else { $DefaultPoolName }

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

function Test-AzureCLI {
    Write-InfoMessage "Checking Azure CLI availability..."
    
    try {
        $azVersion = az --version 2>&1 | Select-String "azure-cli" | Select-Object -First 1
        if ($azVersion) {
            Write-InfoMessage "Azure CLI found: $azVersion"
            return $true
        }
    }
    catch {
        Write-ErrorMessage "Azure CLI not found. Please install from https://aka.ms/InstallAzureCLI"
        return $false
    }
    
    return $false
}

function Test-DevCenterExtension {
    Write-InfoMessage "Checking Azure CLI devcenter extension..."
    
    try {
        $extensions = az extension list --output json | ConvertFrom-Json
        $devCenterExt = $extensions | Where-Object { $_.name -eq "devcenter" }
        
        if ($devCenterExt) {
            Write-InfoMessage "Dev Center extension found: v$($devCenterExt.version)"
            return $true
        }
        else {
            Write-WarningMessage "Dev Center extension not installed. Attempting to install..."
            az extension add --name devcenter --yes
            
            # Verify installation
            $extensions = az extension list --output json | ConvertFrom-Json
            $devCenterExt = $extensions | Where-Object { $_.name -eq "devcenter" }
            
            if ($devCenterExt) {
                Write-InfoMessage "Dev Center extension installed successfully."
                return $true
            }
            else {
                Write-ErrorMessage "Failed to install Dev Center extension."
                return $false
            }
        }
    }
    catch {
        Write-ErrorMessage "Error checking Dev Center extension: $_"
        return $false
    }
}

function Test-AzureAuth {
    Write-InfoMessage "Checking Azure authentication..."
    
    try {
        $account = az account show --output json 2>&1 | ConvertFrom-Json
        if ($account.id) {
            Write-InfoMessage "Authenticated as: $($account.user.name)"
            Write-InfoMessage "Subscription: $($account.name) ($($account.id))"
            return $true
        }
    }
    catch {
        Write-ErrorMessage "Not authenticated to Azure. Please run: az login"
        return $false
    }
    
    return $false
}

function New-DevBox {
    param(
        [string]$Name,
        [string]$DevCenter,
        [string]$Project,
        [string]$Pool
    )
    
    Write-InfoMessage "Creating Dev Box: $Name"
    Write-InfoMessage "  Dev Center: $DevCenter"
    Write-InfoMessage "  Project: $Project"
    Write-InfoMessage "  Pool: $Pool"
    
    try {
        $result = az devcenter dev dev-box create `
            --dev-center-name $DevCenter `
            --project-name $Project `
            --pool-name $Pool `
            --name $Name `
            --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMessage "Failed to create Dev Box. Error: $result"
            return $null
        }
        
        $devBox = $result | ConvertFrom-Json
        Write-InfoMessage "Dev Box creation initiated successfully."
        Write-InfoMessage "  Status: $($devBox.provisioningState)"
        
        return $devBox
    }
    catch {
        Write-ErrorMessage "Exception creating Dev Box: $_"
        return $null
    }
}

function Wait-DevBoxProvisioning {
    param(
        [string]$Name,
        [int]$TimeoutMinutes
    )
    
    Write-InfoMessage "Waiting for Dev Box provisioning to complete..."
    Write-InfoMessage "  Timeout: $TimeoutMinutes minutes"
    
    $startTime = Get-Date
    $timeoutTime = $startTime.AddMinutes($TimeoutMinutes)
    $pollIntervalSeconds = 30
    $attempt = 0
    
    while ((Get-Date) -lt $timeoutTime) {
        $attempt++
        
        try {
            $devBox = az devcenter dev dev-box show --name $Name --output json 2>&1 | ConvertFrom-Json
            $status = $devBox.provisioningState
            
            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
            Write-Host "[POLL $attempt] Status: $status (Elapsed: $elapsed min)" -ForegroundColor Gray
            
            if ($status -eq "Succeeded" -or $status -eq "Running") {
                Write-InfoMessage "Dev Box provisioned successfully!"
                Write-InfoMessage "  Final Status: $status"
                Write-InfoMessage "  Total Time: $elapsed minutes"
                return $devBox
            }
            elseif ($status -eq "Failed") {
                Write-ErrorMessage "Dev Box provisioning failed."
                return $null
            }
            
            Start-Sleep -Seconds $pollIntervalSeconds
        }
        catch {
            Write-WarningMessage "Error polling Dev Box status: $_"
            Start-Sleep -Seconds $pollIntervalSeconds
        }
    }
    
    Write-ErrorMessage "Dev Box provisioning timed out after $TimeoutMinutes minutes."
    return $null
}

function Show-DevBoxInfo {
    param($DevBox)
    
    Write-Header "Dev Box Information"
    
    Write-Host "Name:              " -NoNewline
    Write-Host $DevBox.name -ForegroundColor Yellow
    
    Write-Host "Status:            " -NoNewline
    $statusColor = if ($DevBox.provisioningState -eq "Succeeded" -or $DevBox.provisioningState -eq "Running") { "Green" } else { "Red" }
    Write-Host $DevBox.provisioningState -ForegroundColor $statusColor
    
    Write-Host "Project:           " -NoNewline
    Write-Host $DevBox.projectName -ForegroundColor Yellow
    
    Write-Host "Pool:              " -NoNewline
    Write-Host $DevBox.poolName -ForegroundColor Yellow
    
    if ($DevBox.hardwareProfile) {
        Write-Host "Hardware:          " -NoNewline
        Write-Host "$($DevBox.hardwareProfile.skuName)" -ForegroundColor Yellow
    }
    
    if ($DevBox.imageReference) {
        Write-Host "Image:             " -NoNewline
        Write-Host "$($DevBox.imageReference.name)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-InfoMessage "To connect to your Dev Box, run:"
    Write-Host "  az devcenter dev dev-box show --name $($DevBox.name) --query `"remoteConnectionUri`" --output tsv" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================================
# Main Script
# ============================================================================

Write-Header "Dev Box Provisioning Script"

# Prerequisites checks
if (-not (Test-AzureCLI)) {
    exit 1
}

if (-not (Test-DevCenterExtension)) {
    Write-WarningMessage "Proceeding without Dev Center extension. Some functionality may be limited."
}

if (-not (Test-AzureAuth)) {
    exit 1
}

# Validate configuration
if ($EffectiveDevCenterName -eq "YOUR-DEVCENTER-NAME" -or 
    $EffectiveProjectName -eq "YOUR-PROJECT-NAME" -or 
    $EffectivePoolName -eq "YOUR-POOL-NAME") {
    Write-ErrorMessage "Configuration not set. Please update the default values in this script or provide parameters."
    Write-Host ""
    Write-Host "You can discover your configuration with:" -ForegroundColor Yellow
    Write-Host "  az devcenter dev dev-box list --output table" -ForegroundColor Cyan
    Write-Host "  az devcenter dev project list --output table" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Create Dev Box
$devBox = New-DevBox -Name $DevBoxName -DevCenter $EffectiveDevCenterName -Project $EffectiveProjectName -Pool $EffectivePoolName

if (-not $devBox) {
    exit 1
}

# Wait for completion if requested
if ($WaitForCompletion) {
    $devBox = Wait-DevBoxProvisioning -Name $DevBoxName -TimeoutMinutes $TimeoutMinutes
    
    if (-not $devBox) {
        exit 1
    }
}

# Show results
Show-DevBoxInfo -DevBox $devBox

Write-Header "Provisioning Complete"
Write-InfoMessage "Dev Box '$DevBoxName' is ready!"
