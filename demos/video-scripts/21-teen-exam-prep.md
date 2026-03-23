# 🎬 Video 21: Teen Exam Prep — Bagrut Study Planning

> **Title (EN):** Study Smart for Bagrut — Exam Prep That Gets It
> **Title (HE):** לימודים חכמים לבגרות — התוכנית שמבינה את הלחץ

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~6 minutes |
| **Target Audience** | Teenagers (age 14-18), Israeli high school students |
| **Language** | Hebrew (primary) + English narration |
| **Prerequisites** | None (new profile) |
| **Difficulty** | Intermediate |
| **Profile** | Noa, 15 years old, כיתה י׳ (10th grade), Tel Aviv |

---

## Key Takeaway

> Squad for Kids isn't just for little kids. For Israeli teens facing bagrut exams, it's a serious study partner that builds realistic plans, respects your schedule, tutors you actively, and keeps you motivated without the pressure.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids

# Create/reset the teen profile
@{
  name = "Noa"
  age = 15
  grade = "10"
  location = "Israel"
  language = "Hebrew"
  school = "תל אביב"
  squadTemplate = "exam-prep"
  sports = @{
    basketball = @("Tuesday", "Thursday")
    startTime = "4:00 PM"
    endTime = "5:30 PM"
  }
  exams = @(
    @{
      subject = "Math"
      units = "5"
      date = "2024-06-15"
    },
    @{
      subject = "English"
      date = "2024-06-20"
    },
    @{
      subject = "History"
      topics = "Holocaust & Revival"
      date = "2024-06-25"
    }
  )
  projects = @(
    @{
      subject = "Biology"
      name = "DNA Research Project"
      dueDate = "2024-06-01"
    }
  )
} | ConvertTo-Json | Set-Content .squad/student-profile.json

# Terminal should be in Hebrew locale for realistic display
```

---

## Storyboard

### Scene 1: Profile Setup [0:00–0:30]

**Screen:** Codespace terminal with VS Code editor visible  
**Background:** Clean desk, Hebrew text in terminal

**Type (Hebrew):**
```
היי, אני נועה, בת 15, כיתה י׳ בתל אביב
```

**Expected Output:**
```
👋 שלום נועה!

טוב להכיר אותך. אני מזהה:
  👤 נועה, בת 15, כיתה י׳
  📍 תל אביב, ישראל
  🗣️ שפה: עברית

תשמחי אם אעזור לך להתכונן לבגרות? יש לנו תוכנית מיוחדת לתלמידים בדיוק כמוך.

בואי נתחיל: תספרי לי על הבגרויות שלך.
```

**Narration (EN - Voiceover):**
> "Meet Noa. Fifteen years old, tenth grade in Tel Aviv. She's about to face serious exams, and she needs a study partner who actually understands the pressure. Let's see how Squad helps her build a real, sustainable study plan."

**Narration (HE - Voiceover):**
> "הכירו את נועה. בת 15, כיתה י׳ בתל אביב. היא עומדת מול בגרויות אמיתיות וצריכה שותף לימודים שבאמת מבין את הלחץ. בואו נראה איך Squad עוזר לה לבנות תוכנית לימודים אמיתית וקיימא."

---

### Scene 2: Exam Schedule Input [0:30–1:30]

**Type (Hebrew):**
```
יש לי בגרות במתמטיקה 5 יחידות ב-15 ביוני, באנגלית ב-20 ביוני, ובהיסטוריה ב-25 ביוני. גם יש לי פרויקט ביולוגיה שצריך לסיים עד 1 ביוני
```

**Expected Output:**
```
🎯 הבנתי — תוכנית בגרות משקפת:

📋 הבחינות שלך:
  1. פרויקט ביולוגיה — עד 1 ביוני (39 ימים)
  2. בגרות מתמטיקה 5 יחידות — 15 ביוני (53 ימים)
  3. בגרות אנגלית — 20 ביוני (58 ימים)
  4. בגרות היסטוריה (שואה ותקומה) — 25 ביוני (63 ימים)

⏰ ספירה לאחור:
  [████████░░░░░░░░░░░░░░░░] 53 ימים עד מתמטיקה

זה הרבה חומר. בואי נבנה תוכנית שמכבדת את הלוח שלך ולא מתניידה?
```

**Narration (EN):**
> "Noa lists her exams: Math five units, English, History — plus a biology project. That's a full load. But the Squad doesn't panic. It parses everything, counts down to each deadline, and starts thinking about how to make this realistic."

---

### Scene 3: Schedule Constraints [1:30–2:15]

**Type (Hebrew):**
```
אני משחקת כדורסל בשלישי וחמישי בערביים, וברור שלא אני לומדת בשבת. אתמול סיימתי משימה קשה - יכול להיות יום קל היום?
```

**Expected Output:**
```
💪 קלטתי את זה:

