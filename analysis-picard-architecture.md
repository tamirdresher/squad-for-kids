# 🖖 idk8s-infrastructure Architecture Analysis
## Stardate 2025.07 — Captain Picard's Definitive Report

> *"Things are only impossible until they are not."* — Captain Jean-Luc Picard

---

## Executive Summary

The **idk8s-infrastructure** repository is the operational backbone of **Project Celestial** — Microsoft Identity's Kubernetes platform (v3), the successor to legacy IAMK8s (v2). It houses the Management Plane, Component Deployer, Automated OS (AOS) orchestration, fleet management SDK, and the EV2-based release pipeline infrastructure for deploying identity workloads (DPX, Gateway) across Azure regions.

### Key Architectural Pillars
1. **Management Plane (MP)** — Regional .NET service (Scale Unit API) that orchestrates workload deployments via EV2 HTTP extensions, backed by FleetManager SDK
2. **Component Deployer** — Manifest-driven, DAG-based deployment engine executing via EV2 shell extensions with topology-aware filtering
3. **Cluster Orchestrator** — EV2-native per-cluster deployment model (ADR-0006) replacing region-level orchestration
4. **AOS (Automated OS)** — Three-component node health pipeline (NHA → NPD → NRS) managing scheduled events, node health, and automated remediation
5. **Release Engineering** — Tag-based semantic versioning (ADR-0007) with on-demand hotfix branches (ADR-0008) and multi-pipeline CI/CD

### Platform Scope
- **10 container images** (7 Linux, 3+1 Windows) across dev/test/prod ACRs
- **20+ ADO pipelines** orchestrating build, publish, release, and integration testing
- **3 cluster types**: DPX, Gateway, Generic — each with dedicated manifests
- **Cross-repo dependencies**: `idk8s-infrastructure-enablement`, `ad-FUN-idsr`, `AD-Platform-LsmJobs`, `IDNA-IDCR-Buildout`
- **Multi-tenant**: AME (prod/test) + CORP (dev) with Entra/dSTS authentication

---

## ADR Catalog — Complete Summaries

### ADR-0001: Record Architecture Decisions
| Field | Value |
|-------|-------|
| **Date** | April 19, 2024 |
| **Status** | Accepted |
| **Decision** | Adopt Architecture Decision Records (ADRs) as lightweight documentation for architectural choices, following Michael Nygard's format |
| **Key Points** | ADRs accepted via PR review; superseded ADRs get new ADRs referencing old ones; stored in `docs/adr/`; detailed design docs may be requested for complex decisions |
| **Consequences** | Requires team discipline; supplements but does not replace detailed technical specifications for complex decisions |

### ADR-0002: IMDS Exception for SEC (Scheduled Events Collector)
| Field | Value |
|-------|-------|
| **Date** | March 5, 2025 |
| **Status** | Accepted |
| **Decision** | Develop ScheduledEventsCollector (SEC) that listens to IMDS endpoint for upcoming scheduled events and persists them as Kubernetes node conditions |
| **Context** | VMs in VMSS receive scheduled events via IMDS (Instance Metadata Service) before maintenance operations; SEC needs IMDS access to minimize disruption to workloads |
| **Consequences** | IMDS endpoint access is prohibited by default; a security exception must be filed for SEC to access it |

### ADR-0003: Platform-Managed Certificates for Partners
| Field | Value |
|-------|-------|
| **Date** | February 25, 2025 |
| **Status** | Accepted |
| **Decision** | Celestial platform manages SSL and Geneva certificates for partners (maintaining v2 contract) rather than requiring BYO certificates |
| **Context** | In v2, shared Nginx ingress + Linkerd handled TLS; shared Geneva account handled logging. In v3 (Celestial), dedicated IP per partner, no shared infrastructure |
| **Options Considered** | (1) Platform manages certs in platform-owned KV → **chosen**; (2) Partners bring own certs |
| **Consequences** | Platform must ensure secure cert generation/storage/delivery, implement auto-rotation without partner intervention. May need security team review and potential reversal |

### ADR-0004: Deployment Process for Cluster Release Candidates
| Field | Value |
|-------|-------|
| **Date** | May 29, 2025 |
| **Status** | **Superseded** by ADR-0007b (tag-based process) |
| **Decision** | Build ID-based flow where InfraEnablement team nominates commits, publishes artifacts via pipeline, and release pipeline consumes them by pinned build number |
| **Artifacts** | Bicep templates, components, executables published to `drop_publish_idk8sctl_bundle/` |
| **Weakness** | Every release required a PR to update build number — manual overhead that motivated ADR-0007b |

