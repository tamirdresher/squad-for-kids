# FedRAMP Dashboard Migration Plan

**Status:** Draft  
**Created:** 2026-03-09  
**Author:** Picard (Lead)  
**Related:** Issue #127, Issue #123  

## Executive Summary

The FedRAMP Security Dashboard has evolved from experimental work into a production-grade compliance monitoring platform with 13 merged PRs, ~100 files, and 5-phase rollout plan. This document outlines the migration from tamresearch1 (research repository) to a dedicated repository with proper governance, ownership, and CI/CD infrastructure.

**Migration Decision:** Move FedRAMP dashboard to dedicated repository `fedramp-dashboard` while preserving git history and maintaining deployment continuity.

## 1. Purpose & Mission

### What Is The FedRAMP Dashboard?

**Primary Purpose:** Production compliance monitoring platform for DK8S sovereign cloud deployments (Azure Government, Fairfax, Mooncake)

**Core Capabilities:**
- Real-time FedRAMP control validation monitoring
- Automated compliance reporting for P0/P1/P2 controls
- Role-based access control (Security Admin, Auditor, SRE, Ops Viewer)
- Multi-environment dashboards (DEV, STG, PROD, sovereign clouds)
- Integration with PagerDuty, Microsoft Teams, and Azure Monitor alerting

**This is NOT:**
- ❌ A reference architecture demo
- ❌ A one-time research experiment
- ❌ A proof-of-concept prototype

**This IS:**
- ✅ A production system deployed to sovereign clouds
- ✅ A compliance automation platform with active alerting
- ✅ A validated solution with 5-phase rollout plan

### Target Users

| User Persona | Access Level | Primary Use Case |
|--------------|--------------|------------------|
| **Security Admin** | Full access | Configure controls, manage RBAC, approve exceptions |
| **Security Engineer** | Read/write validation data | Investigate failures, update control baselines |
| **SRE (Site Reliability Engineer)** | Operational dashboards | Monitor control health, respond to incidents |
| **Ops Viewer** | Read-only dashboards | View compliance status, export reports |
| **Auditor** | Compliance reports only | Generate audit evidence, compliance snapshots |
| **Platform Team** | Infrastructure management | Deploy upgrades, manage sovereign cloud configs |

### Success Criteria

**Phase 1 (Setup - Weeks 1-2):**
- ✅ New repository created with squad integration (Ralph, Scribe)
- ✅ CI/CD pipelines operational (Azure DevOps + GitHub Actions)
- ✅ Initial documentation complete (README, architecture, runbooks)
- ✅ Access controls configured (GitHub teams, Azure RBAC)

**Phase 2 (Migration - Weeks 3-4):**
- ✅ All FedRAMP code migrated with git history
- ✅ Infrastructure deployments validated in DEV/STG
- ✅ API tests passing in new repo
- ✅ Documentation links updated

**Phase 3 (Validation - Week 5):**
- ✅ End-to-end validation in STG environment
- ✅ No regression in existing deployments
- ✅ Squad agents functional (triage, routing)
- ✅ Monitoring and alerting operational

**Phase 4 (Cleanup - Week 6):**
- ✅ tamresearch1 FedRAMP artifacts archived
- ✅ References updated across documentation
- ✅ Old pipelines disabled
- ✅ Knowledge transfer complete

## 2. Current State Inventory

### What Moves to New Repo

**Core Application Code (~60 files):**
```
/api/FedRampDashboard.Api/          → /src/api/
  - Controllers (5): Compliance, Controls, Environments, History, Reports
  - Authorization: RbacRoles.cs
  - Middleware: CacheTelemetryMiddleware.cs
  - Models: ApiModels.cs
  - Configuration: CacheTelemetryOptions.cs
  - Program.cs, appsettings.json

/functions/                          → /src/functions/
  - ProcessValidationResults.cs (data pipeline)
  - ArchiveExpiredResults.cs (cold archival)
  - AlertProcessor.cs (incident routing)
  - AlertHelper.cs (alerting logic)
  - integrations/PagerDutyClient.cs
  - integrations/TeamsClient.cs
  - FedRampDashboard.Functions.csproj, host.json

/dashboard-ui/                       → /src/dashboard-ui/
  - React application (Vite + TypeScript)
  - Components: Layout, charts, pages, common
  - Services: api.service.ts, RBAC utilities
  - ~20 TypeScript files

/infrastructure/                     → /infrastructure/
  - Bicep templates (phase1-data-pipeline.bicep, phase4-alerting.bicep)
  - Deployment scripts (deploy-phase1.ps1, deploy-phase4.ps1)
  - Environment configs (environments/)
  - ~10 files

/tests/                              → /tests/
  - API tests: FedRampDashboard.Api.Tests/
  - Validation tests: fedramp-validation/
    - Network policy tests
    - OPA policy tests
    - WAF rule tests
    - Compliance delta reports
  - ~15 files
```

