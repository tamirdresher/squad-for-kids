# 📅 Study Scheduler Skill

> Adapted from the production squad's Kids Study Assistant and Squad Scheduler systems.

## Purpose

Automatically schedule and manage study sessions for children. Creates daily study plans with spaced repetition, sends reminders, and adapts to the student's curriculum and pace.

## Capabilities

- **Daily study plan generation** with spaced repetition algorithm
- **Exam-aware scheduling** — prioritizes subjects with upcoming tests
- **Multi-student support** — tracks multiple children independently
- **Shabbat/weekend-aware** — respects rest days and cultural calendar
- **Cron-based triggers** — morning check-ins, afternoon homework reminders
- **Break scheduling** — enforces brain breaks between study blocks

## Trigger Schedule

| Trigger | Time | Action |
|---------|------|--------|
| Morning check-in | 08:00 (school days) | Post today's study plan |
| Homework reminder | 15:30 (weekdays) | Remind about pending assignments |
| Evening review | 19:00 (school days) | Quick review of what was learned |
| Weekend activity | 10:00 (Sat/Sun) | Fun learning activities suggestion |

## Configuration

Study schedule is defined in `.squad/schedule.json`:

```json
{
  "id": "daily-study-plan",
  "name": "Daily Study Plan",
  "trigger": {
    "type": "cron",
    "expression": "0 8 * * 0-4"
  },
  "task": {
    "type": "agent",
    "action": "generate-daily-plan"
  },
  "options": {
    "shabbatAware": true,
    "timezone": "auto",
    "maxSessionMinutes": 45,
    "breakMinutes": 10
  }
}
```

## Exam Schedule Format

Parents or kids can add upcoming exams in YAML:

```yaml
exams:
  - subject: "Mathematics"
    date: "2026-04-15"
    topics: ["fractions", "decimals", "word problems"]
    weight: high
  - subject: "Science"
    date: "2026-04-20"
    topics: ["solar system", "gravity"]
    weight: medium
```

## Spaced Repetition Algorithm

1. New material gets 3 study sessions in the first week
2. Review sessions at day 1, 3, 7, 14, 30
3. Exam subjects get increased frequency as the date approaches
4. Difficult topics (low quiz scores) get extra repetitions
5. Mastered topics move to maintenance mode (monthly review)

## Integration Points

- **Student Profile** → reads grade, curriculum, learning pace
- **Teaching Plan** → updates progress after each session
- **Gamification** → awards XP for completed sessions, streak bonuses
- **Parent Reports** → logs session completion for weekly summaries
- **Homework Tracker** → coordinates with assignment deadlines

## Upstream Reference

Adapted from:
- `tamresearch1/.squad/skills/kids-study-assistant/` — exam schedule parsing, daily plan generation
- `tamresearch1/.squad/implementations/squad-scheduler-design.md` — cron triggers, provider model
- `tamresearch1/scripts/kids-study/` — PowerShell implementation of study plan generation
