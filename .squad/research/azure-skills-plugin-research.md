# Azure Skills Plugin Research
**Issue:** #343  
**Researcher:** Seven  
**Date:** 2026-03-11  
**Blog Post:** https://devblogs.microsoft.com/all-things-azure/announcing-the-azure-skills-plugin  
**Repository:** https://github.com/microsoft/azure-skills

---

## Executive Summary

The **Azure Skills Plugin** is Microsoft's solution to the "Azure expertise gap" in coding agents. It packages 20+ curated Azure skills, the Azure MCP Server (200+ tools across 40+ services), and the Foundry MCP Server into a single installable plugin. The plugin transforms generic Azure advice into executable, workflow-driven operations with built-in guardrails.

**Key Value:** Skills provide the "brain" (when/how to act), MCP servers provide the "hands" (what to execute), and the plugin keeps both aligned.

---

## What Are Azure Skills?

Azure Skills are **structured workflow definitions** that teach coding agents how Azure work actually gets done. They're not prompt templates—they're decision trees, guardrails, and orchestration logic that capture Azure expertise.

### How They Work

1. **Skills load on-demand** — Agent can access large capability set without bloating every prompt
2. **Skills are auditable** — Plain text, version-controlled, reviewable markdown files
3. **Skills pair with MCP** — Workflow guidance (skill) + execution layer (MCP tools)
4. **Skills are portable** — Same package works across GitHub Copilot CLI, VS Code, Claude Code, and other compatible hosts

### Architecture

```
User Request
    ↓
Agent analyzes intent
    ↓
Agent loads relevant Azure skill(s)
    ↓
Skill provides workflow steps + decision logic
    ↓
Agent executes steps using Azure MCP Server tools
    ↓
Agent returns structured results
```

**Example workflow:** `azure-prepare` → `azure-validate` → `azure-deploy`

---

## Repository Details

**Location:** https://github.com/microsoft/azure-skills  
**Structure:**
- `.github/plugins/azure-skills/skills/` — 21 skill definitions
- `.github/plugins/azure-skills/.mcp.json` — MCP server configuration
- Synced from: https://github.com/microsoft/GitHub-Copilot-for-Azure

**Installation Targets:**
- GitHub Copilot CLI: `/plugin install azure@azure-skills`
- VS Code: Azure MCP extension from marketplace
- Claude Code: `claude plugin install azure@azure-skills`

---

## Available Skills (21 Total)

### Deployment & Operations
1. **azure-prepare** — Analyze project, generate Dockerfiles, infrastructure code, azure.yaml
2. **azure-validate** — Pre-flight checks before deployment
3. **azure-deploy** — Orchestrate deployment pipeline via `azd`
4. **azure-diagnostics** — Troubleshoot failures with logs, metrics, KQL queries
5. **azure-compliance** — Check compliance posture, audit configurations

### Optimization & Design
6. **azure-cost-optimization** — Find waste, generate savings recommendations
7. **azure-compute** — Compute service selection and sizing guidance
8. **azure-resource-visualizer** — Visualize resource relationships and dependencies
9. **azure-resource-lookup** — Search and discover Azure resources
10. **azure-quotas** — Check quota limits and request increases

### Platform Services
11. **azure-storage** — Storage account guidance (blob, file, queue, table)
12. **azure-kusto** — Azure Data Explorer (Kusto) query and cluster management
13. **azure-messaging** — Service Bus, Event Grid, Event Hubs guidance
14. **azure-rbac** — Role assignments, permissions, and access control
15. **azure-cloud-migrate** — Migration assessment and planning

### AI & Specialized
16. **azure-ai** — Azure AI services (OpenAI, Cognitive Services, ML)
17. **azure-aigateway** — AI Gateway configuration and management
18. **azure-hosted-copilot-sdk** — Hosted Copilot SDK integration
19. **microsoft-foundry** — Microsoft Foundry model catalog, deployments, agents
20. **entra-app-registration** — Entra ID app registration and service principals
21. **appinsights-instrumentation** — Application Insights telemetry setup

---

## How Squad Could Use Azure Skills

### Current Squad Architecture

The squad uses:
- `.squad/agents/` — Agent charters (identity, expertise, style)
- `.squad/skills/` — Custom skills (already established pattern)
- `.squad/decisions.md` — Team decisions and conventions
- Custom MCP configurations (Azure DevOps, GitHub, Teams, etc.)

### Integration Opportunities

#### 1. **Install as Plugin (Recommended)**

Install Azure Skills Plugin at the repository level:

```bash
gh copilot-cli /plugin install azure@azure-skills
```

**Benefit:** Squad members (Picard, Belanna, Worf, etc.) can invoke Azure skills when working on Azure-related issues without re-implementing expertise.

