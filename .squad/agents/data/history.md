# Data — History

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

### 2026-03-11 Completion: squad-monitor Issue #10 — Session Display Enhancement

**Context:** Session display showed truncated IDs like "49_58236" which lacked context. Users needed to see session start time, working directory/repo name, and Copilot resume ID for meaningful session identification.

**Implementation:**
- Created `ExtractSessionMetadataFromEventsFile()` to parse events.jsonl files:
  - Extracts session start time from `session.start` event timestamp
  - Extracts resume ID from `session.start` sessionId field (first 8 chars of GUID)
  - Extracts working directory from `session.resume` context.cwd field
- Updated `DeriveSessionName()` to accept and integrate metadata into session display name
- Removed separate Repo/CWD column from session table
- Widened Session column to 45 chars to accommodate rich format
- Applied to both Agency and Copilot session scanning paths

**Display Format:**
- Agency sessions: `Ralph-Mar 11 20:39 (30380cd9) | tamresearch1`
- Copilot sessions: `Copilot-shortId | reponame` or `Copilot-Mar 11 20:39 (resumeId) | reponame`

**Architecture Decisions:**
- Resume ID truncated to 8 chars for display density (full GUID too long)
- Session start time from events.jsonl preferred over directory name parsing
- CWD extracted as last path segment only (repo name, not full path)
- Metadata extraction reads first 16KB of events.jsonl (increased from 8KB)
- Handles missing metadata gracefully with fallbacks

**Key File Paths:**
- `C:\temp\squad-monitor\Program.cs` — ~2500 lines, single-file app
- Branch: `squad/10-session-display`
- Build: ✅ Success (0 warnings)

TBD - Q2 work incoming

### 2026-03-11 Completion: squad-monitor Issues #1 & #3

**Context:** Two squad-monitor enhancements deployed this round.

**Issue #1 — Token Usage Panel (PR #9):**
- Enhanced token panel with latency metrics, per-session cost breakdown
- Implemented event deduplication via API call ID to prevent double-counting
- `assistant_usage` + `cli.model_call` events deduplicated using HashSet lookups

**Issue #3 — Multi-Session View (PR #8):**
- Added `--multi-session` / `-m` flag for session-focused monitoring
- Configurable session window: `--session-window <minutes>` (default 30)
- Keyboard toggle `m` for view switching (mutually exclusive with `o`)
- Expanded feed: 80 entries in multi-session mode vs 30 in dashboard

**Status:** Both PRs merged. Decisions documented and deduplicated in decisions.md.

## Learnings

### Issue #10: Session Display Enhancement (2026-03-11)

**Context:** squad-monitor issue #10 required showing full session context instead of truncated IDs. Sessions needed to display date/time, working directory/repo name, and Copilot resume ID.

**events.jsonl Structure:**
- `session.start` event contains `sessionId` (full GUID) and `timestamp`
- `session.resume` event contains `context.cwd`, `context.repository`, `context.branch`
- Both events appear in first ~2-3KB of file
- Files use UTF-8 encoding with one JSON object per line

**Implementation Approach:**
1. Created `ExtractSessionMetadataFromEventsFile()` returning tuple `(Cwd, ResumeId, StartTime)`
2. Reads first 16KB of events.jsonl with FileShare.ReadWrite (concurrent access safe)
3. Uses regex patterns via `ExtractString()` helper for targeted extraction
4. Resume ID truncated to first 8 chars (e.g., "30380cd9" from full GUID)
5. Start time parsed with DateTimeStyles.RoundtripKind and converted to local time
6. CWD extracted as last path segment for display density

**DeriveSessionName() Enhancement:**
- Old signature: `(string dirOrFileName, DateTime? creationTime = null)`
- New signature: `(string dirOrFileName, DateTime? creationTime = null, string cwd = "", string resumeId = "")`
- Builds format: `"MMM dd HH:mm (resumeId) | reponame"` with fallbacks for missing parts
- Copilot sessions: `"shortId | reponame"` (simpler format)
- Graceful degradation: missing CWD → show short ID, missing resumeId → show short ID

**Session Table Layout Change:**
- Removed separate "Repo/CWD" column (18 chars)
- Widened "Session" column from 25 to 45 chars
- All metadata now in single consolidated display name
- Cleaner visual presentation, less column scanning

