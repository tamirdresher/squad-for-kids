# K8s-Native Capability Routing: Design Specification

**Issue:** [#999](https://github.com/tamirdresher_microsoft/tamresearch1/issues/999)  
**Status:** Design Phase  
**Author:** Picard (Squad Lead)  
**Date:** 2026-03-21  
**Reviewers:** B'Elanna (Infrastructure)

---

## Executive Summary

This document specifies a Kubernetes-native capability routing system that replaces Squad's file-based machine capability discovery with K8s node labels and scheduling primitives. When a GitHub issue has a `needs:gpu` label, the Squad operator schedules the agent pod to a node with `nvidia.com/gpu=true`.

**Key Components:**
1. Label Mapping: GitHub `needs:*` → K8s node labels (`squad.io/capability-*`)
2. Capability Discovery DaemonSet: Automated node labeling
3. Pod Scheduling: `nodeSelector` and `nodeAffinity` based on issue requirements
4. AKS Node Pools: Purpose-built pools with pre-configured capabilities

---

## 1. Problem Statement

Squad's current capability routing uses file-based discovery (`~/.squad/machine-capabilities.json`). In Kubernetes, capabilities are expressed as node labels and pod scheduling constraints—native primitives that enable the K8s scheduler to match workloads to infrastructure.

---

## 2. Label Mapping

| GitHub Label        | K8s Node Label                     | Discovery Method                           |
|---------------------|------------------------------------|--------------------------------------------|
| `needs:gpu`         | `nvidia.com/gpu`                   | NVIDIA device plugin                       |
| `needs:browser`     | `squad.io/capability-browser`      | Capability DaemonSet (Playwright probe)    |
| `needs:whatsapp`    | `squad.io/capability-whatsapp`     | Capability DaemonSet (session files)       |
| `needs:azure-speech`| `squad.io/capability-azure-speech` | Capability DaemonSet (SDK/secret)          |
| `needs:personal-gh` | `squad.io/capability-personal-gh`  | Capability DaemonSet (secret mounted)      |
| `needs:emu-gh`      | `squad.io/capability-emu-gh`       | Capability DaemonSet (secret mounted)      |
| `needs:teams-mcp`   | `squad.io/capability-teams-mcp`    | Capability DaemonSet (MCP config)          |
| `needs:onedrive`    | `squad.io/capability-onedrive`     | Capability DaemonSet (FUSE mount)          |

---

## 3. Capability Discovery DaemonSet

A DaemonSet runs on every node, probes for capabilities, and applies labels via the K8s API.

**Key Characteristics:**
- Runs with `nodes/patch` RBAC permission
- Rescans every 5 minutes
- Removes labels when capabilities are lost
- Tolerates GPU/tainted nodes

**Example Manifest:**

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: squad-capability-discovery
  namespace: squad
spec:
  template:
    spec:
      serviceAccountName: capability-discoverer
      containers:
        - name: discoverer
          image: ghcr.io/tamirdresher/squad-capability-discoverer:latest
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
```

---

## 4. Pod Scheduling

The Squad operator translates issue labels to pod scheduling constraints.

**Example:** Issue with `needs:gpu` + `needs:browser` generates:

```yaml
spec:
  nodeSelector:
    nvidia.com/gpu: "true"
    squad.io/capability-browser: "true"
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
```

**Operator Logic (Golang):**

```go
var capabilityLabelMap = map[string]string{
    "gpu":       "nvidia.com/gpu",
    "browser":   "squad.io/capability-browser",
    "whatsapp":  "squad.io/capability-whatsapp",
    // ...
}

func buildPodSpec(issue *SquadIssue) corev1.PodSpec {
    spec := corev1.PodSpec{NodeSelector: make(map[string]string)}
    for _, label := range issue.Labels {
        if strings.HasPrefix(label, "needs:") {
            capability := strings.TrimPrefix(label, "needs:")
            if k8sLabel, ok := capabilityLabelMap[capability]; ok {
                spec.NodeSelector[k8sLabel] = "true"
            }
        }
    }
    return spec
}
```

---

## 5. AKS Node Pools

Production AKS deployment uses specialized node pools:

### GPU Pool
```bash
az aks nodepool add --name gpupool --node-vm-size Standard_NC6s_v3 \
  --node-taints nvidia.com/gpu=true:NoSchedule \
  --labels squad.io/memory-tier=high --min-count 0 --max-count 3
```

### Browser Pool
```bash
az aks nodepool add --name browserpool --node-vm-size Standard_D4s_v5 \
  --labels squad.io/memory-tier=standard --min-count 1 --max-count 10
```

### General Pool
```bash
az aks nodepool add --name agentpool --node-vm-size Standard_D2s_v5 \
  --labels squad.io/memory-tier=standard --min-count 2 --max-count 20
```

---

## 6. Migration Path

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 1 | Deploy capability DaemonSet | Not Started |
| Phase 2 | Update Squad operator with label mapping | Not Started |
| Phase 3 | Create AKS node pools | Not Started |
| Phase 4 | Test with real issues | Not Started |
| Phase 5 | Deprecate `discover-machine-capabilities.ps1` | Not Started |

**Backward Compatibility:** Ralph checks `$env:KUBERNETES_SERVICE_HOST` to choose between K8s node labels or JSON manifest.

---

## 7. Security

- ServiceAccount `capability-discoverer` requires `nodes/patch` ClusterRole
- This is a sensitive permission—audit all ClusterRoleBindings granting it
- DaemonSet runs as non-root with read-only root filesystem

---

## 8. Related Issues

- #987 — Machine capability discovery (predecessor)
- #1000 — Squad Helm chart
- #995 — Test Squad-on-K8s with non-human user
- #1159 — AKS Automatic compatibility

---

**Status:** ✅ Design Complete — Ready for B'Elanna Review
