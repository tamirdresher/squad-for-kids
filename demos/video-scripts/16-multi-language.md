# 🎬 Video 16: Multi-Language

> **Title (EN):** Hebrew, English, Arabic — Learning in Any Language
> **Title (HE):** עברית, אנגלית, ערבית — ללמוד בכל שפה

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~4 minutes |
| **Target Audience** | Parents in multilingual communities |
| **Languages** | English, Hebrew, Arabic |
| **Prerequisites** | Student profile |
| **Difficulty** | Beginner |

---

## Key Takeaway

> The Squad seamlessly switches between languages mid-session. Kids can learn math in Hebrew, English in English, and even practice Arabic — all in the same conversation.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force
```

---

## Storyboard

### Scene 1: Default Language [0:00–0:30]

**Type:**
```
copilot
```

Then:
```
Hi Hermione!
```

**Expected:** Response in English (default language in profile)

---

### Scene 2: Switch to Hebrew [0:30–1:15]

**Type:**
```
הרמיוני, אפשר לדבר בעברית?
```

**Expected (verify — switches to Hebrew):**
```
🧙‍♀️ בטח, יואב! אני שמחה לדבר איתך בעברית! 🇮🇱

מה תרצה ללמוד היום? אני יכולה:
  📖 לקרוא איתך סיפור בעברית
  🔢 לתרגל חשבון בעברית
  📝 לעזור עם כתיבה
  🇬🇧 ללמד אותך מילים באנגלית

מה מתחשק לך?
```

**Type:**
```
בואי נתרגל חשבון
```

**Expected:**
```
🧙‍♀️ מצוין! 

🔢 שאלה: כמה זה 23 + 19?

רמז: התחל מספרת האחדות. מה זה 3 + 9? 🤔
```

**Narration (EN):**
> "Yoav switches to Hebrew with a single sentence. The Squad responds entirely in Hebrew — including math terminology. This is critical for Israeli students who learn math in Hebrew at school."

---

### Scene 3: English Lesson in English [1:15–2:00]

**Type:**
```
Now let's practice English vocabulary
```

**Expected (switches to English):**
```
🧙‍♀️ Great idea! Let's practice English! 🇬🇧

Today's vocabulary theme: Animals! 🐾

Match the Hebrew word to the English word:

1. כלב = ___
2. חתול = ___
3. ציפור = ___
4. דג = ___

(Hint: dog, cat, fish, bird — but in which order? 🤔)
```

**Narration (EN):**
> "For English vocabulary, the system naturally switches to English — because that's the subject. But it keeps Hebrew hints for comfort, since that's Yoav's primary language."

---

### Scene 4: Arabic Introduction [2:00–2:45]

**Type:**
```
Can I learn some Arabic words too?
```

**Expected:**
```
🧙‍♀️ Of course! Arabic is a beautiful language, and it's actually
related to Hebrew! Let's start with greetings:

🇸🇦 Arabic Greetings:

| Arabic | Pronunciation | Hebrew Equivalent | English |
|--------|--------------|-------------------|---------|
| مرحبا | Mar-ha-ba | שלום | Hello |
| شكرا | Shuk-ran | תודה | Thank you |
| صباح الخير | Sa-bah al-kheir | בוקר טוב | Good morning |

🤯 Fun fact: Both Arabic and Hebrew come from the same language family!
The word for "peace" is almost the same:
  🇸🇦 سلام (Salaam) ↔ שלום (Shalom) 🇮🇱

Want to practice more? 🌍
```

**Narration (EN):**
> "The Squad can introduce new languages too — here it connects Arabic to Hebrew, showing shared roots. This is especially relevant in Israel where Arabic is an official language."

---

### Scene 5: Mixed-Language Session [2:45–3:30]

**Type:**
```
תגידי לי facts about space באנגלית
```

**Expected (code-switching — responds in both):**
```
🧙‍♀️ Sure! Here are some amazing space facts! 🚀

1. 🌍 Earth spins at 1,670 km/h — כדור הארץ מסתובב במהירות 1,670 קמ"ש!
2. ☀️ The Sun is 109 times bigger than Earth — השמש גדולה פי 109 מכדור הארץ
3. 🌙 The Moon is 384,400 km away — הירח נמצא במרחק 384,400 ק"מ

💡 Vocabulary boost:
  - Space = חלל
  - Planet = כוכב לכת
  - Star = כוכב
  - Moon = ירח

רוצה לשמוע עוד? (Want to hear more?) 🌌
```

**Narration (EN):**
> "Yoav mixes Hebrew and English in one sentence — and the Squad matches that style. This is how bilingual kids actually communicate. The system meets them where they are."

---

### Scene 6: Closing [3:30–4:00]

**Narration (EN):**
> "Hebrew, English, Arabic — or any combination. The Squad adapts to how your child actually speaks. In a multilingual world, that's not a feature — it's a necessity."

---

## Reset / Cleanup

```powershell
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force
```

---

## TTS Commands

```powershell
# English narration
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/16-multi-language-en.txt `
    --write-media output/narration/16-multi-language-en.mp3

# Hebrew narration segments
edge-tts --voice "he-IL-HilaNeural" --rate "+0%" `
    --file scripts/16-multi-language-he.txt `
    --write-media output/narration/16-multi-language-he.mp3

# Arabic narration segments
edge-tts --voice "ar-SA-ZariyahNeural" --rate "+0%" `
    --file scripts/16-multi-language-ar.txt `
    --write-media output/narration/16-multi-language-ar.mp3
```
