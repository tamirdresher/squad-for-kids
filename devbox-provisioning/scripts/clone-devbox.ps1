<#
.SYNOPSIS
    Clone an existing Microsoft Dev Box configuration.

.DESCRIPTION
    Automatically detects the configuration of an existing Dev Box and creates
    a new Dev Box with identical settings (Dev Center, project, pool, image).

.PARAMETER NewDevBoxName
    Name for the new Dev Box instance. Must be 3-63 characters, alphanumeric and hyphens.

.PARAMETER SourceDevBoxName
    Name of the source Dev Box to clone. If not specified, attempts to auto-detect
    the first available Dev Box or prompts for selection.

.PARAMETER WaitForCompletion
    If set, script will wait for Dev Box provisioning to complete before exiting.
    Default: $true

.PARAMETER TimeoutMinutes
    Maximum time to wait for provisioning completion (minutes).
    Default: 30

.EXAMPLE
    .\clone-devbox.ps1 -NewDevBoxName "my-clone"
    Auto-detects current Dev Box and clones it.

.EXAMPLE
    .\clone-devbox.ps1 -NewDevBoxName "hotfix-env" -SourceDevBoxName "main-devbox"
    Clones a specific Dev Box by name.

.NOTES
    File Name  : clone-devbox.ps1
    Author     : B'Elanna (Infrastructure Expert)
    Issue      : #35
    Requires   : Azure CLI with devcenter extension
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9-]{3,63}$')]
    [string]$NewDevBoxName,

    [Parameter(Mandatory = $false)]
    [string]$SourceDevBoxName = "",

    [Parameter(Mandatory = $false)]
    [bool]$WaitForCompletion = $true,

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

function Get-CurrentDevBoxes {
    Write-InfoMessage "Discovering existing Dev Boxes..."
    
    try {
        $devBoxes = az devcenter dev dev-box list --output json 2>&1 | ConvertFrom-Json
        
        if ($LASTEXITCODE -ne 0 -or -not $devBoxes) {
            Write-ErrorMessage "Failed to list Dev Boxes. Error: $devBoxes"
            return $null
        }
        
        Write-InfoMessage "Found $($devBoxes.Count) Dev Box(es)."
        return $devBoxes
    }
    catch {
        Write-ErrorMessage "Exception listing Dev Boxes: $_"
        return $null
    }
}

function Select-SourceDevBox {
    param([array]$DevBoxes, [string]$PreferredName)
    
    if ($DevBoxes.Count -eq 0) {
        Write-ErrorMessage "No existing Dev Boxes found to clone."
        return $null
    }
    
    # If a specific name was provided, try to find it
    if ($PreferredName) {
        $source = $DevBoxes | Where-Object { $_.name -eq $PreferredName }
        
        if ($source) {
            Write-InfoMessage "Found source Dev Box: $PreferredName"
            return $source
        }
        else {
            Write-WarningMessage "Dev Box '$PreferredName' not found."
        }
    }
    
    # If only one Dev Box exists, use it
    if ($DevBoxes.Count -eq 1) {
        Write-InfoMessage "Auto-selecting the only available Dev Box: $($DevBoxes[0].name)"
        return $DevBoxes[0]
    }
    
    # Multiple Dev Boxes - show menu
    Write-Host ""
    Write-Host "Multiple Dev Boxes found. Select source to clone:" -ForegroundColor Yellow
    Write-Host ""
    
    for ($i = 0; $i -lt $DevBoxes.Count; $i++) {
        $devBox = $DevBoxes[$i]
        Write-Host "  [$($i + 1)] $($devBox.name)" -ForegroundColor Cyan
        Write-Host "      Project: $($devBox.projectName)" -ForegroundColor Gray
        Write-Host "      Pool: $($devBox.poolName)" -ForegroundColor Gray
        Write-Host "      Status: $($devBox.provisioningState)" -ForegroundColor Gray
        Write-Host ""
    }
    
    do {
        $selection = Read-Host "Enter selection (1-$($DevBoxes.Count))"
        $selectionIndex = [int]$selection - 1
    } while ($selectionIndex -lt 0 -or $selectionIndex -ge $DevBoxes.Count)
    
    $selectedDevBox = $DevBoxes[$selectionIndex]
    Write-InfoMessage "Selected: $($selectedDevBox.name)"
    
    return $selectedDevBox
}

function Get-DevBoxDetails {
    param([string]$Name)
    
    Write-InfoMessage "Fetching detailed configuration for: $Name"
    
    try {
        $devBox = az devcenter dev dev-box show --name $Name --output json 2>&1 | ConvertFrom-Json
        
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMessage "Failed to get Dev Box details. Error: $devBox"
            return $null
        }
        
        return $devBox
    }
    catch {
        Write-ErrorMessage "Exception fetching Dev Box details: $_"
        return $null
    }
}

