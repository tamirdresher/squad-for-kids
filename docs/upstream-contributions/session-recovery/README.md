# Session Recovery — Find and Resume Lost Copilot CLI Sessions

## The Problem

Copilot CLI sessions get lost. You accidentally close a terminal, your machine restarts, or a session crashes mid-task. The work isn't gone — Copilot CLI stores session history in a local SQLite database (`session_store`) — but finding and resuming the right session is tedious without the right queries.

## What This Provides

A ready-to-use **session recovery skill** for Squad deployments that:

1. **Finds recent sessions** by time range, working directory, or topic keywords
2. **Filters noise** — excludes monitoring agents (Ralph, keep-alive, heartbeat sessions)
3. **Shows context** — session summaries, last checkpoints, files touched, linked PRs
4. **Enables resume** — provides the exact `--resume SESSION_ID` command

## Contents

| File | Purpose |
|------|---------|
| `SKILL.md` | Squad skill definition with all SQL queries and usage patterns |
| `scripts/recover-sessions.ps1` | PowerShell convenience script for interactive recovery |
| `templates/recovery-prompt.md` | Ready-to-paste prompt for Copilot CLI |
| `CONTRIBUTING-NOTES.md` | Upstream integration guidance |

## Quick Start

### Option 1: Use the PowerShell Script

```powershell
# Find sessions from the last 24 hours
.\scripts\recover-sessions.ps1

# Look back 48 hours, filter by keyword
.\scripts\recover-sessions.ps1 -Hours 48 -Filter "auth"

# Find sessions for a specific project
.\scripts\recover-sessions.ps1 -WorkingDir "my-project"
```

### Option 2: Use the Prompt Template

Copy the contents of `templates/recovery-prompt.md` and paste into:

```powershell
agency copilot --yolo -p "<paste prompt here>"
```

### Option 3: Use the Skill Directly

If installed as a Squad skill (`.squad/skills/session-recovery/SKILL.md`), any agent can use the SQL queries from the skill definition to search `session_store`.

## How It Works

Copilot CLI persists session history in a SQLite database accessible via the `sql` tool with `database: "session_store"`. The database contains:

- **sessions** — metadata (ID, working directory, branch, summary, timestamps)
- **turns** — full conversation history (user messages + assistant responses)
- **checkpoints** — progress snapshots taken during long tasks
- **session_files** — files created or edited during the session
- **session_refs** — linked PRs, commits, and issues
- **search_index** — FTS5 full-text search across all session content

The skill provides tested SQL queries that efficiently search this database and format results for quick identification and resume.

## Requirements

- Copilot CLI with `session_store` support (standard in current versions)
- PowerShell 5.1+ or PowerShell Core 7+ (for the convenience script)
- `agency` CLI in PATH (script falls back to printing the prompt if not found)
