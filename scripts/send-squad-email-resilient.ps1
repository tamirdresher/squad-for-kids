#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Resilient email wrapper with rate limiting, retry/backoff, and Gmail fallback.

.DESCRIPTION
    Wraps send-squad-email.ps1 to provide production-grade email delivery:

    1. Pre-send rate check  — warns/throttles if >30 emails sent in the last hour.
    2. Exponential backoff  — retries transient failures (SMTP 4xx, timeouts) up to
       MaxRetries times with delays of base^(2n-1) seconds (default: 2s, 8s, 32s).
    3. SMTP error parsing   — classifies errors as transient (retry) vs permanent (fail fast).
    4. Gmail SMTP fallback  — if the primary Outlook path fails permanently OR exhausts
       retries, automatically tries Gmail SMTP (smtp.gmail.com:587) using a separate
       credential from Windows Credential Manager (key: squad-email-gmail).
    5. Structured logging   — every send attempt is logged to ~/.squad/email-send-log.json
       with timestamp, provider, result, error details, and retry count.

    PRIMARY PATH: Gmail SMTP (tdsquadai@gmail.com) — Outlook consumer SMTP AUTH is
    disabled for td-squad-ai-team@outlook.com, so Gmail is attempted first by default.

.PARAMETER To
    Recipient email address(es).

.PARAMETER Subject
    Email subject line.

.PARAMETER Body
    Email body text.

.PARAMETER Attachments
    Optional file paths to attach.

.PARAMETER Cc
    Optional CC recipient(s).

.PARAMETER Bcc
    Optional BCC recipient(s).

.PARAMETER BodyAsHtml
    Send body as HTML.

.PARAMETER MaxRetries
    Maximum send attempts per provider (default 3).

.PARAMETER RetryDelaySeconds
    Base delay for exponential backoff (default 2).

.PARAMETER RateLimitPerHour
    Maximum emails per hour before throttle warning (default 30).

.PARAMETER SkipRateCheck
    Bypass the pre-send rate limit check.

.PARAMETER PreferOutlook
    Try Outlook SMTP first instead of Gmail (not recommended; Outlook consumer
    SMTP AUTH is typically disabled).

.EXAMPLE
    .\send-squad-email-resilient.ps1 -To "user@example.com" -Subject "Test" -Body "Hello"

