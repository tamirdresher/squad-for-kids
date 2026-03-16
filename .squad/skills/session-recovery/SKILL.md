---
name: session-recovery
description: "Find and resume recently closed Copilot CLI sessions. Use when a session was accidentally closed, or to find past sessions by topic, working directory, or time range. Triggers on: recover session, find session, resume session, lost session, closed session, recent sessions."
domain: "workflow-recovery"
confidence: "high"
source: "manual"
tools:
  - name: "sql"
    description: "Query session_store database for past session history"
    when: "Always — session_store is the source of truth for session history"
---

# Session Recovery

## When to Use

- A Copilot CLI session was accidentally closed and needs to be resumed
- You need to find a past session by topic (e.g., "monetization", "aspire", "podcast")
- You want to see what sessions ran in a specific directory recently
- You need to recover work from a session that was interrupted

## When Not to Use

- The session completed normally and work was committed
- You're looking for git history (use `git log` instead)
- The session is older than the retention period in session_store

## How It Works

Copilot CLI stores session history in a SQLite database called `session_store`. This database is read-only and contains:

| Table | Key Columns | Purpose |
|-------|-------------|---------|
| `sessions` | id, cwd, repository, branch, summary, created_at, updated_at | Session metadata |
| `turns` | session_id, turn_index, user_message, assistant_response, timestamp | Conversation history |
| `checkpoints` | session_id, checkpoint_number, title, overview | Progress snapshots |
| `session_files` | session_id, file_path, tool_name, turn_index | Files touched |
| `session_refs` | session_id, ref_type, ref_value | Linked PRs/commits/issues |
| `search_index` | content, session_id, source_type | FTS5 full-text search |

## Core Queries

### 1. Find Recent Sessions (Last 24 Hours)

```sql
SELECT
  s.id,
  s.summary,
  s.cwd,
  s.branch,
  s.updated_at,
  (SELECT title FROM checkpoints WHERE session_id = s.id ORDER BY checkpoint_number DESC LIMIT 1) AS last_checkpoint
FROM sessions s
WHERE s.updated_at >= datetime('now', '-24 hours')
ORDER BY s.updated_at DESC;
```

### 2. Filter Out Ralph Sessions

Ralph (the work monitor) creates many sessions. Exclude them:

```sql
SELECT
  s.id,
  s.summary,
  s.cwd,
  s.updated_at,
  (SELECT title FROM checkpoints WHERE session_id = s.id ORDER BY checkpoint_number DESC LIMIT 1) AS last_checkpoint
FROM sessions s
WHERE s.updated_at >= datetime('now', '-24 hours')
  AND (s.summary IS NULL OR s.summary NOT LIKE '%ralph%')
  AND s.id NOT IN (
    SELECT DISTINCT t.session_id FROM turns t
    WHERE t.turn_index = 0
      AND (t.user_message LIKE '%ralph%' OR t.user_message LIKE '%keep-alive%')
  )
ORDER BY s.updated_at DESC;
```

### 3. Search by Topic (FTS5)

Use `search_index` for keyword search. FTS5 uses `MATCH` with `OR` for synonyms:

```sql
SELECT DISTINCT s.id, s.summary, s.cwd, s.updated_at
FROM search_index si
JOIN sessions s ON si.session_id = s.id
WHERE search_index MATCH 'monetization OR monetize OR billing OR payment'
  AND s.updated_at >= datetime('now', '-48 hours')
ORDER BY s.updated_at DESC
LIMIT 10;
```

### 4. Find Sessions by Working Directory

```sql
SELECT s.id, s.summary, s.updated_at,
  (SELECT title FROM checkpoints WHERE session_id = s.id ORDER BY checkpoint_number DESC LIMIT 1) AS last_checkpoint
FROM sessions s
WHERE s.cwd LIKE '%tamresearch1%'
  AND s.updated_at >= datetime('now', '-48 hours')
ORDER BY s.updated_at DESC;
```

### 5. Get Session Details Before Resuming

```sql
-- See what the session was doing
SELECT turn_index, substr(user_message, 1, 200) AS ask, timestamp
FROM turns
WHERE session_id = 'SESSION_ID_HERE'
ORDER BY turn_index;

-- See checkpoint progress
SELECT checkpoint_number, title, overview
FROM checkpoints
WHERE session_id = 'SESSION_ID_HERE'
ORDER BY checkpoint_number;

-- See files touched
SELECT file_path, tool_name
FROM session_files
WHERE session_id = 'SESSION_ID_HERE';
```

## How to Resume a Session

Once you have the session ID:

```powershell
agency copilot --resume SESSION_ID
```

## Ready-to-Use Prompt Template

Paste this into `agency copilot --yolo -p "..."` to find and list recent non-Ralph sessions:

```
Find my recent Copilot CLI sessions from the last 48 hours. Use the sql tool with database session_store.

Run these queries:

1. First, find all recent sessions excluding Ralph:
SELECT s.id, s.summary, s.cwd, s.branch, s.updated_at,
  (SELECT title FROM checkpoints WHERE session_id = s.id ORDER BY checkpoint_number DESC LIMIT 1) AS last_checkpoint
FROM sessions s
WHERE s.updated_at >= datetime('now', '-48 hours')
  AND (s.summary IS NULL OR LOWER(s.summary) NOT LIKE '%ralph%')
  AND s.id NOT IN (
    SELECT DISTINCT t.session_id FROM turns t
    WHERE t.turn_index = 0
      AND (LOWER(t.user_message) LIKE '%ralph%' OR LOWER(t.user_message) LIKE '%keep-alive%' OR LOWER(t.user_message) LIKE '%heartbeat%')
  )
ORDER BY s.updated_at DESC
LIMIT 30;

2. Then show the FULL session IDs grouped by working directory, with summary and last checkpoint, formatted as a clean table.

3. Highlight any sessions that mention: monetization, aspire, podcast, or pending issues.

Show the results so I can pick which session to resume with: agency copilot --resume SESSION_ID
```

## Convenience Script

A PowerShell script is available at `scripts/recover-sessions.ps1` that automates the full workflow:

```powershell
# Find sessions from the last 24 hours (default), excluding Ralph
.\scripts\recover-sessions.ps1

# Look back 48 hours
.\scripts\recover-sessions.ps1 -Hours 48

# Filter by keyword
.\scripts\recover-sessions.ps1 -Filter "monetization"

# Include Ralph sessions too
.\scripts\recover-sessions.ps1 -ExcludeRalph:$false
```

## Tips

- **FTS5 query expansion**: The `search_index` table uses keyword matching, not semantic search. Search for synonyms: `'auth OR login OR token OR JWT'`
- **Time windows**: Start with `-24 hours`, expand to `-48 hours` or `-7 days` if needed
- **Session IDs are UUIDs**: Always copy the full ID for `--resume`
- **Check checkpoints first**: They show what stage the session was at when it closed
- **Multiple keywords**: Use `MATCH 'word1 OR word2'` in FTS5, or `LIKE '%word%'` for substring matching
- **Working directory matters**: Filter by `cwd` to find sessions for a specific project

## Anti-Patterns

- Don't search by partial session IDs — always use full UUIDs
- Don't try to resume sessions that completed successfully — they have no pending work
- Don't use `MATCH` with special characters without escaping — wrap in double quotes: `MATCH '"C:\path"'`
- Don't skip the Ralph filter — Ralph sessions are high-volume and will flood results
