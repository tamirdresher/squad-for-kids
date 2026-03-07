# FedRAMP Compensating Controls — Infrastructure Implementation
## Issue #54: Network Policies, Helm Integration, CI/CD Pipeline

**Author:** B'Elanna (Infrastructure Expert)  
**Date:** 2026-03-12  
**Status:** Implementation-Ready  
**FedRAMP Controls:** SC-7 (Boundary Protection), AC-4 (Information Flow), CM-7 (Least Functionality)

---

## 1. Executive Summary

CVE-2026-24512 (CVSS 8.8) exposed that DK8S has **zero compensating controls** around ingress-nginx. This document delivers production-ready Kubernetes NetworkPolicies, Helm chart integration, and CI/CD pipeline validation to establish defense-in-depth for ingress endpoints across all cloud environments.

**What ships:**
- Default-deny NetworkPolicy baseline for `ingress-nginx` namespace
- Allow-list policies for controller traffic (public + sovereign)
- Helm templates with per-environment configuration
- ArgoCD sync wave ordering (policies deploy before ingress)
- CI/CD pre-deploy validation pipeline (kubeval + conftest)
- Progressive rollout strategy: Test → PPE → Prod → Sovereign

---

## 2. Network Policies

### 2.1 Design Principles

| Principle | Implementation |
|-----------|---------------|
| **Zero-trust baseline** | Default-deny all ingress/egress in `ingress-nginx` namespace |
| **Explicit allow-list** | Only ports 80, 443, 10254 (health), 8443 (webhook) permitted inbound |
| **Namespace isolation** | Cross-namespace traffic blocked except to backend workloads |
| **Least-privilege egress** | Controller can only reach backend pods, DNS, and API server |
| **Sovereign hardening** | Gov clusters restrict source CIDRs to known Front Door/AppGW ranges |

### 2.2 Policy Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ingress-nginx namespace                    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │           default-deny-all (sync-wave: -10)          │    │
│  │   Blocks ALL ingress + egress to/from all pods       │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │      allow-ingress-controller (sync-wave: -9)        │    │
│  │                                                       │    │
│  │  INGRESS:                    EGRESS:                  │    │
│  │  ├─ :80/:443 from LB/FD     ├─ :80/:443/:8080/:8443  │    │
│  │  ├─ :10254 from kubelet          to backend namespaces│    │
│  │  └─ :8443 from API server   ├─ :53 to kube-dns       │    │
│  │                              └─ :443 to API server    │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  deny-cross-namespace-to-internals (sync-wave: -10)  │    │
│  │   Blocks access to nginx status, metrics abuse,       │    │
│  │   debug/admin endpoints from other namespaces         │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 Manifest Files

All manifests are in [`docs/fedramp/`](fedramp/):

| File | Purpose | Sync Wave |
|------|---------|-----------|
| `networkpolicy-ingress-default-deny.yaml` | Default-deny all traffic | -10 |
| `networkpolicy-ingress-controller.yaml` | Allow-list for controller (public cloud) | -9 |
| `networkpolicy-ingress-sovereign.yaml` | Allow-list for controller (Fairfax/Mooncake) | -9 |
| `networkpolicy-namespace-isolation.yaml` | Block cross-namespace internal access | -10 |

### 2.4 Public vs. Sovereign Cloud Differences

| Aspect | Public Cloud | Sovereign (Gov) |
|--------|-------------|-----------------|
| **Inbound source** | `0.0.0.0/0` (WAF filters upstream) | Restricted to Azure Gov Front Door CIDRs |
| **HTTP port 80** | Allowed (redirect to 443) | **Blocked** — TLS-only enforced |
| **Auth egress** | Entra ID (standard endpoints) | dSTS (dedicated CIDRs required) |
| **Backend ports** | 80, 443, 8080, 8443 | 443, 8443 only |

### 2.5 CVE-2026-24512 Mitigation

These policies directly mitigate CVE-2026-24512 by:

