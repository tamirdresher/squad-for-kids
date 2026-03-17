<#
.SYNOPSIS
    Installs Windows Terminal profiles for GitHub EMU and Public accounts.
.DESCRIPTION
    Adds two profiles to Windows Terminal settings.json that pre-set GH_CONFIG_DIR
    so each shell session targets the correct GitHub CLI credential store.
    The script is idempotent — existing profiles are skipped.
#>
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Well-known Windows Terminal settings path
$settingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'

if (-not (Test-Path $settingsPath)) {
    Write-Error "Windows Terminal settings.json not found at: $settingsPath`nIs Windows Terminal (Store edition) installed?"
    return
}

# Stable GUIDs for idempotency
$emuGuid  = '{a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d}'
$pubGuid  = '{d5c4b3a2-1f0e-4d9c-8b7a-6e5f4d3c2b1a}'

$emuProfile = [ordered]@{
    guid             = $emuGuid
    name             = 'GitHub EMU (Work)'
    commandline      = "pwsh -NoExit -Command `"`$env:GH_CONFIG_DIR = '$HOME\.config\gh-emu'; Write-Host '🏢 GitHub EMU account active' -ForegroundColor Yellow; gh auth status`""
    tabTitle         = 'GH EMU'
    tabColor         = '#FFB900'
    icon             = 'ms-appx:///ProfileIcons/pwsh.png'
    hidden           = $false
}

$pubProfile = [ordered]@{
    guid             = $pubGuid
    name             = 'GitHub Public (Personal)'
    commandline      = "pwsh -NoExit -Command `"`$env:GH_CONFIG_DIR = '$HOME\.config\gh-public'; Write-Host '🌐 GitHub Public account active' -ForegroundColor Green; gh auth status`""
    tabTitle         = 'GH Public'
    tabColor         = '#16C60C'
    icon             = 'ms-appx:///ProfileIcons/pwsh.png'
    hidden           = $false
}

# Read current settings (preserve comments by using raw text for backup, but parse as JSON)
$raw = Get-Content $settingsPath -Raw
$settings = $raw | ConvertFrom-Json

# Ensure profiles.list exists
if (-not $settings.profiles.list) {
    Write-Error "Unexpected settings.json structure — profiles.list not found."
    return
}

$existingGuids = $settings.profiles.list | ForEach-Object { $_.guid }
$added = @()

if ($existingGuids -contains $emuGuid) {
    Write-Host "✔ GitHub EMU profile already exists — skipping." -ForegroundColor DarkYellow
} else {
    $settings.profiles.list += [PSCustomObject]$emuProfile
    $added += 'GitHub EMU (Work)'
}

if ($existingGuids -contains $pubGuid) {
    Write-Host "✔ GitHub Public profile already exists — skipping." -ForegroundColor DarkGreen
} else {
    $settings.profiles.list += [PSCustomObject]$pubProfile
    $added += 'GitHub Public (Personal)'
}

if ($added.Count -eq 0) {
    Write-Host "`nNo changes needed — both profiles already installed." -ForegroundColor Cyan
    return
}

if ($DryRun) {
    Write-Host "`n[DryRun] Would add: $($added -join ', ')" -ForegroundColor Magenta
    $settings | ConvertTo-Json -Depth 20 | Write-Host
    return
}

# Back up before writing
$backupPath = "$settingsPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $settingsPath $backupPath
Write-Host "Backup saved to $backupPath" -ForegroundColor DarkGray

$settings | ConvertTo-Json -Depth 20 | Set-Content $settingsPath -Encoding UTF8

Write-Host "`n✅ Installed profiles: $($added -join ', ')" -ForegroundColor Green
Write-Host "Restart Windows Terminal (or open a new tab) to see the new profiles."
