# DK8S Stability & Configuration Management Analysis

**Author:** B'Elanna Torres, Infrastructure Expert  
**Date:** 2026-03-07  
**Issue:** #4 — DK8S stability & config management improvements + Aurora research  
**Sources:** WorkIQ (Teams conversations, emails, meeting transcripts, IcM incidents), EngineeringHub docs, DK8S platform knowledge base, prior infrastructure inventory

---

## Executive Summary

DK8S reliability concerns concentrate around **four systemic areas**: networking dependencies (NAT Gateway, DNS, ingress), service mesh (Istio) interactions, upgrade/rollout blast radius, and configuration management complexity (ConfigGen). None of these are "DK8S is broken" — they are **platform scaling pains** that become acute as the fleet grows and cluster uniformity decreases. This analysis catalogs confirmed incidents, identifies root causes, and provides prioritized recommendations.

---

## 1. Catalog of Current Stability Issues

### 1.1 High-Impact Incidents (Confirmed via IcM / PIR)

| # | Incident | Severity | Date | Clusters Affected | Root Cause | Status |
|---|----------|----------|------|-------------------|------------|--------|
| 1 | DNS + Istio ztunnel interaction | Sev2 | Jan 2026 | CUS3-20, WEU3-20 | Istio ztunnel misbehavior under DNS failures after geneva-loggers added to mesh + cluster autoscaler failure | PIR completed |
| 2 | NAT Gateway datapath degradation | Sev2 | Nov 2025 – Feb 2026 | WEU-14, WEU-16, EUAE-34 | Azure platform-side NAT Gateway degradation (external) | Recurring |
| 3 | Ingress networking 504s | Sev2 | Oct 2025 | UKS-929 | External DNS resolution failures at ingress layer; requests never reached pods | Self-mitigated |
| 4 | AKS workload identity removal | Sev2 | Recent | US sovereign clusters | AKS removed critical workload identity services during upgrade | Post-incident |
| 5 | Cluster autoscaler + VMSS failures | Sev2 | Jan 2026 | Multiple | Scale-up failures during Istio-enabled cluster incidents | Under investigation |

### 1.2 Recurring Stability Patterns

| Pattern | Frequency | Impact | Source |
|---------|-----------|--------|--------|
| NAT Gateway zonal failures | ~Monthly | Image pull failures, secret mount failures, probe failures | IcM + resiliency doc |
| Ingress/DNS resolution failures | Quarterly | 504 gateway timeouts across services | Teams support channel |
| Argo CD rollback failures | Ongoing | Production rollbacks don't cleanly revert shared resources (ingress, identities, bindings) | DK8S Leads meetings |
| Node cordon issues during upgrades | During K8s version upgrades | Pending/unschedulable pods | Workshop discussions |
| HPA saturation | Under load | Insufficient scaling response | Operational reviews |
| Infra component crash loops | Periodic | Platform component restarts | PIR discussions |
| Quota exhaustion | During scale events | Stalled upgrades, manual intervention required | Workshop transcripts |

### 1.3 Platform-Level Reliability Concerns

1. **Dual infrastructure risk** — Teams running on both CIEng and DK8S experience operational overhead, uncertainty, and migration-induced instability
2. **Missing JIT approval policies** — New clusters lack JIT policies, complicating incident mitigation
3. **Single-zone resource dependencies** — NAT Gateways and VMs are zonal; no zone-aware alerting today
4. **DR limitations** — Supportability clusters have regional constraints (Kusto leader/follower); no cross-region BCDR out of box
5. **Ingress NGINX deprecation** — Migration to AKS Application Routing requires ~10min downtime for services without DR

---

## 2. Configuration Management Pain Points

### 2.1 ConfigGen Structural Issues

