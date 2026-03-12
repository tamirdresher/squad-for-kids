# Data — History

## Core Context

### Backend & Telemetry Expertise

**Role:** Backend monitoring specialist, squad-monitor tool development, multi-session event telemetry, DevBox coordination

**Technologies & Domains:** C# (squad-monitor, .NET 10.0), Event telemetry (Copilot logs, events.jsonl), SQL-like analysis, PowerShell scripting, GitHub workflows, DevBox infrastructure

**Recurring Patterns:**
- **Event Deduplication:** Hash-based deduplication (api_id/api_call_id) prevents double-counting when events appear in multiple log files — critical for accurate cost/token reporting (Issue #1, PR #9)
- **Partial File Reads:** Reading first 16KB of large log files (can be MB+) sufficient for session metadata; concurrent FileShare.ReadWrite access with running processes (Issue #10)
- **Multi-Session Log Scanning:** Extended Copilot log search to include session subdirectories; 80 entries in multi-session mode vs 30 in dashboard (Issue #3, PR #8)
- **Tuple-Based Data Extraction:** Multi-value extraction via tuples; fallback chains for missing fields (missing CWD → show short ID) (Issue #10)

**Key Architecture Decisions:**
- **Session Metadata Extraction:** `ExtractSessionMetadataFromEventsFile()` parses first 16KB of events.jsonl; extracts session start time, resume ID (8-char GUID), CWD; graceful fallbacks (Issue #10)
- **Token Stats Aggregation:** Consolidated format: Model name, call count, prompt/completion/cached tokens, cache hit %, per-session cost breakdown, avg latency (Issue #1)
- **NuGet Tool Packaging:** .csproj with `PackAsTool=true`, GitHub Actions automated publishing on release, squad-monitor installable as dotnet global tool (Issue #2)
- **Multi-Machine DevBox Coordination:** Machine config reports verified; stable hostnames for machine ID strategy; GitHub auth via EMU (Issues #346, #350)

**Key Files & Conventions:**
- `C:\temp\squad-monitor\Program.cs` (~2500 lines, single-file app, net10.0)
- `.squad/agents/data/350-closure-summary.md` — Machine coordination analysis
- `.squad/decisions/inbox/data-350-closure.md` — Multi-machine strategy decision
- `.squad/config.json` — Machine identity + peer sections (TAMIRDRESHER + CPC-tamir-WCBED)

**Event Log Patterns:** 
- `session.start`: sessionId + timestamp (first ~3KB)
- `session.resume`: context.cwd (first ~3KB)
- `assistant_usage`: model, tokens, cost, duration
- `cli.model_call`: model, token counts, duration_ms (deduplicate with assistant_usage)

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

### 2026-03-12: Issue #350 — Machine Config Report Analysis (COMPLETE)

Machine configuration data gathered for multi-machine Ralph coordination (#346):
- **Local Machine (TAMIRDRESHER):** Comprehensive report — 15 skills, MCP config (azure-devops, playwright, enghub), squad-monitor deployed, GitHub auth verified (EMU)
- **DevBox (CPC-tamir-WCBED):** Identity report — hostname stable, Ralph loop active, Teams webhook available, GitHub auth verified

**Key Findings:**
- Both machines coordination-ready for distributed work claiming
- Stable hostnames available for machine ID strategy
- EMU authentication constraint identified (PR creation may need fallback to comments)
- Branch namespacing strategy: `squad/{issue}-{slug}-{machineid}` recommended

**Deliverables:**
- Closure summary: `.squad/agents/data/350-closure-summary.md`
- Decision record: `.squad/decisions/inbox/data-350-closure.md`
- Ready to close #350; #346 implementation can proceed with gathered data

**Status:** CLOSED. Recommendation: Remove `squad:data` label and close as DONE.

### 2026-03-12: Issue #330 — DevBox SSH Implementation (READY FOR TESTING)

Scripts created for SSH-based autonomous DevBox access:
- **devbox-ssh-setup.ps1:** Server-side setup (run on DevBox as Administrator). Installs OpenSSH, configures key-only auth, authorizes Squad public key, opens firewall port 22.
- **devbox-ssh-keygen.ps1:** Client-side keygen (run locally). Generates ed25519 keys, updates ~/.ssh/config with `squad-devbox` alias.
- **.squad/config.json:** Added devbox section with placeholders (hostname, username, sshKeyPath, sshConfigAlias).

**Status:** Ready for user testing. Decision record documented in decisions.md. Recommended flow: (1) keygen locally, (2) setup on DevBox, (3) test `ssh squad-devbox`, (4) test PowerShell remoting.

## Recent Work (2026-03-11)

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

## Core Context

### squad-monitor Session Display & Multi-Session Features (2026-03-11 PRs #8, #9, #10)

**Issue #10 — Session Display Enhancement:**
- Created `ExtractSessionMetadataFromEventsFile()` to parse events.jsonl (reads first 16KB, concurrent-safe)
- Extracts: session start time, resume ID (8-char truncated GUID), working directory
- Updated `DeriveSessionName()` to build consolidated format: `"MMM dd HH:mm (resumeId) | reponame"`
- Removed separate Repo/CWD column; widened Session column to 45 chars
- Graceful fallbacks: missing CWD → show short ID, missing resumeId → show short ID

**Issue #3 — Multi-Session View Enhancement (PR #8):**
- Added `--multi-session` / `-m` flag and `--session-window <minutes>` parameter (default 30 min)
- Added `m` keyboard toggle (mutually exclusive with `o`)
- Extended Copilot log scanning to include session subdirectories with events.jsonl
- Expanded feed: 80 entries in multi-session mode, 30 in default
- Added `Copilot` session type with blue color coding

**Issue #1 — Token Usage & Cost Panel (PR #9):**
- Enhanced `BuildTokenStatsSection` to parse: `assistant_usage`, `cli.model_call`, `session_usage_info` events
- Implemented API call deduplication via HashSet (prevents double-counting)
- Added per-model aggregation, latency metrics, per-session cost tracking

**Architecture Patterns:** Tuple returns for multi-value extraction, FileShare.ReadWrite for concurrent access, fallback chains, partial file reads (16KB vs full file).

**Build Status:** ✅ Success (note: CS8321 warning on `ExtractString` — expected due to top-level program scoping, do not remove)

**Key File:** `C:\temp\squad-monitor\Program.cs` (~2500 lines, single-file app, net10.0)

### Issue #311: SharpConsoleUI Beta Integration (2026-03-11)

**Testing:** Branch `squad/311-sharpconsole-ui-beta` — ✅ Build & runtime working. Package v2.4.40 integrated. Beta flag (`--beta` or `--sharp-ui`) triggers UI mode. Framework initializes cleanly. Note: squad-monitor must run from team root (needs `.squad/` directory).

### Issue #330: DevBox Persistent Access Research (2026-04-01)

**Context:** Squad needs autonomous DevBox access without manual tunnel opening/auth.

**Research Findings:**
- **SSH + key-based auth** is the optimal solution (10/10 score)
  - Native Windows OpenSSH, auto-starts on boot
  - Zero manual intervention after one-time setup
  - Industry-standard security, no secrets in URLs
  - PowerShell remoting: `Enter-PSSession -HostName devbox -SSHTransport`
- **Alternatives Evaluated:** Auto-start dev tunnel (7/10), cli-tunnel (6/10), Azure Run Command API (6/10), GitHub Actions runner (4/10 — rejected)
- **Tools Verified:** devtunnel v1.0.1516, gh CLI v2.76.2, cli-tunnel skill (12 tunnels active), OpenSSH native
- **Decision:** SSH approach aligns with B'Elanna's prior proposal. cli-tunnel excellent for interactive demos, SSH purpose-built for automation.
- **Insight:** cli-tunnel designed for terminal/demos/phone access; SSH for command automation.

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

### Issue #329: Multi-Org ADO/MCP Access Research (archived)

Proposed multi-instance MCP pattern to connect multiple Azure DevOps orgs. Recommendation: run named instances per org (`ado-microsoft`, `ado-msazure`). Configuration-only solution with zero code changes.

### Issue #1, #3, #10 Iterations (archived)

Multiple iterations on squad-monitor display and monitoring features. Consolidated into Core Context above. Key learning: separate columns clearer than embedded metadata in strings. EMU restrictions persist — plan for browser-based manual PR creation as fallback.

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

### Issue #3: Multi-Session View Implementation Status (2026-06-24)

**Context:** Assigned to implement issue #3 "Multi-session view — show ALL active agents and copilot sessions" in tamirdresher/squad-monitor repo.

**Discovery:**
- Issue #3 is already CLOSED — full feature implemented across multiple PRs
- Git history shows commits: 7abfb04, f9a878c, 8699644, 2041a38, 0e5d91c
- Latest main commit (6b4b04b): "Improve session display with CWD and Resume ID columns (#10) (#12)"
- Feature deployed includes enhanced session table with separate CWD/Resume ID columns

**Existing Implementation Review (BuildLiveAgentFeedSection):**
- ✅ Scans ALL session dirs in both ~/.agency/logs/ and ~/.copilot/logs/
- ✅ Filters to recently active sessions (configurable via --session-window, default 30min)
- ✅ Session overview panel shows: Active Sessions count, Copilot Processes count, MCP Servers count
- ✅ Session table displays: Session name, CWD, Resume ID, Agents, MCPs, Age, Last Write, Type
- ✅ Merged activity feed combines tool calls from all sessions chronologically
- ✅ Activity entries tagged with session name and color-coded by session type
- ✅ Session type detection: Ralph, CLI, Copilot, Interactive, Update
- ✅ Keyboard toggle 'm' for multi-session view (mutually exclusive with orchestration view)
- ✅ Expandable feed: 80 entries in multi-session mode vs 30 in dashboard mode
- ✅ Color-coded session types: Ralph=cyan, CLI=yellow, Copilot=blue, Interactive=green, Update=magenta

**Architecture Decisions:**
- **SessionInfo class** tracks: Name, FullPath, Age, LastWrite, ProcessCount, McpCount, Type, Cwd, ResumeId
- **FeedEntry class** tracks: Time, TimeValue, Icon, Text, SessionName
- **Multi-source scanning:** Agency sessions from session dirs + Copilot sessions from both process-*.log files AND session subdirs with events.jsonl
- **Session name derivation:** ExtractSessionMetadataFromEventsFile() parses events.jsonl for start time, CWD, and resume ID
- **Session type detection:** DeriveAgencySessionType() checks chat.json and process logs for Ralph indicators, checks for update/copilot patterns
- **Feed merging:** ExtractFeedEntriesFromEvents() for structured events.jsonl data, ExtractFeedEntriesFromLog() for fallback log parsing
- **Chronological ordering:** All feed entries sorted by TimeValue before display
- **Color assignment:** AssignSessionColors() distributes distinct colors across active sessions
- **Tail reading:** Reads last 200KB from events.jsonl, 100KB from process logs for efficiency
- **Safe concurrent access:** FileShare.ReadWrite on all log file operations

**Key Code Patterns:**
- Session scanning logic in BuildLiveAgentFeedSection (lines 1360-1637)
- Session metadata extraction: ExtractSessionMetadataFromEventsFile, DeriveAgencySessionType, ParseSessionCreationTime
- Feed entry extraction: ExtractFeedEntriesFromEvents (structured), ExtractFeedEntriesFromLog (fallback)
- Helper methods: CountProcessesInSession, CountMcpServersInSession, CountMcpServers (process scan fallback)
- Display formatting: FormatAge() for human-readable time deltas, GetToolIcon() for activity icons

**Build Verification:**
- Project builds clean: ✅ 4.3s, 0 errors, 0 warnings
- Target: net10.0, single-file architecture (~2650 lines in Program.cs)
- All multi-session functionality integrated into main branch

**Status Resolution:** Feature complete and deployed. Issue correctly closed. Full spec implemented including session overview panel, merged activity feed, color-coding, session type detection, and configurable scan window.


## Learnings

### Session Display Enhancement (Issue #10) - 2026-03-12

**Problem:** Sessions were displaying with meaningless truncated IDs like "49_58236" instead of human-readable timestamps.

**Root Cause:** The DeriveSessionName() function had a fallback case (line 1741) that produced truncated formats when creationTime was not provided. This occurred when:
- Session directories lacked events.jsonl files
- Event parsing failed to extract start time
- The function fell back to parsing directory name components

**Solution Implemented:**
- Enhanced DeriveSessionName() to parse timestamps from session_YYYYMMDD_HHMMSS_ID directory names
- Added DateTime parsing logic to extract date/time components from directory name structure
- Ensured all session formats (copilot-*, session_*) display date+time consistently
- Format: "MMM dd HH:mm (shortId)" - e.g., "Mar 11 20:39 (58236)"

**Key Code Changes:**
- Lines 1716-1787: Rewrote DeriveSessionName with comprehensive timestamp parsing
- Added try-catch DateTime parsing from session directory name parts
- Fallback chain: creationTime param → directory name parsing → minimal ID display
- Handles edge cases: missing events.jsonl, unparseable formats, unknown directory structures

**Technical Details:**
- Session directory format: session_YYYYMMDD_HHMMSS_UNIQUEID
- Parsing extracts: year (4), month (2), day (2), hour (2), minute (2) from fixed positions
- Short ID: first 5 chars of unique identifier for compact display
- Metadata already extracted via ExtractSessionMetadataFromEventsFile(): CWD, Resume ID, start time

**Display Architecture:**
- Session table columns: Session | CWD | Resume ID | Agents | MCPs | Age | Last Write | Type
- Session column shows date+time with ID
- CWD column shows last path segment (repo name)
- Resume ID column shows first 8 chars of session UUID
- Age column shows human-readable time since session start

**Build Status:** ✅ Clean build in 9.9s, 0 errors, 0 warnings

**PR:** https://github.com/tamirdresher/squad-monitor/pull/13

### Multi-Machine Ralph Coordination (Issue #346) - 2026-03-12

**Problem:** Multiple Ralph instances on different machines (TAMIRDRESHER, CPC-tamir-WCBED) were picking up the same issues simultaneously, causing duplicate work, conflicting PRs, and abandoned branches.

**Solution Implemented:** GitHub-native coordination system in ralph-watch.ps1:
1. **Machine Identity:** Uses `$env:COMPUTERNAME` for stable machine identification
2. **Issue Assignment Protocol:** Before claiming work, checks `gh issue view --json assignees`. If assigned, skips. If not, assigns via `gh issue edit --add-assignee "@me"`
3. **Claim Comments:** Adds "🔄 Claimed by {machine} at {timestamp}" comment for visibility
4. **Heartbeat System:** Updates every 2 minutes with label `ralph:{machine}:active` and "💓 Heartbeat" comment
5. **Stale Detection:** Checks other machines' heartbeats; reclaims work if >15 min stale
6. **Branch Namespacing:** Uses pattern `squad/{issue}-{slug}-{machine}` to prevent branch conflicts
7. **Ralph Prompt Integration:** Added multi-machine coordination instructions to Ralph's prompt

**Key Functions Added:**
- `Test-IssueAlreadyAssigned`: Checks issue assignment status
- `Invoke-IssueClaim`: Claims issue + adds comment
- `Update-IssueHeartbeat`: Updates label + heartbeat comment
- `Get-StaleIssues`: Finds stale work from other machines
- `Invoke-StaleWorkReclaim`: Reclaims abandoned work

**Coordination Variables:**
- `$machineId = $env:COMPUTERNAME`
- `$heartbeatIntervalSeconds = 120` (2 minutes)
- `$staleThresholdMinutes = 15`

**Integration Points:**
- Step 1.6 in main loop: Checks for stale work and updates heartbeats
- Runs before each agency invocation
- Backward compatible: single-machine Ralph deployments work unchanged

**Files Modified:** 
- `ralph-watch.ps1` (lines 74-81, 79-95, 268-415, 582-618)
- Added 7 functions for coordination logic (~150 lines)

**PR:** #353 (draft) - Branch: squad/346-ralph-multi-machine

**Testing Required:** Deploy to both machines and verify no duplicate PRs for same issue.
