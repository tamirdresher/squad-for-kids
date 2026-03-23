# 🎬 Video 08: WhatsApp / Telegram Integration

> **Title (EN):** Study from Your Phone — Chat-Based Learning
> **Title (HE):** ללמוד מהטלפון — למידה בצ'אט

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~5 minutes |
| **Target Audience** | Parents, non-technical users |
| **Languages** | English + Hebrew (separate recordings) |
| **Prerequisites** | WhatsApp Web or Telegram Web, Playwright MCP configured |
| **Difficulty** | Advanced (setup), Easy (usage) |

---

## Key Takeaway

> Kids can interact with their Squad through WhatsApp or Telegram — no GitHub needed. Parents set it up once via Playwright MCP, and kids just text their learning requests like chatting with a friend.

---

## Pre-Recording Setup

```powershell
cd C:\temp\squad-for-kids

# 1. Ensure Playwright MCP is configured
cat .copilot/mcp-config.json

# 2. Launch Edge in CDP mode
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
    --remote-debugging-port=9222 `
    --user-data-dir="C:\temp\edge-demo-profile" `
    --start-maximized

# 3. Open WhatsApp Web (https://web.whatsapp.com) — scan QR code
# 4. Have a test conversation ready (use a second phone)
# 5. Student profile must exist
Copy-Item demos/profiles/yoav-grade2.json .squad/student-profile.json -Force
```

### Phone Setup (second device)

- Use a second phone to send messages to WhatsApp Web
- Or use Telegram Desktop as the "kid's device"
- Pre-create a chat thread named "Squad Study" or similar

---

## Storyboard

### Scene 1: Why Messaging? [0:00–0:30]

**Screen:** Phone mockup or WhatsApp Web

**Narration (EN):**
> "Not every kid has a laptop. Not every parent wants their child on GitHub. But every family has a phone. With Squad for Kids, your child can text their questions on WhatsApp or Telegram — and get the same personalized learning experience."

**Narration (HE):**
> "לא לכל ילד יש מחשב נייד. לא כל הורה רוצה שהילד שלו בגיטהאב. אבל לכל משפחה יש טלפון. עם סקוואד לילדים, הילד שלכם יכול לשלוח את השאלות שלו בוואטסאפ או טלגרם — ולקבל את אותה חווית למידה מותאמת אישית."

---

### Scene 2: Setup Overview [0:30–1:15]

**Screen:** Terminal + config file

**Narration (EN):**
> "The integration uses Playwright MCP — a browser automation tool that connects to WhatsApp Web or Telegram Web. It reads incoming messages and routes them to the Squad, just like GitHub issues."

**On Screen:**
1. Show the MCP config briefly
2. Show the concept: Phone → WhatsApp Web → Playwright → Squad → Response → WhatsApp Web → Phone

**Diagram (show on screen or narrate):**
```
📱 Kid's Phone                    💻 Parent's Computer
     │                                    │
     ├─ WhatsApp message ──────► WhatsApp Web
     │                                    │
     │                           Playwright MCP reads message
     │                                    │
     │                           Squad processes request
     │                                    │
     │                           Playwright types response
     │                                    │
     ◄── Response appears ◄───── WhatsApp Web
```

---

### Scene 3: Kid Sends a Message [1:15–2:15]

**Screen:** Split — WhatsApp Web (browser) + terminal

**Message from phone (type on second device):**
```
הי הרמיוני! 🧙‍♀️ מה זה שבר עשרוני?
```

**English equivalent:**
```
Hi Hermione! 🧙‍♀️ What's a decimal fraction?
```

**Narration (EN):**
> "Yoav texts Hermione on WhatsApp — in Hebrew, naturally. The Playwright MCP picks up the message, sends it to the Squad, and the response appears right in the chat."

**Narration (HE):**
> "יואב שולח הודעה להרמיוני בוואטסאפ — בעברית, כמובן. ה-Playwright MCP אוסף את ההודעה, שולח אותה לסקוואד, והתשובה מופיעה ישירות בצ'אט."

