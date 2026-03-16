# Contributing Notes — Directive Capture

## Target: bradygaster/squad (branch: dev)

This document maps files in this contribution package to their intended locations in the upstream Squad repository.

## File Mapping

| This package | Upstream location | Notes |
|---|---|---|
| `README.md` | `docs/skills/directive-capture/README.md` | Overview and getting-started guide |
| `SKILL.md` | `docs/skills/directive-capture/SKILL.md` | Full skill specification |
| `prompt-additions/coordinator-directive-detection.md` | `docs/skills/directive-capture/prompt-additions/coordinator-directive-detection.md` | Coordinator prompt text |
| `prompt-additions/agent-directive-awareness.md` | `docs/skills/directive-capture/prompt-additions/agent-directive-awareness.md` | Agent awareness prompt text |
| `templates/decision-inbox-template.md` | `docs/skills/directive-capture/templates/decision-inbox-template.md` | Inbox file template |
| `examples/*` | `docs/skills/directive-capture/examples/` | Example captured directives |

## Integration Points

### Coordinator agent instructions

The coordinator prompt addition (`coordinator-directive-detection.md`) should be added to the coordinator agent's system instructions. In the upstream Squad repo, this would be incorporated into the coordinator's agent definition file.

### Agent instructions

The agent awareness prompt (`agent-directive-awareness.md`) should be added to every agent's base instructions so all agents respect captured decisions.

### Decisions directory

The upstream repo needs:

```
.squad/decisions/
├── decisions.md     # Canonical decisions ledger
└── inbox/           # Drop-box for incoming directives
```

If `decisions/` already exists in upstream, this contribution is additive — it enhances the existing pattern with automated directive detection.

## What This Contribution Does NOT Include

- **Code or tooling** — This is pure prompt engineering
- **Changes to existing agent logic** — Only additive prompt text
- **Schema definitions** — Uses simple markdown, not YAML/JSON
- **Breaking changes** — Fully backward-compatible with existing decisions architecture

## Testing

To verify directive capture works:

1. Add the coordinator prompt addition to your coordinator agent
2. Send a message containing a directive signal: "From now on, always use conventional commits"
3. Verify that a file appears in `.squad/decisions/inbox/`
4. Verify the agent acknowledges with `📌 Captured: ...`
5. Verify that non-directive messages ("Run the tests") are not captured
