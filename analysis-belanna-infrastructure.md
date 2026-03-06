# 🔧 B'Elanna Torres — Infrastructure Deep Dive: idk8s-infrastructure

**Analyst**: B'Elanna Torres, Infrastructure Expert  
**Repo**: `msazure/One/idk8s-infrastructure` (Microsoft Identity Kubernetes Platform / Celestial)  
**Date**: Analysis based on current `main` branch

---

## Table of Contents
1. [Helm Chart Architecture](#1-helm-chart-architecture)
2. [IaC / Bicep Analysis](#2-iac--bicep-analysis)
3. [EV2 Deployment Model](#3-ev2-deployment-model)
4. [Multi-Cloud Container Replication](#4-multi-cloud-container-replication)
5. [Component Manifest Analysis](#5-component-manifest-analysis)
6. [Container Build Pipeline](#6-container-build-pipeline)
7. [Docker Images](#7-docker-images)
8. [Pipeline Architecture](#8-pipeline-architecture)
9. [Infrastructure Gaps & Recommendations](#9-infrastructure-gaps--recommendations)

---

## 1. Helm Chart Architecture

### 1.1 Celestial Chart (Primary Workload Chart)

**Location**: `/src/helm/charts/celestial/`  
**Chart Type**: Application (v2 API, version 1.0.0)

The Celestial chart is the **shared deployment chart for all services running on the Celestial platform**. It is NOT a specific service chart — it's a platform-level template that Fleet Manager renders per-service at deployment time.

#### Templates Inventory

| Template | Purpose |
|----------|---------|
| `_helpers.tpl` | Name generators, labels, security context, cloud-to-Geneva mapping, cluster version detection |
| `deployment.yaml` | **Core template** — multi-container Deployment with Geneva sidecars, dSMS support, init containers |
| `service.yaml` | LoadBalancer Service (only for `external` type with service tag annotations) |
| `hpa.yaml` | Standard HPA (autoscaling/v2) for CPU/memory targets |
| `keda.yaml` | KEDA ScaledObject for advanced autoscaling (v3 clusters only) |
| `pdb.yaml` | PodDisruptionBudget with `AlwaysAllow` unhealthy eviction |
| `_autoscale_policies.yaml` | KEDA HPA behavior policies (scaleUp/scaleDown) |
| `_autoscale_profile.yaml` | KEDA trigger profiles (cron, CPU, memory) |

#### Deployment Template Architecture

The `deployment.yaml` is the most complex template (~400 lines). Key architectural patterns:

**Container Structure (per pod)**:
1. **Init Container: `init-geneva-cert`** (platform-managed secrets mode) — Uses Azure CLI to authenticate via workload identity or managed identity, downloads Geneva certificates and SSL certificates from KeyVault, converts to PEM format
2. **Init Container: `dsmsnativebootstrapper`** (dSMS mode) — Runs dSMS native bootstrapper as a sidecar with `restartPolicy: Always` for continuous certificate rotation
3. **Sidecar: `mdsd`** (Geneva Logs) — Configurable size (small/medium/large/xLarge/2xLarge) with graceful shutdown coordination
4. **Sidecar: `mdm`** (Geneva Metrics) — Metrics agent with socket-based IFX input
5. **Application container** — Single app container (multi-container explicitly blocked via fail guard)

**Security Model**:
- **All containers** get identical hardened security context: `runAsNonRoot: true`, `runAsUser: 1000`, `readOnlyRootFilesystem: true`, all capabilities dropped, RuntimeDefault seccomp
- `automountServiceAccountToken: false` for service deployments (true only for KVW)
- Workload identity via `azure.workload.identity/use: "true"` label when not using managed identity

**Multi-Cloud Support** (in `_helpers.tpl`):
The chart supports **8 sovereign clouds** via the `celestial.geneva.cloud` helper:
- `public` → AzurePublicCloud
- `fairfax` → AzureUSGovernmentCloud
- `mooncake` → AzureChinaCloud
- `ussec` → USSec
- `usnat` → USNat
- `bleu` → AzureBleuCloud
- `delos` → AzureDelosCloud

Each cloud requires custom Azure CLI cloud registration commands in the init-geneva-cert container (fully implemented for all 8).

**Cluster Version Detection**:
- `celestial.isClusterV3`: Any cluster type other than `"generic"` is v3
- v3 clusters enable: dSMS, KEDA autoscaling, resilience probes
- v2 ("generic") clusters use the legacy platform-managed secrets path

**Graceful Shutdown Coordination**:
- App container creates `MainAppContainerDied.txt` file in shared volume on termination
- Geneva sidecars poll for this file before starting their flush timers
- `terminationGracePeriodSeconds` = eventsFlushDuration + maxAppTerminationGrace + 60s buffer

**Volume Architecture** (12+ volumes per pod):
- `keyvault-auth-vol` (Memory-backed, 10Mi) — Geneva cert storage
- `ssl-auth-vol` (Memory-backed, 10Mi) — SSL cert storage
- `mdsd-run-vol`, `mdsd-logs`, `mdsd-d`, `mdsd-linuxmonagent` — Geneva logs agent
- `mdm-run-vol` — Geneva metrics agent
- `tmp-*` (multiple) — Temp dirs for each container (readonly root filesystem)
- `ca-certificates` — Host CA cert bundle mount
- `celestial-default` (1Gi) — Service scratch space
- `dsms-secrets` (Memory-backed, 5Mi) — dSMS secrets (v3 only)
- `dsmsbootstrapper-*` — dSMS bootstrapper working dirs (v3 only)

#### Values Architecture

**`values.yaml`** (production defaults):
```yaml
deployment:
  loadBalancer.type: "none"          # No public IP by default
  minAvailableReplicas: 75%          # PDB minimum
  replicas: 4                         # Default replica count
  autoscaling.enabled: false
  replicaDistributionStrategy:
    acrossZones.enabled: true         # Zone-spread topology constraints

secrets:
  enableDsms: false                   # Platform-managed secrets by default

geneva:
  sidecarSize: "small"               # Configurable: small/medium/large/xLarge/2xLarge
  eventsFlushDurationSeconds: 300    # 5-minute flush window

resilienceProbe:
  enabled: false                      # v3 cluster feature
```

**`values-template.yaml`** — Onboarding template for new services. Documents all configurable fields including:
- Container definitions with `imageName`, `resourceLimits`, `startupProbe`
- KeyVaultWatcher configuration
- Environment variable injection
- Volume mount paths

**Platform-injected values** (set by Fleet Manager at deployment time):
```yaml
celestial:
  name: <AppName>
  region: <Region>
  helmChartVersion: "1.0"
  cloud: <CloudName>
  cluster:
    name: <ClusterName>
    type: <ClusterType>  # generic, gateway, dpx, management_plane
  workloadAuth:
    useManagedIdentity: false
    clientId: "<ClientId>"
  geneva:
    certKeyVaultUrl: <KV URL>
    certName: <CertName>
  sslCertName: <SSLCertName>
  IMAGE_<name>: "<Full Image URL>"
  mdsdImage: <MDSD sidecar image>
  mdmImage: <MDM sidecar image>
  azureCliImage: <Azure CLI image>
  dsmsNativeBootstrapperImage: <dSMS image>
```

### 1.2 KeyVaultWatcher Chart

**Location**: `/src/helm/charts/keyvaultwatcher/`  
**Purpose**: Sidecar deployment for zero-touch secret rotation

**Architecture**:
- Deploys as a **separate Deployment** (not a sidecar) in the same namespace
- Single container running KVW agent with configmap-based configuration
- Watches specified KeyVaults for secret/certificate changes
- Triggers rolling restart of the main service Deployment on secret rotation
- Hardened security context (identical to main chart)
- Uses workload identity for KeyVault access
- Fixed resource limits: 100m CPU, 300Mi memory

**ConfigMap structure**:
```json
{
  "KeyVaultsToWatch": [{
    "KeyVaultUrl": "<url>",
    "SecretsToWatch": [{
      "Name": "<name>",
      "Type": "Certificate|secret",
      "DeploymentsToRestart": [{
        "Namespace": "<ns>",
        "Type": "Deployment",
        "Name": "<deployment-name>"
      }]
    }]
  }],
  "IntervalSeconds": 300,
  "Metrics": { "MdmNamespace": "<namespace>" }
}
```

### 1.3 Management Plane Helm Values (Per-Region)

**Location**: `/src/helm/values/managementplane/`

**Base values** (`values.yaml`):
```yaml
deployment:
  loadBalancer.type: "external"
  ingressServiceTag: "/AzureIdentityNonProd/Others"
  replicas: 2
  minAvailableReplicas: 50%
  containers:
    managementplane-container:
      imageName: "managementplane"
      resourceLimits: { cpuInCores: 0.4, memoryInMB: 300 }
      startupProbe: { enabled: true, probeType: "httpGet", scheme: "https", endpoint: "/healthz", port: 8080 }
      volumeMountPath: "/tmp"
geneva:
  sidecarSize: "small"
  logs: { environment: "DiagnosticsPROD", account: "IDK8sDEV", namespace: "IDK8sLinuxMP", configVersion: "1.0" }
  metrics: { account: "IDK8sDEV", namespace: "IDK8sLinuxMP" }
  eventsFlushDurationSeconds: 30  # Reduced from default 300 for MP
```

**Per-environment overrides** (thin layer pattern):

| File | Key Overrides |
|------|--------------|
| `values-IDK8SMP-DEV-EASTUS2.yaml` | `Mode: generic`, `Environment: dev`, `UseUserAuth: true` |
| `values-IDK8SMP-DEV-EASTUS2-CLI.yaml` | `Mode: cli`, `Environment: dev` |
| `values-IDK8SMP-SANDBOX-EASTUS2-CLI.yaml` | `Mode: cli`, `Environment: sandbox` |
| `values-IDK8SMP-DEV-EASTUS2-INTEGRATIONTESTS.yaml` | Integration test configuration |
| `values-IDK8SMP-DEV-EASTUS2-INTEGRATIONTESTS-CLI.yaml` | CLI integration test configuration |

**Pattern**: Base values define the full configuration; per-environment files override only env-specific settings (environment name, mode, auth settings). This is a clean **thin overlay** approach.

---

## 2. IaC / Bicep Analysis

### 2.1 Global Resources (`/src/bicep/glob/`)

**Main file**: `global-resources-main.bicep`  
**Environments**: `dev`, `test`, `prod` (parameter-controlled)

#### Resources Provisioned

| Resource | Description | Environment Notes |
|----------|-------------|-------------------|
| **Global ACR** (`idk8sacr{env}`) | Premium SKU, zone-redundant, no admin user, no anonymous pull | Delete-locked in test/prod |
| **Staging ACR** (`idk8sacr{env}stage`) | Staging registry for prod promotion | Prod only |
| **MISE Cache Rule** | ACR cache rule for `mcr.microsoft.com/msftonly/mise/mise-1p-container-image` | Filters to linux tags only |
| **ACR Purge Task** | Daily purge of untagged images >90 days old (keep 3) | Dev only (PR build pressure) |
| **User Worker Node MSI** | Regional managed identity for worker node VMSS | All envs, delete-locked in test/prod |
| **ADO ACR Identity** | MSI for pipeline ACR push operations | Test/prod only |
| **Staging ACR ADO Identity** | MSI for staging ACR push | Prod only |
| **Global Key Vault** (`idk8s{env}globalkv`) | Standard SKU, RBAC-authorized, soft-delete enabled | Delete-locked |
| **KV Identity** | MSI with KV Administrator role for certificate operations | All envs |
| **KV Issuer** | Deployment script to configure OneCert issuer in KV | All envs |
| **Geneva SC Cert** | Geneva Source Control EV2 certificate (`OneCertV2-PrivateCA`) | Test/prod only |
| **OIDC Storage Account** | Storage for OIDC configuration | Dev only |
| **Log Analytics Workspace** | `PerGB2018` SKU, 30-day retention, 1GB daily cap | All envs |
| **Action Group** | Azure Monitor action group for alerting | All envs |
| **Compute Galleries** | Image galleries for ARCO (Azure Recommended Configuration Orchestration) | Prod: 6 galleries (`gal.prod` + ring0-ring4), dev/test: 1 |
| **Global Storage Account** | For EV2 infra test results (file share: `ev2-infratest-junits`) | Dev/test only |
| **Inventory Storage Account** | Centralized release/rollout state tracking (table storage) | All envs |
| **Maintenance Configuration** | VMSS OS Image daily + host monthly maintenance windows | Per-region timezones |

#### RBAC Assignments

| Principal | Role | Scope |
|-----------|------|-------|
| OneBranch ACR Access App | ACR Push | Global ACR |
| LSM High-Privilege App | ACR Pull | Global ACR (test/prod) |
| LSM TCB High-Privilege App | ACR Pull | Global ACR (test/prod) |
| ADO ACR Identity | ACR Push | Global ACR (test/prod) |
| EV2 Test Connection | KV Secrets User | Global KV (dev/test) |
| Approver Security Group | KV Secrets User | Global KV |
| Bootstrapper MSI | Storage Table Data Contributor | Inventory SA |

#### ARCO (Azure Recommended Configuration Orchestration)

ARCO objects manage VM image updates across the cluster fleet:
- **Image definitions**: `azl3-1.32.10-gen` (Linux) and `windows-1.32.10-gen` (Windows)
- **Ring model**: Dev = no ARCO, Test = 2 objects ('' and '-test'), Prod = 4 rings (`-prod1` through `-prod4`)
- **Upgrade policy**: PlatformOrchestratedForNewAndExistingResources, 80% tier completion threshold, max 5 concurrent per region

#### Maintenance Configuration

Region-aware maintenance windows:
- **OS Image Daily**: 8-hour window, every day at 22:00 local time
- **Host Monthly**: 4-hour window, last Saturday of each month
- **Regions covered**: swedencentral, eastus, eastus2, eastus2euap, centralus, northcentralus

#### Parameter Files

- `parameters/generic/dev/global-resources-params.json` — Empty (dev uses defaults)
- `parameters/generic/prod/global-resources-params.json` — Standard ARM parameter format with `oneBranchAcrAccessAppObjectId` override

### 2.2 Bicep Module Summary

| Module | Purpose |
|--------|---------|
| `modules/action_group.bicep` | Azure Monitor action group (global location) |
| `modules/log_analytics_workspace.bicep` | Log Analytics workspace (PerGB2018) |
| `modules/maintenance_configuration.bicep` | VMSS maintenance windows per region/timezone |
| `modules/storage_account.bicep` | GRS storage account with TLS1.2, soft-delete |
| `modules/arco/arco.bicep` | ARCO service artifact with SDP upgrade policies |
| `modules/arco/arco_deployment.bicep` | ARCO deployment for Linux+Windows images per ring |
| `modules/gallery/compute_gallery.bicep` | Azure Compute Gallery resource |
| `modules/gallery/gallery_deployment.bicep` | Subscription-scoped gallery + RG deployment |
| `modules/cert/cert.bicep` | Deployment script for OneCert certificate creation in KV |
| `modules/kv-issuer/kv-issuer.bicep` | Deployment script for KV certificate issuer setup |
| `modules/avm/key-vault/vault/` | AVM (Azure Verified Modules) Key Vault with access policies, keys, secrets |

---

## 3. EV2 Deployment Model

### 3.1 Deployment Tracks Overview

The repo defines **5 distinct EV2 deployment tracks**:

| Track | Location | Purpose | Environment |
|-------|----------|---------|-------------|
| **clusters-sdp** | `/ev2/clusters-sdp/` | Production cluster lifecycle (SDP-governed) | dev/test/prod |
| **clusters-pre-release** | `/ev2/clusters-pre-release/` | Build qualification testing | test |
| **clusters-non-sdp** | `/ev2/clusters-non-sdp/` | Special-purpose clusters outside SDP | dev/test |
| **management-plane** | `/ev2/management-plane/` | Management plane bootstrapping | dev/sandbox |
| **replication** | `/ev2/replication/` | Container image replication to all clouds | all |

Plus ancillary tracks:
- `/ev2/scaleunitapi-tests/` — Scale unit API test execution
- `/ev2/skylarc-appconfig/` — Skylarc AppConfig deployment

### 3.2 SDP Cluster Deployment (`clusters-sdp`)

**27 cluster configs** across 3 environments:

| Environment | Clusters |
|-------------|----------|
| **dev** | 1 global config (`eastus2`, subscription `4ae88fd2...`) |
| **test** | 1 global + 4 clusters (eastus2-001, eastus2-mp001, swedencentral-001/009/mp001) |
| **prod** | 1 global + 21 clusters across centralus, eastus, northcentralus |

**Cluster Types** (from configs):
- `gen` — Generic workload clusters
- `gateway` — Gateway clusters (external-facing with service tags)
- `management_plane` — Management plane clusters (MP network access controls)
- `dpx` — DPX clusters

**Production Cluster Inventory**:

| Region | Workers | MP | Total |
|--------|---------|-----|-------|
| centralus | 001-005 | mp001 | 6 |
| eastus | 001 | mp001 | 2 |
| northcentralus | 000-008 | mp001 | 10 |
| **Total** | | | **18** |

**Cluster Config Schema** (example: `prod.centralus-001.yml`):
```yaml
name: '001'
kind: gateway
region: centralus
subscription_id: <subscription>
bicep:
  linuxUserVmSku: Standard_D32s_v4
  linuxVmSku: Standard_D16s_v4
  controlPlaneVmSku: Standard_D16s_v4
  controlPlaneInstanceCount: 5
  egressPublicIPv4PrefixLength: 30
  egressPublicIPv6PrefixLength: 126
  features:
    customImageGallery: { name: "gal.prod.ring1", subscriptionId: "..." }
    useNodeHealthAgentForAHE: true
    enableDsmsSop: true
    vmssMaintenance: { enabled: true }
components:
  stageXX:
    - pod-health-check-service
    - remediation-controller
    - wireserver-file-proxy
```

**SDP Ring Rollout** (from `Cluster.SDP.yml`):

The SDP pipeline implements a **5-ring production rollout** with manual approval gates:

| Ring | Clusters | Gate |
|------|----------|------|
| PPE | swedencentral-mp001, swedencentral-001, swedencentral-009 | (parallel) |
| R0 (canary) | northcentralus-000, eastus-mp001, eastus-001, northcentralus-008 | Manual approval |
| R1 | centralus-001/002, northcentralus-001/002 | Manual approval |
| R2 | centralus-mp001/003, northcentralus-mp001/003/004/005/006/007 | Manual approval |
| R3 | centralus-004 | Manual approval |
| R4 | centralus-005 | Manual approval |

Each stage uses `Cluster.Bootstrap-AsStage.yml` which:
1. Optionally deletes cluster (disruptive release mode with manual approval after delete)
2. Creates/updates cluster via EV2 shell extension
3. Supports `Default` or `ComponentDeployer` rollout spec types

### 3.3 Pre-Release Cluster Deployment

**Single cluster**: `test.centralus-001` (gateway type)  
**Purpose**: Build Qualification — kept as close to PROD as possible but with smaller VM sizes

Key differences from prod:
- Uses `Standard_D4ds_v6` instead of `Standard_D32s_v4`
- No IP tags (non-prod service tags lack zonal capacity)
- Feature flags for testing: `deployNodeIdentityCertificates: true`, `deployDmsiOnWinNodes: false`
- Service model uses `adm-azurelinux-30-l` shell image (vs `adm-ubuntu-2004-l` for MP)

### 3.4 Non-SDP Clusters

**5 special-purpose clusters** outside the SDP governance:

| Config | Purpose |
|--------|---------|
| `dev.swedencentral-mp001` | SU API integration test flow (10-day TTL) |
| `dev.swedencentral-wrk001` | Dev worker cluster |
| `test.eastus2euap-001` | IS testing (EUAP region, full component staging) |
| `test.swedencentral-007/008` | Test clusters in Sweden |

Notable: `test.eastus2euap-001` has the most detailed component staging with explicit stage ordering (stage01-stage05), including foundational identities and LCH (Lifecycle Hooks) testing.

### 3.5 Management Plane EV2

**Service Group**: `idk8s-bootstrap-managementplane`

**6 service resource groups** (RGs):
1. `idk8s-dev-eastus2-mp-ev2` — Dev generic MP
2. `idk8s-dev-eastus2-mp-cli-ev2` — Dev CLI MP
3. `idk8s-dev-eastus2-mp-integrationtests-ev2` — Dev integration tests
4. `idk8s-dev-eastus2-mp-integrationtests-cli-ev2` — Dev CLI integration tests
5. `idk8s-sandbox-eastus2-mp-cli-ev2` — Sandbox CLI
6. `idk8s-pub-eus2-dev` — VMSS-based MP (newer platform)

**Scope binding architecture**: Three-layer scope tags:
- **Environment layer**: `dev`/`sandbox` — Sets env, tenant, region, ACR
- **Cluster layer**: `v2cluster`/`vmsscluster` — Sets subscription, MSI, cluster details, helm chart paths
- **Scale unit layer**: `generic`/`cli`/`integrationtests-*`/`vmss` — Sets scale unit name

**Shell Extension**: Executes `management-plane.sh` bootstrapper with 60-minute timeout, using user-assigned MSI in a VNet-connected EV2 container (`adm-ubuntu-2004-l:v6`).

---

## 4. Multi-Cloud Container Replication

### 4.1 Replication Architecture

**10 cloud configurations** for container image replication:

| Cloud | Azure Environment | ACR Name | Stamps | Tenant |
|-------|-------------------|----------|--------|--------|
| **Dev** | AzureCloud | `idk8sacrdev` | 1 | Microsoft Corp (72f988bf) |
| **NonOfficialDev** | AzureCloud | `idk8sacrdev` | 1 | Microsoft Corp (isOfficialBuild=false) |
| **Test** | AzureCloud | `idk8sacrtest` | 1 | AME (33e01921) |
| **Production** | AzureCloud | `idk8sacrppe` + `iamkubernetesppe` + `iamkubernetesprod` + `idk8sacrprod` | **4** | AME (33e01921) |
| **Fairfax** | AzureUSGovernment | `iamkubernetesff` | 1 | Fairfax (cab8a31a) |
| **Mooncake** | AzureChinaCloud | `iamkubernetesmc` | 1 | Mooncake (a55a4d5b) |
| **USNat** | USNat | `iamkubernetesexusnatwest` | 1 | USNat (70a90262) |
| **USSec** | USSec | `iamkubernetesrx` | 1 | USSec (20ac2fc4) |
| **Bleu** | Bleu | `iamkubernetesbc` | 1 | Bleu (e4c3160c) |
| **Delos** | Delos | `iamkubernetesde` | 1 | Delos (eee66108) |

### 4.2 Production Multi-Stamp Pattern

Production is unique with **4 ACR stamps** (all others have 1):
1. `idk8sacrppe` — PPE ACR (subscription `96d65208`)
2. `iamkubernetesppe` — PPE legacy ACR (subscription `18cec2bf`)
3. `iamkubernetesprod` — Production ACR (subscription `93f73474`)
4. `idk8sacrprod` — Production v3 ACR (subscription `44ce895f`)

This indicates a **migration in progress** from legacy `iamkubernetes*` naming to `idk8sacr*` naming, with both maintained for backward compatibility.

### 4.3 Replication Pipeline

**Two-step process** (from `RolloutSpec.json`):
1. **ImagesUploadStep** — Uploads container images as tarballs via `run.sh` script
2. **UpdateStableTagStep** — Updates stable tags after successful upload (depends on step 1)

**Shell execution**: Uses `adm-azurelinux-30-l:v2` with user-assigned managed identity per cloud. Image tarballs passed as SAS-protected secure values.

**Production also deploys test apps** to 3 scale units:
- `IDK8SLINUXAPP-PUB-WCU-001` (West Central US)
- `IDK8SLINUXAPP-PUB-CUS-008` (Central US)
- `IDK8SWINAPP-PUB-NCUS-001` (North Central US, Windows)

---

## 5. Component Manifest Analysis

### 5.1 Three Manifest Types

**Location**: `/src/manifests/`

All manifests share the same structure but differ in deployed components:

| Manifest | Kind | Components |
|----------|------|------------|
| `generic-manifest.yml` | `generic` | Base set: 7 components |
| `gateway-manifest.yml` | `gateway` | Base + wireserver-file-proxy: 8 components |
| `dpx-manifest.yml` | `dpx` | Base + skylarc-agent: 8 components |

### 5.2 Component Dependency Chain

All manifests follow the same two-phase foundation:

```
cluster-bicep-model (idk8sctlbicep)
    └── core-cluster-components (idk8sctlconfigure)
            ├── node-health-agent (IS)
            ├── node-repair-service (IS)
            ├── descheduler (IS)
            ├── node-problem-detector (IS)
            ├── keda (WS)
            ├── pod-health-check-service (WS)
            ├── remediation-controller (WS)
            ├── wireserver-file-proxy (WS) [gateway only]
            └── skylarc-agent (WE) [dpx only]
```

### 5.3 Component Kind Types

| Kind | Description |
|------|-------------|
| `idk8sctlbicep` | Bicep infrastructure deployment via idk8sctl create |
| `idk8sctlconfigure` | Core Helm components via idk8sctl configure |
| `idk8sctlconfigurecomponent` | Individual Helm component via idk8sctl |

### 5.4 Team Ownership

| Team | Components |
|------|------------|
| **IE** (Infrastructure Engineering) | cluster-bicep-model, core-cluster-components |
| **IS** (Infrastructure Services) | node-health-agent, node-repair-service, descheduler, node-problem-detector |
| **WS** (Workload Services) | pod-health-check-service, remediation-controller, keda, wireserver-file-proxy |
| **WE** (Workload Engineering) | skylarc-agent |

---

## 6. Container Build Pipeline

### 6.1 Built Container Images

From `OneBranch.Variables.yml`, the full image inventory:

**Linux (.NET)**:
| Image | Source |
|-------|--------|
| `dsms-cert-injection-service-linux` | DsmsBootstrapNodeService |
| `nha-linux` | NodeHealthAgent |
| `nrs` | NodeRepairService |
| `dsmsnativebootstrapper` | DsmsNativeBootstrapper |
| `remediation-controller-linux` | RemediationController |
| `wireserver-file-proxy-linux` | WireServerFileProxy |
| `pod-health-check-service-linux` | PodHealthCheckService |
| `npd-linux` | node-problem-detector (Dockerfile) |
| `debug` | diagnostics debug container |

**Linux (Go)**:
| Image | Source |
|-------|--------|
| `pod-health-api-controller-linux` | Go-based pod health API controller |

**Windows**:
| Image | Source |
|-------|--------|
| `nha-windows` | NodeHealthAgent |
| `dsms-cert-injection-service-windows` | DsmsBootstrapNodeService |
| `pod-health-check-service-windows` | PodHealthCheckService |
| `npd-windows` | node-problem-detector (Dockerfile) |
| `skylarc-agent-windows` | Skylarc agent (custom Dockerfile) |
| `debug-windows` | diagnostics debug container |

### 6.2 ACR Registry Matrix

| Registry | Domain | Purpose |
|----------|--------|---------|
| `idk8sacrdev` | idk8sacrdev.azurecr.io | Dev builds |
| `idk8sacrppe` | idk8sacrppe.azurecr.io | PPE |
| `idk8sacrtest` | idk8sacrtest.azurecr.io | Test |
| `idk8sacrprod` | idk8sacrprod.azurecr.io | Production v3 |
| `iamkubernetesppe` | iamkubernetesppe.azurecr.io | PPE legacy |
| `iamkubernetesprod` | iamkubernetesprod.azurecr.io | Production legacy |
| `skylarcagentacr` | skylarcagentacr.azurecr.io | Skylarc agent base |

### 6.3 NuGet Packages Published

Pushed to IDNA-Secure-Packaging feed:
- `Microsoft.Entra.Platform.Celestial.CLI`
- `Microsoft.Entra.Platform.FleetManager.ResourceProvider`
- `Microsoft.Entra.Platform.FleetManager.Library`
- `Microsoft.Entra.Platform.DsmsBootstrapNodeService`
- `Microsoft.Entra.Platform.DsmsNativeBootstrapper`
- `debug-container` (diagnostics module)

---

## 7. Docker Images

### 7.1 Node Problem Detector

**Linux** (`docker/node-problem-detector/linux/Dockerfile`):
```dockerfile
FROM mcr.microsoft.com/oss/v2/kubernetes/node-problem-detector:v0.8.21-2 AS source
FROM mcr.microsoft.com/azurelinux/base/core:3.0.20260204
COPY --from=source /usr/bin/node-problem-detector /usr/bin/
COPY --from=source /usr/bin/npd-health-checker /usr/bin/
```

**Windows** (`docker/node-problem-detector/windows/Dockerfile`):
```dockerfile
FROM mcr.microsoft.com/oss/v2/kubernetes/node-problem-detector:v0.8.21-2 AS source
FROM mcr.microsoft.com/windows/servercore:ltsc2022
COPY --from=source C:\Windows\System32\node-problem-detector.exe C:\Windows\System32\
COPY --from=source C:\Windows\System32\npd-health-checker.exe C:\Windows\System32\
```

Both use multi-stage builds to extract binaries from the upstream image and rebase onto compliant base images (Azure Linux 3.0 / Windows Server Core LTSC 2022).

### 7.2 Skylarc Agent (Windows)

```dockerfile
FROM skylarcagentacr.azurecr.io/skylarc-agent:1.0.4
COPY DsmsNativeBootstrapper/release/ /DsmsNativeBootstrapper/
COPY start.ps1 .
COPY run_geneva_ma_k8s.ps1 /Monitoring/Agent/
ENTRYPOINT ["powershell", "-File", ".\\start.ps1"]
```

**Startup sequence** (`start.ps1`):
1. Run dSMS Native Bootstrapper (if DSMS_Enable != "false") — installs certificates
2. Start Monitoring Agent (Geneva MA) as background process
3. Start Skylarc Agent as foreground process
4. Code signature verification for troubleshooting WDAC/Device Guard

---

## 8. Pipeline Architecture

### 8.1 OneBranch Pipeline Template

**Core template**: `.pipelines/templates/OneBranch.Template.yml`

**Build stages**:
1. **linux_build** — Bash lint, EV2 build version publishing, .NET SDK setup, DevSkim static analysis, helm validation, Linux Docker image builds, Go Docker image builds
2. **windows_build** — .NET build/test/publish, Windows Docker image builds, NuGet package publishing, test app builds
3. **push_packages_to_IDNA_secure_feed** — NuGet promotion (official builds)
4. **push_diagnostics_to_IDNA_secure_feed** — Diagnostics module promotion
5. **validateAdrs** — ADR validation (PR builds to main only)

**SDL Configuration**:
- CodeQL 3000 with TSA bug filing
- PoliCheck (break on issues)
- PSScriptAnalyzer (break on issues)
- BinSkim v4.4.2 (pinned to avoid OB config issue)
- Component Governance (failOnAlert: High)
- CloudVault integration (stage-based upload)
- ESRP signing (Linux)

**Build infrastructure**:
- Linux: `mcr.microsoft.com/onebranch/azurelinux/build:3.0`
- Windows: `onebranch.azurecr.io/windows/ltsc2022/vse2022:latest`
- Network: KS1 (for GitHub/NuGet endpoint access)
- Go version: 1.25.1, Mage version: 1.15.0

### 8.2 Key Pipeline Files

| Pipeline | Trigger | Purpose |
|----------|---------|---------|
| `OneBranch.Official.yml` | `main` push | Official build + NuGet publish |
| `OneBranch.PullRequest.yml` | PR trigger | PR validation + mutation testing + helm validation |
| `OneBranch.Cluster.Release.Official.yml` | Manual | SDP cluster deployment |
| `OneBranch.ContainerImagesBuildReplicate.Official.yml` | Manual | Container image replication |
| `OneBranch.GlobalResources.Official.yml` | Manual | Bicep global resource deployment |
| `Release.FleetManager.Official.yml` | Manual | Fleet Manager release with EV2 ManagedSDP |
| `Release.ManagementPlane.Official.yml` | Manual | Management plane deployment |

### 8.3 Helm Chart Push Pipeline

`CopyHelmChartFilesAndPush-AsStage.yml` implements a **3-stage promotion**:
1. DEV → Push to `idk8sacrdev`
2. PPE → Push to `iamkubernetesppe` (parallel with DEV)
3. PROD → Push to `iamkubernetesprod` (depends on PPE)
4. Non-public clouds → Replicate from PROD artifact

---

## 9. Infrastructure Gaps & Recommendations

### 9.1 Critical Findings

| # | Category | Finding | Severity |
|---|----------|---------|----------|
| 1 | **Helm** | Single-container enforcement — `deployment.yaml` explicitly fails on >1 container. This blocks sidecar patterns that services may need beyond Geneva | Medium |
| 2 | **Helm** | Geneva init container uses inline bash for all 8 clouds' `az cloud register` commands (~80 lines). This is fragile and hard to test | Medium |
| 3 | **Bicep** | Maintenance configuration module has timezone/region data **hardcoded in the Bicep module** itself rather than in parameter files. Comment acknowledges this is "clearly wrong" pending PBI 3374194 | Medium |
| 4 | **Bicep** | Dev parameter file is **empty** — all dev-specific config is baked into Bicep conditionals rather than externalized | Low |
| 5 | **EV2** | Management Plane uses `adm-ubuntu-2004-l:v6` (Ubuntu 20.04) while pre-release clusters use `adm-azurelinux-30-l:v1` — inconsistent base images | Medium |
| 6 | **Docker** | Skylarc agent `start.ps1` has a commented-out `exit $ExitCode` in FailAndExit — errors are logged but won't terminate the container, potentially masking failures | High |
| 7 | **Replication** | Production has 4 ACR stamps while all sovereign clouds have 1. The legacy `iamkubernetes*` and new `idk8sacr*` naming coexistence suggests an incomplete migration | Low |
| 8 | **Pipeline** | BinSkim version is pinned (`4.4.2`) with a comment referencing incident 660579650 — this may drift from OneBranch defaults over time | Low |
| 9 | **SDP** | 5-ring rollout has very manual approval gates — R2 deploys 8 clusters at once after approval, which is a large blast radius | Medium |
| 10 | **Helm** | KVW chart reuses `celestial.name` and `celestial.deploymentName` helpers — tightly coupled to the main chart's naming | Low |

### 9.2 Architecture Recommendations

1. **Template Modularization**: The `deployment.yaml` template at ~400 lines should be split into sub-templates for init containers, Geneva sidecars, and app containers. This would improve testability and allow selective rendering.

2. **Cloud Configuration Externalization**: Move the `az cloud register` commands from inline bash to a configmap or script mounted from a dedicated cloud-config source. Each cloud's endpoint configuration should be data-driven, not code-driven.

3. **Maintenance Config Extraction**: Complete PBI 3374194 to move timezone/region mappings out of the Bicep module into parameter files. This is currently a deployment risk — adding a new region requires a code change.

4. **ACR Naming Consolidation**: Complete the migration from `iamkubernetes*` to `idk8sacr*` naming convention. The dual naming creates confusion and doubles the RBAC configuration needed.

5. **Skylarc FailAndExit**: Uncomment the `exit $ExitCode` line in `start.ps1`. Silently continuing after bootstrapper or monitoring agent failures means the pod runs in a degraded state without Kubernetes awareness.

6. **SDP Ring Granularity**: Consider splitting R2 (8 clusters) into two sub-rings to reduce blast radius. Currently, a bad deployment could impact all MP and worker clusters in the R2 batch simultaneously.

7. **Helm Validation**: The `validationTests` chart exists but is only run conditionally (`runValidationForSharedHelm` parameter, only in PR builds). Consider making this mandatory for all builds.

8. **dSMS Migration Path**: The chart supports both platform-managed secrets and dSMS, but dSMS is only available on v3 clusters. Document a clear migration timeline for v2→v3 to avoid maintaining dual secret management indefinitely.

### 9.3 Strengths

- **Comprehensive multi-cloud support**: 8 sovereign clouds fully implemented with per-cloud configuration
- **Strong security posture**: Hardened security contexts, workload identity, read-only root filesystems, dropped capabilities
- **Well-structured EV2 model**: Clear separation of SDP/pre-release/non-SDP tracks with appropriate governance
- **Clean values overlay pattern**: Thin per-environment overrides on top of comprehensive base values
- **ARCO integration**: Ring-based OS image management with configurable upgrade policies
- **Graceful shutdown coordination**: Sophisticated sidecar lifecycle management ensures log/metric flushing

---

*"I've reconfigured the plasma relays and traced every EPS conduit. This infrastructure is solid but needs some targeted improvements to reach peak efficiency."* — B'Elanna Torres
