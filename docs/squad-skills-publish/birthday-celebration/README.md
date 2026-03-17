# 🎂 Birthday & Celebration System

Automated team birthday and celebration tracking with privacy-safe registry and scheduled notifications.

## What It Does

- **Track celebrations** — Maintain a privacy-safe registry (month/day only, no birth year)
- **Upcoming alerts** — Check for birthdays within a configurable window
- **Celebration messages** — Generate themed messages for team channels
- **Multi-channel delivery** — Webhooks, email, GitHub issues, or messaging APIs
- **Multiple event types** — Birthdays, work anniversaries, milestones

## Trigger Phrases

- `birthday`, `team birthday`
- `upcoming birthdays`, `who has a birthday`
- `celebration`, `celebrate`

## Quick Start

### Prerequisites

- JSON registry file with team member birthdays
- Delivery channel (webhook URL, email, or messaging API)

### Example Usage

```
User: "Check for upcoming birthdays this week"
Agent: [Reads celebrations.json, checks dates within 7-day window]
Agent: "🎂 Alice Chen's birthday is in 3 days (March 15)!"
```

## Registry Format

```json
{
  "members": [
    { "name": "Alice Chen", "birthday": "03-15", "role": "Engineer" }
  ]
}
```

## Privacy

- Only month/day stored — no birth year
- Opt-in only
- Private team channels only

## See Also

- [News Broadcasting](../news-broadcasting/) — Deliver celebration announcements
- [Notification Routing](../notification-routing/) — Route to the right channel
