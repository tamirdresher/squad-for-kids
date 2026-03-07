# Decisions

> Team decisions that all agents must respect. Managed by Scribe.

---

## Decision 1: Gap Analysis When Repository Access Blocked

**Date:** 2026-03-02  
**Author:** Picard (Lead)  
**Status:** ✅ Adopted  
**Scope:** Team Process

When primary data source (repository, database, API) is inaccessible, perform a comprehensive "gap analysis" on available secondary sources to identify what information is missing, assess quality of existing documentation, and create actionable investigation plan for when access is obtained.

**Applies to:** Repository access failures, database access issues, API unavailability, tool limitations  
**Does NOT apply when:** No secondary sources exist, gap analysis duplicates existing work, or user explicitly requests "wait for access"

**Consequences:**
- ✅ Delivers value even when blocked on primary task
- ✅ Creates actionable investigation plan for future work
- ✅ Exposes documentation quality issues early
- ⚠️ Gap analysis is speculative; may identify false positives

**Mitigation:** Clearly mark analysis as "partial/blocked" with warnings, distinguish confirmed vs. potential gaps, provide specific unblocking requirements.

**Related:** Applied to idk8s-infrastructure analysis (analysis-picard-architecture.md) which identified 10 major gaps and 6-day investigation plan despite repository access failure.

---

## Decision 2: Infrastructure Patterns for idk8s-infrastructure

**Date:** 2026-03-02  
**Author:** B'Elanna (Infrastructure Expert)  
**Status:** Proposed  
**Scope:** Infrastructure Standards

**Key Architectural Patterns Identified:**

1. **Cluster Orchestrator Pattern (ADR-0006):** Each Kubernetes cluster = separate EV2 stamp
   - Rationale: Leverage EV2's parallelism, retry, and state tracking
   - Impact: Deployment isolation, automatic retry, parallel execution

2. **Scale Unit Scheduler:** Filter → Score → Select pipeline for cluster placement
   - TopologyClusterFilter: Match cloud, env, region, cluster type
   - SpreadScaleUnitsScorer: Prefer clusters with fewer scale units
   - Explicit pinning via configuration

3. **Node Health Lifecycle (ADR-0012):** Multi-layered health monitoring with VMSS integration
   - Flow: Scheduled events → NodeHealthAgent → K8s conditions → NodeRepairService taints → Pod eviction
   - Key: Only approve scheduled events after workload pods drained

4. **Multi-Cloud Abstraction:** Unified codebase with cloud-specific adaptations
   - Auth: Entra ID (Public) vs. dSTS (Sovereign)
   - Secrets: KeyVault (Public) vs. dSMS (Sovereign)

**Team-Relevant Standards:**
- Infrastructure changes should include Bicep template updates
- Component manifests must declare dependencies explicitly
- Helm values must follow standard schema (tenant, service, resources, Azure resources, monitoring)
- All deployments via EV2 with progressive rings (Test → PPE → Prod)
- Tag-based releases only (no branch-based deployments per ADR-0007)
- SKU standardization: Dds_v6/Dads_v6 families only (ADR-0009)

---

## Decision 3: Security Findings — idk8s-infrastructure

**Date:** 2026-03-02  
**Author:** Worf (Security & Cloud)  
**Status:** Proposed  
**Impact:** High

**6 Critical/High Severity Findings:**

1. **Manual Certificate Rotation Risk** (CRITICAL)
   - KeyVault TLS certificates require manual rotation by service owners
   - Risk: Expired certificates cause service outages; manual process prone to human error
   - Action: Implement cert-manager, enable ACME/Azure Key Vault auto-renewal, 30-day expiration alerting

2. **Traffic Manager Public Exposure** (CRITICAL)
   - Scale units exposed to public internet without documented WAF protection
   - Risk: Application-layer attacks, DDoS, no centralized threat detection
   - Action: Mandate Azure Front Door/Application Gateway with WAF, enable DDoS Protection Standard, require TLS 1.2+

3. **Cross-Cloud Security Inconsistency** (CRITICAL)
   - Security implementations differ across Public, Fairfax, Mooncake, sovereign clouds
   - Risk: Configuration drift, compliance violations (FedRAMP, MLPS 2.0/3.0, GDPR)
   - Action: Establish cross-cloud security baseline, implement OPA/Rego validation, quarterly audits

4. **Dual Authentication Complexity** (HIGH)
   - System supports both Entra ID and dSTS authentication
   - Risk: Configuration errors could bypass authentication, increased maintenance burden
   - Action: Accelerate migration to dSTS-only within 6 months, deprecate Entra ID path

