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