**Expected Response (appears in WhatsApp):**
```
🧙‍♀️ הרמיוני כאן! שאלה מצוינת, יואב!

שבר עשרוני הוא דרך לכתוב חלקים של מספר שלם.
חשוב על זה ככה:

🍕 אם יש לך פיצה ואתה חותך אותה ל-10 חלקים שווים,
כל חלק הוא 0.1 (עשירית)

אז 0.5 = חצי פיצה = 5 חלקים מתוך 10!

רוצה שנתרגל עוד דוגמאות? 📝
```

---

### Scene 4: Back-and-Forth Conversation [2:15–3:15]

**Screen:** WhatsApp Web — continuing the conversation

**Kid types:**
```
כן! תני לי תרגיל
```

**Expected Response:**
```
📝 בסדר! הנה תרגיל:

יש לך 0.3 של פיצה ואבא נתן לך עוד 0.4 פיצה.
כמה פיצה יש לך עכשיו? 🍕

רמז: חשוב על זה כמו 3 חלקים + 4 חלקים...
```

**Kid types:**
```
0.7!
```

**Expected Response:**
```
🎉 מדהים, יואב! 0.3 + 0.4 = 0.7 — צדקת!

3 חתיכות + 4 חתיכות = 7 חתיכות = 0.7

+15 XP 🌟 רצף של 2 ימים! 🔥

רוצה עוד תרגיל או לעבור לנושא אחר?
```

**Narration (EN):**
> "The conversation flows naturally — just like texting a friend. The Squad remembers context, tracks XP, and even awards streak points. All through WhatsApp."

---

### Scene 5: Telegram Alternative [3:15–3:45]

**Screen:** Telegram Web (brief)

**Narration (EN):**
> "The same works with Telegram — and it's actually easier because Telegram has a bot API. You can set up a dedicated bot that kids message directly."

**On Screen:** Show Telegram bot chat briefly (can be a screenshot if not live)

---

### Scene 6: Parent Controls [3:45–4:30]

**Screen:** Terminal — config settings

**Narration (EN):**
> "Parents control the hours — no messages after bedtime. They control the topics — nothing inappropriate. And they get a daily summary of what was discussed. All configurable in decisions.md."

**On Screen:**
```markdown
# decisions.md — Messaging Rules
- WhatsApp hours: 3 PM – 7 PM (after school, before bed)
- Block topics: violence, social media, mature content
- Parent daily digest: enabled (email summary at 8 PM)
```

---

### Scene 7: Closing [4:30–5:00]

**Narration (EN):**
> "Learning happens where kids already are — on their phones. No apps to install, no accounts to create. Just text your Squad and start learning."

**Narration (HE):**
> "למידה קורית במקום שבו ילדים כבר נמצאים — בטלפון שלהם. בלי אפליקציות להתקין, בלי חשבונות ליצור. פשוט כתבו לסקוואד שלכם והתחילו ללמוד."

---

## Reset / Cleanup

```powershell
# Clear WhatsApp conversation (manual)
# Stop Playwright MCP if running
# Close Edge CDP instance
Stop-Process -Id (Get-Process msedge | Where-Object {$_.CommandLine -match "9222"}).Id -ErrorAction SilentlyContinue
```

---

## Screen Recording Notes

| Setting | Value |
|---------|-------|
| **Resolution** | 1920×1080 |
| **Main area** | WhatsApp Web (browser), split with terminal for setup |
| **Speed adjustments** | Real-time for chat, speed up config sections |
| **Pause points** | After first response appears in WhatsApp |
| **Privacy** | Blur/hide phone numbers and contact lists |

---

## TTS Commands

```powershell
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/08-whatsapp-en.txt `
    --write-media output/narration/08-whatsapp-en.mp3

edge-tts --voice "he-IL-HilaNeural" --rate "+0%" `
    --file scripts/08-whatsapp-he.txt `
    --write-media output/narration/08-whatsapp-he.mp3
```
