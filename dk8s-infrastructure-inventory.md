# DK8S Platform Infrastructure Inventory

**Author:** B'Elanna Torres, Infrastructure Expert  
**Date:** 2026-03-06  
**Scope:** Two Kubernetes platforms — **Celestial (idk8s)** and **DK8S (Defender Kubernetes)**  
**Sources:** analysis-belanna-infrastructure.md, idk8s-infrastructure-complete-guide.md, aspire-kind-analysis.md, Dk8sCodingAI-1 skills, Dk8sCodingAIgithub docs

---

## 1. Kubernetes Clusters

### 1.1 Celestial (idk8s-infrastructure) — Production Clusters

**Total production clusters: 18** across 3 regions (Public cloud only in repo)

| Region | Cluster Name | Type | VM SKU (Linux User) | VM SKU (System) | Control Plane |
|--------|-------------|------|---------------------|-----------------|---------------|
| centralus | 001 | gateway | Standard_D32s_v4 | Standard_D16s_v4 | 5× Standard_D16s_v4 |
| centralus | 002 | gateway | Standard_D32s_v4 | Standard_D16s_v4 | 5× Standard_D16s_v4 |
| centralus | 003 | gateway | Standard_D32s_v4 | Standard_D16s_v4 | 5× Standard_D16s_v4 |
| centralus | 004 | gateway | Standard_D32s_v4 | Standard_D16s_v4 | 5× Standard_D16s_v4 |
| centralus | 005 | gateway | Standard_D32s_v4 | Standard_D16s_v4 | 5× Standard_D16s_v4 |
| centralus | mp001 | management_plane | — | — | — |
| eastus | 001 | gateway | Standard_D32s_v4 | Standard_D16s_v4 | — |
| eastus | mp001 | management_plane | — | — | — |
| northcentralus | 000–008 | gateway/gen | Standard_D32s_v4 | Standard_D16s_v4 | — |
| northcentralus | mp001 | management_plane | — | — | — |

**Test clusters: 5** (eastus2, swedencentral)  
**Dev clusters: 2** (eastus2, swedencentral)  
**Pre-release: 1** (centralus — gateway, Standard_D4ds_v6)  
**Non-SDP special-purpose: 5** (swedencentral, eastus2euap)

### 1.2 Celestial Cluster Types

| Type | Purpose | Extra Components |
|------|---------|------------------|
| `generic` | Base workload clusters (v2) | 7 standard components |
| `gateway` | External-facing with service tags, dedicated IPs | + wireserver-file-proxy (8 components) |
| `dpx` | Data Processing clusters | + skylarc-agent (8 components) |
| `management_plane` | Regional control plane (Scale Unit API) | MP-specific Helm values |

### 1.3 Celestial Multi-Cloud Environments

| Cloud | Code | Auth Model | ACR Registry |
|-------|------|------------|-------------|
| Azure Public | PUB | Entra ID / dSTS | `idk8sacrprod`, `iamkubernetesprod` |
| Fairfax (Gov) | FF | dSTS only | `iamkubernetesff` |
| Mooncake (China) | MC | dSTS only | `iamkubernetesmc` |
| USNat | — | dSTS only | `iamkubernetesexusnatwest` |
| USSec | — | dSTS only | `iamkubernetesrx` |
| BLEU | — | dSTS only | `iamkubernetesbc` |
| Delos | — | dSTS only | `iamkubernetesde` |

### 1.4 DK8S (Defender Kubernetes) Cluster Patterns

**Naming convention:** `{prefix}-{env}-{region}-{id}` (e.g., `mps-dk8s-prd-eus2-1234`)  
**Node pool naming:** `{region}{id}{type}{zone}` (e.g., `eus21234s1`)

**Cluster definition schema** (from `ClustersInventory_DK8S.json`):
- Fields: TENANT, ENV, DEV_GROUP, REGION, CLUSTER_ID, CLUSTER_NAME_PREFIX, CLUSTER_SUBSCRIPTION_ID
- Pool types: SYSTEM_POOLS, USER_POOLS
- Configuration repos: `Infra.K8s.Clusters/K8S.Clusters.Inventory/`
- Schema: `ClustersInventorySchema.json`

---

## 2. Node Pools & Configurations

