<#
╔══════════════════════════════════════════════════════════════════════════════╗
║  SECURITY: NEVER send email from tamirdresher@microsoft.com via Outlook    ║
║  COM or any other method. This script ONLY sends from:                     ║
║    • td-squad-ai-team@outlook.com  (Graph API — Microsoft internal)        ║
║    • tdsquadai@gmail.com           (Gmail SMTP — external recipients)      ║
║  Any attempt to use Outlook COM or tamirdresher@microsoft.com is BLOCKED.  ║
╚══════════════════════════════════════════════════════════════════════════════╝

.SYNOPSIS
    Unified Squad email with auto-routing: Outlook Graph API for @microsoft.com,
    Gmail SMTP for external recipients.

.DESCRIPTION
    Auto-routes based on recipient domain:
      @microsoft.com → Graph API via td-squad-ai-team@outlook.com
      Everything else → Gmail SMTP via tdsquadai@gmail.com

    Gmail app password lookup order:
      1. Windows Credential Manager key "squad-email-gmail"
      2. Environment variable SQUAD_GMAIL_APP_PASSWORD
      3. GitHub Secret via `gh secret list -R tamirdresher/squad-personal-demo`

    Security gate: Only accepts commands from authenticated sessions matching
    tamir.dresher@gmail.com or tamirdresher@microsoft.com.

.PARAMETER To
    Recipient email address(es). Comma-separated for multiple.

.PARAMETER Subject
    Email subject line.

.PARAMETER Body
    Email body content.

.PARAMETER BodyType
    Body content type: 'text' or 'html'. Default: 'text'.

.PARAMETER Cc
    CC recipient(s). Comma-separated for multiple.

.PARAMETER Bcc
    BCC recipient(s). Comma-separated for multiple.

.PARAMETER Importance
    Email importance: 'low', 'normal', 'high'. Default: 'normal'.

.PARAMETER Via
    Force a specific sending route: 'outlook' or 'gmail'. If omitted, auto-routes
    based on recipient domain.

.PARAMETER CallerIdentity
    Email of the session owner requesting the send. Must be an authorized identity.

.EXAMPLE
    .\Send-SquadEmail.ps1 -To "someone@microsoft.com" -Subject "Hello" -Body "Internal" -CallerIdentity "tamirdresher@microsoft.com"

.EXAMPLE
    .\Send-SquadEmail.ps1 -To "user@example.com" -Subject "Report" -Body "External" -CallerIdentity "tamir.dresher@gmail.com"

.EXAMPLE
    .\Send-SquadEmail.ps1 -To "user@gmail.com" -Subject "Test" -Body "Forced via Gmail" -Via gmail -CallerIdentity "tamir.dresher@gmail.com"
#>
param(
    [Parameter(Mandatory)][string]$To,
    [Parameter(Mandatory)][string]$Subject,
    [Parameter(Mandatory)][string]$Body,
    [ValidateSet('text','html')][string]$BodyType = 'text',
    [string]$Cc,
    [string]$Bcc,
    [ValidateSet('low','normal','high')][string]$Importance = 'normal',
    [ValidateSet('outlook','gmail')][string]$Via,
    [string]$CallerIdentity,
    [switch]$SaveToSentItems
)

$ErrorActionPreference = 'Stop'

# ── Constants ────────────────────────────────────────────────────────────────
$GRAPH_CREDENTIAL_KEY = "squad-email-graph-token"
$GMAIL_CREDENTIAL_KEY = "squad-email-gmail"
$CLIENT_ID = "14d82eec-204b-4c2f-b7e8-296a70dab67e"  # Microsoft Graph CLI (public client)
$TOKEN_ENDPOINT = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"
$GRAPH_ENDPOINT = "https://graph.microsoft.com/v1.0/me/sendMail"
$SCOPE = "https://graph.microsoft.com/Mail.Send https://graph.microsoft.com/Mail.ReadWrite offline_access"

