# 🎬 10-Minute Full Demo — Squad for Kids

> **Runtime:** ~10 minutes | **Audience:** Conference talks, deep-dives, investor pitches
> **Prerequisites:** GitHub Copilot CLI installed, this repo cloned
> **Includes:** Everything from the 5-min demo + Gamer, YouTuber, Study Buddy, grade transition, parent squad, Hebrew mode

---

## Pre-Demo Setup

```powershell
# Fresh start for the full demo
.\demos\run-demo.ps1 -Mode Fresh
```

---

## Part 1: Scenes 1–7 [0:00–5:00]

**Follow the [5-Minute Quick Demo](demo-5min.md) for Scenes 1–7.**

At the end of Scene 7, Yoav has a complete profile, a Harry Potter team, and has done a quick math warmup.

---

## Scene 8: Gamer in Action — Fred Weasley [5:00–6:00]

**Context:** Fred Weasley (the Gamer) challenges Yoav to a math game.

**Type:**
```
I want to play a game!
```

**Expected behavior:** Fred Weasley takes over:

```
🎮 Fred: OI! Someone said the magic word — GAME! 🎯

Alright Yoav, here's what we're playing today:

⚡ QUIDDITCH MATH CHALLENGE ⚡

I'm going to throw math problems at you like Bludgers, and you
have to hit them back with the right answers! Score 5 to catch
the Golden Snitch! 🏆

Each correct answer = 1 goal. Miss = the Bludger gets past you.
Ready, Keeper?

🏐 Bludger 1: What's 6 × 3?
   ⏱️ Quick — it's coming fast!
```

**Type:**
```
18
```

**Expected:**
```
🎮 Fred: WHAM! 💥 You smashed that one! 6 × 3 = 18 — GOAL!
   Score: Yoav 1 – Bludgers 0

🏐 Bludger 2: What's 45 - 17?
   ⏱️ Incoming!
```

**Type:**
```
28
```

**Expected:**
```
🎮 Fred: Another BRILLIANT save! 💪 45 - 17 = 28!
   Score: Yoav 2 – Bludgers 0

   +10 XP per goal! Keep this up and the Quidditch Cup is OURS!

🏐 Bludger 3: What's 8 + 7 + 5?
```

> 💡 **Demo tip:** Point out that Fred gamifies the exact same curriculum-aligned math — but the kid thinks they're playing Quidditch, not doing homework. The difficulty is auto-adjusted for grade 2.

**After a few rounds, type:**
```
Can I stop for now?
```

**Expected:**
```
🎮 Fred: Brilliant match, Yoav! Final score:
   ⚡ Yoav 3 – Bludgers 0 ⚡
   You'd make a proper Gryffindor Keeper! 🦁

   +30 XP earned in Quidditch Math!
   🏆 New personal best!

   Want to play again later? I've got loads more games!
```

---

## Scene 9: YouTuber in Action — George Weasley [6:00–7:00]

**Context:** George Weasley (the YouTuber) explains a science concept like a YouTube video.

**Type:**
```
George, can you explain why it rains?
```

**Expected behavior:** George launches into a YouTube-style explanation:

```
🎬 George: *adjusts camera* 

Welcome back to George's WICKED SCIENCE! 🧪
Episode 47: "Why Water Falls From the Sky
(And No, It's Not a Charm Gone Wrong)" 💧

*intro music plays in your imagination* 🎵

Okay Yoav, here's the deal. You know how when you
boil water for tea, steam rises up? ☕💨

That's EVAPORATION — water turning into an invisible gas
and floating up into the sky. It's like the water is saying
"I'm outta here!" and zooming upward.

Now, up in the sky it's COLD. Like, Dementor-cold. ❄️
And when that invisible water gas gets cold enough...
it turns back into tiny water droplets!

A BILLION of those tiny droplets together = a cloud! ☁️

And when the cloud gets SO full it can't hold any more...
*drumroll* 🥁

IT RAINS! 🌧️

That's basically a water recycling system that's been running
for BILLIONS of years. Pretty wicked, right?

🧠 POP QUIZ: What's the word for water turning into gas?
   (Hint: starts with E!)
```

**Type:**
```
Evaporation!
```

**Expected:**
```
🎬 George: 🎉 DING DING DING! EVAPORATION! 

If you liked this episode, smash that... well, there's no
like button, but tell Hermione I taught you something!
She never believes me. 😤

+15 XP for Science!

🔔 Next episode: "Where Does the Sun Go at Night?"
   (Spoiler: it doesn't actually go anywhere! Mind. Blown. 🤯)
```

> 💡 **Demo tip:** Point out that George uses YouTube creator language naturally — "episodes," "pop quiz," "smash that like button." Kids who watch YouTube ALL DAY get content in a format they already love. But it's teaching real science from the Israeli grade 2 curriculum.

