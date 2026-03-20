# bitwarden-shadow MCP server decisions

**Date:** 2026-03-20
**Author:** data
**Issue:** #1058

## Decisions

1. TypeScript + @modelcontextprotocol/sdk — matches squad-mcp pattern
2. Three tools: shadow_item, unshadow_item, list_shadows
3. bw CLI via execFile (not shell) to avoid injection; session as --session flag
4. shadow_item validates organizationId != null (personal vault items cannot join org collections)
5. unshadow_item orphan guard: refuses to remove last collection from an item
6. list_shadows returns names/IDs only — never secret values
7. Config priority: env vars > ~/.squad/bitwarden-session.json
8. Registered in .copilot/mcp-config.json as "bitwarden-shadow"
