# Decision Proposal: Azure Fleet Manager Adoption for DK8S RP

**Author:** Picard (Lead)  
**Date:** 2026-03-07  
**Status:** Proposed  
**Impact:** High  
**Issue:** #3

---

## Decision

**DEFER** adoption of Azure Kubernetes Fleet Manager (AKFM) for DK8S RP.

Do not adopt now. Establish prerequisites for future adoption (H2 2026 or later).

## Context

Azure Fleet Manager was evaluated as a potential replacement/complement to DK8S's current multi-cluster management stack (ArgoCD + EV2 + ConfigGen). The evaluation covered AKFM capabilities, open-source alternatives (Rancher Fleet, KubeFleet, Kratix, Karmada), internal team discussions (Feb 12 & Feb 18 meetings), and identity/FIC blockers (Sept 2025 email thread).

## Rationale

1. **Identity is a hard blocker.** Workload Identity / FIC automation is unresolved. Fleet Manager amplifies identity brittleness when moving workloads across clusters. Team consensus from Feb 12 meeting: "identity binding is a block here."

2. **ROI unclear today.** ArgoCD + EV2 + ConfigGen handles current multi-cluster deployment needs. Fleet Manager's unique value (cluster replacement, blue/green) is not an operational need yet.

3. **Dual control plane risk.** Running Fleet Manager alongside ArgoCD creates competing reconciliation, ambiguous source of truth, and operational complexity the team flagged as "overkill."

4. **No better alternative exists.** Among OSS options evaluated, none provides a better fit than AKFM for DK8S when the time comes. Rancher Fleet (too much Rancher coupling), Kratix (different problem space), KubeFleet (too early). ArgoCD remains right for app delivery.

## Prerequisites for Revisiting

| # | Prerequisite | Status |
|---|-------------|--------|
| 1 | Workload Identity migration complete | In Progress |
| 2 | FIC automation validated | Blocked |
| 3 | Cluster replacement becomes operational need | Not yet |
| 4 | Fleet vs. ArgoCD swim lanes defined | Not started |
| 5 | EV2 + Fleet integration prototyped | Not started |

## Immediate Actions

- Track AKFM roadmap (sovereign cloud, ArgoCD integration)
- Resolve identity blockers independently of Fleet decision
- Time-boxed PoC when prerequisites 1-2 met

## Consequences

- ✅ Avoids premature complexity in an already-functioning deployment stack
- ✅ Preserves team focus on identity/FIC resolution (higher priority)
- ✅ Keeps AKFM as a viable future option with clear adoption criteria
- ⚠️ Delays potential cluster upgrade automation improvements
- ⚠️ Blue/green cluster replacement remains unavailable

## Full Analysis

See: `fleet-manager-evaluation.md`
