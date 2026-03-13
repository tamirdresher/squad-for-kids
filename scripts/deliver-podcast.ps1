#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deliver a generated podcast: OneDrive upload, email attachment, Teams notification.

.DESCRIPTION
    Three-phase delivery pipeline for podcast audio files:
      Phase 1 — Copy to OneDrive sync folder for cloud access
      Phase 2 — Send email with file attachment via agency MCP mail (Graph API fallback)
      Phase 3 — Post Teams webhook MessageCard with "Download Podcast" button

    Each phase is independent — a failure in one does not block the others.

.PARAMETER AudioFile
    Path to the podcast audio file (MP3 or WAV).

.PARAMETER Title
    Podcast title for notifications. Derived from filename if omitted.

.PARAMETER Recipient
    Email address to deliver to. Default: tamirdresher@microsoft.com

.PARAMETER TeamsWebhookFile
    Path to file containing the Teams incoming-webhook URL.

.PARAMETER OneDrivePath
    Relative path within OneDrive sync folder. Default: Squad/Podcasts

.PARAMETER AgencyBin
    Path to the agency binary for MCP mail/sharepoint calls.

.PARAMETER SkipEmail
    Skip the email delivery phase.

.PARAMETER SkipTeams
    Skip the Teams notification phase.

.PARAMETER SkipOneDrive
    Skip the OneDrive upload phase.

.PARAMETER DryRun
    Log what would happen without actually sending anything.

.EXAMPLE
    .\deliver-podcast.ps1 -AudioFile "RESEARCH_REPORT-audio.mp3"

.EXAMPLE
    .\deliver-podcast.ps1 -AudioFile "podcast.wav" -Title "Weekly Briefing" -DryRun
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$AudioFile,

    [string]$Title,
    [string]$Recipient = "tamirdresher@microsoft.com",
    [string]$TeamsWebhookFile = "$env:USERPROFILE\.squad\teams-webhook.url",
    [string]$OneDrivePath = "Squad/Podcasts",
    [string]$AgencyBin = "C:\.Tools\agency\CurrentVersion\agency.exe",
    [switch]$SkipEmail,
    [switch]$SkipTeams,
    [switch]$SkipOneDrive,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================================
# HELPERS
# ============================================================================

function Format-PodcastTitle {
    param([string]$FileName)
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $stem = $stem -replace '[-_](audio|podcast)$', ''
    $stem = $stem -replace '\.podcast-script$', ''
    $stem = $stem -replace '[-_]', ' '
    return (Get-Culture).TextInfo.ToTitleCase($stem.ToLower())
}

function Invoke-AgencyMcp {
    <#
    .SYNOPSIS
        Call a single tool on an agency MCP server via stdio JSON-RPC 2.0.
        Performs the initialize → notifications/initialized → tools/call handshake.
    #>
    param(
        [Parameter(Mandatory)][string]$McpType,
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)][hashtable]$Arguments,
        [string]$Binary = "C:\.Tools\agency\CurrentVersion\agency.exe",
        [int]$TimeoutMs = 60000
    )

    Write-Host "    MCP → agency $McpType / $ToolName" -ForegroundColor Gray

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Binary
    $psi.Arguments = "mcp $McpType"
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        # 1 — initialize
        $initReq = @{
            jsonrpc = "2.0"; id = 1; method = "initialize"
            params = @{
                protocolVersion = "2024-11-05"
                capabilities    = @{}
                clientInfo      = @{ name = "deliver-podcast"; version = "1.0" }
            }
        } | ConvertTo-Json -Depth 10 -Compress

        $proc.StandardInput.WriteLine($initReq)
        $proc.StandardInput.Flush()

        $initTask = $proc.StandardOutput.ReadLineAsync()
        if (-not $initTask.Wait($TimeoutMs)) { throw "MCP initialize timed out" }
        $initResp = $initTask.Result
        if (-not $initResp) { throw "MCP server returned empty initialize response" }

        # 2 — initialized notification
        $proc.StandardInput.WriteLine('{"jsonrpc":"2.0","method":"notifications/initialized"}')
        $proc.StandardInput.Flush()

        # 3 — call tool
        $callReq = @{
            jsonrpc = "2.0"; id = 2; method = "tools/call"
            params = @{ name = $ToolName; arguments = $Arguments }
        } | ConvertTo-Json -Depth 10 -Compress

        $proc.StandardInput.WriteLine($callReq)
        $proc.StandardInput.Flush()

        $resultTask = $proc.StandardOutput.ReadLineAsync()
        if (-not $resultTask.Wait($TimeoutMs)) { throw "MCP tool/call timed out after $($TimeoutMs / 1000)s" }
        $resultLine = $resultTask.Result

        $proc.StandardInput.Close()
        $proc.WaitForExit(5000) | Out-Null

        if ($resultLine) { return ($resultLine | ConvertFrom-Json) }
        return $null
    }
    finally {
        if (-not $proc.HasExited) { try { $proc.Kill() } catch {} }
        $proc.Dispose()
    }
}