### ADR-0005: Management Plane Clusters in Release Pipeline
| Field | Value |
|-------|-------|
| **Date** | June 3, 2025 |
| **Status** | Accepted |
| **Decision** | Integrate MP clusters into main release pipeline with parallel deployment alongside workload clusters (Ring 1 & Ring 2) |
| **Options Considered** | (1) Status quo (independent deployment) — rejected for synchronization issues; (2) **Parallel deployment** → chosen; (3) Dedicated rings — rejected for complexity |
| **Context** | MP clusters are regionally scoped (one per region), host SU API for internal operations; separate processes caused drift and operational complexity |

### ADR-0006: Cluster Orchestrator — Cluster vs. Regional Mode
| Field | Value |
|-------|-------|
| **Date** | June 5, 2025 |
| **Status** | Accepted |
| **Decision** | Adopt **Cluster Orchestrator** model where every cluster is a separate EV2 stamp, over Region Orchestrator where EV2 only knows about regions |
| **Key Advantage** | Offloads parallelism, retries, LKG tracking, and visibility to EV2; simpler error handling (single cluster restart/rollback); stable topology snapshots |
| **Trade-off** | EV2 config must be updated when clusters are added/removed (manageable in source control alongside CelestialClusters.json) |
| **Reversibility** | Can migrate to Region Orchestrator later without discarding much code; reverse is not true |

### ADR-0007a: In-Cluster TLS Certificate Management
| Field | Value |
|-------|-------|
| **Date** | June 27, 2025 |
| **Status** | Accepted |
| **Decision** | Use **distinct namespaces per component** with OneCert for AME certificates (Option 1) as short-to-medium-term solution |
| **Options Evaluated** | (1) Distinct namespaces (e.g., `skylarc-dpx-prod-celestial`) → **chosen**; (2) Different cluster local domains — too risky; (3) DNS rewrite rules — CoreDNS dependency risk; (4) Cluster CA with cert-manager — pending security review |
| **Scope** | Custom cluster components owned end-to-end (e.g., Skylarc Agent). Out-of-scope: K8s native components, OSS components (Gatekeeper, metrics-server, KEDA) — acknowledged gap |
| **Consequences** | Services must parameterize target DNS names; follow-up needed with security team on Cluster CA usage |

### ADR-0007b: Tag-Based Deployment Process for Release Candidates
| Field | Value |
|-------|-------|
| **Date** | June 12, 2025 |
| **Status** | Accepted (supersedes ADR-0004) |
| **Decision** | Adopt semantic versioning (`cluster/vX.Y` tags) for cluster release artifacts; release pipeline discovers artifacts by tag rather than build ID |
| **Versioning Rules** | Major = breaking changes (cluster rebuilds); Minor = compatible features (may need config updates); Patch = compatible fixes (no config updates) |
| **Flow** | IE team tags pipeline → release pipeline pulls latest successful run with matching tag → bundles with cluster configs from idk8s-infrastructure |
| **Known Limitation** | Cannot use different artifacts for different cluster types (single tag) — to be addressed later |

### ADR-0008: Release Branch Process for Cluster Configurations
| Field | Value |
|-------|-------|
| **Date** | July 1, 2025 |
| **Status** | Accepted |
| **Decision** | Create hotfix branches **on demand** (not proactively per release cycle) for cluster configurations |
| **Options** | (1) Continue with main — error-prone; (2) Proactive release branches — overhead; (3) **On-demand hotfix branches** → chosen |
| **Process** | Regular releases use `main`; if restart needed after config changes, create `hotfix/vX.Y` from original commit; pipeline runs from hotfix branch; changes cherry-picked back to main |
| **Benefit** | No branch management overhead for normal releases; safe restart capability for exceptional cases |

### ADR-0009: SKU Selection
| Field | Value |
|-------|-------|
| **Date** | July 11, 2025 |
| **Status** | Accepted |
| **Decision** | Standardize on AMD/Intel v6 family: `Dds_v6` (Intel) or `Dads_v6` (AMD) for all new capacity; migrate existing capacity during cluster rebuilds |
| **Rationale** | Previous generations (Ds_v4, Das_v5, Dds_v6 mix) caused testing overhead; v6 available in all regions; customers have Intel/AMD preferences |
| **Consequences** | Reduced testing combinations, improved reliability, future-proof hardware supply, regional flexibility |

