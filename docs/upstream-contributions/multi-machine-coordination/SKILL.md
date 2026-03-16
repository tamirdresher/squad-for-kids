# Skill: Cross-Machine Coordination Pattern

**Skill ID:** `cross-machine-coordination`
**Owner:** Ralph (Work Monitor)
**Squad Integration:** All agents
**Status:** Ready for adoption

---

## Overview

Enables Squad agents running on different machines (laptop, cloud DevBox, Azure VM)
to securely share work, coordinate execution, and pass results without manual
intervention.

**Pattern:** Git-based task queuing + GitHub Issues supplement

---

## Usage

### For Task Sources (any machine)

**To assign work to a remote machine:**

```bash
# Create task file
cat > .squad/cross-machine/tasks/2026-01-15T1030Z-laptop-build-tests.yaml << 'EOF'
id: build-tests-001
source_machine: {your-machine}
target_machine: {target-machine}
priority: high
created_at: 2026-01-15T10:30:00Z
task_type: gpu_workload
payload:
  command: "python scripts/run-gpu-job.py --input data.csv --output results.csv"
  expected_duration_min: 15
  resources:
    gpu: true
    memory_gb: 8
status: pending
EOF

# Commit & push
git add .squad/cross-machine/tasks/
git commit -m "Cross-machine task: GPU build-tests [squad:machine-{target-machine}]"
git push origin main
```

The watcher on `{target-machine}` will:
1. Pull the task on next cycle (configurable, default 5 min)
2. Validate schema & command whitelist
3. Execute the workload
4. Write result to `.squad/cross-machine/results/build-tests-001.yaml`
5. Commit & push the result

---

### For Task Executors (target machines)

The watcher automatically monitors `.squad/cross-machine/tasks/` for work targeted
at this machine.

**On each cycle:**

```
1. git pull origin main
2. Load all .yaml files in .squad/cross-machine/tasks/
3. Filter for status=pending AND target_machine matches this machine
4. For each matching task:
   a. Validate schema (must have: id, source_machine, target_machine, payload)
   b. Validate command against whitelist
   c. Execute task (with timeout)
   d. Write result to .squad/cross-machine/results/{id}.yaml
   e. Commit & push result
```

---

### For Urgent/Ad-Hoc Tasks

**Use GitHub Issues with `squad:machine-{name}` label:**

```bash
gh issue create \
  --title "{target-machine}: Run diagnostic check" \
  --body "Execute diagnostic on remote machine. Input: path/to/input.dat" \
  --label "squad:machine-{target-machine}" \
  --label "urgent"
```

The watcher on `{target-machine}` will:
1. Detect issue with `squad:machine-{target-machine}` label
2. Parse task from issue body
3. Execute task
4. Comment with result
5. Close issue

---

## File Formats

### Task File (YAML)

**Location:** `.squad/cross-machine/tasks/{timestamp}-{machine}-{task-id}.yaml`

**Required Fields:**
```yaml
id: {task-id}                      # Unique identifier (alphanumeric + dash)
source_machine: {hostname}         # Where task was created
target_machine: {hostname}         # Where task will execute (or ANY)
priority: high|normal|low          # Execution priority
created_at: 2026-01-15T10:30:00Z   # ISO 8601 timestamp
task_type: gpu_workload|script|command|test|build  # Category
payload:
  command: "..."                   # Shell command to execute
  expected_duration_min: 15        # Timeout (minutes)
  resources:                       # Optional resource hints
    gpu: true|false
    memory_gb: 8
    cpu_cores: 4
status: pending|executing|completed|failed
```

**Optional Fields:**
```yaml
description: "Human-readable task description"
timeout_override_min: 120          # Override default timeout
retry_count: 3                     # Max retry attempts for failed tasks
depends_on: other-task-id          # Wait for another task to complete first
```

### Result File (YAML)

**Location:** `.squad/cross-machine/results/{task-id}.yaml`

```yaml
task_id: {task-id}                     # Links back to original task
executing_machine: {hostname}          # Machine that ran the task
started_at: 2026-01-15T10:31:00Z       # Execution start
completed_at: 2026-01-15T10:45:00Z     # Execution end
status: completed|failed|timeout       # Outcome
exit_code: 0                           # Shell exit code
stdout: "..."                          # Captured standard output
stderr: "..."                          # Captured standard error
duration_seconds: 840                  # Wall-clock duration
artifacts:                             # Optional output files
  - path: "artifacts/output.csv"
    type: data
    size_mb: 2.5
```

---

## Security Model

### Validation Pipeline

All tasks go through:

1. **Schema Validation**
   - YAML structure matches spec
   - Required fields present
   - No unexpected fields (reject)

2. **Command Whitelist**
   - Only approved commands/patterns allowed
   - Path validation (no `../../` escapes)
   - Environment variable sanitization
   - No inline shell operators (`&&`, `|`, `>`) unless explicitly whitelisted

3. **Resource Limits**
   - Timeout enforced (default: 60 min, configurable)
   - Memory cap (configurable)
   - CPU threads (configurable)
   - Disk write limit (configurable)

4. **Execution Isolation**
   - Runs as unprivileged user
   - Temp directory cleaned after execution
   - Network access: restricted per policy

5. **Audit Trail**
   - All executions logged to git
   - Result stored immutably in commit history

### Threat Mitigations

