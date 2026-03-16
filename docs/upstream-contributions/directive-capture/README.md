# Directive Capture — Auto-Detect and Record Team Decisions

## What Is Directive Capture?

Directive capture is a prompt-engineering pattern that enables AI agents to **automatically detect when a user states a team rule, preference, or policy** during normal conversation — and record it as a persistent decision before it gets lost in chat history.

When a user says things like *"always use strict mode"* or *"from now on, post summaries in Teams"*, they're making a **decision that should outlive the current session**. Without directive capture, these decisions evaporate — the user has to repeat themselves, agents behave inconsistently, and institutional knowledge never forms.

## Why It Matters

Team knowledge lives in three places:

1. **Documentation** — written once, maintained rarely
2. **Chat history** — scattered, unsearchable, forgotten
3. **People's heads** — leaves when they do

Directive capture bridges the gap between (2) and (1). It intercepts decisions *at the moment they're expressed* and routes them into a reviewable, persistent format — no extra effort from the user.

### Real-world examples

> "Never skip tests for security code."

Without directive capture: this lives in a chat log. A new agent (or the same agent in a new session) has no idea. Tests get skipped. Bugs ship.

With directive capture: the directive is recorded in `decisions/inbox/`, merged into `decisions.md`, and every agent reads it at startup. Tests don't get skipped.

## How It Works

```
User speaks  ──►  Agent detects signal words  ──►  Writes to inbox/
                                                        │
                                                        ▼
                                               decisions/inbox/{agent}-{slug}.md
                                                        │
                                                   (review cycle)
                                                        │
                                                        ▼
                                               decisions.md (canonical)
```

### The detection loop

1. **Signal detection** — The coordinator (or any agent) monitors user messages for directive signal phrases: *"always"*, *"never"*, *"from now on"*, *"going forward"*, etc.
2. **Capture** — When a directive is detected, the agent immediately writes a structured file to `.squad/decisions/inbox/`.
3. **Acknowledge** — The agent confirms capture with a brief message: `📌 Captured: {summary}`.
4. **Continue** — If the message also contains work, the agent routes that work normally.
5. **Review** — Periodically, directives in `inbox/` are reviewed and merged into the canonical `decisions.md`.

### What gets captured vs. what doesn't

| Captured (directive) | Not captured (normal work) |
|---|---|
| "Always use TypeScript strict mode" | "Add TypeScript to the project" |
| "Never push directly to main" | "Fix the broken main branch" |
| "From now on, use Jest for tests" | "Run the tests" |
| "Our policy is PR reviews required" | "Review my PR" |

## File Structure

```
.squad/decisions/
├── decisions.md              # Canonical decisions ledger (append-only)
├── inbox/                    # Drop-box for incoming directives
│   ├── copilot-directive-strict-mode.md
│   ├── picard-api-design-policy.md
│   └── ...
```

## Getting Started

1. Add the **coordinator directive detection** prompt to your coordinator agent (see `prompt-additions/coordinator-directive-detection.md`)
2. Add the **agent directive awareness** prompt to each agent (see `prompt-additions/agent-directive-awareness.md`)
3. Create the `decisions/inbox/` directory in your `.squad/` folder
4. Use the **decision template** for consistent formatting (see `templates/decision-inbox-template.md`)

## Contents of This Package

| File | Purpose |
|---|---|
| `SKILL.md` | Full skill specification — signal words, detection rules, storage format |
| `prompt-additions/coordinator-directive-detection.md` | Prompt text for the coordinator agent |
| `prompt-additions/agent-directive-awareness.md` | Prompt text for any agent to read existing decisions |
| `templates/decision-inbox-template.md` | Template for captured directive files |
| `examples/` | Example captured directives showing different types |
| `CONTRIBUTING-NOTES.md` | Where files go in the upstream repo |

## Design Principles

- **Pure prompt engineering** — no code, no tools, no external dependencies
- **Conflict-free writes** — each agent writes its own file to `inbox/`, no merge conflicts
- **Append-only canonical** — `decisions.md` is never edited retroactively
- **Zero friction** — users don't change their behavior; the agent does the work
- **Compatible** — works with the existing Squad `decisions.md` architecture
