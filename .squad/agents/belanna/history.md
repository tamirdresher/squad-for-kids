# B'Elanna — History

## Core Context

- **Project:** Cross-repo research and analysis team covering infrastructure, security, cloud native, and development across Azure DevOps and GitHub repositories
- **User:** Tamir Dresher
- **Role:** Infrastructure Expert
- **Joined:** 2026-03-02T15:01:26Z
- **Note:** Recast from Trinity (The Matrix) to B'Elanna (Star Trek TNG/Voyager)

## Learnings

<!-- Append learnings below -->

### 2026-03-02: idk8s-infrastructure Deep-Dive Analysis

**Task:** Infrastructure layer analysis of Identity Kubernetes Platform (Celestial) fleet management system.

**Challenge:** Repository not directly accessible via Azure DevOps MCP tools (project "One", repo "idk8s-infrastructure" not found). Conducted analysis based on architectural report and infrastructure patterns.

**Key Findings:**

1. **Helm Chart Strategy:**
   - Tenant workload charts stored in ACR (Azure Container Registry)
   - OPA/Rego policy validation pre-deployment
   - Chart resolution via `Library/HelmArtifactRegistry/`
   - Values schema includes: tenant/service identity, resources, Azure resources (KeyVault, Storage), monitoring (Geneva)

2. **Kubernetes Manifest Organization:**
   - **Two deployment axes:** Cluster infrastructure (Component Deployer) + Tenant workloads (Management Plane)
   - Component manifests with dependency resolution, topology selectors (clusterTypes, regions, clouds)
   - Namespace isolation per scale unit: `{tenant}-{service}-{cloud}-{region}-{seq}`

3. **Bicep/ARM Templates:**
   - Located in `src/bicep/`
   - Provisions: AKS clusters, managed identities, KeyVault, Storage, Traffic Manager
   - SKU standardization: Dds_v6/Dads_v6 (ADR-0009)
   - Multi-cloud parameterization: Public, Fairfax, Mooncake, BlackForest, USNat, USSec

4. **Deployment Pipelines:**
   - Docker build → ACR
   - Helm package → ACR (OCI registry)
   - EV2 spec generation (ServiceModel, RolloutSpec, ScopeBindings)
   - Progressive rings: Test → PPE → Production
   - Tag-based releases (ADR-0007)

5. **EV2 Configuration:**
   - **Cluster Orchestrator pattern (ADR-0006):** Each cluster = separate EV2 stamp
   - ServiceModel: HTTP extensions calling Management Plane API
   - RolloutSpec: Orchestration steps with dependencies, parallel actions within rings
   - ScopeBindings: Azure subscription/resource group mappings per cloud

6. **Cluster Configuration:**
   - ClusterRegistry maintains inventory across 7 cloud environments
   - Cluster types: Generic, DPX, Gateway, MP
   - Node pools: System (K8s components), User (tenant workloads)
   - Topology filtering + scheduler scoring (Filter-Score-Select pattern)

7. **Component Manifests:**
   - YAML declarations with `kind`, `dependencies`, `topology` selectors
   - Plugin-based execution: HelmPlugin, ManifestPlugin, DaemonSetPlugin
   - Deployment order via topological sort with parallel batches
   - AOS components: NodeHealthAgent, NodeRepairService, RemediationController, PodHealthCheckService, pod-health-api-controller

**Infrastructure Patterns Identified:**
- Kubernetes operator patterns in C# (reconciliation loops, desired-state)
- Scale unit scheduler (Kubernetes scheduler pattern: Filter → Score → Select)
- Node health lifecycle with Azure VMSS integration (ADR-0012)
- Multi-cloud abstraction (Entra ID vs. dSTS, KeyVault vs. dSMS)

**Deliverable:** Comprehensive 48KB infrastructure analysis report (`analysis-belanna-infrastructure.md`) covering all 7 focus areas: Helm charts, K8s manifests, Bicep templates, pipelines, EV2 config, cluster definitions, component manifests.

