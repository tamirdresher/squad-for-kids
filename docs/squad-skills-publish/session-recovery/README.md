# 🔄 Session Recovery

Find and resume recently closed AI agent sessions. Prevents lost work by making session history searchable and resumable.

## What It Does

- **Search sessions** — Find past sessions by topic, working directory, or time range
- **Filter noise** — Exclude background/monitoring sessions from results
- **Inspect state** — View conversation history and checkpoint progress before resuming
- **Full-text search** — Query across all past session content using FTS5

## Trigger Phrases

- `recover session`, `find session`
- `resume session`, `lost session`
- `recent sessions`, `session history`
- `what was I working on?`

## Quick Start

### Prerequisites

- Session history stored in a queryable database (SQLite with FTS5 recommended)
- Agent platform that supports session resume (e.g., `copilot --resume {ID}`)

### Example Usage

```
User: "Find my sessions from the last 24 hours about authentication"
Agent: [Queries session_store with FTS5 MATCH 'auth OR login OR token']
Agent: "Found 3 sessions. Session abc-123 was working on JWT token refresh..."
```

## Key Features

| Feature | Description |
|---------|-------------|
| Time-window search | Find sessions from last N hours/days |
| Topic search | FTS5 full-text search with query expansion |
| Directory filter | Narrow results to a specific project path |
| Background filter | Exclude monitoring/heartbeat sessions |
| Checkpoint inspection | See what stage a session was at when it closed |

## See Also

- [Reflect](../reflect/) — Capture learnings before session closes
- [Cross-Machine Coordination](../cross-machine-coordination/) — Continue work on another machine
