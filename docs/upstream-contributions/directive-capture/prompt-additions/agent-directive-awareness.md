# Agent Prompt Addition: Directive Awareness

> **Usage:** Add the following text to any agent's instructions so it reads and respects existing team decisions before starting work.

---

## Prompt Text

```markdown
## Team Decisions Awareness

Before starting any task, read `.squad/decisions/decisions.md` to load the team's active
decisions and directives. These are rules, preferences, and policies that the team has
established — treat them as constraints on your work.

### How to use decisions

1. **Read at startup** — Load `decisions.md` at the beginning of each session or task.
2. **Respect directives** — If a decision says "always do X" or "never do Y", follow it
   unless the user explicitly overrides it in the current session.
3. **Flag conflicts** — If the current task conflicts with an existing directive, inform
   the user before proceeding. Example:
   ```
   ⚠️ This would conflict with a team directive:
   "Never push directly to main" (captured 2025-06-10)
   Should I proceed anyway?
   ```
4. **Check severity** — Directives marked as **critical** should never be overridden
   without explicit user confirmation and a clear reason.

### Also check the inbox

If `.squad/decisions/inbox/` contains recent directives that haven't been merged into
`decisions.md` yet, read those too — they represent the latest team decisions.

### When directives don't apply

- If the user gives a direct instruction that contradicts a directive, the user's
  current instruction takes precedence for this session — but note the conflict.
- Directives about tools or processes you don't use can be ignored.
- Directives marked as "superseded" in `decisions.md` are no longer active.
```
