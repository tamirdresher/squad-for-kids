# Decision: Keep `.squad/` tracked through Squad v1.0 transition

**Date:** 2026-03-22  
**Author:** Picard  
**Status:** Proposed — needs Tamir sign-off  
**Tracking Issue:** tamirdresher_microsoft/tamresearch1#1351  
**Assessment:** `.squad/UPSTREAM-MIGRATION-ASSESSMENT.md`

## Decision

**Keep `.squad/` tracked in version control (opt-in behavior)** as upstream Squad moves to treat `.squad/` as build output in v1.0.

## Rationale

1. Our 44 custom skills (`/skills/*`) contain irreplaceable domain-specific implementations that `squad build` cannot regenerate from `squad.config.ts`
2. Agent histories (`/agents/*/history.md`) are institutional memory, not build output
3. Upstream PRD #498 explicitly supports keeping `.squad/` tracked as opt-in
4. We are already using SDK mode — `squad.config.ts` is fully configured

## Required Actions

1. **Run `squad export`** once v0.9.0 ships — create a backup snapshot
2. **Clean up root-level clutter** — remove temporary `commit-msg-*.txt` files
3. **Audit `.gitignore`** — ensure `cross-machine/`, `monitoring/` and certain root files are properly tiered
4. **Update `upstream-state.json`** — set `lastSeenDiscussionId` to at least `"499"` so Ralph doesn't re-report this
5. **Ensure `squad.config.ts` captures routing rules** so `squad build` produces correct framework scaffolding

## Not Doing

- NOT untracking `.squad/` from version control
- NOT migrating to `.squad/`-as-build-output at this time

## Review Date

Revisit when `squad export` tooling is available and after v0.10.0 ships.