**Key Patterns:**
- Tuple returns for multi-value extraction functions
- FileShare.ReadWrite for safe concurrent log file access
- Fallback chains: events.jsonl → directory name parsing → directory timestamps
- Partial read optimization: 16KB vs full file (some events.jsonl files are MB+)

**Testing Notes:**
- Build: ✅ clean (0 warnings after removing unused ExtractCwdFromEventsFile)
- EMU restriction prevents PR creation via gh CLI (must use browser)
- Branch pushed successfully to origin

### Issue #3: Multi-Session View Enhancement (2026-03-11)

**Context:** squad-monitor needed a dedicated multi-session monitoring mode. The existing code already scanned multiple sessions but lacked a focused view and used a hardcoded 4-hour scan window.

**Changes Made (PR #8):**
- Added `--multi-session` / `-m` flag for focused session-only view
- Added `--session-window <minutes>` parameter (default 30 min per issue spec)
- Added `m` keyboard toggle in live mode (mutually exclusive with `o`)
- Extended copilot log scanning to include session subdirectories with `events.jsonl`
- Expanded feed limit: 80 entries in multi-session mode, 30 in default dashboard
- Added `Copilot` session type with blue color coding

**Architecture Decisions:**
- `BuildMultiSessionContent` delegates to `BuildLiveAgentFeedSection` with `expandedFeed: true` — avoids duplication
- Session window parameter flows through all scan methods via `sessionWindowMinutes` parameter
- Keyboard toggles are mutually exclusive: pressing `m` disables `o` and vice versa
- Copilot session dirs scanned separately from CLI process-*.log files to avoid double-counting

**Key File Paths:**
- `C:\temp\squad-monitor\Program.cs` — single-file application, ~2500 lines
- `C:\temp\squad-monitor\SharpUI.cs` — SharpConsoleUI beta prototype (placeholder)
- Build: `cd C:\temp\squad-monitor && dotnet build`
- Target: net10.0, LangVersion 13.0

**Pre-existing Warning:** CS8321 on `ExtractString` — it IS used but compiler flags it due to top-level program static function scoping. Do not remove.

### Issue #330: DevBox Persistent Access Research (2026-04-01)

**Context:** Squad needs autonomous DevBox access without manual tunnel opening/auth.

**Research Findings:**
- **SSH + key-based auth** is the optimal solution (10/10 score)
  - Native Windows OpenSSH, auto-starts on boot
  - Zero manual intervention after one-time setup
  - Industry-standard security, no secrets in URLs
  - PowerShell remoting works natively: `Enter-PSSession -HostName devbox -SSHTransport`

**Alternatives Evaluated:**
1. Auto-start dev tunnel (7/10) — doesn't solve cookie auth problem
2. cli-tunnel (6/10) — better for monitoring/demos, not automation
3. Azure Run Command API (6/10) — adds unnecessary API complexity
4. GitHub Actions self-hosted runner (4/10) — security risk, rejected

**Tools Verified:**
- devtunnel CLI v1.0.1516 (installed, logged in)
- gh CLI v2.76.2 (installed)
- cli-tunnel skill (12 active tunnels, good for monitoring use case)
- OpenSSH native capability (needs enabling on DevBox)

**Decision:** Recommend SSH approach (aligns with B'Elanna's prior proposal in `.squad/decisions/inbox/belanna-devbox-access.md`)

**Deliverables:**
- Research document: `.squad/decisions/inbox/data-devbox-tunnel.md`
- Issue comment: #330 with full analysis and implementation plan

**Key Insight:** cli-tunnel is excellent for its designed purpose (interactive terminal, demos, recording, phone access), but SSH is purpose-built for remote command automation.

### Issue #311: SharpConsoleUI Beta Testing (2026-03-11)

**Context:** Test SharpConsoleUI v2.4.40 integration in squad-monitor beta branch.

**Test Results:**
- **Branch:** `squad/311-sharpconsole-ui-beta` (tamirdresher/squad-monitor)
- **Build:** ✅ Success (1 minor warning: unused local function)
- **Runtime:** ✅ Working correctly with `--beta` flag
- **Package:** SharpConsoleUI v2.4.40 integrated successfully

**Runtime Behavior:**
- Displays beta mode splash screen with framework info
- Shows version confirmation (2.4.40)
- Lists planned features: multi-window compositor, agent status panel, session log panel, decisions panel
- Clean exit with any key press

**Key Insights:**
- squad-monitor requires `.squad` directory (must run from team root)
- Beta flag (`--beta` or `--sharp-ui`) triggers SharpConsoleUI mode
- Framework initializes cleanly, proof-of-concept working as intended

**Deliverables:**
- Test results comment on issue #311
- Verified build and runtime functionality

### Issue #1: Token Usage, Cost, and Model Stats Panel (2026-06-18)

**Context:** Enhance squad-monitor dashboard with comprehensive token/cost/model telemetry from `~/.copilot/logs/`.

**Implementation:**
- Enhanced `BuildTokenStatsSection` in `Program.cs` to parse three event types:
  - `assistant_usage` — model, input/output/cached tokens, cost, duration
  - `cli.model_call` — model, prompt/completion/cached tokens, duration_ms
  - `session_usage_info` — token_limit, current_tokens (context window)
- Deduplicated events via `api_id` / `api_call_id` to prevent double-counting
- Added `ModelCallStats` class for richer per-model aggregation
- Added Avg Latency column (from duration_ms) and per-session cost tracking

**Key Insights:**
- `assistant_usage` and `cli.model_call` events often report the same API call — deduplicate via api_id
- `cli.model_call` uses `prompt_tokens_count`/`completion_tokens_count`; `assistant_usage` uses `input_tokens`/`output_tokens`
- Cost data only appears in `assistant_usage` events, not `cli.model_call`
- Log files opened with `FileShare.ReadWrite` to avoid conflicts with running Copilot processes
- Target framework: net10.0, LangVersion 13.0

**Deliverables:**
- Branch: `squad/1-token-usage-panel` (tamirdresher/squad-monitor)
- Build: ✅ Success (dotnet build clean)
- PR creation blocked by EMU restrictions — branch pushed for manual PR

### Issue #10: Session Display — Rebase and PR Attempt (2026-06-18)

**Context:** Revisited issue #10 branch to finalize. Branch existed with implementation complete but no PR was created (EMU restriction).

**Actions Taken:**
- Fetched latest `origin/main` — main had advanced with icon legend and token usage panel merges
- Rebased `squad/10-session-display` onto latest `origin/main` (b5f0dc4) — clean rebase, one cherry-pick skip (token panel already merged)
- Build verified: ✅ clean (0 warnings)
- Force-pushed rebased branch to origin
- PR creation via `gh pr create` again blocked by EMU restriction
- Branch is at `cfe2a06`, ready for manual PR at: https://github.com/tamirdresher/squad-monitor/compare/main...squad/10-session-display

**Key Learning:** EMU (Enterprise Managed User) restrictions are persistent — always plan for manual PR creation via browser as fallback.

### Issue #329: Multi-Org ADO/MCP Access Research (2026-06-24)

**Context:** Squad can't access repos in different Azure DevOps orgs. The `@azure-devops/mcp` package takes org name as a startup argument and cannot switch at runtime. Current setup has `microsoft` in global config and `msazure` in repo config, but global overrides repo.

**Research Findings:**
- `@azure-devops/mcp` is single-org by design: `npx @azure-devops/mcp <org-name>`
- Global config (`~/.copilot/mcp-config.json`): connected to `microsoft`
- Repo config (`.copilot/mcp-config.json`): connected to `msazure`
- Global instance takes precedence, so `msazure` repos are unreachable
- Decision 14 (B'Elanna, 2026-03-11) already approved multi-instance pattern but Phase 2 validation was never completed

**Three Approaches Evaluated:**
1. **Multi-Instance MCP (Recommended):** Run separate named instances per org (`ado-microsoft`, `ado-msazure`). Config-only, zero code changes, scales to N orgs.
2. **Proxy/Router:** Custom middleware dispatching to correct org. Over-engineered, single point of failure.
3. **Dynamic Switching:** Restart MCP with different org. Impractical, disrupts active sessions.

**Deliverables:**
- Technical proposal with architecture diagram posted as comment on issue #329
- Label `status:pending-user` added — waiting for Tamir to confirm approach and org list
- Project board updated to "Pending User"

**Key Insight:** The solution is purely configuration. Each MCP server instance gets a unique name prefix (e.g., `ado-microsoft`, `ado-msazure`), and tools are automatically namespaced by MCP. Adding a new org = 5 lines of JSON config.

### Issue #10: Session Display Enhancement - Separate Columns (2026-06-24)

**Context:** Revisited issue #10 with new approach. Previous implementation embedded CWD and Resume ID in session name string. New approach uses dedicated table columns for better scanability.

**Implementation Changes:**
- Modified session table to add **CWD** and **Resume ID** columns
- Session column width reduced from 45 to 25 chars (cleaner names)
- CWD column: 20 chars width, yellow color for visibility
- Resume ID column: 10 chars width, cyan color
- Total columns: 8 (Session, CWD, Resume ID, Agents, MCPs, Age, Last Write, Type)

**DeriveSessionName() Simplification:**
- Removed embedded CWD/Resume ID logic from session name string
- Session name now shows only: `"MMM dd HH:mm (shortId)"` for Agency/Copilot sessions
- Copilot sessions: just `shortId` without metadata
- CWD and Resume ID now populated directly from SessionInfo.Cwd and SessionInfo.ResumeId properties

**Table Rendering Changes:**
- SessionInfo class already had Cwd and ResumeId properties (from previous work)
- Updated sessionTable.AddRow() to include `session.Cwd` and `session.ResumeId` columns
- Removed string manipulation to extract metadata from Name field

**Build & Deploy:**
- Branch: `squad/10-session-display-improvements` (new branch name)
- Build: ✅ Success (23.8s, 0 warnings)
- PR: #12 created and linked to issue #10
- Comment added to issue

**Key Learning:** Separate columns are clearer than embedded metadata in strings. SessionInfo already had the properties populated by ExtractSessionMetadataFromEventsFile() from previous work, so this was a pure display layer change.

### Issue #1: Token Usage Panel Status Check (2026-06-24)

**Context:** Assigned to implement issue #1 "Token usage, cost, and model stats panel" in squad-monitor repo. Task instructions indicated creating new feature implementation.

**Discovery:**
- Issue #1 was already CLOSED — feature implemented in commit 1b68db8 (PR #9)
- Commit message: "feat: enhance token usage panel with cli.model_call parsing, latency stats, and per-session costs (#1) (#9)"
- Git history shows feature deployed 2 days ago along with issue #3 multi-session view
- Issue comment notes: "Moved to tamirdresher_microsoft/tamresearch1 — that's where our dev team works. This repo is code-only."

**Existing Implementation Review (BuildTokenStatsSection):**
- ✅ Parses all three event types: `assistant_usage`, `cli.model_call`, `session_usage_info`
- ✅ Tracks model name, calls count, prompt/completion/cached tokens
- ✅ Calculates cache hit % with color-coding (green >50%, yellow >20%, dim otherwise)
- ✅ Computes per-session cost breakdown (average + max displayed)
- ✅ Shows premium request count (Opus model filter)
- ✅ Displays context window usage % from session_usage_info
- ✅ Deduplicated via api_id HashSet to prevent double-counting
- ✅ Formats token counts with K/M suffixes (FormatTokenCount)
- ✅ Displays avg latency from duration_ms with color thresholds

**Key Code Patterns:**
- Uses `ModelCallStats` class for per-model aggregation (Calls, PromptTokens, CompletionTokens, CachedTokens, TotalCost, DurationsMs)
- `ReadAheadBlock()` reads multi-line JSON blocks from log stream (up to 80 lines or closing brace)
- `ExtractLong()`, `ExtractDouble()`, `ExtractString()` helpers use regex for field extraction
- Log files opened with `FileShare.ReadWrite` for safe concurrent access
- Scans 5 most recent log files from ~/.copilot/logs/
- Summary line shows totals with color-coded thresholds

**Build Verification:**
- Project builds clean: ✅ 1.2s, 0 errors, 0 warnings
- Target: net10.0, single-file architecture (~2500 lines in Program.cs)

**Status Resolution:** Feature complete and deployed. No work needed. Issue correctly marked as closed in GitHub.