### 2.1 Celestial Node Pools

| Pool | Purpose | Notes |
|------|---------|-------|
| System | K8s system components (kube-system) | Standard_D16s_v4 |
| User (Linux) | Tenant workloads | Standard_D32s_v4 (prod), Standard_D4ds_v6 (pre-release) |
| User (Windows) | Windows workloads (NHA, NPD, PHCS, DSMS) | Servercore:ltsc2022 base |

**SKU Standards** (ADR-0009): Dds_v6 / Dads_v6 families (new deployments)  
**Maintenance windows**: OS Image daily (22:00 local, 8hr), Host monthly (last Saturday, 4hr)  
**ARCO upgrade policy**: PlatformOrchestrated, 80% tier threshold, max 5 concurrent per region  
**Image galleries**: 1 (dev/test), 6 (prod: gal.prod + ring0-ring4)

### 2.2 DK8S Node Pools

Pool definitions stored in `ClustersInventory_DK8S.json` with per-cluster overrides.

---

## 3. Helm Charts & Their Purposes

### 3.1 Celestial Charts (idk8s-infrastructure)

| Chart | Location | Purpose | Key Features |
|-------|----------|---------|--------------|
| **Celestial** | `/src/helm/charts/celestial/` | Platform-level shared deployment chart for all services | Multi-container pods (app + Geneva sidecars), 8 sovereign clouds, KEDA autoscaling, dSMS/platform-managed secrets |
| **KeyVaultWatcher** | `/src/helm/charts/keyvaultwatcher/` | Zero-touch secret rotation sidecar | Watches KeyVaults, triggers rolling restarts on secret change, 100m CPU / 300Mi memory |
| **ValidationTests** | `/src/helm/charts/validationTests/` | Chart validation test harness | PowerShell-based render + compare against expected manifests |

**Values hierarchy** (Celestial):
```
values.yaml (base defaults)
  └── values-{REGION}-{ENV}.yaml (thin environment overlay)
      └── Platform-injected values (set by Fleet Manager at deploy time)
```

**Key base defaults**: 4 replicas, 75% PDB, no public IP, Geneva small, 300s flush, zone-spread topology

### 3.2 DK8S Charts (Defender Kubernetes)

**Standard chart structure** (from scaffold-component skill):
```
charts/{component}/
├── Chart.yaml       (apiVersion: v2)
├── values.yaml      (defaults: 2 replicas, 100m/128Mi, KEDA optional)
├── _helpers.tpl     (chart.name, chart.fullname, chart.labels, chart.selectorLabels)
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── keda.yaml     (if autoscaling)
    └── servicemonitor.yaml
```

**Values hierarchy** (3-tier):
```
values.yaml (base)
  └── helm-{env}-values.yaml (environment)
      └── helm-{env}-{tenant}-{region}-values.yaml (tenant+region)
```

**Registry**: `wcdprodacr.azurecr.io`  
**Image pattern**: `wcdprodacr.azurecr.io/{component}:$(Build.BuildNumber)`  
**Chart OCI**: `oci://wcdprodacr.azurecr.io/helm/{component}:{version}`

**Reference components**: Prometheus, Logging, defender-infra-logging-operator, GenevaExternalScaler (KEDA)

---

## 4. ArgoCD App-of-Apps Structure

### 4.1 DK8S ArgoCD Architecture

**Repository**: `Infra.K8s.ArgoCD` (Azure DevOps, WDATP project)

| Directory | Purpose |
|-----------|---------|
| `argo-cd/` | ArgoCD server installation |
| `app-of-dk8s-apps/` | Parent app-of-apps (references all child apps) |
| `chart-of-dk8s-apps/` | Chart-of-apps pattern |
| `values/` | Environment-specific values |

**Application manifest pattern**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {component-name}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://dev.azure.com/microsoft/WDATP/_git/{repo-name}
    targetRevision: HEAD
    path: charts/{component-name}
  destination:
    server: https://kubernetes.default.svc
    namespace: {namespace}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 4.2 Celestial — No ArgoCD

Celestial uses **EV2 + Component Deployer** instead of ArgoCD. Deployments are driven by EV2 shell extensions calling the ComponentDeployer.CLI which executes Helm installs per component manifest.

---

## 5. Infrastructure Patterns

