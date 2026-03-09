# Decision: PR Merge Conflict Resolution Strategy

**Date:** 2026-03-15  
**Decided By:** B'Elanna (Infrastructure Expert)  
**Context:** PR merge conflict resolution for PRs #216, #217, #218, #220  
**Status:** Resolved

## Problem

Four approved PRs were blocked with merge conflicts after PR #219 was merged. The conflicts occurred in:
- `.squad/` append-only files (histories, logs, decisions)
- Dashboard UI implementation files (same feature added by multiple PRs)
- Local working directory changes from ralph-watch activity

## Decision

**Sequential Merge Strategy with Context-Aware Conflict Resolution**

### Process Applied

1. **Sequential Processing** (not parallel)
   - Each PR merged changes main, affecting subsequent merges
   - Order: #216 → #217 → #218 → #220

2. **Conflict Resolution by File Type**
   - **`.squad/` files:** Rely on union merge strategy (already in .gitattributes)
   - **Dashboard UI files:** Context-aware resolution:
     - PR #217: Keep branch version (--ours) — Picard-approved enhanced implementation
     - PR #218: Keep main version (--theirs) — main now has PR #217's implementation
   - **Local changes:** git stash before merge operations

3. **Verification Steps**
   - Push merged branch
   - Wait for CI (3-second delay)
   - Squash-merge via gh pr merge
   - Close linked issue
   - Update project board
   - Pull latest main before next PR

### Rationale

**Why Sequential:**
- Each merge changes the main baseline
- Parallel merges would create race conditions
- Allows context-aware decisions based on what's already merged

**Why Context-Aware Resolution:**
- "Both added" conflicts require understanding feature provenance
- PR #217 had the most complete implementation (raw log view + processed view)
- PR #218's version would have been redundant after #217 merged
- Kept approved enhancements, avoided duplicate code

**Why Union Merge for .squad/:**
- Append-only files (histories, logs) should preserve all content
- .gitattributes merge=union already configured
- Auto-resolves most .squad/ conflicts without manual intervention

## Outcomes

✅ All 4 PRs merged successfully  
✅ All 4 linked issues closed  
✅ All 4 project board items updated to Done  
✅ No duplicate dashboard UI code  
✅ All .squad/ append-only files preserved both sides' content

## Patterns Observed

1. **Union merge works:** .gitattributes merge=union auto-resolved history/log conflicts
2. **Local changes common:** ralph-watch activity creates local mods requiring stash
3. **Feature duplication risk:** Multiple PRs adding same files → "both added" conflicts
4. **Fast-forward warnings harmless:** Expected when main diverged during merge window

## Lessons for Future Conflict Resolution

1. **Always process blocked PRs sequentially** — order matters when main is changing
2. **Check feature provenance** — understand which branch has the most complete implementation
3. **Trust union merge** — .gitattributes handles .squad/ append-only files automatically
4. **Stash early** — assume ralph-watch has created local changes
5. **Use gh pr merge** — handles branch deletion and main update atomically

## Related

- PRs: #216, #217, #218, #220
- Issues: #215, #207, #214, #199
- Previous PR that triggered conflicts: #219
