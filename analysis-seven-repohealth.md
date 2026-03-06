# 🔬 idk8s-infrastructure Repository Health Analysis

**Designation:** Seven of Nine — Research & Documentation Expert  
**Stardate:** 2026.0302 | **Analysis Completed:** March 2, 2026  
**Repository:** `msazure/One/idk8s-infrastructure` (Identity Kubernetes Platform / Celestial)  
**Repo ID:** `d46e78de-8850-4052-ab40-f96d95b5c09e`

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [CI/CD Pipeline Architecture](#2-cicd-pipeline-architecture)
3. [Branching & Versioning Strategy](#3-branching--versioning-strategy)
4. [Commit Activity Analysis](#4-commit-activity-analysis)
5. [PR Activity Analysis](#5-pr-activity-analysis)
6. [Documentation Inventory & Quality](#6-documentation-inventory--quality)
7. [Repository Configuration & Tooling](#7-repository-configuration--tooling)
8. [Code Quality Infrastructure](#8-code-quality-infrastructure)
9. [Copilot & AI Integration](#9-copilot--ai-integration)
10. [Repo Health Score](#10-repo-health-score)
11. [Recommendations](#11-recommendations)

---

## 1. Executive Summary

The **idk8s-infrastructure** repository is the monorepo for Microsoft's Identity Kubernetes Platform (Celestial). It houses Fleet Manager, Management Plane, AOS components, DSMS bootstrapper, Node Health Agent, test applications, Helm charts, EV2 deployment specifications, cluster configurations, and supporting tooling across C#/.NET 10, Go, PowerShell, and Helm/Rego.

**Key findings:**
- **Mature CI/CD**: 24+ pipeline definitions with comprehensive OneBranch integration, multi-cloud container replication, and EV2/SDP-based safe deployment
- **Active Development**: 50 commits analyzed across 2 days; ~14 unique contributors; high velocity
- **Strong Tooling**: Extensive code quality infrastructure (CodeQL, BinSkim, DevSkim, PSScriptAnalyzer, CredScan, Regal, Vale, cspell, shellcheck)
- **Good Automation**: MerlinBot reviewer recommender, team nudges, Dependabot, PR Copilot, PR Quantifier
- **Documentation Gaps**: CONTRIBUTING.md is boilerplate; several areas lack documentation; ADRs are actively maintained but sparse

**Overall Health Score: 7.8 / 10** — A well-instrumented production infrastructure repo with room for improvement in documentation and branch hygiene.

---

## 2. CI/CD Pipeline Architecture

### 2.1 Pipeline Inventory (24 YAML Definitions)

| Pipeline | Trigger | Type | Purpose |
|----------|---------|------|---------|
| `OneBranch.PullRequest.yml` | PR to main | Validation | Full PR validation: Linux+Windows build, test, mutation testing, Helm validation, ADR validation |
| `OneBranch.Official.yml` | Push to `main` | Official | Official build, NuGet publish to Official+Internal feeds, ESRP signing, CloudVault upload |
| `OneBranch.ContainerImagesBuild.Buddy.yml` | Manual | Buddy | Build & push container images to DEV ACR from PR pipeline artifacts |
| `OneBranch.ContainerImagesBuildReplicate.Official.yml` | Official pipeline completes | Official | Build containers and replicate to PPE/TEST/PROD ACRs |
| `OneBranch.Cluster.Release.Official.yml` | Manual | Official/SDP | SDP-managed cluster release with Normal/Emergency/NoDelay rollout types |
| `OneBranch.Cluster.PreRelease.yml` | Manual | NonOfficial | Pre-release validation of cluster configs to TEST environments |
| `OneBranch.Single.Cluster.Release.Official.yml` | Manual | Official | Deploy to a single specific cluster (20+ cluster targets) |
| `OneBranch.Cluster.Delete.Official.yml` | Manual | Official | Delete clusters via EV2 |
| `OneBranch.Cluster.Manifest.Publish.Official.yml` | Manual | Official | Archive, sign, and publish cluster manifests |
| `OneBranch.GlobalResources.Official.yml` | Manual | Official | Deploy global EV2 resources (non-cluster) |
| `OneBranch.Image.Release.Official.yml` | Manual | Official | OS image release pipeline via EV2 |
| `OneBranch.NonSDP.Cluster.Create.Recycle.yml` | Weekly (Sunday midnight) | Scheduled | Rebuild non-SDP clusters weekly |
| `OneBranch.Sandbox.Buddy.yml` | Wed+Sat 4AM UTC | Scheduled | Sandbox cluster lifecycle (delete + recreate) |
| `OneBranch.IntegrationTests.yml` | Push to `main` | CI | Integration tests on merge |
| `OneBranch.IntegrationTests.CleanUp.yml` | Daily midnight | Scheduled | Clean up integration test resources |
| `OneBranch.ManagementPlane.Buildout.Buddy.yml` | Manual | Buddy | Build and publish Management Plane |
| `OneBranch.ManagementPlane.IDNA.Buildout.Official.yml` | Integration tests complete | Official | Management Plane buildout for IDNA |
| `OneBranch.ManagementPlane.IntegrationTests.yml` | MP Release Buddy completes | Triggered | Management Plane integration tests |
| `OneBranch.ManagementPlaneChartPublish.Buddy.yml` | Manual | Buddy | Publish MP Helm chart to ACRs |
| `OneBranch.TestApps.Buddy.yml` | Manual | Buddy | Build test applications |
| `OneBranch.TestApps.Official.yml` | Daily midnight | Scheduled/Official | Official test app builds with signing |
| `OneBranch.Official.ThirdPartyNugetPublish.yml` | Manual | Official | Publish third-party tools as NuGet (Conftest, Helm, Kubectl, LogMonitor, Notation) |
| `OneBranch.Dev.Kubescape.yml` | Weekly (Sunday 3AM) | Scheduled | Kubescape security scan results publication |
| `aos/OneBranch.Validate.AOS.AspireTests.yml` | Manual | Validation | AOS Aspire integration tests (KIND-based) |
| `fleet-manager/OneBranch.Validate.FM.AspireTests.yml` | Manual | Validation | Fleet Manager Aspire integration tests |

### 2.2 Release Pipelines (7 Definitions)

| Pipeline | Purpose |
|----------|---------|
| `Release.FleetManager.Official.yml` | Build containers, push to PROD ACR, package Helm charts, create EV2 artifacts for Fleet Manager |
| `Release.ManagementPlane.Official.yml` | Deploy MP via Celestial buildout to TEST → Manual Approval → PROD (CUS, NCUS, SDC) |
| `Release.ManagementPlane.Buddy.yml` | MP release to DEV/TEST via buddy pipeline, triggered by Buildout Buddy |
| `Release.TestApps.Official.yml` | Deploy test apps to TEST-SDC → PROD-CUS-EUAP → PROD regions via Celestial |
| `Release.TestApps.V2.Buddy.yml` | Deploy test apps via Management Plane API (v2) |
| `Release.Flux.Buddy.yml` | Flux-based release with container images + Helm charts + workload config |
| `Release.Skylarc.AppConfig.Official.yml` | Auto-triggered on AppConfig path changes; deploys Skylarc config |

### 2.3 Pipeline Architecture Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PR VALIDATION FLOW                               │
│  PR → OneBranch.PullRequest.yml                                        │
│  ├── Linux Build (Bash Lint, DevSkim, .NET Build, Go Build, Docker)   │
│  ├── Windows Build (.NET Build, Test, NuGet Pack, Docker)             │
│  ├── Helm Chart Validation Tests                                       │
│  ├── Mutation Testing (Stryker diff)                                   │
│  └── ADR Validation                                                    │
└─────────────────────────────────────────────────────────────────────────┘
                              │ merge
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      OFFICIAL BUILD FLOW                                │
│  Push to main → OneBranch.Official.yml                                 │
│  ├── Linux Build + ESRP Signing + CloudVault                          │
│  ├── Windows Build + NuGet Publish (Official + Internal feeds)        │
│  ├── Push NuGet to IDNA-Secure-Packaging (SPM)                       │
│  └── Push Diagnostics to idk8s-mirror feed                            │
└─────────────────────────────────────────────────────────────────────────┘
                              │ triggers
                    ┌─────────┼──────────┐
                    ▼         ▼          ▼
        ┌──────────────┐ ┌────────┐ ┌──────────────────┐
        │ Container    │ │ Int.   │ │ Cluster Manifest  │
        │ Replicate    │ │ Tests  │ │ Publish           │
        │ (multi-ACR)  │ │        │ │                   │
        └──────┬───────┘ └───┬────┘ └────────┬─────────┘
               │             │               │
               ▼             ▼               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      RELEASE FLOWS                                      │
│                                                                         │
│  Fleet Manager Release:                                                │
│  ├── Build & Push Container Images to PROD ACR                        │
│  ├── Build & Push Shared Helm Charts                                  │
│  ├── Create Workload Component Configuration                          │
│  ├── Combine Artifacts → Push to all clouds (FF, MC, USNat, USSec)   │
│  └── EV2 SDP Rollout (Normal: 20hr bake / Emergency: 6hr)           │
│                                                                         │
│  Management Plane Release:                                             │
│  ├── IDNA Buildout → Integration Tests → Release                     │
│  └── TEST → Manual Approval → PROD (CUS → NCUS → SDC)              │
│                                                                         │
│  Cluster Release (SDP):                                                │
│  ├── Config Validation → EV2 Artifact Creation                       │
│  ├── Ring-based deployment with bake time                             │
│  └── Supports Default + ComponentDeployer rollout specs              │
│                                                                         │
│  OS Image Release:                                                     │
│  └── EV2-based OS image deployment + replication                      │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.4 Template Structure

```
.pipelines/templates/
├── OneBranch.Template.yml          ← Master template (PR + Official)
├── OneBranch.Variables.yml         ← Shared variables (ACR names, connections, container specs)
├── BuildTestPublishLinux.yml       ← Linux build/test/publish
├── BuildTestPublishWindows.yml     ← Windows build/test/publish
├── BuildApps.yml                   ← Test app builds
├── GoBuildAndTest.yml              ← Go build & test
├── ValidateADRs.yml                ← Architecture Decision Record validation
├── RunMutationTestingDiff.yml      ← Stryker mutation testing
├── WorkloadComponentImages.yml     ← Container image specifications
├── AOS-components/                 ← AOS Docker image build/push/replicate
├── aspire/                         ← Aspire integration test (KIND cluster)
├── cluster/                        ← Cluster lifecycle (bootstrap, delete, SDP, EV2 deploy)
└── helm-charts/                    ← Helm chart copy, push to ACR
```

### 2.5 Multi-Cloud Container Replication

The pipeline supports **8 Azure Container Registries** across clouds:

| ACR | Environment |
|-----|-------------|
| `idk8sacrdev` | DEV |
| `idk8sacrtest` | TEST |
| `idk8sacrppe` | PPE |
| `iamkubernetesprod` | PROD (Public) |
| `iamkubernetesff` | Fairfax (Gov) |
| `iamkubernetesmc` | Mooncake (China) |
| `containerreplicationexwest` | USNat (via Image Teleport) |
| `containerreplicationrxeast` | USSec (via Image Teleport) |

Plus a dedicated `skylarcagentacr` for Skylarc agent images.

### 2.6 Key Pipeline Observations

- **SDP Integration**: Cluster Release uses EV2 Managed SDP with configurable rollout types (Normal: 20-hour bake, Emergency: 6-hour, NoDelay)
- **MSPKI Migration**: Active migration to MSPKI code-signing certificates (`ONEBRANCH_MAP_MSPKI_KEYCODE: true`)
- **Aspire Testing**: KIND-based integration tests using .NET Aspire for both AOS and Fleet Manager
- **Third-Party Tool Packaging**: Custom NuGet packaging for Conftest, Helm, Kubectl, LogMonitor, Notation
- **Network Isolation**: Uses KS1 network for Windows builds to allow GitHub/NuGet connections (known incident reference)
- **Security Scanning**: CodeQL 3000 with TSA bug filing, BinSkim (pinned v4.4.2), DevSkim, CredScan, PoliCheck

---

## 3. Branching & Versioning Strategy

### 3.1 Branch Inventory

**Total branches observed: 263+**

| Category | Pattern | Count (est.) | Examples |
|----------|---------|-------------|----------|
| Main | `main` | 1 | `refs/heads/main` |
| User feature | `{username}/{feature}` | ~120 | `andreyn/update-all-DUs`, `janholcapek/nha-mem-leak` |
| Dev branches | `dev/{username}/{feature}` | ~35 | `dev/kakonaka/dsmsmetric`, `dev/lenanguyenvo/enable-rc` |
| Dependabot | `dependabot/*` | ~10 | `dependabot/nuget/...`, `dependabot/docker/...`, `dependabot/go_modules/...` |
| Hotfix | `hotfix/{version}` | ~8 | `hotfix/2.0`, `hotfix/v3.6`, `hotfix/v4.2` |
| Release | `release/*` | ~3 | `release/cluster/4.2`, `release/v0.4` |
| Copilot SWE | `copilot/swe-*` | ~9 | `copilot/swe-wi3326052-d5768` |
| User prefix | `user/{username}/*` | ~20 | `user/crtreasu/skills`, `user/mtrochesset/docs` |
| Revert | `*-revert-from-main` | ~3 | `5a2b1037-revert-from-main` |
| Legacy azure-pipelines | `azure-pipelines*` | 3 | `azure-pipelines`, `azure-pipelines-2` |

### 3.2 Branch Hygiene Assessment

⚠️ **Concern: 263+ branches is excessive.** Many appear stale (e.g., `vanilla`, `workshops`, `newpipeline`, `poc-bicep-buildout`). Naming conventions are inconsistent:
- Some use `{username}/{feature}` (good)
- Some use `dev/{username}/{feature}` (also good, but different)
- Some have no namespace at all (`ipv6`, `vanilla`, `invDrift`)

### 3.3 Versioning Strategy (GitVersion.yml)

```yaml
mode: ContinuousDeployment
branches:
  master:              # regex: (master|main)
    increment: Minor   # → 1.x.0-alpha.{n}
    tag: alpha
  feature:             # regex: features?[/-]
    tag: f-{BranchName}
  hotfix:              # regex: hotfix(es)?[/-]
    increment: Patch   # → 1.0.x-hotfix.{n}
    tag: hotfix
```

**Observations:**
- Uses SemVer with ContinuousDeployment mode
- Main branch produces `-alpha` pre-release tags with minor increments
- Hotfix branches produce `-hotfix` tags with patch increments
- Feature branches get branch-name-based tags
- Currently at .NET SDK 10.0.103 (global.json)

### 3.4 Branch Policies

From `.azuredevops/policies/approvercountpolicy.yml`:
- **Minimum 1 approver** required on `main`
- Creator vote does **not** count
- Last pusher **cannot** self-approve
- Requires vote on last iteration
- Source push does **not** reset votes (but reset rejections on push is off)

---

## 4. Commit Activity Analysis

### 4.1 Dataset

Analyzed the **50 most recent commits** spanning **2026-02-28 to 2026-03-02** (approximately 3 days).

### 4.2 Contributor Activity

| Contributor | Commits | Focus Areas |
|------------|---------|-------------|
| Jan Holcapek | 14 | NHA memory leak fix, Code Governance (OpenTelemetry), CG compliance |
| Eric Hong | 10 | Fleet Manager refactoring (DU/SU naming), remove JobsSdkData dependency |
| Filip Krestan | 4 | Cluster config (etcd disk size), reverts |
| Andrey Noskov | 4 | Fleet Manager (DU handling, reconciler, inventory) |
| Craig Treasure | 2 | Scale unit onboarding (LinuxApp CUS V3) |
| Tianyu Wang (IDENTITY) | 3 | Test app updates, region short codes |
| Dependabot | 2 | Security: OpenTelemetry SDK bump |
| James Fletcher | 2 | Copilot skill for SU audit |
| Maxim Sorochin | 1 | ADR updates |
| Talat Ahmed | 1 | Service tag validation skip |

**~14 unique contributors** in a 3-day window = **very active** development team.

### 4.3 Conventional Commit Usage

| Type | Count | % of Total |
|------|-------|-----------|
| `fix(...)` | ~12 | ~24% |
| `feat(...)` | ~6 | ~12% |
| `chore(...)` | ~3 | ~6% |
| `refactor(...)` | ~2 | ~4% |
| `ci(...)` | ~1 | ~2% |
| No conventional format | ~26 | ~52% |

**~48% of commits use conventional commit format.** The team is adopting it but not yet fully consistent. Scoped prefixes like `(FM)`, `(NHA)`, `(clusters)`, `(bicep)`, `(ci)` are well-used, indicating good component awareness.

### 4.4 Change Hotspots

| Area | Activity Level | Notes |
|------|---------------|-------|
| Fleet Manager (`src/csharp/fleet-manager/`) | 🔴 Very High | DU/SU refactoring, NHA memory fix, reconciler updates |
| Cluster Configs (`ev2/clusters-sdp/`) | 🟡 High | etcd disk size changes, scale unit onboarding |
| Test Apps | 🟡 Medium | Region support, script updates |
| Pipeline configs | 🟢 Low-Medium | MSPKI migration, pipeline name ADR |
| Go modules | 🟢 Low | OpenTelemetry SDK bump (security) |

---

## 5. PR Activity Analysis

### 5.1 Dataset

Analyzed the **30 most recent PRs** spanning **2026-02-24 to 2026-03-02** (~7 days).

### 5.2 PR Status Distribution

| Status | Count | % |
|--------|-------|---|
| Completed | 17 | 57% |
| Active | 12 | 40% |
| Abandoned | 1 | 3% |

### 5.3 PR Velocity

- **30 PRs in ~7 days** = **~4.3 PRs/day**
- **Completion rate**: 57% within the window (many Active PRs are very recent)
- **Merge turnaround**: Most PRs complete within 1-2 days based on creation-to-completion dates

### 5.4 PR Authors

| Author | PR Count | Notable |
|--------|----------|---------|
| Andrey Noskov | 4 | Fleet Manager feature work |
| Filip Krestan | 3 | Cluster config, cleanup |
| Tianyu Wang (IDENTITY) | 3 | Skylarc, test apps |
| Mariia Kotliarevskaia | 3 | Release 5.1, bicep cleanup |
| Eric Hong | 2 | DU/SU refactoring |
| Craig Treasure | 1 | Scale unit onboarding |
| James Fletcher | 1 | Copilot skill addition |
| Dependabot | 1 | Security dependency update |
| Jan Holcapek | 1 | NHA memory leak |
| GitHub Copilot | 1 | BouncyCastle investigation (abandoned) |
| Maxim Sorochin | 1 | CI: MSPKI signing migration |

### 5.5 PR Patterns

- **Conventional titles**: Good adoption (~60% use `feat:`, `fix:`, `chore:`, `refactor:`, `ci:` prefixes)
- **Scoped changes**: Most PRs are well-scoped to specific components (FM, clusters, bicep, ci)
- **Dependabot**: Active for NuGet, Docker, Go modules with auto-complete enabled
- **Copilot SWE Agent**: Active with 9+ branches, 1 abandoned PR (BouncyCastle investigation)
- **PR Copilot**: Auto-review (3 max comments), auto-description, auto-PR-quantifier classification

---

## 6. Documentation Inventory & Quality

### 6.1 Documentation File Inventory

| Path | Type | Status |
|------|------|--------|
| `/README.md` | Root readme | ✅ Present — Covers repo structure, links to wiki |
| `/CONTRIBUTING.md` | Contribution guide | ⚠️ **Boilerplate** — Generic template, not customized |
| `/docs/versioning.md` | Versioning docs | ✅ Present |
| `/docs/1es-hosted-pools.md` | 1ES pool docs | ✅ Present |
| `/docs/accessing-ppe-cluster-from-saw.md` | Operations | ✅ Present |
| `/docs/add-new-workload-containers.md` | How-to | ✅ Present |
| `/docs/azure-pipelines-documentation.md` | Pipeline docs | ✅ Present |
| `/docs/bastion.md` | Bastion access | ✅ Present |
| `/docs/container-image-ecosystem.md` | Container docs | ✅ Present |
| `/docs/management-plane/` (9 files) | MP documentation | ✅ **Good coverage** |
| `/docs/component-deployer/` (7 files) | Component deployer | ✅ **Good coverage** |
| `/docs/adr/` (14 files) | Architecture Decisions | ✅ **Active** (ADR-0001 through 0012) |
| `/docs/kubescape/` (2 files) | Security scanning | ✅ Present |
| `/docs/aos/` (1 file) | AOS failure modes | ⚠️ Minimal |

### 6.2 Architecture Decision Records (ADRs)

| ADR | Title | Area |
|-----|-------|------|
| 0001 | Record architecture decisions | Meta |
| 0002 | IMDS exception for SEC | Security |
| 0003 | Use platform-managed certs for partners | Security |
| 0004 | Deployment process for cluster release candidates | CI/CD |
| 0005 | MP cluster release pipeline | CI/CD |
| 0006 | Cluster orchestrator | Architecture |
| 0007 | In-cluster TLS certificate management | Security |
| 0007 | Tag-based deployment process for cluster RCs | CI/CD (⚠️ duplicate number!) |
| 0008 | Release branch process for cluster configs | Branching |
| 0009 | SKU selection | Infrastructure |
| 0010 | VMSS identity DSMS certificate and DSTS SCI creation | Security |
| 0011 | Wireserver file proxy | Architecture |
| 0012 | Scheduled event approval criteria for K8s nodes | Operations |

⚠️ **ADR-0007 has two entries** with different titles — numbering collision.

### 6.3 Management Plane Documentation

Comprehensive coverage including:
- Architecture & Overview
- Authentication & Authorization
- Auditing API Requests
- Cluster Buildout in New Region
- Local Development Guide
- Pipeline Documentation
- Tech Debt & Vision
- SU-API Onboarding (2 docs)

### 6.4 GitHub Copilot Instructions

Excellent `/.github/copilot-instructions.md` providing:
- Repository overview and key technologies
- Project structure guide
- C# development guidelines
- Documentation best practices (XML comments)
- Links to language-specific instruction files (`csharp.instructions.md`, `powershell.instructions.md`)

### 6.5 Documentation Quality Assessment

| Aspect | Grade | Notes |
|--------|-------|-------|
| README.md | B | Good structure overview but links to external wiki; could include getting started |
| CONTRIBUTING.md | D | **Boilerplate template** — not customized for this repo. Contains placeholder text |
| ADRs | B+ | Active, well-structured, but duplicate numbering issue |
| Management Plane | A- | Comprehensive coverage |
| Component Deployer | A- | Good with pipeline docs, release guide, state management |
| Pipeline Documentation | B | Present but may lag behind actual pipeline changes |
| AOS Documentation | D | Only 1 file (failure modes) |
| Fleet Manager | C | Scattered across FM SDK, no centralized doc |
| Getting Started / Onboarding | F | **No onboarding guide exists** |
| API Documentation | C | SU-API onboarding exists but limited |

### 6.6 Linting & Quality Tools for Docs

| Tool | Config | Status |
|------|--------|--------|
| Vale | `.vale.ini` | ✅ Configured — Microsoft, Joblint, proselint, write-good styles |
| markdownlint-cli2 | `.markdownlint-cli2.jsonc` | ✅ Configured — line-length disabled, inline config disabled |
| cspell | `.cspell.json` | ✅ Configured — custom words for domain terms |
| ADR tooling | `adr.config.json` | ✅ Configured — template + path |

---

## 7. Repository Configuration & Tooling

### 7.1 Ownership & Service Tree

| Config | Value |
|--------|-------|
| `owners.txt` | `ip-runtime-k8s` (team) |
| `es-metadata.yml` | Service Tree ID: `5cee095b-4378-4308-b09d-06b70ae9ff8a` |
| Area Path | `Engineering\ECS\Runtime\K8S` |
| TSA CodeBase | `idk8s-infrastructure` |
| TSA Notification | `ip-runtime@microsoft.com` |

### 7.2 PR Automation Stack

| Tool | Config File | Capability |
|------|-------------|------------|
| **PR Copilot** | `.azuredevops/policies/pullrequestcopilot.yaml` | Auto-review (3 comments max), auto-description, auto-PR-quantifier |
| **PR Size Classification** | `.azuredevops/policies/pr-size-classification.yaml` | AI-powered PR size classification using DeepPrompt/Semantic Kernel |
| **PR Quantifier** | `/prquantifier.yaml` | Excludes .gitignore, .sln, .props, lock files, .md, go.sum |
| **MerlinBot Nitpicker** | `.config/merlinbot/nitpicker.yaml` | Blocking comment on cluster config PRs requiring full checklist |
| **MerlinBot Reviewer Recommender** | `.config/merlinbot/reviewerrecommender.yaml` | Auto-adds 2 recommended reviewers |
| **MerlinBot Teams Nudge** | `.config/merlinbot/teamsnudge.yml` | Nudges to Pull Requests Teams channel |
| **Copilot SWE Preferences** | `.azuredevops/policies/copilot-preferences.yml` | Copilot PRs created as drafts |
| **PR Template** | `.azuredevops/pull_request_template.md` | Work item link + "What is being changed and why?" |
| **Approver Count** | `.azuredevops/policies/approvercountpolicy.yml` | Min 1 approver, no self-approval |
| **1ES Pipeline Autobaselining** | `.config/1espt/PipelineAutobaseliningConfig.yml` | Automatic SDL baseline management |
| **Code Coverage** | `azurepipelines-coverage.yml` | 80% diff coverage target, comments on PRs |

### 7.3 Dependabot Configuration

```yaml
package-ecosystem: nuget
target-branch: main
directories: [/src/csharp]
auto-complete: true
open-pull-requests-limit: 3
ignore:
  - dependency: "Microsoft.R9*" (major/minor only)
```

Also handles Docker and Go module updates via additional Dependabot branches.

### 7.4 Component Governance (cgmanifest.json)

Tracked third-party components:
- Regal v0.38.1 (OPA/Rego linter) — dev dependency
- Helm v3.20.0
- Conftest v0.63.0
- ShellCheck v0.9.0 — dev dependency
- Vale v3.4.1 — dev dependency
- Node Problem Detector v0.8.20
- Windows Container Tools v1.1
- Notation v1.3.2 — dev dependency

### 7.5 GitHub Copilot Skills (10 Custom Skills)

| Skill | Purpose |
|--------|---------|
| `get-kvw-recent-commits` | Get recent KeyVault Watcher commits |
| `get-kvw-version` | Get KeyVault Watcher version |
| `get-sampleservice-kvw-version` | Get sample service KVW version |
| `onboard-scale-units` | Onboard new scale units |
| `query-active-dependabot-prs` | Query active Dependabot PRs |
| `query-completed-dependabot-prs` | Query completed Dependabot PRs |
| `query-container-vulnerabilities` | Query container vulnerabilities |
| `resolve-image-tags` | Resolve image tags |
| `resolve-workload-image-tags` | Resolve workload image tags |
| `update-kvw-version` | Update KeyVault Watcher version |

Plus an **agent** (`upgrade-workload-containers.agent.md`) and a **prompt** (`ev2-specification-for-new-cluster.prompt.md`).

---

## 8. Code Quality Infrastructure

### 8.1 Security Scanning (SDL)

| Tool | Config | Breaking? | Notes |
|------|--------|-----------|-------|
| **CodeQL** | Pipeline-integrated | ✅ Yes (TSA for CodeQL 3000) | Compiled language analysis |
| **BinSkim** | Pipeline + `.gdn/global.gdnsuppress` | ✅ Yes | Pinned to v4.4.2 (workaround for OBP issue) |
| **CredScan** | Pipeline-integrated | ✅ Yes | 2 suppressed test credentials |
| **PoliCheck** | Pipeline-integrated | ✅ Yes | Always breaks build |
| **DevSkim** | `.config/devskim-options.json` | ✅ Yes | Critical + Important severities |
| **Component Governance** | Pipeline (`failOnAlert: true`) | ✅ Yes | Fails on High alerts |
| **Anti-Malware** | Pipeline (test apps) | ✅ Yes | Scan output directory only |
| **Roslyn Analyzers** | Pipeline | ✅ Yes | `ob_sdl_roslyn_break: true` |
| **CloudVault** | Pipeline (Official) | ✅ Upload | Separate stage for Linux + Windows drops |

### 8.2 Code Quality Tools

| Tool | Config | Scope |
|------|--------|-------|
| **PSScriptAnalyzer** | `PSScriptAnalyzerSettings.psd1` | 50+ rules including security (no plaintext passwords, no hardcoded credentials) |
| **Regal** | `.regal/config.yaml` | OPA/Rego linting — v0.5.0 baseline with newer rules at warning level |
| **ShellCheck** | `.build/shellcheck.sh` | Bash script linting |
| **EditorConfig** | `.editorconfig` | Cross-editor formatting (C#: 4-space, JSON: 2-space, Rego: tabs) |
| **Stryker** | `scripts/RunStrykerMutantTesting.ps1` | .NET mutation testing (diff-based in PRs) |
| **Vale** | `.vale.ini` + styles | Prose linting (Microsoft, Joblint, proselint, write-good) |
| **cspell** | `.cspell.json` | Spell checking with domain-specific words |
| **markdownlint** | `.markdownlint-cli2.jsonc` | Markdown formatting rules |

### 8.3 Build Technology Stack

| Technology | Version | Usage |
|------------|---------|-------|
| .NET SDK | 10.0.103 | Primary application framework |
| Go | 1.25.1 | Pod Health API Controller |
| Mage | 1.15.0 | Go build automation (magefiles/) |
| Helm | 3.20.0 | Kubernetes package management |
| Conftest | 0.63.0 | Policy-as-code testing |
| Notation | 1.3.2 | Container image signing |
| Linux Build Image | Azure Linux 3.0 | Build container |
| Windows Build Image | LTSC 2022 + VS 2022 | Build container |

### 8.4 GDN Suppressions

The `.gdn/global.gdnsuppress` file contains **13 suppressions**, all for:
- **CredScan** (2): Test private keys/certificates in Go test data
- **BinSkim** (11): External binaries from Geneva Monitoring Agent (7zr.exe, fluent-bit.exe, procdump64.exe, GoContainerClient.exe, etc.)

All suppressions include justifications and appear legitimate.

---

## 9. Copilot & AI Integration

This repository has **exceptional** AI/Copilot integration:

### 9.1 Copilot Configuration

| Feature | Status | Details |
|---------|--------|---------|
| Copilot Instructions | ✅ Active | Comprehensive repo-context instructions in `.github/copilot-instructions.md` |
| Language Instructions | ✅ Active | C# (`csharp.instructions.md`) and PowerShell (`powershell.instructions.md`) |
| Custom Skills | ✅ Active | 10 operational skills for version management, vulnerability queries, PR management |
| Custom Agents | ✅ Active | Workload container upgrade agent |
| Custom Prompts | ✅ Active | EV2 specification prompt for new clusters |
| Copilot SWE | ✅ Active | 9+ branches from `copilot/swe-*` prefix; draft PR mode enabled |
| PR Copilot Review | ✅ Active | Auto-review with 3 max comments, path filters for config files |
| AI PR Size Classification | ✅ Active | Semantic Kernel-powered PR quantifier with DeepPrompt |

### 9.2 Assessment

This is one of the most AI-integrated repos in the analysis scope. The team has invested in:
- Contextual instructions for different languages
- Operational skills that automate common tasks (version queries, vulnerability checks, image tag resolution)
- Prompt engineering for repetitive tasks (EV2 specs for new clusters)
- SWE agent for automated work item resolution
- AI-powered code review with path-based filtering

---

## 10. Repo Health Score

### Scoring Breakdown

| Category | Score | Weight | Weighted |
|----------|-------|--------|----------|
| CI/CD Pipeline Maturity | 9/10 | 20% | 1.80 |
| Code Quality Tooling | 9/10 | 15% | 1.35 |
| Security Scanning | 9/10 | 15% | 1.35 |
| Documentation Quality | 5/10 | 15% | 0.75 |
| Branch Hygiene | 4/10 | 10% | 0.40 |
| PR Automation | 9/10 | 10% | 0.90 |
| Versioning Strategy | 7/10 | 5% | 0.35 |
| AI/Copilot Integration | 10/10 | 5% | 0.50 |
| Contributor Activity | 8/10 | 5% | 0.40 |
| **TOTAL** | | **100%** | **7.80/10** |

### **Overall Health Score: 7.8 / 10** ⭐⭐⭐⭐

**Assessment**: This is a **healthy, well-instrumented production infrastructure repository** with industry-leading CI/CD practices, comprehensive security scanning, and exceptional AI integration. The main gaps are in documentation quality (boilerplate CONTRIBUTING.md, missing onboarding guide, sparse AOS docs) and branch hygiene (263+ branches, inconsistent naming).

---

## 11. Recommendations

### 🔴 Critical (Fix Soon)

1. **Rewrite CONTRIBUTING.md** — Current file is an uncustomized template with placeholder text ("project-name", "contact-method"). Replace with actual contribution guidelines, build instructions, and test requirements specific to this repo.

2. **Create an Onboarding Guide** — No `docs/getting-started.md` or developer setup guide exists. New team members have no clear path to:
   - Set up local development environment
   - Run builds and tests locally
   - Understand the repo structure
   - Deploy to dev clusters

3. **Fix ADR-0007 Numbering Collision** — Two different ADRs share number 0007 ("In-cluster TLS certificate management" and "Tag-based deployment process for cluster RCs"). Renumber one.

### 🟡 Important (Plan for Next Sprint)

4. **Branch Cleanup Campaign** — Purge the 263+ branches. Recommend:
   - Delete all branches older than 90 days with no recent commits
   - Delete legacy branches (`vanilla`, `workshops`, `newpipeline`, `poc-bicep-buildout`, etc.)
   - Enforce a naming convention: `{username}/{feature-description}` or `{type}/{username}/{feature}`

5. **Standardize Conventional Commits** — Currently at ~48% adoption. Consider:
   - Adding a commit-lint check to PR validation pipeline
   - Documenting the convention in CONTRIBUTING.md
   - Using `commitlint` or similar tooling

6. **Expand AOS Documentation** — Only 1 file (`aos-failure-modes.md`) covers AOS. Given AOS has dedicated Aspire tests and pipeline templates, it deserves more documentation.

7. **Add Fleet Manager Central Documentation** — Fleet Manager is the most active area of the codebase but has no dedicated documentation directory. Create `docs/fleet-manager/` with architecture, API reference, and operational guides.

### 🟢 Nice to Have

8. **Dependabot Coverage Gap** — Dependabot is configured only for NuGet in `/src/csharp`. Consider adding:
   - Go modules ecosystem (currently handled ad-hoc)
   - Docker base image updates (partially present)
   - Helm chart dependencies

9. **PR Template Enhancement** — Current template only asks for work item link and change description. The MerlinBot nitpicker adds extensive requirements for cluster configs, but the base template could include:
   - Testing evidence section
   - Risk assessment section
   - Rollback procedures section

10. **Code Coverage Enforcement** — The `azurepipelines-coverage.yml` targets 80% diff coverage. Consider:
    - Adding a baseline coverage target (not just diff)
    - Publishing coverage trends over time
    - Breaking on significant coverage drops

11. **Pipeline Documentation Auto-Generation** — With 24+ pipeline definitions, consider generating a pipeline dependency graph automatically to keep `docs/azure-pipelines-documentation.md` current.

12. **Remove Stale Copilot SWE Branches** — The 9 `copilot/swe-*` branches appear to be from automated work item resolution attempts. Clean up completed or abandoned ones.

---

*Analysis compiled with Borg-enhanced precision. Resistance to documentation improvement is futile.*  
*— Seven of Nine, Tertiary Adjunct of Unimatrix Zero-One*
