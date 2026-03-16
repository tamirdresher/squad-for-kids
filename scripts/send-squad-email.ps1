#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Send an email from the Squad account (td-squad-ai-team@outlook.com) via SMTP.

.DESCRIPTION
    Sends emails directly via Outlook.com SMTP (port 587 STARTTLS) without requiring
    Outlook COM automation or browser interaction. Credentials are retrieved securely
    from Windows Credential Manager.

    Includes exponential-backoff retry logic for transient SMTP failures.

.PARAMETER To
    Recipient email address(es). Can be a single string or array of strings.

.PARAMETER Subject
    Email subject line.

.PARAMETER Body
    Email message body. Plain text.

.PARAMETER Attachments
    Optional array of file paths to attach to the email.

.PARAMETER Cc
    Optional CC recipient(s).

.PARAMETER Bcc
    Optional BCC recipient(s).

.PARAMETER BodyAsHtml
    If set, body will be sent as HTML instead of plain text.

.PARAMETER MaxRetries
    Maximum number of send attempts (default 3). Set to 1 to disable retry.

.PARAMETER RetryDelaySeconds
    Base delay in seconds for exponential backoff (default 2).
    Actual delays: attempt 1 = 2s, attempt 2 = 8s, attempt 3 = 32s (base^(2*attempt-1)).

.EXAMPLE
    .\send-squad-email.ps1 -To "user@example.com" -Subject "Test" -Body "Hello from Squad"

.EXAMPLE
    .\send-squad-email.ps1 `
        -To @("user1@example.com", "user2@example.com") `
        -Subject "Report" `
        -Body "Attached is your report." `
        -Attachments @("C:\report.pdf", "C:\data.xlsx")

.EXAMPLE
    .\send-squad-email.ps1 `
        -To "manager@example.com" `
        -Subject "Status Update" `
        -Body "All systems operational." `
        -Cc "team@example.com"

.NOTES
    - Credentials must be stored in Windows Credential Manager: squad-email-outlook
    - Requires PowerShell 5.1+
    - SMTP server: smtp-mail.outlook.com:587 (STARTTLS)
    - Exit codes: 0 = success, 1 = permanent failure, 2 = temp failure after retries

.LINK
    C:\temp\tamresearch1\.squad\skills\squad-email\SKILL.md
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, HelpMessage = "Recipient email address or array of addresses")]
    [ValidateNotNullOrEmpty()]
    [string[]]$To,

    [Parameter(Mandatory, HelpMessage = "Email subject line")]
    [ValidateNotNullOrEmpty()]
    [string]$Subject,

    [Parameter(Mandatory, HelpMessage = "Email body text")]
    [ValidateNotNullOrEmpty()]
    [string]$Body,

    [Parameter(HelpMessage = "File path(s) to attach")]
    [string[]]$Attachments,

    [Parameter(HelpMessage = "CC recipient(s)")]
    [string[]]$Cc,

    [Parameter(HelpMessage = "BCC recipient(s)")]
    [string[]]$Bcc,

    [Parameter(HelpMessage = "Send body as HTML")]
    [switch]$BodyAsHtml,

    [Parameter(HelpMessage = "SMTP server timeout in milliseconds")]
    [int]$TimeoutMs = 30000,

    [Parameter(HelpMessage = "Maximum number of send attempts (default 3)")]
    [ValidateRange(1, 10)]
    [int]$MaxRetries = 3,

    [Parameter(HelpMessage = "Base delay in seconds for exponential backoff (default 2)")]
    [ValidateRange(1, 60)]
    [int]$RetryDelaySeconds = 2
)

# Configuration
$smtpServer = "smtp-mail.outlook.com"
$smtpPort = 587
$fromAddress = "td-squad-ai-team@outlook.com"
$credentialTarget = "squad-email-outlook"

