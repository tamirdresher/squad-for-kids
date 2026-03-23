# 🎬 Video 15: Parent Weekly Report

> **Title (EN):** What Did My Child Learn This Week?
> **Title (HE):** מה הילד שלי למד השבוע?

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~3 minutes |
| **Target Audience** | Parents |
| **Language** | English |
| **Prerequisites** | Student profile with 1+ week of activity |
| **Difficulty** | Beginner |

---

## Key Takeaway

> Parents get a clear, actionable weekly summary — topics covered, time spent, strengths, concerns, and recommendations. No digging through GitHub required.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force

# Ensure some reports exist in .squad/reports/
Test-Path .squad/reports/
```

---

## Storyboard

### Scene 1: The Report [0:00–0:30]

**Screen:** Terminal or GitHub (rendered markdown)

**Narration (EN):**
> "Parents don't need to check every issue or PR. The Squad generates a weekly report — clear, concise, and designed for busy parents. Here's what it looks like."

---

### Scene 2: Show the Report [0:30–1:45]

**Screen:** Rendered markdown report

**Expected report content (verify or create mock):**
```markdown
# 📊 Weekly Progress Report — Yoav
## Week of January 13-19, 2026

### 📈 Summary
| Metric | Value |
|--------|-------|
| Study sessions | 5 (Mon, Tue, Wed, Thu, Sun) |
| Total time | 3 hours 15 minutes |
| Lessons completed | 4 |
| Quizzes taken | 2 |
| Average quiz score | 82% |
| XP earned | 175 |
| Current streak | 5 days 🔥 |

### 📚 Topics Covered
| Subject | Topics | Performance |
|---------|--------|-------------|
| 🔢 Math | Addition with carrying, intro to subtraction | ⭐⭐⭐⭐ Strong |
| 📖 Hebrew | Reading: "הכלב שלי", vocabulary | ⭐⭐⭐ Good |
| 🔬 Science | States of matter (solids, liquids) | ⭐⭐ Needs work |
| 🇬🇧 English | Basic greetings, colors | ⭐⭐⭐ Good |

### 💪 Strengths
- Math is Yoav's strongest area — he solved 47+38 independently!
- Showed genuine curiosity about dinosaurs (self-initiated lesson)
- 5-day streak shows growing consistency

### ⚠️ Areas of Concern
- Science scores are lower (70% average) — states of matter needs review
- Skipped Friday session (possibly Shabbat-related — not a concern)
- Gets frustrated with multi-step subtraction — may need more scaffolding

### 🎯 Recommendations for Next Week
1. **Science boost:** Schedule extra 10-min science sessions
2. **Subtraction practice:** Use visual aids (number line, blocks)
3. **Celebrate the streak!** Consider a real-world reward at 7 days

### 🗣️ Notable Quotes from Yoav
> "Math is like magic spells!" (after learning multiplication)
> "I hate math" (during difficult subtraction — frustration passed quickly)
> "Can we learn about space next?" (self-initiated interest!)
```

**Narration (EN):**
> "The report shows exactly what a parent needs — time spent, topics covered, strengths and concerns, and specific recommendations. Notice the 'Notable Quotes' section — it captures moments parents would miss."

---

### Scene 3: Actionable Insights [1:45–2:20]

**Narration (EN):**
> "The report doesn't just describe — it recommends. Science needs a boost, so it suggests extra sessions. Yoav is frustrated with subtraction, so it recommends visual aids. And it suggests celebrating the 5-day streak with a real-world reward."

**On Screen:** Highlight the "Recommendations" section

---

### Scene 4: How It's Delivered [2:20–2:40]

**Narration (EN):**
> "Reports are generated automatically every Sunday evening and saved in the repo. Parents can also receive them by email or WhatsApp — whatever's most convenient."

**On Screen:**
```
.squad/reports/
├── weekly-2026-01-12.md
├── weekly-2026-01-19.md  ← This week
└── weekly-2026-01-26.md  (upcoming)
```

---

### Scene 5: Closing [2:40–3:00]

**Narration (EN):**
> "One report, once a week, everything you need to know. The Squad does the teaching — and the reporting. You just enjoy watching your child grow."

---

## Reset / Cleanup

```powershell
.\demos\reset-demo.ps1
```

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/15-parent-report-en.txt `
    --write-media output/narration/15-parent-report-en.mp3
```
