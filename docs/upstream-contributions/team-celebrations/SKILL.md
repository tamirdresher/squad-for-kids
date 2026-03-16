# Celebrations Skill

> Skill definition for team birthday, anniversary, and milestone celebrations.

## Overview

The Celebrations Skill enables Squad to automatically recognize and celebrate team milestones. It checks a local data store for upcoming events and generates personalized, heartfelt messages delivered through your chosen channel.

## Data Storage

### Team Member Data

Team data is stored in `.squad/team-data/members.json`. This file contains **only opt-in, minimal information**:

```json
{
  "version": "1.0",
  "members": [
    {
      "id": "unique-member-id",
      "displayName": "Alex",
      "birthday": "03-15",
      "startDate": "2022-06-01",
      "optedIn": true,
      "celebrationPreferences": {
        "birthdayMessage": true,
        "anniversaryMessage": true,
        "milestoneMessage": true
      }
    }
  ]
}
```

### Schema Rules

| Field | Required | Format | Notes |
|-------|----------|--------|-------|
| `id` | Yes | String | Unique identifier (GitHub username, email, or UUID) |
| `displayName` | Yes | String | Preferred name for messages (first name or nickname) |
| `birthday` | No | `MM-DD` | Month and day only — **no year, no age** |
| `startDate` | No | `YYYY-MM-DD` | Date joined the team (for anniversary calculations) |
| `optedIn` | Yes | Boolean | Must be `true` for any celebrations to trigger |
| `celebrationPreferences` | No | Object | Granular opt-in per celebration type |

### Privacy Model

The privacy model is **the most important part of this skill**:

1. **Explicit opt-in required** — The `optedIn` field must be `true`. Default is `false` (or absent).
2. **Birthday has no year** — We store `MM-DD` only. No age calculation, no age display.
3. **Granular preferences** — Members can opt into birthdays but not anniversaries, or vice versa.
4. **Self-service removal** — Any member can set `optedIn: false` or remove their entry entirely.
5. **No external sync** — Data stays in the repository. No cloud storage, no external APIs store this data.
6. **No derived data** — The skill never calculates or displays age. It never stores data beyond what's in the schema.

### Populating Member Data

Members can be added through any of these methods:

- **Manual entry** — Team members submit a PR adding themselves to `members.json`
- **Team directory sync** — A script pulls names from GitHub org, Azure AD, or similar (opt-in still required)
- **Onboarding flow** — New team members are invited to opt-in during onboarding

Regardless of method, the `optedIn` field must be explicitly set by the individual.

## Celebrations Check Logic

### When to Check

The celebrations check runs at the **start of each Ralph watch cycle** (typically daily, in the morning).

### What to Check

```
For each member where optedIn == true:
  1. If birthday is set AND birthday matches any day in [today .. today + 7 days]:
     -> Queue birthday celebration (if celebrationPreferences.birthdayMessage != false)
  
  2. If startDate is set AND anniversary of startDate matches any day in [today .. today + 7 days]:
     -> Queue anniversary celebration (if celebrationPreferences.anniversaryMessage != false)
  
  3. Check for achievement milestones (configurable):
     -> Queue milestone celebration (if celebrationPreferences.milestoneMessage != false)
```

### Lookahead Window

The default lookahead is **7 days**. This ensures:
- Weekend birthdays aren't missed
- Messages can be delivered on the workday closest to the event
- No duplicate messages (track delivered celebrations in a state file)

### Deduplication

Track delivered celebrations in `.squad/team-data/.celebrations-state.json`:

```json
{
  "delivered": [
    {
      "memberId": "unique-member-id",
      "type": "birthday",
      "date": "2025-03-15",
      "deliveredAt": "2025-03-14T09:00:00Z"
    }
  ]
}
```

## Message Generation

### Principles

Messages should be:
- **Personalized** — Use the member's display name, reference their specific milestone
- **Heartfelt** — Genuine warmth, not corporate templates
- **Fun** — Squad has personality! Emoji, humor, and energy are welcome
- **Brief** — A few sentences, not a novel
- **Respectful** — No age references, no assumptions about personal life

### Generation Methods

Messages can be generated through:

1. **Template-based** — Use the templates in `templates/` with variable substitution
2. **AI-generated** — Use WorkIQ or a similar AI tool for more personalized, contextual messages
3. **Custom** — Teams can provide their own message generation logic

### Template Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{name}}` | Member's display name | Alex |
| `{{years}}` | Years on the team (anniversary only) | 3 |
| `{{milestone}}` | Milestone description | 100th PR merged |
| `{{date}}` | The celebration date | March 15 |
| `{{team}}` | Team name | Squad Alpha |

## Delivery

### Supported Channels

The celebrations skill supports pluggable delivery:

| Channel | Configuration | Notes |
|---------|--------------|-------|
| **Teams channel** | Channel name in ceremony definition | Default — uses Neelix for delivery |
| **Email** | SMTP config or Graph API | No provider lock-in — any SMTP works |
| **Webhook** | URL endpoint | For Slack, Discord, or custom integrations |
| **Custom** | Script path | Run any script for delivery |

### Channel Routing

By default, celebration messages route to the **`wins`** channel:

```
CHANNEL: wins
```

Teams can override this in their ceremony definition to use any channel they prefer.

### Message Format

Delivered messages follow this structure:

```
[Celebration Type] — [Member Name]

[Generated message]

— Your Squad
```

## Configuration

### Skill Configuration (`.squad/skills/celebrations.json`)

```json
{
  "skill": "celebrations",
  "enabled": true,
  "lookaheadDays": 7,
  "delivery": {
    "channel": "wins",
    "method": "teams"
  },
  "milestones": {
    "prCount": [10, 50, 100, 500, 1000],
    "issuesClosed": [25, 100, 500],
    "custom": []
  }
}
```

### Milestone Definitions

Milestones can be defined for any trackable achievement:

- **PR count** — 10th, 50th, 100th, 500th, 1000th PR merged
- **Issues closed** — 25th, 100th, 500th issue closed
- **Custom** — Teams can define their own milestones (e.g., "first release", "first on-call rotation")

## Integration Points

| System | Integration | Purpose |
|--------|------------|---------|
| Ralph | Watch cycle hook | Triggers the daily celebrations check |
| Neelix | Message delivery | Posts celebration messages to Teams channels |
| Kes | Scheduling | Schedules delivery for optimal timing |
| GitHub API | Milestone data | PR counts, issue counts for achievement milestones |
| Team directory | Member sync | Optional: pull team roster (opt-in still required) |

---

*Every celebration is a small act of recognition that says: "You matter to this team."*