### ADR-0010: VMSS Identity dSMS Certificate and dSTS SCI Creation Automation
| Field | Value |
|-------|-------|
| **Date** | July 24, 2025 |
| **Status** | Accepted |
| **Decision** | Automate dSMS certificate and dSTS SCI creation inside `idk8sctl create cluster` workflow (Option 1 — Go code in idk8sctl) |
| **Options Rejected** | (2) Separate .NET executable — splits languages; (3) Bicep deploymentScripts — too complex in bash |
| **Implementation** | New dSMS/dSCM clients in idk8sctl; VMSS naming logic moved from Bicep to idk8sctl; cert paths/SCI principalIds passed as Bicep parameters; deletion via `--remove-dsts-identity` flag |
| **Consequences** | No more manual steps; dSMS/dSTS resources defined in Go not Bicep (until Prism migration) |

### ADR-0011: WireServer File Proxy
| Field | Value |
|-------|-------|
| **Date** | September 25, 2025 |
| **Status** | Accepted |
| **Decision** | Build a simple proxy service to serve Gateway the Azure service tags mapping file, since WireServer access is being locked down at network level for security |
| **Context** | Gateway reads service tags from WireServer; Linux requires root access; WireServer being blocked for security; service tags file itself is not sensitive |
| **Consequences** | New cluster-level component running as root on Gateway clusters; Gateway changes URL for service tags; not a generic proxy — must revisit if more files needed |

### ADR-0012: Scheduled Event Approval Criteria for Kubernetes Nodes
| Field | Value |
|-------|-------|
| **Date** | November 6, 2024 |
| **Status** | Accepted |
| **Decision** | Coordinate with other orchestration systems (Option 3) — approve scheduled events only when specific criteria are met |
| **Criteria** | **Both** must be satisfied: (1) Node has `maintenance.k8s.msidentity.io/scheduled-event` taint set by NodeRepairService; (2) Node has no workload pods running (only static/DaemonSet pods remain) |
| **Options Rejected** | (1) Always approve immediately — violates PDBs, risks data loss; (2) Never approve — longer maintenance windows |
| **Consequences** | Balances workload stability with maintenance speed; requires dependency on NRS and K8s API for pod enumeration |

---

## Architecture Deep-Dive

### Management Plane (MP)

#### Overview
The MP is a **regional .NET service** deployed as a Windows container in dedicated MP Kubernetes clusters (one per region). Its primary production service is the **Scale Unit (SU) API**, which deploys scale units (workloads) into designated workload clusters.

#### Architecture Stack
```
┌──────────────────────────────────────────────────┐
│                    EV2 Pipeline                   │
│         (ExpressV2Internal tasks)                 │
└──────────────────┬───────────────────────────────┘
                   │ HTTP Extension (SN+I cert → Entra token)
                   ▼
┌──────────────────────────────────────────────────┐
│              Scale Unit API                       │
│  ┌─────────────────┐  ┌────────────────────────┐ │
│  │ ManagementPlane  │  │ ManagementPlane.Library │ │
│  │ (Controllers,    │  │ (Services, Models,     │ │
│  │  Middleware,     │  │  IPersistentStore)     │ │
│  │  Auth/MISE)     │  │                        │ │
│  └────────┬────────┘  └───────────┬────────────┘ │
│           │                       │               │
│           ▼                       ▼               │
│  ┌──────────────────────────────────────────────┐ │
│  │        ResourceProvider (FleetManager SDK)    │ │
│  │  CelestialClusters.json, ServiceProfile.json  │ │
│  │  ScaleUnits.json, Tenant data                 │ │
│  └──────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
    K8s API Server      Azure ARM/Resources
    (ConfigMaps)        (via MP SP cert)
```

#### Runtime Modes
- **Generic (EV2) mode** — Production: Exposes EV2-compatible endpoints for deployment, monitoring
- **CLI mode** — Dev sandbox: Backend for Celestial CLI operations (currently not in use)

#### Authentication Flow
1. **EV2 → SU API**: Platform-generated EV2 certificate → exchanged for Entra token against MP app registration → MISE middleware validates
2. **SU API → Downstream**: MP service principal (regional, SN+I cert from AKV) → ClientCertificateCredential for ARM/K8s API calls
3. **Tenant Authorization**: ServiceProfile.json maps deployment identities to tenants; TenantAuthorizationHandler validates caller → tenant mapping

#### Persistent Storage
- **Production**: Kubernetes ConfigMaps (IPersistentStore interface)
- **Local Dev**: InMemoryStore implementation
- **Future**: CustomResource objects (CRDs) per MVP Phase 3

