# 🎬 Video 04: Parent Creates Issues

> **Title (EN):** Curriculum in Your Hands — Parents Add Learning Goals
> **Title (HE):** תוכנית הלימודים בידיים שלכם — הורים מוסיפים מטרות למידה

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~3 minutes |
| **Target Audience** | Parents |
| **Languages** | English + Hebrew (separate recordings) |
| **Prerequisites** | Forked repo, student profile |
| **Difficulty** | Beginner |

---

## Key Takeaway

> Parents can add structured curriculum items using `squad:copilot` labels. These get routed directly to Copilot for automated lesson creation — no coding required.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force
# Open browser to GitHub issues page
# Ensure Ralph is NOT running (we want to show the label-based routing)
```

### Profile: `demos/profiles/yoav-grade2.json`

---

## Storyboard

### Scene 1: Parent's Perspective [0:00–0:25]

**Screen:** GitHub repo README (showing curriculum section)

**Narration (EN):**
> "As a parent, you control the curriculum. While your child asks for fun topics, you can add structured learning goals — math milestones, reading levels, exam prep. Use the 'squad:copilot' label to route work directly to the AI agent."

**Narration (HE):**
> "בתור הורה, אתם שולטים בתוכנית הלימודים. בזמן שהילד מבקש נושאים כיפיים, אתם יכולים להוסיף מטרות למידה מובנות — אבני דרך במתמטיקה, רמות קריאה, הכנה למבחנים. השתמשו בתווית 'squad:copilot' כדי לנתב עבודה ישירות לסוכן ה-AI."

---

### Scene 2: Create a Curriculum Issue [0:25–1:15]

**Screen:** GitHub "New Issue" page

**Title to type:**
```
📚 Add multiplication tables practice (2nd grade, Israeli curriculum)
```

**Body to type:**
```
## Learning Goal
Yoav needs to master multiplication tables 1-5 before moving to 3rd grade.

## Requirements
- Interactive practice problems (not just worksheets)
- Use Israeli curriculum standards for כיתה ב'
- Include visual aids (arrays, groups of objects)
- Progressive difficulty: start with ×2, then ×5, then ×3, ×4
- Celebrate milestones (e.g., "You mastered the 2s table!")

## Timeline
Complete by end of semester (June 2026)
```

**Labels to add:** `squad:copilot`

**Narration (EN):**
> "The parent writes a detailed learning goal. Notice the 'squad:copilot' label — this tells the system to route it directly to Copilot, which will generate the practice materials automatically."

**Narration (HE):**
> "ההורה כותב מטרת למידה מפורטת. שימו לב לתווית 'squad:copilot' — זה אומר למערכת לנתב את זה ישירות לקופיילוט, שייצר את חומרי התרגול באופן אוטומטי."

**Expected:** Issue created with `squad:copilot` label

---

### Scene 3: More Parent Issue Examples [1:15–2:00]

**Screen:** Create 2 more issues rapidly

**Issue 2 — Title:**
```
📖 Weekly reading comprehension: "הנסיך הקטן" (The Little Prince) in Hebrew
```

**Issue 2 — Body:**
```
Create a 4-week reading plan for "הנסיך הקטן" adapted for 2nd grade level:
- Week 1: Chapters 1-5, vocabulary list, 3 comprehension questions
- Week 2: Chapters 6-12, character analysis activity
- Week 3: Chapters 13-20, creative writing prompt
- Week 4: Finish book, book report template

Label: squad:copilot
```

**Issue 3 — Title:**
```
🔬 Prepare for science test: States of matter (מוצק, נוזל, גז)
```

**Issue 3 — Body:**
```
Yoav has a science test next Thursday on states of matter.
Create a study guide with:
- Simple explanations with everyday examples
- A quiz with 10 questions
- Fun experiments he can do at home (with water/ice)
- Hebrew vocabulary: מוצק, נוזל, גז, התמוססות, התאדות

Label: squad:copilot
```

**Narration (EN):**
> "Parents can add as many goals as they want — reading plans, test prep, project ideas. Each one gets its own issue, its own timeline, and its own generated content."

**Narration (HE):**
> "הורים יכולים להוסיף כמה מטרות שירצו — תוכניות קריאה, הכנה למבחנים, רעיונות לפרויקטים. לכל אחת יש משימה משלה, ציר זמן משלה, ותוכן שנוצר אוטומטית."

---

### Scene 4: Labels Explanation [2:00–2:40]

**Screen:** GitHub labels page or issue sidebar

**Narration (EN):**
> "Quick note on labels: 'squad' means any squad agent can pick it up — great for kid-initiated requests. 'Squad:copilot' routes it directly to GitHub Copilot — perfect for structured curriculum work that needs code generation. Parents use 'squad:copilot', kids use 'squad'."

**Narration (HE):**
> "הערה מהירה על תוויות: 'squad' אומר שכל סוכן סקוואד יכול לאסוף את זה — מעולה לבקשות של ילדים. 'squad:copilot' מנתב ישירות לגיטהאב קופיילוט — מושלם לעבודת תוכנית לימודים מובנית. הורים משתמשים ב-'squad:copilot', ילדים משתמשים ב-'squad'."

**On Screen:**
| Label | Who Uses It | Routed To |
|-------|-------------|-----------|
| `squad` | Kids | Any squad agent |
| `squad:copilot` | Parents | GitHub Copilot directly |

---

### Scene 5: Closing [2:40–3:00]

**Narration (EN):**
> "You're the principal of your child's school. Set the goals, let the AI do the heavy lifting."

**Narration (HE):**
> "אתם המנהלים של בית הספר של הילד שלכם. הגדירו את המטרות, תנו ל-AI לעשות את העבודה הקשה."

---

## Reset / Cleanup

```powershell
.\demos\reset-demo.ps1
# Close demo issues on GitHub
```

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/04-parent-creates-issues-en.txt `
    --write-media output/narration/04-parent-creates-issues-en.mp3

edge-tts --voice "he-IL-HilaNeural" --rate "+0%" `
    --file scripts/04-parent-creates-issues-he.txt `
    --write-media output/narration/04-parent-creates-issues-he.mp3
```
