# Skill: proxy-claude — Claude Code via GitHub Copilot License

**Category:** AI Tooling / Agent Execution  
**Status:** Available (install once, use anytime)  
**Source:** https://github.com/aep-edge-microsoft/proxy-claude  
**Assessment:** [PROXY_CLAUDE_ASSESSMENT.md](../../../PROXY_CLAUDE_ASSESSMENT.md)

---

## What This Skill Enables

Run Claude Code (Anthropic's agentic terminal CLI) using your **GitHub Copilot Business/Enterprise license** — no Anthropic API key required. proxy-claude is a local proxy that translates between the Anthropic Messages API and GitHub Copilot's OpenAI-compatible API.

Use this when you need Claude Code's full agentic capabilities (multi-file editing, terminal commands, autonomous multi-step tasks) without a separate Anthropic subscription.

---

## Setup (One-time)

```powershell
# Clone and install globally
git clone https://github.com/aep-edge-microsoft/proxy-claude.git
cd proxy-claude
npm install
npm install -g .

# First run — triggers GitHub device-code auth + model selection
proxy-claude
```

On first run:
1. Browser opens for GitHub device-code login
2. Interactive prompt to pick primary model (`claude-sonnet-4`) and fast model (`gpt-4.1-mini`)
3. Proxy starts, Claude Code launches wired to it
4. Subsequent runs start instantly (token cached at `~/.proxy-claude/github-token`)

---

## Daily Usage

```powershell
# Normal launch — starts proxy + Claude Code
proxy-claude

# Autonomous mode (no confirmation prompts) — USE CAREFULLY
proxy-claude --yolo

# Switch models
proxy-claude --reset-models

# Agency CLI wrapper (MSFT internal)
proxy-claude --agency

# Reset everything (re-auth + re-pick models)
Remove-Item ~/.proxy-claude/github-token
Remove-Item ~/.proxy-claude/server.lock
proxy-claude
```

---

## Integration with Squad / ralph-watch

The proxy exposes a health endpoint. Use this from ralph-watch or agent spawning scripts:

```powershell
function Test-ProxyClaudeHealth {
    $lockFile = "$env:USERPROFILE\.proxy-claude\server.lock"
    if (-not (Test-Path $lockFile)) { return $false }
    
    $lock = Get-Content $lockFile | ConvertFrom-Json
    try {
        $health = Invoke-RestMethod "http://127.0.0.1:$($lock.port)/"
        return $health.status -eq "ok"
    } catch { return $false }
}

function Invoke-ClaudeCodeTask {
    param([string]$Prompt, [switch]$Yolo)
    
    if (-not (Test-ProxyClaudeHealth)) {
        Write-Warning "proxy-claude not running or unhealthy — start with: proxy-claude"
        return
    }
    
    $lock = Get-Content "$env:USERPROFILE\.proxy-claude\server.lock" | ConvertFrom-Json
    $env:ANTHROPIC_BASE_URL = "http://127.0.0.1:$($lock.port)"
    $env:ANTHROPIC_AUTH_TOKEN = $lock.nonce
    
    $args = @("-p", $Prompt)
    if ($Yolo) { $args += "--dangerously-skip-permissions" }
    
    & claude @args
}
```

---

## Model Configuration

Models are configured in `~/.claude/settings.json`:

```json
{
  "env": {
    "ANTHROPIC_MODEL": "claude-sonnet-4",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4",
    "ANTHROPIC_SMALL_FAST_MODEL": "gpt-4.1-mini",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "gpt-4.1-mini"
  }
}
```

Available models via Copilot license:
| Model | Best for |
|---|---|
| `claude-sonnet-4` | Primary coding (default) |
| `claude-opus-4` | Most capable, slower |
| `gpt-4.1` | OpenAI alternative |
| `gpt-4.1-mini` | Fast/cheap slot |
| `o4-mini` | OpenAI reasoning |

---

## Key Architecture Patterns (for squad adoption)

### Singleton token sharing
Only one proxy runs at a time. Multiple Claude Code sessions share it. The lock file pattern:
```json
// ~/.proxy-claude/server.lock
{"pid": 1234, "port": 54321, "nonce": "uuid", "version": "1.x"}
```

### Health endpoint
```
GET http://127.0.0.1:<port>/
→ {"status": "ok"}           # healthy
→ {"status": "token_unhealthy"}  # token expired/broken
```

### Token resilience
- Auto-refresh at `expiry - 60s`
- 5 retries with exponential backoff (3s → 48s) on transient errors
- Handles VPN reconnect / laptop sleep/wake (`ENOTFOUND`, `ECONNRESET`, `ETIMEDOUT`)

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `proxy-claude: command not found` | `npm run build` or `npm install -g .` |
| "Proxy already running" after crash | `Remove-Item ~/.proxy-claude/server.lock` |
| 421 Misdirected Request | `Remove-Item ~/.proxy-claude/github-token && proxy-claude` |
| Token unhealthy (VPN) | Wait for auto-retry or restart proxy |

---

## When to Use This Skill

✅ **Heavy autonomous coding tasks** — let Claude Code do multi-file refactoring end-to-end  
✅ **When you need `--yolo` mode** — fully automated agent execution  
✅ **Cost-free Claude access** — using existing Copilot Enterprise seat  
⚠️ **Not for Copilot chat workflows** — this is for Claude Code CLI, not `gh copilot`  
⚠️ **Localhost only** — intentionally not network-accessible  