| Area | Pain Point | Evidence |
|------|-----------|----------|
| **Modeling overload** | ConfigGen stretched beyond original design — requires workarounds and parametrization to model DK8S clusters | Design doc: "Lot of workaround and parametrization to adapt ConfigGen purpose" |
| **Centralized bottleneck** | Central config repos slow iteration; "big dev loop," risk of impacting unrelated components | Design review recording; cluster modeling doc |
| **Expansion complexity** | Manifest resolution grows complex as clusters lose uniformity (per-cluster MIs, per-DC ACRs, DC-aware Helm builds) | PR descriptions: "can no longer blindly fetch the first manifest reference" |
| **Weak feedback loops** | IDP not aware when EV2 steps or scripts fail; no signal when users skip NuGet versions | DK8S next.pptx: "IDP isn't aware if something in the deployment is not behaving correctly" |
| **Breaking change coordination** | Breaking changes require cross-team coordination; tracked as leadership KPI: "Decrease the # of ConfigGen Breaking Changes" | IDP Leadership channel |
| **Abstraction leakage** | Region-agnostic design constraints leak into authoring; require synthetic manifests, custom dedup, topology resolvers | PR: "creator pattern is against the region-agnostic design principles of ConfigGen" |

### 2.2 ConfigGen Breaking Changes — Deployment Impact

| Breaking Change | Impact | Mitigation |
|-----------------|--------|------------|
| Tenant-wide → cluster-scoped Managed Identities | Older generated configs assumed uniform MI; deployments fail without regeneration | NuGet upgrade + artifact regeneration |
| Shared → per-cluster/per-DC ACR resolution | ACR references break without newer ConfigGen versions | Forced NuGet upgrades via bulk PRs |
| NuGet config security policy changes | CI failures despite locally-correct ConfigGen output | nuget.config updates across repos |
| EV2 parameter regeneration requirements | Identity and ACR changes require full Ev2 parameter regeneration | Mandatory rebuild after upgrade |

**Key insight:** ConfigGen breaking changes are acknowledged at IDP leadership level as a **productivity killer**. Most failures surface at build/CI time, not runtime — but the frequency erodes team confidence and slows velocity.

### 2.3 Configuration Drift Risk

The gap between "what I wrote" and "what gets deployed" widens as:
- Cluster topology becomes non-uniform
- Synthetic manifests proliferate
- Teams delay NuGet upgrades
- Feedback from deployment failures is delayed or absent

---

## 3. Root Cause Analysis

### 3.1 Networking Instability

**Root causes:**
- **External dependency on Azure NAT Gateway** — DK8S has no control over zonal failures; current alerting pages on single NAT Gateway drops without zone awareness
- **DNS resolution fragility** — Multiple incidents trace to DNS failures at node level, amplified by service mesh (Istio ztunnel) and cluster autoscaler interactions
- **Ingress migration complexity** — Moving from NGINX to AKS Application Routing introduces downtime risk for services without DR

**Contributing factors:**
- No zone-aware monitoring discriminating between partial vs. full AZ failure
- Cluster autoscaler amplifies pod churn during networking degradation
- Geneva log/metric delivery fails when DNS fails, creating observability blackouts during incidents

### 3.2 Istio / Service Mesh Risk

**Root causes:**
- Istio ambient mode (ztunnel) is new technology with limited production track record
- Including infrastructure services (geneva-loggers) in the mesh creates cascading failure paths
- Troubleshooting Istio failures requires specialized expertise not widely distributed

**Contributing factors:**
- Opt-in model means partial mesh enrollment, creating inconsistent security posture
- Scale-up failures interact with VMSS provisioning and ztunnel initialization
- Service mesh adds latency to failure detection (mTLS handshake failures are less obvious than connection refused)

### 3.3 Upgrade & Rollout Blast Radius

**Root causes:**
- **Argo Rollouts shared-resource failures** — Rollbacks don't cleanly revert ingress, identities, and bindings that are shared across revisions
- **AKS platform changes** — Breaking changes introduced by AKS (workload identity removal, API deprecations) during upgrades
- **Insufficient staging rings** — Need additional STG/pre-prod validation to catch sovereign cloud failures earlier