1. **Limiting blast radius:** Even if an attacker injects config via `rules.http.paths.path`, the compromised controller pod cannot make arbitrary egress connections — only DNS, API server, and backend workload ports are permitted.
2. **Blocking lateral movement:** Default-deny prevents a compromised controller from scanning or connecting to pods in `kube-system` or other infrastructure namespaces.
3. **Restricting ingress surface:** Sovereign clusters accept traffic only from known Front Door CIDRs, blocking exploitation from arbitrary internet sources.

---

## 3. Helm Chart Integration

### 3.1 Template

The Helm template at [`docs/fedramp/helm-networkpolicy-template.yaml`](fedramp/helm-networkpolicy-template.yaml) generates both the default-deny and allow-list policies from a single template, controlled by `values.yaml`.

**Key features:**
- `networkPolicy.enabled` — master switch (default: `true`)
- `networkPolicy.sovereign.enabled` — activates restricted CIDRs for gov clusters
- `networkPolicy.nodeCIDRs` — configurable per-cluster node CIDR ranges
- `networkPolicy.allowedBackendPorts` — customizable backend port list

### 3.2 Values Configuration

Reference values at [`docs/fedramp/helm-values-networkpolicy.yaml`](fedramp/helm-values-networkpolicy.yaml).

**Per-environment override pattern** (ArgoCD ApplicationSet):

```yaml
# applicationset.yaml
spec:
  generators:
    - list:
        elements:
          - cluster: test-eus2
            environment: test
            valuesFile: values-test.yaml
          - cluster: prod-eus2
            environment: prod
            valuesFile: values-prod.yaml
          - cluster: gov-usva
            environment: sovereign
            valuesFile: values-sovereign.yaml
  template:
    spec:
      source:
        helm:
          valueFiles:
            - values.yaml
            - '{{ valuesFile }}'
```

### 3.3 ArgoCD Sync Wave Ordering

NetworkPolicies **must** deploy before Ingress resources to prevent a window where traffic flows without policy enforcement.

```
Sync Wave -10:  default-deny-all, namespace-isolation
Sync Wave -9:   allow-ingress-controller
Sync Wave -5:   OPA ConstraintTemplates (Worf's deliverable)
Sync Wave  0:   ingress-nginx controller Deployment, Service
Sync Wave  5:   Ingress resources, backend Services
Sync Wave 10:   Monitoring (ServiceMonitor, PrometheusRule)
```

**Why this ordering matters:**
- If Ingress deploys before NetworkPolicy, there is a time window where the controller accepts traffic without boundary enforcement.
- ArgoCD sync waves guarantee atomic ordering within a single sync operation.
- The `-10` wave ensures zero-trust is established before any workload pods start.

---

## 4. CI/CD Pipeline Integration

### 4.1 Pre-Deploy Validation Pipeline

Add to the existing OneBranch pipeline (or Azure DevOps YAML pipeline):

```yaml
# .pipelines/validate-network-policies.yaml
stages:
  - stage: ValidateNetworkPolicies
    displayName: "Validate Network Policies & Ingress Config"
    jobs:
      - job: KubevalValidation
        displayName: "Schema Validation (kubeval)"
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: Bash@3
            displayName: 'Install kubeval'
            inputs:
              targetType: inline
              script: |
                wget -q https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
                tar xf kubeval-linux-amd64.tar.gz
                sudo mv kubeval /usr/local/bin/

          - task: Bash@3
            displayName: 'Validate NetworkPolicy manifests'
            inputs:
              targetType: inline
              script: |
                echo "=== Validating NetworkPolicy manifests ==="
                kubeval --strict --kubernetes-version 1.28.0 \
                  docs/fedramp/networkpolicy-*.yaml
                echo "=== All NetworkPolicy manifests are valid ==="

      - job: ConftestValidation
        displayName: "Policy-as-Code (conftest/OPA)"
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: Bash@3
            displayName: 'Install conftest'
            inputs:
              targetType: inline
              script: |
                wget -q https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_Linux_x86_64.tar.gz
                tar xf conftest_Linux_x86_64.tar.gz
                sudo mv conftest /usr/local/bin/

          - task: Bash@3
            displayName: 'Run policy checks'
            inputs:
              targetType: inline
              script: |
                echo "=== Running OPA policy checks ==="
                conftest test docs/fedramp/networkpolicy-*.yaml \
                  --policy policy/networkpolicy/ \
                  --output table
                echo "=== Policy checks passed ==="

      - job: HelmTemplateValidation
        displayName: "Helm Template Render & Validate"
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: HelmDeploy@0
            displayName: 'Helm template (public cloud)'
            inputs:
              command: template
              chartPath: charts/ingress-nginx
              releaseName: ingress-nginx
              overrideValues: 'networkPolicy.enabled=true'

          - task: HelmDeploy@0
            displayName: 'Helm template (sovereign cloud)'
            inputs:
              command: template
              chartPath: charts/ingress-nginx
              releaseName: ingress-nginx
              valueFile: charts/ingress-nginx/values-sovereign.yaml

          - task: Bash@3
            displayName: 'Validate rendered templates with kubeval'
            inputs:
              targetType: inline
              script: |
                helm template ingress-nginx charts/ingress-nginx \
                  --set networkPolicy.enabled=true | kubeval --strict
```

