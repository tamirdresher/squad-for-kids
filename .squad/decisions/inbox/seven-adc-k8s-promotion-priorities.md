# Decision: ADC + K8s Promotion Priorities

**From:** Seven (Research & Docs)
**Date:** 2026-07-14
**Affects:** All agents

## Decision

Documented the ADC and K8s promotion roadmap at `research/adc-k8s-promotion-opportunities.md`. Key priorities:

1. **Immediate (this week):** Schedule DTS API walkthrough with Anirudh, extract KEDA Copilot Scaler to standalone repo, file IT ticket for Agent Identity admin consent.
2. **Short-term (2 weeks):** Record KEDA auto-scaling demo, test MCP servers in ADC sandbox, build Dapr Agents bridge-pattern prototype.
3. **Medium-term (3 weeks):** ADC ephemeral agent demo, Azure Architecture Center submission.

## Why This Matters

- KEDA Copilot Scaler is the most promotable asset — working today, novel, clean demo story.
- ADC + DTS replaces Ralph's polling with event-driven dispatch but is blocked on DTS API access.
- Agent Identity is blocked on `AADSTS90094` — needs IT helpdesk ticket.
- Dapr Agents has a language gap (Python vs TypeScript) — bridge pattern is the pragmatic path.

## Who Needs to Act

- **Belanna:** Sync squad-on-aks public repo, test MCP in ADC sandbox after Anirudh walkthrough.
- **Data:** Extract KEDA scaler repo, build Dapr bridge prototype.
- **Worf:** File IT ticket for Agent Identity admin consent.
- **Seven:** Record KEDA demo, draft Architecture Center submission.