**Example use case:** Issue tagged `azure-infrastructure` → B'Elanna (Infrastructure) invokes `azure-prepare`, `azure-validate`, `azure-deploy` for deployment automation.

#### 2. **Adapt Skills to `.squad/skills/`**

Fork relevant skills into `.squad/skills/azure/` with squad-specific customizations:
- Add references to `.squad/decisions.md` for team conventions
- Integrate with squad routing logic in `.squad/routing.md`
- Customize for tamresearch1 project context

**Best candidates for adaptation:**
- `azure-diagnostics` → Worf (Security) could use for security posture analysis
- `azure-compliance` → Worf (Security) for compliance audits
- `azure-rbac` → Worf (Security) for permission reviews
- `azure-cost-optimization` → Picard (Lead) for budget reviews

#### 3. **MCP Server Integration**

Azure Skills Plugin uses **Azure MCP Server** (200+ tools). Squad already uses multiple MCP servers (ADO, GitHub, Teams).

**Option:** Enable Azure MCP Server in squad's MCP configuration if Azure work becomes frequent.

**Location:** `.squad/.mcp.json` or per-agent MCP configs

---

## Skills Mapping to Squad Roles

| Azure Skill | Squad Member | Rationale |
|-------------|--------------|-----------|
| `azure-deploy` | B'Elanna (Infrastructure) | Deployment orchestration is her domain |
| `azure-diagnostics` | Worf (Security) | Security posture troubleshooting |
| `azure-compliance` | Worf (Security) | Compliance checks and audits |
| `azure-rbac` | Worf (Security) | Permission management and RBAC |
| `azure-cost-optimization` | Picard (Lead) | Budget oversight and efficiency |
| `azure-compute` | B'Elanna (Infrastructure) | Service selection and sizing |
| `azure-ai` | Data (Backend) | AI services integration |
| `azure-kusto` | Data (Backend) | Data analytics and queries |
| `azure-storage` | Data (Backend) | Storage architecture decisions |
| `entra-app-registration` | Worf (Security) | Identity and access management |

**Key insight:** Squad's specialization pattern (agent roles) aligns well with Azure Skills' domain-specific structure.

---

## Recommendations

### Short Term (Immediate)

1. **Install Azure Skills Plugin** in the Copilot CLI environment for this repository
2. **Assign Issue #343 to B'Elanna** (Infrastructure) — if Azure deployment work is planned, she's the natural consumer
3. **Test integration** — Try a prompt like "Prepare this project for Azure" and observe skill activation

### Medium Term (Next Sprint)

1. **Evaluate skill usage patterns** — Track which Azure skills the squad uses most
2. **Document Azure workflows** — If squad frequently works with Azure, add Azure patterns to `.squad/decisions.md`
3. **Consider selective skill customization** — Fork 2-3 high-value skills into `.squad/skills/azure/` with squad-specific context

### Long Term (Future Consideration)

