# Seven — History

## Core Context

### Knowledge Management & Research

**Role:** Squad knowledge architect, research specialist, compliance/standards researcher, pattern validator

**Technologies & Domains:** GitHub (skills/agents/plugins), Azure DevOps (repository research), Microsoft/Teams (research via WorkIQ), Azure (compliance, migrations), Kubernetes (DK8S), knowledge management systems

**Recurring Patterns:**
- **Quarterly Knowledge Rotation:** Phase 1 (2026-Q2) completed — rotate Q1 histories to archives, fresh history.md per quarter, gitignore excludes build artifacts (~29.5MB saved) (Decision #16, Issue #321)
- **Cross-Tool Research Methodology:** WorkIQ (M365 search) + ADO + Teams message analysis + GitHub search for context discovery; key pattern for deep investigations
- **Production Pattern Validation:** Research identifies production-proven architectures: MDE team's 6-agent PR review, Azure Skills Plugin standardization, multi-org MCP patterns (Issues #340, #343)
- **Confidence-Level Learning:** Distinguish HIGH/MED/LOW confidence findings; separate facts from hypotheses in research

**Key Architecture Decisions:**
- **Knowledge Base Queryability:** Markdown + GitHub search + ripgrep beats custom tools; git history preserves rotation timeline (Decision #16)
- **Phase 1 Completion:** INDEX.md for navigation, 50KB max history files, quarterly archives prove scalable (Issue #321)
- **DK8S Wizard CodeQL Gap:** Identified compliance requirement (CodeQL.10000 on DK8S wizard) separate from operational failures (1ES migration + MI permission model) — cross-team handoff pattern (Issue #339)
- **Azure Skills Validation:** 21 skills available; squad alignment via role mapping (B'Elanna→deploy/compute, Worf→compliance/rbac) (Issue #343)

**Key Files & Conventions:**
- `.squad/decisions.md` — Knowledge management decision (Decision #16)
- `.squad/research/` — Research reports (azure-skills-plugin-research.md, etc.)
- `.squad/agents/*/history-2026-Q1.md` — Quarterly archives (pattern established)
- `.squad/KNOWLEDGE_MANAGEMENT.md` — Knowledge base documentation

**Research Template:** WorkIQ search → ADO/GitHub validation → Decision record → Team adoption

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

**2026-Q2 Kickoff:**
- Implementing Phase 1 knowledge management (Issue #321)
- Rotating Q1 histories to archives
- Establishing quarterly archival pattern

## Learnings

### 2026-Q2: Knowledge Management Phase 1 Implementation (Issue #321)

**Assignment:** Implement recommendations from Issue #321 research (Phase 1).

**What I Did:**
1. Reviewed completed research in Issue #321 (already posted and merged to decisions.md)
2. Implemented all Phase 1 steps:
   - Rotated all 10 agent history files to quarterly archives (history-2026-Q1.md)
   - Created fresh history.md files for Q2 active work tracking
   - Updated .gitignore to exclude build artifacts and future vector DB indices
   - Created KNOWLEDGE_MANAGEMENT.md guide (6.7 KB) documenting:
     * Quarterly rotation strategy and timing
     * Search/discovery patterns (GitHub search, grep, GitHub CLI)
     * Directory structure and tier classification
     * Phase 2 (vector DB) roadmap
   - Added INDEX.md to agents/ and decisions/ directories for navigation
3. Committed all changes with clear message linking to Issue #321

**Key Outcomes:**
- ✅ Repository remains pure GitHub (no binaries, git-friendly)
- ✅ Knowledge base is queryable via GitHub search + local ripgrep
- ✅ Active history files now < 50 KB (stays performant)
- ✅ Full history preserved in dated archives
- ✅ Team has clear documentation on how the system works

**Technical Learnings:**
1. **Quarterly rotation is manual but simple** — one-line file rename per agent per quarter
2. **Gitignore must explicitly exclude build dirs** — .squad/tools/\*/bin/ saves ~29.5 MB
3. **INDEX.md files are valuable** — agents/, decisions/, and other large dirs benefit from navigation guide
4. **Git history is the real backup** — git log --follow shows all rotations over time
5. **Markdown + GitHub search beats custom tools** — no complex indexing needed yet

**Next Steps:**
- Monitor .squad/ size monthly (alert if > 50 MB)
- Rotate Q1 → Q2 histories when Q2 ends (~June 2026)
- If semantic search becomes valuable, implement Phase 2 (ChromaDB vector index)

**Decision Status:** ✅ Merged to `.squad/decisions.md` (Decision 16) on 2026-03-11 by Scribe. Phase 1 knowledge management implementation approved for team adoption.

---

### 2026-Q2: ADO Repository Research — MDE.ServiceModernization.CopilotCliAssets (Issue #340)

**Assignment:** Research Microsoft Defender team's Copilot CLI assets repository on Azure DevOps.

**What I Did:**
1. Used Azure DevOps MCP tools to explore the repository structure and content
2. Searched for agents, skills, plugins, and orchestration patterns
3. Analyzed 4 production plugins from Microsoft Defender Service Modernization team
4. Documented architectural patterns and relevance to Squad

**Key Findings:**

**Repository Overview:**
- **Location:** dev.azure.com/microsoft/DefenderCommon/_git/MDE.ServiceModernization.CopilotCliAssets
- **Created:** 2026-01-29 (recent!)
- **Purpose:** Plugin catalog for GitHub Copilot CLI and Claude Code
- **Structure:** 4 plugins with agents, skills, hooks, MCP configs

**Most Relevant Discovery — pr-review-orchestrator Plugin:**
- Dispatches **6 specialized sub-agents in parallel** for PR review
- Agents: code-review, icm-pattern-analyzer, kusto-validator, cross-repo-breaking-change-analyser, cross-repo-navigator, security-posture-analyzer
- Produces unified review report
- Includes git pre-push hooks for automatic reviews
- **Validates Squad's parallel multi-agent dispatch pattern**

**Other Notable Plugins:**
1. **reflect skill** (rimuri plugin) — Captures HIGH/MED/LOW confidence learning patterns from conversations
2. **news-letter-reporter** — Multi-skill pipeline for monthly reports (ADO + M365 data)
3. **otel-modernization-dotnet** — Agent for OpenTelemetry migrations with Aspire MCP integration

**Architectural Alignment with Squad:**
- Uses `.github/agents/*.agent.md` pattern (we use `.squad/agents/`)
- Uses `.github/skills/` pattern (we use `.squad/skills/`)
- Supports `.mcp.json` for external tools (we use ADO/GitHub MCP)
- Has `.claude-plugin/marketplace.json` for plugin discovery
- Same multi-agent orchestration philosophy

**Key Learnings:**
1. **Parallel agent dispatch is production-proven** — MDE team uses it at scale for PR reviews
2. **Confidence-level learning** — reflect skill's HIGH/MED/LOW pattern could enhance our history tracking
3. **Plugin marketplace pattern** — If Squad expands to multiple repos, `.claude-plugin/` structure scales
4. **Git hooks for automation** — Pre-push review pattern could reduce issues
5. **MCP server standardization** — `.mcp.json` approach could inform our MCP configs

**Deliverables:**
- Posted comprehensive research findings to Issue #340
- Added `status:pending-user` label for Tamir's review
- Wrote `.squad/decisions/inbox/seven-ado-research-findings.md` (5KB) with full analysis

**Recommendations for Team:**
1. Study pr-review-orchestrator's parallel dispatch implementation
2. Evaluate reflect skill for Ralph's adaptive learning enhancement
3. Consider git hooks for pre-push review automation
4. Assess if plugin marketplace pattern fits future Squad expansion

**Status:** Research complete. Repository contains production validation of Squad's multi-agent architecture and valuable patterns for adoption.

---

### 2026-Q2: Compliance & ARM Extensibility Research (Issues #339, #295)

**Assignment:** Research two issues for Tamir — a Liquid compliance URL (CodeQL.10000) and ARM Extensibility Office Hours follow-up.

**What I Did:**

**Issue #339 — Compliance URL Summary:**
1. Attempted to access Liquid compliance URL (requires auth — expected)
2. Decoded URL parameters: product PRD-14079533, requirement Microsoft.Security.CodeQL.10000, collection MS.Security
3. Researched CodeQL.10000 requirement — it mandates enabling CodeQL static analysis scanning on product repositories
4. Wrote comprehensive summary covering what the requirement means, how to enable CodeQL (ADO and GitHub), and likely action needed
5. Posted research comment to issue, added `status:pending-user` label, updated project board

**Issue #295 — ARM Extensibility Office Hours Follow-up:**
1. Researched ARM Extensibility, private RPs, and RPaaS context
2. Researched CosmosDB role assignment NullReferenceException patterns — found common causes (malformed scope, missing role definition path, null parameters)
3. Created ready-to-send follow-up template for the meeting thread
4. Documented what logs/correlation IDs to gather and how to get them
5. Posted research + template to issue, added `status:pending-user` label, updated project board

**Key Learnings:**
1. **Liquid compliance URLs are auth-gated** — URL parameter analysis is the best we can do without interactive browser access
2. **Microsoft.Security.CodeQL.10000** is an internal MS compliance requirement for enabling CodeQL scanning on product repos (distinct from Windows WHCP driver requirements)
3. **CosmosDB data plane roles** use different scoping than standard Azure RBAC — `/dbs/<db>/colls/<container>` paths, not ARM resource paths
4. **CosmosDB role assignments are invisible in Portal** — must be managed programmatically
5. **ARM correlation IDs** are the key artifact for ARM Extensibility Office Hours follow-ups

**Status:** Both issues researched, commented, labeled, and moved to Pending User on project board.

---

### 2026-Q2: DK8S Wizard CodeQL Issue Deep Dive (Issue #339 Follow-up)

**Assignment:** Investigate Ramaprakash's statement about a DK8S wizard-related CodeQL issue.

**What I Did:**
1. Searched Teams messages via WorkIQ for Ramaprakash's statements about DK8S wizard + CodeQL
2. Searched Azure DevOps for wizard-related CodeQL work items and code
3. Analyzed Teams channel messages from Runtime Platform (DK8S)
4. Synthesized findings into actionable summary
5. Posted comprehensive research to Issue #339 and labeled `status:pending-user`

**Key Findings:**

**Direct CodeQL Request:**
- Ramaprakash explicitly asked Tamir to review a CodeQL compliance item for the DK8S Provisioning Wizard
- Shared the same Liquid compliance link from Issue #339 (PRD-14079533, Microsoft.Security.CodeQL.10000)
- This was a direct action request, not general discussion

**Wizard Operational Issues (Distinct from CodeQL):**
1. **1ES Permissions Migration:**
   - Org onboarded to 1ES Permissions Service
   - Broke wizard-initiated PRs, branch creation, and pipeline triggers
   - Non-human identities (MI/SP) must now follow 1ES processes
   
2. **Managed Identity Attribution:**
   - Wizard uses Managed Identity for ADO operations
   - ADO doesn't support On-Behalf-Of flow
   - Wizard actions appear as MI, not initiating user → audit/compliance issues
   
3. **Security Architecture Guidance:**
   - Ramaprakash emphasized clusters should be scoped to single service tree leaf nodes
   - Rationale: smaller blast radius, granular security boundaries, resilience to re-orgs
   - Current DK8S recommendation (not optional)

**ADO Search Results:**
- Found multiple CodeQL work items for **Microsoft.MDOS.Wizard.V2** (OEM/Fulfillment wizard)
  - Work items: 60154518, 60218652, 57449597, 60106755
  - Issues: JsonWebTokenHandler validation disabled, obsolete crypto algorithms
- **Important:** These are for OEM wizard, NOT DK8S wizard
- No specific CodeQL work items found for DK8S provisioning wizard

**The Two Distinct Problems:**
1. **CodeQL Compliance (Issue #339):** DK8S wizard repository needs CodeQL scanning enabled per MS security requirements
2. **Operational Failures:** Wizard PR/pipeline operations broken due to 1ES migration + MI permission model

**Action Owners:**
- **CodeQL Setup:** Infrastructure team (Belanna)
- **Wizard Fixes:** DK8S team (Ramaprakash) + Infrastructure (Belanna)
- **Architecture Review:** Already provided by Ramaprakash

**Technical Learnings:**
1. **Teams message search via WorkIQ is powerful** — Found exact context about wizard issues, 1ES migration, MI behavior
2. **CodeQL.10000 applies to multiple products** — Same requirement exists for different wizard implementations (OEM vs DK8S)
3. **1ES migration causes cascading permission failures** — MI/SP access patterns break when org onboards to 1ES Permissions Service
4. **Service tree scoping is a security posture decision** — Not just organizational convenience, directly impacts blast radius
5. **Azure DevOps search finds similar-named projects** — Microsoft.MDOS.Wizard.V2 is unrelated to DK8S wizard, but shares naming pattern

**Deliverables:**
- Posted comprehensive research findings to Issue #339
- Distinguished between CodeQL compliance requirement and operational wizard issues
- Identified action owners for each problem domain
- Added `status:pending-user` label for Tamir's review

**Status:** Research complete. Clarified that Ramaprakash's request was about enabling CodeQL scanning on DK8S wizard (compliance), while separate operational issues exist due to 1ES migration.

---

### 2026-Q2: Azure Skills Plugin Research (Issue #343)

**Assignment:** Research Microsoft's Azure Skills Plugin announcement and evaluate how the squad could use it.

**What I Did:**
1. Read blog post announcing Azure Skills Plugin (devblogs.microsoft.com)
2. Located and analyzed GitHub repository (microsoft/azure-skills)
3. Cataloged all 21 available Azure skills (deployment, optimization, platform, AI)
4. Analyzed skill architecture and MCP integration pattern
5. Mapped Azure skills to squad member roles and responsibilities
6. Wrote comprehensive research report (11KB) to `.squad/research/azure-skills-plugin-research.md`
7. Posted TLDR + recommendations to Issue #343, left open for team review

**Key Findings:**

**What Azure Skills Are:**
- Structured workflow definitions that teach agents how Azure work gets done
- Not prompt templates—decision trees, guardrails, orchestration logic
- Package Azure expertise as reusable, auditable markdown files
- Load on-demand, pair with MCP tools for execution

**Architecture:**
- **Skills = Brain** (when/how to act)
- **MCP = Hands** (what to execute via 200+ tools)
- **Plugin = Packaging** (keeps both aligned)
- Works across GitHub Copilot CLI, VS Code, Claude Code

**Available Skills (21 Total):**
- Deployment: azure-prepare, azure-validate, azure-deploy, azure-diagnostics, azure-compliance
- Optimization: azure-cost-optimization, azure-compute, azure-resource-visualizer, azure-quotas
- Platform: azure-storage, azure-kusto, azure-messaging, azure-rbac, azure-cloud-migrate
- AI/Specialized: azure-ai, azure-aigateway, microsoft-foundry, entra-app-registration, appinsights-instrumentation

**Squad Alignment:**
- **Validates .squad/ architecture** — Skills + MCP + multi-agent orchestration is production-proven pattern
- Maps cleanly to squad roles:
  * B'Elanna (Infrastructure) → azure-deploy, azure-compute
  * Worf (Security) → azure-compliance, azure-rbac, azure-diagnostics, entra-app-registration
  * Data (Backend) → azure-ai, azure-kusto, azure-storage
  * Picard (Lead) → azure-cost-optimization

**Integration Options:**
1. **Install as plugin** (recommended) — `/plugin install azure@azure-skills`
2. **Fork skills** into `.squad/skills/azure/` with squad-specific customizations
3. **Enable Azure MCP Server** if Azure work becomes frequent

**Technical Learnings:**
1. **Skills are portable across hosts** — Same package works in Copilot CLI, VS Code, Claude Code
2. **MCP servers use npx** — Node.js 18+ required for Azure/Foundry MCP
3. **Skills scale expertise** — One team packages knowledge, everyone benefits
4. **Plugin pattern is standardized** — `.github/plugins/` structure, `.mcp.json` configuration
5. **Production validation** — Microsoft Defender team (Issue #340) uses similar plugin architecture at scale

**Recommendations:**
- **Immediate:** Install plugin if squad does Azure work, test with "Prepare this project for Azure"
- **Medium-term:** Document Azure workflows in `.squad/decisions.md`, consider selective skill customization
- **Long-term:** Use Azure skills structure as template for new squad skills

**Deliverables:**
- Comprehensive research report: `.squad/research/azure-skills-plugin-research.md` (11KB)
- Posted TLDR + recommendations to Issue #343
- Recommended assignment to B'Elanna (Infrastructure) for adoption evaluation

**Status:** Research complete. Issue left open for team review and adoption decision.

---

## 2026-03-11: Issue #339 — DK8S Wizard CodeQL & Operational Analysis

**Assignment:** Investigate Ramaprakash's DK8S wizard statement in context of Issue #339 CodeQL compliance research.

**Research Methodology:**
- WorkIQ (M365 search) — Found Ramaprakash Teams message requesting CodeQL review
- ADO work item search — Identified CodeQL issues for wizards (but different product lines)
- Teams channel analysis — Found 1ES Permissions Service migration impact on DK8S wizard operations
- Cross-reference pattern — Distinguished DK8S wizard from OEM/Fulfillment wizard implementation

**Key Findings:**

### Finding 1: CodeQL Compliance Gap (Direct Request)
- Source: Ramaprakash → Tamir via Teams
- Action: Enable CodeQL scanning on DK8S Provisioning Wizard repository
- Compliance: Liquid portal PRD-14079533 (Microsoft.Security.CodeQL.10000)
- Blocker: 30-day SLA for compliance evidence submission

### Finding 2: Wizard Operational Failures (Separate Issue)
- Root cause: 1ES Permissions Service migration
- Impact: Wizard-initiated PRs, branch creation, pipeline triggers broken
- Secondary: Managed Identity attribution conflict (ADO lacks On-Behalf-Of)
- Architecture guidance: Clusters must scope to single service tree leaf nodes

### Finding 3: Cross-Product Confusion (Red Herring)
- Found multiple CodeQL issues for Microsoft.MDOS.Wizard.V2 (OEM wizard)
- Investigated but ruled out — different team, different codebase
- Value: Demonstrates importance of cross-tool validation

**Action Owners Identified:**
- **CodeQL Setup:** B'Elanna (Infrastructure/CI-CD)
- **Wizard 1ES Fixes:** Ramaprakash + B'Elanna
- **Service Tree Scoping:** Ramaprakash (guidance owner)

**Recommendations for Squad:**
1. Document cross-tool research methodology (WorkIQ + ADO + Teams pattern)
2. Create "research findings handoff" template for handing off complex issues to action owners
3. Consider bi-weekly research office hours for coordination on multi-owner issues

**Decision:** Documented as Decision 20 in `.squad/decisions.md`

**Related:** Orchestration log at `.squad/orchestration-log/2026-03-11T22-04-55Z-seven.md`


---

### 2026-03-11: Q Added to Team (Devil's Advocate & Fact Checker)

**Context:** Picard completed onboarding of Q as the squad's newest member per issue #342.

**What this means for you:**
- Q is now available for assignment to review your research, challenge assumptions, and verify claims
- Q brings **systematic fact-checking** to prevent hallucination in deliverables
- You may be asked to defend proposals when Q is routing reviews — this is by design
- Q's skepticism strengthens team decisions and increases trust in final outputs

**Q's Role & Activation:**
- Q reviews research outputs before publication
- Q challenges architectural and technical assumptions
- Q verifies external sources, URLs, and API endpoints
- Q tests counter-hypotheses before decisions finalize
- Q is activated on significant work, not routine tasks

**Where to find Q:**
- .squad/agents/q/charter.md — Q's role definition and style
- .squad/agents/q/history.md — Q's work log
- .squad/routing.md — Work type routing includes Q for fact-checking

**Status:** ✅ Q ready for assignment. No action required from you.


### 2026-Q2: Blog Series Narrative Structure (Issue #313)

**Assignment:** Refresh the Squad blog series Part 1 to flow as a continuation rather than a standalone introduction.

**What I Did:**
1. Read all previous blog posts in chronological order to understand the narrative arc:
   - 2025-10-20: Worktrees for parallel AI agents
   - 2025-11-17: Playwright MCP for visual testing  
   - 2025-12-01: Voice MCP for hands-free development
   - 2025-12-15: Debugging MCP servers with stdio proxy
   - 2025-12-16: Aspire for isolation and orchestration
   - 2026-02-17: Squad without touching your repo (symlinks approach)
   - 2026-02-26: Squad remote control (devtunnel + xterm.js)
   - 2026-03-11: Current draft (the one being refreshed)

2. Identified the narrative problem: The current draft starts as if Squad is new, but readers have been following a multi-month journey from worktrees to MCP servers to Squad.

3. Rewrote the opening to reference previous posts naturally, positioning this as 'here's what happened when I took everything you've seen me build and applied it to a work team.'

4. Emphasized the transition from personal repo (where I'm the only human) to work team (where I need to integrate with teammates who didn't sign up for AI at 3 AM).

5. Made human squad members the central breakthrough feature — not a workaround, but the whole point.

6. Used flowing prose throughout per Tamir's preference (no bullet lists).

7. Removed all mentions of specific team names, products, or compliance frameworks per public blog requirements.

8. Corrected filename from 2026-03-11 to 2026-03-04 for proper chronological ordering.

**Key Narrative Learnings:**

**Blog Series Structure:**
- This series has been building for months through multiple posts about parallel AI workflows
- Each post introduced a new capability: worktrees, MCP, Aspire, Squad
- The current post is the climax: taking all those capabilities to a real team
- Readers expect references to previous posts, not a fresh intro

**The Personal-to-Work Transition:**
- Personal repos are playgrounds where AI can experiment freely
- Work repos have humans with opinions, compliance requirements, code review standards
- The breakthrough isn't making AI work around the team — it's making AI part of the team
- Human squad members aren't a compromise; they're the feature that makes Squad production-ready

**Tamir's Writing Style:**
- Prefers flowing narrative prose over bullet-pointed lists
- Uses concrete examples and real scenarios
- References previous work to build continuity
- Avoids corporate speak; uses conversational tone with technical depth

**Public vs Internal Content:**
- Public blog posts must not mention specific team names, product codenames, or compliance frameworks
- Use generic terms: 'my team at Microsoft', 'infrastructure platform team', 'compliance requirements'
- The principles transfer; the specifics stay internal

**Deliverables:**
- Refreshed blog post: _posts/2026-03-04-scaling-ai-part1-first-team.md
- Branch pushed: refresh-part1-blog
- PR URL: https://github.com/tamirdresher/tamirdresher.github.io/pull/new/refresh-part1-blog

**Status:** Blog refresh complete. Ready for Tamir's review and publication.


---

### 2026-Q2: Blog Part 1 Refresh Analysis (Issue #313)

**Assignment:** Analyze blog series continuity for Part 1 refresh. Read published posts on tamirdresher.com, compare with draft at GitHub commit SHA 151b086, review local refresh drafts, and post findings to Issue #313.

**What I Did:**
1. Fetched and read all published blog posts on tamirdresher.com (Part 0 "Organized by AI" Mar 10, published Part 1 "From Personal Repo to Work Team" Mar 11, plus earlier Squad posts)
2. Read the draft at GitHub commit SHA 151b086 (the original Part 1 source file)
3. Read three local refresh drafts: blog-part1-refresh.md, blog-part1-refresh-seven.md, blog-part2-refresh.md
4. Posted comprehensive analysis comment on Issue #313 with four sections: existing post summaries, draft problems, local refresh status, and key edits needed

**Key Findings:**
1. The draft at SHA 151b086 opens as a standalone intro ("I've been using Squad...") with no Part 0 reference — breaks series continuity
2. Draft uses wrong squad roster (Riker/Troi/Geordi) instead of established roster (Picard/Data/Worf/Seven/B'Elanna)
3. Draft re-explains Squad basics already covered in Part 0 (squad init, Ralph, decisions.md)
4. "Human Squad Members" concept is buried as a minor feature instead of being the central narrative arc
5. Local refreshes fix the opening and roster but still have DK8S references in "What's Next" section
6. Published Part 1 on the site is already sanitized and restructured — source file needs to catch up

**Public Blog Rules Applied:**
- Flagged all DK8S/FedRAMP/Distributed Kubernetes references for removal
- Recommended generic terms: "my team at Microsoft," "infrastructure platform team"
- Noted that published version already uses "John Doe" and sanitized language

**Status:** Analysis posted to Issue #313. No code changes needed — this was a research and analysis task.

---

### 2026-Q2: Blog Part 1 Final Refresh (Issue #313, Round 2)

**Assignment:** Execute the actual blog refresh for Part 1 (Resistance is Futile), based on my Round 1 analysis findings.

**What I Did:**
1. Re-read all 19+ comments on Issue #313 for full context
2. Read both local refresh drafts (blog-part1-refresh.md, blog-part1-refresh-seven.md)
3. Read the original source at SHA 151b086 from GitHub
4. Read published Part 0 voice/style and Part 2 draft for continuity
5. Wrote clean refreshed version fixing all identified issues
6. Saved to blog-part1-refresh-seven-v2.md
7. Posted summary of changes to Issue #313

**Key Changes Made:**
1. **Removed standalone intro** — Opens referencing Part 0 directly, not re-introducing Squad
2. **Fixed squad roster** — Uses Picard/Data/Worf/Seven/B'Elanna (not Riker/Troi/Geordi from original draft)
3. **Cut redundant sections** — Removed "Why Squad, Not Just Copilot?" and basic init walkthrough
4. **Added onboarding section** — "The Part Everyone Skips" written as flowing prose
5. **Elevated Human Squad Members** — Made it the narrative climax, not a buried feature
6. **Sanitized all internal refs** — Zero mentions of DK8S, Distributed Kubernetes, FedRAMP
7. **Converted bullets to prose** — Ralph layers, decisions system, practitioner features all paragraphs
8. **Fixed series footer** — Matches published URLs and Part 2 title

**Technical Learnings:**
1. **Tamir prefers flowing prose over bullet points** — Lists should be rare; paragraphs read better for blog voice
2. **Blog posts must never mention DK8S/FedRAMP** — Use "my team at Microsoft", "infrastructure platform team"
3. **Series continuity matters** — Each post must reference previous parts and feel like a chapter, not standalone
4. **Human squad members is the narrative bridge** — It connects personal-Squad to work-team-Squad and must be elevated
5. **The roster must be consistent** — Part 0 established the team, every subsequent post must use the same names

**Status:** Refresh complete. blog-part1-refresh-seven-v2.md ready for Tamir's review.