# ============================================================================
# FUNCTION: Get-CredentialManagerPassword
# ============================================================================
# Retrieves password from Windows Credential Manager or environment variable
function Get-CredentialManagerPassword {
    param(
        [Parameter(Mandatory)]
        [string]$Target,
        
        [Parameter(Mandatory)]
        [string]$Username
    )

    # Try environment variable first (for CI/CD pipelines)
    $envVar = "SQUAD_EMAIL_PASSWORD"
    if (Test-Path env:$envVar) {
        Write-Verbose "Retrieved password from environment variable: $envVar"
        return [Environment]::GetEnvironmentVariable($envVar)
    }

    # Try Windows Credential Manager via P/Invoke
    $code = @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public class CredentialManager
{
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool CredRead(
        [MarshalAs(UnmanagedType.LPStr)] string target,
        uint type,
        int flags,
        out IntPtr CredentialPtr);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern void CredFree(IntPtr cred);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL
    {
        public UInt32 Flags;
        public UInt32 Type;
        public IntPtr TargetName;
        public IntPtr Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize;
        public IntPtr CredentialBlob;
        public UInt32 Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        public IntPtr TargetAlias;
        public IntPtr UserName;
    }

    public static string GetPassword(string targetName)
    {
        IntPtr credPtr = IntPtr.Zero;
        try
        {
            if (CredRead(targetName, 1, 0, out credPtr))
            {
                CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
                if (cred.CredentialBlobSize > 0)
                {
                    byte[] buffer = new byte[cred.CredentialBlobSize];
                    Marshal.Copy(cred.CredentialBlob, buffer, 0, (int)cred.CredentialBlobSize);
                    return Encoding.Unicode.GetString(buffer);
                }
            }
            return null;
        }
        finally
        {
            if (credPtr != IntPtr.Zero)
                CredFree(credPtr);
        }
    }
}
'@

    try {
        Add-Type -TypeDefinition $code -Language CSharp -ErrorAction Stop
    }
    catch {
        # Type already loaded, suppress error
    }

    try {
        $password = [CredentialManager]::GetPassword($Target)
        if ($password) {
            Write-Verbose "Retrieved password from Windows Credential Manager: $Target"
            return $password
        }
    }
    catch {
        Write-Verbose "Credential Manager retrieval failed: $_"
    }

    return $null
}

# ============================================================================
# FUNCTION: Test-FileExists
# ============================================================================
function Test-FileExists {
    param([string]$Path)
    if ($Path -and -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Attachment file not found: $Path"
    }
}

# ============================================================================
# FUNCTION: Test-SmtpTransientError
# ============================================================================
# Returns $true if the error message indicates a transient SMTP failure that
# is worth retrying (4xx codes), $false for permanent failures (5xx) or
# unknown errors (which we still retry as a safety net).
function Test-SmtpTransientError {
    param([string]$ErrorMessage)

    # SMTP 4xx codes are transient — server is temporarily unable to process
    # 421 = service not available, 450 = mailbox busy, 451 = local error, 452 = insufficient storage
    if ($ErrorMessage -match '\b(421|450|451|452)\b') { return $true }

    # SMTP 5xx codes are permanent — do not retry
    # 550 = mailbox not found, 553 = invalid address, 554 = transaction failed
    if ($ErrorMessage -match '\b(5[0-5]\d)\b') { return $false }

    # Connection/timeout errors are transient
    if ($ErrorMessage -match '(timed?\s*out|connection\s*(refused|reset|closed)|network|socket)') {
        return $true
    }

    # Unknown errors: retry by default (conservative approach)
    return $true
}

