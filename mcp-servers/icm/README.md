# ICM MCP Server

MCP server for [ICM (Incident Management)](https://icm.ad.msft.net) — search, view, and update incidents from AI assistants.

## Tools

| Tool | Description |
|---|---|
| `icm_get_incident` | Get details of a specific incident by ID |
| `icm_search_incidents` | Search incidents with OData filters (severity, status, team, etc.) |
| `icm_get_timeline` | Get timeline entries for an incident |
| `icm_list_recent` | List recent incidents for a team/service |
| `icm_get_mitigation` | Get mitigation details for an incident |
| `icm_update_incident` | Update incident fields (status, severity, notes) |
| `icm_add_timeline_entry` | Add a note/entry to an incident timeline |

## Prerequisites

- **Node.js** ≥ 18
- **Azure AD credentials** — the server uses `DefaultAzureCredential` from `@azure/identity`, so any of the following work:
  - `az login` (Azure CLI)
  - Managed Identity (when running in Azure)
  - Environment variables (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_CLIENT_SECRET`)

## Setup

```bash
cd mcp-servers/icm
npm install
npm run build
```

## Usage

### Stdio (default)

```bash
npm start
# or
node dist/index.js
```

### Development

```bash
npm run dev
```

### Copilot MCP config

Add to `.copilot/mcp-config.json`:

```json
{
  "mcpServers": {
    "icm": {
      "command": "node",
      "args": ["mcp-servers/icm/dist/index.js"]
    }
  }
}
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `ICM_BASE_URL` | `https://icm.ad.msft.net/api/cert` | ICM REST API base URL |
| `ICM_SCOPE` | `https://icm.ad.msft.net/.default` | Azure AD token scope |

## Example Queries

**Search active Sev2 incidents for a team:**
```
filter: "Severity eq 2 and Status eq 'Active' and OwningTeamId eq 'MyOrg\\MyTeam'"
```

**List recent incidents:**
```
owningTeamId: "MyOrg\\MyTeam"
top: 10
status: "Active"
```

**Add a timeline note:**
```
incidentId: "123456789"
text: "Investigating root cause — CPU spike correlated with deployment at 14:00 UTC."
```
