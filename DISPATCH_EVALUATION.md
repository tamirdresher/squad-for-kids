# Dispatch Evaluation for Squad Integration

> Evaluated by: Seven (Research & Docs)  
> Date: 2025-07-14  
> Source: https://github.com/jongio/dispatch  
> Issue: tamirdresher_microsoft/tamresearch1 #963

---

## What is Dispatch?

Dispatch is a **terminal UI (TUI) for browsing, searching, and re-launching GitHub Copilot CLI sessions**. It reads the local Copilot CLI session store (a SQLite database at `~/.copilot/session-store.db`) and presents every past session in a searchable, sortable, groupable interface — with conversation previews, attention indicators, and four launch modes.

It is *not* a routing engine or a work-dispatch system in the traditional sense. The name is intentional: it "dispatches" (re-launches) Copilot sessions. It does not route tasks to agents or manage multi-agent workflows.

---

## How it Works

**Tech stack:** Go CLI, [Bubble Tea](https://github.com/charmbracelet/bubbletea) TUI framework, pure-Go SQLite driver. Cross-platform (Windows/macOS/Linux, amd64/arm64).

**Core data source:** The same SQLite session store that GitHub Copilot CLI writes to. Dispatch reads sessions, turns, checkpoints, files, and refs from this DB.

**Key capabilities:**
- **Full-text search** — two-tier: quick search on summaries/branches/repos; deep search on turns/checkpoints/files after 300ms
- **Grouping and sorting** — flat, folder, repo, branch, date; 5 sort fields
- **Attention indicators** — real-time session status dots: waiting (purple), active (green), stale (yellow), interrupted (orange ⚡), idle (gray)
- **Resume sessions** — `Enter` re-opens a session in-place, new tab, new window, or split pane
- **Multi-session open** — select multiple sessions and launch them all at once
- **Custom launch command** — `custom_command` in config replaces the Copilot CLI launch entirely, using `{sessionId}` as a placeholder
- **Workspace recovery** — detects sessions interrupted by crash or reboot
- **AI semantic search** — optional, powered by Copilot SDK

**Configuration:** JSON file per platform. Notable options: `agent`, `model`, `yoloMode`, `custom_command`, `workspace_recovery`.

---

## Relevance to Squad

| Dimension | Dispatch | Squad |
|---|---|---|
| **Purpose** | Browse + resume past Copilot sessions | Route work to specialized AI agents |
| **Routing** | None — it re-launches, doesn't route | Label-based (squad:picard, etc.), config-driven |
| **Audience** | Individual Copilot user | Multi-agent orchestration system |
| **Data source** | Local session store (SQLite) | GitHub Issues, PRs, labels |
| **Agent awareness** | Can filter by agent name in config | Full agent roster with specializations |
| **Status tracking** | Session attention indicators | Ralph watches issues/PRs |
| **Launch mechanism** | Terminal window/tab | Copilot CLI `--agent` spawn |

**Overlap:** Both tools touch the Copilot CLI session store. Squad's session database IS the same database Dispatch reads. Both care about session state, agent names, and model selection.

**What Squad does that Dispatch doesn't:**
- Multi-agent coordination with distinct specializations
- Work routing based on issue labels or work type
- Agent-to-agent communication and delegation
- GitHub Issues as the work queue

**What Dispatch does that Squad doesn't:**
- Human-friendly TUI to survey all active/past sessions
- Real-time attention indicators for which sessions need attention
- Resume interrupted sessions by workspace recovery
- Full-text search across conversation history

---

## Integration Opportunities

### 1. Operator Dashboard for Squad Sessions (High Value, Low Effort)
Install Dispatch locally and use it as a **read-only dashboard** to monitor all active Squad agent sessions. The attention indicators (waiting/active/interrupted) map naturally to agent states. Squad operators can see at a glance which agents are waiting for input, which crashed, and which are done.

```sh
dispatch  # Browse all Squad agent sessions in a single TUI
```

Filter by agent using `/` search (sessions are grouped by folder/repo/branch — Squad sessions share the `tamresearch1` directory).

### 2. Resume Crashed Agents via Dispatch
Squad's current gap: when an agent session is interrupted (crash, reboot), there's no clean recovery path. Dispatch's **workspace recovery** feature and `R` keybinding (resume all interrupted sessions) could be used by an operator to manually restart crashed agent sessions without losing context.

### 3. Custom Launch Command → Squad Agent Scoping
The `custom_command` config allows replacing the Copilot CLI launch entirely:

```json
"custom_command": "gh copilot session resume {sessionId} --agent picard"
```

This is speculative — it would require knowing session-to-agent mappings, which Dispatch doesn't currently track.

### 4. Ralph Integration (Future)
Ralph currently watches for new issues. A tighter integration idea: Ralph could query the session store (same DB Dispatch reads) to detect stale/interrupted sessions and auto-restart them, borrowing the same detection logic Dispatch uses for its attention indicators. This would not use Dispatch directly, but the same SQLite queries.

### 5. Squad Session Launcher (Developer UX)
For humans working with Squad (Tamir), Dispatch provides a much better UX than manually hunting for session IDs. Setting `agent` in Dispatch config scopes launches to a specific Squad persona:

```json
{
  "agent": "picard",
  "yoloMode": false,
  "launch_mode": "tab"
}
```

---

## Recommendation

**Use it as a developer tool. Do not integrate into Squad's routing core.**

Dispatch solves a real UX problem — *"what sessions do I have, and how do I get back to them?"* — that any heavy Copilot CLI user faces. Tamir will likely find it genuinely useful day-to-day.

However, it doesn't address Squad's architectural challenges:
- It doesn't route work to agents
- It doesn't know about Squad's agent specializations or label conventions  
- It doesn't replace Ralph or the issue-based dispatch mechanism
- It's a single-user TUI, not a coordination layer

The name is confusing — "Dispatch" sounds like it routes tasks, but it launches sessions. The overlap with Squad is **infrastructural** (shared session DB) not **architectural** (different problem domain).

**What would actually help Squad:** A lightweight dashboard that reads the session store and shows per-agent status — which is exactly what Dispatch does. So: **install it, use it, and if the custom_command or AI search features mature, revisit.**

---

## Next Steps (if applicable)

1. **Install Dispatch** on Tamir's machine as a developer tool:
   ```powershell
   irm https://raw.githubusercontent.com/jongio/dispatch/main/install.ps1 | iex
   ```

2. **Try the attention indicator view** during a Squad run to see if it gives useful session-level visibility.

3. **Track the repo** — Dispatch is v0.1.x and actively developed by Jon Gallant. If it adds multi-user or session tagging features, integration potential increases.

4. **Log findings to Squad decisions** if Dispatch is adopted as standard operator tooling — agents need to know it exists when they suggest "check active sessions."
