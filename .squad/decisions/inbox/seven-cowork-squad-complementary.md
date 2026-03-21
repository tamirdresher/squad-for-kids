# Decision: CoWork + Squad are complementary, not competing

**Author:** Seven
**Date:** 2026-03-21
**Issue:** #964

## Decision

Use CoWork alongside Squad — they operate in different lanes. No replacement needed.

- **CoWork** handles M365 office work (calendar, email, docs, meetings) for Tamir as a knowledge worker.
- **Squad brain** handles engineering work (code, PRs, architecture, content) for Tamir as a developer.

## Integration point

Kes already interfaces with M365 via Graph API. When CoWork becomes broadly available (post-Frontier Program), consider wiring Kes to delegate complex M365 coordination tasks to CoWork while Squad retains ownership of developer workflow.

## Worth borrowing (6 patterns from CoWork)

1. Plan-to-action loop with explicit approval (show plan before executing)
2. Mid-task progress comments on GitHub issues
3. Unified in-flight task dashboard (enhance Ralph's watch.ps1)
4. Live M365 context refresh into squad sessions (via Kes)
5. Dry-run mode for destructive operations
6. Plan-first requirement for 🔴 high-risk tasks before branch creation

## Research

Full analysis at `research/cowork-vs-squad-brain-2026-03-21.md`