function Send-EmailViaGraphCli {
    <#
    .SYNOPSIS
        Fallback: send email via Microsoft Graph REST API using an az-CLI token.
    #>
    param(
        [string]$To,
        [string]$Subject,
        [string]$BodyHtml,
        [string]$AttachmentPath   # $null = no attachment
    )

    $token = (az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv 2>$null)
    if (-not $token) { throw "Cannot obtain Graph API token via az CLI (run 'az login' first)" }

    $attachments = @()
    if ($AttachmentPath -and (Test-Path $AttachmentPath)) {
        $bytes = [System.IO.File]::ReadAllBytes($AttachmentPath)
        $contentType = if ($AttachmentPath -match '\.wav$') { "audio/wav" } else { "audio/mpeg" }
        $attachments += @{
            "@odata.type" = "#microsoft.graph.fileAttachment"
            name          = [System.IO.Path]::GetFileName($AttachmentPath)
            contentType   = $contentType
            contentBytes  = [Convert]::ToBase64String($bytes)
        }
    }

    $payload = @{
        message = @{
            subject      = $Subject
            body         = @{ contentType = "HTML"; content = $BodyHtml }
            toRecipients = @( @{ emailAddress = @{ address = $To } } )
        }
    }
    if ($attachments.Count -gt 0) { $payload.message.attachments = $attachments }

    $json = $payload | ConvertTo-Json -Depth 10
    $headers = @{
        Authorization  = "Bearer $token"
        "Content-Type" = "application/json; charset=utf-8"
    }

    Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/sendMail" `
        -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($json))
}

# ============================================================================
# MAIN
# ============================================================================

Write-Host ""
Write-Host "=== Podcast Delivery ===" -ForegroundColor Magenta

# ── Validate ───────────────────────────────────────────────────────────────
$audioPath = Resolve-Path $AudioFile -ErrorAction Stop
$fileInfo   = Get-Item $audioPath
$fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
$fileName   = $fileInfo.Name

if (-not $Title) { $Title = Format-PodcastTitle $fileName }

Write-Host "  File:      $fileName ($fileSizeMB MB)"
Write-Host "  Title:     $Title"
Write-Host "  Recipient: $Recipient"
if ($DryRun) { Write-Host "  MODE:      DRY RUN" -ForegroundColor Yellow }
Write-Host ""

$shareLink   = $null
$results     = @()
$emailSentOk = $false
$emailHadAttachment = $false

# ── Phase 1: OneDrive Upload ──────────────────────────────────────────────

