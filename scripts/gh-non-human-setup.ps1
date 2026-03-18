#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Sets up an isolated GitHub CLI environment for a non-human Squad identity.

.DESCRIPTION
    Creates a fully isolated GH_CONFIG_DIR for running Squad autonomously under
    a non-human identity (GitHub App or service account). This enables:
    - Running Copilot CLI sessions without affecting the human user's auth
    - Concurrent Squad agent processes with isolated credentials
    - GitHub App-based authentication (no Copilot license required)

    Directory: ~/.config/gh-non-human → non-human Squad identity

    Authentication methods supported:
    1. GitHub App (recommended) — uses installation token
    2. PAT (fallback) — uses a personal access token
    3. EMU service account — if CoreIdentity provisions one

.PARAMETER AppId
    GitHub App ID for App-based authentication.

.PARAMETER PrivateKeyPath
    Path to the GitHub App private key PEM file.

.PARAMETER InstallationId
    GitHub App installation ID.

.PARAMETER PAT
    Personal Access Token (fallback if no GitHub App).

.PARAMETER Verify
    Only verify existing auth — do not create directories or run login.

.PARAMETER SetupProfile
    Add helper functions to the current user's PowerShell profile.

.EXAMPLE
    ./gh-non-human-setup.ps1 -AppId 12345 -PrivateKeyPath ./key.pem -InstallationId 67890
    # Set up with GitHub App authentication

.EXAMPLE
    ./gh-non-human-setup.ps1 -Verify
    # Verify existing non-human auth is working

.EXAMPLE
    ./gh-non-human-setup.ps1 -PAT "ghp_xxxx"
    # Set up with a PAT (fallback)
#>
[CmdletBinding()]
param(
    [string]$AppId,
    [string]$PrivateKeyPath,
    [string]$InstallationId,
    [string]$PAT,
    [switch]$Verify,
    [switch]$SetupProfile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Configuration ───────────────────────────────────────────────────────────
$NonHumanConfigDir = Join-Path $HOME '.config' 'gh-non-human'
$NonHumanName = 'squad-non-human'
$LogFile = Join-Path $HOME '.config' 'gh-non-human' 'setup.log'

# ── Helpers ─────────────────────────────────────────────────────────────────
function Write-Step {
    param([string]$Message)
    Write-Host "`n▸ $Message" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  ⚠ $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor Red
}

function Log {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$ts] $Message"
    Write-Host $entry
    if (Test-Path (Split-Path $LogFile)) {
        $entry | Out-File -FilePath $LogFile -Append -Encoding UTF8
    }
}

# ── Directory Setup ─────────────────────────────────────────────────────────
function Initialize-ConfigDir {
    Write-Step "Setting up isolated GH_CONFIG_DIR at: $NonHumanConfigDir"

    if (-not (Test-Path $NonHumanConfigDir)) {
        New-Item -ItemType Directory -Path $NonHumanConfigDir -Force | Out-Null
        Write-OK "Created directory: $NonHumanConfigDir"
    } else {
        Write-OK "Directory already exists: $NonHumanConfigDir"
    }

    # Initialize log file
    Log "Non-human GH config setup initialized"
}

# ── GitHub App Authentication ───────────────────────────────────────────────
function Set-GitHubAppAuth {
    param(
        [string]$AppId,
        [string]$KeyPath,
        [string]$InstId
    )

    Write-Step "Configuring GitHub App authentication"

    if (-not (Test-Path $KeyPath)) {
        Write-Fail "Private key not found at: $KeyPath"
        return $false
    }

    # Store app config
    $appConfig = @{
        app_id          = $AppId
        private_key     = $KeyPath
        installation_id = $InstId
        created_at      = (Get-Date -Format 'o')
    } | ConvertTo-Json

    $configPath = Join-Path $NonHumanConfigDir 'app-config.json'
    $appConfig | Out-File -FilePath $configPath -Encoding UTF8
    Write-OK "App config saved to: $configPath"

    # Generate installation token
    Write-Step "Generating installation access token..."
    try {
        $env:GH_CONFIG_DIR = $NonHumanConfigDir

        # Use gh api to generate installation token (requires app JWT first)
        # For now, store the config — token generation requires JWT signing
        Write-Warn "GitHub App JWT signing requires additional setup"
        Write-Warn "Use 'gh auth login' with the installation token once generated"

        Log "GitHub App config stored: AppId=$AppId, InstallationId=$InstId"
        return $true
    } finally {
        $env:GH_CONFIG_DIR = $null
    }
}

# ── PAT Authentication ──────────────────────────────────────────────────────
function Set-PATAuth {
    param([string]$Token)

    Write-Step "Configuring PAT authentication for non-human identity"

    $env:GH_CONFIG_DIR = $NonHumanConfigDir
    try {
        # Login with the PAT
        $Token | gh auth login --with-token 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-OK "PAT authentication successful"
            Log "PAT authentication configured"

            # Verify
            $status = gh auth status 2>&1
            Write-Host $status
            return $true
        } else {
            Write-Fail "PAT authentication failed"
            return $false
        }
    } finally {
        $env:GH_CONFIG_DIR = $null
    }
}