### 5.1 EV2 (ExpressV2) Deployment

#### Celestial EV2 Tracks

| Track | Location | Purpose | Environments |
|-------|----------|---------|-------------|
| **clusters-sdp** | `/ev2/clusters-sdp/` | Production cluster lifecycle (SDP-governed) | dev/test/prod |
| **clusters-pre-release** | `/ev2/clusters-pre-release/` | Build qualification testing | test |
| **clusters-non-sdp** | `/ev2/clusters-non-sdp/` | Special-purpose clusters | dev/test |
| **management-plane** | `/ev2/management-plane/` | MP bootstrapping | dev/sandbox |
| **replication** | `/ev2/replication/` | Container image replication (10 clouds) | all |
| **scaleunitapi-tests** | `/ev2/scaleunitapi-tests/` | SU API test execution | — |
| **skylarc-appconfig** | `/ev2/skylarc-appconfig/` | Skylarc AppConfig | — |

**SDP Ring Rollout** (5-ring progressive):

| Ring | Clusters | Gate |
|------|----------|------|
| PPE | swedencentral-mp001, swedencentral-001, swedencentral-009 | Parallel |
| R0 (canary) | northcentralus-000, eastus-mp001, eastus-001, ncus-008 | Manual |
| R1 | centralus-001/002, ncus-001/002 | Manual |
| R2 | centralus-mp001/003, ncus-mp001/003-007 | Manual |
| R3 | centralus-004 | Manual |
| R4 | centralus-005 | Manual |

**Cluster Orchestrator Pattern** (ADR-0006): Each K8s cluster = separate EV2 stamp, enabling parallel deployment, automatic retry, and state tracking per cluster.

#### DK8S EV2 Templates

**Repository**: `WDATP.Infra.System.Cluster`  
**Structure**:
```
cg/GoTemplates/Ev2Deployment/
├── Parameters/     (ARM parameters)
├── RolloutSpecs/   (EV2 orchestration)
├── ServiceModels/  (Service definitions)
├── ScopeBindings/  (Runtime bindings)
├── Templates/      (ARM templates)
└── Scripts/        (Setup scripts)
```

### 5.2 OneBranch Pipelines

#### Celestial Pipelines (20+)

| Pipeline | Purpose |
|----------|---------|
| `OneBranch.Official.yml` | Main build + NuGet publish |
| `OneBranch.PullRequest.yml` | PR validation + mutation testing |
| `OneBranch.Cluster.Release.Official.yml` | SDP cluster deployment |
| `OneBranch.ContainerImagesBuildReplicate.Official.yml` | Image replication |
| `OneBranch.GlobalResources.Official.yml` | Bicep global resource deploy |
| `Release.FleetManager.Official.yml` | Fleet Manager release (EV2 ManagedSDP) |
| `Release.ManagementPlane.Official.yml` | MP deployment |

**Build infrastructure**: Linux (Azure Linux 3.0), Windows (LTSC2022/VSE2022), KS1 network  
**SDL**: CodeQL 3000, PoliCheck, PSScriptAnalyzer, BinSkim v4.4.2, Component Governance, ESRP signing

#### DK8S Pipeline Templates

**Required references** (all DK8S repos):
```yaml
resources:
  repositories:
    - repository: templates
      type: git
      name: DefenderCommon/Infra.Pipelines.Templates
      ref: refs/tags/1.stable
    - repository: PipelineTemplates
      type: git
      name: WDATP.Infra.System.PipelineTemplates
      ref: refs/heads/master
```

**Pipeline files**: `onebranch.official.yml`, `onebranch.buddy.yml`, `onebranch.pr.yml`  
**Template entry**: `build/helm-ev2-pkg.yaml@PipelineTemplates`

### 5.3 ConfigGen (DK8S)

**Repository**: `Wcd.Infra.ConfigurationGeneration`  
**Purpose**: Expands base manifests into per-cluster configurations

**Flow**:
```
ClustersInventory.json + base values.yaml
  → ConfigGen expansion
  → Per-cluster manifests (helm-prd-ame-eus2-1234-values.yaml)
  → Consumed by: EV2 Deployment, ArgoCD, direct Helm releases
```

### 5.4 Component Deployer (Celestial)

Three manifest types for cluster-level component installation:

