# Decision: DevBox Provisioning Phase 2 Architecture

**Date:** 2026-03-07  
**Author:** B'Elanna (Infrastructure Expert)  
**Issue:** #63  
**PR:** #64  

## Context

Phase 2 of DevBox provisioning automation adds natural language interpretation on top of Phase 1 Bicep templates and PowerShell scripts. Goal is to enable non-technical users to provision DevBoxes with phrases like "Create 3 devboxes like mine."

## Decision

Implemented a Squad skill at `.squad/skills/devbox-provisioning/SKILL.md` that:

1. **Natural Language Mapping:**
   - Maps common phrases to Phase 1 script invocations
   - Single DevBox: `provision.ps1` or `clone-devbox.ps1`
   - Bulk: Loop with name generation
   - Discovery: Direct Azure CLI queries

2. **Validation-First Approach:**
   - Check auth, extension, permissions BEFORE calling scripts
   - Validate naming, uniqueness, quota constraints
   - 7 documented error patterns with remediation guidance

3. **Bulk Provisioning Script:**
   - New `bulk-provision.ps1` for team environments
   - Parallel execution (default, 5 concurrent) for speed
   - Sequential mode available for quota-constrained scenarios
   - Job-based concurrency with batch coordination

4. **Error Interpretation Layer:**
   - Translates Azure CLI errors to human-actionable messages
   - No raw error exposure to end users
   - Specific remediation steps for each failure mode

## Rationale

- **Why Squad Skill?** Abstracts Azure CLI complexity from users. Squad coordinator handles interpretation, not users.
- **Why Validation First?** Fail fast before expensive provisioning operations. Better UX.
- **Why Parallel Bulk?** Team provisioning (5-10 DevBoxes) is common use case. Sequential would take hours.
- **Why Job-Based Concurrency?** PowerShell `Start-Job` is native, no external dependencies. Clean progress tracking.

## Alternatives Considered

1. **Direct Azure CLI in skill:** Rejected — exposes implementation details, violates abstraction
2. **Sequential-only bulk:** Rejected — too slow for team scenarios (30+ min per DevBox)
3. **Unlimited parallelism:** Rejected — could exceed Azure quota, cause failures mid-batch
4. **Custom MCP server:** Deferred to Phase 3 — overkill for current scope

## Implications

- Users can now provision DevBoxes via natural language without Azure CLI knowledge
- Team leads can bulk-provision environments for sprints/projects
- Squad coordinator gains new capability domain (infrastructure provisioning)
- Phase 3 can layer MCP server integration for real-time status

## Open Questions

- **Quota monitoring:** Should skill proactively check quota before bulk provisioning? (Currently relies on graceful failure)
- **Naming collision resolution:** Auto-append timestamp vs. prompt user? (Currently errors on conflict)
- **Phase 3 timeline:** When will `@microsoft/devbox-mcp` be available?

---

**Status:** Implemented  
**Next Steps:** Phase 3 planning — MCP integration, advanced templating, cost optimization
