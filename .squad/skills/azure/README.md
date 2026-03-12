# Azure Skills — Integrated from Microsoft Azure Skills Plugin

**Source:** https://github.com/microsoft/azure-skills  
**Integration Date:** 2026-03-11  
**Integrated By:** B'Elanna (Infrastructure Expert)  
**Issue:** #343

---

## About These Skills

These skills are **direct copies** from Microsoft's Azure Skills Plugin. They provide workflow guidance for common Azure operations without requiring the full plugin installation. Each skill is structured to work standalone with our existing MCP setup.

---

## Available Skills (6 Priority Skills)

### 1. **azure-diagnostics** — Production Troubleshooting
- **When to use:** Debug production issues, analyze logs, troubleshoot Container Apps/Function Apps
- **Covers:** KQL queries, health checks, image pull failures, cold starts, health probes
- **Who benefits:** B'Elanna (Infrastructure), Worf (Security), Picard (Incident Manager)

### 2. **azure-rbac** — Role-Based Access Control
- **When to use:** Permission management, role assignments, access control audits
- **Covers:** RBAC best practices, least-privilege principles, identity management
- **Who benefits:** Worf (Security), Picard (Lead)

### 3. **azure-compliance** — Compliance & Security Posture
- **When to use:** Compliance checks, audit configurations, policy validation
- **Covers:** Azure Policy, security baselines, regulatory compliance
- **Who benefits:** Worf (Security)

### 4. **azure-cost-optimization** — Cost Management
- **When to use:** Find waste, generate savings recommendations, budget reviews
- **Covers:** Resource optimization, cost analysis, right-sizing
- **Who benefits:** Picard (Lead), B'Elanna (Infrastructure)

### 5. **azure-resource-lookup** — Resource Discovery
- **When to use:** Search and discover Azure resources across subscriptions
- **Covers:** Resource graph queries, cross-subscription search
- **Who benefits:** All squad members

### 6. **azure-deploy** — Deployment Orchestration
- **When to use:** Deploy applications to Azure via azd (Azure Developer CLI)
- **Covers:** Pre-flight checks, deployment pipelines, rollback procedures
- **Who benefits:** B'Elanna (Infrastructure)

---

## How to Use

### Option 1: Direct Reference (Current Setup)
Squad members can reference these skill files directly when working on Azure-related tasks. Skills are markdown-based and provide step-by-step guidance.

### Option 2: Install Full Plugin (Future Enhancement)
For access to all 21 skills + Azure MCP Server (200+ tools):

```bash
gh copilot-cli /plugin install azure@azure-skills
```

**Note:** Plugin installation requires Azure CLI (`az`) and Azure Developer CLI (`azd`) installed and authenticated.

---

## Azure MCP Server Configuration

The Azure Skills Plugin uses **Azure MCP Server** for execution. To enable it, add to `.copilot/mcp-config.json`:

```json
{
  "mcpServers": {
    "azure-mcp": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@azure/mcp"],
      "env": {
        "AZURE_SUBSCRIPTION_ID": "${AZURE_SUBSCRIPTION_ID}"
      }
    }
  }
}
```

**Status:** Not currently configured. Azure MCP Server provides 200+ tools across 40+ Azure services. Consider enabling if Azure work becomes frequent.

---

## Skills Not Yet Integrated

The following skills exist in the Azure Skills Plugin but are not yet copied here:

- **azure-prepare** — Analyze projects, generate Dockerfiles, infrastructure code
- **azure-validate** — Pre-flight checks before deployment
- **azure-compute** — Compute service selection and sizing
- **azure-storage** — Storage account guidance
- **azure-kusto** — Azure Data Explorer queries
- **azure-messaging** — Service Bus, Event Grid, Event Hubs
- **azure-cloud-migrate** — Migration assessment
- **azure-ai** — Azure AI services (OpenAI, Cognitive Services)
- **azure-quotas** — Quota limits and requests
- **azure-resource-visualizer** — Visualize resource relationships
- **entra-app-registration** — Entra ID app registration
- **appinsights-instrumentation** — Application Insights telemetry
- Plus 3 more...

To add more skills, use:
```powershell
gh api "/repos/microsoft/azure-skills/contents/.github/plugins/azure-skills/skills/SKILL_NAME" -q '.[] | select(.name | endswith(".md")) | .download_url'
```

---

## Maintenance

These skills are maintained by Microsoft in the upstream repo. When updating:

1. Check https://github.com/microsoft/azure-skills for new versions
2. Download updated skills via gh api or git clone
3. Review changes for compatibility with our squad setup
4. Update this README with integration notes

---

## Related

- **Issue #343:** Research and integration task
- **Research Doc:** `.squad/research/azure-skills-plugin-research.md` (by Seven)
- **Decision:** Not yet formalized — evaluate usage patterns before adopting full plugin

---

## References

- Blog post: https://devblogs.microsoft.com/all-things-azure/announcing-the-azure-skills-plugin
- GitHub repo: https://github.com/microsoft/azure-skills
- Azure MCP Server: https://learn.microsoft.com/azure/developer/azure-mcp-server/
