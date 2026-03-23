# 🎬 Video 17: Read Aloud

> **Title (EN):** Listen & Learn — Lessons Become Audio
> **Title (HE):** הקשיבו ולמדו — שיעורים הופכים לשמע

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~3 minutes |
| **Target Audience** | Parents, younger kids |
| **Language** | English |
| **Prerequisites** | Student profile, edge-tts installed |
| **Difficulty** | Beginner |

---

## Key Takeaway

> Lessons can be converted to speech — multiple voices, multiple languages. Perfect for auditory learners, younger kids who can't read well yet, or studying on the go.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force

# Ensure edge-tts is installed
pip install edge-tts --quiet

# Ensure a lesson file exists to convert
Test-Path kids-study/
```

---

## Storyboard

### Scene 1: The Need [0:00–0:20]

**Narration (EN):**
> "Not every child reads well — especially young ones. And sometimes kids want to learn while doing other things. Read Aloud turns any lesson into an audio experience with natural-sounding voices."

---

### Scene 2: Convert a Lesson [0:20–1:00]

**Screen:** Terminal

**Type:**
```
Read me the dinosaur lesson out loud
```

**Expected:**
```
🔊 Reading lesson: "Dinosaurs — A Magical History"
🎙️ Voice: Hermione (en-US-JennyNeural)
⏱️ Estimated: 3 minutes

🧙‍♀️ "Hello Yoav! Today we're going on a journey back in time...
65 million years ago, incredible creatures called dinosaurs
roamed the Earth..."

[Audio plays through terminal / generates MP3]

📁 Audio saved: kids-study/audio/dinosaurs-lesson.mp3
```

**On Screen:** Show audio playing (if possible) or the file being created

---

### Scene 3: Multiple Voices [1:00–1:45]

**Type:**
```
Can Hagrid read the science part?
```

**Expected:**
```
🔊 Switching voice to Hagrid (en-GB-RyanNeural — deep, warm)

🧔 "Righ' then, Yoav! Let me tell yeh about these magnificent
creatures! There were three main types of dinosaurs..."

📁 Audio saved: kids-study/audio/dinosaurs-hagrid.mp3
```

**Type:**
```
And can you read the quiz questions in Hebrew?
```

**Expected:**
```
🔊 Switching to Hebrew voice (he-IL-HilaNeural)

🧙‍♀️ "שאלה ראשונה: איזה סוג של דינוזאור היה הכי גדול?
א. טי-רקס
ב. ברכיוזאורוס
ג. וולוסירפטור..."

📁 Audio saved: kids-study/audio/dinosaurs-quiz-he.mp3
```

**Narration (EN):**
> "Different characters get different voices. Hermione sounds thoughtful and clear. Hagrid sounds deep and warm. And the Hebrew version uses a native Israeli voice. All generated with edge-tts — free and instant."

---

### Scene 4: The TTS Pipeline [1:45–2:20]

**Screen:** Terminal — show the actual edge-tts commands

**Type:**
```powershell
# Behind the scenes:
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --text "Hello Yoav! Today we're learning about dinosaurs..." `
    --write-media dinosaur-lesson.mp3
```

**Narration (EN):**
> "Under the hood, it's edge-tts — Microsoft's neural text-to-speech engine. Free, fast, and supports dozens of languages and voices. The Squad wraps it so kids just say 'read it to me.'"

---

### Scene 5: Use Cases [2:20–2:45]

**Narration (EN):**
> "Read Aloud is perfect for bedtime learning, car rides, younger kids who are still learning to read, and kids with visual processing differences. The lesson is the same — the delivery adapts."

**On Screen (text overlay):**
```
📱 Use Cases:
  🛏️ Bedtime learning
  🚗 Car ride lessons
  👶 Pre-readers (ages 4-6)
  ♿ Accessibility support
  🎧 Audio review while doing chores
```

---

### Scene 6: Closing [2:45–3:00]

**Narration (EN):**
> "Every lesson, every language, every character — now in audio. Learning doesn't need a screen. It just needs a voice."

---

## Reset / Cleanup

```powershell
Remove-Item kids-study/audio/ -Recurse -ErrorAction SilentlyContinue
```

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/17-read-aloud-en.txt `
    --write-media output/narration/17-read-aloud-en.mp3
```
