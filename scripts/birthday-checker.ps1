<#
.SYNOPSIS
    Daily birthday checker for the DK8S Platform team.

.DESCRIPTION
    Checks if any DK8S Platform team member has a birthday today.
    If yes, generates a personalized birthday email with AI-researched contributions
    and sends it via Outlook COM.

.PARAMETER Test
    Test mode: pretends the first team member has a birthday today.
    Generates the email as HTML and opens it in a browser for preview.
    Does NOT send any email.

.PARAMETER TestName
    In test mode, use a specific person's name instead of the first member.

.PARAMETER BirthdayFile
    Path to the team-birthdays.json file. Defaults to .squad/team-birthdays.json.

.EXAMPLE
    # Production: run daily check
    .\birthday-checker.ps1

    # Test: preview the email template
    .\birthday-checker.ps1 -Test

    # Test with a specific person
    .\birthday-checker.ps1 -Test -TestName "Anand Kumar"
#>

[CmdletBinding()]
param(
    [switch]$Test,

    [string]$TestName,

    [string]$BirthdayFile
)

$ErrorActionPreference = "Stop"

# --- Resolve paths ---
$repoRoot = (git rev-parse --show-toplevel 2>$null) -replace '/', '\'
if (-not $repoRoot) {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

if (-not $BirthdayFile) {
    $BirthdayFile = Join-Path $repoRoot ".squad\team-birthdays.json"
}

$emailScript = Join-Path $repoRoot "scripts\birthday-email.ps1"

# --- Load team birthday data ---
if (-not (Test-Path $BirthdayFile)) {
    Write-Error "Birthday file not found: $BirthdayFile"
    exit 1
}

$birthdayData = Get-Content $BirthdayFile -Raw | ConvertFrom-Json
$members = $birthdayData.members

Write-Host "🎂 DK8S Platform Birthday Checker" -ForegroundColor Magenta
Write-Host "=================================" -ForegroundColor Magenta
Write-Host "Team: $($birthdayData.team)" -ForegroundColor Cyan
Write-Host "Members loaded: $($members.Count)" -ForegroundColor Cyan

# --- Determine today's date (MM-DD format) ---
$today = (Get-Date).ToString("MM-dd")
Write-Host "Today's date: $today" -ForegroundColor Yellow

# --- Find birthday matches ---
$birthdayPeople = @()

if ($Test) {
    Write-Host ""
    Write-Host "🧪 TEST MODE — Simulating a birthday" -ForegroundColor Yellow
    Write-Host ""

    if ($TestName) {
        $testMember = $members | Where-Object { $_.name -eq $TestName }
        if (-not $testMember) {
            Write-Error "Member '$TestName' not found in birthday registry."
            exit 1
        }
        $birthdayPeople = @($testMember)
    }
    else {
        # Pick the first member with a non-placeholder birthday, or just the first member
        $birthdayPeople = @($members[0])
    }

    Write-Host "Simulating birthday for: $($birthdayPeople[0].name)" -ForegroundColor Green
}
else {
    # Production mode — check actual dates
    $birthdayPeople = @($members | Where-Object { $_.birthday -eq $today })

    if ($birthdayPeople.Count -eq 0) {
        Write-Host ""
        Write-Host "No birthdays today. 📅" -ForegroundColor Gray
        exit 0
    }
}

# --- Process each birthday person ---
foreach ($person in $birthdayPeople) {
    Write-Host ""
    Write-Host "🎉 Birthday detected: $($person.name) ($($person.role))" -ForegroundColor Green
    Write-Host "   Alias: $($person.alias)" -ForegroundColor Cyan

    # --- Build CC list (all other team members) ---
    $ccAddresses = @()
    foreach ($member in $members) {
        if ($member.alias -ne $person.alias) {
            $ccAddresses += "$($member.alias)@microsoft.com"
        }
    }
    $ccList = $ccAddresses -join ";"

    # --- Research contributions (placeholder for WorkIQ integration) ---
    # In production, this would call WorkIQ to research the person's recent work.
    # For now, we use curated defaults per role.
    $contributions = @()

    switch -Wildcard ($person.role) {
        "*Manager*" {
            $contributions = @(
                "Leading the DK8S Platform team with vision and empathy",
                "Driving strategic technical decisions that shaped our platform",
                "Mentoring team members and fostering a culture of excellence",
                "Keeping the team aligned and focused through complex projects",
                "Building bridges across organizations to deliver customer value"
            )
        }
        "*Senior*" {
            $contributions = @(
                "Delivering high-impact technical solutions across the platform",
                "Mentoring junior engineers and raising the team's technical bar",
                "Leading key design reviews and architecture decisions",
                "Contributing thoughtful, thorough code reviews",
                "Driving innovation in our development practices"
            )
        }
        default {
            $contributions = @(
                "Shipping reliable features that our customers depend on",
                "Writing clean, well-tested code that stands the test of time",
                "Being an enthusiastic collaborator in team discussions",
                "Bringing fresh ideas and creative solutions to complex problems",
                "Growing rapidly and making a real impact on the platform"
            )
        }
    }

    # --- Generate email ---
    if ($Test) {
        $outputPath = Join-Path $repoRoot "birthday-preview.html"

        Write-Host "   Generating preview email..." -ForegroundColor Yellow

        & $emailScript `
            -Name $person.name `
            -Role $person.role `
            -Alias $person.alias `
            -Contributions $contributions `
            -CcList $ccList `
            -OutputHtml $outputPath

        Write-Host ""
        Write-Host "✅ Preview saved to: $outputPath" -ForegroundColor Green
        Write-Host "   Opening in browser..." -ForegroundColor Cyan

        # Open in default browser
        Start-Process $outputPath
    }
    else {
        Write-Host "   Sending birthday email via Outlook..." -ForegroundColor Yellow

        & $emailScript `
            -Name $person.name `
            -Role $person.role `
            -Alias $person.alias `
            -Contributions $contributions `
            -CcList $ccList `
            -Send

        Write-Host "✅ Birthday email sent to $($person.name)!" -ForegroundColor Green

        # --- Post birthday notification to Teams "Wins and Celebrations" channel ---
        # Channel routing: birthday notifications go to the "wins" channel.
        # When running with Teams MCP tools, use channelId from .squad/teams-channels.json.
        # Fallback: post to general channel via webhook.
        $channelsFile = Join-Path $repoRoot ".squad\teams-channels.json"
        $webhookFile = Join-Path $env:USERPROFILE ".squad\teams-webhook.url"
        if (Test-Path $webhookFile) {
            try {
                $webhookUrl = (Get-Content $webhookFile -Raw -Encoding utf8).Trim()
                if (-not [string]::IsNullOrWhiteSpace($webhookUrl)) {
                    $teamsMsg = @{
                        "@type"    = "MessageCard"
                        "@context" = "https://schema.org/extensions"
                        summary    = "Birthday: $($person.name)"
                        themeColor = "FF69B4"
                        title      = "🎂 Happy Birthday $($person.name)!"
                        text       = "CHANNEL: wins`n`n🎉 Today is **$($person.name)**'s birthday ($($person.role))! A birthday email has been sent. 🥳"
                    }
                    $body = $teamsMsg | ConvertTo-Json -Depth 5
                    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json" | Out-Null
                    Write-Host "   Teams notification sent (CHANNEL: wins)" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "   Warning: Teams notification failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host ""
Write-Host "🎂 Birthday checker complete." -ForegroundColor Magenta
