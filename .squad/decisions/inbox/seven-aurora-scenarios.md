# Decision Proposal: Aurora Scenario Prioritization for DK8S

**Date:** 2026-03-07  
**Author:** Seven (Research & Docs)  
**Status:** Proposed  
**Scope:** Testing & Validation Strategy  
**Related:** Issue #4, aurora-scenario-catalog.md, aurora-research.md, dk8s-stability-analysis.md

---

## Proposal

Adopt a 12-scenario Aurora validation catalog for DK8S, organized in three priority tiers, with a phased 20-week implementation starting with Aurora Bridge integration (zero test rewriting) and culminating in Deployment Integrated Validation (DIV) quality gates.

## Key Decisions Required

### 1. Start with Cluster Provisioning (SC-001) as First Native Experiment

**Rationale:** Tamir requested this directly. Cluster provisioning is a P0 control-plane workload that is well-suited to Aurora's scenario structure — discrete operations, clear success criteria, measurable timing. DK8S currently has **no structured provisioning baseline**, so the first Aurora runs establish the baseline.

**Impact on rollout velocity:** Aurora experiments run *parallel* to existing pipelines, not in the critical path. Bridge and control-plane workloads validate after deployment, not before (until DIV integration in Phase 4). No component change or rollout velocity impact in Phases 1–3.

### 2. Use Bridge for ConfigGen (SC-005) as Immediate Win

**Rationale:** Aurora Bridge connects existing ADO pipelines to Aurora with zero test rewriting. ConfigGen's ADO pipeline can be the first Bridge-connected workload, providing Aurora's ICM integration, historical analysis, and alerting on top of existing tests.

### 3. Prioritize Data-Plane Workloads for Confirmed Incidents

**Rationale:** B'Elanna's stability analysis identified 5 confirmed Sev2 incidents. SC-006 (NAT Gateway Resilience) and SC-007 (DNS Under Load) directly address the #1 and #2 outage drivers. These require Chaos Studio integration and long-haul execution — higher effort but highest impact.

### 4. Defer DIV Integration to Phase 4

**Rationale:** DIV integration (gating deployments on Aurora results) adds Aurora to the critical path. This should only happen after confidence is established through Phases 1–3. Premature DIV integration risks slowing rollouts without validated quality signal.

## Consequences

- ✅ Establishes structured validation baseline where none exists today
- ✅ Directly addresses confirmed Sev2 incident patterns
- ✅ Early voluntary adoption gives DK8S a head start if DIV becomes mandatory (S360 KPI)
- ✅ Bridge integration provides immediate value with zero test rewriting
- ⚠️ Custom workload development required (~8 weeks) — Aurora has no K8s-native scenarios out of box
- ⚠️ Aurora currently limited to East US and West US2 for control-plane simulations
- ⚠️ Matrix explosion (72 combinations for SC-001 alone) requires disciplined core/extended/full strategy

## Team Input Needed

1. Confirm cluster provisioning as the first native experiment
2. Approve .NET SDK project creation for Aurora.DK8S.Scenarios assembly
3. Identify Azure subscription + quota for Aurora test runs
4. Decide on ICM routing for Aurora-generated incidents (DK8S service tree node)
