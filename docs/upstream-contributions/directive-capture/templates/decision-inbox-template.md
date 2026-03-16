# Decision Inbox Template

> **Usage:** When an agent captures a directive, copy this template to
> `.squad/decisions/inbox/{agent}-directive-{slug}.md` and fill in the fields.

---

```markdown
### {TIMESTAMP}: {Brief descriptive title}

**Captured:** {YYYY-MM-DD}
**By:** {User name} (via {Agent name})
**Severity:** standard | critical

## Directive

{The directive as stated by the user — verbatim or lightly paraphrased for clarity.
Keep it concise. One to three sentences maximum.}

## Context

{One sentence describing what was being discussed when the directive was stated.
This helps future readers understand the intent behind the rule.}
```

---

## Field Guide

| Field | Description | Example |
|---|---|---|
| `{TIMESTAMP}` | ISO 8601 datetime or human-readable | `2025-06-15T10:30:00Z` |
| `{Brief descriptive title}` | Short summary of the directive | `Use TypeScript strict mode` |
| `{YYYY-MM-DD}` | Date of capture | `2025-06-15` |
| `{User name}` | Who stated the directive | `Tamir` |
| `{Agent name}` | Which agent captured it | `Coordinator`, `Picard`, `Copilot` |
| `Severity` | `standard` for preferences, `critical` for rules where violations cause real damage | `standard` |
| `Directive` | The actual rule or policy | `Always run linting before committing` |
| `Context` | What was being discussed | `Discussed during CI pipeline setup` |

## Filename Convention

```
.squad/decisions/inbox/{agent}-directive-{slug}.md
```

- `{agent}` — lowercase name of the capturing agent: `copilot`, `picard`, `data`, etc.
- `{slug}` — kebab-case summary, 2-5 words: `strict-mode`, `no-friday-deploys`, `use-pnpm`

### Examples

- `copilot-directive-strict-mode.md`
- `picard-directive-no-friday-deploys.md`
- `data-directive-prefer-composition.md`
- `copilot-directive-pr-reviews-required.md`
