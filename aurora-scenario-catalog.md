# DK8S Scenario Catalog for Aurora

**Author:** Seven (Research & Docs) — Issue #4  
**Date:** 2026-03-07  
**Status:** Proposed — ready for team review  
**Sources:** Aurora workload manifest schema (WorkIQ/EngineeringHub), Cloud Talks transcript, B'Elanna's stability analysis, DK8S platform knowledge base, infrastructure inventory  
**Classification:** Internal — not for external distribution

---

## Table of Contents

1. [Aurora Scenario Structure](#1-aurora-scenario-structure)
2. [DK8S-to-Aurora Mapping Strategy](#2-dk8s-to-aurora-mapping-strategy)
3. [P0 — Critical Path Scenarios](#3-p0--critical-path-scenarios)
4. [P1 — High Value Scenarios](#4-p1--high-value-scenarios)
5. [P2 — Extended Coverage Scenarios](#5-p2--extended-coverage-scenarios)
6. [Deep Dive: Cluster Provisioning Experiment](#6-deep-dive-cluster-provisioning-experiment)
7. [Matrix Dimensions](#7-matrix-dimensions)
8. [Implementation Roadmap](#8-implementation-roadmap)

---

## 1. Aurora Scenario Structure

Aurora workloads are defined via a **JSON workload manifest** with three top-level sections:

```json
{
  "Workload": {
    "Name": "DK8S_ClusterProvisioning",
    "Description": "End-to-end cluster provisioning validation",
    "ManagedBy": "Aurora",
    "QualityMetrics": null,
    "WorkloadRunType": "Draft"
  },
  "Properties": {
    "SubscriptionId": "__SubscriptionId__",
    "Region": "__Region__",
    "CreateIcM": "__CreateIcM__",
    "CreateImpact": false,
    "ScenarioExecutionByManifest": true,
    "ExecutionTags": ["dk8s", "cluster-provisioning"],
    "NotificationFrequency": "Weekly",
    "GroupId": "<guid>",
    "GroupName": "DK8S_Provisioning_Dev",
    "ClassName": "CommonScenarioGroup",
    "AssemblyName": "Aurora.DK8S.Scenarios",
    "ResourceGroupPrefix": "dk8s-aurora"
  },
  "Scenarios": [
    {
      "ScenarioName": "Create_AksCluster",
      "Assembly": "Aurora.DK8S.ScenarioTests",
      "ScenarioClass": "ClusterProvisioningGroup",
      "ScenarioMethod": "Create_AksCluster",
      "Enabled": true,
      "NodeVmSize": "__Systempool_NodeSKU__",
      "InitialAgentCount": 3
    }
  ]
}
```

**Key concepts:**
- **Parameterization:** `__Token__` syntax resolved from a parameters file at execution time
- **Workload types:** Control-plane (short, discrete ops), Data-plane/DW (long-haul continuous), Customer reference (realistic E2E), Service availability monitoring (lightweight probes), Bridge (reuse existing ADO tests)
- **Matrix execution:** One workload definition × multiple parameter combinations (regions, SKUs) executed in parallel
- **ICM integration:** Automatic incident creation on failure with configurable severity and routing
- **Execution modes:** Ad-hoc (run once), scheduled/recurring, DIV-triggered (deployment-gated)

---

## 2. DK8S-to-Aurora Mapping Strategy

### Workload Type Selection

| DK8S Operation Category | Recommended Aurora Workload Type | Rationale |
|------------------------|----------------------------------|-----------|
| Cluster lifecycle (create, upgrade, delete) | **Control-plane** | Discrete operations with binary pass/fail |
| Component deployment (Helm/ArgoCD) | **Control-plane** | Deployment + validation sequence |
| Networking resilience (NAT GW, DNS) | **Data-plane (DW)** | Requires sustained monitoring to detect degradation |
| ConfigGen pipeline | **Bridge** | Reuse existing ADO pipeline tests directly |
| Service mesh (Istio) | **Control-plane + Data-plane** | Injection is control-plane; mesh behavior is data-plane |
| Cross-region failover | **Customer reference** | Multi-step, multi-resource realistic scenario |
| Platform health monitoring | **Service availability monitoring** | Lightweight probes, high frequency |

### Integration Entry Points

1. **Phase 1 — Bridge:** Connect existing DK8S ADO pipelines to Aurora (zero test rewriting)
2. **Phase 2 — Control-plane workloads:** Build native Aurora scenarios for cluster ops
3. **Phase 3 — Data-plane/DW workloads:** Long-haul resiliency and performance scenarios
4. **Phase 4 — DIV integration:** Gate production deployments on Aurora validation results

---

## 3. P0 — Critical Path Scenarios

### SC-001: Cluster Provisioning

| Field | Value |
|-------|-------|
| **Scenario ID** | `SC-001` |
| **Name** | `DK8S_Cluster_Provisioning` |
| **What it validates** | End-to-end creation of a new DK8S AKS cluster including VNET, NSG, node pools, system components, and ArgoCD bootstrap |
| **Aurora workload type** | Control-plane |
| **Priority** | **P0** |
| **Input parameters** | `Region`, `SubscriptionId`, `ClusterNamePrefix`, `Tenant`, `Environment` (dev/test/prod), `SystemPoolSKU` (Standard_Dds_v6), `UserPoolSKU` (Standard_Dds_v6), `SystemPoolCount` (3), `UserPoolCount` (3–6), `KubernetesVersion`, `NetworkPlugin` (azure/cilium) |
| **Success criteria** | Cluster reaches `Succeeded` provisioning state within 45 min; all system node pools `Ready`; kube-system pods healthy; ArgoCD sync completes; DNS resolution functional; Geneva agents reporting |
| **SLA targets** | Provisioning < 45 min; 0 failed system pods; ArgoCD sync < 10 min post-provision |
| **Matrix dimensions** | Regions: `eastus2`, `westus2`, `westeurope`, `swedencentral` × K8s versions: `1.29`, `1.30`, `1.31` × Network: `azure`, `cilium` |
| **Estimated execution** | ~60 min per matrix cell |
| **Dependencies** | Azure subscription with quota; VNET address space; ACR access; EV2 templates |
| **Validation sequence** | 1. ARM deployment → 2. AKS provisioning → 3. Node pool readiness → 4. System pod health → 5. ArgoCD bootstrap → 6. DNS resolution → 7. Geneva telemetry flow → 8. Cleanup |
| **Metrics to capture** | Provisioning duration (p50/p95/p99), node readiness time, pod startup latency, ArgoCD sync duration, first-telemetry time |

---

### SC-002: Cluster Upgrade

| Field | Value |
|-------|-------|
| **Scenario ID** | `SC-002` |
| **Name** | `DK8S_Cluster_Upgrade` |
| **What it validates** | Kubernetes version upgrade on existing cluster — control plane upgrade, node pool surge upgrade, workload continuity during upgrade |
| **Aurora workload type** | Control-plane |
| **Priority** | **P0** |
| **Input parameters** | `Region`, `SubscriptionId`, `ClusterId`, `SourceK8sVersion`, `TargetK8sVersion`, `MaxSurge` (33%), `NodeDrainTimeout` (30 min), `PodDisruptionBudget` (75%) |
| **Success criteria** | Control plane upgrade completes; all node pools upgraded; zero data-plane downtime (measured via continuous health probe); no pod eviction failures; workload identity intact post-upgrade |
| **SLA targets** | Control plane upgrade < 30 min; node pool upgrade < 15 min/pool; zero involuntary pod kills; workload availability > 99.9% during upgrade |
| **Matrix dimensions** | Upgrade paths: `1.29→1.30`, `1.30→1.31` × Regions: `eastus2`, `westeurope` × Cluster sizes: small (3 nodes), medium (10 nodes), large (30+ nodes) |
| **Estimated execution** | ~90 min per matrix cell |
| **Dependencies** | Pre-provisioned cluster at source version; continuous health probe workload running |
| **Known risks** | AKS platform changes can remove critical workload identity services during upgrade (confirmed incident, B'Elanna's analysis); cluster autoscaler + VMSS failures during Istio-enabled cluster upgrades |
| **Metrics to capture** | Upgrade total duration, per-node-pool upgrade time, pod eviction count, workload availability percentage, API server availability during upgrade |

---

### SC-003: Node Pool Scaling

| Field | Value |
|-------|-------|
| **Scenario ID** | `SC-003` |
| **Name** | `DK8S_NodePool_Scaling` |
| **What it validates** | Node pool scale-up and scale-down operations, including VMSS provisioning, node readiness, pod scheduling, and graceful drain |
| **Aurora workload type** | Control-plane |
| **Priority** | **P0** |
| **Input parameters** | `Region`, `SubscriptionId`, `ClusterId`, `PoolName`, `CurrentNodeCount`, `TargetNodeCount` (scale-up), `ScaleDownNodeCount`, `NodeSKU`, `MaxPodsPerNode` (50), `DrainTimeout` |
| **Success criteria** | Scale-up: new nodes reach `Ready` state within 10 min; pods scheduled on new nodes within 2 min of readiness. Scale-down: nodes cordoned, pods drained, VMSS instances deleted cleanly |
| **SLA targets** | Node readiness < 10 min; pod scheduling < 2 min post-readiness; drain completes < 5 min; no orphaned VMSS instances |
| **Matrix dimensions** | Scale directions: up (3→6, 6→15, 15→30), down (30→15, 15→6) × SKUs: `Standard_D4ds_v6`, `Standard_D8ds_v6`, `Standard_D16ds_v6` × Regions: `eastus2`, `westeurope` |
| **Estimated execution** | ~30 min per matrix cell |
| **Dependencies** | Pre-provisioned cluster with target node pool; sufficient Azure quota in region |
| **Known risks** | Quota exhaustion during scale events stalls upgrades (confirmed pattern); cluster autoscaler + VMSS failures (confirmed Sev2) |
| **Metrics to capture** | VMSS provision time, node readiness latency, pod scheduling latency, drain duration, quota utilization |

---

### SC-004: Component Deployment

| Field | Value |
|-------|-------|
| **Scenario ID** | `SC-004` |
| **Name** | `DK8S_Component_Deployment` |
| **What it validates** | End-to-end deployment of a Helm chart via ArgoCD app-of-apps pattern — image pull, chart render, deployment rollout, health checks, ArgoCD sync status |
| **Aurora workload type** | Control-plane |
| **Priority** | **P0** |
| **Input parameters** | `Region`, `ClusterId`, `ComponentName`, `ChartVersion`, `ImageTag`, `Namespace`, `Tenant`, `ACR` (`wcdprodacr.azurecr.io`), `ValuesOverride` (environment-specific) |
| **Success criteria** | ArgoCD Application reaches `Synced`+`Healthy` status; all pods in target deployment are `Running`+`Ready`; service endpoints responding; Prometheus ServiceMonitor scraping successfully |
| **SLA targets** | ArgoCD sync < 5 min; pod rollout < 3 min; health check pass < 1 min post-rollout; zero CrashLoopBackOff |
| **Matrix dimensions** | Components: `prometheus`, `logging`, `ingress`, `secret-sync-controller`, `logging-operator` × Environments: dev, test, prod × Regions: `eastus2`, `westeurope` |
| **Estimated execution** | ~15 min per matrix cell |
| **Dependencies** | Healthy cluster; ArgoCD installed and connected; ACR credentials; component image in registry |
| **Known risks** | ArgoCD rollback failures — rollbacks don't cleanly revert shared resources (ingress, identities, bindings) per DK8S Leads meetings. Image pull failures cascade from NAT Gateway issues |
| **Metrics to capture** | Sync duration, pod startup time, image pull time, rollout completion time, first health check pass |

---

## 4. P1 — High Value Scenarios

### SC-005: ConfigGen Validation

| Field | Value |
|-------|-------|
| **Scenario ID** | `SC-005` |
| **Name** | `DK8S_ConfigGen_Validation` |
| **What it validates** | ConfigGen pipeline — manifest expansion from generic user manifest to cluster-specific configuration, NuGet package resolution, EV2 parameter generation |
| **Aurora workload type** | **Bridge** (reuse existing ADO pipeline) |
| **Priority** | **P1** |
| **Input parameters** | `PipelineId` (ADO Build Pipeline ID), `NuGetVersion` (ConfigGen package version), `ManifestPath`, `ClusterInventoryPath`, `TenantFilter` |
| **Success criteria** | Pipeline completes without errors; generated configs match expected schema; no breaking change regressions; EV2 parameters valid |
| **SLA targets** | Pipeline execution < 15 min; 0 schema validation errors; diff from baseline < threshold |
| **Matrix dimensions** | ConfigGen versions: current, current-1 × Tenant counts: single-tenant, multi-tenant × Cluster types: uniform fleet, non-uniform fleet |
| **Estimated execution** | ~20 min per matrix cell |
| **Dependencies** | ADO pipeline with Aurora Bridge connector; ConfigGen NuGet feed access; cluster inventory repo |
| **Known risks** | ConfigGen breaking changes are a confirmed productivity killer at IDP leadership level. NuGet version adoption is voluntary; teams delay upgrades. Centralized config repos create bottleneck |
| **Metrics to capture** | Pipeline duration, expansion output size, schema validation results, diff from previous version |

---

### SC-006: Networking Resilience (NAT Gateway Failover)

| Field | Value |
|-------|-------|
| **Scenario ID** | `SC-006` |
| **Name** | `DK8S_NAT_Gateway_Resilience` |
| **What it validates** | Cluster behavior during NAT Gateway degradation — image pull capability, secret mount operations, probe health, egress connectivity, and recovery |
| **Aurora workload type** | **Data-plane (DW)** — long-haul with Chaos Studio integration |
| **Priority** | **P1** |
| **Input parameters** | `Region`, `ClusterId`, `ChaosExperimentId`, `FaultType` (NAT GW datapath degradation), `FaultDuration` (15–60 min), `AffectedZone` (single AZ vs region-wide), `MonitoringInterval` (30s) |
| **Success criteria** | Workloads survive single-AZ NAT Gateway failure without Sev2; image pulls succeed via alternate path within 5 min; secrets mount within 10 min; Geneva telemetry continues flowing |
| **SLA targets** | Workload availability > 99% during single-AZ failure; recovery < 10 min post-fault-clear; zero data loss |
| **Matrix dimensions** | Fault scopes: single-AZ, multi-AZ × Regions: `westeurope` (confirmed incident region), `eastus2` × Cluster sizes: small, large |
| **Estimated execution** | ~90 min per matrix cell (includes fault injection + recovery + validation) |
| **Dependencies** | Azure Chaos Studio access; pre-provisioned cluster with running workloads; NAT Gateway zone awareness |
| **Known risks** | NAT Gateway zonal failures are ~monthly (confirmed via IcM). No zone-aware monitoring today — single NAT GW drop pages as Sev2 without AZ discrimination |
| **Metrics to capture** | Time-to-detect, time-to-recover, image pull success rate during fault, secret mount latency, Geneva delivery rate, pod restart count |

---

### SC-007: DNS Resolution Under Load

| Field | Value |
|-------|-------|
| **Scenario ID** | `SC-007` |
| **Name** | `DK8S_DNS_Resolution_Load` |
| **What it validates** | CoreDNS performance under sustained query load — resolution latency, failure rate, interaction with Istio ztunnel, behavior during node DNS failures |
| **Aurora workload type** | **Data-plane (DW)** |
| **Priority** | **P1** |
| **Input parameters** | `Region`, `ClusterId`, `QueryRate` (qps target), `QueryDomains` (internal services, external endpoints, ACR), `Duration` (1–8 hours), `IstioEnabled` (true/false) |
| **Success criteria** | DNS resolution latency p99 < 100ms under load; failure rate < 0.1%; no cascading failures when individual nodes lose DNS; Geneva agents continue reporting |
| **SLA targets** | Resolution p50 < 5ms, p99 < 100ms; error rate < 0.1%; recovery from node-level DNS failure < 2 min |
| **Matrix dimensions** | Load levels: 100qps, 500qps, 1000qps × Istio mesh: enabled, disabled × CoreDNS replicas: 2, 4, 8 |
| **Estimated execution** | ~120 min per matrix cell |
| **Dependencies** | Pre-provisioned cluster; CoreDNS configured; load generator workload; DNS monitoring |
| **Known risks** | DNS failures amplified by Istio ztunnel and cluster autoscaler (confirmed Sev2 Jan 2026). Geneva log/metric delivery fails when DNS fails, creating observability blackouts |
| **Metrics to capture** | Resolution latency (p50/p95/p99), error rate, CoreDNS pod CPU/memory, ztunnel interaction latency, Geneva delivery rate |

---

### SC-008: Istio Mesh Injection/Rollback

| Field | Value |
|-------|-------|
| **Scenario ID** | `SC-008` |
| **Name** | `DK8S_Istio_Mesh_Operations` |
| **What it validates** | Istio ambient mode (ztunnel) injection into namespaces, mTLS establishment, traffic routing, and clean rollback to non-mesh state |
| **Aurora workload type** | **Control-plane** (injection/rollback) + **Data-plane** (mesh behavior) |
| **Priority** | **P1** |
| **Input parameters** | `Region`, `ClusterId`, `Namespace`, `IstioVersion`, `MeshMode` (ambient/sidecar), `ExclusionList` (kube-system, geneva-loggers, CoreDNS), `mTLSMode` (strict/permissive) |
| **Success criteria** | Injection: ztunnel pods running on all nodes; mTLS established between mesh services; traffic flows without errors. Rollback: clean removal without pod restarts; no orphaned ztunnel resources |
| **SLA targets** | Injection < 5 min per namespace; zero service disruption during injection; rollback < 5 min; mTLS handshake < 500ms |
| **Matrix dimensions** | Istio versions: current, current-1 × Mesh modes: ambient, sidecar × Namespace counts: 1, 5, 15 |
| **Estimated execution** | ~45 min per matrix cell |
| **Dependencies** | Pre-provisioned cluster; Istio control plane installed; test workloads in target namespaces |
| **Known risks** | Istio ztunnel misbehavior under DNS failures confirmed Sev2 (Jan 2026, CUS3-20, WEU3-20). Including infrastructure services in mesh creates cascading failure paths. Scale-up failures interact with VMSS provisioning and ztunnel initialization |
| **Metrics to capture** | Injection duration, mTLS establishment time, inter-service latency (mesh vs non-mesh), rollback duration, pod restart count |

---

## 5. P2 — Extended Coverage Scenarios

### SC-009: Multi-Tenant Isolation Validation

| Field | Value |
|-------|-------|
| **Scenario ID** | `SC-009` |
| **Name** | `DK8S_MultiTenant_Isolation` |
| **What it validates** | Namespace isolation between tenants — network policies, RBAC enforcement, resource quotas, cross-tenant traffic blocking |
| **Aurora workload type** | Control-plane |
| **Priority** | **P2** |
| **Input parameters** | `Region`, `ClusterId`, `TenantA`, `TenantB`, `NetworkPolicyMode` (default-deny), `ResourceQuota`, `RBACConfig` |
| **Success criteria** | Cross-namespace traffic blocked by default; RBAC prevents tenant-A accessing tenant-B resources; resource quotas enforced; no privilege escalation paths |
| **SLA targets** | 100% network policy enforcement; 0 cross-tenant RBAC violations; quota enforcement within 1 min |
| **Matrix dimensions** | Tenant pairs: 2, 5, 10 tenants × Network plugins: azure, cilium × Policy modes: default-deny, custom |
| **Estimated execution** | ~30 min per matrix cell |
| **Dependencies** | Multi-tenant cluster; network policy controller; RBAC configuration |
| **Known risks** | No evidence of default-deny Kubernetes Network Policies today (confirmed security gap per Worf's analysis) |

---

### SC-010: Cross-Region Failover

| Field | Value |
|-------|-------|
| **Scenario ID** | `SC-010` |
| **Name** | `DK8S_CrossRegion_Failover` |
| **What it validates** | Service continuity during regional failure — Traffic Manager failover, secondary cluster activation, data consistency, DNS propagation |
| **Aurora workload type** | **Customer reference** (multi-resource, realistic E2E) |
| **Priority** | **P2** |
| **Input parameters** | `PrimaryRegion`, `SecondaryRegion`, `TrafficManagerProfile`, `FailoverType` (planned/unplanned), `ServiceEndpoints`, `DNSPropagationTimeout` |
| **Success criteria** | Failover completes within target RTO; secondary cluster serves traffic; DNS resolves to secondary; no data loss beyond RPO |
| **SLA targets** | RTO < 15 min (planned), < 30 min (unplanned); RPO < 5 min; DNS propagation < 5 min |
| **Matrix dimensions** | Region pairs: `eastus2↔westus2`, `westeurope↔swedencentral` × Failover types: planned, unplanned × Service counts: 1, 5, 10 |
| **Estimated execution** | ~120 min per matrix cell |
| **Dependencies** | Multi-region deployment; Traffic Manager configured; secondary cluster pre-provisioned |
| **Known risks** | DR limitations — supportability clusters have regional constraints (Kusto leader/follower); no cross-region BCDR out of box |

---

### SC-011: Certificate Rotation

| Field | Value |
|-------|-------|
| **Scenario ID** | `SC-011` |
| **Name** | `DK8S_Certificate_Rotation` |
| **What it validates** | TLS certificate rotation without service disruption — KeyVault certificate update, in-cluster secret sync, pod restart with new cert, mTLS re-establishment |
| **Aurora workload type** | Control-plane |
| **Priority** | **P2** |
| **Input parameters** | `Region`, `ClusterId`, `KeyVaultName`, `CertificateName`, `RotationMethod` (auto/manual), `GracePeriodDays` (30), `SecretSyncInterval` |
| **Success criteria** | New certificate propagated to all pods within grace period; zero TLS errors during rotation; mTLS connections re-established; no service downtime |
| **SLA targets** | Propagation < 15 min; 0 TLS handshake failures; 0 pod crash loops; service availability 100% during rotation |
| **Matrix dimensions** | Rotation methods: auto (cert-manager), manual (KeyVault) × Certificate types: server, client, mTLS × Secret sync controllers: SecretSyncController, KeyVaultWatcher |
| **Estimated execution** | ~30 min per matrix cell |
| **Dependencies** | KeyVault access; SecretSyncController or KeyVaultWatcher installed; certificate authority |
| **Known risks** | Manual certificate rotation is a CRITICAL security finding — KeyVault TLS certificates require manual rotation by service owners. Expired certificates cause outages |

---

### SC-012: Secret Rotation

| Field | Value |
|-------|-------|
| **Scenario ID** | `SC-012` |
| **Name** | `DK8S_Secret_Rotation` |
| **What it validates** | Application secret rotation — KeyVault secret update, CSI driver sync, pod rolling restart, application reconnection with new credentials |
| **Aurora workload type** | Control-plane |
| **Priority** | **P2** |
| **Input parameters** | `Region`, `ClusterId`, `KeyVaultName`, `SecretName`, `SecretType` (connection-string, api-key, certificate), `SyncInterval`, `ApplicationDeployment` |
| **Success criteria** | New secret value available in pods within sync interval; application reconnects using new credentials; no authentication failures during rotation; rolling restart completes without downtime |
| **SLA targets** | Secret propagation < 5 min; 0 authentication failures; pod rolling restart < 3 min; service availability 100% |
| **Matrix dimensions** | Secret types: connection-string, api-key, certificate × Sync methods: CSI driver, SecretSyncController × Application types: stateless, stateful |
| **Estimated execution** | ~20 min per matrix cell |
| **Dependencies** | KeyVault CSI driver installed; SecretSyncController configured; test application with secret dependency |

---

## 6. Deep Dive: Cluster Provisioning Experiment

This section provides the detailed scenario definition for the proposed first Aurora experiment.

### 6.1 Full Workload Manifest

```json
{
  "Workload": {
    "Name": "DK8S_ClusterProvisioning_E2E",
    "Description": "End-to-end validation of DK8S AKS cluster provisioning including networking, node pools, system components, ArgoCD bootstrap, and observability stack",
    "ManagedBy": "Aurora",
    "QualityMetrics": {
      "ProvisioningDuration_P95_Minutes": 45,
      "SystemPodHealth_Percentage": 100,
      "ArgoCDSyncDuration_P95_Minutes": 10,
      "DNSResolution_SuccessRate": 99.9,
      "GenevaFirstTelemetry_P95_Minutes": 5
    },
    "WorkloadRunType": "Draft"
  },
  "Properties": {
    "SubscriptionId": "__SubscriptionId__",
    "Region": "__Region__",
    "CreateIcM": "__CreateIcM__",
    "CreateImpact": false,
    "ScenarioExecutionByManifest": true,
    "ExecutionTags": ["dk8s", "cluster-provisioning", "e2e", "p0"],
    "NotificationFrequency": "Weekly",
    "GroupId": "__GroupId__",
    "GroupName": "DK8S_Provisioning",
    "ClassName": "ClusterProvisioningScenarioGroup",
    "AssemblyName": "Aurora.DK8S.Scenarios",
    "ResourceGroupPrefix": "dk8s-aurora-provision"
  },
  "Scenarios": [
    {
      "ScenarioName": "VNET_And_NSG_Creation",
      "Assembly": "Aurora.DK8S.ScenarioTests",
      "ScenarioClass": "NetworkingGroup",
      "ScenarioMethod": "Create_VNET_With_NSG",
      "Enabled": true,
      "Order": 1,
      "VNetAddressSpace": "10.0.0.0/16",
      "SubnetCount": 3,
      "NSGRules": "dk8s-standard"
    },
    {
      "ScenarioName": "AKS_Cluster_Creation",
      "Assembly": "Aurora.DK8S.ScenarioTests",
      "ScenarioClass": "ClusterProvisioningGroup",
      "ScenarioMethod": "Create_AksCluster",
      "Enabled": true,
      "Order": 2,
      "KubernetesVersion": "__KubernetesVersion__",
      "NetworkPlugin": "__NetworkPlugin__",
      "NodeVmSize": "__Systempool_NodeSKU__",
      "NodeOsDiskSize": "__Systempool_NodeOsDiskSize__",
      "NodeOsDiskType": "Ephemeral",
      "InitialAgentCount": 3,
      "MaxPodsPerNode": 50
    },
    {
      "ScenarioName": "UserPool_Creation",
      "Assembly": "Aurora.DK8S.ScenarioTests",
      "ScenarioClass": "ClusterProvisioningGroup",
      "ScenarioMethod": "Create_UserNodePool",
      "Enabled": true,
      "Order": 3,
      "NodeVmSize": "__Userpool_NodeSKU__",
      "InitialAgentCount": "__Userpool_InitialCount__",
      "AvailabilityZones": ["1", "2", "3"]
    },
    {
      "ScenarioName": "System_Pod_Health_Check",
      "Assembly": "Aurora.DK8S.ScenarioTests",
      "ScenarioClass": "HealthCheckGroup",
      "ScenarioMethod": "Validate_SystemPods",
      "Enabled": true,
      "Order": 4,
      "RequiredNamespaces": ["kube-system"],
      "RequiredPods": ["coredns", "kube-proxy", "azure-cni"],
      "HealthTimeout": 600
    },
    {
      "ScenarioName": "ArgoCD_Bootstrap",
      "Assembly": "Aurora.DK8S.ScenarioTests",
      "ScenarioClass": "GitOpsGroup",
      "ScenarioMethod": "Bootstrap_ArgoCD",
      "Enabled": true,
      "Order": 5,
      "ArgoCDRepoURL": "https://dev.azure.com/microsoft/WDATP/_git/Infra.K8s.ArgoCD",
      "AppOfAppsPath": "app-of-dk8s-apps/",
      "SyncTimeout": 600
    },
    {
      "ScenarioName": "DNS_Resolution_Validation",
      "Assembly": "Aurora.DK8S.ScenarioTests",
      "ScenarioClass": "NetworkingGroup",
      "ScenarioMethod": "Validate_DNS",
      "Enabled": true,
      "Order": 6,
      "TestDomains": ["kubernetes.default.svc", "wcdprodacr.azurecr.io"],
      "MaxLatencyMs": 100,
      "QueryCount": 100
    },
    {
      "ScenarioName": "Geneva_Telemetry_Flow",
      "Assembly": "Aurora.DK8S.ScenarioTests",
      "ScenarioClass": "ObservabilityGroup",
      "ScenarioMethod": "Validate_Geneva_Flow",
      "Enabled": true,
      "Order": 7,
      "GenevaAccount": "__GenevaAccount__",
      "GenevaNamespace": "__GenevaNamespace__",
      "MaxFirstTelemetryMinutes": 5
    },
    {
      "ScenarioName": "Cleanup",
      "Assembly": "Aurora.DK8S.ScenarioTests",
      "ScenarioClass": "ClusterProvisioningGroup",
      "ScenarioMethod": "Delete_Cluster_And_Resources",
      "Enabled": true,
      "Order": 8
    }
  ]
}
```

### 6.2 Parameters File (for Matrix Execution)

```json
{
  "ParameterSets": [
    {
      "Name": "EastUS2_v1.30_Azure",
      "SubscriptionId": "<dk8s-test-sub-id>",
      "Region": "eastus2",
      "KubernetesVersion": "1.30",
      "NetworkPlugin": "azure",
      "Systempool_NodeSKU": "Standard_D4ds_v6",
      "Systempool_NodeOsDiskSize": "128",
      "Userpool_NodeSKU": "Standard_D8ds_v6",
      "Userpool_InitialCount": "3",
      "CreateIcM": "false",
      "GroupId": "<guid>",
      "GenevaAccount": "dk8s-test",
      "GenevaNamespace": "dk8s"
    },
    {
      "Name": "WestEurope_v1.31_Cilium",
      "SubscriptionId": "<dk8s-test-sub-eu>",
      "Region": "westeurope",
      "KubernetesVersion": "1.31",
      "NetworkPlugin": "cilium",
      "Systempool_NodeSKU": "Standard_D4ds_v6",
      "Systempool_NodeOsDiskSize": "128",
      "Userpool_NodeSKU": "Standard_D8ds_v6",
      "Userpool_InitialCount": "6",
      "CreateIcM": "false",
      "GroupId": "<guid>",
      "GenevaAccount": "dk8s-test-eu",
      "GenevaNamespace": "dk8s"
    }
  ]
}
```

### 6.3 Step-by-Step Validation Sequence

```
Phase 1: Infrastructure Setup (0-10 min)
├── 1.1 Create Resource Group with DK8S naming convention
├── 1.2 Deploy VNET with 3 subnets (system, user, pods)
├── 1.3 Apply NSG rules (DK8S standard egress/ingress)
└── 1.4 ✓ Validate: RG exists, VNET has 3 subnets, NSG rules applied

Phase 2: Cluster Provisioning (10-45 min)
├── 2.1 Submit AKS cluster creation (ARM/Bicep)
├── 2.2 Wait for control plane provisioning
├── 2.3 Validate system node pool readiness
├── 2.4 Create user node pool with zone spread
├── 2.5 ✓ Validate: cluster state=Succeeded, all nodes Ready, zones balanced

Phase 3: Platform Bootstrap (45-55 min)
├── 3.1 Install ArgoCD from app-of-dk8s-apps
├── 3.2 Configure ArgoCD with ADO repo credentials
├── 3.3 Trigger initial sync
├── 3.4 ✓ Validate: ArgoCD pods healthy, app-of-apps synced, child apps created

Phase 4: Health Validation (55-60 min)
├── 4.1 Check all kube-system pods (coredns, kube-proxy, azure-cni)
├── 4.2 Run DNS resolution tests (internal + external)
├── 4.3 Verify Geneva agent pod health
├── 4.4 Query Geneva for first telemetry signal
├── 4.5 ✓ Validate: all system pods Running, DNS p99 < 100ms, Geneva reporting

Phase 5: Baseline Capture (60 min)
├── 5.1 Capture timing metrics for all phases
├── 5.2 Record resource utilization (CPU, memory, disk)
├── 5.3 Log to Aurora Kusto for historical comparison
└── 5.4 ✓ Validate: all metrics recorded, comparison with previous runs

Phase 6: Cleanup (60-70 min)
├── 6.1 Delete AKS cluster
├── 6.2 Delete VNET and NSG
├── 6.3 Delete Resource Group
└── 6.4 ✓ Validate: all resources deleted, no orphaned resources
```

### 6.4 Baseline Comparison

To compare against the current (non-Aurora) provisioning process:

| Metric | Current Baseline | Aurora Target | Measurement Method |
|--------|-----------------|---------------|-------------------|
| Provisioning duration (p50) | Unknown — no structured measurement | Establish baseline in first 10 runs | Aurora Kusto query |
| Provisioning success rate | Unknown | > 95% | Aurora success/failure tracking |
| System pod readiness | Unknown — manual spot checks | 100% within 5 min post-provision | Automated health check scenario |
| ArgoCD sync time | Unknown | < 10 min | Scenario timer |
| DNS resolution latency | Unknown | p99 < 100ms | DNS probe scenario |
| First telemetry signal | Unknown | < 5 min | Geneva query scenario |

**Key insight:** DK8S currently has **no structured baseline metrics** for provisioning. The first Aurora runs will *establish* the baseline, not compare against one. This is itself a high-value outcome — you can't improve what you can't measure.

---

## 7. Matrix Dimensions

### 7.1 Global Matrix Parameters

| Dimension | Values | Applicable Scenarios |
|-----------|--------|---------------------|
| **Region** | `eastus2`, `westus2`, `westeurope`, `swedencentral` | All |
| **K8s Version** | `1.29`, `1.30`, `1.31` | SC-001, SC-002, SC-008 |
| **Network Plugin** | `azure`, `cilium` | SC-001, SC-003, SC-009 |
| **Node SKU** | `Standard_D4ds_v6`, `Standard_D8ds_v6`, `Standard_D16ds_v6` | SC-001, SC-003 |
| **Cluster Size** | small (3 nodes), medium (10 nodes), large (30+ nodes) | SC-002, SC-003, SC-006, SC-007 |
| **Environment** | dev, test, prod | SC-004, SC-005 |
| **Istio State** | enabled, disabled | SC-007, SC-008 |

### 7.2 Matrix Explosion Management

Full matrix for SC-001 alone = 4 regions × 3 K8s versions × 2 network plugins × 3 SKUs = **72 combinations**.

**Recommended strategy:**
1. **Core matrix** (always run): 2 regions × latest K8s version × default network × default SKU = **2 cells**
2. **Extended matrix** (weekly): 4 regions × 2 K8s versions × 2 network plugins = **16 cells**
3. **Full matrix** (monthly or pre-release): All combinations = **72 cells**

---

## 8. Implementation Roadmap

### Phase 1: Bridge Integration (Weeks 1–4)

| Step | Action | Owner | Deliverable |
|------|--------|-------|-------------|
| 1.1 | Register DK8S with Aurora | DK8S Platform Team | Aurora subscription + Fairbanks access |
| 1.2 | Connect ConfigGen ADO pipeline via Aurora Bridge | DK8S Platform Team | SC-005 running in Aurora |
| 1.3 | Connect sanity test pipeline via Aurora Bridge | DK8S Platform Team | Bridge validation of `k8sSanityApp` |
| 1.4 | Configure ICM routing for Bridge workloads | DK8S Platform Team | ICM rules for DK8S service tree |

### Phase 2: Control-Plane Workloads (Weeks 5–12)

| Step | Action | Owner | Deliverable |
|------|--------|-------|-------------|
| 2.1 | Build Aurora .NET SDK project for DK8S scenarios | DK8S Platform Team | `Aurora.DK8S.Scenarios` assembly |
| 2.2 | Implement SC-001 (Cluster Provisioning) | DK8S Platform Team | First native Aurora workload |
| 2.3 | Run SC-001 in core matrix (2 regions) | DK8S Platform Team | Baseline metrics established |
| 2.4 | Implement SC-002, SC-003, SC-004 | DK8S Platform Team | P0 scenarios operational |
| 2.5 | Configure ICM for native workloads | DK8S Platform Team | Automatic incident creation |

### Phase 3: Data-Plane & Resiliency (Weeks 13–20)

| Step | Action | Owner | Deliverable |
|------|--------|-------|-------------|
| 3.1 | Set up Chaos Studio integration | DK8S Platform Team | Fault injection capability |
| 3.2 | Implement SC-006 (NAT Gateway Resilience) | DK8S Platform Team | First resiliency scenario |
| 3.3 | Implement SC-007, SC-008 | DK8S Platform Team | DNS + Istio scenarios |
| 3.4 | Enable long-haul execution for DW workloads | DK8S Platform Team | Continuous monitoring |

### Phase 4: DIV Integration (Weeks 20+)

| Step | Action | Owner | Deliverable |
|------|--------|-------|-------------|
| 4.1 | Integrate Aurora results with Azure Build Health | DK8S Platform Team | Quality gate signal |
| 4.2 | Configure DIV triggers on EV2 deployments | DK8S Platform Team | Deployment-gated validation |
| 4.3 | Implement P2 scenarios (SC-009 through SC-012) | DK8S Platform Team | Extended coverage |
| 4.4 | Full matrix execution capability | DK8S Platform Team | Production-grade validation |

---

## Appendix: Scenario Summary Table

| ID | Name | Priority | Aurora Type | Est. Time | Matrix Size |
|----|------|----------|-------------|-----------|-------------|
| SC-001 | Cluster Provisioning | P0 | Control-plane | 60 min | 2–72 cells |
| SC-002 | Cluster Upgrade | P0 | Control-plane | 90 min | 2–12 cells |
| SC-003 | Node Pool Scaling | P0 | Control-plane | 30 min | 2–30 cells |
| SC-004 | Component Deployment | P0 | Control-plane | 15 min | 2–30 cells |
| SC-005 | ConfigGen Validation | P1 | Bridge | 20 min | 2–6 cells |
| SC-006 | NAT Gateway Resilience | P1 | Data-plane (DW) | 90 min | 2–12 cells |
| SC-007 | DNS Under Load | P1 | Data-plane (DW) | 120 min | 2–18 cells |
| SC-008 | Istio Mesh Ops | P1 | Control+Data | 45 min | 2–18 cells |
| SC-009 | Multi-Tenant Isolation | P2 | Control-plane | 30 min | 2–12 cells |
| SC-010 | Cross-Region Failover | P2 | Customer ref | 120 min | 2–12 cells |
| SC-011 | Certificate Rotation | P2 | Control-plane | 30 min | 2–6 cells |
| SC-012 | Secret Rotation | P2 | Control-plane | 20 min | 2–6 cells |

**Total scenarios:** 12  
**P0 (critical path):** 4 — must work before production Aurora adoption  
**P1 (high value):** 4 — addresses confirmed stability incidents  
**P2 (extended):** 4 — security hardening and DR validation