#### Key Modules (FleetManager.sln)
| Module | Purpose |
|--------|---------|
| ManagementPlane | API controllers, middleware, auth handlers |
| ManagementPlane.Library | Shared service logic, EV2 services, models |
| ManagementPlane.Bootstrapper | Cluster bootstrap tool for MP deployment |
| ResourceProvider | FleetManager SDK, tenant/cluster data, Azure client extensions |
| Inventory / Inventory.AzureTableStorage | Cluster inventory with Azure Table Storage backend |
| ComponentDeployer / ComponentDeployer.CLI | Manifest-driven deployment engine |
| NodeHealthAgent | Channels VMSS scheduled events to K8s API, reports node health |
| NodeRepairService | Taints/untaints nodes based on health status |
| RemediationController | Kubernetes controller for remediation workflows |
| PodHealthCheckService | Pod health monitoring and validation |
| DsmsBootstrapNodeService | Certificate injection for DSMS bootstrap |
| DsmsNativeBootstrapper | Native DSMS certificate management |
| WireServerFileProxy | Simple proxy for Azure service tags file |
| Celestial.CLI | CLI tooling for dev sandbox operations |
| WorkloadCanaryApp | Canary testing application |
| TenantManager.CLI | Tenant management CLI |
| IMDS / IMDSProxy / MockIMDSService | IMDS interaction and testing |

#### MP Auditing
- Implemented via **OpenTelemetry SDK** sending logs to ETW (Windows) / UnixDomainSocket (Linux)
- Collected by Geneva agent; configured per-environment in Helm values files
- Applied via `AuditingMiddleware.cs` with `[Audited]` attribute on controller actions
- Covers: elevated permission actions, customer data access, system state changes

#### MP Cluster Buildout Process (New Region)
Multi-step process spanning 4+ repos:
1. Model subscription in `ad-FUN-idsr` (AC2) → nightly build creates subscription
2. Create regional resources (Key Vault, certificates, Entra apps) in `IDK8s-MP.ac2`
3. Apply via LSM job in Geneva Actions
4. Create OS images in `idk8s-infrastructure-enablement`
5. Add EV2 spec + cluster config in `idk8s-infrastructure`
6. Trigger MP cluster creation pipeline
7. Deploy SU API (13-step process including MSI allow-listing, FM NuGet updates, LSM onboarding)

### Component Deployer

#### Architecture
Split into two projects for future EV2 HTTP extension migration:
- **ComponentDeployer.CLI** — CLI interface (current EV2 shell extension entry point)
- **ComponentDeployer** — Core business logic, manifest parsing, execution planning

#### Manifest System
Three cluster-type manifests: `dpx-manifest.yml`, `gateway-manifest.yml`, `generic-manifest.yml`

**Component Kinds:**
1. **Idk8sctlBicep** — Executes `idk8sctl create` (ARM/Bicep deployment)
2. **Idk8sctlConfigure** — Executes `idk8sctl configure` (all default cluster components)
3. **Idk8sctlConfigureComponent** — Executes `idk8sctl configure --name <component>` (single component)

#### Execution Planning (DAG)
- Dependencies specified via `dependsOn` parameter
- Non-dependent components execute in parallel within stages
- Stages execute sequentially
- Cyclic dependency detection with exception on failure
- **Example**: A → [B, C parallel] → D

#### Topology Selector
Kubernetes-style label selectors for conditional deployment:
- **Keys**: `ring`, `environment`, `region`
- **Operators**: `In`, `NotIn`
- **Logic**: AND across all matchExpressions
- Applied **before** execution plan building; dependency validation after filtering
- ⚠️ Filtering a dependency without filtering its dependents causes deployment failure

#### State Management
- Tracks installed component versions in **Azure Storage Account Tables** (per environment: dev/test/prod)
- Compares desired vs. actual version before deployment; skips if matching
- Current: idk8sctl artifact version as proxy for all components
- Future: Per-component unique version (digest) for granular tracking

#### Phase 0 Manifest Contract (Future)
Evolving toward two-level manifest system:
- **Cluster Manifest** — References component manifests via `ref` field; includes `clusterKind`, `metadata`, `version`
- **Component Manifest** — Individual deployable unit with `owner`, `artifactReference`, `dependsOn` (with NuGet-style version ranges)
- **Celestial Manifest** — Zip archive of cluster + component manifests, published to ACR, consumed by EV2
- **Component Folder Structure**: `helm-chart/`, `values/`, `validation/`, `version.txt`

#### Pipeline Architecture
```
┌─────────────────────┐     ┌──────────────────────┐
│  Manifest Publish   │     │   Build Pipeline     │
│  Pipeline (440887)  │     │   (296836)           │
│  → ACR artifacts    │     │   → CLI binaries     │
│  (sign, replicate   │     │                      │
│   CORP→TEST→PROD)   │     │                      │
└────────┬────────────┘     └──────────┬───────────┘
         │                             │
         ▼                             ▼
┌────────────────────────────────────────────────────┐
│    Cluster Release Pipeline (414565)                │
│   ┌──────────────────────────────────────────┐     │
│   │           EV2 Archive                     │     │
│   │  • Manifest digests (from Manifest Pub)   │     │
│   │  • Component Deployer CLI (from Build)    │     │
│   │  • idk8sctl binaries (from IE Pipeline)   │     │
│   └──────────────────────────────────────────┘     │
└────────────────────────────────────────────────────┘
                       ▲
         ┌─────────────┴──────────────┐
         │    IE Pipeline (436735)    │
         │  (idk8sctl, Bicep,         │
         │   Components from          │
         │   idk8s-infra-enablement)  │
         └────────────────────────────┘
```

