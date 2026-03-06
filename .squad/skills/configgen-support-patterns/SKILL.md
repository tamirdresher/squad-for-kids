---
name: "configgen-support-patterns"
description: "Recurring support patterns from ConfigGen SDK - Support channel"
domain: "configgen-operations"
confidence: "high"
source: "teams-channel-learning"
learned_from: "ConfigGen SDK – Support"
first_seen: "2026-07-04"
---

## Context
These patterns were extracted from the ConfigGen SDK - Support channel in the Infra and Developer Platform Community team. They represent the most common recurring issues that ConfigGen consumers encounter.

## Patterns

### SFI Enforcement Breaking Builds
**Trigger:** ConfigGen package update introduces security enforcement (SFI-NS3.2.1, NAT Gateway requirements) that turns previously passing builds into fatal errors.
**Root cause:** Enforcement transitions from permissive → required without adequate advance warning to consumers.
**Resolution:** Check ConfigGen release notes for enforcement changes. Use `SuppressValidation` flags where available as temporary mitigation. File issue if enforcement is premature for your scenario.
**Key insight:** Platform behavior changes faster than consumer understanding. Enforcement rollouts need advance communication.

### Auto-Generated Config Causing Deployment Failures
**Trigger:** EV2 deployment fails with duplicate resource errors (e.g., duplicate role assignments).
**Root cause:** ConfigGen auto-generates `AuthorizationRoleAssignmentArray` and other sections. When Managed Identity is reused across services, duplicates appear.
**Resolution:** Check for auto-generated sections that conflict with explicit configuration. Request opt-out mechanism if auto-generation is inappropriate for your scenario.
**Key insight:** Teams struggle when ConfigGen adds behavior rather than requiring opt-in.

### Modeling Gaps (Azure Features ConfigGen Cannot Express)
**Trigger:** Team needs to use an Azure feature that ConfigGen doesn't model.
**Common gaps identified:**
- Per-table Log Analytics retention (only workspace-level supported)
- Synapse workspace without Managed Virtual Network
- Azure Front Door (partial support only)
- AAD nested group membership with TeamSecurityGroup
**Resolution:** Use manual ARM templates or hybrid approaches for unsupported scenarios. File ConfigGen feature request with PR-based repro.
**Key insight:** ConfigGen is strong for golden paths but repeatedly hits edge cases where Azure supports something ConfigGen cannot model.

### CI/CD Validation Gaps
**Trigger:** Config regressions reach production because ConfigGen tests don't validate AppSettings.
**Root cause:** ConfigGen validation focuses on infrastructure resource declarations, not application configuration values.
**Resolution:** Add custom validation tests for AppSettings in consumer CI pipeline. Don't rely solely on ConfigGen's built-in validation.
**Frequency:** Bi-weekly.

### PR Review Bottleneck
**Trigger:** PRs waiting days for ConfigGen team review/approval.
**Root cause:** ConfigGen is a shared dependency with a narrow reviewer set.
**Impact:** Creates friction and deployment latency for consuming teams.
**Mitigation:** Tag specific reviewers, escalate in DK8S Leads channel if blocked > 2 days.

## Anti-Patterns
- **Upgrading ConfigGen packages without reading release notes** — Enforcement changes are documented but often missed.
- **Assuming auto-generated config is always correct** — Review generated output, especially for identity and networking sections.
- **Filing support questions without a PR-based repro** — The ConfigGen team expects reproducible configuration examples.
- **Waiting silently for PR reviews** — Proactively ping in the support channel after 1 business day.
