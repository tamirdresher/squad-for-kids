# Squad MCP Server — Design Document

## Overview

The Squad MCP Server exposes squad operations (triage, routing, status, board health) as reusable MCP tools for AI assistants and external systems. This enables any Copilot agent or external client to programmatically interact with the squad's operational state.

## Architecture

### Runtime & Technology Stack

- **Runtime:** Node.js (v20+) with TypeScript
- **Rationale:** Existing squad ecosystem (squad-cli by bradygaster) is Node/TS-based; consistency with existing tooling
- **MCP SDK:** `@modelcontextprotocol/sdk` v1.12.1+
- **GitHub Integration:** `@octokit/rest` for GitHub API calls
- **File System Access:** Native Node.js `fs/promises` for `.squad/` file reads
- **Validation:** `zod` for schema validation of tool parameters and configuration

### Project Structure

```
mcp-servers/squad-mcp/
├── DESIGN.md                 # This document
├── README.md                 # Usage and deployment guide
├── package.json              # Dependencies and scripts
├── tsconfig.json             # TypeScript config
├── src/
│   ├── index.ts              # MCP server entry point
│   ├── config.ts             # Configuration loader
│   ├── github.ts             # GitHub API client wrapper
│   ├── squad-state.ts        # .squad/ file readers
│   ├── tools/
│   │   ├── get-squad-health.ts
│   │   ├── triage-issue.ts
│   │   ├── check-board-status.ts
│   │   ├── get-member-capacity.ts
│   │   ├── evaluate-routing.ts
│   │   └── index.ts          # Tool registry
│   └── types.ts              # Shared types
└── dist/                     # Compiled output (gitignored)
```

### Configuration

The server requires the following configuration:

```json
{
  "github": {
    "token": "ghp_...",              // GitHub PAT with repo access
    "owner": "tamirdresher_microsoft", // Repository owner
    "repo": "tamresearch1"            // Repository name
  },
  "squadRoot": "/path/to/repo/.squad" // Path to .squad directory
}
```

Configuration can be provided via:
1. Environment variables (`GITHUB_TOKEN`, `GITHUB_OWNER`, `GITHUB_REPO`, `SQUAD_ROOT`)
2. Configuration file at `~/.config/squad-mcp/config.json`
3. Working directory `.squad/` (auto-detected if `SQUAD_ROOT` not set)

## Tool Definitions

### 1. `get_squad_health`

**Purpose:** Returns comprehensive squad health metrics

**Parameters:**
```typescript
{
  includeMetrics?: boolean  // Include detailed metrics (default: true)
}
```

**Returns:**
```typescript
{
  status: "healthy" | "warning" | "critical",
  metrics: {
    teamSize: number,
    openIssues: number,
    openPRs: number,
    issuesPerMember: number,
    avgIssueAge: number,      // days
    untriagedCount: number,   // Issues with `squad` label only
    copilotQueueSize: number  // Issues labeled `squad:copilot`
  },
  members: Array<{
    name: string,
    role: string,
    status: string,
    assignedIssues: number
  }>,
  lastBoardUpdate: string,    // ISO timestamp
  summary: string
}
```

**Implementation:**
- Read `.squad/team.md` to get member roster
- Query GitHub API for open issues count (state=open)
- Query GitHub API for open PRs count (state=open)
- Read `.squad/board_snapshot.json` for last update timestamp
- Calculate health status:
  - `healthy`: <10 open issues, <5 PRs, <2 issues per member
  - `warning`: 10-20 issues, 5-10 PRs, 2-4 issues per member
  - `critical`: >20 issues, >10 PRs, >4 issues per member

---

### 2. `triage_issue`

**Purpose:** Triage an issue (analyze, label, assign)

**Parameters:**
```typescript
{
  issueNumber: number,
  action: "analyze" | "label" | "assign",
  labels?: string[],         // For action="label"
  assignee?: string,         // For action="assign"
  routingRule?: string,      // Suggested routing (e.g., "squad:data")
  comment?: string           // Optional triage note
}
```

**Returns:**
```typescript
{
  issueNumber: number,
  action: string,
  result: "success" | "error",
  appliedLabels?: string[],
  assignedTo?: string,
  message: string
}
```

**Implementation:**
- `analyze`: Read issue body/title, evaluate @copilot fit (🟢/🟡/🔴), suggest routing based on `.squad/routing.md` patterns
- `label`: Apply/remove labels via GitHub API
- `assign`: Set assignee via GitHub API, apply `squad:{member}` label

---

### 3. `check_board_status`

**Purpose:** Check board reconciliation status

**Parameters:**
```typescript
{
  iteration?: string,        // Iteration name (default: current)
  includeDetails?: boolean   // Include per-issue details (default: false)
}
```

**Returns:**
```typescript
{
  iteration: string,
  status: "synced" | "drift" | "error",
  issueCount: number,
  driftCount: number,         // Issues out of sync
  lastSync: string,           // ISO timestamp
  issues?: Array<{            // If includeDetails=true
    number: number,
    title: string,
    state: string,
    labels: string[],
    assignee?: string,
    drift?: string            // Description of drift
  }>,
  summary: string
}
```

**Implementation:**
- Read `.squad/board_snapshot.json` for cached board state
- Query GitHub API for current board state
- Compare timestamps, issue counts, label states
- Detect drift: issues labeled `squad:{member}` but not assigned, issues closed but still in board, etc.

---

### 4. `get_member_capacity`

**Purpose:** Get capacity/availability for a squad member

**Parameters:**
```typescript
{
  member: string,            // Member name (e.g., "data", "picard")
  includeAssignments?: boolean // Include assigned issues (default: true)
}
```

