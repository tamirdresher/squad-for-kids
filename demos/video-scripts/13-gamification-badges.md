# 🎬 Video 13: Gamification & Badges

> **Title (EN):** Level Up! — XP, Streaks, and Badges
> **Title (HE):** שדרוג! — נקודות ניסיון, רצפים ותגים

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~4 minutes |
| **Target Audience** | Kids, parents |
| **Language** | English |
| **Prerequisites** | Student profile with some gamification data |
| **Difficulty** | Beginner |

---

## Key Takeaway

> Squad for Kids makes learning feel like a game — XP points, level-ups, streaks, and collectible badges. These are designed around intrinsic motivation, not just rewards.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids

# Use profile with some existing gamification data
$profile = Get-Content demos/profiles/yoav-grade2.json | ConvertFrom-Json
$profile.gamification = @{
    xp = 280
    level = 3
    levelName = "Apprentice"
    badges = @("First Lesson", "Math Whiz", "7-Day Streak", "Quiz Champ")
    streakDays = 4
    lastSessionDate = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
}
$profile | ConvertTo-Json -Depth 10 | Set-Content .squad/student-profile.json
```

---

## Storyboard

### Scene 1: Check Your Stats [0:00–0:40]

**Screen:** Terminal — Copilot CLI

**Type:**
```
copilot
```

Then:
```
Show me my stats!
```

**Expected:**
```
🎮 Yoav's Adventure Stats

⭐ XP: 280 / 500 (to next level)
📊 Level: 3 — Apprentice
🔥 Current Streak: 4 days!
📅 Last Session: Today

🏅 Badges Earned (4/20):
  🎓 First Lesson — Completed your first lesson
  🔢 Math Whiz — Solved 10 math problems
  🔥 7-Day Streak — Studied 7 days in a row
  🏆 Quiz Champ — Scored 100% on a quiz

▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░ 56% to Level 4!
```

---

### Scene 2: Earn XP [0:40–1:30]

**Type:**
```
Give me a quick math challenge!
```

**Expected:**
```
🏆 Coach here! Quick-fire round! ⚡

❓ What's 9 × 3?
```

**Type:**
```
27
```

**Expected:**
```
✅ CORRECT! 9 × 3 = 27! 

+15 XP ⭐ (Total: 295 XP)

❓ Next: What's 48 ÷ 6?
```

**Type:**
```
8
```

**Expected:**
```
✅ CORRECT again! You're on fire! 🔥

+15 XP ⭐ (Total: 310 XP)

❓ Bonus round: What's 7 × 7?
```

**Type:**
```
49
```

**Expected:**
```
✅ THREE IN A ROW! 🎉🎉🎉

+25 XP ⭐ (Combo bonus!) 
Total: 335 XP

🏅 NEW BADGE UNLOCKED: "Hat Trick" 🎩
   → Answer 3 questions correctly in a row!

▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░ 67% to Level 4!
```

**Narration (EN):**
> "Every correct answer earns XP. Streaks give combo bonuses. And badges unlock for specific achievements — three in a row earns the 'Hat Trick' badge. Kids LOVE collecting these."

---

### Scene 3: Level Up [1:30–2:15]

**Narration (EN):**
> "Let's see what happens when Yoav reaches the next level."

**Type:**
```
Keep going! More questions!
```

**After several correct answers (speed up in post)...**

**Expected (level-up moment):**
```
🎉🎉🎉 LEVEL UP! 🎉🎉🎉

⭐ You reached Level 4: EXPLORER! ⭐

  Level 1: Rookie      ✅
  Level 2: Learner     ✅
  Level 3: Apprentice  ✅
  Level 4: Explorer    ← YOU ARE HERE! 🌟
  Level 5: Scholar
  Level 6: Master
  Level 7: Wizard

🧙‍♀️ Hermione: "Congratulations, Yoav! Even I didn't 
level up this fast at Hogwarts!" 🏰

New perks unlocked:
  🔓 Harder challenges available
  🔓 Custom avatar options
  🔓 Daily fun fact feature
```

**Narration (EN):**
> "The level-up is a big deal — celebration, character congratulations, and new features unlocked. This is gamification done right — motivating through achievement, not just rewards."

---

### Scene 4: Streak System [2:15–3:00]

**Type:**
```
How's my streak doing?
```

**Expected:**
```
🔥 Streak Report

Current streak: 5 days! 🔥🔥🔥🔥🔥
Best streak ever: 12 days (your record!)

Calendar this week:
  Sun ✅ Mon ✅ Tue ✅ Wed ✅ Thu ✅ Fri ⬜ Sat ⬜

⚠️ Keep it going! Study tomorrow to reach 6 days!

🏅 Upcoming streak badges:
  🔥 14-Day Streak — 9 more days
  🌟 30-Day Streak — 25 more days (legendary!)
```

**Narration (EN):**
> "Streaks create healthy habits. The system tracks daily study sessions and awards badges for consistency. Notice it's Shabbat-aware — Friday and Saturday are optional, but the streak doesn't break."

---

### Scene 5: Closing [3:00–3:40]

**Type:**
```
What badges can I still earn?
```

**Expected:**
```
🏅 Badge Collection (5/20 earned)

Earned:
  ✅ First Lesson | ✅ Math Whiz | ✅ 7-Day Streak
  ✅ Quiz Champ | ✅ Hat Trick (NEW!)

Locked:
  🔒 Bookworm — Read 5 complete lessons
  🔒 Science Explorer — Complete 3 science experiments
  🔒 Code Wizard — Write your first program
  🔒 14-Day Streak — Study 14 days in a row
  🔒 Perfect Week — Study every day Mon-Fri
  🔒 Night Owl — Complete a late session (before bedtime!)
  ... and 9 more secret badges! 🤫
```

**Narration (EN):**
> "There are secret badges to discover, streaks to maintain, and levels to chase. Learning isn't a chore — it's a game. And every game is more fun when you're leveling up."

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
| **Speed** | 1x for interactions, 2x for rapid-fire answers |
| **Key moments** | Badge unlock, level-up celebration |
| **Sound effects** | Consider adding "ding" sound on badge unlock in post |

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/13-gamification-en.txt `
    --write-media output/narration/13-gamification-en.mp3
```
