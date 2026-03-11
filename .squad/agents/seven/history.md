# Seven — History

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
