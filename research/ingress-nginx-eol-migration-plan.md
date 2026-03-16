# Ingress-NGINX EOL Migration Plan — Kubernetes Gateway API

**Issue:** #644  
**Status:** 🔴 URGENT — EOL reached March 16, 2026  
**Author:** B'Elanna (Infrastructure Expert)  
**Date:** 2026-03-16  
**Classification:** Infrastructure / Networking / Security  

---

## Executive Summary

The community-maintained `kubernetes/ingress-nginx` controller reached **End of Life on March 16, 2026**. The repository is now read-only — no further releases, bug fixes, or security patches will be issued. Any DK8S clusters still running ingress-nginx are operating on unsupported, unpatched infrastructure.

**The recommended migration target is the Kubernetes Gateway API**, with **Envoy Gateway** as the primary implementation for DK8S clusters. This document provides the complete migration strategy.

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Gateway API Overview](#2-gateway-api-overview)
3. [Migration Strategy for DK8S](#3-migration-strategy-for-dk8s)
4. [Gateway Implementation Recommendation](#4-gateway-implementation-recommendation)
5. [Timeline & Risk Assessment](#5-timeline--risk-assessment)
6. [Action Items](#6-action-items)
7. [Appendix: Reference Links](#7-appendix-reference-links)

---

## 1. Current State Assessment

### 1.1 What Ingress-NGINX Provides Today

Ingress-NGINX is the most widely deployed Kubernetes ingress controller. In DK8S clusters, it provides:

| Capability | Details |
|---|---|
| **TLS Termination** | Terminates HTTPS at the edge, forwards plaintext to backends |
| **Host-based Routing** | Routes traffic based on `Host` header to different services |
| **Path-based Routing** | Routes traffic based on URL path prefixes/exact matches |
| **Rate Limiting** | Annotations for request-rate and connection limits |
| **IP Allowlisting** | Restricts access by source IP ranges |
| **Authentication** | External auth, basic auth, client certificate auth |
| **CORS** | Cross-Origin Resource Sharing header management |
| **Custom Headers** | Injection of request/response headers |
| **Rewrites & Redirects** | URL rewriting and HTTP-to-HTTPS redirects |
| **WebSocket Support** | Upgrades connections for WebSocket traffic |
| **Session Affinity** | Cookie-based sticky sessions |
| **Custom Error Pages** | Configurable 404/503 error responses |
| **Proxy Buffering** | Configurable upstream buffering and timeouts |
| **Canary Deployments** | Traffic splitting via canary annotations |

### 1.2 Why Ingress-NGINX Is EOL

The retirement was announced by the Kubernetes project in November 2025 and confirmed by a joint statement from Kubernetes Steering and Security committees in January 2026:

| Factor | Detail |
|---|---|
| **Maintainer Burnout** | The controller relied on ~2–3 volunteer maintainers for 100K+ production clusters worldwide |
| **Security Surface** | Features like `nginx.snippets` annotations allowed arbitrary NGINX config injection — a critical attack vector (CVE-2025-1974, etc.) |
| **Technical Debt** | Years of accumulated annotations, edge cases, and workarounds |
| **Ecosystem Shift** | Gateway API graduated to GA (Kubernetes 1.28+), providing a superior, standardized alternative |

**Timeline:**
- **Nov 2025**: Retirement announced on kubernetes.dev blog
- **Jan 2026**: Kubernetes Steering/Security joint statement
- **March 16, 2026**: EOL — repository archived, no further patches

### 1.3 Risks of Running EOL Software

Running ingress-nginx post-EOL introduces immediate and escalating risk:

| Risk Category | Impact | Severity |
|---|---|---|
| **Unpatched CVEs** | New vulnerabilities will not be fixed. Any future CVE is a permanent 0-day in your cluster | 🔴 Critical |
| **Compliance Violations** | SOC 2, PCI-DSS, ISO 27001, HIPAA, and FedRAMP all require timely patching of critical infrastructure | 🔴 Critical |
| **No Support** | No community support, no bug fixes, no documentation updates | 🟠 High |
| **Kubernetes Compatibility** | Future K8s versions may break ingress-nginx with no upstream fix | 🟠 High |
| **Supply Chain Risk** | Archived repository may be targeted for dependency confusion or takeover attacks | 🟠 High |
| **Audit Findings** | Internal and external audits will flag EOL ingress controllers | 🟡 Medium |

> ⚠️ **FedRAMP Note:** For DK8S clusters in government cloud (MAG/Fairfax), running EOL ingress-nginx is a **P0 compliance blocker**. Refer to `FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md` for details.

---

## 2. Gateway API Overview

### 2.1 What Is Kubernetes Gateway API?

The Gateway API is the official next-generation Kubernetes API for managing service networking. It graduated to **GA (v1.0)** in Kubernetes 1.28 (October 2023) and is now the recommended replacement for the Ingress API.

Key design principles:
- **Role-oriented**: Separates infrastructure concerns (platform team) from application routing (dev teams)
- **Expressive**: Native support for header-based routing, traffic splitting, URL rewrites, and more — no annotations needed
- **Extensible**: Clean extension points for vendor-specific features without fragile annotation hacks
- **Portable**: Standardized across all implementations

### 2.2 Key Resource Types

```
┌─────────────────────────────────────────────────────────┐
│                    Platform Team                         │
│                                                         │
│  ┌──────────────┐      ┌──────────────────────────┐     │
│  │ GatewayClass │──────│ Gateway                  │     │
│  │ (provider)   │      │ (listeners, TLS, ports)  │     │
│  └──────────────┘      └──────────┬───────────────┘     │
│                                   │                     │
├───────────────────────────────────┼─────────────────────┤
│                    App Teams      │                      │
│                                   │                     │
│  ┌──────────────┐  ┌─────────────▼────────────────┐    │
│  │ HTTPRoute    │  │ GRPCRoute                    │    │
│  │ (L7 routing) │  │ (gRPC routing)               │    │
│  ├──────────────┤  ├──────────────────────────────┤    │
│  │ TCPRoute     │  │ TLSRoute                     │    │
│  │ (L4 TCP)     │  │ (TLS passthrough)            │    │
│  └──────────────┘  └────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

| Resource | Owner | Purpose |
|---|---|---|
| **GatewayClass** | Platform/infra team | Defines which controller handles Gateways (like StorageClass for PVs) |
| **Gateway** | Platform/infra team | Configures listeners (ports, TLS certs, protocols) |
| **HTTPRoute** | App teams | Defines HTTP routing rules (host, path, headers → backend service) |
| **GRPCRoute** | App teams | Defines gRPC-specific routing |
| **TCPRoute / UDPRoute** | App teams | Layer 4 routing |
| **TLSRoute** | App teams | TLS passthrough routing |
| **ReferenceGrant** | Namespace owners | Explicitly allows cross-namespace references |

### 2.3 Benefits Over Ingress API

| Aspect | Ingress API | Gateway API |
|---|---|---|
| **Routing expressiveness** | Host + path only; everything else via annotations | Host, path, header, query param, method matching natively |
| **Traffic management** | Annotation-dependent (non-portable) | Native traffic splitting, mirroring, rewrites, redirects |
| **TLS configuration** | Basic, per-Ingress | Per-listener TLS with SNI, mTLS support |
| **Role separation** | Single resource, single owner | GatewayClass/Gateway (infra) vs Routes (app) |
| **Cross-namespace** | Not supported | Supported with ReferenceGrant |
| **Extensibility** | Annotations (fragile, non-standard) | Policy attachments (standardized extension model) |
| **Portability** | Controller-specific annotations break portability | Conformance tests ensure consistent behavior |
| **gRPC** | No native support | First-class GRPCRoute |

### 2.4 Available Implementations

| Implementation | Proxy | Maintainer | GA Status | Notes |
|---|---|---|---|---|
| **Envoy Gateway** | Envoy | CNCF (Envoy community) | GA | Full conformance, hot-reload, extensible |
| **Istio Gateway** | Envoy | Istio project | GA | Best with service mesh; overkill for edge-only |
| **NGINX Gateway Fabric** | NGINX | F5/NGINX | GA | Familiar to NGINX teams; limited L4/mTLS |
| **Contour** | Envoy | VMware/Broadcom | GA | Mature, good for basic use cases |
| **Kong Gateway** | Kong/OpenResty | Kong Inc. | GA | API management features built-in |
| **HAProxy Ingress** | HAProxy | HAProxy Technologies | Beta | Strong L4, emerging Gateway API support |
| **Cilium** | eBPF/Envoy | Isovalent/Cisco | GA | eBPF-native, high performance, CNI integration |
| **GKE Gateway** | Google Cloud LB | Google | GA | GKE-only, managed |
| **AKS App Gateway for Containers** | Azure ALB | Microsoft | GA | AKS-native, managed; 1P option |

---

## 3. Migration Strategy for DK8S

### Phase 1: Audit (Week 1–2)

**Objective:** Discover and catalog all Ingress resources and ingress-nginx-specific configurations across all DK8S clusters.

#### 3.1.1 Discover All Ingress Resources

```bash
# List ALL Ingress resources across all namespaces
kubectl get ingress --all-namespaces -o wide

# Get detailed YAML for analysis
kubectl get ingress --all-namespaces -o yaml > all-ingress-resources.yaml

# Count Ingress resources per namespace
kubectl get ingress --all-namespaces --no-headers | awk '{print $1}' | sort | uniq -c | sort -rn

# Multi-cluster: iterate across all DK8S clusters
for ctx in $(kubectl config get-contexts -o name | grep dk8s); do
  echo "=== Cluster: $ctx ==="
  kubectl --context="$ctx" get ingress --all-namespaces -o wide
done
```

#### 3.1.2 Identify Ingress-NGINX Annotations in Use

```bash
# Extract all unique annotations across Ingress resources
kubectl get ingress --all-namespaces -o json | \
  jq -r '.items[].metadata.annotations // {} | keys[]' | \
  sort | uniq -c | sort -rn

# Filter for ingress-nginx-specific annotations
kubectl get ingress --all-namespaces -o json | \
  jq -r '.items[].metadata.annotations // {} | keys[]' | \
  grep "nginx.ingress.kubernetes.io" | \
  sort | uniq -c | sort -rn
```

**Common ingress-nginx annotations to catalog:**

| Annotation | Gateway API Equivalent | Migration Complexity |
|---|---|---|
| `nginx.ingress.kubernetes.io/rewrite-target` | HTTPRoute `URLRewrite` filter | Low |
| `nginx.ingress.kubernetes.io/ssl-redirect` | HTTPRoute `RequestRedirect` filter | Low |
| `nginx.ingress.kubernetes.io/proxy-body-size` | BackendTLSPolicy / impl-specific | Medium |
| `nginx.ingress.kubernetes.io/rate-limit-*` | Implementation-specific policy | Medium |
| `nginx.ingress.kubernetes.io/auth-url` | Implementation-specific (ExtAuth) | High |
| `nginx.ingress.kubernetes.io/auth-signin` | Implementation-specific (ExtAuth) | High |
| `nginx.ingress.kubernetes.io/configuration-snippet` | **No equivalent — requires manual redesign** | 🔴 High |
| `nginx.ingress.kubernetes.io/server-snippet` | **No equivalent — requires manual redesign** | 🔴 High |
| `nginx.ingress.kubernetes.io/canary-*` | HTTPRoute traffic splitting | Medium |
| `nginx.ingress.kubernetes.io/cors-*` | Implementation-specific CORS policy | Medium |
| `nginx.ingress.kubernetes.io/whitelist-source-range` | Implementation-specific IP policy | Medium |
| `nginx.ingress.kubernetes.io/affinity` | Implementation-specific session policy | Medium |

#### 3.1.3 Generate Audit Report

```bash
# Generate a migration complexity report
cat <<'EOF' > audit-ingress.sh
#!/bin/bash
echo "=== DK8S Ingress-NGINX Audit Report ==="
echo "Date: $(date -u)"
echo ""
echo "--- Ingress Resource Count ---"
kubectl get ingress --all-namespaces --no-headers | wc -l
echo ""
echo "--- Resources by Namespace ---"
kubectl get ingress --all-namespaces --no-headers | awk '{print $1}' | sort | uniq -c | sort -rn
echo ""
echo "--- Annotation Usage ---"
kubectl get ingress --all-namespaces -o json | \
  jq -r '.items[].metadata.annotations // {} | keys[]' | \
  grep "nginx.ingress" | sort | uniq -c | sort -rn
echo ""
echo "--- HIGH RISK: snippet annotations ---"
kubectl get ingress --all-namespaces -o json | \
  jq -r '.items[] | select(.metadata.annotations["nginx.ingress.kubernetes.io/configuration-snippet"] != null or .metadata.annotations["nginx.ingress.kubernetes.io/server-snippet"] != null) | "\(.metadata.namespace)/\(.metadata.name)"'
echo ""
echo "--- TLS Certificates in Use ---"
kubectl get ingress --all-namespaces -o json | \
  jq -r '.items[] | .spec.tls[]?.secretName // empty' | sort | uniq -c | sort -rn
EOF
chmod +x audit-ingress.sh
```

**Deliverable:** Audit spreadsheet with every Ingress resource, its namespace, annotations, TLS config, and estimated migration complexity (Low/Medium/High).

---

### Phase 2: Convert (Week 2–4)

**Objective:** Convert Ingress resources to Gateway API resources using `ingress2gateway` and manual adjustments.

#### 3.2.1 Install ingress2gateway

```bash
# Option 1: Go install (recommended)
go install github.com/kubernetes-sigs/ingress2gateway@latest

# Option 2: Download pre-built binary
# https://github.com/kubernetes-sigs/ingress2gateway/releases

# Option 3: Homebrew (macOS/Linux)
brew install ingress2gateway

# Verify installation
ingress2gateway --version
```

#### 3.2.2 Run Conversion

```bash
# Convert from live cluster (all namespaces, ingress-nginx provider)
ingress2gateway print \
  --providers=ingress-nginx \
  --all-namespaces \
  > gateway-api-resources.yaml

# Convert from exported YAML file
ingress2gateway print \
  --providers=ingress-nginx \
  --input-file=all-ingress-resources.yaml \
  > gateway-api-resources.yaml

# Convert a specific namespace
ingress2gateway print \
  --providers=ingress-nginx \
  --namespace=production \
  > gateway-api-production.yaml
```

#### 3.2.3 What ingress2gateway Converts vs. What Needs Manual Work

| Converts Automatically ✅ | Requires Manual Adjustment ⚠️ |
|---|---|
| Host rules → HTTPRoute hostnames | `configuration-snippet` / `server-snippet` annotations |
| Path rules → HTTPRoute path matches | External auth (`auth-url`, `auth-signin`) |
| TLS config → Gateway listeners | Rate limiting policies |
| Basic rewrites → URLRewrite filters | CORS policies |
| SSL redirects → RequestRedirect filters | Session affinity/sticky sessions |
| Backend service references | Custom error pages |
| Multiple hosts → multiple HTTPRoutes | IP allowlisting |
| | Canary deployments with complex rules |
| | Custom proxy buffer/timeout settings |

#### 3.2.4 Example: Before and After

**Before (Ingress):**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit-rps: "10"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.dk8s.example.com
    secretName: app-tls-cert
  rules:
  - host: app.dk8s.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

**After (Gateway API):**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: dk8s-envoy
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: dk8s-gateway
  namespace: gateway-infra
spec:
  gatewayClassName: dk8s-envoy
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: app-tls-cert
        namespace: production
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            gateway-access: "true"
  - name: http-redirect
    protocol: HTTP
    port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-api
  namespace: production
spec:
  parentRefs:
  - name: dk8s-gateway
    namespace: gateway-infra
  hostnames:
  - app.dk8s.example.com
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: api-service
      port: 8080
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: frontend-service
      port: 80
---
# Rate limiting requires implementation-specific policy
# Envoy Gateway example:
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: my-app-rate-limit
  namespace: production
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: my-app-api
  rateLimit:
    type: Local
    local:
      rules:
      - limit:
          requests: 10
          unit: Second
---
# Cross-namespace reference grant (required for TLS cert in different namespace)
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-tls
  namespace: production
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: Gateway
    namespace: gateway-infra
  to:
  - group: ""
    kind: Secret
```

---

### Phase 3: Parallel Run (Week 4–6)

**Objective:** Run both ingress-nginx and the new Gateway controller side-by-side to validate behavior.

#### 3.3.1 Deploy Gateway Controller

```bash
# Install Gateway API CRDs (if not already present)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# Install Envoy Gateway (Helm)
helm install envoy-gateway \
  oci://docker.io/envoyproxy/gateway-helm \
  --version v1.2.0 \
  -n envoy-gateway-system \
  --create-namespace

# Verify installation
kubectl get gatewayclass
kubectl get pods -n envoy-gateway-system
```

#### 3.3.2 Deploy Converted Resources

```bash
# Apply Gateway API resources (non-destructive — doesn't affect existing Ingress)
kubectl apply -f gateway-api-resources.yaml

# Verify routes are accepted
kubectl get gateway -A
kubectl get httproute -A
kubectl describe httproute my-app-api -n production
```

#### 3.3.3 Validate Side-by-Side

```bash
# Get the new Gateway's external IP/LB
kubectl get gateway dk8s-gateway -n gateway-infra \
  -o jsonpath='{.status.addresses[0].value}'

# Test against the new gateway using curl with Host header override
GATEWAY_IP=$(kubectl get gateway dk8s-gateway -n gateway-infra \
  -o jsonpath='{.status.addresses[0].value}')

curl -H "Host: app.dk8s.example.com" https://$GATEWAY_IP/api --resolve app.dk8s.example.com:443:$GATEWAY_IP

# Compare responses between old and new
diff <(curl -s https://app.dk8s.example.com/api) \
     <(curl -s -H "Host: app.dk8s.example.com" https://$GATEWAY_IP/api \
       --resolve app.dk8s.example.com:443:$GATEWAY_IP)
```

#### 3.3.4 Monitoring & Observability

Ensure the new gateway emits metrics to Geneva/MDM:

```yaml
# Envoy Gateway metrics integration
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: dk8s-proxy-config
  namespace: envoy-gateway-system
spec:
  telemetry:
    metrics:
      prometheus:
        enable: true
      sinks:
      - type: OpenTelemetry
        openTelemetry:
          host: otel-collector.monitoring.svc
          port: 4317
```

**Deliverable:** Side-by-side comparison report showing identical routing behavior, latency comparison, and error rate comparison between old and new.

---

### Phase 4: Cutover (Week 6–7)

**Objective:** Switch production DNS/traffic from ingress-nginx to the new Gateway.

#### 3.4.1 DNS Cutover Strategy

```
Option A: DNS Swap (Recommended for DK8S)
─────────────────────────────────────────
1. Lower DNS TTL to 60s (do this 24h+ before cutover)
2. Update DNS records to point to new Gateway LB IP
3. Monitor traffic on both old and new controllers
4. Once all traffic flows through new gateway, proceed to cleanup

Option B: Weighted DNS (Lower risk, slower)
─────────────────────────────────────────
1. Use Azure Traffic Manager or DNS-based load balancing
2. Start: 90% old → 10% new
3. Gradually shift: 70/30 → 50/50 → 30/70 → 0/100
4. Monitor at each step for errors
```

#### 3.4.2 Cutover Checklist

- [ ] All HTTPRoutes report `Accepted: True` and `ResolvedRefs: True`
- [ ] End-to-end tests pass against new gateway
- [ ] Latency P50/P95/P99 within acceptable thresholds
- [ ] Error rates match or improve on baseline
- [ ] TLS certificates correctly terminate on all listeners
- [ ] Rate limiting / auth policies validated
- [ ] Geneva/MDM metrics flowing from new gateway
- [ ] Alerts configured for new gateway health
- [ ] Runbook updated for new gateway operations
- [ ] On-call team briefed on new architecture

---

### Phase 5: Cleanup (Week 7–8)

**Objective:** Remove ingress-nginx and legacy Ingress resources.

```bash
# Step 1: Verify zero traffic on old ingress controller
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller --tail=100 | \
  grep -c "request"
# Should show 0 or near-0 new requests

# Step 2: Remove old Ingress resources
kubectl delete ingress --all -A --dry-run=client  # Preview
kubectl delete ingress --all -A                    # Execute

# Step 3: Uninstall ingress-nginx controller
helm uninstall ingress-nginx -n ingress-nginx
# OR
kubectl delete namespace ingress-nginx

# Step 4: Remove ingress-nginx CRDs if any
kubectl delete crd -l app.kubernetes.io/name=ingress-nginx

# Step 5: Clean up orphaned resources
kubectl get svc -A | grep ingress-nginx  # Remove any leftover services
kubectl get cm -A | grep ingress-nginx   # Remove any leftover configmaps
```

---

## 4. Gateway Implementation Recommendation

### 4.1 Comparison Matrix for DK8S

| Criteria | Envoy Gateway | NGINX Gateway Fabric | Istio Gateway |
|---|---|---|---|
| **Gateway API Conformance** | ✅ Full GA conformance | ✅ Full GA conformance | ✅ Full GA conformance |
| **Proxy Engine** | Envoy (CNCF graduated) | NGINX | Envoy |
| **Config Reload** | Hot reload (xDS) — zero disruption | NGINX reload — brief connection drops | Hot reload (xDS) |
| **L4 Support (TCP/UDP)** | ✅ Full | ⚠️ Experimental | ✅ Full |
| **gRPC Support** | ✅ Native | ⚠️ Experimental | ✅ Native |
| **mTLS** | ✅ Built-in | ⚠️ Limited | ✅ Built-in (mesh) |
| **Rate Limiting** | ✅ Local + Global | ⚠️ Limited | ✅ Full |
| **External Auth** | ✅ ExtAuth filter | ⚠️ Limited | ✅ Full |
| **Observability** | ✅ Prometheus + OTel native | ⚠️ Basic metrics | ✅ Rich (mesh-level) |
| **Geneva/MDM Integration** | ✅ Via OTel collector | ⚠️ Requires custom setup | ✅ Via OTel collector |
| **Performance** | 🟢 Excellent under high concurrency | 🟢 Good for HTTP workloads | 🟢 Excellent |
| **Operational Complexity** | 🟢 Low-Medium | 🟢 Low | 🔴 High (mesh overhead) |
| **1P (Microsoft) Alignment** | ✅ AKS App GW for Containers uses Envoy | ⚠️ No direct 1P alignment | ⚠️ Istio-based mesh available |
| **Community / Ecosystem** | 🟢 Large, growing fast | 🟡 Moderate | 🟢 Large but complex |
| **License** | Apache 2.0 | Apache 2.0 (OSS) / Commercial (Plus) | Apache 2.0 |

### 4.2 Recommendation: Envoy Gateway

**We recommend Envoy Gateway as the primary Gateway API implementation for DK8S clusters.**

**Rationale:**

1. **Full Gateway API conformance** — passes all standard and extended conformance tests
2. **Zero-disruption config changes** — Envoy's xDS hot-reload eliminates the NGINX reload problem that caused brief connection drops
3. **1P alignment** — Microsoft's own AKS Application Gateway for Containers is built on Envoy, making this the strategic direction for Azure Kubernetes
4. **Superior L4/L7 capabilities** — native gRPC, TCP/UDP, WebSocket support without experimental flags
5. **Built-in security** — mTLS, rate limiting, external auth, and CORS as first-class policy objects
6. **Observability** — native Prometheus and OpenTelemetry support integrates directly with Geneva/MDM via OTel collector
7. **Operational simplicity** — significantly simpler than Istio (no mesh overhead) while providing comparable edge gateway features
8. **CNCF pedigree** — Envoy is a CNCF graduated project with massive adoption (Lyft, Google, AWS, Microsoft)

**When to consider alternatives:**
- **Istio Gateway**: Only if the cluster already runs Istio service mesh and you need unified edge + mesh management
- **NGINX Gateway Fabric**: Only for teams with deep NGINX expertise that require specific NGINX modules not available in Envoy

---

## 5. Timeline & Risk Assessment

### 5.1 Proposed Timeline

```
Week 0 (NOW)     ┃ Issue #644 opened. EOL date reached.
                  ┃
Week 1–2         ┃ PHASE 1: AUDIT
                  ┃ ├─ Run audit scripts across all DK8S clusters
                  ┃ ├─ Catalog all Ingress resources & annotations
                  ┃ ├─ Identify high-risk snippet annotations
                  ┃ └─ Produce audit spreadsheet
                  ┃
Week 2–4         ┃ PHASE 2: CONVERT
                  ┃ ├─ Install ingress2gateway
                  ┃ ├─ Run automated conversion
                  ┃ ├─ Manual adjustments for complex annotations
                  ┃ ├─ Create implementation-specific policies
                  ┃ └─ Peer review all converted resources
                  ┃
Week 4–6         ┃ PHASE 3: PARALLEL RUN
                  ┃ ├─ Deploy Envoy Gateway to staging clusters
                  ┃ ├─ Apply converted Gateway API resources
                  ┃ ├─ Run side-by-side comparison tests
                  ┃ ├─ Validate observability pipeline
                  ┃ └─ Deploy to production clusters (parallel)
                  ┃
Week 6–7         ┃ PHASE 4: CUTOVER
                  ┃ ├─ Lower DNS TTLs
                  ┃ ├─ Switch DNS to new Gateway LB
                  ┃ ├─ Monitor error rates and latency
                  ┃ └─ Confirm all traffic on new gateway
                  ┃
Week 7–8         ┃ PHASE 5: CLEANUP
                  ┃ ├─ Remove ingress-nginx controller
                  ┃ ├─ Delete legacy Ingress resources
                  ┃ ├─ Update documentation & runbooks
                  ┃ └─ Close Issue #644
                  ┃
Week 8           ┃ ✅ MIGRATION COMPLETE
```

**Total estimated duration: 8 weeks**

### 5.2 Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | CVE discovered in ingress-nginx during migration window | High | Critical | Prioritize migration; apply WAF rules as interim protection |
| R2 | `configuration-snippet` annotations require significant rework | Medium | High | Audit early; engage app teams for redesign in Phase 1 |
| R3 | Application teams slow to test/validate | Medium | High | Set hard cutover deadline; provide self-service validation tools |
| R4 | Performance regression with new gateway | Low | High | Benchmark in Phase 3; keep old controller as rollback |
| R5 | Missing feature parity in Envoy Gateway | Low | Medium | Document gaps; use ExtensionPolicy for custom needs |
| R6 | DNS cutover causes brief traffic disruption | Medium | Medium | Lower TTL 24h before; use weighted DNS if available |
| R7 | TLS certificate mismatch in new gateway | Low | High | Validate all certs in Phase 3; use cert-manager for automation |

### 5.3 Rollback Plan

If critical issues are discovered after cutover:

1. **Immediate (< 5 min):** Switch DNS back to ingress-nginx LB IP (kept running during Phase 4)
2. **Short-term (< 1 hour):** Scale ingress-nginx controller back up if it was scaled down
3. **Medium-term:** Revert Gateway API resources and ingress-nginx stays as-is while issues are investigated
4. **Constraint:** Ingress-nginx controller should NOT be removed (Phase 5) until at least 1 week of stable operation on the new gateway

> ⚠️ **Rollback is time-limited.** Every day on EOL ingress-nginx increases CVE exposure. Rollback should be treated as a temporary measure, not a permanent state.

---

## 6. Action Items

### Immediate (This Week)

| # | Action | Owner | Due |
|---|---|---|---|
| A1 | Run audit scripts across all DK8S clusters | DK8S Platform Team | Week 1 |
| A2 | Identify clusters using `configuration-snippet` / `server-snippet` | DK8S Platform Team | Week 1 |
| A3 | Notify all app teams of ingress-nginx EOL and migration timeline | DK8S Platform Team | Week 1 |
| A4 | Create `#ingress-migration` Teams channel for coordination | DK8S Platform Team | Week 1 |

### Phase 1–2 (Weeks 1–4)

| # | Action | Owner | Due |
|---|---|---|---|
| A5 | Install and test ingress2gateway on staging cluster | DK8S Platform Team | Week 2 |
| A6 | Convert all Ingress resources and review output | DK8S Platform Team | Week 3 |
| A7 | Redesign `snippet`-based configurations to use proper Gateway API patterns | App Teams (with Platform support) | Week 4 |
| A8 | Create Helm chart for Envoy Gateway deployment (DK8S-standard) | DK8S Platform Team | Week 3 |
| A9 | Configure Geneva/MDM metrics pipeline for Envoy Gateway | DK8S Platform Team | Week 3 |

### Phase 3–5 (Weeks 4–8)

| # | Action | Owner | Due |
|---|---|---|---|
| A10 | Deploy Envoy Gateway to staging clusters | DK8S Platform Team | Week 4 |
| A11 | Deploy Envoy Gateway to production clusters (parallel mode) | DK8S Platform Team | Week 5 |
| A12 | App teams validate their routes on new gateway | App Teams | Week 5–6 |
| A13 | Execute DNS cutover for each cluster | DK8S Platform Team | Week 6–7 |
| A14 | Remove ingress-nginx from all clusters | DK8S Platform Team | Week 7–8 |
| A15 | Update runbooks, alerting, and on-call documentation | DK8S Platform Team | Week 8 |
| A16 | Close Issue #644 | DK8S Platform Team | Week 8 |

### FedRAMP / Compliance

| # | Action | Owner | Due |
|---|---|---|---|
| A17 | File compliance exception for EOL ingress-nginx during migration window | Security/Compliance Team | Week 1 |
| A18 | Prioritize government cloud (MAG/Fairfax) clusters for early cutover | DK8S Platform Team | Week 5 |
| A19 | Document migration in compliance audit trail | Security/Compliance Team | Week 8 |

---

## 7. Appendix: Reference Links

### Official Resources
- [Kubernetes Blog: Ingress NGINX Retirement](https://www.kubernetes.dev/blog/2025/11/12/ingress-nginx-retirement/)
- [Kubernetes Blog: Steering/Security Statement on Ingress-NGINX](https://kubernetes.io/blog/2026/01/29/ingress-nginx-statement/)
- [Gateway API Official Documentation](https://gateway-api.sigs.k8s.io/)
- [Gateway API Migration Guide](https://gateway-api.sigs.k8s.io/guides/getting-started/migrating-from-ingress/)
- [Migrating from Ingress-NGINX specifically](https://gateway-api.sigs.k8s.io/guides/getting-started/migrating-from-ingress-nginx/)

### Tools
- [ingress2gateway (GitHub)](https://github.com/kubernetes-sigs/ingress2gateway)
- [ingress2gateway Documentation](https://ingress2gateway.readthedocs.io/en/latest/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)

### Microsoft / Azure
- [Microsoft Tech Community: From Ingress to Gateway API](https://techcommunity.microsoft.com/blog/azurearchitectureblog/from-ingress-to-gateway-api-a-pragmatic-path-forward-and-why-it-matters-now/4489779)
- [AKS Application Gateway for Containers](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/overview)

### Migration Guides
- [Dev.to: March 2026 Migration Playbook](https://dev.to/onin/the-end-of-kubernetesingress-nginx-your-march-2026-migration-playbook-fhn)
- [Okteto: NGINX Deprecation Migration Guide](https://www.okteto.com/blog/ingress-nginx-controller-deprecation-your-migration-guide-to-kubernetes-gateway-api/)
- [Collabnix: NGINX to Gateway API Complete Guide](https://collabnix.com/complete-guide-migrating-from-nginx-ingress-to-kubernetes-gateway-api-in-2025/)
- [Google Open Source Blog: End of an Era](https://opensource.googleblog.com/2026/02/the-end-of-an-era-transitioning-away-from-ingress-nginx.html)

---

*This document is a living artifact. Updates will be tracked via Issue #644. Questions → `#ingress-migration` Teams channel.*
