# 🤖 צוות AI לילדים — Kids Squad Setup

סקריפטים אוטומטיים ליצירת צוות AI אישי לילדים, בהשראת [Squad](https://github.com/bradygaster/squad).

## 🌟 מה זה?

כל ילד מקבל **צוות AI מותאם אישית** שעוזר לו לפתח פרויקטים!
הסקריפטים מתקינים הכל אוטומטית — כלי פיתוח, VS Code, חשבון GitHub, פרויקט ראשון, ומוניטור.

## 👥 הצוותים

| ילד/ה | סקריפט | צוות | פרויקט ראשון |
|--------|--------|------|-------------|
| 🌟 שירה (15) | `setup-squad-shira.ps1` | צוות מחקר (Study-Buddy, Code-Pro, Design-Eye, Data-Viz) | ניתוח נתונים ב-Python |
| 🎮 יונתן (13) | `setup-squad-yonatan.ps1` | צוות משחקים (GameDev, ArtBot, BugHunter, IdeaGuy) | Space Invaders |
| 🦸 אייל (8.5) | `setup-squad-eyal.ps1` | צוות גיבורי-על (ציירון, קודי, רעיונית) | דף סופר-גיבורים |

## 🚀 הרצה מהירה

```powershell
# שירה
irm https://raw.githubusercontent.com/tamirdresher/kids-squad-setup/main/setup-squad-shira.ps1 -OutFile setup.ps1
powershell -ExecutionPolicy Bypass -File setup.ps1

# יונתן
irm https://raw.githubusercontent.com/tamirdresher/kids-squad-setup/main/setup-squad-yonatan.ps1 -OutFile setup.ps1
powershell -ExecutionPolicy Bypass -File setup.ps1

# אייל (עם אבא/אמא)
irm https://raw.githubusercontent.com/tamirdresher/kids-squad-setup/main/setup-squad-eyal.ps1 -OutFile setup.ps1
powershell -ExecutionPolicy Bypass -File setup.ps1
```

## 📋 מה כל סקריפט עושה

1. **בדיקת דרישות** — Git, VS Code, Python/Node.js, GitHub CLI
2. **הגדרת GitHub** — התחברות או יצירת חשבון
3. **יצירת צוות AI** — תיקיית `.squad/` עם סוכנים, תפקידים, ותיאורים בעברית
4. **הגדרת VS Code** — הרחבות מומלצות, הגדרות מותאמות גיל
5. **Ralph Watch** — מוניטור שעוקב אחרי הריפו
6. **Git & GitHub** — אתחול ריפו, commit ראשון, push
7. **פרויקט ראשון** — קוד מוכן להרצה, מותאם לגיל ולתחום העניין

## ⚙️ אפשרויות

```powershell
# הרצה יבשה — מראה מה יקרה בלי לשנות כלום
.\setup-squad-shira.ps1 -DryRun

# דילוג על התקנת כלים (אם כבר מותקנים)
.\setup-squad-shira.ps1 -SkipPrereqs
```

## 📖 מידע נוסף

- [הבלוג של אבא — Organized by AI](https://www.tamirdresher.com/blog/2026/03/10/organized-by-ai)
- [Squad Framework](https://github.com/bradygaster/squad)
- [GitHub Copilot](https://github.com/features/copilot)

---
*נוצר על ידי צוות ה-AI של תמיר דרשר 🤖*