| Manifest | Cluster Type | Components |
|----------|-------------|------------|
| `generic-manifest.yml` | generic | 7 base components |
| `gateway-manifest.yml` | gateway | 8 (base + wireserver-file-proxy) |
| `dpx-manifest.yml` | dpx | 8 (base + skylarc-agent) |

**Dependency chain**:
```
cluster-bicep-model (idk8sctlbicep)
  └── core-cluster-components (idk8sctlconfigure)
        ├── node-health-agent       [Team: IS]
        ├── node-repair-service     [Team: IS]
        ├── descheduler             [Team: IS]
        ├── node-problem-detector   [Team: IS]
        ├── keda                    [Team: WS]
        ├── pod-health-check-svc    [Team: WS]
        ├── remediation-controller  [Team: WS]
        ├── wireserver-file-proxy   [Team: WS, gateway only]
        └── skylarc-agent           [Team: WE, dpx only]
```

### 5.5 Container Registries

#### Celestial ACR Inventory

| Registry | Purpose | Tenant |
|----------|---------|--------|
| `idk8sacrdev` | Dev builds | Microsoft Corp (72f988bf) |
| `idk8sacrtest` | Test | AME (33e01921) |
| `idk8sacrppe` | PPE (new) | AME |
| `idk8sacrprod` | Production v3 (new) | AME |
| `iamkubernetesppe` | PPE (legacy) | AME |
| `iamkubernetesprod` | Production (legacy) | AME |
| `iamkubernetesff` | Fairfax | Fairfax (cab8a31a) |
| `iamkubernetesmc` | Mooncake | Mooncake (a55a4d5b) |
| `iamkubernetesexusnatwest` | USNat | USNat (70a90262) |
| `iamkubernetesrx` | USSec | USSec (20ac2fc4) |
| `iamkubernetesbc` | BLEU | BLEU (e4c3160c) |
| `iamkubernetesde` | Delos | Delos (eee66108) |
| `skylarcagentacr` | Skylarc agent base | — |

⚠️ **Migration in progress**: `iamkubernetes*` → `idk8sacr*` naming. Both maintained for backward compatibility.

#### DK8S ACR

| Registry | Purpose |
|----------|---------|
| `wcdprodacr.azurecr.io` | Primary container + Helm chart registry |

---

## 6. Container Images

### 6.1 Celestial Linux (.NET)

| Image | Source Project |
|-------|---------------|
| `dsms-cert-injection-service-linux` | DsmsBootstrapNodeService |
| `nha-linux` | NodeHealthAgent |
| `nrs` | NodeRepairService |
| `dsmsnativebootstrapper` | DsmsNativeBootstrapper |
| `remediation-controller-linux` | RemediationController |
| `wireserver-file-proxy-linux` | WireServerFileProxy |
| `pod-health-check-service-linux` | PodHealthCheckService |
| `npd-linux` | node-problem-detector (Dockerfile) |
| `debug` | Diagnostics container |

### 6.2 Celestial Linux (Go)

| Image | Source |
|-------|--------|
| `pod-health-api-controller-linux` | Go-based pod health API controller |

### 6.3 Celestial Windows

| Image | Source |
|-------|--------|
| `nha-windows` | NodeHealthAgent |
| `dsms-cert-injection-service-windows` | DsmsBootstrapNodeService |
| `pod-health-check-service-windows` | PodHealthCheckService |
| `npd-windows` | node-problem-detector |
| `skylarc-agent-windows` | Skylarc agent (custom) |
| `debug-windows` | Diagnostics container |

### 6.4 Base Images

| Use | Base |
|-----|------|
| Linux .NET | `mcr.microsoft.com/azurelinux/base/core:3.0` |
| Windows .NET | `mcr.microsoft.com/windows/servercore:ltsc2022` |
| NPD source | `mcr.microsoft.com/oss/v2/kubernetes/node-problem-detector:v0.8.21-2` |
| OneBranch Linux build | `mcr.microsoft.com/onebranch/azurelinux/build:3.0` |
| Skylarc base | `skylarcagentacr.azurecr.io/skylarc-agent:1.0.4` |

---

## 7. Aspire Integration

### 7.1 Celestial Aspire AppHosts

