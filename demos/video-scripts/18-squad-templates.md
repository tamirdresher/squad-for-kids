# 🎬 Video 18: Squad Templates

> **Title (EN):** Dream Team, Creators, Exam Prep — Pick Your Template
> **Title (HE):** צוות החלומות, יוצרים, הכנה למבחנים — בחרו תבנית

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~4 minutes |
| **Target Audience** | Parents, educators |
| **Language** | English |
| **Prerequisites** | Clean repo (no profile yet) |
| **Difficulty** | Beginner |

---

## Key Takeaway

> Squad for Kids comes with pre-built templates for different learning styles and age groups. Parents pick a template, and the entire squad is configured instantly — agents, curriculum focus, gamification style, and teaching methods.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids

# Remove existing profile for fresh template selection
Remove-Item .squad/student-profile.json -ErrorAction SilentlyContinue

# Verify templates exist
ls .squad/templates/
```

---

## Storyboard

### Scene 1: What Are Templates? [0:00–0:25]

**Narration (EN):**
> "Not sure how to configure a learning squad? Templates do it for you. Each template is a pre-built team optimized for a specific learning style, age group, or goal."

---

### Scene 2: The Dream Team [0:25–1:15]

**Screen:** Terminal / rendered markdown

**On Screen:** Show `.squad/templates/dream-team.md` content

```markdown
🌟 The Dream Team
General Learning • Ages 6-12

Six specialists covering the full elementary curriculum:

| Agent | Character | Specialty |
|-------|-----------|-----------|
| Coach | Encouraging sports coach | Math & Logic |
| Story | Dramatic storyteller | Reading & Writing |
| Explorer | Curious scientist | Science & Nature |
| Pixel | Fun YouTuber kid | Digital Skills |
| Harmony | Patient music teacher | Arts & Music |
| Buddy | Best friend | Social & Emotional |
```

**Narration (EN):**
> "The Dream Team is the all-rounder — six agents covering math, reading, science, digital skills, arts, and social-emotional learning. Perfect for ages 6 to 12. This is what most families start with."

---

### Scene 3: The Creators [1:15–2:00]

**On Screen:** Show Creators template

```markdown
🎨 The Creators
Creative Kids • Ages 8-14

For kids who want to MAKE things:

| Agent | Character | Specialty |
|-------|-----------|-----------|
| Director | Film director | Video & Animation |
| Coder | Friendly hacker kid | Programming |
| Artist | Bob Ross for kids | Digital Art |
| Writer | Enthusiastic author | Creative Writing |
| Builder | Minecraft architect | 3D Design |
| DJ | Music producer | Music Production |
```

**Narration (EN):**
> "The Creators template is for kids who want to make things — code games, create videos, produce music, design worlds. It turns screen time into creative time."

---

### Scene 4: Exam Prep [2:00–2:40]

**On Screen:** Show Exam Prep template

```markdown
📝 Exam Prep
Test Preparation • Ages 10-18

Focused squad for exam preparation:

| Agent | Character | Specialty |
|-------|-----------|-----------|
| Tutor | Strict but fair professor | Subject mastery |
| Quizzer | Game show host | Practice tests & drills |
| Planner | Organized librarian | Study schedules |
| Motivator | Life coach | Confidence & focus |
| Reviewer | Editor | Essay review & feedback |
| Flashcard | Memory champion | Spaced repetition cards |
```

**Narration (EN):**
> "When exams are coming, switch to Exam Prep. This template replaces creative agents with focused tutoring — practice tests, study schedules, and spaced repetition flashcards."

---

### Scene 5: Apply a Template [2:40–3:30]

**Screen:** Terminal

**Type:**
```
copilot
```

Then:
```
I want to use the Creators template for my 10-year-old
```

**Expected:**
```
🎨 Great choice! Setting up The Creators template...

Configuring for age 10:
  ✅ Programming: Scratch + beginner Python
  ✅ Video: Simple storyboarding, stop-motion
  ✅ Art: Digital drawing fundamentals
  ✅ Writing: Short stories, world-building
  ✅ 3D: Minecraft Education basics
  ✅ Music: GarageBand-style beat making

🎬 Your Creative Squad is ready!

Tell me your child's name to complete setup...
```

**Narration (EN):**
> "One sentence — 'use the Creators template for my 10-year-old' — and the entire squad reconfigures. Age-appropriate tools, curriculum, and teaching styles. Instant."

---

### Scene 6: Closing [3:30–4:00]

**Narration (EN):**
> "Three templates, three learning philosophies. Dream Team for well-rounded education. Creators for makers and builders. Exam Prep for test season. And you can always customize or switch."

---

## Reset / Cleanup

```powershell
Remove-Item .squad/student-profile.json -ErrorAction SilentlyContinue
```

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/18-squad-templates-en.txt `
    --write-media output/narration/18-squad-templates-en.mp3
```
