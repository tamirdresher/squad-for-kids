<#
.SYNOPSIS
    Resolves the Teams Incoming Webhook URL for a given channel key.

.DESCRIPTION
    Looks up channel-specific webhook URL files at:
      $env:USERPROFILE\.squad\teams-webhooks\{ChannelKey}.url
    Falls back to the legacy general webhook at:
      $env:USERPROFILE\.squad\teams-webhook.url

.PARAMETER ChannelKey
    Channel key matching a key in .squad/teams-channels.json (e.g., "alerts", "wins", "tech-news").

.OUTPUTS
    [string] The webhook URL, or $null if none found.

.EXAMPLE
    . .\scripts\Get-ChannelWebhookUrl.ps1
    $url = Get-ChannelWebhookUrl -ChannelKey "alerts"
#>
function Get-ChannelWebhookUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ChannelKey = "general"
    )

    $webhooksDir = Join-Path $env:USERPROFILE ".squad\teams-webhooks"
    $legacyFile  = Join-Path $env:USERPROFILE ".squad\teams-webhook.url"

    # 1. Try channel-specific webhook file
    if ($ChannelKey) {
        $channelFile = Join-Path $webhooksDir "$ChannelKey.url"
        if (Test-Path $channelFile) {
            $url = (Get-Content $channelFile -Raw -Encoding utf8).Trim()
            if (-not [string]::IsNullOrWhiteSpace($url)) {
                Write-Verbose "Using channel-specific webhook for '$ChannelKey': $channelFile"
                return $url
            }
        }
    }

    # 2. Try general channel webhook file
    if ($ChannelKey -ne "general") {
        $generalFile = Join-Path $webhooksDir "general.url"
        if (Test-Path $generalFile) {
            $url = (Get-Content $generalFile -Raw -Encoding utf8).Trim()
            if (-not [string]::IsNullOrWhiteSpace($url)) {
                Write-Verbose "Channel '$ChannelKey' webhook not found, using general: $generalFile"
                return $url
            }
        }
    }

    # 3. Fall back to legacy single-webhook file
    if (Test-Path $legacyFile) {
        $url = (Get-Content $legacyFile -Raw -Encoding utf8).Trim()
        if (-not [string]::IsNullOrWhiteSpace($url)) {
            Write-Verbose "Using legacy webhook file: $legacyFile"
            return $url
        }
    }

    Write-Verbose "No webhook URL found for channel '$ChannelKey'"
    return $null
}
