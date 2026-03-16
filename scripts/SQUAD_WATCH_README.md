# Squad Watch — Persistent Agent Loop

Cross-platform PowerShell Core script that keeps an AI coding agent working on GitHub issues even when you're away.

## Prerequisites

- **PowerShell 7+** (`pwsh`) — [Install](https://aka.ms/powershell-release?tag=stable)
- **GitHub CLI** (`gh`) — [Install](https://cli.github.com/) and run `gh auth login`

## Quick Start

```bash
# From the repo root:
pwsh scripts/squad-watch.ps1

# Dry run — list issues without processing:
pwsh scripts/squad-watch.ps1 -DryRun

# Single check cycle (useful for cron):
pwsh scripts/squad-watch.ps1 -Once

# Custom config path:
pwsh scripts/squad-watch.ps1 -ConfigPath /path/to/config.json
```

## Configuration

Edit `.squad/watch-config.json`:

| Field | Default | Description |
|---|---|---|
| `checkIntervalMinutes` | `15` | Minutes between issue checks |
| `issueLabel` | `"squad"` | GitHub label filter for issues |
| `repo` | auto-detect | `owner/repo` to monitor |
| `maxConcurrentAgents` | `1` | Max issues to process per round |
| `healthCheckUrl` | `null` | URL to ping each round (e.g., Uptime Kuma) |
| `logRetentionDays` | `7` | Days to keep log files |
| `roundTimeoutMinutes` | `30` | Max time per agent round |
| `maxConsecutiveFailures` | `5` | Failures before auto-shutdown |
| `retryBackoffBaseSeconds` | `10` | Base for exponential retry backoff |

If `repo` is empty, it auto-detects from `git remote get-url origin`.

## Files Written

| File | Purpose |
|---|---|
| `.squad/heartbeat.json` | Current status, round, PID, timestamps |
| `.squad/ralph-{MACHINE}.lock` | Multi-instance mutex (auto-cleaned) |
| `.squad/logs/watch-YYYY-MM-DD.log` | Daily activity logs |

## Multi-Instance Safety

Each machine creates a lock file at `.squad/ralph-{MACHINE}.lock`. If a lock exists and the PID is still alive, a second instance will refuse to start. Stale locks (dead PID) are auto-cleaned.

## Self-Healing

- **gh auth**: Checked on startup and every 10 rounds. Retries with exponential backoff.
- **Consecutive failures**: After `maxConsecutiveFailures` rounds fail, the script exits cleanly.
- **Log rotation**: Old logs are purged based on `logRetentionDays`.

## Extending

The `Invoke-AgentForIssue` function is the extensibility point. Replace its body with your agent invocation, e.g.:

```powershell
# Example: invoke GitHub Copilot agent
gh copilot agent run --repo $Repo --issue $($Issue.number) --prompt "Work on this issue"
```

## Stopping

Press **Ctrl+C** for graceful shutdown. The lock file and heartbeat are updated before exit.

## Running as a Scheduled Task

Use `-Once` mode with your OS scheduler:

```bash
# cron (Linux/macOS)
*/15 * * * * pwsh /path/to/scripts/squad-watch.ps1 -Once

# Task Scheduler (Windows) — trigger every 15 minutes
pwsh -NoProfile -File C:\repo\scripts\squad-watch.ps1 -Once
```

## Related

- `ralph-watch.ps1` — The original Ralph implementation (tamresearch1-specific)
- `start-all-ralphs.ps1` — Multi-repo launcher
- `.squad/schedule.json` — Full schedule configuration
