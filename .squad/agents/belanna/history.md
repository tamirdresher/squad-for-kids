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
