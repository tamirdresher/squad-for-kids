# Decision Proposal: Implement Multi-Org ADO MCP Configuration

**Date:** 2026-06-24  
**Author:** Data (Code Expert)  
**Related Issue:** #329  
**Related Decision:** Decision 14 (approved 2026-03-11)

## Proposal

Complete the implementation of Decision 14's multi-instance MCP pattern by updating both global and repo-level MCP config files to replace the single `azure-devops` instance with named `ado-microsoft` and `ado-msazure` instances.

## Why This Matters to the Team

- All squad agents are currently blind to `msazure` org repos, PRs, and work items
- Cross-org PR reviews (e.g., PR #15000967 in msazure/CESEC) fail silently
- Decision 14 was approved 3+ months ago but Phase 2 validation was never completed

## Config Change (both files)

```json
{
  "ado-microsoft": {
    "type": "local",
    "command": "npx",
    "args": ["-y", "@azure-devops/mcp", "microsoft"],
    "tools": ["*"]
  },
  "ado-msazure": {
    "type": "local",
    "command": "npx",
    "args": ["-y", "@azure-devops/mcp", "msazure"],
    "tools": ["*"]
  }
}
```

## Impact

- Tool names change: `azure-devops-*` → `ado-microsoft-*` / `ado-msazure-*`
- All agent routing.md references need updating
- Memory: ~50MB additional for second Node.js process

## Status

Pending user decision on approach confirmation and org list.