🏀 כדורסל: שלישי וחמישי (בערביים) — מוכן!
🕯️ שבת: אין לימודים
✅ אתמול נסיעה קשה — כן, היום ייהיה קל

תוכנית שבועית:
┌─────────────────────────────────────────┐
│ ימי שנייה - חמישי                        │
├──────────────┬──────────┬───────────────┤
│ יום          │ זמן      │ תוכנית        │
├──────────────┼──────────┼───────────────┤
│ שני           │ 15:00    │ מתמטיקה (45 דק) │
│ שלישי ⚽      │ 18:00    │ אנגלית (30 דק) │
│ רביעי         │ 15:00    │ היסטוריה (45 דק)│
│ חמישי ⚽      │ 18:30    │ ביולוגיה (45 דק)│
│ ראשון         │ 10:00    │ חזרה כללית (60 דק)│
│ שישי         │ 10:00    │ קריאה קלה      │
│ שבת 🕊️      │ מנוחה    │ ללא לימודים    │
└──────────────┴──────────┴───────────────┘

💡 כל גוש לימודי 25 דק חזרה (spaced repetition) + 5 דק הפסקה.
את הנושאים שקשים לך תחזרי יותר לעתים קרובות.

זה עובד לך? רוצה לשנות משהו?
```

**Narration (EN):**
> "She mentions basketball twice a week, no studying on Saturday, and that today should be lighter after working hard yesterday. The Squad doesn't just note this — it rebuilds the entire plan around it. Shabbat is off-limits. Basketball evenings shift to after practice. Smart recovery is built in."

---

### Scene 4: Active Math Tutoring [2:15–3:30]

**Type (Hebrew):**
```
בואי נתחיל לחזור על מתמטיקה. פונקציות טריגונומטריות מחבילות אותי.
```

**Expected Output:**
```
📐 טריגונומטריה — בואי נפתור את זה

🎯 המשימה: הבן את sin/cos/tan כמו שצוחקים בבגרות

➊ התיאוריה (רק מה שצריך):
───────────────────────────────
במשולש ישר זווית:
  • sin(θ) = צלע נגדית / יתר
  • cos(θ) = צלע צמודה / יתר
  • tan(θ) = צלע נגדית / צלע צמודה

💡 כלל הזהב: SOH CAH TOA
  S = Sin = Opposite/Hypotenuse
  C = Cos = Adjacent/Hypotenuse
  T = Tan = Opposite/Adjacent

➋ בעיה אמיתית מבגרות (2023):
───────────────────────────────
"במשולש ישר זווית ABC, הזווית הישרה ב-C.
AB (יתר) = 10 ס״מ, והזווית A = 35°.
מצא את אורך AC."

🤔 מה תעשי תחילה?
  א. זהי בעיית sin
  ב. זהי בעיית cos
  ג. זהי בעיית tan

דעי לי את התשובה שלך (א, ב, או ג), ואני אראה לך את השלבים הבאים.

⏱️ פתרי לבד כ-15 דקות. אני פה אם תצטרכי עזרה. 💪
```

**Narration (EN):**
> "Now the Squad shifts into tutor mode. Noa says trigonometry is crushing her. Instead of just giving her the formula, the Squad breaks it down: explains SOH CAH TOA, shows a real bagrut-style question, and then asks her to try. This is active learning, not passive lecture."

---

### Scene 5: History Deep Dive [3:30–4:30]

**Type (Hebrew):**
```
אוקיי, בואי נעברנו. עכשיו היסטוריה - שואה ותקומה. איך אני אמורה לזכור את כל זה?
```

**Expected Output:**
```
📚 שואה ותקומה — מבנה ניתוח מקור

🎯 המטרה: לא לזכור תאריכים. להבין את הסיפור.

⏱️ ציר הזמן המינימלי (מה שבגרות דורשת):
────────────────────────────────────────
  1933 — היטלר לשלטון
  1938 — קריסטלנכט (המ習start של הגזל)
  1941 — התחלת השואה ("הפתרון הסופי")
  1945 — שחרור, קץ המלחמה
  1948 — קום המדינה

