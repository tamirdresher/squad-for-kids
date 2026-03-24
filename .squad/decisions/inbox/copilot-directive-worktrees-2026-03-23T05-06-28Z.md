### 2026-03-23T05-06-28Z: User directive
**By:** Tamir (via Copilot)
**What:** Always use git worktrees for squad state isolation in demo repos and blog post examples. The worktree-local strategy is the preferred approach — each branch gets its own .squad/ state via a mounted worktree.
**Why:** User request — captured for team memory. Ensures demo repos and documentation consistently show worktrees as the canonical pattern.
