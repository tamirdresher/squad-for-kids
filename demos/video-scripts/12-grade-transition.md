# 🎬 Video 12: Grade Transition

> **Title (EN):** Growing Up with Squad — Automatic Grade Updates
> **Title (HE):** גדלים עם הסקוואד — עדכוני כיתה אוטומטיים

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~3 minutes |
| **Target Audience** | Parents, educators |
| **Language** | English |
| **Prerequisites** | Student profile with grade history |
| **Difficulty** | Beginner |

---

## Key Takeaway

> When a child advances to the next grade, the Squad automatically detects the transition, updates the curriculum, adjusts difficulty, and celebrates the milestone. No manual reconfiguration needed.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids

# Use the grade-transition profile (yoav about to move from 2nd to 3rd)
Copy-Item demos/profiles/yoav-grade3-transition.json .squad/student-profile.json -Force
```

### Profile: `demos/profiles/yoav-grade3-transition.json`

This profile has `nextGradeDate: "2026-09-01"` and we'll simulate the date being reached.

---

## Storyboard

### Scene 1: Before the Transition [0:00–0:30]

**Screen:** Terminal — show current profile

**Type:**
```
copilot
```

Then:
```
What grade am I in?
```

**Expected:**
```
📋 You're in 2nd grade, Yoav! (כיתה ב')

Grade history:
  📅 1st grade — started Sep 2024
  📅 2nd grade — started Sep 2025
  📅 3rd grade — starts Sep 2026 (upcoming!)

You're doing great! 🌟
```

---

### Scene 2: Trigger Grade Transition [0:30–1:15]

**Narration (EN):**
> "When the next school year starts, the Squad detects the grade change automatically. Let's see what happens when Yoav moves to 3rd grade."

**Type:**
```
I just started 3rd grade!
```

**Expected (verify — grade transition flow):**
```
🎉🎉🎉 CONGRATULATIONS, YOAV! 🎉🎉🎉

You've graduated to 3rd grade! (כיתה ג') 🎓

🧙‍♀️ Hermione: "I'm SO proud of you! Let me update everything..."

📚 Curriculum Updated:
  ✅ All 2nd grade progress saved
  🔄 New topics unlocked for 3rd grade:
    🔢 Math: Multiplication & division, fractions intro
    📖 Hebrew: Cursive writing, longer reading passages
    🔬 Science: Earth & space, ecosystems
    🇬🇧 English: Past tense, reading comprehension level 2
    📜 Bible: More complex stories, basic commentary

🏆 Achievement Unlocked: "Grade Jumper" badge! (+100 XP)

Your profile has been updated automatically!
```

**Narration (EN):**
> "The system celebrates the milestone, unlocks new curriculum topics, and awards a special badge. The child feels proud and excited about the new challenges ahead."

---

### Scene 3: New Difficulty Level [1:15–2:00]

**Type:**
```
Hermione, give me a math problem
```

**Expected (verify — 3rd grade level, not 2nd):**
```
🧙‍♀️ Ready for 3rd grade math? Here we go!

🔢 What's 6 × 4?

Hint: Think of it as 6 groups of 4 objects.
You could even draw it! 🎨

(This is multiplication — a whole new branch of math magic! ✨)
```

**Narration (EN):**
> "Notice the difference — before the transition, math problems were addition and subtraction. Now it's multiplication. The Squad automatically adjusted the difficulty to match the new grade level."

---

### Scene 4: Grade History & Progress [2:00–2:30]

**Type:**
```
Show me everything I learned in 2nd grade
```

**Expected:**
```
📊 Yoav's 2nd Grade Report Card

📈 Topics Mastered:
  ✅ Addition with carrying (47 + 38 = 85 — remember? 😊)
  ✅ Subtraction basics
  ✅ Reading: Short Hebrew passages
  ✅ Dinosaurs lesson (Hagrid's favorite!)
  ✅ States of matter (מוצק, נוזל, גז)

📊 Stats:
  🏆 Total XP earned: 450
  📝 Lessons completed: 23
  🔥 Longest streak: 12 days
  🏅 Badges: Explorer, Streak Master, Quiz Champ

Everything is saved in your grade history! 📁
```

---

### Scene 5: Closing [2:30–3:00]

**Narration (EN):**
> "Grade transitions are automatic and celebratory. The Squad grows with your child — adjusting content, unlocking new topics, and preserving everything they've accomplished. No reset, no starting over. Just continuous growth."

---

## Reset / Cleanup

```powershell
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force
```

---

## Screen Recording Notes

| Setting | Value |
|---------|-------|
| **Resolution** | 1920×1080 |
| **Main area** | Terminal full-screen |
| **Speed** | 1x |
| **Key moment** | The graduation celebration (let it sit 5 seconds) |

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/12-grade-transition-en.txt `
    --write-media output/narration/12-grade-transition-en.mp3
```
