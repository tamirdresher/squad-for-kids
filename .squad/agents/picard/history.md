# Picard — History

## Core Context

- **Project:** Cross-repo research and analysis team covering infrastructure, security, cloud native, and development across Azure DevOps and GitHub repositories
- **User:** Tamir Dresher
- **Role:** Lead
- **Joined:** 2026-03-02T15:01:26Z
- **Note:** Recast from Neo (The Matrix) to Picard (Star Trek TNG/Voyager)

## Learnings

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
