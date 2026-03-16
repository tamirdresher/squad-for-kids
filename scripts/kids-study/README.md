# Kids Study Assistant

> PowerShell automation scripts for exam schedule tracking and study planning

## 📋 Overview

A practical study assistant that helps manage exam schedules and creates daily study plans. Built with PowerShell 7 for Windows, supports Hebrew content (RTL).

## ✨ Features

- **Exam Schedule Tracking** - Parse YAML schedule with exam dates, subjects, and topics
- **Smart Study Planning** - Generate daily study plans with spaced repetition
- **Shabbat Awareness** - Automatically excludes Friday evening through Saturday
- **Multi-Student Support** - Track exams for multiple children
- **Markdown Export** - Generate formatted daily plans
- **Squad Integration** - Ready for GitHub Actions automation

## 📱 Notification Setup (Discord/Telegram)

### Overview

Send daily study plans directly to kids via their favorite messaging apps:
- **Discord** (Recommended for kids - simplest setup)
- **Telegram** (Popular, requires bot setup)

### Discord Webhook (Simplest Option)

**Why Discord?**
- No bot setup needed - just a URL
- Supports rich formatting
- Kids already using Discord

**Setup Steps:**

1. Create a Discord server (or use existing)
2. Go to Server Settings → Integrations → Webhooks
3. Click "New Webhook" → Select channel → Copy URL
4. Run setup script:
   ```powershell
   .\setup-notifications.ps1
   ```
5. Choose option `1` (Discord), paste webhook URL
6. Done! ✅

**Using Discord notifications:**
```powershell
.\Start-DailyStudyRoutine.ps1 -NotifyDiscord
```

### Telegram Bot Setup

**Setup Steps:**

1. Open Telegram → Find `@BotFather`
2. Send `/newbot` → Choose name and username
3. Copy the token you receive
4. Run setup script:
   ```powershell
   .\setup-notifications.ps1
   ```
5. Choose option `2` (Telegram), paste token and chat ID
6. To find your Chat ID:
   - Send bot a test message
   - Open: `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates`
   - Find your chat ID in the JSON response

**Using Telegram notifications:**
```powershell
.\Start-DailyStudyRoutine.ps1 -NotifyTelegram
```

**Both channels at once:**
```powershell
.\Start-DailyStudyRoutine.ps1 -NotifyDiscord -NotifyTelegram
```

### Configuration File

Notification settings are stored in `notification-config.yaml`:

```yaml
discord:
  webhook_url: "https://discordapp.com/api/webhooks/..."

telegram:
  bot_token: "123456:ABC..."
  chat_id: "987654321"
```

**To reconfigure:**
```powershell
.\setup-notifications.ps1
```

## 🚀 Quick Start

### Prerequisites

- **PowerShell 7+** - Already installed (check: `pwsh --version`)
- **powershell-yaml module** - Auto-installed on first run

### Setup

1. Navigate to the scripts directory:
   ```powershell
   cd C:\temp\tamresearch1\scripts\kids-study
   ```

2. Edit `schedule.yaml` with your exam data:
   ```yaml
   students:
     - name: "ילד 1"
       grade: "כיתה ז'"
       exams:
         - subject: "מתמטיקה"
           date: "2025-08-15"
           topics:
             - "משוואות"
             - "שברים"
   ```

3. Run the daily routine:
   ```powershell
   .\Start-DailyStudyRoutine.ps1
   ```

## 📜 Scripts Reference

### `Send-Notification.ps1`
Unified notification sender for Discord, Telegram, WhatsApp.

```powershell
# Send to Discord
.\Send-Notification.ps1 -Channel discord `
    -Message "תוכנית לימוד חדשה" `
    -WebhookUrl "https://discordapp.com/api/webhooks/..."

# Send to Telegram
.\Send-Notification.ps1 -Channel telegram `
    -Message "תוכנית לימוד חדשה" `
    -BotToken "123456:ABC..." `
    -ChatId "987654321"
```

### `setup-notifications.ps1`
Interactive setup for Discord webhooks and Telegram bots (Hebrew UI).

```powershell
.\setup-notifications.ps1
```

**Features:**
- Step-by-step Hebrew instructions
- Validates webhook URLs
- Saves to notification-config.yaml

### `Get-ExamSchedule.ps1`
Parses exam schedule and calculates days until each exam.

```powershell
# Get all exams
.\Get-ExamSchedule.ps1

# Get only urgent exams (next 7 days)
.\Get-ExamSchedule.ps1 | Where-Object { $_.DaysUntil -le 7 }
```

**Output:** Array of exam objects with `StudentName`, `Subject`, `ExamDate`, `DaysUntil`, `Status`, etc.

### `New-StudyPlan.ps1`
Generates a structured study plan with topic allocation.

```powershell
# Default: 14-day plan, 2 hours/day
.\New-StudyPlan.ps1

# Custom: 7-day plan, 3 hours/day, exclude Shabbat
.\New-StudyPlan.ps1 -DaysAhead 7 -StudyHoursPerDay 3 -ExcludeShabbat
```

**Output:** Hashtable of daily study sessions, grouped by date.

### `Export-StudyPlan.ps1`
Exports daily study plan to Markdown format.

```powershell
# Default: creates daily-plan.md
.\Export-StudyPlan.ps1

