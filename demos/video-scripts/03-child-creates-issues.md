# 🎬 Video 03: Child Creates Issues

> **Title (EN):** "I Want to Learn Fractions!" — Kids Drive Their Own Learning
> **Title (HE):** "אני רוצה ללמוד שברים!" — ילדים מובילים את הלמידה שלהם

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~3 minutes |
| **Target Audience** | Parents, educators |
| **Languages** | English + Hebrew (separate recordings) |
| **Prerequisites** | Forked repo, student profile, Copilot CLI |
| **Difficulty** | Beginner |

---

## Key Takeaway

> Kids can tell the Squad what they want to learn by creating a GitHub issue. It's as simple as writing a sentence. The Squad labels it, routes it, and starts building a lesson — all automatically.

---

## Pre-Recording Setup

### Environment

```powershell
cd C:\temp\squad-for-kids

# 1. Ensure student profile exists
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force

# 2. Verify Copilot CLI works
copilot --version

# 3. Open browser to GitHub issues page (your fork)
# 4. Have Ralph running in a separate terminal (optional — for auto-pickup demo)
```

### Profile Setup

Use `demos/profiles/yoav-grade2.json`:
- Name: Yoav, Grade 2, Rishon LeZion
- Cast: Harry Potter universe
- Language: English

---

## Storyboard

### Scene 1: The Idea [0:00–0:20]

**Screen:** GitHub issues page (empty or few issues)

**Narration (EN):**
> "What if your child could just say what they want to learn — and get a personalized lesson? With Squad for Kids, they can. All they do is create a GitHub issue."

**Narration (HE):**
> "מה אם הילד שלכם יכול פשוט לומר מה הוא רוצה ללמוד — ולקבל שיעור מותאם אישית? עם סקוואד לילדים, הם יכולים. כל מה שהם צריכים לעשות זה ליצור issue בגיטהאב."

---

### Scene 2: Kid Creates an Issue [0:20–1:00]

**Screen:** GitHub "New Issue" page

**On Screen:**
1. Click "New Issue"
2. Type the title:

**Title to type (EN):**
```
I want to learn about fractions! 🍕
```

**Body to type (EN):**
```
Hermione, can you teach me fractions? I don't understand
how to add 1/2 + 1/3. Pizza examples would be cool!
```

**Title to type (HE version):**
```
אני רוצה ללמוד שברים! 🍕
```

**Body to type (HE version):**
```
הרמיוני, את יכולה ללמד אותי שברים? אני לא מבין
איך לחבר 1/2 + 1/3. דוגמאות עם פיצה יהיו מגניבות!
```

3. Add label: `squad`
4. Click "Submit new issue"

**Narration (EN):**
> "Yoav types what he wants to learn — in his own words. He even addresses Hermione, his head teacher in the Harry Potter squad. He adds the 'squad' label so the system knows to pick it up."

**Narration (HE):**
> "יואב מקליד מה הוא רוצה ללמוד — במילים שלו. הוא אפילו פונה להרמיוני, המורה הראשית שלו בסקוואד הארי פוטר. הוא מוסיף את תווית 'סקוואד' כדי שהמערכת תדע לאסוף את זה."

**Expected:** Issue created with `squad` label

---

### Scene 3: Squad Responds [1:00–2:00]

**Screen:** GitHub issue page — watching for auto-comment

**Narration (EN):**
> "Within seconds, the Squad picks up the issue. It reads Yoav's request, checks his grade level and curriculum, and starts building a personalized fractions lesson — with pizza examples, just like he asked."

**Narration (HE):**
> "תוך שניות, הסקוואד אוסף את המשימה. הוא קורא את הבקשה של יואב, בודק את רמת הכיתה ותוכנית הלימודים שלו, ומתחיל לבנות שיעור שברים מותאם אישית — עם דוגמאות פיצה, בדיוק כמו שביקש."

**Expected Response (auto-comment on issue — verify on screen):**
```
🧙‍♀️ Hermione here! Great question, Yoav!

I'm preparing a fractions lesson just for you. Here's what we'll cover:

📝 **Lesson Plan: Fractions with Pizza! 🍕**
1. What is a fraction? (pizza slices!)
2. Finding common denominators
3. Adding 1/2 + 1/3 step by step
4. Practice problems with pizza drawings

Give me a moment to prepare everything...
```

**On Screen:**
1. Show the auto-comment appearing
2. Show the PR being created (link appears in issue)
3. Scroll through the generated lesson content

---

### Scene 4: More Examples [2:00–2:40]

**Screen:** GitHub "New Issue" — rapid-fire examples

**Narration (EN):**
> "Kids can ask for anything — 'teach me about volcanoes,' 'help me with my spelling test,' 'I want to code a game.' Each request becomes a personalized lesson."

**Narration (HE):**
> "ילדים יכולים לבקש כל דבר — 'למדו אותי על הרי געש', 'עזרו לי עם מבחן האיות', 'אני רוצה לתכנת משחק'. כל בקשה הופכת לשיעור מותאם אישית."

**On Screen (quick montage — type fast, show titles only):**

```
Title: Help me prepare for my English vocabulary test
Label: squad

Title: Can we do a science experiment about magnets?
Label: squad

Title: I want to build a website about my favorite animal
Label: squad
```

---

### Scene 5: Closing [2:40–3:00]

**Narration (EN):**
> "The child drives their own learning. They ask, the Squad delivers. No waiting for a teacher, no expensive tutor. Just curiosity, meet AI."

**Narration (HE):**
> "הילד מוביל את הלמידה שלו. הוא שואל, הסקוואד מספק. בלי לחכות למורה, בלי מורה פרטי יקר. רק סקרנות, פוגשת AI."

---

## Reset / Cleanup

```powershell
# Close the demo issues
# Delete any generated lesson PRs
.\demos\reset-demo.ps1
```

---

## Screen Recording Notes

| Setting | Value |
|---------|-------|
| **Resolution** | 1920×1080 |
| **Main area** | Browser (GitHub issues) |
| **Speed adjustments** | Speed up agent processing, keep typing at normal speed |
| **Pause points** | After issue submission, after Squad's first response |

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/03-child-creates-issues-en.txt `
    --write-media output/narration/03-child-creates-issues-en.mp3

edge-tts --voice "he-IL-HilaNeural" --rate "+0%" `
    --file scripts/03-child-creates-issues-he.txt `
    --write-media output/narration/03-child-creates-issues-he.mp3
```