---

## Scene 10: Study Buddy — Dobby [7:00–7:45]

**Context:** Yoav hits a frustration moment.

**Type:**
```
this is hard, I can't do math
```

**Expected behavior:** Dobby (Study Buddy) detects frustration and responds:

```
🤗 Dobby: *sits down next to Yoav*

Dobby hears you, Yoav. And Dobby wants you to know something
very important:

Math IS hard sometimes. Even Hermione says so!
And feeling frustrated doesn't mean you're bad at it.
It means your brain is GROWING. 🌱

You know what? Dobby couldn't do ANYTHING at first.
But Dobby kept trying, and now look — Dobby helps
the bravest wizards at Hogwarts! 💪

Here's what we can do right now:
  1. 🎮 Take a brain break with Fred (play a quick game?)
  2. 🔄 Try the same math a different way
  3. 🎨 Do something creative with Luna for a bit
  4. 💬 Just chat — Dobby is here to listen

What sounds good? There's no wrong answer! 💙
```

> 💡 **Demo tip:** THIS is the moment that matters most for parents watching. Point out:
> - Dobby never says "it's easy" or "just try harder"
> - Validates the feeling FIRST, then offers options
> - Uses Harry Potter to normalize struggle
> - The kid has AGENCY — they choose what to do next
> - Dr. Sarah (child psychologist on the dev team) designed this protocol

**Type:**
```
let's play a game with Fred
```

**Expected:**
```
🤗 Dobby: That's a WONDERFUL choice! Dobby will tell Fred
   you're ready for some fun! 🎮💫

   (Dobby will be right here if you need me later! 💙)

🎮 Fred: Oi! Dobby says you need a pick-me-up!
   How about something easy and fun — Wizard Trivia! 🧙

   Question 1: What's the name of Harry's owl?
   a) Crookshanks  b) Hedwig  c) Scabbers  d) Errol
```

> 💡 **Demo tip:** The transition from Study Buddy → Gamer is seamless. The brain break is still educational (trivia) but feels like pure fun. After the break, the kid can return to math refreshed.

---

## Scene 11: Grade Transition [7:45–8:30]

**Context:** Fast-forward demonstration. We simulate what happens when Ralph detects a new school year.

**What to do:** Load the grade-3 transition profile:

```powershell
# In a separate terminal (not shown in demo) or pause recording:
Copy-Item "demos\profiles\yoav-grade3-transition.json" ".squad\student-profile.json" -Force
```

**Then in the Copilot session, type:**
```
hi
```

**Expected behavior:** Ralph detects the grade transition and triggers the celebration:

```
🔄 Ralph: *checks calendar* Hold on... 📅

🎉🎊✨ AMAZING NEWS, Yoav!! ✨🎊🎉

You're now in GRADE 3! 🎓

🎓 Hermione is SO proud of you! An entire year of learning
   completed — that's a LOT of knowledge!

Your team is updating with new exciting subjects and topics...

🆕 New this year:
  - 📐 Geometry (גיאומטריה) — shapes, angles, measurement!
  - 💻 Computer Science (מדעי המחשב) — coding begins!
  - 📚 Deeper English — longer reading, writing paragraphs

Your squad is ready for grade 3:
  🎓 Hermione — Updated lesson plans for grade 3!
  📚 Hagrid — New science experiments coming!
  🎮 Fred — Grade 3 challenges unlocked!
  🎬 George — New episodes filmed!
  🤗 Dobby — Still here, always! 💙

📊 Your year in review:
  🏆 Level 6: Champion (2,450 XP!)
  🎖️ 5 badges earned
  🔥 Best streak: 12 days
  📚 Covered: Math, Hebrew, Reading, Science, English

Let's make grade 3 your BEST year yet! 🚀
```

> 💡 **Demo tip:** Explain that Ralph runs this check on EVERY session start. When the date passes September 1st, it auto-detects the transition. The curriculum lookup re-runs for the new grade. No parent intervention needed.

---

## Scene 12: Parent Squad [8:30–9:15]

**Context:** Show the parent's view — their upstream squad that monitors the child.

**What to do:** Switch to the parent-squad demo directory:

```
cd demos/parent-squad
copilot
```

**Type:**
```
How is Yoav doing?
```

**Expected behavior:** The parent squad loads from upstream and shows:

