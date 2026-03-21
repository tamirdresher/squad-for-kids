# Decision: Aspire + Squad Integration via MCP

**Date:** 2026-03-22  
**Author:** Troi (Blogger & Voice Writer)  
**Status:** Published (PR #50 in blog repo)  
**Related:** Blog post "Aspire + Squad = ❤️"

## Context

Tamir works on .NET Aspire at Microsoft (infrastructure platform team) and runs Squad autonomously. The insight: both are orchestrators — Aspire for distributed apps, Squad for development teams — and they connect via Aspire's MCP server.

## Decision

Wrote a standalone blog post (not part of Scaling AI series) showing how Aspire and Squad complement each other through MCP integration.

## Key Points

**The Love Story:**
- Aspire orchestrates your distributed application (services, databases, caches, health checks)
- Squad orchestrates your development team (AI agents that write code, review PRs, monitor work)
- MCP bridge: Aspire's MCP server exposes app state to AI agents programmatically
- Together: Aspire shows what's wrong, Squad diagnoses and fixes it

**Real Example (from the post):**
- Friday afternoon: API service showing "Unhealthy" in Aspire Dashboard
- Ralph (monitor agent) queried Aspire MCP server for service health status
- Found failing health check: `/health/ready` returning 503
- Pulled logs, identified root cause: PostgreSQL connection pool exhausted
- Opened sub-issue for Data: "Increase max pool size in connection string config"
- Full diagnosis without human intervention

**What I'm Building:**
- Auto-recovery workflows (when Aspire reports crash, Ralph triggers recovery script)
- Chaos engineering (B'Elanna kills a service via MCP, monitors recovery)
- Cost optimization (Seven tracks resource usage, audits over-provisioning)
- Continuous learning (squad logs every diagnosis to build runbooks)

## Voice Patterns

- Opening: "I didn't expect my day job and side project to be a perfect match"
- Story-driven: Friday debugging session → realization → full workflow
- First-person throughout
- Genuine humor: "Two orchestrators. One codebase. Zero conflicts."
- Honest reflection: "not production-ready, but the direction is right"
- Technical depth wrapped in narrative

## SVG Diagrams

1. **hero.svg** — Aspire logo + Squad logo with heart and "MCP Bridge" label
2. **architecture.svg** — Full flow: Aspire Dashboard → MCP Server → Squad agents → GitHub Issues → Code changes → Aspire redeploys

## Publishing

- Branch: `posts/aspire-squad-love`
- Commit: e1a72c3
- PR: https://github.com/tamirdresher/tamirdresher.github.io/pull/50
- Status: Ready for review and merge

## Learnings

- Standalone posts work well when they tell a complete story with a clear insight
- "Two things you didn't know were related" structure is compelling
- Real examples are critical — showed MCP integration in practice, not theory
- Aspire MCP server is the bridge that makes autonomous monitoring and response possible
- This could be Part 8 of the scaling series if Tamir wants to extend it, but works perfectly as standalone

## Next Steps

- Tamir reviews PR #50
- If approved, merge to master (Jekyll builds and publishes automatically)
- Consider follow-up post on specific MCP integration patterns (how to query Aspire from Squad agents)
