# Issue #999: K8s-Native Capability Routing — Implementation Guide

**Status:** Design Complete; Implementation Started  
**Issue:** [#999](https://github.com/tamirdresher_microsoft/tamresearch1/issues/999)  
**Author:** Picard (Squad Lead)  
**Date:** 2026-03-20

---

## Overview

This document outlines the implementation status and remaining work for K8s-native capability routing — mapping GitHub issue `needs:*` labels to K8s node labels and pod scheduling constraints.

## What Has Been Delivered

### Design Documents (Complete)
- ✅ `docs/k8s-capability-routing.md` — Full design spec with architecture rationale
- ✅ `docs/squad-on-k8s/capability-routing.md` — Detailed technical guide with examples

### Kubernetes Manifests (Ready for Deployment)
- ✅ `infrastructure/k8s/capability-discovery-daemonset.yaml` — DaemonSet + RBAC + ServiceAccount
  - Runs on every K8s node to probe and label capabilities
  - Requires `squad/capability-discoverer` image implementation
  
- ✅ `infrastructure/k8s/capability-mapping-configmap.yaml` — Operator config
  - Maps `needs:*` GitHub labels to K8s node selectors
  - Node pool recommendations for AKS
  - Can be updated without redeploying operator

- ✅ `infrastructure/keda/capability-routing-scaler.yaml` — KEDA ScaledObjects
  - Auto-scales GPU and browser node pools based on pending pod demand
  - Part of cost optimization for on-demand workloads

## What Needs to Be Done (Implementation Phases)

### Phase 1: Capability Discoverer Image (Blocking)
**Owner:** [TBD — Infrastructure Team / Belanna]  
**Effort:** 1-2 weeks

Create the `squad/capability-discoverer` container image that:
1. **Detects browser capability** — Check if Playwright/Chromium is installed
2. **Detects WhatsApp session** — Check for mounted WhatsApp session files
3. **Detects Azure Speech SDK** — Check for SDK or API key availability
4. **Detects GitHub tokens** — Check for mounted secrets (personal-gh, emu-gh)
5. **Detects Teams MCP** — Check for MCP config presence
6. **Detects OneDrive mount** — Check for FUSE mount point
7. **Classifies memory tier** — Query node allocatable memory and classify (low/standard/high)
8. **Patches node labels** — Use K8s API to update node labels with `squad.io/*` prefix
9. **Periodic rescanning** — Re-probe every 300 seconds to detect changes
10. **Health probes** — Expose `/healthz` and `/readyz` endpoints (port 8081)

**Pseudocode reference:** See `docs/k8s-capability-routing.md` §3.2 "Discovery Logic"

### Phase 2: Squad Operator Integration
**Owner:** [TBD — Operator Development]  
**Effort:** 1-2 weeks  
**Blocked by:** Phase 1 (capability-discoverer image)

Modify the Squad operator to:
1. **Load capability mapping** — Read `capability-mapping` ConfigMap at startup
2. **Parse GitHub labels** — Extract `needs:*` labels from SquadRound CR
3. **Inject pod spec** — Build nodeSelector, tolerations, and resource limits from mapping
4. **Apply affinity** — For future `prefers:*` labels, inject preferred affinity rules
5. **Add KEDA labels** — Label pod with `squad.io/needs-{capability}=true` for KEDA triggers

**Example logic:** See `docs/k8s-capability-routing.md` §5.3 "Squad Operator: Injection Logic"  
**ConfigMap reference:** `infrastructure/k8s/capability-mapping-configmap.yaml`

### Phase 3: AKS Node Pool Setup
**Owner:** [TBD — Infrastructure / Belanna]  
**Effort:** 1 week  
**Blocked by:** Phase 2 (operator must be ready to schedule pods)

Deploy AKS node pools:
```bash
# See infrastructure/k8s/capability-mapping-configmap.yaml for pool definitions
az aks nodepool add \
  --cluster-name aks-squad-prod \
  --resource-group rg-squad-prod \
  --name generalpool \
  --node-vm-size Standard_D4s_v5 \
  --node-count 2 \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 10 \
  --labels squad.io/capability-general=true

# GPU pool (scale-to-zero)
az aks nodepool add \
  --cluster-name aks-squad-prod \
  --resource-group rg-squad-prod \
  --name gpupool \
  --node-vm-size Standard_NC4as_T4_v3 \
  --node-count 0 \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 3 \
  --labels squad.io/capability-gpu=true \
  --node-taints nvidia.com/gpu=true:NoSchedule
```

See `docs/k8s-capability-routing.md` §6 "AKS Node Pool Configuration" for all commands.

### Phase 4: Capability DaemonSet Deployment
**Owner:** [TBD — Infrastructure / Belanna]  
**Effort:** 1-2 days  
**Blocked by:** Phases 1–3

Deploy the DaemonSet and verify:
```bash
kubectl apply -f infrastructure/k8s/capability-discovery-daemonset.yaml
kubectl apply -f infrastructure/k8s/capability-mapping-configmap.yaml
kubectl apply -f infrastructure/keda/capability-routing-scaler.yaml

# Verify DaemonSet rolled out on all nodes
kubectl rollout status daemonset/squad-capability-discovery -n squad-system

# Check node labels
kubectl get nodes --show-labels | grep squad.io
```

See `docs/k8s-capability-routing.md` §7 "Testing Capability Routing" for verification steps.

### Phase 5: Ralph Integration & Migration
**Owner:** [TBD — Ralph Agent / Scheduling]  
**Effort:** 1 week  
**Blocked by:** Phase 4 (DaemonSet must be labeling nodes)

Update Ralph to:
1. **Dual-source capability checks** — Query both K8s node labels (if in-cluster) and `machine-capabilities.json` (if bare metal)
2. **Prefer K8s queries** — If `$env:KUBERNETES_SERVICE_HOST` is set, use `kubectl get node` to check capabilities
3. **Backward compatibility** — Fall back to JSON manifest for local machine capability checks

**Reference:** See `docs/k8s-capability-routing.md` §7 "Migration Path" for backward compat strategy.

### Phase 6: Deprecation & Cleanup
**Owner:** [TBD]  
**Effort:** 1 day  
**Blocked by:** Phase 5

Once all Ralph instances use K8s labeling:
1. **Deprecate** `discover-machine-capabilities.ps1` — Mark as legacy
2. **Remove** JSON manifest fallback from Ralph (Phase 6+)
3. **Archive** machine-capabilities documentation

---

## Design Decisions Ratified

| Decision | Status | Reference |
|----------|--------|-----------|
| Use **node labels** (not pod labels) for capabilities | ✅ Approved | §8.1 |
| Use **DaemonSet + node pool labels (hybrid)** | ✅ Approved | §8.2 |
| Hard requirements via `nodeSelector`; soft via `affinity` | ✅ Approved | §8.3 |
| Namespace: `squad.io/capability-*` for all Squad labels | ✅ Approved | §8.4 |
| RBAC: Capability discoverer gets `nodes/patch` permission | ✅ Approved | §6 |

---

## Open Questions & Future Enhancements

### Q1: Label Versioning
Should labels carry version info? e.g., `squad.io/capability-browser: "playwright-1.41"` vs just `"true"`?  
**Decision:** Defer to Phase 2. For now, use boolean `"true"`/`"false"`.

### Q2: Capability Removal Logic
When a capability is lost (e.g., GitHub token expires), the DaemonSet must actively **remove** the label.  
**Implementation:** Use `kubectl label node ... squad.io/capability-personal-gh-` (trailing dash removes label).

### Q3: DaemonSet Image Strategy
Build from scratch or extend `bitnami/kubectl`?  
**Decision:** Custom minimal image with required probe scripts. Size ~50–100 MB.

### Q4: Secret Presence Detection
How does DaemonSet detect mounted secrets?  
**Implementation:** Projected volumes in DaemonSet spec mount secrets with `optional: true`. Check if file exists in `/run/secrets/`.

### Q5: Pod Anti-Affinity for Multi-Replica Agents
Ralph runs multiple replicas. Should we spread them across nodes?  
**Future work:** Add `podAntiAffinity` rules (§2.4). Not in Phase 1.

---

## Success Criteria

- [ ] Phase 1: Capability-discoverer image built and pushed to ACR
- [ ] Phase 2: Operator updated and tested with sample SquadRound CRs
- [ ] Phase 3: AKS node pools created with correct labels and taints
- [ ] Phase 4: DaemonSet deployed; nodes are correctly labeled
- [ ] Phase 5: Ralph queries K8s labels; backward compat works
- [ ] Phase 6: `discover-machine-capabilities.ps1` deprecated in code

Verification:
```bash
# Nodes should have squad.io and nvidia.com labels
kubectl get nodes --show-labels | grep -E "squad.io|nvidia.com"

# Pods should schedule correctly
kubectl run test-pod --image=busybox \
  --overrides='{"spec":{"nodeSelector":{"squad.io/capability-gpu":"true"}}}'
kubectl get pod test-pod -o wide
```

---

## Related Issues

- **#987** — Machine capability discovery (predecessor; replaced by K8s labels)
- **#994** — Squad-on-K8s architecture (parent design)
- **#1000** — Squad Helm chart (coordinates secret/node pool management)
- **#995** — Test Squad-on-K8s with non-human user
- **#1159** — AKS Automatic compatibility

---

## Summary

**The design is complete and ratified.** Implementation is organized into 6 phases:
1. Build capability-discoverer image
2. Integrate into Squad operator
3. Create AKS node pools
4. Deploy DaemonSet and verify
5. Update Ralph with dual-source capability checks
6. Deprecate and clean up legacy code

**Estimated total effort:** 4–5 weeks  
**Blockers:** None (design-ready)  
**Next step:** Assign Phase 1 (capability-discoverer image) to infrastructure team.
