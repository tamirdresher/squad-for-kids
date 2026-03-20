# 📧 Parent Notifications Skill

> Adapted from the production squad's email pipeline and family email routing system.

## Purpose

Deliver learning reports, progress updates, and important notifications to parents via email. Supports automated weekly reports, real-time alerts, and keyword-based actions.

## Capabilities

- **Weekly parent reports** — auto-generated summaries of learning progress
- **Real-time alerts** — notify parents of milestones, concerns, or achievements
- **Email-based actions** — parents can send commands via email keywords
- **Multi-channel delivery** — email (primary), with extensibility for Teams/webhooks
- **Sensitivity labeling** — respects organizational email policies

## Report Types

| Report | Frequency | Content |
|--------|-----------|---------|
| Weekly Summary | Every Sunday 18:00 | Topics covered, time spent, strengths, areas to practice |
| Achievement Alert | Real-time | Badge earned, level up, streak milestone |
| Concern Flag | Real-time | Frustration detected, extended inactivity, difficulty spike |
| Monthly Overview | 1st of month | Month-long trends, curriculum progress, recommendations |

## Email Action Keywords

Parents can email the squad with these keywords in the subject:

| Keyword | Action | Example |
|---------|--------|---------|
| `@report` | Generate an on-demand progress report | `@report How is Sarah doing in math?` |
| `@schedule` | View or modify study schedule | `@schedule Add extra math on Tuesdays` |
| `@pause` | Pause learning sessions | `@pause Vacation until March 15` |
| `@resume` | Resume learning sessions | `@resume Back from vacation` |

## Weekly Report Template

```markdown
# 📊 Weekly Learning Report — {child_name}
**Week of {start_date} to {end_date}**

## 🌟 Highlights
- {highlight_1}
- {highlight_2}

## 📚 Subjects Covered
| Subject | Sessions | Time | Mastery |
|---------|----------|------|---------|
| {subject} | {count} | {minutes}min | {level} |

## 💪 Strengths
- {strength_1}

## 🎯 Areas to Practice
- {area_1}

## 🏆 Achievements
- {badge_or_milestone}

## 📝 Recommended Weekend Activities
- {activity_1}
```

## Configuration

```json
{
  "parentEmail": "parent@example.com",
  "reportFrequency": "weekly",
  "reportDay": "Sunday",
  "reportTime": "18:00",
  "timezone": "auto",
  "alertTypes": ["achievement", "concern", "milestone"],
  "language": "auto"
}
```

## Security Model

- **No child data in email body** — reports use first name only
- **Authorized recipients only** — parent email verified during onboarding
- **All notifications logged** — audit trail in `.squad/notification-log.json`
- **Unsubscribe support** — parents can opt out of any notification type

## Upstream Reference

Adapted from:
- `tamresearch1/scripts/squad-email/` — email routing, SMTP/Graph API integration
- `tamresearch1/.squad/email-pipeline/` — family email guide, keyword-based actions
- `tamresearch1/.squad/kids-directives/procedures.md` — RP-002 Weekly Parent Report pattern
