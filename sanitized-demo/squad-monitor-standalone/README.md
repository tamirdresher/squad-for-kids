# Squad Monitor

A real-time dashboard for monitoring GitHub Copilot agent automation workflows. Built with C# and Spectre.Console, Squad Monitor provides live visibility into agent activities, GitHub issues, pull requests, and automation loops.

## Features

- **Live Agent Activity Monitoring** — Real-time parsing of GitHub Copilot CLI agent logs to show tool invocations, sub-agent spawns, and task completions
- **Automation Heartbeat** — Monitor the health and status of your automation loop (via `automation-watch.ps1`)
- **GitHub Integration** — Display open issues, active pull requests, and recently merged PRs
- **Orchestration Log** — Track agent activities over time with detailed status and outcome information
- **Dual View Modes** — Switch between full dashboard view and orchestration-only view
- **Cross-Platform** — Runs on Windows, macOS, and Linux (requires .NET 8+)

## What is Squad Monitor?

Squad Monitor is a terminal-based observability tool for teams using GitHub Copilot CLI with agent-based automation. It provides a unified dashboard that shows:

1. **Agent Activity** — What your Copilot agents are doing right now (tool calls, spawned sub-agents, task launches)
2. **Automation Loop Health** — Status of your background automation script (rounds, failures, metrics)
3. **GitHub Workflow** — Open issues, active PRs, review status, CI checks, recent merges
4. **Historical Activity** — Orchestration logs showing what agents have done and when

## Architecture

```
squad-monitor/
├── src/SquadMonitor/
│   ├── Program.cs           # Main dashboard logic
│   ├── AgentLogParser.cs    # Live agent log parsing
│   └── SquadMonitor.csproj  # Project file
├── automation-watch.ps1     # Optional: automation loop script
├── README.md                # This file
├── QUICKSTART.md            # 5-minute setup guide
└── LICENSE                  # MIT License
```

### Components

**Program.cs** — The dashboard engine. Uses Spectre.Console for rich terminal UI. Polls multiple data sources (heartbeat files, GitHub CLI, orchestration logs, agent logs) and renders a unified dashboard. Supports `--interval`, `--once`, and `--config-dir` flags.

**AgentLogParser.cs** — Tails GitHub Copilot CLI agent logs (`~/.agency/logs/session_*/process-*.log`) and extracts:
- Tool invocations (e.g., `Tool invocation result: github-search_code`)
- Sub-agent spawns (e.g., `"agent_type": "explore"`)
- Background tasks (e.g., `"name": "task"` with description)
- Agent completions

**automation-watch.ps1** — A PowerShell automation loop that:
- Runs GitHub Copilot CLI periodically (every 5 minutes by default)
- Writes heartbeat and log files to `~/.squad/`
- Integrates with GitHub (issues, PRs, labels)
- Optional webhook alerts on failures

## Installation

### Prerequisites

