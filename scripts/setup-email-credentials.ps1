<#
.SYNOPSIS
    Stores Gmail credentials securely in Windows Credential Manager.

.DESCRIPTION
    Prompts for Gmail address and App Password, then stores them in
    Windows Credential Manager under the target "GmailAutomation".
    Credentials are never written to disk in plain text.

.EXAMPLE
    pwsh scripts/setup-email-credentials.ps1

.NOTES
    Requires: Windows with Credential Manager
    The App Password is a 16-character code from Google Account → App Passwords.
    It is NOT your regular Google password.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$TargetName = "GmailAutomation"
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "=== Gmail Credential Setup ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script stores your Gmail credentials in Windows Credential Manager."
Write-Host "You need an App Password (not your regular Google password)."
Write-Host ""
Write-Host "To generate an App Password:" -ForegroundColor Yellow
Write-Host "  1. Go to https://myaccount.google.com/apppasswords"
Write-Host "  2. Select app 'Mail', device 'Windows Computer'"
Write-Host "  3. Click Generate and copy the 16-character password"
Write-Host ""

# Prompt for email
$email = Read-Host -Prompt "Enter your Gmail address"
if ([string]::IsNullOrWhiteSpace($email)) {
    Write-Error "Email address is required."
    exit 1
}
if ($email -notmatch '@gmail\.com$' -and $email -notmatch '@googlemail\.com$') {
    Write-Warning "Address doesn't look like a Gmail address. Proceeding anyway."
}

# Prompt for App Password (masked)
$securePassword = Read-Host -Prompt "Enter your Gmail App Password" -AsSecureString
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$appPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

if ([string]::IsNullOrWhiteSpace($appPassword)) {
    Write-Error "App Password is required."
    exit 1
}

# Strip spaces from the app password (Google shows it as "xxxx xxxx xxxx xxxx")
$appPassword = $appPassword -replace '\s', ''

if ($appPassword.Length -ne 16) {
    Write-Warning "App Password is typically 16 characters. Got $($appPassword.Length) characters."
}

# Store in Windows Credential Manager using cmdkey
# Format: username = email, password = app password
$cmdkeyResult = & cmdkey /generic:$TargetName /user:$email /pass:$appPassword 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to store credentials in Credential Manager: $cmdkeyResult"
    exit 1
}

# Clear the password from memory
$appPassword = $null
[System.GC]::Collect()

Write-Host ""
Write-Host "✅ Credentials stored successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Target:   $TargetName" -ForegroundColor Gray
Write-Host "Username: $email" -ForegroundColor Gray
Write-Host "Password: ****" -ForegroundColor Gray
Write-Host ""
Write-Host "To verify, open:" -ForegroundColor Yellow
Write-Host "  Control Panel → Credential Manager → Windows Credentials"
Write-Host "  Look for '$TargetName'"
Write-Host ""
Write-Host "To test email access:" -ForegroundColor Yellow
Write-Host "  pwsh scripts/check-personal-email.ps1 -Last 5"
Write-Host ""
Write-Host "To remove these credentials later:" -ForegroundColor Yellow
Write-Host "  cmdkey /delete:$TargetName"