### AOS (Automated OS Orchestration)

#### Component Pipeline
```
VMSS Scheduled Events → SEC/NHA → K8s Node Conditions → NRS → Taints → Pod Draining
                                                          ↑
Azure Node Health    → NPD ─────→ K8s Node Conditions ───┘
```

#### Components
| Component | Role |
|-----------|------|
| **ScheduledEventsCollector (SEC)** | Listens to IMDS for scheduled events |
| **Node Health Agent (NHA)** | Channels VMSS events to K8s API; reports health to VMSS RP |
| **Node Problem Detector (NPD)** | Detects node problems; reports conditions |
| **Node Repair Service (NRS)** | Taints/untaints nodes based on NHA + NPD conditions |

#### Failure Mode Analysis (5 scenarios documented)
1. **NHA Down** — SEC events lost; NRS can't taint for maintenance; AHE reports Unknown. Mitigations: system-node-critical priority, adequate resource limits, readiness probes blocking release train
2. **NPD Down** — Health conditions not reported; unhealthy nodes not tainted. Mitigations: monitoring for missing conditions, readiness probes
3. **Over-Sensitive NPD Rules** — Mass taint → mass drain → capacity loss. Mitigation: configurable taint threshold
4. **NPD Flapping** — Rapid state changes causing instability. Mitigation: grace periods in tainting logic
5. **NRS Replicas Down** — No tainting/untainting. Mitigation: tainted node count monitoring

#### Proposed Multi-Stage Grace Period Model
- **T0**: Record last transition time (LTT) when condition becomes unhealthy
- **T1**: After 1st grace period → `PreferNoSchedule` taint + report AHE failure
- **T2**: After 2nd grace period → `NoSchedule` taint (no drain; watchdog handles)

#### AOS Action Items (from failure analysis)
| Component | Action |
|-----------|--------|
| NHA | Set system-node-critical priority class |
| NHA | Configure adequate container requests/limits |
| NHA | Wait for SEC initialization in readiness probes |
| NHA | Ignore stale NPD conditions in NHC |
| NPD | Configure adequate container requests/limits |
| NPD | Implement readiness probes blocking release train |
| NRS | Ignore stale node conditions in tainting logic |
| NRS | Configurable threshold for tainted node count |
| Telemetry | Dashboard for VM health (RP side) |
| Telemetry | Monitor missing node conditions |
| Telemetry | Dashboard for individual NPD plugins |
| Telemetry | Monitor tainted node count |
| VMSS | Revisit batch size for auto-repair |
| VMSS | Kubernetes Graceful node shutdown |

### Release Engineering

#### SU API CI/CD (8 pipelines)
1. `ManagementPlaneChartPublish-Buddy` → Helm chart to dev ACR
2. `ManagementPlane-Buildout-Buddy` → Docker image to dev ACR (auto-trigger from Official build)
3. `ManagementPlane-Release-Buddy` → Deploy to CORP dev cluster (EV2 shell + MP.Bootstrapper)
4. `SU-API-IntegrationTests` → Deploy test apps to CORP workload cluster (simulates AME flow)
5. `ManagementPlane-IDNA-Buildout-Official` → Signed binaries + Docker to AME ACRs (triggered by integration tests)
6. `ManagementPlane-Release-Official` → Deploy to AME test/prod (EV2 extension + LSM, manual trigger)
7. `ManagementPlane-Cluster-Official` → Create MP clusters in AME
8. `IntegrationTests-ClusterRecycle` → Scheduled cluster recreation for integration tests

