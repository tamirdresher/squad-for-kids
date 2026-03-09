# Squad Monitor — 5-Minute Quickstart

Get Squad Monitor running in 5 minutes or less.

## Prerequisites Check

Before starting, ensure you have:

```bash
# Check .NET SDK (8.0 or later required)
dotnet --version

# Check GitHub CLI
gh --version

# Check GitHub Copilot CLI (optional for full experience)
gh copilot --version
```

If any are missing, see the [Installation](#installation) section below.

## Quick Start (3 Steps)

### 1. Clone and Build

```bash
git clone https://github.com/your-org/squad-monitor
cd squad-monitor
dotnet build src/SquadMonitor/SquadMonitor.csproj
```

### 2. Authenticate GitHub CLI

```bash
gh auth login
```

Follow the prompts to authenticate with your GitHub account.

### 3. Run the Monitor

```bash
dotnet run --project src/SquadMonitor/SquadMonitor.csproj
```

You should see a live dashboard with:
- GitHub issues and PRs (from current directory's repo)
- Automation heartbeat (if `automation-watch.ps1` is running)
- Agent activity (if Copilot agents are active)

**Press `Ctrl+C` to exit.**

## Optional: Set Up Automation Loop

To see the full observability experience with automated agent rounds:

### 1. Customize the Prompt

Edit `automation-watch.ps1` and modify the `$prompt` variable to define what your agent should do each round. Example:

```powershell
$prompt = @'
Check for open GitHub issues labeled "automation" and work on them.
If there are multiple issues, spawn agents for all of them in parallel.
'@
```

### 2. Run the Automation Loop

```powershell
.\automation-watch.ps1
```

The script will:
- Run every 5 minutes
- Write heartbeat to `~/.squad/automation-heartbeat.json`
- Log rounds to `~/.squad/automation-watch.log`

### 3. View in Squad Monitor

Open a new terminal and run Squad Monitor:

```bash
dotnet run --project src/SquadMonitor/SquadMonitor.csproj
```

You'll now see the automation loop status in the dashboard!

## Installation (If Prerequisites Missing)

### .NET 8 SDK

**Windows:**
```powershell
winget install Microsoft.DotNet.SDK.8
```

**macOS:**
```bash
brew install dotnet@8
```

**Linux (Ubuntu/Debian):**
```bash
wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
chmod +x ./dotnet-install.sh
./dotnet-install.sh --channel 8.0
```

### GitHub CLI

**Windows:**
```powershell
winget install GitHub.cli
```

**macOS:**
```bash
brew install gh
```

**Linux:**
```bash
# Debian/Ubuntu
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

### GitHub Copilot CLI

```bash
gh extension install github/gh-copilot
```

## Next Steps

### Keyboard Controls

- **`o` or `O`** — Toggle between full dashboard and orchestration-only view
- **`Ctrl+C`** — Exit

### Command-Line Options

```bash
# Custom refresh interval (10 seconds)
dotnet run --project src/SquadMonitor -- --interval 10

# Run once (no live refresh)
dotnet run --project src/SquadMonitor -- --once

# Custom config directory
dotnet run --project src/SquadMonitor -- --config-dir ~/.my-squad
```

### Publish as Standalone Executable

To create a portable executable:

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

The executable will be in `src/SquadMonitor/bin/Release/net8.0/{runtime}/publish/SquadMonitor` (or `SquadMonitor.exe` on Windows).

### Configuration Files

Squad Monitor reads from:
- `~/.squad/automation-heartbeat.json` — Automation loop status
- `~/.squad/automation-watch.log` — Automation round logs
- `~/.squad/orchestration-log/` — Agent activity logs
- `~/.agency/logs/session_*/process-*.log` — Copilot CLI agent logs

You can override `~/.squad/` with `--config-dir`:

```bash
dotnet run --project src/SquadMonitor -- --config-dir ~/.my-custom-config
```

## Troubleshooting

### "No heartbeat file found"

**Solution:** Start the automation loop with `.\automation-watch.ps1` and wait for it to complete one round.

### "Could not fetch issues"

**Solution:** Ensure GitHub CLI is authenticated with `gh auth login` and you're in a git repository directory.

### "No agent activity showing"

**Solution:** Run a GitHub Copilot CLI session with an agent (e.g., `gh copilot --agent squad`) to generate activity logs.

### Terminal layout issues

**Solution:** Resize your terminal to at least 120x40 characters, or use `--once` mode for static output.

## Full Documentation

For detailed documentation, see [README.md](README.md).

## Support

For issues or questions, open an issue on GitHub: https://github.com/your-org/squad-monitor/issues
