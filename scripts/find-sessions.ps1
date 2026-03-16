<#
.SYNOPSIS
    Prompt template for finding recent Copilot CLI sessions.

.DESCRIPTION
    This file contains a ready-to-use prompt that can be piped into
    `agency copilot` to query the session_store database and find
    recently closed sessions. The sql tool with session_store is only
    available inside Copilot CLI, so this generates the prompt rather
    than querying directly.

.PARAMETER Hours
    How many hours back to search. Default: 48.

.PARAMETER Filter
    Optional keyword to highlight in results (e.g., "monetization").

.PARAMETER ExcludeRalph
    Whether to exclude Ralph/keep-alive sessions. Default: $true.

.EXAMPLE
    # Print the prompt to the console
    .\scripts\find-sessions.ps1

    # Generate prompt for last 24 hours filtering for "aspire"
    .\scripts\find-sessions.ps1 -Hours 24 -Filter "aspire"

    # Pipe directly into copilot
    agency copilot --yolo -p (.\scripts\find-sessions.ps1 -Hours 24)
#>
param(
    [int]$Hours = 48,
    [string]$Filter = "",
    [switch]$ExcludeRalph = $true
)

$ralphExclusion = ""
if ($ExcludeRalph) {
    $ralphExclusion = @"

  AND (s.summary IS NULL OR LOWER(s.summary) NOT LIKE '%ralph%')
  AND s.id NOT IN (
    SELECT DISTINCT t.session_id FROM turns t
    WHERE t.turn_index = 0
      AND (LOWER(t.user_message) LIKE '%ralph%'
        OR LOWER(t.user_message) LIKE '%keep-alive%'
        OR LOWER(t.user_message) LIKE '%heartbeat%')
  )
"@
}

$filterHighlight = ""
$filterSearch = ""
if ($Filter -ne "") {
    $filterHighlight = "`n3. Specifically highlight any sessions mentioning: $Filter"
    $filterSearch = @"

Also run a targeted FTS5 search:
SELECT DISTINCT s.id, s.summary, s.cwd, s.updated_at
FROM search_index si
JOIN sessions s ON si.session_id = s.id
WHERE search_index MATCH '$Filter'
  AND s.updated_at >= datetime('now', '-$Hours hours')
ORDER BY s.updated_at DESC
LIMIT 10;
"@
}

$prompt = @"
Find my recent Copilot CLI sessions. Use the sql tool with database: "session_store".

Run this query:
SELECT
  s.id,
  s.summary,
  s.cwd,
  s.branch,
  s.updated_at,
  (SELECT title FROM checkpoints WHERE session_id = s.id ORDER BY checkpoint_number DESC LIMIT 1) AS last_checkpoint,
  (SELECT substr(t.user_message, 1, 120) FROM turns t WHERE t.session_id = s.id AND t.turn_index = 0) AS first_ask
FROM sessions s
WHERE s.updated_at >= datetime('now', '-$Hours hours')$ralphExclusion
ORDER BY s.updated_at DESC
LIMIT 30;
$filterSearch
Format results as a clean table grouped by working directory (cwd).
Show the FULL session ID for each so I can resume with: agency copilot --resume SESSION_ID$filterHighlight
"@

Write-Output $prompt
