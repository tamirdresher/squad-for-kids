# Issue #999: K8s-Native Capability Routing — Master Index

## Document Map

### 🎯 Start Here (Executive Level)
- **`issue-999-quick-ref.md`** — 2-minute overview + deployment checklist
- **`issue-999-summary.txt`** — Formatted summary for team notification

### 📐 Design & Decisions (Technical Leadership)
- **`issue-999-decision-record.md`** — Ratified decisions with alternatives considered
- **`docs/k8s-capability-routing.md`** — Original design spec (full, detailed)
- **`docs/squad-on-k8s/capability-routing.md`** — Comprehensive technical guide with examples

### 🔧 Implementation (Engineers)
- **`.squad/implementations/issue-999-implementation-guide.md`** — Phased rollout plan with success criteria
- **`infrastructure/k8s/capability-discovery-daemonset.yaml`** — Ready-to-deploy DaemonSet + RBAC
- **`infrastructure/k8s/capability-mapping-configmap.yaml`** — Operator config (needs:* → K8s labels)
- **`infrastructure/keda/capability-routing-scaler.yaml`** — KEDA autoscaling rules

---

## Key Facts at a Glance

| Question | Answer |
|----------|--------|
| **What?** | Map GitHub `needs:*` labels to K8s node labels for pod scheduling |
| **Why?** | Squad's capability-based routing must work natively in Kubernetes |
| **When?** | Design complete; ready for implementation (4–5 weeks) |
| **Who?** | Picard (Lead); Infrastructure & Operator teams own phases 1–6 |
| **How?** | DaemonSet discovers capabilities; Operator injects scheduling constraints |

---

## Design Rationale (TL;DR)

✅ **Node labels** (not pod labels) — capabilities are infrastructure properties  
✅ **Hybrid approach** — static pool labels (fast) + dynamic DaemonSet (responsive)  
✅ **Hard requirements** via `nodeSelector` — `needs:*` labels must be satisfied  
✅ **Namespace** `squad.io/capability-*` — consistent, collision-free  
✅ **ConfigMap-driven** — operator config updatable without redeployment  

---

## Label Mapping at a Glance

```
needs:gpu           → nvidia.com/gpu: "true"              (NVIDIA plugin)
needs:browser       → squad.io/capability-browser: "true" (DaemonSet)
needs:whatsapp      → squad.io/capability-whatsapp: "true" (DaemonSet)
needs:personal-gh   → squad.io/capability-personal-gh: "true" (Secret check)
needs:high-memory   → squad.io/memory-tier: "high"        (Node pool)
```

Full reference: `docs/k8s-capability-routing.md` §2

---

## Implementation Phases (6 Weeks Total)

| Phase | What | Timeline | Owner |
|-------|------|----------|-------|
| 1 | Build `squad/capability-discoverer` image | 1–2w | [Infrastructure] |
| 2 | Integrate with Squad operator | 1–2w | [Operator team] |
| 3 | Create AKS node pools (gpu, browser, highmem) | 1w | [Infrastructure] |
| 4 | Deploy DaemonSet + verify | 2d | [Infrastructure] |
| 5 | Update Ralph for dual-source checks | 1w | [Ralph agent] |
| 6 | Deprecate legacy discovery code | 1d | [Anyone] |

**Next action:** Assign Phase 1

---

## Verification Checklist (Post-Deployment)

```bash
# Phase 4: Verify DaemonSet rolled out
kubectl rollout status daemonset/squad-capability-discovery -n squad-system

# Verify node labels
kubectl get nodes --show-labels | grep squad.io

# Test pod scheduling with GPU requirement
kubectl run test-gpu --image=busybox \
  --overrides='{"spec":{"nodeSelector":{"nvidia.com/gpu":"true"}}}'
kubectl get pod test-gpu -o wide

# Phase 5: Verify Ralph queries K8s labels
# (Manual test with Ralph in K8s env)
```

See `docs/k8s-capability-routing.md` §7 for full testing procedure.

---

## File Manifest

### Kubernetes Manifests (Production-Ready)
```
infrastructure/k8s/
  ├── capability-discovery-daemonset.yaml (DaemonSet + RBAC + ServiceAccount)
  └── capability-mapping-configmap.yaml   (Operator config)

infrastructure/keda/
  └── capability-routing-scaler.yaml      (KEDA ScaledObjects)
```

### Design & Documentation
```
docs/
  ├── k8s-capability-routing.md           (Original design spec)
  └── squad-on-k8s/
      └── capability-routing.md           (Comprehensive guide)

.squad/decisions/
  ├── issue-999-index.md                  (This file)
  ├── issue-999-quick-ref.md              (2-min overview)
  ├── issue-999-summary.txt               (Formatted summary)
  └── issue-999-decision-record.md        (Decisions with rationale)

.squad/implementations/
  └── issue-999-implementation-guide.md   (6-phase rollout plan)
```

---

## FAQ

**Q: Why node labels instead of pod labels?**  
A: Capabilities describe infrastructure (does this node have a GPU?), not workload requirements. Pod labels would be backwards.

**Q: Why DaemonSet + node pool labels?**  
A: DaemonSet alone is slow; node pool labels alone can't detect dynamic capabilities (secrets, mounts). Hybrid is optimal.

**Q: What happens to `discover-machine-capabilities.ps1`?**  
A: Deprecated in Phase 6, but Ralph maintains backward compatibility until all instances are K8s-only.

**Q: Can I skip a phase?**  
A: No — phases are dependent. Phase 2 needs Phase 1's image; Phase 4 needs Phase 3's pools; Phase 5 needs Phase 4's labels.

**Q: What about AKS Automatic?**  
A: Node pool setup works with AKS Automatic; capability discovery is cluster-agnostic (works on any K8s).

---

## Contact & Questions

- **Design questions?** → Review `issue-999-decision-record.md`
- **Implementation blockers?** → Picard (Lead)
- **Operator integration?** → [TBD — Operator team]
- **Infrastructure setup?** → Belanna (Infrastructure Expert)

---

**Last updated:** 2026-03-20  
**Status:** ✅ Design Complete, Ready for Implementation
