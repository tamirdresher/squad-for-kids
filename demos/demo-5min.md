# 🎬 5-Minute Quick Demo — Squad for Kids

> **Runtime:** ~5 minutes | **Audience:** Developers, educators, parents
> **Prerequisites:** GitHub Copilot CLI installed, this repo cloned

---

## Pre-Demo Setup

```powershell
# Run from the repo root — sets up a clean environment
.\demos\run-demo.ps1 -Mode Fresh
```

This removes any existing student profile so the onboarding flow triggers naturally.

---

## Scene 1: Parent Starts [0:00–0:30]

**Context:** A parent opens their terminal in the squad-for-kids repo for the first time.

**What to do:** Open GitHub Copilot CLI in the repo root.

```
cd C:\temp\squad-for-kids
copilot
```

**Type:**
```
hi
```

**Expected behavior:** The Squad agent detects NO `.squad/student-profile.json` and enters Init Mode. It will display:

```
🎉 Welcome to Squad for Kids! 🎉

I'm going to build you your very own team of awesome learning helpers!
But first, I need to get to know you a little bit. Ready? Let's go! 🚀

What's your first name?
```

> 💡 **Demo tip:** Pause briefly after the welcome to let the audience read it.

---

## Scene 2: Kid Onboarding [0:30–1:30]

**Type each response when prompted:**

**Prompt:** "What's your first name?"
```
Yoav
```

**Prompt:** "When's your birthday? 🎂"
```
March 12, 2018
```

**Prompt:** "What grade are you in?"
```
2nd grade
```

**Prompt:** "What city do you live in? 🏙️"
```
Rishon LeZion
```

**Expected behavior:** Squad auto-detects:
- **Country:** Israel 🇮🇱
- **Curriculum:** Israeli Ministry of Education (תכנית הלימודים)
- **Subjects:** Math, Hebrew, Reading, Science, English, Bible Studies, Art, PE, Social Skills
- **Default language:** Hebrew

> 💡 **Demo tip:** Point out that curriculum detection is automatic — the parent just says a city, and Squad figures out the rest.

---

## Scene 3: Language Choice [1:30–2:00]

**Expected prompt from Squad:**
```
🗣️ Since you're in Israel, I'll talk to you in Hebrew (עברית).
Would you like that, or would you prefer a different language?
```

**Type:**
```
English please
```

**Expected behavior:** Squad confirms English and continues all interactions in English.

> 💡 **Demo tip:** Mention that Squad supports 10+ languages and auto-detects based on location. Parents can override at any time.

---

## Scene 4: Universe Pick [2:00–2:45]

**Expected prompt from Squad:**
```
🎬 One more fun question, Yoav!
What's your FAVORITE movie, show, book, or game?
(This is going to be really cool, I promise! 😎)
```

**Type:**
```
Harry Potter
```

**Expected behavior:** Squad casts the team from the Harry Potter universe. It selects characters whose personality matches each role.

> 💡 **Demo tip:** This is the magic moment. Explain that Squad maps educational roles to characters kids LOVE. It works with ANY universe — Minecraft, Frozen, Pokémon, Spider-Man, whatever the kid picks.

---

## Scene 5: Team Reveal [2:45–3:30]

**Expected output (the Grand Reveal):**

```
🎉✨ Yoav, YOUR SQUAD IS READY! ✨🎉

Meet your amazing learning team:

🎓 Hermione Granger — Your Head Teacher
   "I'll make sure you learn everything you need for grade 2!
    Organization and preparation are key — let's make a plan!"

📚 Hagrid — Your Science & Subject Helper
   "Don' worry, we'll figure it out together! I know a thing or two
    about creatures, nature, and how the world works!"

🎨 Luna Lovegood — Your Creative Coach
   "The things others find strange are usually the most interesting.
    Let's create something nobody's ever seen before!"

🎮 Fred Weasley — Your Gamer
   "Right then — fancy a challenge? I've got games that'll make
    your brain do backflips! Wanna play?"

🎬 George Weasley — Your YouTuber
   "Welcome to today's episode! I'm going to explain this so well,
    even Percy would be impressed. Ready? Action!"

🤗 Dobby — Your Study Buddy
   "Dobby is here to help! Dobby believes in you, and Dobby will
    always be here when you need a friend. 💙"

Ready to start learning? Just tell me what you'd like to work on! 🚀
```

