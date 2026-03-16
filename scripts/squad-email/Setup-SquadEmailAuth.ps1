<#
.SYNOPSIS
    One-time setup: authenticate the Squad email for headless sending via Microsoft Graph API.

.DESCRIPTION
    Uses OAuth2 Device Code Flow - you'll get a code to enter at microsoft.com/link.
    After authenticating, the refresh token is saved to Windows Credential Manager
    for all future Send-SquadEmail.ps1 calls.

.PARAMETER SaveToGitHubSecret
    Also save the refresh token as a GitHub Secret for cross-machine access.

.PARAMETER GitHubRepo
    GitHub repo for secret storage. Default: tamirdresher_microsoft/tamresearch1

.EXAMPLE
    .\Setup-SquadEmailAuth.ps1
    .\Setup-SquadEmailAuth.ps1 -SaveToGitHubSecret
#>
param(
    [switch]$SaveToGitHubSecret,
    [string]$GitHubRepo = "tamirdresher_microsoft/tamresearch1"
)

$ErrorActionPreference = 'Stop'
$CREDENTIAL_KEY = "squad-email-graph-token"
$CLIENT_ID = "14d82eec-204b-4c2f-b7e8-296a70dab67e"
$DEVICE_CODE_ENDPOINT = "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode"
$TOKEN_ENDPOINT = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"
$SCOPE = "https://graph.microsoft.com/Mail.Send https://graph.microsoft.com/Mail.ReadWrite offline_access"

# --- Credential Manager (same as Send-SquadEmail.ps1) ---
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class CredManagerSetup {
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredWriteW(ref CREDENTIAL credential, int flags);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL {
        public int Flags; public int Type; public string TargetName; public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public int CredentialBlobSize; public IntPtr CredentialBlob;
        public int Persist; public int AttributeCount; public IntPtr Attributes;
        public string TargetAlias; public string UserName;
    }

    public static bool Write(string target, string secret, string username) {
        byte[] byteArray = Encoding.Unicode.GetBytes(secret);
        CREDENTIAL cred = new CREDENTIAL();
        cred.Type = 1; cred.TargetName = target;
        cred.CredentialBlobSize = byteArray.Length;
        cred.CredentialBlob = Marshal.AllocHGlobal(byteArray.Length);
        Marshal.Copy(byteArray, 0, cred.CredentialBlob, byteArray.Length);
        cred.Persist = 2; cred.UserName = username;
        try { return CredWriteW(ref cred, 0); }
        finally { Marshal.FreeHGlobal(cred.CredentialBlob); }
    }
}
"@ -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== Squad Email Authentication Setup ===" -ForegroundColor Cyan
Write-Host "Account: td-squad-ai-team@outlook.com" -ForegroundColor White
Write-Host ""

# Step 1: Request device code
Write-Host "Requesting device code..." -ForegroundColor Yellow
$deviceResponse = Invoke-RestMethod -Method POST -Uri $DEVICE_CODE_ENDPOINT -Body @{
    client_id = $CLIENT_ID
    scope     = $SCOPE
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Open: $($deviceResponse.verification_uri)" -ForegroundColor White
Write-Host "  Enter code: $($deviceResponse.user_code)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Sign in with: td-squad-ai-team@outlook.com" -ForegroundColor Cyan
Write-Host "Waiting for authentication..." -ForegroundColor Gray

# Step 2: Poll for token
$interval = $deviceResponse.interval
if (-not $interval) { $interval = 5 }
$expiresAt = (Get-Date).AddSeconds($deviceResponse.expires_in)

while ((Get-Date) -lt $expiresAt) {
    Start-Sleep -Seconds $interval

    try {
        $tokenResponse = Invoke-RestMethod -Method POST -Uri $TOKEN_ENDPOINT -Body @{
            client_id   = $CLIENT_ID
            grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
            device_code = $deviceResponse.device_code
        }

        # Success!
        Write-Host ""
        Write-Host "Authentication successful!" -ForegroundColor Green

        # Save refresh token
        [CredManagerSetup]::Write($CREDENTIAL_KEY, $tokenResponse.refresh_token, "td-squad-ai-team@outlook.com") | Out-Null
        Write-Host "Refresh token saved to Windows Credential Manager (key: $CREDENTIAL_KEY)" -ForegroundColor Green

        # Optionally save to GitHub Secret
        if ($SaveToGitHubSecret) {
            Write-Host "Saving to GitHub Secret..." -ForegroundColor Yellow
            try {
                $tokenResponse.refresh_token | gh secret set SQUAD_EMAIL_REFRESH_TOKEN -R $GitHubRepo 2>&1
                Write-Host "Saved to GitHub Secret: SQUAD_EMAIL_REFRESH_TOKEN" -ForegroundColor Green
            } catch {
                Write-Host "Failed to save GitHub Secret: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Manually save with: echo '<token>' | gh secret set SQUAD_EMAIL_REFRESH_TOKEN -R $GitHubRepo" -ForegroundColor Yellow
            }
        }

        # Test it
        Write-Host ""
        Write-Host "Testing email send capability..." -ForegroundColor Yellow
        $headers = @{
            Authorization  = "Bearer $($tokenResponse.access_token)"
            "Content-Type" = "application/json"
        }
        $testPayload = @{
            message = @{
                subject      = "Squad Email Setup Complete"
                body         = @{ contentType = "text"; content = "Headless email sending is now configured for td-squad-ai-team@outlook.com. This is a test email." }
                toRecipients = @(@{ emailAddress = @{ address = "td-squad-ai-team@outlook.com" } })
            }
            saveToSentItems = $true
        } | ConvertTo-Json -Depth 10

        try {
            Invoke-RestMethod -Method POST -Uri "https://graph.microsoft.com/v1.0/me/sendMail" -Headers $headers -Body $testPayload
            Write-Host "Test email sent! Setup complete." -ForegroundColor Green
        } catch {
            Write-Host "Test email failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "The refresh token is saved - try running Send-SquadEmail.ps1" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
        Write-Host "Usage: .\Send-SquadEmail.ps1 -To 'user@example.com' -Subject 'Hello' -Body 'Message'" -ForegroundColor White
        return
    } catch {
        $errorMsg = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($errorMsg.error -eq "authorization_pending") {
            Write-Host "." -NoNewline -ForegroundColor Gray
            continue
        } elseif ($errorMsg.error -eq "slow_down") {
            $interval += 5
            continue
        } else {
            Write-Error "Authentication failed: $($errorMsg.error_description ?? $_.Exception.Message)"
            return
        }
    }
}

Write-Error "Device code expired. Please run setup again."