### 4.2 Conftest Policy Rules

```rego
# policy/networkpolicy/deny_missing_default_deny.rego
package networkpolicy

deny[msg] {
    input.kind == "NetworkPolicy"
    input.metadata.namespace == "ingress-nginx"
    input.metadata.name != "default-deny-all"
    not default_deny_exists
    msg := "FAIL: NetworkPolicy deployed to ingress-nginx without default-deny-all policy"
}

default_deny_exists {
    input.kind == "NetworkPolicy"
    input.metadata.name == "default-deny-all"
    input.spec.podSelector == {}
    count(input.spec.ingress) == 0
    count(input.spec.egress) == 0
}

# Reject NetworkPolicies that allow 0.0.0.0/0 egress
deny[msg] {
    input.kind == "NetworkPolicy"
    input.metadata.namespace == "ingress-nginx"
    some i
    input.spec.egress[i].to[_].ipBlock.cidr == "0.0.0.0/0"
    msg := sprintf("FAIL: NetworkPolicy '%s' allows unrestricted egress (0.0.0.0/0)", [input.metadata.name])
}

# Sovereign policies must not allow HTTP (port 80)
deny[msg] {
    input.kind == "NetworkPolicy"
    input.metadata.labels["dk8s.io/cloud-type"] == "sovereign"
    some i
    input.spec.ingress[i].ports[_].port == 80
    msg := sprintf("FAIL: Sovereign NetworkPolicy '%s' allows HTTP port 80 — TLS-only required", [input.metadata.name])
}

# All policies must have FedRAMP control label
deny[msg] {
    input.kind == "NetworkPolicy"
    input.metadata.namespace == "ingress-nginx"
    not input.metadata.labels["fedramp.dk8s.io/control"]
    msg := sprintf("FAIL: NetworkPolicy '%s' missing fedramp.dk8s.io/control label", [input.metadata.name])
}
```

### 4.3 Progressive Rollout Strategy

```
Stage 1: Test Cluster (automated)
  ├─ Deploy NetworkPolicies via ArgoCD sync
  ├─ Run connectivity tests (curl from pod → ingress, verify blocked paths)
  ├─ Run chaos test: attempt egress to blocked CIDR → must fail
  └─ Gate: All tests pass → auto-promote

Stage 2: PPE Cluster (automated + manual gate)
  ├─ Deploy via ArgoCD sync
  ├─ Run integration tests against PPE workloads
  ├─ Monitor: Zero increase in 5xx errors, zero dropped healthchecks
  └─ Gate: 24-hour soak → manual approval

Stage 3: Prod Clusters (ring-based)
  ├─ Ring 0: 1 prod cluster (lowest traffic)
  ├─ 24-hour soak + monitoring
  ├─ Ring 1: Remaining prod clusters
  └─ Gate: SRE approval per ring

Stage 4: Sovereign Clusters (manual)
  ├─ Deploy sovereign-specific policies
  ├─ Validate dSTS egress connectivity
  ├─ FedRAMP compliance team sign-off
  └─ 48-hour soak with enhanced monitoring
```

### 4.4 Validation Tests (Post-Deploy)

