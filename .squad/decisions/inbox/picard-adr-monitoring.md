# Decision: Daily ADR Channel Monitoring

**Date:** 2026-03-09
**Author:** Picard (Lead)
**Issue:** #198
**Status:** Implemented

## Decision

Added daily read-only monitoring of the IDP ADR Notifications Teams channel to the Squad schedule. Runs at 07:00 UTC (10:00 AM Israel time) on weekdays via ralph-watch.ps1.

## Rationale

Tamir needs visibility into ADR activity without manually checking the channel. Squad provides automated monitoring with strict read-only constraints — never comments on the channel or ADRs.

## Implementation

- Schedule: `.squad/schedule.json` → `daily-adr-check` entry
- Query template: `.squad/scripts/workiq-queries/idp-adr-notifications.md`
- Script: `.squad/scripts/daily-adr-check.ps1`
- Integration: `ralph-watch.ps1` time-based trigger at 07:00 UTC
- State: `.squad/monitoring/adr-check-state.json`

## Constraints

- **NEVER** post to the IDP ADR Notifications channel
- **NEVER** comment on any ADR document
- Only send private summaries to Tamir via Teams webhook
- Only notify when there are actionable items (no noise)

## Team Impact

All agents should be aware of this constraint. If any agent encounters ADR-related work, it must respect the read-only policy on the IDP ADR Notifications channel.