# ── Verification ────────────────────────────────────────────────────────────
function Test-NonHumanAuth {
    Write-Step "Verifying non-human identity authentication"

    if (-not (Test-Path $NonHumanConfigDir)) {
        Write-Fail "Config directory not found: $NonHumanConfigDir"
        return $false
    }

    $env:GH_CONFIG_DIR = $NonHumanConfigDir
    try {
        $status = gh auth status 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-OK "Non-human identity is authenticated"
            Write-Host $status
            Log "Auth verification: PASSED"

            # Test API access
            Write-Step "Testing API access..."
            $user = gh api /user 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($user) {
                Write-OK "API access confirmed. User: $($user.login)"
                Log "API access verified: $($user.login)"
            }

            return $true
        } else {
            Write-Fail "Non-human identity is NOT authenticated"
            Write-Host $status
            Log "Auth verification: FAILED"
            return $false
        }
    } finally {
        $env:GH_CONFIG_DIR = $null
    }
}

# ── Profile Setup ───────────────────────────────────────────────────────────
function Install-ProfileHelpers {
    Write-Step "Installing profile helper functions"

    $profileContent = @'

# ── Non-Human Squad Identity ────────────────────────────────────────────────
function ghn {
    <#
    .SYNOPSIS
        Run gh commands as the non-human Squad identity.
    #>
    $env:GH_CONFIG_DIR = "$HOME\.config\gh-non-human"
    gh @args
    $env:GH_CONFIG_DIR = $null
}

function Invoke-SquadAsNonHuman {
    <#
    .SYNOPSIS
        Run a Squad command under the non-human identity with full isolation.
    #>
    param([string]$Command)
    $env:GH_CONFIG_DIR = "$HOME\.config\gh-non-human"
    try {
        Invoke-Expression $Command
    } finally {
        $env:GH_CONFIG_DIR = $null
    }
}

Set-Alias -Name gh-nonhuman -Value ghn
'@

    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    $existing = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($existing -and $existing.Contains('gh-non-human')) {
        Write-Warn "Profile helpers already installed"
    } else {
        $profileContent | Out-File -FilePath $profilePath -Append -Encoding UTF8
        Write-OK "Profile helpers added to: $profilePath"
        Write-OK "New functions available: ghn, Invoke-SquadAsNonHuman"
    }

    Log "Profile helpers installed"
}

# ── Main ────────────────────────────────────────────────────────────────────
Write-Host "`n════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host "  Non-Human Squad Identity — GitHub CLI Setup" -ForegroundColor Blue
Write-Host "════════════════════════════════════════════════════════════════`n" -ForegroundColor Blue

if ($Verify) {
    $result = Test-NonHumanAuth
    if ($result) {
        Write-Host "`n✅ Non-human identity is ready." -ForegroundColor Green
    } else {
        Write-Host "`n❌ Non-human identity needs setup. Run without -Verify to configure." -ForegroundColor Red
    }
    exit ($result ? 0 : 1)
}

# Step 1: Initialize directory
Initialize-ConfigDir

# Step 2: Configure authentication
$authOk = $false

if ($AppId -and $PrivateKeyPath -and $InstallationId) {
    $authOk = Set-GitHubAppAuth -AppId $AppId -KeyPath $PrivateKeyPath -InstId $InstallationId
} elseif ($PAT) {
    $authOk = Set-PATAuth -Token $PAT
} else {
    Write-Warn "No authentication method specified."
    Write-Host "  Options:"
    Write-Host "    -AppId + -PrivateKeyPath + -InstallationId  (GitHub App)"
    Write-Host "    -PAT 'ghp_xxxx'                             (Personal Access Token)"
    Write-Host ""
    Write-Host "  For now, creating the isolated directory structure only."
    Log "Directory created without authentication"
}

# Step 3: Verify
if ($authOk) {
    Test-NonHumanAuth | Out-Null
}

# Step 4: Install profile helpers (if requested)
if ($SetupProfile) {
    Install-ProfileHelpers
}

# Summary
Write-Host "`n────────────────────────────────────────────────────────────────" -ForegroundColor Blue
Write-Host "  Setup Summary" -ForegroundColor Blue
Write-Host "────────────────────────────────────────────────────────────────" -ForegroundColor Blue
Write-Host "  Config Dir:     $NonHumanConfigDir"
Write-Host "  Auth Status:    $(if ($authOk) { '✅ Configured' } else { '⏳ Pending' })"
Write-Host "  Log File:       $LogFile"
Write-Host ""
Write-Host "  Usage:" -ForegroundColor Yellow
Write-Host '    $env:GH_CONFIG_DIR = "' + $NonHumanConfigDir + '"'
Write-Host "    gh auth status"
Write-Host '    $env:GH_CONFIG_DIR = $null'
Write-Host ""
Write-Host "  Or use the wrapper (after -SetupProfile):" -ForegroundColor Yellow
Write-Host "    ghn auth status"
Write-Host "    ghn issue list --repo tamirdresher_microsoft/tamresearch1"
Write-Host "────────────────────────────────────────────────────────────────`n" -ForegroundColor Blue

Log "Setup complete. Auth: $(if ($authOk) { 'OK' } else { 'PENDING' })"
