# Decision Proposal: RP Registration Escalation Strategy

**Date:** 2026-03-08
**Author:** Picard (Lead)
**Status:** Proposed
**Scope:** RP Registration / Platform Dependencies
**Related:** Issue #11, IcM 757549503

## Decision

Escalate the Cosmos DB role assignment failure (IcM 757549503) blocking Private.BasePlatform RP registration through RPaaS IST Office Hours, and request a manual workaround to unblock registration while the automation bug is fixed.

## Context

- IcM 757549503 is a Sev 3 incident: Cosmos DB role assignment failure blocks RP manifest rollout
- Root cause is a `NullReferenceException` in `CosmosDbRoleAssignmentJob` — a bug on the RPaaS platform side
- Related IcM 754149871 indicates this may be a broader Cosmos DB role assignment issue
- The incident has been in "New" state since 2026-03-06 with no resolution
- Our RP registration pipeline is completely blocked at this step

## Proposed Actions

1. **Escalate at RPaaS IST Office Hours** — present the blocking issue with both IcM references
2. **Request manual Cosmos DB role assignment** — ask RPaaS DRI if they can manually complete the step
3. **Verify all prerequisites** — confirm PC Code, Profit Center Program ID, ServiceTree ID, and subscription are correct before re-attempting
4. **If unblocked within 2 weeks:** proceed with RP registration PUT, Operations RT, and manifest checkin
5. **If still blocked after 2 weeks:** escalate to Sev 2 or reach out to ARM-Extensibility leads directly

## Consequences

- ✅ Unblocks RP registration pipeline
- ✅ Establishes relationship with RPaaS DRI team
- ✅ Documents the dependency for future reference
- ⚠️ Manual workaround may need to be repeated if automation isn't fixed
- ⚠️ Timeline depends on external team responsiveness

## Alternatives Considered

1. **Wait for automated fix** — rejected because timeline is unknown and RP registration is on critical path
2. **Private RP path** — considered but adds complexity; standard Hybrid RP onboarding is preferred
3. **Direct RP exception** — rejected because Hybrid RP is the correct model and doesn't require exception
