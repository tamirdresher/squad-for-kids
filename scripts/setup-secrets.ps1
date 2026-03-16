#Requires -Version 5.1
<#
.SYNOPSIS
    Loads squad secrets into the current session from secure sources.
.DESCRIPTION
    Priority order:
      1. Windows Credential Manager (most secure, preferred)
      2. $env:USERPROFILE\.squad\.env file (machine-local, not in repo)
      3. Existing environment variables (already set by user)

    Never reads from or writes to any file inside the git repository.
    Run this early in your session — devbox-startup.ps1 calls it automatically.
.EXAMPLE
    . .\scripts\setup-secrets.ps1
    # Dot-source to set variables in current scope
.NOTES
    Requires CredentialManager module for Credential Manager access.
    Install with: Install-Module -Name CredentialManager -Scope CurrentUser
#>

param(
    [switch]$Quiet,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'SilentlyContinue'

# --- Configuration: known secrets and their Credential Manager targets ---
$SecretDefs = @(
    @{
        EnvVar   = 'GOOGLE_API_KEY'
        CredTarget = 'google-gemini-api-key'
        Description = 'Google Gemini API Key'
        Required = $true
    },
    @{
        EnvVar   = 'TEAMS_WEBHOOK_URL'
        CredTarget = $null  # file-based, see special handling
        FilePath = "$env:USERPROFILE\.squad\teams-webhook.url"
        Description = 'Teams Webhook URL'
        Required = $true
    },
    @{
        EnvVar   = 'TELEGRAM_BOT_TOKEN'
        CredTarget = 'telegram-bot-token'
        Description = 'Telegram Bot Token'
        Required = $false
    },
    @{
        EnvVar   = 'SQUAD_EMAIL_PASSWORD'
        CredTarget = 'squad-email-outlook'
        Description = 'Squad Email Password'
        Required = $false
    }
)

$envFilePath = "$env:USERPROFILE\.squad\.env"

# --- Helper: read credential from Windows Credential Manager ---
function Get-CredentialValue {
    param([string]$Target)
    try {
        if (Get-Module -ListAvailable -Name CredentialManager) {
            Import-Module CredentialManager -ErrorAction Stop
            $cred = Get-StoredCredential -Target $Target -ErrorAction Stop
            if ($cred) {
                return $cred.GetNetworkCredential().Password
            }
        }
    } catch { }
    return $null
}

# --- Helper: parse .env file (KEY=VALUE, ignore comments/blanks) ---
function Get-EnvFileValues {
    param([string]$Path)
    $values = @{}
    if (Test-Path $Path) {
        Get-Content $Path | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith('#') -and $line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
                $values[$Matches[1]] = $Matches[2]
            }
        }
    }
    return $values
}

# --- Main ---
if (-not $Quiet) {
    Write-Host "`n=== Squad Secrets Setup ===" -ForegroundColor Cyan
    Write-Host "Sources: Credential Manager > $envFilePath > existing env vars`n"
}

$envFileValues = Get-EnvFileValues -Path $envFilePath
$results = @()
$allPresent = $true

foreach ($secret in $SecretDefs) {
    $name = $secret.EnvVar
    $value = $null
    $source = $null

    # 1. Try Credential Manager
    if ($secret.CredTarget) {
        $value = Get-CredentialValue -Target $secret.CredTarget
        if ($value) { $source = 'Credential Manager' }
    }

    # 2. Try dedicated file (e.g., webhook URL)
    if (-not $value -and $secret.FilePath -and (Test-Path $secret.FilePath)) {
        $content = Get-Content $secret.FilePath -Raw
        $value = if ($content) { $content.Trim() } else { $null }
        if ($value) { $source = "File ($($secret.FilePath))" }
    }

    # 3. Try .env file
    if (-not $value -and $envFileValues.ContainsKey($name)) {
        $value = $envFileValues[$name]
        if ($value) { $source = ".env file" }
    }

    # 4. Already in environment
    if (-not $value) {
        $existing = [Environment]::GetEnvironmentVariable($name)
        if ($existing) {
            $value = $existing
            $source = 'Existing env var'
        }
    }

    # Set environment variable if we found a value
    if ($value -and -not $ValidateOnly) {
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }

    $status = if ($value) { 'OK' } elseif ($secret.Required) { 'MISSING' } else { 'OPTIONAL (not set)' }
    if (-not $value -and $secret.Required) { $allPresent = $false }

    $results += [PSCustomObject]@{
        Secret      = $secret.Description
        EnvVar      = $name
        Status      = $status
        Source      = if ($value) { $source } else { '-' }
        Required    = $secret.Required
    }
}

# --- Report ---
if (-not $Quiet) {
    foreach ($r in $results) {
        $color = switch ($r.Status) {
            'OK'                { 'Green' }
            'MISSING'           { 'Red' }
            'OPTIONAL (not set)' { 'Yellow' }
        }
        $icon = switch ($r.Status) {
            'OK'                { '[OK]' }
            'MISSING'           { '[!!]' }
            'OPTIONAL (not set)' { '[--]' }
        }
        Write-Host "  $icon $($r.Secret) ($($r.EnvVar)) — $($r.Status)" -ForegroundColor $color
        if ($r.Source -ne '-') {
            Write-Host "       Source: $($r.Source)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    if ($allPresent) {
        Write-Host "All required secrets loaded." -ForegroundColor Green
    } else {
        Write-Host "WARNING: Some required secrets are missing!" -ForegroundColor Red
        Write-Host "See .env.example for setup instructions." -ForegroundColor Yellow
        Write-Host "Store secrets in Credential Manager or $envFilePath" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Return success/failure for scripting
return $allPresent
