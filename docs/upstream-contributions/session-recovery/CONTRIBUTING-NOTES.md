# Contributing Notes — Session Recovery

## Target Upstream

- **Repository:** bradygaster/squad
- **Branch:** dev
- **PR title:** `docs: Upstream contribution — session recovery (#675)`

## Where Files Go in Upstream

| Source (this package) | Upstream destination |
|---|---|
| `SKILL.md` | `.squad/skills/session-recovery/SKILL.md` |
| `scripts/recover-sessions.ps1` | `scripts/recover-sessions.ps1` |
| `templates/recovery-prompt.md` | `docs/session-recovery-prompts.md` or `.squad/skills/session-recovery/templates/` |
| `README.md` | Optionally link from main README or keep in skill directory |

## Compatibility Notes

### session_store Schema

The SQL queries target the standard Copilot CLI `session_store` database, which is available via the `sql` tool with `database: "session_store"`. The schema is:

- `sessions` (id, cwd, repository, branch, summary, created_at, updated_at)
- `turns` (session_id, turn_index, user_message, assistant_response, timestamp)
- `checkpoints` (session_id, checkpoint_number, title, overview, history, work_done, technical_details, important_files, next_steps)
- `session_files` (session_id, file_path, tool_name, turn_index, first_seen_at)
- `session_refs` (session_id, ref_type, ref_value, turn_index, created_at)
- `search_index` (FTS5: content, session_id, source_type, source_id)

This schema is part of the standard Copilot CLI and should not be modified.

### Ralph Filter

The monitoring agent filter excludes sessions matching `ralph`, `keep-alive`, or `heartbeat` in the first user message. This is generic — any Squad deployment using a monitoring/heartbeat agent will benefit from this filter. Deployments without such agents can disable it (`-ExcludeRalph:$false`).

### PowerShell Script

The `recover-sessions.ps1` script works on:
- **Windows:** PowerShell 5.1+ and PowerShell Core 7+
- **macOS/Linux:** PowerShell Core 7+

The script gracefully falls back to printing the prompt if `agency` is not found in PATH.

### No External Dependencies

This contribution has zero external dependencies. It only uses:
- The built-in `sql` tool (available in all Copilot CLI sessions)
- Standard PowerShell (for the convenience script)
- The `agency` CLI (optional — script prints prompt as fallback)

## Testing

To verify the skill works:

1. Open a Copilot CLI session
2. Run: `SELECT count(*) FROM sessions;` with `database: "session_store"`
3. If it returns a number > 0, the session_store is available
4. Run the "Find Recent Sessions" query from SKILL.md
5. Verify results include session IDs, summaries, and timestamps

To test the PowerShell script:

```powershell
# Should print the prompt (unless agency is in PATH)
.\scripts\recover-sessions.ps1 -ListOnly

# With keyword filter
.\scripts\recover-sessions.ps1 -Filter "test" -ListOnly
```

## Review Checklist

- [ ] SQL queries execute without errors against session_store
- [ ] No repo-specific paths or references remain
- [ ] PowerShell script handles missing `agency` gracefully
- [ ] FTS5 MATCH syntax is correct (uses OR, not AND)
- [ ] Skill frontmatter follows `.squad/skills/` conventions