🔍 כיצד לנתח מקור (זה מה שתוציאי בבגרות):
────────────────────────────────────────
כשמציגים לך מקור (מכתב, תמונה, קטע), שאלי עצמך:
  1. מי כתב? (מי, מתי, איפה)
  2. למי זה מיועד? (מאה, תפקיד)
  3. מה היה ההקשר? (מה קרה אז בעולם)
  4. מה זה מגיד לנו על מחשבות או תחושות?
  5. מה זה לא מגיד? (מה חסר?)

📋 שאלת חזרה טיפוסית בבגרות:
"אנליזה מקור - מכתב מ-1942 מגטו וורשה"
[מקור]
"בחן את המקור לאור הנתונים ההיסטוריים. מה הוא חושף?"

✍️ תשובה טובה תכלול:
  • זיהוי המחבר ומצבו
  • קשר למאורעות היסטוריים
  • עדויות מהטקסט
  • סיכום בתובנה

📖 דוגמה טובה:
"הרגשות של יתר ודכדוך חוזרים במכתב. מחבר טען שהקשיים גברו לאורך זמן."

❌ דוגמה גרועה:
"זה מכתב מ-1942. השואה הייתה קשה."
(חסר עומק, חסר ניתוח)

🎯 תרגול:
בואי נעשה ניתוח מקור משמעותי עכשיו? אני אתן לך מקור מעיתון השדרות מ-1948.
```

**Narration (EN):**
> "History is different. Noa doesn't need to memorize dates — she needs to analyze sources like a historian. The Squad walks her through the structure of a source analysis, shows what good answers look like versus surface-level ones, and offers to practice right now with a real document."

---

### Scene 6: Daily Check-in & Streak [4:30–5:15]

**Screen:** New day — Codespace opens. Squad greeting appears before Noa types anything.

**Expected Output:**
```
☀️ בוקר טוב, נועה!

📅 היום (חמישי, 23 במאי):
┌────────────────┬──────────┐
│ נושא           │ זמן      │
├────────────────┼──────────┤
│ חזרה אנגלית    │ 30 דק    │
│ (הכנה לבחינה)  │          │
│ פרויקט ביולוגיה│ 45 דק    │
│ (מחקר נוסף)    │          │
└────────────────┴──────────┘

⏰ זמן מומלץ: 18:00 (אחרי כדורסל) ✅

📊 התקדמותך:
  ✅ אתמול: סיימת טריגונומטריה — כל הכבוד! 🔥
  🔥 רצף: 5 ימים רצופים של לימודים
  📈 מתמטיקה: עלית מ-65% ל-78% בתרגילים
  📈 אנגלית: 12 מילים חדשות שמורות השבוע

👀 נראה שאתמול הקשיבו לי כשאמרת "יום קל" — הכנסתי לך בלוק אחד בלבד.
כל צעד בכיוון הנכון.

בואי נתחיל? או שאתמול עדיין קשה?
```

**Narration (EN):**
> "The next day, Noa opens the Codespace. The Squad greets her with today's plan, reminds her of yesterday's progress, shows her five-day streak, and notes that math scores improved from 65% to 78%. It's not pushy — it's observant, encouraging, and realistic."

---

### Scene 7: Parent View — Weekly Report [5:15–5:45]

**Screen:** Parent opens a dashboard link  
**Note:** Different color scheme (pastel), less detailed than student view

**Expected Output:**
```
📊 דוח שבועי — נועה (כיתה י׳)

📅 שבוע: 16–23 במאי

✅ הלימודים:
  • שעות לימוד: 11.5 שעות
  • נושאים: מתמטיקה, אנגלית, היסטוריה, ביולוגיה
  • ממוצע יומי: ~90 דקות

🎯 התקדמות:
  • רצף: 5 ימים רצופים
  • מתמטיקה: 65% → 78% (טרנד חיובי ✓)
  • אנגלית: תרגול קריאה עולה
  • היסטוריה: נתחלה ניתוח מקורות

⚠️ נקודות לעקיבה:
  • פרויקט ביולוגיה: בזמן (עד 1 ביוני)
  • אנגלית: צריכה עידוד בשמיעה (listening)

🕯️ חוקי שבת: מכובדים ✓
⚽ כדורסל: משתלב בתוכנית ✓

💡 מה אתם רואים:
  לא ציונים. לא לחץ. רק מודעות מרגיעה.
  נועה דוגלת בלימודים. היא בשביל הזה.