$GMAIL_SMTP_SERVER = "smtp.gmail.com"
$GMAIL_SMTP_PORT = 587
$GMAIL_ADDRESS = "tdsquadai@gmail.com"
$OUTLOOK_ADDRESS = "td-squad-ai-team@outlook.com"

$AUTHORIZED_IDENTITIES = @(
    "tamir.dresher@gmail.com",
    "tamirdresher@microsoft.com"
)

$SCRIPT_ROOT = $PSScriptRoot
$LOG_FILE = Join-Path (Split-Path $SCRIPT_ROOT -Parent | Split-Path -Parent) ".squad\ralph-email-monitor.log"

# ── Security Gate ────────────────────────────────────────────────────────────
function Assert-AuthorizedCaller {
    # Check explicit CallerIdentity parameter
    if ($CallerIdentity -and ($AUTHORIZED_IDENTITIES -contains $CallerIdentity.ToLower())) {
        return $true
    }

    # Check git config as fallback identity source
    $gitEmail = git config user.email 2>$null
    if ($gitEmail -and ($AUTHORIZED_IDENTITIES -contains $gitEmail.ToLower())) {
        return $true
    }

    # Check GH_TOKEN owner
    try {
        $ghUser = gh api user --jq '.email // .login' 2>$null
        if ($ghUser -and ($AUTHORIZED_IDENTITIES -contains $ghUser.ToLower())) {
            return $true
        }
    } catch {}

    Write-Error "SECURITY: Unauthorized caller. Email sending is only permitted for: $($AUTHORIZED_IDENTITIES -join ', '). Provide -CallerIdentity or configure git user.email."
    return $false
}

# ── Logging ──────────────────────────────────────────────────────────────────
function Write-EmailLog {
    param([string]$From, [string]$To, [string]$Subject, [string]$Route, [string]$Status)
    $logDir = Split-Path $LOG_FILE -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] route=$Route status=$Status from=$From to=$To subject=$Subject"
    Add-Content -Path $LOG_FILE -Value $entry
}

