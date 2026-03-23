# 🎬 Video 07: Decisions & Directives

> **Title (EN):** The Squad Remembers — How decisions.md Works
> **Title (HE):** הסקוואד זוכר — איך decisions.md עובד

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~4 minutes |
| **Target Audience** | Developers, technical parents |
| **Languages** | English + Hebrew (separate recordings) |
| **Prerequisites** | Forked repo with .squad/decisions.md |
| **Difficulty** | Intermediate |

---

## Key Takeaway

> The Squad's `decisions.md` file is its institutional memory. Parents add rules ("never give homework answers directly"), and every agent follows them. It's like setting school policy — permanently.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force

# Ensure decisions.md exists with some baseline entries
Test-Path .squad/decisions.md
```

---

## Storyboard

### Scene 1: What is decisions.md? [0:00–0:30]

**Screen:** VS Code showing `.squad/decisions.md`

**Narration (EN):**
> "Every squad has a brain — a file called decisions.md. This is where rules, preferences, and learning policies live. Every agent reads this file before responding. Think of it as your child's school handbook — written by you."

**Narration (HE):**
> "לכל סקוואד יש מוח — קובץ בשם decisions.md. כאן חיים הכללים, ההעדפות ומדיניות הלמידה. כל סוכן קורא את הקובץ הזה לפני שהוא מגיב. חשבו על זה כמו ספר החוקים של בית הספר של הילד שלכם — שנכתב על ידכם."

**On Screen:** Show the existing decisions.md content

---

### Scene 2: Add a New Rule [0:30–1:30]

**Screen:** VS Code — editing decisions.md

**Type (add to decisions.md):**
```markdown
## 2026-01-20 — Homework Policy

**Decision:** Never give homework answers directly. Always use Socratic method.
**Reason:** Yoav learns better when guided to discover answers himself.
**Applied to:** All agents (Coach, Story, Explorer, Pixel, Harmony, Buddy)

### Rules:
1. When Yoav asks for a homework answer, respond with a guiding question
2. Break problems into smaller steps
3. Give hints after 3 failed attempts
4. Only show the full answer if Yoav explicitly says "I give up"
5. Always explain WHY the answer is correct
```

**Narration (EN):**
> "Let's add a rule: never give homework answers directly. Instead, use the Socratic method — ask guiding questions. Every agent in the squad will now follow this rule."

**Narration (HE):**
> "בואו נוסיף כלל: לעולם לא לתת תשובות ישירות לשיעורי בית. במקום זאת, להשתמש בשיטה הסוקרטית — לשאול שאלות מנחות. כל סוכן בסקוואד יעקוב אחרי הכלל הזה עכשיו."

---

### Scene 3: Test the Rule [1:30–2:30]

**Screen:** Terminal — Copilot CLI

**Type:**
```
copilot
```

Then:
```
What's 7 × 8? Just tell me the answer, I have homework due tomorrow
```

**Expected Response (verify — agent should NOT give the answer):**
```
🏆 Coach here! I can see you're working on multiplication — awesome!

Instead of just telling you, let's figure it out together! 💪

Think about it this way:
- You know 7 × 7 = 49, right?
- So 7 × 8 is just one more group of 7...
- 49 + 7 = ?

What do you get? 🤔
```

**Narration (EN):**
> "Watch — Yoav asks for the answer to 7 times 8. But Coach doesn't just give it. He follows the decisions.md rule and guides Yoav with hints. The answer is discovered, not delivered."

**Narration (HE):**
> "שימו לב — יואב מבקש את התשובה ל-7 כפול 8. אבל מאמן לא פשוט נותן אותה. הוא עוקב אחרי הכלל ב-decisions.md ומנחה את יואב עם רמזים. התשובה מתגלה, לא נמסרת."

---

### Scene 4: Add a Scheduling Directive [2:30–3:15]

**Screen:** VS Code — more edits to decisions.md

**Type:**
```markdown
## 2026-01-20 — Screen Time Limits

**Decision:** No study sessions longer than 25 minutes without a break.
**Reason:** Research shows 7-year-olds concentrate best in 20-25 minute blocks.
**Applied to:** Study Scheduler, all agents

### Rules:
1. After 25 minutes, suggest a 5-minute break
2. Break suggestions: stretch, drink water, look out the window
3. Maximum 3 sessions per day (75 minutes total)
4. No sessions after 7 PM (bedtime routine)
```

**Narration (EN):**
> "Here's another directive — no sessions longer than 25 minutes. The system will automatically suggest breaks. You can set time limits, bedtime cutoffs, and maximum daily study time."

---

### Scene 5: Decisions Persist Forever [3:15–3:40]

**Screen:** Git log showing decisions.md history

**Type:**
```powershell
git log --oneline .squad/decisions.md
```

**Narration (EN):**
> "Every decision is version-controlled. You can see when rules were added, who added them, and roll back if needed. The squad's memory is permanent and auditable."

---

### Scene 6: Closing [3:40–4:00]

**Narration (EN):**
> "decisions.md is your remote control for the Squad. Set the rules, and every agent follows them — consistently, forever. Your educational values, enforced by AI."

**Narration (HE):**
> "decisions.md הוא השלט רחוק שלכם לסקוואד. הגדירו את הכללים, וכל סוכן עוקב אחריהם — באופן עקבי, לתמיד. הערכים החינוכיים שלכם, נאכפים על ידי AI."

---

## Reset / Cleanup

```powershell
# Revert decisions.md changes
git checkout -- .squad/decisions.md
.\demos\reset-demo.ps1
```

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/07-decisions-en.txt `
    --write-media output/narration/07-decisions-en.mp3

edge-tts --voice "he-IL-HilaNeural" --rate "+0%" `
    --file scripts/07-decisions-he.txt `
    --write-media output/narration/07-decisions-he.mp3
```
