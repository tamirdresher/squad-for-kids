# Team Celebrations — Birthday & Milestone System

> A reusable Squad skill for celebrating team birthdays, work anniversaries, and milestones — because great teams celebrate each other.

## Why This Matters

Teams that celebrate together stay together. Recognition of personal milestones — a birthday, a work anniversary, a 100th PR — builds the kind of trust and camaraderie that makes distributed teams feel *connected*. This isn't just about cake emoji — it's about showing people they're valued.

## What This Provides

| Component | Description |
|-----------|-------------|
| **Celebrations Skill** | Checks for upcoming milestones, generates personalized messages |
| **Ceremony Definition** | "Daily Celebrations Check" — runs every morning during Ralph's watch cycle |
| **Message Templates** | Birthday, anniversary, and milestone templates with personality |
| **Data Schema** | Privacy-first `members.json` for team member data |

## How It Integrates with Squad

The celebrations system plugs into Squad's existing architecture:

1. **Ralph (Work Monitor)** — Runs the daily celebrations check at the start of each watch cycle
2. **Neelix (Communications)** — Can deliver celebration messages to Teams channels
3. **Kes (Scheduling)** — Can schedule celebration posts for optimal timing
4. **Channel Routing** — Messages route to the `wins` channel (or your configured celebrations channel)

## Privacy Model

This system is designed to be **privacy-conscious by default**:

- **Opt-in only** — Team members must explicitly consent to share their data
- **Minimal data** — Only name, birthday (month/day — no year), and start date
- **No sensitive info** — No ages, no personal details, no tracking
- **Local storage** — Data lives in `.squad/team-data/members.json`, not external services
- **Easy removal** — Any member can remove themselves at any time

## Quick Start

1. Copy `templates/members.json` to `.squad/team-data/members.json`
2. Have team members opt-in and add their details
3. Add the celebrations ceremony to your `.squad/ceremonies/` directory
4. Configure your delivery channel in the ceremony definition
5. Ralph handles the rest during each watch cycle

## Design Principles

- **No email provider lock-in** — Delivery is pluggable (Teams, email, webhook, etc.)
- **Works with any team directory** — Sync from Azure AD, GitHub org, or manual entry
- **Personality matters** — Messages should be heartfelt and fun, not corporate boilerplate
- **Respects boundaries** — Never pushy, always optional

## File Structure

```
team-celebrations/
+-- README.md                          # This file
+-- SKILL.md                           # The celebrations skill definition
+-- ceremony-definition.md             # Daily celebrations check ceremony
+-- CONTRIBUTING-NOTES.md              # Where files go in upstream
+-- templates/
    +-- members.json                   # Example team data schema
    +-- birthday-message.md            # Birthday message template
    +-- anniversary-message.md         # Work anniversary message template
    +-- milestone-message.md           # Milestone celebrations template
```

## Contributing

See [CONTRIBUTING-NOTES.md](CONTRIBUTING-NOTES.md) for guidance on integrating this into the upstream Squad repository.

---

*Built with love by a Squad that celebrates its people.*
