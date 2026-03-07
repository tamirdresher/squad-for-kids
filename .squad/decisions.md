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

---

## Decision 13: Teams Integration via MCP Server + GitHub App

**Date:** 2026-03-07  
**Author:** Picard (Lead)  
**Status:** Needs Team Review  
**Scope:** Communication & Integration  
**Related Issues:** #18, #19, #33

### Context

Tamir asked for two-way Teams communication (Issue #18). During research, discovered two critical tools that change our approach:

1. **Microsoft Agent 365 Teams MCP Server** — enables sending messages to Teams channels via MCP tool calls
2. **GitHub in Teams integration** — official app for GitHub → Teams notifications

### Proposed Decision

Adopt a **three-layer communication architecture**:

| Layer | Tool | Purpose |
|-------|------|---------|
| **GitHub → Teams** | GitHub in Teams app (official) | Real-time notifications for issues, PRs, comments |
| **Teams → GitHub** | WorkIQ + teams-monitor skill | Poll Teams for actionable messages, create GitHub issues |
| **Squad → Teams** | Teams MCP Server | Post updates, reply to threads, send notifications |

### Key Findings

#### Teams MCP Server Capabilities

- `mcp_graph_teams_postChannelMessage` — send messages to channels
- `mcp_graph_teams_replyToChannelMessage` — reply in threads
- `mcp_graph_chat_postMessage` — send direct messages
- `mcp_graph_teams_listChannelMessages` — read messages (alternative to WorkIQ)
- Full CRUD on channels, teams, members

**Critical unknown:** Need to verify Teams MCP Server is enabled in our MCP configuration. If not, determine what's needed (scope approval, configuration, etc.).

#### GitHub in Teams Integration

Official app that:
- Subscribes Teams channels to GitHub repos
- Posts threaded notifications for all GitHub activity
- Supports link unfurling and commands (`@GitHub Notifications`)
- Integrates Copilot coding agent for context-aware help

**Setup required:** Install app, connect GitHub account, subscribe channels. See Issue #19.

### Supersedes

Earlier Power Automate / Bot Framework recommendations in Issue #18. Those become **fallback options only** if MCP Server path doesn't work.

### Implications

#### If Teams MCP Server is available:
- ✅ True bidirectional communication without custom infrastructure
- ✅ No Azure Bot, no Power Automate, no custom webhooks
- ✅ Agents can post updates directly via MCP tools
- ⚠️ Need to handle message threading correctly (reply to threads, not spam channel)
- ⚠️ Need to tune notification frequency (don't over-notify)

#### If Teams MCP Server is NOT available:
- Fall back to original plan: Power Automate (Teams → GitHub) + Workflows webhooks (Squad → Teams)
- OR: Build custom Teams bot via Bot Framework (2-4 week effort)

### Action Items

1. **Picard/Data:** Verify Teams MCP Server availability — check MCP tool list for `mcp_graph_teams_*` tools
2. **Tamir:** Set up GitHub in Teams (Issue #19) — install app, subscribe channels
3. **Team:** Test full round-trip once both pieces are in place
4. **Scribe:** If MCP Server is verified, move this decision from inbox to decisions.md as adopted

### References

- Teams MCP Server docs: https://learn.microsoft.com/en-us/microsoft-agent-365/mcp-server-reference/teams
- GitHub in Teams docs: https://docs.github.com/en/integrations/how-tos/teams
- Microsoft Agency framework: https://learn.microsoft.com/en-us/agent-framework/overview/ (future consideration)
- Issue #18: https://github.com/tamirdresher_microsoft/tamresearch1/issues/18
- Issue #19: https://github.com/tamirdresher_microsoft/tamresearch1/issues/19

---

## Decision 14: Squad Differentiation vs Multi-Agent Frameworks

**Date:** 2026-03-08  
**Author:** Seven (Research & Docs)  
**Status:** Proposed  
**Scope:** Product Vision & Market Positioning  
**Related:** Issue #32

### Summary

Squad is **not reinventing the wheel**, but it is solving a **fundamentally different problem** than existing multi-agent frameworks. This decision documents the findings and recommends how the team should position Squad going forward.

### Findings

#### What Squad Is

- **Persistent AI agent team** with 6 specialized roles (Picard/Lead, B'Elanna/Infrastructure, Worf/Security, Data/Code, Seven/Research, Ralph/Monitor)
- **Stateful coordination** across sessions via GitHub issues, persistent agent memory (history.md), and team decision ledgers
- **CLI-integrated orchestration** via GitHub Copilot CLI or VS Code (not a daemon, not a chat interface)
- **Domain expertise encoding** — agents accumulate and retain knowledge about your codebase, infrastructure, security posture

#### Competitive Landscape

| Framework | Primary Use | State Model | Integration | Multi-Agent | Memory |
|-----------|------------|-----------|-------------|------------|--------|
| **OpenCLAW** | Personal automation via chat | Stateless | WhatsApp/Slack/Discord | No (single + sub-tasks) | None |
| **CrewAI** | Business workflow automation | Stateful | Python API | Yes (role-based) | Per-session |
| **MetaGPT** | Code generation | Stateful | Python API | Yes (software roles) | Implicit |
| **ChatDev** | Software delivery simulation | Stateful | Python API | Yes (conversational) | Conversation history |
| **AWS Agent Squad** | General orchestration | Stateful | Python/TypeScript API | Yes (specialized agents) | Per-session |
| **Squad** | Complex project coordination | **Stateful persistent** | **GitHub + CLI** | Yes (specialized + team roles) | **Persistent across sessions** |

#### Squad's Genuine Differentiation

1. **GitHub as Work Queue** — Issues are tasks; enables public visibility, audit trails, approval loops (vs. chat-based task entry)
2. **Persistent Agent Memory** — Agents log learnings to history.md files; institutional knowledge compounds across sessions
3. **Decision Ledger** — Team decisions recorded in `.squad/decisions.md` as explicit traces (vs. implicit in other frameworks)
4. **Work Monitor (Ralph)** — Active queue triage and escalation (vs. passive chat-waiting)
5. **No Chat Dependency** — Works through CLI/VS Code; not Slack/WhatsApp/Discord-dependent
6. **Casting + Identity System** — Agents drawn from Star Trek universe; distinct voices aid memory and specialization

#### Market Gap Identified

**Stateful team coordination with persistent memory across sessions is underserved.**

- OpenCLAW solves: "Automate my repetitive tasks from chat"
- CrewAI solves: "Coordinate a team on business workflows"
- MetaGPT solves: "Simulate a software engineering company"
- **Squad solves: "Build a team that gets smarter the more we work together on this complex project"**

### Recommendation

#### 1. Lean Into Differentiation — Don't Copy OpenCLAW

Do **NOT** try to:
- Become a chat interface (that's OpenCLAW/CrewAI's domain)
- Add WhatsApp/Slack/Discord integrations (diminishes Squad's core strength)
- Copy CrewAI's Python library approach (Squad's GitHub integration is the differentiator)

**DO:**
- Double down on persistent memory and decision traces
- Make agent history.md and decisions.md *first-class artifacts*, not hidden state
- Promote "reasoning trace > compressed fact" as core philosophy (aligns with agent knowledge transfer patterns)
- Build Squad Places integration *deeper* (agents discovering each other's decision traces is powerful)

#### 2. Market Positioning

**Short tagline for Squad:**
- "A persistent AI agent team that remembers what you've learned"
- "GitHub issues → AI agent coordination → institutional knowledge accumulation"

**Compare to:**
- OpenCLAW: "Personal automation from your favorite chat app"
- CrewAI: "Role-based teams for business workflows"
- Squad: "Persistent team memory for complex projects"

#### 3. Next Steps

1. **Document Squad's architecture** explicitly: GitHub issue routing → Coordinator → Specialized agents → Persistent memory
2. **Create case studies** showing how persistent memory adds value (e.g., "Security findings that compound across sessions")
3. **Publish research findings** on why narrative-based knowledge transfer works for AI teams (from Squad Places research)
4. **Consider adding OpenCLAW integration** if demand emerges (agents as skills), but don't compromise Squad's core design

### Consequences

✅ **Positive:**
- Squad has genuine market differentiation (not a "me-too" framework)
- Persistent memory model is genuinely valuable for long-running projects
- GitHub integration aligns with how real teams work (issues are already the task entry point)
- Decision traces philosophy has scientific backing (squad Places research shows agents prefer reasoning over facts)

⚠️ **Risk:**
- Smaller addressable market than OpenCLAW (personal productivity is bigger than institutional knowledge)
- Requires explaining Squad's value prop clearly (persistence + memory = not obvious to everyone)
- If CrewAI adds persistent memory, Squad loses differentiation (unlikely in next 12 months)

### Decision

**Adopt this positioning:**

Squad is a **persistent AI agent team for complex projects**, differentiated by stateful memory across sessions, GitHub-issue-driven work routing, and decision ledger traceability. It does not try to be OpenCLAW (personal automation) or CrewAI (business workflows); instead, it solves the underserved need for team memory and institutional knowledge accumulation in AI-driven work.

This decision affects:
- Marketing messaging (no comparisons to OpenCLAW; highlight persistence + memory)
- Product roadmap (invest in memory systems, decision traces, Squad Places integration; deprioritize chat integrations)
- Agent training (emphasize historical reasoning, cross-session learnings, narrative-based knowledge)

---

## Decision 15: Adopt OpenCLAW Production Patterns for Continuous Learning System

**Date:** 2026-03-09  
**Author:** Seven (Research & Docs)  
**Status:** Proposed  
**Scope:** Continuous Learning System + Squad Operations  
**Related:** PR #10, Issue #13, Issue #6, continuous-learning-design.md

### Context

The OpenCLAW article documents production patterns for running AI agents at scale, including memory architecture, multi-agent orchestration, and a DevBot case study. Several patterns directly improve our continuous learning system design and squad operations.

### Proposed Changes

#### A. Add QMD Extraction Framework to Digest Templates (Phase 1)

Add a 5-category extraction taxonomy to the digest template:
- **Decisions made** — architectural choices, governance changes, policy updates
- **Commitments created** — deadlines, ownership assignments, delivery promises
- **Pattern changes** — frequency shifts, new failure modes, resolution drift
- **Blockers + resolutions** — blocked items, what unblocked them, timeline
- **Drop** — routine operations, simple Q&A, repeated status updates

**Impact:** Immediately improves digest signal quality without infrastructure changes.

#### B. Add Dream Routine Cross-Digest Analysis (New Phase 2.5)

Insert a "Dream Routine" between Phase 2 and Phase 3 of the continuous learning design:
- At session start, cross-reference last N digests
- Detect trending topics (frequency increase/decrease across digests)
- Flag items meeting skill promotion criteria (3+ digests, 2+ weeks)
- Surface resolved blockers and stalled items

**Impact:** Bridges the gap between individual digests and skill accumulation. Makes pattern detection continuous rather than manual.

#### C. Redesign Channel Scanner as Triage Sub-Agent (Phase 2 Enhancement)

Transform the Channel Scanner from "query and store" to "query, classify, prioritize, escalate":
- **Classification:** incident / decision / question / coordination
- **Priority:** P0 (production outage) → P3 (cleanup)
- **Escalation:** P0 items trigger immediate squad action
- **Audit:** Log all triage decisions for pattern analysis

**Impact:** Turns channel monitoring from passive note-taking into active intelligence gathering.

#### D. Define Agent Authority Levels (Squad-Wide)

Adopt DevBot's authority level model:
- **Level 1 — Research:** Gather information, human decides
- **Level 2 — Propose & Execute:** Draft action, execute after approval
- **Level 3 — Full Autonomy:** Act independently, escalate exceptions

**Impact:** Clarifies when agents can act autonomously vs. defer to Tamir.

### Consequences

- ✅ Digest quality immediately improves with QMD framework
- ✅ Cross-digest analysis detects patterns invisible in individual snapshots
- ✅ Triage model transforms scanning from passive to active intelligence
- ✅ Authority levels reduce ambiguity in agent decision-making
- ⚠️ Dream routine adds ~5 min to session start (worthwhile for context)
- ⚠️ Authority level definitions require team discussion to calibrate per agent

### Source

[OpenCLAW in the Real World](https://trilogyai.substack.com/p/openclaw-in-the-real-world?r=18detb) — Trilogy AI Substack

---

## Decision 16: RP Registration Approach for DK8S

**Date:** 2026-03-08  
**Author:** Seven (Research & Docs)  
**Status:** Proposed  
**Scope:** RP Registration Strategy  
**Related:** Issue #11, rp-registration-guide.md

### Proposal

Adopt a Hybrid RP approach for DK8S's BasePlatformRP registration: RPaaS for simple CRUD resource types, Direct RP for complex orchestration types, and RP Lite for read-only inventory exposure.

### Key Findings

1. **RPaaS is the recommended path for new services** — but DK8S's complex orchestration logic (fleet scheduling, scale unit management, Kubernetes operator patterns) doesn't fit RPaaS's callback model cleanly
2. **Custom (Direct) RP requires an exception** — new unmanaged RPs need approval via aka.ms/RPaaSException
3. **Hybrid RP is the best of both worlds** — managed types for simple CRUD + direct types for complex workflows
4. **Timeline: 4–10 months** depending on complexity and review cycles
5. **TypeSpec is mandatory** for all new services since January 2024
6. **OBO subscriptions are now auto-provisioned** (since May 2024) when PC Code and Program ID are provided

### Recommended Next Steps

1. **Attend ARM API Modeling Office Hours** with resource type proposal
2. **Determine RP type** (Managed, Direct, or Hybrid) based on complexity assessment
3. **Begin TypeSpec authoring** for resource types
4. **File RPaaS onboarding IcM** with ServiceTree metadata
5. **Review IcM 757549503 response** to incorporate any guidance from RPaaS team

### Consequences

- ✅ Structured registration path aligned with ARM standards
- ✅ Auto-generated SDKs, Portal, CLI, Bicep support
- ✅ Sovereign cloud support (Mooncake, Fairfax since May 2025)
- ⚠️ 4–10 month timeline depending on approach
- ⚠️ Go vs .NET tension (RPaaS tooling is .NET-based, DK8S is Go-native)
- ⚠️ Ongoing compliance burden (API reviews, SDK regen, certification)

---

## Decision 17: RP Registration Escalation Strategy

**Date:** 2026-03-08  
**Author:** Picard (Lead)  
**Status:** Proposed  
**Scope:** RP Registration / Platform Dependencies  
**Related:** Issue #11, IcM 757549503

### Decision

Escalate the Cosmos DB role assignment failure (IcM 757549503) blocking Private.BasePlatform RP registration through RPaaS IST Office Hours, and request a manual workaround to unblock registration while the automation bug is fixed.

### Context

- IcM 757549503 is a Sev 3 incident: Cosmos DB role assignment failure blocks RP manifest rollout
- Root cause is a `NullReferenceException` in `CosmosDbRoleAssignmentJob` — a bug on the RPaaS platform side
- Related IcM 754149871 indicates this may be a broader Cosmos DB role assignment issue
- The incident has been in "New" state since 2026-03-06 with no resolution
- Our RP registration pipeline is completely blocked at this step

### Proposed Actions

1. **Escalate at RPaaS IST Office Hours** — present the blocking issue with both IcM references
2. **Request manual Cosmos DB role assignment** — ask RPaaS DRI if they can manually complete the step
3. **Verify all prerequisites** — confirm PC Code, Profit Center Program ID, ServiceTree ID, and subscription are correct before re-attempting
4. **If unblocked within 2 weeks:** proceed with RP registration PUT, Operations RT, and manifest checkin
5. **If still blocked after 2 weeks:** escalate to Sev 2 or reach out to ARM-Extensibility leads directly

### Consequences

- ✅ Unblocks RP registration pipeline
- ✅ Establishes relationship with RPaaS DRI team
- ✅ Documents the dependency for future reference
- ⚠️ Manual workaround may need to be repeated if automation isn't fixed
- ⚠️ Timeline depends on external team responsiveness

### Alternatives Considered

1. **Wait for automated fix** — rejected because timeline is unknown and RP registration is on critical path
2. **Private RP path** — considered but adds complexity; standard Hybrid RP onboarding is preferred
3. **Direct RP exception** — rejected because Hybrid RP is the correct model and doesn't require exception

---

## Decision 18: Continuous Learning System for Teams Channel Monitoring

**Date:** 2026-03-07  
**Author:** Picard (Lead)  
**Status:** Proposed  
**Scope:** Team Process, Knowledge Management  
**Issue:** #6

### Decision

Adopt a phased continuous learning system that uses WorkIQ to poll DK8S and ConfigGen Teams channels, generate structured digests, and promote recurring patterns into squad skills.

### Key Points

1. **Four channels to monitor:** DK8S Support (P0), ConfigGen Support (P0), DK8S Platform Leads (P1), BAND Collaboration (P2)
2. **WorkIQ is the data source** — no custom API integrations needed, but access is user-scoped (requires Tamir's channel membership)
3. **Phase 1 (immediate):** Manual scan protocol at session start — zero infrastructure, immediate value
4. **Phase 2 (weeks 2-3):** Standardized prompt templates for reproducible scans
5. **Phase 3 (weeks 4-6):** Pattern extraction pipeline with human-gated skill promotion
6. **Phase 4 (deferred):** GitHub Actions automation — blocked on WorkIQ API access from runners
7. **9 recurring patterns already identified** and promoted to `.squad/skills/` as initial seed

### Rationale

- The squad loses operational context between sessions because Teams channel knowledge isn't persisted
- WorkIQ already provides access to all four target channels
- File-based digests and skills align with existing squad architecture (no new infrastructure)
- Manual-first approach validates the pattern before investing in automation

### Consequences

- ✅ Squad starts each session with fresh operational context (< 7 days stale)
- ✅ Recurring support patterns are pre-loaded, reducing re-discovery time
- ✅ Skill library grows organically from real operational data
- ⚠️ WorkIQ access is user-scoped — breaks if Tamir loses channel access
- ⚠️ Digest privacy must be managed — internal support content in repo files
- ⚠️ Manual scanning adds session startup time (~5 min for 4 channels)

### Artifacts

- `continuous-learning-design.md` — Full design document
- `.squad/skills/dk8s-support-patterns/SKILL.md` — Initial DK8S patterns
- `.squad/skills/configgen-support-patterns/SKILL.md` — Initial ConfigGen patterns
- `.squad/digests/` — Directory for future digest storage

---

## Decision 19: Azure Fleet Manager Adoption for DK8S RP

**Author:** Picard (Lead)  
**Date:** 2026-03-07  
**Status:** Proposed  
**Impact:** High  
**Issue:** #3

### Decision

**DEFER** adoption of Azure Kubernetes Fleet Manager (AKFM) for DK8S RP.

Do not adopt now. Establish prerequisites for future adoption (H2 2026 or later).

### Context

Azure Fleet Manager was evaluated as a potential replacement/complement to DK8S's current multi-cluster management stack (ArgoCD + EV2 + ConfigGen). The evaluation covered AKFM capabilities, open-source alternatives (Rancher Fleet, KubeFleet, Kratix, Karmada), internal team discussions (Feb 12 & Feb 18 meetings), and identity/FIC blockers (Sept 2025 email thread).

### Rationale

1. **Identity is a hard blocker.** Workload Identity / FIC automation is unresolved. Fleet Manager amplifies identity brittleness when moving workloads across clusters. Team consensus from Feb 12 meeting: "identity binding is a block here."

2. **ROI unclear today.** ArgoCD + EV2 + ConfigGen handles current multi-cluster deployment needs. Fleet Manager's unique value (cluster replacement, blue/green) is not an operational need yet.

3. **Dual control plane risk.** Running Fleet Manager alongside ArgoCD creates competing reconciliation, ambiguous source of truth, and operational complexity the team flagged as "overkill."

4. **No better alternative exists.** Among OSS options evaluated, none provides a better fit than AKFM for DK8S when the time comes. Rancher Fleet (too much Rancher coupling), Kratix (different problem space), KubeFleet (too early). ArgoCD remains right for app delivery.

### Prerequisites for Revisiting

| # | Prerequisite | Status |
|---|-------------|--------|
| 1 | Workload Identity migration complete | In Progress |
| 2 | FIC automation validated | Blocked |
| 3 | Cluster replacement becomes operational need | Not yet |
| 4 | Fleet vs. ArgoCD swim lanes defined | Not started |
| 5 | EV2 + Fleet integration prototyped | Not started |

### Immediate Actions

- Track AKFM roadmap (sovereign cloud, ArgoCD integration)
- Resolve identity blockers independently of Fleet decision
- Time-boxed PoC when prerequisites 1-2 met

### Consequences

- ✅ Avoids premature complexity in an already-functioning deployment stack
- ✅ Preserves team focus on identity/FIC resolution (higher priority)
- ✅ Keeps AKFM as a viable future option with clear adoption criteria
- ⚠️ Delays potential cluster upgrade automation improvements
- ⚠️ Blue/green cluster replacement remains unavailable

### Full Analysis

See: `fleet-manager-evaluation.md`

---

## Decision 20: Fleet Manager Security — FIC and Identity Movement

**Date:** 2026-03-07  
**Author:** Worf (Security & Cloud)  
**Issue:** #3 — Azure Fleet Manager evaluation for DK8S RP  
**Status:** Proposed  
**Impact:** Critical

### Summary

Fleet Manager adoption for DK8S RP is a **CONDITIONAL NO-GO** from a security perspective. Four hard security gates must be satisfied before proceeding.

### Security Gates (All Must Pass)

| Gate | Condition | Current Status |
|------|-----------|----------------|
| **G1** | Workload Identity migration complete (retire AAD Pod Identity) | 🟡 In Progress |
| **G2** | Fleet Manager GA in US NAT, US SEC, Blue, Delos | 🔴 Not Met |
| **G3** | FIC scaling solution (Identity Bindings or equivalent) GA | 🔴 Preview Only |
| **G4** | Fleet Manager hub threat model documented | 🔴 Not Started |

### Critical Risks Identified

1. **FIC 20-per-UAMI ceiling** — DK8S scale (50+ clusters) exceeds per-identity FIC limit
2. **UAMI node exposure** — Shared fleet environments allow node-level identity access (Falcon team confirmed)
3. **Sovereign cloud gaps** — Features not available in all required clouds (hard constraint)
4. **Identity movement gaps** — No automated FIC lifecycle for cluster migration scenarios

### 17 Mitigations Proposed

See `fleet-manager-security-analysis.md` for full details:
- 4 pre-adoption requirements
- 5 architecture controls
- 4 operational controls
- 4 migration-specific controls

### Phased Adoption Path

- **Phase 0 (Q2 2026):** PoC in public cloud, non-production
- **Phase 1 (Q3 2026):** Limited production, public cloud only
- **Phase 2 (Q4 2026):** Multi-region public cloud
- **Phase 3 (2027+):** Sovereign clouds (dependent on AKS roadmap)

### Alignment

Aligns with Picard's architectural DEFER recommendation. Security gates are the primary blockers.

### Evidence Sources

- Feb 18, 2026 Defender/AKS meeting — identity blast radius, sovereign cloud constraints
- Partner FIC Document — UAMI exposure in shared fleets, zero-trust gaps
- EngineeringHub — FalconFleet FIC guide, Fleet Workload Identity Setup
- Public docs — Azure Fleet Manager MI, AKS Identity Bindings (preview)
