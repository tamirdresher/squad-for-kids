# 📰 Daily Briefing — Example Format

Use this template as the base format for Neelix daily briefings. Adapt the sections based on actual squad activity.

---

## Example Output

```
📰 SQUAD DAILY BRIEFING — Monday, March 17 2026
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Good morning! Your favorite AI news reporter here with today's updates.

🟢 COMPLETED
• #142 — Auth module refactored (merged by @alice)
• #155 — Dashboard CSS fixes (closed)

🟡 IN PROGRESS
• #160 — API rate limiting implementation (@bob, 60% done)
• #163 — Search indexing optimization (@carol)

🔴 BLOCKED
• #158 — Deployment pipeline — waiting on infra approval

📊 BY THE NUMBERS
• PRs merged: 3
• Issues closed: 5
• New issues: 2
• Build status: ✅ All green

💡 KEY DECISIONS
> "Moving to weekly releases starting next sprint" — @lead

🎯 TODAY'S FOCUS
The team is heads-down on the API rate limiting work.
Review requested on PR #161 — @bob needs eyes on the middleware.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📡 This has been your Squad Daily Briefing.
   Neelix, signing off. Stay merge-tastic! 🖖
```

## Sections Breakdown

| Section | Required | Notes |
|---------|----------|-------|
| Header + date | ✅ | Always include |
| Completed items | ✅ | Issues/PRs closed since last briefing |
| In Progress | ✅ | Active work with assignees |
| Blocked | If any | Highlight blockers prominently |
| By the Numbers | Optional | Quick stats when available |
| Key Decisions | If any | Pull quotes from decisions.md |
| Today's Focus | Optional | What the team should pay attention to |
| Sign-off | ✅ | Always end with personality |

## Adaptive Card Version

For Teams delivery, wrap the above in an Adaptive Card JSON structure:

```json
{
  "type": "AdaptiveCard",
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "version": "1.5",
  "body": [
    {
      "type": "TextBlock",
      "text": "📰 SQUAD DAILY BRIEFING",
      "weight": "Bolder",
      "size": "Large"
    },
    {
      "type": "TextBlock",
      "text": "Monday, March 17 2026",
      "isSubtle": true
    },
    {
      "type": "TextBlock",
      "text": "🟢 **COMPLETED**\n- #142 — Auth module refactored\n- #155 — Dashboard CSS fixes",
      "wrap": true
    },
    {
      "type": "TextBlock",
      "text": "━━━━━━━━━━━━━━━━━━━━━━━━",
      "isSubtle": true
    },
    {
      "type": "TextBlock",
      "text": "📡 _Neelix, signing off. Stay merge-tastic!_ 🖖",
      "wrap": true,
      "isSubtle": true
    }
  ]
}
```

## Channel Routing

Daily briefings should include: `CHANNEL: tech-news`
