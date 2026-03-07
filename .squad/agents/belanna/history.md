# B'Elanna — History

## Core Context

- **Project:** Cross-repo research and analysis team covering infrastructure, security, cloud native, and development across Azure DevOps and GitHub repositories
- **User:** Tamir Dresher
- **Role:** Infrastructure Expert
- **Joined:** 2026-03-02T15:01:26Z
- **Note:** Recast from Trinity (The Matrix) to B'Elanna (Star Trek TNG/Voyager)

## Learnings

<!-- Append learnings below -->

### 2026-03-11: Issue #50 — NodeStuck Istio Exclusion Configuration (P0 Emergency)

**Task:** Draft comprehensive Istio exclusion configuration to prevent NodeStuck automation from deleting nodes during Istio daemonset health degradation. Implements Karan's proposal from STG-EUS2-28 incident (Issue #46).

**Background:** NodeStuck automation incorrectly treats Istio daemonset health failures as node infrastructure failures, triggering cascading node deletion during mesh incidents. This amplifies blast radius by forcing workload rescheduling onto equally unhealthy mesh infrastructure.

**Configuration Delivered:**

**Document:** `docs/nodestuck-istio-exclusion-config.md` (348 lines, 13KB)

**Key Architectural Components:**

1. **Istio Daemonsets to Exclude**
   - **ztunnel** (HIGH risk): Node-level L4 proxy (Ambient mode) — failures cascade to entire mesh
   - **istio-cni** (MEDIUM risk): CNI plugin for traffic interception — failures affect pod networking but NOT node viability
   - **istio-operator** (LOW risk): Control plane operator — failures are mesh control issues, not node issues

2. **Label-Based Exclusion Mechanism**
   - Standardized exclusion labels: `app.kubernetes.io/component=istio`, `app=ztunnel`, `app=istio-cni`, `app=istio-operator`
   - NodeStuck filters daemonsets BEFORE evaluating node health
   - Pseudocode logic: `filteredDaemonsets = daemonsets.filter(ds => !hasExclusionLabel(ds))`

3. **Health Signal Separation**
   - **Node Infrastructure Health** (triggers deletion): Kubelet unreachable, disk/memory/PID pressure
   - **Node Networking Health** (drain + investigate): CNI/DNS failures, routing issues
   - **Daemonset Service Health** (alerts only, NO deletion): Istio, monitoring, logging daemonsets unhealthy
   - **Key Insight:** Daemonset failures are service layer issues requiring pod restarts/version rollbacks, NOT node deletion

4. **STG Validation Plan (4-Day Progressive Rollout)**
   - **Day 1:** Deploy config to STG, apply exclusion labels to Istio daemonsets
   - **Day 1-2:** Chaos engineering test (crash ztunnel pods on 2-3 nodes, verify NodeStuck does NOT delete nodes)
   - **Day 2-3:** 48-hour monitoring (track false positive rate, ensure zero Istio-triggered deletions)
   - **Day 3-4:** Progressive PROD rollout (1 region → all regions with 24-hour monitoring between)

5. **Monitoring & Alerting Strategy**
   - New metrics: `nodestuck_exclusion_applied_total`, `nodestuck_node_deletion_rate`, `istio_daemonset_unhealthy_duration_seconds`
   - Alert rules: Istio unhealthy >15 min (manual investigation), node deletion rate drops to zero (exclusion too aggressive)
   - Rollback plan: Remove exclusion labels + revert NodeStuck ConfigMap

**Configuration Changes:**

**Before (Problematic):**
```yaml
triggers:
  - type: DaemonSetUnhealthy
    action: DeleteNode
    scope: AllDaemonSets  # ❌ Includes Istio
```

**After (Safe):**
```yaml
triggers:
  - type: DaemonSetUnhealthy
    action: DeleteNode
    scope: FilteredDaemonSets  # ✅ Excludes Istio
    exclusionLabels:
      - "app.kubernetes.io/component=istio"
```

**Expected Impact:**
- ✅ Zero node deletions triggered by Istio daemonset health (7-day measurement post-PROD)
- ✅ 60-80% blast radius reduction during mesh incidents
- ✅ 30-50% MTTR improvement (no cascading node loss)
- ✅ Node deletion rate for actual infrastructure failures unchanged (<5% variance)