```bash
#!/bin/bash
# validate-networkpolicy.sh — Run after deployment to verify policies work
set -euo pipefail

NAMESPACE="ingress-nginx"
TEST_NS="networkpolicy-test"

echo "=== Creating test namespace ==="
kubectl create namespace $TEST_NS --dry-run=client -o yaml | kubectl apply -f -

echo "=== Test 1: Verify ingress on :443 is allowed ==="
kubectl run curl-test --namespace=$TEST_NS --rm -i --restart=Never \
  --image=curlimages/curl -- curl -sk --connect-timeout 5 \
  https://ingress-nginx-controller.$NAMESPACE.svc.cluster.local:443
echo "PASS: HTTPS ingress allowed"

echo "=== Test 2: Verify internal port :18080 is blocked ==="
if kubectl run curl-test2 --namespace=$TEST_NS --rm -i --restart=Never \
  --image=curlimages/curl -- curl -sk --connect-timeout 5 \
  http://ingress-nginx-controller.$NAMESPACE.svc.cluster.local:18080 2>/dev/null; then
  echo "FAIL: Internal port 18080 should be blocked!"
  exit 1
fi
echo "PASS: Internal port blocked by NetworkPolicy"

echo "=== Test 3: Verify healthcheck :10254 from node CIDR ==="
kubectl run curl-test3 --namespace=$NAMESPACE --rm -i --restart=Never \
  --image=curlimages/curl -- curl -s --connect-timeout 5 \
  http://localhost:10254/healthz
echo "PASS: Healthcheck accessible"

echo "=== Cleanup ==="
kubectl delete namespace $TEST_NS --ignore-not-found

echo "=== All NetworkPolicy validation tests passed ==="
```

---

## 5. Monitoring & Alerting

### 5.1 Metrics to Track

| Metric | Source | Alert Threshold |
|--------|--------|----------------|
| `networkpolicy_drop_count` | Calico/Cilium CNI | > 0 drops on allowed paths |
| `nginx_ingress_controller_requests` | ingress-nginx | Drop > 10% after policy deploy |
| `nginx_ingress_controller_upstream_connect_errors` | ingress-nginx | Increase after deploy = policy too restrictive |
| `kube_networkpolicy_count` | kube-state-metrics | < expected count = drift |

### 5.2 Rollback Procedure

```bash
# Emergency rollback: Remove restrictive policies, keep default-deny
kubectl delete networkpolicy allow-ingress-controller -n ingress-nginx
kubectl delete networkpolicy deny-cross-namespace-to-internals -n ingress-nginx

# Full rollback: Remove all policies (WARNING: returns to zero-trust gap)
kubectl delete networkpolicy --all -n ingress-nginx

# ArgoCD rollback to previous sync
argocd app rollback ingress-nginx --revision <previous-revision>
```

---

## 6. Dependencies on Other Workstreams

| Workstream | Owner | Dependency |
|-----------|-------|------------|
| WAF Rules (Azure Front Door) | Worf (Security) | WAF must be in place before sovereign policies can restrict to FD CIDRs |
| OPA/Gatekeeper Admission | Worf (Security) | ConstraintTemplates validate Ingress resources at admission time |
| Emergency Patching Runbook | Worf (Security) | Runbook references NetworkPolicy rollback procedure from §5.2 |
| Ingress Vulnerability Scan | Data (Code Expert) | CI/CD pipeline integration point in §4.1 |

---

## 7. FedRAMP Control Mapping

| NIST Control | Description | This Implementation |
|-------------|-------------|-------------------|
| **SC-7** | Boundary Protection | NetworkPolicies enforce ingress/egress boundaries |
| **SC-7(5)** | Deny by Default | Default-deny policy in ingress-nginx namespace |
| **AC-4** | Information Flow Enforcement | Egress restricted to required paths only |
| **CM-7** | Least Functionality | Only ports 80, 443, 10254, 8443 allowed |
| **SI-4** | Information System Monitoring | CNI drop metrics + ingress error monitoring |
| **CA-2** | Security Assessments | Conftest policy-as-code in CI/CD |

---

*Document generated as part of Issue #54 FedRAMP compensating controls implementation.*
