#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates .squads/config.json files against the schema.

.DESCRIPTION
    Finds all .squads/config.json files in the repository and validates them
    against the JSON schema. Reports errors and exits with non-zero code if
    validation fails.

.PARAMETER Path
    Path to a specific .squads/config.json file to validate. If not provided,
    scans the entire repository.

.PARAMETER Quiet
    Suppress success messages, only show errors.

.EXAMPLE
    .\scripts\validate-squads-config.ps1
    Validates all .squads/config.json files in the repository.

.EXAMPLE
    .\scripts\validate-squads-config.ps1 -Path src/platform/.squads/config.json
    Validates a specific config file.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Path,
    
    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

# Get repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Get-Location).Path
}

# Schema path
$schemaPath = Join-Path $repoRoot ".squad/schemas/squads-config.schema.json"

if (-not (Test-Path $schemaPath)) {
    Write-Error "Schema not found at: $schemaPath"
    exit 1
}

# Load schema
$schema = Get-Content $schemaPath -Raw | ConvertFrom-Json

# Find config files
$configFiles = @()
if ($Path) {
    if (-not (Test-Path $Path)) {
        Write-Error "Config file not found: $Path"
        exit 1
    }
    $configFiles = @($Path)
} else {
    Write-Host "DEBUG: Searching for .squads/config.json files from repo root: $repoRoot" -ForegroundColor Cyan
    $allConfigFiles = Get-ChildItem -Path $repoRoot -Recurse -Filter "config.json" -Force
    Write-Host "DEBUG: Found $($allConfigFiles.Count) total config.json files" -ForegroundColor Cyan
    $configFiles = $allConfigFiles | 
        Where-Object { $_.Directory.Name -eq ".squads" } |
        Select-Object -ExpandProperty FullName
    Write-Host "DEBUG: Filtered to $($configFiles.Count) files in .squads directories" -ForegroundColor Cyan
    foreach ($f in $configFiles) {
        Write-Host "DEBUG:   - $f" -ForegroundColor Cyan
    }
}

if ($configFiles.Count -eq 0) {
    if (-not $Quiet) {
        Write-Host "✓ No .squads/config.json files found - nothing to validate" -ForegroundColor Green
    }
    exit 0
}

# Validation function
function Test-JsonSchema {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Schema,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    $errors = @()
    
    # Check required fields
    if ($Schema.required) {
        foreach ($requiredField in $Schema.required) {
            if (-not $Config.PSObject.Properties.Name.Contains($requiredField)) {
                $errors += "Missing required field: $requiredField"
            }
        }
    }
    
    # Check version
    if ($Config.version -ne 1) {
        $errors += "Invalid version: $($Config.version) (must be 1)"
    }
    
    # Validate area
    if ($Config.area) {
        if (-not $Config.area.name) {
            $errors += "area.name is required"
        } elseif ($Config.area.name -notmatch '^[a-z0-9-]+$') {
            $errors += "area.name must be lowercase with hyphens only: $($Config.area.name)"
        }
        
        if (-not $Config.area.path) {
            $errors += "area.path is required"
        }
    }
    
    # Validate routing labels (if present)
    if ($Config.routing -and $Config.routing.labels) {
        foreach ($label in $Config.routing.labels.PSObject.Properties.Name) {
            if ($label -notmatch '^[a-z0-9:-]+$') {
                $errors += "Invalid label format: $label (must be lowercase with hyphens/colons)"
            }
        }
    }
    
    # Validate capabilities (if present)
    if ($Config.capabilities -and $Config.capabilities.required) {
        $validCapabilities = @("whatsapp", "browser", "gpu", "personal-gh", "emu-gh", "teams-mcp", "onedrive", "azure-speech")
        foreach ($cap in $Config.capabilities.required) {
            if ($cap -notin $validCapabilities) {
                $errors += "Invalid capability: $cap (must be one of: $($validCapabilities -join ', '))"
            }
        }
    }
    
    return $errors
}

# Validate all configs
$totalErrors = 0
$validatedCount = 0

foreach ($configFile in $configFiles) {
    $relativePath = $configFile.Replace($repoRoot, "").TrimStart("/\")
    
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        $errors = Test-JsonSchema -Config $config -Schema $schema -Path $configFile
        
        if ($errors.Count -eq 0) {
            if (-not $Quiet) {
                Write-Host "✓ $relativePath" -ForegroundColor Green
            }
            $validatedCount++
        } else {
            Write-Host "✗ $relativePath" -ForegroundColor Red
            foreach ($validationError in $errors) {
                Write-Host "  - $validationError" -ForegroundColor Red
            }
            $totalErrors += $errors.Count
        }
    } catch {
        Write-Host "✗ $relativePath" -ForegroundColor Red
        Write-Host "  - JSON parse error: $($_.Exception.Message)" -ForegroundColor Red
        $totalErrors++
    }
}

# Summary
if (-not $Quiet) {
    Write-Host ""
    Write-Host "Validated $validatedCount file(s)" -ForegroundColor Cyan
}

if ($totalErrors -gt 0) {
    Write-Host "Found $totalErrors validation error(s)" -ForegroundColor Red
    exit 1
} else {
    if (-not $Quiet) {
        Write-Host "All configurations valid ✓" -ForegroundColor Green
    }
    exit 0
}
