# 🎬 Video 14: Study Scheduler

> **Title (EN):** Your Personal Study Plan — Spaced Repetition That Works
> **Title (HE):** תוכנית הלימודים האישית שלכם — חזרה מרווחת שעובדת

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~4 minutes |
| **Target Audience** | Parents, educators |
| **Language** | English |
| **Prerequisites** | Student profile with some learning history |
| **Difficulty** | Beginner |

---

## Key Takeaway

> The Squad generates daily study plans using spaced repetition — topics you struggle with appear more often. It's Shabbat-aware, respects bedtime, and counts down to exams.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force

# Ensure some learning history exists for spaced repetition
# The scheduler needs past sessions to calculate review intervals
```

---

## Storyboard

### Scene 1: Daily Plan [0:00–0:45]

**Screen:** Terminal — Copilot CLI

**Type:**
```
What should I study today?
```

**Expected:**
```
📅 Yoav's Study Plan — Tuesday, January 21

Good morning! ☀️ Here's your personalized plan:

| ⏰ Time | 📚 Subject | 📝 Activity | ⏱️ Duration |
|---------|-----------|-------------|-------------|
| Block 1 | 🔢 Math | Review: addition with carrying (due for review!) | 15 min |
| ☕ | Break | Stretch, drink water 🧃 | 5 min |
| Block 2 | 📖 Hebrew | New: Reading passage "הכלב שלי" | 20 min |
| ☕ | Break | Quick game or snack 🍎 | 5 min |
| Block 3 | 🔬 Science | Review: States of matter quiz | 10 min |

⏱️ Total study time: 45 minutes (with breaks: 55 min)
🔔 Suggested start: 3:30 PM (after school)

📊 Why these topics?
  - Math: Last practiced 3 days ago (spaced repetition: review now!)
  - Hebrew: New content — next in curriculum sequence
  - Science: Quiz score was 70% — needs reinforcement
```

**Narration (EN):**
> "The scheduler doesn't just list subjects randomly. It uses spaced repetition — topics you struggled with come back sooner. Math needs a review because it's been 3 days. Science needs reinforcement because the last quiz score was low."

---

### Scene 2: Shabbat Awareness [0:45–1:30]

**Type:**
```
What about Friday and Saturday?
```

**Expected:**
```
🕯️ Shabbat Schedule

📅 Friday (January 24):
  Morning only — finish by 2:00 PM (candle lighting prep)
  🔢 Quick math review (10 min)
  📖 Light reading for fun (optional)

📅 Saturday (January 25):
  🚫 No study sessions scheduled
  Shabbat Shalom! 🕊️

📅 Sunday (January 26):
  Full schedule resumes
  Your streak won't break over Shabbat! 🔥

⚙️ This schedule respects your location settings (Israel).
  Candle lighting: 4:42 PM | Havdalah: 5:52 PM
```

**Narration (EN):**
> "The scheduler is culturally aware. For Israeli families, it respects Shabbat — no sessions from Friday afternoon through Saturday evening. And the streak system doesn't penalize rest days."

---

### Scene 3: Exam Countdown [1:30–2:15]

**Type:**
```
I have a science test next Thursday on states of matter
```

**Expected:**
```
🎯 Exam Mode Activated!

📝 Science Test: States of Matter
📅 Thursday, January 30 (9 days away)

🗓️ Study Plan:
  Day 1-3: Review all material (15 min/day)
  Day 4-5: Practice quizzes
  Day 6-7: Focus on weak areas
  Day 8: Full mock test
  Day 9: Light review + confidence boost

📋 Topics to Cover:
  ✅ Solids (מוצק) — Mastered
  ⚠️ Liquids (נוזל) — Needs review (scored 60%)
  ❌ Gases (גז) — Not yet covered!
  ❌ Transitions (שינויי מצבי צבירה) — Not yet covered!

⚡ Priority: Start with gases (גז) TODAY!

Want me to create a study session for gases right now? 💨
```

**Narration (EN):**
> "Tell the Squad about an upcoming test, and it creates a countdown study plan. It analyzes what you've mastered, what needs review, and what you haven't learned yet — then prioritizes accordingly."

---

### Scene 4: Adjust the Schedule [2:15–3:00]

**Type:**
```
I have soccer practice on Tuesday and Thursday from 4-5 PM
```

**Expected:**
```
⚽ Got it! Schedule updated:

📅 Tuesday & Thursday:
  Study before soccer: 3:00 - 3:45 PM (45 min)
  OR after soccer: 5:30 - 6:15 PM (45 min)

Which do you prefer? Before or after practice?
```

**Type:**
```
After
```

**Expected:**
```
✅ Updated! Tuesday & Thursday sessions moved to 5:30 PM.

Your weekly schedule:
  Sun: 3:30 PM | Mon: 3:30 PM | Tue: 5:30 PM ⚽
  Wed: 3:30 PM | Thu: 5:30 PM ⚽ | Fri: Morning only
  Sat: Rest 🕊️
```

**Narration (EN):**
> "The scheduler adapts to the child's real life — sports, activities, family time. It's not a rigid timetable; it's a smart assistant that works around your child's schedule."

---

### Scene 5: Closing [3:00–3:40]

**Narration (EN):**
> "Spaced repetition, Shabbat awareness, exam countdowns, activity scheduling — all automatic. The Squad knows when to push and when to rest. It's the study planner every parent wishes they had time to create."

---

## Reset / Cleanup

```powershell
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force
```

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/14-study-scheduler-en.txt `
    --write-media output/narration/14-study-scheduler-en.mp3
```