**Contributing factors:**
- DK8S as intermediary between AKS and service teams absorbs blast radius from both directions
- Manual cluster operations (deletions) trigger alert storms and downstream failures
- Build-time coupling (ConfigGen → pipeline → EV2) means a single version skew can cascade

### 3.4 Configuration Management Complexity

**Root causes:**
- ConfigGen designed for uniform fleet; DK8S clusters are increasingly non-uniform
- Centralized ownership model creates single-team bottleneck for all config changes
- No runtime feedback loop from EV2 back to IDP/ConfigGen

**Contributing factors:**
- NuGet version adoption is voluntary; teams delay upgrades until forced
- Breaking changes ship without backward compatibility windows
- Gap between config authoring and deployment outcome is widening

---

## 4. Short-Term Mitigations (0–3 months)

### 4.1 Networking

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| N1 | **Implement zone-aware NAT Gateway monitoring** — Differentiate AZ-scoped vs. region-wide failures; reduce unnecessary Sev2 pages | Medium | High |
| N2 | **Add DNS resolution health checks** to node readiness gates — Prevent scheduling on nodes with DNS failures | Low | High |
| N3 | **Decouple Geneva agents from Istio mesh** — Remove geneva-loggers from service mesh to prevent cascading observability failures | Low | Critical |

### 4.2 Istio

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| I1 | **Establish Istio exclusion list** for infrastructure components (Geneva, CoreDNS, kube-system) | Low | High |
| I2 | **Add ztunnel health monitoring** with automatic rollback trigger if ztunnel failure rate > threshold | Medium | High |
| I3 | **Create Istio troubleshooting runbook** — Distribute mesh debugging knowledge beyond platform team | Low | Medium |

### 4.3 Configuration Management

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| C1 | **Enforce minimum ConfigGen NuGet version** in CI — Block builds with known-broken versions | Low | High |
| C2 | **Add deployment feedback webhook** — Report EV2 step failures back to IDP for visibility | Medium | High |
| C3 | **Create breaking change changelog** per ConfigGen release with migration guide | Low | Medium |

### 4.4 Operational

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| O1 | **Add deny assignments** at management-group level to prevent manual cluster/resource deletions | Low | High |
| O2 | **Standardize squash-merge** across infra repositories for safer rollbacks | Low | Medium |
| O3 | **Pre-validate quota** before cluster upgrades — Automated check against regional limits | Medium | Medium |

---

## 5. Long-Term Architecture Improvements (3–12 months)

### 5.1 Networking Resilience

| # | Initiative | Description |
|---|-----------|-------------|
| L1 | **Multi-AZ NAT Gateway failover** | Deploy redundant NAT Gateways per AZ; implement automatic failover at network layer |
| L2 | **DNS caching and fallback** | Local DNS cache per node with fallback to regional resolver; reduce cascading DNS failures |
| L3 | **Ingress migration to AKS App Routing** | Complete NGINX deprecation with zero-downtime migration path for all services |

### 5.2 Service Mesh Maturity

| # | Initiative | Description |
|---|-----------|-------------|
| L4 | **Istio ambient mode graduated rollout** | Ring-based mesh enrollment with automatic canary validation before promoting |
| L5 | **Mesh observability integration** | Integrate Istio telemetry with Geneva; mesh-aware dashboards for mTLS handshake failures, ztunnel health |
| L6 | **Infrastructure component mesh isolation** | Permanent exclusion of platform daemonsets and system components from mesh |

### 5.3 Configuration Management Evolution

