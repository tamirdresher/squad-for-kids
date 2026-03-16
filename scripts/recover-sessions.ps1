<#
.SYNOPSIS
    Find and resume recently closed Copilot CLI sessions.

.DESCRIPTION
    Automates the workflow of finding accidentally closed Copilot CLI
    sessions and resuming them. Uses `agency copilot` with the sql
    session_store to discover recent sessions, then offers to resume
    a selected one.

.PARAMETER Hours
    How many hours back to search for sessions. Default: 24.

.PARAMETER Filter
    Optional keyword to search for in session content (e.g., "monetization",
    "aspire", "podcast"). Uses FTS5 search when provided.

.PARAMETER ExcludeRalph
    Exclude Ralph/keep-alive/heartbeat sessions from results. Default: $true.

.PARAMETER ListOnly
    Only list sessions without prompting to resume. Default: $false.

.PARAMETER WorkingDir
    Filter sessions by working directory (substring match).

.EXAMPLE
    # Find sessions from the last 24 hours, excluding Ralph
    .\scripts\recover-sessions.ps1

    # Look back 48 hours, filter for "monetization"
    .\scripts\recover-sessions.ps1 -Hours 48 -Filter "monetization"

    # Find sessions for a specific project folder
    .\scripts\recover-sessions.ps1 -WorkingDir "tamresearch1"

    # Just list, don't prompt to resume
    .\scripts\recover-sessions.ps1 -ListOnly

    # Include Ralph sessions
    .\scripts\recover-sessions.ps1 -ExcludeRalph:$false
#>
[CmdletBinding()]
param(
    [int]$Hours = 24,
    [string]$Filter = "",
    [switch]$ExcludeRalph = $true,
    [switch]$ListOnly = $false,
    [string]$WorkingDir = ""
)

$ErrorActionPreference = "Stop"

# --- Build the query prompt ---
$ralphClause = ""
if ($ExcludeRalph) {
    $ralphClause = @"
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

$cwdClause = ""
if ($WorkingDir -ne "") {
    $cwdClause = "`n  AND s.cwd LIKE '%$WorkingDir%'"
}

$filterQuery = ""
if ($Filter -ne "") {
    $filterQuery = @"

Then also run this FTS5 keyword search to find sessions by topic:
SELECT DISTINCT s.id, s.summary, s.cwd, s.updated_at
FROM search_index si
JOIN sessions s ON si.session_id = s.id
WHERE search_index MATCH '$Filter'
  AND s.updated_at >= datetime('now', '-$Hours hours')
ORDER BY s.updated_at DESC
LIMIT 10;

Highlight sessions matching "$Filter" in the output.
"@
}

$prompt = @"
I need to find recently closed Copilot CLI sessions to resume one. Use the sql tool with database: "session_store".

Query 1 - Recent sessions:
SELECT
  s.id,
  s.summary,
  s.cwd,
  s.branch,
  s.updated_at,
  (SELECT title FROM checkpoints WHERE session_id = s.id ORDER BY checkpoint_number DESC LIMIT 1) AS last_checkpoint,
  (SELECT substr(t.user_message, 1, 150) FROM turns t WHERE t.session_id = s.id AND t.turn_index = 0) AS first_ask
FROM sessions s
WHERE s.updated_at >= datetime('now', '-$Hours hours')$ralphClause$cwdClause
ORDER BY s.updated_at DESC
LIMIT 30;
$filterQuery
Present results as a numbered list grouped by working directory. For each session show:
- Number (for selection)
- Full session ID
- Summary or first ask (truncated)
- Last checkpoint title
- Last activity time
- Working directory

Format as a clean, readable table. Show the FULL session IDs so they can be copied for resume.
At the end, remind me to resume with: agency copilot --resume SESSION_ID
"@

# --- Check for agency command ---
$agencyPath = Get-Command "agency" -ErrorAction SilentlyContinue
if (-not $agencyPath) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host " 'agency' command not found in PATH" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The generated prompt is printed below." -ForegroundColor Cyan
    Write-Host "Paste it into your Copilot CLI manually:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  agency copilot --yolo -p `"<prompt>`"" -ForegroundColor Gray
    Write-Host ""
    Write-Host "--- PROMPT START ---" -ForegroundColor DarkGray
    Write-Output $prompt
    Write-Host "--- PROMPT END ---" -ForegroundColor DarkGray
    exit 0
}

# --- Run the discovery prompt ---
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Session Recovery - Searching last $Hours hours" -ForegroundColor Cyan
if ($Filter -ne "") {
    Write-Host " Filter: $Filter" -ForegroundColor Cyan
}
if ($ExcludeRalph) {
    Write-Host " Excluding: Ralph/keep-alive sessions" -ForegroundColor Cyan
}
if ($WorkingDir -ne "") {
    Write-Host " Working dir: *$WorkingDir*" -ForegroundColor Cyan
}
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Querying session history..." -ForegroundColor Gray
& agency copilot --yolo -p $prompt

if ($ListOnly) {
    exit 0
}

# --- Prompt to resume ---
Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " Ready to Resume" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
$sessionId = Read-Host "Paste the session ID to resume (or press Enter to skip)"

if ($sessionId -and $sessionId.Trim() -ne "") {
    $sessionId = $sessionId.Trim()
    Write-Host ""
    Write-Host "Resuming session: $sessionId" -ForegroundColor Cyan
    Write-Host ""
    & agency copilot --resume $sessionId
}
else {
    Write-Host "No session selected. Exiting." -ForegroundColor Gray
}
