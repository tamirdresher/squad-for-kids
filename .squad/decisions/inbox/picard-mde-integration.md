# MDE CopilotCliAssets Integration Decision

**Date:** 2026-03-11  
**Author:** Picard (Lead)  
**Status:** 📝 DRAFT (Pending Review)  
**Scope:** Skills & Knowledge Management

---

## Context

Tamir requested evaluation of https://dev.azure.com/microsoft/DefenderCommon/_git/MDE.ServiceModernization.CopilotCliAssets to identify useful patterns for Squad integration.

Research (documented elsewhere) identified:
1. **pr-review-orchestrator plugin** — Parallel PR review with specialized sub-agents
2. **reflect skill** — Learning capture system with HIGH/MED/LOW confidence tracking
3. **monthly-service-report agent** — Orchestrates monthly reports from ADO + M365 data
4. **Plugin packaging structure** — `.claude-plugin/` and `marketplace.json` patterns

Tamir's directive: "Use what you think we need"

---

## Decision

### ✅ INTEGRATED: Reflect Skill

**Adopted:** `.squad/skills/reflect/SKILL.md`

**Why:** 
- Squad already uses `history.md` (agent learnings) and `decisions.md` (team decisions)
- Reflect adds **in-flight learning capture** with confidence levels (HIGH/MED/LOW)
- Prevents repeating mistakes by documenting user corrections immediately
- Complements existing knowledge systems rather than replacing them

**Adaptations:**
- Storage paths adapted to `.squad/` structure (no Serena MCP dependency)
- Routes team-wide learnings through `.squad/decisions/inbox/` for Scribe review
- Agent-specific learnings append to `.squad/agents/{agent}/history.md`
- Preserves HIGH/MED/LOW confidence classification from original

**Original credit:** Richard Murillo (rimuri), MDE.ServiceModernization.CopilotCliAssets

---

## ❌ NOT INTEGRATED: PR Review Orchestrator

**Skipped:** pr-review-orchestrator plugin

**Why:**
- Squad already has Ralph monitoring PRs and routing to appropriate agents
- B'Elanna handles infrastructure/security reviews
- Adding parallel sub-agent orchestration would duplicate existing workflows
- Git pre-push hooks pattern could be revisited if pre-commit checks become necessary

**If reconsidered:** Could extract pre-push hook pattern if Tamir wants automated reviews before every push

---

## ❌ NOT INTEGRATED: Monthly Service Report

**Skipped:** monthly-service-report agent and supporting skills

**Why:**
- Highly specific to MDE team's reporting structure (Azure DevOps + M365 data aggregation)
- Squad doesn't have monthly reporting requirements yet
- Neelix (Communications) handles ad-hoc reporting needs currently
- Would need customization for Squad's context

**If reconsidered:** Could adapt if Tamir requests monthly team productivity reports

---

## ❌ NOT INTEGRATED: Plugin Packaging Structure

**Skipped:** `.claude-plugin/` and `marketplace.json` patterns

**Why:**
- Squad is designed for single-repo adoption, not plugin marketplace distribution
- `.squad/` structure is intentionally Git-based and simple (no plugin registry)
- Adding packaging layer would increase complexity without clear benefit
- Skills can be copied directly between squads when needed

**If reconsidered:** Revisit if Squad ecosystem grows to need centralized plugin distribution

---

## Implementation

1. ✅ Created `.squad/skills/reflect/SKILL.md` (adapted from MDE version)
2. ✅ Documented integration decision in `.squad/decisions/inbox/picard-mde-integration.md`
3. ✅ Updated Picard's history.md with learnings
4. ⏳ Pending: Comment on issue #340 with integration summary
5. ⏳ Pending: Add `status:pending-user` label to issue #340

---

## Rationale

**Integration principle:** Adopt patterns that enhance Squad's existing knowledge management without duplicating workflows or adding unnecessary complexity.

- **Reflect skill** fits this principle — adds structured learning capture to complement history.md/decisions.md
- **PR orchestrator** violates this principle — duplicates Ralph's monitoring and agent routing
- **Monthly reports** violates this principle — solves a problem Squad doesn't have yet
- **Plugin packaging** violates this principle — adds complexity without current need

---

## Consequences

### ✅ Benefits

1. **Improved learning capture** — Confidence-leveled patterns prevent repeating mistakes
2. **Structured reflection** — Clear workflow for capturing corrections, praise, and edge cases
3. **Gradual knowledge promotion** — In-flight learnings can graduate to history.md or decisions.md
4. **Attribution preserved** — Original credit to MDE team maintained

### ⚠️ Risks

1. **Adoption overhead** — Squad agents must learn to invoke reflect proactively
2. **Duplication potential** — Learnings could be captured in both reflect AND history.md
3. **Maintenance burden** — One more skill to maintain alongside existing patterns

### 🛡️ Mitigations

1. **Training needed** — Document reflect usage examples in squad conventions
2. **Clear boundaries** — Reflect is for in-flight capture; history.md is for completed work
3. **Gradual rollout** — Start with Picard/Scribe using reflect, expand to other agents if successful

---

## Related

- **Issue #340** — MDE CopilotCliAssets evaluation (trigger for this work)
- **Decision 1** — Gap analysis when blocked (demonstrates Squad's knowledge capture culture)
- **Agent history.md files** — Existing learning capture pattern that reflect complements

---

## Approval

**Propose for adoption:** Yes, merge to `.squad/decisions.md` after Tamir reviews issue #340 comment

**Alternative:** If Tamir wants PR orchestrator or monthly reports, revisit those patterns in separate issues
