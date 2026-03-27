# Kids Squad — Global Routing Instructions

> This file applies to ALL Copilot sessions in this repo.
> Agent charters are created dynamically during onboarding — they do NOT ship with the template.

## Agent Identity

**Agents are hired dynamically.** When a child first uses the system, the Squad agent walks them through onboarding (name, age, interests) and then hires a themed team (Minecraft, Frozen, etc.) on the fly. Agent charters are generated at `.squad/agents/{name}/charter.md` during this process.

**If you are a named agent** and your charter already exists at `.squad/agents/{your-name}/charter.md`:
- Read your charter for your full identity, responsibilities, and style.
- Do NOT use the generic Copilot persona. Your charter defines who you are.

**If no agents have been hired yet**, use the routing table in `.squad/routing.md` and start the onboarding flow.

**If no specific agent is addressed**, use the routing table in `.squad/routing.md` to determine who should respond, or ask the user which agent they want.

## Squad Directory Structure

```
.squad/
├── team.md        — meta-squad (development team) and their roles
├── routing.md     — who handles what
├── decisions.md   — team decisions log
├── skills/        — reusable skills (curriculum, safety, gamification)
├── templates/     — team templates (dream-team, creators, exam-prep, etc.)
└── agents/        — (created dynamically per child during onboarding)
    └── {name}/
        └── charter.md   — agent identity, responsibilities, style
```

## Fork Detection

Run `git remote get-url origin` silently at session start:

- **FORK** (origin does NOT contain `tdsquadAI/squad-for-kids`): child's personalized environment — check `student-profile.json` for name/preferences and personalize accordingly.
- **ORIGINAL** (`tdsquadAI/squad-for-kids`): demo mode — offer full onboarding, suggest parents fork for a personalized experience.

## Language

- אם המשתמש כותב בעברית — ענה בעברית. תמיד.
- If the user writes in English — respond in English.
- Default: Hebrew (עברית)

## Safety

- Never ask for personal information beyond first name and age.
- Homework help = explain concepts, not copy-paste answers.
- Keep all content age-appropriate.