| # | Initiative | Description |
|---|-----------|-------------|
| L7 | **Decentralize ConfigGen ownership** | Move from monolithic central repo to per-team config repos with shared schema validation |
| L8 | **CRD-first configuration model** | Replace file-based config expansion with Kubernetes CRDs managed by operators; GitOps-native, cluster as source of truth |
| L9 | **ConfigGen → RP integration** | Connect ConfigGen output to BasePlatformRP for runtime validation, feedback, and drift detection |
| L10 | **Backward compatibility windows** | Require N-1 version compatibility for all ConfigGen breaking changes; automated compatibility testing |

### 5.4 Platform Resilience

| # | Initiative | Description |
|---|-----------|-------------|
| L11 | **Self-hosted VPA at scale** | Replace AKS VPA add-on with self-hosted VPA for >1k pod clusters |
| L12 | **Minimum D8 node size standard** | Enforce D8+ across all clusters to prevent daemonset overhead from starving workloads |
| L13 | **Additional STG validation ring** | Add pre-prod ring for sovereign clouds; catch breaking changes before USNat/USGov impact |
| L14 | **RP-driven deployment model** | Resource Provider as control plane for cross-cluster scheduling, side-by-side deployments, centralized quota |

---

## 6. Prioritized Recommendations

### Tier 1 — Do Now (Critical, Low Effort)

1. **N3: Decouple Geneva from Istio mesh** — Prevents cascading observability blackouts during incidents (Jan 2026 outage root cause)
2. **C1: Enforce minimum ConfigGen NuGet version** — Eliminates known-broken deployment paths at CI time
3. **O1: Deny assignments for manual deletions** — Prevents alert storms from manual resource removal
4. **I1: Istio exclusion list for infra components** — Reduces mesh-induced failure surface

### Tier 2 — Do Soon (High Impact, Medium Effort)

5. **N1: Zone-aware NAT Gateway monitoring** — Reduces false Sev2 pages and improves incident discrimination
6. **N2: DNS health in node readiness** — Prevents pod scheduling on DNS-broken nodes
7. **C2: Deployment feedback webhook** — Closes the IDP visibility gap for EV2 failures
8. **I2: ztunnel health monitoring with rollback** — Automated safety net for mesh failures

### Tier 3 — Plan Next Quarter (Strategic)

9. **L7: Decentralize ConfigGen ownership** — Removes central bottleneck; enables team velocity
10. **L13: Additional STG ring for sovereign clouds** — Catches sovereign-specific failures pre-production
11. **L8: CRD-first configuration model** — Long-term replacement for file-based config expansion
12. **L14: RP-driven deployment model** — Strategic architecture for fleet-scale reliability

---

## 7. Metrics to Track

| Metric | Current State | Target |
|--------|--------------|--------|
| IcM count (DK8S platform) | Tracked; leadership KPI to reduce | -30% Q-over-Q |
| Mean time to mitigation | Tracked | Reduce by 25% |
| ConfigGen breaking changes per quarter | "Too many" (leadership acknowledgment) | ≤1 per quarter |
| NAT Gateway false Sev2 pages | Unknown (no zone discrimination) | Eliminate with zone-aware monitoring |
| ConfigGen NuGet adoption latency | Voluntary; teams delay | <2 weeks for critical versions |
| Istio ztunnel failure rate | Not tracked | <0.1% per cluster |

---

## 8. Cross-Reference: Related Documents

| Document | Relevance |
|----------|-----------|
| `dk8s-infrastructure-inventory.md` | Full cluster and component inventory |
| `dk8s-platform-knowledge.md` | Platform architecture reference |
| `analysis-belanna-infrastructure.md` | Prior infrastructure deep-dive |
| `analysis-worf-security.md` | Security findings (cert rotation, network policies) |
| DK8S Resiliency to AZ Failures (SharePoint) | Zone failure design doc |
| Design Doc for Model DK8s Clusters in ConfigGen (SharePoint) | ConfigGen modeling decisions |
| Dk8s next.pptx | Future platform architecture |

---

*Analysis based on confirmed incidents, meeting transcripts, email threads, design documents, and engineering hub documentation. No speculative findings included — all issues cited have explicit source evidence.*
