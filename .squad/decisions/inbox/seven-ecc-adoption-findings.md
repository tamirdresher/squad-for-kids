# Decision: ECC Adoption Findings for Squad

**Date:** 2026-03-22
**Author:** Seven
**Status:** Draft — awaiting coordinator approval
**Ref:** Issue #1295, PR #1310

## Summary
Audited affaan-m/everything-claude-code for patterns transferable to the squad.

## Key Findings

### Adopt Immediately (Issues opened)
1. **ECC Planner Format** (issue #1311) — picard should output phased plans with file paths, dependencies, risks, success criteria
2. **ECC Code Review Standard** (issue #1312) — worf should use confidence-based (>80%), severity-tiered reviews with AI-code addendum
3. **5-Phase Orchestration Pipeline** (issue #1313) — formalize Research→Plan→Implement→Review→Verify as squad standard
4. **4-Tier Comms Classification** (issue #1315) — kes should classify: skip/info_only/meeting_info/action_required
5. **Iterative Retrieval Pattern** (issue #1317) — all agents max 3 follow-up cycles; pass WHY not just what

### Key Structural Pattern (All Agents Should Know)
From ECC: each phase agent gets ONE input file and produces ONE output file. Outputs become inputs for next phase. Never skip phases. Store intermediate outputs as files, not just in conversation.

### Not Worth Adopting
- Hook lifecycle system (Claude-specific)
- Plugin marketplace (Claude-specific)
- Context window management (Claude-specific model architecture)

## Files
- Full analysis: `research/1295-claude-code-adoption.md`
