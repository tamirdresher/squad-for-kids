<#
.SYNOPSIS
    Send emails from the Squad email (td-squad-ai-team@outlook.com) via Microsoft Graph API.
    Headless, no browser needed after initial setup.

.DESCRIPTION
    Uses OAuth2 refresh tokens stored in Windows Credential Manager to send emails
    via Microsoft Graph API. Supports text and HTML bodies, CC, BCC, attachments.

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

.EXAMPLE
    .\Send-SquadEmail.ps1 -To "tamir.dresher@gmail.com" -Subject "Hello" -Body "Test email"

.EXAMPLE
    .\Send-SquadEmail.ps1 -To "user@example.com" -Subject "Report" -Body "<h1>Report</h1><p>Details here</p>" -BodyType html
#>
param(
    [Parameter(Mandatory)][string]$To,
    [Parameter(Mandatory)][string]$Subject,
    [Parameter(Mandatory)][string]$Body,
    [ValidateSet('text','html')][string]$BodyType = 'text',
    [string]$Cc,
    [string]$Bcc,
    [ValidateSet('low','normal','high')][string]$Importance = 'normal',
    [switch]$SaveToSentItems
)

$ErrorActionPreference = 'Stop'
$CREDENTIAL_KEY = "squad-email-graph-token"
$CLIENT_ID = "14d82eec-204b-4c2f-b7e8-296a70dab67e"  # Microsoft Graph CLI (public client)
$TOKEN_ENDPOINT = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"
$GRAPH_ENDPOINT = "https://graph.microsoft.com/v1.0/me/sendMail"
$SCOPE = "https://graph.microsoft.com/Mail.Send offline_access"

# --- Credential Manager helpers (pure P/Invoke, no module needed) ---
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

function Get-RefreshToken {
    $token = [CredManager]::Read($CREDENTIAL_KEY)
    if (-not $token) {
        # Also check environment variable (for CI/containers)
        $token = $env:SQUAD_EMAIL_REFRESH_TOKEN
    }
    return $token
}

function Save-RefreshToken([string]$token) {
    [CredManager]::Write($CREDENTIAL_KEY, $token, "td-squad-ai-team@outlook.com") | Out-Null
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

        # Save new refresh token (they rotate)
        if ($response.refresh_token) {
            Save-RefreshToken $response.refresh_token
        }

        return $response.access_token
    } catch {
        Write-Error "Token refresh failed: $($_.Exception.Message). Re-run Setup-SquadEmailAuth.ps1"
        return $null
    }
}

function Send-Email {
    $accessToken = Get-AccessToken
    if (-not $accessToken) { return $false }

    # Build recipients
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
        Write-Host "Email sent successfully from td-squad-ai-team@outlook.com to $To" -ForegroundColor Green
        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Error "Failed to send email (HTTP $statusCode): $($_.Exception.Message)"
        return $false
    }
}

# Execute
Send-Email