#### Versioning Strategy
- **Tool**: GitVersion in Continuous Deployment mode
- **Branching**: `main` increments minor; `hotfix` increments patch
- **Pre-release**: Alpha tag incremented per commit (e.g., `0.3.0-alpha0001`)
- **Known Issue**: libgit2 BinSkim compliance blocks GitVersion upgrades (libgit2/libgit2#6952)

---

## Cross-Repo Dependency Map

```
                    ┌───────────────────────────┐
                    │   idk8s-infrastructure    │
                    │   (this repo)             │
                    └─────┬───────┬───────┬─────┘
                          │       │       │
          ┌───────────────┘       │       └───────────────┐
          ▼                       ▼                       ▼
┌─────────────────────┐ ┌─────────────────┐ ┌─────────────────────┐
│ idk8s-infrastructure│ │   ad-FUN-idsr   │ │  AD-Platform-       │
│ -enablement         │ │                 │ │  LsmJobs            │
│                     │ │ AC2 config for: │ │                     │
│ • idk8sctl binaries │ │ • Subscriptions │ │ • FM SDK consumer   │
│ • Bicep templates   │ │ • Entra apps    │ │ • LSM deployment    │
│ • Component Helm    │ │ • Key Vaults    │ │   packages          │
│ • OS image building │ │ • Certificates  │ │ • Version must      │
│ • RBAC definitions  │ │ • MP resources  │ │   match FM NuGet    │
│ • NSG configs       │ │ (IDK8s-MP.ac2)  │ │                     │
│ • cluster release   │ │                 │ │                     │
│   artifact pipeline │ │                 │ │                     │
└─────────────────────┘ └─────────────────┘ └─────────────────────┘
                                                      │
                                            ┌─────────┴───────────┐
                                            │  IDNA-IDCR-Buildout │
                                            │                     │
                                            │ • Celestial buildout│
                                            │   templates         │
                                            │ • FM SDK consumer   │
                                            │ • GenerateReleaseSpec│
                                            │ • Release templates │
                                            │ (to be deprecated?) │
                                            └─────────────────────┘

Additional References:
• Entra-Core-Services-Docs — SOPs for MSI allow-listing
• OneBranch.Pipelines/GovernedTemplates — Pipeline base templates
• kubernetes/node-problem-detector — External NPD source for Windows image
```

### Dependency Details

| Source Repo | Dependency Type | What's Consumed | Update Process |
|-------------|----------------|-----------------|----------------|
| **idk8s-infrastructure-enablement** | Build artifacts | idk8sctl, Bicep, Components, OS images, RBAC/NSG definitions | Tag-based (`cluster/vX.Y`); IE team publishes, IS team consumes |
| **ad-FUN-idsr** | AC2 configuration | Subscriptions, Entra app registrations, Key Vaults, certificates, MP service principals | PR-based; LSM job applies changes via Geneva Actions |
| **AD-Platform-LsmJobs** | FM SDK NuGet | FleetManager SDK for LSM deployment jobs | Manual version bump; must verify no breaking changes |
| **IDNA-IDCR-Buildout** | Build templates | Celestial buildout templates (GenerateReleaseSpec, Release), FM SDK | FM version update; dependency "should be removed soon" per docs |
| **OneBranch** | Pipeline templates | GovernedTemplates for official pipeline extensions | Managed by OneBranch team |

---

## Gap Analysis & Prioritized Recommendations

### 🔴 Critical Gaps

#### 1. Missing ADR for Management Plane → CRD Migration (Phase 3)
**Impact**: The shift from ConfigMaps to CRDs as persistent storage is referenced in tech debt/vision docs and MVP Phases doc, but no ADR captures the design decision, migration strategy, or backward compatibility plan.
**Recommendation**: Author ADR-0013 covering CRD schema design, migration from ConfigMaps, and rollback strategy.

#### 2. No ADR for Cluster CA / cert-manager Security Decision
**Impact**: ADR-0007a explicitly defers the Cluster CA decision pending security review. OSS components (Gatekeeper, metrics-server, KEDA) using self-signed CAs are an "acknowledged gap." No follow-up ADR exists.
**Recommendation**: Author ADR documenting security team's determination and approved patterns for in-cluster certificate management.

#### 3. Undocumented AOS Remediation Controller
**Impact**: `RemediationController` exists as a full project in the solution but has zero documentation. The AOS failure modes doc covers NHA, NPD, and NRS but never mentions the Remediation Controller.
**Recommendation**: Add `docs/aos/remediation-controller.md` documenting its role, relationship to NRS, and failure modes.

### 🟡 High-Priority Gaps

#### 4. No Architecture Doc for ResourceProvider / FleetManager SDK
**Impact**: The ResourceProvider is the core dependency for all MP operations — it manages tenant data, cluster registry (CelestialClusters.json), Azure client extensions, and the FM SDK. No architecture documentation exists.
**Recommendation**: Create `docs/fleet-manager-sdk/` documentation covering data model, tenant resolution, and API surface.

#### 5. Missing Inventory Subsystem Documentation
**Impact**: The Inventory and Inventory.AzureTableStorage projects manage cluster state tracking (used by Component Deployer state management). Only a brief mention in state-management.md exists.
**Recommendation**: Document the inventory data model, storage account tables schema, and query patterns.

#### 6. No ADR for Windows vs. Linux Container Decision
**Impact**: MP runs as Windows container (noted as tech debt — "big & slow to spin up"). The original ADR is an external SharePoint doc, not in the repo. No in-repo record exists.
**Recommendation**: Capture the Windows container decision and planned Linux migration as an in-repo ADR.

#### 7. Incomplete dSTS Migration Plan
**Impact**: Multiple docs reference the shift from Entra → dSTS (auth, onboarding, OBO flow), but no consolidated migration plan or ADR captures timelines, dependencies, or rollback.
**Recommendation**: Author ADR covering dSTS adoption, SP OBO flow, User OBO flow, and the CORP testing strategy.

### 🟢 Medium-Priority Gaps

#### 8. No Documentation for Pod Health Check Service
**Impact**: PodHealthCheckService has source + tests but no docs. Its relationship to AOS components is unclear.
**Recommendation**: Add operational documentation and integrate into AOS failure modes analysis.

#### 9. No Documentation for DsmsBootstrapNodeService / DsmsNativeBootstrapper
**Impact**: Two DSMS-related projects with tests but no architecture docs. ADR-0010 covers idk8sctl automation but not the in-cluster certificate injection components.
**Recommendation**: Document the DSMS certificate lifecycle from node bootstrap → certificate rotation → pod delivery.

#### 10. Missing Operational Runbooks / TSGs
**Impact**: Only the auditing doc references a TSG. No runbooks exist for Component Deployer failures, cluster release rollbacks, AOS cascading failures, or MP unavailability.
**Recommendation**: Create `docs/tsg/` directory with operational runbooks for each subsystem.

#### 11. Kubescape Documentation Incomplete
**Impact**: `/docs/kubescape/` directory exists but was not analyzed; security scanning integration undocumented in the main docs index.
**Recommendation**: Ensure kubescape scanning policies, exemptions, and CI integration are documented.

#### 12. No ADR for EV2 Extension Choice (Shell vs. HTTP)
**Impact**: Component Deployer uses shell extension today, with explicit project split for future HTTP extension migration. No ADR records why shell was chosen first or the migration trigger criteria.
**Recommendation**: Author ADR capturing the shell → HTTP extension migration plan and decision criteria.

#### 13. Multi-Cluster Type Strategy Undocumented
**Impact**: Three cluster types (DPX, Gateway, Generic) exist with separate manifests, but no architectural doc explains why these types exist, their workload boundaries, or when to create a new type.
**Recommendation**: Document cluster type taxonomy and evolution strategy.

---

## Tech Debt & Vision Insights

### Current Tech Debt (from docs)

| Area | Debt Item | Severity |
|------|-----------|----------|
| **MP/SU API** | Windows container — large image, slow startup | High |
| **MP/SU API** | Missing Ev2 endpoints (/validate, /suspend, /cancel) | Medium |
| **MP/SU API** | CLI API integration tests not complete | Medium |
| **FM SDK** | Need to decommission IResourceProvider use in LSM flow | High |
| **FM SDK** | Publish new FM NuGet & update in LSM | Medium |
| **MP Auth** | NodeMSI for AKV access should use native dSMS support | Medium |
| **MP Auth** | Entra → dSTS migration pending | High |
| **Release** | IDNA-IDCR-Buildout FM dependency "should be removed soon" | Medium |
| **Release** | Cannot use different artifacts per cluster type (ADR-0007b limitation) | Medium |
| **Versioning** | GitVersion upgrade blocked by libgit2 BinSkim compliance | Low |
| **AOS** | 15+ monitoring/telemetry gaps identified in failure modes analysis | High |
| **AOS** | NRS grace period logic not yet implemented | Medium |
| **Certificates** | OSS components using self-signed CAs — security gap acknowledged | High |
| **Replication** | TestApps V2 Buddy pipeline on hold ("replication story not solved") | Medium |

### Strategic Vision

1. **SU Deployment via MP** — Replace LSM with MP as primary fleet-wide deployment mechanism
2. **Entra-free Deployments** — Move to dSTS for SU API authentication (SP OBO → User OBO)
3. **CRD-based State** — Migrate from ConfigMaps to CRDs for structured, observable state (MVP Phase 3)
4. **Cluster RP Operator** — K8s operator wrapping idk8sctl for on-demand cluster provisioning
5. **N+1 Controller** — Orchestrate disruptive cluster upgrades with N+1 spare cluster strategy
6. **Workload Migration Controller** — Automated workload migration between clusters
7. **Component Deployer HTTP Extension** — Migrate from shell to HTTP extension for better observability
8. **Per-Component Versioning** — Replace monolithic idk8sctl version with individual component digests
9. **Prism Integration** — Potential future for defining dSMS/dSTS resources in Bicep (ADR-0010)
10. **MP SLOs** — Formal SLOs for management plane availability and deployment latency

---

## Appendices

### A. Container Image Inventory

#### Linux Images (7)
| Image | Source Project | Purpose |
|-------|---------------|---------|
| dsms-cert-injection-service-linux | DsmsBootstrapNodeService | Certificate injection for DSMS bootstrap |
| nha-linux | NodeHealthAgent | Node Health Agent for Linux |
| nrs | NodeRepairService | Automated node remediation |
| dsmsnativebootstrapper | DsmsNativeBootstrapper | DSMS certificate management |
| remediation-controller-linux | RemediationController | Node remediation workflows |
| pod-health-check-service-linux | PodHealthCheckService | Pod health monitoring |
| wireserver-file-proxy-linux | WireServerFileProxy | Azure service tags proxy |

#### Windows Images (4)
| Image | Source Project | Purpose |
|-------|---------------|---------|
| nha-windows | NodeHealthAgent | Node Health Agent for Windows |
| dsms-cert-injection-service-windows | DsmsBootstrapNodeService | Certificate injection |
| pod-health-check-service-windows | PodHealthCheckService | Pod health monitoring |
| npd-windows | External (k8s/node-problem-detector) | Node Problem Detector |

### B. Container Registry Strategy

| Environment | Registry | Tenant |
|-------------|----------|--------|
| Dev | `idk8sacrdev` | CORP |
| Test | `idk8sacrtest` | AME |
| Prod | `iamkubernetesprod` (migrating to `idk8sacrtestprod`) | AME |

### C. Storage Accounts (Component Deployer State)

| Environment | Account |
|-------------|---------|
| Dev | `inventorysadev` |
| Test | `inventorysatest` |
| Prod | `inventorysaprod` |

### D. Pipeline Inventory (Key Pipelines)

| Pipeline | ID | Purpose |
|----------|-----|---------|
| idk8s-infrastructure-Official | 296836 | Main build pipeline |
| idk8s-infrastructure-ClusterRelease-Official | 414565 | Cluster release (EV2) |
| idk8s-infrastructure-Cluster-Manifest-Publish-Official | 440887 | Manifest publish to ACR |
| idk8s-infrastructure-ManagementPlane-Cluster-Official | 396681 | MP cluster creation |
| idk8s-infrastructure-ManagementPlane-IDNA-Buildout-Official | 397580 | SU API official build |
| idk8s-infrastructure-ManagementPlane-Release-Official | 386796 | SU API release to AME |
| idk8s-infrastructure-ManagementPlane-Buildout-Buddy | 396130 | SU API dev build |
| idk8s-infrastructure-ManagementPlane-Release-Buddy | 382465 | SU API dev release |
| idk8s-infrastructure-SU-API-IntegrationTests | 406312 | Integration tests |
| idk8s-infrastructure-ManagementPlaneChartPublish-Buddy | 393473 | Helm chart publish to dev ACR |
| idk8s-infrastructure-IntegrationTests-ClusterRecycle | 400450 | Scheduled cluster recreation |
| idk8s-infrastructure-enablement_release-cluster_artifact | 436735 | IE team cluster artifacts |

### E. ADR Status Summary

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| 0001 | Record Architecture Decisions | ✅ Accepted | Apr 2024 |
| 0002 | IMDS Exception for SEC | ✅ Accepted | Mar 2025 |
| 0003 | Platform-Managed Certs for Partners | ✅ Accepted | Feb 2025 |
| 0004 | Deployment Process (Build ID) | ⚠️ Superseded by 0007b | May 2025 |
| 0005 | MP Clusters in Release Pipeline | ✅ Accepted | Jun 2025 |
| 0006 | Cluster Orchestrator | ✅ Accepted | Jun 2025 |
| 0007a | In-Cluster TLS Certificate Management | ✅ Accepted | Jun 2025 |
| 0007b | Tag-Based Deployment Process | ✅ Accepted | Jun 2025 |
| 0008 | Release Branch Process for Configs | ✅ Accepted | Jul 2025 |
| 0009 | SKU Selection | ✅ Accepted | Jul 2025 |
| 0010 | VMSS Identity dSMS/dSTS Automation | ✅ Accepted | Jul 2025 |
| 0011 | WireServer File Proxy | ✅ Accepted | Sep 2025 |
| 0012 | Scheduled Event Approval Criteria | ✅ Accepted | Nov 2024 |

---

*Report compiled by Captain Picard, Lead Architect — idk8s-infrastructure Analysis Squad*
*"Make it so." 🖖*
