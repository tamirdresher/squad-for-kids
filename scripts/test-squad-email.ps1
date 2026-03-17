#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test the Squad email setup.

.DESCRIPTION
    Verifies that the Squad email credential is properly configured
    and can send test emails.

.PARAMETER To
    Email address to send test email to (default: sender's email)

.EXAMPLE
    .\test-squad-email.ps1
    .\test-squad-email.ps1 -To "recipient@example.com"

.NOTES
    - Requires send-squad-email.ps1 in the same scripts directory
    - Credential must be set up via setup-squad-credentials.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$To
)

$credentialTarget = "squad-email-outlook"
$userName = "td-squad-ai-team@outlook.com"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sendEmailScript = Join-Path $scriptDir "send-squad-email.ps1"

if (-not (Test-Path $sendEmailScript)) {
    Write-Host "✗ Error: send-squad-email.ps1 not found in $scriptDir" -ForegroundColor Red
    exit 1
}

# Verify credential exists
Write-Host "Checking credential setup..." -ForegroundColor Yellow
$credCheck = cmdkey /list:$credentialTarget 2>&1 | Select-String "Target:" | Measure-Object | Select-Object -ExpandProperty Count
if ($credCheck -eq 0) {
    Write-Host "✗ Credential not found: $credentialTarget" -ForegroundColor Red
    Write-Host "Run setup-squad-credentials.ps1 first." -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Credential found" -ForegroundColor Green

# Use sender's email if not specified
if (-not $To) {
    $To = $userName
    Write-Host "Sending test email to: $To (sender's own email)" -ForegroundColor Cyan
}
else {
    Write-Host "Sending test email to: $To" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Testing email send..." -ForegroundColor Yellow

try {
    & $sendEmailScript `
        -To $To `
        -Subject "Squad Email Test - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" `
        -Body "This is a test email from the Squad email system.`n`nIf you received this, the email setup is working correctly.`n`nSent from: $userName`nTimestamp: $(Get-Date -Format 'u')" `
        -Verbose
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ Test email sent successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "The Squad email system is ready to use." -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "✗ Email send failed. Check the error above." -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "✗ Error running test: $_" -ForegroundColor Red
    exit 1
}
