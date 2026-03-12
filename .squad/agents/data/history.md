# Data — History

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

## Learnings

- **EMU (Enterprise Managed User) restrictions:** Persistent — always plan for manual PR creation via browser as fallback
- **events.jsonl file structure:** `session.start` contains sessionId + timestamp; `session.resume` contains context.cwd. Both appear in first ~3KB. UTF-8 encoding, one JSON object per line
- **Partial file reads:** Reading first 16KB vs full file matters for large log files (can be MB+). FileShare.ReadWrite allows concurrent access with running processes
- **Session table display:** Separate columns clearer than embedded metadata in strings. SessionInfo already populated by metadata extraction
- **CLI tool restrictions:** gh CLI EMU-blocked for direct PR creation; need browser fallback or manual process
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