**Recommendation:** Direct repository access would enable validation of architectural patterns and provide concrete artifact examples for future reference.

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

---

## 2026-03-05: Squad Places Community Engagement

**Task:** Visit Squad Places (AI agent social network) and engage with community content — browse posts, post insights, and reply to interesting discussions.

**Engagement Overview:**
- **Platform:** https://web.nicebeach-b92b0c14.eastus.azurecontainerapps.io/
- **Role:** Infrastructure Expert — K8s, Helm, ArgoCD, cloud-native patterns
- **Status:** Read-only web feed; actual posting/commenting requires API integration (designed for agent-first interaction)

**Community Learnings:**

1. **Platform Design Patterns:**
   - Squad Places is architected as **agent-first social network** — no web forms, API-driven (POST /api/artifacts, POST /api/comments)
   - Artifact types: decision, pattern, lesson, insight
   - Persistence: Azure Blob Storage (no SQL) — JSON blobs + prefix queries + Levenshtein duplicate detection
   - Rate limiting for agents requires rethinking (agents are bursty, coordinated, ignore Retry-After, trigger DDoS-like patterns)

2. **Squad Breakdown (7 teams observed):**
   - **Marvel Cinematic Universe:** .NET CLI modernization; shared "Tool-Gated Migration Loops" (build-as-validation pattern)
   - **The Wire:** Aspire community content discovery engine (ACCES) — RSS-first discovery, gap analysis, deduplication (3-tier: hash → fuzzy → human)
   - **Nostromo Crew:** Go-based agent server; REST/WebSocket API; subprocess orchestration; highlighted "Tmux Pattern" for agent lifecycle decoupling
   - **Breaking Bad:** .NET Terrarium 2.0 modernization (Framework 3.5 → .NET 10); multi-agent wiring failures lesson; 10 agents, 14-sprint migration
   - **The Usual Suspects:** Squad SDK/multi-agent runtime; prompt-as-code governance; dependency graph architecture (CLI → SDK → Copilot SDK); non-deterministic testing patterns
   - **Squad Places:** The platform itself; lessons on AI agent network design; Ed25519 identity, sanitization against prompt injection, trust models
   - **ra:** Minimal profile (go-based agent server)

3. **Infrastructure & Cloud-Native Insights from Community:**
   - **Aspire Integration:** Squad Places uses Aspire for orchestration; mentioned in "One-Command Engine Runs" pattern and Blob Storage architecture post
   - **Azure Blob Storage as Database:** Complete persistence layer without SQL Server — challenges traditional architecture assumptions
   - **Multi-Agent Orchestration Patterns:**
     - Event-driven coordination over polling (vs. request-response)
     - Graceful session degradation via async isolation
     - Real-time cost tracking through telemetry streams
     - Tmux-inspired agent decoupling (agents run independent of client connections)
   
4. **DevOps & Quality Patterns Worth Applying:**
   - **Tool-Gated Migration Loops:** Build tool as arbiter (propose → validate → fail → fix → loop), not agent guessing
   - **Report Assembly as Quality Gate:** Editor-in-chief agent validates cross-file consistency before ship
   - **Leaf-to-Root Migration Strategy:** Start from dependencies, work upward (validated layer before next depends on it)
   - **Scout-Librarian-Analyst Pipeline:** Three-stage content discovery (parallel scouts → deterministic dedup → human-actionable analysis)

5. **Testing & Reliability Themes:**
   - Multi-agent bugs are **always at integration boundaries** (wiring, lifecycle, serialization) — not logic errors
   - Non-deterministic AI output requires new testing discipline (quality gates, determinism windows, consensus patterns)
   - Edge cases for agent-consumed systems: unbounded recursion in comments, orphaned replies, body overflow, dead URLs, missing pagination

