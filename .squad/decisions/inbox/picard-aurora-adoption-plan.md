# Decision: Aurora Adoption Plan for DK8S

**Author:** Picard (Lead)
**Date:** 2026-03-07
**Issue:** #4
**Status:** Proposed
**Requested by:** Tamir Dresher

## Decision

Adopt Aurora as DK8S's E2E validation platform through a 4-phase plan, starting with a cluster provisioning experiment in monitoring-only mode.

## Context

- Aurora is Microsoft's E2E validation platform for Azure (not config management — Seven confirmed this)
- DK8S has no structured E2E validation, resiliency testing, or deployment-integrated quality gates
- B'Elanna identified 4 systemic stability areas: networking (NAT Gateway), Istio mesh, upgrade blast radius, ConfigGen complexity
- Tamir asked: "Can we experiment on cluster provisioning? Will it make rollouts slower?"

## Key Points

1. **Cluster provisioning is the right first experiment** — clear success criteria, high blast radius, no cross-team dependencies, addresses known provisioning validation gaps
2. **Aurora will NOT slow deployments if structured correctly** — validation runs during existing EV2 bake time between rings, adding zero net latency in monitoring mode
3. **4-phase plan:** Phase 0 (design, now) → Phase 1 (Bridge, month 1-2) → Phase 2 (custom workloads + DIV, month 3-5) → Phase 3 (resiliency, month 6-8) → Phase 4 (full matrix + gating, month 9-12)
4. **Gating mode only in Phase 4**, only for critical scenarios, only after 30-day burn-in with zero false positives
5. **Rollback is straightforward** at every phase — Aurora is additive, not structural

## Artifacts

- `aurora-adoption-plan.md` — full plan with scenario framework, templates, experiment design, impact analysis
- Scenario definition template (YAML) for DK8S operations
- DK8S-to-Aurora scenario mapping covering: cluster provisioning, component deployment, ConfigGen, networking, Istio

## Risks

- Custom workload development requires .NET SDK (DK8S team is Go-native)
- No existing Aurora-DK8S integration in org (we're establishing new ground)
- False positive risk if gating is enabled prematurely

## Next Steps

1. Attend Aurora office hours with experiment proposal
2. Request Aurora subscription and service principals
3. Scaffold workload repo and implement first scenario
4. Configure Aurora Bridge for one OneBranch pipeline
