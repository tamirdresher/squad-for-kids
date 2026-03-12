<#
.SYNOPSIS
    Sets up SSH server on DevBox for Squad persistent access.

.DESCRIPTION
    Configures OpenSSH Server on Windows DevBox:
    - Installs OpenSSH Server capability
    - Configures key-based authentication (disables password auth)
    - Sets up authorized_keys with Squad's public key
    - Configures Windows Firewall rules
    - Tests the setup
    
    Run this script ON the DevBox with Administrator privileges.

.PARAMETER PublicKey
    The SSH public key to authorize (Squad's public key).
    If not provided, the script will prompt for it.

.EXAMPLE
    .\devbox-ssh-setup.ps1 -PublicKey "ssh-ed25519 AAAAC3Nza..."
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$PublicKey
)

$ErrorActionPreference = "Stop"

# Check for Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== DevBox SSH Server Setup ===" -ForegroundColor Cyan
Write-Host "This script will configure SSH server for Squad persistent access`n" -ForegroundColor Gray

# Step 1: Check if OpenSSH Server is installed
Write-Host "[1/7] Checking OpenSSH Server installation..." -ForegroundColor Yellow
$opensshServer = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

if ($opensshServer.State -eq "Installed") {
    Write-Host "  ✓ OpenSSH Server already installed" -ForegroundColor Green
} else {
    Write-Host "  → Installing OpenSSH Server..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Write-Host "  ✓ OpenSSH Server installed" -ForegroundColor Green
}

# Step 2: Start and enable SSHD service
Write-Host "`n[2/7] Configuring SSHD service..." -ForegroundColor Yellow
try {
    Start-Service sshd -ErrorAction SilentlyContinue
    Set-Service -Name sshd -StartupType 'Automatic'
    Write-Host "  ✓ SSHD service started and set to automatic" -ForegroundColor Green
} catch {
    Write-Host "  ! Warning: Could not start SSHD service: $_" -ForegroundColor Yellow
}

# Step 3: Configure firewall rules
Write-Host "`n[3/7] Configuring Windows Firewall..." -ForegroundColor Yellow
$firewallRule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
if ($firewallRule) {
    Write-Host "  ✓ Firewall rule already exists" -ForegroundColor Green
} else {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    Write-Host "  ✓ Firewall rule created (port 22)" -ForegroundColor Green
}

# Step 4: Configure SSH for key-only authentication
Write-Host "`n[4/7] Configuring SSH daemon..." -ForegroundColor Yellow
$sshdConfigPath = "$env:ProgramData\ssh\sshd_config"

if (Test-Path $sshdConfigPath) {
    $sshdConfig = Get-Content $sshdConfigPath
    
    # Backup original config
    $backupPath = "$sshdConfigPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $sshdConfigPath $backupPath
    Write-Host "  → Config backed up to: $backupPath" -ForegroundColor Gray
    
    # Update config settings
    $configUpdates = @{
        'PubkeyAuthentication' = 'yes'
        'PasswordAuthentication' = 'no'
        'PermitEmptyPasswords' = 'no'
    }
    
    $modified = $false
    foreach ($key in $configUpdates.Keys) {
        $value = $configUpdates[$key]
        $pattern = "^#?\s*$key\s+"
        
        if ($sshdConfig -match $pattern) {
            $sshdConfig = $sshdConfig -replace $pattern, "$key $value"
            $modified = $true
        } else {
            $sshdConfig += "`n$key $value"
            $modified = $true
        }
    }
    
    if ($modified) {
        $sshdConfig | Set-Content $sshdConfigPath
        Write-Host "  ✓ SSH config updated (key-only auth enabled)" -ForegroundColor Green
    } else {
        Write-Host "  ✓ SSH config already correct" -ForegroundColor Green
    }
} else {
    Write-Host "  ! Warning: sshd_config not found at $sshdConfigPath" -ForegroundColor Yellow
}

# Step 5: Set up authorized_keys
Write-Host "`n[5/7] Setting up authorized_keys..." -ForegroundColor Yellow

if (-not $PublicKey) {
    Write-Host "  → Enter Squad's SSH public key (starts with 'ssh-ed25519' or 'ssh-rsa'):" -ForegroundColor Cyan
    $PublicKey = Read-Host "     "
    
    if ([string]::IsNullOrWhiteSpace($PublicKey)) {
        Write-Host "  ! ERROR: Public key is required" -ForegroundColor Red
        exit 1
    }
}

$sshDir = "$env:USERPROFILE\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir | Out-Null
    Write-Host "  → Created .ssh directory" -ForegroundColor Gray
}

$authorizedKeysPath = "$sshDir\authorized_keys"
$keyExists = $false

if (Test-Path $authorizedKeysPath) {
    $existingKeys = Get-Content $authorizedKeysPath
    if ($existingKeys -contains $PublicKey) {
        $keyExists = $true
        Write-Host "  ✓ Public key already in authorized_keys" -ForegroundColor Green
    }
}

if (-not $keyExists) {
    Add-Content -Path $authorizedKeysPath -Value $PublicKey
    Write-Host "  ✓ Public key added to authorized_keys" -ForegroundColor Green
}

# Set proper permissions on authorized_keys (remove inheritance, set owner permissions only)
$acl = Get-Acl $authorizedKeysPath
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
    "FullControl",
    "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl $authorizedKeysPath $acl
Write-Host "  ✓ Permissions set on authorized_keys" -ForegroundColor Gray

# Step 6: Restart SSHD to apply changes
Write-Host "`n[6/7] Restarting SSHD service..." -ForegroundColor Yellow
try {
    Restart-Service sshd
    Write-Host "  ✓ SSHD restarted successfully" -ForegroundColor Green
} catch {
    Write-Host "  ! Warning: Could not restart SSHD: $_" -ForegroundColor Yellow
}

# Step 7: Test SSH setup
Write-Host "`n[7/7] Testing SSH server..." -ForegroundColor Yellow
$sshdStatus = Get-Service sshd
if ($sshdStatus.Status -eq "Running") {
    Write-Host "  ✓ SSHD is running" -ForegroundColor Green
} else {
    Write-Host "  ! Warning: SSHD is not running (Status: $($sshdStatus.Status))" -ForegroundColor Yellow
}

# Get DevBox IP addresses
$ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" } | Select-Object -ExpandProperty IPAddress

Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "`nSSH server is configured and running." -ForegroundColor White
Write-Host "`nConnection information:" -ForegroundColor Cyan
Write-Host "  User:  $env:USERNAME" -ForegroundColor White
Write-Host "  IP(s): $($ipAddresses -join ', ')" -ForegroundColor White
Write-Host "  Port:  22" -ForegroundColor White
Write-Host "`nTest connection from Squad machine:" -ForegroundColor Cyan
Write-Host "  ssh -i ~/.ssh/squad-devbox-key $env:USERNAME@<devbox-ip>" -ForegroundColor Yellow
Write-Host "`nPowerShell remoting:" -ForegroundColor Cyan
Write-Host "  Enter-PSSession -HostName <devbox-ip> -UserName $env:USERNAME -SSHTransport" -ForegroundColor Yellow
Write-Host ""
