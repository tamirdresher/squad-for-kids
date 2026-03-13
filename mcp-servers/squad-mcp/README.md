# Squad MCP Server

MCP server that exposes squad operations (triage, routing, status, board health) as reusable tools for AI assistants and external systems.

## Features

### Available Tools (Phase 1)

- **`get_squad_health`** — Get comprehensive squad health metrics including open issues, PRs, member capacity, and board status

### Coming Soon (Phase 2+)

- **`triage_issue`** — Triage an issue (analyze, label, assign)
- **`check_board_status`** — Check board reconciliation status
- **`get_member_capacity`** — Get capacity/availability for a squad member
- **`evaluate_routing`** — Evaluate routing for an issue based on routing rules

## Installation

```bash
cd mcp-servers/squad-mcp
npm install
npm run build
```

## Configuration

The server requires GitHub credentials and squad root path. Configuration can be provided via:

### Option 1: Environment Variables

```bash
export GITHUB_TOKEN="ghp_your_token_here"
export GITHUB_OWNER="tamirdresher_microsoft"
export GITHUB_REPO="tamresearch1"
export SQUAD_ROOT="/path/to/repo/.squad"  # Optional, defaults to ./.squad
```

### Option 2: Config File

Create `~/.config/squad-mcp/config.json`:

```json
{
  "github": {
    "token": "ghp_your_token_here",
    "owner": "tamirdresher_microsoft",
    "repo": "tamresearch1"
  },
  "squadRoot": "/path/to/repo/.squad"
}
```

## Usage

### Standalone (stdio transport)

```bash
node dist/index.js
```

The server will run on stdio (stdin/stdout) and can be connected to any MCP client.

### With MCP Client (e.g., Copilot CLI)

Add to your MCP configuration:

```json
{
  "mcpServers": {
    "squad": {
      "command": "node",
      "args": ["/path/to/mcp-servers/squad-mcp/dist/index.js"],
      "env": {
        "GITHUB_TOKEN": "ghp_your_token_here",
        "GITHUB_OWNER": "tamirdresher_microsoft",
        "GITHUB_REPO": "tamresearch1",
        "SQUAD_ROOT": "/path/to/repo/.squad"
      }
    }
  }
}
```

## Tool Reference

### `get_squad_health`

Get comprehensive squad health metrics.

**Parameters:**
- `includeMetrics` (boolean, optional): Include detailed metrics (default: true)

**Returns:**
```json
{
  "status": "healthy" | "warning" | "critical",
  "metrics": {
    "teamSize": 12,
    "openIssues": 8,
    "openPRs": 3,
    "issuesPerMember": 0.7,
    "avgIssueAge": 12,
    "untriagedCount": 2,
    "copilotQueueSize": 1
  },
  "members": [
    {
      "name": "Data",
      "role": "Code Expert",
      "status": "✅ Active",
      "assignedIssues": 1
    }
  ],
  "lastBoardUpdate": "2026-03-13T10:00:00Z",
  "summary": "Squad health: ✅ HEALTHY — 8 open issues, 3 open PRs, 2 untriaged, 1 in @copilot queue. Average issue age: 12 days."
}
```

**Health Status Criteria:**
- **Healthy (✅)**: <10 open issues, <5 PRs, <2 issues per member
- **Warning (⚠️)**: 10-20 issues, 5-10 PRs, 2-4 issues per member
- **Critical (🔴)**: >20 issues, >10 PRs, >4 issues per member

## Development

### Build

```bash
npm run build
```

### Watch mode (auto-rebuild)

```bash
npm run watch
```

### Type checking

```bash
npm run typecheck
```

### Run in dev mode (with tsx)

```bash
npm run dev
```

## Architecture

See [DESIGN.md](./DESIGN.md) for detailed architecture, tool definitions, and implementation phases.

## Integration with Squad State

The server reads squad state from:
- `.squad/team.md` — Member roster, roles, status
- `.squad/routing.md` — Routing rules
- `.squad/board_snapshot.json` — Cached board state
- `.squad/config.json` — Squad configuration

All write operations (labels, assignees) go through GitHub API. The server does not modify `.squad/` files directly.

## License

MIT
