<#
.SYNOPSIS
    Sets up Outlook.com inbox rules for the family email pipeline.
    Routes emails from Gabi based on @keyword in subject line.

.DESCRIPTION
    Creates 4 inbox rules on td-squad-ai-team@outlook.com via Microsoft Graph API:
      1. @print → Forward to HP ePrint (Dresherhome@hpeprint.com)
      2. @calendar → Forward to Tamir with [CALENDAR] prefix
      3. @reminder → Forward to Tamir with [REMINDER] prefix
      4. All other from Gabi → Forward to Tamir with [FAMILY] prefix

    Requires Graph API authentication. If no refresh token is cached, runs
    device code flow for one-time interactive auth.

.PARAMETER DryRun
    If set, shows what rules would be created without actually creating them.

.PARAMETER Force
    If set, deletes existing family pipeline rules before creating new ones.

.EXAMPLE
    .\Setup-FamilyEmailRules.ps1
    .\Setup-FamilyEmailRules.ps1 -DryRun
    .\Setup-FamilyEmailRules.ps1 -Force
#>
param(
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ── Configuration ────────────────────────────────────────────────────────────
$GRAPH_CREDENTIAL_KEY = "squad-email-graph-token"
$CLIENT_ID = "14d82eec-204b-4c2f-b7e8-296a70dab67e"
$TOKEN_ENDPOINT = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"
$DEVICE_CODE_ENDPOINT = "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode"
$SCOPE = "https://graph.microsoft.com/Mail.Send https://graph.microsoft.com/Mail.ReadWrite https://graph.microsoft.com/MailboxSettings.ReadWrite offline_access"
$RULES_ENDPOINT = "https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messageRules"

$FAMILY_SENDER = "gabrielayael@gmail.com"
$TAMIR_EMAIL = "tamirdresher@microsoft.com"
$PRINTER_EMAIL = "Dresherhome@hpeprint.com"
$RULE_PREFIX = "[FamilyPipeline]"

# ── Credential Manager P/Invoke ─────────────────────────────────────────────
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class FamilyRulesCredManager {
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredReadW(string target, int type, int flags, out IntPtr credential);
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredWriteW(ref CREDENTIAL credential, int flags);
    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern void CredFree(IntPtr credential);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL {
        public int Flags; public int Type; public string TargetName; public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public int CredentialBlobSize; public IntPtr CredentialBlob;
        public int Persist; public int AttributeCount; public IntPtr Attributes;
        public string TargetAlias; public string UserName;
    }

    public static string Read(string target) {
        IntPtr credPtr;
        if (!CredReadW(target, 1, 0, out credPtr)) return null;
        try {
            CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
            if (cred.CredentialBlobSize > 0)
                return Marshal.PtrToStringUni(cred.CredentialBlob, cred.CredentialBlobSize / 2);
            return null;
        } finally { CredFree(credPtr); }
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

# ── Auth Functions ───────────────────────────────────────────────────────────
function Get-AccessToken {
    # Try cached refresh token first
    $refreshToken = [FamilyRulesCredManager]::Read($GRAPH_CREDENTIAL_KEY)

    if ($refreshToken) {
        Write-Host "Using cached refresh token..." -ForegroundColor Gray
        try {
            $tokenResponse = Invoke-RestMethod -Method POST -Uri $TOKEN_ENDPOINT -Body @{
                client_id     = $CLIENT_ID
                grant_type    = "refresh_token"
                refresh_token = $refreshToken
                scope         = $SCOPE
            }
            # Update stored refresh token
            [FamilyRulesCredManager]::Write($GRAPH_CREDENTIAL_KEY, $tokenResponse.refresh_token, "td-squad-ai-team@outlook.com") | Out-Null
            return $tokenResponse.access_token
        } catch {
            Write-Host "Cached token expired. Starting interactive auth..." -ForegroundColor Yellow
        }
    }

    # Device code flow
    Write-Host ""
    Write-Host "=== One-time Authentication Required ===" -ForegroundColor Cyan
    $deviceResponse = Invoke-RestMethod -Method POST -Uri $DEVICE_CODE_ENDPOINT -Body @{
        client_id = $CLIENT_ID
        scope     = $SCOPE
    }

    Write-Host ""
    Write-Host "  1. Open: $($deviceResponse.verification_uri)" -ForegroundColor White
    Write-Host "  2. Enter code: $($deviceResponse.user_code)" -ForegroundColor Yellow
    Write-Host "  3. Sign in with: td-squad-ai-team@outlook.com" -ForegroundColor Cyan
    Write-Host ""

    $interval = if ($deviceResponse.interval) { $deviceResponse.interval } else { 5 }
    $expiresAt = (Get-Date).AddSeconds($deviceResponse.expires_in)

    while ((Get-Date) -lt $expiresAt) {
        Start-Sleep -Seconds $interval
        try {
            $tokenResponse = Invoke-RestMethod -Method POST -Uri $TOKEN_ENDPOINT -Body @{
                client_id   = $CLIENT_ID
                grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
                device_code = $deviceResponse.device_code
            }
            Write-Host "Authenticated!" -ForegroundColor Green
            [FamilyRulesCredManager]::Write($GRAPH_CREDENTIAL_KEY, $tokenResponse.refresh_token, "td-squad-ai-team@outlook.com") | Out-Null
            return $tokenResponse.access_token
        } catch {
            $err = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($err.error -eq "authorization_pending") { Write-Host "." -NoNewline -ForegroundColor Gray; continue }
            elseif ($err.error -eq "slow_down") { $interval += 5; continue }
            else { throw "Auth failed: $($err.error_description ?? $_.Exception.Message)" }
        }
    }
    throw "Device code expired. Run again."
}

# ── Rule Definitions ─────────────────────────────────────────────────────────
$rules = @(
    @{
        displayName = "$RULE_PREFIX Print Request"
        sequence     = 1
        isEnabled    = $true
        conditions   = @{
            fromContains    = @($FAMILY_SENDER)
            subjectContains = @("@print")
        }
        actions      = @{
            forwardTo          = @(@{ emailAddress = @{ address = $PRINTER_EMAIL; name = "HP ePrint - Home Printer" } })
            stopProcessingRules = $true
        }
    },
    @{
        displayName = "$RULE_PREFIX Calendar Request"
        sequence     = 2
        isEnabled    = $true
        conditions   = @{
            fromContains    = @($FAMILY_SENDER)
            subjectContains = @("@calendar")
        }
        actions      = @{
            forwardTo          = @(@{ emailAddress = @{ address = $TAMIR_EMAIL; name = "Tamir Dresher" } })
            stopProcessingRules = $true
        }
    },
    @{
        displayName = "$RULE_PREFIX Reminder Request"
        sequence     = 3
        isEnabled    = $true
        conditions   = @{
            fromContains    = @($FAMILY_SENDER)
            subjectContains = @("@reminder")
        }
        actions      = @{
            forwardTo          = @(@{ emailAddress = @{ address = $TAMIR_EMAIL; name = "Tamir Dresher" } })
            stopProcessingRules = $true
        }
    },
    @{
        displayName = "$RULE_PREFIX All Family Email"
        sequence     = 4
        isEnabled    = $true
        conditions   = @{
            fromContains = @($FAMILY_SENDER)
        }
        actions      = @{
            forwardTo          = @(@{ emailAddress = @{ address = $TAMIR_EMAIL; name = "Tamir Dresher" } })
            stopProcessingRules = $true
        }
    }
)

# ── Main ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Family Email Pipeline Setup ===" -ForegroundColor Cyan
Write-Host "Inbox: td-squad-ai-team@outlook.com" -ForegroundColor White
Write-Host "Sender: $FAMILY_SENDER" -ForegroundColor White
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] Would create these rules:" -ForegroundColor Yellow
    foreach ($rule in $rules) {
        $keyword = if ($rule.conditions.subjectContains) { $rule.conditions.subjectContains[0] } else { "(any)" }
        $dest = $rule.actions.forwardTo[0].emailAddress.address
        Write-Host "  Rule $($rule.sequence): Subject=$keyword → Forward to $dest" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "[DRY RUN] No changes made." -ForegroundColor Yellow
    return
}

# Authenticate
$accessToken = Get-AccessToken
$headers = @{
    Authorization  = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

# Clean up existing family pipeline rules if -Force
if ($Force) {
    Write-Host "Checking for existing family pipeline rules..." -ForegroundColor Yellow
    try {
        $existing = Invoke-RestMethod -Method GET -Uri $RULES_ENDPOINT -Headers $headers
        $familyRules = $existing.value | Where-Object { $_.displayName -like "$RULE_PREFIX*" }
        foreach ($r in $familyRules) {
            Write-Host "  Deleting: $($r.displayName)" -ForegroundColor Red
            Invoke-RestMethod -Method DELETE -Uri "$RULES_ENDPOINT/$($r.id)" -Headers $headers | Out-Null
        }
        if ($familyRules.Count -eq 0) { Write-Host "  No existing rules found." -ForegroundColor Gray }
    } catch {
        Write-Host "  Warning: Could not check existing rules: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Create rules
$created = 0
foreach ($rule in $rules) {
    $keyword = if ($rule.conditions.subjectContains) { $rule.conditions.subjectContains[0] } else { "(catch-all)" }
    $dest = $rule.actions.forwardTo[0].emailAddress.address
    Write-Host "Creating rule $($rule.sequence): $keyword → $dest ... " -NoNewline

    try {
        $body = $rule | ConvertTo-Json -Depth 10
        $result = Invoke-RestMethod -Method POST -Uri $RULES_ENDPOINT -Headers $headers -Body $body
        Write-Host "OK (id: $($result.id))" -ForegroundColor Green
        $created++
    } catch {
        $errDetail = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
        $errMsg = $errDetail.error.message ?? $_.Exception.Message
        Write-Host "FAILED: $errMsg" -ForegroundColor Red
    }
}

Write-Host ""
if ($created -eq $rules.Count) {
    Write-Host "All $created rules created successfully!" -ForegroundColor Green
} else {
    Write-Host "$created/$($rules.Count) rules created." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Instructions for Gabi ===" -ForegroundColor Cyan
Write-Host "Email: td-squad-ai-team@outlook.com" -ForegroundColor White
Write-Host ""
Write-Host "Keywords (put in subject line):" -ForegroundColor White
Write-Host '  @print    → Prints on home printer' -ForegroundColor Green
Write-Host '  @calendar → Creates calendar event for Tamir' -ForegroundColor Green
Write-Host '  @reminder → Sends reminder to Tamir' -ForegroundColor Green
Write-Host '  (none)    → General message forwarded to Tamir' -ForegroundColor Green
Write-Host ""
Write-Host "Example: Subject: '@print Yonatan homework page 5'" -ForegroundColor Gray
Write-Host "         Attach the file to print." -ForegroundColor Gray
