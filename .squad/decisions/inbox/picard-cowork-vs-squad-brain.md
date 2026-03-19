# Decision: Copilot Cowork vs. Squad Brain Extension

**Date:** 2026-03-18  
**Author:** Picard (Lead)  
**Issue:** #964  
**Status:** RECOMMENDATION DELIVERED

## What Was Evaluated

Microsoft Copilot Cowork (https://aka.ms/cowork) — announced March 9, 2026. An AI agent layer for M365 productivity automation (calendar, documents, meeting prep, company research). Built on Work IQ + Microsoft Graph + Claude models. Currently Research Preview; Frontier program rollout late March 2026. Priced at $99/user/month on the E7 tier.

## Decision

**MONITOR — Do Not Adopt Yet. Potentially Complement Later if MCP ships.**

## Rationale

The squad brain extension (session_store + decisions.md + per-agent history + 15+ specialists + Ralph loop) is more capable than Cowork for our actual use cases in four key dimensions:

1. **Persistent cross-session memory** — session_store SQLite with FTS5 across ALL past sessions is qualitatively different from Cowork's per-session Microsoft Graph context.
2. **Domain specialization** — 15+ experts vs. 1 generalist. Each squad agent has domain history, accountability, and skills.
3. **Developer context** — Cowork has zero GitHub/ADO/code integration. Squad lives there.
4. **Autonomy** — Ralph runs continuously without user checkpoints. Cowork requires approval gates.

## When to Revisit

- When Cowork reaches general availability (late March 2026)
- If Cowork ships an MCP endpoint — could delegate M365-specific document/calendar tasks to it as a tool call
- If complex Excel/PPT generation from M365 sources becomes a frequent squad need

## Impact

- No changes to current architecture
- Watch Frontier program rollout
- If MCP ships: evaluate adding as a tool for Kes (calendar) or Seven (research docs)
