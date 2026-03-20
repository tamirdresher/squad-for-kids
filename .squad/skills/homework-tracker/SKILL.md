# 📋 Homework Tracker Skill

> Adapted from the production squad's Ralph Watch monitoring system and kids directives.

## Purpose

Continuously monitor homework assignments, track completion status, enforce deadlines, and alert parents when tasks are overdue. Acts as a persistent background watcher that keeps the learning on track — like a friendly, tireless teaching assistant.

## Capabilities

- **Assignment tracking** — log homework with subject, description, due date
- **Status monitoring** — pending → in progress → completed → verified
- **Deadline alerts** — reminders at configurable intervals before due date
- **Overdue detection** — escalates to parent notification when overdue
- **Completion verification** — validates that work meets minimum quality
- **Multi-subject dashboard** — overview of all assignments across subjects
- **Streak tracking** — consecutive on-time submissions earn bonus XP

## Assignment States

```
📝 Assigned → 🔄 In Progress → ✅ Completed → ✔️ Verified
                                    ↓
                              ⏰ Overdue → 📧 Parent Alert
```

## Assignment Format

Assignments are tracked in `.squad/homework.json`:

```json
{
  "assignments": [
    {
      "id": "hw-math-001",
      "subject": "Mathematics",
      "title": "Fractions worksheet — page 42",
      "description": "Complete exercises 1-10 on fraction addition",
      "assignedDate": "2026-03-10",
      "dueDate": "2026-03-12",
      "status": "pending",
      "priority": "high",
      "estimatedMinutes": 30,
      "actualMinutes": null,
      "completedDate": null,
      "notes": ""
    }
  ]
}
```

## Monitoring Schedule

| Check | Frequency | Action |
|-------|-----------|--------|
| Assignment scan | Every session start | Load pending assignments, show dashboard |
| Reminder | 24h before due | "Don't forget — math homework due tomorrow!" |
| Urgent reminder | 4h before due | "Your math homework is due today!" |
| Overdue check | Hourly after due | Mark as overdue, notify parent |
| Daily summary | 15:30 weekdays | List all pending assignments with deadlines |
| Weekly review | Sunday | Summarize week's completion rate |

## Ralph-Style Monitoring Pattern

Inspired by `ralph-watch.ps1`, the homework tracker uses:

1. **Single-instance guard** — only one tracker runs at a time
2. **Heartbeat file** — writes `.squad/homework-heartbeat.json` every cycle
3. **Structured logging** — all actions logged to `.squad/homework-tracker.log`
4. **Failure escalation** — after 3 consecutive missed check-ins, alert parent
5. **Graceful recovery** — on restart, catches up on missed checks

## Gamification Integration

| Achievement | Condition | XP Reward |
|------------|-----------|-----------|
| On Time! | Submit before deadline | +10 XP |
| Early Bird | Submit 24h+ before deadline | +20 XP |
| Perfect Week | All assignments on time for a week | +50 XP |
| Homework Hero | 30-day streak of on-time submissions | +100 XP + badge |
| Catch Up | Complete an overdue assignment | +5 XP |

## Parent Directives Integration

Parents can manage homework rules via `.squad/parent-directives.md`:

```markdown
## Homework Rules
- No gaming until homework is complete
- Maximum 2 hours of homework per day
- Brain break every 30 minutes
- Weekend homework should be done Saturday morning (unless Shabbat-observant)
```

These rules are **inviolable** — agents cannot override them.

## Dashboard View

When a child starts a session, they see:

```
┌─────────────────────────────────────────┐
│ 📋 Homework Dashboard                  │
│                                         │
│ ⚡ Due Today:                           │
│   📐 Math: Fractions p.42 (30 min)     │
│   📖 Reading: Chapter 5 summary        │
│                                         │
│ 📅 Coming Up:                           │
│   🔬 Science: Volcano poster (Fri)     │
│   ✍️ Writing: Book report (next Mon)    │
│                                         │
│ ✅ Completed This Week: 4/6            │
│ 🔥 Streak: 12 days!                    │
└─────────────────────────────────────────┘
```

## Integration Points

- **Study Scheduler** → coordinates study time around homework deadlines
- **Parent Notifications** → sends overdue alerts and weekly completion rates
- **Curriculum Lookup** → validates assignments against expected curriculum topics
- **Gamification** → awards XP and badges for completion patterns
- **Read Aloud** → can read assignment instructions for younger kids

## Upstream Reference

Adapted from:
- `tamresearch1/ralph-watch.ps1` — persistent monitoring pattern, heartbeat, single-instance guard
- `tamresearch1/.squad/kids-directives/tasks.md` — task assignment and status tracking format
- `tamresearch1/.squad/kids-directives/procedures.md` — RP-003 Homework Reminder pattern
- `tamresearch1/.squad/monitoring/` — structured logging, failure escalation
