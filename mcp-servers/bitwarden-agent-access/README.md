# bitwarden-agent-access MCP Server

> Replaces the `bitwarden-shadow` MCP server. Uses [bitwarden/agent-access](https://github.com/bitwarden/agent-access) (`aac` CLI) instead of direct Bitwarden CLI with session tokens.

**Issue:** [#1247](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1247)  
**Replaces:** `mcp-servers/bitwarden-shadow/`

---

## Why the Switch?

| Concern | Old (`bitwarden-shadow`) | New (`bitwarden-agent-access`) |
|---------|--------------------------|-------------------------------|
| Auth model | `BW_SESSION` (vault session key) | E2E encrypted tunnel + pairing token |
| Vault access | MCP server holds session token | No vault access on agent side |
| Collection setup | Org + service accounts required | Zero setup, any Bitwarden plan |
| Secret exposure | Session key in env | No credentials in server process |
| Revocation | Unshadow item from collection | Stop `aac listen` (instant) |
| Multi-machine | Session expires/machine-bound | Pairing sessions cached in `~/.access-protocol/` |
| Bitwarden plan | Teams/Enterprise for service accts | Free plan supported |

---

## Security Model

```
Your device (trusted)          Agent (untrusted)
┌──────────────────┐           ┌──────────────────────────────────┐
│  aac listen      │◄──E2E────►│  bitwarden-agent-access MCP      │
│  (your vault)    │  tunnel   │  get_credential_info(domain=X)   │
│                  │           │  → returns: {username, hasPassword}│
│  bw CLI         │           │  NO raw password in output       │
└──────────────────┘           │                                  │
                               │  run_with_credential(domain=X,   │
                               │    command=["gh","auth","login"]) │
                               │  → credential injected as env var │
                               │  → subprocess env only, not AI   │
                               └──────────────────────────────────┘
```

The agent never holds your vault session token. Credentials are resolved on your device, tunneled E2E, and injected directly into subprocess environments (via `aac run`). The AI never sees raw secret values.

---

## Setup

### 1. Install aac CLI

**Windows:**
```powershell
.\setup-bitwarden-agent-access.ps1 -InstallOnly
```

Or manually: download [`aac-windows-x86_64.zip`](https://github.com/bitwarden/agent-access/releases/latest/download/aac-windows-x86_64.zip) and extract to a directory on your PATH.

**macOS / Linux:** see [bitwarden/agent-access README](https://github.com/bitwarden/agent-access#installation).

### 2. Install dependencies and build

```bash
cd mcp-servers/bitwarden-agent-access
npm install
npm run build
```

### 3. Configure MCP server

Add to your Copilot MCP config (`~/.copilot/mcp-config.json` or equivalent):

```json
{
  "mcpServers": {
    "bitwarden": {
      "command": "node",
      "args": ["mcp-servers/bitwarden-agent-access/dist/index.js"],
      "env": {
        "AAC_BIN": "aac"
      }
    }
  }
}
```

### 4. Pair with your vault

When the AI needs credentials, it will ask you to run:

```powershell
.\setup-bitwarden-agent-access.ps1
# OR: just run `aac listen` directly
```

The `aac listen` command displays a pairing token (e.g. `ABC-DEF-GHI`). Give that token to the AI — it uses it once to establish an encrypted session. Sessions are cached; you only need to re-pair after clearing sessions.

---

## MCP Tools

### `check_aac_available`
Verify the `aac` CLI is installed and working.

### `list_aac_sessions`
List cached pairing sessions (fingerprints only — no secrets).

### `clear_aac_sessions`
Clear stale sessions. User must re-pair after this.

### `get_credential_info`
Get credential metadata for a domain. Returns `username`, `hasPassword`, `hasTotp`, `uri`, `notes` — **never the raw password**.

```
get_credential_info(domain="github.com")
get_credential_info(domain="github.com", pairing_token="ABC-DEF-GHI")
get_credential_info(item_id="uuid-of-vault-item")
```

### `run_with_credential`
Run a command with credentials injected as environment variables. Secrets never touch AI context.

```
run_with_credential(
  domain="github.com",
  command=["gh", "auth", "login", "--with-token"],
  env_mappings={"GITHUB_TOKEN": "password"}
)

run_with_credential(
  domain="database.prod",
  command=["psql", "-h", "db.example.com"],
  env_mappings={"PGUSER": "username", "PGPASSWORD": "password"}
)
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AAC_BIN` | `aac` | Path to aac CLI binary |
| `AAC_PROXY_URL` | (aac default) | Override relay proxy URL |
| `AAC_SESSION` | — | Pre-cached session fingerprint |
| `AAC_PAIRING_TOKEN` | — | Default pairing token (for CI/headless use) |

---

## Notes

- **Early preview**: bitwarden/agent-access APIs may change. Pin to a specific aac version for stability.
- **Internet required**: Uses a relay proxy (`wss://ap.lesspassword.dev` by default) for the E2E tunnel. Override with `AAC_PROXY_URL` for a self-hosted relay.
- **`aac listen` must be running** on your device when the agent requests credentials. For unattended/CI use, pre-pair and cache sessions.