**Documentation (~12 files):**
```
/docs/fedramp-*.md                   → /docs/
  - Phase 1-5 implementation docs
  - RBAC configuration guide
  - Compensating controls (security + infrastructure)
  - Cache SLI documentation

FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md → /docs/security/
```

**CI/CD Pipelines:**
```
/.azuredevops/fedramp-validation-phase1.yml → /.azuredevops/
/.github/workflows/fedramp-validation.yml   → /.github/workflows/
```

**OpenAPI Specification:**
```
/api/openapi-fedramp-dashboard.yaml  → /api-specs/openapi.yaml
```

**Total Migration:** ~100 files

### What Stays in tamresearch1

**Research Infrastructure (unchanged):**
- Squad agent configuration (squad.config.ts, .squad/)
- General-purpose infrastructure patterns (non-FedRAMP)
- Research documentation (DK8S stability, Aurora adoption, etc.)
- Training materials (training/)
- Non-FedRAMP tests and scripts

**Shared Configuration:**
- devbox-provisioning/ (shared dev environment)
- package.json (general tooling)
- Root README.md (research repo context)

## 3. New Repository Structure

### Repository: `fedramp-dashboard`

**Proposed GitHub URL:** `https://github.com/tamirdresher_microsoft/fedramp-dashboard`

```
fedramp-dashboard/
├── .squad/                           # Squad integration
│   ├── agents/                       # Agent charters (picard, belanna, worf, data, seven)
│   ├── decisions.md                  # Team decisions log
│   └── digests/                      # Ralph orchestration logs
│
├── src/
│   ├── api/                          # .NET 8 REST API
│   │   ├── Authorization/
│   │   ├── Configuration/
│   │   ├── Controllers/
│   │   ├── Middleware/
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Program.cs
│   │
│   ├── functions/                    # Azure Functions (data pipeline)
│   │   ├── integrations/
│   │   └── *.cs
│   │
│   └── dashboard-ui/                 # React + TypeScript UI
│       ├── src/
│       │   ├── components/
│       │   ├── services/
│       │   ├── hooks/
│       │   └── types/
│       └── vite.config.ts
│
├── infrastructure/                   # Bicep IaC
│   ├── bicep/                        # Template modules
│   ├── environments/                 # Per-env configs (dev, stg, prod, sovereign)
│   └── scripts/                      # Deployment automation
│
├── tests/
│   ├── api-tests/                    # xUnit API tests
│   ├── validation/                   # Compliance validation scripts
│   │   ├── network-policy-tests.sh
│   │   ├── opa-policy-tests.sh
│   │   └── waf-rule-tests.sh
│   └── e2e/                          # End-to-end UI tests (future)
│
├── docs/
│   ├── architecture/                 # Architecture diagrams, ADRs
│   ├── runbooks/                     # Operational runbooks
│   ├── deployment/                   # Deployment guides
│   ├── security/                     # Security assessments
│   └── api/                          # API documentation
│
├── api-specs/
│   └── openapi.yaml                  # OpenAPI 3.0 specification
│
├── .azuredevops/
│   ├── pipelines/
│   │   ├── ci-api.yml               # API CI pipeline
│   │   ├── ci-functions.yml         # Functions CI pipeline
│   │   ├── ci-ui.yml                # UI CI pipeline
│   │   ├── cd-infrastructure.yml    # Infrastructure CD
│   │   └── validation-pipeline.yml  # Compliance validation
│   └── templates/                   # Reusable pipeline templates
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                   # PR validation
│   │   ├── security-scan.yml        # Trivy, CodeQL
│   │   └── deploy-sovereign.yml     # Sovereign cloud deployment
│   ├── CODEOWNERS                   # Code ownership rules
│   └── ISSUE_TEMPLATE/              # Issue templates
│
├── scripts/
│   ├── azure-monitor-helper.sh      # Telemetry helpers
│   ├── setup-dev-environment.sh     # Local setup
│   └── ralph-watch.ps1              # Squad orchestrator
│
├── README.md                        # Project overview
├── CONTRIBUTING.md                  # Contribution guidelines
├── SECURITY.md                      # Security policy
├── LICENSE                          # MIT License
└── squad.config.ts                  # Squad configuration
```