.EXAMPLE
    .\send-squad-email-resilient.ps1 -To "user@example.com" -Subject "Report" -Body "See attached" `
        -Attachments @("C:\report.pdf") -MaxRetries 5

.NOTES
    Exit codes: 0 = success, 1 = permanent failure on all providers,
                2 = transient failure after exhausting retries on all providers
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, HelpMessage = "Recipient email address(es)")]
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

    [Parameter(HelpMessage = "Max send attempts per provider (default 3)")]
    [ValidateRange(1, 10)]
    [int]$MaxRetries = 3,

    [Parameter(HelpMessage = "Base delay in seconds for exponential backoff (default 2)")]
    [ValidateRange(1, 60)]
    [int]$RetryDelaySeconds = 2,

    [Parameter(HelpMessage = "Max emails per hour before throttle warning (default 30)")]
    [ValidateRange(1, 500)]
    [int]$RateLimitPerHour = 30,

    [Parameter(HelpMessage = "Bypass pre-send rate limit check")]
    [switch]$SkipRateCheck,

    [Parameter(HelpMessage = "Try Outlook SMTP first instead of Gmail")]
    [switch]$PreferOutlook
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$squadDir       = Join-Path $env:USERPROFILE ".squad"
$sendLogPath    = Join-Path $squadDir "email-send-log.json"

# Gmail is the primary path because Outlook consumer SMTP AUTH is disabled
$gmailConfig = @{
    SmtpServer     = "smtp.gmail.com"
    Port           = 587
    FromAddress    = "tdsquadai@gmail.com"
    CredentialKey  = "squad-email-gmail"
    ProviderName   = "Gmail"
}

$outlookConfig = @{
    SmtpServer     = "smtp-mail.outlook.com"
    Port           = 587
    FromAddress    = "td-squad-ai-team@outlook.com"
    CredentialKey  = "squad-email-outlook"
    ProviderName   = "Outlook"
}

# ============================================================================
# FUNCTION: Get-CredentialManagerPassword
# ============================================================================
function Get-CredentialManagerPassword {
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Username
    )

    # Environment variable override (CI/CD)
    $envVarMap = @{
        "squad-email-gmail"   = "SQUAD_GMAIL_PASSWORD"
        "squad-email-outlook" = "SQUAD_EMAIL_PASSWORD"
    }
    $envVar = $envVarMap[$Target]
    if ($envVar -and (Test-Path env:$envVar)) {
        Write-Verbose "Password from env var: $envVar"
        return [Environment]::GetEnvironmentVariable($envVar)
    }

    # Windows Credential Manager via P/Invoke
    $code = @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public class CredentialManagerResilient
{
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool CredRead(
        [MarshalAs(UnmanagedType.LPStr)] string target,
        uint type, int flags, out IntPtr CredentialPtr);

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
            if (credPtr != IntPtr.Zero) CredFree(credPtr);
        }
    }
}
'@

    try { Add-Type -TypeDefinition $code -Language CSharp -ErrorAction Stop } catch { }

    try {
        $password = [CredentialManagerResilient]::GetPassword($Target)
        if ($password) {
            Write-Verbose "Password from Credential Manager: $Target"
            return $password
        }
    }
    catch { Write-Verbose "Credential Manager read failed: $_" }

    return $null
}

# ============================================================================
# FUNCTION: Write-SendLog
# ============================================================================
# Appends a structured entry to the JSON send log.
function Write-SendLog {
    param(
        [string]$Provider,
        [string]$Result,      # Success | TransientFailure | PermanentFailure | RateLimited
        [string]$ErrorDetail,
        [int]$Attempt,
        [string[]]$Recipients
    )

    # Ensure directory exists
    if (-not (Test-Path $squadDir)) {
        New-Item -ItemType Directory -Path $squadDir -Force | Out-Null
    }

    $entry = @{
        timestamp  = (Get-Date).ToUniversalTime().ToString("o")
        provider   = $Provider
        result     = $Result
        error      = $ErrorDetail
        attempt    = $Attempt
        to         = ($Recipients -join "; ")
        subject    = $Subject
    }

    # Read existing log, append, and write back (keep last 200 entries)
    $log = @()
    if (Test-Path $sendLogPath) {
        try {
            $raw = Get-Content -Path $sendLogPath -Raw -ErrorAction Stop
            if ($raw) { $log = @($raw | ConvertFrom-Json) }
        }
        catch { $log = @() }
    }

    $log = @($log) + @($entry)
    # Trim to last 200 entries to prevent unbounded growth
    if ($log.Count -gt 200) { $log = $log[-200..-1] }

    $log | ConvertTo-Json -Depth 4 | Set-Content -Path $sendLogPath -Encoding UTF8
}

# ============================================================================
# FUNCTION: Test-RateLimit
# ============================================================================
# Returns $true if the number of emails sent in the last hour exceeds the limit.
function Test-RateLimit {
    if (-not (Test-Path $sendLogPath)) { return $false }

    try {
        $raw = Get-Content -Path $sendLogPath -Raw -ErrorAction Stop
        if (-not $raw) { return $false }
        $log = @($raw | ConvertFrom-Json)
    }
    catch { return $false }

    $oneHourAgo = (Get-Date).ToUniversalTime().AddHours(-1).ToString("o")
    $recentSuccesses = @($log | Where-Object {
        $_.result -eq "Success" -and $_.timestamp -ge $oneHourAgo
    })

    return ($recentSuccesses.Count -ge $RateLimitPerHour)
}

# ============================================================================
# FUNCTION: Test-SmtpTransientError
# ============================================================================
function Test-SmtpTransientError {
    param([string]$ErrorMessage)

    # SMTP 4xx = transient (421, 450, 451, 452)
    if ($ErrorMessage -match '\b(421|450|451|452)\b') { return $true }
    # SMTP 5xx = permanent — handled by Test-SmtpPermanentError
    if ($ErrorMessage -match '\b(5[0-5]\d)\b') { return $false }
    # Network-level transient errors
    if ($ErrorMessage -match '(timed?\s*out|connection\s*(refused|reset|closed)|network|socket)') {
        return $true
    }
    # Default: treat as transient (retry is safer than giving up)
    return $true
}

# ============================================================================
# FUNCTION: Test-SmtpPermanentError
# ============================================================================
function Test-SmtpPermanentError {
    param([string]$ErrorMessage)

    if ($ErrorMessage -match '\b(550|553|554|521|523)\b') { return $true }
    if ($ErrorMessage -match '(authentication\s+failed|auth.*required|invalid.*credential|SMTP AUTH.*not.*enabled)') {
        return $true
    }
    return $false
}

# ============================================================================
# FUNCTION: Send-ViaProvider
# ============================================================================
# Attempts to send email through a single SMTP provider with retry/backoff.
# Returns a hashtable: @{ Sent = $bool; Permanent = $bool; Error = "..." }
function Send-ViaProvider {
    param(
        [hashtable]$Config
    )

    $providerName = $Config.ProviderName
    Write-Verbose "Attempting send via $providerName ($($Config.SmtpServer):$($Config.Port))"

    # Retrieve credentials
    $password = Get-CredentialManagerPassword -Target $Config.CredentialKey -Username $Config.FromAddress
    if (-not $password) {
        $msg = "No credentials found for $providerName (key: $($Config.CredentialKey))"
        Write-Host "⚠ $msg" -ForegroundColor Yellow
        Write-SendLog -Provider $providerName -Result "PermanentFailure" -ErrorDetail $msg -Attempt 0 -Recipients $To
        return @{ Sent = $false; Permanent = $true; Error = $msg }
    }

    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    $credential = New-Object PSCredential($Config.FromAddress, $securePassword)

    $mailParams = @{
        From       = $Config.FromAddress
        To         = $To
        Subject    = $Subject
        Body       = $Body
        SmtpServer = $Config.SmtpServer
        Port       = $Config.Port
        UseSsl     = $true
        Credential = $credential
    }
    if ($Cc)          { $mailParams['Cc']          = $Cc }
    if ($Bcc)         { $mailParams['Bcc']         = $Bcc }
    if ($Attachments) { $mailParams['Attachments']  = $Attachments }
    if ($BodyAsHtml)  { $mailParams['BodyAsHtml']   = $true }

    $lastError = $null

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Verbose "$providerName attempt $attempt/$MaxRetries"
            Send-MailMessage @mailParams -ErrorAction Stop

            Write-SendLog -Provider $providerName -Result "Success" -ErrorDetail "" -Attempt $attempt -Recipients $To
            return @{ Sent = $true; Permanent = $false; Error = "" }
        }
        catch {
            $lastError = $_
            $errMsg = $_.Exception.Message

            # Permanent error — bail immediately
            if (Test-SmtpPermanentError -ErrorMessage $errMsg) {
                Write-Host "✗ $providerName permanent error (attempt $attempt): $errMsg" -ForegroundColor Red
                Write-SendLog -Provider $providerName -Result "PermanentFailure" -ErrorDetail $errMsg -Attempt $attempt -Recipients $To
                return @{ Sent = $false; Permanent = $true; Error = $errMsg }
            }

            # Transient error — retry with exponential backoff
            Write-SendLog -Provider $providerName -Result "TransientFailure" -ErrorDetail $errMsg -Attempt $attempt -Recipients $To

            if ($attempt -lt $MaxRetries) {
                # Exponential backoff: base^(2*attempt-1), capped at 120s
                $delay = [math]::Pow($RetryDelaySeconds, (2 * $attempt - 1))
                $delay = [math]::Min($delay, 120)
                Write-Host "⚠ $providerName transient error (attempt $attempt/$MaxRetries): $errMsg" -ForegroundColor Yellow
                Write-Host "  Retrying in $delay seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $delay
            }
        }
    }

    # All retries exhausted
    $errMsg = $lastError.Exception.Message
    Write-Host "✗ $providerName failed after $MaxRetries attempt(s): $errMsg" -ForegroundColor Red
    return @{ Sent = $false; Permanent = $false; Error = $errMsg }
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

# 1. Pre-send rate check
if (-not $SkipRateCheck -and (Test-RateLimit)) {
    Write-Host "⚠ Rate limit warning: $RateLimitPerHour+ emails sent in the last hour." -ForegroundColor Yellow
    Write-Host "  Proceeding anyway, but external SMTP providers may throttle." -ForegroundColor Yellow
    Write-SendLog -Provider "RateCheck" -Result "RateLimited" -ErrorDetail "$RateLimitPerHour+ emails/hour" -Attempt 0 -Recipients $To
}

# 2. Validate attachments up front
if ($Attachments) {
    foreach ($att in $Attachments) {
        if (-not (Test-Path -LiteralPath $att -PathType Leaf)) {
            Write-Host "✗ Attachment not found: $att" -ForegroundColor Red
            exit 1
        }
    }
}

# 3. Determine provider order: Gmail first (Outlook SMTP AUTH is disabled), unless overridden
if ($PreferOutlook) {
    $providers = @($outlookConfig, $gmailConfig)
}
else {
    $providers = @($gmailConfig, $outlookConfig)
}

# 4. Try each provider in order, with fallback
$finalResult = $null
foreach ($provider in $providers) {
    $result = Send-ViaProvider -Config $provider

    if ($result.Sent) {
        Write-Host "✓ Email sent successfully via $($provider.ProviderName) to: $($To -join ', ')" -ForegroundColor Green
        Write-Host "  Subject: $Subject"
        exit 0
    }

    $finalResult = $result

    # If permanent failure, try fallback provider
    if ($result.Permanent) {
        Write-Host "  → Falling back to next provider..." -ForegroundColor Yellow
        continue
    }

    # If transient failure exhausted retries, also try fallback
    Write-Host "  → Falling back to next provider after transient failures..." -ForegroundColor Yellow
}

# 5. All providers failed
Write-Host "✗ All email providers failed." -ForegroundColor Red
if ($finalResult.Permanent) {
    exit 1   # Permanent failure
}
else {
    exit 2   # Transient failure, all retries exhausted
}
