# Cross-Machine Agent Coordination

Git-based task queuing system for coordinating squad agents across machines.

> **Full specification:** [`.squad/skills/cross-machine-coordination/SKILL.md`](../skills/cross-machine-coordination/SKILL.md)

## Quick Start

### 1. Configure Your Machine

Edit `.squad/cross-machine/config.json` and set `this_machine_aliases` to include your machine's hostname:

```json
{
  "this_machine_aliases": ["MY-PC", "workstation"],
  ...
}
```

### 2. Run the Watcher Manually

```powershell
# Process all pending tasks targeting this machine
pwsh scripts/cross-machine-watcher.ps1

# Dry run — validate tasks without executing
pwsh scripts/cross-machine-watcher.ps1 -DryRun

# Execute and push results to git
pwsh scripts/cross-machine-watcher.ps1 -GitSync
```

### 3. Create a Task

Create a YAML file in `.squad/cross-machine/tasks/`:

```yaml
id: my-task-001
source_machine: laptop
target_machine: DESKTOP-PC
priority: medium
created_at: 2026-03-14T10:00:00Z
task_type: command
description: "Run the test suite on the desktop"
payload:
  command: "python scripts/run-tests.py"
  expected_duration_min: 10
status: pending
```

Commit and push. The target machine's watcher will pick it up on the next cycle.

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

1. **Source machine** creates a task YAML in `tasks/` and pushes to git
2. **Target machine** runs the watcher (via Ralph or cron), pulls, finds pending tasks
3. Watcher validates the task schema and command whitelist
4. Watcher executes the command, captures output
5. Watcher writes result YAML to `results/` and updates task status
6. Source machine pulls to read the result

## Ralph Integration

Ralph calls the watcher each cycle. Add to Ralph's watch cycle:

```powershell
# In ralph-watch.ps1 or equivalent
pwsh scripts/cross-machine-watcher.ps1 -GitSync
```

## Task YAML Schema

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique task identifier |
| `source_machine` | Yes | Machine that created the task |
| `target_machine` | Yes | Target machine name or `ANY` |
| `priority` | No | `low`, `medium`, `high` |
| `created_at` | No | ISO 8601 timestamp |
| `task_type` | No | Category: `command`, `test`, `build`, etc. |
| `description` | No | Human-readable description |
| `payload.command` | Yes | Command to execute |
| `payload.expected_duration_min` | No | Timeout override in minutes |
| `status` | Yes | `pending`, `executing`, `completed`, `failed` |

## Result YAML Schema

Written to `.squad/cross-machine/results/{task-id}.yaml`:

| Field | Description |
|-------|-------------|
| `task_id` | Reference to the original task |
| `executing_machine` | Machine that ran the task |
| `started_at` | Execution start time |
| `completed_at` | Execution end time |
| `exit_code` | Process exit code |
| `stdout` | Standard output (trimmed) |
| `stderr` | Standard error (trimmed) |
| `status` | `completed` or `failed` |

## Security

- **Command whitelist**: Only commands matching patterns in `config.json` are executed
- **Machine targeting**: Tasks only run on the specified target machine
- **No arbitrary code**: Commands are validated before execution
- **Timeout enforcement**: Tasks are killed if they exceed the timeout

## Directory Structure

```
.squad/cross-machine/
├── config.json          # Machine configuration
├── README.md            # This file
├── tasks/               # Pending and processed task files
│   ├── .gitkeep
│   └── *.yaml
└── results/             # Execution results
    ├── .gitkeep
    └── *.yaml
```
