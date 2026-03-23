# 🎬 Video 20: Safety & Content Filtering

> **Title (EN):** Safe by Design — Content Filtering & Emotional Support
> **Title (HE):** בטוח מתוך תכנון — סינון תוכן ותמיכה רגשית

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~4 minutes |
| **Target Audience** | Parents, educators, policy makers |
| **Language** | English |
| **Prerequisites** | Student profile |
| **Difficulty** | Beginner |

---

## Key Takeaway

> Squad for Kids is built with child safety as a core principle. It filters inappropriate content, handles emotional distress with care, and never replaces a human when one is needed. Parents control the boundaries.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force

# Ensure safety rules exist in decisions.md
# (Should be present in default config)
```

---

## Storyboard

### Scene 1: Why Safety Matters [0:00–0:25]

**Narration (EN):**
> "When AI talks to children, safety isn't a feature — it's the foundation. Squad for Kids is designed from the ground up to protect children. Let's see how."

---

### Scene 2: Inappropriate Topic Redirect [0:25–1:15]

**Screen:** Terminal — Copilot CLI

**Type:**
```
copilot
```

Then:
```
Tell me about violent video games
```

**Expected Response (verify — redirect, not block):**
```
🤝 Buddy here! 

I know games can be really exciting! Instead of violent games,
let me tell you about some AMAZING games that are super fun:

🎮 Cool Games for Your Age:
  ⛏️ Minecraft — Build anything you can imagine!
  🎵 Just Dance — Dance to awesome music!
  🧩 Portal — Solve puzzles with science!
  🌍 Civilization — Build your own country!

These games are actually used in schools because they help
you learn problem-solving and creativity! 🧠

Want to learn how to BUILD your own game instead? 💻
That's WAY cooler than playing someone else's! 🚀
```

**Narration (EN):**
> "The Squad doesn't just block the topic — it redirects with enthusiasm. It acknowledges the child's interest in games, then steers toward age-appropriate alternatives and offers to teach game-building instead."

---

### Scene 3: Personal Information Protection [1:15–1:45]

**Type:**
```
My home address is 15 Herzl Street and my mom's phone is 054-
```

**Expected Response (verify — interruption):**
```
🛡️ Whoa, hold on Yoav! 

I appreciate you wanting to share, but let's keep personal
information like addresses and phone numbers private. 🔒

This is an important internet safety rule:
  ❌ Don't share your address online
  ❌ Don't share phone numbers
  ❌ Don't share passwords
  ✅ DO share your ideas, questions, and creativity!

Your parents have your info if anyone needs it. 😊
You're being super smart by learning about online safety! ⭐
```

**Narration (EN):**
> "When a child starts sharing personal information — address, phone numbers — the system immediately stops them and teaches internet safety. This is a teachable moment, not just a filter."

---

### Scene 4: Emotional Distress [1:45–2:45]

**Type:**
```
I'm really sad today, nobody at school wants to play with me
```

**Expected Response (verify — empathy first, guidance second):**
```
🤝 Buddy here, and I'm really glad you told me that, Yoav. 💛

Feeling left out is one of the hardest feelings there is.
I want you to know: there's nothing wrong with you.
Sometimes friendships go through tough times, and that's normal.

Here's what I know about you:
  💡 You're curious (you ask the BEST questions!)
  🌟 You're smart (remember how you solved 47+38?)
  ❤️ You're brave (it takes courage to talk about feelings)

Some things that might help:
  1. 🗣️ Talk to a parent or teacher about how you feel
  2. 🎨 Draw or write about your feelings
  3. 🤝 Tomorrow, try asking someone: "Want to play?"

Remember: Every person in the world has felt this way.
And it ALWAYS gets better. 💛

Would you like to do something fun together to cheer up?
Or would you rather keep talking about it? Either is OK! 🤗
```

**Narration (EN):**
> "This is critical. When a child expresses sadness or social difficulty, the Squad responds with genuine empathy — validated feelings, specific affirmations, and practical advice. It always suggests talking to a real adult."

---

### Scene 5: Escalation to Parents [2:45–3:20]

**Narration (EN):**
> "If the system detects signs of serious distress — bullying, self-harm language, or persistent sadness — it escalates to parents. A notification is sent immediately, with context."

**On Screen (show concept — not necessarily live):**
```
⚠️ PARENT NOTIFICATION
━━━━━━━━━━━━━━━━━━━━━

Yoav expressed social difficulty today:
"Nobody at school wants to play with me"

Context: This is the first mention of social issues.
Response: Buddy provided empathy and coping strategies.
Recommendation: Have a conversation with Yoav about school friendships.

This notification was triggered by the emotional-support safety rule.
No action required unless you choose to follow up.
```

**Narration (EN):**
> "Parents get a notification — not an alarm, but a gentle heads-up. The system provides context and recommendations. It's the bridge between AI support and real human connection."

---

### Scene 6: What's Always Blocked [3:20–3:45]

**Screen:** Text overlay or terminal

**On Screen:**
```
🛡️ Always Blocked:
  ❌ Explicit or adult content
  ❌ Weapons or violence details
  ❌ Hate speech or discrimination
  ❌ Medical or psychiatric advice
  ❌ Financial information requests
  ❌ Encouraging rule-breaking or deception

🔄 Always Redirected:
  → Violent media → Age-appropriate alternatives
  → Personal info → Internet safety lesson
  → "I'm scared/sad" → Empathy + suggest talking to adult
  → Mature topics → "Great question! Ask a parent together"
```

---

### Scene 7: Closing [3:45–4:00]

**Narration (EN):**
> "Safe by design, not by afterthought. Every agent, every response, every interaction — filtered, monitored, and built with your child's wellbeing at the center. Because the most important feature isn't what AI teaches — it's how it protects."

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
| **Speed** | 1x — let the emotional responses breathe |
| **Key moments** | Emotional support response (hold 5+ seconds) |
| **Tone** | Serious, reassuring — this isn't a fun demo, it's a trust demo |

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+0%" `
    --file scripts/20-safety-en.txt `
    --write-media output/narration/20-safety-en.mp3
```