function Show-CloneConfiguration {
    param($SourceDevBox)
    
    Write-Header "Clone Configuration"
    
    Write-Host "Source Dev Box:    " -NoNewline
    Write-Host $SourceDevBox.name -ForegroundColor Yellow
    
    Write-Host "New Dev Box:       " -NoNewline
    Write-Host $NewDevBoxName -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "Configuration to clone:" -ForegroundColor Cyan
    
    Write-Host "  Dev Center:      " -NoNewline
    Write-Host $SourceDevBox.devCenterName -ForegroundColor White
    
    Write-Host "  Project:         " -NoNewline
    Write-Host $SourceDevBox.projectName -ForegroundColor White
    
    Write-Host "  Pool:            " -NoNewline
    Write-Host $SourceDevBox.poolName -ForegroundColor White
    
    if ($SourceDevBox.hardwareProfile) {
        Write-Host "  Hardware:        " -NoNewline
        Write-Host "$($SourceDevBox.hardwareProfile.skuName)" -ForegroundColor White
    }
    
    if ($SourceDevBox.imageReference) {
        Write-Host "  Image:           " -NoNewline
        Write-Host "$($SourceDevBox.imageReference.name)" -ForegroundColor White
    }
    
    Write-Host ""
}

# ============================================================================
# Main Script
# ============================================================================

Write-Header "Dev Box Cloning Script"

# Prerequisites check
Write-InfoMessage "Checking prerequisites..."

try {
    $azVersion = az --version 2>&1 | Select-String "azure-cli" | Select-Object -First 1
    if (-not $azVersion) {
        Write-ErrorMessage "Azure CLI not found. Please install from https://aka.ms/InstallAzureCLI"
        exit 1
    }
}
catch {
    Write-ErrorMessage "Azure CLI not found. Please install from https://aka.ms/InstallAzureCLI"
    exit 1
}

# Check authentication
try {
    $account = az account show --output json 2>&1 | ConvertFrom-Json
    if (-not $account.id) {
        Write-ErrorMessage "Not authenticated to Azure. Please run: az login"
        exit 1
    }
    Write-InfoMessage "Authenticated as: $($account.user.name)"
}
catch {
    Write-ErrorMessage "Not authenticated to Azure. Please run: az login"
    exit 1
}

# Get existing Dev Boxes
$devBoxes = Get-CurrentDevBoxes
if (-not $devBoxes) {
    exit 1
}

# Select source Dev Box
$sourceDevBox = Select-SourceDevBox -DevBoxes $devBoxes -PreferredName $SourceDevBoxName
if (-not $sourceDevBox) {
    exit 1
}

# Get detailed configuration
$sourceDetails = Get-DevBoxDetails -Name $sourceDevBox.name
if (-not $sourceDetails) {
    Write-WarningMessage "Could not fetch detailed configuration. Using basic info."
    $sourceDetails = $sourceDevBox
}

# Show what will be cloned
Show-CloneConfiguration -SourceDevBox $sourceDetails

# Confirm action
Write-Host ""
$confirm = Read-Host "Proceed with cloning? (Y/N)"
if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-WarningMessage "Clone operation cancelled."
    exit 0
}

# Extract configuration for cloning
$devCenterName = $sourceDetails.devCenterName
$projectName = $sourceDetails.projectName
$poolName = $sourceDetails.poolName

# Call the provision script
$provisionScriptPath = Join-Path $PSScriptRoot "provision.ps1"

if (-not (Test-Path $provisionScriptPath)) {
    Write-ErrorMessage "provision.ps1 not found at: $provisionScriptPath"
    Write-InfoMessage "Creating Dev Box manually via Azure CLI..."
    
    try {
        Write-InfoMessage "Creating Dev Box: $NewDevBoxName"
        $result = az devcenter dev dev-box create `
            --dev-center-name $devCenterName `
            --project-name $projectName `
            --pool-name $poolName `
            --name $NewDevBoxName `
            --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMessage "Failed to create Dev Box. Error: $result"
            exit 1
        }
        
        Write-InfoMessage "Dev Box creation initiated successfully."
        Write-InfoMessage "Check status with: az devcenter dev dev-box show --name $NewDevBoxName"
    }
    catch {
        Write-ErrorMessage "Exception creating Dev Box: $_"
        exit 1
    }
}
else {
    Write-InfoMessage "Invoking provision.ps1..."
    
    & $provisionScriptPath `
        -DevBoxName $NewDevBoxName `
        -DevCenterName $devCenterName `
        -ProjectName $projectName `
        -PoolName $poolName `
        -WaitForCompletion $WaitForCompletion `
        -TimeoutMinutes $TimeoutMinutes
    
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Provisioning script failed."
        exit 1
    }
}

Write-Header "Clone Complete"
Write-InfoMessage "Dev Box '$NewDevBoxName' has been cloned from '$($sourceDetails.name)'!"
