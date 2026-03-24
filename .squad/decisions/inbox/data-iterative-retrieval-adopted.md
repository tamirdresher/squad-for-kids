# Decision: Iterative Retrieval Pattern Adopted

**Date:** 2026-03-28
**Issue:** #1317
**Agent:** Data

## Decision
Adopted the iterative retrieval pattern for all squad agent spawning.

## What changed
- `.squad/agents/ralph/charter.md` — added Iterative Retrieval Protocol section
- `.squad/skills/iterative-retrieval/SKILL.md` — new reusable skill created
- `ralph-watch.ps1` — spawn template comment block + live prompt instruction added

## Protocol summary
- Every agent spawn prompt must include: Task / WHY / Success criteria / Escalation path
- Max 3 cycles before escalating to `status:needs-decision`
- Ralph validates all outputs against success criteria before closing any issue

## Source
PR: squad/1317-iterative-retrieval-CPC-tamir-3H7BI (rate-limited at creation, push succeeded)
