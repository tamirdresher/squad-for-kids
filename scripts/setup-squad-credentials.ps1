#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup credentials for Squad email SMTP sending.

.DESCRIPTION
    Stores the Squad email app password in Windows Credential Manager
    for use by send-squad-email.ps1 script.

.EXAMPLE
    .\setup-squad-credentials.ps1
    Then enter the app password when prompted.

.NOTES
    - Requires Windows Credential Manager
    - App password must be obtained from https://account.microsoft.com/security
    - For Outlook.com with 2FA enabled: Generate "Mail" / "Windows" app password
#>

[CmdletBinding()]
param()

$credentialTarget = "squad-email-outlook"
$userName = "td-squad-ai-team@outlook.com"

Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Squad Email Credential Setup" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check if credential already exists
$existing = cmdkey /list:$credentialTarget 2>$null
if ($existing) {
    Write-Host "✓ Credential already exists for: $credentialTarget" -ForegroundColor Green
    $response = Read-Host "Do you want to replace it? (yes/no)"
    if ($response -ne "yes") {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "Enter your Outlook.com app password:" -ForegroundColor Yellow
Write-Host "(If 2FA enabled, use: https://account.microsoft.com/security → App passwords)" -ForegroundColor Gray
Write-Host ""

$password = Read-Host "App password" -AsSecureString
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUni($password)
)

if ([string]::IsNullOrWhiteSpace($plainPassword)) {
    Write-Host "✗ Password cannot be empty." -ForegroundColor Red
    exit 1
}

try {
    # Delete existing credential if present
    cmdkey /delete:$credentialTarget 2>$null | Out-Null
    
    # Store new credential
    & cmdkey /generic:$credentialTarget /user:$userName /pass:$plainPassword
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ Credential stored successfully!" -ForegroundColor Green
        Write-Host "  Target: $credentialTarget" -ForegroundColor Green
        Write-Host "  User: $userName" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now use send-squad-email.ps1 to send emails." -ForegroundColor Green
    }
    else {
        throw "cmdkey command failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Host "✗ Error storing credential: $_" -ForegroundColor Red
    exit 1
}
finally {
    # Clear the plain text password from memory
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
        [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemAuto($password)
    )
    Remove-Variable -Name plainPassword -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
