<#
.SYNOPSIS
    Imports a WhatsApp Monitor browser session from WA_MONITOR_SESSION env var.

.DESCRIPTION
    Reverses wa-session-export.ps1. Reads the Base64 blob from WA_MONITOR_SESSION,
    optionally decrypts with AES-256-GCM (key from WA_SESSION_KEY), and extracts
    the Chromium profile to the local userDataDir.

    Designed for CI/CD (GitHub Actions) and multi-machine Ralph deployments.

.PARAMETER ProfileDir
    Destination Chromium user-data directory.
    Defaults to %LOCALAPPDATA%\WhatsAppMonitor\profile.

.PARAMETER EncryptionKey
    32-byte AES-256 key as Base64. Falls back to WA_SESSION_KEY env var.

.PARAMETER SessionBlob
    Base64 blob or file path. Defaults to WA_MONITOR_SESSION env var.

.PARAMETER Force
    Overwrite existing profile without prompting.

.EXAMPLE
    # CI/CD usage — secrets injected as env vars by the runner
    .\wa-session-import.ps1 -Force

.EXAMPLE
    # Import from local file
    .\wa-session-import.ps1 -SessionBlob .\session.b64 -Force

.NOTES
    - Stop running monitor instances before importing.
    - After import, start the monitor with Headless = true.
    - If session is stale, delete profile and re-authenticate via QR on one machine.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $ProfileDir    = (Join-Path $env:LOCALAPPDATA "WhatsAppMonitor\profile"),
    [string] $EncryptionKey = "",
    [string] $SessionBlob   = "",
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve blob
if ([string]::IsNullOrWhiteSpace($SessionBlob)) {
    $SessionBlob = if ($env:WA_MONITOR_SESSION) { $env:WA_MONITOR_SESSION } else { "" }
}
if (-not [string]::IsNullOrWhiteSpace($SessionBlob) -and (Test-Path $SessionBlob -PathType Leaf)) {
    $SessionBlob = [IO.File]::ReadAllText($SessionBlob).Trim()
}
if ([string]::IsNullOrWhiteSpace($SessionBlob)) {
    Write-Error "No session blob. Set WA_MONITOR_SESSION or pass -SessionBlob."; exit 1
}

# Resolve key
if ([string]::IsNullOrWhiteSpace($EncryptionKey)) {
    $EncryptionKey = if ($env:WA_SESSION_KEY) { $env:WA_SESSION_KEY } else { "" }
}

# Decode Base64
try { $rawBytes = [Convert]::FromBase64String($SessionBlob.Trim()) }
catch { Write-Error "Failed to decode Base64: $_"; exit 1 }

# Detect AES-256-GCM encrypted blob (WAGC magic header)
$magic = [Text.Encoding]::ASCII.GetBytes("WAGC")
$isEncrypted = ($rawBytes.Length -gt 32 -and
    $rawBytes[0] -eq $magic[0] -and $rawBytes[1] -eq $magic[1] -and
    $rawBytes[2] -eq $magic[2] -and $rawBytes[3] -eq $magic[3])

if ($isEncrypted) {
    if ([string]::IsNullOrWhiteSpace($EncryptionKey)) {
        Write-Error "Blob is encrypted (WAGC header) but no key provided. Set WA_SESSION_KEY."; exit 1
    }
    try {
        $keyBytes = [Convert]::FromBase64String($EncryptionKey)
        if ($keyBytes.Length -ne 32) { throw "Key must be 32 bytes. Got $($keyBytes.Length)." }
    } catch { Write-Error "Invalid WA_SESSION_KEY: $_"; exit 1 }

    # Layout: magic(4) + nonce(12) + tag(16) + ciphertext
    $nonce      = $rawBytes[4..15]
    $tag        = $rawBytes[16..31]
    $ciphertext = $rawBytes[32..($rawBytes.Length-1)]
    $plaintext  = [byte[]]::new($ciphertext.Length)

    $aes = [Security.Cryptography.AesGcm]::new([byte[]]$keyBytes, 16)
    try { $aes.Decrypt($nonce, $ciphertext, $tag, $plaintext) }
    catch { Write-Error "Decryption failed — wrong key or corrupted blob: $_"; exit 1 }
    finally { $aes.Dispose() }

    $zipBytes = $plaintext
} else {
    if (-not [string]::IsNullOrWhiteSpace($EncryptionKey)) {
        Write-Warning "Encryption key provided but no WAGC header — treating as plain zip."
    }
    $zipBytes = $rawBytes
}

# Prepare destination
if (Test-Path $ProfileDir) {
    if (-not $Force) {
        $a = Read-Host "Profile exists at '$ProfileDir'. Overwrite? [y/N]"
        if ($a -notmatch '^[Yy]') { Write-Host "Aborted."; exit 0 }
    }
    Remove-Item $ProfileDir -Recurse -Force
}
New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null

# Extract
$tmpZip = [IO.Path]::GetTempFileName() + ".zip"
try {
    [IO.File]::WriteAllBytes($tmpZip, $zipBytes)
    Expand-Archive -Path $tmpZip -DestinationPath $ProfileDir -Force
    Write-Host "SUCCESS: Session imported to: $ProfileDir"
    Write-Host "         Start WhatsApp Monitor with Headless=true — no QR scan needed."
} catch {
    Write-Error "Failed to extract: $_"; exit 1
} finally {
    if (Test-Path $tmpZip) { Remove-Item $tmpZip -Force }
}
