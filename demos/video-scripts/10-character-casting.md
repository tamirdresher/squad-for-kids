# 🎬 Video 10: Character Casting

> **Title (EN):** Your Agents, Your Characters — Universe Selection
> **Title (HE):** הסוכנים שלכם, הדמויות שלכם — בחירת עולם

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~3 minutes |
| **Target Audience** | Kids, parents |
| **Language** | English |
| **Prerequisites** | Existing student profile |
| **Difficulty** | Beginner |

---

## Key Takeaway

> Kids pick their favorite fictional universe — Harry Potter, Minecraft, Star Wars — and all Squad agents transform into characters from that world. This makes learning feel like play.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force

# Modify profile to have NO cast universe yet (to show selection)
$profile = Get-Content .squad/student-profile.json | ConvertFrom-Json
$profile.castUniverse = $null
$profile.cast = $null
$profile | ConvertTo-Json -Depth 10 | Set-Content .squad/student-profile.json
```

---

## Storyboard

### Scene 1: Why Casting Matters [0:00–0:20]

**Narration (EN):**
> "Kids don't want to talk to 'Math Agent' and 'Science Agent.' They want to talk to Hermione and Hagrid. Character casting makes every interaction feel like an adventure."

---

### Scene 2: Choose a Universe [0:20–1:00]

**Screen:** Terminal — Copilot CLI

**Type:**
```
I want to pick my squad characters!
```

**Expected (universe selection menu):**
```
🎬 Choose Your Universe!

1. 🧙‍♂️ Harry Potter
   Hermione teaches, Hagrid explores, Luna creates, Fred & George entertain, Dobby helps

2. ⛏️ Minecraft
   Steve builds, Alex explores, Villager teaches, Creeper challenges, Wolf companions

3. ⭐ Star Wars
   Yoda teaches wisdom, R2-D2 computes, Chewbacca encourages, BB-8 organizes

4. 🦸 Marvel/DC Superheroes
   Spider-Man problem-solves, Batman investigates, Iron Man engineers

5. 🎮 Custom — pick your own characters from any universe!
```

**Type:**
```
2
```

**Expected (Minecraft cast reveal):**
```
⛏️ Welcome to Minecraft Academy!

Your new Squad:
  ⛏️ Steve — Head Teacher (builds knowledge block by block)
  🗡️ Alex — Explorer (discovers new topics like new biomes)
  🏘️ Villager — Curriculum Master (trades emeralds for wisdom)
  🧟 Creeper — Quiz Master (surprise tests — don't explode!)
  🐺 Wolf — Study Buddy (loyal companion, always by your side)
  🎨 Allay — Creative Coach (collects ideas and brings them to life)

Ready to craft some knowledge? ⛏️
```

**Narration (EN):**
> "Yoav picks Minecraft, and suddenly Steve is his teacher, Alex explores science with him, and the Creeper gives surprise quizzes. Same learning content — completely different experience."

---

### Scene 3: See the Difference [1:00–1:45]

**Type:**
```
Steve, teach me about gravity
```

**Expected (Minecraft-themed response):**
```
⛏️ Steve here! Great question, builder!

You know how in Minecraft, when you break a block under sand,
the sand falls down? 🟡⬇️

That's GRAVITY! In the real world, gravity is the force that
pulls everything toward the ground — just like sand blocks fall
in Minecraft.

🧪 Try this experiment:
Drop a feather and a book at the same time.
Which hits the ground first? 🤔

(Hint: In Minecraft, all blocks fall at the same speed...
but in real life, it's different! Why do you think?)
```

**Narration (EN):**
> "Steve teaches gravity using Minecraft concepts — falling sand blocks. The lesson is identical in content to what any other universe would teach, but the framing makes it instantly relatable."

---

### Scene 4: Switch Universe [1:45–2:30]

**Type:**
```
Can I switch to Star Wars?
```

**Expected:**
```
⭐ May the Force be with you, Yoav!

Your new Squad:
  🟢 Yoda — Head Teacher ("Learn fractions, you will!")
  🤖 R2-D2 — Math & Logic (beeps and computes)
  🐻 Chewbacca — Encourager (RRRAAAARGH = "You can do it!")
  🔵 BB-8 — Organizer (rolls around keeping you on track)
  ✨ Rey — Explorer (discovers new topics)
  💬 C-3PO — Language Teacher (6 million forms of communication!)

Switching complete! The Force is strong with this one! ⭐
```

**Narration (EN):**
> "Want to switch? Just ask. The agents swap characters instantly — all your progress, lessons, and XP stay the same. Only the personalities change."

---

### Scene 5: Closing [2:30–3:00]

**Narration (EN):**
> "Every child has a world they love. Squad for Kids meets them there. Hermione, Steve, Yoda — they're all great teachers. The child picks, the Squad adapts."

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
| **Speed adjustments** | 1x — let the character reveals breathe |
| **Key moments** | Cast roster reveals — pause 3-5 seconds each |

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/10-character-casting-en.txt `
    --write-media output/narration/10-character-casting-en.mp3
```