> 💡 **Demo tip:** Let this sink in. Point out how each character's personality matches their role perfectly. Hermione = organized head teacher. Hagrid = warm science helper. Fred = competitive gamer. George = entertainer. Dobby = unconditional support.

---

## Scene 6: First Lesson [3:30–4:30]

**Type:**
```
Let's do some math!
```

**Expected behavior:** Hermione (Head Teacher) kicks off a grade-2 math warmup, Israeli curriculum:

```
🎓 Hermione: Excellent choice, Yoav! A proper wizard always knows their numbers!

Let's start with a quick warm-up! 🧙‍♀️

📐 Challenge 1: If you have 7 chocolate frogs and Hagrid gives you 8 more,
   how many chocolate frogs do you have now?

Take your time — even I double-check my arithmetic! 📝
```

**Type:**
```
15
```

**Expected:**
```
🎓 Hermione: 🌟 BRILLIANT, Yoav! 7 + 8 = 15 — absolutely correct!
   +10 XP! You're on your way to becoming a math wizard! 🧙‍♀️

   Ready for the next one?

📐 Challenge 2: Yoav has 23 Bertie Bott's Every Flavour Beans.
   He eats 9 of them (hopefully not the earwax ones! 🤢).
   How many does he have left?
```

> 💡 **Demo tip:** Point out how the math problems are age-appropriate (grade 2, addition/subtraction within 100) AND themed to Harry Potter. The curriculum drives the difficulty; the universe drives the fun.

---

## Scene 7: Parent Report [4:30–5:00]

**Type:**
```
Show me the parent report
```

**Expected behavior:** Scribe generates a weekly report summary. Even with just one session, it shows:

```
📊 Weekly Learning Report — Yoav

📈 Week at a Glance
┌─────────────────────┬──────────────────────┐
│ Sessions this week   │ 1                    │
│ Total learning time  │ ~5 minutes           │
│ Subjects covered     │ Mathematics          │
│ XP earned           │ +20 XP               │
│ Current level       │ Level 1: Rookie      │
│ Streak              │ 1 day 🔥             │
└─────────────────────┴──────────────────────┘

💪 Strengths: Quick mental arithmetic, addition confidence
🎯 Practice needed: Will discover as more sessions happen
💡 Recommendation: Yoav responded well to Harry Potter themed
   problems — keep using character references for engagement!
```

> 💡 **Demo tip:** Explain that full reports go to `.squad/reports/weekly-{date}.md` and the parent squad (upstream) gets these automatically.

---

## End [5:00]

**Type:**
```
Thanks, bye!
```

**Expected:**
```
🤗 Dobby: Dobby was so happy to learn with Yoav today!
   Dobby will be right here whenever you want to come back! 💙

🎓 Hermione: Great first session, Yoav! See you next time — we have
   SO much more to explore! ✨

📊 Session saved. +20 XP earned today!
```

---

## Quick Reference

| Step | Time | Prompt | Key Point |
|------|------|--------|-----------|
| 1. Welcome | 0:00 | `hi` | Auto-detects first-time setup |
| 2. Onboarding | 0:30 | Name, birthday, grade, city | 4 questions, auto-detects curriculum |
| 3. Language | 1:30 | `English please` | Multilingual, auto-suggests |
| 4. Universe | 2:00 | `Harry Potter` | Works with ANY franchise |
| 5. Team Reveal | 2:45 | (automatic) | Characters match roles |
| 6. First Lesson | 3:30 | `Let's do some math!` | Curriculum-aligned + themed |
| 7. Parent Report | 4:30 | `Show me the parent report` | Auto-generated analytics |
