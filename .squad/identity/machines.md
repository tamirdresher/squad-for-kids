# Squad Machine Registry

## Active Machines

### CPC-tamir-WCBED (DevBox)
- **Type:** Windows DevBox (cloud)
- **Owner:** Tamir
- **Status:** Active
- **Services Running:**
  - Production Ralph Watch (`ralph-watch.ps1`)
  - Research Ralph Watch (tamresearch1-research)
  - GitHub Actions Self-Hosted Runner (labels: `devbox`, `CPC-tamir-WCBED`, `self-hosted`, `windows`)
  - Agency Copilot `--yolo` session
- **Auto-Start:** Scheduled task `SquadAutoStart` (logon + session unlock)
- **Sleep Policy:** Disabled (`standby-timeout-ac 0`)
- **MCP Servers:** azure-devops, teams, mail, calendar, sharepoint, work-iq (built-in), github (built-in)
- **Repos:**
  - `C:\Users\tamirdresher\tamresearch1` (production)
  - `C:\Users\tamirdresher\tamresearch1-research` (research)
- **GitHub Runner Dir:** `C:\actions-runner`

## DevBox Provisioning Checklist

When setting up a new DevBox, ensure:

1. **Clone repos** — production + research
2. **gh auth login** — device code flow, scopes: `gist`, `read:org`, `read:project`, `repo`, `workflow`
3. **Teams webhook** — Save to `~/.squad/teams-webhook.url`
4. **MCP config** — Copy `~/.copilot/mcp-config.json` (azure-devops, teams, mail, calendar, sharepoint)
5. **GitHub Actions Runner** — Download to `C:\actions-runner`, configure with labels: `devbox,{hostname},self-hosted,windows`
6. **Auto-start script** — `scripts/devbox-autostart.ps1` registered as `SquadAutoStart` scheduled task
7. **Disable sleep** — `powercfg /change standby-timeout-ac 0`
8. **Start services** — Run `scripts/devbox-autostart.ps1` or start manually
