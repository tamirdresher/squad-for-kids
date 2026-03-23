# Decision: K8s-Native Capability Routing Architecture

**Date:** 2026-03-21  
**Author:** Picard (Lead)  
**Status:** Proposed (awaiting B'Elanna review)  
**Issue:** #999  
**PR:** #1286

## Context

Squad's current capability routing uses file-based discovery (`~/.squad/machine-capabilities.json`) and Ralph's PowerShell functions to match issues to machines. When moving to Kubernetes, we need a K8s-native approach that leverages the scheduler's built-in primitives.

## Decision

Use **K8s node labels** and **pod scheduling constraints** for capability routing:

1. **Label Mapping:** GitHub `needs:*` labels map directly to K8s node labels
   - `needs:gpu` → `nvidia.com/gpu=true`
   - `needs:browser` → `squad.io/capability-browser=true`
   - `needs:whatsapp` → `squad.io/capability-whatsapp=true`

2. **Capability Discovery DaemonSet:** Runs on every node, probes for capabilities, applies labels via K8s API
   - Rescans every 5 minutes
   - Removes labels when capabilities are lost
   - Requires `nodes/patch` RBAC permission

3. **Pod Scheduling:** Squad operator translates issue labels to `nodeSelector` constraints
   - Hard requirements: `nodeSelector` (pod stays Pending if unsatisfied)
   - Soft preferences (future): `nodeAffinity.preferred...`

4. **AKS Node Pools:** Specialized pools with static + dynamic labels
   - GPU pool: `Standard_NC6s_v3` (0-3 nodes, tainted)
   - Browser pool: `Standard_D4s_v5` (1-10 nodes, Playwright)
   - General pool: `Standard_D2s_v5` (2-20 nodes, default)

5. **Migration Path:** Hybrid mode
   - Ralph checks `$env:KUBERNETES_SERVICE_HOST` to choose K8s labels or JSON manifest
   - Phases: DaemonSet deploy → Operator update → Node pools → Test → Deprecate JSON

## Rationale

- **Why node labels over ConfigMaps?** Capabilities are infrastructure properties — the K8s scheduler natively understands node labels for scheduling decisions.
- **Why DaemonSet over manual labeling?** Automated discovery catches drift, scales across clusters, and removes human error.
- **Why `squad.io/` namespace?** Avoids collisions with other operators and vendor labels.
- **Why hard requirements only (Phase 1)?** Simplifies MVP. Soft preferences are a future enhancement.

## Consequences

**Benefits:**
- First-class K8s integration (scheduler understands capabilities)
- Eliminates file-based state (`~/.squad/machine-capabilities.json`)
- Automated discovery via DaemonSet (no manual node labeling)
- Scales across multi-cluster deployments
- Clear migration path (hybrid mode during transition)

**Risks:**
- DaemonSet requires `nodes/patch` permission (sensitive — audit regularly)
- Label drift if DaemonSet fails (mitigated by 5min rescan)
- Node pool design must be coordinated with Helm chart (#1000)

**Open Questions (to resolve with B'Elanna):**
1. DaemonSet image: Build from scratch or extend existing K8s tooling image?
2. Secret presence detection: How to handle secrets added after node startup?
3. Capability versioning: Should labels carry versions (e.g., `playwright-1.41`) or just boolean?

## Team Impact

- **B'Elanna (Infrastructure):** Owns implementation — DaemonSet image, RBAC, node pool creation
- **Data (Code Expert):** Squad operator changes (Golang reconciler label mapping)
- **Ralph (Work Monitor):** Hybrid mode support in PowerShell (K8s vs JSON manifest)
- **Worf (Security):** RBAC audit (ClusterRoleBinding for `nodes/patch`)

## References

- **Design Doc:** `docs/k8s-capability-routing-design.md`
- **Issue:** #999
- **PR:** #1286 (draft)
- **Related Issues:** #987 (predecessor), #1000 (Helm chart), #995 (non-human testing)
