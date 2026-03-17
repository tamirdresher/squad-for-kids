<#
.SYNOPSIS
    Sets up per-channel Teams Incoming Webhook URL files for the Squad notification system.

.DESCRIPTION
    Creates the ~/.squad/teams-webhooks/ directory and validates that webhook URLs
    are configured for each channel defined in .squad/teams-channels.json.

    Each channel gets its own webhook URL file at:
      $env:USERPROFILE\.squad\teams-webhooks\{channel-key}.url

    Messages posted via channel-specific webhooks appear as bot/app messages
    in Teams, not from any specific person.

.PARAMETER Validate
    Only validate existing configuration — don't prompt for missing URLs.

.EXAMPLE
    .\scripts\setup-webhooks.ps1            # Interactive setup
    .\scripts\setup-webhooks.ps1 -Validate  # Validation only

.NOTES
    Issue: #821 — Use Teams Incoming Webhooks for squad channel posts
#>
param(
    [switch]$Validate
)

$ErrorActionPreference = "Stop"

# Paths
$repoRoot     = Split-Path $PSScriptRoot -Parent
$channelsFile = Join-Path $repoRoot ".squad\teams-channels.json"
$webhooksDir  = Join-Path $env:USERPROFILE ".squad\teams-webhooks"
$legacyFile   = Join-Path $env:USERPROFILE ".squad\teams-webhook.url"

# Load channel definitions
if (-not (Test-Path $channelsFile)) {
    Write-Host "ERROR: Channel config not found: $channelsFile" -ForegroundColor Red
    exit 1
}

$channelConfig = Get-Content $channelsFile -Raw -Encoding utf8 | ConvertFrom-Json
$channels = $channelConfig.channels.PSObject.Properties

Write-Host ""
Write-Host "=== Squad Teams Webhook Setup ===" -ForegroundColor Cyan
Write-Host "Issue #821: Per-channel incoming webhooks" -ForegroundColor Gray
Write-Host ""

# Create directory
if (-not (Test-Path $webhooksDir)) {
    if ($Validate) {
        Write-Host "WARNING: Webhooks directory does not exist: $webhooksDir" -ForegroundColor Yellow
    } else {
        New-Item -ItemType Directory -Path $webhooksDir -Force | Out-Null
        Write-Host "Created: $webhooksDir" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Channel Webhook Status:" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────" -ForegroundColor Gray

$configured = 0
$missing    = 0

foreach ($ch in $channels) {
    $key  = $ch.Name
    $name = $ch.Value.name
    $use  = $ch.Value.use
    $file = Join-Path $webhooksDir "$key.url"

    if (Test-Path $file) {
        $url = (Get-Content $file -Raw -Encoding utf8).Trim()
        if (-not [string]::IsNullOrWhiteSpace($url)) {
            Write-Host "  ✅ $key" -ForegroundColor Green -NoNewline
            Write-Host " ($name)" -ForegroundColor Gray
            $configured++
            continue
        }
    }

    Write-Host "  ❌ $key" -ForegroundColor Red -NoNewline
    Write-Host " ($name) — $use" -ForegroundColor Yellow
    $missing++
}

Write-Host ""
Write-Host "Summary: $configured configured, $missing missing" -ForegroundColor $(if ($missing -eq 0) { "Green" } else { "Yellow" })

# Legacy webhook check
if (Test-Path $legacyFile) {
    $legacyUrl = (Get-Content $legacyFile -Raw -Encoding utf8).Trim()
    if (-not [string]::IsNullOrWhiteSpace($legacyUrl)) {
        Write-Host ""
        Write-Host "Legacy webhook found: $legacyFile" -ForegroundColor Gray
        Write-Host "  This is used as fallback when channel-specific webhooks are missing." -ForegroundColor Gray
    }
}

if ($Validate) {
    if ($missing -gt 0) {
        Write-Host ""
        Write-Host "Run without -Validate to set up missing webhooks." -ForegroundColor Yellow
        exit 1
    }
    exit 0
}

# Interactive setup for missing channels
if ($missing -gt 0) {
    Write-Host ""
    Write-Host "=== How to Create Incoming Webhooks ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "For each channel above marked ❌:" -ForegroundColor White
    Write-Host "  1. Open Microsoft Teams" -ForegroundColor Gray
    Write-Host "  2. Go to the target channel" -ForegroundColor Gray
    Write-Host "  3. Click '...' (More options) → Connectors / Manage channel" -ForegroundColor Gray
    Write-Host "  4. Find 'Incoming Webhook' and click Configure" -ForegroundColor Gray
    Write-Host "  5. Name it 'Squad Bot' (or similar) and optionally set an icon" -ForegroundColor Gray
    Write-Host "  6. Copy the webhook URL" -ForegroundColor Gray
    Write-Host "  7. Paste it when prompted below, or save it manually to:" -ForegroundColor Gray
    Write-Host "     $webhooksDir\{channel-key}.url" -ForegroundColor White
    Write-Host ""
    Write-Host "NOTE: Messages sent via incoming webhooks appear as bot/app" -ForegroundColor Yellow
    Write-Host "      messages, not from any specific person." -ForegroundColor Yellow
    Write-Host ""

    foreach ($ch in $channels) {
        $key  = $ch.Name
        $name = $ch.Value.name
        $file = Join-Path $webhooksDir "$key.url"

        # Skip already configured
        if (Test-Path $file) {
            $existing = (Get-Content $file -Raw -Encoding utf8).Trim()
            if (-not [string]::IsNullOrWhiteSpace($existing)) { continue }
        }

        $url = Read-Host "Webhook URL for '$key' ($name) [Enter to skip]"
        if (-not [string]::IsNullOrWhiteSpace($url)) {
            $url = $url.Trim()
            if ($url -notmatch '^https://') {
                Write-Host "  Skipped — URL must start with https://" -ForegroundColor Yellow
                continue
            }
            Set-Content -Path $file -Value $url -Encoding utf8 -NoNewline
            Write-Host "  Saved: $file" -ForegroundColor Green
        } else {
            Write-Host "  Skipped '$key'" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "Setup complete. Re-run with -Validate to check status." -ForegroundColor Green
}
