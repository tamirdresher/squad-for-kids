<#
.SYNOPSIS
    Main orchestration script for Kids Study Assistant.

.DESCRIPTION
    Daily automation script that:
    1. Reads exam schedule
    2. Generates study plan
    3. Exports to Markdown
    4. Optionally posts to Teams/GitHub or sends notifications
    
    Can be scheduled via Windows Task Scheduler or GitHub Actions.

.PARAMETER SchedulePath
    Path to schedule.yaml. Defaults to schedule.yaml in script directory.

.PARAMETER PostToTeams
    If set, posts the daily plan to Microsoft Teams (requires Teams webhook or Graph API setup).

.PARAMETER PostToGitHub
    If set, posts the daily plan as a comment on a tracking issue.

.PARAMETER NotifyDiscord
    If set, sends daily plan to Discord webhook (requires configuration).

.PARAMETER NotifyTelegram
    If set, sends daily plan to Telegram bot (requires configuration).

.PARAMETER ConfigPath
    Path to notification-config.yaml. Defaults to notification-config.yaml in script directory.

.EXAMPLE
    .\Start-DailyStudyRoutine.ps1
    Generates and displays the daily plan.

.EXAMPLE
    .\Start-DailyStudyRoutine.ps1 -NotifyDiscord
    Generates plan and sends to Discord webhook.

.EXAMPLE
    .\Start-DailyStudyRoutine.ps1 -NotifyDiscord -NotifyTelegram
    Generates plan and sends to both Discord and Telegram.

.EXAMPLE
    .\Start-DailyStudyRoutine.ps1 -PostToTeams
    Generates plan and posts to Teams channel.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SchedulePath = "$PSScriptRoot\schedule.yaml",
    
    [Parameter()]
    [switch]$PostToTeams,
    
    [Parameter()]
    [switch]$PostToGitHub,
    
    [Parameter()]
    [string]$GitHubIssueNumber = "512",
    
    [Parameter()]
    [switch]$NotifyDiscord,
    
    [Parameter()]
    [switch]$NotifyTelegram,
    
    [Parameter()]
    [string]$ConfigPath = "$PSScriptRoot\notification-config.yaml"
)

$ErrorActionPreference = "Stop"

Write-Host @"

╔════════════════════════════════════════╗
║   Kids Study Assistant - Daily Run    ║
╚════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Step 1: Check schedule file exists
Write-Host "[1/4] Checking schedule file..." -ForegroundColor Yellow
if (-not (Test-Path $SchedulePath)) {
    Write-Error "Schedule file not found: $SchedulePath"
    exit 1
}
Write-Host "      ✓ Schedule file found`n" -ForegroundColor Green

# Step 2: Parse exam schedule
Write-Host "[2/4] Parsing exam schedule..." -ForegroundColor Yellow
try {
    $exams = & "$PSScriptRoot\Get-ExamSchedule.ps1" -SchedulePath $SchedulePath
    $upcomingCount = ($exams | Where-Object { $_.DaysUntil -ge 0 }).Count
    Write-Host "      ✓ Found $upcomingCount upcoming exams`n" -ForegroundColor Green
}
catch {
    Write-Error "Failed to parse schedule: $_"
    exit 1
}

# Step 3: Generate study plan
Write-Host "[3/4] Generating study plan..." -ForegroundColor Yellow
try {
    $planPath = & "$PSScriptRoot\Export-StudyPlan.ps1" -SchedulePath $SchedulePath
    Write-Host "      ✓ Study plan generated`n" -ForegroundColor Green
}
catch {
    Write-Error "Failed to generate study plan: $_"
    exit 1
}

# Step 4: Distribute plan
Write-Host "[4/4] Distributing plan..." -ForegroundColor Yellow

$planContent = Get-Content -Path $planPath -Raw -Encoding UTF8

if ($PostToTeams) {
    Write-Host "      → Posting to Teams..." -ForegroundColor Cyan
    # TODO: Implement Teams webhook posting
    # Requires: Teams webhook URL in environment variable or config
    Write-Warning "      Teams posting not yet implemented. Set TEAMS_WEBHOOK_URL environment variable."
}

