# Squad MCP Server Architecture Decision

**Date:** 2026-03-13  
**Author:** Data  
**Issue:** #417 — Build Squad MCP Server to expose squad operations (#385)  
**PR:** #453  
**Status:** Phase 1 Complete

## Decision

Build a dedicated Squad MCP Server using Node.js + TypeScript to expose squad operations (triage, routing, status, board health) as reusable MCP tools for AI assistants and external systems.

## Context

From Copilot Features Evaluation research (#385), we identified a need for squad operations to be accessible programmatically beyond just embedded copilot-instructions context. This enables:
- External MCP clients to query squad health
- Other agents to evaluate routing without full context load
- Automation tools to triage issues
- Board sync tools to check drift status

## Architecture Decisions

### Runtime Choice: Node.js + TypeScript

**Rationale:**
- Existing squad-cli ecosystem (by bradygaster) is Node/TS-based
- Consistency with existing tooling reduces learning curve
- @modelcontextprotocol/sdk has excellent TypeScript support
- @octokit/rest provides native GitHub API integration

**Alternatives Considered:**
- **.NET/C#:** Would match squad-monitor but creates bifurcation in squad tooling (two runtimes to maintain)
- **Python:** Would match other MCP servers in repo but lacks squad ecosystem consistency

### State Integration: Read `.squad/`, Write via GitHub API

**Rationale:**
- `.squad/` files are the source of truth (maintained by squad members)
- MCP server is read-only observer for most operations
- Mutations (labels, assignees) go through GitHub API for audit trail
- Prevents file conflicts and maintains single-writer discipline

**Key Pattern:**
- `team.md`, `routing.md`, `board_snapshot.json` → read-only parsers
- Issue triage, labeling, assignment → GitHub API only
- No direct writes to `.squad/` files by MCP server

### Configuration: Environment Variables First, Config File Fallback

**Priority Order:**
1. Environment variables (GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO, SQUAD_ROOT)
2. Config file at `~/.config/squad-mcp/config.json`
3. Auto-detect SQUAD_ROOT from current directory (`./.squad`)

**Rationale:**
- Environment variables work well for DevBox deployment (systemd service)
- Config file provides persistent setup for local development
- Auto-detection reduces friction for quick tests

### Transport: stdio (stdin/stdout)

**Phase 1 Decision:** stdio transport for local MCP clients (Copilot CLI)

**Future Considerations:**
- HTTP transport for container/serverless deployment
- WebSocket for streaming operations (board sync)

**Rationale:** stdio is simplest for local dev and DevBox deployment. HTTP adds complexity we don't need yet.

## Tool Implementation Strategy

### Phase 1: Core Infrastructure + First Tool (PR #453)
- `get_squad_health` — read-only, fully functional
- GitHub API client wrapper (Octokit)
- Squad state file parsers (team.md, board_snapshot.json)
- Configuration loader

### Phase 2: Read-Only Tools (Next PR)
- `check_board_status` — compare cached vs live state
- `get_member_capacity` — query issues by label
- `evaluate_routing` — pattern matching on routing.md

### Phase 3: Write Operations (Future PR)
- `triage_issue` — apply labels, assign, comment
- Audit logging for mutations
- Permission checks

### Phase 4: Deployment (Future PR)
- DevBox systemd service
- MCP Registry registration
- Performance optimization

**Rationale:** Incremental delivery with clear phase boundaries. Phase 1 proves architecture, Phase 2 completes read-only tools, Phase 3 adds write operations with proper safeguards.

## Health Status Thresholds

Defined clear criteria for squad health status:

- **Healthy (✅)**: <10 open issues, <5 PRs, <2 issues per member
- **Warning (⚠️)**: 10-20 issues, 5-10 PRs, 2-4 issues per member
- **Critical (🔴)**: >20 issues, >10 PRs, >4 issues per member

**Rationale:** Based on observed squad capacity (12 active members). Thresholds calibrated to trigger warnings before capacity overload.

## Security Considerations

- **GitHub Token Storage:** Recommend Azure Key Vault or GitHub Secrets, not config files
- **Read-Only Default:** Most tools are read-only (get_squad_health, check_board_status, get_member_capacity, evaluate_routing)
- **Write Operations Gated:** triage_issue requires explicit repo write access, audit logs via GitHub API
- **Input Validation:** All tool parameters validated via Zod schemas

## Implications for Team

1. **MCP Server Reusability:** Any Copilot agent can now query squad health without loading full `.squad/` context
2. **External Integration:** External automation tools can interact with squad state programmatically
3. **Board Sync Tooling:** Future board sync tools can leverage `check_board_status` instead of reimplementing state comparison
4. **Triage Automation:** Once Phase 3 ships, Lead agents can use `triage_issue` to label/assign issues programmatically

## References

- **Design Document:** `mcp-servers/squad-mcp/DESIGN.md`
- **PR #453:** https://github.com/tamirdresher_microsoft/tamresearch1/pull/453
- **Issue #417:** https://github.com/tamirdresher_microsoft/tamresearch1/issues/417
- **Research #385:** Copilot Features Evaluation — identified need for MCP-exposed squad operations
- **MCP SDK:** https://github.com/modelcontextprotocol/typescript-sdk
- **Squad CLI Reference:** https://github.com/bradygaster/squad-cli (existing Node/TS squad tooling)