# Custom output path
.\Export-StudyPlan.ps1 -OutputPath "C:\plans\today.md"
```

**Output:** Path to generated Markdown file.

### `Start-DailyStudyRoutine.ps1`
Main automation script - orchestrates all steps.

```powershell
# Run daily routine
.\Start-DailyStudyRoutine.ps1

# With Teams posting (when configured)
.\Start-DailyStudyRoutine.ps1 -PostToTeams

# With GitHub issue comment (when configured)
.\Start-DailyStudyRoutine.ps1 -PostToGitHub
```

## 🔧 Advanced Configuration

### Notification Options

**Discord Webhook (Recommended)**
```powershell
# One-time setup
.\setup-notifications.ps1

# Use it
.\Start-DailyStudyRoutine.ps1 -NotifyDiscord
```

**Telegram Bot**
```powershell
# One-time setup
.\setup-notifications.ps1

# Use it
.\Start-DailyStudyRoutine.ps1 -NotifyTelegram
```

**Both Discord and Telegram**
```powershell
.\Start-DailyStudyRoutine.ps1 -NotifyDiscord -NotifyTelegram
```

### Scheduling with Task Scheduler

Run daily at 7:00 AM:

```powershell
$action = New-ScheduledTaskAction -Execute "pwsh.exe" `
    -Argument "-File C:\temp\tamresearch1\scripts\kids-study\Start-DailyStudyRoutine.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At 7:00AM

Register-ScheduledTask -TaskName "KidsStudyAssistant" `
    -Action $action -Trigger $trigger -Description "Daily study plan generator"
```

### Teams Integration

Set Teams webhook URL as environment variable:

```powershell
$env:TEAMS_WEBHOOK_URL = "https://outlook.office.com/webhook/..."
```

Then run with `-PostToTeams` flag.

### GitHub Integration

Post to issue using `gh` CLI:

```powershell
$planPath = "C:\temp\tamresearch1\scripts\kids-study\daily-plan.md"
gh issue comment 512 --body-file $planPath
```

## 🎯 Example Workflow

**Daily Automation with Notifications:**
1. Schedule.yaml updated by parents/kids
2. Task Scheduler runs `Start-DailyStudyRoutine.ps1 -NotifyDiscord` at 7 AM
3. Script generates daily plan
4. Notification sent to Discord/Telegram automatically
5. Kids see their study schedule on messaging app
6. Plan also saved to daily-plan.md for reference

**With Multiple Notifications:**
```powershell
# Set up once
.\setup-notifications.ps1

# Schedule this command to run daily at 7 AM:
.\Start-DailyStudyRoutine.ps1 -NotifyDiscord -NotifyTelegram
```

**Manual Usage:**
```powershell
# Quick check: what exams are coming up?
.\Get-ExamSchedule.ps1 | Format-Table StudentName, Subject, DaysUntil, Status

# Generate this week's plan
.\New-StudyPlan.ps1 -DaysAhead 7

# Export today's plan to Markdown
.\Export-StudyPlan.ps1

# Send to Discord
.\Start-DailyStudyRoutine.ps1 -NotifyDiscord
```

## 📁 File Structure

```
scripts/kids-study/
├── schedule.yaml                  # Exam schedule data (edit this)
├── notification-config.yaml       # Discord/Telegram/WhatsApp config
├── Get-ExamSchedule.ps1           # YAML parser
├── New-StudyPlan.ps1              # Study plan generator
├── Export-StudyPlan.ps1           # Markdown exporter
├── Send-Notification.ps1          # Notification sender (Discord/Telegram)
├── setup-notifications.ps1        # Interactive setup (Hebrew UI)
├── Start-DailyStudyRoutine.ps1    # Main orchestration script
├── daily-plan.md                  # Generated daily plan (output)
└── README.md                      # This file
```

## 🔍 Troubleshooting

**"powershell-yaml module not found"**
- The script auto-installs it on first run
- Manual install: `Install-Module powershell-yaml -Scope CurrentUser`

**Hebrew text displays incorrectly**
- Ensure your terminal supports UTF-8
- PowerShell 7 handles UTF-8 by default
- VS Code: Set terminal encoding to UTF-8

**Dates are parsed incorrectly**
- Ensure dates in schedule.yaml are in YYYY-MM-DD format
- Example: `date: "2025-08-15"`

**Script won't run due to execution policy**
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## 🚀 Future Enhancements

- [x] Discord/Telegram notifications
- [ ] WhatsApp support (via Twilio)
- [ ] AI-generated study material summaries (via Azure OpenAI)
- [ ] OneDrive Excel sync for schedule updates
- [ ] Practice question generation per topic
- [ ] Progress tracking (what was actually studied)
- [ ] Interactive Q&A mode via Teams/Discord

## 📝 License

Part of tamresearch1 project. For personal/family use.

---

*Created by: Data (Code Expert)*  
*Issue: #512 - Kids Study Assistant*  
*Last updated: 2025-03-13 - Added Discord/Telegram notifications*
