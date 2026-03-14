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

**Daily Automation:**
1. Schedule.yaml updated by parents/kids
2. Task Scheduler runs `Start-DailyStudyRoutine.ps1` at 7 AM
3. Script generates daily plan
4. Plan posted to Teams family channel or GitHub issue
5. Kids see their study schedule for the day

**Manual Usage:**
```powershell
# Quick check: what exams are coming up?
.\Get-ExamSchedule.ps1 | Format-Table StudentName, Subject, DaysUntil, Status

# Generate this week's plan
.\New-StudyPlan.ps1 -DaysAhead 7

# Export today's plan to Markdown
.\Export-StudyPlan.ps1
```

## 📁 File Structure

```
scripts/kids-study/
├── schedule.yaml                 # Exam schedule data (edit this)
├── Get-ExamSchedule.ps1          # YAML parser
├── New-StudyPlan.ps1             # Study plan generator
├── Export-StudyPlan.ps1          # Markdown exporter
├── Start-DailyStudyRoutine.ps1   # Main orchestration script
├── daily-plan.md                 # Generated daily plan (output)
└── README.md                     # This file
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

- [ ] AI-generated study material summaries (via Azure OpenAI)
- [ ] OneDrive Excel sync for schedule updates
- [ ] WhatsApp/SMS reminders via Twilio
- [ ] Practice question generation per topic
- [ ] Progress tracking (what was actually studied)
- [ ] Interactive Q&A mode via Teams

## 📝 License

Part of tamresearch1 project. For personal/family use.

---

*Created by: Data (Code Expert)*  
*Issue: #512 - Kids Study Assistant*  
*Last updated: 2025-03-13*
