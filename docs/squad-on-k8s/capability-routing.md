# K8s-Native Capability Routing

> **Issue:** #999 — Design: K8s-Native Capability Routing (Node Labels to Issue Labels)  
> **Cross-references:** #994 (Squad-on-K8s), #987 (Machine capability labels)  
> **Author:** Seven (Research & Docs) — architecture from B'Elanna (Infrastructure)  
> **Date:** 2026-03-20  
> **Status:** Approved — v1.0

---

## Overview

Squad's `needs:*` label system routes GitHub issues to machines with specific hardware/software
capabilities. On K8s, this concept maps to **node labels** and **pod scheduling constraints**.

This document provides the complete technical design:
- Label mapping (issue → node)
- Capability DaemonSet (replaces `discover-machine-capabilities.ps1`)
- Pod spec injection patterns (required vs preferred)
- AKS node pool CLI setup
- RBAC for the capability discoverer

> **Summary** is also in `docs/squad-on-k8s/architecture.md §10`.

---

## Table of Contents

1. [Label Mapping Reference](#1-label-mapping-reference)
2. [Pod Scheduling Patterns](#2-pod-scheduling-patterns)
3. [Capability Discovery DaemonSet](#3-capability-discovery-daemonset)
4. [AKS Node Pool Setup](#4-aks-node-pool-setup)
5. [Squad Operator: Injection Logic](#5-squad-operator-injection-logic)
6. [RBAC for Capability Discoverer](#6-rbac-for-capability-discoverer)
7. [Testing Capability Routing](#7-testing-capability-routing)
8. [Design Decisions](#8-design-decisions)

---

## 1. Label Mapping Reference

### 1.1 Complete Mapping Table

| GitHub Issue Label | K8s Node Label | Label Namespace | Source | Node Pool |
|-------------------|---------------|----------------|--------|-----------|
| `needs:gpu` | `nvidia.com/gpu: "true"` | NVIDIA | NVIDIA device plugin | `gpu-pool` |
| `needs:browser` | `squad.io/capability-browser: "true"` | `squad.io` | Capability DaemonSet | `browser-pool` |
| `needs:high-memory` | `squad.io/memory-tier: "high"` | `squad.io` | Node pool config | `highmem-pool` |
| `needs:whatsapp` | `squad.io/capability-whatsapp: "true"` | `squad.io` | Capability DaemonSet | Any |
| `needs:azure-speech` | `squad.io/capability-azure-speech: "true"` | `squad.io` | Capability DaemonSet | Any |
| `needs:personal-gh` | `squad.io/capability-personal-gh: "true"` | `squad.io` | Capability DaemonSet | Any |
| `needs:emu-gh` | `squad.io/capability-emu-gh: "true"` | `squad.io` | Capability DaemonSet | Any |
| `needs:teams-mcp` | `squad.io/capability-teams-mcp: "true"` | `squad.io` | Capability DaemonSet | Any |
| `needs:onedrive` | `squad.io/capability-onedrive: "true"` | `squad.io` | Capability DaemonSet | Any |
| *(no needs label)* | *(default scheduling)* | — | — | `general-pool` |

### 1.2 Label Namespace Conventions

- `nvidia.com/*` — NVIDIA device plugin labels (automatic)
- `squad.io/capability-*` — Software/service capabilities (DaemonSet-managed)
- `squad.io/memory-tier` — Memory tier classification (`standard`, `high`, `ultra`)
- `squad.io/gpu-tier` — GPU classification (`t4`, `a100`) when multiple GPU types exist

---

## 2. Pod Scheduling Patterns

### 2.1 Hard Requirements: nodeSelector

Use `nodeSelector` for capabilities that are **strictly required** — the pod cannot run without them.
A pod with an unsatisfied `nodeSelector` stays `Pending` until a matching node is available.

**Single requirement — `needs:gpu`:**
```yaml
spec:
  nodeSelector:
    nvidia.com/gpu: "true"
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  containers:
    - name: agent
      resources:
        limits:
          nvidia.com/gpu: "1"     # must request GPU resource too
```

**Single requirement — `needs:browser`:**
```yaml
spec:
  nodeSelector:
    squad.io/capability-browser: "true"
  containers:
    - name: agent
      resources:
        requests:
          cpu: "1000m"
          memory: "2Gi"
```

**Single requirement — `needs:high-memory`:**
```yaml
spec:
  nodeSelector:
    squad.io/memory-tier: "high"
  containers:
    - name: agent
      resources:
        requests:
          memory: "8Gi"
        limits:
          memory: "16Gi"
```

**Multiple requirements — `needs:gpu` + `needs:browser`:**
```yaml
spec:
  nodeSelector:
    nvidia.com/gpu: "true"
    squad.io/capability-browser: "true"   # node must satisfy ALL selectors
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  containers:
    - name: agent
      resources:
        limits:
          nvidia.com/gpu: "1"
        requests:
          cpu: "2000m"
          memory: "4Gi"
```

### 2.2 Soft Preferences: nodeAffinity

Use `preferredDuringSchedulingIgnoredDuringExecution` for capabilities that are **nice to have**
but not blocking. The pod will still schedule if no preferred node is available.

```yaml
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 80
          preference:
            matchExpressions:
              - key: squad.io/capability-azure-speech
                operator: In
                values: ["true"]
        - weight: 50
          preference:
            matchExpressions:
              - key: squad.io/capability-browser
                operator: In
                values: ["true"]
```

**Weight guidance:**
- `100` — Strong preference (prefer always, but not a blocker)
- `50` — Moderate preference
- `20` — Weak preference (nice, but essentially don't care)

### 2.3 Required + Preferred Combination

An issue may have both hard requirements and soft preferences:

```yaml
# needs:gpu (hard) + prefers:browser (soft)
spec:
  nodeSelector:
    nvidia.com/gpu: "true"          # HARD — must be on GPU node
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 60
          preference:
            matchExpressions:
              - key: squad.io/capability-browser
                operator: In
                values: ["true"]
  containers:
    - name: agent
      resources:
        limits:
          nvidia.com/gpu: "1"
```

### 2.4 Anti-Affinity: Spreading Replicas

For Ralph (multiple replicas), spread pods across nodes to avoid SPOF:

```yaml
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                squad.io/agent: ralph
            topologyKey: kubernetes.io/hostname
```

---

## 3. Capability Discovery DaemonSet

### 3.1 Full DaemonSet Spec

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: squad-capability-discovery
  namespace: squad-system
  labels:
    app: squad-capability-discovery
    app.kubernetes.io/part-of: squad
    app.kubernetes.io/component: capability-discovery
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
      priorityClassName: system-node-critical
      tolerations:
        - operator: Exists                   # run on all nodes including tainted ones
      hostNetwork: false
      containers:
        - name: discoverer
          image: acrsquadprod.azurecr.io/squad/capability-discoverer:latest
          imagePullPolicy: IfNotPresent
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: PROBE_INTERVAL_SECONDS
              value: "300"                   # re-probe every 5 minutes
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "100m"
              memory: "128Mi"
          securityContext:
            privileged: false
            runAsNonRoot: true
            runAsUser: 1000
            capabilities:
              drop: ["ALL"]
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8081
            initialDelaySeconds: 10
            periodSeconds: 60
          readinessProbe:
            httpGet:
              path: /readyz
              port: 8081
            initialDelaySeconds: 5
            periodSeconds: 30
```

### 3.2 Capability Probing Logic

The discoverer container runs this probe sequence every `PROBE_INTERVAL_SECONDS`:

```
Probe sequence (pseudo-code)
──────────────────────────────
capabilities = {}

# 1. Browser / Playwright
if playwright_installed():
    capabilities["squad.io/capability-browser"] = "true"

# 2. WhatsApp session
if whatsapp_session_exists("/run/secrets/whatsapp-session"):
    capabilities["squad.io/capability-whatsapp"] = "true"

# 3. Azure Speech SDK
if azure_speech_sdk_available():
    capabilities["squad.io/capability-azure-speech"] = "true"

# 4. Personal GitHub token
if secret_mounted("/run/secrets/personal-github-token"):
    capabilities["squad.io/capability-personal-gh"] = "true"

# 5. EMU GitHub token
if secret_mounted("/run/secrets/emu-github-token"):
    capabilities["squad.io/capability-emu-gh"] = "true"

# 6. Teams MCP
if teams_mcp_running():
    capabilities["squad.io/capability-teams-mcp"] = "true"

# 7. OneDrive
if onedrive_fuse_mounted("/mnt/onedrive"):
    capabilities["squad.io/capability-onedrive"] = "true"

# 8. Memory tier
total_memory = get_node_memory_gb()
if total_memory >= 64:
    capabilities["squad.io/memory-tier"] = "high"
elif total_memory >= 16:
    capabilities["squad.io/memory-tier"] = "standard"

# Patch node labels via K8s API
patch_node_labels(NODE_NAME, capabilities)
```

### 3.3 Node Label Patch Operation

The discoverer patches only `squad.io/*` labels — it never removes labels it didn't add.
Removal happens only when a capability is actively probed as absent:

```python
# Only patch changed labels
current = get_node_labels(node_name)
squad_labels = {k: v for k, v in current.items() if k.startswith("squad.io/")}
desired_squad_labels = probe_capabilities()

to_add = {k: v for k, v in desired_squad_labels.items() if current.get(k) != v}
to_remove = {k: None for k in squad_labels if k not in desired_squad_labels}

if to_add or to_remove:
    patch_node(node_name, labels={**to_add, **to_remove})
    log(f"Patched node {node_name}: added={to_add}, removed={to_remove}")
```

---

## 4. AKS Node Pool Setup

### 4.1 Node Pool Design

```
Cluster: aks-squad-prod
├── System pool: system-pool (Standard_D4s_v5, 2 nodes, min:2 max:5)
│   └── Labels: (none squad-specific)
│
├── General pool: general-pool (Standard_D4s_v5, 2 nodes, min:1 max:10)
│   └── Labels: squad.io/capability-general=true
│
├── GPU pool: gpu-pool (Standard_NC4as_T4_v3, 0 nodes, min:0 max:3)
│   └── Labels: squad.io/capability-gpu=true, nvidia.com/gpu=true
│   └── Taints: nvidia.com/gpu=true:NoSchedule
│
├── Browser pool: browser-pool (Standard_D8s_v5, 0 nodes, min:0 max:5)
│   └── Labels: squad.io/capability-browser=true
│
└── High-memory pool: highmem-pool (Standard_E16s_v5, 0 nodes, min:0 max:2)
    └── Labels: squad.io/memory-tier=high
```

### 4.2 AKS CLI Commands

```bash
CLUSTER="aks-squad-prod"
RG="rg-squad-prod"

# General-purpose pool (baseline — always on)
az aks nodepool add \
  --cluster-name $CLUSTER \
  --resource-group $RG \
  --name generalpool \
  --node-vm-size Standard_D4s_v5 \
  --node-count 2 \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 10 \
  --labels squad.io/capability-general=true \
  --os-type Linux

# GPU pool (scale-to-zero when no GPU work pending)
az aks nodepool add \
  --cluster-name $CLUSTER \
  --resource-group $RG \
  --name gpupool \
  --node-vm-size Standard_NC4as_T4_v3 \
  --node-count 0 \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 3 \
  --labels squad.io/capability-gpu=true \
  --node-taints nvidia.com/gpu=true:NoSchedule \
  --os-type Linux

# Browser pool (scale-to-zero when no browser work pending)
az aks nodepool add \
  --cluster-name $CLUSTER \
  --resource-group $RG \
  --name browserpool \
  --node-vm-size Standard_D8s_v5 \
  --node-count 0 \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 5 \
  --labels squad.io/capability-browser=true \
  --os-type Linux

# High-memory pool
az aks nodepool add \
  --cluster-name $CLUSTER \
  --resource-group $RG \
  --name highmempool \
  --node-vm-size Standard_E16s_v5 \
  --node-count 0 \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 2 \
  --labels squad.io/memory-tier=high \
  --os-type Linux
```

### 4.3 KEDA Autoscaling for Pending Jobs

Use KEDA to scale GPU/browser pools based on pending SquadRound CRs:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: gpu-pool-scaler
  namespace: squad-system
spec:
  scaleTargetRef:
    name: gpu-node-placeholder    # placeholder Deployment on gpu-pool
  minReplicaCount: 0
  maxReplicaCount: 3
  triggers:
    - type: kubernetes-workload
      metadata:
        podSelector: "squad.io/needs-gpu=true"
        value: "1"               # 1 GPU pod = 1 node
```

---

## 5. Squad Operator: Injection Logic

### 5.1 Label-to-NodeSelector Mapping ConfigMap

The capability mapping is stored as a ConfigMap for easy updates without operator redeployment:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: capability-mapping
  namespace: squad-system
data:
  mapping.yaml: |
    capabilities:
      needs:gpu:
        nodeSelector:
          nvidia.com/gpu: "true"
        tolerations:
          - key: nvidia.com/gpu
            operator: Exists
            effect: NoSchedule
        resourceLimits:
          nvidia.com/gpu: "1"

      needs:browser:
        nodeSelector:
          squad.io/capability-browser: "true"
        resourceRequests:
          cpu: "1000m"
          memory: "2Gi"

      needs:high-memory:
        nodeSelector:
          squad.io/memory-tier: "high"
        resourceRequests:
          memory: "8Gi"
        resourceLimits:
          memory: "16Gi"

      needs:whatsapp:
        nodeSelector:
          squad.io/capability-whatsapp: "true"

      needs:azure-speech:
        nodeSelector:
          squad.io/capability-azure-speech: "true"

      needs:personal-gh:
        nodeSelector:
          squad.io/capability-personal-gh: "true"

      needs:emu-gh:
        nodeSelector:
          squad.io/capability-emu-gh: "true"

      needs:teams-mcp:
        nodeSelector:
          squad.io/capability-teams-mcp: "true"

      needs:onedrive:
        nodeSelector:
          squad.io/capability-onedrive: "true"
```

### 5.2 Operator Reconciliation Flow

```
SquadRound CR created (by Ralph)
             │
             ▼
   Operator reads issue labels from GitHub API
             │
             ▼
   Filter labels matching "needs:*"
             │
             ├── No needs labels → use default (generalpool) scheduling
             │
             └── Has needs labels → load capability-mapping ConfigMap
                         │
                         ▼
                  Merge nodeSelector entries
                         │
                  Merge tolerations
                         │
                  Merge resource limits
                         │
                         ▼
                  Create Job spec with merged scheduling
                         │
                         ▼
                  Create Job in squad-system namespace
                         │
                         ▼
                  Update SquadRound status: phase=running
```

### 5.3 Example: Operator-Created Job for needs:gpu Issue

Input: GitHub issue `#1234` with labels `["squad:data", "needs:gpu", "research"]`

Output Job:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-job-1234
  namespace: squad-system
  labels:
    squad.io/agent: data
    squad.io/issue: "1234"
    squad.io/needs-gpu: "true"      # added for KEDA scaling trigger
spec:
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: squad-agent
      nodeSelector:
        nvidia.com/gpu: "true"       # injected from needs:gpu
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      containers:
        - name: data-agent
          image: acrsquadprod.azurecr.io/squad/data:latest
          args:
            - --issue=1234
            - --repo=tamirdresher_microsoft/tamresearch1
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "2000m"
              memory: "4Gi"
              nvidia.com/gpu: "1"    # injected from needs:gpu resource limit
          env:
            - name: GH_TOKEN
              valueFrom:
                secretKeyRef:
                  name: squad-github-token
                  key: token
          volumeMounts:
            - name: squad-config
              mountPath: /squad
              readOnly: true
            - name: session-storage
              mountPath: /session
      volumes:
        - name: squad-config
          configMap:
            name: squad-config
        - name: session-storage
          persistentVolumeClaim:
            claimName: squad-session-pvc
```

---

## 6. RBAC for Capability Discoverer

The DaemonSet needs permission to patch node labels:

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: capability-discoverer
  namespace: squad-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: squad-node-labeler
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "patch"]    # get to read current labels, patch to update
  - apiGroups: [""]
    resources: ["nodes/status"]
    verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: squad-node-labeler-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: squad-node-labeler
subjects:
  - kind: ServiceAccount
    name: capability-discoverer
    namespace: squad-system
```

**Security note:** The `patch` verb on `nodes` is broad. Scope it further with an admission
webhook that only allows patching `squad.io/*` prefixed labels (Phase 2 hardening).

---

## 7. Testing Capability Routing

### 7.1 Verify Node Labels

```bash
# Check what capabilities a node has
kubectl get nodes --show-labels | grep squad.io

# Check a specific node
kubectl describe node <node-name> | grep -A20 "Labels:"

# Find all GPU-capable nodes
kubectl get nodes -l nvidia.com/gpu=true

# Find all browser-capable nodes
kubectl get nodes -l squad.io/capability-browser=true
```

### 7.2 Test-Schedule a Pod

Verify that a pod with specific requirements lands on the right node:

```bash
# Create a test pod requiring browser capability
kubectl run test-browser \
  --image=busybox \
  --restart=Never \
  --overrides='{"spec":{"nodeSelector":{"squad.io/capability-browser":"true"}}}' \
  -n squad-system -- sleep 30

# Check which node it landed on
kubectl get pod test-browser -n squad-system -o wide

# Cleanup
kubectl delete pod test-browser -n squad-system
```

### 7.3 Test Pending Behavior

Verify that a pod with unsatisfied requirements stays `Pending`:

```bash
# Create a pod requiring a non-existent capability
kubectl run test-pending \
  --image=busybox \
  --restart=Never \
  --overrides='{"spec":{"nodeSelector":{"squad.io/capability-whatsapp":"true"}}}' \
  -n squad-system -- sleep 30

# Should be Pending if no whatsapp-capable node exists
kubectl get pod test-pending -n squad-system
# NAME           READY   STATUS    RESTARTS   AGE
# test-pending   0/1     Pending   0          30s

# Check scheduler event
kubectl describe pod test-pending -n squad-system | grep -A5 Events:
# Warning  FailedScheduling  0/3 nodes are available: 3 node(s) didn't match node selector.

# Cleanup
kubectl delete pod test-pending -n squad-system
```

### 7.4 Simulate the Full Flow

```bash
# 1. Create a SquadRound CR manually (simulating Ralph)
kubectl apply -f - <<EOF
apiVersion: squad.github.com/v1alpha1
kind: SquadRound
metadata:
  name: test-round-gpu-1
  namespace: squad-system
spec:
  agentRef: data
  roundNumber: 1
  triggeredBy: manual
  repository: tamirdresher_microsoft/tamresearch1
  issueLabels:
    - squad:data
    - needs:gpu
EOF

# 2. Watch the operator create a Job
kubectl get jobs -n squad-system -w

# 3. Verify the Job has GPU nodeSelector
kubectl get job data-job-<number> -n squad-system -o jsonpath='{.spec.template.spec.nodeSelector}'
```

---

## 8. Design Decisions

### 8.1 Node Labels vs Pod Labels

**Chosen: Node labels** for capabilities.

Capabilities are properties of the **infrastructure**, not the workload. A node either has a GPU
or it doesn't — this is fixed by the hardware, not the pod spec. Labeling nodes (not pods) ensures
that capability requirements flow correctly through K8s scheduling.

### 8.2 DaemonSet vs Manual Labeling vs Node Pool Labels

**Chosen: DaemonSet + Node Pool Labels (hybrid).**

| Approach | Pros | Cons |
|----------|------|------|
| Manual labeling | Simple, no DaemonSet needed | Labels drift; human error; doesn't detect changes |
| DaemonSet only | Auto-detects runtime capabilities | Overhead on every node; startup delay |
| Node pool labels (AKS) | Fast, pre-defined, no probe needed | Only for static capabilities (GPU, memory) |
| **Hybrid** | **Static caps → pool labels; dynamic caps → DaemonSet** | **Slightly more complex** |

**Rule:** Use node pool labels for **static, hardware-defined** capabilities (GPU, memory tier).
Use DaemonSet for **dynamic, software-defined** capabilities (browser, WhatsApp, OneDrive).

### 8.3 Required vs Preferred

**Chosen: Hard requirements (`nodeSelector`) for `needs:*` labels, soft preferences
(`affinity`) for anything marked `prefers:*` (future extension).**

Current Squad label system only has hard requirements (`needs:*`). No `prefers:*` labels
exist today. When `prefers:*` labels are introduced, use `preferredDuringScheduling` with
graduated weights.

### 8.4 Label Namespace

**Chosen: `squad.io/capability-*` for all Squad-managed labels.**

This avoids collisions with:
- `nvidia.com/*` — NVIDIA plugin
- `kubernetes.io/*` — K8s built-ins
- `node.kubernetes.io/*` — Node feature discovery
- `beta.kubernetes.io/*` — Legacy K8s

Using a consistent `squad.io/` prefix makes it easy to list, grep, and policy-control
all Squad-related node labels.

---

## Quick Reference: Issue Label → kubectl

```bash
# What node will needs:gpu issues land on?
kubectl get nodes -l nvidia.com/gpu=true -o custom-columns=NAME:.metadata.name,GPU:.metadata.labels.nvidia\\.com/gpu

# What node will needs:browser issues land on?
kubectl get nodes -l squad.io/capability-browser=true -o custom-columns=NAME:.metadata.name

# What capabilities does a specific node have?
kubectl get node <name> -o jsonpath='{.metadata.labels}' | python3 -c "
import sys, json
labels = json.load(sys.stdin)
caps = {k: v for k, v in labels.items() if k.startswith('squad.io/') or k.startswith('nvidia.com/')}
print(json.dumps(caps, indent=2))
"

# Force a DaemonSet reprobing cycle (by restarting)
kubectl rollout restart daemonset/squad-capability-discovery -n squad-system
```

---

## Related Documents

| Document | Description |
|----------|-------------|
| `docs/squad-on-k8s/architecture.md` | Full Squad-on-K8s architecture (§10 summarizes this doc) |
| `docs/squad-on-aks.md` | AKS deployment guide (node pool creation in context) |
| `infrastructure/k8s/crds/` | CRD YAML specs |

---

*Document authored by Seven (Research & Docs) · Issue #999 · 2026-03-20*
