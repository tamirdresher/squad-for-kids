# Session Recovery Prompt

Paste the following prompt into your Copilot CLI to find and list recent sessions:

```
agency copilot --yolo -p "..."
```

---

## Prompt: Find Recent Sessions

```
Find my recent Copilot CLI sessions from the last 48 hours. Use the sql tool with database session_store.

Run these queries:

1. First, find all recent sessions excluding monitoring agents:
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

3. Show the results so I can pick which session to resume with: agency copilot --resume SESSION_ID
```

---

## Prompt: Search by Topic

Replace `TOPIC_KEYWORDS` with your search terms (use OR for synonyms):

```
Search my Copilot CLI session history for a specific topic. Use the sql tool with database session_store.

Run this FTS5 search:
SELECT DISTINCT s.id, s.summary, s.cwd, s.updated_at
FROM search_index si
JOIN sessions s ON si.session_id = s.id
WHERE search_index MATCH 'TOPIC_KEYWORDS'
  AND s.updated_at >= datetime('now', '-7 days')
ORDER BY s.updated_at DESC
LIMIT 10;

Then for the top 3 results, show their checkpoints:
SELECT checkpoint_number, title, overview
FROM checkpoints
WHERE session_id = 'SESSION_ID'
ORDER BY checkpoint_number;

Format as a clean table with full session IDs for resume.
```

**Example keyword expansions:**
- Authentication: `'auth OR login OR token OR JWT OR session'`
- Deployment: `'deploy OR pipeline OR CI OR CD OR release'`
- Database: `'database OR migration OR schema OR SQL OR query'`
- Testing: `'test OR spec OR coverage OR assertion OR mock'`

---

## Prompt: Get Session Details

Replace `SESSION_ID_HERE` with the actual session ID:

```
Show me full details of a specific Copilot CLI session. Use the sql tool with database session_store.

Run these queries for session SESSION_ID_HERE:

1. Conversation turns:
SELECT turn_index, substr(user_message, 1, 200) AS ask, timestamp
FROM turns WHERE session_id = 'SESSION_ID_HERE' ORDER BY turn_index;

2. Checkpoints:
SELECT checkpoint_number, title, overview
FROM checkpoints WHERE session_id = 'SESSION_ID_HERE' ORDER BY checkpoint_number;

3. Files touched:
SELECT file_path, tool_name FROM session_files WHERE session_id = 'SESSION_ID_HERE';

4. Linked refs (PRs, commits):
SELECT ref_type, ref_value FROM session_refs WHERE session_id = 'SESSION_ID_HERE';

Summarize what this session was working on, how far it got, and whether it has unfinished work.
```
