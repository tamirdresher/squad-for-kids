# Decision: `azd ai agent run invoke` — Squad Integration Recommendation

**Date:** 2026-05-30
**Author:** Picard
**Status:** PROPOSED
**Issue:** #986

## Summary

`azd ai agent run invoke` (azure.ai.agents extension v0.1.14-preview) is a process
manager + message bus for AI agent workflows. It offers:

- Managed process lifecycle (start/restart/crash handling)
- Persistent multi-turn conversation threads
- Unified local/cloud invocation via same CLI
- Per-agent dependency isolation

## Decision

**Adopt in three phases:**

1. **Phase 1 (now):** Use `azd ai agent run` to replace the current `agency.exe` + Ralph
   circuit-breaker watchdog pattern. Eliminates orphaned process problems.

2. **Phase 2 (next):** Wire GitHub issue IDs to `azd` thread IDs for per-issue
   conversation continuity across agent invocations.

3. **Phase 3 (later):** Deploy compute-heavy agents (Picard, Seven) to Azure AI Foundry;
   route via `azd ai agent invoke` without code changes.

## What NOT to change yet

- Keep Copilot CLI for GitHub-specific operations
- Don't deploy all agents to cloud until Phase 1 is validated on Windows

## Open Questions (blocking Phase 1)

1. Windows DevBox compatibility — blog examples show Linux/macOS
2. External thread ID scoping (can we pass `--thread-id issue-986`?)
3. Non-Foundry runtime support for local Copilot CLI agents

## Action Items

- [ ] Belanna: validate `azd ai agent run` on Windows DevBox
- [ ] Ralph: identify all orphaned-process kill paths that could be retired
- [ ] Picard: design agent manifest format for Squad agent registry
