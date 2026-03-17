# Agency Copilot — Optimal Configuration Reference

> **Last updated:** 2026-03-16 | **Agency version:** 2026.3.14.2

## TL;DR

Ralph currently runs:
```
agency copilot --yolo --autopilot --agent squad -p $prompt --resume=$sessionId
```

**Recommended change** — add `--mcp mail --mcp calendar`:
```
agency copilot --yolo --autopilot --agent squad --mcp mail --mcp calendar -p $prompt --resume=$sessionId
```

These two services are NOT in mcp-config.json and have no other way to activate.
All other needed MCPs (ADO, Teams, EngHub, Playwright, Aspire, etc.) already load from `~/.copilot/mcp-config.json`.

---

## How MCPs Load (3 sources, merged at startup)

| Source | What loads | Ralph needs to do |
|--------|-----------|-------------------|
| **Defaults** | `bluebird`, `workiq` — always on unless `--no-default-mcps` | Nothing |
| **mcp-config.json** | `~/.copilot/mcp-config.json` entries — auto-loaded | Keep file current |
| **`--mcp` flag** | Agency built-in MCPs added per-session | Add missing services here |

### Key insight
The `--mcp` flag and `mcp-config.json` are **additive**. They don't conflict.
Using `--mcp mail` is equivalent to adding mail to mcp-config.json, but the `--mcp` flag
uses Agency's built-in HTTP proxy with automatic EntraID auth — cleaner than manual config.

---

## All Available Built-in MCPs (`--mcp` flag)

| Name | Description | Requires args? | Recommended? |
|------|-------------|----------------|--------------|
| `ado` | Azure DevOps (work items, repos, PRs, pipelines) | `--org` optional (auto-detected) | ✅ Yes but we use npx version in config |
| `bluebird` | Engineering Copilot Mini | `--org`, `--project` optional | ✅ Default — always on |
| `workiq` | WorkIQ (M365 Copilot) | None | ✅ Default — always on |
| `teams` | Microsoft Teams (chats, channels, messages) | None | ✅ Already in mcp-config.json |
| `mail` | Microsoft Mail (Outlook email) | None | ⚠️ **MISSING — add via --mcp** |
| `calendar` | Microsoft Calendar | None | ⚠️ **MISSING — add via --mcp** |
| `sharepoint` | Microsoft SharePoint | None | 🔵 Optional |
| `enghub` | EngineeringHub (eng.ms docs, TSGs) | None | ✅ Already in mcp-config.json |
| `kusto` | Azure Kusto | `--service-uri` required | 🔵 Optional (needs cluster URL) |
| `icm` | ICM incidents | None | 🔵 Optional |
| `security-context` | Azure Security Context | None | 🔵 Optional |
| `es-chat` | ES Chat | None | 🔵 Optional |
| `msft-learn` | Microsoft Learn docs | None | 🔵 Optional |
| `s360-breeze` | S360 Breeze | None | 🔵 Optional |
| `cloudbuild` | CloudBuild | None | 🔵 Optional |
| `asa` | ASA | None | 🔵 Optional |

---

## Current mcp-config.json (`~/.copilot/mcp-config.json`)

These auto-load every session:

| Name | How it runs | Status |
|------|------------|--------|
| `aspire` | `aspire mcp start` | ✅ Working |
| `azure-devops` | `npx @azure-devops/mcp microsoft` | ✅ Working |
| `playwright` | `npx @playwright/mcp@latest` | ✅ Working |
| `enghub` | `enghub-mcp start` | ✅ Working |
| `teams` | `agency mcp teams` | ✅ Working |
| `nano-banana` | `npx nano-banana-mcp` | ✅ Working |

### What's NOT in mcp-config.json (and should be added or use --mcp)

| Service | Best approach |
|---------|--------------|
| `mail` | Add to mcp-config.json OR use `--mcp mail` |
| `calendar` | Add to mcp-config.json OR use `--mcp calendar` |
| `sharepoint` | Use `--mcp sharepoint` when needed |

---

## Optimal mcp-config.json

```json
{
  "mcpServers": {
    "aspire": {
      "type": "local",
      "command": "aspire",
      "args": ["mcp", "start"],
      "env": { "DOTNET_ROOT": "${DOTNET_ROOT}" },
      "tools": ["*"]
    },
    "azure-devops": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@azure-devops/mcp", "microsoft"],
      "tools": ["*"]
    },
    "playwright": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"],
      "tools": ["*"]
    },
    "enghub": {
      "type": "local",
      "command": "enghub-mcp",
      "args": ["start"],
      "tools": ["*"]
    },
    "teams": {
      "type": "local",
      "command": "agency",
      "args": ["mcp", "teams"],
      "tools": ["*"]
    },
    "mail": {
      "type": "local",
      "command": "agency",
      "args": ["mcp", "mail"],
      "tools": ["*"]
    },
    "nano-banana": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "nano-banana-mcp"],
      "env": { "GOOGLE_API_KEY": "${GOOGLE_API_KEY}" },
      "tools": ["*"]
    }
  }
}
```

---

## Ralph Command Line — Before vs After

### BEFORE (current)
```powershell
agency copilot --yolo --autopilot --agent squad -p $p --resume=$roundSessionId
```
- ❌ No mail — Ralph can't read/send email
- ❌ No calendar — Ralph can't check/create meetings
- ✅ Teams, ADO, EngHub, Aspire, Playwright all load from mcp-config.json
- ✅ Bluebird + WorkIQ load as defaults

### AFTER (recommended)
```powershell
agency copilot --yolo --autopilot --agent squad --mcp mail --mcp calendar -p $p --resume=$roundSessionId
```
- ✅ Mail active — Ralph can read email, send notifications
- ✅ Calendar active — Ralph can check schedules, create meetings
- ✅ Everything else unchanged

### Why `--mcp` instead of only mcp-config.json?
Both work. We do BOTH for belt-and-suspenders:
- `mcp-config.json` — affects ALL agency copilot sessions (interactive too)
- `--mcp` flag — ensures Ralph specifically always has these services

---

## Key Flags Reference

| Flag | Purpose | Ralph uses? |
|------|---------|-------------|
| `--yolo` | Allow all tools/paths/URLs without prompts | ✅ Yes |
| `--autopilot` | Continue automatically in prompt mode | ✅ Yes |
| `--agent <name>` | Load a named agent | ✅ `squad` |
| `-p <prompt>` | Non-interactive prompt | ✅ Yes |
| `--resume=<id>` | Resume/create session with specific ID | ✅ Yes |
| `--mcp <name>` | Add a built-in MCP server | ⬅️ **Adding** |
| `--no-default-mcps` | Skip bluebird/workiq defaults | ❌ Don't use |
| `--model <model>` | Override model | Not needed |
| `--add-dir <dir>` | Allow file access to extra dirs | Not needed (yolo covers) |
| `--allow-tool <tool>` | Allow specific tool without prompt | Not needed (yolo covers) |
| `--no-ask-user` | Disable ask_user tool | Consider for full autonomy |
| `--max-autopilot-continues <n>` | Limit continuation loops | Consider for safety |

---

## Troubleshooting

### "MCP server failed to start"
- Check if `agency mcp <name>` works standalone: `agency mcp mail`
- Verify EntraID auth: some MCPs need active Azure login
- Check `~/.agency/logs/` for detailed errors

### Duplicate MCP servers
If the same service is in BOTH mcp-config.json AND `--mcp` flag, agency may start two instances.
For services in mcp-config.json, don't also use `--mcp` for the same service.

### Which MCPs are actually loaded?
Check the agency session log in `~/.agency/logs/session_*/` — it lists all MCPs at startup.
