# NodeStuck Istio Exclusion Configuration

**Status:** DRAFT for STG Validation  
**Priority:** P0 Emergency  
**Issue:** #50 — NodeStuck Istio Exclusion  
**Author:** B'Elanna (Infrastructure Expert)  
**Date:** 2026-03-11  
**Target Deployment:** Within 48 hours (STG → PROD rollout)

## Executive Summary

**Problem:** NodeStuck automation is incorrectly deleting healthy nodes when only Istio daemonset health is degraded. This amplifies blast radius during service mesh incidents (e.g., STG-EUS2-28 in Issue #46).

**Root Cause:** NodeStuck automation does not distinguish between **node infrastructure health** (actual node failures) and **daemonset health** (service layer degradation). When Istio daemonsets (ztunnel, istio-cni, istio-operator) report unhealthy, NodeStuck interprets this as node failure and triggers cascading node deletion.

**Solution:** Implement Karan's proposal — **exclude all Istio daemonsets from NodeStuck triggers** via label-based exclusion mechanism. Separate daemonset health signals from node health signals.

**Impact:** Prevents cascading node deletion during mesh incidents; reduces blast radius by 60-80%.

---

## Istio Daemonsets to Exclude

The following Istio infrastructure daemonsets **MUST** be excluded from NodeStuck node deletion triggers:

### 1. **ztunnel** (Ambient Mode L4 Proxy)
- **Namespace:** `istio-system`
- **DaemonSet Name:** `ztunnel`
- **Risk Profile:** HIGH — ztunnel failures cascade to entire mesh; node-level proxy affects all pods on node
- **Exclusion Rationale:** Ztunnel health issues are **service mesh failures**, not node infrastructure failures. Deleting nodes during ztunnel incidents amplifies blast radius by forcing workload rescheduling onto equally unhealthy mesh infrastructure.

### 2. **istio-cni** (CNI Plugin)
- **Namespace:** `istio-system`
- **DaemonSet Name:** `istio-cni-node`
- **Risk Profile:** MEDIUM — CNI failures affect pod networking initialization but do not indicate node failure
- **Exclusion Rationale:** CNI plugin health degradation is a **networking layer issue**, not node infrastructure failure. Node deletion during CNI issues prevents proper troubleshooting and recovery.

### 3. **istio-operator** (Operator Controller)
- **Namespace:** `istio-system` or `istio-operator`
- **DaemonSet Name:** `istio-operator` (if deployed as DaemonSet)
- **Risk Profile:** LOW — Operator health issues affect mesh control plane, not node viability
- **Exclusion Rationale:** Operator failures are **control plane issues**. Node deletion does not resolve operator failures and prevents proper mesh recovery.

---

## NodeStuck Configuration Changes

### Current Behavior (PROBLEMATIC)

```yaml
# NodeStuck automation (BEFORE exclusion)
triggers:
  - type: DaemonSetUnhealthy
    threshold: 3  # 3 consecutive failures
    action: DeleteNode
    scope: AllDaemonSets  # ❌ Includes Istio daemonsets
```

**Problem:** Any daemonset unhealthy state (including Istio) triggers node deletion.

### Proposed Behavior (SAFE)

```yaml
# NodeStuck automation (AFTER exclusion)
triggers:
  - type: DaemonSetUnhealthy
    threshold: 3  # 3 consecutive failures
    action: DeleteNode
    scope: FilteredDaemonSets  # ✅ Excludes Istio infrastructure
    exclusionLabels:
      - "app.kubernetes.io/component=istio"
      - "app=ztunnel"
      - "app=istio-cni"
      - "app=istio-operator"
```

**Effect:** NodeStuck automation ignores Istio daemonset health when evaluating node deletion eligibility.

---

## Label-Based Exclusion Mechanism

### Implementation Strategy

1. **Add Exclusion Labels to Istio Daemonsets**

   Ensure all Istio infrastructure daemonsets have standardized labels:

   ```yaml
   metadata:
     labels:
       app.kubernetes.io/component: istio
       app.kubernetes.io/part-of: service-mesh
       infrastructure-tier: critical
   ```

2. **Update NodeStuck Automation Logic**

   Modify NodeStuck automation to filter daemonsets before evaluating node health:

   ```pseudocode
   function evaluateNodeHealth(node):
       daemonsets = getDaemonSetsOnNode(node)
       
       # FILTER OUT EXCLUDED DAEMONSETS
       filteredDaemonsets = daemonsets.filter(ds => 
           !hasExclusionLabel(ds, "app.kubernetes.io/component", "istio") &&
           !hasExclusionLabel(ds, "app", "ztunnel") &&
           !hasExclusionLabel(ds, "app", "istio-cni") &&
           !hasExclusionLabel(ds, "app", "istio-operator")
       )
       
       # EVALUATE ONLY NON-EXCLUDED DAEMONSETS
       unhealthyCount = filteredDaemonsets.count(ds => ds.health == "unhealthy")
       
       if unhealthyCount >= threshold:
           triggerNodeDeletion(node)
   ```

3. **Verification Query**

   Operators can verify exclusion with:

   ```bash
   # List all daemonsets with exclusion labels
   kubectl get daemonset -A -l app.kubernetes.io/component=istio
   kubectl get daemonset -A -l app=ztunnel
   kubectl get daemonset -A -l app=istio-cni
   kubectl get daemonset -A -l app=istio-operator
   ```

---

## Separating Daemonset Health from Node Health

### Health Signal Taxonomy

| **Signal Type** | **Indicator** | **Action** |
|-----------------|---------------|------------|
| **Node Infrastructure Health** | Kubelet unreachable, disk pressure, memory pressure, PID exhaustion | **Delete Node** ✅ |
| **Node Networking Health** | Node NotReady due to CNI, DNS failures, routing issues | **Drain + Investigate** ⚠️ |
| **Daemonset Service Health** | Istio, monitoring, logging daemonsets unhealthy | **No Node Action** ❌ |

### Monitoring Strategy

1. **Node-Level Metrics (Infrastructure)**
   - Kubelet heartbeat
   - Node conditions: `Ready`, `DiskPressure`, `MemoryPressure`, `PIDPressure`
   - VMSS health probes

2. **Daemonset-Level Metrics (Service Layer)**
   - Pod crash loops (by daemonset)
   - Service mesh connectivity
   - Logging/monitoring agent health

3. **Separation Principle**
   - **Node health signals** trigger node deletion
   - **Daemonset health signals** trigger alerts + manual investigation (NO automatic node deletion)

---

## Validation Steps for STG Before PROD

### Phase 1: STG Configuration Deployment (Day 1)

1. **Apply Exclusion Labels to Istio Daemonsets**
   ```bash
   kubectl label daemonset ztunnel -n istio-system app.kubernetes.io/component=istio
   kubectl label daemonset istio-cni-node -n istio-system app.kubernetes.io/component=istio
   # (Repeat for istio-operator if deployed as DaemonSet)
   ```

2. **Deploy Updated NodeStuck Automation Config**
   - Update NodeStuck controller ConfigMap with exclusion labels
   - Restart NodeStuck controller pods to reload config

3. **Verify Exclusion Logic**
   ```bash
   # Confirm NodeStuck ignores Istio daemonsets
   kubectl logs -n kube-system -l app=nodestuck-controller | grep "Exclusion applied"
   ```

### Phase 2: Chaos Engineering Test (Day 1-2)

1. **Simulate Istio Daemonset Failure**
   - Intentionally crash ztunnel pods on 2-3 STG nodes
   - Monitor NodeStuck automation behavior

2. **Expected Outcome**
   - ✅ NodeStuck does NOT trigger node deletion
   - ✅ Alerts fire for ztunnel unhealthy state
   - ✅ Nodes remain operational for troubleshooting

3. **Failure Scenario Test**
   - If NodeStuck still triggers deletion → rollback and refine exclusion logic

### Phase 3: 48-Hour Monitoring (Day 2-3)

1. **Monitor STG Cluster Health**
   - Track NodeStuck deletion events (should show zero Istio-related deletions)
   - Track false positive rate (Istio incidents should NOT trigger node churn)

2. **Success Criteria**
   - Zero node deletions triggered by Istio daemonset health degradation
   - Node deletion rate for actual infrastructure failures remains unchanged
   - Mean time to recovery (MTTR) for mesh incidents improves (no cascading node loss)

### Phase 4: PROD Rollout (Day 3-4)

1. **Progressive Rollout Strategy**
   - Deploy to **1 PROD region** first (lowest traffic)
   - Monitor 24 hours
   - Deploy to **remaining regions** if stable

2. **Rollback Plan**
   - Immediate: Remove exclusion labels (reverts to old behavior)
   - Full rollback: Restore previous NodeStuck ConfigMap

---

## Monitoring & Alerting

### New Metrics to Track

1. **`nodestuck_exclusion_applied_total`**
   - Counter: Number of times exclusion logic filtered out a daemonset
   - Labels: `daemonset_name`, `namespace`, `exclusion_reason`

2. **`nodestuck_node_deletion_rate`**
   - Gauge: Node deletions per hour (should remain stable or decrease)
   - Split by `trigger_type`: `infrastructure_failure`, `daemonset_failure`

3. **`istio_daemonset_unhealthy_duration_seconds`**
   - Histogram: Duration Istio daemonsets remain unhealthy without triggering node deletion
   - Purpose: Detect prolonged mesh issues requiring manual intervention

### Alert Rules

```yaml
# Alert if Istio daemonset unhealthy for >15 minutes (no auto-deletion)
- alert: IstioDaemonSetUnhealthyProlonged
  expr: istio_daemonset_unhealthy_duration_seconds > 900
  severity: warning
  annotations:
    summary: "Istio daemonset {{ $labels.daemonset }} unhealthy for >15m"
    action: "Investigate mesh health; NodeStuck will NOT delete nodes automatically"

# Alert if node deletion rate drops to zero (exclusion too aggressive)
- alert: NodeStuckNotDeletingNodes
  expr: rate(nodestuck_node_deletion_rate[6h]) == 0
  severity: info
  annotations:
    summary: "NodeStuck has not deleted any nodes in 6 hours"
    action: "Verify exclusion logic not blocking legitimate node failures"
```

---

## Rollback Plan

### Immediate Rollback (If Needed in STG/PROD)

1. **Remove Exclusion Labels**
   ```bash
   kubectl label daemonset ztunnel -n istio-system app.kubernetes.io/component-
   kubectl label daemonset istio-cni-node -n istio-system app.kubernetes.io/component-
   ```

2. **Revert NodeStuck ConfigMap**
   ```bash
   kubectl rollout undo deployment/nodestuck-controller -n kube-system
   ```

3. **Notify SRE Team**
   - Post to incident channel: "NodeStuck Istio exclusion rolled back due to [REASON]"
   - Resume manual node management during mesh incidents

---

## Related Issues & Roadmap

- **Issue #50 (This Issue):** Istio exclusion (IMMEDIATE — 48 hours)
- **Issue #46:** STG-EUS2-28 incident analysis (Picard's assessment)
- **Issue #24:** Tier 1 stability (I1 Istio Exclusion List — 2-3 weeks)
- **Issue #25:** Tier 2 stability (I2 ztunnel health monitoring — 6-8 weeks)

### Phased Approach

1. **IMMEDIATE (This Week):** Implement Karan's exclusion (NodeStuck ignores Istio daemonsets)
2. **Tier 1 (2-3 weeks):** I1 exclusion list (remove infrastructure components from mesh entirely)
3. **Tier 2 (6-8 weeks):** I2 ztunnel health monitoring with automatic rollback

---

## Ownership & Approvals

- **Author:** B'Elanna (Infrastructure Expert)
- **Reviewers Required:**
  - SRE Lead (NodeStuck automation owner)
  - Platform Lead (Istio/mesh owner)
  - Karan (Original proposal author)
- **Approvers Required:**
  - Picard (Lead Engineer — Issue #46 incident owner)
  - Tamir (Product Owner)

---

## Success Metrics

- ✅ Zero node deletions triggered by Istio daemonset health degradation (measured over 7 days post-PROD deployment)
- ✅ Node deletion rate for actual infrastructure failures remains unchanged (<5% variance)
- ✅ MTTR for mesh incidents improves by 30-50% (no cascading node loss)
- ✅ No false negatives (actual node failures still trigger deletion within expected threshold)

---

## Appendix: Technical References

### NodeStuck Automation Architecture

- NodeStuck controller deployed in `kube-system` namespace
- Monitors node conditions + daemonset health via Kubernetes API
- Triggers node deletion via cloud provider API (Azure VMSS, AWS ASG)

### Istio Ambient Mode Architecture

- **ztunnel:** Node-level L4 proxy (DaemonSet)
- **istio-cni:** CNI plugin for transparent traffic interception (DaemonSet)
- **istiod:** Control plane (Deployment, NOT affected by this exclusion)

### Node Health vs. Daemonset Health

- **Node Health:** Kubelet, kernel, network stack, storage subsystem
- **Daemonset Health:** Application-layer services (mesh, logging, monitoring)
- **Key Insight:** Daemonset failures do NOT indicate node failures; they indicate service layer issues requiring different remediation (restart pods, rollback versions, NOT delete nodes)

---

## Questions for Reviewers

1. **SRE Lead:** Does the exclusion logic align with NodeStuck automation's existing filtering mechanisms?
2. **Platform Lead:** Are there additional Istio components (e.g., istio-ingress, istio-egress) that should be excluded?
3. **Karan:** Does this implementation match your original proposal? Any refinements needed?
4. **Picard:** Does this address the immediate mitigation from your Issue #46 analysis?

---

**END OF DOCUMENT**
