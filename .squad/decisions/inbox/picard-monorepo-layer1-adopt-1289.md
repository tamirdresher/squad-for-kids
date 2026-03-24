# Decision: Adopt monorepo Layer 1 in active subdirectories (issue #1289)

**Date:** 2026-03-24
**Author:** Picard
**Issue:** #1289 (references bradygaster/squad#457)

## Decision

**Adopt Layer 1 now. Defer Layer 2. Contribute reference implementation back to Brady's repo.**

## What we're doing

tamresearch1 already has the Layer 1 reference implementation at root (`.squad-context.md`) and the full monorepo guide (`.squad/docs/monorepo-support.md`). The missing piece is extending Layer 1 to active functional areas.

### Areas to add `.squad-context.md` to (separate implementation issues):

| Area | Owner | Label |
|------|-------|-------|
| `infrastructure/` | B'Elanna | `area:infra` |
| `api/` | Data | `area:api` |
| `marketing/` | Troi + Neelix | `area:marketing` |
| `research/` | Seven | `area:research` |
| `scripts/` | Data + B'Elanna | `area:scripts` |

### What we're NOT doing (yet)

- **Layer 2** (per-area `.squads/` directories): tamresearch1 is a single-team repo. Not needed until concurrent multi-squad work emerges.
- **Layer 3** (directory-aware auto-dispatch): Depends on bradygaster/squad framework changes. Will adopt when Brady lands it.

## Upstream contribution

The `.squad-context.md` format and `monorepo-support.md` are ahead of brady/squad#457. We should open a contribution PR to bradygaster/squad with:
- Three-layer design documentation
- Reference `.squad-context.md` format
- Sibling-isolation design note (area decisions don't cross-inherit between sibling areas — only root→area)

## Rejected alternatives

- **Layer 2 now**: Overkill. Single team, no concurrent multi-squad work.
- **Wait for Brady to land framework first**: Layer 1 is convention-only, no framework needed. We can act independently today.

## Affects

- Data: implement `.squad-context.md` files in the 5 areas above
- B'Elanna: review `infrastructure/` context file
- Seven: review `research/` context file
- Troi/Neelix: review `marketing/` context file
- All agents: once files exist, load nearest `.squad-context.md` when working in a subdirectory (already documented in `.squad/docs/monorepo-support.md`)