**Returns:**
```typescript
{
  member: string,
  role: string,
  status: string,            // From team.md (e.g., "✅ Active")
  assignedIssues: number,
  capacity: "available" | "moderate" | "busy",
  assignments?: Array<{
    number: number,
    title: string,
    labels: string[],
    createdAt: string
  }>
}
```

**Implementation:**
- Read `.squad/team.md` to get member role/status
- Query GitHub API for issues labeled `squad:{member}`
- Calculate capacity:
  - `available`: 0-1 issues
  - `moderate`: 2-3 issues
  - `busy`: 4+ issues

---

### 5. `evaluate_routing`

**Purpose:** Evaluate routing for an issue based on routing rules

**Parameters:**
```typescript
{
  issueContext: {
    title: string,
    body: string,
    labels?: string[]
  },
  copilotEval?: boolean      // Include @copilot capability eval (default: true)
}
```

**Returns:**
```typescript
{
  suggestedRoute: string,    // "squad:data", "squad:copilot", etc.
  confidence: "high" | "medium" | "low",
  reasoning: string,
  copilotFit?: "🟢" | "🟡" | "🔴",  // If copilotEval=true
  alternativeRoutes?: string[]
}
```

**Implementation:**
- Parse `.squad/routing.md` for routing rules
- Parse `.squad/team.md` for member expertise domains
- Apply keyword matching (e.g., "C#" → Data, "K8s" → B'Elanna)
- If copilotEval=true, evaluate against @copilot capability profile:
  - 🟢: Bug fixes, tests, dependency updates, well-defined tasks
  - 🟡: Small features with specs (needs PR review)
  - 🔴: Architecture, security, design decisions
- Return suggested route with reasoning

---

## Integration with Existing Squad State

The server reads squad state from:

1. **`.squad/team.md`** — Member roster, roles, status, @copilot capability profile
2. **`.squad/routing.md`** — Routing rules, work type → agent mapping
3. **`.squad/board_snapshot.json`** — Cached board state (updated by monitoring/board-sync tool)
4. **`.squad/decisions.md`** — Team decisions (read-only reference)
5. **`.squad/config.json`** — Squad configuration (machine identity, GitHub repo)

The server **does not modify** `.squad/` files directly — all mutations happen via GitHub API (labels, assignees, comments). This maintains the existing squad-cli workflow where `.squad/` files are the source of truth updated by squad members.

## Deployment Options

### 1. Local Development (stdio transport)

```bash
cd mcp-servers/squad-mcp
npm install
npm run build
node dist/index.js
```

MCP client connects via stdio (stdin/stdout) — suitable for local Copilot CLI usage.

### 2. DevBox Deployment

Deploy as a background service on DevBox:
- Run via `pm2` or `systemd` service
- Expose via stdio transport (Copilot CLI connects locally)
- Environment variables set in service config

### 3. Container Deployment (future)

Package as Docker container, expose via HTTP transport (MCP SDK supports this), deploy to Azure Container Apps or AKS.

### 4. Serverless (future)

Azure Functions or AWS Lambda with HTTP trigger, MCP server responds to tool calls via HTTP.

## Security Considerations

- **GitHub Token:** Store in secure vault (Azure Key Vault, GitHub Secrets), not in config files
- **Read-only by default:** Most tools are read-only (get_squad_health, check_board_status, get_member_capacity, evaluate_routing)
- **Write operations:** triage_issue with action="label" or "assign" requires repo write access — audit logs via GitHub API
- **Input validation:** All tool parameters validated via Zod schemas before execution

## Testing Strategy

1. **Unit tests:** Tool logic with mocked GitHub API and file system
2. **Integration tests:** End-to-end with test repository
3. **Manual testing:** MCP Inspector (built into MCP SDK) for interactive testing

## Future Enhancements

- **Streaming tool support:** For long-running operations (e.g., board sync)
- **Resource support:** Expose `.squad/` files as MCP resources (read-only access to team.md, routing.md, etc.)
- **Prompt support:** Pre-built prompts for common squad operations (e.g., "Triage this issue", "Who should handle this?")
- **Webhook integration:** Real-time updates when GitHub issues change (via webhooks)
- **Analytics tools:** Historical metrics (velocity, cycle time, member activity over time)

## Implementation Phases

### Phase 1: Core Infrastructure (This PR)
- [x] Design document
- [x] Project scaffolding (package.json, tsconfig.json, directory structure)
- [x] MCP server entry point with tool registration
- [x] Configuration loader
- [x] GitHub API client wrapper
- [x] Squad state file readers
- [x] Implement `get_squad_health` tool (fully functional)

### Phase 2: Read-Only Tools (Next PR)
- [ ] Implement `check_board_status` tool
- [ ] Implement `get_member_capacity` tool
- [ ] Implement `evaluate_routing` tool
- [ ] Add comprehensive error handling
- [ ] Add unit tests

### Phase 3: Write Operations (Future PR)
- [ ] Implement `triage_issue` tool (analyze, label, assign)
- [ ] Add audit logging
- [ ] Add permission checks
- [ ] Integration tests

### Phase 4: Deployment & Registration (Future PR)
- [ ] DevBox deployment scripts
- [ ] MCP Registry registration
- [ ] Documentation for external consumers
- [ ] Performance optimization

## References

- **MCP SDK:** https://github.com/modelcontextprotocol/typescript-sdk
- **MCP Specification:** https://modelcontextprotocol.io/
- **Octokit (GitHub API):** https://github.com/octokit/rest.js
- **Squad CLI (bradygaster):** https://github.com/bradygaster/squad-cli (reference implementation)
