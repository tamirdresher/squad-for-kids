# Multi-Machine Coordination — Git-Based Task Queue

> **Upstream contribution for [bradygaster/squad](https://github.com/bradygaster/squad)**

## Problem Statement

Squad agents often run on different machines — a laptop, a cloud DevBox, an Azure VM.
Today, coordinating work across those machines requires manual copy-paste: you create
a task on Machine A, switch contexts to Machine B, run it, then ferry the result back.

This contribution adds a **git-based task queue** that lets any Squad agent dispatch
work to any other machine automatically. No external message broker, no webhooks —
just YAML files committed to the repo that machines pull on their watch cycle.

## How It Works

```
Machine A                          Git Repo                         Machine B
─────────                          ────────                         ─────────
Create task YAML  ──push──▶  tasks/my-task.yaml  ◀──pull──  Watcher reads tasks
                                                               │
                                                               ▼
                                                         Execute command
                                                               │
                                                               ▼
                              results/my-task.yaml ◀──push── Write result
Read result      ◀──pull──
```

1. **Source machine** writes a task YAML → `git push`
2. **Target machine** pulls, finds pending tasks targeting it
3. Watcher validates schema + command whitelist
4. Watcher executes, captures output
5. Watcher writes result YAML → `git push`
6. Source machine pulls the result on its next cycle

## What's Included

| File | Purpose |
|------|---------|
| `SKILL.md` | Full skill specification — schema, security model, examples |
| `templates/config.json` | Machine configuration template |
| `templates/task-template.yaml` | Task file template |
| `templates/result-template.yaml` | Result file template |
| `scripts/cross-machine-watcher.ps1` | PowerShell watcher skeleton |
| `CONTRIBUTING-NOTES.md` | Placement guide for upstream PR |

## Key Design Decisions

- **Git as transport** — no infrastructure dependency; works offline with eventual consistency
- **YAML task files** — human-readable, diffable, auditable via git history
- **Command whitelist** — only pre-approved commands execute; no arbitrary code execution
- **Machine targeting** — tasks specify a `target_machine`; watchers only pick up their own
- **Timeout enforcement** — every task has a timeout; stalled processes are killed
- **Immutable audit trail** — every execution is a git commit

## Security Model

All tasks pass through a validation pipeline before execution:

1. Schema validation (required fields, no unexpected fields)
2. Command whitelist check (glob patterns in config)
3. Path traversal prevention (no `../../` in commands)
4. Resource limits (timeout, memory, CPU)
5. Execution isolation (unprivileged user, temp dir cleanup)

See `SKILL.md` for the full threat model and mitigations.

## Quick Start

```bash
# 1. Copy templates into your repo
cp -r templates/ .squad/cross-machine/

# 2. Edit config.json — set your machine name and whitelist
$EDITOR .squad/cross-machine/config.json

# 3. Run the watcher (or integrate with Ralph)
pwsh scripts/cross-machine-watcher.ps1 -ConfigPath .squad/cross-machine/config.json

# 4. Create a task from another machine
cat > .squad/cross-machine/tasks/my-first-task.yaml << 'EOF'
id: my-first-task
source_machine: laptop
target_machine: devbox
priority: normal
created_at: 2026-01-01T12:00:00Z
task_type: command
payload:
  command: "echo Hello from cross-machine coordination!"
  expected_duration_min: 1
status: pending
EOF

git add .squad/cross-machine/tasks/ && git commit -m "Task: test cross-machine" && git push
```

## Battle-Tested

This pattern has been used in production across multiple machines for GPU workloads,
blog rendering pipelines, and automated test execution. The included skill spec is
derived from that real-world usage.

## License

Contributed under the same license as the upstream Squad project.
