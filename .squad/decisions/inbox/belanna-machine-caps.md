# Decision: Machine Capability Labels + Smart Ralph Routing

**Date:** 2026-03-19
**Author:** B'Elanna (Infrastructure Expert)
**Issue:** #987
**Status:** Implemented

## Context

Ralph runs on multiple machines. Some issues require specific machine capabilities — a GPU for ML workloads, an active WhatsApp session, a particular GitHub account type, Azure Speech SDK, etc. Without capability awareness, Ralph wastes rounds attempting work it cannot complete, then fails.

## Decision

Introduced a `needs:*` label taxonomy and machine capability discovery system:

1. **8 `needs:*` labels** created on the repo: `needs:whatsapp`, `needs:browser`, `needs:gpu`, `needs:personal-gh`, `needs:emu-gh`, `needs:teams-mcp`, `needs:onedrive`, `needs:azure-speech`.

2. **Discovery script** (`scripts/discover-machine-capabilities.ps1`) probes the local machine for available tools, accounts, and services. Writes `~/.squad/machine-capabilities.json`.

3. **`Test-MachineCapability` function** added to `ralph-watch.ps1` — takes issue labels, returns whether the machine can handle the issue.

4. **Prompt-level routing** — Ralph's prompt now instructs it to check `needs:*` labels against the capability manifest before picking up any issue. Issues with unmet requirements are skipped silently.

5. **Startup integration** — Ralph runs the discovery script on round 1 and every 50th round to keep the manifest fresh.

## Consequences

- Ralph instances self-select work they can complete — no wasted rounds.
- Adding new capability types requires: (a) create label, (b) add probe to discovery script, (c) document in routing.md.
- Issues without `needs:*` labels are unaffected — any machine picks them up.
- The manifest is machine-local (`~/.squad/`), not committed to the repo.

## Files Changed

- `scripts/discover-machine-capabilities.ps1` — new
- `ralph-watch.ps1` — `Test-MachineCapability` function + prompt update + startup discovery call
- `.squad/routing.md` — documentation of capability routing
- GitHub labels — 8 new `needs:*` labels created
