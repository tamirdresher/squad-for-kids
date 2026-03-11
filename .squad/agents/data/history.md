# Data — History

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

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
