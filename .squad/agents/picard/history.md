# Picard — History

## Core Context

- **Project:** Cross-repo research and analysis team covering infrastructure, security, cloud native, and development across Azure DevOps and GitHub repositories
- **User:** Tamir Dresher
- **Role:** Lead
- **Joined:** 2026-03-02T15:01:26Z
- **Note:** Recast from Neo (The Matrix) to Picard (Star Trek TNG/Voyager)

## Learnings

### 2026-03-07: Ralph Watch v5 Assessment — Observability Gap Analysis

**Context:** Tamir asked for assessment of ralph-watch.ps1 (hourly polling script for monitoring GitHub issues/PRs). Existing implementation runs the squad agent in a 5-minute loop with basic comment tracking via `.ralph-state.json`. Request: "Can you make it working ok? Any suggestions for improvement?"

**Assessment Delivered:**

Ralph Watch v5 is **operationally functional** but **blind** — no telemetry, logging, or failure recovery. Identified 5 critical gaps:

1. **No Execution Logs** — Running silently; no audit trail of what actually happened each round
2. **No Error Recovery** — Single failure breaks the loop; no retry logic or exponential backoff
3. **Incomplete Change Detection** — Only tracks issue comments, not PR comments or state changes
4. **No Metrics** — Can't answer "Is Ralph alive?" or "How effective is this interval?"
5. **No Failure Notification** — Silent failures; Tamir has no way to know when rounds fail

**Improvement Plan Posted to Issue #15:**
- **Quick Wins (1 hour):** Add structured JSON logging (`.ralph-log.jsonl`), capture round output, add metrics file (`.ralph-metrics.json`)
- **Medium Effort (2-3 hours):** Implement PR comment detection, state change tracking, retry logic with exponential backoff
- **Nice-to-Have:** Teams integration, threshold alerting, round duration tracking

**Key Insight:** Before optimizing interval/coverage, instrument first. A week of data will reveal: "Are we missing actionable changes? Is 5 minutes too frequent/infrequent? Where are the blind spots?" Data-driven > guessing.

**Decision Pattern Applied:**
- Diagnosed root cause (lack of observability, not lack of functionality)
- Prioritized quick wins for immediate visibility
- Deferred optimization until metrics are available
- Framed next steps as data collection + decision point

---

### 2026-03-02: idk8s-infrastructure Deep Architecture Analysis

**Context:** Tasked with deep-diving into the idk8s-infrastructure Azure DevOps repository (project "One", msazure org) to extend existing architecture report. Repository access via MCP tools failed - project "One" not found, searches for "idk8s-infrastructure" returned zero results.

**Technical Learnings:**

1. **Repository Discovery Limitations:**
   - Azure DevOps MCP tools require exact project name and repository name
   - Organization name must also be correct (msazure assumed, but may be different)
   - Search functionality has limited scope across organizations
   - Lesson: Always verify full repository path: `https://dev.azure.com/{org}/{project}/_git/{repo}`

2. **Gap Analysis as Deliverable:**
   - When primary data source (repo) is inaccessible, analyzing existing documentation for gaps provides high value
   - Identified 10 major architectural knowledge gaps in the existing report
   - Created actionable investigation plan for when access is obtained
   - Lesson: "What's missing" analysis can be as valuable as "what's there" analysis

3. **Architecture Report Quality Indicators:**
   - Missing ADR content (beyond titles) is a red flag for incomplete architectural documentation
   - Configuration flow tracing (source → build → deploy → runtime) is often overlooked but critical
   - Cross-repository dependency mapping is essential for understanding blast radius
   - Vision/roadmap documents provide strategic context that technical docs cannot

4. **Azure DevOps vs GitHub Context:**
   - If repository is actually on GitHub, completely different MCP tools are needed (github-mcp-server-*)
   - User's assumption of "Azure DevOps" may not match reality
   - Lesson: Confirm repository platform before deep analysis

**Architectural Insights from Report Analysis:**

1. **Strengths Identified:**
   - Strong Kubernetes-inspired patterns (reconciliation, desired-state, scheduler)
   - Clean separation of concerns (MP, ResourceProvider, Inventory, Reconcilers)
   - Mature multi-tenancy with namespace isolation and resource quotas
   - Sophisticated 4-layer health management system

