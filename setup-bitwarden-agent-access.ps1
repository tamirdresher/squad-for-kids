<#
.SYNOPSIS
    Setup bitwarden/agent-access (aac) for Squad AI agents on Windows.

.DESCRIPTION
    This script:
    1. Downloads and installs the aac CLI
    2. Starts aac listen so you can pair the AI with your Bitwarden vault
    3. Saves the pairing token for use in the MCP server config

    The AI ONLY gets credentials you explicitly share.
    Your vault is never directly accessible — everything goes through
    the encrypted tunnel on YOUR device.

.NOTES
    Prerequisites:
    - Bitwarden CLI (bw) installed and available on PATH
    - Your Bitwarden vault unlocked

    This replaces setup-bitwarden.ps1 (the old shadow-collection approach).
    No organization plan required. No service accounts. No BW_SESSION tokens.
#>

param(
    [switch]$InstallOnly,
    [string]$InstallDir = "$env:LOCALAPPDATA\bitwarden-agent-access"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Bitwarden Agent Access (aac) Setup" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This replaces the old Bitwarden shadow approach." -ForegroundColor White
Write-Host "No organization plan, no session tokens, no collection setup." -ForegroundColor Green
Write-Host ""

# Step 1: Download aac if not present
$aacPath = (Get-Command aac -ErrorAction SilentlyContinue)?.Source
if (-not $aacPath) {
    Write-Host "Step 1: Installing aac CLI..." -ForegroundColor Cyan
    
    $releaseUrl = "https://github.com/bitwarden/agent-access/releases/latest/download/aac-windows-x86_64.zip"
    $zipPath = Join-Path $env:TEMP "aac-windows.zip"
    
    Write-Host "  Downloading from: $releaseUrl" -ForegroundColor Gray
    Invoke-WebRequest -Uri $releaseUrl -OutFile $zipPath
    
    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
    Expand-Archive -Path $zipPath -DestinationPath $InstallDir -Force
    Remove-Item $zipPath
    
    $aacExe = Join-Path $InstallDir "aac.exe"
    if (-not (Test-Path $aacExe)) {
        # May be nested
        $found = Get-ChildItem -Recurse -Path $InstallDir -Filter "aac.exe" | Select-Object -First 1
        if ($found) { $aacExe = $found.FullName }
    }
    
    # Add to user PATH
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath -notlike "*$InstallDir*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$userPath;$InstallDir", "User")
        $env:PATH = "$env:PATH;$InstallDir"
        Write-Host "  ✅ Added $InstallDir to user PATH" -ForegroundColor Green
    }
    
    Write-Host "  ✅ aac installed to: $aacExe" -ForegroundColor Green
} else {
    Write-Host "Step 1: aac is already installed at: $aacPath" -ForegroundColor Green
}

# Verify
$version = & aac --version 2>&1
Write-Host "  aac version: $version" -ForegroundColor Gray
Write-Host ""

if ($InstallOnly) {
    Write-Host "✅ Installation complete. Run without -InstallOnly to pair." -ForegroundColor Green
    exit 0
}

# Step 2: Instructions for pairing
Write-Host "Step 2: Pairing" -ForegroundColor Cyan
Write-Host ""
Write-Host "  aac listen will start now." -ForegroundColor Yellow
Write-Host "  It will display a PAIRING TOKEN like: ABC-DEF-GHI" -ForegroundColor Yellow
Write-Host ""
Write-Host "  COPY that token — you'll need it in the AI session." -ForegroundColor Green
Write-Host ""
Write-Host "  The AI will use: get_credential_info(domain='...', pairing_token='ABC-DEF-GHI')" -ForegroundColor Gray
Write-Host "  Sessions are cached in ~/.access-protocol/ for future use." -ForegroundColor Gray
Write-Host ""
Write-Host "  Press Ctrl+C in aac listen to stop sharing credentials." -ForegroundColor Gray
Write-Host ""
Write-Host "Starting aac listen (Ctrl+C to stop)..." -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

& aac listen
