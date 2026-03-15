# יצירת תמונות וגרפיקה — Skill

**יכולת:** יצירת תמונות וגרפיקה באמצעות Copilot CLI וכלים מאושרים

**סטטוס:** ⚠️ מוגבל — בעיקר גרפיקה טקסטואלית (Mermaid, SVG, ASCII)

---

## מה אפשר לעשות

### ✅ עובד היום

| יכולת | איך | 
|-------|-----|
| **דיאגרמות Mermaid** (flowchart, sequence) | Copilot מייצר קוד `.mmd` → רנדור עם `@mermaid-js/mermaid-cli` |
| **גרפיקת SVG** | Copilot מייצר קוד SVG → שמירה כ-`.svg` |
| **ASCII art** | Copilot מייצר דיאגרמות בטקסט |

### ❌ לא זמין (עדיין)

| מגבלה | למה |
|-------|-----|
| **יצירת תמונות פוטוריאליסטיות** | GitHub Models לא כוללים מודלים ליצירת תמונות |
| **Stable Diffusion** | לא ב-GitHub Models |

---

## איך להשתמש

### דיאגרמות Mermaid — ⭐ מומלץ

```bash
# 1. יצירת קוד Mermaid עם Copilot
# 2. שמירה לקובץ
echo "flowchart TD
  A[התחלה] --> B[בחירה]
  B --> C{מה לעשות?}
  C -->|משחק| D[לשחק!]
  C -->|שיעורים| E[ללמוד!]" > diagram.mmd

# 3. רנדור ל-SVG
npx @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.svg
```

### שרתי MCP

```bash
# שרת Mermaid MCP
# GitHub: https://github.com/hustcc/mcp-mermaid
# מרנדר Mermaid ל-PNG/SVG

# שרת Azure Diagram MCP
# GitHub: https://github.com/dminkovski/azure-diagram-mcp
# יצירת דיאגרמות תשתית
```

---

## טיפים לילדים 🎨

1. **התחילו עם Mermaid** — הכי קל ללמוד
2. **השתמשו ב-Copilot** כדי ליצור את הקוד — פשוט תתארו מה אתם רוצים
3. **SVG עובד בכל דפדפן** — אפשר לשים בדף HTML
4. **ASCII art** — מגניב להודעות בטרמינל!

---

*נוצר: 2026-03-25*
