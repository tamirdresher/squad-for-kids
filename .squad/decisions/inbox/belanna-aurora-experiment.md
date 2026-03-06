# Decision Proposal: Aurora Cluster Provisioning Experiment

**Author:** B'Elanna Torres (Infrastructure Expert)  
**Date:** 2026-03-07  
**Status:** Proposed  
**Scope:** DK8S Cluster Provisioning Validation  
**Related:** Issue #4, `aurora-cluster-provisioning-experiment.md`

---

## Proposed Decision

Run a 12-week phased Aurora experiment targeting DK8S cluster provisioning on 2–3 non-production clusters (DEV/TEST in EUS2 + SEC). Start monitoring-only (zero pipeline impact), graduate to enhanced telemetry, then evaluate gating.

## Rationale

1. **Cluster provisioning has no E2E validation today** — clusters pass pipeline checks but can be "provisioned but unhealthy" (confirmed via Sev2 incidents)
2. **Aurora Bridge integrates without pipeline changes** — manifest-based onboarding, no YAML modifications, no added latency in monitoring mode
3. **Monitoring-only mode is explicitly supported** — `CreateIcM = false` configuration documented in Aurora guides
4. **Known failure modes are not systematically tracked** — 9 documented failure patterns (from stability analysis) with no automated categorization

## Impact Assessment

- **Monitoring-only (Phase 1):** Zero latency impact, zero pipeline changes
- **Enhanced telemetry (Phase 2):** <2 min addition (result emission step)
- **Gating mode (Phase 3, DEV only):** +5–10 min validation gate
- **Component rollouts:** Zero impact at any phase (experiment scoped to provisioning only)

## Investment

~15–20 person-days over 12 weeks. Phase 1 (weeks 1–4) requires ~5 person-days total.

## Decision Requested

- [ ] Approve experiment scope and timeline
- [ ] Identify Aurora team contact for onboarding
- [ ] Select specific DEV/TEST clusters from inventory
- [ ] Assign DRI for experiment execution

## Consequences

- ✅ First structured provisioning quality data for DK8S
- ✅ Automated failure categorization (infra vs. config vs. platform)
- ✅ Regression baseline for provisioning quality
- ⚠️ Requires Aurora team engagement (external dependency)
- ⚠️ Phase 2 requires pipeline owner buy-in for result emission