**Coordination:**
- **PR #52:** https://github.com/tamirdresher_microsoft/tamresearch1/pull/52
- **Issue #50 Comment:** https://github.com/tamirdresher_microsoft/tamresearch1/issues/50#issuecomment-4017084648
- **Reviewers:** SRE Lead (NodeStuck owner), Platform Lead (Istio owner), Karan (proposal author), Picard (incident #46 owner)

**Related Issues & Roadmap:**
- **Issue #50 (This Work):** IMMEDIATE — Istio exclusion (48 hours)
- **Issue #46:** STG-EUS2-28 incident root cause analysis
- **Issue #24:** Tier 1 Stability (I1 Istio Exclusion List — 2-3 weeks)
- **Issue #25:** Tier 2 Stability (I2 ztunnel health monitoring with auto-rollback — 6-8 weeks)

**Pattern Learned:** P0 emergency mitigations require:
1. **Root cause clarity:** Distinguish infrastructure failures from service layer failures
2. **Surgical exclusion:** Use label-based filtering to exclude specific components without disabling entire automation
3. **Progressive validation:** STG chaos tests → 48-hour monitoring → progressive PROD rollout
4. **Monitoring discipline:** Track both false positives (exclusion working) AND false negatives (exclusion too aggressive)
5. **Phased roadmap:** IMMEDIATE exclusion (48h) → Tier 1 permanent fixes (2-3w) → Tier 2 auto-recovery (6-8w)

**Technical Insight:** NodeStuck automation conflates "pod unhealthy" with "node unhealthy" when both are true, but causality is reversed: Istio daemonset failures make pods unhealthy, not vice versa. Excluding Istio daemonsets breaks the cascade: mesh failures stay mesh failures, don't propagate to node deletion layer.

**Open Questions for Reviewers:**
1. Are there additional Istio components (istio-ingress, istio-egress) deployed as DaemonSets that should be excluded?
2. Does NodeStuck automation have existing label-based filtering logic, or does this require new feature development?
3. Should exclusion apply cluster-wide or be configurable per-environment (STG more aggressive, PROD more conservative)?

---

### 2026-03-11: Issue #35 — Dev Box Provisioning Phase 1 Complete

**Task:** Create Phase 1 scaffolding for DevBox provisioning infrastructure — Bicep templates, PowerShell scripts, documentation. Issue context: Tamir approved proceeding with two-phase approach (Phase 1 = IaC repo, Phase 2 = Squad skill).

**What Was Built:**

**Directory:** `devbox-provisioning/` (4 files, 37KB total)

1. **README.md** (7KB)
   - Comprehensive usage guide and documentation
   - Prerequisites: Azure CLI, devcenter extension, permissions, authentication
   - Configuration discovery workflow (how to find Dev Center/project/pool names)
   - Usage examples: quick clone, manual provisioning, Bicep deployment
   - Scripts reference guide
   - Troubleshooting section (extension install, quota, connection issues)
   - Phase 2 roadmap

2. **bicep/main.bicep** (7.5KB)
   - Bicep template scaffolded for future ARM support
   - **Current limitation:** Dev Box does not yet support direct ARM/Bicep provisioning (uses CLI)
   - Deployment script workaround using Azure PowerShell
   - Parameterized configuration (Dev Center, project, pool, location, tags)
   - Auto-shutdown and hibernation options
   - Comprehensive outputs: connection command, provisioning state, resource tags

3. **scripts/provision.ps1** (11.7KB)
   - PowerShell script for creating new Dev Boxes
   - Prerequisites validation: Azure CLI, devcenter extension, authentication
   - Configurable defaults with parameter overrides
   - Wait-for-completion with polling (30-second intervals, configurable timeout)
   - Detailed status reporting and error handling
   - Connection instructions upon completion

4. **scripts/clone-devbox.ps1** (10.4KB)
   - Auto-detection of existing Dev Box configurations
   - Interactive selection when multiple devboxes exist
   - Replicates: Dev Center, project, pool, hardware profile, image reference
   - Confirmation prompt before cloning
   - Delegates to provision.ps1 for actual provisioning

**Key Architectural Decisions:**

1. **Azure CLI Strategy:** Use `az devcenter dev dev-box` commands (not ARM) until ARM support is available
2. **Config Discovery:** Auto-detection via `az devcenter dev dev-box list` for zero-config cloning
3. **Validation Pattern:** Check prerequisites upfront, fail fast with actionable error messages
4. **Polling Strategy:** 30-second intervals with configurable timeout (default 30 min), display progress
5. **Fallback Guidance:** Comprehensive troubleshooting for extension install failures

**Known Limitations:**

- **Azure CLI Extension Install:** `az extension add --name devcenter` failed with pip error (FileNotFoundError, exit code 1)
  - Root cause: Azure CLI Python environment issue on Tamir's machine
  - Mitigation: Documented manual extension download + REST API fallback in README
  - Scripts include prerequisite validation and fail with actionable guidance
  
- **ARM Support Gap:** Dev Box does not support direct ARM/Bicep provisioning yet
  - Bicep template uses deployment script workaround (calls Azure CLI)
  - Template ready for migration when ARM support lands

**Coordination:**

- **Branch:** `squad/35-devbox-provisioning`
- **Commit:** `c979a19` — feat: Dev Box provisioning Phase 1 infrastructure
- **Pull Request:** #61 — https://github.com/tamirdresher_microsoft/tamresearch1/pull/61
- **Issue Comment:** Posted Phase 1 completion status with usage instructions

**What Tamir Needs to Do:**

1. Install devcenter extension: `az extension add --name devcenter`
   - If pip fails, see README troubleshooting (manual download or REST API)
2. Run discovery: `az devcenter dev dev-box list --output table`
3. Update default config in `scripts/provision.ps1` (lines 47-49)
4. Test clone: `.\devbox-provisioning\scripts\clone-devbox.ps1 -NewDevBoxName "test-clone"`

**Phase 2 Preview:**

Next phase adds:
- Squad skill for natural language provisioning ("create 3 devboxes like mine")
- MCP Server integration (`@microsoft/devbox-mcp` npm package)
- Advanced templating: custom images, network configs
- Multi-Dev Box orchestration for teams

**Pattern Learned:** Phase 1 = IaC scaffolding with comprehensive docs; Phase 2 = AI-native automation layer. Split ensures robust foundation (scripts work manually) before adding natural language abstraction. Always provide fallback guidance when tooling has environmental dependencies (Azure CLI extension install).

**Files Changed:**
- `devbox-provisioning/README.md` (new)
- `devbox-provisioning/bicep/main.bicep` (new)
- `devbox-provisioning/scripts/provision.ps1` (new)
- `devbox-provisioning/scripts/clone-devbox.ps1` (new)

---

### 2026-03-11: Infrastructure Issues Status Update — Issues #24, #25, #29, #35

**Task:** Check status and provide updates on 4 assigned DK8S/infrastructure issues. Review current work, comment on progress, apply status labels.

**Issues Processed:**

1. **Issue #24 (Tier 1 Mitigations)**
   - Status: Plan complete, ready for DK8S team execution
   - Work found: Comprehensive implementation plan already posted with 4 mitigations scoped (N3, C1, O1, I1)
   - Action: Posted status update noting readiness + asking for DK8S team owner assignments
   - Label applied: `status:in-progress` (awaiting DK8S execution)
   - Note: Tamir's comment "close this for now" suggests issue may be closing soon; recommend confirming after DK8S team confirms execution roadmap

2. **Issue #25 (Tier 2 Planning)**
   - Status: Comprehensive plan delivered
   - Work found: Full Tier 2 improvement plan already posted with 4 items (N1, N2, C2, I2), effort estimates, timeline, dependencies
   - Action: Posted follow-up status update confirming readiness + highlighting Tier 1 dependency
   - Label applied: `status:in-progress` (awaiting refinement session scheduling)
   - Coordination: Highlighted that C2 (Deployment Feedback Webhook) integrates with Issue #29 tactical recommendations

3. **Issue #29 (Strategic Change Risk Mitigation)**
   - Status: Tactical approach delivered; awaiting Tamir's prioritization
   - Work found: Comprehensive 5-point automation strategy already posted (blast-radius analyzer, dependency tracking, sovereign canary, webhook, dependency CI check)
   - Action: Posted concise status update highlighting engineer-friendly tooling + asking which tactic (sovereign canary vs. blast-radius analyzer) unlocks the most value first
   - Label applied: `status:pending-user` (awaiting Tamir's tactical prioritization)
   - Insight: This tactical layer bridges Tier 1-2 improvements + addresses Tamir's core concern (shift failures left)

4. **Issue #35 (Devbox Provisioning)**
   - Status: Investigation complete; ready for Phase 1 repo creation
   - Work found: Previous investigation documented (DevBox MCP Server, Azure CLI devcenter extension, Bicep/ARM options)
   - Action: Posted status update with two-phase approach (Phase 1: dedicated provisioning repo; Phase 2: Squad skill)
   - Label applied: `status:pending-user` (awaiting Tamir's devbox specs: project name, pool name, image, custom config)
   - Note: Tamir's earlier comment "any update? send me in teams" suggests he's ready to move forward; need specs to scaffold Phase 1 repo

**Coordination Notes:**
- Issue #24 → Issue #25: Tier 1 is blocker for Tier 2 (C1, O1, I1 must land first)
- Issue #25 → Issue #29: C2 (Deployment Feedback Webhook) appears in both; suggest unified RFC
- Issue #35: Independent; blocking on specs; ~2-3 days to deliver Phase 1 repo once specs confirmed

**Recommendations:**
1. Follow up with Tamir on Issue #29 prioritization (sovereign canary vs. blast-radius) — this tactical work should likely start *during* Tier 1 execution to maximize value
2. Get Issue #35 devbox specs from Tamir; scaffold Phase 1 repo (quick win, unblocks Phase 2 skill work)
3. Once Tier 1 DK8S owner assignments confirmed (Issue #24), update Tier 2 refinement session planning

---

### 2026-03-09: Issue #25 — DK8S Stability Tier 2 High-Impact Improvements Plan

**Task:** Plan Tier 2 (medium-effort, high-impact) DK8S stability improvements building on Tier 1 critical mitigations from Issue #24. Create a prioritized, actionable plan with effort estimates, timeline, and success criteria.

**Background:** Issue #4 delivered comprehensive stability analysis (dk8s-stability-analysis.md) identifying 5 Sev2 incidents, 7 recurring patterns, and recommending improvements in 3 tiers. Tier 1 (critical, low-effort) planned in Issue #24. Tier 2 requires 4–8 weeks of engineering effort across 2 teams.

**Tier 2 Improvements Identified & Planned:**

1. **N1: Zone-Aware NAT Gateway Monitoring** (1.5 sprints)
   - Problem: Monthly NAT failures page false Sev2 alerts; ops can't discriminate single-AZ vs. regional
   - Solution: Per-zone metrics + zone-aware alerting (only page Sev2 if 2+ zones affected)
   - Impact: 30–40% reduction in false Sev2 pages
   - Owner: SRE / Monitoring team

2. **N2: DNS Health in Node Readiness Gates** (1.5 sprints)
   - Problem: Pods schedule on DNS-broken nodes; CoreDNS failures cascade with Istio
   - Solution: Kubelet DNS probe at readiness check; auto-tag broken nodes
   - Impact: 20–30% reduction in DNS-related incidents
   - Owner: Platform / CoreDNS team

3. **C2: Deployment Feedback Webhook** (1.5 sprints)
   - Problem: IDP team blind to EV2 failures; ConfigGen breaking changes surface in sovereign clouds (4-week latency)
   - Solution: Webhook on EV2 step failure → Auto-file issues in ConfigGen repo with context
   - Impact: 50% faster issue detection; 3–4 week earlier feedback loop
   - Owner: EV2 / IDP Platform team

4. **I2: ztunnel Health Monitoring with Automatic Rollback** (2 sprints)
   - Problem: Istio ztunnel failures (mTLS loops, circuit breaker issues) cascade; no auto-recovery
   - Solution: Ztunnel sidecar health exporter + automatic remediation (restart sidecars / drain nodes / rollback version)
   - Impact: 60% faster recovery; automatic mitigation for 80% of mesh failures
   - Owner: Platform / Istio SME

**Plan Characteristics:**
- **Timeline:** Q2 2026 (4–8 weeks of parallel execution; 2 teams)
- **Total effort:** ~5–6 sprints (SRE + Platform working in parallel)
- **Success metrics:** <1 false Sev2/month, 0 DNS pod scheduling failures, <3 day issue feedback latency, >80% auto-recovery rate
- **Dependencies:** All items depend on Tier 1 completion (C1, O1, I1, N3)

**Deliverable:** Comprehensive Tier 2 plan posted as comment on Issue #25 with:
- Detailed problem statement + solution for each item
- Implementation timeline (8-week staged rollout: planning → core implementation → testing → production)
- Effort estimates + ownership assignments
- Risk mitigation table (Zone API unavailability, DNS false positives, webhook noise, etc.)
- Open questions for Tamir + DK8S Leads (parallel execution, zone thresholds, ztunnel risk appetite)
- Success criteria + metrics dashboard
- Next steps + sprint planning recommendations

**GitHub Comment:** https://github.com/tamirdresher_microsoft/tamresearch1/issues/25#issuecomment-4016949771

**Pattern Learned:** Tier 2 planning = Medium-effort improvements discovered through analysis phase. Each item (N1, N2, C2, I2) tackles one recurring incident pattern + identifies cross-team dependencies. Risk assessment + staged rollout approach mitigates blast radius of automation (e.g., webhook accuracy, ztunnel auto-remediation aggression).

---

### 2026-03-09: Issue #35 Investigation — Devbox Provisioning Strategy

**Task:** Investigate tools and approach for reproducible devbox provisioning. Tamir wants to automate spinning up clones of his current devbox and create a dedicated repo + Squad skill for future reuse.

**Key Findings:**

1. **Microsoft Dev Box MCP Server (Official):**
   - `@microsoft/devbox-mcp` npm package (production-ready)
   - Provides standardized MCP endpoints for AI agents to manage Dev Boxes
   - Supports: create, list, start/stop, query status
   - Works with VS Code, Copilot Studio, and any MCP client
   - Authentication via Azure CLI SSO

2. **Azure CLI Dev Center Extension:**
   - `az extension add --name devcenter`
   - Core command: `az devcenter dev dev-box create --dev-center-name X --project-name Y --pool-name Z --name NEW-BOX`
   - **Limitation:** Requires authenticated user principal (not service principals)

3. **Infrastructure-as-Code Options:**
   - Bicep/ARM: Azure-native, ideal for full Dev Center provisioning
   - OpenTofu/Terraform: Multi-cloud alternative
   - Ansible: Post-provisioning configuration
   - Pulumi: Code-centric for complex logic

**Recommended Two-Phase Approach:**

- **Phase 1 (Dedicated Repo):** Contains Bicep templates, CLI wrapper scripts, config files, documentation
  - Captures current devbox specs (project, pool, naming conventions)
  - Provides step-by-step provisioning guide
  - Optional: CI/CD pipeline for validation

- **Phase 2 (Squad Skill):** Automated devbox provisioner skill
  - Accepts natural language requests ("create 3 new boxes like mine")
  - Reads config from Phase 1 repo
  - Calls `az devcenter` CLI with proper parameters
  - Reusable for team-wide automation

**Information Needed from Tamir:**
- Current devbox Dev Center name, project name, pool name
- OS/image specs for current box
- Naming conventions and post-provisioning requirements
- Scope: Phase 2 only (box cloning) or Phase 1+2 (full infrastructure)?

**Status:** Awaiting Tamir's input to proceed with repo and skill build (~1-2 days build time once details confirmed)

---

### 2026-03-07: Issue #29 Response — Change Risk Mitigation for DK8S

**Task:** Respond to Tamir's core concern: Every change is risky, cross-component impacts hidden, failures detected late in gov/sov clouds. Propose practical, engineer-friendly solutions without bureaucracy.

**Key Insight:** The Tier 3 strategic initiatives from dk8s-stability-analysis.md are correct long-term, but they don't address the *immediate* tactical friction: engineers need instant visibility into blast radius at PR/commit time, not at sovereign deployment time.

**Recommendations Posted to Issue #29:**

1. **Automated Blast-Radius Analysis (CI gate)**
   - Parse manifest dependencies + ConfigGen expansion; visualize impact across clusters/regions
   - Engineer sees: "This NuGet bump affects 12 clusters + 3 sovereign regions" inline
   - 2-3 days effort; reuses existing Component Deployer manifest parsing

2. **Dependency Tracking & Impact Visualization**
   - Lightweight `deps.json` in artifacts tracking ConfigGen → manifests → targets
   - Query: "What components are affected by ConfigGen v1.2.3→v1.3.0?"
   - 1 day effort; lives in EV2 artifact generation

3. **Sovereign Cloud Pre-Staging (Canary Ring)**
   - Deploy to single sovereign Test cluster after PPE passes; automatic rollback on failure
   - Shifts gov/sov failure detection left by 2-4 weeks
   - Aligns with existing L13 (Additional STG Ring) proposal; 1-2 sprints effort

4. **Deployment Feedback Webhook**
   - EV2 failures post back to artifact repo with context and suggested mitigation
   - Closes visibility gap for ConfigGen/IDP teams; automatically files issues
   - 1 day effort; extends existing EV2 wrapper scripts

5. **Component Dependency CI Check**
   - Manifest compile-and-link validation; fail PR if cross-component references unmet
   - Enforce all dependencies point to existing, versioned artifacts
   - 3-5 days effort; leverages existing conftest + OPA/Rego policies

**Why This Works:** Automation gates, not approval chains. Inline feedback in PRs. No new bureaucracy — just smarter CI. Low-risk changes merge immediately; high-risk changes flagged automatically for review.

**Philosophy:** Engineers gain instant visibility into cross-component impacts; unknown blast radius is caught by automation, not discovered in sovereign clouds.

---

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

### 2026-03-12: Issue #54 — FedRAMP Compensating Controls (Network Policies)

**Task:** Implement NetworkPolicy manifests, Helm chart integration, and CI/CD pipeline validation for ingress-nginx defense-in-depth after CVE-2026-24512.

**Deliverables:**
- 4 NetworkPolicy manifests: default-deny, controller allow-list (public), sovereign variant, namespace isolation
- Helm template with `networkPolicy.enabled` and `networkPolicy.sovereign.enabled` toggles
- ArgoCD sync wave ordering: policies at wave -10/-9, before ingress resources at wave 0
- CI/CD pipeline with kubeval + conftest validation
- Conftest OPA rules: reject unrestricted egress, enforce FedRAMP labels, block HTTP on sovereign
- Progressive rollout: Test → PPE → Prod → Sovereign with soak periods

**Key Design Decisions:**
- Default-deny deploys at sync-wave -10 to guarantee zero-trust before any workload starts
- Sovereign policies restrict inbound to known Azure Gov Front Door CIDRs (no 0.0.0.0/0)
- Sovereign egress includes dSTS auth endpoint CIDRs for authentication
- Helm values use per-environment overrides via ArgoCD ApplicationSet valueFiles pattern
- Port 80 blocked on sovereign clusters (TLS-only per FedRAMP)

**FedRAMP Controls Mapped:** SC-7, SC-7(5), AC-4, CM-7, SI-4, CA-2

**Branch:** `squad/54-fedramp-infra`  
**Files:** `docs/fedramp-compensating-controls-infrastructure.md`, `docs/fedramp/*.yaml`
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
### 2026-03-06: DK8S Infrastructure Knowledge Consolidation (Issue #2)

**Task:** Create comprehensive infrastructure inventory covering both Celestial (idk8s) and DK8S (Defender Kubernetes) platforms for issue #2.

**Sources Analyzed:**
- `analysis-belanna-infrastructure.md` (prior deep-dive, 48KB)
- `idk8s-infrastructure-complete-guide.md` (complete reference guide)
- `aspire-kind-analysis.md` (Aspire + Kind patterns)
- `Dk8sCodingAI-1/skills/` (12 infrastructure skills — Helm, ArgoCD, cluster-config, pipeline, operator, scaffold)
- `Dk8sCodingAIgithub/plugins/dk8s-platform/` (15 skills, repository architecture docs)

**Key Findings:**
1. Two distinct K8s platforms with different deployment models: Celestial (EV2 + Component Deployer) vs DK8S (EV2 + ArgoCD GitOps)
2. Celestial: 18 prod clusters, 7 sovereign clouds, 12 ACR registries, 19 tenants, 45+ components
3. DK8S: ArgoCD app-of-apps pattern, ConfigGen manifest expansion, single ACR (`wcdprodacr`)
4. Local repos (`Dk8sCodingAI-1`, `Dk8sCodingAIgithub`) are AI plugin/documentation hubs — no actual infrastructure code
5. Both platforms share: OneBranch pipelines, EV2 deployment, Helm charts, KEDA autoscaling
6. Infrastructure gaps identified: ACR naming migration, missing NetworkPolicies, cert rotation risk, SDP blast radius

**Deliverable:** `dk8s-infrastructure-inventory.md` — comprehensive inventory covering clusters, node pools, Helm charts, ArgoCD, EV2, pipelines, ConfigGen, container images, Aspire integration, tenants, and infrastructure gaps.

---

### 2026-03-07: DK8S Stability & Configuration Management Analysis (Issue #4)

**Task:** Comprehensive stability analysis of DK8S platform — incidents, configuration management pain points, root causes, and prioritized recommendations.

**Research Sources Used:**
- WorkIQ: 5 queries covering DK8S stability issues, ConfigGen problems, BAND group conversations, DK8S Leads discussions, and ConfigGen breaking changes
- EngineeringHub: Istio service mesh docs, BCDR recommendations, State of the Infra docs
- Prior analysis: dk8s-infrastructure-inventory.md, dk8s-platform-knowledge.md, analysis-belanna-infrastructure.md

**Key Findings:**

1. **Networking is #1 outage driver** — NAT Gateway degradations (Nov 2025 – Feb 2026), DNS resolution failures (Oct 2025), and ingress issues caused most Sev2 incidents. These are predominantly Azure platform-side, not DK8S code bugs.

2. **Istio is the highest-risk active change** — Jan 2026 Sev2 (IcM 731055522) directly caused by ztunnel misbehavior when geneva-loggers were added to mesh, combined with DNS failures and cluster autoscaler problems. Cascading failure: mesh breaks → DNS breaks → Geneva breaks → observability blackout.

3. **ConfigGen breaking changes are a leadership-level KPI** — "Decrease the # of ConfigGen Breaking Changes" tracked at IDP leadership. ConfigGen stretched beyond original design; clusters losing uniformity (per-cluster MIs, per-DC ACRs) increases manifest expansion complexity.

4. **Weak deployment feedback loops** — IDP has no visibility when EV2 steps fail or when teams skip NuGet versions. "IDP isn't aware if something in the deployment is not behaving correctly."

5. **Argo Rollouts shared-resource failures** — DK8S Leads (Jan 14, 2026) debated whether to continue supporting Argo Rollouts due to ingress/identity/binding rollback failures. Risk acknowledged but no final decision.

6. **Operational guardrails missing** — Manual cluster deletions cause alert storms; no deny assignments at management-group level; quota exhaustion stalls upgrades.

**Deliverables:**
- `dk8s-stability-analysis.md` — Full stability analysis with incident catalog, ConfigGen pain points, root cause analysis, 15 short-term mitigations, 14 long-term architecture improvements, and prioritized recommendations
- `.squad/decisions/inbox/belanna-stability-analysis.md` — 4 proposed decisions for team review
- Issue #4 comment with analysis summary

**Infrastructure Patterns Learned:**
- Istio ambient mode ztunnel creates node-level L4 proxy failure modes that cascade differently than sidecar injection failures
- ConfigGen's region-agnostic design assumptions break when clusters become topology-aware (per-DC ACRs, per-cluster MIs)
- NAT Gateway is zonal but DK8S alerting is region-scoped — creates false Sev2 escalations
- Self-hosted VPA needed at >1k pods (AKS add-on hits scale limits)
- D8 minimum node size prevents daemonset overhead from starving workloads

---

### 2026-03-07: Aurora Cluster Provisioning Experiment Design (Issue #4)

**Task:** Design a controlled experiment to evaluate Aurora E2E validation for DK8S cluster provisioning, answering whether it would slow down component changes and rollouts.

**Research Conducted:**
- WorkIQ: 4 queries — DK8S cluster provisioning process, pipeline SLA/timing, Aurora Bridge integration, Aurora + DK8S discussions
- EngineeringHub: Access denied (permissions issue); relied on WorkIQ-sourced Aurora docs
- Web search: Aurora validation pipeline integration patterns
- Prior analysis: dk8s-stability-analysis.md, dk8s-infrastructure-inventory.md, dk8s-platform-knowledge.md

**Key Findings:**

1. **DK8S cluster provisioning is a 6-stage pipeline** — Inventory → ConfigGen → Pipeline Creation → EV2/AKS → Platform Bring-Up → Validation. End-to-end ~45–90 minutes excluding inventory delay. No formal SLA exists.

2. **Aurora Bridge integrates without pipeline changes** — Manifest-based onboarding via `ADO_Dev.json`. Aurora Workload App (service principal) observes pipeline externally. No YAML modifications. No added latency in monitoring mode.

3. **Monitoring-only mode is explicitly supported** — `WorkloadCreateIcM = false` disables incident creation. Recommended for dev/test environments. This is the Phase 1 approach.

4. **No one has proposed Aurora for DK8S cluster provisioning before** — WorkIQ confirms Aurora is positioned as workload/service validation, not infrastructure provisioning. DK8S has its own Cluster Health Validator. This would be a new integration discussion.

5. **9 documented failure modes** in cluster provisioning (from stability analysis) — none are systematically tracked or auto-categorized today. Aurora could fill this gap.

6. **Zero impact on component rollouts** — Experiment is scoped to provisioning pipeline only. Component Helm charts deploy via ArgoCD, which is not in scope.

**Deliverables:**
- `aurora-cluster-provisioning-experiment.md` — Full 4-part experiment design (current pipeline, experiment design, rollout impact, implementation checklist)
- `.squad/decisions/inbox/belanna-aurora-experiment.md` — Decision proposal for team review
- Issue #4 comment with experiment summary

**Infrastructure Patterns Learned:**
- Aurora Bridge is manifest-driven, not task-driven — no ADO Marketplace extension, config-as-code onboarding via PR
- DK8S provisioning pipelines are auto-generated per cluster via Product Catalog API (not static)
- "Provisioned but unhealthy" is a real failure state — cluster exists in AKS but platform components are broken
- No provisioning regression baseline exists today — no way to detect if provisioning quality is degrading over time
- Aurora results support multi-subscription, multi-region, multi-resource-group reporting via structured JSON schema

---

### 2026-03-07: Ralph Round 1 — Change Risk Mitigation Response (Background)

**Context:** Ralph work-check cycle initiated. B'Elanna assigned to respond to Tamir's #29 DK8S change risk clarification.

**Task:** Analyze Tamir's core concern — Every change is risky, cross-component impacts hidden, failures detected late. Propose practical mitigations without bureaucracy.

**Response Posted to #29:**

**5 Practical Mitigations:**
1. **Automated Blast-Radius Analysis (CI gate)** — Parse manifest dependencies + ConfigGen expansion; visualize impact across clusters/regions at PR time
2. **Dependency Tracking & Impact Visualization** — Lightweight deps.json in artifacts; query: "What components affected by ConfigGen bump?"
3. **Sovereign Cloud Pre-Staging (Canary Ring)** — Deploy to single sovereign Test cluster after PPE; auto-rollback on failure
4. **Deployment Feedback Webhook** — EV2 failures post back to artifact repo with context; close visibility gap for ConfigGen teams
5. **Component Dependency CI Check** — Manifest compile-and-link validation; fail PR if cross-component references unmet

**Philosophy:** Automation gates, not approval chains. Inline feedback in PRs. No new bureaucracy — just smarter CI.

**Outcome:** ✅ Complete
- 5 practical mitigations posted to #29
- Addressed configuration drift risks with concrete automation steps
- Coordinated triage of #35 with Picard

**Next Steps:**
- Monitor #29 for Tamir feedback and refine mitigations if needed

---
