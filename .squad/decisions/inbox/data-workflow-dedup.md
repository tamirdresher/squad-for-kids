# Decision: Workflow Comment Dedup Pattern

**Date:** 2026-07-15
**Author:** Data (Code Expert)
**Status:** Implemented

## Context

The `squad-issue-assign.yml` and `squad-triage.yml` workflows both post comments on GitHub issues when squad labels are applied. Because triage adds a `squad:{member}` label which re-triggers the assign workflow, every triage event produced 2+ comments — causing email notification spam for the repo owner.

## Decision

Adopt the `listComments → find(marker) → updateComment/createComment` dedup pattern (already used in `drift-detection.yml`) for all squad workflows that post issue comments.

### Rules
1. **Triage workflow:** Uses `🏗️ Squad Triage` as the dedup marker. Updates existing triage comment if one exists.
2. **Assign workflow:** Uses `📋 Assigned to {name}` / `🤖 Routed to @copilot` as markers. Updates if same-marker comment exists. **Additionally skips entirely** if triage already posted a comment assigning the same member.
3. **Future workflows** that post issue comments should follow this same pattern.

## Consequences

- No more duplicate comments on issues when labels are toggled
- Existing comments get updated with latest info rather than creating a trail of stale ones
- Slight API overhead (one `listComments` call per workflow run) — negligible
