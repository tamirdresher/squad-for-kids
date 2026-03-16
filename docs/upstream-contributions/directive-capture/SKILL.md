# Skill: Directive Capture

## Overview

Directive capture is the ability for an AI agent to **detect when a user is stating a team rule, preference, or policy** and automatically record it as a structured decision — without the user having to explicitly ask.

This is a **passive detection** skill: the agent monitors every user message for directive signals and captures them inline, before routing any work.

---

## Signal Words and Phrases

The following words and phrases indicate the user is making a directive (a decision that should persist across sessions).

### High-confidence signals (almost always a directive)

| Signal | Example |
|---|---|
| "Always …" | "Always run linting before committing" |
| "Never …" | "Never use `any` type in TypeScript" |
| "From now on …" | "From now on, all PRs need two reviewers" |
| "Going forward …" | "Going forward, we use PostgreSQL" |
| "The rule is …" | "The rule is no direct pushes to main" |
| "Our policy is …" | "Our policy is 80% test coverage minimum" |
| "Make sure to always …" | "Make sure to always include error handling" |
| "Don't ever …" | "Don't ever commit secrets to the repo" |
| "We always …" | "We always write integration tests for APIs" |
| "We never …" | "We never deploy on Fridays" |

### Medium-confidence signals (likely a directive when combined with a rule)

| Signal | Example |
|---|---|
| "From here on …" | "From here on, use conventional commits" |
| "Remember to …" (persistent) | "Remember to tag releases with semver" |
| "Make it a rule …" | "Make it a rule that docs are updated with code" |
| "Standard practice is …" | "Standard practice is feature branches" |
| "We should always …" | "We should always log API responses" |
| "Every time you …" | "Every time you add a route, add a test" |
| "Whenever …, make sure …" | "Whenever deploying, make sure to notify the channel" |
| "I want all … to …" | "I want all functions to have JSDoc comments" |
| "Use X instead of Y" | "Use pnpm instead of npm" |
| "Prefer X over Y" | "Prefer composition over inheritance" |

### Low-confidence signals (only a directive if stating a persistent rule)

| Signal | Example that IS a directive | Example that is NOT |
|---|---|---|
| "Keep …" | "Keep all configs in `/config`" | "Keep working on the feature" |
| "Stop …" | "Stop using `var` in new code" | "Stop the dev server" |
| "Switch to …" | "Switch to Vitest for all testing" | "Switch to the main branch" |

### NOT directives (do not capture)

These patterns look similar but are **work requests**, not decisions:

- "Build X", "Fix Y", "Test Z" — work instructions
- "How does X work?" — questions
- "Can you check if …" — investigation requests
- "Run the tests" — single-action commands
- "Let's try X" — experimentation, not a rule
- Agent-directed tasks: "Data, refactor the API" — routing, not a directive

---

## Detection Rules

### Rule 1: Signal + Persistence = Directive

A message is a directive if it contains a signal phrase AND expresses something that should persist beyond the current session. Ask: *"Would the user want every future agent to know this?"*

### Rule 2: Capture Before Routing

If a message contains both a directive and a work request, capture the directive FIRST, then route the work.

> "From now on, use TypeScript strict mode. Also, fix the login bug."
>
> → Capture: "Use TypeScript strict mode" (directive)
> → Route: "Fix the login bug" (work)

### Rule 3: Verbatim or Light Paraphrase

Record the user's words as closely as possible. Light paraphrase is acceptable for clarity, but don't editorialize or add interpretation.

### Rule 4: Don't Double-Capture

If a directive already exists in `decisions.md`, don't capture it again. Acknowledge that it's already recorded.

### Rule 5: Acknowledge Briefly

After capturing, confirm with a single line:

```
📌 Captured: [one-line summary of the directive]
```

Do not make the acknowledgment longer than the directive itself.

---

## What to Capture

Each captured directive should include:

| Field | Description |
|---|---|
| **Timestamp** | When the directive was captured (ISO 8601 or human-readable) |
| **Source** | Who stated the directive (user name, via which agent) |
| **Directive** | The rule/preference/policy, verbatim or lightly paraphrased |
| **Context** | What was being discussed when the directive was stated (one sentence) |
| **Severity** | `standard` — normal preference; `critical` — violations cause real damage |

---

## Where to Store

### Inbox (immediate write)

```
.squad/decisions/inbox/{agent}-directive-{slug}.md
```

- `{agent}` — the agent that captured the directive (e.g., `copilot`, `picard`, `data`)
- `{slug}` — a brief kebab-case summary (e.g., `strict-mode`, `no-friday-deploys`)

### Canonical (after review)

Directives are merged into `.squad/decisions/decisions.md` during review cycles. The canonical file is:

- **Append-only** — never edited retroactively
- **Read by all agents** at session start
- **The source of truth** for team decisions

---

## Decision Lifecycle

```
1. Detection    →  Agent spots directive signal in user message
2. Capture      →  Agent writes to decisions/inbox/{agent}-directive-{slug}.md
3. Acknowledge  →  Agent confirms: "📌 Captured: {summary}"
4. Review       →  Team lead or scribe reviews inbox/ entries
5. Merge        →  Approved directives appended to decisions.md
6. Enforce      →  All agents read decisions.md and follow captured directives
```

### Review outcomes

| Outcome | Action |
|---|---|
| **Approved** | Merge into `decisions.md`, delete from `inbox/` |
| **Clarification needed** | Flag for discussion with the user |
| **Duplicate** | Delete from `inbox/`, note existing entry |
| **Superseded** | Mark old directive as superseded, merge new one |
| **Rejected** | Delete from `inbox/`, note reason |

---

## Integration with Existing Architecture

Directive capture is designed to work with the existing Squad decisions architecture:

- **No new tools required** — pure prompt engineering
- **No schema changes** — uses the same markdown format as existing decisions
- **Conflict-free** — each agent writes its own file, no merge conflicts
- **Backward compatible** — agents that don't have directive capture still read `decisions.md` normally
