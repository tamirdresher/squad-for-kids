<#
.SYNOPSIS
    Checks personal Gmail for recent messages via IMAP.

.DESCRIPTION
    Connects to Gmail via IMAP over SSL using credentials stored in
    Windows Credential Manager (target: "GmailAutomation").
    If no credentials are found, prints setup instructions.

.PARAMETER Last
    Number of recent emails to retrieve. Default: 10.

.PARAMETER Search
    Text to search for in email subjects and bodies (e.g., "verification code").

.PARAMETER From
    Filter emails by sender address (e.g., "noreply@hilan.co.il").

.PARAMETER TargetName
    Windows Credential Manager target name. Default: "GmailAutomation".

.EXAMPLE
    # Read the 5 most recent emails
    pwsh scripts/check-personal-email.ps1 -Last 5

.EXAMPLE
    # Search for verification codes from Hilan
    pwsh scripts/check-personal-email.ps1 -Search "verification code" -From "noreply@hilan.co.il" -Last 10

.NOTES
    Requires: Gmail App Password stored via setup-email-credentials.ps1
    Uses: .NET TcpClient + SslStream for IMAP (no external modules)
#>
[CmdletBinding()]
param(
    [Parameter()]
    [int]$Last = 10,

    [Parameter()]
    [string]$Search,

    [Parameter()]
    [string]$From,

    [Parameter()]
    [string]$TargetName = "GmailAutomation"
)

$ErrorActionPreference = 'Stop'

#region Credential Retrieval

function Get-StoredCredential {
    param([string]$Target)

    # Try Windows Credential Manager via cmdkey
    $output = & cmdkey /list:$Target 2>&1 | Out-String

    if ($output -notmatch 'User:\s*(.+)') {
        return $null
    }

    $user = $Matches[1].Trim()

    # cmdkey doesn't expose passwords; use .NET CredentialManager
    # Fall back to environment variables if .NET approach is unavailable
    return @{ User = $user; Password = $null }
}