6. **Rate Limiting Rethinking:**
   - Traditional rate limiting breaks for agents: bursty traffic, coordinated patterns, ignore Retry-After headers
   - Traffic looks like DDoS when legitimate
   - Squad Places implements: squad-aware rate limiting + sliding window + edge case handling for agent behavior

**Key Observation — Infrastructure Expert Takeaway:**
The most valuable insight for infrastructure work: **Build infrastructure for agent first, humans second.** Squad Places chose Blob Storage (stateless, prefix-queryable, no schema drift) over SQL because agents don't need ACID transactions — they need resilience, cost-visibility, and replay semantics. This inverts classical database selection criteria.

**Recommendations for TNG Squad Infrastructure Work:**
- Apply "Tmux Pattern" to any long-running K8s workloads (decouple session from connection)
- Consider Aspire + Blob Storage model for non-transactional content pipelines
- Implement "Tool-Gated" validation loops: CRD spec → validation → feedback loop
- Test with agent burst patterns, not human click patterns

**Note:** Web feed is read-only; community interaction requires direct API calls. Full engagement (posting infrastructure insights, replying to multi-agent patterns) would require SDK integration.

---

### 2026-03-06: DK8S Stability Analysis for Aurora Platform (Issue #4)

**Context:** Background task (Mode: background) to analyze DK8S platform stability and readiness for Aurora E2E validation platform integration.

**Outcome:** ⚠️ Platform stability concerns identified, phased Aurora adoption recommended

**Stability Findings:**
- **5 Sev2 Incidents:** Historical instability patterns documented (cluster scheduling, node lifecycle, workload eviction)
- **7 Architectural Patterns:** Identified sustainable approaches (Cluster Orchestrator, Scale Unit Scheduler, Node Health Lifecycle, Multi-Cloud Abstraction)
- **6 ConfigGen Pain Points:** NuGet versioning coordination, cross-component dependencies, package distribution model limitations

**ConfigGen Impact:**
ResourceProvider distributed as NuGet creates version coordination challenges across Management Plane, Go services, and CLI. Alternative solutions evaluated:
1. **Semantic versioning locks** (short-term: explicit coordination)
2. **OCI registry distribution** (medium-term: versioned manifests)
3. **Unified codebase** (long-term: monorepo consideration)

**Aurora Integration Prerequisites:**
Before Aurora Phase 1 deployment on test cluster:
- [ ] ConfigGen versioning protocol implemented
- [ ] 5 Sev2 incident patterns mitigated (schedule validation, node health monitoring)
- [ ] Scale unit scheduler performance baseline established

**Phased Adoption Timeline:**
- **Phase 1 (Weeks 1-4):** Aurora on isolated test cluster (pattern validation)
- **Phase 2 (Weeks 5-12):** PPE ring deployment (production-scale testing)
- **Phase 3 (Week 13+):** Production gradual rollout (progressive rings)

**Recommendation:**
DK8S is not ready for Aurora in current state. Infrastructure team must resolve ConfigGen versioning and validate Sev2 incident patterns first. Estimated 4-6 week stabilization timeline before Aurora Phase 1 start.

**Branch:** squad/4-stability-aurora  
**Artifacts:** dk8s-stability-analysis.md  
**PR:** #8 opened

**Cross-Team Integration:**
- **Picard (Lead):** Infrastructure stability affects fleet manager deployment timeline
- **Worf (Security):** Security mitigations must address ConfigGen distribution security implications
- **Seven (Research):** Aurora phased strategy depends on infrastructure readiness gate
- **Data (Code):** Package distribution changes require reconciliation with code organization

**Infrastructure Pattern Insight:**
Kubernetes-inspired patterns (reconciliation, desired-state, scheduler) are powerful but require careful coordination across component boundaries. ConfigGen as NuGet creates implicit coupling that breaks at scale; solution is explicit versioning protocol or alternative distribution model that makes dependencies explicit.
