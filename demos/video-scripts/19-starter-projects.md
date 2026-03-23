# 🎬 Video 19: Starter Projects

> **Title (EN):** Build Something Cool — HTML, JavaScript, Python Projects
> **Title (HE):** תבנו משהו מגניב — פרויקטים ב-HTML, JavaScript, Python

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~5 minutes |
| **Target Audience** | Kids (8-14), parents |
| **Language** | English |
| **Prerequisites** | Student profile, Codespace running |
| **Difficulty** | Beginner to Intermediate |

---

## Key Takeaway

> The Squad includes starter projects that let kids build real things — a superhero webpage, JavaScript games, and Python science experiments. Coding isn't abstract; it's creative and fun.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force

# Check starter projects exist
ls starter-projects/
```

---

## Storyboard

### Scene 1: What Are Starter Projects? [0:00–0:25]

**Narration (EN):**
> "Squad for Kids doesn't just teach concepts — it lets kids build real things. Starter projects are guided coding activities where kids create websites, games, and experiments with AI assistance."

---

### Scene 2: HTML Superhero Page [0:25–1:30]

**Screen:** Codespace editor + browser preview

**Type:**
```
Pixel, I want to make a superhero website!
```

**Expected:**
```
💻 Pixel here! Awesome — let's build your superhero page! 🦸

I've set up a starter project for you:
📁 starter-projects/superhero-page/

Let's start! Open index.html and type your superhero's name:

<html>
<body>
  <h1>🦸 [YOUR SUPERHERO NAME]</h1>
  <p>Superpower: [WHAT CAN THEY DO?]</p>
  <p>Weakness: [EVERY HERO HAS ONE!]</p>
</body>
</html>

What's your superhero's name? 🦸
```

**Type:**
```
Captain Code! His power is turning bugs into features!
```

**Expected:**
```
💻 LOVE IT! 😂 Here's your page:

<html>
<head>
  <title>Captain Code</title>
  <style>
    body { background: #1a1a2e; color: #e94560; font-family: Arial; text-align: center; }
    h1 { font-size: 3em; }
    .power { color: #0f3460; background: #e94560; padding: 10px; border-radius: 10px; }
  </style>
</head>
<body>
  <h1>🦸 Captain Code</h1>
  <p class="power">⚡ Superpower: Turns bugs into features!</p>
  <p>🛡️ Weakness: Infinite loops</p>
  <img src="hero.png" alt="Captain Code">
</body>
</html>

Open the preview to see it! (Ctrl+Shift+V or open in browser)
Want to add more? We can add:
  🎨 Colors and animations
  📸 Draw your hero (or generate an image)
  🔗 Links to other pages
```

**On Screen:** Show the HTML preview rendering in the browser

**Narration (EN):**
> "Yoav creates a superhero webpage — with real HTML and CSS. The Squad generates the code, explains each part, and lets the kid customize. It's not a tutorial — it's creative expression through code."

---

### Scene 3: JavaScript Game [1:30–2:45]

**Type:**
```
Can we make a game?
```

**Expected:**
```
💻 YES! Let's build a number guessing game! 🎮

📁 starter-projects/guess-the-number/

Here's the idea: The computer picks a number between 1 and 100,
and you have to guess it! After each guess, it tells you
"higher" or "lower."

Let's start with the basic code:

// game.js
let secretNumber = Math.floor(Math.random() * 100) + 1;
let guess = prompt("I'm thinking of a number between 1 and 100. Guess!");

if (guess == secretNumber) {
  alert("🎉 You got it!");
} else if (guess < secretNumber) {
  alert("📈 Higher!");
} else {
  alert("📉 Lower!");
}

Try running it! Then we'll add:
  🔄 Multiple guesses
  📊 Guess counter
  🏆 High score tracking
```

**Narration (EN):**
> "A real JavaScript game — not a sandbox or simulation. The kid can run it, play it, and modify it. Each modification teaches a new programming concept: loops, conditionals, variables."

---

### Scene 4: Python Science Experiment [2:45–3:45]

**Type:**
```
What about Python? Can we do a science experiment?
```

**Expected:**
```
💻 Python + Science = AMAZING! 🔬

📁 starter-projects/science-lab/

Let's calculate how long it takes for a ball to hit the ground
when dropped from different heights!

# gravity_experiment.py
import math

def fall_time(height_meters):
    """How long does it take to fall from this height?"""
    g = 9.8  # gravity (m/s²)
    time = math.sqrt(2 * height_meters / g)
    return round(time, 2)

# Test different heights!
heights = [1, 5, 10, 50, 100]  # meters

print("🔬 Gravity Experiment!")
print("=" * 40)
for h in heights:
    t = fall_time(h)
    print(f"Drop from {h}m → hits ground in {t} seconds")

# 🤔 Challenge: What about the Moon? (gravity = 1.6 m/s²)
```

**Expected output:**
```
🔬 Gravity Experiment!
========================================
Drop from 1m → hits ground in 0.45 seconds
Drop from 5m → hits ground in 1.01 seconds
Drop from 10m → hits ground in 1.43 seconds
Drop from 50m → hits ground in 3.19 seconds
Drop from 100m → hits ground in 4.52 seconds
```

**Narration (EN):**
> "A Python script that models real physics. The kid runs it, sees the results, and gets a challenge — what happens on the Moon? This is STEM education that feels like play."

---

### Scene 5: Project Gallery [3:45–4:30]

**Screen:** Show the starter-projects directory

**On Screen:**
```
starter-projects/
├── superhero-page/      🦸 HTML & CSS
├── guess-the-number/    🎮 JavaScript game
├── science-lab/         🔬 Python experiments
├── pixel-art/           🎨 CSS Grid art
├── story-generator/     📖 Random story maker
├── calculator/          🔢 Build a calculator
├── weather-app/         🌤️ API introduction
├── minecraft-mod/       ⛏️ Basic modding concepts
└── quiz-builder/        ❓ Make your own quiz
```

**Narration (EN):**
> "Nine starter projects — each one teaches different skills through creative building. And because it's in a Codespace, there's nothing to install. Open and code."

---

### Scene 6: Closing [4:30–5:00]

**Narration (EN):**
> "The best way to learn to code is to build something you care about. A superhero page, a guessing game, a gravity simulator. The Squad guides, the kid creates. That's real education."

---

## Reset / Cleanup

```powershell
git checkout -- starter-projects/
.\demos\reset-demo.ps1
```

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/19-starter-projects-en.txt `
    --write-media output/narration/19-starter-projects-en.mp3
```
