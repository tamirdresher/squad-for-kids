#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Sets up isolated GitHub CLI config directories for multi-account auth.

.DESCRIPTION
    Creates two isolated GH_CONFIG_DIR directories and authenticates each
    to a separate GitHub account. This eliminates cross-talk between concurrent
    processes (e.g., multiple Ralph instances) that need different accounts.

    Directories:
      ~/.config/gh-emu    → tamirdresher_microsoft (EMU/work)
      ~/.config/gh-public → tamirdresher           (personal)

    Reference: https://github.com/jongio/gh-public-gh-emu-setup

.PARAMETER SkipLogin
    Skip the interactive gh auth login prompts (useful if already authenticated).

.PARAMETER Verify
    Only verify existing auth — do not create directories or run login.

.EXAMPLE
    ./setup-gh-isolated-auth.ps1
    # Full setup: create dirs, authenticate both accounts, verify.

.EXAMPLE
    ./setup-gh-isolated-auth.ps1 -Verify
    # Just check that both accounts are authenticated.

.EXAMPLE
    ./setup-gh-isolated-auth.ps1 -SkipLogin
    # Create directories but skip login (if tokens were already provisioned).
#>
[CmdletBinding()]
param(
    [switch]$SkipLogin,
    [switch]$Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Configuration ───────────────────────────────────────────────────────────
$accounts = @(
    @{
        Name      = 'EMU (work)'
        ConfigDir = Join-Path $HOME '.config' 'gh-emu'
        User      = 'tamirdresher_microsoft'
        Host      = 'github.com'
    }
    @{
        Name      = 'Public (personal)'
        ConfigDir = Join-Path $HOME '.config' 'gh-public'
        User      = 'tamirdresher'
        Host      = 'github.com'
    }
)

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

function Test-GhInstalled {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        Write-Fail 'GitHub CLI (gh) is not installed or not on PATH.'
        Write-Host '  Install from: https://cli.github.com/' -ForegroundColor Gray
        return $false
    }
    $version = & gh --version 2>&1 | Select-Object -First 1
    Write-OK "GitHub CLI found: $version"
    return $true
}

function New-ConfigDir {
    param([string]$Path)
    if (Test-Path $Path) {
        Write-OK "Directory already exists: $Path"
    } else {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        Write-OK "Created directory: $Path"
    }
}

function Invoke-GhLogin {
    param(
        [string]$ConfigDir,
        [string]$HostName,
        [string]$AccountName
    )

    # Capture before ANY operations that might touch GH_CONFIG_DIR (e.g. Test-GhAuth)
    $originalConfigDir = $env:GH_CONFIG_DIR

    Write-Host ''
    Write-Host "  Logging in as $AccountName to $HostName" -ForegroundColor White
    Write-Host "  Config dir: $ConfigDir" -ForegroundColor Gray
    Write-Host ''

    try {
        $env:GH_CONFIG_DIR = $ConfigDir
        & gh auth login --hostname $HostName --web --git-protocol https
        if ($LASTEXITCODE -ne 0) {
            throw "gh auth login failed for $AccountName (exit code $LASTEXITCODE)"
        }
    }
    finally {
        # Restore previous value (may be $null)
        $env:GH_CONFIG_DIR = $originalConfigDir
    }
}

function Test-GhAuth {
    param(
        [string]$ConfigDir,
        [string]$ExpectedUser,
        [string]$AccountName
    )

    $originalConfigDir = $env:GH_CONFIG_DIR
    try {
        $env:GH_CONFIG_DIR = $ConfigDir

        # Check auth status
        $status = & gh auth status 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "$AccountName — not authenticated"
            Write-Host "  $status" -ForegroundColor Gray
            return $false
        }

        # Verify the logged-in user matches expectations
        $actualUser = (& gh api user --jq '.login' 2>&1).Trim()
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "$AccountName — authenticated but could not verify user"
            Write-Host "  $status" -ForegroundColor Gray
            return $true  # auth works, just can't confirm user
        }

        if ($actualUser -eq $ExpectedUser) {
            Write-OK "$AccountName — authenticated as $actualUser"
            return $true
        } else {
            Write-Warn "$AccountName — authenticated as '$actualUser' (expected '$ExpectedUser')"
            return $false
        }
    }
    finally {
        $env:GH_CONFIG_DIR = $originalConfigDir
    }
}

# ── Main ────────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║   GitHub CLI Isolated Auth Setup (GH_CONFIG_DIR)           ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan

# Pre-flight: gh must be installed
Write-Step 'Checking prerequisites'
if (-not (Test-GhInstalled)) {
    exit 1
}

# Verify-only mode
if ($Verify) {
    Write-Step 'Verifying existing auth for all accounts'
    $allOk = $true
    foreach ($acct in $accounts) {
        if (-not (Test-Path $acct.ConfigDir)) {
            Write-Fail "$($acct.Name) — config dir not found: $($acct.ConfigDir)"
            $allOk = $false
            continue
        }
        if (-not (Test-GhAuth -ConfigDir $acct.ConfigDir -ExpectedUser $acct.User -AccountName $acct.Name)) {
            $allOk = $false
        }
    }
    Write-Host ''
    if ($allOk) {
        Write-OK 'All accounts verified.'
        exit 0
    } else {
        Write-Fail 'One or more accounts failed verification. Run without -Verify to fix.'
        exit 1
    }
}

# Step 1: Create directories
Write-Step 'Creating isolated config directories'
foreach ($acct in $accounts) {
    New-ConfigDir -Path $acct.ConfigDir
}

# Step 2: Authenticate
if ($SkipLogin) {
    Write-Step 'Skipping login (SkipLogin flag set)'
} else {
    Write-Step 'Authenticating accounts (interactive — browser will open)'
    foreach ($acct in $accounts) {
        Write-Host ''
        Write-Host "  ── $($acct.Name) ──" -ForegroundColor Yellow
        Invoke-GhLogin -ConfigDir $acct.ConfigDir -HostName $acct.Host -AccountName $acct.User
    }
}

# Step 3: Verify
Write-Step 'Verifying all accounts'
$allOk = $true
foreach ($acct in $accounts) {
    if (-not (Test-GhAuth -ConfigDir $acct.ConfigDir -ExpectedUser $acct.User -AccountName $acct.Name)) {
        $allOk = $false
    }
}

# Summary
Write-Host ''
Write-Host '──────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
if ($allOk) {
    Write-OK 'Setup complete. Both accounts are authenticated.'
} else {
    Write-Warn 'Setup finished with warnings. Check output above.'
    exit 1
}

Write-Host ''
Write-Host '  Usage in scripts:' -ForegroundColor Gray
Write-Host '    $env:GH_CONFIG_DIR = "$HOME\.config\gh-emu"    # EMU account' -ForegroundColor DarkGray
Write-Host '    $env:GH_CONFIG_DIR = "$HOME\.config\gh-public" # personal account' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  Shell functions (add to $PROFILE):' -ForegroundColor Gray
Write-Host '    function gh-emu { $env:GH_CONFIG_DIR = "$HOME\.config\gh-emu"; gh @args }' -ForegroundColor DarkGray
Write-Host '    function gh-pub { $env:GH_CONFIG_DIR = "$HOME\.config\gh-public"; gh @args }' -ForegroundColor DarkGray
Write-Host ''
