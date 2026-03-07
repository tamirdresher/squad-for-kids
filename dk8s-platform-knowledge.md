# DK8S Platform Knowledge Base

> **Consolidated from**: 8 analysis reports, 2 local repos (Dk8sCodingAI-1, Dk8sCodingAIgithub), workspace inventory (dk8s-all-repos.code-workspace)
>
> **Author**: Seven (Research & Docs) — Issue #2
> **Date**: Consolidated July 2025
> **Scope**: Two distinct DK8S platforms documented — Defender K8S (DK8S) and Identity K8S (idk8s/Celestial)

---

## Table of Contents

1. [Platform Overview](#1-platform-overview)
2. [Complete Repository Map](#2-complete-repository-map)
3. [Architecture: idk8s-infrastructure (Celestial)](#3-architecture-idk8s-infrastructure-celestial)
4. [Architecture: Defender K8S (DK8S)](#4-architecture-defender-k8s-dk8s)
5. [Key Components and Relationships](#5-key-components-and-relationships)
6. [Infrastructure Patterns](#6-infrastructure-patterns)
7. [Security Architecture](#7-security-architecture)
8. [CI/CD and Deployment](#8-cicd-and-deployment)
9. [Known Issues and Gaps](#9-known-issues-and-gaps)
10. [Team and Org Structure](#10-team-and-org-structure)
11. [Cross-Repo Analysis: idk8s → BasePlatformRP](#11-cross-repo-analysis-idk8s--baseplatformrp)
12. [Source References](#12-source-references)

---

## 1. Platform Overview

This knowledge base covers **two related but distinct Kubernetes platforms** within Microsoft:

### idk8s-infrastructure (Celestial)
- **Purpose**: Fleet management control plane for Microsoft Entra (Identity) division's AKS clusters
- **Repo**: `msazure/One/idk8s-infrastructure`
- **Owner**: Identity Platform Team (Service Tree ID: `5cee095b-4378-4308-b09d-06b70ae9ff8a`)
- **Scope**: 27 clusters across 7 sovereign clouds, 19 tenants, ~45 projects in monorepo
- **Tech stack**: .NET 8/C# 13, Go 1.25, Helm 3, Bicep, PowerShell, Rego/OPA
- **Evolution**: v1 (IAMK8s manual) → v2 (IAMK8s + LSM) → **v3 (Celestial, current)**

### Defender K8S (DK8S)
- **Purpose**: Enterprise Kubernetes infrastructure platform for Microsoft Defender
- **Repos**: ~50 repos covering cluster provisioning, infrastructure components, observability, security, deployment pipelines, and shared libraries
- **Owner**: Tamir Dresher's team
- **Stack**: Go 1.23+ (operators), Helm 3, YAML (K8s manifests, OneBranch pipelines), ArgoCD (GitOps), EV2, Azure AKS (multi-tenant)

### BasePlatformRP (Cross-Platform Abstraction)
- **Purpose**: ARM Resource Provider abstracting K8s workload deployment across providers (DK8S, Celestial, ACA)
- **Repo**: `Infra.K8s.BasePlatformRP`
- **Stack**: .NET 10, TypeSpec, .NET Aspire 13.1, BaseRP Framework
- **Status**: Early-stage (~10 projects), complementary layer above both platforms

---

## 2. Complete Repository Map

### From workspace: dk8s-all-repos.code-workspace (48 repos)

#### 📚 Documentation (2)
| Repo | Purpose |
|------|---------|
| `defender-developer-docs` | Developer documentation |
| `MPS.Wiki.DefenderK8SPlatform` | Wiki for Defender K8S Platform |

#### 🏗️ Core Infrastructure (9)
| Repo | Purpose |
|------|---------|
| `Infra.K8s.Clusters` | Cluster inventory, tenant definitions, rings |
| `Infra.K8s.ArgoCD` | ArgoCD configuration, app-of-apps |
| `WDATP.Infra.System.Cluster` | EV2 deployment ARM/Go templates |
| `WDATP.Infra.System.ClusterProvisioning` | Cluster provisioning automation |
| `WDATP.Infra.System.Dk8sPlatform` | Platform POC and components |
| `WDATP.Infra.System.Ingress` | Ingress infrastructure |
| `WDATP.Infra.System.Overprovisioning` | Cluster overprovisioning |
| `WDATP.Infra.System.CoreDNS` | CoreDNS configuration |
| `Infra.K8s.Karpenter` | Karpenter node autoscaling |

#### ⚙️ Configuration (2)
| Repo | Purpose |
|------|---------|
| `Wcd.Infra.ConfigurationGeneration` | ConfigGen — expands user manifests per cluster |
| `Infra.K8S.Configurations` | Configuration templates |

#### ⚙️ Deployment (6)
| Repo | Purpose |
|------|---------|
| `WDATP.Infra.System.SharedHelmCharts` | Base/common Helm charts |
| `WDATP.Infra.System.PipelineTemplates` | DK8S-specific build templates |
| `WDATP.Infra.System.ChartOfDk8sApps` | Chart of DK8S applications |
| `WDATP.Infra.System.EV2Deployment` | EV2 deployment templates |
| `Infra.Pipelines.Templates` | OneBranch base pipeline templates (Microsoft standard) |
| `WDATP.Infra.System.ArgoRollouts` | Argo Rollouts for progressive delivery |

#### 🔒 Security (4)
| Repo | Purpose |
|------|---------|
| `WDATP.Infra.System.Kevlar` | Security tooling |
| `WDATP.Infra.KeyvaultAgent` | KeyVault agent |
| `WDATP.Infra.System.AadPodIdentity` | AAD Pod Identity (deprecated, migrating to Workload Identity) |
| `WDATP.Infra.System.SecretSyncController` | Secret synchronization controller |

#### 📊 Observability (5)
| Repo | Purpose |
|------|---------|
| `WDATP.Infra.System.Prometheus` | Prometheus monitoring stack |
| `WDATP.Infra.System.Logging` | Geneva logging (fluentd, mdsd) |
| `defender-infra-logging-operator` | CRD-based logging configuration (Go operator) |
| `WDATP.Infra.GenevaExternalScaler` | KEDA external scaler for Geneva |
| `WDATP.Infra.SupportabilityKusto` | Kusto supportability queries |

#### 🤖 Automation (4)
| Repo | Purpose |
|------|---------|
| `MDATP.Infra.System.IncidentAutomation` | Incident automation |
| `wdatp.infra.system.tools` | Utilities and scripts |
| `Dk8sCodingAI` | AI coding tooling (original) |
| `WDATP.Infra.System.RenovateBot` | Automated dependency updates |

#### 🔧 Node Management (3)
| Repo | Purpose |
|------|---------|
| `MDATP.Infra.System.NodeRemediation` | Node problem detection and remediation |
| `WDATP.Infra.System.VacantNamespaceJob` | Namespace cleanup CronJob |
| `WDATP.Infra.System.Draino` | Node draining automation |

#### 🧪 Testing (2)
| Repo | Purpose |
|------|---------|
| `MDATP.Infra.System.k8sSanityApp` | Platform sanity testing |
| `MDATP.Infra.System.SimpleApp` | Simple test application |

#### 📦 Libraries (14)
| Repo | Purpose |
|------|---------|
| `WDATP.Infra.App.Authentication` | Authentication library |
| `WDATP.Infra.App.AuthenticationProvider` | Authentication provider |
| `WDATP.Infra.App.IntegrationTestsTools` | Integration test tooling |
| `WDATP.Infra.App.Monitoring.Api.Instrumentation` | API instrumentation |
| `WDATP.Infra.App.Monitoring.Audit` | Audit monitoring |
| `WDATP.Infra.App.Monitoring.Instrumentor` | Core instrumentor |
| `WDATP.Infra.App.Monitoring.Instrumentor.EventCounter` | EventCounter instrumentor |
| `WDATP.Infra.App.Monitoring.Instrumentor.Mdm` | MDM instrumentor |
| `WDATP.Infra.App.Monitoring.Instrumentor.OpenTelemetry` | OpenTelemetry instrumentor |
| `WDATP.Infra.App.Monitoring.Logger` | Logging library |
| `WDATP.Infra.App.Monitoring.Metrics.Core` | Core metrics |
| `WDATP.Infra.App.Monitoring.VipTenants` | VIP tenant monitoring |
| `WDATP.Infra.App.Promitor` | Promitor integration |
| `WDATP.Infra.App.SecretProvider` | Secret provider |

#### 🔍 Other (3)
| Repo | Purpose |
|------|---------|
| `WDATP.Infra.EventsReader` | Events reader |
| `dk8s-pipeline-p-model` | Formal verification (P model) |
| `WDATP.AzureServiceMigrationTool` | Azure service migration tool |

#### OCI/Artifact Management (2)
| Repo | Purpose |
|------|---------|
| `WDATP.Infra.ORAS.AcrContentWatcher` | ACR content watcher |
| `WDATP.Infra.ORAS.Agent` | ORAS agent |

---

## 3. Architecture: idk8s-infrastructure (Celestial)

### System Context

```
┌─────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT PIPELINE                       │
│  ADO Build Pipeline → EV2 Safe Deployment Platform          │
│                         │                                    │
│               HTTP Extension calls                           │
│                         ▼                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           MANAGEMENT PLANE (per-region)               │   │
│  │  Scale Unit API ← ResourceProvider SDK (NuGet)        │   │
│  │  ScaleUnit Reconciler → ScaleUnit Scheduler           │   │
│  │  DeploymentUnit Reconciler                            │   │
│  └──────────────────────────────────────────────────────┘   │
│                         │                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │        COMPONENT DEPLOYER (EV2 shell extension)       │   │
│  │  Deploys cluster-level components (infra, platform)   │   │
│  └──────────────────────────────────────────────────────┘   │
│                         │                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │               AOS Components (In-Cluster)             │   │
│  │  NodeHealthAgent │ NodeRepairService │ RemediationCtrl │   │
│  │  PodHealthCheckService │ pod-health-api-controller    │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Core Design Philosophy
Kubernetes-native resource model even outside Kubernetes: entities have `Metadata` (Generation, ResourceVersion), `Spec` (desired state), and `Status` (observed state with ObservedGeneration). Classic reconciliation loops converge actual → desired state.

### Key Subsystems

#### Management Plane
- **Type**: ASP.NET 8 Web API, Windows container, one per region
- **Authentication**: MISE (Entra + dSTS), certificate-based S2S
- **State store**: Kubernetes ConfigMaps (planned migration to CRDs)
- **Namespace**: `Microsoft.Entra.Platform.FleetManager.*`

#### ResourceProvider (FleetManager SDK)
- Reconciliation engine: ScaleUnit + DeploymentUnit reconcilers
- Scheduler: Filter → Score → Select (Kubernetes-scheduler-inspired)
- Per-tenant configuration for 19 tenants
- Distributed as NuGet package

#### Component Deployer
- Manifest-driven DAG-based deployment engine
- EV2 shell extensions with topology-aware filtering
- Three cluster types: DPX, Gateway, Generic

#### AOS (Automated OS)
- NodeHealthAgent: IMDS → Kubernetes node conditions
- NodeRepairService: Taints/untaints based on health
- PodHealthCheckService: Pod-level health monitoring
- RemediationController: Automated remediation

### 19 Registered Tenants

| # | Tenant | Description |
|---|--------|-------------|
| 1 | idk8s | Core Identity K8s platform (linuxapp, mp, winapp) |
| 2 | mciem | Cloud Infrastructure Entitlement Management |
| 3 | eis | Entra Identity Services |
| 4 | kalypso | Kalypso platform |
| 5 | mise | Microsoft Identity Service Essentials |
| 6 | entragw | Entra Gateway |
| 7 | entrarec | Entra Reconciliation |
| 8 | entraghmcp | Entra GH MCP |
| 9 | scim | SCIM protocol service |
| 10 | reporting | Reporting service |
| 11 | appgov | App Governance |
| 12 | agentreg | Agent Registry |
| 13 | dunloe | Dunloe service |
| 14 | dds | Distributed Data Service |
| 15 | gsadp | GSA Data Platform |
| 16 | iamtgov | IAM Tenant Governance |
| 17 | idcache | Identity Cache |
| 18 | esi | Entra Supplemental Intelligence |
| 19 | ztai | Zero Trust AI |

### Architecture Decision Records (12 ADRs)

| ADR | Title | Status |
|-----|-------|--------|
| 0001 | Record Architecture Decisions | Accepted |
| 0002 | IMDS Exception for SEC (Scheduled Events Collector) | Accepted |
| 0003 | Platform-Managed Certificates for Partners | Accepted |
| 0004 | Deployment Process for Cluster Release Candidates | **Superseded** by 0007b |
| 0005 | Management Plane Clusters in Release Pipeline | Accepted |
| 0006 | Cluster Orchestrator — per-cluster EV2 stamps | Accepted |
| 0007a | In-Cluster TLS Certificate Management | Accepted |
| 0007b | Tag-Based Deployment (semantic versioning) | Accepted |
| 0008 | Release Branch Process (on-demand hotfix) | Accepted |
| 0009 | SKU Selection (Dds_v6/Dads_v6 standardization) | Accepted |
| 0010 | VMSS Identity dSMS/dSTS Automation | Accepted |
| 0011 | WireServer File Proxy | Accepted |
| 0012 | Scheduled Event Approval Criteria | Accepted |

### Strategic Roadmap (from MP tech-debt document)
1. SU deployment via MP (LSM substitution)
2. Entra-free SU deployments (dSTS migration, eliminate circular dependency)
3. CRD-based state management (replace ConfigMaps)
4. Cluster RP Operator (on-demand provisioning via `idk8sctl`)
5. N+1 Cluster Upgrade Orchestration
6. Workload Migration Controller (planned, not yet implemented)
7. Management Plane SLOs
8. Per-component versioning

---

## 4. Architecture: Defender K8S (DK8S)

### Two Repository Types

```
┌─────────────────────────────────────────────────────────────┐
│                    DK8S REPOSITORIES                         │
├─────────────────────────────┬───────────────────────────────┤
│     COMPONENT REPOS         │   CLUSTER PROVISIONING REPOS  │
│   (Installed in clusters)   │   (Manage cluster lifecycle)  │
├─────────────────────────────┼───────────────────────────────┤
│ • Helm charts               │ • Cluster inventory           │
│ • ArgoCD applications       │ • ConfigGen tools             │
│ • Go operators              │ • Pipeline templates          │
│ • Infrastructure services   │ • EV2 deployment templates    │
└─────────────────────────────┴───────────────────────────────┘
```

### Dependency Graph

```
Infra.Pipelines.Templates (OneBranch base - Microsoft standard)
        │ extends
WDATP.Infra.System.PipelineTemplates (DK8S-specific build templates)
        │ template reference
   ┌────┴────┐
   ▼         ▼
Component  Provisioning
Repos      Repos
   │         │
   ▼         ▼
ACR: Images + Helm Charts ◄── Infra.K8s.Clusters (inventory)
   │                             │
   │                        ConfigGen expands per cluster
   ▼                             ▼
ArgoCD (app-of-apps) ──► Deploys to clusters
```

### Artifact Flow
1. Component repo build produces container images + Helm charts → ACR
2. EV2 packages artifacts → downloaded by cluster repos
3. ConfigGen processes with cluster inventory → per-cluster manifests
4. ArgoCD syncs generated manifests to clusters

### ConfigGen (Expansion Engine)
Expands generic manifests into cluster-specific configurations:
- `values.yaml` → `helm-prd-ame-eus2-1234-values.yaml` (per cluster)
- `ClustersInventory.json` → `Parameters.AKS.PRD.EUS2.1234.json` (per cluster)

### Coding Standards

#### Helm Chart Structure
```
my-chart/
├── Chart.yaml              # apiVersion: v2 always
├── values.yaml             # Sensible defaults
├── values/                 # Environment-specific overrides
│   ├── helm-dev-values.yaml
│   ├── helm-stg-values.yaml
│   └── helm-prd-{tenant}-{region}-values.yaml
├── templates/
└── README.md
```

#### Values Hierarchy (highest to lowest priority)
1. `helm-{env}-{tenant}-{region}-{cluster}-values.yaml`
2. `helm-{env}-{tenant}-{region}-values.yaml`
3. `helm-{env}-{tenant}-values.yaml`
4. `helm-{env}-values.yaml`
5. `values.yaml` (defaults)

#### Go Operator Structure
Standard kubebuilder layout: `cmd/`, `api/v1alpha1/`, `pkg/controllers/`, `config/`, `Makefile`, `Dockerfile`

---

## 5. Key Components and Relationships

### idk8s Solution Structure (45 projects)

```
FleetManager.slnx (modern .slnx format)
├── 23 Production Projects
│   ├── ManagementPlane (ASP.NET Web, win-x64)
│   ├── ManagementPlane.Library
│   ├── ResourceProvider (FleetManager SDK)
│   ├── ComponentDeployer (ASP.NET Web, self-contained)
│   ├── Library (shared utilities)
│   ├── Inventory / Inventory.AzureTableStorage
│   ├── NodeHealthAgent, NodeRepairService
│   ├── PodHealthCheckService, RemediationController
│   ├── IMDS / IMDSProxy
│   ├── DsmsBootstrapNodeService / DsmsNativeBootstrapper
│   ├── WireServerFileProxy
│   ├── Celestial.CLI, TenantManager.CLI, ComponentDeployer.CLI
│   ├── ManagementPlane.Bootstrapper
│   ├── Celestial.Templates, CelestialConfiguration.SchemaGenerator
│   └── ResourceProvider.Tools
├── 19 Test Projects (xUnit + Moq + AutoFixture + AwesomeAssertions)
├── 3 .NET Aspire Projects (AOS.AppHost, AOS.ServiceDefaults, ResourceProvider.AppHost)
└── Go service (pod-health-api-controller)
```

### Core Dependency Chain
`Library` → `Inventory` → `ResourceProvider` → `ManagementPlane` (bottom-up)

### Cross-Repo Dependencies (idk8s)
| Repo | Relationship |
|------|-------------|
| `idk8s-infrastructure-enablement` | Produces `idk8sctl` binaries, Bicep templates, OS images |
| `ad-FUN-idsr` | Subscription modeling (AC2) |
| `AD-Platform-LsmJobs` | Consumes FleetManager SDK NuGet |
| `IDNA-IDCR-Buildout` | Celestial buildout templates |

---

## 6. Infrastructure Patterns

### Cluster Orchestrator Pattern (ADR-0006)
- Each Kubernetes cluster = separate EV2 stamp
- Leverages EV2's parallelism, retry, and state tracking
- Provides deployment isolation and automatic rollback per cluster

### Scale Unit Scheduler (Filter → Score → Select)
- **TopologyClusterFilter**: Match cloud, env, region, cluster type
- **SpreadScaleUnitsScorer**: Prefer clusters with fewer scale units
- Explicit pinning via configuration supported

### Node Health Lifecycle (ADR-0012)
```
Scheduled Events (IMDS) → NodeHealthAgent → K8s conditions
→ NodeRepairService taints → Pod eviction → Approve event
```
Key: Only approve scheduled events after workload pods drained.

### Multi-Cloud Abstraction
Supports 8 sovereign clouds: Public, Fairfax (Gov), Mooncake (China), USSec, USNat, BLEU, Delos + dev
- Auth: Entra ID (Public) vs. dSTS (Sovereign)
- Secrets: KeyVault (Public) vs. dSMS (Sovereign)

### Helm Chart Architecture (idk8s Celestial Chart)
- Platform-level template rendered per-service by Fleet Manager
- Container structure per pod: init-geneva-cert, dSMS bootstrapper, mdsd sidecar, mdm sidecar, application container
- Hardened security: `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, all capabilities dropped, RuntimeDefault seccomp
- Graceful shutdown via shared file (`MainAppContainerDied.txt`) for sidecar coordination

### EV2 Deployment Model
- 5-ring Safe Deployment Practice (SDP): Test → PPE → Prod (canary) → Prod (region) → Prod (global)
- Tag-based releases (ADR-0007b): semantic versioning `cluster/vX.Y`
- On-demand hotfix branches (ADR-0008)
- 24+ pipeline definitions, 7 release pipelines

### Workload Migration (Current State)
No dedicated migration subsystem exists. Migration achieved by composing primitives:
1. Add new scale unit on target cluster
2. Deploy workload release
3. Shift traffic at DNS/Traffic Manager level
4. Delete old scale unit from source
A Workload Migration Controller is planned but not implemented.

---

## 7. Security Architecture

### Authentication (idk8s)
| Layer | Mechanism | Assessment |
|-------|-----------|------------|
| EV2 → MP | AadApplicationAuthentication (cert → Entra token → MISE) | ✅ Strong |
| MP → Downstream | SN+I cert (ClientCertificateCredential) | ✅ Strong |
| Node → Secrets | DSMS Bootstrap + ACMS (OneCert) + KeyGuard validation | ✅ Strong |
| Dev mode | MockAuthHandler (synthetic claims) | ⚠️ Hardcoded OID risk |

### Container Security
- Distroless images
- All containers: `runAsNonRoot: true`, `runAsUser: 1000`, `readOnlyRootFilesystem: true`
- All capabilities dropped, RuntimeDefault seccomp
- `automountServiceAccountToken: false` for service deployments

### Critical Security Findings (6 total)

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 1 | Manual certificate rotation risk | CRITICAL | Needs cert-manager |
| 2 | Traffic Manager public exposure (no WAF) | CRITICAL | Needs Azure Front Door |
| 3 | Cross-cloud security inconsistency | CRITICAL | Needs baseline + OPA |
| 4 | Dual authentication complexity (Entra + dSTS) | HIGH | Migrate to dSTS-only |
| 5 | No default-deny Network Policies | HIGH | Deploy default-deny |
| 6 | Workload Identity migration (deprecated NMI) | MEDIUM | Migrate to WIF |

### Remediation Timeline
- **Immediate (Q1 2026)**: Automated cert lifecycle, WAF for Traffic Manager
- **Short-term (Q2 2026)**: Cross-cloud security baseline, dSTS-only migration
- **Medium-term (H2 2026)**: Default-deny Network Policies, Workload Identity Federation

---

## 8. CI/CD and Deployment

### idk8s Pipeline Inventory (24+ definitions)

| Category | Count | Examples |
|----------|-------|---------|
| PR Validation | 1 | Full Linux+Windows build, test, mutation testing |
| Official Build | 2 | NuGet publish, ESRP signing, CloudVault upload |
| Container Build | 2 | DEV ACR (buddy), PROD ACR (official) |
| Cluster Release | 4 | SDP-managed, single-cluster, pre-release, delete |
| Management Plane | 4 | Buildout, chart publish, integration tests |
| Integration Tests | 3 | On merge, cleanup, Aspire-based |
| Scheduled | 3 | Sandbox rebuild, non-SDP cluster recycle, Kubescape scan |
| Test Apps | 3 | Build, official, deploy |
| Third-Party | 1 | NuGet publish (Conftest, Helm, Kubectl, etc.) |

### DK8S Pipeline Pattern
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

extends:
  template: v2/OneBranch.Official.CrossPlat.yml@templates
```

### Code Quality Infrastructure
- CodeQL, BinSkim, DevSkim, PSScriptAnalyzer, CredScan
- Regal (Rego linting), Vale, cspell, shellcheck
- MerlinBot reviewer recommender
- Stryker mutation testing (80% diff coverage target)
- Dependabot for dependency updates

### Repository Health (idk8s)
- **Score**: 7.8/10
- **Strengths**: Mature CI/CD, 24+ pipelines, strong tooling, active development (~14 contributors)
- **Gaps**: Boilerplate CONTRIBUTING.md, sparse documentation in some areas

---

## 9. Known Issues and Gaps

### Architecture Gaps
1. **No Workload Migration Controller** — Migration is manual composition of primitives
2. **ConfigMap-based state** — CRDs planned but not implemented
3. **No OBO flow** — Authorization moderate without On-Behalf-Of
4. **No Cluster RP Operator** — Manual cluster creation workflow

### Security Gaps
1. Manual certificate rotation (CRITICAL)
2. No WAF for public Traffic Manager endpoints (CRITICAL)
3. Cross-cloud security inconsistency (CRITICAL)
4. No default-deny Network Policies (HIGH)
5. Deprecated AAD Pod Identity still in use (MEDIUM)

### BasePlatformRP Gaps (22 issues identified)
- No CI/CD pipeline infrastructure (P1)
- Minimal test coverage (P1)
- No security scanning configuration (P0)
- No ADR process (P0)
- No OneBranch setup (P1)
- No EV2 deployment framework (P2)

### Access/Tooling Gaps
- Azure DevOps API access to idk8s-infrastructure blocked during initial analysis (project "One" not found)
- Resolved via Playwright/Edge browser fallback (Decision 6)

---

## 10. Team and Org Structure

### Research Team (This Repo — Star Trek TNG/Voyager)
| Agent | Role | Specialty |
|-------|------|-----------|
| Picard | Lead | Architecture decisions, gap analysis |
| B'Elanna | Infrastructure | Helm, Bicep, EV2, multi-cloud containers |
| Worf | Security | Auth flows, secrets, network, container security |
| Data | Code Expert | Solution structure, dependency graphs, API patterns |
| Seven | Research & Docs | Documentation, presentations, analysis |

### DK8S AI Tooling Team (Dk8sCodingAI — Star Trek DS9/Discovery)
16 agents covering Go, .NET, Helm, pipelines, ArgoCD, security, observability, testing, automation, compliance, Azure internals.

Key agents: Sisko (Lead), O'Brien (.NET), Bashir (Go), Dax (Infrastructure), Odo (Security), Kira (Observability), Saru (Pipelines).

### DK8S AI Skills (15)
| Category | Skills |
|----------|--------|
| Development | argocd-specialist, cluster-config, cluster-validate, git-commit, go-test, helm-developer, helm-validate, new-repo-setup, operator-developer, pipeline-engineer, reviewer, scaffold-component |
| On-Call | oncall-triage, stale-task-closer, waiting-for-user-closer |

---

## 11. Cross-Repo Analysis: idk8s → BasePlatformRP

### Stack Position
- **idk8s**: Management plane (runs inside K8s, manages fleet)
- **BasePlatformRP**: ARM Resource Provider (runs as Azure service, receives ARM requests via RPaaS)

### Complementary Relationship
```
BasePlatformRP (ARM RP abstraction layer)
    │ provisions / manages
    ▼
idk8s-infrastructure (Fleet management control plane)
    │ deploys to
    ▼
AKS Clusters (workloads)
```

### Shared Patterns
Both use MISE authentication, .NET Aspire for local dev, OpenTelemetry, Azure SDK, Managed Resource Groups.

### Key Adoption Recommendations (idk8s → BasePlatformRP)
1. Adopt ADR process (from idk8s 12 ADRs)
2. Implement MockAuthHandler for local dev
3. Add security scanning (DevSkim, CodeQL, BinSkim)
4. Set up OneBranch pipeline infrastructure
5. Adopt Stryker mutation testing
6. Study idk8s MCP server pattern (InfraScaleMCP)

---

## 12. Source References

| Document | Content |
|----------|---------|
| `analysis-picard-architecture.md` | Complete ADR catalog, MP architecture, reconciliation loops |
| `analysis-belanna-infrastructure.md` | Helm charts, Bicep, EV2, container builds, pipelines |
| `analysis-worf-security.md` | Auth flows, secrets management, 14 security findings |
| `analysis-data-code.md` | Solution structure, 23 production projects, API patterns |
| `analysis-seven-repohealth.md` | 24 pipelines, branching strategy, code quality tooling |
| `idk8s-architecture-report.md` | High-level architecture, subsystem breakdown, tenant list |
| `idk8s-infrastructure-complete-guide.md` | Comprehensive 15-section guide covering all aspects |
| `cross-repo-analysis-idk8s-to-baseplatformrp.md` | Comparison matrix, alignment analysis, roadmap |
| `workload-migration-deep-dive.md` | Migration primitives, scheduler, reconciliation |
| `aspire-kind-analysis.md` | Aspire setup comparison across 3 repos |
| `baseplatform-issues.md` | 22 prioritized issues for BasePlatformRP |
| `Dk8sCodingAI-1/docs/repository-architecture.md` | DK8S repo types, dependency graph |
| `Dk8sCodingAI-1/plugins/dk8s-platform/instructions.md` | ConfigGen, pipeline templates, artifact flow |
| `dk8s-all-repos.code-workspace` | Complete 48-repo inventory |
