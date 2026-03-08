# Decision: Ralph Notification Frequency Reduction

**Date:** 2026-03-08  
**Author:** Data (Code Expert)  
**Issue:** #112  
**Status:** Implemented

## Context

Ralph runs every 5 minutes via `ralph-watch.ps1` and launches a full Copilot session with the Squad agent. The original prompt said "dont forget to update me in teams if needed," which was too vague and resulted in Teams notifications being sent after every iteration, even when no actionable work occurred.

User (Tamir) reported notification fatigue — receiving "Ralph — Board Status Report" messages every 5 minutes was disruptive.

## Decision

**Updated the Ralph prompt to explicitly specify notification criteria:**

Only send Teams notifications when there are **actionable items**:
- New issues requiring user decisions
- PRs ready for review or merged
- CI/CD failures
- Completed work user should be aware of
- Items requiring user action

**Do NOT send** Teams notifications for:
- Routine board status checks with no changes
- Background processing with no user-facing impact
- Work in progress with no blockers

## Implementation

Modified `ralph-watch.ps1` line 8:

**Before:**
```powershell
$prompt = 'Ralph, Go! make sure the PR comments are also taken care of and then merge the PRs when they are ready and open new issues if needed. dont forget to update me in teams if needed'
```

**After:**
```powershell
$prompt = 'Ralph, Go! make sure the PR comments are also taken care of and then merge the PRs when they are ready and open new issues if needed. IMPORTANT: Only send a Teams message if there are important changes that require my attention — such as new issues needing my decision, PRs ready for review or merged, CI failures, completed work I should know about, or items requiring user action. Do NOT send a Teams message for routine board status checks with no actionable changes.'
```

## Rationale

1. **Prompt clarity is critical for LLM behavior**: Vague instructions like "if needed" leave interpretation to the model, leading to over-triggering
2. **Examples improve precision**: Listing specific scenarios (PRs merged, CI failures) provides concrete guidance
3. **Negative cases matter**: Explicitly stating when NOT to notify prevents false positives
4. **User experience over completeness**: 5-minute automation frequency requires strict notification gating to avoid becoming noise

## Impact

**Benefits:**
- Reduced notification fatigue for user
- Teams channel remains actionable (signal vs noise)
- Ralph continues to do background work silently unless intervention needed

**Risks:**
- User might miss some notifications if Ralph's interpretation of "actionable" differs from user's
- Can be tuned further if false negatives occur

## Alternatives Considered

1. **Increase Ralph interval (e.g., 15 minutes)** — Rejected: Slows down automation responsiveness
2. **Digest-style notifications (batch updates)** — Rejected: Defeats purpose of real-time issue triaging
3. **Notification filtering at Teams webhook level** — Rejected: Puts filtering logic outside automation control

## Related

- Issue #104: Teams notification system for issue closes (workflow-based, not Ralph-driven)
- Issue #112: This decision directly addresses user request

## Team Consensus

**Approved by:** Tamir Dresher (user/product owner)  
**Implemented by:** Data (Code Expert)

Commit: 9891b0f
