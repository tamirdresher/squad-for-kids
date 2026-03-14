# Kids Study Assistant — Squad Skill

> Exam schedule tracking and daily study plan generation

## Overview

The Kids Study Assistant is a PowerShell automation skill that helps manage exam schedules and creates structured study plans. It parses exam data from YAML, generates daily study schedules with spaced repetition, and exports plans to Markdown format.

## Capabilities

- **Parse exam schedules** from YAML files
- **Calculate days until exams** with status indicators (Urgent, Soon, Upcoming)
- **Generate daily study plans** with topic allocation and spaced repetition
- **Exclude Shabbat** (Friday evening through Saturday)
- **Export to Markdown** for easy sharing
- **Multi-student support** - track multiple children
- **Hebrew content support** (RTL)

## Location

Scripts are located at: `C:\temp\tamresearch1\scripts\kids-study\`

## Usage

### Via Squad Framework

When triggered by issue mentions or scheduled runs:

```powershell
# In squad automation context
& "C:\temp\tamresearch1\scripts\kids-study\Start-DailyStudyRoutine.ps1" -PostToGitHub -GitHubIssueNumber "512"
```

### Direct Usage

```powershell
cd C:\temp\tamresearch1\scripts\kids-study

# Get exam schedule
.\Get-ExamSchedule.ps1

# Generate study plan
.\New-StudyPlan.ps1 -DaysAhead 14 -ExcludeShabbat

# Export today's plan
.\Export-StudyPlan.ps1

# Run full daily routine
.\Start-DailyStudyRoutine.ps1
```

## Configuration

Edit `schedule.yaml` to add/update exams:

```yaml
students:
  - name: "ילד 1"
    grade: "כיתה ז'"
    exams:
      - subject: "מתמטיקה"
        date: "2026-03-25"
        topics:
          - "משוואות"
          - "שברים"
        notes: "Chapters 5-7"
```

## Integration Points

### GitHub Issues
Post daily plans as comments:
```powershell
gh issue comment 512 --body-file "C:\temp\tamresearch1\scripts\kids-study\daily-plan.md"
```

### Microsoft Teams
Set `TEAMS_WEBHOOK_URL` environment variable and use `-PostToTeams` flag:
```powershell
$env:TEAMS_WEBHOOK_URL = "https://outlook.office.com/webhook/..."
.\Start-DailyStudyRoutine.ps1 -PostToTeams
```

### Task Scheduler
Schedule daily runs at 7:00 AM:
```powershell
$action = New-ScheduledTaskAction -Execute "pwsh.exe" `
    -Argument "-File C:\temp\tamresearch1\scripts\kids-study\Start-DailyStudyRoutine.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 7:00AM
Register-ScheduledTask -TaskName "KidsStudyAssistant" -Action $action -Trigger $trigger
```

## Scripts Reference

| Script | Purpose | Output |
|--------|---------|--------|
| `Get-ExamSchedule.ps1` | Parse YAML schedule | Array of exam objects |
| `New-StudyPlan.ps1` | Generate study plan | Hashtable of daily sessions |
| `Export-StudyPlan.ps1` | Export to Markdown | Path to .md file |
| `Start-DailyStudyRoutine.ps1` | Orchestrate all steps | Daily plan + summary |

## Requirements

- PowerShell 7+ (already installed)
- `powershell-yaml` module (auto-installed on first run)

## Example Output

```markdown
# 📚 Daily Study Plan
**Date:** Sunday, March 22, 2026

## ⚠️ Upcoming Exams
- 🎯 **ילד 1** - מתמטיקה in **3 days** (2026-03-25)

## 📖 Today's Study Sessions

### 👤 ילד 1
| Time | Subject | Topic | Duration | Type |
|------|---------|-------|----------|------|
| 16:00 | מתמטיקה | משוואות | 20 min | Review |
| 16:00 | מתמטיקה | שברים | 20 min | Review |
```

## Trigger Patterns

This skill is triggered by:
- Issue mentions: "kids study", "exam schedule", "study plan"
- Scheduled automation (Task Scheduler)
- Manual invocation via GitHub Actions

## Future Enhancements

- AI-generated study material summaries
- OneDrive Excel sync
- WhatsApp/SMS reminders
- Practice question generation
- Progress tracking

## Testing

All scripts have been tested and confirmed working:

```powershell
# Test 1: Parse schedule ✓
.\Get-ExamSchedule.ps1 | Format-Table

# Test 2: Generate plan ✓
.\New-StudyPlan.ps1 -DaysAhead 14 -ExcludeShabbat

# Test 3: Export Markdown ✓
.\Export-StudyPlan.ps1

# Test 4: Full routine ✓
.\Start-DailyStudyRoutine.ps1
```

## Related Issues

- #512 - Kids Study Assistant (primary issue)

## Maintainer

Data (Code Expert)

---

*Last updated: 2026-03-14*
