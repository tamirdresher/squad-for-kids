---
name: "squad-conventions"
description: "מוסכמות ודפוסים בשימוש בפרויקט Squad"
domain: "project-conventions"
confidence: "high"
source: "manual"
---

## הקשר

המוסכמות האלה חלות על כל העבודה ב-Squad CLI (`create-squad`). Squad הוא כלי Node.js בלי תלויות חיצוניות שמוסיף צוותי סוכני AI לכל פרויקט.

## דפוסים

### אפס תלויות

ל-Squad אין תלויות זמן ריצה. הכל משתמש ב-Node.js מובנה (`fs`, `path`, `os`, `child_process`). אל תוסיפו חבילות ל-`dependencies` ב-`package.json`.

### מבנה קבצים

- `.squad/` — מצב הצוות (בבעלות המשתמש, לא מוחלף בעדכון)
- `.squad/templates/` — תבניות (בבעלות Squad, מוחלפות בעדכון)
- `.github/agents/squad.agent.md` — פרומפט רכז (בבעלות Squad)
- `.squad/skills/` — כישורי צוות בפורמט SKILL.md (בבעלות המשתמש)
- `.squad/decisions/inbox/` — תיבה להחלטות מקבילות

### תאימות Windows

תמיד להשתמש ב-`path.join()` לנתיבי קבצים — לא לכתוב `/` או `\` ישירות. Squad חייב לעבוד על Windows, macOS, ו-Linux.

### Init — שמירה על קיים

ב-init: אם קובץ או תיקייה כבר קיימים — דלגו ודווחו "already exists". לעולם לא למחוק מצב של משתמש.

## דוגמאות

```javascript
// טיפול בשגיאות
function fatal(msg) {
  console.error(`${RED}✗${RESET} ${msg}`);
  process.exit(1);
}

// בניית נתיב (בטוח ל-Windows)
const agentDest = path.join(dest, '.github', 'agents', 'squad.agent.md');

// דפוס skip-if-exists
if (!fs.existsSync(ceremoniesDest)) {
  fs.copyFileSync(ceremoniesSrc, ceremoniesDest);
  console.log(`${GREEN}✓${RESET} .squad/ceremonies.md`);
} else {
  console.log(`${DIM}ceremonies.md already exists — skipping${RESET}`);
}
```

## אנטי-דפוסים

- **הוספת תלויות npm** — Squad הוא zero-dep
- **מפרידי נתיבים קשיחים** — תמיד `path.join()`
- **מחיקת מצב משתמש ב-init** — init מדלג על קיימים
- **stack traces גולמיים** — הכל דרך `fatal()`
