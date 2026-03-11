# Decision: Azure Skills Integration Pattern

**Date:** 2026-03-11  
**Author:** B'Elanna (Infrastructure Expert)  
**Issue:** #343  
**Status:** Proposed

---

## Decision

**Use staged adoption pattern for external skill plugins: copy skill markdown files first, defer full plugin installation until usage is validated.**

---

## Context

The Azure Skills Plugin provides 21 Azure-specific skills and an Azure MCP Server with 200+ tools. Seven's research (issue #343) recommended integration. Question: Should we install the full plugin immediately or take a staged approach?

---

## Recommendation

**Adopt the staged integration pattern:**

### Phase 1 (Current): Skill Files Only
- Copy priority skill markdown files to `.squad/skills/azure/`
- Provide workflow guidance without infrastructure overhead
- Squad members reference skills and use existing Az CLI commands
- Track which skills are actually used in practice

### Phase 2 (Future): Full Plugin + MCP Server
- Install full plugin if Azure work becomes frequent (multiple tasks per sprint)
- Enable Azure MCP Server (200+ tools) via `.copilot/mcp-config.json`
- Requires: Azure CLI `az` + Azure Developer CLI `azd` installed and authenticated

### Phase 3 (Long-term): Customization
- Fork high-value skills with squad-specific context
- Integrate with `.squad/decisions.md` conventions
- Add squad routing logic

---

## Rationale

1. **Reduce Infrastructure Overhead**: Full plugin requires `azd` installation, Azure subscription auth, MCP server configuration. Defer until value is proven.

2. **Validate Usage First**: We don't yet know how much Azure work the squad does. Track skill references before investing in full setup.

3. **Skills Are Portable Documentation**: Markdown files provide complete workflow guidance. MCP tools are optional execution layer.

4. **Staged Risk**: Installing full plugin now adds:
   - MCP server to maintain and troubleshoot
   - Auth flows to manage (Azure subscription, service principals)
   - Tool namespace collision risk (200+ new tools)

5. **Precedent**: This pattern matches how we handle other integrations — prove value with minimal setup, then expand.

---

## Skills Integrated (Phase 1)

**6 priority skills copied:**
- `azure-diagnostics` — Production troubleshooting (Infrastructure + Security)
- `azure-rbac` — Permission management (Security)
- `azure-compliance` — Compliance checks (Security)
- `azure-cost-optimization` — Cost management (Lead + Infrastructure)
- `azure-resource-lookup` — Resource discovery (All squad)
- `azure-deploy` — Deployment orchestration (Infrastructure)

**15 skills deferred:**
- azure-prepare, azure-validate, azure-ai, azure-kusto, azure-storage, azure-messaging, azure-cloud-migrate, azure-compute, azure-quotas, azure-resource-visualizer, azure-aigateway, azure-hosted-copilot-sdk, microsoft-foundry, entra-app-registration, appinsights-instrumentation

Can be added on-demand if squad work requires them.

---

## Impact

### ✅ Benefits
- **Zero infrastructure overhead** — no new MCP servers to configure
- **Immediate value** — squad can reference skills now
- **Usage validation** — learn which skills matter before investing in full plugin
- **Flexibility** — can still install full plugin later without losing skill files

### ⚠️ Trade-offs
- **Manual execution** — squad must translate skill guidance into Az CLI commands
- **No MCP automation** — 200+ Azure tools unavailable until Phase 2
- **Limited depth** — some skills reference MCP tools that won't work without full plugin

### 🔧 Mitigation
- Document exact Az CLI commands for common skill workflows
- Add "How to Use" section in `.squad/skills/azure/README.md`
- Track skill references in squad history — if frequent, trigger Phase 2

---

## Success Metrics

**Trigger for Phase 2 (full plugin installation):**
- Squad references Azure skills in 3+ issues per sprint (frequent usage)
- OR squad has recurring Azure deployment workflows (not one-off tasks)
- OR squad explicitly requests Azure MCP Server tools

**Trigger for Phase 3 (skill customization):**
- Squad consistently references 2-3 specific skills (high-value subset identified)
- Squad has established Azure conventions worth encoding in skills
- Skills need integration with `.squad/decisions.md` or `.squad/routing.md`

---

## Related Decisions

- **Decision 1**: Gap Analysis When Repository Access Blocked (staged investigation pattern)
- **Decision 14**: Multi-Org ADO MCP Setup (MCP configuration precedent)

---

## References

- Research: `.squad/research/azure-skills-plugin-research.md` (by Seven)
- Skills directory: `.squad/skills/azure/`
- Upstream repo: https://github.com/microsoft/azure-skills
- Azure MCP docs: https://learn.microsoft.com/azure/developer/azure-mcp-server/

---

## Approval

**Status:** Proposed — waiting for team feedback

If approved:
- Merge to `.squad/decisions.md` as Decision [next number]
- Document staged integration pattern as reusable for future plugins
- Add to squad onboarding docs as "how we evaluate external plugins"