1. **Azure MCP Server adoption** — If Azure work scales, enable Azure MCP Server for all agents
2. **Skill authoring pattern** — Study Azure skills structure as a template for creating new squad skills
3. **Plugin marketplace integration** — If squad expands to multiple repos, consider plugin marketplace pattern (learned from ADO research in Issue #340)

---

## Comparison to Squad's Current Skills

### Similarities
- Both use markdown-based skill definitions
- Both emphasize workflow orchestration over one-shot prompts
- Both integrate with MCP servers for execution layer
- Both are version-controlled and auditable

### Differences
- **Scope:** Azure skills are Azure-specific; squad skills are project/team-specific
- **Distribution:** Azure skills are packaged as plugin; squad skills are repository-native
- **Portability:** Azure skills work across hosts; squad skills are currently Copilot CLI-focused
- **Maintenance:** Azure skills maintained by Microsoft; squad skills maintained by team

### Key Takeaway
Azure Skills Plugin validates the squad's skill-based architecture and provides a production-grade example of multi-agent skill orchestration at scale.

---

## Technical Prerequisites

If the squad decides to adopt Azure Skills Plugin:

**Required:**
- Node.js 18+ (for MCP servers via `npx`)
- Azure CLI (`az`) installed and authenticated
- Azure Developer CLI (`azd`) for deployment workflows

**Optional:**
- Azure subscription (for live operations)
- Service principal credentials (for CI/CD scenarios)
- Managed identity (for Azure-hosted execution)

**Installation Impact:**
- Plugin size: ~100KB (skills are markdown files)
- MCP servers: ~5MB NPM packages
- No binary dependencies in `.squad/` directory

---

## Open Questions for Team

1. **How much Azure work does the squad do?** If minimal, plugin may be overkill; if frequent, it's valuable.
2. **Should Azure skills be global or per-agent?** Could B'Elanna have Azure skills enabled, others not?
3. **Fork vs. consume?** Use plugin as-is, or customize skills into `.squad/skills/azure/`?
4. **MCP server consolidation?** Squad uses multiple MCP servers—should Azure MCP be added to the stack?

---

## Related Research

- **Issue #340:** ADO Repository Research (MDE.ServiceModernization.CopilotCliAssets)
  - Finding: Microsoft Defender team uses similar plugin/skill architecture at production scale
  - Finding: `pr-review-orchestrator` plugin validates parallel multi-agent dispatch pattern
  - Insight: Azure Skills Plugin is part of broader Microsoft push toward packaged agent capabilities

---

## References

- Blog post: https://devblogs.microsoft.com/all-things-azure/announcing-the-azure-skills-plugin
- Repository: https://github.com/microsoft/azure-skills
- Azure MCP Server docs: https://learn.microsoft.com/azure/developer/azure-mcp-server/
- Upstream repo: https://github.com/microsoft/GitHub-Copilot-for-Azure
- Install shortlink: https://aka.ms/azure-plugin

---

## Conclusion

The Azure Skills Plugin is a **production-ready, well-architected solution** that aligns closely with the squad's multi-agent skill orchestration philosophy. It provides 20+ Azure-specific skills, 200+ MCP tools, and works across multiple coding agent hosts.

**Recommendation:** Install the plugin and evaluate usage patterns. If the squad does meaningful Azure work, this plugin will accelerate deployment workflows and reduce Azure decision-making overhead. If Azure work is minimal, it's still valuable as a reference implementation for advanced skill architecture.

**Next Action:** Assign to B'Elanna (Infrastructure) or Picard (Lead) for adoption evaluation.

---

## Integration Status

**Date:** 2026-03-11  
**Integrated By:** B'Elanna (Infrastructure Expert)  
**Issue:** #343

### What Was Done

1. ✅ **6 Priority Azure Skills Copied** to `.squad/skills/azure/`:
   - `azure-diagnostics.md` — Production troubleshooting and log analysis
   - `azure-rbac.md` — Role-based access control and permissions
   - `azure-compliance.md` — Compliance checks and policy validation
   - `azure-cost-optimization.md` — Cost management and waste reduction
   - `azure-resource-lookup.md` — Resource discovery across subscriptions
   - `azure-deploy.md` — Deployment orchestration via azd

2. ✅ **Skills Documentation Created:**
   - `README.md` in `.squad/skills/azure/` with usage instructions
   - Skill-to-squad-member mapping (who benefits from each skill)
   - Instructions for installing full plugin if needed

3. ✅ **MCP Configuration Reviewed:**
   - Repo-level `.copilot/mcp-config.json` exists with ADO MCP configured
   - Azure MCP Server NOT currently configured
   - Documented how to add Azure MCP Server if team decides to enable it

### Skills Selection Rationale

**Prioritized for squad's work profile:**
- **Infrastructure:** Diagnostics, deployment, cost optimization, resource lookup
- **Security:** RBAC, compliance (relevant to Worf)
- **Operations:** All skills support incident response and maintenance

**Not yet integrated (15 skills):**
- azure-prepare, azure-validate, azure-ai, azure-kusto, azure-storage, azure-messaging, azure-cloud-migrate, azure-compute, azure-quotas, azure-resource-visualizer, azure-aigateway, azure-hosted-copilot-sdk, microsoft-foundry, entra-app-registration, appinsights-instrumentation

These can be added on-demand if squad work requires them.

### Azure MCP Server Status

**Not installed.** The Azure Skills Plugin includes the Azure MCP Server (200+ tools across 40+ Azure services). This requires:
- Node.js 18+ (already available)
- Azure CLI `az` (needs verification)
- Azure Developer CLI `azd` (not verified)
- Azure subscription access (available for team)

**Recommendation:** Defer full plugin installation until squad has a concrete Azure deployment workflow. Current skill files provide workflow guidance that can be followed manually or with existing Az CLI commands.

### Next Steps

1. **Evaluate Usage:** Track which Azure skills squad members reference during actual work
2. **Consider Full Plugin:** If Azure work becomes frequent (multiple tasks per sprint), install the full plugin for Azure MCP Server access
3. **Expand Skill Library:** Add additional skills on-demand based on team needs

### Files Modified

- Created: `.squad/skills/azure/azure-diagnostics.md`
- Created: `.squad/skills/azure/azure-rbac.md`
- Created: `.squad/skills/azure/azure-compliance.md`
- Created: `.squad/skills/azure/azure-cost-optimization.md`
- Created: `.squad/skills/azure/azure-resource-lookup.md`
- Created: `.squad/skills/azure/azure-deploy.md`
- Created: `.squad/skills/azure/README.md`
- Updated: `.squad/research/azure-skills-plugin-research.md` (this section)