| Threat | Mitigation |
|--------|-----------|
| **Malicious task injection** | Branch protection + PR review before merge to main |
| **Credential leakage** | Pre-commit secret scan + environment variable scrubbing |
| **Resource exhaustion** | Timeout + memory limits enforced per task |
| **Code injection** | Command whitelist + no shell evaluation of dynamic input |
| **Result tampering** | Git commit history provides immutable audit trail |
| **Path traversal** | Command paths validated; `../` patterns rejected |

---

## Configuration

The watcher reads configuration from `.squad/cross-machine/config.json`:

```json
{
  "enabled": true,
  "poll_interval_seconds": 300,
  "this_machine_aliases": ["{your-hostname}", "{optional-alias}"],
  "max_concurrent_tasks": 2,
  "task_timeout_minutes": 60,
  "command_whitelist_patterns": [
    "python scripts/*",
    "node scripts/*",
    "pwsh scripts/*"
  ],
  "result_ttl_days": 30
}
```

| Field | Description |
|-------|-------------|
| `enabled` | Master switch for cross-machine coordination |
| `poll_interval_seconds` | How often to check for new tasks |
| `this_machine_aliases` | Hostnames/aliases this machine responds to |
| `max_concurrent_tasks` | Max parallel task executions |
| `task_timeout_minutes` | Default timeout if task doesn't specify one |
| `command_whitelist_patterns` | Glob patterns for allowed commands |
| `result_ttl_days` | Auto-cleanup age for old results |

---

## Examples

### Example 1: GPU Workload (Laptop → Cloud DevBox)

**1. Laptop creates task:**

```yaml
# .squad/cross-machine/tasks/2026-01-15T1030Z-laptop-gpu-001.yaml
id: gpu-job-001
source_machine: my-laptop
target_machine: cloud-devbox
priority: high
created_at: 2026-01-15T10:30:00Z
task_type: gpu_workload
payload:
  command: "python scripts/run-gpu-job.py --input data.csv --output results.csv"
  expected_duration_min: 15
  resources:
    gpu: true
    memory_gb: 8
status: pending
```

**2. Laptop commits & pushes:**

```bash
git add .squad/cross-machine/tasks/
git commit -m "Task: GPU job [squad:machine-cloud-devbox]"
git push origin main
```

**3. Cloud DevBox watcher (next cycle):**

```
[Watcher Cycle]
- Pulled origin/main
- Detected: gpu-job-001 (status: pending, target: cloud-devbox)
- Validation: ✅ Schema OK, command whitelisted
- Executing: python scripts/run-gpu-job.py ...
- [15 minutes of processing]
- Completed: exit code 0
- Writing result → results/gpu-job-001.yaml
- Committing & pushing...
```

**4. Laptop reads result (next pull):**

```yaml
# .squad/cross-machine/results/gpu-job-001.yaml
task_id: gpu-job-001
executing_machine: cloud-devbox
started_at: 2026-01-15T10:35:00Z
completed_at: 2026-01-15T10:50:00Z
status: completed
exit_code: 0
stdout: "GPU job completed. Output: results.csv"
stderr: ""
duration_seconds: 900
artifacts:
  - path: "artifacts/results.csv"
    type: data
    size_mb: 2.5
```

---

### Example 2: Urgent Task via GitHub Issue

```bash
gh issue create \
  --title "cloud-devbox: Run diagnostic check" \
  --body "Check model file integrity and report status." \
  --label "squad:machine-cloud-devbox" \
  --label "urgent"
```

The watcher detects the issue, executes, comments with the result, and closes it.

---

## Error Handling

### Task Execution Failures

If a task fails (exit code != 0):

1. Result written with `status: failed` + exit code
2. stderr captured in result
3. Committed to git for audit
4. Source machine can retry by resetting task `status: pending`

### Stalled Tasks

If a task doesn't complete within timeout:

1. Process killed
2. Result written with `status: timeout`
3. Source can investigate or retry

### Network Failures

If git push/pull fails:

- Watcher retries on next cycle
- Tasks queue locally until connectivity restored
- No tasks lost (stored in local repo)

---

## Monitoring & Debugging

```bash
# Check pending tasks
ls .squad/cross-machine/tasks/
cat .squad/cross-machine/tasks/*.yaml | grep -E "^(id|status|target_machine):"

# Check results
cat .squad/cross-machine/results/{task-id}.yaml

# View execution history
git log --oneline .squad/cross-machine/ | head -20
```

---

## Integration with Ralph / Watcher

Add the watcher call to your agent's watch cycle:

```powershell
# In your watch loop
pwsh scripts/cross-machine-watcher.ps1 -ConfigPath .squad/cross-machine/config.json -GitSync
```

Or run standalone with a cron job / scheduled task:

```bash
# Every 5 minutes
*/5 * * * * cd /path/to/repo && pwsh scripts/cross-machine-watcher.ps1 -GitSync
```

---

## Future Enhancements

Potential expansions:

1. **Task Priorities** — execution order based on priority field
2. **Serial Pipelines** — Machine A → B → C task chains
3. **Resource Availability Polling** — query target machine before submitting
4. **Cost Tracking** — log resource usage per task
5. **Notification Webhooks** — alert on task completion
6. **Web Dashboard** — real-time task status visualization

---

## Questions?

Contact: Ralph (Work Monitor) or your Squad lead.
