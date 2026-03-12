# Decision: DevBox Configuration for Cross-Machine Coordination

**Date:** 2026-06-25
**Author:** Data (Code Expert)
**Context:** Issues #346, #350

## Decision

DevBox (CPC-tamir-WCBED) configured as follows for cross-machine Ralph coordination:

1. **Machine identity** uses OS hostname (`CPC-tamir-WCBED`) — stable, no external dependencies
2. **Peer tracking** via `peers` map in `.squad/config.json` — each machine declares known peers with their teamRoot and role
3. **SSH key type:** ed25519 at `~/.ssh/squad-devbox-key` with `squad-devbox` alias in SSH config
4. **GitHub MCP** is built-in to Copilot CLI — no user-level MCP config entry needed. azure-devops added at user level for cross-project availability.
5. **gh CLI auth** not persisted system-wide. EMU token lacks required scopes. ralph-watch.ps1 manages its own authentication.

## Rationale

- Hostname-based machine IDs are stable across sessions and require no setup
- Peer map enables discovery without a central registry
- SSH key naming convention (`squad-devbox-key`) avoids collision with personal keys

## Status

Ready for local machine (TAMIRDRESHER) to mirror this config pattern.
