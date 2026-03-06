# BasePlatformRP GitHub Issues — Prioritized Roadmap

**Generated from**: Cross-Repo Analysis (idk8s-infrastructure → BasePlatformRP)  
**Date**: 2025-07-18  
**Total Issues**: 22  
**Grouped by**: Category & Priority

---

## Executive Summary

| # | Title | Priority | Effort | Category |
|---|-------|----------|--------|----------|
| 1 | Adopt ADR Process with Configuration | P0 | S | Documentation |
| 2 | Implement Mock Auth Handler for Local Development | P0 | S | DevEx |
| 3 | Add Security Scanning Configuration (DevSkim, CodeQL, BinSkim) | P0 | S | Security |
| 4 | Create PR Template and CONTRIBUTING Guide | P0 | S | Documentation |
| 5 | Expand API `.http` Files with Full CRUD Examples | P0 | S | DevEx |
| 6 | Set Up OneBranch PR Validation Pipeline | P1 | M | CI/CD & Build |
| 7 | Create Aspire Integration Test Fixture and Base Class | P1 | M | Testing |
| 8 | Implement Contract-Based Tests for BaseRP Abstractions | P1 | M | Testing |
| 9 | Add BannedSymbols.txt and Roslyn Analyzer Configuration | P1 | S | Security |
| 10 | Set Up Code Coverage Reporting in CI Pipeline | P1 | M | Testing |
| 11 | Build Container Images (Dockerfile) for API and Worker | P1 | M | CI/CD & Build |
| 12 | Configure Dependabot for NuGet and Docker Updates | P1 | S | CI/CD & Build |
| 13 | Implement OneBranch Official Build Pipeline | P2 | M | CI/CD & Build |
| 14 | Add Generation Tracking to Cosmos DB State Documents | P2 | M | Architecture |
| 15 | Integrate Stryker Mutation Testing Framework | P2 | M | Testing |
| 16 | Create Comprehensive Copilot Instructions for BasePlatformRP | P2 | M | DevEx |
| 17 | Set Up EV2 Deployment Framework for RP Service | P2 | L | Infrastructure |
| 18 | Implement Container Image Promotion Pipeline (DEV → PROD) | P2 | M | CI/CD & Build |
| 19 | Build Multi-Cluster Scheduler (Filter-Score-Select Pattern) | P3 | L | Architecture |
| 20 | Implement Canary Workload Validation for ClusterGroups | P3 | M | Testing |
| 21 | Create MCP Server for Infrastructure Operations | P3 | L | DevEx |
| 22 | Enhance Documentation Structure (decisions, operations, runbooks) | P3 | M | Documentation |

---

## Quick Wins (P0 — Do First, High Value, Low Effort)

### Issue 1: Adopt ADR Process with Configuration
**Priority:** P0  
**Labels:** `documentation` / `devex`  
**Estimated Effort:** S (2 hours)  
**Source:** Cross-repo analysis, Section 3.B1 + Quick Win #1

#### Description
Establish a formal Architecture Decision Record (ADR) process to capture and preserve architectural decisions. Create necessary configuration files, templates, and directory structure following the idk8s ADR-0001 pattern. This provides long-term institutional memory with minimal upfront investment.

