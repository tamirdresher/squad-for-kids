# 🎬 Video 02: Ralph Watch

> **Title (EN):** Ralph Never Sleeps — Automatic Issue Processing
> **Title (HE):** ראלף לא ישן — עיבוד אוטומטי של משימות

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~3 minutes |
| **Target Audience** | Developers, technical parents |
| **Languages** | English + Hebrew (separate recordings) |
| **Prerequisites** | Forked repo, student profile exists |
| **Difficulty** | Intermediate |

---

## Key Takeaway

> Ralph is the Squad's background worker — it watches for new issues, routes them to the right agent, and creates PRs automatically. Parents and kids don't need to babysit anything.

---

## Pre-Recording Setup

### Environment

```powershell
cd C:\temp\squad-for-kids

# 1. Ensure student profile exists
Test-Path demos/profiles/yoav-grade2.json

# 2. Create 2-3 unprocessed issues in the repo:
#    Issue A: "Yoav wants to learn about dinosaurs" (label: squad)
#    Issue B: "Add 2nd grade math worksheet: addition with carrying" (label: squad:copilot)
#    Issue C: "Weekly progress check for Yoav" (label: squad)

# 3. Ensure Copilot CLI is installed and authenticated
copilot --version
```

### Profile Setup

Use `demos/profiles/yoav-grade2.json` — the standard demo profile.

---

## Storyboard

### Scene 1: What is Ralph? [0:00–0:30]

**Screen:** Terminal, repo root

**Narration (EN):**
> "Meet Ralph — the Squad's tireless background worker. Ralph watches your repository for new issues, figures out what needs to be done, and routes work to the right agent. Let's see him in action."

**Narration (HE):**
> "הכירו את ראלף — עובד הרקע הבלתי נלאה של הסקוואד. ראלף עוקב אחרי המאגר שלכם, מחפש משימות חדשות, מבין מה צריך לעשות ומנתב את העבודה לסוכן הנכון. בואו נראה אותו בפעולה."

**On Screen:**
1. Show the terminal at repo root
2. Briefly open `ralph-watch-kids.ps1` in editor to show the concept

---

### Scene 2: Start Ralph [0:30–1:00]

**Screen:** Terminal

**Type:**
```powershell
.\ralph-watch-kids.ps1
```

**Narration (EN):**
> "Start Ralph with a single command. He immediately scans for open issues tagged with the squad label."

**Narration (HE):**
> "מפעילים את ראלף עם פקודה אחת. הוא מיד סורק משימות פתוחות עם תווית סקוואד."

**Expected Output (verify on screen):**
```
🔍 Ralph is watching... (checking every 60 seconds)
📋 Found 3 open issues with squad labels
   #12 — Yoav wants to learn about dinosaurs [squad]
   #13 — Add 2nd grade math worksheet [squad:copilot]
   #14 — Weekly progress check for Yoav [squad]
```

---

### Scene 3: Ralph Processes Issues [1:00–2:00]

**Screen:** Terminal showing Ralph's processing output

**Narration (EN):**
> "Watch — Ralph picks up each issue, reads the content, checks the routing rules, and assigns it to the right agent. The dinosaur request goes to the curriculum agent. The math worksheet goes to Copilot. And the progress check generates a parent report."

**Narration (HE):**
> "שימו לב — ראלף אוסף כל משימה, קורא את התוכן, בודק את כללי הניתוב, ומקצה אותה לסוכן הנכון. בקשת הדינוזאורים הולכת לסוכן תוכנית הלימודים. דף העבודה במתמטיקה הולך לקופיילוט. ובדיקת ההתקדמות מייצרת דוח להורים."

**Expected Output (verify on screen):**
```
🚀 Processing #12: "Yoav wants to learn about dinosaurs"
   → Routing to: curriculum-lookup agent
   → Creating lesson plan...
   → PR #15 opened: "Add dinosaur lesson for Yoav"

🚀 Processing #13: "Add 2nd grade math worksheet"
   → Routing to: @copilot (squad:copilot label)
   → Generating worksheet...
   → PR #16 opened: "Math worksheet: addition with carrying"

🚀 Processing #14: "Weekly progress check"
   → Routing to: parent-notifications agent
   → Generating weekly report...
   → Comment posted on #14 with progress summary
```

**On Screen:**
- Speed up any waiting periods (>5 seconds of spinner)
- Highlight the routing decisions (which agent gets which issue)

---

### Scene 4: Verify Results [2:00–2:40]

**Screen:** Split — terminal left, browser right (GitHub issues)

**Narration (EN):**
> "Let's check GitHub — Ralph created pull requests for the lessons and posted a progress report. All without anyone lifting a finger."

**Narration (HE):**
> "בואו נבדוק בגיטהאב — ראלף יצר בקשות משיכה לשיעורים ופרסם דוח התקדמות. הכל בלי שאף אחד הזיז אצבע."

**On Screen:**
1. Open GitHub in browser
2. Show the new PRs created by Ralph
3. Show the comment on the progress check issue
4. Click into one PR to show the generated content

---

### Scene 5: Closing [2:40–3:00]

**Screen:** Terminal with Ralph still running

**Narration (EN):**
> "Ralph keeps watching. New issue? He's on it. Think of him as your child's learning assistant that never takes a break. Stop him anytime with Ctrl+C."

**Narration (HE):**
> "ראלף ממשיך לעקוב. משימה חדשה? הוא על זה. חשבו עליו כעוזר הלמידה של הילד שלכם שלעולם לא לוקח הפסקה. עצרו אותו בכל עת עם Ctrl+C."

**Type:**
```
Ctrl+C
```

---

## Reset / Cleanup

```powershell
# Close any open PRs created during the demo
# Reset issues to open state
.\demos\reset-demo.ps1

# Delete any created lesson files
git checkout -- kids-study/
```

---

## Screen Recording Notes

| Setting | Value |
|---------|-------|
| **Resolution** | 1920×1080 |
| **Main area** | Terminal (full screen), split for Scene 4 |
| **Speed adjustments** | 2-4x during agent processing waits |
| **Pause points** | After Ralph discovers issues, after PRs created |

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/02-ralph-watch-en.txt `
    --write-media output/narration/02-ralph-watch-en.mp3

edge-tts --voice "he-IL-HilaNeural" --rate "+0%" `
    --file scripts/02-ralph-watch-he.txt `
    --write-media output/narration/02-ralph-watch-he.mp3
```
