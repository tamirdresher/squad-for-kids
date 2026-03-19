# Decision: Monorepo Support Architecture

**Date:** 2026-03-19  
**Author:** Picard  
**Issue:** #1012  
**Status:** Proposed — awaiting Tamir review

## Decision

Design a three-layer monorepo support model for Squad:

1. **Layer 1 — `.squad-context.md`:** Lightweight per-area context files, walk-up discovery, zero framework changes. Ship first.
2. **Layer 2 — `.squads/` directories:** Formal per-area team + routing configs that inherit from root HQ. Medium effort.
3. **Layer 3 — Directory-aware dispatch:** Full automatic area detection from issue file paths. Future roadmap.

## Key Invariants

- **Agent charters always live at root.** No charter duplication inside `.squads/` dirs.
- **HQ security gates cannot be overridden by area configs.** Areas can add requirements, never remove them.
- **Area `decisions/` is local; root decisions always apply to all areas.**
- **Identity model stays user-passthrough today.** Document honestly in `mcp-servers.md`. Track SP auth as a separate future issue.

## Rationale

This matches how Turborepo/Nx handle per-package config: root = defaults, child = targeted overrides. The area team.md references root agents by name (single source of truth) rather than redefining them. This prevents charter drift across areas.

## Next Steps

1. Tamir approves/adjusts the design on issue #1012
2. Seven writes `.squad/docs/monorepo-guide.md`
3. Kes or Worf adds `area:*` labels to the repo
4. Pick one real area to implement Phase 2 as reference implementation