2. **Concerns Identified:**
   - ConfigMap as persistent store is interim solution with scalability limits (1MB, no indexing, weak concurrency)
   - Windows containers for Management Plane (5-10x larger than Linux, slower)
   - NuGet package distribution for core logic creates versioning coordination challenges
   - Celestial CLI "not in active use" suggests weak local dev story
   - 19 hardcoded tenants in Data/Tenants/ doesn't scale beyond ~20

3. **Red Flags:**
   - ADRs 0001-0003 missing (foundational decisions lost)
   - No disaster recovery plan mentioned
   - No capacity planning guidance
   - EV2 endpoints (/validate, /suspend, /cancel) not implemented (returning 501)

**Decision Pattern:**
- **When blocked on primary data source:** Deliver gap analysis and investigation plan rather than blocking
- **Gap categories that matter most:**
  1. Strategic (vision, roadmap, deprecation timelines)
  2. Operational (DR, capacity planning, observability)
  3. Architectural reasoning (full ADR content, alternatives considered)
  4. Integration (cross-repo dependencies, external services)
  5. Configuration lifecycle (source to runtime tracing)

**Actions for User:**
- Requested full repository URL verification
- Provided 6-day investigation plan for when access is obtained
- Documented 10 specific architectural gaps to investigate

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

**Context:** Visited Squad Places (https://web.nicebeach-b92b0c14.eastus.azurecontainerapps.io/) — an agent social network where AI squads publish knowledge artifacts (decisions, patterns, lessons, insights). The platform currently hosts 38 artifacts across 7 squads.

**Key Observations:**

### Squads & Communities Present:
1. **Marvel Cinematic Universe** — .NET CLI for app modernization (Stark, Banner, Rogers, Romanoff, Barton)
2. **Squad Places** — The platform builders (Keaton, Fenster, Hockney, McManus, Baer)
3. **Nostromo Crew** — Go-based coding agent server for Claude Code/Copilot orchestration
4. **Breaking Bad** — Modernizing .NET Terrarium 2.0 (.NET Framework 3.5 → .NET 10, Blazor + SignalR)
5. **The Wire** — Aspire Community Content Engine Squad (ACCES pipeline: discover → normalize → dedupe → classify → analyze → output)
6. **The Usual Suspects** — Squad SDK multi-agent runtime framework for GitHub Copilot (20+ agents)

### High-Value Architectural Patterns Published:

**1. File-Based Outbox Queue: Offline-Resilient Publish Pattern** (15 comments)
- Pattern for distributed artifact publishing with local queueing on failure
- Enables offline-first AI team collaboration
- Key insight: File-per-artifact eliminates contention and enables parallel processing
- Security considerations: Outbox directory permissions, artifact integrity checksums
- Token extraction must happen per-batch (not startup) for ASP.NET anti-forgery protection
- Version field in artifact envelope needed for schema migration

**2. Prompts as Executable Code: Rigor Over Prose** (13 comments)
- **Core thesis:** Treating prompts with versioning, review, and testing discipline is critical
- **Signal classification case study (from The Wire/ACCES):** Moving from prose prompts → structured templates raised classification consistency from 70% → 94% across runs
- **Squad SDK insight:** Prompts wrapped in typed contracts (inputs, outputs, model config, retry policy) enables independent testability
- **Testing challenge:** Prompts must be mutation-tested; flipping one clause should break tests
- **Critical risk:** Prompt drift across model versions (GPT-4 vs GPT-4-turbo) is a testing nightmare; defense is contract-based testing on output shape, not content
- Spawn templates now mandate: charter inline, team root, input artifacts, decision inbox path, response-order block

**3. One-Way Dependency Graph: SDK/CLI Split** (7 comments)
- Architecture decision: Enforce unidirectional dependencies (CLI → SDK → @github/copilot-sdk)
- Enables independent package evolution and maintains library purity
- Prevents circular dependencies and coupling complexity

**4. Scout-Librarian-Analyst Pipeline Pattern** (5 comments)
- Three-stage architecture for multi-source content discovery
- Stage 1: Scout (parallel scouts across heterogeneous sources)
- Stage 2: Librarian (deterministic deduplication)
- Stage 3: Analyst (human-actionable output)
- Designed for scale with source diversity

**5. Testing Non-Deterministic AI Agent Output** (10 comments)
- Core challenge: LLM responses are inherently non-deterministic
- Must test output shape/structure, not content
- Expensive LLM calls require resumable pipelines (checkpoints, not replays)
- Quality gates must be probabilistic (X% consistency across runs)

### Learnings for Architecture & Leadership:

**1. Signal > Vanity Metrics**
- GitHub stars measure awareness; issues/PRs measure real adoption
- Adoption signals: first production integration, issue reporting, active discussion
- Classification: adoption > praise > request > complaint > confusion

**2. Determinism as Non-Negotiable**
- For any LLM pipeline where downstream decisions depend on classifier output, treat prompts as code
- Test fixtures + regression testing move classification from "interesting experiment" → "production intelligence"
- The 70% → 94% consistency jump is typical for this pattern

**3. File-Based Patterns Enable Inspection & Resumability**
- Drop-box pattern gives inspectability: walk through each stage's outbox directory to debug pipeline
- No log archaeology; no event replays—just files with timestamps
- Atomic write guarantees at item level without needing transactions
- Critical for teams working with non-deterministic LLM operations

**4. Offline-First Architecture for Distributed Teams**
- Publish-remote-first, queue-locally-on-failure pattern enables AI teams to socialize knowledge offline
- Retry handling must account for potential duplicates (Levenshtein distance dedup on receiver side)
- Token extraction per-batch (not per-startup) for stateful protocols

**5. Prompts are Contracts**
- Prompts define the interface between agent and task
- Versioning prompts = versioning the squad's understanding of the domain
- Squad SDK model: skills are independently testable, typed, version-controlled units
- Cannot retrofit testing onto prose-style prompts

**6. Risk: Model Drift is Uncontrollable**
- Prompt didn't change. Code didn't change. But GPT-4 vs GPT-4-turbo behavior did.
- Defense: Test output SHAPE, not content
- Implication: Production LLM systems must be schema-forward, not output-forward

### Artifacts I Found Most Relevant:

- **For distributed systems teams:** File-Based Outbox Queue pattern (idempotency, offline-first, inspectability)
- **For multi-agent frameworks:** Prompts as Executable Code + Testing Non-Deterministic Output (determinism requirements)
- **For architecture leads:** One-Way Dependency Graph (SDK/CLI split reduces coordination overhead)
- **For intelligence pipelines:** Scout-Librarian-Analyst (scaling content discovery with deterministic dedup)

### 2026-03-07: Azure Fleet Manager Architecture Evaluation (Issue #3)

**Context:** Evaluated Azure Kubernetes Fleet Manager (AKFM) for DK8S RP adoption. Conducted multi-source research: EngineeringHub internal docs, public Azure docs, KubeFleet OSS, open-source alternatives (Rancher Fleet, Kratix, Karmada), and WorkIQ retrieval of past team meetings/emails.

**Technical Learnings:**

1. **AKFM is built on KubeFleet (CNCF Sandbox):** The open-source foundation provides an exit path from vendor lock-in. Hub-spoke architecture with Fleet Agent per member cluster.

2. **Key Value Props for DK8S:** Cluster upgrade orchestration (Update Runs) and blue/green cluster replacement are the strongest differentiators vs. status quo. App deployment propagation (CRP) overlaps heavily with existing ArgoCD + ConfigGen.

3. **Identity is a Hard Blocker:** WorkIQ confirmed multiple meetings (Feb 12, Feb 18, 2026) where identity binding was explicitly called a "block" or "precondition." FIC automation gaps mean workload movement across clusters is unsafe today.

4. **Dual Control Plane Risk:** Running Fleet Manager alongside ArgoCD creates competing reconciliation loops and ambiguous source-of-truth for deployment state. Team flagged this as "overkill" in Feb 12 meeting.

5. **ConfigGen Expressiveness Gap:** Fleet Manager's resource overrides are less expressive than ConfigGen's 5-tier values hierarchy. Migration would lose configuration granularity.

6. **Constraints:** 200-cluster limit, same Entra ID tenant required, sovereign cloud feature parity may lag.

**Decision:** DEFER — do not adopt now. Establish prerequisites (Workload Identity migration, FIC automation, operational need for cluster replacement) before revisiting. No open-source alternative provides better fit than AKFM for DK8S when the time comes.

**Artifacts Produced:**
- `fleet-manager-evaluation.md` — Full architecture evaluation with feature mapping, alternative comparison, risk assessment
- Decision inbox entry: `picard-fleet-manager-eval.md`
- Issue #3 comment with summary

---

### Community Quality Assessment:

- **Depth:** Comments are substantive; people explain their implementation, edge cases, and lessons learned
- **Collaboration:** Evidence of squads learning from each other (The Wire references Breaking Bad, Squad Places references Usual Suspects)
- **Practicality:** Posts include code patterns, configuration decisions, testing strategies—not just theory
- **Maturity:** API documentation is OpenAPI 3.1.1, designed explicitly for AI agent self-integration (no external docs needed)

### API Notes:

Platform provides:
- `POST /api/squads/enlist` — Register a squad
- `POST /api/artifacts` — Publish knowledge artifact (decision, pattern, lesson, insight)
- `GET /api/feed` — Paginated discovery feed (page, pageSize params; default 20, max 100)
- Comments visible on detail pages (web-only in current version)
- Feed is read-only via web UI; publishing requires API calls

**Engagement Summary:**
Reviewed 8+ high-value architectural artifacts focusing on resilience, multi-agent coordination, testing strategies, and offline-first design. Identified cross-cutting themes: determinism requirements, file-based patterns for resumability, and contract-based testing for LLM systems. The Squad Places community is publishing production-grade patterns at scale.

---

### 2026-03-06: Fleet Manager Architecture Evaluation (Issue #3)

**Context:** Background task (Mode: background) to evaluate fleet manager architecture for Identity/FIC platform.

**Outcome:** ✅ DEFER recommendation

**Key Recommendation:**
Fleet manager architecture is sound, but approval is contingent on addressing:
1. **Security prerequisites (Worf):** 12 identified risks, 17 mitigations required
   - Certificate lifecycle automation (60-day critical path)
   - WAF deployment for public endpoints (immediate)
   - Cross-cloud security baseline establishment (30-day)
2. **Infrastructure stability (B'Elanna):** 5 Sev2 incidents require mitigation
   - ConfigGen versioning coordination
   - Scale unit scheduler tuning
   - Node health lifecycle validation

**Conditional Go Path:**
- Q1 2026: Implement security mitigations (certificate automation, WAF)
- Q2 2026: Infrastructure stability improvements + cross-cloud baseline
- Q3 2026: Unconditional fleet manager deployment approval

**Branch:** squad/3-fleet-manager-eval (pushed)  
**Artifacts:** fleet-manager-evaluation.md  
**PR:** #7 opened

---

### 2026-07-04: Continuous Learning System Design (Issue #6)

**Context:** Designed a system for the squad to continuously monitor DK8S and ConfigGen Teams channels, learn from daily support patterns, and build that knowledge into squad skills.

**Technical Learnings:**

1. **WorkIQ is the key data source:** WorkIQ (MCP tool) provides access to all four target channels — DK8S Support, ConfigGen Support, DK8S Platform Leads, and BAND Collaboration — all within the "Infra and Developer Platform Community" team. Access is user-scoped (requires Tamir's channel membership).

2. **Recurring patterns already exist and are high-signal:**
   - DK8S: Capacity starvation (weekly), node bootstrap failures (weekly), Azure platform misattribution (bi-weekly), identity/KV coupling (monthly)
   - ConfigGen: SFI enforcement breakages (weekly), auto-generated config failures (weekly), modeling gaps (ongoing), CI/CD validation gaps (bi-weekly), PR review bottleneck (daily)

3. **Phased approach is correct:** Manual scan protocol (Phase 1) delivers immediate value with zero infrastructure. Prompt templates (Phase 2) make it reproducible. Pattern extraction (Phase 3) is the learning flywheel. GitHub Actions (Phase 4) is blocked on WorkIQ API access from runners.

4. **Privacy constraint matters:** Digests contain internal support content. Must decide whether to gitignore `.squad/digests/` or treat the repo as internal-only.

5. **Cross-channel meta-patterns identified:**
   - Platform behavior changes faster than consumer understanding
   - Implicit defaults cause most breakages
   - Azure platform issues are repeatedly misattributed to DK8S/ConfigGen
   - Ownership boundaries between DK8S, ConfigGen, BAND, and AKS are unclear to consumers

**Decision:** Proposed 4-phase implementation starting with manual WorkIQ polling at session start, progressing to automated skill accumulation. Created initial skill entries for 9 recurring patterns across both channels.

**Artifacts:**
- `continuous-learning-design.md` — Full architecture and phased implementation plan
- `.squad/skills/dk8s-support-patterns/SKILL.md` — 4 DK8S operational patterns
- `.squad/skills/configgen-support-patterns/SKILL.md` — 5 ConfigGen operational patterns
- `.squad/decisions/inbox/picard-continuous-learning.md` — Decision proposal
- `.squad/digests/` — Directory for future digest storage

**Branch:** squad/6-continuous-learning

**Cross-Agent Notes:**
- Worf's security analysis and B'Elanna's infrastructure assessment both on same branch
- Seven's Aurora research provides complementary platform validation
- Data's heartbeat workflow fix enables reliable monitoring for rollout tracking

**Decision Pattern:**
When blocking conditions are addressable (not architectural failures), DEFER with explicit mitigation path and timeline. This enables parallel work on prerequisites while maintaining clear go/no-go criteria.
### 2026-03-07: Aurora Adoption Plan & Scenario Definition Framework (Issue #4)

**Context:** Tamir asked whether we could run an Aurora experiment on a DK8S component — specifically cluster provisioning — and whether Aurora would make rollouts slower. Built comprehensive adoption plan synthesizing Seven's Aurora research, B'Elanna's stability analysis, and deep WorkIQ intelligence.

**Key Learnings:**

1. **Aurora scenario structure:** Workload → Scenario → Steps → Assertions. Scenarios require: workload definition (onboarding manifest), success criteria (quantitative thresholds), and matrix parameters (regions, SKUs, versions). Authentication uses two service principals via Key Vault certs.

2. **Aurora Bridge is the lowest-friction entry:** Connects existing ADO pipelines without test rewrites. Provides monitoring, alerting, and historical trending immediately. This is the right Phase 1 move.

3. **DIV runs during bake time, not blocking deployments:** DK8S already has mandatory bake periods between EV2 rings. Aurora validation can execute during these windows, adding zero net latency. This is the critical insight that answers "will it slow us down?" — no, if structured correctly.

4. **Cluster provisioning is ideal first candidate:** Clear success criteria, high blast radius, no cross-team dependencies, addresses known provisioning validation gaps surfaced in Runtime Platform reviews and cluster automation brainstorms (confirmed via WorkIQ).

5. **Other teams' approach — Databricks model:** Deep nightly validation (full matrix, 1-2 hours) + lightweight per-deployment checks (3-5 smoke scenarios, 10-15 min). This separation minimizes rollout impact while maximizing coverage.

6. **No existing DK8S-Aurora connection in org:** WorkIQ confirmed Aurora and DK8S discussions are "adjacent rather than unified." We would be establishing a new integration, not joining existing work.

7. **EngineeringHub access denied:** Could not fetch Aurora onboarding docs via enghub-search or enghub-fetch. Relied on Seven's prior research URLs and WorkIQ intelligence instead.

**Decision:** Proceed with 4-phase adoption plan. Phase 0 (experiment design) starts immediately. Monitoring-only through Phase 1-2. Gating mode only in Phase 4, only for critical scenarios, only after 30-day burn-in.

**Artifacts produced:**
- `aurora-adoption-plan.md` — comprehensive plan with scenario definition framework, templates, phased rollout, experiment design, and impact analysis
- Decision inbox entry: `.squad/decisions/inbox/picard-aurora-adoption-plan.md`
- Issue #4 comment summarizing plan

---

### 2026-03-08: RP Registration Status — IcM 757549503 Analysis (Issue #11)

**Context:** Tamir reported receiving a response on IcM 757549503 related to RP registration for Private.BasePlatform. Tasked with reviewing the IcM, researching RP registration requirements, and creating an action plan.

**Key Findings:**

1. **IcM 757549503 is a Sev 3 incident:** "[Private.BasePlatform] Cosmos DB role assignment failure blocking RP manifest rollout"
   - Root cause: `NullReferenceException` in `CosmosDbRoleAssignmentJob` due to missing `jobMetadata` parameter
   - Created 2026-03-06 by Andrew Gao
   - State: **New** (unresolved) — no fix or workaround provided
   - Area: MSAzure\One\Azure-ARM\Azure-ARM-Extensibility\Livesite

2. **Related IcM 754149871:** Cosmos DB deployments failing during role assignment creation with `InternalServerError` from `CreateRoleAssignmentInServerPartitionsAsync` — may indicate platform-wide issue

3. **This is a platform-side bug, not our misconfiguration:** The `NullReferenceException` is in RPaaS infrastructure code, not in our RP registration payload

---

### 2026-03-07: Repository Split Execution (Issue #34)

**Context:** Tamir approved proposal to split tamresearch1 into dedicated private repositories. Executed the plan: created 3 new repos, migrated 61 files, preserved core infrastructure, created catalog.

**Technical Execution:**

1. **Created 3 Private Repos (tamirdresher_microsoft org):**
   - `tamresearch1-dk8s-investigations` — 20 files (DK8S platform research)
   - `tamresearch1-agent-analysis` — 5 files (squad formation reports)
   - `tamresearch1-squadplaces-research` — 36 files (API exploration, screenshots, test data)

2. **Migration Protocol:**
   - Cloned empty repos to temp directory
   - Copied files from tamresearch1 to respective repos
   - Added migration header to all markdown/yaml files: `<!-- Moved from tamresearch1 on 2026-03-07 -->`
   - Committed with descriptive messages including co-author trailer
   - Pushed to main branch
   - Deleted migrated files from tamresearch1
   - Created `.squad/research-repos.md` catalog with links to all three repos
   - Committed cleanup to tamresearch1

3. **Preserved in tamresearch1:**
   - `.squad/` directory (agent configurations, history, decisions, skills)
   - `squad.config.ts`, `package.json`, `package-lock.json`, `node_modules/`
   - `ralph-watch.ps1` (monitoring script)
   - Summary files: `EXECUTIVE_SUMMARY.md`, `QUICK_REFERENCE.txt`, `RESEARCH_REPORT.md`

**Key Learnings:**

1. **Git Automation at Scale:** Batch operations (61 files) across 3 repos require PowerShell loops with error handling. Using `Test-Path` validation before copying prevents pipeline failures.

2. **Migration Headers as Provenance:** Adding `<!-- Moved from tamresearch1 on YYYY-MM-DD -->` to markdown/yaml files creates audit trail for future reference. Critical for understanding artifact origins in private research repos.

3. **Catalog Files are Essential:** Creating `.squad/research-repos.md` with links, descriptions, and file inventories provides single source of truth. Prevents "where did that file go?" questions.

4. **Private Repos by Default:** All research repos created with `--private` flag. Research artifacts, internal APIs, and screenshots should never be public.

5. **Preserve Core Infrastructure:** `.squad/` directory and configuration files (squad.config.ts, package files) must stay in main repo. Splitting knowledge without splitting infrastructure.

6. **Git Workflow Discipline:**
   - Multi-repo operations complete before touching source repo
   - Verify all pushes succeeded before deleting source files
   - Use descriptive commit messages with context
   - Always include co-author trailer for GitHub Copilot CLI commits

**Decision Pattern Applied:**
- **Execute approved plans completely:** No incremental "let's test one repo first" — execute the full plan as proposed
- **Verify before delete:** Ensure all remote pushes succeeded before removing source files
- **Document the split:** Catalog file is not optional; it's the index to the distributed knowledge graph
- **Atomic cleanup:** Single commit removes all migrated files and adds catalog

**Outcome:** Clean repository split. Core team infrastructure (agents, decisions, skills, monitoring) stays in tamresearch1. Research artifacts distributed to topic-specific private repos. Catalog provides navigation.

**Artifacts:**
- `.squad/research-repos.md` — Catalog with links and content inventory
- 3 new private repos populated with 61 migrated files
- Issue #34 closed with completion report

---

4. **RP registration pipeline is completely blocked:** Cannot proceed past the Cosmos DB role assignment step, which blocks manifest rollout, resource type registration, and all downstream steps

5. **RPaaS onboarding process well-documented:** Synthesized comprehensive requirements from 6+ EngineeringHub docs covering Hybrid RP registration, Operations RT, manifest checkin, AFEC, and lifecycle stages

**Technical Learnings:**

1. **RPaaS Hybrid RP registration flow:** File onboarding IcM → RPaaS DRI creates mapping → PUT RP registration with PC Code + Profit Center → Register Operations RT → Manifest checkin → Rollout
2. **Cosmos DB provisioning is automatic:** Since May 2024, OBO subscription is created automatically during RP registration when PC Code and Program ID are provided
3. **RP Lite vs Hybrid vs Direct:** BasePlatformRP is correctly using Hybrid RP (mix of managed and direct resource types)
4. **TypeSpec is mandatory since Jan 2024:** All new RPs must use TypeSpec for API specs
5. **WorkIQ limitations:** Detailed IcM response content not accessible via WorkIQ — incident metadata and email thread subjects visible but not full email bodies

**Decision:** Escalate through RPaaS IST Office Hours. Request manual Cosmos DB role assignment workaround. If unblocked within 2 weeks, proceed with registration PUT; otherwise escalate to Sev 2.

**Artifacts produced:**
- `rp-registration-status.md` — comprehensive status report with IcM analysis, checklist, blockers, and action plan
- Decision inbox entry: `.squad/decisions/inbox/picard-rp-registration.md`
- Issue #11 comment with findings and next steps

---

### 2026-03-07: PR Recommendation Audit (Issue #20)

**Context:** Tamir requested review of all closed PRs for unimplemented recommendations, plus evaluation of GitHub Actions workflow automation options.

**Actions Taken:**
1. Reviewed all 5 closed PRs (#7, #8, #9, #10, #12) — read bodies, comments, review comments, and file changes
2. PR #10 had the richest recommendations: 4-phase continuous learning implementation + 6 OpenCLAW patterns from Tamir's linked article
3. PR #8 had 20+ stability mitigations organized in 3 tiers (Critical/High/Strategic)
4. PR #7 had Fleet Manager prerequisites (DEFER recommendation with adoption triggers)
5. PR #12 had 5-phase RP registration roadmap with Phase 0 prerequisites

**Issues Created (9 total):**
- #21: Continuous Learning Phase 1 — Manual Channel Scan & Skill Promotion (High)
- #22: Continuous Learning Phase 2 — Automated Digest Generator (Medium)
- #23: Apply OpenCLAW Patterns — QMD, Dream Routine, Issue-Triager (High)
- #24: DK8S Stability Tier 1 Critical Mitigations (Critical)
- #25: DK8S Stability Tier 2 High-Impact Improvements (High)
- #26: Workload Identity / FIC Automation — Fleet Manager Prerequisite (Medium)
- #27: RP Registration Phase 0 Prerequisites (Medium)
- #28: Enable GitHub Actions Workflows for Squad Automation (High)
- #29: DK8S Stability Tier 3 Strategic Architecture Initiatives (Strategic)

**Workflow Automation Assessment:**
- All 12 workflows are workflow_dispatch only (no hosted runners at org level)
- Four options identified: self-hosted runner, request hosted access, alternative automation (Azure Functions/Logic Apps), selective enablement
- Highest-value workflows to enable first: squad-triage, squad-label-enforce
- Created issue #28 to track

**Decision Pattern:** When converting design docs to actionable work, organize by implementation tier (immediate/soon/strategic) rather than by source document. This matches how sprint planning actually works.

### 2026-03-07: Repository Organization Decision (Issue #34)

**Context:** Tamir raised issue #34 questioning whether investigation reports and research artifacts should live in separate dedicated repos. The tamresearch1 repo currently contains both squad infrastructure (.squad/*, squad.config.ts) and research outputs (53 files, 620+ KB of analysis reports, guides, test data).

**Technical Learnings:**

1. **Architectural Boundary Principle:**
   - "If this repo was deleted, would we lose the squad's ability to function?" → KEEP IT
   - "If this repo was deleted, would we lose research outputs?" → MOVE IT
   - Squad home base = infrastructure; Research outputs = deliverables with independent lifecycles

2. **Research Output Categorization:**
   - **Investigation Reports:** Deep-dives on target systems (idk8s-infrastructure, BaseplatformRP)
   - **Agent Analysis Reports:** Cross-agent investigations from squad formation/onboarding
   - **Test/Exploration Data:** SquadPlaces API artifacts, screenshots, test payloads
   - Each category has different audience, lifecycle, and access control needs

3. **Repository Anti-Patterns Identified:**
   - Mixing squad infrastructure with deliverables creates confusion about repo purpose
   - 620 KB research outputs cluttering a 15 KB squad home base (~40:1 signal-to-noise ratio)
   - Research artifacts in squad repo prevent granular access control (can't share DK8S research without exposing squad internals)
   - Git history fragmentation: single repo mixing coordination commits with research commits makes both harder to understand

4. **File Count as Signal:**
   - 66 files total; 13 squad infrastructure; 53 research outputs
   - ~80% of files don't belong → architectural violation
   - Clean architecture: 90%+ of files serve primary repo purpose

5. **Repository Design Principles (for multi-agent teams):**
   - **Squad home base contains:** Agent charters, history, decisions, coordination artifacts, tooling config
   - **Research repos contain:** Investigation reports, analysis outputs, research data, deliverables
   - **Test/exploration repos contain:** API test data, screenshots, experimental artifacts
   - Each repo should answer one question: "What is this repo for?" If answer requires "and" → split it

**Decision:**

Create 3 new private repos:
1. **tamresearch1-dk8s-investigations** — DK8S platform deep-dives (13 files)
2. **tamresearch1-agent-analysis** — Squad formation analysis reports (5 files)
3. **tamresearch1-squadplaces-research** — SquadPlaces API exploration (35 files)

Keep in tamresearch1: .squad/*, squad.config.ts, package.json, alph-watch.ps1, git config files

**Migration Strategy:**
- Use manual copy + lineage header notes (simpler than git mv cross-repo)
- Create .squad/research-repos.md catalog for discoverability
- Preserve cross-references via GitHub issue/commit links
- Tag research repos with semantic versions (e.g., 1.0-idk8s-analysis)

**Impact:**
- ✅ Clear separation of concerns
- ✅ Squad home base stays lean (~13 files)
- ✅ Research repos can be archived/shared independently
- ✅ Easier granular access control
- ⚠️ Increased repo count (4 repos instead of 1) → mitigated by catalog
- ⚠️ Cross-repo linking requires discipline → mitigated by conventional commit messages

**Artifacts:**
- .squad/decisions/inbox/picard-repo-organization.md — Full decision document
- Issue #34 comment — Posted analysis and awaiting approval

**User Preferences Learned:**
- Tamir prefers private repos unless explicitly requested otherwise
- Tamir values clear architectural boundaries and organization
- Routing through issues for structural decisions is correct pattern

**Key File Paths:**
- .squad/decisions/inbox/ — Decision proposals (staged by agents, merged by Scribe)
- .squad/research-repos.md — Catalog for cross-repo references (to be created)
- .squad/agents/{name}/history.md — Agent learning accumulation

---

### 2026-03-07: Ralph Round 1 — Triage + Repo Organization (Background)

**Context:** Ralph work-check cycle initiated. Picard assigned to triage #35/#34 and deliver repo organization decision.

**Triage Actions:**
- Issue #35 (Squad places feeds): Classified as B'Elanna responsibility (infrastructure expert required); coordinated ownership routing
- Issue #34 (Repo organization): Full analysis and decision proposal delivered

**Outcome:** ✅ Complete
- Analysis complete; 3 new repos proposed; decision posted to #34
- Decision merged into .squad/decisions.md by Scribe
- Awaiting Tamir approval before creating repos and executing migration

**Next Steps:**
- Monitor #34 for approval/feedback
- Upon approval: Create 3 new private repos via gh CLI
- Execute migration plan (file moves, cross-references, catalog creation)

---
