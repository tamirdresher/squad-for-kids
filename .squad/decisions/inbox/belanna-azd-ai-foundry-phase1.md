# Decision: Phase 1 Azure AI Foundry Infrastructure

**Date:** 2026-03-23  
**Author:** B'Elanna (Infrastructure Expert)  
**Issue:** #986  
**Status:** Implemented — PR pending

---

## What Was Decided

Created Phase 1 infrastructure scaffolding for Azure AI Foundry cloud-resident agents.

## Resources Provisioned (via Bicep)

| Resource | Name Pattern | Reason |
|----------|-------------|--------|
| Log Analytics Workspace | `squad-logs-ai-<env>-<suffix>` | Observability |
| Storage Account | `squadaistor<suffix>` (max 24 chars) | Required by AI Hub |
| Key Vault | `squad-kv-ai-<env>-<suffix>` | Required by AI Hub |
| Application Insights | `squad-appinsights-ai-<env>-<suffix>` | Agent run tracing |
| Azure AI Services (OpenAI) | `squad-ai-services-<env>-<suffix>` | Model endpoint |
| Azure AI Foundry Hub | `squad-ai-hub-<env>-<suffix>` | Hub for all Squad agents |
| Azure AI Foundry Project | `squad-ai-project-<env>-<suffix>` | Scoped project for Squad |

## Location

All files at: `infrastructure/azd-ai-agent/`

## Key Constraints Applied

- **Consumption-based tiers only** — `Standard_LRS`, `S0 AI Services`, `GlobalStandard` model SKU
- **No private endpoints in Phase 1** — public access enabled, tighten in Phase 3
- **RBAC authorization on KV** (not access policies) — consistent with modern Azure patterns
- **Soft delete: 7 days** (minimum) — low cost, still protected
- **Model: gpt-4o, capacity: 10K TPM** — sufficient for Seven's research workload

## Windows Compatibility Risk

`azd ai agent run` may not work on Windows (blog examples were Linux/macOS).  
**Decision:** GitHub Actions bridge (Phase 2, ubuntu-latest) is the safe path. Local Windows invoke still needs validation before committing to it.

## Next Steps

- Data: implement Phase 2 GitHub Actions bridge (`.github/workflows/squad-cloud-invoke.yml`)
- B'Elanna: validate `azd provision` against actual Azure subscription once PR merges
- B'Elanna: test Windows `azd ai agent invoke` compatibility after `azd extension add azure.ai.agents`
