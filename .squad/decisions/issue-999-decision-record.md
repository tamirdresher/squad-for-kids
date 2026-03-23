# Decision Record: Issue #999 — K8s-Native Capability Routing

**Issue:** [#999](https://github.com/tamirdresher_microsoft/tamresearch1/issues/999)  
**Decision Owner:** Picard (Lead)  
**Date:** 2026-03-20  
**Status:** APPROVED

---

## Problem Statement

Squad routes GitHub issues with `needs:*` labels (e.g., `needs:gpu`, `needs:browser`) to machines with specific hardware/software capabilities. On bare metal, Ralph probes machine capabilities via `discover-machine-capabilities.ps1` and stores them in a JSON manifest.

In Kubernetes, this must map to **node labels and pod scheduling constraints**. A pod needing a GPU should request `nodeSelector: nvidia.com/gpu: "true"`. The design integrates this fully with K8s primitives.

---

## Decision: Use K8s Node Labels + DaemonSet Discovery

### Design Choice: Infrastructure Labels (Not Pod Labels)

**Chosen:** Node labels  
**Rationale:**
- Capabilities are **properties of infrastructure**, not workloads
- A node either has a GPU (hardware-defined) or doesn't
- Node labels enable correct scheduling across all workloads
- Aligns with K8s ecosystem practices (NodeFeatureDiscovery, NVIDIA plugin)

**Alternative rejected:** Pod labels would require workloads to declare their capabilities, which is backwards — infrastructure should declare what it offers, workloads declare what they need.

---

### Design Choice: Hybrid DaemonSet + Node Pool Labels

**Chosen:** Static capabilities via node pool labels + dynamic capabilities via DaemonSet  
**Rationale:**
- **Node pool labels** (set at AKS pool creation) — GPU, memory tier, disk type (static, rarely change)
- **DaemonSet labels** — Software/credential capabilities (dynamic, change frequently)
  - Browser/Playwright installed
  - GitHub token secrets present
  - WhatsApp session available
  - OneDrive mount available

| Approach | Pros | Cons | Chosen |
|----------|------|------|--------|
| DaemonSet only | Auto-detects; responsive | Overhead; startup delay | ❌ |
| Manual labeling | Simple; no overhead | Drifts; human error | ❌ |
| **Hybrid** | **Fast (pool labels) + responsive (DaemonSet)** | **Slightly complex** | ✅ |

**Alternative rejected:** DaemonSet-only would incur unnecessary overhead on GPU/memory nodes that don't need runtime probes.

---

### Design Choice: Hard Requirements (`nodeSelector`) vs Soft Preferences (`affinity`)

**Chosen:**
- `needs:*` labels → **hard requirements** (`nodeSelector`)
  - Pod stays `Pending` if no matching node exists
  - Blocking; accurate for capabilities without fallbacks
  
- `prefers:*` labels (future) → **soft preferences** (`nodeAffinity`, weighted)
  - Pod will schedule on any node if preferred nodes unavailable
  - Non-blocking; for "nice to have" capabilities

**Rationale:**
- Current Squad label system only has hard requirements
- Soft preferences can be added in Phase 2 with graduated weights (100 = strong, 50 = moderate, 20 = weak)
- Aligns with K8s semantics: "needs" = required, "prefers" = optional

**Alternative rejected:** All pods soft? No — some capabilities (GPU, WhatsApp session) are truly required for specific work.

---

### Design Choice: Label Namespace

**Chosen:** `squad.io/capability-*` for all Squad-managed labels  
**Rationale:**
- Avoids collisions with ecosystem labels
  - `nvidia.com/*` — NVIDIA device plugin
  - `kubernetes.io/*` — K8s built-ins
  - `node.kubernetes.io/*` — Node feature discovery
  - `beta.kubernetes.io/*` — Legacy K8s
- Consistent prefix makes it easy to search, audit, and policy-control all Squad labels
- Follows Kubernetes label naming conventions (domain/key format)

**Example:** `squad.io/capability-browser=true`, `squad.io/memory-tier=high`, `squad.io/storage-tier=ssd`

---

### Design Choice: RBAC Scope

**Chosen:** Capability discoverer gets `nodes/patch` permission  
**Rationale:**
- Minimal necessary permission to update labels
- Scoped to single ServiceAccount in `squad-system` namespace
- Production hardening: future admission webhook to restrict patching to only `squad.io/*` labels

**Security note:** Broad permission; monitor usage. Phase 2 will add webhook validation.

---

## Label Mapping Table

| GitHub Issue Label | K8s Node Label | Source |
|-------------------|-----|--------|
| `needs:gpu` | `nvidia.com/gpu: "true"` | NVIDIA device plugin (automatic) |
| `needs:browser` | `squad.io/capability-browser: "true"` | Capability DaemonSet |
| `needs:whatsapp` | `squad.io/capability-whatsapp: "true"` | Capability DaemonSet |
| `needs:azure-speech` | `squad.io/capability-azure-speech: "true"` | Capability DaemonSet |
| `needs:personal-gh` | `squad.io/capability-personal-gh: "true"` | Capability DaemonSet (secret mount) |
| `needs:emu-gh` | `squad.io/capability-emu-gh: "true"` | Capability DaemonSet (secret mount) |
| `needs:teams-mcp` | `squad.io/capability-teams-mcp: "true"` | Capability DaemonSet |
| `needs:onedrive` | `squad.io/capability-onedrive: "true"` | Capability DaemonSet (mount check) |
| `needs:high-memory` | `squad.io/memory-tier: "high"` | Node pool labels (AKS) |
| `needs:ssd` | `squad.io/storage-tier: "ssd"` | Capability DaemonSet (disk probe) |

---

## Implementation Strategy: Phased Rollout

| Phase | Deliverable | Duration | Blocker |
|-------|-------------|----------|---------|
| 1 | Capability-discoverer image | 1–2w | None |
| 2 | Operator integration | 1–2w | Phase 1 |
| 3 | AKS node pool setup | 1w | Phase 2 |
| 4 | DaemonSet deployment & verification | 2d | Phase 3 |
| 5 | Ralph dual-source capability checks | 1w | Phase 4 |
| 6 | Deprecate `discover-machine-capabilities.ps1` | 1d | Phase 5 |

**Total estimated effort:** 4–5 weeks

---

## Ratified Decisions

1. ✅ **Node labels** carry capability metadata (not pod labels)
2. ✅ **Hybrid approach:** Node pool labels (static) + DaemonSet (dynamic)
3. ✅ **Hard requirements** via `nodeSelector`; future **soft preferences** via `affinity`
4. ✅ **Namespace:** `squad.io/capability-*` for all Squad labels
5. ✅ **RBAC:** Capability discoverer gets `nodes/patch` (Phase 2: add admission webhook)
6. ✅ **Label values:** Boolean strings (`"true"`/`"false"`), not structured data
7. ✅ **ConfigMap-driven:** Operator reads capability mapping from ConfigMap for easy updates

---

## Future Enhancements (Phase 2+)

- **Label versioning:** e.g., `squad.io/capability-browser: "playwright-1.41"` instead of just `"true"`
- **Admission webhook:** Validate that only `squad.io/*` labels are patched by capability-discoverer
- **Pod anti-affinity:** Spread Ralph replicas across nodes to avoid SPOF
- **Preferred affinity:** Introduce `prefers:*` labels for soft scheduling hints
- **Capability versioning:** Track when capabilities change (for auditing)
- **Cost attribution:** Tag pods with node pool cost class (for FinOps)

---

## Approval

| Role | Status | Comment |
|------|--------|---------|
| Picard (Lead) | ✅ APPROVED | Design is solid, phased approach is realistic |
| B'Elanna (Infrastructure) | ✅ APPROVED | Node pool strategy aligns with AKS best practices |
| Team (via design doc review) | ✅ APPROVED | Design docs in `docs/` ready for implementation |

---

**Next step:** Assign Phase 1 (capability-discoverer image) and proceed.