| AppHost | Purpose | Kind Cluster? | Key Resources |
|---------|---------|---------------|---------------|
| **AOS.AppHost** | AOS local dev (node health stack) | Yes (2 worker nodes) | MockIMDS per node, NHA per node, NRS, Descheduler |
| **ResourceProvider.AppHost** | RP local dev (Helm deployment testing) | Yes (single control plane) | Azurite (Azure Table Storage) |

**Custom Aspire resources**: `KindResource`, `NodeVirtualResource`, `DeschedulerResource`, `MinikubeResource`

### 7.2 BasePlatformRP Aspire AppHost

| Resource | Emulator | Purpose |
|----------|----------|---------|
| Cosmos DB | Preview emulator | Workspace storage |
| Azure Storage | Azurite | Queue processing |
| Key Vault | AzureKeyVaultEmulator | Secret management |
| App Configuration | Emulator | Feature flags |

**No Kubernetes dependency** — pure ARM Resource Provider. Kind needed only when future `ClusterGroup`/`ApplicationDeployment` resources go live.

---

## 8. Tenants (Celestial — 19 Registered)

| # | Tenant ID | Notable Services |
|---|-----------|------------------|
| 1 | **idk8s** | linuxapp, mp (Management Plane), winapp |
| 2 | **mciem** | analyticsapi, collectorlistener, datacollector, onboardingapi, reportingapi, scheduler, weatherapi |
| 3 | **eis** | Entra Identity Services |
| 4 | **kalypso** | Kalypso platform |
| 5 | **mise** | Microsoft Identity Service Essentials |
| 6 | **entragw** | Entra Gateway |
| 7 | **entrarec** | Entra Reconciliation |
| 8 | **entraghmcp** | Entra GH MCP |
| 9 | **scim** | SCIM protocol service |
| 10 | **reporting** | Reporting service |
| 11 | **appgov** | App Governance |
| 12 | **agentreg** | Agent Registry |
| 13 | **dunloe** | Dunloe service |
| 14 | **dds** | Distributed Data Service |
| 15 | **gsadp** | GSA Data Platform |
| 16 | **iamtgov** | IAM Tenant Governance |
| 17 | **idcache** | Identity Cache |
| 18 | **esi** | Entra Supplemental Intelligence |
| 19 | **ztai** | Zero Trust AI |

**Scale unit naming**: `{SERVICE}-{CLOUD}-{REGION}-{SEQ}` (e.g., `IDK8SLINUXAPP-PUB-CUS-000`)  
**Namespace isolation**: `{tenant}-{service}-{cloud}-{region}-{seq}`

---

## 9. Known Infrastructure Issues & Gaps

### 9.1 Critical

| # | Issue | Severity | Source |
|---|-------|----------|--------|
| 1 | Manual certificate rotation risk (KeyVault TLS certs) | CRITICAL | Worf security analysis |
| 2 | Traffic Manager public exposure without documented WAF | CRITICAL | Worf security analysis |
| 3 | Cross-cloud security inconsistency | CRITICAL | Worf security analysis |
| 4 | Skylarc `start.ps1` silently continues after bootstrapper failure (commented-out exit) | HIGH | B'Elanna analysis |
| 5 | SDP R2 deploys 8 clusters at once — large blast radius | MEDIUM | B'Elanna analysis |
| 6 | MP uses Ubuntu 20.04 while pre-release uses Azure Linux 3.0 — inconsistent base images | MEDIUM | B'Elanna analysis |

### 9.2 Architecture Debt

| # | Item | Status |
|---|------|--------|
| 1 | ACR naming migration (`iamkubernetes*` → `idk8sacr*`) | In progress |
| 2 | v2 → v3 cluster migration (platform-managed secrets → dSMS) | Ongoing |
| 3 | ConfigMap → CRD state management migration (MVP Phase 3) | Planned |
| 4 | Entra ID → dSTS-only authentication | Planned (6-month target) |
| 5 | Maintenance config timezone hardcoded in Bicep (PBI 3374194) | Acknowledged |
| 6 | BinSkim version pinned at 4.4.2 (incident 660579650) | Risk of drift |
| 7 | `deployment.yaml` ~400 lines — needs modularization | Tech debt |
| 8 | Single-container enforcement blocks future sidecar patterns | Design constraint |

