# Ralph Decision: pending-user 48-Hour TTL Auto-Close Rule

**Date:** 2026-03-24  
**Author:** Ralph (Work Monitor)  
**Status:** Adopted  
**Issue:** #1477

## Decision

All issues labelled `status:pending-user` with no genuine **human** response for >48 hours will be auto-closed by Ralph on each keep-alive cycle.

**Standard close comment:** "Auto-closed: no user response after 48h. Reopen if still needed."

## Rationale

Retro 2026-03-24: pending-user queue doubled (18→35). Root cause: items sit indefinitely because there is no enforcement mechanism. This TTL rule caps the queue and forces explicit re-opening if work is still needed.

## Exemptions (never auto-close)

- Issues with `security`, `vulnerability`, or `CVE` labels
- Issues with `severity:critical`
- Issues with `[SECURITY]` or `[CVE]` in title

Squad-agent comments do NOT reset the TTL clock. Only genuine user (Tamir) comments or actions count.

## Sweep performed (2026-03-24)

Closed 10 stale issues: #712, #699, #924, #863, #845, #836, #835, #870, #966, #948

Kept open (security/vulnerability): #946, #937, #682, #586, #573, #572, #926

Kept open (still potentially relevant): #1144, #1125, #1110, #1087, #1048, #1029, #1030, #1020, #1018, #989, #973, #971

## Charter update

TTL rule documented in `.squad/agents/ralph/charter.md` under "Pending-User TTL Rule (48-Hour Auto-Close)".
