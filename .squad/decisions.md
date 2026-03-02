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
