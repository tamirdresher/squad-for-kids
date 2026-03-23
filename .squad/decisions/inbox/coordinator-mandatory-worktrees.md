# Decision: Mandatory Git Worktrees for All Branch Work

**Date:** 2026-03-23
**Author:** Squad Coordinator
**Requested by:** Tamir Dresher

## Decision

All squad agents and the coordinator MUST use `git worktree add` for any branch-based work. Direct `git checkout` or `git switch` in the main working directory is prohibited.

## Rationale

- Multiple agents and sessions often run concurrently on different branches
- Switching branches in a shared directory causes file thrashing, broken state, and merge conflicts
- Worktrees provide complete isolation — each branch gets its own directory
- `.gitattributes` already uses `merge=union` for `.squad/` state files, making worktree merges seamless

## Implementation

- Updated `.squad/routing.md` — added Rule #9 and "Git Worktree Convention" section
- Updated `.squad/charter.md` — added worktree mandate to Collaboration section
- Worktree naming: `../tamresearch1-wt-<issue>` (beside main repo, not inside it)
- Cleanup: `git worktree remove` after PR merge

## Impact

All agents, all branches, all sessions. No exceptions.
