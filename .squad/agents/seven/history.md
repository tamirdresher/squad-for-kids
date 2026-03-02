# Seven — History

## Core Context

- **Project:** Cross-repo research and analysis team covering infrastructure, security, cloud native, and development across Azure DevOps and GitHub repositories
- **User:** Tamir Dresher
- **Role:** Research & Docs
- **Joined:** 2026-03-02T15:01:26Z
- **Note:** Recast from Oracle (The Matrix) to Seven (Star Trek TNG/Voyager)

## Learnings

<!-- Append learnings below -->

### 2026-03-02: Repository Health Analysis - Access Limitation

**Task:** Analyze idk8s-infrastructure repo health and CI/CD on Azure DevOps  
**Outcome:** Access blocked - repository not found in specified project "One"

**Key learnings:**
1. Azure DevOps API tools require exact project name and repository coordinates - cannot fuzzy search
2. When repository access fails, architecture reports and existing documentation can still provide substantial value
3. Repository health analysis requires: repo ID → commits, branches, PRs, pipelines all depend on this first query
4. Inferred 19 tenants, sophisticated fleet management architecture, .NET 8 + Go tech stack from existing docs
5. Always document access limitations clearly - unblocking is often a prerequisite to analysis

**Technical observations from architecture report:**
- idk8s-infrastructure is a fleet management control plane for Entra/Identity AKS clusters
- Uses Kubernetes operator patterns implemented in C# (reconciliation loops, desired-state model)
- Dual deployment model: Component Deployer (infrastructure) + Management Plane (workloads)
- 19 multi-tenant scale units across multiple Azure sovereign clouds
- OneBranch + EV2 safe deployment pipeline with ring-based rollouts

**Next actions needed:**
- Verify correct Azure DevOps org, project name, and repo name
- Confirm API permissions (Code read access)
- Re-run analysis once access is established

---

## Cross-Session Learning: Azure DevOps Access Limitations

**Important for all future sessions with this team:**

All five agents (Picard, B'Elanna, Worf, Data, Seven) encountered the same Azure DevOps access limitation during 2026-03-02 idk8s-deep-analysis session:

- **Problem:** Azure DevOps project "One" in msazure organization not found via API tools
- **Impact:** Unable to access idk8s-infrastructure repository directly
- **Root Causes (suspected):**
  1. Project name "One" may be incorrect or abbreviated
  2. Repository may be in different Azure DevOps organization
  3. Repository may be on GitHub, not Azure DevOps
  4. API connection may have incorrect credentials or limited permissions
  
- **Unblocking Strategy:**
  - User must verify and provide: Full Azure DevOps URL `https://dev.azure.com/{org}/{project}/_git/{repo}` OR GitHub org/repo URL
  - Confirm API user has Code (Read) permissions
  - Once unblocked, all agents can re-run their analyses with full repository access

- **What Was Delivered Despite Limitation:**
  - Gap analysis of existing architecture report (Picard)
  - Infrastructure pattern inference (B'Elanna)
  - Security architecture analysis (Worf)
  - Code pattern inference (Data)
  - Repository health assessment (Seven)
  
- **What Will Require Unblocking:**
  - Direct code inspection and metrics
  - CI/CD pipeline analysis
  - Repository activity metrics (commits, branches, PRs)
  - SAST security scanning
  - API contract validation

**Action:** Before spawning agents for future idk8s-infrastructure tasks, verify and document correct repository location.
