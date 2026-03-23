# 🎬 Video 06: Scheduled Tasks

> **Title (EN):** Set It and Forget It — Automated Daily Check-Ins
> **Title (HE):** הגדר ושכח — בדיקות יומיות אוטומטיות

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~4 minutes |
| **Target Audience** | Technical parents, developers |
| **Languages** | English + Hebrew (separate recordings) |
| **Prerequisites** | Forked repo with GitHub Actions enabled |
| **Difficulty** | Intermediate |

---

## Key Takeaway

> GitHub Actions cron jobs can run daily check-ins, generate progress reports, and remind kids to study — all automatically. Parents set it once and the Squad handles the rest.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids

# 1. Ensure .github/workflows/ contains the scheduled workflows
ls .github/workflows/

# 2. Have the browser open to GitHub Actions tab
# 3. Ensure student profile exists with some learning history
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force
```

---

## Storyboard

### Scene 1: The Problem [0:00–0:25]

**Screen:** Calendar/planner visual (or just narration over repo)

**Narration (EN):**
> "Kids forget to study. Parents forget to check. Teachers can't follow up with every student. What if the system could handle check-ins automatically — every single day?"

**Narration (HE):**
> "ילדים שוכחים ללמוד. הורים שוכחים לבדוק. מורים לא יכולים לעקוב אחרי כל תלמיד. מה אם המערכת יכלה לטפל בבדיקות אוטומטית — כל יום?"

---

### Scene 2: Show the Workflow Files [0:25–1:15]

**Screen:** VS Code / GitHub — workflow YAML files

**On Screen:**
1. Open `.github/workflows/squad-heartbeat.yml`
2. Highlight the cron schedule

**File content to show:**
```yaml
name: Squad Daily Heartbeat
on:
  schedule:
    - cron: '0 7 * * 0-4'  # 7 AM, Sunday-Thursday (Israeli school week)
  workflow_dispatch:         # Manual trigger for testing

jobs:
  daily-checkin:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run daily check-in
        run: |
          # Check what's due today
          # Generate daily study plan
          # Post reminder issue if no activity yesterday
```

**Narration (EN):**
> "Here's the secret — a GitHub Actions workflow that runs every morning at 7 AM, Sunday through Thursday — matching the Israeli school week. It checks what's due, generates a daily plan, and creates a reminder if the kid hasn't studied."

**Narration (HE):**
> "הנה הסוד — תהליך גיטהאב אקשנס שרץ כל בוקר בשבע, ראשון עד חמישי — מותאם לשבוע הלימודים הישראלי. הוא בודק מה ביומן, מייצר תוכנית יומית, ויוצר תזכורת אם הילד לא למד."

---

### Scene 3: Trigger Manually [1:15–2:00]

**Screen:** GitHub Actions tab

**On Screen:**
1. Go to Actions tab
2. Select "Squad Daily Heartbeat"
3. Click "Run workflow" → "Run workflow"
4. Watch the job execute

**Narration (EN):**
> "Let's trigger it manually to see what happens. In production, this runs automatically every morning."

**Expected output in Actions log:**
```
📅 Daily Check-In for Yoav (2026-01-20)
📊 Yesterday's activity: 0 sessions (no study detected)
📋 Today's curriculum:
   - Math: Multiplication tables (×3) — 15 min
   - Hebrew: Reading comprehension — 20 min
   - Science: States of matter review — 10 min
⚡ Creating reminder issue...
✅ Issue #25 created: "📚 Yoav's Study Plan — Monday Jan 20"
```

---

### Scene 4: Show the Generated Issue [2:00–2:45]

**Screen:** Browser — the auto-created issue

**On Screen:** Show the auto-generated study plan issue:

```markdown
# 📚 Yoav's Study Plan — Monday, January 20

Good morning, Yoav! 🌅 Here's what we're working on today:

## Today's Schedule
| Time | Subject | Activity | Duration |
|------|---------|----------|----------|
| 🔢 | Math | Multiplication tables (×3) | 15 min |
| 📖 | Hebrew | Reading: הנסיך הקטן Ch. 3 | 20 min |
| 🔬 | Science | States of matter flash cards | 10 min |

## Yesterday's Streak
⚠️ No study session detected yesterday!
Your streak is at risk — let's get back on track! 💪

## Fun Fact of the Day
🦕 Did you know? The T-Rex had the strongest bite of any land animal ever!
```

**Narration (EN):**
> "The system creates a friendly daily plan with specific tasks, time estimates, and even a fun fact. It noticed Yoav didn't study yesterday and gently encourages him to get back on track."

**Narration (HE):**
> "המערכת יוצרת תוכנית יומית ידידותית עם משימות ספציפיות, הערכות זמן, ואפילו עובדה מעניינת. היא שמה לב שיואב לא למד אתמול ומעודדת אותו בעדינות לחזור למסלול."

---

### Scene 5: Other Scheduled Workflows [2:45–3:30]

**Screen:** GitHub Actions — list of workflows

**Narration (EN):**
> "There are more scheduled tasks — weekly progress reports for parents, monthly curriculum reviews, and a Shabbat-aware scheduler that never sends notifications on Friday evening or Saturday."

**On Screen:**
Show list of workflows:
```
squad-heartbeat.yml      — Daily study reminders (7 AM Sun-Thu)
squad-board-sync.yml     — Sync project board with issues
squad-triage.yml         — Auto-triage new issues
```

---

### Scene 6: Closing [3:30–4:00]

**Narration (EN):**
> "Set it once, and the Squad checks in every morning. Your child gets a personalized daily plan, and you get peace of mind. Education that runs on autopilot."

**Narration (HE):**
> "הגדירו פעם אחת, והסקוואד בודק כל בוקר. הילד שלכם מקבל תוכנית יומית מותאמת אישית, ואתם מקבלים שקט נפשי. חינוך שרץ על טייס אוטומטי."

---

## Reset / Cleanup

```powershell
# Close auto-generated issues from the manual trigger
.\demos\reset-demo.ps1
```

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/06-scheduled-tasks-en.txt `
    --write-media output/narration/06-scheduled-tasks-en.mp3

edge-tts --voice "he-IL-HilaNeural" --rate "+0%" `
    --file scripts/06-scheduled-tasks-he.txt `
    --write-media output/narration/06-scheduled-tasks-he.mp3
```
