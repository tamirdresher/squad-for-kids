# 🎬 Video 05: Issue Auto-Resolution

> **Title (EN):** From Question to Lesson — The Full Loop
> **Title (HE):** משאלה לשיעור — הלולאה המלאה

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~5 minutes |
| **Target Audience** | Developers, educators, technical parents |
| **Languages** | English + Hebrew (separate recordings) |
| **Prerequisites** | Forked repo, student profile, Ralph configured |
| **Difficulty** | Intermediate |

---

## Key Takeaway

> This is the "magic moment" — watch an issue go from creation to lesson delivery with zero human intervention. Issue created → Ralph picks up → agent generates content → PR opened → auto-merged → lesson available.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids

# 1. Clean state
.\demos\reset-demo.ps1

# 2. Ensure profile
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force

# 3. Start Ralph in background terminal
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd C:\temp\squad-for-kids; .\ralph-watch-kids.ps1"

# 4. Open browser to GitHub (issues tab + PR tab side by side)
# 5. Have OBS ready with 3 scenes:
#    Scene A: Browser (GitHub)
#    Scene B: Terminal (Ralph output)
#    Scene C: Split view (both)
```

---

## Storyboard

### Scene 1: Setup Context [0:00–0:30]

**Screen:** Split — terminal (Ralph running) + browser (GitHub issues)

**Narration (EN):**
> "This is the full loop — the most important demo. We'll create an issue, and watch as the Squad automatically turns it into a personalized lesson. No human intervention at any step. Let's start the clock."

**Narration (HE):**
> "זו הלולאה המלאה — הדמו הכי חשוב. ניצור משימה ונצפה בסקוואד הופך אותה אוטומטית לשיעור מותאם אישית. בלי התערבות אנושית בשום שלב. מתחילים לעצור זמן."

---

### Scene 2: Create the Issue [0:30–1:15]

**Screen:** Browser — GitHub "New Issue"

**Title to type:**
```
🦕 Teach me about dinosaurs — what happened to them?
```

**Body to type:**
```
I saw a movie about dinosaurs and I want to know:
1. What kinds of dinosaurs were there?
2. Why did they disappear?
3. Could they come back?

Can we do a fun quiz at the end?

— Yoav
```

**Label:** `squad`

**Click:** "Submit new issue"

**Narration (EN):**
> "Yoav wants to learn about dinosaurs. He creates an issue — just like a kid texting a question. Notice the 'squad' label. Now watch what happens."

**On Screen:** Note the timestamp — start the clock.

---

### Scene 3: Ralph Detects [1:15–1:45]

**Screen:** Terminal — Ralph's output

**Narration (EN):**
> "Within seconds, Ralph detects the new issue. He reads Yoav's request, checks the student profile — age 7, grade 2, Harry Potter universe — and routes it to the right agent."

**Narration (HE):**
> "תוך שניות, ראלף מזהה את המשימה החדשה. הוא קורא את הבקשה של יואב, בודק את פרופיל התלמיד — בן 7, כיתה ב', עולם הארי פוטר — ומנתב אותה לסוכן הנכון."

**Expected Output (verify):**
```
🔍 New issue detected: #XX "Teach me about dinosaurs"
📋 Student: Yoav (Grade 2, Age 7)
🎭 Cast: Harry Potter universe
🚀 Routing to: curriculum-lookup + kid-friendly agents
⏳ Generating lesson...
```

---

### Scene 4: Agent Works [1:45–3:00]

**Screen:** Terminal — agent processing (speed up 2-4x in post)

**Narration (EN):**
> "The agent is generating a grade-appropriate dinosaur lesson — with Harry Potter theming, quiz questions, and fun facts. This typically takes 30 to 60 seconds."

**Narration (HE):**
> "הסוכן מייצר שיעור דינוזאורים ברמת הכיתה — עם ערכת נושא של הארי פוטר, שאלות חידון, ועובדות מעניינות. זה בדרך כלל לוקח 30 עד 60 שניות."

**Expected Output (verify):**
```
📝 Lesson generated: "Dinosaurs — A Magical History"
   - 3 sections: Types, Extinction, Could They Return?
   - Quiz: 5 multiple-choice questions
   - Themed as "Hagrid's Care of Magical Creatures: Dinosaur Edition"
📂 Files created:
   - kids-study/lessons/dinosaurs-grade2.md
   - kids-study/quizzes/dinosaurs-quiz.md
🔀 Creating pull request...
```

---

### Scene 5: PR Created [3:00–3:45]

**Screen:** Browser — GitHub PR page

**Narration (EN):**
> "A pull request appears — containing the lesson, the quiz, and a comment back on the original issue letting Yoav know his lesson is ready."

**Narration (HE):**
> "בקשת משיכה מופיעה — מכילה את השיעור, את החידון, ותגובה על המשימה המקורית שמודיעה ליואב שהשיעור שלו מוכן."

**On Screen:**
1. Show the PR title and description
2. Click "Files changed" — show the generated lesson content
3. Scroll through the lesson (themed with Harry Potter characters)
4. Show the quiz questions
5. Switch to the original issue — show the auto-comment

**Expected auto-comment on issue:**
```
🧙‍♂️ Hagrid here! Your dinosaur lesson is ready!

I've prepared a special "Care of Magical Creatures: Dinosaur Edition" for you:
📖 Lesson: Types of dinosaurs, why they disappeared, and could they come back
❓ Quiz: 5 fun questions to test what you learned

Check out PR #YY to start learning! 🦕
```

---

### Scene 6: Auto-Merge [3:45–4:30]

**Screen:** PR page — merge happening

**Narration (EN):**
> "The PR passes checks and auto-merges. The lesson is now part of Yoav's learning repository — always available, always his."

**On Screen:**
1. Show PR checks passing (green checkmarks)
2. Show auto-merge (or manually click merge for the demo)
3. Show the merged lesson file in the repo

---

### Scene 7: Closing — Show the Clock [4:30–5:00]

**Screen:** Split — original issue + merged lesson

**Narration (EN):**
> "From question to personalized lesson — automatically. Yoav asked about dinosaurs and got a grade-appropriate, Harry-Potter-themed lesson with a quiz. Total time: under two minutes. That's the power of Squad for Kids."

**Narration (HE):**
> "משאלה לשיעור מותאם אישית — אוטומטית. יואב שאל על דינוזאורים וקיבל שיעור ברמת הכיתה שלו, בערכת נושא של הארי פוטר, עם חידון. זמן כולל: פחות משתי דקות. זה הכוח של סקוואד לילדים."

---

## Reset / Cleanup

```powershell
# Stop Ralph
Stop-Process -Name "powershell" -ErrorAction SilentlyContinue
# or Ctrl+C in Ralph terminal

# Clean up generated files
git checkout -- kids-study/
.\demos\reset-demo.ps1
```

---

## Screen Recording Notes

| Setting | Value |
|---------|-------|
| **Resolution** | 1920×1080 |
| **Main area** | 3 OBS scenes (browser, terminal, split) |
| **Speed adjustments** | 2-4x during agent processing |
| **Pause points** | After issue creation, after PR appears, after merge |
| **Timer overlay** | Add elapsed time counter in OBS (optional but impactful) |

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/05-issue-auto-resolution-en.txt `
    --write-media output/narration/05-issue-auto-resolution-en.mp3

edge-tts --voice "he-IL-HilaNeural" --rate "+0%" `
    --file scripts/05-issue-auto-resolution-he.txt `
    --write-media output/narration/05-issue-auto-resolution-he.mp3
```