סוג פעולה: יצא עם דוגלה זמין אם צריכה תמיכה בשמיעה באנגלית.
```

**Narration (EN):**
> "Parents see a different view — no pressure, no grades. Just awareness. What subjects is Noa studying? How many hours? Is she on track? Are there areas needing support? The report shows trends, respects Shabbat, and never implies judgment."

---

### Scene 8: Closing Statement [5:45–6:00]

**Screen:** Noa back at terminal, natural ending (no "bye" — just closing the app)

**Narration (EN):**
> "Squad for Kids isn't about babies and stickers anymore. For teenagers facing real exams in a real language, it becomes something else: an honest study partner. One that knows your schedule, teaches you actively, measures real progress, and keeps you motivated without judgment. That's the study support every teen needs."

**Narration (HE):**
> "Squad for Kids זה לא רק צעצועים וציוני. לתלמידים בגרות שעומדים מול בחינות אמיתיות בשפה שלהם, זה הופך למשהו אחר: שותף לימודים אמיתי. אחד שמכיר את לוח הזמנים שלך, מלמד אותך באופן פעיל, מודד התקדמות אמיתית, ושומר אותך במוטיבציה ללא שיפוט. זו התמיכה בלימודים שכל מתבגר צריך."

---

## Pre-Recording Checklist

- [ ] Terminal font size: 16pt (readable in 1080p)
- [ ] Terminal theme: Dark background (Dracula or One Dark Pro)
- [ ] VS Code: Hebrew language pack installed (`code --install-extension MS-CEINTL.vscode-language-pack-he`)
- [ ] System time: Set to May 23, 2024 (exam prep period)
- [ ] System language: Hebrew
- [ ] Network: Connected (Squad API calls are live)
- [ ] Volume: Check mic levels before recording
- [ ] Camera: Capture desk + screen (optional, adds realism)

---

## Reset / Cleanup

```powershell
# After recording, reset the profile
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force
```

---

## TTS Commands

### English Narration

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+10%" `
    --text "Squad for Kids isn't about babies and stickers anymore. For teenagers facing real exams in a real language, it becomes something else: an honest study partner. One that knows your schedule, teaches you actively, measures real progress, and keeps you motivated without judgment. That's the study support every teen needs." `
    --write-media output/narration/21-teen-exam-prep-en-closing.mp3
```

### Hebrew Narration

```powershell
edge-tts --voice "he-IL-HilaNeural" --rate "+5%" `
    --text "Squad for Kids זה לא רק צעצועים וציוני. לתלמידים בגרות שעומדים מול בחינות אמיתיות בשפה שלהם, זה הופך למשהו אחר: שותף לימודים אמיתי. אחד שמכיר את לוח הזמנים שלך, מלמד אותך באופן פעיל, מודד התקדמות אמיתית, ושומר אותך במוטיבציה ללא שיפוט. זו התמיכה בלימודים שכל מתבגר צריך." `
    --write-media output/narration/21-teen-exam-prep-he-closing.mp3
```

---

## Editing Notes

- **Color grading:** Slightly more saturated than kid demos (feels less playful, more serious)
- **Pacing:** Slightly slower — let Noa's typing and Squad's responses breathe
- **Music:** Instrumental, modern (not childish) — think lo-fi study beats
- **Text overlay:** Show timestamps, exam countdown, streak counter
- **Camera:** If using face cam, show thoughtful expressions (not excited, not stressed)

---

## Recording Tips

1. **Authenticity:** Type at natural speed, don't rush. Mistakes (and corrections) are OK.
2. **Hebrew typing:** Use Hebrew keyboard layout (Windows: Alt+Shift or Win+Space). Don't show keyboard layout switching.
3. **Squad responses:** If live API is slow, paste pre-recorded output instead. Edit smoothly.
4. **Breathing room:** Pause between scenes. Let responses fully render before moving on.
5. **Natural ending:** Don't say "The End" or "Thanks for watching." Just close the terminal naturally.

---

## Thumbnail Concept

**Visual:** Noa's face (or silhouette), Israeli flag emoji 🇮🇱, exam calendar 📅, and text "BAGRUT 53 DAYS LEFT"  
**Color:** Teal/blue (calmer than earlier videos), clean sans-serif font  
**Vibe:** Academic but approachable — "This is real"

---

## Cross-Promotion Notes

- Link to **Video 14** (Study Scheduler) in description — shows the spaced repetition system in action
- Link to **Video 18** (Squad Templates) — shows how "Exam Prep" template is built
- Link to **Video 16** (Multi-Language) — shows Hebrew/English switching in detail
- New playlist: "Squad for Teens & Families"

