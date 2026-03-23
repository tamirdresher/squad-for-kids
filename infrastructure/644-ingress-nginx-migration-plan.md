# Ingress-NGINX EOL → Gateway API Migration Plan

**Issue:** [#644](https://github.com/tamirdresher_microsoft/tamresearch1/issues/644)  
**Author:** B'Elanna (Infrastructure Expert)  
**Date:** 2026-03-22  
**Priority:** 🔴 CRITICAL — EOL was March 16, 2026 (6 days past deadline)  
**Status:** ACTIVE — No patched version deployed yet

---

## Context & Background

Ingress-NGINX (community-maintained `kubernetes/ingress-nginx`) reached **End-of-Life on March 16, 2026**. After EOL:

- No further security patches, bug fixes, or releases
- CVE-2026-24512 (CVSS 8.8, RCE) and the IngressNightmare series remain actively exploitable in versions < 1.13.7 / 1.14.3
- FedRAMP P0 compliance is breached — remediation was required within 24h of the 2026-03-06 assessment ([`FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md`](../FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md))

The DK8S platform (internal Kubernetes on AKS, 19 tenants, government cloud targets including Fairfax) must migrate to a **supported ingress/gateway solution immediately**.

---

## Scope

| Component | Affected |
|---|---|
| DK8S AKS clusters (all regions) | ✅ All clusters running ingress-nginx |
| squad-on-aks workloads | ✅ squad Helm chart, Ralph agent |
| Sovereign cloud clusters (Fairfax) | ✅ Must follow within 24–48h |
| Mooncake (China) | ⚠️ Audit required — possible deprecation path |

---

## Current State

### ingress-nginx Controller

```
Controller:        kubernetes/ingress-nginx (community OSS)
Known vuln:        CVE-2026-24512 (CVSS 8.8, RCE), CVE-2025-1974, CVE-2026-24514
Affected versions: < v1.13.7 / < v1.14.3
EOL date:          March 16, 2026
Status:            UNPATCHED (version not yet confirmed in codebase — ASSUME VULNERABLE)
```

### Current Cluster Ingress Pattern (squad-on-aks)

The squad Helm chart currently exposes Ralph via a `ClusterIP` Service with no external ingress. Any external-facing services on DK8S clusters use the platform-managed ingress-nginx controller with standard `Ingress` resources and `kubernetes.io/ingress.class: nginx` annotation.

### Key Gaps (from FedRAMP P0 Assessment)

| Gap | Status |
|---|---|
| Network Policies (default-deny) | ❌ Not implemented (H2 2026 planned) |
| WAF (Azure Front Door) | ❌ Not deployed (Q1 2026 planned) |
| OPA/Rego admission validation | ❌ Not implemented (Q2 2026 planned) |
| Ingress RBAC audit | ❌ Not documented |

---

## Target State

### Decision: AKS Application Routing Add-on (Interim) → Gateway API (Long-term)

Based on internal DK8S guidance ([eng.ms: Migration Plan — Transition to AKS Application Routing Add-on](https://eng.ms/docs/microsoft-security/microsoft-threat-protection-mtp/onesoc-1soc/infra-and-developer-platform-scip-idp/infra-and-developer-platform-scip-idp/internal/defender-k8s/engineering/transition_to_aks_application_routing_addon)):

#### Phase 1 (Immediate): AKS Application Routing Add-on

The DK8S team has validated and recommends the **AKS Application Routing Add-on** as the transitional solution:

- ✅ Fully managed and patched by the AKS platform team
- ✅ Drops-in as ingress-nginx replacement (same `Ingress` API — no app changes)
- ✅ Lifecycle managed through Microsoft — EOL risk transferred to AKS team
- ✅ Support committed through November 2026
- ✅ Internally uses NGINX but under Microsoft management (security patches SLA)
- ✅ Validated feature parity for DK8S workloads (host/path routing, TLS, LB, annotations)

**IngressClass:** `webapprouting.kubernetes.azure.com`

**Known gaps vs OSS NGINX (DK8S validation findings):**

| Feature | OSS NGINX | App Routing Add-on |
|---|---|---|
| KEDA-based custom scaling | ✅ | ❌ (standard HPA only) |
| Custom cipher suites (ECDHE-ECDSA-AES256-SHA384 etc.) | ✅ | ❌ |
| ConfigMap global auth URL | ✅ | ❌ (per-Ingress only) |
| CORS via ConfigMap | ✅ | ❌ (per-Ingress annotation) |
| External auth log labels | ✅ | ❌ (dropped) |
| Custom certificate rotation (PFX shared cert) | ✅ | ⚠️ Partial |

> **Action required for CORS/auth users:** Services using global CORS config or external auth URL must **rebuild and redeploy** with per-Ingress annotations before migration.

#### Phase 2 (Q3 2026): Kubernetes Gateway API

The Kubernetes community's modern successor to the Ingress API. Target implementation: **Azure Application Gateway for Containers** or **Cilium Gateway API** (to be confirmed with DK8S Infra team).

Gateway API advantages:
- Role-oriented: separates infrastructure (GatewayClass/Gateway) from app routing (HTTPRoute)
- Native multi-protocol support (HTTP, TCP, gRPC, TLS)
- No annotation sprawl — first-class header matching, traffic splitting, retries
- Supported by Azure Application Gateway for Containers (GA on AKS)

---

## Migration Strategy: Single Mode (Cluster-wide)

Per DK8S internal recommendation, we adopt **Single Mode migration** (not dual-mode):

| Factor | Single Mode | Why we choose it |
|---|---|---|
| New public IP required | ❌ No | Avoids firewall/client IP updates |
| Service redeployment | ❌ Not required | Only CORS/auth services must redeploy |
| Rollout | Cluster-wide | Fast, clean cut-over |
| Effort from service teams | Very low | Only validation post-migration |
| Rollback | Cluster-wide via pipeline (~10 min) | Controlled |
| Expected downtime | ~8 minutes | Acceptable for non-DR services |

---

## Migration Timeline

### 🔴 WEEK 1 (March 22–29, 2026) — CRITICAL

| Day | Action | Owner |
|---|---|---|
| Day 1 (Mar 22) | **Audit all DK8S clusters** — confirm ingress-nginx version via `kubectl get deployment` | DK8S Infra |
| Day 1 | **Identify CORS/auth-URL services** via Kusto query (see DK8S runbook) | DK8S Infra |
| Day 1–2 | **CORS/auth services rebuild and redeploy** with per-Ingress annotations | Service owners |
| Day 2–3 | **Enable `ENABLE_APP_ROUTING_ADD_ON` flag** in clusterInventory (per DK8S eng.ms runbook) | DK8S Infra |
| Day 3 | **Test ring deployment** (allow 2h for artifact propagation) — validate heartbeat, TLS, routing | DK8S Infra + Squad |
| Day 4 | **PPE ring deployment** — monitor for regression (8 min expected downtime window) | DK8S Infra |
| Day 5–7 | **Production ring deployment** — execute traffic switch | DK8S Infra |
| Day 7 | **Validate Application Routing Dashboard** — confirm NGINX pods healthy | DK8S Infra |

### ⚠️ WEEK 2 (March 29 – April 5, 2026) — Sovereign Clouds

| Day | Action | Owner |
|---|---|---|
| Day 8–9 | **Fairfax (US Gov)** cluster migration — same process, sovereign cloud timeline | DK8S Infra |
| Day 9–10 | **Mooncake (China)** audit and migration (if not on deprecation path) | DK8S Infra |
| Day 10 | **OPA emergency policy** for any delayed clusters: block ALL new Ingress creation except `kube-system` | DK8S Infra |

### 📋 Q3 2026 — Gateway API Migration (Phase 2)

| Month | Action |
|---|---|
| April | Architecture decision: Application Gateway for Containers vs Cilium Gateway API |
| May | Proof-of-concept: HTTPRoute equivalents for squad workloads |
| June | Pilot migration: squad-on-aks namespace |
| July | Full cluster Gateway API rollout |

---

## Step-by-Step Migration Process

### Step 1: Audit Current State

```bash
# Check ingress-nginx version across all clusters
kubectl get deployment -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# List all current Ingress resources
kubectl get ingress --all-namespaces -o wide

# Audit Ingress creation RBAC
kubectl get rolebindings,clusterrolebindings --all-namespaces -o json | \
  jq '.items[] | select(.roleRef.kind=="ClusterRole" and (.roleRef.name | contains("ingress")))'

# Check for CORS annotations (services needing special handling)
kubectl get ingress --all-namespaces -o json | \
  jq '.items[] | select(.metadata.annotations | to_entries[] | .key | contains("cors"))'
```

### Step 2: Enable Application Routing Add-on

```bash
# Enable on existing cluster
az aks approuting enable \
  --resource-group <ResourceGroupName> \
  --name <ClusterName>

# Verify the add-on is running
kubectl get pods -n app-routing-system

# Check NginxIngressController CRD is available
kubectl get nginxingresscontroller -A
```

### Step 3: Apply squad NginxIngressController CR

Deploy the custom NginxIngressController CR that matches our workload requirements:

```bash
kubectl apply -f infrastructure/gateway-api/squad-nginx-ingress-controller.yaml
```

### Step 4: Traffic Switch

Update squad Helm chart to use new IngressClass:

```bash
# In squad values, update ingressClassName to webapprouting.kubernetes.azure.com
helm upgrade squad infrastructure/helm/squad \
  --set ingress.className=webapprouting.kubernetes.azure.com \
  --namespace squad \
  --wait
```

### Step 5: Validate and Monitor

```bash
# Confirm all ingress traffic is flowing through new controller
kubectl get ingress --all-namespaces

# Check Application Routing Dashboard metrics
# Monitor for 8-minute downtime window

# Verify heartbeat endpoint
curl -I https://<cluster-ingress-ip>/healthz
```

---

## Risk Assessment

| Risk | Severity | Probability | Mitigation |
|---|---|---|---|
| **~8 min downtime during cut-over** | Medium | High | Schedule during low-traffic window; DR regions absorb traffic for DR-enabled services |
| **CORS/auth services break post-migration** | High | Medium | Identify and redeploy BEFORE migration; Kusto query per DK8S runbook |
| **Custom cipher suites incompatibility** | High | Low | Audit cipher suite usage; negotiate with security team for acceptable alternatives |
| **Sovereign cloud delayed > 24h** | Critical | Medium | Apply OPA emergency policy: block Ingress creation except `kube-system` + RBAC audit |
| **Phase 2 Gateway API delay (Q3 slip)** | Medium | Medium | App Routing Add-on supported through Nov 2026 — buffer exists |
| **Fairfax deployment lag** | High | High | Begin sovereign cloud audit in parallel with production migration |
| **CVE-2026-24512 exploitation in delay window** | Critical | Medium | OPA policy + monitoring alerts + RBAC lockdown as compensating controls |

---

## Rollback Plan

### Rollback via Release Pipeline (Recommended, ~10 min)

1. Trigger the DK8S Rollback Pipeline
2. Select last stable artifacts for: `Ingress` + `AppRoutingAddOn`
3. Deploy — reverts App Routing Add-on config and redeploys previous ingress-nginx controller

### Manual Rollback via Geneva Actions (~15 min)

```bash
# 1. Uninstall app-routing-addon
kubectl delete -n app-routing-system deployment --all

# 2. Roll back nginx-ingress Helm release
helm rollback nginx-ingress -n wdatp-infra-system-ingress

# 3. Verify traffic restored
kubectl get ingress --all-namespaces
```

> **Note:** Rolling back to ingress-nginx < 1.13.7 restores the CVE-2026-24512 vulnerability. This is only acceptable with:
> - OPA policy blocking new Ingress creation
> - Monitoring alerts on Ingress modifications
> - Network policy blocking pod-to-ingress-controller traffic

---

## Testing Approach

### Pre-Migration Validation

- [ ] Verify all current Ingress resources catalogued
- [ ] Identify CORS/auth-URL services from Kusto query
- [ ] CORS/auth services rebuilt with per-Ingress annotations
- [ ] App Routing Add-on enabled in TEST cluster
- [ ] squad NginxIngressController CR applied
- [ ] TLS certificates verified (Azure Key Vault integration)
- [ ] DNS resolution confirmed

### Post-Migration Validation

- [ ] Application Routing Dashboard: all NGINX pods green
- [ ] HTTP/HTTPS routing: path-based routing functional for all services
- [ ] TLS offloading: certificates rotating correctly via Key Vault
- [ ] Metrics: Prometheus scraping from new controller
- [ ] Alert: web request failure rate < 0.1%
- [ ] Heartbeat endpoint responding
- [ ] Downtime window: < 10 minutes total

### Regression Tests

```bash
# Test 1: Basic HTTP routing
curl -I http://<ingress-ip>/healthz

# Test 2: TLS/HTTPS
curl -vk https://<fqdn>/ 2>&1 | grep "SSL connection"

# Test 3: Path-based routing
curl -I https://<fqdn>/api/v1/health
curl -I https://<fqdn>/metrics

# Test 4: Header forwarding
curl -H "X-Forwarded-For: 1.2.3.4" https://<fqdn>/

# Test 5: CVE-2026-24512 no longer exploitable (verify via security scan)
kubectl exec -n app-routing-system deployment/nginx-controller -- \
  /nginx-ingress-controller --version
```

---

## Phase 2: Gateway API Manifests (Q3 2026 Target)

Reference manifests for the eventual Gateway API migration are in:
- [`infrastructure/gateway-api/gatewayclass.yaml`](gateway-api/gatewayclass.yaml) — Azure Application Gateway for Containers
- [`infrastructure/gateway-api/gateway.yaml`](gateway-api/gateway.yaml) — Squad Gateway instance
- [`infrastructure/gateway-api/httproute-squad.yaml`](gateway-api/httproute-squad.yaml) — HTTPRoute for squad workloads
- [`infrastructure/gateway-api/squad-nginx-ingress-controller.yaml`](gateway-api/squad-nginx-ingress-controller.yaml) — Phase 1 NginxIngressController CR

These manifests demonstrate the eventual migration from `Ingress` resources to `HTTPRoute` + `Gateway` resources.

---

## Coordination Required

| Team | Action Needed | Timeline |
|---|---|---|
| **DK8S Infra** | Enable App Routing Add-on flag in clusterInventory + trigger Cluster Provisioning pipeline | Week 1 |
| **Service owners (CORS/auth)** | Rebuild and redeploy with per-Ingress annotations | Day 1–2 |
| **Security (Worf)** | Confirm OPA emergency policy for sovereign cloud delay window | Day 1 |
| **Monitoring** | Enable alerts on web request failure rates + Ingress modification events | Day 2 |
| **Fairfax operations** | Begin sovereign cloud audit in parallel | Day 1 |

---

## References

1. [FedRAMP P0 Assessment — nginx-ingress-heartbeat vulnerabilities](../FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md)
2. [DK8S eng.ms: Migration Plan — Transition to AKS Application Routing Add-on](https://eng.ms/docs/microsoft-security/microsoft-threat-protection-mtp/onesoc-1soc/infra-and-developer-platform-scip-idp/infra-and-developer-platform-scip-idp/internal/defender-k8s/engineering/transition_to_aks_application_routing_addon)
3. [AKS Application Routing Add-on docs](https://learn.microsoft.com/en-us/azure/aks/app-routing)
4. [AKS Ingress options overview](https://learn.microsoft.com/en-us/azure/aks/concepts-network-ingress)
5. [Kubernetes Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/)
6. [Gateway API SIG-Network spec](https://gateway-api.sigs.k8s.io/)
7. [CVE-2026-24512 Advisory](https://github.com/kubernetes/kubernetes/issues/136678)

---

*— B'Elanna, Infrastructure Expert | squad-on-aks | 2026-03-22*  
*If it ships, it ships reliably. Automates everything twice.*