## 4. Migration Strategy

### Approach: Progressive Migration with Parallel Validation

**Goal:** Zero-downtime migration preserving git history and deployment continuity

### Phase 1: Repository Setup (Week 1)

**Tasks:**
1. **Create new GitHub repository**
   - Name: `fedramp-dashboard`
   - Owner: `tamirdresher_microsoft`
   - Visibility: Private
   - Initialize with: README.md, LICENSE (MIT), .gitignore (C#, Node, Terraform)

2. **Configure GitHub settings**
   - Enable branch protection: `main` (require PR reviews, status checks)
   - Enable GitHub Actions
   - Add topics: `fedramp`, `compliance`, `azure`, `dotnet`, `react`
   - Configure Dependabot

3. **Set up access controls**
   - Create GitHub teams:
     - `fedramp-admins` (Picard, B'Elanna, Worf)
     - `fedramp-developers` (Data, Seven)
     - `fedramp-reviewers` (all squad agents)
   - Configure CODEOWNERS:
     ```
     /src/api/         @fedramp-developers
     /infrastructure/  @fedramp-admins
     /docs/security/   @worf
     ```

4. **Set up squad integration**
   - Copy `.squad/` structure from tamresearch1
   - Update squad.config.ts for new repo
   - Configure Ralph Watch (ralph-watch.ps1)
   - Test agent spawn and routing

5. **Initialize CI/CD pipelines**
   - Create Azure DevOps project: `FedRAMP-Dashboard`
   - Configure service connections (Azure RM, GitHub)
   - Import pipeline templates
   - Set up variable groups

**Deliverables:**
- ✅ Empty repository with governance configured
- ✅ Squad integration functional
- ✅ CI/CD scaffolding ready
- ✅ Access controls in place

**Go/No-Go Decision Point:** Repository setup validated, team has write access

### Phase 2: Code Migration (Weeks 2-3)

**Strategy:** Use git subtree/filter-branch to preserve history

**Option A: Git Subtree with History (Recommended)**
```bash
# Clone tamresearch1
git clone https://github.com/tamirdresher_microsoft/tamresearch1.git
cd tamresearch1

# Create migration branch
git checkout -b fedramp-migration

# Extract FedRAMP subdirectories with history
git filter-repo --path api/FedRampDashboard.Api --path functions --path dashboard-ui \
  --path infrastructure --path tests/fedramp-validation --path tests/FedRampDashboard.Api.Tests \
  --path docs/fedramp-dashboard-*.md --path docs/fedramp-compensating-controls-*.md \
  --path FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md \
  --path .azuredevops/fedramp-validation-phase1.yml \
  --path .github/workflows/fedramp-validation.yml \
  --path api/openapi-fedramp-dashboard.yaml

# Reorganize directory structure
git mv api/FedRampDashboard.Api src/api
git mv functions src/functions
git mv dashboard-ui src/dashboard-ui
git mv api/openapi-fedramp-dashboard.yaml api-specs/openapi.yaml
git commit -m "chore: reorganize directory structure for new repo"

# Push to new fedramp-dashboard repo
git remote add fedramp-dashboard https://github.com/tamirdresher_microsoft/fedramp-dashboard.git
git push fedramp-dashboard fedramp-migration:main
```

**Option B: Fresh Start with Archive (If history not critical)**
- Copy files to new repo
- Create single "Initial migration from tamresearch1" commit
- Link to tamresearch1 history in README

**Recommendation:** Use Option A to preserve:
- Commit authorship (13 PRs across 5+ contributors)
- Issue references in commit messages
- Code review context
- Blame history for debugging

**Tasks:**
1. Run git filter-repo migration script
2. Validate all files present in new repo
3. Update internal file paths (imports, references)
4. Fix broken links in documentation
5. Update package.json / .csproj references
6. Run build validation (dotnet build, npm run build)
7. Run unit tests
8. Create migration commit with full context

**Deliverables:**
- ✅ All FedRAMP code in new repo with history
- ✅ Directory structure follows new layout
- ✅ Builds succeed locally
- ✅ Unit tests passing

**Go/No-Go Decision Point:** All builds green, tests passing

### Phase 3: Infrastructure Validation (Week 3)

**Tasks:**
1. **Deploy to DEV environment**
   ```bash
   cd infrastructure
   az deployment group create \
     --resource-group fedramp-dashboard-dev-rg \
     --template-file bicep/main.bicep \
     --parameters environments/dev.json
   ```

2. **Deploy Azure Functions**
   ```bash
   cd src/functions
   func azure functionapp publish fedramp-pipeline-func-dev
   ```

3. **Deploy API to App Service**
   ```bash
   cd src/api
   dotnet publish -c Release
   az webapp deploy --resource-group fedramp-dashboard-dev-rg \
     --name fedramp-dashboard-api-dev --src-path bin/Release/net8.0/publish
   ```

4. **Deploy React UI to Static Web App**
   ```bash
   cd src/dashboard-ui
   npm run build
   az staticwebapp deploy --app-name fedramp-dashboard-ui-dev \
     --source ./dist
   ```

5. **Run integration tests**
   ```bash
   cd tests/validation
   export ENVIRONMENT=dev
   ./network-policy-tests.sh
   ./opa-policy-tests.sh
   ./waf-rule-tests.sh
   ```

6. **Validate telemetry**
   - Check Azure Monitor logs (ControlValidationResults_CL)
   - Verify Cosmos DB ingestion
   - Test PagerDuty/Teams alerting

**Deliverables:**
- ✅ DEV environment deployed from new repo
- ✅ All services running
- ✅ Integration tests passing
- ✅ Telemetry flowing correctly

**Go/No-Go Decision Point:** DEV environment fully operational

### Phase 4: CI/CD Pipeline Migration (Week 4)

**Tasks:**
1. **Migrate Azure DevOps pipelines**
   - Copy pipeline YAML from tamresearch1/.azuredevops
   - Update paths (api/FedRampDashboard.Api → src/api)
   - Update variable groups
   - Test CI build on feature branch
   - Test CD deployment to DEV

2. **Migrate GitHub Actions workflows**
   - Copy workflows from tamresearch1/.github/workflows
   - Update repository references
   - Configure GitHub secrets
   - Test PR validation workflow

3. **Configure deployment gates**
   - DEV: Automatic on merge to main
   - STG: Manual approval required
   - PROD: Manual approval + deployment window
   - Sovereign: Manual approval + change request

4. **Set up monitoring**
   - Azure Monitor alerts for build failures
   - PagerDuty integration for deployment failures
   - Teams notifications for PR merges

**Deliverables:**
- ✅ CI/CD pipelines operational
- ✅ Automated deployments to DEV
- ✅ Manual gates configured for PROD
- ✅ Monitoring and alerting active

**Go/No-Go Decision Point:** Full CI/CD cycle validated end-to-end

### Phase 5: Production Switchover (Week 5)

**Pre-Switchover Checklist:**
- [ ] DEV environment stable for 1 week
- [ ] STG deployment successful
- [ ] All integration tests passing
- [ ] Runbooks updated with new repo URLs
- [ ] Team trained on new repo structure
- [ ] Rollback plan documented and tested

**Switchover Tasks:**
1. **Deploy to PROD**
   - Use existing infrastructure (no recreation)
   - Deploy API update (minimal downtime: < 30 seconds)
   - Deploy Functions update (zero downtime: deployment slots)
   - Deploy UI update (zero downtime: static web app)
   - Validate health checks

2. **Update documentation**
   - README.md with new repo URL
   - OpenAPI spec with new endpoints
   - Runbooks with new deployment procedures
   - Training materials with new access URLs

3. **Update external references**
   - Azure Monitor dashboards
   - PagerDuty service mapping
   - Teams channel links
   - Wiki pages

4. **Verify monitoring**
   - Health checks passing
   - Telemetry flowing
   - Alerts operational
   - Dashboards updating

**Rollback Plan:**
```bash
# If critical issue detected within 4 hours:
# 1. Revert API deployment
az webapp deployment slot swap --resource-group fedramp-dashboard-prod-rg \
  --name fedramp-dashboard-api-prod --slot staging --action swap

# 2. Revert Functions deployment
az functionapp deployment slot swap --resource-group fedramp-dashboard-prod-rg \
  --name fedramp-pipeline-func-prod --slot staging --action swap

# 3. Notify team via PagerDuty/Teams
# 4. Root cause analysis in tamresearch1 repo
```

**Deliverables:**
- ✅ PROD running from new repo
- ✅ Zero customer-impacting incidents
- ✅ Monitoring and alerting confirmed
- ✅ Team trained and comfortable

**Go/No-Go Decision Point:** PROD stable for 48 hours with no issues

### Phase 6: Cleanup (Week 6)

**Tasks:**
1. **Archive tamresearch1 FedRAMP artifacts**
   - Create `archive/fedramp-legacy/` directory
   - Move all FedRAMP files with README explaining migration
   - Update root README.md: "FedRAMP dashboard moved to dedicated repo"
   - Add deprecation notice in all archived files

2. **Disable old pipelines**
   - Mark Azure DevOps pipelines as deprecated
   - Disable GitHub Actions workflows
   - Update pipeline documentation

3. **Update cross-references**
   - Search for "tamresearch1" in new repo
   - Replace with "fedramp-dashboard"
   - Fix documentation links
   - Update issue templates

4. **Knowledge transfer**
   - Team meeting: walkthrough of new repo structure
   - Document differences from tamresearch1
   - Update operational runbooks
   - Update on-call procedures

5. **Final validation**
   - Run full test suite
   - Deploy to sovereign cloud (if applicable)
   - Verify all documentation current
   - Close migration issue #127

**Deliverables:**
- ✅ tamresearch1 cleaned of FedRAMP code
- ✅ Old pipelines disabled
- ✅ All references updated
- ✅ Team fully transitioned

**Success Criteria:** tamresearch1 returns to pure research focus, fedramp-dashboard is self-sufficient

## 5. Ownership & Governance

### Code Owners

**API & Functions (.NET):**
- **Primary:** Data (Code Expert)
- **Backup:** Picard (Lead)
- Responsible for: Code quality, API design, performance optimization

**Infrastructure (Bicep, deployment scripts):**
- **Primary:** B'Elanna (Infrastructure Expert)
- **Backup:** Picard (Lead)
- Responsible for: IaC templates, deployment automation, sovereign cloud configs

**Security & Compliance:**
- **Primary:** Worf (Security & Cloud)
- **Backup:** Seven (Research & Docs)
- Responsible for: RBAC, security assessments, compliance validation

**Dashboard UI (React/TypeScript):**
- **Primary:** Data (Code Expert)
- **Backup:** Seven (Research & Docs)
- Responsible for: UI/UX, accessibility, responsive design

**Documentation:**
- **Primary:** Seven (Research & Docs)
- **Backup:** Picard (Lead)
- Responsible for: README, runbooks, API docs, architecture documentation

**Orchestration & Routing:**
- **Primary:** Scribe (Coordinator)
- **Backup:** Picard (Lead)
- Responsible for: Squad integration, Ralph Watch, issue triage

### Decision Authority

| Decision Type | Authority | Escalation |
|---------------|-----------|------------|
| **Architecture (API, data model)** | Picard (Lead) | Tamir (Owner) |
| **Infrastructure (Azure resources)** | B'Elanna (Infrastructure) | Picard → Tamir |
| **Security (RBAC, compliance)** | Worf (Security) | Picard → Tamir |
| **Code quality (patterns, tests)** | Data (Code Expert) | Picard → Tamir |
| **Documentation standards** | Seven (Research & Docs) | Picard → Tamir |
| **Scope changes (new features)** | Picard → Tamir | N/A |

### Squad Integration

**Ralph (Orchestrator):**
- Monitors fedramp-dashboard GitHub issues/PRs
- Routes work to appropriate agents
- Runs hourly via ralph-watch.ps1
- Logs orchestration state to `.squad/digests/`

**Scribe (Coordinator):**
- Manages team decisions (`.squad/decisions.md`)
- Generates digests for Tamir
- Coordinates cross-agent work
- Handles feature planning and triage

**Agent Charters:** (moved from tamresearch1/.squad/agents/)
- picard.md (Lead)
- belanna.md (Infrastructure)
- worf.md (Security)
- data.md (Code Expert)
- seven.md (Research & Docs)

## 6. Risk Mitigation

### Risk 1: Deployment Disruption During Migration

**Impact:** HIGH | **Probability:** MEDIUM

**Mitigation:**
- Use blue-green deployment (Azure Functions deployment slots)
- Deploy during low-traffic window (weekends)
- Maintain tamresearch1 pipelines active until PROD validates
- Test rollback procedure in DEV/STG before PROD

**Rollback Trigger:**
- Any PROD deployment failure
- Health check failures > 5 minutes
- Customer-reported incidents

### Risk 2: Git History Loss

**Impact:** MEDIUM | **Probability:** LOW

**Mitigation:**
- Use git filter-repo (preserves full commit history)
- Test migration on throwaway repo first
- Back up tamresearch1 before migration
- Document PR references in migration commit

**Contingency:**
- If history corruption detected: revert to fresh start (Option B)
- Link to tamresearch1 commits in new repo README

### Risk 3: Broken Cross-References

**Impact:** MEDIUM | **Probability:** HIGH

**Mitigation:**
- Search all files for "tamresearch1" before migration
- Update OpenAPI spec with new URLs
- Create redirect mapping document
- Update external dashboards (Azure Monitor, PagerDuty)

**Validation:**
- Automated link checker in CI pipeline
- Manual review of critical documentation
- Test all runbook procedures post-migration

### Risk 4: Squad Integration Failure

**Impact:** MEDIUM | **Probability:** MEDIUM

**Mitigation:**
- Test Ralph Watch in new repo before migration
- Validate agent spawn and routing
- Keep tamresearch1 squad integration as reference
- Document any configuration differences

**Validation:**
- Spawn test issue and verify agent assignment
- Test PR review workflow
- Verify orchestration logs generated

### Risk 5: CI/CD Pipeline Gaps

**Impact:** HIGH | **Probability:** MEDIUM

**Mitigation:**
- Copy all pipeline files (not rebuild from scratch)
- Test in DEV environment first
- Maintain parallel pipelines during transition
- Document service connection requirements

**Validation:**
- Run full CI/CD cycle in DEV
- Deploy to STG from new repo
- Verify all environment variables present
- Test manual approval gates

## 7. Success Metrics

### Week 1 (Setup)
- [ ] Repository created and accessible
- [ ] 5 agents have write access
- [ ] Squad integration tested (1 issue triaged)
- [ ] CI/CD scaffolding in place

### Week 3 (Migration)
- [ ] All code migrated with history
- [ ] DEV environment deployed from new repo
- [ ] All tests passing (unit + integration)
- [ ] Zero regressions detected

### Week 5 (Production)
- [ ] PROD deployed from new repo
- [ ] Zero customer-impacting incidents
- [ ] Monitoring and alerting operational
- [ ] Team trained on new structure

### Week 6 (Cleanup)
- [ ] tamresearch1 FedRAMP artifacts archived
- [ ] Old pipelines disabled
- [ ] All documentation updated
- [ ] Issue #127 closed

## 8. Timeline & Milestones

| Week | Milestone | Owner | Deliverables |
|------|-----------|-------|--------------|
| **1** | Repository Setup | Picard + B'Elanna | New repo, access controls, squad integration |
| **2** | Code Migration Start | Data | Git history extracted, builds passing |
| **3** | Infrastructure Validation | B'Elanna | DEV deployed, integration tests passing |
| **4** | CI/CD Migration | Data + B'Elanna | Pipelines operational, automated deployments |
| **5** | Production Switchover | Picard + Team | PROD deployed, monitoring validated |
| **6** | Cleanup | Seven + Scribe | tamresearch1 archived, documentation updated |

**Total Duration:** 6 weeks  
**Go-Live Target:** Week 5 (PROD deployment)  
**Project Complete:** Week 6 (cleanup done)

## 9. Open Questions

### For Tamir (Decision Required)

1. **Repository Naming:** Confirm `fedramp-dashboard` as repository name? Alternative: `dk8s-fedramp-dashboard`, `compliance-dashboard`

2. **Sovereign Cloud Scope:** Which sovereign clouds are in scope for Phase 1 migration?
   - Azure Government (MAG)?
   - Azure Government Secret (DoD)?
   - Azure China (Mooncake)?
   - Other?

3. **Squad Agent Allocation:** Should all 5 agents (Picard, B'Elanna, Worf, Data, Seven) move to new repo, or subset?

4. **CI/CD Platform Preference:** Azure DevOps, GitHub Actions, or both?
   - Current: Both platforms used (ADO for infra, GHA for validation)
   - Recommendation: Consolidate to GitHub Actions for consistency

5. **License:** Confirm MIT License for new repo? (tamresearch1 has no explicit license)

### For Team (Technical Decisions)

1. **Git History Depth:** Preserve full history (13 PRs, ~80 commits) or squash to single migration commit?
   - Recommendation: Preserve full history for blame/debugging

2. **Deployment Slots:** Use blue-green deployment slots for zero-downtime? (adds Azure cost)
   - Recommendation: Yes for PROD, optional for DEV/STG

3. **Monitoring Consolidation:** Migrate to dedicated Application Insights instance or keep shared?
   - Recommendation: Dedicated instance for better cost tracking

4. **Documentation Migration:** Move all FedRAMP docs or only production-relevant ones?
   - Recommendation: Move all (12 docs), archive non-production later if needed

## 10. Appendices

### Appendix A: File Migration Manifest

**Complete list of files to migrate:** (see Section 2 for details)

**Total Count:** ~100 files
- Source code: ~60 files
- Infrastructure: ~10 files
- Tests: ~15 files
- Documentation: ~12 files
- CI/CD: 2 files
- OpenAPI: 1 file

### Appendix B: Environment Configuration

| Environment | Resource Group | Region | Subscription |
|-------------|----------------|--------|--------------|
| DEV | fedramp-dashboard-dev-rg | eastus2 | [TBD] |
| STG | fedramp-dashboard-stg-rg | eastus2 | [TBD] |
| PROD | fedramp-dashboard-prod-rg | eastus2 | [TBD] |
| MAG | fedramp-dashboard-mag-rg | usgovvirginia | [TBD] |

### Appendix C: Dependencies

**External Dependencies:**
- Azure Monitor (Log Analytics workspace)
- Cosmos DB (hot storage)
- Azure Functions runtime (.NET 8)
- Azure App Service (.NET 8)
- Azure Static Web Apps (Node 20, React 18)
- PagerDuty API
- Microsoft Teams webhooks
- Azure AD / Entra ID (authentication)

**NuGet Packages:**
- Microsoft.Azure.Functions.Worker (v1.21.0+)
- Microsoft.Azure.Cosmos (v3.40.0+)
- Microsoft.ApplicationInsights (v2.22.0+)

**npm Packages:**
- react (v18.2.0)
- vite (v5.0.0)
- recharts (v2.10.0)
- @azure/msal-browser (v3.7.0)

### Appendix D: Rollback Procedures

**Scenario 1: PROD Deployment Failure**
```bash
# Immediate rollback using deployment slots
az webapp deployment slot swap --resource-group fedramp-dashboard-prod-rg \
  --name fedramp-dashboard-api-prod --slot staging --action swap

az functionapp deployment slot swap --resource-group fedramp-dashboard-prod-rg \
  --name fedramp-pipeline-func-prod --slot staging --action swap
```

**Scenario 2: Data Pipeline Corruption**
```bash
# Restore Cosmos DB from point-in-time backup
az cosmosdb sql container restore \
  --account-name fedramp-cosmos-prod \
  --database-name SecurityDashboard \
  --container-name ControlValidationResults \
  --restore-timestamp "2026-03-09T10:00:00Z"
```

**Scenario 3: Complete Migration Abort**
- Revert to tamresearch1 pipelines (keep active during transition)
- Disable new repo CI/CD
- Root cause investigation
- Schedule retry with fixes

### Appendix E: Contact Information

| Role | Contact | Responsibility |
|------|---------|----------------|
| **Project Owner** | Tamir Dresher | Final approval, strategic decisions |
| **Migration Lead** | Picard | Overall coordination, go/no-go decisions |
| **Infrastructure Lead** | B'Elanna | Azure resources, deployment automation |
| **Security Lead** | Worf | RBAC, compliance validation |
| **Code Lead** | Data | API, functions, UI code quality |
| **Documentation Lead** | Seven | README, runbooks, architecture docs |

---

**Next Steps:**
1. Tamir reviews and approves migration plan
2. Picard creates new GitHub repository
3. Team begins Phase 1 (Repository Setup) in Week 1
4. Weekly status updates via `.squad/digests/`

**Related Issues:**
- Issue #123: FedRAMP scope question (origin)
- Issue #127: Migration planning (this document)
