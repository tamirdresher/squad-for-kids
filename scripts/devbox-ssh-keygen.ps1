<#
.SYNOPSIS
    Generates SSH key pair for Squad DevBox access.

.DESCRIPTION
    Creates an ed25519 SSH key pair for Squad's DevBox connection:
    - Generates key at ~/.ssh/squad-devbox-key
    - Won't overwrite existing keys (safe to run multiple times)
    - Displays public key to copy to DevBox
    - Creates/updates ~/.ssh/config with DevBox host entry

    Run this script on the LOCAL machine where Squad runs.

.PARAMETER DevBoxHost
    The hostname or IP address of the DevBox.
    If not provided, the script will prompt for it.

.PARAMETER DevBoxUser
    The username to use for SSH connection.
    If not provided, the script will prompt for it.

.EXAMPLE
    .\devbox-ssh-keygen.ps1 -DevBoxHost "10.0.0.5" -DevBoxUser "azureuser"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$DevBoxHost,
    
    [Parameter(Mandatory=$false)]
    [string]$DevBoxUser
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Squad DevBox SSH Key Generator ===" -ForegroundColor Cyan
Write-Host "This script will create SSH keys for Squad DevBox access`n" -ForegroundColor Gray

# Step 1: Check for ssh-keygen
Write-Host "[1/4] Checking for ssh-keygen..." -ForegroundColor Yellow
$sshKeygen = Get-Command ssh-keygen -ErrorAction SilentlyContinue
if (-not $sshKeygen) {
    Write-Host "  ! ERROR: ssh-keygen not found. Please install OpenSSH Client." -ForegroundColor Red
    Write-Host "    Install with: Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✓ ssh-keygen found: $($sshKeygen.Source)" -ForegroundColor Green

# Step 2: Generate SSH key pair
Write-Host "`n[2/4] Generating SSH key pair..." -ForegroundColor Yellow

$sshDir = "$env:USERPROFILE\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir | Out-Null
    Write-Host "  → Created .ssh directory" -ForegroundColor Gray
}

$keyPath = "$sshDir\squad-devbox-key"

if (Test-Path $keyPath) {
    Write-Host "  ℹ Key already exists at: $keyPath" -ForegroundColor Cyan
    $overwrite = Read-Host "  Overwrite existing key? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "  → Using existing key" -ForegroundColor Gray
    } else {
        Remove-Item $keyPath -Force
        Remove-Item "$keyPath.pub" -Force -ErrorAction SilentlyContinue
        & ssh-keygen -t ed25519 -f $keyPath -N '""' -C "squad-devbox-access"
        Write-Host "  ✓ New key pair generated" -ForegroundColor Green
    }
} else {
    & ssh-keygen -t ed25519 -f $keyPath -N '""' -C "squad-devbox-access"
    Write-Host "  ✓ Key pair generated" -ForegroundColor Green
}

# Step 3: Display public key
Write-Host "`n[3/4] Public key:" -ForegroundColor Yellow
$publicKey = Get-Content "$keyPath.pub"
Write-Host "`n  $publicKey`n" -ForegroundColor Green
Write-Host "  Copy this public key and run devbox-ssh-setup.ps1 on the DevBox with:" -ForegroundColor Cyan
Write-Host "  .\devbox-ssh-setup.ps1 -PublicKey `"$publicKey`"" -ForegroundColor Yellow

# Step 4: Update SSH config
Write-Host "`n[4/4] Updating SSH config..." -ForegroundColor Yellow

if (-not $DevBoxHost) {
    Write-Host "  → Enter DevBox hostname or IP address:" -ForegroundColor Cyan
    $DevBoxHost = Read-Host "     "
    if ([string]::IsNullOrWhiteSpace($DevBoxHost)) {
        Write-Host "  ! Skipping SSH config update (no hostname provided)" -ForegroundColor Yellow
        Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
        exit 0
    }
}

if (-not $DevBoxUser) {
    Write-Host "  → Enter DevBox username:" -ForegroundColor Cyan
    $DevBoxUser = Read-Host "     "
    if ([string]::IsNullOrWhiteSpace($DevBoxUser)) {
        Write-Host "  ! Skipping SSH config update (no username provided)" -ForegroundColor Yellow
        Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
        exit 0
    }
}

$sshConfigPath = "$sshDir\config"
$hostEntryName = "squad-devbox"

$hostEntry = @"

# Squad DevBox
Host $hostEntryName
    HostName $DevBoxHost
    User $DevBoxUser
    IdentityFile ~/.ssh/squad-devbox-key
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
"@

$configExists = Test-Path $sshConfigPath
$entryExists = $false

if ($configExists) {
    $existingConfig = Get-Content $sshConfigPath -Raw
    if ($existingConfig -match "Host\s+$hostEntryName\s") {
        $entryExists = $true
        Write-Host "  ℹ Host entry '$hostEntryName' already exists in SSH config" -ForegroundColor Cyan
        $overwrite = Read-Host "  Update with new details? (y/N)"
        if ($overwrite -eq "y" -or $overwrite -eq "Y") {
            # Remove old entry
            $pattern = "(?m)^# Squad DevBox.*?(?=\r?\n(Host\s|\z))"
            $existingConfig = $existingConfig -replace $pattern, ""
            $existingConfig.TrimEnd() + $hostEntry | Set-Content $sshConfigPath
            Write-Host "  ✓ SSH config updated" -ForegroundColor Green
        } else {
            Write-Host "  → Keeping existing config" -ForegroundColor Gray
        }
    } else {
        Add-Content -Path $sshConfigPath -Value $hostEntry
        Write-Host "  ✓ Host entry added to SSH config" -ForegroundColor Green
    }
} else {
    $hostEntry.TrimStart() | Set-Content $sshConfigPath
    Write-Host "  ✓ SSH config created with host entry" -ForegroundColor Green
}

# Display connection instructions
Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "`nSSH key generated and configuration updated." -ForegroundColor White
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Copy the public key (shown above) to the DevBox" -ForegroundColor White
Write-Host "  2. Run devbox-ssh-setup.ps1 on the DevBox with the public key" -ForegroundColor White
Write-Host "  3. Test connection from this machine:" -ForegroundColor White
Write-Host "`n     ssh $hostEntryName" -ForegroundColor Yellow
Write-Host "`nPowerShell remoting:" -ForegroundColor Cyan
Write-Host "     Enter-PSSession -HostName $hostEntryName -SSHTransport" -ForegroundColor Yellow
Write-Host ""
