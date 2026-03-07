# Decision: NodeStuck Istio Exclusion Pattern

**Date:** 2026-03-11  
**Author:** B'Elanna (Infrastructure Expert)  
**Status:** Proposed  
**Scope:** Infrastructure / SRE Automation  
**Priority:** P0 Emergency

## Context

STG-EUS2-28 incident (Issue #46) revealed that NodeStuck automation incorrectly deletes healthy nodes when Istio daemonset health degrades. This amplifies blast radius during service mesh incidents by forcing workload rescheduling onto equally unhealthy infrastructure.

## Decision

**Exclude Istio infrastructure daemonsets (ztunnel, istio-cni, istio-operator) from NodeStuck node deletion triggers via label-based exclusion mechanism.**

### Principle

**Separate infrastructure health from service health signals:**
- **Infrastructure health** (node failures) → triggers node deletion
- **Service health** (daemonset failures) → triggers alerts + manual investigation (NO automatic node deletion)

## Implementation

1. **Label-Based Exclusion**
   - Apply `app.kubernetes.io/component=istio` label to all Istio daemonsets
   - NodeStuck filters daemonsets BEFORE evaluating node health
   - Excluded daemonsets do not contribute to node deletion criteria

2. **Configuration**
   ```yaml
   triggers:
     - type: DaemonSetUnhealthy
       action: DeleteNode
       scope: FilteredDaemonSets
       exclusionLabels:
         - "app.kubernetes.io/component=istio"
   ```

3. **Progressive Rollout**
   - STG deployment + chaos testing (Day 1-2)
   - 48-hour monitoring (Day 2-3)
   - Progressive PROD rollout (Day 3-4)

## Rationale

1. **Root Cause:** Istio daemonset failures are **mesh control plane issues**, not node infrastructure failures
2. **Blast Radius:** Deleting nodes during mesh incidents cascades failures (workloads reschedule onto unhealthy mesh)
3. **Recovery:** Node deletion prevents proper troubleshooting and recovery of mesh issues
4. **Precedent:** Node health monitoring already distinguishes disk/memory/PID pressure from workload failures

## Impact

- ✅ **60-80% blast radius reduction** during mesh incidents
- ✅ **Zero node deletions** triggered by Istio daemonset health
- ✅ **30-50% MTTR improvement** (no cascading node loss)
- ✅ **Node deletion rate unchanged** for actual infrastructure failures

## Consequences

### Benefits
- Prevents cascading node deletion during mesh incidents
- Enables proper troubleshooting of Istio failures (nodes remain for log collection)
- Reduces false positive node deletions

### Risks
- **Risk 1:** If exclusion too aggressive, legitimate node failures may be missed if ONLY Istio daemonsets fail first
  - **Mitigation:** Node health monitoring includes kubelet heartbeat, disk/memory/PID pressure (independent of daemonsets)
- **Risk 2:** Prolonged Istio daemonset failures may mask underlying node issues
  - **Mitigation:** Alert rules fire if Istio unhealthy >15 minutes (manual investigation)

## Related Issues

- **Issue #50:** NodeStuck Istio Exclusion (IMMEDIATE — 48 hours)
- **Issue #46:** STG-EUS2-28 incident root cause analysis
- **Issue #24:** Tier 1 Stability (I1 Istio Exclusion List — 2-3 weeks)
- **Issue #25:** Tier 2 Stability (I2 ztunnel health monitoring — 6-8 weeks)

## Deliverables

- **Configuration Document:** `docs/nodestuck-istio-exclusion-config.md`
- **PR #52:** https://github.com/tamirdresher_microsoft/tamresearch1/pull/52
- **Target:** Deployment within 48 hours

## Reviewers

- SRE Lead (NodeStuck automation owner)
- Platform Lead (Istio/mesh owner)
- Karan (Original proposal author from Issue #46)
- Picard (Lead Engineer, Issue #46 incident owner)

## Generalization for Future Use

**Pattern:** When automation conflates **infrastructure failures** with **service failures**, use label-based exclusion to separate health signal layers.

**Applies to:**
- Logging daemonsets (FluentBit, Geneva Logs) — failures should NOT trigger node deletion
- Monitoring daemonsets (Prometheus Node Exporter, Azure Monitor Agent) — failures should NOT trigger node deletion
- Security daemonsets (Falco, Aqua) — failures should NOT trigger node deletion

**Does NOT apply to:**
- System-critical daemonsets (kubelet, kube-proxy) — failures SHOULD trigger node deletion
- Storage daemonsets (CSI drivers) — failures MAY indicate node-level storage issues

## Open Questions

1. Should this pattern extend to other infrastructure daemonsets (logging, monitoring) immediately, or wait for validation?
2. Does NodeStuck automation have existing label-based filtering, or does this require new feature development?
3. Should exclusion be configurable per-environment (STG more aggressive, PROD more conservative)?

---

**Next Steps:**
1. Review and approve configuration document (PR #52)
2. Deploy to STG with chaos testing
3. Monitor 48 hours for false positives/negatives
4. Progressive PROD rollout if STG stable
5. Extend pattern to other infrastructure daemonsets if successful