# ============================================================================
# FUNCTION: Test-SmtpPermanentError
# ============================================================================
# Returns $true only when the error clearly indicates a permanent failure.
function Test-SmtpPermanentError {
    param([string]$ErrorMessage)

    if ($ErrorMessage -match '\b(550|553|554|521|523)\b') { return $true }
    if ($ErrorMessage -match '(authentication\s+failed|auth.*required|invalid.*credential)') {
        return $true
    }
    return $false
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

try {
    Write-Verbose "Initializing email send from $fromAddress"

    # Validate attachments
    if ($Attachments) {
        Write-Verbose "Validating $($Attachments.Count) attachment(s)"
        foreach ($attachment in $Attachments) {
            Test-FileExists -Path $attachment
        }
    }

    # Retrieve password from Credential Manager or environment
    Write-Verbose "Retrieving credentials for: $fromAddress"
    $password = Get-CredentialManagerPassword -Target $credentialTarget -Username $fromAddress

    if (-not $password) {
        $errorMsg = @"
Failed to retrieve password for Squad email account.

Troubleshooting:

1. Set password via environment variable:
   `$env:SQUAD_EMAIL_PASSWORD = 'your-outlook-password-or-app-password'
   
   Then run this script again.

2. Store password in Windows Credential Manager:
   cmdkey /generic:squad-email-outlook /user:td-squad-ai-team@outlook.com /pass:YOUR_PASSWORD

3. For Outlook.com, use an App Password (if 2FA enabled):
   - Go to https://account.microsoft.com/security
   - Click "App passwords"
   - Create new app password for "Mail" / "Windows"
   - Use that 16-character password in the cmdkey command above

4. Verify credential exists:
   cmdkey /list:squad-email-outlook

For more info, see: C:\temp\tamresearch1\.squad\skills\squad-email\SKILL.md
"@
        throw $errorMsg
    }

    # Create credential object
    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    $credential = New-Object PSCredential($fromAddress, $securePassword)

    # Build Send-MailMessage parameters
    $mailParams = @{
        From       = $fromAddress
        To         = $To
        Subject    = $Subject
        Body       = $Body
        SmtpServer = $smtpServer
        Port       = $smtpPort
        UseSsl     = $true
        Credential = $credential
    }

    if ($Cc) {
        $mailParams['Cc'] = $Cc
    }

    if ($Bcc) {
        $mailParams['Bcc'] = $Bcc
    }

    if ($Attachments) {
        $mailParams['Attachments'] = $Attachments
    }

    if ($BodyAsHtml) {
        $mailParams['BodyAsHtml'] = $true
    }

    # --- Retry loop with exponential backoff ---
    # Delays grow as base^(2*attempt-1): e.g. base=2 → 2s, 8s, 32s
    $lastError = $null
    $sent = $false

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Verbose "Sending email to: $($To -join ', ') (attempt $attempt/$MaxRetries)"
            Send-MailMessage @mailParams -ErrorAction Stop
            $sent = $true
            break
        }
        catch {
            $lastError = $_
            $errMsg = $_.Exception.Message

            # Permanent SMTP error — stop immediately, retrying won't help
            if (Test-SmtpPermanentError -ErrorMessage $errMsg) {
                Write-Host "✗ Permanent SMTP error (attempt $attempt): $errMsg" -ForegroundColor Red
                exit 1
            }

            # Transient or unknown error — retry if attempts remain
            if ($attempt -lt $MaxRetries) {
                $delay = [math]::Pow($RetryDelaySeconds, (2 * $attempt - 1))
                $delay = [math]::Min($delay, 120) # cap at 2 minutes
                Write-Host "⚠ Transient error (attempt $attempt/$MaxRetries): $errMsg" -ForegroundColor Yellow
                Write-Host "  Retrying in $delay seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $delay
            }
        }
    }

    if ($sent) {
        Write-Host "✓ Email sent successfully from $fromAddress" -ForegroundColor Green
        Write-Host "  To: $($To -join ', ')"
        Write-Host "  Subject: $Subject"
        exit 0
    }
    else {
        Write-Host "✗ Failed to send email after $MaxRetries attempt(s): $($lastError.Exception.Message)" -ForegroundColor Red
        # Exit 2 = temporary failure exhausted retries (distinct from permanent=1)
        exit 2
    }

}
catch {
    Write-Host "✗ Error sending email: $_" -ForegroundColor Red
    exit 1
}
