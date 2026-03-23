# Issue #999: K8s-Native Capability Routing — Quick Reference

## What It Does
Maps GitHub issue `needs:*` labels to Kubernetes node labels for intelligent pod scheduling.

**Before (Bare Metal):**
```
GitHub Issue: "needs:gpu" 
    ↓
Ralph: Check ~/.squad/machine-capabilities.json
    ↓
Schedule task on GPU-capable machine
```

**After (Kubernetes):**
```
GitHub Issue: "needs:gpu"
    ↓
Squad Operator: Read capability-mapping ConfigMap
    ↓
Create pod with nodeSelector: {nvidia.com/gpu: "true"}
    ↓
K8s scheduler: Find node with nvidia.com/gpu=true
    ↓
Pod scheduled on GPU node
```

## Key Components

| Component | File | Purpose |
|-----------|------|---------|
| **DaemonSet** | `infrastructure/k8s/capability-discovery-daemonset.yaml` | Runs on every node; probes & labels capabilities |
| **ConfigMap** | `infrastructure/k8s/capability-mapping-configmap.yaml` | Operator config: maps `needs:*` → K8s labels |
| **KEDA Scaler** | `infrastructure/keda/capability-routing-scaler.yaml` | Auto-scales GPU/browser pools based on demand |

## Label Examples

| GitHub Label | K8s Node Label | Where Set |
|---|---|---|
| `needs:gpu` | `nvidia.com/gpu: "true"` | NVIDIA plugin (automatic) |
| `needs:browser` | `squad.io/capability-browser: "true"` | DaemonSet probe |
| `needs:whatsapp` | `squad.io/capability-whatsapp: "true"` | DaemonSet probe |
| `needs:personal-gh` | `squad.io/capability-personal-gh: "true"` | DaemonSet (secret check) |
| `needs:high-memory` | `squad.io/memory-tier: "high"` | AKS node pool config |

## Design Decisions (Ratified)

✅ **Use node labels** (not pod labels)  
✅ **Hybrid:** Node pool labels (static) + DaemonSet (dynamic)  
✅ **Hard requirements** via `nodeSelector`  
✅ **Namespace:** `squad.io/capability-*`  
✅ **RBAC:** Capability discoverer gets `nodes/patch`  

## Implementation Phases

| Phase | What | Effort | Owner |
|-------|------|--------|-------|
| 1 | Build capability-discoverer image | 1–2w | [TBD] |
| 2 | Operator integration | 1–2w | [TBD] |
| 3 | AKS node pools | 1w | [TBD] |
| 4 | Deploy DaemonSet | 2d | [TBD] |
| 5 | Ralph dual-source checks | 1w | [TBD] |
| 6 | Deprecate legacy code | 1d | [TBD] |

**Total: 4–5 weeks**

## Verify Deployment

```bash
# Check node labels exist
kubectl get nodes --show-labels | grep squad.io

# Check DaemonSet running
kubectl get daemonset -n squad-system squad-capability-discovery

# Test pod scheduling
kubectl run test --image=busybox \
  --overrides='{"spec":{"nodeSelector":{"squad.io/capability-gpu":"true"}}}'
```

## Documentation

- **Full Design:** `docs/k8s-capability-routing.md`
- **Technical Guide:** `docs/squad-on-k8s/capability-routing.md`
- **Decision Record:** `.squad/decisions/issue-999-decision-record.md`
- **Implementation Plan:** `.squad/implementations/issue-999-implementation-guide.md`

## Questions?

See Picard (Lead) or review the design docs above.
