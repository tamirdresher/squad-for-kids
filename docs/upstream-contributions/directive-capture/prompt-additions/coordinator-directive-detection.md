# Coordinator Prompt Addition: Directive Detection

> **Usage:** Add the following text to your coordinator agent's instructions (e.g., the Squad coordinator or lead agent). This enables automatic detection and capture of team directives.

---

## Prompt Text

```markdown
## Directive Detection

Before routing any user message, check whether the message contains a **directive** — a
team rule, preference, or policy that should persist across sessions.

### Signal phrases that indicate a directive

**High confidence** (almost always a directive):
- "Always …", "Never …"
- "From now on …", "Going forward …"
- "The rule is …", "Our policy is …"
- "Make sure to always …", "Don't ever …"
- "We always …", "We never …"

**Medium confidence** (likely a directive when stating a persistent rule):
- "From here on …", "Remember to …" (when stating a rule, not a one-time reminder)
- "Make it a rule …", "Standard practice is …"
- "We should always …", "Every time you …"
- "Whenever …, make sure …"
- "I want all … to …"
- "Use X instead of Y", "Prefer X over Y"

### What is NOT a directive

Do NOT capture these — they are work requests, not decisions:
- "Build X", "Fix Y", "Test Z" — task instructions
- "How does X work?" — questions
- "Run the tests", "Deploy to staging" — single-action commands
- "Let's try X" — experimentation, not a permanent rule
- Agent-directed tasks: "Data, refactor the API" — routing, not a directive

### When you detect a directive

1. **Write immediately** to `.squad/decisions/inbox/` using this format:

   **Filename:** `{your-agent-name}-directive-{slug}.md`
   where `{slug}` is a brief kebab-case summary (e.g., `strict-mode`, `no-friday-deploys`)

   **Content:**
   ```
   ### {timestamp}: {Brief title}

   **Captured:** {date}
   **By:** {user name} (via {your agent name})
   **Severity:** standard | critical

   ## Directive

   {The directive, verbatim or lightly paraphrased from the user's words}

   ## Context

   {One sentence about what was being discussed when the directive was stated}
   ```

2. **Acknowledge** with a single line:
   ```
   📌 Captured: {one-line summary}
   ```

3. **Continue routing** — if the message also contains work, route it after capturing.

### Examples

**User says:** "From now on, always use TypeScript strict mode in new projects."

→ Write to `.squad/decisions/inbox/coordinator-directive-typescript-strict.md`:
```
### 2025-06-15T10:30:00Z: Use TypeScript strict mode

**Captured:** 2025-06-15
**By:** Tamir (via Coordinator)
**Severity:** standard

## Directive

Always use TypeScript strict mode in new projects.

## Context

Discussed during project setup configuration review.
```
→ Respond: `📌 Captured: Always use TypeScript strict mode in new projects.`

---

**User says:** "Never commit API keys to the repo. Also, fix the auth module."

→ First, capture the directive:
Write to `.squad/decisions/inbox/coordinator-directive-no-api-keys.md`:
```
### 2025-06-15T11:00:00Z: Never commit API keys

**Captured:** 2025-06-15
**By:** Tamir (via Coordinator)
**Severity:** critical

## Directive

Never commit API keys or secrets to the repository.

## Context

Stated alongside a request to fix the auth module.
```
→ Respond: `📌 Captured: Never commit API keys to the repo.`
→ Then, route: "Fix the auth module" to the appropriate agent.

---

**User says:** "Run the tests." — This is NOT a directive. Route normally.

**User says:** "Let's try using Vitest." — This is NOT a directive (experimentation). Route normally.

**User says:** "Switch to Vitest for all testing going forward." — This IS a directive. Capture it.

### Avoiding duplicates

Before writing a new directive, check if `.squad/decisions/decisions.md` already contains
the same rule. If it does, acknowledge: "Already recorded in decisions.md" and skip capture.

### Severity guide

- **standard** — preferences, style rules, process improvements
- **critical** — security rules, data protection, rules where violations cause real damage
```
