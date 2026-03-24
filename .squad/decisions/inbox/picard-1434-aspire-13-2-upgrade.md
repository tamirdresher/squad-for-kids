# Decision: Aspire 13.2 Upgrade Plan

**Date:** 2026-03-24
**Author:** Picard
**For:** All agents, Tamir
**Issue:** #1434

## Decision

Adopt Aspire 13.2. The upgrade path is straightforward since Aspire is **not yet in production use** in tamresearch1 (no csproj files use Aspire SDK). The primary action is **installing the Aspire CLI 13.2 on all dev machines** and preparing the aspire-kind work (issues #1423-1425) to target 13.2 from the start.

## Key 13.2 Changes That Affect Active Work

1. **aspire-kind / KindClusterResource (#1423-1425)**: The `BeforeResourceStartedEvent` now ONLY fires when actually starting (breaking change). The pattern Seven documented is still correct but event firing behavior changed — verify the lifecycle hook fires as expected.

2. **Service discovery env vars**: Now use scheme (`https`) instead of endpoint name. Any future downstream wiring should use scheme-based patterns.

3. **CLI `aspire agent init`** replaces `aspire mcp` — use when bootstrapping agent config.

4. **`aspire.config.json`** replaces `.aspire/settings.json` + `apphost.run.json` — write new config here.

## No Breaking Changes for Current Codebase

Current tamresearch1 has no Aspire-dependent code. All breaking changes are aspirational for new work.
