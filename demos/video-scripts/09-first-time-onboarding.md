# 🎬 Video 09: First-Time Onboarding

> **Title (EN):** Meet Your Squad — The First 60 Seconds
> **Title (HE):** הכירו את הסקוואד שלכם — 60 השניות הראשונות

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~5 minutes |
| **Target Audience** | Parents, educators, kids (family viewing) |
| **Language** | English |
| **Prerequisites** | Forked repo, NO existing student profile |
| **Difficulty** | Beginner |

---

## Key Takeaway

> A child's first interaction with Squad is magical — the system asks their name, age, grade, city, and interests, then builds a personalized team of AI agents. The entire onboarding takes under 60 seconds.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids

# CRITICAL: Remove any existing profile so onboarding triggers
Remove-Item .squad/student-profile.json -ErrorAction SilentlyContinue
Remove-Item kids-study/ -Recurse -ErrorAction SilentlyContinue

# Verify clean state
Test-Path .squad/student-profile.json  # Should be False

# Set simplified prompt
function prompt { "squad-for-kids> " }
```

### Profile Setup

**None** — this demo shows profile creation from scratch.

---

## Storyboard

### Scene 1: Cold Start [0:00–0:20]

**Screen:** Terminal at repo root

**Type:**
```
copilot
```

Then:
```
hi
```

**Narration (EN):**
> "This is what a child sees the very first time. No profile exists yet. The Squad detects this and enters onboarding mode — friendly, colorful, and designed for a 7-year-old."

**Expected Response (verify):**
```
🎉 Welcome to Squad for Kids! 🎉

I'm going to build you your very own team of awesome learning helpers!
But first, I need to get to know you a little bit. Ready? Let's go! 🚀

What's your first name?
```

---

### Scene 2: Name & Birthday [0:20–1:00]

**Prompt:** "What's your first name?"
**Type:**
```
Yoav
```

**Expected:**
```
Nice to meet you, Yoav! 👋

When's your birthday? 🎂 (So I know how old you are!)
```

**Type:**
```
March 12, 2018
```

**Expected:**
```
Awesome! You're 7 years old! 🎂

What grade are you in at school?
```

**Narration (EN):**
> "The system is warm and encouraging. It uses emojis, simple language, and celebrates each answer. This isn't a boring form — it's a conversation."

---

### Scene 3: Grade & Location [1:00–1:45]

**Prompt:** "What grade are you in?"
**Type:**
```
2nd grade
```

**Prompt:** "What city do you live in?"
**Type:**
```
Rishon LeZion
```

**Expected (verify — curriculum auto-detection):**
```
🇮🇱 Cool — Rishon LeZion, Israel!

I found the right curriculum for you:
📚 Israeli Ministry of Education (תכנית הלימודים)

Your subjects:
  🔢 Mathematics (חשבון)
  📖 Hebrew Language (עברית)
  📕 Reading Comprehension (הבנת הנקרא)
  🔬 Science & Technology (מדע וטכנולוגיה)
  🇬🇧 English (אנגלית)
  📜 Bible Studies (תנ"ך)
  🎨 Art (אמנות)
  ⚽ Physical Education (חינוך גופני)
  🤝 Social Skills (כישורי חיים)

Does this look right? 👍
```

**Narration (EN):**
> "Here's the magic — Yoav just says his city, and the Squad auto-detects the country, curriculum system, and all the right subjects. Israeli curriculum, Hebrew language, grade-appropriate content. No configuration needed."

---

### Scene 4: Interests [1:45–2:15]

**Type:**
```
yes! I love Harry Potter and Minecraft
```

**Expected:**
```
Harry Potter AND Minecraft?! Amazing taste! 🧙‍♂️⛏️

I'm going to use these to make learning super fun for you!

Now for the best part... 🥁
```

---

### Scene 5: Universe Selection [2:15–3:00]

**Expected (Squad presents options):**
```
🎬 Pick Your Universe!

Your learning team can be characters from your favorite world:

1. 🧙‍♂️ Harry Potter — Hermione teaches, Hagrid explores, Dobby helps
2. ⛏️ Minecraft — Steve builds, Alex explores, Villager trades knowledge
3. ⭐ Star Wars — Yoda teaches, R2-D2 computes, Chewbacca encourages
4. 🦸 Superheroes — Spider-Man solves, Batman investigates
5. 🎮 Custom — pick your own characters!

Which world do you want? (type the number)
```

**Type:**
```
1
```

**Expected:**
```
🧙‍♂️ Excellent choice! Welcome to Hogwarts Academy!

Your Squad is ready:

  🏆 Hermione Granger — Head Teacher (Math & Logic)
  🧔 Hagrid — Explorer (Science & Nature)
  🌙 Luna Lovegood — Creative Coach (Arts & Writing)
  👯 Fred Weasley — Gamer (Digital Skills & Fun)
  👯 George Weasley — YouTuber (Videos & Projects)
  🧦 Dobby — Study Buddy (Homework & Encouragement)

Your profile has been saved! Let's start learning! 🚀
```

**Narration (EN):**
> "Yoav picks Harry Potter and instantly gets a full squad of Hogwarts characters — each one mapped to a learning specialty. Hermione handles math. Hagrid teaches science. Dobby is always there to help with homework."

---

### Scene 6: Verify Profile [3:00–3:30]

**Screen:** Show the generated profile file

**Type:**
```
Can you show me my profile?
```

**Expected:** Squad displays the student-profile.json summary

**Alternatively, show the file directly:**
```powershell
cat .squad/student-profile.json
```

---

### Scene 7: First Learning Interaction [3:30–4:30]

**Type:**
```
Hermione, can you teach me something cool today?
```

**Expected Response (verify — themed, age-appropriate):**
```
🧙‍♀️ Of course, Yoav! Since you're in 2nd grade and we just met,
let me start with something magical...

Did you know that math is like magic spells? ✨

Here's your first spell:
🔢 The Doubling Charm: 2 × 2 = 4, 2 × 4 = 8, 2 × 8 = 16...

See the pattern? Each number doubles!
What do you think 2 × 16 equals? 🤔
```

---

### Scene 8: Closing [4:30–5:00]

**Narration (EN):**
> "In under a minute, Yoav went from zero to having a full personalized learning team. His curriculum, his language, his favorite characters, his pace. That's Squad for Kids."

---

## Reset / Cleanup

```powershell
Remove-Item .squad/student-profile.json -ErrorAction SilentlyContinue
Remove-Item kids-study/ -Recurse -ErrorAction SilentlyContinue
.\demos\reset-demo.ps1
```

---

## Screen Recording Notes

| Setting | Value |
|---------|-------|
| **Resolution** | 1920×1080 |
| **Main area** | Terminal full-screen |
| **Speed adjustments** | Keep at 1x — this should feel natural and conversational |
| **Pause points** | After curriculum detection, after universe reveal |
| **Key moment** | The squad roster reveal — let it breathe on screen for 5 seconds |

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/09-onboarding-en.txt `
    --write-media output/narration/09-onboarding-en.mp3
```
