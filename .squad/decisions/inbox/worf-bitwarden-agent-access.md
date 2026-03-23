# Decision: Replace bitwarden-shadow with bitwarden/agent-access

**Date:** 2026-05-16  
**Author:** Worf  
**Issue:** #1247  
**Branch:** feat/bitwarden-agent-access-1247-CPC-tamir-3H7BI

## Decision

Replace the `bitwarden-shadow` MCP server (which used `BW_SESSION` + collection scoping) with a new `bitwarden-agent-access` MCP server that wraps the `aac` CLI from [bitwarden/agent-access](https://github.com/bitwarden/agent-access).

## Rationale

The old approach required:
- Bitwarden Organization plan (Teams/Enterprise) for service accounts
- Manually shadowing items into collections before agents could read them
- `BW_SESSION` held as an env var in the MCP server process

The new approach (`aac`):
- Works on any Bitwarden plan including free
- No session tokens on the agent side — E2E encrypted tunnel to user's device
- `aac listen` on user's device, pairing token given to agent once
- `aac run` injects credentials directly into subprocess env — raw passwords never reach the AI
- Zero collection/org setup required

## Security properties preserved

- AI never sees raw passwords (only `username`, `hasPassword`, `hasTotp` metadata)
- `run_with_credential` injects secrets as child process env vars only (same guarantee as `aac run`)
- Revocation: stop `aac listen` = instant access revocation

## Warning

bitwarden/agent-access is **early preview** (APIs may change). Pin aac CLI version for production stability.

## Files changed

- `mcp-servers/bitwarden-agent-access/` — new MCP server
- `setup-bitwarden-agent-access.ps1` — Windows setup script (replaces `setup-bitwarden.ps1`)
- `mcp-servers/bitwarden-shadow/` — kept but deprecated (do not remove until confirmed working)

## Agent impact

All agents that previously used `bitwarden-shadow` tools (`shadow_item`, `unshadow_item`, `list_shadows`) should switch to:
- `check_aac_available` — verify setup
- `list_aac_sessions` — check pairing
- `get_credential_info(domain=X)` — get username/metadata
- `run_with_credential(domain=X, command=[...])` — inject secrets into subprocess
