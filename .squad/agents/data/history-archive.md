# Data — History Archive

Comprehensive learnings and detailed work history. Recent activity tracked in history.md.

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

### 2026-06-25: DevBox Config Setup (#346/#350)

**Context:** Cross-machine Ralph coordination requires proper DevBox configuration. Config had placeholders, SSH keys missing, user-level MCP config absent.

**Work Done:**
1. **`.squad/config.json`** — Replaced placeholders with actual DevBox identity (CPC-tamir-WCBED), added `machineId`, `peers` section for TAMIRDRESHER local machine
2. **SSH keys** — Generated ed25519 key pair at `~/.ssh/squad-devbox-key`, created `~/.ssh/config` with `squad-devbox` host entry
3. **User-level MCP config** — Created `~/.copilot/mcp-config.json` with azure-devops MCP server (GitHub MCP is built-in to Copilot CLI)
4. **`~/.squad/teams-webhook.url`** — Created placeholder awaiting URL from local machine
5. **gh CLI auth** — Token from git credential manager lacks `read:org` scope (EMU restriction). ralph-watch.ps1 handles its own auth independently.

**Key Finding:** EMU token scopes are limited — gh CLI auth requires `read:org` which GCM tokens don't provide. Not a blocker; ralph-watch manages authentication directly.

### 2026-07-22: ClawMongo-Inspired Optimization Exploration (archived)
**Outcome:** Completed work on 2026-07-22: ClawMongo-Inspired Optimization Exploration
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-07-18: Issue #543 — Telegram Bot Configuration (archived)
**Outcome:** Completed work on 2026-07-18: Issue #543 — Telegram Bot Configuration
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-06-26: Issue #14 — Clickable Hyperlinks in TUI (archived)
**Outcome:** Completed work on 2026-06-26: Issue #14 — Clickable Hyperlinks in TUI
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-12: Issue #496 — XTTS Voice Cloning Python 3.12 Incompatibility (archived)
**Outcome:** Completed work on 2026-03-12: Issue #496 — XTTS Voice Cloning Python 3.12 Incompatibility
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-12: Issue #350 — Machine Config Report Analysis (COMPLETE) (archived)
**Outcome:** Completed work on 2026-03-12: Issue #350 — Machine Config Report Analysis (COMPLETE)
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-20: Issue #1205 — Charity Game Company Technical Architecture Study (archived)
**Outcome:** Completed work on 2026-03-20: Issue #1205 — Charity Game Company Technical Architecture Study
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-13: Issue #417 — Squad MCP Server (COMPLETE — Phase 1) (archived)
**Outcome:** Design document with full API contracts
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-13: Issue #417 — Squad MCP Server (COMPLETE — Phase 1) (archived)
**Outcome:** Completed work on 2026-03-13: Issue #417 — Squad MCP Server (COMPLETE — Phase 1)
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-13: Issue #454 — Copilot CLI v1.0.5 Feature Adoption (PLANNING) (archived)
**Outcome:** Completed work on 2026-03-13: Issue #454 — Copilot CLI v1.0.5 Feature Adoption (PLANNING)
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history
