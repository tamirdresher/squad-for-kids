# Skill: GitHub Project Board Management

**Confidence:** medium
**Domain:** issue-lifecycle, project-management

## הקשר

הצוות משתמש בלוח GitHub Projects V2 כדי לעקוב אחרי מצב issues. כש-issue משנה סטטוס — צריך לעדכן גם את הלוח.

## עמודות בלוח

| עמודה | מתי להשתמש |
|--------|------------|
| **Todo** | Issue מסווג ומשויך אבל העבודה לא התחילה |
| **In Progress** | עובדים על זה (branch נוצר, PR בטיוטה) |
| **Done** | Issue נסגר, PR מוזג |
| **Blocked** | לא ניתן להתקדם — חסימה |
| **Needs Help** | צריך עזרה מהמנחה |

## איך להזיז items

### 1. הוספת issue ללוח

```bash
gh project item-add 1 --owner tamirdresher --url https://github.com/tamirdresher/kids-squad-setup/issues/{NUMBER}
```

### 2. הזזת item לעמודה

```bash
gh project item-edit --project-id {PROJECT_ID} --id {ITEM_ID} --field-id {STATUS_FIELD_ID} --single-select-option-id {OPTION_ID}
```

## מתי לעדכן את הלוח

1. **סיווג:** כשמסווגים issue → הגדר `Todo`
2. **התחלת עבודה:** כשיוצרים branch/PR → הגדר `In Progress`
3. **חסימה:** כשנתקלים בבעיה → הגדר `Blocked` + תגובה שמסבירה למה
4. **צריך עזרה:** כשמוסיפים לייבל `needs-help` → הגדר `Needs Help`
5. **סגירה:** כשסוגרים issue → הגדר `Done`

## חשוב

- תמיד לעדכן גם את הלוח וגם את הלייבל ביחד
- אם פקודות `gh project` נכשלות — לרשום את הכישלון אבל לא לחסום את העבודה
- כש**סוגרים** issue (כולל "לא מתוכנן") — תמיד להזיז ל-Done