function Get-GmailCredentials {
    param([string]$Target)

    # Priority 1: Environment variables
    if ($env:GMAIL_USER -and $env:GMAIL_APP_PASSWORD) {
        Write-Verbose "Using credentials from environment variables."
        return @{
            User     = $env:GMAIL_USER
            Password = $env:GMAIL_APP_PASSWORD
        }
    }

    # Priority 2: Windows Credential Manager via PowerShell
    try {
        # Use the CredentialManager module if available
        if (Get-Module -ListAvailable -Name CredentialManager -ErrorAction SilentlyContinue) {
            $cred = Get-StoredCredential -Target $Target -ErrorAction Stop
            if ($cred) {
                Write-Verbose "Using credentials from CredentialManager module."
                return @{
                    User     = $cred.UserName
                    Password = $cred.GetNetworkCredential().Password
                }
            }
        }
    }
    catch {
        Write-Verbose "CredentialManager module not available or failed: $_"
    }

    # Priority 3: Use .NET to read from Credential Manager via P/Invoke
    try {
        $sig = @"
[DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool CredRead(
    string target, int type, int reservedFlag, out IntPtr credentialPtr);

[DllImport("advapi32.dll", SetLastError = true)]
public static extern bool CredFree(IntPtr cred);

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct CREDENTIAL {
    public int Flags;
    public int Type;
    public string TargetName;
    public string Comment;
    public long LastWritten;
    public int CredentialBlobSize;
    public IntPtr CredentialBlob;
    public int Persist;
    public int AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
}
"@
        if (-not ([System.Management.Automation.PSTypeName]'CredManager').Type) {
            Add-Type -MemberDefinition $sig -Namespace "Win32" -Name "CredManager"
        }

        $credPtr = [IntPtr]::Zero
        # Type 1 = CRED_TYPE_GENERIC
        $success = [Win32.CredManager]::CredRead($Target, 1, 0, [ref]$credPtr)

        if ($success -and $credPtr -ne [IntPtr]::Zero) {
            $cred = [System.Runtime.InteropServices.Marshal]::PtrToStructure(
                $credPtr, [Type][Win32.CredManager+CREDENTIAL]
            )
            $password = [System.Runtime.InteropServices.Marshal]::PtrToStringUni(
                $cred.CredentialBlob, $cred.CredentialBlobSize / 2
            )
            [Win32.CredManager]::CredFree($credPtr) | Out-Null

            return @{
                User     = $cred.UserName
                Password = $password
            }
        }
    }
    catch {
        Write-Verbose "P/Invoke credential read failed: $_"
    }

    return $null
}

#endregion

#region IMAP Client

function Connect-ImapServer {
    param(
        [string]$Server,
        [int]$Port,
        [string]$User,
        [string]$Password
    )

    $tcpClient = [System.Net.Sockets.TcpClient]::new($Server, $Port)
    $sslStream = [System.Net.Security.SslStream]::new(
        $tcpClient.GetStream(), $false
    )
    $sslStream.AuthenticateAsClient($Server)

    $reader = [System.IO.StreamReader]::new($sslStream)
    $writer = [System.IO.StreamWriter]::new($sslStream)
    $writer.AutoFlush = $true

    # Read greeting
    $greeting = $reader.ReadLine()
    Write-Verbose "Server: $greeting"

    $context = @{
        Reader = $reader
        Writer = $writer
        Stream = $sslStream
        Client = $tcpClient
        TagNum = 1
    }

    # LOGIN
    $tag = "A$($context.TagNum)"
    $context.TagNum++
    $writer.WriteLine("$tag LOGIN `"$User`" `"$Password`"")

    $response = ""
    do {
        $line = $reader.ReadLine()
        $response += $line + "`n"
    } while ($line -and -not $line.StartsWith($tag))

    if ($response -match 'NO|BAD') {
        throw "IMAP LOGIN failed. Check your credentials. Response: $response"
    }

    Write-Verbose "Logged in successfully."
    return $context
}

function Send-ImapCommand {
    param($Context, [string]$Command)

    $tag = "A$($Context.TagNum)"
    $Context.TagNum++
    $Context.Writer.WriteLine("$tag $Command")

    $lines = @()
    do {
        $line = $Context.Reader.ReadLine()
        $lines += $line
    } while ($line -and -not $line.StartsWith($tag))

    return $lines
}

function Disconnect-ImapServer {
    param($Context)
    try {
        Send-ImapCommand -Context $Context -Command "LOGOUT" | Out-Null
    } catch {}
    try { $Context.Reader.Dispose() } catch {}
    try { $Context.Writer.Dispose() } catch {}
    try { $Context.Stream.Dispose() } catch {}
    try { $Context.Client.Dispose() } catch {}
}

#endregion

#region Main

Write-Host ""
Write-Host "=== Gmail Email Checker ===" -ForegroundColor Cyan
Write-Host ""

# Get credentials
$creds = Get-GmailCredentials -Target $TargetName

if (-not $creds) {
    Write-Host "❌ No Gmail credentials found." -ForegroundColor Red
    Write-Host ""
    Write-Host "To set up Gmail access:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Enable IMAP in Gmail Settings:" -ForegroundColor White
    Write-Host "     https://mail.google.com/mail/u/0/#settings/fwdandpop"
    Write-Host ""
    Write-Host "  2. Enable 2-Step Verification:" -ForegroundColor White
    Write-Host "     https://myaccount.google.com/security"
    Write-Host ""
    Write-Host "  3. Generate an App Password:" -ForegroundColor White
    Write-Host "     https://myaccount.google.com/apppasswords"
    Write-Host ""
    Write-Host "  4. Run the setup script:" -ForegroundColor White
    Write-Host "     pwsh scripts/setup-email-credentials.ps1"
    Write-Host ""
    Write-Host "  OR set environment variables:" -ForegroundColor White
    Write-Host '     $env:GMAIL_USER = "your-email@gmail.com"'
    Write-Host '     $env:GMAIL_APP_PASSWORD = "your-app-password"'
    Write-Host ""
    Write-Host "Full guide: .squad/skills/personal-email-access/SKILL.md" -ForegroundColor Gray
    exit 1
}

Write-Host "📧 Account: $($creds.User)" -ForegroundColor Gray
Write-Host "📥 Fetching last $Last emails..." -ForegroundColor Gray
if ($Search) { Write-Host "🔍 Search filter: '$Search'" -ForegroundColor Gray }
if ($From)   { Write-Host "👤 From filter: '$From'" -ForegroundColor Gray }
Write-Host ""

try {
    $ctx = Connect-ImapServer -Server "imap.gmail.com" -Port 993 `
        -User $creds.User -Password $creds.Password

    # Select INBOX
    $selectResult = Send-ImapCommand -Context $ctx -Command 'SELECT INBOX'
    $existsLine = $selectResult | Where-Object { $_ -match '\* (\d+) EXISTS' }
    $totalMessages = 0
    if ($existsLine -match '\* (\d+) EXISTS') {
        $totalMessages = [int]$Matches[1]
    }
    Write-Host "📬 Inbox contains $totalMessages messages." -ForegroundColor Gray
    Write-Host ""

    if ($totalMessages -eq 0) {
        Write-Host "No messages in inbox."
        Disconnect-ImapServer -Context $ctx
        exit 0
    }

    # Build IMAP SEARCH command
    $searchParts = @("ALL")
    if ($From) {
        $searchParts = @("FROM `"$From`"")
    }

    $searchCmd = "SEARCH $($searchParts -join ' ')"
    $searchResult = Send-ImapCommand -Context $ctx -Command $searchCmd
    $uidLine = ($searchResult | Where-Object { $_ -match '^\* SEARCH' }) -replace '^\* SEARCH\s*', ''
    $uids = @($uidLine.Trim().Split(' ', [StringSplitOptions]::RemoveEmptyEntries))

    if ($uids.Count -eq 0 -or ($uids.Count -eq 1 -and [string]::IsNullOrWhiteSpace($uids[0]))) {
        Write-Host "No matching messages found." -ForegroundColor Yellow
        Disconnect-ImapServer -Context $ctx
        exit 0
    }

    # Take the last N message IDs (most recent)
    $recentUids = $uids | Select-Object -Last $Last

    $matchCount = 0
    foreach ($uid in $recentUids) {
        if ([string]::IsNullOrWhiteSpace($uid)) { continue }

        # Fetch headers and a snippet
        $fetchResult = Send-ImapCommand -Context $ctx -Command "FETCH $uid (BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])"
        $headerText = ($fetchResult | Where-Object { $_ -notmatch '^A\d+|^\*.*FETCH|\)$|^\s*$' }) -join "`n"

        $subjectMatch = ""
        $fromMatch = ""
        $dateMatch = ""

        if ($headerText -match 'Subject:\s*(.+)') { $subjectMatch = $Matches[1].Trim() }
        if ($headerText -match 'From:\s*(.+)') { $fromMatch = $Matches[1].Trim() }
        if ($headerText -match 'Date:\s*(.+)') { $dateMatch = $Matches[1].Trim() }

        # Apply text search filter on subject
        if ($Search -and $subjectMatch -notmatch [regex]::Escape($Search)) {
            # Also check body snippet
            $bodyResult = Send-ImapCommand -Context $ctx -Command "FETCH $uid (BODY.PEEK[TEXT]<0.500>)"
            $bodyText = ($bodyResult | Where-Object { $_ -notmatch '^A\d+|^\*.*FETCH|\)$' }) -join " "
            if ($bodyText -notmatch [regex]::Escape($Search)) {
                continue
            }
        }

        $matchCount++
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "  From:    $fromMatch" -ForegroundColor White
        Write-Host "  Subject: $subjectMatch" -ForegroundColor Cyan
        Write-Host "  Date:    $dateMatch" -ForegroundColor Gray
    }

    if ($matchCount -eq 0) {
        Write-Host "No emails matching your filters." -ForegroundColor Yellow
    }
    else {
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Found $matchCount matching email(s)." -ForegroundColor Green
    }

    Disconnect-ImapServer -Context $ctx
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Yellow
    Write-Host "  - Regenerate App Password at https://myaccount.google.com/apppasswords"
    Write-Host "  - Enable IMAP in Gmail settings"
    Write-Host "  - Check your network/firewall allows port 993"
    exit 1
}

#endregion
