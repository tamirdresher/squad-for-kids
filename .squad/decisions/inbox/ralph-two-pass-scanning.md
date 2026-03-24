# Decision: Ralph adopts two-pass issue scanning

**Date:** 2026-06-07
**Author:** Data (implementing #1469)
**Status:** Implemented

## Decision

Ralph's issue scan cycle now uses a **two-pass approach**:

1. **Pass 1 (lightweight):** `gh issue list --json number,title,labels,assignees` — no body/comments
2. **Pass 2 (selective hydration):** `gh issue view <number> --json body,comments` — only for issues
   that survive the Pass 1 filter (not blocked, not already assigned and idle, not done/postponed)

## Rationale

Previous single-pass approach fetched full issue JSON for every open issue.
For a ~25-issue backlog that was ~26 API calls/round; the new approach reduces that to ~7 (~72%).
Threshold for change was >20% — comfortably met.

No behavioural change to triage logic. The filter rules are purely additive gate-keeping.

## Filter Rules (Pass 1 → skip hydration)

- Non-empty `assignees` AND label is NOT `status:needs-review` → already owned
- `status:blocked` or `status:waiting-external` → externally gated
- `status:done` or `status:postponed` → closed loop
- Title matches stale/auto patterns → noise

## References

- Issue: tamirdresher_microsoft/tamresearch1#1469
- Upstream proposal: bradygaster/squad#596
- Charter updated: `.squad/agents/ralph/charter.md` — "Issue Scanning Protocol (Two-Pass)" section
