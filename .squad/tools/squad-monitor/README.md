# squad-monitor

**Status:** Published as .NET Global Tool  
**NuGet:** https://www.nuget.org/packages/squad-monitor  
**Source:** https://github.com/tamirdresher/squad-monitor

## Installation

```bash
dotnet tool install -g squad-monitor
```

## Usage

Run from anywhere after installation:

```bash
# Default: refresh every 5 seconds
squad-monitor

# Custom refresh interval
squad-monitor --interval 10

# Run once and exit
squad-monitor --once
```

## What It Does

Live terminal dashboard for monitoring AI agent orchestration:

- **Ralph Watch Loop** — heartbeat, round status, failure tracking
- **GitHub Integration** — issues, PRs with CI status, recently merged PRs
- **Orchestration Activity** — agent assignments and progress
- **Live Refresh** — auto-updates with flicker-free rendering
- **Dual View Mode** — press `O` to toggle orchestration-only view

## Requirements

- .NET 10 SDK
- GitHub CLI (`gh`) authenticated via `gh auth login`
- `.squad/` directory in your repo (created by Squad orchestrator)

## Updating

```bash
dotnet tool update -g squad-monitor
```

## Development

For local development or contributing, see the [source repository](https://github.com/tamirdresher/squad-monitor).
