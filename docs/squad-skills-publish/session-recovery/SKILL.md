---
name: session-recovery
description: "Find and resume recently closed AI agent sessions. Use when a session was accidentally closed, or to find past sessions by topic, working directory, or time range."
license: MIT
metadata:
  version: 1.0.0
  adapted_from: Copilot CLI session management patterns
---

# Session Recovery

**Find and resume recently closed AI agent sessions.** Prevents lost work by making session history searchable and resumable.

Use when a session was accidentally closed, interrupted, or you need to pick up where you left off. Works with any agent platform that stores session history in a queryable database.

---

## Triggers

| Phrase | Priority |
|--------|----------|
| `recover session`, `find session` | HIGH — User lost work |
| `resume session`, `lost session` | HIGH — Immediate need |
| `recent sessions`, `session history` | MEDIUM — Browsing |
| `what was I working on?` | MEDIUM — Context recovery |

---

## Prerequisites

- Session history stored in a queryable database (SQLite, PostgreSQL, etc.)
- Access to session metadata: ID, working directory, timestamps, summary
- Access to conversation turns and/or checkpoint data
- Resume capability in the agent platform

### Expected Schema

The skill assumes a session store with these tables (adapt to your platform):

| Table | Key Columns | Purpose |
|-------|-------------|---------|
| `sessions` | id, cwd, repository, branch, summary, created_at, updated_at | Session metadata |
| `turns` | session_id, turn_index, user_message, assistant_response, timestamp | Conversation history |
| `checkpoints` | session_id, checkpoint_number, title, overview | Progress snapshots |
| `session_files` | session_id, file_path, tool_name, turn_index | Files touched |
| `session_refs` | session_id, ref_type, ref_value | Linked PRs/commits/issues |
| `search_index` | content, session_id, source_type | Full-text search (FTS5) |

---

## Core Queries

### 1. Find Recent Sessions (Last 24 Hours)

```sql
SELECT
  s.id,
  s.summary,
  s.cwd,
  s.branch,
  s.updated_at,
  (SELECT title FROM checkpoints WHERE session_id = s.id
   ORDER BY checkpoint_number DESC LIMIT 1) AS last_checkpoint
FROM sessions s
WHERE s.updated_at >= datetime('now', '-24 hours')
ORDER BY s.updated_at DESC;
```

### 2. Filter Out Background/Monitoring Sessions

Background agents (monitoring loops, heartbeats) create high-volume sessions. Exclude them:

```sql
SELECT s.id, s.summary, s.cwd, s.updated_at,
  (SELECT title FROM checkpoints WHERE session_id = s.id
   ORDER BY checkpoint_number DESC LIMIT 1) AS last_checkpoint
FROM sessions s
WHERE s.updated_at >= datetime('now', '-24 hours')
  AND s.id NOT IN (
    SELECT DISTINCT t.session_id FROM turns t
    WHERE t.turn_index = 0
      AND (
        LOWER(t.user_message) LIKE '%keep-alive%'
        OR LOWER(t.user_message) LIKE '%heartbeat%'
        OR LOWER(t.user_message) LIKE '%monitor%'
      )
  )
ORDER BY s.updated_at DESC;
```

**Customize the filter** by adding your own background agent keywords to the exclusion list.

### 3. Search by Topic (Full-Text Search)

Use FTS5 `MATCH` with `OR` for synonyms — session stores use keyword matching, not semantic search:

```sql
SELECT DISTINCT s.id, s.summary, s.cwd, s.updated_at
FROM search_index si
JOIN sessions s ON si.session_id = s.id
WHERE search_index MATCH 'authentication OR auth OR login OR token OR JWT'
  AND s.updated_at >= datetime('now', '-48 hours')
ORDER BY s.updated_at DESC
LIMIT 10;
```

**Query expansion matters.** Always search for synonyms and related terms.

### 4. Find Sessions by Working Directory

```sql
SELECT s.id, s.summary, s.updated_at,
  (SELECT title FROM checkpoints WHERE session_id = s.id
   ORDER BY checkpoint_number DESC LIMIT 1) AS last_checkpoint
FROM sessions s
WHERE s.cwd LIKE '%my-project%'
  AND s.updated_at >= datetime('now', '-48 hours')
ORDER BY s.updated_at DESC;
```

### 5. Get Session Details Before Resuming

```sql
-- Conversation history
SELECT turn_index, substr(user_message, 1, 200) AS ask, timestamp
FROM turns
WHERE session_id = '{SESSION_ID}'
ORDER BY turn_index;

-- Checkpoint progress
SELECT checkpoint_number, title, overview
FROM checkpoints
WHERE session_id = '{SESSION_ID}'
ORDER BY checkpoint_number;

-- Files touched
SELECT file_path, tool_name
FROM session_files
WHERE session_id = '{SESSION_ID}';
```

---

## How to Resume

Once you have the session ID, use your platform's resume command:

```bash
# GitHub Copilot CLI
copilot --resume {SESSION_ID}

# Or platform-specific equivalent
agent resume --session {SESSION_ID}
```

---

## Tips

- **Start with 24 hours**, expand to 48h or 7 days if needed
- **FTS5 query expansion**: Search synonyms — `'auth OR login OR token OR JWT'`
- **Session IDs are UUIDs**: Copy the full ID for resume
- **Check checkpoints first**: They show what stage the session was at
- **Filter by `cwd`** to narrow to a specific project

## Anti-Patterns

- Don't search by partial session IDs — always use full UUIDs
- Don't resume completed sessions — they have no pending work
- Don't use `MATCH` with special characters without quoting — wrap paths in double quotes
- Don't skip the background-session filter — monitoring sessions flood results

---

## See Also

- [Reflect](../reflect/) — Capture learnings before session closes
- [Cross-Machine Coordination](../cross-machine-coordination/) — Continue work on another machine
