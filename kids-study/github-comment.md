# ✅ Kids Study Assistant Scripts — Ready to Use

## Summary

Built production-ready PowerShell 7 scripts that **actually work** for exam schedule tracking and daily study planning. All scripts have been tested and confirmed functional.

## 📁 Location

All scripts are at: `C:\temp\tamresearch1\scripts\kids-study\`

## 🚀 Quick Start

### 1. Edit Your Exam Schedule

Edit `schedule.yaml` with your kids' exams:

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
          - "גיאומטריה"
        notes: "Chapters 5-7"
```

### 2. Run the Daily Routine

```powershell
cd C:\temp\tamresearch1\scripts\kids-study
.\Start-DailyStudyRoutine.ps1
```

That's it! You'll get:
- ✓ Exam reminders for upcoming tests
- ✓ Daily study plan with time allocation
- ✓ Markdown output for sharing
- ✓ Smart scheduling (excludes Shabbat)

## 📜 Available Scripts

| Script | What It Does |
|--------|--------------|
| `Get-ExamSchedule.ps1` | Parse schedule, show days until each exam |
| `New-StudyPlan.ps1` | Generate multi-day study plan with spaced repetition |
| `Export-StudyPlan.ps1` | Export today's plan to Markdown |
| `Start-DailyStudyRoutine.ps1` | Run everything (main script) |

## ⚙️ Features

✅ **Works on PowerShell 7** (no issues like before)  
✅ **Hebrew content support** (RTL text handled correctly)  
✅ **Multi-student tracking** (manage multiple kids)  
✅ **Shabbat awareness** (no study sessions Friday-Saturday)  
✅ **Spaced repetition** (review sessions before exams)  
✅ **Auto-installs dependencies** (powershell-yaml module)  
✅ **Clean output** (Markdown format for Teams/GitHub)

## 🔧 Automation Options

### Daily Task Scheduler

Run automatically every morning at 7:00 AM:

```powershell
$action = New-ScheduledTaskAction -Execute "pwsh.exe" `
    -Argument "-File C:\temp\tamresearch1\scripts\kids-study\Start-DailyStudyRoutine.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At 7:00AM

Register-ScheduledTask -TaskName "KidsStudyAssistant" `
    -Action $action -Trigger $trigger -Description "Daily study plan"
```

### Post to GitHub

```powershell
gh issue comment 512 --body-file "C:\temp\tamresearch1\scripts\kids-study\daily-plan.md"
```

### Post to Teams

Set webhook URL and run with `-PostToTeams`:

```powershell
$env:TEAMS_WEBHOOK_URL = "https://outlook.office.com/webhook/..."
.\Start-DailyStudyRoutine.ps1 -PostToTeams
```

## 📖 Example Output

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
| 16:20 | מתמטיקה | שברים | 20 min | Review |
```

## 🧪 Testing

All scripts tested successfully:

```powershell
# ✓ Parse schedule with Hebrew content
.\Get-ExamSchedule.ps1 | Format-Table

# ✓ Generate 14-day plan with Shabbat exclusion
.\New-StudyPlan.ps1 -DaysAhead 14 -ExcludeShabbat

# ✓ Export to Markdown
.\Export-StudyPlan.ps1

# ✓ Full daily routine
.\Start-DailyStudyRoutine.ps1
```

## 📚 Documentation

Full documentation at: `C:\temp\tamresearch1\scripts\kids-study\README.md`

Squad skill definition: `.squad/skills/kids-study-assistant/SKILL.md`

## 🎯 Addressing Your Concerns

> "The script doesn't really work in practice. Also need to install PowerShell 7 because it works differently."

**Fixed:**
- ✅ PowerShell 7 verified installed and working
- ✅ Scripts thoroughly tested end-to-end
- ✅ Dependencies auto-install on first run
- ✅ Clear error messages if something goes wrong
- ✅ Detailed README with examples

These scripts are **production-ready** and handle real-world usage scenarios.

## 🚀 Next Steps (Optional Future Enhancements)

The current scripts provide a solid foundation. Future additions could include:
- AI-generated study material summaries
- OneDrive Excel sync for schedule updates
- WhatsApp/SMS reminders
- Practice question generation
- Progress tracking

But what's built now **works and is ready to use today**.

---

**Delivered by:** Data (Code Expert)  
**Status:** ✅ Ready for use  
**Date:** 2026-03-14
