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

---

## Decision 5: Repository Organization — Squad Home vs. Research Outputs

**Date:** 2026-03-07  
**Author:** Picard (Lead)  
**Status:** ✅ Proposed  
**Scope:** Repository Architecture

### Context

Issue #34 raised by Tamir: This repository (tamresearch1) contains both:
1. Squad infrastructure (.squad/*, squad.config.ts, package.json)
2. Investigation reports and research artifacts (analysis-*.md, *-guide.md, etc.)

The question: Should investigation outputs live in separate dedicated repositories?

### Analysis

#### Current Repository Contents (66 files in root)

**Squad Infrastructure (BELONGS HERE):**
- .squad/* — agent charters, history, decisions, logs
- squad.config.ts — squad configuration
- package.json — squad-cli tooling
- .gitignore, .gitattributes — repo metadata
- ralph-watch.ps1 — squad automation

**Investigation Reports (27 files, SHOULD MOVE):**
- analysis-belanna-infrastructure.md (34 KB)
- analysis-data-code.md (35 KB)
- analysis-picard-architecture.md (40 KB)
- analysis-seven-repohealth.md (36 KB)
- analysis-worf-security.md (45 KB)
- idk8s-architecture-report.md (31 KB)
- idk8s-infrastructure-complete-guide.md (183 KB)
- cross-repo-analysis-idk8s-to-baseplatformrp.md (37 KB)
- workload-migration-deep-dive.md (33 KB)

**Research Artifacts (SHOULD MOVE):**
- aspire-kind-analysis.md, aurora-adoption-plan.md, aurora-cluster-provisioning-experiment.md, aurora-scenario-catalog.md, baseplatform-issues.md, continuous-learning-design.md, dk8s-infrastructure-inventory.md, dk8s-platform-knowledge.md, dk8s-stability-analysis.md, fleet-manager-evaluation.md, fleet-manager-security-analysis.md, rp-registration-guide.md, rp-registration-status.md

**SquadPlaces Test Data (SHOULD MOVE):**
- api-docs.yaml, artifact-detail.yaml, feed-*.yaml, squads-page.yaml, artifact*.json, comment*.json, squad-export.json, *.png screenshots, current-page.md, feed-*.md, squad-places-feed-*.md, artifact-with-comments.md

**Total:** 53 files (620+ KB) that don't belong in the squad home base.

### Decision

**AGREE with Tamir.** This repository should be the squad's home base and finite knowledge base — NOT a dumping ground for research outputs.

#### Architectural Principles

1. **Squad Home Base Contains:**
   - Agent definitions and history (.squad/agents/*)
   - Team decisions (.squad/decisions.md, .squad/decisions/inbox/*)
   - Squad configuration (squad.config.ts, package.json)
   - Team coordination artifacts (.squad/ceremonies.md, roster.md, routing.md)
   - Meta-documentation about HOW the squad works

2. **Research Outputs Belong In:**
   - Dedicated private repositories per investigation domain
   - Organized by subject matter (infrastructure, security, platform, etc.)
   - Versioned and tagged appropriately
   - Cross-referenced from squad decisions when relevant

3. **Boundary Test:**
   - "If this repo was deleted, would we lose the squad's ability to function?" → KEEP IT
   - "If this repo was deleted, would we lose research outputs?" → MOVE IT

#### Proposed Repository Structure

**Create 3 New Private Repos:**

1. **tamresearch1-dk8s-investigations** (Private)
   - Purpose: Deep-dive research on DK8S platform (idk8s-infrastructure, BaseplatformRP)
   - Scope: 13 files (420 KB) covering infrastructure, platform knowledge, migrations

2. **tamresearch1-agent-analysis** (Private)
   - Purpose: Cross-agent investigation reports (initial squad deep-dives)
   - Scope: 5 files (190 KB) of analysis reports from Picard, B'Elanna, Data, Seven, Worf

3. **tamresearch1-squadplaces-research** (Private)
   - Purpose: SquadPlaces API exploration, screenshots, test data
   - Scope: 35 files (1.1 MB) of API artifacts, test data, screenshots, documentation

### Impact

**Benefits:**
- ✅ Clear separation of concerns: squad infrastructure vs. research outputs
- ✅ Squad home base stays lean and focused
- ✅ Research repos can have own lifecycles (archive, share, fork)
- ✅ Easier to grant granular access (e.g., share dk8s-investigations with Azure team)

---

## Decision 6: Ralph Watch — Always Fetch/Pull Latest Code

**Date:** 2026-03-07  
**Author:** Tamir Dresher (via Copilot directive)  
**Status:** ✅ Adopted  
**Scope:** Ralph Watch Process

Ralph watch automation must fetch and pull latest code from the configured branch before each cycle begins. This is the first operation in Ralph's loop.

**Rationale:**
- Prevents stale code execution
- Ensures each cycle operates on current state
- Aligns squad work with latest repository changes

**Implementation:**
- Add `git fetch && git pull` as initial step in Ralph watch loop
- Applies to all configured branches
- Fail-safe: Log and skip pull if network/auth issues; proceed with local state

**Related:** Ralph activation round 1 (2026-03-07T16:42:08Z)

**Risks:**
- ⚠️ Increased repo count (4 repos instead of 1)
- ⚠️ Cross-repo linking requires discipline
- ⚠️ Git history fragmentation (mitigated by lineage notes)

**Mitigation:**
- Maintain .squad/research-repos.md catalog with links and descriptions
- Use conventional commit messages with cross-repo references
- Tag research repos consistently (e.g., v1.0-idk8s-analysis)

### Team Consensus

**Required:** Tamir approval before creating repos and moving files.

**Next Steps:**
1. Tamir reviews this decision (posted to issue #34)
2. If approved, Picard creates 3 new private repos
3. Picard executes migration plan
4. Scribe updates .squad/research-repos.md catalog
5. Close issue #34
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

---

## Decision 5: Ralph Auto-Pull Directive

**Date:** 2026-03-07  
**Author:** Tamir Dresher (via Copilot)  
**Issue:** #37  
**Status:** ✅ Adopted  
**Scope:** Ralph Watch Behavior

Ralph watch should always fetch/pull the latest code from the branch before each cycle. First thing Ralph does in the loop is git fetch && git pull.

**Rationale:** Prevent stale code issues where squad members have made changes but Ralph isn't picking them up.

**Implementation:** Updated ralph-watch.ps1 to execute git fetch and pull at the start of each watch cycle before processing issues.

**Related:** Data agent completed implementation and committed changes in round 3.


---

# Triage Decision: Issue #42 — Patent Analysis

**Routed to:** Seven (Research & Docs)  
**Label:** `squad:seven`  
**Date:** 2025-01-21

## Decision

Issue #42 asks for a comprehensive review of Microsoft internal patent policies and analysis of whether the squad multi-agent architecture and integration approach could be patentable.

This is fundamentally a **research and analysis task**:
- Requires investigation into internal IP guidance
- Requires understanding patent landscape and principles
- Requires synthesis across existing work
- Produces a technical advisory document

**Routing rationale:** Seven owns research, documentation, and technical analysis. This task aligns directly with that charter.

## Next Steps

Seven will:
1. Review Microsoft internal patent guidance and policies
2. Assess the squad architecture and integration patterns for patentability
3. Produce an analysis and recommendation
4. Present findings in issue #42

---

# Decision: Repository Organization via Topic-Based Splitting

**Date:** 2026-03-07  
**Decider:** Picard  
**Status:** Executed  
**Issue:** #34

## Context

tamresearch1 repo contained 61+ research files covering 3 distinct topics:
- DK8S platform investigations (architecture, infrastructure, workload migration)
- Squad formation analysis (5 agent investigation reports)
- SquadPlaces API exploration (screenshots, test data, API docs)

All mixed together in root directory alongside core squad infrastructure (.squad/, configs).

## Decision

Split research artifacts into 3 dedicated private repositories:
1. `tamresearch1-dk8s-investigations`
2. `tamresearch1-agent-analysis`
3. `tamresearch1-squadplaces-research`

Preserve core squad infrastructure in tamresearch1.

## Rationale

**Problem:** Growing root directory clutter makes navigation difficult. Three distinct research topics deserve isolation.

**Benefits of Split:**
1. **Topical Isolation:** Each repo focuses on single domain
2. **Access Control:** Private repos protect research/screenshots from public exposure
3. **Discoverability:** Topic-specific repos easier to share with stakeholders
4. **Clean Main Repo:** tamresearch1 becomes squad infrastructure hub, not research archive

**Preserved Infrastructure:**
- `.squad/` directory (agents, decisions, skills, history)
- `squad.config.ts`, package files, node_modules
- `ralph-watch.ps1` monitoring script
- Summary files (EXECUTIVE_SUMMARY.md, etc.)

## Execution Protocol

1. Create private repos with `gh repo create --private`
2. Clone each repo to temp directory
3. Copy relevant files to each repo
4. Add migration headers to markdown/yaml: `<!-- Moved from tamresearch1 on 2026-03-07 -->`
5. Commit with descriptive messages + co-author trailer
6. Push to main branch
7. Verify all pushes succeeded
8. Delete migrated files from tamresearch1
9. Create `.squad/research-repos.md` catalog
10. Commit cleanup to tamresearch1

## Outcome

- **61 files migrated** across 3 repos
- **tamresearch1 cleaned:** Root directory now contains only active files + .squad/ infrastructure
- **Catalog created:** `.squad/research-repos.md` provides navigation to all research repos
- **Issue #34 closed** with completion report

## Key Insight

**Catalog files are not optional.** When splitting repositories, a catalog file in the main repo is the index to the distributed knowledge graph. Without it, knowledge becomes fragmented and unfindable.

## Alternatives Considered

1. **Git submodules:** Too complex for read-only research artifacts
2. **Monorepo with directories:** Doesn't solve access control or navigation
3. **Single research-archive repo:** Loses topical isolation

## Related Decisions

- Continuous learning system design (Issue #6) — skills stay in tamresearch1
- Ralph monitoring setup — monitoring script stays in tamresearch1

---

# Decision: GitHub-Teams Integration Approach

**Date:** 2026-03-07  
**Author:** Data  
**Issue:** #33  
**Status:** Recommended

## Context

Tamir requested automation of GitHub-Teams integration setup, asking specifically about:
1. Using Playwright CLI with Edge browser
2. Alternative Windows automation tools for Teams desktop app
3. Avoiding manual browser steps

## Investigation

Researched three approaches:
1. **Microsoft Graph API** - ✅ Best option
2. **Playwright browser automation** - ❌ Not applicable (Teams is native app)
3. **Windows UI automation** - ❌ Fragile, complex, security concerns

## Key Findings

### What CAN Be Automated (Graph API)
- **App Installation**: GitHub app installation to Teams via `New-MgTeamInstalledApp` cmdlet
- **Team/Channel Discovery**: Programmatic team and channel enumeration
- **Permissions**: Requires `TeamsAppInstallation.ReadWriteForTeam` scope

**GitHub App ID**: `0d820ecd-def2-4297-adad-78056cde7c78` (verified from Microsoft docs)

### What CANNOT Be Automated
- **`@GitHub signin`**: Initiates GitHub OAuth flow requiring user consent
- **`@GitHub subscribe`**: Bot command that needs authenticated context
- **Reason**: Security by design - OAuth flows must have user interaction

## Recommended Solution

**Hybrid Approach**:
1. **Automated** (PowerShell + Graph API): Install GitHub app to team
2. **Manual** (< 2 min): User completes OAuth signin and subscription in Teams

## Implementation

Created `setup-github-teams-integration.ps1`:
- Authenticates with Microsoft Graph
- Lists available teams
- Installs GitHub app programmatically
- Provides clear manual step instructions

**Time Savings**: Reduces setup from ~5 minutes to ~2 minutes (60% reduction)

## Alternative Considered: Windows UI Automation

Evaluated tools:
- **UI Automation API** (C#/.NET)
- **Power Automate Desktop**
- **AutoHotkey**

**Why Rejected**:
- Teams desktop UI changes frequently (brittle)
- No reliable element selectors for bot interactions
- Security context issues (user must be signed in)
- Complexity >> benefit

## Security Notes

- Graph API requires admin consent for team-level permissions
- OAuth flows correctly require interactive user consent (can't be bypassed)
- Script uses delegated permissions (runs as user, not app-only)

## References

- [Microsoft Graph: Install app to team](https://learn.microsoft.com/en-us/graph/api/team-post-installedapps)
- [GitHub Teams Integration](https://github.com/integrations/microsoft-teams)
- PowerShell module: `Microsoft.Graph.Teams` v2.26.1



---

## Decision: OpenCLAW Pattern Analysis (Seven Round 4)

# Issue #23: Apply OpenCLAW Patterns — Analysis & Implementation Plan

**Author:** Seven (Research & Docs Expert)  
**Date:** 2026-03-10  
**Request:** Tamir Dresher  
**Reference:** Issue #23  
**Scope:** Evaluate and propose Squad adoption of three OpenCLAW patterns

---

## Executive Summary

This analysis evaluates three OpenCLAW production patterns for Squad adoption:

1. **QMD Framework (Question-Model-Data)** → **Recommended: Adopt immediately (Phase 1)**
2. **Dream Routine** → **Recommended: Adopt as Phase 2.5 intermediate step**
3. **Issue-Triager Scanner** → **Recommended: Adopt as Channel Scanner enhancement (Phase 2)**

All three patterns **directly address gaps** identified in our continuous learning design (CONTINUOUS_LEARNING_PHASE_1.md). Combined effort: 4-6 weeks. Team value: High (improves signal quality, cross-digest analysis, triage automation).

---

## Pattern 1: QMD Framework (Question-Model-Data → Quality Memory Digest)

### What Is It?

**QMD** is OpenCLAW's 5-category extraction taxonomy for filtering signal from noise in unstructured observations:

```
Quality Memory Digest = {
  - Decisions made        (architectural choices, governance, policy changes)
  - Commitments created   (deadlines, ownership, delivery promises)
  - Pattern changes       (frequency shifts, new failure modes, resolution drift)
  - Blockers + resolutions (blocked items, what unblocked them, when)
  - Drop (routine ops)    (simple Q&A, repeated status updates, noise)
}
```

**Why OpenCLAW uses it:** Running 50+ agents 24/7 means massive observation volume. Without categorization, memory becomes write-only noise. QMD separates signal (decisions, commitments, patterns) from noise (routine operations). DevBot's memory stays lean and queryable.

### How OpenCLAW Implements QMD

1. **Post-session extraction:** After each agent session, LLM categorizes observations into 5 buckets
2. **Memory storage:** Only signal categories (decisions, commitments, patterns, blockers) are persisted; noise is discarded
3. **Query optimization:** Cross-agent queries can now target specific categories (find all commitments from last week, all pattern changes, all blockers)
4. **Confidence calibration:** DevBot explicitly marks confidence (High/Medium/Low) on each item before persisting

### How Squad Could Adopt QMD

**Current gap:** Our continuous learning design (Phase 1) extracts insights from Teams channels but has no categorization framework. Digests become shallow (list of observations) rather than deep (actionable patterns).

**Proposed adoption:**

1. **Add QMD to Digest Template** (CONTINUOUS_LEARNING_PHASE_1.md template update)
   ```
   ## Digest: [Channel] — [Date Range]
   
   ### 🎯 Decisions Made
   - [Decision 1]: [context] (source: @username, timestamp)
   - [Decision 2]: ...
   Confidence: High / Medium / Low
   
   ### ✅ Commitments Created
   - [Commitment 1]: [owner, deadline] (source: ...)
   - [Commitment 2]: ...
   Confidence: High / Medium / Low
   
   ### 🔄 Pattern Changes
   - [Pattern 1]: [old → new] (evidence: N incidents, last 2 weeks)
   - [Pattern 2]: ...
   Confidence: High / Medium / Low
   
   ### 🚧 Blockers + Resolutions
   - [Blocker 1]: [status, resolution date, what unblocked it] (source: ...)
   - [Blocker 2]: ...
   Confidence: High / Medium / Low
   
   ### 🗑️ Drop (Routine Ops — Not Extracted)
   - Routine escalations, simple Q&A responses, status updates
   - Decision: These are important but not actionable patterns
   ```

2. **Phase 1 Implementation (Agents Apply to Teams Channels)**
   - Scribe + agents manually categorize observations from Teams channels
   - Builds QMD muscle; later automated in Phase 2
   - Immediate benefit: Digests become queryable by category

3. **Phase 2: LLM-Assisted QMD Extraction**
   - LLM auto-categorizes in-session observations
   - Agents review + confirm before persisting
   - Maintains confidence calibration (LLM might be high-confidence but wrong)

4. **Storage & Querying**
   - Digests stored in `.squad/digests/[channel]/[date].md` with QMD structure
   - Query template: `SELECT all Decisions from #dk8s-support digests [last 30 days]`
   - Enables Decision Ledger to pull decisions automatically (decision.md generation becomes semi-automated)

### Assessment for Squad

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Effort to Implement** | 🟢 Low (1-2 weeks) | Add 5 sections to template, update Phase 1 workflow, no infrastructure changes |
| **Value Add** | 🟢 High | Solves "signal vs noise" problem; directly improves digest quality; enables automation downstream |
| **Dependencies** | 🟡 Medium | Requires Phase 1 cadence active (already underway); no blocking dependencies |
| **Team Buy-In** | 🟢 High | Addresses problem agents already recognize (too much noise in channels) |
| **Long-Term ROI** | 🟢 High | Foundation for all Phase 2+ automation; confidence calibration prevents bad actors from gaming memory |

**Risk Mitigation:**
- Start with High-confidence items only; allow Medium/Low to accumulate before acting on them
- Don't over-optimize early; Phase 1 is learning, not perfection
- Validate QMD categorization on 2-3 test digests before rolling out to team

---

## Pattern 2: Dream Routine (Cross-Digest Pattern Detection)

### What Is It?

**Dream Routine** is OpenCLAW's background pattern detection loop that runs *between* sessions:

```
Dream Routine (scheduled nightly) {
  for each agent:
    scan digests from last N days
    detect trending topics (frequency increase/decrease)
    flag items meeting promotion criteria
    surface resolved blockers & stalled items
    log findings for next morning's standup
}
```

**Why OpenCLAW uses it:** Individual sessions capture point-in-time observations. Dream Routines aggregate across sessions to detect *trends* (incident spike, repeated blocker, newly successful pattern). DevBot's team gets a "what changed?" briefing every morning without running ad-hoc queries.

### How OpenCLAW Implements Dream Routine

1. **Scheduled execution:** Nightly at midnight, cross-session aggregation runs
2. **Trend detection:** Simple heuristics
   - Incident count [today] > 2x [past week avg] → escalate
   - Item appears in digests from N different channels → cross-functional issue
   - Item marked "resolved" consistently → remove from tracking
3. **Output:** Markdown report emailed to team summarizing trends, blockers, recommendations
4. **Memory update:** Trends are fed back to individual agent memories (closed-loop learning)

### How Squad Could Adopt Dream Routine

**Current gap:** Our Phase 1 design scans channels per-session (capture observations) but never analyzes *across* digests to detect trends. Phase 2 (skill promotion) requires manual review of accumulated digests. Dream Routines automate this and create Phase 2.5.

**Proposed adoption (New Phase 2.5):**

1. **Insert Dream Routine Between Phase 2 and Phase 3**
   ```
   Phase 1: Channel Scanning (weekly, manual)
             ↓
   Phase 2: Digest Creation (per-channel, manual categorization)
             ↓
   ✨ DREAM ROUTINE (nightly, automated) ← NEW
             ↓
   Phase 3: Skill Promotion (quarterly, manual with Dream Routine input)
   ```

2. **Specific Implementation for Squad**

   **Dream Routine Tasks:**
   ```
   # .squad/scripts/dream-routine.ps1 (nightly cron)
   
   foreach ($channel in $MONITORED_CHANNELS) {
     $digests = Get-Digests -Channel $channel -Days 14
     
     # Trend Detection
     $decisions = Extract-QMD($digests, "Decisions")
     $trend = Detect-FrequencyChange($decisions)
     
     $blockers = Extract-QMD($digests, "Blockers")
     $persistent = Find-PersistentBlockers($blockers, days: 7)
     
     $patterns = Extract-QMD($digests, "Pattern Changes")
     $significant = Filter-HighConfidence($patterns, confidence: "High")
     
     # Promotion Candidates
     $candidates = Find-SkillCandidates($digests, rules: {
       frequency: "appears in 3+ digests",
       recency: "within last 14 days",
       utility: "team confirms in survey"
     })
     
     # Output
     Write-PromotionReport -Channel $channel -Trends $trend -Persistent $persistent -Candidates $candidates
   }
   
   # Email report to Scribe + team
   Send-Email -Subject "Dream Routine: Trends & Promotion Candidates" -Recipients @("squad@", "picard@")
   ```

3. **Dream Routine Output (Daily 9 AM Report)**
   - Trending topics (incidents increasing, resolution time improving, new patterns emerging)
   - Persistent blockers (same issue appears 5+ days in a row)
   - Skill promotion candidates (3+ appearances, high confidence, team utility confirmed)
   - Actions for humans (Scribe reviews + routes to appropriate agents)

4. **Feedback Loop**
   - Scribe reviews dream routine output every morning
   - Routes to agents: "ConfigGen just had 3 incidents with same root cause—add to troubleshooting skill"
   - Agents execute: Extract pattern, add to skill, propose decision
   - Loop closes: Decisions feed back to institutional memory

### Assessment for Squad

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Effort to Implement** | 🟡 Medium (2-3 weeks) | Requires trend detection algorithms, scheduled execution (Azure DevOps cron or GitHub Actions), reporting template |
| **Value Add** | 🟢 High | Closes gap between Phase 2 (individual digests) and Phase 3 (skill promotion); makes pattern detection continuous, not manual |
| **Dependencies** | 🟡 Medium | Requires QMD framework (Phase 1) + 2-3 weeks of active Phase 1 channel scanning to have enough data |
| **Team Buy-In** | 🟢 High | Saves Scribe 1-2 hours daily; gives team early warning of trends before they become crises |
| **Long-Term ROI** | 🟢 High | Foundation for Phase 3 automation; enables skill promotion without manual backlog review; creates institutional memory of "what changed" |

**Implementation Priority:**
1. ✅ Get QMD framework working (1-2 weeks, Phase 1)
2. ✅ Accumulate 2-3 weeks of QMD digests (3 weeks, Phase 1)
3. **→ Implement Dream Routine** (2-3 weeks, Phase 2.5)
4. Use Dream Routine output to drive Phase 3 skill promotion

**Risk Mitigation:**
- Start with simple trend detection (incident count delta); add sophistication later
- Manual review required for all recommendations (no auto-promotion)
- If trend detection is wrong 2+ times, pause and re-calibrate algorithms

---

## Pattern 3: Issue-Triager Scanner (Classification + Priority + Escalation)

### What Is It?

**Issue-Triager** is OpenCLAW's sub-agent that transforms reactive scanning into proactive triage:

```
Issue-Triager (DevBot use case) {
  daily cron → query issue API
           → classify (incident / decision / question / coordination)
           → assign priority (P0-P3 scoring)
           → escalate P0 → immediate human review
           → log decisions in audit trail
}
```

**Why OpenCLAW uses it:** DevBot's team was drowning in GitHub issue noise. They built Issue-Triager to:
1. **Classify** issues by type (not all issues are created equal)
2. **Prioritize** with explicit criteria (P0 = production outage, P1 = blocking, P2 = planned, P3 = cleanup)
3. **Escalate** P0 items immediately (no queue; straight to humans)
4. **Log decisions** (audit trail: why this was classified as P2, who escalated it)

Result: Team went from "500 open issues, don't know where to start" to "3 P0 items waiting for you, rest are backlog."

### How OpenCLAW Implements Issue-Triager

1. **Daily run:** GitHub Issues API query → paginate through repos + projects
2. **Classification:** LLM reads issue title + labels + recent comments → "is this an incident?"
3. **Scoring:** Rules engine (production keyword? → P0; blocked by someone? → P1; feature request? → P3)
4. **Escalation:** P0 items → Slack ping to on-call → GitHub action closes stale items
5. **Audit trail:** Every decision logged to `triage.log` (compliance + learning)

### How Squad Could Adopt Issue-Triager

**Current gap:** Squad's "Channel Scanner" (Phase 2 design) is query-and-store: scan Teams channels, store observations, wait for humans to find insights. This is note-taking, not triage.

OpenCLAW's Issue-Triager shows what "triage-as-first-class-citizen" looks like:
- Classification (incident vs. decision vs. question)
- Priority assignment (explicit criteria, visible to team)
- Escalation (P0 → immediate action, P3 → backlog)
- Audit trail (decisions logged, not lost)

**Proposed adoption (Enhancement to Phase 2 Channel Scanner):**

1. **Current Channel Scanner (Phase 2 design)**
   ```
   Teams Channel → query messages from last 24h
               → extract observations
               → store in .squad/digests/channel/
               → wait for Scribe manual review
   ```

2. **Enhanced with Issue-Triager Pattern**
   ```
   Teams Channel → query messages from last 24h
               → extract observations
               → CLASSIFY: incident / decision / question / coordination
               → PRIORITIZE: P0 (production issue) / P1 (blocking) / P2 (planned) / P3 (routine)
               → ESCALATE: P0 → immediate Slack alert to on-call
               → store in .squad/digests/channel/ with metadata
               → log decision to audit trail (.squad/logs/triage.log)
   ```

3. **Classification Rules for Squad**

   | Type | Detection | Example |
   |------|-----------|---------|
   | **Incident** | Keywords: outage, down, broken, failure, error spike, critical | "DK8S prod cluster DNS broken, 100 pods affected" |
   | **Decision** | Keywords: approved, decided, we're going with, after discussion | "Architecture review approved ConfigGen migration to async" |
   | **Question** | Format: ?, help with, how do I, troubleshooting | "How do we handle etcd failover?" |
   | **Coordination** | Keywords: meeting, sync, please join, FYI, heads up | "Cross-team meeting Thurs 2pm re: AKS networking" |

4. **Priority Scoring Rules**

   | Priority | Criteria | Action |
   |----------|----------|--------|
   | **P0** | Production impact + requires immediate response | Slack alert to on-call; GitHub action creates issue; flag in standup |
   | **P1** | Blocking multiple teams OR blocking current sprint | Added to squad inbox; reviewed within 24h |
   | **P2** | Important but not urgent OR planned work | Added to backlog; reviewed within 1 week |
   | **P3** | Routine, context, cleanup | Digested; monthly review for pattern extraction |

5. **Implementation: Channel Scanner with Triage (Phase 2 Enhancement)**

   ```powershell
   # .squad/scripts/channel-scanner-with-triage.ps1 (daily cron)
   
   foreach ($channel in $TEAMS_CHANNELS_TO_MONITOR) {
     $messages = Get-TeamsMessages -Channel $channel -Last 24h
     
     foreach ($message in $messages) {
       # Extract observation
       $obs = Extract-Observation($message)
       
       # Classify
       $class = Classify-Message($obs, rules: @{
         incident: "outage|down|broken|error spike"
         decision: "approved|decided|going with"
         question: "how.*\?|help.*with"
         coordination: "meeting|sync|FYI"
       })
       
       # Prioritize
       $priority = Score-Priority($obs, rules: @{
         P0: "production AND (impact > 10 pods OR customer)"
         P1: "blocking AND (team_count > 1 OR sprint_blocker)"
         P2: "important AND NOT urgent"
         P3: "routine OR context"
       })
       
       # Escalate if P0
       if ($priority -eq "P0") {
         Send-Slack -Channel "#squad-alerts" -Message "🚨 P0 from $channel: $obs"
         Create-GitHubIssue -Title "URGENT: $obs" -Labels @("P0", "incident", $channel)
       }
       
       # Store
       Add-ToDigest -Channel $channel -Observation @{
         text: $obs
         classification: $class
         priority: $priority
         source: $message.link
         timestamp: $message.timestamp
       }
       
       # Log decision
       Log-TriageDecision -Message "Classified as $class, priority $priority" -Source $message.link
     }
   }
   ```

6. **Output & Team Integration**

   **Daily 9 AM Digest:**
   ```
   # Squad Triage Report — 2026-03-11
   
   ## 🚨 P0 Items (Immediate Action)
   - DNS resolution timeout in prod cluster (DK8S support channel)
   - ConfigGen SDK breaking change in 2.1.0 release (ConfigGen channel)
   
   ## 🔴 P1 Items (Within 24h)
   - EV2 deployment pipeline blocked on permission review (DevOps channel)
   - 3-way cluster failover testing scheduled (Platform channel)
   
   ## 🟡 P2 Items (This Sprint)
   - Architecture review for async ConfigGen (Architecture channel)
   - Istio upgrade decision needed (Networking channel)
   
   ## 🟢 P3 Items (Backlog)
   - 12 routine escalations, Q&A responses
   - Context updates from 3 channels
   ```

   **Audit Trail (for compliance + learning):**
   ```
   2026-03-11 09:15:42 | "DNS resolution timeout..." | classified: incident | priority: P0 | rule: "production AND (impact > 10 pods)" | escalated: true
   2026-03-11 09:16:00 | "ConfigGen breaking change..." | classified: incident | priority: P0 | rule: "customer impact" | escalated: true
   2026-03-11 09:18:30 | "EV2 deployment blocked..." | classified: decision | priority: P1 | rule: "blocking AND team_count > 1" | escalated: false
   ```

### Assessment for Squad

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Effort to Implement** | 🟡 Medium (2-3 weeks) | Classification rules need tuning, priority scoring needs team calibration, audit logging infrastructure |
| **Value Add** | 🟢 High | Transforms Channel Scanner from passive note-taking to active triage; P0 escalation prevents incidents from being lost; audit trail enables learning |
| **Dependencies** | 🟢 Low | No dependencies on QMD or Dream Routine (can be implemented independently); works on Phase 2 Channel Scanner design |
| **Team Buy-In** | 🟢 High | Addresses immediate pain (drowning in channel noise); P0 escalation feels like "someone is watching"; audit trail provides compliance |
| **Long-Term ROI** | 🟢 High | Incident response time decreases; on-call efficiency increases; triage history informs future automation |

**Implementation Priority:**
1. Implement Phase 2 Channel Scanner (base functionality)
2. Add classification rules (week 1)
3. Add priority scoring (week 1-2)
4. Add P0 escalation + audit trail (week 2-3)
5. Team calibration & tuning (ongoing)

**Risk Mitigation:**
- Start with simple classification (incident vs. not); add sophistication later
- Manual review for all P0 escalations initially (no auto-actions)
- If priority scoring is wrong 3+ times, pause and re-calibrate rules
- Audit trail required for all decisions (compliance + learning)

---

## Comparative Analysis: How Patterns Work Together

### Dependency Flow

```
Phase 1: QMD Framework (signal vs. noise filtering)
         ↓
Phase 2: Channel Scanner + Issue-Triager (active triage, classification, escalation)
         ↓
Phase 2.5: Dream Routine (cross-digest trend detection)
         ↓
Phase 3: Skill Promotion (with Dream Routine + audit trail input)
```

### Use Case: "What Changed This Week?"

**Without these patterns:**
- Scribe manually reviews 5 channels, 200+ messages
- Extracts ~10-15 observations
- Stores as unstructured text
- **Manual process; takes 2-3 hours; fragile and incomplete**

**With all three patterns adopted:**
1. **QMD Framework** categorizes observations automatically as they're captured
2. **Issue-Triager** flags P0 incidents immediately (no waiting for Scribe)
3. **Dream Routine** nightly aggregates: "Incident frequency up 40% this week, ConfigGen blockers down, 1 item ready for skill promotion"
4. **Output:** Scribe gets automated report; spends 15 min reviewing, routing, acting
5. **Result:** Same insights, 80% less manual work; earlier escalation of P0 items**

---

## Adoption Roadmap (8-Week Plan)

### Week 1-2: QMD Framework (Phase 1 Enhancement)
- Update digest template with 5 categories + confidence levels
- Pilot with 2 channels (DK8S support, ConfigGen)
- Scribe + agents manually categorize observations
- Validate: Are digests now more queryable?

### Week 3-4: Channel Scanner + Issue-Triager (Phase 2)
- Build Channel Scanner base (query Teams API, store observations)
- Add Issue-Triager classification rules (incident/decision/question/coordination)
- Implement priority scoring (P0-P3)
- Test with 1-2 channels

### Week 5-6: P0 Escalation + Audit Trail
- Add Slack/GitHub escalation for P0 items
- Log all triage decisions to audit trail
- Team calibration: tune classification rules + priority scores based on week 3-4 pilot

### Week 7-8: Dream Routine (Phase 2.5)
- Implement trend detection (frequency delta, persistent blockers)
- Accumulate 2+ weeks of QMD-categorized digests + triage logs
- Nightly aggregation + daily report
- Team feedback: does Dream Routine output match intuition?

### Ongoing: Phase 3 Input
- Dream Routine becomes input to skill promotion decision
- Audit trail becomes compliance + learning artifact

---

## Cost-Benefit Analysis

### Development Effort
- **QMD Framework:** 1-2 weeks (template update + manual categorization practice)
- **Issue-Triager:** 2-3 weeks (classification rules, scoring, escalation)
- **Dream Routine:** 2-3 weeks (trend detection, reporting, feedback loop)
- **Total:** 5-8 weeks team effort (can be parallelized)

### Immediate Benefits (Weeks 1-4)
- Digest quality improves 50% (QMD filtering)
- P0 incidents caught & escalated within 1h (Issue-Triager escalation)
- Scribe workload reduced 30% (Phase 2 Channel Scanner automation)
- Audit trail created (compliance + learning)

### Medium-Term Benefits (Weeks 5-8)
- Pattern detection becomes continuous (Dream Routine)
- Skill promotion candidates identified automatically (Dream Routine + audit trail)
- Team confidence in Squad memory increases (visible categorization + escalation)

### Long-Term Benefits (Phase 3+)
- Phase 3 skill promotion requires 50% less manual review (Dream Routine input)
- Incident response time decreases 25-30% (earlier detection + P0 escalation)
- Institutional memory becomes machine-queryable (all decisions + patterns categorized)

---

## Risks & Mitigations

### Risk 1: Over-Categorization (QMD Analysis Paralysis)
**Problem:** Team spends too much time deciding "is this a decision or a commitment?"
**Mitigation:** 
- Accept "good enough" categorization in Phase 1
- Allow multiple tags (item can be both decision + commitment)
- Use confidence levels (Medium/Low acceptable while learning)

### Risk 2: Bad Prioritization Rules (Issue-Triager Gives Wrong Scores)
**Problem:** Innocent messages get P0'd; critical items get P3'd
**Mitigation:**
- Manual review of all P0 items in weeks 1-2
- Weekly calibration meetings (team reviews scoring misses)
- If >20% accuracy on priority, pause and retune rules

### Risk 3: Dream Routine False Positives (Trend Detection Over-Triggers)
**Problem:** "Incident frequency up 40%" turns out to be normal variation
**Mitigation:**
- Require 3+ data points before flagging as trend
- Use confidence intervals (only flag if 90%+ confidence)
- Scribe reviews all recommendations; no auto-actions

### Risk 4: Audit Trail Overload (Compliance Burden)
**Problem:** Logging every triage decision creates huge files, no one reads them
**Mitigation:**
- Compress/archive logs older than 30 days
- Auto-summarize logs weekly (like Dream Routine output)
- Use for learning, not compliance initially

---

## Recommendation

**Adopt all three patterns in this order:**

1. ✅ **Start with QMD Framework immediately** (Week 1)
   - Lowest effort, highest immediate value
   - Enables all downstream improvements
   - No risk; just a template update

2. ✅ **Implement Issue-Triager with Channel Scanner** (Weeks 3-5)
   - Medium effort, high immediate ROI
   - Catches P0 incidents early
   - Enables audit trail (compliance requirement anyway)

3. ✅ **Add Dream Routine** (Weeks 6-8)
   - Medium effort, excellent long-term ROI
   - Foundation for Phase 3 automation
   - Makes pattern detection continuous

**Why this order:**
- QMD is the foundation (all downstream patterns depend on categorized data)
- Issue-Triager delivers immediate business value (P0 escalation)
- Dream Routine requires data accumulation (needs weeks 1-5 of QMD + triage logs)

**Success metrics (8 weeks):**
- Digest signal-to-noise ratio improves 50%+
- P0 incidents caught & escalated within 1 hour (vs. next morning check now)
- Dream Routine identifies 1-2 actionable trends per week
- Team morale increases (feel like someone is watching, taking action)

---

## References

- OpenCLAW article: [OpenCLAW in the Real World](https://trilogyai.substack.com/p/openclaw-in-the-real-world)
- Squad decisions: `.squad/decisions.md` (Decision 15: OpenCLAW patterns)
- Continuous learning design: `CONTINUOUS_LEARNING_PHASE_1.md`
- Phase 1 implementation guide: `.squad/skills/dk8s-support-patterns/SKILL.md` (example)
- Issue #13: OpenCLAW research (earlier analysis)
- Issue #32: Squad capability expansion

---

## Next Steps (If Approved)

1. **Scribe + Picard:** Review this analysis, confirm priority & timeline
2. **Week 1:** Update digest template, pilot QMD with DK8S + ConfigGen channels
3. **Week 2:** Team feedback on QMD categorization, adjust as needed
4. **Week 3:** Begin Phase 2 Channel Scanner implementation (parallel path)
5. **Weekly:** Sync on progress, adjust scope based on team capacity

---

**Seven (Research & Docs Expert)**  
**Ready to support implementation of any/all patterns.**


---

## Decision: Status Labels for Issue Visibility

**Date:** 2026-03-07  
**Decision Owner:** Picard  
**Status:** Implemented



**Date:** 2025-01-XX  
**Decision Owner:** Picard  
**Status:** Proposed

## Problem
Issue #43: User (Tamir) needs visibility into which issues the squad is actively working on vs. which are waiting for his input. Current approach lacks GitHub-native filtering/sorting.

## Solution
Implement four status labels to enable user-side filtering in GitHub issues interface:

| Label | Color | Meaning |
|-------|-------|---------|
| `status:in-progress` | Yellow (#FBCA04) | Squad actively working |
| `status:pending-user` | Purple (#7057FF) | Blocked waiting for user input/decision |
| `status:done` | Green (#0E8A16) | Work complete, ready to close |
| `status:blocked` | Red (#B60205) | Blocked on external dependency |

## How It Works
1. **Discoverability:** User can now filter in GitHub issues UI with `label:status:pending-user` or similar
2. **Maintenance:** Squad updates labels as work progresses through stages
3. **Mapping:** Applied retroactively based on deliverable presence:
   - Issues with output files in repo → `status:pending-user` (waiting for feedback)
   - Issues actively in progress → `status:in-progress`
   - Issues with completed work → `status:done`
   - Issues with blockers → `status:blocked`

## Initial Application
- **#42** (Patent Research) → `status:pending-user`
- **#41** (Blog Draft) → `status:in-progress`
- **#39** (Continuous Learning) → `status:pending-user`
- **#35** (Research Report) → `status:pending-user`
- **#33** (Teams Integration) → `status:done`
- **#43** (This triage) → `status:in-progress`
- Others without deliverables: No status (backlog)

## Benefits
- **User Control:** Tamir can see at a glance which issues need his action
- **Squad Clarity:** Clear handoff points between squad work and user decisions
- **GitHub Native:** No external tools required, works in standard GitHub issues interface
- **Queryable:** Enables dashboards, automation, and reporting via label filters

## Implementation Notes
Labels created via `gh label create` with `--force` to allow updates.
Squad responsible for maintaining accuracy as work progresses.


---

## Decision: Issue Status & Team-Relevant Findings

**Date:** 2026-03-07  
**Decision Owner:** Seven (Research & Docs)  
**Status:** Needs Team Input



**Date:** 2026-03-13  
**Author:** Seven (Research & Docs)  
**Status:** Needs Team Input  
**Scope:** Team Priorities  

---

## Summary

Completed status check on 4 assigned issues. Two require Tamir's decision; one needs clarification; one is blocked waiting for next action.

---

## Findings

### Issue #42 — Patent Research (DECISION GATE)
**Status:** Research Complete ✅ | Decision Required  

**What's Ready for Tamir:**
- Comprehensive prior art analysis (Squad vs NEC patent WO2025099499A1, CrewAI, MetaGPT, LangGraph, gitclaw)
- Patent strategy recommendation: File narrow, defensible claims (Ralph monitoring + casting governance)
- Risk assessment: Skip broad multi-agent claims (heavily prior-art'd)
- Microsoft patent process documented with costs ($3-5K, all covered by Microsoft)

**Decision Gate (Tamir Must Answer):**
1. Inventorship: Who conceived Ralph monitoring, casting, git-state, drop-box patterns?
2. Public disclosure: Has Squad already been mentioned in blog, GitHub, or presentations?
3. gitclaw timeline: When did gitclaw development start vs Squad?
4. Filing scope: US only or international?
5. Strategic intent: Defensive (prevent copying) or offensive (monetization)?

**Timing:** CRITICAL. If Squad disclosed publicly, 60-day grace period clock is running. File provisional patent BEFORE any public announcement.

**Recommendation:** File this week if Tamir decides yes; then publish blog and announcements freely.

---

### Issue #41 — Blog Draft (REVIEW GATE)
**Status:** Content Complete ✅ | Review Required  

**What's Ready for Tamir:**
- Full 2,500-word blog draft with 9 image placeholder descriptions
- Narrative: Personal (I'm not organized) → Problem (tools fail) → Solution (AI Squad) → How It Works (examples) → Lessons → Try It Yourself
- Includes real code (ralph-watch.ps1), real issues (#23, decision from Worf), real team structure
- Engineer-appropriate tone: Systems thinking, not marketing speak

**Decision Gate (Tamir Must Answer):**
1. Content edits or revisions needed?
2. Which sections resonate most with intended audience?
3. Publication venue: Blog, Medium, dev.to, internal Microsoft channel?
4. Timeline: Publish before or after patent filing?

**Next Action:** Tamir reviews, provides feedback, decides publication timing.

---

### Issue #32 — OpenCLAW vs Squad (RESEARCH COMPLETE)
**Status:** Finding Delivered ✅ | No Action Needed  

**What We Learned:**
- Squad is NOT reinventing the wheel; solving a different problem than OpenCLAW ecosystem
- gitclaw is closest comparison (both git-native)
- Squad's genuine differentiation: GitHub as work queue, persistent agent memory, decision ledger, casting/identity system, work monitor (Ralph)
- Market positioning: Squad fills gap in "stateful team coordination with persistent memory"
- No direct competitors; competes indirectly with CrewAI, AutoGPT, MetaGPT
- Confidence: High (researched via web_search + framework site visits)

**Use Case:** This finding directly supports patent filing strategy (narrow claims around unique elements like Ralph) and positioning for any future funding or partnerships.

---

### Issue #17 — Work-Claw Research (BLOCKED, NEEDS CONTEXT)
**Status:** Waiting for Tamir  

**What's Needed:**
1. What is Work-Claw? (Microsoft-internal? External project? GitHub?)
2. URL or access details?
3. What specific aspects to research? (Capabilities vs Squad? Integration opportunities? Architecture comparison?)

**Once Tamir provides context, I can deliver:**
- Feature comparison vs Squad
- Integration points and opportunities
- Architectural alignment assessment
- Recommendations for Squad enhancement

---

## Pattern Observation: Decision Gates as Team Health Signal

The four issues follow a pattern:
- **#42 (Patent)**: Research complete, waiting for strategic decision owner (Tamir)
- **#41 (Blog)**: Content complete, waiting for editorial/publishing decision (Tamir)
- **#32 (Framework)**: Question answered, findings available for architecture decisions
- **#17 (Work-Claw)**: Stalled waiting for context and decision owner clarity

**Insight:** Research/Docs work succeeds when decision ownership is explicit. When issues lack clear "decision owner" or "success criteria," work stalls.

**Recommendation for Team:** Every GitHub issue should include:
- [ ] Decision owner (who decides if work is done?)
- [ ] Success criteria (what does done look like?)
- [ ] Decision deadline (when is decision needed?)

This pattern helps research work unblock business decisions rather than sit in "complete but unused" status.

---

## Next Steps

**For Tamir:**
1. Review #42 patent findings; answer the 5 clarification questions
2. Review #41 blog draft; provide feedback
3. Clarify what Work-Claw research is needed for #17
4. Decide: Patent first, then publish? Or consult patent attorney first?

**For Seven:**
- Waiting on Tamir for all four issues
- Can execute any follow-up research or writing based on Tamir's decisions
- Will track issue progress in next status checkpoint

**For Team:**
- Patent research findings available for architectural/strategic decisions
- Blog draft available for engineering culture messaging
- OpenCLAW/Squad positioning available for competitive analysis

---

**Status:** Awaiting Tamir input on all four issues  
**Confidence:** High (research complete where possible; blockers clearly identified)  
**Timeline:** Ready to move forward immediately upon Tamir's input


---

## Decision: User Directive — Status Label Enforcement

**Date:** 2026-03-07T17:45:41Z  
**Author:** Tamir Dresher (via Copilot)  
**Status:** ✅ Adopted  
**Scope:** Team Process / Issue Management

**Directive:** Status labels (status:in-progress, status:pending-user, status:done, status:blocked) MUST always be followed by the squad. Every issue must have the correct status label updated as work progresses. This is non-negotiable.

**Captured from:** Issue #43 (Tamir's strong emphasis: "make sure it will always be followed by the squad!!!!!")

**Enforcement:** All agents must validate and update status labels when transitioning work on any GitHub issue.

---

## Decision: Squad Activity Monitor Tool Architecture

**Date:** 2026-03-07  
**Author:** Data (Code Expert)  
**Issue:** #40  
**Status:** ✅ Implemented  
**Scope:** Squad Tooling

### Context
Tamir requested a local tool to monitor squad member activity in real-time. Initial proposal included both PowerShell script and web dashboard options. Tamir chose the local tool approach but requested C# instead of PowerShell, specifically mentioning .NET 10's single-file capabilities.

### Decision
Built Squad Activity Monitor as a C# 13 console application using .NET 10 with Spectre.Console for terminal UI.

### Technical Choices

**Platform: .NET 10 + C# 13**
- **Rationale:** Latest available SDK, single-file publish capability, modern language features
- **Benefits:** Cross-platform, type-safe, performant, self-contained executable
- **Trade-offs:** Requires .NET SDK to run (or single-file publish for distribution)

**UI Framework: Spectre.Console**
- **Rationale:** Best-in-class terminal UI library for .NET
- **Benefits:** Beautiful tables, color support, rich formatting, escape handling
- **Trade-offs:** External dependency (but stable, well-maintained)

**Architecture: Simple File Parser**
- **Rationale:** Orchestration logs are markdown files with predictable structure
- **Benefits:** No database, no state, simple regex parsing, fast startup
- **Trade-offs:** Limited to what's in log files, no historical analysis

**Data Source: Orchestration Logs Only**
- **Rationale:** Primary source of truth for squad activity
- **Benefits:** Direct access, no API needed, real-time updates
- **Trade-offs:** Doesn't capture session logs or detailed agent state (not needed for MVP)

### Implementation Patterns
1. **Top-level statements** — No unnecessary ceremony
2. **Records** — Clean data models (AgentActivity)
3. **Regex parsing** — Extract timestamp and agent name from filename
4. **Markdown parsing** — Simple regex for Status, Assignment, Outcome sections
5. **Smart formatting** — Age relative to UTC now, color coding by status

### User Preferences Captured
- **C# over PowerShell** — Better type safety, more portable
- **Local tool over web dashboard** — Faster to build, simpler to use
- **Auto-refresh default** — Monitor mode is primary use case
- **\--once\ flag** — Quick status check without loop

### Future Enhancements (Deferred)
- Session log integration for detailed agent state
- Historical trend analysis (activity over time)
- Agent filtering (show only specific agents)
- Export to JSON/CSV for analysis
- Web dashboard (if team grows or remote monitoring needed)

### Outcome
✅ Tool implemented in ~270 lines of C#, tested successfully, PR #47 created.  
✅ Displays 20 recent activities with beautiful formatting.  
✅ Auto-refresh every 5s (configurable).  
✅ Color-coded status indicators work as expected.

### Lessons Learned
1. Timestamp parsing from filenames requires explicit regex grouping
2. Spectre.Console's Markup.Escape() is critical for user-generated content
3. .NET 10 single-file publish creates truly self-contained executables
4. Top-level statements + records = minimal ceremony for console apps

---

## Decision 4: # Decision: STG-EUS2-28 Incident Response — Fast-Track I1 Istio Exclusion List

**Date:** 2026-03-11  
**Author:** Picard (Lead)  
**Status:** Proposed (Requires Tamir + DK8S Leadership Confirmation)  
**Scope:** Incident Response, Stability Engineering  
**Related Issues:** #46 (incident report), #24 (Tier 1 mitigations), #25 (Tier 2 plan)

## Context

STG-EUS2-28 cluster incident (detected 2026-03-07T17:45Z via Teams Bridge integration) exhibited cascading failure pattern:
- Draino → Karpenter → Istio ztunnel → NodeStuck automation
- >20% unhealthy nodes
- ztunnel pods failing despite Ready nodes
- Node deletion automation triggering on daemonset health (not actual node failure)

**Critical Correlation:** This pattern is **identical** to Jan 2026 Sev2 (IcM 731055522) analyzed in Issue #4 stability research. Squad predicted this exact failure mode 4+ weeks before production recurrence.

## Decision: Elevate I1 from Tier 1 to P0 Immediate Execution

**I1 (Establish Istio Exclusion List for Infrastructure Components)** should be:
- **Elevated from:** Tier 1 "critical, low-effort" (planned for next sprint)
- **Elevated to:** P0 immediate execution (start this week)

### Rationale

1. **Active Incident Validates Research:** Real-world recurrence proves I1 is not theoretical — it directly mitigates production failure mode
2. **Low Implementation Cost:** 2-3 days effort (label-based mesh exclusion + admission controller)
3. **Breaks Cascading Loop:** Removing infrastructure daemonsets from mesh prevents Draino/Karpenter/NodeStuck cascade
4. **Enables I2:** Clean baseline required before implementing ztunnel health monitoring + auto-rollback (Tier 2)

### Scope

**Components to Exclude from Service Mesh:**
- CoreDNS (kube-system)
- Geneva-loggers (monitoring infrastructure)
- All kube-system daemonsets
- Monitoring infrastructure (prometheus exporters, telegraf agents)
- Node-level system components (CSI drivers, CNI plugins)

**Implementation:**
- Label-based exclusion (namespace + pod labels)
- Admission controller validation (prevent accidental mesh injection)
- Validate in STG before PROD rollout

### Three-Phase Mitigation Strategy

**Phase 1 (This Week): Karan's NodeStuck Exclusion**
- **Tactical fix:** Exclude Istio daemonsets from NodeStuck node deletion automation
- **Rationale:** Stop the bleeding — prevents node churn from amplifying incidents
- **Owner:** SRE team
- **Timeline:** 48h implementation + validation

**Phase 2 (2-3 Weeks): I1 Istio Exclusion List**
- **Strategic fix:** Remove infrastructure components from service mesh entirely
- **Rationale:** Root cause mitigation — infrastructure should never trigger application mesh logic
- **Owner:** Platform + Istio SME team
- **Timeline:** Current sprint (fast-tracked from Tier 1 plan)

**Phase 3 (6-8 Weeks): I2 ztunnel Health Monitoring**
- **Proactive mitigation:** Automatic rollback when ztunnel failure rate exceeds threshold
- **Rationale:** Prevent future incidents through automated health-based remediation
- **Owner:** Platform + Istio SME team
- **Timeline:** Tier 2 execution (Issue #25)

## Applies To

- **DK8S Platform Team:** I1 implementation (Istio exclusion list)
- **SRE Team:** Phase 1 NodeStuck automation changes
- **Squad (B'Elanna):** Technical review + validation of I1 implementation approach

## Does NOT Apply When

- Infrastructure components legitimately need service mesh features (rare; requires explicit justification)
- Cluster is already experiencing Sev1 incident (revert to manual remediation, implement I1 post-incident)

## Consequences

✅ **Benefits:**
- Prevents Draino/Karpenter/NodeStuck cascading failure loop
- Reduces false positive node deletion (infrastructure daemonset health ≠ node health)
- Establishes clean baseline for future Istio upgrades
- Demonstrates research ROI to DK8S leadership (predicted failure, mitigations ready)

⚠️ **Risks:**
- Excluded components lose mesh observability (mTLS metrics, tracing) — acceptable tradeoff for stability
- Requires cross-team coordination (Platform, SRE, Istio SME)
- Implementation window: Must complete before next STG deployment cycle

## Mitigation for Risks

- **Observability gap:** Infrastructure components use existing monitoring (Prometheus exporters, Geneva logs) — mesh observability not required
- **Coordination risk:** Phase 1 (NodeStuck) is independent of Phase 2 (I1) — can proceed in parallel
- **Validation:** STG rollout with 48h soak time before PROD

## Related Patterns

**"Active Incident Validation" Pattern:**
1. When active incident matches prior research prediction → Escalate mitigations from planned to P0
2. Accept tactical symptom fixes (Phase 1) while strategic solution (Phase 2) is implemented
3. Use incident as forcing function to accelerate critical work
4. Frame to leadership: "Research predicted incident, mitigations already designed, need execution priority"

## Success Metrics

- **Phase 1:** Zero node deletions triggered by Istio daemonset health within 7 days of deployment
- **Phase 2:** Zero Istio-related cascading failures in STG environment within 30 days of I1 rollout
- **Phase 3:** >80% automatic recovery rate for ztunnel failures (measured over 90 days post-I2)

## Open Questions for Tamir + DK8S Leadership

1. **Execution Priority:** Confirm I1 fast-track to current sprint (vs. waiting for planned Tier 1 execution)?
2. **Phase 1 Coordination:** Should Squad (B'Elanna) provide NodeStuck exclusion implementation guidance to SRE team?
3. **FedRAMP P0:** Should nginx-ingress-heartbeat vulnerabilities be tracked as separate issue #48?
4. **New Issues:** Confirm creation of Issue #47 (NodeStuck exclusion) and Issue #48 (FedRAMP P0)?

## References

- **Issue #46:** STG-EUS2-28 incident report (Teams Bridge detection)
- **Issue #24:** Tier 1 critical mitigations (I1 original scope)
- **Issue #25:** Tier 2 high-impact improvements (I2 ztunnel health monitoring)
- **Issue #4:** DK8S stability analysis (5 Sev2 incidents, 7 failure patterns)
- **B'Elanna's Analysis:** Jan 2026 Sev2 (IcM 731055522) — ztunnel + DNS + geneva-loggers cascading failure

---

**Next Steps:**
1. Tamir confirms fast-track decision
2. B'Elanna provides I1 implementation guidance (label design, admission controller config)
3. SRE team implements Phase 1 (NodeStuck exclusion) within 48h
4. Platform team schedules I1 implementation for current sprint
5. Post-incident review validates correlation + documents lessons learned


---
### 2026-03-07T18:23Z: User directive — Teams communication approach
**By:** Tamir Dresher (via Copilot)
**What:** Use WorkIQ + webhook approach for Teams communication for now. Teams MCP Server (issue #45) is deprioritized.
**Why:** User request — practical approach using existing tools rather than waiting for MCP Server setup.
---
# Decision: Patent Research Re-Scoped to Usage Pattern (Issue #42)

**Date:** 2026-03-15  
**Author:** Seven (Research & Docs)  
**Status:** Informational (research findings)  
**Related Issues:** #42

## Context

Original patent research (March 2026) analyzed Squad framework's technical architecture (Ralph monitoring, casting governance, git-based state, etc.) for patentability. Tamir clarified in follow-up comments that the question was NOT about patenting Squad itself, but about the **USAGE PATTERN**: using a multi-agent AI squad as a personal assistant / cognitive extension for a human professional (specifically a TAM).

## Research Question (Re-Scoped)

**Is the way we use Squad here — as an AI personal assistant / human extension for a TAM — patentable?**

## Key Findings

### 1. Prior Art Landscape

**Existing Patents:**
- US11574205B2 (Granted): Unified cognition for virtual personal cognitive assistant — multiple domain agents coordinated by personalized cognition manager
- US20230306967A1 (Application): Personal assistant multi-skill — cognitive enhancement layer across domains
- US20240419246 (Application): Human augmentation platform using context, biosignals, and LLMs
- US20240430216 (Application): Copilot for multi-user, multi-step workflows with multi-agent orchestration

**Open-Source Implementations:**
- Agent Squad (AWS Labs): Multi-agent framework for enterprise workflows, customer support, technical troubleshooting
- LangChain Multi-Agent Assistants: Supervisor/sub-agent pattern for personal productivity
- Mobile-Agent-E (Academic): Hierarchical multi-agent with self-evolving memory for professional workflows

**Microsoft's Public Work:**
- Microsoft Copilot Studio: Orchestrator + sub-agent patterns for domain-specific enterprise workflows
- Microsoft Developer Blog (2025): "Designing Multi-Agent Intelligence" — advocates multi-agent architecture for enterprise productivity with Teams/Outlook/SharePoint integration

### 2. Novelty Assessment

**Broad claims WILL FAIL:**
- "Multi-agent AI assistant for professionals" — covered by prior art (US11574205B2, AWS Agent Squad, LangChain)
- General orchestration patterns — well-established in open-source and patents

**Narrow claims MAY BE PATENTABLE:**

1. **TAM-Specific Orchestration Pattern** (MEDIUM novelty)
   - Multi-agent system specifically designed for TAM workflows (research, communication, issue tracking, continuous learning)
   - No patents found specifically for TAM or domain-specialist cognitive extension with this workflow integration
   - Risk: Obviousness — USPTO may view as obvious application of known patterns to specific domain

2. **Human-AI Collaborative Workflow Pattern** (MEDIUM-HIGH novelty)
   - Parallel human-AI work with git-based shared memory for audit and intervention
   - Seamless handoff between human and AI team members
   - Continuous learning from TAM's decisions and domain context
   - Hybrid pattern (human-supervised + autonomous) less documented than pure autonomous or pure supervised

3. **Domain-Adaptive Continuous Learning for Individual Professional** (MEDIUM novelty)
   - Learning from single TAM's domain context, adapting agent specializations
   - Using git-based decision history as training corpus for personalization
   - Risk: Continuous learning is well-established; narrow TAM-focused implementation may be defensible

4. **GitHub + Teams + ADO Integration as "Human Extension Substrate"** (MEDIUM novelty)
   - Specific usage pattern of these tools as integrated substrate for human-AI collaboration
   - GitHub issues as task definitions, Teams as communication bridge, git history as shared memory
   - Risk: Integration patterns are common; specific usage for cognitive extension could be defensible

### 3. Risk Analysis

**Obviousness Risk: HIGH**
- USPTO examiners may view as obvious combination of known elements: multi-agent orchestration + personal productivity + domain specialization
- Mitigation: Must demonstrate non-obvious technical advantages (specific orchestration efficiency, learning mechanisms, workflow patterns)

**Microsoft Internal Prior Art Risk: MEDIUM**
- Microsoft's public work on multi-agent Copilot and agentic AI may establish prior art
- Timing investigation required: When did implementation begin vs. Microsoft's public disclosures?

**Broad Claims Will Fail: HIGH**
- Claims like "multi-agent AI assistant for professionals" will be rejected due to prior art
- Mitigation: File narrow, specific claims focused on TAM-specific workflow, human-AI parallel collaboration, domain-adaptive learning

## Recommendation

### Filing Strategy: Option A (Recommended)

**File narrow TAM-focused claims:**
- System for cognitive extension of TAM with domain-specialized agents (research, communication, issue management, monitoring)
- Git-based shared memory enabling human audit and intervention
- Orchestration pattern for human-AI parallel workflow where TAM and agents collaborate on simultaneous tasks
- Continuous learning from TAM's domain context and decision history
- Integrated GitHub + Teams + ADO substrate for task definition and coordination

**Pros:**
- Specific enough to avoid broad prior art
- Focuses on unique TAM workflow and human-AI collaboration pattern
- Higher grant probability

**Cons:**
- Narrow scope limits defensive value
- Competitors could design around with different domain (e.g., Customer Success Manager)

**Timeline:** 2-3 weeks for provisional filing  
**Cost:** ~$3-5K (Microsoft covers)

### Critical Questions Before Filing

1. **Inventorship:** Who conceived the "AI squad as TAM human extension" concept? When?
2. **Public Disclosure:** Has this usage pattern been publicly disclosed? (Blog posts, conference talks, public GitHub repo with pattern documented?)
3. **Microsoft Internal:** Has Microsoft filed or disclosed similar TAM/domain-specialist cognitive extension concepts internally?
4. **Implementation Details:** What specific orchestration mechanisms, learning algorithms, or workflow patterns are implemented that go beyond standard multi-agent frameworks?

## Bottom Line

**Usage pattern is POTENTIALLY PATENTABLE with narrow, specific claims** focused on TAM workflow and human-AI collaboration pattern. Obviousness is primary risk. Must demonstrate non-obvious technical advantages.

**Recommended action:** If specific innovations exist in TAM workflow orchestration, domain learning, and human-AI parallel collaboration, **file narrow provisional patent** to lock priority date, then assess competitive landscape over 12 months.

## Key Learning for Squad

When user clarifies scope mid-research ("not Squad itself"), **IMMEDIATELY pivot to re-scoped analysis** rather than defending original scope. User's clarification takes absolute priority over prior work investment. In this case, entire patent analysis needed reframing from "Squad technical architecture" to "usage pattern as human extension" — fundamentally different patent question.

## Next Steps

1. Tamir reviews findings and decides whether to proceed with patent filing
2. If proceeding: Clarify inventorship, public disclosure status, Microsoft internal conflicts
3. If filing: Engage Microsoft patent attorney to draft narrow TAM-focused claims
4. Timeline: Provisional filing within 2-3 weeks to preserve priority date

---

**References:**
- Issue #42: https://github.com/tamirdresher_microsoft/tamresearch1/issues/42
- Original patent research: PATENT_RESEARCH_REPORT.md, PATENT_RESEARCH_METHODOLOGY.md
- Issue #42 re-scoped analysis comment: Posted 2026-03-15

