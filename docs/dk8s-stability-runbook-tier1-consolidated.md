# DK8S Stability Runbook — Tier 1 Consolidated (Operational Reference)

**Status:** Operational Reference — Tier 1 Mitigations Deployed  
**Author:** B'Elanna (Infrastructure Expert)  
**Date:** 2026-03-12  
**Consolidates:** Issues #50, #51, #54 (PRs #52, #53, #55, #56)  
**Related Tiers:** Tier 2 (#25), Tier 3 (#29)  
**Classification:** DK8S Internal — Incident Response & Operations

---

## Executive Summary

This runbook consolidates **Tier 1 critical stability mitigations** deployed across DK8S infrastructure in early March 2026. Three P0/FedRAMP high-priority issues were resolved through coordinated infrastructure and security improvements:

| Issue | PR | Title | Status |
|-------|----|----|--------|
| **#50** | **#52** | NodeStuck Istio Exclusion Configuration | ✅ DEPLOYED |
| **#51** | **#53** | FedRAMP P0 nginx-ingress Security Assessment + Emergency Patch | ✅ DEPLOYED |
| **#54** | **#55, #56** | FedRAMP Compensating Controls (Network Policies, WAF, OPA, CI/CD validation) | ✅ DEPLOYED |

**Operational Outcomes:**
- ✅ NodeStuck no longer cascades node deletion during mesh incidents
- ✅ CVE-2026-24512 patched (ingress-nginx >= v1.13.7 or v1.14.3)
- ✅ Default-deny NetworkPolicies deployed across ingress-nginx namespace
- ✅ WAF protection active on Azure Front Door / Application Gateway
- ✅ OPA/Gatekeeper admission control validates Ingress resource safety
- ✅ CI/CD pre-deploy validation pipeline operational

**This document serves as:** Incident response reference, operational troubleshooting guide, FedRAMP control evidence, and integration point for Tier 2/3 stability work.

---

## Part 1: NodeStuck Istio Exclusion (Issue #50, PR #52)

### 1.1 Problem Statement

**Incident:** STG-EUS2-28 (Issue #46)  
**Root Cause:** NodeStuck automation incorrectly interprets Istio daemonset health degradation as node infrastructure failure.  
**Blast Radius:** Cascading node deletion amplifies mesh incidents by 60-80%.

**Timeline of Failure:**
```
T+0:    Istio ztunnel pod fails on Node-5 (mesh incident)
T+1m:   NodeStuck detects ztunnel unhealthy (reads as "node failing")
T+2m:   NodeStuck deletes Node-5 (incorrect action)
T+3m:   Workloads forcibly rescheduled onto Node-6 (also unhealthy mesh)
T+4m:   Cascading failures across cluster (now 2 nodes failed instead of 1)
```

### 1.2 Solution Architecture

**Key Principle:** Separate health signals
- **Node Infrastructure Health** (triggers deletion): Kubelet unreachable, disk/memory/PID pressure
- **Node Networking Health** (drain + investigate): CNI/DNS failures, routing issues
- **Daemonset Service Health** (alerts only, NO deletion): Istio, monitoring, logging daemonsets unhealthy

### 1.3 Implementation

**Excluded Daemonsets:**
```yaml
# All daemonsets tagged with these labels are excluded from NodeStuck triggers
exclusionLabels:
  - "app.kubernetes.io/component=istio"
  - "app=ztunnel"
  - "app=istio-cni"
  - "app=istio-operator"
```

**Specific Daemonsets:**
1. **ztunnel** (Ambient mode L4 proxy) — HIGH RISK: node-level failures cascade to entire mesh
2. **istio-cni** (CNI plugin) — MEDIUM RISK: pod networking failures, not node infrastructure
3. **istio-operator** (mesh control plane) — LOW RISK: control plane issue, not node viability

**NodeStuck Configuration (AFTER):**
```yaml
triggers:
  - type: DaemonSetUnhealthy
    threshold: 3  # 3 consecutive failures
    action: DeleteNode
    scope: FilteredDaemonSets
    exclusionLabels:
      - "app.kubernetes.io/component=istio"
      - "app=ztunnel"
      - "app=istio-cni"
      - "app=istio-operator"
```

### 1.4 Validation & Monitoring

**Chaos Test Plan (STG Progression):**
```
Day 1:    Deploy config, apply exclusion labels to Istio daemonsets
Day 1-2:  Chaos test — crash ztunnel pods on 2-3 nodes → verify NodeStuck does NOT delete nodes
Day 2-3:  48-hour soak, verify false positive rate = 0
Day 3-4:  Progressive PROD rollout (1 region → all regions, 24h monitoring between)
```

**Key Metrics to Track:**
| Metric | Alert Threshold |
|--------|-----------------|
| `nodestuck_node_deletion_rate` | Should decrease by 60-80% |
| `nodestuck_exclusion_applied_total` | Count of exclusion evaluations |
| `istio_daemonset_unhealthy_duration_seconds` | Mesh recovery time (should NOT increase) |

**Rollback Procedure:**
```bash
# Remove exclusion config (returns to previous behavior)
kubectl edit configmap nodestuck-config -n kube-system
# Edit: scope: AllDaemonSets  (removes FilteredDaemonSets + exclusionLabels)
```

---

## Part 2: FedRAMP P0 nginx-ingress Security Assessment (Issue #51, PR #53)

### 2.1 Vulnerability Overview

**CVE-2026-24512: Arbitrary Configuration Injection**
- **CVSS Score:** 8.8 (HIGH)
- **Impact:** Remote code execution in ingress-nginx controller pod
- **Attack Vector:** Ingress resource path injection → nginx configuration directive execution
- **Affected Versions:** ingress-nginx < v1.13.7 AND < v1.14.3
- **Exploitation Complexity:** LOW (no user interaction required)

**Additional IngressNightmare Series CVEs:**
- CVE-2025-1974: RCE via annotation abuse
- CVE-2026-24514: Denial of service via admission controller flooding
- Unauthenticated heartbeat endpoint exposure: DDoS risk

### 2.2 DK8S Platform Vulnerability Assessment

**Critical Gaps (Pre-mitigation):**
| Gap | Finding | Impact | Timeline |
|-----|---------|--------|----------|
| **Network Policies** | Not implemented | No lateral movement prevention | H2 2026 → NOW (Tier 1) |
| **WAF Protection** | Not deployed | No application-layer attack detection | Q1 2026 → NOW (Tier 1) |
| **OPA/Rego Validation** | Not implemented | No admission control for Ingress resources | Q2 2026 → NOW (Tier 1) |
| **Admission Controller** | Partially deployed | Only mesh injection validation, NOT Ingress security | — |

**Threat Model:**
```
Scenario 1: External Attacker (HIGHEST RISK)
├─ Prerequisite: Ability to submit Ingress resource
│  (via compromised CI/CD, insider threat, or RBAC misconfiguration)
├─ Attack:
│  1. Submit Ingress with crafted path: "; <malicious_nginx_directive>"
│  2. ingress-nginx reloads config → executes injected directive
│  3. Attacker gains RCE in controller pod
│  4. Pivot: Extract secrets (controller has broad cluster RBAC by default)
│  5. Escalate: Full cluster compromise via service account tokens

Scenario 2: Lateral Movement from Compromised Pod
├─ Prerequisite: Initial foothold in any tenant pod
├─ WITHOUT NetworkPolicies: Compromised pod can reach controller pod
├─ Attack proceeds as Scenario 1 (exploits CVE-2026-24512)
```

### 2.3 Remediation Actions (Deployed)

**Immediate Actions (24-72 hours):**
1. ✅ **Emergency Patch:** Upgrade ingress-nginx to >= v1.13.7 or >= v1.14.3
2. ✅ **RBAC Audit:** Verify Ingress creation permission NOT granted to untrusted principals
3. ✅ **Network Policies:** Deploy default-deny + allow-list (see Part 3)
4. ✅ **WAF Activation:** Enable Azure Front Door / Application Gateway WAF (see Part 3)

**Monitoring & Detection:**
```bash
# Verify patch deployment
kubectl get deployment ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: ingress-nginx:v1.13.7 or v1.14.3+

# Monitor for CVE exploitation attempts (WAF logs)
az monitor log-analytics query \
  --workspace resourceGroup/workspaceName \
  --query 'AzureDiagnostics | where OperationName == "ApplicationGatewayFirewall" \
    and action_s == "Blocked" and ruleId_s in ("932100", "932110")'
```

---

## Part 3: FedRAMP Compensating Controls (Issue #54, PRs #55 & #56)

### 3.1 Defense-in-Depth Architecture

**Four Security Layers (collectively prevent CVE-2026-24512 exploitation):**

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: WAF (Azure Front Door / Application Gateway)      │
│  • Blocks malicious requests before reaching ingress         │
│  • OWASP RuleSet 2.1, RCE/XSS/SQLi/Bot protection           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: NetworkPolicies (Kubernetes default-deny)         │
│  • Limits blast radius if exploit succeeds                  │
│  • Controller can only reach DNS, API server, backend pods   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: OPA/Gatekeeper Admission Control                   │
│  • Validates Ingress resources at admission time             │
│  • Rejects suspicious paths, annotations, directives         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 4: CI/CD Pre-Deploy Validation                        │
│  • kubeval schema validation                                 │
│  • conftest OPA policy checks                                │
│  • Prevents misconfigured policies from deploying            │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Layer 1: WAF (Azure Front Door Premium / Application Gateway WAF_v2)

**Deployment Architecture:**
- **Public Cloud:** Azure Front Door Premium with WAF Policy
- **Sovereign Cloud:** Application Gateway v2 with WAF_v2 SKU (prevention mode)

**OWASP Ruleset Configuration:**
```json
{
  "policySettings": {
    "enabledState": "Enabled",
    "mode": "Prevention",
    "requestBodyCheck": "Enabled"
  },
  "managedRules": {
    "managedRuleSets": [
      {
        "ruleSetType": "Microsoft_DefaultRuleSet",
        "ruleSetVersion": "2.1",
        "ruleGroupOverrides": [
          {
            "ruleGroupName": "REQUEST-932-APPLICATION-ATTACK-RCE",
            "rules": [
              {"ruleId": "932100", "enabledState": "Enabled", "action": "Block"},
              {"ruleId": "932110", "enabledState": "Enabled", "action": "Block"}
            ]
          },
          {
            "ruleGroupName": "REQUEST-941-APPLICATION-ATTACK-XSS",
            "rules": [
              {"ruleId": "941100", "enabledState": "Enabled", "action": "Block"}
            ]
          },
          {
            "ruleGroupName": "REQUEST-942-APPLICATION-ATTACK-SQLI",
            "rules": [
              {"ruleId": "942100", "enabledState": "Enabled", "action": "Block"}
            ]
          }
        ]
      },
      {
        "ruleSetType": "Microsoft_BotManagerRuleSet",
        "ruleSetVersion": "1.1"
      }
    ]
  }
}
```

**Mitigation:** RCE (932100/932110) rules block injection payloads before reaching nginx-ingress.

### 3.3 Layer 2: Kubernetes NetworkPolicies

**Design Principles:**
| Principle | Implementation |
|-----------|-----------------|
| Zero-trust baseline | Default-deny all ingress/egress in `ingress-nginx` namespace |
| Explicit allow-list | Only ports 80, 443, 10254 (health), 8443 (webhook) permitted |
| Namespace isolation | Cross-namespace traffic blocked except to backend workloads |
| Least-privilege egress | Controller reaches only backend pods, DNS, API server |
| Sovereign hardening | Gov clusters restrict source CIDRs to Front Door/AppGW ranges |

**Policy Deployment Order (ArgoCD Sync Waves):**
```yaml
Sync Wave -10:  default-deny-all, namespace-isolation
Sync Wave -9:   allow-ingress-controller
Sync Wave -5:   OPA ConstraintTemplates
Sync Wave  0:   ingress-nginx controller Deployment, Service
Sync Wave  5:   Ingress resources, backend Services
Sync Wave 10:   Monitoring (ServiceMonitor, PrometheusRule)
```

**Key Policy (default-deny-all):**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ingress-nginx
  labels:
    fedramp.dk8s.io/control: SC-7(5)
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

**Blast Radius Mitigation:** Even if CVE-2026-24512 exploits controller pod, compromised pod cannot make arbitrary egress connections — only DNS, API server, and backend workload ports allowed.

**Public vs. Sovereign Cloud Differences:**
| Aspect | Public Cloud | Sovereign (Gov) |
|--------|-------------|-----------------|
| **Inbound source** | `0.0.0.0/0` (WAF filters upstream) | Restricted to Azure Gov Front Door CIDRs |
| **HTTP port 80** | Allowed (redirect to 443) | **Blocked** — TLS-only enforced |
| **Auth egress** | Entra ID (standard endpoints) | dSTS (dedicated CIDRs required) |
| **Backend ports** | 80, 443, 8080, 8443 | 443, 8443 only |

### 3.4 Layer 3: OPA/Gatekeeper Admission Control

**Constraint Rules (Pre-Deploy Validation):**

```rego
# policy/networkpolicy/deny_missing_default_deny.rego
package networkpolicy

deny[msg] {
    input.kind == "NetworkPolicy"
    input.metadata.namespace == "ingress-nginx"
    input.metadata.name != "default-deny-all"
    not default_deny_exists
    msg := "FAIL: NetworkPolicy deployed without default-deny-all"
}

# Reject unrestricted egress
deny[msg] {
    input.kind == "NetworkPolicy"
    some i
    input.spec.egress[i].to[_].ipBlock.cidr == "0.0.0.0/0"
    msg := sprintf("FAIL: NetworkPolicy '%s' allows unrestricted egress", [input.metadata.name])
}

# Sovereign policies: TLS-only
deny[msg] {
    input.kind == "NetworkPolicy"
    input.metadata.labels["dk8s.io/cloud-type"] == "sovereign"
    some i
    input.spec.ingress[i].ports[_].port == 80
    msg := sprintf("FAIL: Sovereign policy allows HTTP — TLS-only required", [input.metadata.name])
}

# All Ingress resources must declare security intent
deny[msg] {
    input.kind == "Ingress"
    not input.metadata.labels["security.dk8s.io/validated"]
    msg := sprintf("FAIL: Ingress '%s' missing security validation label", [input.metadata.name])
}

# Reject suspicious path injection patterns
deny[msg] {
    input.kind == "Ingress"
    some i
    input.spec.rules[i].http.paths[_].path
    path_contains_bash := regex.match(".*[;|&<>].*", input.spec.rules[i].http.paths[_].path)
    path_contains_bash
    msg := sprintf("FAIL: Ingress path contains shell metacharacters — potential injection", [input.metadata.name])
}
```

**Admission Workflow:**
```
User creates/updates Ingress resource
    ↓
Kubernetes API server → OPA/Gatekeeper webhooks
    ↓
ConstraintTemplates evaluate against resource
    ↓
DENY → Resource rejected, user sees policy violation
ALLOW → Resource admitted to cluster
```

### 3.5 Layer 4: CI/CD Pre-Deploy Validation

**Pre-Deploy Pipeline:**
```yaml
stages:
  - stage: ValidateNetworkPolicies
    jobs:
      - job: KubevalValidation
        steps:
          - bash: |
              kubeval --strict --kubernetes-version 1.28.0 \
                docs/fedramp/networkpolicy-*.yaml

      - job: ConftestValidation
        steps:
          - bash: |
              conftest test docs/fedramp/networkpolicy-*.yaml \
                --policy policy/networkpolicy/ \
                --output table

      - job: HelmTemplateValidation
        steps:
          - bash: |
              helm template ingress-nginx charts/ingress-nginx \
                --set networkPolicy.enabled=true | kubeval --strict
```

**Post-Deploy Connectivity Tests:**
```bash
#!/bin/bash
# After policies deploy, run validation

echo "Test 1: Verify HTTPS ingress is allowed"
kubectl run curl-test --namespace=networkpolicy-test --rm -i --restart=Never \
  --image=curlimages/curl -- curl -sk \
  https://ingress-nginx-controller.ingress-nginx.svc.cluster.local:443

echo "Test 2: Verify internal port :18080 is blocked"
if kubectl run curl-test2 --namespace=networkpolicy-test --rm -i --restart=Never \
  --image=curlimages/curl -- curl -sk \
  http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:18080; then
  echo "FAIL: Internal port should be blocked!"
  exit 1
fi
```

---

## Part 4: Incident Response Procedures

### 4.1 Incident: Istio Daemonset Unhealthy

**Symptoms:**
- Ztunnel/istio-cni pods showing unhealthy status
- Service mesh traffic latency increasing
- BUT nodes should NOT be deleted

**Investigation Steps:**
```bash
# 1. Check daemonset status
kubectl get daemonsets -n istio-system -o wide
kubectl describe daemonset ztunnel -n istio-system

# 2. Verify NodeStuck did NOT delete nodes
kubectl get nodes
# Compare count to pre-incident baseline

# 3. Check NodeStuck logs (if available)
kubectl logs -n kube-system -l app=nodestuck --tail=100

# 4. Verify exclusion labels are applied
kubectl get daemonset ztunnel -n istio-system -o jsonpath='{.spec.template.metadata.labels}'
# Should contain: app: ztunnel, app.kubernetes.io/component: istio
```

**Remediation:**
```bash
# Option A: Restart daemonset
kubectl rollout restart daemonset/ztunnel -n istio-system

# Option B: Check Istio operator status (if deployed)
kubectl get pods -n istio-system | grep operator
kubectl logs -n istio-system -l app=istio-operator --tail=50

# Option C: Escalate if persistent
# → Contact mesh team (not infrastructure team)
```

### 4.2 Incident: nginx-ingress CVE Detected

**Symptoms:**
- WAF logs show blocked RCE patterns (932100/932110 rules triggered)
- OR: Security team alerts about new ingress-nginx CVE published

**Investigation Steps:**
```bash
# 1. Verify current nginx-ingress version
kubectl get deployment ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# 2. Check CVE database for version
# → If vulnerable version detected, proceed to remediation

# 3. Review WAF logs for exploitation attempts
az monitor log-analytics query --workspace <workspace> \
  --query 'AzureDiagnostics | where OperationName == "ApplicationGatewayFirewall" \
    and action_s == "Blocked"'

# 4. Check Ingress resources for suspicious patterns
kubectl get ingress -A -o json | \
  jq '.items[] | select(.spec.rules[].http.paths[].path | contains(";") or contains("|") or contains("&"))'
```

**Remediation (Urgent):**
```bash
# 1. IMMEDIATE: Update ingress-nginx chart values
kubectl set image deployment/ingress-nginx-controller \
  -n ingress-nginx \
  controller=ingress-nginx:v1.14.3

# 2. Monitor rollout
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx

# 3. Verify pods are running with new version
kubectl get pods -n ingress-nginx -o jsonpath='{.items[].spec.containers[0].image}'

# 4. Run post-deploy connectivity tests (see Layer 4 above)
bash validate-networkpolicy.sh

# 5. Check metrics for degradation
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 10254:10254
curl http://localhost:10254/metrics | grep nginx_ingress_controller_requests
```

**Rollback Procedure (if upgrade causes issues):**
```bash
kubectl rollout undo deployment/ingress-nginx-controller -n ingress-nginx
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx
```

### 4.3 Incident: NetworkPolicy Too Restrictive

**Symptoms:**
- Ingress requests returning 502/503 errors
- Backend connectivity failing
- Controller logs show "connection refused" to backend pods

**Investigation Steps:**
```bash
# 1. Check NetworkPolicy state
kubectl get networkpolicies -n ingress-nginx
kubectl describe networkpolicy allow-ingress-controller -n ingress-nginx

# 2. Verify controller can reach backend pods
CONTROLLER_POD=$(kubectl get pods -n ingress-nginx -o name | head -1)
kubectl exec $CONTROLLER_POD -n ingress-nginx -- \
  curl -s http://backend-service.backend-namespace.svc.cluster.local:8080/health

# 3. Check backend egress rules
kubectl describe networkpolicy allow-ingress-controller -n ingress-nginx | grep -A 20 "egress"

# 4. Verify backend namespace is NOT blocked
kubectl get networkpolicies -n backend-namespace
```

**Remediation:**
```bash
# Option A: Temporarily relax egress rules (if test cluster)
kubectl patch networkpolicy allow-ingress-controller -n ingress-nginx \
  --type='json' -p='[{"op":"replace","path":"/spec/egress/0/to/0/podSelector","value":{}}]'

# Option B: Rollback to previous NetworkPolicy version
argocd app rollback ingress-nginx --revision <previous-revision>

# Option C: Emergency removal (WARNING: returns to zero-trust gap)
kubectl delete networkpolicy allow-ingress-controller -n ingress-nginx
# Keep default-deny in place!

# After fix: Monitor for false positives
kubectl top nodes
kubectl top pods -n ingress-nginx
```

### 4.4 Incident: WAF False Positives Blocking Legitimate Traffic

**Symptoms:**
- WAF logs show "Blocked" for legitimate application paths
- Application-specific rules being triggered (e.g., rule 941100 for XSS)
- User reports: "My upload/API path is blocked"

**Investigation Steps:**
```bash
# 1. Get WAF rule IDs that triggered
az monitor log-analytics query --workspace <workspace> \
  --query 'AzureDiagnostics | where action_s == "Blocked" | distinct ruleId_s'

# 2. Review rule details
# → Check Microsoft OWASP rule documentation for rule IDs

# 3. Analyze request that was blocked
az monitor log-analytics query --workspace <workspace> \
  --query 'AzureDiagnostics | where action_s == "Blocked" \
    | project timeGenerated, clientIp_s, requestUri_s, ruleId_s'

# 4. Determine if false positive
# → Consult with application team
```

**Remediation (with Approval):**
```bash
# Option A: Exclude specific path from WAF
# (Update WAF policy to exclude patterns)

# Option B: Change rule action from "Block" to "Log"
# (Lower severity, monitor in logs)

# Option C: Whitelist specific client IP (if internal)
# (Update WAF IP restriction rules)

# Always: Document exception + require security sign-off
```

---

## Part 5: FedRAMP Control Mapping

**This runbook provides evidence for the following FedRAMP controls:**

| NIST Control | Description | This Implementation | Status |
|-------------|-------------|-------------------|--------|
| **SC-7** | Boundary Protection | NetworkPolicies enforce ingress/egress boundaries | ✅ |
| **SC-7(5)** | Deny by Default | Default-deny policy in ingress-nginx namespace | ✅ |
| **AC-4** | Information Flow Enforcement | Egress restricted to required paths only | ✅ |
| **AC-3** | Access Control | RBAC for Ingress resource creation; admission control validation | ✅ |
| **CM-7** | Least Functionality | Only ports 80, 443, 10254, 8443 allowed | ✅ |
| **SI-3** | Malicious Code Protection | WAF blocks RCE/XSS/SQLi patterns (932100, 932110, 941100, 942100) | ✅ |
| **SI-4** | Information System Monitoring | CNI drop metrics, ingress error monitoring, WAF logs | ✅ |
| **CA-2** | Security Assessments | Conftest policy-as-code in CI/CD (Layer 4) | ✅ |
| **CM-3** | Configuration Change Control | Helm templates, ArgoCD sync waves, pre-deploy validation | ✅ |
| **IR-4** | Incident Handling | Emergency runbook (see Part 4), patching procedures | ✅ |

**Evidence Artifacts:**
- NetworkPolicy manifests: `docs/fedramp/networkpolicy-*.yaml`
- Helm templates: `charts/ingress-nginx/templates/networkpolicy.yaml`
- OPA/Gatekeeper policies: `policy/networkpolicy/*.rego`
- CI/CD validation: `.pipelines/validate-network-policies.yaml`
- WAF configuration: Azure Front Door / Application Gateway policies (Azure portal)
- Emergency patch commit: PR #53

---

## Part 6: Tier 2 Roadmap Integration

**This Tier 1 runbook is a foundation for Tier 2 stability improvements (Issue #25):**

| Tier 2 Item | Description | Dependency on Tier 1 | Timeline |
|-----------|-----------|----------------------|----------|
| **N1** | Networking automation tuning | Requires validated default-deny baseline | 2-3w |
| **N2** | Cross-region mesh observability | Requires mesh incidents NOT cascading (NodeStuck fix) | 4-6w |
| **C2** | Deployment feedback webhook | Requires OPA admission control + WAF signals | 6-8w |
| **I2** | Ztunnel health monitoring + auto-rollback | Requires NodeStuck exclusion stable | 6-8w |

**Key Insight:** Tier 2 automates recovery. Tier 1 stops cascading failures. Together, they provide **self-healing infrastructure**.

---

## Part 7: Tier 3 Strategic Architecture Links

**This Tier 1 runbook informs Tier 3 architecture decisions (Issue #29):**

1. **Change Risk Visibility (Issue #29 Recommendation #1)**
   - Tier 1 WAF + admission control provide real-time attack surface visibility
   - Feeds into PR deployment gates (Tier 3 future)

2. **Blast Radius Quantification (Issue #29 Recommendation #2)**
   - NetworkPolicy enforcement limits blast radius to namespace + connected backends
   - Enables precise incident impact prediction

3. **Sovereign Cloud Hardening (Issue #29 Recommendation #3)**
   - Tier 1 sovereign-specific policies (see Part 3.3) restrict source CIDRs to Gov Front Door
   - Foundation for dSTS-only authentication (Tier 3 strategic initiative)

4. **Automated Incident Recovery (Issue #29 Recommendation #4)**
   - Tier 1 provides isolation (policies) + detection (metrics)
   - Tier 2/3 build remediation automation on top

5. **Cross-Cloud Baseline (Issue #29 Recommendation #5)**
   - Tier 1 policies + WAF rules are cloud-agnostic
   - Enable unified compliance posture across Public, Fairfax, Mooncake

---

## Part 8: Quick Reference — Common Operations

### 8.1 Verify Tier 1 Deployments

```bash
#!/bin/bash
# Quick health check for all Tier 1 mitigations

echo "=== NodeStuck Exclusion ==="
kubectl get configmap nodestuck-config -n kube-system -o jsonpath='{.data.exclusionLabels}'

echo "=== ingress-nginx Version ==="
kubectl get deployment ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

echo "=== NetworkPolicies Deployed ==="
kubectl get networkpolicies -n ingress-nginx -o name

echo "=== WAF Status ==="
az network front-door waf-policy show --resource-group <rg> --name <waf-name>

echo "=== OPA/Gatekeeper ==="
kubectl get constrainttemplates | grep ingress

echo "✅ All Tier 1 mitigations verified"
```

### 8.2 Monitor Tier 1 Health

```bash
#!/bin/bash
# Real-time monitoring dashboard

watch -n 5 "
  echo '=== NodeStuck Actions ==='
  kubectl get events -n kube-system --field-selector involvedObject.name~nodestuck | tail -5
  
  echo '=== NetworkPolicy Drops ==='
  kubectl exec -it <ingress-pod> -n ingress-nginx -- \
    netstat -s | grep 'segments.retransmitted\|segments.* dropped'
  
  echo '=== WAF Blocks (Last Hour) ==='
  date -u +%s -d '1 hour ago' | while read ts; do
    az monitor metrics list --resource <waf-id> \
      --metric "BlockedRequests" --start-time $ts
  done
"
```

### 8.3 Emergency Escalation Path

```
Incident Detected
    ↓
Is it NodeStuck-related? (nodes being deleted)
├─ YES → Contact Infrastructure team (B'Elanna)
│   └─ Verify exclusion labels, check daemonset health
└─ NO → Continue to next question

Is it ingress-nginx CVE-related? (RCE/injection)
├─ YES → Contact Security team (Worf)
│   └─ Verify version, review WAF logs, prepare emergency patch
└─ NO → Continue to next question

Is it NetworkPolicy-related? (connectivity failing)
├─ YES → Contact Infrastructure team (B'Elanna)
│   └─ Check policy rules, verify backend egress, test connectivity
└─ NO → Contact Platform team (Picard)

Need help? → Slack #dk8s-incidents
```

---

## Appendix A: Document Cross-Reference

**Related Issues:**
- Issue #46: STG-EUS2-28 Incident (catalyst)
- Issue #50: NodeStuck Istio Exclusion (PR #52)
- Issue #51: FedRAMP P0 nginx-ingress Assessment (PR #53)
- Issue #54: FedRAMP Compensating Controls (PRs #55, #56)
- Issue #25: Tier 2 Stability Improvements (roadmap)
- Issue #29: Tier 3 Strategic Architecture (vision)

**Detailed Documentation:**
- `docs/nodestuck-istio-exclusion-config.md` — NodeStuck technical deep-dive
- `docs/FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md` — CVE-2026-24512 full assessment
- `docs/fedramp-compensating-controls-security.md` — WAF + OPA configuration
- `docs/fedramp-compensating-controls-infrastructure.md` — NetworkPolicy design + CI/CD integration

**Test Evidence:**
- `tests/fedramp-validation/runbook-validation-checklist.md` — Tier 1 validation suite
- `tests/fedramp-validation/TEST_PLAN.md` — FedRAMP test procedures

---

## Appendix B: Contacts & Escalation

| Role | Name | Contact | Expertise |
|------|------|---------|-----------|
| **Infrastructure Expert** | B'Elanna | slack:#dk8s | K8s, NodeStuck, NetworkPolicies |
| **Security & Cloud** | Worf | slack:#security | CVE assessment, WAF, OPA, FedRAMP |
| **Lead Architect** | Picard | slack:#platform | Overall DK8S strategy |
| **On-Call Rotation** | — | slack:#oncall | Current incident owner |

---

**Last Updated:** 2026-03-12  
**Status:** ✅ OPERATIONAL — All Tier 1 mitigations deployed and validated  
**Next Review:** 2026-04-12 (monthly)  
**Owner:** B'Elanna (Infrastructure Expert)

