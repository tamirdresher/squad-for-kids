# 📱 Squad Mobile — Quick Start Guide
# מדריך מהיר — סקוואד מהנייד

> Talk to your AI Squad from your phone via Telegram or Discord.
>
> דברו עם צוות ה-AI שלכם מהנייד דרך טלגרם או דיסקורד.

---

## 🚀 Telegram Setup (5 min) | הגדרת טלגרם (5 דקות)

### Step 1: Create a Bot | שלב 1: יצירת בוט

1. Open Telegram on your phone | פתחו את טלגרם בנייד
2. Search for **@BotFather** | חפשו את **@BotFather**
3. Send: `/newbot` | שלחו: `/newbot`
4. Choose a name: `Squad Bot` (or anything) | בחרו שם: `Squad Bot` (או כל שם)
5. Choose a username: `my_squad_bot` (must end in `bot`) | בחרו שם משתמש (חייב להסתיים ב-`bot`)
6. **Copy the token** BotFather gives you | **העתיקו את הטוקן** שבוטפאדר נותן לכם

> ⏱️ This takes ~2 minutes | זה לוקח ~2 דקות

### Step 2: Run Setup | שלב 2: הרצת הגדרה

```powershell
# In your repo directory | בתיקיית הריפו שלכם
.\scripts\setup-telegram-bot.ps1
```

The script will:
- Ask for your token | יבקש את הטוקן שלכם
- Validate it with Telegram | יאמת מול טלגרם
- Save config to `~/.squad/telegram-config.json`
- Create inbox/outbox directories

### Step 3: Start the Bot | שלב 3: הפעלת הבוט

```powershell
# Foreground (see logs) | פורגראונד (רואים לוגים)
.\scripts\start-telegram-bot.ps1

# Background (runs silently) | רקע (רץ בשקט)
.\scripts\start-telegram-bot.ps1 -Background
```

### Step 4: Test It! | שלב 4: בדיקה!

1. Open Telegram on your phone | פתחו טלגרם בנייד
2. Find your bot (search its username) | מצאו את הבוט (חפשו לפי שם משתמש)
3. Send `/start` | שלחו `/start`
4. Send any message — it goes to your Squad! | שלחו כל הודעה — היא מגיעה לסקוואד!

### Commands | פקודות

| Command | What it does | מה זה עושה |
|---------|-------------|-------------|
| `/start` | Welcome message | הודעת ברוכים הבאים |
| `/help` | Show commands | הצגת פקודות |
| `/status` | Check Squad status | בדיקת סטטוס סקוואד |
| `/ask <question>` | Ask your Squad | שאלו את הסקוואד |
| (any text) | Send to inbox | שליחה לתיבת דואר |

---

## 🎮 Discord Setup (5 min) | הגדרת דיסקורד (5 דקות)

> ⏳ Coming soon — Data is building the Discord bot.
>
> ⏳ בקרוב — Data בונה את בוט הדיסקורד.

### When Ready | כשיהיה מוכן

1. Create a Discord server (or use existing) | צרו שרת דיסקורד (או השתמשו בקיים)
2. Create a bot at [Discord Developer Portal](https://discord.com/developers/applications)
3. Run setup: `.\scripts\setup-discord-bot.ps1`
4. Start: `.\scripts\start-discord-bot.ps1`

---

## 📖 How It Works | איך זה עובד

```
Your Phone                    Your PC
──────────                    ──────────
 Telegram  ──→ Telegram API ──→  squad-telegram-bot.py
    ↑                              ↓ writes to
    │                         ~/.squad/mobile-inbox/
    │                              ↓ picked up by
    │                         squad-mobile-watcher.py
    │                              ↓ routes to
    │                         Copilot CLI / Squad
    │                              ↓ response to
    │                         ~/.squad/mobile-outbox/
    │                              ↓ picked up by
    └──── Telegram API ←──── squad-telegram-bot.py
```

### Architecture | ארכיטקטורה

- **`squad-telegram-bot.py`** — Polls Telegram, reads/writes messages | סוקר טלגרם, קורא/כותב הודעות
- **`squad-mobile-watcher.py`** — Bridges inbox→Squad→outbox | מגשר בין תיבת דואר לסקוואד
- **`setup-telegram-bot.ps1`** — One-time setup wizard | אשף הגדרה חד-פעמי
- **`start-telegram-bot.ps1`** — Launch script with checks | סקריפט הפעלה עם בדיקות

### Files | קבצים

| Path | Purpose | תפקיד |
|------|---------|-------|
| `~/.squad/telegram-config.json` | Bot token & settings | טוקן והגדרות |
| `~/.squad/mobile-inbox/` | Incoming messages | הודעות נכנסות |
| `~/.squad/mobile-outbox/` | Outgoing responses | תגובות יוצאות |
| `~/.squad/mobile-processed/` | Archived messages | הודעות בארכיון |
| `~/.squad/telegram-bot.log` | Bot logs | לוגים של הבוט |
| `~/.squad/telegram-bot-state.json` | Poll offset state | מצב סקירה |

---

## 🔒 Security | אבטחה

### Lock to Your Chat ID | נעילה ל-Chat ID שלכם

After first message, check the bot log for your chat ID:

```powershell
Get-Content ~/.squad/telegram-bot.log | Select-String "chat"
```

Then edit `~/.squad/telegram-config.json`:

```json
{
  "bot_token": "your-token",
  "allowed_chat_ids": [123456789]
}
```

This blocks anyone else from using your bot.

> אחרי ההודעה הראשונה, בדקו את הלוג לקבלת ה-chat ID שלכם.
> הוסיפו אותו ל-allowed_chat_ids בקונפיג כדי לנעול את הבוט.

---

## 🛠️ Troubleshooting | פתרון בעיות

| Problem | Solution | פתרון |
|---------|----------|-------|
| "No token found" | Run `setup-telegram-bot.ps1` | הריצו את סקריפט ההגדרה |
| Bot doesn't respond | Check `~/.squad/telegram-bot.log` | בדקו את הלוג |
| "requests not found" | Run `pip install requests` | התקינו requests |
| Messages not processed | Start `squad-mobile-watcher.py` too | הפעילו גם את הוואצ'ר |
| Unauthorized error | Add your chat ID to config | הוסיפו chat ID לקונפיג |

---

## 🏃 TL;DR — Fastest Path | הדרך המהירה ביותר

```powershell
# 1. Get token from @BotFather on Telegram
# 1. קבלו טוקן מ-@BotFather בטלגרם

# 2. Run setup | הריצו הגדרה
.\scripts\setup-telegram-bot.ps1

# 3. Start bot | הפעילו בוט
.\scripts\start-telegram-bot.ps1 -Background

# 4. Start watcher (in another terminal) | הפעילו וואצ'ר (בטרמינל נוסף)
python scripts\squad-mobile-watcher.py

# 5. Open Telegram, find your bot, send a message!
# 5. פתחו טלגרם, מצאו את הבוט, שלחו הודעה!
```

---

*Built by B'Elanna — Infrastructure Expert*
*If it ships, it ships reliably.*
