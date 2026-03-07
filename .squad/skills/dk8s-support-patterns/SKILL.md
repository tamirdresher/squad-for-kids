---
name: "dk8s-support-patterns"
description: "Recurring support patterns from DK8S Clusters (Kubernetes) - Support channel"
domain: "dk8s-operations"
confidence: "high"
source: "teams-channel-learning"
learned_from: "DK8S Clusters (Kubernetes) – Support"
first_seen: "2026-07-04"
---

## Context
These patterns were extracted from the DK8S Clusters (Kubernetes) - Support channel in the Infra and Developer Platform Community team. They represent the most common recurring issues that surface in support threads.

## Patterns

### Pod Scheduling / Capacity Starvation
**Trigger:** Pods drop below min replicas, latency spikes, FailedScheduling events storm.
**Common misdiagnosis:** Teams assume HPA/PDB/affinity misconfiguration.
**Actual root cause:** Cluster-level capacity exhaustion — not enough schedulable nodes.
**Resolution:** Check node pool capacity and autoscaler status before investigating workload config. Escalate as cluster capacity issue, not application issue.
**Example:** CANE-23 incident — pods stuck at 1 replica despite min=2, thousands of FailedScheduling events.

### Node Bootstrap Failures (Karpenter + AKS)
**Trigger:** Nodes created by autoscaler but never join the cluster.
**Root cause:** VM extensions (CSE, billing extension) fail before kubelet starts. Karpenter provisions replacement nodes that also fail.
**Resolution:** Check VM extension provisioning status. Often requires Azure CRP team engagement, not DK8S platform fix.
**Key insight:** Hundreds of nodes can be provisioned but never registered, causing prolonged capacity starvation.

### Azure Platform Issues Misattributed to DK8S
**Trigger:** VMExtension failures, CNI NetworkNotReady, CRP incidents.
**Pattern:** Support threads start as "DK8S is broken" but investigation reveals Azure Compute Resource Provider incident.
**Resolution:** Check Azure status page and CRP incident tracker. Communicate clearly: "This is an Azure platform issue, not DK8S/Karpenter/your chart."
**Frequency:** Bi-weekly occurrence.

### Identity / Key Vault / Cluster-Scoped Role Coupling
**Trigger:** AKV directory changes, role assignment propagation delays, cluster-level identity reuse.
**Risk:** Cluster-scoped identity decisions create service-level blast radius.
**Pattern:** Teams repeatedly ask how to scope identity changes to avoid breaking unrelated services.
**Resolution:** Isolate identity changes per service where possible. Review ArgoCD reconciliation impact before applying cluster-wide role changes.

## Anti-Patterns
- **Assuming workload misconfiguration first** — Check cluster capacity before debugging HPA/PDB.
- **Treating all scheduling failures identically** — Distinguish between workload affinity issues and cluster-level exhaustion.
- **Ignoring Azure platform status** — Always check CRP status when node-level failures occur.
