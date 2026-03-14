# Decision: Squad-Monitor Feed & Token Stats Fix

**Date:** 2026-03-14
**Author:** Data (Code Expert)
**Status:** Implemented

## Context

The squad-monitor TUI dashboard had two visible bugs:
1. Live Agent Feed section was completely empty (bottom half blank)
2. Token Usage stats showed stale numbers from 2 days ago

## Root Causes

### Feed Empty — Windows directory LastWriteTime bug
The session scanning code filtered directories by `DirectoryInfo.LastWriteTime`. On Windows, this property only updates when files/directories are created or deleted directly inside the directory — NOT when existing files are modified. Active sessions with ongoing log writes appeared stale and were filtered out by the 30-minute window.

### Token Stats Stale — Missing agency log source
`BuildTokenStatsSection()` only read `~/.copilot/logs/*.log` (top-level). Active agency sessions write their `assistant_usage` and `cli.model_call` events to `~/.agency/logs/session_*/process-*.log`, which were never scanned. This caused stats to reflect only old CLI sessions.

### Bonus: Markup error
The `[ok]` icon string was interpreted as a Spectre.Console markup tag, causing an `InvalidOperationException`. Replaced with ✅ emoji.

## Decision

1. **Directory filtering:** Fall back to checking the most recent file's LastWriteTime inside each directory when the directory's own LastWriteTime falls outside the window
2. **Token source expansion:** Scan both `~/.copilot/logs/*.log` AND `~/.agency/logs/session_*/process-*.log` for usage data (up to 10 most recent agency logs)
3. **Markup safety:** Replace bracket-containing icon text with safe emoji characters

## Impact

- Token stats jumped from 107 opus/$642 → 1072 opus/$6583 (now includes agency session data)
- Feed now shows 40 entries from the active agency session
- No more markup rendering errors

## Commit

`32054a0` on `squad/10-session-display` branch, pushed to `tamirdresher/squad-monitor`
