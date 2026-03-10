# Squad Activity Monitor v2

> **⚠️ NOTE**: This tool is now available as a [.NET global tool on NuGet](https://www.nuget.org/packages/squad-monitor).  
> **Recommended installation**: `dotnet tool install -g squad-monitor`  
> This local copy is for development/testing only.

A multi-panel terminal dashboard for monitoring squad activity, GitHub work queue, and Ralph watch loop health.

## Features

- 🎨 Beautiful terminal UI with Spectre.Console
- 🔄 Auto-refresh every 5 seconds (configurable)
- 📊 Color-coded status indicators (green/yellow/red)
- 🔀 **Orchestration-only view** — Press 'o' to toggle detailed orchestration activity view
- 💚 **Ralph heartbeat panel** — shows watch loop status, round count, staleness
- 📜 **Ralph log panel** — recent round summaries from `ralph-watch.log`
- 📋 **GitHub Issues panel** — open issues with `squad` label, assignees, status
- 🔀 **GitHub PRs panel** — open PRs with review status, CI rollup
- 🎯 **Orchestration log panel** — agent activity from `.squad/orchestration-log/`

## Keyboard Controls

- **Press 'o' or 'O'** — Toggle between full dashboard and orchestration-only view
- **Ctrl+C** — Exit the monitor

## Data Sources

| Panel | Source | Requirement |
|-------|--------|-------------|
| Ralph Heartbeat | `~/.squad/ralph-heartbeat.json` | ralph-watch.ps1 v7+ |
| Ralph Log | `~/.squad/ralph-watch.log` | ralph-watch.ps1 v7+ |
| GitHub Issues | `gh issue list --label squad` | `gh` CLI authenticated |
| GitHub PRs | `gh pr list` | `gh` CLI authenticated |
| Orchestration Log | `.squad/orchestration-log/*.md` | Squad orchestration |

## Usage

```bash
# Run with auto-refresh (default 5s)
dotnet run

# Custom refresh interval
dotnet run -- --interval 10

# Run once without refresh loop
dotnet run -- --once
```

## Build & Publish

```bash
# Build
dotnet build

# Publish as single-file executable
dotnet publish -c Release -r win-x64 --self-contained
```

The published executable will be at: `bin\Release\net10.0\win-x64\publish\squad-monitor.exe`

## Panels

### Ralph Watch Loop
Reads `~/.squad/ralph-heartbeat.json` (written by ralph-watch.ps1) to show:
- Running/idle/crashed status
- Current round number
- Time since last run (green <10m, yellow <30m, red >30m)
- Consecutive failure count

### Ralph Recent Rounds
Tails `~/.squad/ralph-watch.log` for the last 5 log lines, color-coded by severity (ERROR=red, WARN=yellow, SUCCESS=green).

### GitHub Issues
Runs `gh issue list --state open --label squad --json ...` to show open squad issues with labels, assignees, and last-updated age.

### GitHub Pull Requests
Runs `gh pr list --state open --json ...` to show open PRs with review decision (approved/changes/pending) and CI check rollup.

### Orchestration Log
Parses `.squad/orchestration-log/*.md` files (top 10 most recent) showing agent, status, age, task, and outcome.

**Press 'o' or 'O' to toggle orchestration-only view**, which displays:
- Detailed statistics (active agents, activities in last 24h, status breakdown)
- Up to 25 most recent activities with full details
- Expanded task descriptions and outcomes
- Agent name, timestamp, status, task, and outcome for each activity

## Requirements

- .NET 10.0 SDK
- `gh` CLI (GitHub CLI) — installed and authenticated for GitHub panels
- ralph-watch.ps1 v7+ — for heartbeat/log panels (gracefully skipped if absent)
