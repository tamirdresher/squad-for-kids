<#
.SYNOPSIS
    Exports a WhatsApp Monitor browser session to a portable encrypted archive.

.DESCRIPTION
    Packs the Chromium persistent-context directory used by WhatsAppMonitor.Demo
    into a zip, optionally encrypts it with AES-256-GCM, Base64-encodes the
    result, and either prints the value or writes it directly to a GitHub secret.

    The exported blob is safe to store as WA_MONITOR_SESSION (GitHub secret or
    env var) and can be restored on any machine using wa-session-import.ps1.

.PARAMETER ProfileDir
    Path to the Chromium user-data directory.
    Defaults to %LOCALAPPDATA%\WhatsAppMonitor\profile.

.PARAMETER EncryptionKey
    A 32-byte AES-256 key as a Base64 string (44 chars).
    Falls back to the WA_SESSION_KEY environment variable.
    If neither is set, the archive is NOT encrypted.

.PARAMETER GhSecret
    When present, uploads the blob directly to GitHub as secret WA_MONITOR_SESSION.
    Requires the 'gh' CLI with secrets:write permission.

.PARAMETER Repo
    GitHub repository (owner/repo) for -GhSecret.
    Defaults to tamirdresher_microsoft/tamresearch1.

.PARAMETER OutFile
    When specified, writes the Base64 blob to this file path instead of stdout.

.EXAMPLE
    # Export and upload to GitHub secret
    .\wa-session-export.ps1 -GhSecret

.EXAMPLE
    # Export with AES-256-GCM encryption to file
    $env:WA_SESSION_KEY = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    .\wa-session-export.ps1 -OutFile session.b64

.NOTES
    - NEVER commit the exported blob or the WA_SESSION_KEY to source control.
    - Stop all running monitor instances before exporting.
    - Only ONE WhatsApp Web connection per device is allowed at a time.
    - The Chromium profile contains localStorage acting as session token —
      treat it with the same sensitivity as a password.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $ProfileDir    = (Join-Path $env:LOCALAPPDATA "WhatsAppMonitor\profile"),
    [string] $EncryptionKey = "",
    [switch] $GhSecret,
    [string] $Repo          = "tamirdresher_microsoft/tamresearch1",
    [string] $OutFile       = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve encryption key
if ([string]::IsNullOrWhiteSpace($EncryptionKey)) {
    $EncryptionKey = if ($env:WA_SESSION_KEY) { $env:WA_SESSION_KEY } else { "" }
}
$useEncryption = -not [string]::IsNullOrWhiteSpace($EncryptionKey)

if ($useEncryption) {
    try {
        $keyBytes = [Convert]::FromBase64String($EncryptionKey)
        if ($keyBytes.Length -ne 32) { throw "Key must be 32 bytes. Got $($keyBytes.Length)." }
    } catch {
        Write-Error "Invalid WA_SESSION_KEY: $_"; exit 1
    }
} else {
    Write-Warning "No encryption key. Archive will be plain Base64. Set WA_SESSION_KEY for encrypted export."
}

if (-not (Test-Path $ProfileDir)) {
    Write-Error "Profile not found: $ProfileDir`nRun monitor once and complete QR scan first."; exit 1
}
Write-Host "Exporting session from: $ProfileDir"

$tmpZip = [IO.Path]::GetTempFileName() + ".zip"
try {
    $excludeDirs  = @("Cache","Code Cache","GPUCache","ShaderCache","blob_storage")
    $excludeFiles = @("*.log","*.tmp","Lock","SingletonLock","SingletonCookie","SingletonSocket","CrashpadMetrics*")

    $tmpCopy = Join-Path ([IO.Path]::GetTempPath()) ("wa-profile-" + [Guid]::NewGuid().ToString("N"))
    Copy-Item -Path $ProfileDir -Destination $tmpCopy -Recurse -Force

    foreach ($d in $excludeDirs) {
        Get-ChildItem -Path $tmpCopy -Recurse -Directory -Filter $d -EA SilentlyContinue |
            Remove-Item -Recurse -Force -EA SilentlyContinue
    }
    foreach ($f in $excludeFiles) {
        Get-ChildItem -Path $tmpCopy -Recurse -File -Filter $f -EA SilentlyContinue |
            Remove-Item -Force -EA SilentlyContinue
    }

    Compress-Archive -Path (Join-Path $tmpCopy "*") -DestinationPath $tmpZip -Force
    Remove-Item $tmpCopy -Recurse -Force

    $zipBytes = [IO.File]::ReadAllBytes($tmpZip)
    Write-Host "Zipped: $([Math]::Round($zipBytes.Length/1KB,1)) KB"

    if ($useEncryption) {
        $nonce = [byte[]]::new(12); $tag = [byte[]]::new(16); $cipher = [byte[]]::new($zipBytes.Length)
        [Security.Cryptography.RandomNumberGenerator]::Fill($nonce)
        $aes = [Security.Cryptography.AesGcm]::new([byte[]]$keyBytes, 16)
        try { $aes.Encrypt($nonce, $zipBytes, $cipher, $tag) } finally { $aes.Dispose() }

        $magic = [Text.Encoding]::ASCII.GetBytes("WAGC")
        $payload = [byte[]]::new(4+12+16+$cipher.Length)
        [Buffer]::BlockCopy($magic,  0,$payload, 0, 4)
        [Buffer]::BlockCopy($nonce,  0,$payload, 4,12)
        [Buffer]::BlockCopy($tag,    0,$payload,16,16)
        [Buffer]::BlockCopy($cipher, 0,$payload,32,$cipher.Length)
        $blob = [Convert]::ToBase64String($payload)
        Write-Host "Encrypted payload: $([Math]::Round($payload.Length/1KB,1)) KB"
    } else {
        $blob = [Convert]::ToBase64String($zipBytes)
    }

    if ($GhSecret) {
        if (-not (Get-Command gh -EA SilentlyContinue)) {
            Write-Error "'gh' CLI not found."; exit 1
        }
        Write-Host "Writing to GitHub secret WA_MONITOR_SESSION on $Repo ..."
        $blob | gh secret set WA_MONITOR_SESSION --repo $Repo --body -
        Write-Host "SUCCESS: GitHub secret WA_MONITOR_SESSION updated."
    } elseif (-not [string]::IsNullOrWhiteSpace($OutFile)) {
        [IO.File]::WriteAllText($OutFile, $blob)
        Write-Host "SUCCESS: Blob written to: $OutFile"
    } else {
        Write-Warning "No -Repo or -OutFile specified."
        Write-Warning "Use -OutFile <path> to write the session blob to a file, or -Repo to upload directly to GitHub Secrets."
        Write-Warning "Printing session credentials to stdout is disabled to prevent credential leakage in CI logs."
        Write-Host "Example: scripts/wa-session-export.ps1 -OutFile session.b64"
        Write-Host "Example: scripts/wa-session-export.ps1 -Repo tamirdresher_microsoft/tamresearch1"
        exit 1
    }
} finally {
    if (Test-Path $tmpZip) { Remove-Item $tmpZip -Force }
}
