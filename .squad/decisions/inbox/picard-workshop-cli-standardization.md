# Decision: Workshop CLI Command Standardization

**Date:** 2026-03-22  
**Decider:** Picard  
**Context:** Issue #757 — Workshop review identified command reference inconsistency  
**Status:** Approved & Implemented

## Decision

Workshop documentation (`docs/workshop-build-your-own-squad.md`) now uses **`agency copilot`** as the primary CLI command, with **`gh copilot`** documented as an alternative.

## Rationale

1. **Consistency with Production Tooling:** `ralph-watch.ps1` (our production automation) uses `agency copilot --yolo --agent squad`. Workshop should match production.

2. **Attendee Success:** Workshop participants need executable, verifiable commands in prerequisites. Generic "GitHub Copilot CLI" left them uncertain which command to run.

3. **Dual Compatibility:** Documenting both commands supports users in different environments while establishing agency copilot as the standard.

## Implementation

Updated 5 locations in workshop doc:
- Prerequisites table
- Framework description  
- Prerequisites verification commands
- Agent invocation narrative
- Production automation example

## Impact

- **Workshop facilitators:** Can confidently instruct attendees on exact command
- **Squad users:** Clear guidance on which CLI to install
- **Future docs:** Pattern established for command references

## Related

- Issue #757 (workshop review)
- `ralph-watch.ps1` (production usage pattern)
- Workshop review Critical Issue #1 (command verification)