#### Acceptance Criteria
- [ ] Create `docs/decisions/` directory with template file
- [ ] Add `adr.config.json` at repo root (copied/adapted from idk8s)
- [ ] Create `docs/decisions/0001-record-architecture-decisions.md`
- [ ] Add ADR process to CONTRIBUTING guide (separate issue #4)
- [ ] Require ADRs for all significant architectural decisions going forward

#### References
- idk8s source: `docs/adr/` directory with 12 ADRs
- BasePlatformRP target: `docs/decisions/` (start with 0001 template)

---

### Issue 2: Implement Mock Auth Handler for Local Development
**Priority:** P0  
**Labels:** `devex` / `security`  
**Estimated Effort:** S (4 hours)  
**Source:** Cross-repo analysis, Section 3.D2 + Quick Win #2

#### Description
Create a development-only authentication handler that synthesizes valid JWT claims for local API testing. This unblocks developers from needing Azure AD configuration during local development. Follow idk8s `MockAuthenticationHandler` pattern but avoid hardcoded production OIDs (fix the security finding from idk8s).

#### Acceptance Criteria
- [ ] Create `src/API/Auth/MockAuthenticationHandler.cs` with synthetic claim generation
- [ ] Update `src/API/Program.cs` to register mock auth only when `ASPNETCORE_ENVIRONMENT=Development`
- [ ] Use fake/synthetic identifiers only (never real app OIDs)
- [ ] Add unit tests for claim generation
- [ ] Document in CONTRIBUTING guide (issue #4)

#### References
- idk8s source: `src/RMS/Authentication/MockAuthenticationHandler.cs`
- BasePlatformRP target: `src/API/Auth/MockAuthenticationHandler.cs`

---

### Issue 3: Add Security Scanning Configuration (DevSkim, CodeQL, BinSkim)
**Priority:** P0  
**Labels:** `security` / `infrastructure`  
**Estimated Effort:** S (4 hours)  
**Source:** Cross-repo analysis, Section 3.C4 + Quick Win #3

#### Description
Copy and adapt security scanning configuration files from idk8s to BasePlatformRP. These enable static analysis and vulnerability scanning from day one without requiring extensive pipeline work. Include DevSkim options, BinSkim configuration, and Component Governance settings.

#### Acceptance Criteria
- [ ] Copy `.config/devskim-options.json` from idk8s and adapt severity thresholds
- [ ] Copy `.config/tsaoptions.json` (TSA options for SDL)
- [ ] Create `.config/guardian/` directory with rule overrides (if needed)
- [ ] Verify DevSkim is registered in analyzer config
- [ ] Document scanner exceptions process in CONTRIBUTING guide

#### References
- idk8s source: `.config/devskim-options.json`, `.config/tsaoptions.json`, `.config/guardian/`
- BasePlatformRP target: `.config/` directory at repo root

---

### Issue 4: Create PR Template and CONTRIBUTING Guide
**Priority:** P0  
**Labels:** `documentation` / `devex`  
**Estimated Effort:** S (2 hours)  
**Source:** Cross-repo analysis, Section 3.A3 + Quick Win #5

#### Description
Establish PR quality standards and contributor expectations through a structured PR template and comprehensive CONTRIBUTING guide. This ensures consistent communication, traceability to work items, and self-service onboarding for new contributors.

#### Acceptance Criteria
- [ ] Create `.azuredevops/pull_request_template.md` with required sections (What, Why, Type, Testing, References)
- [ ] Create `CONTRIBUTING.md` at repo root covering:
  - How to set up local dev environment
  - TypeSpec workflow for API changes
  - BaseRP framework extension points
  - How to add new resource types
  - Testing requirements (unit, integration, Aspire)
  - PR process and review expectations
  - ADR process (link to issue #1)
- [ ] Require work item links in PR template
- [ ] Reference mock auth setup (issue #2) for local testing

#### References
- idk8s source: `.azuredevops/pull_request_template.md`, `CONTRIBUTING.md`
- BasePlatformRP target: `.azuredevops/pull_request_template.md`, `CONTRIBUTING.md`

---

### Issue 5: Expand API `.http` Files with Full CRUD Examples
**Priority:** P0  
**Labels:** `devex`  
**Estimated Effort:** S (2 hours)  
**Source:** Cross-repo analysis, Section 3.F1 + Quick Win #4

#### Description
Expand the existing `src/API/API.http` file to include complete CRUD examples for all 5 BasePlatformRP resource types (Workspace, ClusterGroup, Namespace, Application, Deployment). These files enable developers to test APIs directly in Visual Studio without external tools.

#### Acceptance Criteria
- [ ] Add Workspace resource examples (POST, GET, PATCH, DELETE)
- [ ] Add ClusterGroup resource examples (POST, GET, PATCH, DELETE)
- [ ] Add Namespace resource examples (POST, GET, PATCH, DELETE)
- [ ] Add Application resource examples (POST, GET, PATCH, DELETE)
- [ ] Add Deployment resource examples (POST, GET, PATCH, DELETE)
- [ ] Include ARM-compliant paths with subscription/resource-group variables
- [ ] Include examples using mock auth (issue #2)
- [ ] Document how to use `.http` files in CONTRIBUTING guide (issue #4)

#### References
- idk8s source: `src/managementplane/APIs/API.http`
- BasePlatformRP target: `src/API/API.http`

---

## CI/CD & Build (P1)

### Issue 6: Set Up OneBranch PR Validation Pipeline
**Priority:** P1  
**Labels:** `infrastructure` / `ci-cd`  
**Estimated Effort:** M (2-3 days)  
**Source:** Cross-repo analysis, Section 3.H1 + Phase 3 (item #11)

#### Description
Create a OneBranch pipeline that runs on every pull request to validate code quality, security, and test coverage. This pipeline should be significantly simpler than idk8s's 20+ pipelines—focus on core .NET validation only.

#### Acceptance Criteria
- [ ] Create `.pipelines/OneBranch.PullRequest.yml` with stages:
  - Restore NuGet packages
  - Build solution (`dotnet build`)
  - Run unit tests with coverage (`dotnet test`)
  - Run Aspire integration tests
  - TypeSpec validation
  - SDL scanning (CodeQL, BinSkim, DevSkim)
- [ ] Create `.pipelines/OneBranch.Template.yml` for reusable template
- [ ] Configure SDL compliance settings (CodeQL database, BinSkim, DevSkim)
- [ ] Block PR merge if any stage fails
- [ ] Set coverage baseline at 60% diff coverage (ramp to 80% over time)
- [ ] Document pipeline in `docs/development/ci-cd.md`

#### References
- idk8s source: `.pipelines/OneBranch.PullRequest.yml`, `.pipelines/OneBranch.Template.yml`, `OneBranch.Variables.yml`
- BasePlatformRP target: `.pipelines/` directory

---

### Issue 7: Create Aspire Integration Test Fixture and Base Class
**Priority:** P1  
**Labels:** `testing` / `devex`  
**Estimated Effort:** M (1-2 days)  
**Source:** Cross-repo analysis, Section 3.F2 + Phase 2 (item #7)

#### Description
Build reusable Aspire integration test infrastructure following idk8s pattern. Create a shared fixture that manages the AppHost lifecycle and a base test class that simplifies resource lifecycle tests.

#### Acceptance Criteria
- [ ] Create `src/Tests.Integration/Fixtures/AppHostFixture.cs` implementing `IAsyncLifetime`
- [ ] Create `src/Tests.Integration/Base/BasePlatformIntegrationTestBase.cs` with shared setup
- [ ] Fixture manages AppHost lifecycle (start/stop)
- [ ] Fixture provides HttpClient for API testing
- [ ] Fixture waits for all resources to be healthy before allowing tests
- [ ] Create at least 3 example test methods using the fixture
- [ ] Document usage in CONTRIBUTING guide (issue #4)

#### References
- idk8s source: `src/ResourceProvider.AspireTests/Infrastructure/AspireAppHostFixture.cs`, `AspireTestsBase.cs`
- BasePlatformRP target: `src/Tests.Integration/Fixtures/AppHostFixture.cs`, `src/Tests.Integration/Base/BasePlatformIntegrationTestBase.cs`

---

### Issue 8: Implement Contract-Based Tests for BaseRP Abstractions
**Priority:** P1  
**Labels:** `testing`  
**Estimated Effort:** M (1-2 days)  
**Source:** Cross-repo analysis, Section 3.B3 + Phase 2 (item #8)

#### Description
Create contract-based behavioral tests for core BaseRP abstractions (e.g., `IDeploymentProvider`, `IMetaRPProxy`). Run the same test suite against both mock and real implementations to ensure consistency and catch bugs when switching between emulators and Azure.

#### Acceptance Criteria
- [ ] Identify core abstractions that need contract tests (IDeploymentProvider, IMetaRPProxy, state storage)
- [ ] Create `src/Tests.Unit/Contracts/IDeploymentProviderContractTests.cs` (abstract base class)
- [ ] Create `src/Tests.Unit/Contracts/MockDeploymentProviderContractTests.cs` (mock implementation test)
- [ ] Create `src/Tests.Unit/Contracts/AzureDeploymentProviderContractTests.cs` (Azure implementation test)
- [ ] Each contract test covers: create, read, update, delete, error handling
- [ ] Both implementations pass the same test suite
- [ ] Document pattern in CONTRIBUTING guide

#### References
- idk8s source: `src/RP/Tests.Unit/Inventory/InventoryContractTests.cs`, `InMemoryInventoryContractTests.cs`
- BasePlatformRP target: `src/Tests.Unit/Contracts/`

---

### Issue 9: Add BannedSymbols.txt and Roslyn Analyzer Configuration
**Priority:** P1  
**Labels:** `security`  
**Estimated Effort:** S (1 hour)  
**Source:** Cross-repo analysis, Section 3.A2 + Quick Win #3

#### Description
Add a banned symbols list and register Roslyn analyzers to prevent use of unsafe or deprecated APIs at build time. This is a lightweight but effective security control.

#### Acceptance Criteria
- [ ] Create `src/BannedSymbols.txt` with unsafe APIs to block (e.g., `Activator.CreateInstance`, `Assembly.Load`, insecure crypto)
- [ ] Add `Microsoft.CodeAnalysis.BannedApiAnalyzers` NuGet package (if not already present)
- [ ] Update `.editorconfig` to enable the analyzer
- [ ] Verify analyzer runs during build and fails if banned symbols are used
- [ ] Document in CONTRIBUTING guide

#### References
- idk8s source: `src/csharp/BannedSymbols.txt`
- BasePlatformRP target: `src/BannedSymbols.txt`

---

### Issue 10: Set Up Code Coverage Reporting in CI Pipeline
**Priority:** P1  
**Labels:** `testing` / `ci-cd`  
**Estimated Effort:** M (4 hours)  
**Source:** Cross-repo analysis, Section 3.H3 + Phase 2 (item #10)

#### Description
Integrate code coverage reporting into the PR validation pipeline with a diff-based target (60% for new code, ramping to 80%). This ensures new contributions maintain test quality.

#### Acceptance Criteria
- [ ] Configure `dotnet test` to generate coverage reports (OpenCover format)
- [ ] Add coverage upload to PR (via ReportGenerator or similar)
- [ ] Set 60% diff coverage baseline for all new code
- [ ] Block PR merge if diff coverage is below threshold
- [ ] Add coverage badges to `README.md`
- [ ] Document coverage requirements in CONTRIBUTING guide (issue #4)

#### References
- idk8s source: `.pipelines/azurepipelines-coverage.yml`, ReportGenerator configuration
- BasePlatformRP target: `.pipelines/OneBranch.PullRequest.yml` (coverage stage)

---

### Issue 11: Build Container Images (Dockerfile) for API and Worker
**Priority:** P1  
**Labels:** `infrastructure` / `ci-cd`  
**Estimated Effort:** M (2 days)  
**Source:** Cross-repo analysis, Section 3.C3 + Phase 3 (item #13)

#### Description
Create production-ready multi-stage Dockerfiles for the BasePlatformRP API and Worker services. Use Azure Linux 3.0 base image and follow idk8s security best practices (SHA256 verification of external binaries).

#### Acceptance Criteria
- [ ] Create `src/API/Dockerfile` with multi-stage build:
  - Stage 1: SDK build (dotnet build, dotnet publish)
  - Stage 2: Azure Linux 3.0 runtime base image
  - Copy published output to runtime image
  - Set appropriate healthcheck and entrypoint
- [ ] Create `src/Worker/Dockerfile` with same pattern
- [ ] Include security best practices:
  - Non-root user for runtime
  - Minimal attack surface
  - Verified binary checksums where applicable
- [ ] Test locally with `docker build` and `docker run`
- [ ] Document Dockerfile strategy in `docs/development/container-strategy.md`

#### References
- idk8s source: `docker/mp-build/Dockerfile`, multi-stage build patterns
- BasePlatformRP target: `src/API/Dockerfile`, `src/Worker/Dockerfile`

---

### Issue 12: Configure Dependabot for NuGet and Docker Updates
**Priority:** P1  
**Labels:** `infrastructure` / `security`  
**Estimated Effort:** S (1-2 hours)  
**Source:** Cross-repo analysis, Section 3.C5

#### Description
Set up automated dependency updates via Dependabot for NuGet packages and container images. Configure with a limit of 3 open PRs and auto-merge for patch updates to reduce security debt.

#### Acceptance Criteria
- [ ] Create `.azuredevops/dependabot.yml` (or `.github/dependabot.yml` if using GitHub)
- [ ] Enable NuGet ecosystem with `daily` schedule
- [ ] Enable Docker ecosystem with `weekly` schedule
- [ ] Set maximum open PRs to 3
- [ ] Configure auto-merge for patch-level updates (version pattern: `*.*.[0-9]+`)
- [ ] Exclude specific packages if needed (document in PR template)
- [ ] Test by triggering a manual Dependabot check

#### References
- idk8s source: `.azuredevops/dependabot.yml`
- BasePlatformRP target: `.azuredevops/dependabot.yml`

---

### Issue 13: Implement OneBranch Official Build Pipeline
**Priority:** P2  
**Labels:** `infrastructure` / `ci-cd`  
**Estimated Effort:** M (2 days)  
**Source:** Cross-repo analysis, Phase 3 (item #12)

#### Description
Create the OneBranch Official Build pipeline that runs on main branch commits. This pipeline builds, publishes container images, and potentially triggers deployment stages.

#### Acceptance Criteria
- [ ] Create `.pipelines/OneBranch.Official.yml`
- [ ] Include all stages from PR pipeline (build, test, SDL scanning)
- [ ] Add container image build stage:
  - Build API image
  - Build Worker image
  - Tag with build number/commit SHA
  - Push to dev ACR
- [ ] Add versioning via Nerdbank.GitVersioning
- [ ] Sign container images with Notation (or equivalent)
- [ ] Publish build artifacts (logs, test results)
- [ ] Document in `docs/development/ci-cd.md`

#### References
- idk8s source: `.pipelines/OneBranch.Official.yml`, container image build stage
- BasePlatformRP target: `.pipelines/OneBranch.Official.yml`

---

### Issue 18: Implement Container Image Promotion Pipeline (DEV → PROD)
**Priority:** P2  
**Labels:** `infrastructure` / `ci-cd`  
**Estimated Effort:** M (2-3 days)  
**Source:** Cross-repo analysis, Section 3.H2 + Phase 5 (item #21)

#### Description
Create a pipeline for promoting container images through environments: DEV → Staging → PROD. This enables staged rollout with manual gates and audit trail.

#### Acceptance Criteria
- [ ] Create `.pipelines/OneBranch.ImagePromotion.yml`
- [ ] DEV stage: automatically promote build output
- [ ] Staging stage: manual gate (approval required)
- [ ] PROD stage: manual gate (approval required)
- [ ] Each promotion replicates image across regional ACRs
- [ ] Log all promotions to audit trail
- [ ] Add image signing/verification at each stage
- [ ] Document promotion runbook in `docs/operations/`

#### References
- idk8s source: Container image replication pipeline patterns, multi-ACR promotion
- BasePlatformRP target: `.pipelines/OneBranch.ImagePromotion.yml`

---

## Testing (P1–P2)

### Issue 14: Add Generation Tracking to Cosmos DB State Documents
**Priority:** P2  
**Labels:** `architecture` / `testing`  
**Estimated Effort:** M (2-3 days)  
**Source:** Cross-repo analysis, Section 3.B4 + Phase 4 (item #16)

#### Description
Implement Kubernetes-style Spec/Status/Generation/ObservedGeneration pattern in BasePlatformRP's Cosmos DB state documents. This enables idempotent processing, drift detection, and safe retries.

#### Acceptance Criteria
- [ ] Add `Generation` and `ObservedGeneration` fields to internal state document schema
- [ ] Generation increments on every spec change
- [ ] Reconciliation process tracks ObservedGeneration
- [ ] Implement optimistic concurrency using Cosmos DB ETags
- [ ] Reject conflicting updates with `ResourceVersionConflictException`-style error
- [ ] Add unit tests for generation tracking logic
- [ ] Document pattern in architecture decision record (ADR-002)

#### References
- idk8s source: Kubernetes Spec/Status/Generation pattern, `ResourceVersionConflictException`
- BasePlatformRP target: `src/RP/InternalStateCollection.cs`, state document schema

---

### Issue 15: Integrate Stryker Mutation Testing Framework
**Priority:** P2  
**Labels:** `testing`  
**Estimated Effort:** M (2 days)  
**Source:** Cross-repo analysis, Section 3.B2 + Phase 4 (item #17)

#### Description
Integrate Stryker mutation testing to measure actual test quality beyond code coverage. Start with diff-based mutation testing in PRs and gradually increase mutation score thresholds per project.

#### Acceptance Criteria
- [ ] Install Stryker.NET globally or as tool manifest
- [ ] Create `scripts/RunStrykerMutantTesting.ps1` (ported from idk8s)
- [ ] Configure per-project MinMutationScore thresholds:
  - Core models: 40%
  - Domain logic: 50%
  - Infrastructure: 25% (ramp up over time)
- [ ] Add diff-based mutation testing to PR pipeline (only tests changed files)
- [ ] Display mutation scores in PR comments
- [ ] Document mutation testing strategy in CONTRIBUTING guide

#### References
- idk8s source: `scripts/RunStrykerMutantTesting.ps1`, Stryker configuration
- BasePlatformRP target: `scripts/RunStrykerMutantTesting.ps1`

---

### Issue 20: Implement Canary Workload Validation for ClusterGroups
**Priority:** P3  
**Labels:** `testing` / `infrastructure`  
**Estimated Effort:** M (2-3 days)  
**Source:** Cross-repo analysis, Section 3.E2 + Phase 5 (item #23)

#### Description
After provisioning a ClusterGroup, deploy a synthetic canary pod to validate that the cluster is functional before marking the resource as Succeeded.

#### Acceptance Criteria
- [ ] Create minimal canary container image with Kubernetes API checks
- [ ] Implement CanaryValidator service in Worker that:
  - Deploys canary pod to provisioned cluster
  - Verifies pod reaches Running state
  - Tests DNS resolution, egress connectivity
  - Cleans up canary pod
  - Reports pass/fail back to ARM state
- [ ] Add retry logic with exponential backoff
- [ ] Timeout after 5 minutes
- [ ] Document in architecture decision record
- [ ] Add integration tests for canary validation

#### References
- idk8s source: `WorkloadCanaryApp` pod and canary validation pattern
- BasePlatformRP target: `src/Worker/Services/CanaryValidator.cs`, canary container

---

## Security (P0–P1)

*Issues #3 and #9 are also security-focused (in CI/CD and Quick Wins sections)*

---

## Architecture (P2–P3)

### Issue 19: Build Multi-Cluster Scheduler (Filter-Score-Select Pattern)
**Priority:** P3  
**Labels:** `architecture`  
**Estimated Effort:** L (1 week)  
**Source:** Cross-repo analysis, Section 3.B5 + Phase 5 (item #22)

#### Description
Implement intelligent multi-cluster workload scheduling for BasePlatformRP ClusterGroups. Use a topology-aware Filter-Score-Select pattern to place workloads across AKS clusters based on region, provider, capacity, and cost.

#### Acceptance Criteria
- [ ] Create `ITopologyFilter` abstraction (region, provider, capabilities matching)
- [ ] Create `IClusterScorer` abstraction (spread, cost, capacity scoring)
- [ ] Create `ClusterSelector` orchestrator that chains filters and scorers
- [ ] Implement RegionFilter, ProviderFilter, CapabilityFilter
- [ ] Implement SpreadScorer, CostScorer, CapacityScorer
- [ ] Unit tests for each filter/scorer
- [ ] Integration tests with mock cluster inventory
- [ ] Document algorithm in ADR (ADR-003: Multi-Cluster Scheduling)

#### References
- idk8s source: `ScaleUnitScheduler`, `TopologyClusterFilter`, `MappingBasedFilter`, `SpreadScaleUnitsScorer`
- BasePlatformRP target: `src/RP/Services/Scheduling/`

---

## Developer Experience (P0–P2)

*Issues #2, #4, #5, #7 are DevEx-focused (in Quick Wins and CI/CD sections)*

### Issue 16: Create Comprehensive Copilot Instructions for BasePlatformRP
**Priority:** P2  
**Labels:** `devex` / `documentation`  
**Estimated Effort:** M (1-2 days)  
**Source:** Cross-repo analysis, Section 3.A4 + Phase 4 (item #18)

#### Description
Write detailed Copilot instructions that guide AI assistants (GitHub Copilot, Copilot Enterprise) through BasePlatformRP's architecture, patterns, and conventions. This accelerates both AI-assisted coding and team onboarding.

#### Acceptance Criteria
- [ ] Create `.github/copilot-instructions.md` covering:
  - Repo purpose and architecture (ARM RP, BaseRP framework, Aspire)
  - Resource types and state model
  - TypeSpec workflow and API conventions
  - BaseRP extension points (IDeploymentProvider, IMetaRPProxy)
  - Testing requirements and patterns
  - Common workflows (add new resource type, fix a bug, write a test)
- [ ] Create `.github/skills/` directory with task-specific prompts:
  - `skills/add-resource-type.md`
  - `skills/write-contract-test.md`
  - `skills/debug-deployment.md`
- [ ] Reference security scanning and ADR process
- [ ] Test instructions with actual Copilot usage

#### References
- idk8s source: `.github/copilot-instructions.md`, `instructions/`, `prompts/`, `skills/` directory
- BasePlatformRP target: `.github/copilot-instructions.md`, `.github/skills/`

---

### Issue 21: Create MCP Server for Infrastructure Operations
**Priority:** P3  
**Labels:** `devex` / `infrastructure`  
**Estimated Effort:** L (1 week)  
**Source:** Cross-repo analysis, Section 3.F3 + Phase 5 (item #24)

#### Description
Build an MCP (Model Context Protocol) server that exposes BasePlatformRP resources, state queries, and deployment operations to AI assistants. This enables AI-assisted operational debugging and resource management.

#### Acceptance Criteria
- [ ] Create `src/Tools/BasePlatformMCP/` project
- [ ] Implement MCP resources for:
  - ARM resource operations (list, get, create, delete)
  - Cosmos DB state queries (inspect internal state)
  - Queue inspection (peek at pending work)
  - Deployment status checks (real-time reconciliation status)
- [ ] Register MCP server in `.mcp.json`
- [ ] Document MCP tools in `.github/copilot-instructions.md`
- [ ] Add example prompts for common operational tasks
- [ ] Integration test with Copilot Enterprise

#### References
- idk8s source: `InfraScaleMCP` concept, MCP server patterns
- BasePlatformRP target: `src/Tools/BasePlatformMCP/`

---

## Infrastructure (P2–P3)

### Issue 17: Set Up EV2 Deployment Framework for RP Service
**Priority:** P2  
**Labels:** `infrastructure`  
**Estimated Effort:** L (1 week)  
**Source:** Cross-repo analysis, Section 3.C2 + Phase 5 (item #20)

#### Description
Adapt idk8s EV2 deployment patterns for BasePlatformRP's RP service deployment. Implement ring-based safe rollout (PPE → R0 → R1 → R2) with progressive bake times.

#### Acceptance Criteria
- [ ] Create `ev2/` directory structure:
  - `ServiceModel.json` (RP service definition)
  - `RolloutSpec.json` (ring configuration)
  - Ring definitions: PPE, R0 (early adopters), R1 (mid-market), R2 (stable)
- [ ] Define minimum bake times per ring (PPE: 1 day, R0: 3 days, R1: 7 days, R2: immediate)
- [ ] Create shell/HTTP extension patterns for RP-specific deployments
- [ ] Document deployment strategy in `docs/operations/deployment.md`
- [ ] Create runbook for rolling back a ring
- [ ] Test in test environment

#### References
- idk8s source: `ev2/` structure, ServiceModel, RolloutSpec patterns
- BasePlatformRP target: `ev2/` directory at repo root

---

## Documentation (P0–P3)

*Issues #1, #4 are documentation-focused (in Quick Wins section)*

### Issue 22: Enhance Documentation Structure (decisions, operations, runbooks)
**Priority:** P3  
**Labels:** `documentation`  
**Estimated Effort:** M (2-3 days)  
**Source:** Cross-repo analysis, Section 3.G1 + Phase 5

#### Description
Expand BasePlatformRP's documentation to match idk8s's maturity level. Organize docs into clear categories (decisions, operations, development guides) and create essential runbooks.

#### Acceptance Criteria
- [ ] Reorganize `docs/` as:
  - `docs/decisions/` — ADRs (issue #1)
  - `docs/operations/` — runbooks for common tasks
  - `docs/development/` — dev guides (Aspire setup, testing, debugging)
  - `docs/design/` — existing design docs (keep and expand)
  - `docs/api/` — API reference (generated from TypeSpec)
- [ ] Create runbooks:
  - `docs/operations/deployment.md` — how to deploy to PPE/R0/R1/R2
  - `docs/operations/troubleshooting.md` — common issues and fixes
  - `docs/operations/incident-response.md` — what to do when things break
- [ ] Create `docs/development/local-setup.md` — step-by-step local dev setup
- [ ] Create `docs/development/debugging.md` — how to debug common issues
- [ ] Add table of contents and navigation to `docs/README.md`
- [ ] Ensure all docs link to relevant issues/ADRs

#### References
- idk8s source: Comprehensive `docs/` structure with `mp/`, `aos/`, `cd/`, `adr/` subdirectories
- BasePlatformRP target: Enhanced `docs/` structure

---

## Dependencies & Sequencing Notes

**Hard dependencies** (must complete before starting dependent issue):
- Issue #1 (ADR Process) should complete before all others (enables architectural decisions)
- Issue #2 (Mock Auth) enables Issue #5 (`.http` files) and Issue #7 (Aspire tests)
- Issue #7 (Aspire Fixture) enables Issue #8 (Contract Tests)
- Issue #6 (PR Pipeline) should complete before Issue #10 (Coverage Reporting)

**Suggested grouping for parallel work**:
- **Sprint 1 (P0 Quick Wins)**: Issues #1, #2, #3, #4, #5 (1 week) — all team members
- **Sprint 2 (P1 Foundation)**: Issues #6, #7, #8, #9, #10, #11, #12 (2-3 weeks) — infrastructure-focused team
- **Sprint 3 (P1-P2 Advanced)**: Issues #13, #14, #15, #16, #18 (2-3 weeks) — architecture/testing
- **Sprint 4+ (P2-P3 Future)**: Issues #17, #19, #20, #21, #22 (month+) — advanced capabilities

---

## Final Notes

- **Total scope**: 22 actionable issues across 7 categories
- **Estimated effort** (all issues): ~12-16 weeks for a full team
- **High-ROI items**: Issues #1–5 (Quick Wins) provide 70% of the value for 20% of the effort
- **Key principle**: BasePlatformRP and idk8s are **complementary**, not competing. Reuse proven patterns, adapt them to BasePlatformRP's ARM RP context, and extend them as needed.

---

**Generated by**: Picard, Lead Architect  
**For**: BasePlatformRP team  
**Reference**: Cross-Repo Analysis (idk8s-infrastructure → BasePlatformRP), 2025-07-18