# ── Credential Manager helpers (pure P/Invoke) ──────────────────────────────
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class CredManager {
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredReadW(string target, int type, int flags, out IntPtr credential);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredWriteW(ref CREDENTIAL credential, int flags);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern void CredFree(IntPtr credential);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL {
        public int Flags;
        public int Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    public static string Read(string target) {
        IntPtr credPtr;
        if (!CredReadW(target, 1, 0, out credPtr)) return null;
        try {
            CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
            if (cred.CredentialBlob == IntPtr.Zero) return null;
            return Marshal.PtrToStringUni(cred.CredentialBlob, cred.CredentialBlobSize / 2);
        } finally { CredFree(credPtr); }
    }

    public static bool Write(string target, string secret, string username) {
        byte[] byteArray = Encoding.Unicode.GetBytes(secret);
        CREDENTIAL cred = new CREDENTIAL();
        cred.Type = 1;
        cred.TargetName = target;
        cred.CredentialBlobSize = byteArray.Length;
        cred.CredentialBlob = Marshal.AllocHGlobal(byteArray.Length);
        Marshal.Copy(byteArray, 0, cred.CredentialBlob, byteArray.Length);
        cred.Persist = 2;
        cred.UserName = username;
        try { return CredWriteW(ref cred, 0); }
        finally { Marshal.FreeHGlobal(cred.CredentialBlob); }
    }
}
"@ -ErrorAction SilentlyContinue

# ── Route Determination ──────────────────────────────────────────────────────
function Get-EmailRoute {
    # Explicit override
    if ($Via) { return $Via }

    # Auto-route: check if ALL recipients are @microsoft.com
    $allRecipients = @($To -split ',') | ForEach-Object { $_.Trim() }
    if ($Cc) { $allRecipients += @($Cc -split ',') | ForEach-Object { $_.Trim() } }
    if ($Bcc) { $allRecipients += @($Bcc -split ',') | ForEach-Object { $_.Trim() } }

    $allMicrosoft = $true
    foreach ($addr in $allRecipients) {
        if ($addr -notmatch '@microsoft\.com$') {
            $allMicrosoft = $false
            break
        }
    }

    if ($allMicrosoft) { return 'outlook' }
    return 'gmail'
}

# ── Graph API (Outlook) Backend ──────────────────────────────────────────────
function Get-RefreshToken {
    $token = [CredManager]::Read($GRAPH_CREDENTIAL_KEY)
    if (-not $token) {
        $token = $env:SQUAD_EMAIL_REFRESH_TOKEN
    }
    return $token
}

function Save-RefreshToken([string]$token) {
    [CredManager]::Write($GRAPH_CREDENTIAL_KEY, $token, $OUTLOOK_ADDRESS) | Out-Null
    Write-Host "Refresh token saved to Credential Manager" -ForegroundColor Green
}

function Get-AccessToken {
    $refreshToken = Get-RefreshToken
    if (-not $refreshToken) {
        Write-Error "No refresh token found. Run Setup-SquadEmailAuth.ps1 first to authenticate."
        return $null
    }

    $body = @{
        client_id     = $CLIENT_ID
        grant_type    = "refresh_token"
        refresh_token = $refreshToken
        scope         = $SCOPE
    }

    try {
        $response = Invoke-RestMethod -Method POST -Uri $TOKEN_ENDPOINT -Body $body -ContentType "application/x-www-form-urlencoded"

        if ($response.refresh_token) {
            Save-RefreshToken $response.refresh_token
        }

        return $response.access_token
    } catch {
        Write-Error "Token refresh failed: $($_.Exception.Message). Re-run Setup-SquadEmailAuth.ps1"
        return $null
    }
}

function Send-ViaOutlook {
    $accessToken = Get-AccessToken
    if (-not $accessToken) { return $false }

    $toRecipients = @($To -split ',' | ForEach-Object {
        @{ emailAddress = @{ address = $_.Trim() } }
    })

    $message = @{
        subject = $Subject
        body = @{
            contentType = $BodyType
            content     = $Body
        }
        toRecipients = $toRecipients
        importance   = $Importance
    }

    if ($Cc) {
        $message.ccRecipients = @($Cc -split ',' | ForEach-Object {
            @{ emailAddress = @{ address = $_.Trim() } }
        })
    }

    if ($Bcc) {
        $message.bccRecipients = @($Bcc -split ',' | ForEach-Object {
            @{ emailAddress = @{ address = $_.Trim() } }
        })
    }

    $payload = @{
        message         = $message
        saveToSentItems = [bool]$SaveToSentItems
    } | ConvertTo-Json -Depth 10

    $headers = @{
        Authorization  = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }

    try {
        Invoke-RestMethod -Method POST -Uri $GRAPH_ENDPOINT -Headers $headers -Body $payload
        Write-Host "Email sent via Outlook (Graph API) from $OUTLOOK_ADDRESS to $To" -ForegroundColor Green
        Write-EmailLog -From $OUTLOOK_ADDRESS -To $To -Subject $Subject -Route "outlook" -Status "sent"
        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-EmailLog -From $OUTLOOK_ADDRESS -To $To -Subject $Subject -Route "outlook" -Status "failed:$statusCode"
        Write-Error "Failed to send via Outlook (HTTP $statusCode): $($_.Exception.Message)"
        return $false
    }
}

# ── Gmail SMTP Backend ──────────────────────────────────────────────────────
function Get-GmailAppPassword {
    # 1. Windows Credential Manager
    $password = [CredManager]::Read($GMAIL_CREDENTIAL_KEY)
    if ($password) {
        Write-Host "Gmail app password loaded from Credential Manager" -ForegroundColor DarkGray
        return $password
    }

    # 2. Environment variable
    if ($env:SQUAD_GMAIL_APP_PASSWORD) {
        Write-Host "Gmail app password loaded from env var" -ForegroundColor DarkGray
        return $env:SQUAD_GMAIL_APP_PASSWORD
    }

    # 3. GitHub Secret (check if accessible)
    try {
        Write-Host "Checking GitHub Secrets for Gmail app password..." -ForegroundColor DarkGray
        $secrets = gh secret list -R tamirdresher/squad-personal-demo 2>&1
        if ($secrets -match 'SQUAD_GMAIL_APP_PASSWORD') {
            Write-Warning "Gmail app password exists as GitHub Secret but cannot be read directly. Set it locally via:`n  cmdkey /generic:squad-email-gmail /user:tdsquadai@gmail.com /pass:<APP_PASSWORD>`n  or set env var SQUAD_GMAIL_APP_PASSWORD"
        }
    } catch {}

    return $null
}

function Send-ViaGmail {
    $appPassword = Get-GmailAppPassword
    if (-not $appPassword) {
        Write-Error "Gmail app password not found. Set it via:`n  1. cmdkey /generic:squad-email-gmail /user:tdsquadai@gmail.com /pass:<APP_PASSWORD>`n  2. `$env:SQUAD_GMAIL_APP_PASSWORD = '<APP_PASSWORD>'`n  3. Store as GitHub Secret SQUAD_GMAIL_APP_PASSWORD"
        Write-EmailLog -From $GMAIL_ADDRESS -To $To -Subject $Subject -Route "gmail" -Status "failed:no-credentials"
        return $false
    }

    try {
        $smtpClient = New-Object System.Net.Mail.SmtpClient($GMAIL_SMTP_SERVER, $GMAIL_SMTP_PORT)
        $smtpClient.EnableSsl = $true
        $smtpClient.Credentials = New-Object System.Net.NetworkCredential($GMAIL_ADDRESS, $appPassword)

        $mailMessage = New-Object System.Net.Mail.MailMessage
        $mailMessage.From = New-Object System.Net.Mail.MailAddress($GMAIL_ADDRESS, "Squad AI Team")
        $mailMessage.Subject = $Subject
        $mailMessage.IsBodyHtml = ($BodyType -eq 'html')
        $mailMessage.Body = $Body

        # Priority mapping
        switch ($Importance) {
            'high' { $mailMessage.Priority = [System.Net.Mail.MailPriority]::High }
            'low'  { $mailMessage.Priority = [System.Net.Mail.MailPriority]::Low }
            default { $mailMessage.Priority = [System.Net.Mail.MailPriority]::Normal }
        }

        # Add recipients
        foreach ($addr in ($To -split ',')) {
            $mailMessage.To.Add($addr.Trim())
        }
        if ($Cc) {
            foreach ($addr in ($Cc -split ',')) {
                $mailMessage.CC.Add($addr.Trim())
            }
        }
        if ($Bcc) {
            foreach ($addr in ($Bcc -split ',')) {
                $mailMessage.Bcc.Add($addr.Trim())
            }
        }

        $smtpClient.Send($mailMessage)
        Write-Host "Email sent via Gmail SMTP from $GMAIL_ADDRESS to $To" -ForegroundColor Green
        Write-EmailLog -From $GMAIL_ADDRESS -To $To -Subject $Subject -Route "gmail" -Status "sent"

        $mailMessage.Dispose()
        $smtpClient.Dispose()
        return $true
    } catch {
        Write-EmailLog -From $GMAIL_ADDRESS -To $To -Subject $Subject -Route "gmail" -Status "failed:$($_.Exception.Message)"
        Write-Error "Failed to send via Gmail SMTP: $($_.Exception.Message)"
        return $false
    }
}

# ── Main Execution ───────────────────────────────────────────────────────────
if (-not (Assert-AuthorizedCaller)) { exit 1 }

$route = Get-EmailRoute
Write-Host "Route: $route | To: $To" -ForegroundColor Cyan

switch ($route) {
    'outlook' { $result = Send-ViaOutlook }
    'gmail'   { $result = Send-ViaGmail }
}

if (-not $result) { exit 1 }
