# Decision: Dev Box Creation Strategy — Issue #103

**Date:** 2026-03-09  
**Author:** B'Elanna (Infrastructure Expert)  
**Context:** Issue #103 - Create Dev Box and share details  
**Status:** For Review

## Context

Tamir requested creation of a Dev Box with details shared via Teams webhook. Investigation revealed complete Dev Box infrastructure already exists in the repository from previous issues (#35, #63, #65), but Azure CLI extension installation is blocked by pip error.

## Decision

**Recommend three-path strategy for Dev Box provisioning:**

1. **Immediate Path**: Azure Portal (https://devportal.microsoft.com)
   - Manual creation, fastest time to result
   - No dependencies on CLI or extension
   - User can document configuration for later automation

2. **Short-Term Path**: Fix Azure CLI extension, enable scripts
   - Resolve pip installation issue
   - Enable `clone-devbox.ps1` for automated cloning
   - Unlocks natural language Squad skill

3. **Long-Term Path**: Full automation with CI/CD
   - Ephemeral Dev Boxes on PR creation
   - Auto-hibernation schedules
   - Cost optimization

## Rationale

- **Portal is production-ready**: No blockers, works immediately
- **Scripts are tested**: All automation code exists and is well-documented
- **Extension is solvable**: Installation issue has multiple workarounds (upgrade pip, manual wheel)
- **Infrastructure investment preserved**: Don't let extension issue block value from existing work

## Implications

### For Tamir
- Can create Dev Box today via portal
- Should document configuration once created
- Can unlock automation by fixing extension (15-30 min effort)

### For Squad
- Dev Box provisioning is a solved problem (scripts exist)
- Natural language provisioning available once extension works
- Infrastructure code is production-ready and reusable

### For Future Issues
- Dev Box creation is now a 5-minute task (portal) or natural language request (Squad)
- Clone script enables rapid environment replication
- MCP server enables programmatic access from AI agents

## Alternatives Considered

1. **Wait for extension fix before creating Dev Box**
   - Rejected: Blocks immediate value, portal is available
   - Portal creation doesn't prevent later automation

2. **Create Dev Box manually via REST API**
   - Rejected: Overcomplicates when portal and scripts exist
   - Scripts already have REST fallback if needed

3. **Use third-party DevBox tools**
   - Rejected: Microsoft's official tools (CLI, MCP server) are the right choice
   - Repository already invested in this tooling

## Follow-Up Actions

1. **Tamir**: Create Dev Box via portal, document configuration
2. **B'Elanna**: Update decision log if extension fix pattern emerges
3. **Squad**: Reuse this pattern for future infrastructure tooling blockers

## References

- **Setup Guide**: `docs/devbox-setup-guide.md`
- **Provisioning Scripts**: `devbox-provisioning/scripts/`
- **Squad Skill**: `.squad/skills/devbox-provisioning/SKILL.md`
- **Teams Notification**: Sent via webhook (2026-03-09)
- **PR**: #219
- **Issue**: #103