```
📊 Parent Dashboard — Yoav's Learning Progress

Hi! Here's what I know about Yoav's recent learning:

📈 This Week's Summary
┌─────────────────────────┬──────────────────────────┐
│ Total sessions          │ 4                        │
│ Learning time           │ 2 hours 15 minutes       │
│ Subjects covered        │ Math, Science, English   │
│ XP earned              │ +185 XP                  │
│ Current level          │ Level 6: Champion ⭐      │
│ Streak                 │ 12 days 🔥               │
└─────────────────────────┴──────────────────────────┘

💪 Strengths
  • Addition and subtraction — very confident
  • Science curiosity — asks great questions
  • Loves the Harry Potter theme — high engagement

🎯 Areas for Practice
  • Multiplication tables (7s and 8s need more work)
  • Word problems — understands operations but struggles
    with identifying which one to use

😊 Engagement & Mood
  • Overall: HIGH — Yoav looks forward to sessions
  • One frustration moment with multiplication (Dobby helped!)
  • Loves Fred's Quidditch Math game

💡 Recommendations
  1. Practice multiplication during car rides — Yoav is close!
  2. Visit the Weizmann Institute science museum — he loved
     the water cycle lesson
  3. Read Harry Potter chapter books together — boosts both
     English and reading comprehension

📅 Coming Up
  • Monday: Math — Introduction to multiplication by 9
  • Wednesday: Science — Magnets and forces
  • Friday: Creative project + review game
```

> 💡 **Demo tip:** Explain that this is a REAL upstream squad connection. The parent never sees the actual learning session — just summaries. Privacy by design. The parent squad is a separate repo with its own `.squad/` config.

---

## Scene 13: Hebrew Mode [9:15–10:00]

**Context:** Switch the language to Hebrew and show the "חברים ללמידה" (Haverim Lelimud) team.

**Go back to the main repo:**
```
cd C:\temp\squad-for-kids
```

**Type:**
```
switch to Hebrew / עבור לעברית
```

**Expected behavior:** Squad switches to full Hebrew mode:

```
🗣️ !בסדר, עוברים לעברית

!יואב, הצוות שלך מדבר עכשיו בעברית 🇮🇱

:הכירו את הצוות בעברית

🎓 הרמיוני גריינג'ר — המורה הראשית
   "!אני אדאג שתלמד הכל לכיתה ב׳"

📚 האגריד — עוזר המקצועות
   "!אל תדאג, ביחד נגלה הכל"

🎨 לונה לאבגוד — מאמנת היצירתיות
   "!בוא ניצור משהו שאף אחד לא ראה"

🎮 פרד ויזלי — הגיימר
   "?מוכן לאתגר"

🎬 ג'ורג' ויזלי — היוטיובר
   "!ברוכים הבאים לפרק של היום"

🤗 דובי — חבר ללמידה
   "💙 !דובי פה בשבילך, תמיד"

?מה תרצה ללמוד
```

**Type:**
```
בוא נעשה חשבון
```

**Expected — Hermione teaches math in Hebrew:**
```
🎓 הרמיוני: !בחירה מעולה, יואב

:בואו נתחיל עם חימום 🧙‍♀️

📐 אתגר 1: אם יש לך 7 צפרדעי שוקולד והאגריד נותן לך עוד 8,
   ?כמה צפרדעי שוקולד יש לך עכשיו

!קח את הזמן — גם אני תמיד בודקת פעמיים 📝
```

> 💡 **Demo tip:** Point out:
> - The ENTIRE interface flipped to Hebrew — names, prompts, content
> - The Harry Potter characters keep their personality but speak Hebrew
> - Curriculum content is the same (Israeli Ministry of Education math)
> - RTL text direction is natural
> - The "חברים ללמידה" template from `.squad/templates/` is the basis

---

## End [10:00]

**Type:**
```
!תודה, להתראות
```

**Expected:**
```
🤗 !דובי: דובי כל כך נהנה ללמוד עם יואב היום
   💙 !דובי יהיה פה כשתרצה לחזור

🎓 הרמיוני: מפגש מעולה, יואב! נתראה בפעם הבאה —
   ✨ !יש לנו עוד כל כך הרבה לגלות

!XP +20 :📊 המפגש נשמר. נצברו
```

---

## Full Demo Timeline

| Step | Time | What Happens | Key Insight |
|------|------|-------------|-------------|
| 1-7 | 0:00–5:00 | Quick demo (onboarding → first lesson) | See demo-5min.md |
| 8. Gamer | 5:00–6:00 | Fred's Quidditch Math Challenge | Gamification = learning in disguise |
| 9. YouTuber | 6:00–7:00 | George explains rain | YouTube format for Gen Alpha |
| 10. Study Buddy | 7:00–7:45 | Dobby handles frustration | Emotional safety first |
| 11. Grade Transition | 7:45–8:30 | Ralph upgrades to grade 3 | Auto-detects, zero parent friction |
| 12. Parent Squad | 8:30–9:15 | Parent dashboard via upstream | Privacy-first parent visibility |
| 13. Hebrew Mode | 9:15–10:00 | Full Hebrew team in action | True multilingual, RTL support |
