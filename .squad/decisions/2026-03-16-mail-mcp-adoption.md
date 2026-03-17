# Decision: Adopt Mail MCP for Email Automation

**Date:** 2026-03-16  
**Decision Status:** ✅ APPROVED FOR ADOPTION  
**Raised By:** Seven (Research & Docs)  
**Impact:** High — Enables new email automation capabilities across squad  

---

## Context

Tamir requested research on `agency mcp mail` to understand what it provides and whether we should use it.

**Finding:** The Mail MCP is a production-ready, Microsoft-native email server built into the Agency CLI. It's already installed and requires only a config entry to activate.

---

## The Decision

**Adopt Work IQ Mail MCP (agency mcp mail) for email automation in squad workflows.**

### Rationale

| Factor | Assessment |
|--------|-----------|
| **Availability** | ✅ Built into Agency CLI, zero installation |
| **Capability** | ✅ Comprehensive: send, read, search, draft, reply |
| **Platform** | ✅ Cross-platform (Windows, Mac, Linux) |
| **Auth** | ✅ OAuth via Entra ID, secure, no credential storage |
| **Enterprise** | ✅ Microsoft Graph backend, audit logs, compliance-ready |
| **Risk** | ✅ Low (preview status is stable; it's an official Microsoft tool) |
| **ROI** | ✅ High (replaces custom Outlook COM automation, enables new workflows) |

---

## What Changes

### Current State
- Outlook COM automation (Windows-only, script-based)
- WorkIQ (read-only email queries)
- Personal IMAP for Gmail

### After Adoption
- **Mail MCP** becomes primary email tool for agent-driven automation
- Outlook COM scripts can be refactored/retired
- Cross-platform, enterprise-standard email operations
- New use cases: inbox automation, email triage, report distribution

---

## Implementation Plan

### Phase 1: Configuration (Immediate)
1. Add mail MCP to `.copilot/mcp-config.json`
2. Verify it loads via `copilot -skills mail`
3. Test basic operations (send email, search, reply)

### Phase 2: Documentation (Short-term)
1. Create squad skill documentation (✅ Done: `.squad/skills/mail-mcp/SKILL.md`)
2. Add to squad skills inventory
3. Document email automation patterns/recipes

### Phase 3: Adoption (Medium-term)
1. Migrate relevant Outlook COM scripts to Mail MCP
2. Create email-driven automation workflows
3. Train squad on capabilities

---

## Action Items

- [ ] **Config Team:** Add mail MCP to MCP config file
- [ ] **Testing:** Run basic email operations to verify functionality
- [ ] **Documentation:** Link skill docs from squad knowledge base
- [ ] **Adoption:** Create first use-case recipe (e.g., inbox automation)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Preview status changes | Monitor Microsoft Learn for updates; Entra ID auth is stable |
| M365-only limitation | Document; no impact if squad stays on Microsoft 365 |
| Rate limiting | Use sensible retry logic; standard enterprise throttling |
| Auth complexity | Leverages existing M365 session; transparent to users |

---

## Success Criteria

✅ Mail MCP successfully added to MCP config  
✅ Test email send/search/reply operations work  
✅ Documentation accessible to squad  
✅ First email automation workflow uses Mail MCP  

---

## References

- [Skill Documentation](./.squad/skills/mail-mcp/SKILL.md)
- [Microsoft Learn - Work IQ Mail](https://learn.microsoft.com/en-us/microsoft-agent-365/mcp-server-reference/mail)
- [Model Context Protocol](https://modelcontextprotocol.io/)

---

**Decision Owner:** Picard (Lead) — recommend for approval  
**Implements:** Seven (Research & Docs)
