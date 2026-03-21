# Dispatch Evaluation — jongio/dispatch

**Date:** 2026-03-21  
**Author:** Seven (Research & Docs)  
**Issue:** [#963 — This look cool from Jon. Dispatch. Maybe I should use it](https://github.com/tamirdresher_microsoft/tamresearch1/issues/963)  
**Status:** ✅ Decision reached — Adopt as personal productivity tool

---

## What Is Dispatch?

[Dispatch](https://github.com/jongio/dispatch) by Jon Gallant (Microsoft) is a **terminal UI (TUI) for browsing, searching, and resuming GitHub Copilot CLI sessions**. Written in Go on [Bubble Tea](https://github.com/charmbracelet/bubbletea), it reads the local Copilot CLI SQLite session store (`~/.copilot/session-store.db`) and renders every past session in a keyboard-driven, searchable interface. It is a developer productivity tool — **not an agent framework, task router, or AI orchestration system**.

---

## Key Features

| Feature | What it does |
|---------|-------------|
| **Full-text search** | Two-tier: instant on summaries/branches/repos; deep search (300ms delay) across full turn transcripts, checkpoints, files, and git refs |
| **Attention indicators** | Real-time colored dots per session: 🟣 waiting, 🟢 active, 🟡 stale, ⚡ interrupted, ⚪ idle |
| **Grouping / pivot** | Group by flat, folder, repo, branch, or date — collapsible trees with session counts |
| **Preview pane** | Chat-style conversation bubbles, checkpoints, files touched, git refs — without opening the session |
| **Multi-select launch** | Space-select multiple sessions → `O` to open all at once in Windows Terminal tabs/panes |
| **Four launch modes** | In-place, new tab, new window, split pane (Windows Terminal) |
| **Session favorites & hiding** | Star or hide sessions; filter to favorites-only |
| **5 built-in themes** | Dispatch Dark/Light, Campbell, One Half Dark/Light; auto-inherits Windows Terminal color scheme |
| **Custom launch command** | `custom_command` config lets you replace the default launch with any command (`{sessionId}` placeholder) |
| **Self-update** | `dispatch update` upgrades in-place; background check notifies on new versions |
| **Cross-platform** | Windows, macOS, Linux — amd64 + arm64 |

---

## Dispatch vs. What Squad Already Has

| Dimension | Squad Framework | Dispatch |
|-----------|----------------|---------|
| **Purpose** | Multi-agent task orchestration | TUI browser and launcher for past sessions |
| **Problem solved** | Route async work to the right AI agent | Find, preview, and resume a past Copilot CLI session |
| **Message bus** | GitHub Issues API | None — read-only SQLite viewer |
| **Coordination** | Lead triage → agent label → agent picks up work | None — developer-facing tool only |
| **Technology** | TypeScript, GitHub CLI, MCP | Go standalone binary |
| **Runtime** | Continuous daemon (Ralph) + on-demand agents | Interactive TUI you open when needed |
| **Data source** | GitHub Issues, PRs, Projects board | Copilot CLI session store (same SQLite DB the `sql` tool queries) |
| **Agent-facing?** | Yes — agents read `.squad/` configs and issue labels | No — humans only |

**Verdict: Zero architectural overlap.** Dispatch and Squad solve completely different problems. There is nothing to integrate — Dispatch is additive.

---

## Where They Intersect

The key insight is that Squad agents *run inside* Copilot CLI sessions — and those sessions land in exactly the SQLite store Dispatch reads. Every Picard, Data, Seven, B'Elanna session creates an entry Dispatch can browse.

| Squad pain point today | How Dispatch addresses it |
|------------------------|--------------------------|
| Many concurrent agent sessions, hard to navigate | Full-text search across all sessions by keyword (e.g., `ralph`, `worf`, `#987`) |
| "Which session was working on issue #987?" | Search `987` instantly across summaries + turns |
| Multiple agents running — which needs my attention? | Attention indicator dots show 🟣 waiting vs. 🟢 active; press `n` to jump to next waiting session |
| Re-open a completed session to review work | Browse by date, folder, repo; preview conversation without opening |
| "What did Data do last Tuesday?" | Time range filters + full turn-level conversation preview |
| Ralph loop complement | Visual surface for sessions waiting on Tamir's input — same signal Ralph monitors, but in a TUI |

---

## Recommendation: ✅ Adopt as Personal Productivity Tool

**Do adopt as:** Tamir's personal terminal session manager for the growing library of Squad agent sessions.

**Do not adopt as:** A Squad architectural component — it has no place in routing, triage, or agent coordination. There is nothing to wire up.

### Rationale

1. **Zero migration cost.** Nothing in Squad changes. No `.squad/` config updates. No agent charters to revise. Installs as a standalone binary.
2. **Immediate value given Squad volume.** The squad generates many agent sessions per day across diverse domains. Dispatch makes them searchable, filterable, and resumable without hunting through terminal tabs.
3. **Attention indicators are directly Squad-relevant.** When 4+ agents run simultaneously, Dispatch shows which are waiting for input — the same signal Ralph monitors, but visible at a glance.
4. **Low risk.** Single Go binary, MIT license, authored by a Microsoftie, ships with a `--demo` mode to try safely before touching real data.
5. **Complements, doesn't replace.** Squad continues to operate exactly as designed. Dispatch is the human-facing navigation layer on top of the session history Squad produces.

### What Dispatch Does NOT Replace

- ❌ Ralph (work monitor daemon)  
- ❌ GitHub Issues as the message bus  
- ❌ Any squad agent  
- ❌ `.squad/routing.md` or label taxonomy  
- ❌ The `sql` tool's session store queries (Dispatch is a TUI; the `sql` tool is for programmatic queries)

---

## Suggested Integration Points

Even though Dispatch requires no Squad integration, two lightweight enhancements would maximize value:

### 1. Set Squad as the Default Agent

In `%APPDATA%\dispatch\config.json`:
```json
{
  "agent": "squad",
  "yoloMode": false,
  "launch_mode": "tab",
  "excluded_dirs": []
}
```

This makes `Enter` on a session launch it with `--agent squad` by default — consistent with Squad conventions.

### 2. Custom Launch Command for Squad Sessions (Optional)

If you want new sessions from Dispatch to pre-load a specific agent charter:
```json
{
  "custom_command": "gh copilot session {sessionId}"
}
```

### 3. Exclude Noisy Directories

Add audio output, dataset, and generated-file directories to `excluded_dirs` so the session list stays clean:
```json
{
  "excluded_dirs": [
    "C:\\temp\\tamresearch1\\uploads",
    "C:\\temp\\tamresearch1\\processed",
    "C:\\temp\\tamresearch1\\voice_samples"
  ]
}
```

---

## Installation

```powershell
# Install (Windows)
irm https://raw.githubusercontent.com/jongio/dispatch/main/install.ps1 | iex

# Try with synthetic data first
dispatch --demo

# Browse real sessions
dispatch
```

---

## References

- [jongio/dispatch](https://github.com/jongio/dispatch) — Source repo (MIT)
- [Issue #963](https://github.com/tamirdresher_microsoft/tamresearch1/issues/963) — Original request
- [`.squad/routing.md`](../.squad/routing.md) — Squad routing table (Seven handles docs/research)
- Prior analysis in issue #963 comments by Picard (triage) and previous Seven session
