# K8s-Native Capability Routing: Design Document

**Issue:** [#999](https://github.com/tamirdresher_microsoft/tamresearch1/issues/999)  
**Status:** Design  
**Author:** Picard (Squad Lead)  
**Date:** 2026-03-20

---

## 1. Problem Statement

Squad currently uses `needs:*` labels on GitHub issues to route work to machines with specific capabilities (see #987). The `discover-machine-capabilities.ps1` script probes local hardware/software and writes a manifest to `~/.squad/machine-capabilities.json`. Ralph's `Test-MachineCapability` function checks this manifest before claiming an issue.

In Kubernetes, this concept maps naturally to **node labels and pod scheduling constraints**. A pod that needs a GPU gets `nodeSelector: nvidia.com/gpu: "true"`. A pod that needs WhatsApp gets `nodeSelector: squad.io/whatsapp: "true"`.

This document designs the full K8s-native capability routing system — replacing the file-based approach with first-class Kubernetes primitives.

---

## 2. Label Mapping: Issue Labels → K8s Node Labels

| Issue `needs:*` Label   | K8s Node Label                     | Discovery Source                        |
|-------------------------|------------------------------------|-----------------------------------------|
| `needs:gpu`             | `nvidia.com/gpu`                   | NVIDIA device plugin (automatic)        |
| `needs:browser`         | `squad.io/capability-browser`      | Capability DaemonSet                    |
| `needs:whatsapp`        | `squad.io/capability-whatsapp`     | Capability DaemonSet                    |
| `needs:azure-speech`    | `squad.io/capability-azure-speech` | Capability DaemonSet                    |
| `needs:personal-gh`     | `squad.io/capability-personal-gh`  | Capability DaemonSet (secret presence)  |
| `needs:emu-gh`          | `squad.io/capability-emu-gh`       | Capability DaemonSet (secret presence)  |
| `needs:teams-mcp`       | `squad.io/capability-teams-mcp`    | Capability DaemonSet                    |
| `needs:onedrive`        | `squad.io/capability-onedrive`     | Capability DaemonSet (FUSE mount check) |
| `needs:high-memory`     | `squad.io/memory-tier: high`       | Capability DaemonSet (allocatable mem)  |
| `needs:ssd`             | `squad.io/storage-tier: ssd`       | Capability DaemonSet (disk type probe)  |

> **Naming convention:** `squad.io/capability-*` for software/credential capabilities; `squad.io/*-tier` for hardware tiers; vendor labels (`nvidia.com/*`) used as-is.

---

## 3. Capability Discovery DaemonSet

Replace `discover-machine-capabilities.ps1` with a K8s DaemonSet that runs on every node and labels it based on what it finds.

### 3.1 DaemonSet Manifest

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: squad-capability-discovery
  namespace: squad
  labels:
    app.kubernetes.io/name: squad-capability-discovery
    app.kubernetes.io/component: infrastructure
spec:
  selector:
    matchLabels:
      app: squad-capability-discovery
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: squad-capability-discovery
    spec:
      serviceAccountName: capability-discoverer
      hostNetwork: false
      tolerations:
        # Run on all nodes including GPU/tainted nodes
        - operator: Exists
          effect: NoSchedule
        - operator: Exists
          effect: NoExecute
      containers:
        - name: discoverer
          image: ghcr.io/tamirdresher/squad-capability-discoverer:latest
          imagePullPolicy: Always
          securityContext:
            privileged: false
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1000
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: RESCAN_INTERVAL_SECONDS
              value: "300"  # Re-probe every 5 minutes
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 64Mi
          volumeMounts:
            - name: node-secrets-probe
              mountPath: /probe/secrets
              readOnly: true
      volumes:
        - name: node-secrets-probe
          projected:
            sources:
              - secret:
                  name: squad-personal-gh
                  optional: true   # Marks capability-personal-gh=true if present
              - secret:
                  name: squad-emu-gh
                  optional: true   # Marks capability-emu-gh=true if present
```

### 3.2 Discovery Logic (Pseudocode)

```python
def discover_and_label(node_name: str):
    labels = {}

    # Browser capability: check if Playwright/Chromium is installed
    labels["squad.io/capability-browser"] = probe_executable("chromium") or probe_executable("playwright")

    # WhatsApp: check for WA session files
    labels["squad.io/capability-whatsapp"] = path_exists("/probe/wa-session/device.dat")

    # Azure Speech: check for SDK or API key secret
    labels["squad.io/capability-azure-speech"] = secret_mounted("azure-speech-key") or sdk_installed("azure-cognitiveservices-speech")

    # Personal GitHub: secret presence
    labels["squad.io/capability-personal-gh"] = secret_mounted("squad-personal-gh")

    # EMU GitHub: secret presence
    labels["squad.io/capability-emu-gh"] = secret_mounted("squad-emu-gh")

    # Teams MCP: check for MCP config
    labels["squad.io/capability-teams-mcp"] = path_exists("/probe/mcp-config/teams.json")

    # OneDrive: FUSE mount check
    labels["squad.io/capability-onedrive"] = mountpoint_exists("/mnt/onedrive")

    # Memory tier
    allocatable_gb = get_node_allocatable_memory_gb()
    if allocatable_gb >= 64:
        labels["squad.io/memory-tier"] = "high"
    elif allocatable_gb >= 16:
        labels["squad.io/memory-tier"] = "standard"
    else:
        labels["squad.io/memory-tier"] = "low"

    # Apply to node via K8s API
    patch_node_labels(node_name, labels)
```

---

## 4. RBAC for Capability Discoverer

The DaemonSet pod needs `nodes/patch` and `nodes/get` permissions.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: capability-discoverer
  namespace: squad
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: squad:capability-discoverer
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: squad:capability-discoverer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: squad:capability-discoverer
subjects:
  - kind: ServiceAccount
    name: capability-discoverer
    namespace: squad
```

> **Security note:** `nodes/patch` is a sensitive permission — it can affect scheduling for all workloads on the cluster. Restrict this ClusterRoleBinding to the `capability-discoverer` ServiceAccount only.

---

## 5. Pod Scheduling Implementation

### 5.1 Hard Requirements (nodeSelector)

When the Squad operator creates an agent pod for an issue with `needs:gpu` + `needs:browser`:

```yaml
spec:
  nodeSelector:
    nvidia.com/gpu: "true"
    squad.io/capability-browser: "true"
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  containers:
    - name: agent
      resources:
        limits:
          nvidia.com/gpu: 1
```

### 5.2 Soft Preferences (nodeAffinity)

For **optional** capabilities (`prefers:azure-speech` label style), use preferred scheduling:

```yaml
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 50
          preference:
            matchExpressions:
              - key: squad.io/capability-azure-speech
                operator: In
                values: ["true"]
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: squad.io/capability-emu-gh
                operator: In
                values: ["true"]
```

### 5.3 Squad Operator: Label → Scheduling Mapping

```go
// In squad-operator reconciler, when creating an agent pod:
func buildPodSpec(issue *SquadIssue) corev1.PodSpec {
    spec := corev1.PodSpec{}
    for _, label := range issue.Labels {
        if strings.HasPrefix(label, "needs:") {
            capability := strings.TrimPrefix(label, "needs:")
            k8sLabel, ok := capabilityLabelMap[capability]
            if ok {
                spec.NodeSelector[k8sLabel] = "true"
            }
        }
        if strings.HasPrefix(label, "prefers:") {
            capability := strings.TrimPrefix(label, "prefers:")
            k8sLabel, ok := capabilityLabelMap[capability]
            if ok {
                // Add as preferred affinity
                addPreferredAffinity(&spec, k8sLabel, 50)
            }
        }
    }
    return spec
}

var capabilityLabelMap = map[string]string{
    "gpu":           "nvidia.com/gpu",
    "browser":       "squad.io/capability-browser",
    "whatsapp":      "squad.io/capability-whatsapp",
    "azure-speech":  "squad.io/capability-azure-speech",
    "personal-gh":   "squad.io/capability-personal-gh",
    "emu-gh":        "squad.io/capability-emu-gh",
    "teams-mcp":     "squad.io/capability-teams-mcp",
    "onedrive":      "squad.io/capability-onedrive",
}
```

---

## 6. AKS Node Pool Configuration

For production AKS, create purpose-specific node pools with labels applied at pool creation time (static capabilities):

```bash
# GPU node pool
az aks nodepool add \
  --resource-group squad-rg \
  --cluster-name squad-aks \
  --name gpupool \
  --node-count 1 \
  --node-vm-size Standard_NC6s_v3 \
  --node-taints nvidia.com/gpu=true:NoSchedule \
  --labels squad.io/memory-tier=high \
  --aks-custom-headers UseGPUDedicatedVHD=true

# Browser/Playwright node pool (CPU-only, higher memory)
az aks nodepool add \
  --resource-group squad-rg \
  --cluster-name squad-aks \
  --name browserpool \
  --node-count 2 \
  --node-vm-size Standard_D4s_v5 \
  --labels squad.io/capability-browser=true squad.io/memory-tier=standard

# General-purpose pool (default)
az aks nodepool add \
  --resource-group squad-rg \
  --cluster-name squad-aks \
  --name agentpool \
  --node-count 3 \
  --node-vm-size Standard_D2s_v5 \
  --labels squad.io/memory-tier=standard
```

> Dynamic capabilities (WhatsApp, GitHub tokens, Azure Speech keys) are handled by the DaemonSet detecting mounted secrets — **not** hard-coded at node pool creation time.

---

## 7. Migration Path

| Phase | What changes | When |
|-------|-------------|------|
| **Phase 1** | Add `capabilityLabelMap` to Squad operator; DaemonSet deployed | Before AKS cutover |
| **Phase 2** | Ralph reads `machine-capabilities.json` OR queries K8s node labels | During cutover |
| **Phase 3** | `discover-machine-capabilities.ps1` retired; K8s-only | Post-cutover |

### Backward Compatibility

During the migration window, Ralph can check capabilities from both sources:

```powershell
function Test-MachineCapability($capability) {
    if ($env:KUBERNETES_SERVICE_HOST) {
        # Running in K8s — query node labels
        $nodeName = $env:NODE_NAME
        $labels = kubectl get node $nodeName -o jsonpath="{.metadata.labels}" | ConvertFrom-Json
        $k8sLabel = $global:capabilityLabelMap[$capability]
        return $labels.$k8sLabel -eq "true"
    } else {
        # Running on bare metal — use JSON manifest
        $manifest = Get-Content ~/.squad/machine-capabilities.json | ConvertFrom-Json
        return $manifest.$capability -eq $true
    }
}
```

---

## 8. Open Questions

1. **DaemonSet image:** Build from scratch or extend an existing K8s tooling image (e.g., `bitnami/kubectl`)? → Lean toward minimal custom image with probe scripts.
2. **Secret presence detection:** Projected volume mounts mean secrets are only available if they exist in the namespace. Needs coordination with Helm chart secret management (issue #1000).
3. **Label cleanup:** When a capability is lost (e.g., personal-gh token expired), the DaemonSet must **remove** the label. Need to handle `kubectl label node ... squad.io/capability-personal-gh-` (trailing dash removes label).
4. **Capability versioning:** Should labels carry a version? e.g., `squad.io/capability-browser: "playwright-1.41"` vs just `"true"`. Defer to Phase 2.

---

## Related Issues

- #987 — Machine capability discovery (predecessor)
- #1000 — Squad Helm chart (coordinates secret/node pool design)
- #995 — Test Squad-on-K8s with non-human user
- #1159 — AKS Automatic compatibility