5. **Network Policy Gaps** (HIGH)
   - No evidence of default-deny Kubernetes Network Policies
   - Risk: Lateral movement between pods, namespace isolation gaps, CIS benchmark violations
   - Action: Deploy default-deny NetworkPolicy, implement CI/CD validation, quarterly audits

6. **Workload Identity Migration** (MEDIUM)
   - System likely using deprecated Azure AD Pod Identity (NMI DaemonSet)
   - Risk: Privileged DaemonSet increases attack surface, performance overhead
   - Action: Migrate to Workload Identity Federation, remove NMI DaemonSets, pilot in dogfood environment

**Immediate Actions (Q1 2026):**
- Implement automated certificate lifecycle management
- Deploy WAF for Traffic Manager endpoints

**Short-term (Q2 2026):**
- Establish cross-cloud security baseline
- Accelerate dSTS-only migration

**Medium-term (H2 2026):**
- Deploy default-deny Network Policies
- Migrate to Workload Identity Federation

---

## Decision 4: Repository Access Required — Data (Code Expert)

**Date:** 2026-03-02  
**Author:** Data (Code Expert)  
**Status:** Action Required

**Issue:** Code analysis blocked by complete Azure DevOps access failure
- Repository "idk8s-infrastructure" not found in project "One"
- Code search returns zero results for idk8s-specific patterns
- Project listing shows 20+ projects but none match expected location

**Team Action Required:**
1. Verify Azure DevOps organization (is it "microsoft" or different?)
2. Verify project name (is it actually "One"?)
3. Verify repository name (could it be renamed?)
4. Verify access permissions (does MCP connection have Code Read access?)

**Alternative:** If repository is on GitHub, provide GitHub org/repo URL or local file system path.

**Impact of Unblocking:** Direct code examination would provide 10x deeper insights than current architectural pattern inference.

---

## Decision 5: Repository Health Analysis Blocked — Seven (Research & Docs)

**Date:** 2026-03-02  
**Author:** Seven (Research & Docs)  
**Status:** Needs Team Input

**Issue:** Cannot complete repository health analysis due to Azure DevOps API failure
- Project "One" not found
- Cannot deliver: commit frequency, build health, PR activity, branching strategy, documentation inventory
- Possible root causes: Incorrect project name, different organization, permission limitation, repo naming mismatch

**Possible Root Causes:**
1. Incorrect project name - "One" may not be the actual Azure DevOps project name
2. Different organization - Repository may be in a different Azure DevOps org
3. Permission limitation - MCP server may lack access
4. Repository naming mismatch - Actual repo name may differ

**Recommended Team Decision:**
- **Option 1 (Recommended):** Unblock API access — Verify correct ADO org URL, project name, repo name; confirm API permissions; re-run analysis once access established
- **Option 2:** Alternative analysis method — Clone repository locally for direct analysis; use Azure DevOps web UI for manual metrics
- **Option 3:** Defer analysis — Document limitation and move to other tasks; revisit when access available

**What We DO Know:** From architecture report, substantial context inferred about fleet management control plane, .NET 8 + Go codebase, OneBranch + EV2 deployment, 19 tenants, multi-cloud support, sophisticated Kubernetes patterns.

---

## Decision 6: Playwright/Edge Browser Access for ADO Repository Analysis

**Date:** 2026-03-02  
**Author:** Tamir Dresher (User Directive)  
**Status:** ✅ Adopted  
**Scope:** Team Tools & Access

When Azure DevOps API access is unavailable, team may use **Playwright CLI with Microsoft Edge browser and Tamir's default user profile** to browse and extract information from ADO repositories directly via web interface.

**Applies to:** ADO repository browsing, manifest extraction, commit history review, pipeline analysis when MCP API fails  
**Does NOT apply when:** Direct code access is available, or repository is hosted on GitHub/local filesystem

**Rationale:**
- MCP Azure DevOps API has experienced intermittent 503 errors during code analysis tasks
- Playwright + Edge with user profile provides authenticated web access as fallback
- Unblocks repository analysis without waiting for infrastructure fixes

**Related:** Used in guide synthesis when Data (agent-6) encountered 503 error; enabled Data (agent-8) and B'Elanna to complete component catalog and infrastructure analysis

---

## Decision 7: Community Engagement Protocol — Squad Places Reconnaissance

**Date:** 2026-03-05  
**Author:** Scribe (on behalf of Team)  
**Status:** ✅ Adopted  
**Scope:** Security & Community Engagement

When team engages with external community sites (Squad Places, open-source repositories, public forums), no secrets or Microsoft confidential information shall be shared.

**Applies to:** Squad Places visits, community pattern analysis, external research, social engagement, public repositories  
**Does NOT apply when:** Operating in internal-only environments, authorized disclosure, or user explicitly approves specific data sharing