if ($PostToGitHub) {
    Write-Host "      → Posting to GitHub Issue #$GitHubIssueNumber..." -ForegroundColor Cyan
    # TODO: Implement GitHub API comment posting
    # Requires: gh CLI or GitHub token
    Write-Warning "      GitHub posting not yet implemented. Use 'gh issue comment $GitHubIssueNumber --body-file `"$planPath`"'"
}

# Load notification config if needed
if ($NotifyDiscord -or $NotifyTelegram) {
    if (-not (Test-Path $ConfigPath)) {
        Write-Warning "      ⚠️  Notification config not found at $ConfigPath"
        Write-Host "      💡 Run .\setup-notifications.ps1 to configure notifications`n" -ForegroundColor Cyan
    }
    else {
        # Parse YAML config
        $configContent = Get-Content -Path $ConfigPath -Raw
        
        # Extract Discord webhook
        $discordWebhook = ""
        if ($configContent -match "webhook_url:\s*[`"`"]?([^`"`"`n]+)[`"`"]?") {
            $discordWebhook = $matches[1].Trim()
        }
        
        # Extract Telegram config
        $telegramToken = ""
        $telegramChatId = ""
        if ($configContent -match "bot_token:\s*[`"`"]?([^`"`"`n]+)[`"`"]?") {
            $telegramToken = $matches[1].Trim()
        }
        if ($configContent -match "chat_id:\s*[`"`"]?([^`"`"`n]+)[`"`"]?") {
            $telegramChatId = $matches[1].Trim()
        }
        
        # Prepare notification message
        $notificationMsg = "📚 תוכנית הלימוד ליום חדש / Daily Study Plan:`n`n" + $planContent
        
        if ($NotifyDiscord -and $discordWebhook) {
            Write-Host "      → Sending to Discord..." -ForegroundColor Cyan
            try {
                & "$PSScriptRoot\Send-Notification.ps1" -Channel discord `
                    -Message $notificationMsg `
                    -Title "תוכנית לימוד יומית" `
                    -WebhookUrl $discordWebhook -ErrorAction Stop
            }
            catch {
                Write-Warning "      ⚠️  Failed to send Discord notification: $_"
            }
        }
        
        if ($NotifyTelegram -and $telegramToken -and $telegramChatId) {
            Write-Host "      → Sending to Telegram..." -ForegroundColor Cyan
            try {
                & "$PSScriptRoot\Send-Notification.ps1" -Channel telegram `
                    -Message $notificationMsg `
                    -BotToken $telegramToken `
                    -ChatId $telegramChatId -ErrorAction Stop
            }
            catch {
                Write-Warning "      ⚠️  Failed to send Telegram notification: $_"
            }
        }
    }
}

Write-Host "      ✓ Distribution complete`n" -ForegroundColor Green

# Display summary
Write-Host @"

╔════════════════════════════════════════╗
║           Summary                      ║
╚════════════════════════════════════════╝

"@ -ForegroundColor Green

$urgentExams = $exams | Where-Object { $_.Status -in @("Today", "Urgent") }
if ($urgentExams.Count -gt 0) {
    Write-Host "⚠️  URGENT: $($urgentExams.Count) exam(s) in next 3 days!" -ForegroundColor Red
    foreach ($exam in $urgentExams) {
        Write-Host "   - $($exam.StudentName): $($exam.Subject) in $($exam.DaysUntil) days" -ForegroundColor Yellow
    }
}
else {
    Write-Host "✓ No urgent exams. All on track!" -ForegroundColor Green
}

Write-Host "`n📄 Daily plan saved to: $planPath"
Write-Host "💡 To notify via Discord: Add -NotifyDiscord flag"
Write-Host "💡 To notify via Telegram: Add -NotifyTelegram flag"
Write-Host "💡 To post to Teams: Set TEAMS_WEBHOOK_URL and run with -PostToTeams"
Write-Host "💡 To post to GitHub: Run: gh issue comment $GitHubIssueNumber --body-file `"$planPath`""
Write-Host "💡 Setup notifications: .\setup-notifications.ps1`n"

Write-Host "✨ Daily routine complete!`n" -ForegroundColor Cyan
