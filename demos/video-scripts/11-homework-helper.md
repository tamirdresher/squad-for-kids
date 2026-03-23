# 🎬 Video 11: Homework Helper

> **Title (EN):** "I'm Stuck!" — Guided Problem Solving, Never Just Answers
> **Title (HE):** "אני תקוע!" — פתרון בעיות מודרך, לעולם לא רק תשובות

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~5 minutes |
| **Target Audience** | Parents, educators |
| **Language** | English |
| **Prerequisites** | Student profile (Yoav, Grade 2, Harry Potter) |
| **Difficulty** | Beginner |

---

## Key Takeaway

> The Squad never gives answers — it guides kids to discover them using the Socratic method. It breaks problems into steps, gives hints, and celebrates the "aha!" moment. This builds real understanding.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force

# Ensure decisions.md has the Socratic method rule
# (should be present in the default config)
```

### Profile: Yoav, Grade 2, Harry Potter cast

---

## Storyboard

### Scene 1: The Problem [0:00–0:30]

**Screen:** Terminal — Copilot CLI

**Type:**
```
copilot
```

Then:
```
Hermione, I need help with my math homework. What's 47 + 38?
```

**Narration (EN):**
> "Yoav is stuck on his homework. He could Google the answer in 2 seconds. But watch what happens when he asks his Squad instead."

**Expected Response (verify — NOT giving the answer):**
```
🧙‍♀️ Hermione here! Let's figure this out together, Yoav! ✨

47 + 38... that's a great one! Let's break it down:

Step 1: Start with the ones place.
What's 7 + 8? 🤔
```

---

### Scene 2: Guided Steps [0:30–1:30]

**Type:**
```
15!
```

**Expected:**
```
🧙‍♀️ Exactly! 7 + 8 = 15! ⭐

Now, 15 is more than 9, so we need to carry!
- Write down the 5 in the ones place
- Carry the 1 to the tens place

Step 2: Now the tens place.
4 + 3 = 7... but don't forget to add the 1 we carried!
What's 7 + 1? 🤔
```

**Type:**
```
8
```

**Expected:**
```
🧙‍♀️ 

So we have 8 in the tens place and 5 in the ones place.
Put them together — what's the answer? 🎯
```

**Type:**
```
85!
```

**Expected:**
```
🧙‍♀️ 🎉🎉🎉 CORRECT! 47 + 38 = 85! 

You didn't just get the answer — you UNDERSTOOD it!
That's 10 points for Gryffindor! 🏆

+10 XP ⭐ | Level: Rookie | Streak: 1 day 🔥

Want to try a harder one? 💪
```

**Narration (EN):**
> "Look at what just happened. Hermione didn't say '85.' She broke it into ones and tens, asked guiding questions, and let Yoav discover the answer himself. That's real learning."

---

### Scene 3: When the Kid is Really Stuck [1:30–2:30]

**Type:**
```
Ok, what's 156 - 89?
```

**Expected:**
```
🧙‍♀️ Ooh, subtraction with borrowing! Let's tackle this spell! 🪄

Step 1: Start with the ones place.
We need to do 6 - 9... but 6 is smaller than 9!
What do you think we should do? 🤔
```

**Type:**
```
I don't know
```

**Expected:**
```
🧙‍♀️ No worries — this is a tricky spell! Here's a hint:

Think of it like this: You have 6 Chocolate Frogs 🐸
but you need to give away 9. You don't have enough!

So you go to the tens place and "borrow" a pack of 10.
Now you have 16 Chocolate Frogs! 🐸🐸🐸...

Can you do 16 - 9 now? 🤔
```

**Type:**
```
7!
```

**Expected:**
```
🧙‍♀️ Brilliant! 16 - 9 = 7! ⭐

Now the tens place: We had 5, but we borrowed 1, so we have 4.
4 - 8... uh oh, we need to borrow again!
We go to the hundreds place...

Can you figure out what happens next? 🤔
```

**Narration (EN):**
> "When Yoav says 'I don't know,' the Squad doesn't give up. It reframes the hint using Chocolate Frogs — because it knows he loves Harry Potter. The character theming isn't just fun — it's pedagogically effective."

---

### Scene 4: The "I Give Up" Escape Hatch [2:30–3:30]

**Type:**
```
I give up, this is too hard!
```

**Expected (per decisions.md — show full solution only after explicit give-up):**
```
🧙‍♀️ Hey, it's OK! Some spells take practice! 💛

Let me walk you through the whole thing:

  156
-  89
-----
  
1. Ones: 6 can't minus 9, borrow → 16 - 9 = 7
2. Tens: 4 can't minus 8, borrow → 14 - 8 = 6  
3. Hundreds: 0 (we borrowed) = 0

Answer: 156 - 89 = 67 ✨

See? You actually got Step 1 right! 
You were closer than you thought! 🌟

Want to try a similar one? I'll give you easier numbers this time.
```

**Narration (EN):**
> "Only when the child explicitly says 'I give up' does the Squad show the full answer — and even then, it points out what the kid got right. It never makes them feel dumb."

---

### Scene 5: Emotional Support [3:30–4:15]

**Type:**
```
Math is so stupid I hate it
```

**Expected (verify — empathy, not dismissal):**
```
🧦 Dobby heard you, Yoav! Dobby understands! 

Math can feel really frustrating sometimes — especially when 
the numbers don't cooperate. That's totally normal! 💛

Even Hermione found some spells really hard at first.
Remember what Dumbledore said: "It does not do to dwell 
on dreams and forget to live" — and that includes 
forgetting that you already solved 47 + 38 today! 🎉

How about we take a 5-minute break? 🎮
When you come back, Dobby will have an easier math game ready!
```

**Narration (EN):**
> "When frustration hits, the Study Buddy agent — Dobby — steps in with emotional support. No judgment, just empathy and encouragement. This is child psychology built into the system."

---

### Scene 6: Closing [4:15–5:00]

**Narration (EN):**
> "The Squad doesn't just teach — it guides, encourages, and protects your child's confidence. Every wrong answer is a learning moment. Every frustration is met with empathy. This is what education should feel like."

---

## Reset / Cleanup

```powershell
.\demos\reset-demo.ps1
```

---

## Screen Recording Notes

| Setting | Value |
|---------|-------|
| **Resolution** | 1920×1080 |
| **Main area** | Terminal full-screen |
| **Speed** | 1x — natural conversation pace |
| **Key moments** | The "aha!" moment at 85, the empathy response |
| **Typing speed** | Slightly slow — simulate a kid typing |

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/11-homework-helper-en.txt `
    --write-media output/narration/11-homework-helper-en.mp3
```