**Rationale:**
- External communities operate with different security posture and data handling policies
- Intellectual property, internal strategies, and security-sensitive findings must remain protected
- Community engagement value (pattern learning, best practices) achievable without exposing confidential details

**Related:** Applied during Squad Places reconnaissance (Picard, B'Elanna, Worf, Data, Seven) where 38 artifacts reviewed across 7 squads without disclosing Microsoft-specific infrastructure, security findings, or internal decision-making

---

## Decision 8: Aurora Adoption Plan for DK8S

**Date:** 2026-03-07  
**Author:** Picard (Lead)  
**Status:** Proposed  
**Scope:** Platform Validation & Quality  
**Related:** Issue #4

**Decision**

Adopt Aurora as DK8S's E2E validation platform through a 4-phase plan, starting with a cluster provisioning experiment in monitoring-only mode.

**Context**

- Aurora is Microsoft's E2E validation platform for Azure (not config management)
- DK8S has no structured E2E validation, resiliency testing, or deployment-integrated quality gates
- B'Elanna identified 4 systemic stability areas: networking (NAT Gateway), Istio mesh, upgrade blast radius, ConfigGen complexity
- Tamir asked: "Can we experiment on cluster provisioning? Will it make rollouts slower?"

**Key Points**

1. **Cluster provisioning is the right first experiment** — clear success criteria, high blast radius, no cross-team dependencies
2. **Aurora will NOT slow deployments if structured correctly** — validation runs during existing EV2 bake time, adding zero net latency in monitoring mode
3. **4-phase plan:** Phase 0 (design) → Phase 1 (Bridge, months 1-2) → Phase 2 (custom workloads + DIV, months 3-5) → Phase 3 (resiliency, months 6-8) → Phase 4 (full matrix + gating, months 9-12)
4. **Gating mode only in Phase 4**, only for critical scenarios, only after 30-day burn-in with zero false positives
5. **Rollback is straightforward** at every phase — Aurora is additive, not structural

**Risks**

- Custom workload development requires .NET SDK (DK8S team is Go-native)
- No existing Aurora-DK8S integration in org
- False positive risk if gating is enabled prematurely

**Next Steps**

1. Attend Aurora office hours with experiment proposal
2. Request Aurora subscription and service principals
3. Scaffold workload repo and implement first scenario
4. Configure Aurora Bridge for one OneBranch pipeline

---

## Decision 9: Aurora Scenario Prioritization for DK8S

**Date:** 2026-03-07  
**Author:** Seven (Research & Docs)  
**Status:** Proposed  
**Scope:** Testing & Validation Strategy  
**Related:** Issue #4, aurora-scenario-catalog.md, aurora-research.md

**Proposal**

Adopt a 12-scenario Aurora validation catalog for DK8S, organized in three priority tiers, with a phased 20-week implementation starting with Aurora Bridge integration and culminating in Deployment Integrated Validation (DIV).

**Key Decisions**

1. **Start with Cluster Provisioning (SC-001)** — P0 control-plane workload, well-suited to Aurora's scenario structure, no component change impact
2. **Use Bridge for ConfigGen (SC-005)** — existing ADO pipeline connected to Aurora with zero test rewriting
3. **Prioritize Data-Plane Workloads for Confirmed Incidents** — SC-006 (NAT Gateway) and SC-007 (DNS) address #1 and #2 outage drivers
4. **Defer DIV Integration to Phase 4** — only after confidence established through Phases 1-3

**Consequences**

- ✅ Establishes structured validation baseline
- ✅ Directly addresses confirmed Sev2 incident patterns
- ✅ Early adoption head start if DIV becomes mandatory (S360 KPI)
- ✅ Bridge integration provides immediate value with zero test rewriting
- ⚠️ Custom workload development required (~8 weeks)
- ⚠️ Matrix explosion (72+ combinations) requires disciplined core/extended/full strategy

---

## Decision 10: DK8S Stability & Config Management Priorities

**Date:** 2026-03-07  
**Author:** B'Elanna Torres (Infrastructure Expert)  
**Status:** Proposed  
**Scope:** DK8S Platform Reliability  
**Related:** Issue #4, dk8s-stability-analysis.md

**Context**

Comprehensive stability analysis of DK8S platform based on IcM incidents, Teams conversations, meeting transcripts, and EngineeringHub docs.

**Key Findings**

1. **Networking is #1 outage driver** — NAT Gateway degradations, DNS resolution failures
2. **Istio integration is highest-risk active change** — Jan 2026 Sev2 from ztunnel + DNS interaction
3. **ConfigGen breaking changes are acknowledged KPI problem** — tracked at IDP level
4. **Weak deployment feedback loops** — no visibility into EV2 step failures or NuGet version adoption
5. **Argo Rollouts have shared-resource failure modes** — leadership actively debating continued support

**Proposed Decisions**

**A. Decouple infrastructure components from Istio mesh**
- Rationale: Jan 2026 outage root cause was geneva-loggers in mesh
- Action: Establish permanent exclusion list for Geneva, CoreDNS, kube-system
- Impact: Prevents observability blackout during mesh failures

**B. Enforce minimum ConfigGen NuGet version at CI**
- Rationale: Breaking changes from MI/ACR transitions break deployments
- Action: CI gate blocking builds using ConfigGen versions below minimum
- Impact: Eliminates known-broken deployment paths

**C. Implement zone-aware NAT Gateway monitoring**
- Rationale: Current alerting pages on single NAT drop without AZ discrimination
- Action: Zone-aware monitoring to reduce false Sev2 pages
- Impact: Better incident discrimination, fewer unnecessary escalations

**D. Add deny assignments for manual resource deletions**
- Rationale: Manual deletions cause alert storms and downstream failures
- Action: Deny assignments at management-group level
- Impact: Prevents accidental infrastructure destruction

---

## Decision 11: Aurora Cluster Provisioning Experiment

**Date:** 2026-03-07  
**Author:** B'Elanna Torres (Infrastructure Expert)  
**Status:** Proposed  
**Scope:** DK8S Cluster Provisioning Validation  
**Related:** Issue #4, aurora-cluster-provisioning-experiment.md

**Proposed Decision**

Run a 12-week phased Aurora experiment targeting DK8S cluster provisioning on 2-3 non-production clusters (DEV/TEST in EUS2 + SEC). Start monitoring-only (zero pipeline impact), graduate to enhanced telemetry, then evaluate gating.

**Rationale**

1. **Cluster provisioning has no E2E validation today** — clusters pass pipeline checks but can be "provisioned but unhealthy"
2. **Aurora Bridge integrates without pipeline changes** — manifest-based onboarding, no YAML modifications
3. **Monitoring-only mode explicitly supported** — `CreateIcM = false` documented in Aurora guides
4. **Known failure modes not systematically tracked** — 9 documented failure patterns with no automated categorization

**Impact Assessment**

- Monitoring-only (Phase 1): Zero latency impact, zero pipeline changes
- Enhanced telemetry (Phase 2): <2 min addition (result emission step)
- Gating mode (Phase 3, DEV only): +5-10 min validation gate
- Component rollouts: Zero impact at any phase

**Investment**

~15-20 person-days over 12 weeks. Phase 1 (weeks 1-4) requires ~5 person-days total.

**Decisions Requested**

- Approve experiment scope and timeline
- Identify Aurora team contact for onboarding
- Select specific DEV/TEST clusters from inventory
- Assign DRI for experiment execution

**Consequences**

- ✅ First structured provisioning quality data for DK8S
- ✅ Automated failure categorization (infra vs. config vs. platform)
- ✅ Regression baseline for provisioning quality
- ⚠️ Requires Aurora team engagement (external dependency)
- ⚠️ Phase 2 requires pipeline owner buy-in for result emission

---

## Decision 12: DK8S Knowledge Consolidation Complete

**Date:** 2026-03-07  
**Author:** Seven (Research & Docs)  
**Status:** Proposed  
**Scope:** Knowledge Management  
**Related:** Issue #2

**Summary**

Consolidated all existing DK8S platform knowledge from 10+ analysis files, 2 local repos, and a 48-repo workspace inventory into `dk8s-platform-knowledge.md`.

**Key Findings**

1. **Two platforms, one ecosystem**: idk8s-infrastructure (Celestial/Entra Identity, 45 projects, 19 tenants) and Defender K8S (DK8S, ~50 repos) are architecturally distinct but share patterns
2. **48 repos catalogued** across 10 categories: 9 core infrastructure, 6 deployment, 5 observability, 4 security, 4 automation, 14 libraries, and more
3. **Critical architecture patterns documented**: Cluster Orchestrator (ADR-0006), Scale Unit Scheduler, Node Health Lifecycle (ADR-0012), ConfigGen expansion engine, ArgoCD app-of-apps GitOps
4. **6 critical/high security findings** consolidated — manual cert rotation, no WAF, cross-cloud inconsistency, network policy gaps
5. **BasePlatformRP is the abstraction layer** above both platforms — 22 identified gaps

**Recommendation**

- Use `dk8s-platform-knowledge.md` as team's canonical reference for both platforms
- Keep updated as new analysis is performed
- Consider splitting into sub-documents if exceeds ~1000 lines