if (-not $SkipOneDrive) {
    Write-Host "[Phase 1] OneDrive Upload" -ForegroundColor Cyan
    try {
        $odRoot = @(
            $env:OneDrive,
            $env:OneDriveCommercial,
            "$env:USERPROFILE\OneDrive",
            "$env:USERPROFILE\OneDrive - Microsoft"
        ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

        if (-not $odRoot) { throw "OneDrive sync folder not found on this machine" }

        $destDir = Join-Path $odRoot $OneDrivePath
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        $destFile = Join-Path $destDir $fileName

        if ($DryRun) {
            Write-Host "  [DRY RUN] Would copy to: $destFile" -ForegroundColor Yellow
        } else {
            Copy-Item -Path $audioPath -Destination $destFile -Force
            Write-Host "  Copied to OneDrive: $destFile" -ForegroundColor Green
        }

        # Best-effort share URL (OneDrive will sync; user can right-click → Share for exact link)
        $relEncoded = ($OneDrivePath + "/" + $fileName) -replace ' ', '%20'
        $shareLink = "https://microsoft-my.sharepoint.com/personal/tamirdresher_microsoft_com/Documents/$relEncoded"

        $results += "OneDrive: OK"
    }
    catch {
        Write-Host "  OneDrive failed: $($_.Exception.Message)" -ForegroundColor Yellow
        $results += "OneDrive: FAILED"
    }
    Write-Host ""
}

# ── Phase 1b: SharePoint MCP Upload (fallback) ───────────────────────────
# If OneDrive sync failed, try uploading via agency SharePoint MCP to get a
# real sharing link. This ensures the Teams card always has a download button.

if (-not $shareLink -and -not $SkipOneDrive -and -not $DryRun -and (Test-Path $AgencyBin)) {
    Write-Host "[Phase 1b] SharePoint MCP Upload (fallback)" -ForegroundColor Cyan
    try {
        # Upload to user's OneDrive via SharePoint MCP
        $bytes = [System.IO.File]::ReadAllBytes($audioPath)
        $b64 = [Convert]::ToBase64String($bytes)
        $contentType = if ($fileName -match '\.wav$') { "audio/wav" } else { "audio/mpeg" }

        $uploadResult = Invoke-AgencyMcp -McpType "sharepoint" `
            -ToolName "createSmallBinaryFile" `
            -Arguments @{
                filename          = $fileName
                base64Content     = $b64
                documentLibraryId = "me"
            } `
            -Binary $AgencyBin -TimeoutMs 120000

        if ($uploadResult -and $uploadResult.result -and -not $uploadResult.error) {
            # Extract file metadata from result
            $content = $uploadResult.result.content
            if ($content -and $content.Count -gt 0) {
                $respText = ($content | ForEach-Object { $_.text }) -join ""
                if ($respText -match '"webUrl"\s*:\s*"([^"]+)"') {
                    $shareLink = $Matches[1]
                    Write-Host "  SharePoint upload OK: $shareLink" -ForegroundColor Green
                    $results += "SharePoint MCP: OK"
                } else {
                    Write-Host "  SharePoint upload succeeded but no webUrl in response" -ForegroundColor Yellow
                    $results += "SharePoint MCP: PARTIAL"
                }
            }
        } else {
            $errMsg = if ($uploadResult.error) { $uploadResult.error.message } else { "unknown" }
            throw "SharePoint MCP error: $errMsg"
        }
    }
    catch {
        Write-Host "  SharePoint MCP failed: $($_.Exception.Message)" -ForegroundColor Yellow
        $results += "SharePoint MCP: FAILED"
    }
    Write-Host ""
}

# ── Phase 2: Email Delivery ───────────────────────────────────────────────

if (-not $SkipEmail) {
    Write-Host "[Phase 2] Email Delivery" -ForegroundColor Cyan

    # Attach file only if under 25 MB (standard email limit)
    $maxAttachMB = 25
    $attachPath = if ($fileSizeMB -le $maxAttachMB) { [string]$audioPath } else { $null }

    # Build HTML body
    $bodyLines = @("<h2>&#127897; Podcast Ready: $Title</h2>")
    if ($attachPath) {
        $bodyLines += "<p>Your podcast (<strong>$fileSizeMB MB</strong>) is attached to this email.</p>"
    } else {
        $bodyLines += "<p>Your podcast (<strong>$fileSizeMB MB</strong>) is too large to attach directly.</p>"
    }
    if ($shareLink) {
        $bodyLines += "<p>&#128194; <a href=`"$shareLink`">Open in OneDrive</a></p>"
    }
    $bodyLines += "<hr><p style='color:#888;font-size:0.85em'>Generated by Squad Podcaster &middot; $(Get-Date -Format 'yyyy-MM-dd HH:mm')</p>"
    $bodyHtml = $bodyLines -join "`n"
    $subject = "Podcast Ready: $Title"

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would email $Recipient" -ForegroundColor Yellow
        Write-Host "    Subject: $subject" -ForegroundColor Yellow
        Write-Host "    Attach:  $(if ($attachPath) { $fileName } else { '(link only — file too large)' })" -ForegroundColor Yellow
        $results += "Email: DRY RUN"
    } else {
        $emailSent = $false

        # ── Try 1: agency MCP mail ────────────────────────────────────
        if ((Test-Path $AgencyBin) -and (-not $emailSent)) {
            try {
                Write-Host "  Trying agency MCP mail..." -ForegroundColor Gray
                $mcpArgs = @{
                    to      = $Recipient
                    subject = $subject
                    body    = $bodyHtml
                    isHtml  = "true"
                }
                if ($attachPath) {
                    $bytes = [System.IO.File]::ReadAllBytes($attachPath)
                    $mcpArgs["attachments"] = @(@{
                        name         = $fileName
                        contentType  = $(if ($fileName -match '\.wav$') { "audio/wav" } else { "audio/mpeg" })
                        contentBytes = [Convert]::ToBase64String($bytes)
                    })
                }

                $mcpResult = Invoke-AgencyMcp -McpType "mail" -ToolName "send_email" `
                    -Arguments $mcpArgs -Binary $AgencyBin -TimeoutMs 90000

                if ($mcpResult -and -not $mcpResult.error) {
                    Write-Host "  Email sent via agency MCP mail" -ForegroundColor Green
                    $emailSent = $true
                    $results += "Email: OK (agency MCP)"
                } else {
                    $errMsg = if ($mcpResult.error) { $mcpResult.error.message } else { "unknown" }
                    throw "MCP returned error: $errMsg"
                }
            }
            catch {
                Write-Host "  Agency MCP mail failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        # ── Try 2: Graph API via az CLI ───────────────────────────────
        if (-not $emailSent) {
            try {
                Write-Host "  Trying Graph API via az CLI..." -ForegroundColor Gray
                Send-EmailViaGraphCli -To $Recipient -Subject $subject `
                    -BodyHtml $bodyHtml -AttachmentPath $attachPath
                Write-Host "  Email sent via Graph API" -ForegroundColor Green
                $emailSent = $true
                $results += "Email: OK (Graph API)"
            }
            catch {
                Write-Host "  Graph API failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        if (-not $emailSent) {
            Write-Host "  Email delivery failed (all methods exhausted)" -ForegroundColor Yellow
            $results += "Email: FAILED"
        } else {
            $emailSentOk = $true
            $emailHadAttachment = [bool]$attachPath
        }
    }
    Write-Host ""
}

# ── Phase 3: Teams Notification ───────────────────────────────────────────

if (-not $SkipTeams) {
    Write-Host "[Phase 3] Teams Notification" -ForegroundColor Cyan
    try {
        if (-not (Test-Path $TeamsWebhookFile)) {
            throw "Webhook URL file not found: $TeamsWebhookFile"
        }
        $webhookUrl = (Get-Content $TeamsWebhookFile -Raw -Encoding utf8).Trim()
        if ([string]::IsNullOrWhiteSpace($webhookUrl)) { throw "Webhook URL file is empty" }

        # Build O365 Connector MessageCard (reliable for incoming webhooks)
        $actions = @()
        if ($shareLink) {
            $actions += @{
                "@type"  = "OpenUri"
                name     = "Download Podcast"
                targets  = @( @{ os = "default"; uri = $shareLink } )
            }
        }
        if ($emailSentOk -and $emailHadAttachment) {
            $actions += @{
                "@type"  = "OpenUri"
                name     = "Open Email (attachment)"
                targets  = @( @{ os = "default"; uri = "https://outlook.office.com/mail/" } )
            }
        }

        # Build delivery status summary
        $deliveryNote = if ($shareLink -and $emailSentOk) {
            "OneDrive link + email attachment"
        } elseif ($shareLink) {
            "OneDrive link (email skipped or failed)"
        } elseif ($emailSentOk -and $emailHadAttachment) {
            "Email with file attached"
        } elseif ($emailSentOk) {
            "Email sent (file too large to attach — link only)"
        } else {
            "No delivery method succeeded — file is on the build machine only"
        }

        $facts = @(
            @{ name = "File";      value = $fileName }
            @{ name = "Size";      value = "$fileSizeMB MB" }
            @{ name = "Delivery";  value = $deliveryNote }
            @{ name = "Generated"; value = (Get-Date -Format "yyyy-MM-dd HH:mm") }
        )

        $card = @{
            "@type"         = "MessageCard"
            "@context"      = "http://schema.org/extensions"
            themeColor      = "6264A7"
            summary         = "Podcast Ready: $Title"
            sections        = @(
                @{
                    activityTitle    = "Podcast Ready"
                    activitySubtitle = $Title
                    activityImage    = "https://img.icons8.com/fluency/48/podcast.png"
                    facts            = $facts
                    markdown         = $true
                }
            )
            potentialAction = $actions
        }

        if ($DryRun) {
            Write-Host "  [DRY RUN] Would post Teams card:" -ForegroundColor Yellow
            $card | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor Gray
            $results += "Teams: DRY RUN"
        } else {
            $body = $card | ConvertTo-Json -Depth 10 -Compress
            Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body `
                -ContentType "application/json; charset=utf-8" | Out-Null
            Write-Host "  Teams notification posted" -ForegroundColor Green
            $results += "Teams: OK"
        }
    }
    catch {
        Write-Host "  Teams failed: $($_.Exception.Message)" -ForegroundColor Yellow
        $results += "Teams: FAILED"
    }
    Write-Host ""
}

# ── Summary ────────────────────────────────────────────────────────────────

Write-Host "=== Delivery Summary ===" -ForegroundColor Magenta
$anyFailed = $false
foreach ($r in $results) {
    if ($r -match "OK|DRY") {
        Write-Host "  $r" -ForegroundColor Green
    } elseif ($r -match "FAIL") {
        Write-Host "  $r" -ForegroundColor Red
        $anyFailed = $true
    } else {
        Write-Host "  $r" -ForegroundColor Yellow
    }
}
Write-Host ""

# Exit 0 even on partial failure — delivery is best-effort and should not
# break the podcast generation pipeline.
exit 0