- **.NET 8 SDK or later** — [Download here](https://dotnet.microsoft.com/download)
- **GitHub CLI (`gh`)** — [Install here](https://cli.github.com/)
- **GitHub Copilot CLI** — [Setup instructions](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-in-the-command-line)
- (Optional) **PowerShell 7+** — For automation-watch.ps1 on non-Windows platforms

### Build from Source

```bash
# Clone the repository
git clone https://github.com/your-org/squad-monitor
cd squad-monitor

# Build the project
dotnet build src/SquadMonitor/SquadMonitor.csproj

# Run the monitor
dotnet run --project src/SquadMonitor/SquadMonitor.csproj
```

### Publish as Standalone Executable

```bash
# Windows
dotnet publish src/SquadMonitor/SquadMonitor.csproj -c Release -r win-x64 --self-contained

# macOS (Intel)
dotnet publish src/SquadMonitor/SquadMonitor.csproj -c Release -r osx-x64 --self-contained

# macOS (Apple Silicon)
dotnet publish src/SquadMonitor/SquadMonitor.csproj -c Release -r osx-arm64 --self-contained

# Linux
dotnet publish src/SquadMonitor/SquadMonitor.csproj -c Release -r linux-x64 --self-contained
```

The executable will be in `src/SquadMonitor/bin/Release/net8.0/{runtime}/publish/`.

## Configuration

Squad Monitor looks for configuration files in:
1. `~/.squad/` — Default location for heartbeat, logs, orchestration data
2. `./.squad/` — Project-local configuration (within your git repo)

You can override the config directory with `--config-dir`:

```bash
dotnet run --project src/SquadMonitor -- --config-dir ~/.my-squad
```

### Expected File Structure

```
~/.squad/
├── automation-heartbeat.json  # Written by automation-watch.ps1
├── automation-watch.log       # Log of automation rounds
└── orchestration-log/         # Agent activity logs
    └── {timestamp}-{agent}.md # Individual agent logs

~/.agency/logs/                # GitHub Copilot CLI logs
└── session_{id}/
    └── process-{pid}-{agent}.log
```

## Usage

### Basic Usage

```bash
# Run with default 5-second refresh
dotnet run --project src/SquadMonitor/SquadMonitor.csproj

# Custom refresh interval (10 seconds)
dotnet run --project src/SquadMonitor -- --interval 10

# Run once (no live refresh)
dotnet run --project src/SquadMonitor -- --once

# Custom config directory
dotnet run --project src/SquadMonitor -- --config-dir ~/.my-squad
```

### Keyboard Controls

- **`o` or `O`** — Toggle between full dashboard view and orchestration-only view
- **`Ctrl+C`** — Exit the monitor

### Dashboard Sections

#### Full Dashboard View

1. **Automation Watch Loop** — Heartbeat status, round number, last run time, consecutive failures, next round countdown
2. **Recent Automation Rounds** — Last 5 rounds with start/end times, duration, exit codes
3. **GitHub Issues** — Open issues (filtered by label, if configured)
4. **GitHub Pull Requests (Open)** — Active PRs with review status, CI status, age
5. **GitHub Pull Requests (Recently Merged)** — Last 10 merged PRs
6. **Live Agent Activity** — Most recent 10 agent actions (tool calls, spawns, tasks)
7. **Orchestration Activity** — Top 10 recent agent activities from orchestration logs

#### Orchestration-Only View

- Detailed orchestration activity with full task descriptions, outcomes, and status
- Statistics (total activities, last 24h, active agents, in-progress/completed/failed counts)
- Up to 25 most recent activities displayed

## Integration with automation-watch.ps1

The `automation-watch.ps1` script is a PowerShell automation loop that:

1. Runs GitHub Copilot CLI with a custom agent and prompt
2. Writes heartbeat and log files that Squad Monitor consumes
3. Handles git repository updates, lockfile management, log rotation
4. Sends webhook alerts on consecutive failures

### Setup automation-watch.ps1

```powershell
# 1. Customize the prompt in automation-watch.ps1 for your workflow
# 2. (Optional) Create webhook URL file for alerts
echo "https://your-webhook-url" > ~/.squad/webhook.url

# 3. Run the automation loop
.\automation-watch.ps1
```

The script will:
- Run every 5 minutes (configurable via `$intervalMinutes`)
- Write to `~/.squad/automation-heartbeat.json` (read by Squad Monitor)
- Log rounds to `~/.squad/automation-watch.log`
- Alert on 3+ consecutive failures (if webhook configured)

## How It Works with Copilot Agents

Squad Monitor is designed for workflows where GitHub Copilot CLI agents are used for automation. Here's how it fits into the ecosystem:

### Typical Workflow

1. **Automation Loop** — `automation-watch.ps1` runs periodically, invoking `gh copilot --agent {name}` with a prompt
2. **Agent Execution** — The Copilot agent spawns sub-agents, calls tools, performs GitHub operations
3. **Logging** — Agent writes logs to `~/.agency/logs/`, orchestration logs to `.squad/orchestration-log/`
4. **Monitoring** — Squad Monitor reads these logs in real-time and displays the dashboard
5. **Observability** — You see live agent activity, automation health, GitHub status, and historical logs

### Agent Log Parsing

The `AgentLogParser` class tails agent log files and extracts structured events:

- **Tool Invocations** — When an agent calls an MCP tool (e.g., `github-search_code`, `powershell`, `edit`)
- **Sub-Agent Spawns** — When an agent spawns another agent (e.g., `explore`, `task`, `general-purpose`)
- **Background Tasks** — When an agent launches a background task (e.g., "Running tests", "Building project")
- **Completions** — When an agent finishes its work

These events are displayed in the "Live Agent Activity" section, giving you real-time visibility into what your agents are doing.

## Customization

### Custom Config Directory

By default, Squad Monitor looks for `.squad/` in the current directory and `~/.squad/` in your home directory. You can override this:

```bash
dotnet run --project src/SquadMonitor -- --config-dir /path/to/custom/config
```

### Custom GitHub Filters

To filter issues by label (e.g., only show issues with `automation` label), modify the `gh issue list` command in `Program.cs`:

```csharp
var output = RunProcess("gh", "issue list --label automation --json number,title,...", teamRoot);
```

### Custom Automation Prompt

Edit `automation-watch.ps1` and modify the `$prompt` variable to customize what your agent does each round.

## Troubleshooting

### No heartbeat file found

**Cause:** `automation-watch.ps1` is not running or hasn't completed its first round.

**Fix:** Start the automation loop with `.\automation-watch.ps1` and wait for it to complete one round.

### Could not fetch issues (gh CLI unavailable)

**Cause:** GitHub CLI is not installed or not authenticated.

**Fix:** Install `gh` and run `gh auth login`.

### No agent activity showing

**Cause:** No recent GitHub Copilot CLI agent sessions, or agent logs are not in `~/.agency/logs/`.

**Fix:** Run a Copilot CLI session with an agent (e.g., `gh copilot --agent squad`) and check that logs are being written to `~/.agency/logs/session_*/`.

### Terminal too small / layout issues

**Cause:** Terminal window is too small for the dashboard layout.

**Fix:** Resize your terminal to at least 120x40 characters, or use `--once` mode for static output.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

### Development Setup

```bash
# Clone and build
git clone https://github.com/your-org/squad-monitor
cd squad-monitor
dotnet restore
dotnet build

# Run tests (if any)
dotnet test
```

## License

MIT License. See [LICENSE](LICENSE) file for details.

## Credits

Built by the Squad team. Inspired by the need for better observability in agent-based automation workflows with GitHub Copilot CLI.

## Related Projects

- [GitHub Copilot CLI](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-in-the-command-line)
- [Spectre.Console](https://spectreconsole.net/) — The terminal UI library powering Squad Monitor
- [GitHub CLI](https://cli.github.com/) — Used for GitHub integration

## Support

For issues, questions, or feature requests, please open an issue on GitHub.

