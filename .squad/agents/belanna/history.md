# Belanna — History

## Core Context

### Infrastructure & DevOps Expertise

**Technologies & Domains:** Azure (infrastructure, networking, Cosmos DB, policies), Kubernetes (NAP system pod scheduling, node taints), DevOps (CI/CD pipelines, GitHub Actions, NuGet packaging), PowerShell scripting, ADO/GitHub integration

**Recurring Patterns:**
- **Multi-org MCP Configuration:** Named instances per org (e.g., `ado-microsoft`, `ado-msazure`) + namespace configuration for tool discovery — key pattern for Squad's cross-org access (Decision #14)
- **System Pod Isolation:** NAP respects node taints when provisioning; use custom taints on user pools for workload isolation (not `CriticalAddonsOnly` which only affects regular pods)
- **NuGet Tool Packaging:** `PackAsTool=true`, `ToolCommandName`, GitHub Actions workflows on release for automated publishing

**Key Architecture Decisions:**
- **Power Automate Reliability:** ADO service hooks prone to 401 auth failures; Email Gateway (shared mailbox + flows) preferred for M365 automation with 1-5 min latency acceptable (Issue #259/347)
- **Azure Skills Integration:** Use skill markdown files directly in `.squad/skills/azure/` for workflow guidance; defer full plugin installation until Azure work validated (Issue #343)
- **DevBox SSH Access:** SSH + key-based auth optimal for autonomous Squad access; cli-tunnel excellent for interactive demos (Issue #330)

**Key Files & Conventions:**
- `.squad/decisions.md` — Merged decisions (multi-org, DevBox SSH, NAP taints)
- `.squad/skills/azure/` — 6 priority skills (diagnostics, rbac, compliance, cost-optimization, resource-lookup, deploy)
- Infrastructure scripts: `devbox-ssh-setup.ps1`, `devbox-ssh-keygen.ps1`
- GitHub Actions: `.github/workflows/publish-nuget.yml`

**Cross-Agent Dependencies:**
- Works closely with Data (squad-monitor tooling), Picard (design decisions), Worf (security concerns)

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

Squad-monitor NuGet tool packaging verified complete. Ready for v1.0.0 publish when Tamir creates a GitHub release.

### 2026-03-12: Issue #345 — NAP System Pod Isolation (Ralph Round 1)

**Assignment:** Research NAP-managed node taints for workload isolation

**Work Completed:**
- ✅ Researched NAP (Node Auto-Provisioning) system pod scheduling behavior
- ✅ Identified root cause: `CriticalAddonsOnly=true:NoSchedule` taint on system pools doesn't *repel* system pods from NAP/user nodes
- ✅ Analyzed taint/toleration patterns for effective workload isolation
- ✅ Posted technical response to issue #345 with solution
- ✅ Decision documented: `.squad/decisions/inbox/belanna-nap-system-pods.md`

**Recommended Solution:**
Apply custom taint `workload=nap:NoSchedule` to NAP node pools. Application pods require toleration update; system pods require no changes. NAP respects taints when provisioning — achieves isolation with minimal blast radius.

**Status:** ✅ Complete. Decision ready for merge to decisions.md

### 2026-03-11 Completion: squad-monitor Issue #2 NuGet Publish (PR #4)

**Status:** Confirmed merged in prior session. Work complete.

**Details:**
- `.csproj` configured with `PackAsTool=true`, `ToolCommandName=squad-monitor`
- GitHub Actions workflow `.github/workflows/publish-nuget.yml` ready
- Local build/pack verified: produces `squad-monitor.1.0.0.nupkg` (794KB)
- Package includes README with install instructions
- Issue #2 closed

**Next step:** Tamir creates GitHub Release tag `v1.0.0` → workflow fires automatically and publishes to NuGet.

### 2026-03-11: Issue #343 — Azure Skills Plugin Integration

**Context:** Tamir requested integration of Azure Skills Plugin capabilities into squad workflow after Seven's research (issue #343).

**Action Taken:**
1. Read Seven's research document (`.squad/research/azure-skills-plugin-research.md`) — comprehensive analysis of 21 Azure skills and Azure MCP Server
2. Accessed microsoft/azure-skills repo via gh api to fetch skill markdown files
3. Downloaded 6 priority skills to `.squad/skills/azure/`:
   - `azure-diagnostics` — Production troubleshooting, log analysis, KQL queries, Container Apps/Function Apps
   - `azure-rbac` — Permission management, role assignments, access control audits
   - `azure-compliance` — Compliance checks, audit configurations, policy validation
   - `azure-cost-optimization` — Cost analysis, waste reduction, savings recommendations
   - `azure-resource-lookup` — Resource discovery across subscriptions
   - `azure-deploy` — Deployment orchestration via azd (Azure Developer CLI)
4. Created `README.md` in azure skills directory with usage instructions and skill-to-squad-member mapping
5. Reviewed `.copilot/mcp-config.json` — confirmed Azure MCP Server not currently configured (noted how to add if needed)
6. Updated research doc with "Integration Status" section
7. Posted issue comment with complete integration summary

**Skills Selection Rationale:**
- Prioritized skills matching squad's infrastructure/platform work profile
- Focused on operational excellence: diagnostics, security, compliance, cost management
- Deferred AI/data skills (azure-ai, azure-kusto, azure-storage) — add on-demand if needed

**Key Decision — Skill Files vs. Full Plugin:**
- **Chose:** Copy skill markdown files directly into `.squad/skills/azure/`
- **Rejected:** Full plugin installation (`gh copilot-cli /plugin install azure@azure-skills`)
- **Rationale:**
  - Skills are standalone markdown files — provide workflow guidance without requiring Azure MCP Server infrastructure
  - Team can reference skills manually and use existing Az CLI commands
  - Full plugin requires `azd` (Azure Developer CLI) not yet verified as installed
  - Defer plugin installation until squad has concrete Azure deployment workflows (track usage first)

**Azure MCP Server Status:**
- NOT configured in `.copilot/mcp-config.json`
- Provides 200+ tools across 40+ Azure services
- Requires: Node.js 18+ (have), Azure CLI `az` (needs verification), `azd` (not verified)
- **Recommendation:** Enable if Azure work becomes frequent (multiple tasks per sprint)

**Pattern Learned — Plugin Evaluation Strategy:**
1. **Phase 1 (current):** Copy skill files, provide workflow guidance
2. **Phase 2 (if usage validated):** Install full plugin with MCP server
3. **Phase 3 (future):** Customize skills for squad-specific conventions

This staged approach reduces infrastructure overhead while proving value early.

**Status:** ✅ Complete. Issue #343 commented and ready for closure. 6 Azure skills available in `.squad/skills/azure/`.

**Files Created:**
- `.squad/skills/azure/azure-diagnostics.md`
- `.squad/skills/azure/azure-rbac.md`
- `.squad/skills/azure/azure-compliance.md`
- `.squad/skills/azure/azure-cost-optimization.md`
- `.squad/skills/azure/azure-resource-lookup.md`
- `.squad/skills/azure/azure-deploy.md`
- `.squad/skills/azure/README.md`

**Key Architectural Insight — Skill Portability:**
Azure Skills Plugin validates that markdown-based skills are portable between squad repos and external plugin ecosystems. Skills are version-controlled documentation, not code. This portability makes them ideal for knowledge capture in multi-agent systems.