### 9.3 Missing Network Policies

No evidence of default-deny Kubernetes Network Policies across clusters. Lateral movement risk between pods. CIS benchmark gap.

### 9.4 Workload Identity Migration

System likely using deprecated Azure AD Pod Identity (NMI DaemonSet). Migration to Workload Identity Federation pending.

---

## 10. Architecture Decision Records (Celestial)

| ADR | Title | Status | Key Decision |
|-----|-------|--------|-------------|
| ADR-0005 | MP in main release pipeline | Adopted | MP clusters deployed alongside workload clusters |
| ADR-0006 | Cluster Orchestrator Pattern | Adopted | Each cluster = separate EV2 stamp |
| ADR-0007 | Tag-based releases | Adopted | No branch-based deployments |
| ADR-0009 | SKU standardization | Adopted | Dds_v6 / Dads_v6 families only |
| ADR-0011 | WireServer file proxy | Adopted | Replace direct WireServer access |
| ADR-0012 | Node health lifecycle | Adopted | Multi-layered health with VMSS integration |

---

## 11. Key Repository Map

### Celestial (idk8s) Ecosystem

| Repository | Organization | Purpose |
|-----------|-------------|---------|
| `idk8s-infrastructure` | msazure/One | Main monorepo — MP, CD, AOS, Fleet Manager, Helm, Bicep, EV2 |
| `idk8s-infrastructure-enablement` | msazure/One | `idk8sctl` binaries, Bicep templates, OS images |
| `IDNA-IDCR-Buildout` | — | Celestial buildout templates for tenant onboarding |
| `AD-Platform-LsmJobs` | — | LSM jobs consuming FleetManager SDK NuGet |

### DK8S (Defender Kubernetes) Ecosystem

| Repository | Organization | Purpose |
|-----------|-------------|---------|
| `Infra.K8s.Clusters` | microsoft/WDATP | Cluster inventory, tenant config, rings |
| `Infra.K8s.ArgoCD` | microsoft/WDATP | ArgoCD installation, app-of-apps |
| `Wcd.Infra.ConfigurationGeneration` | microsoft/WDATP | ConfigGen tool (manifest expansion) |
| `WDATP.Infra.System.Cluster` | microsoft/WDATP | EV2 templates for cluster creation |
| `WDATP.Infra.System.ClusterProvisioning` | microsoft/WDATP | Provisioning pipelines |
| `WDATP.Infra.System.PipelineTemplates` | microsoft/WDATP | Shared ADO pipeline templates |
| `WDATP.Infra.System.SharedHelmCharts` | microsoft/WDATP | Base Helm charts |
| `Infra.K8s.BasePlatformRP` | — | ARM Resource Provider (future K8s integration) |

### Plugin/Documentation Repos (local)

| Repository | Location | Content |
|-----------|----------|---------|
| `Dk8sCodingAI-1` | `C:\Users\tamirdresher\source\repos\Dk8sCodingAI-1` | DK8S plugin hub — 12 infrastructure skills, agent instructions, pattern docs |
| `Dk8sCodingAIgithub` | `C:\Users\tamirdresher\source\repos\Dk8sCodingAIgithub` | Claude Code plugin marketplace — 15 DK8S skills |

---

## 12. NuGet Packages (Celestial)

| Package | Feed | Purpose |
|---------|------|---------|
| `Microsoft.Entra.Platform.Celestial.CLI` | IDNA-Secure-Packaging | Developer CLI tool |
| `Microsoft.Entra.Platform.FleetManager.ResourceProvider` | IDNA-Secure-Packaging | Fleet Manager SDK |
| `Microsoft.Entra.Platform.FleetManager.Library` | IDNA-Secure-Packaging | Shared library |
| `Microsoft.Entra.Platform.DsmsBootstrapNodeService` | IDNA-Secure-Packaging | dSMS bootstrap |
| `Microsoft.Entra.Platform.DsmsNativeBootstrapper` | IDNA-Secure-Packaging | dSMS native cert management |
| `debug-container` | IDNA-Secure-Packaging | Diagnostics module |

---

*"Every EPS conduit traced, every plasma relay mapped. This is the full infrastructure picture — two platforms, 45+ components, 7 clouds."* — B'Elanna Torres
