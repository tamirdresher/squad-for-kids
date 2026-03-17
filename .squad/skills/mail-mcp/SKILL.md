# Mail MCP Server - Research & Recommendation

**Status:** ✅ Available in Agency CLI  
**Recommendation:** ✅ ADOPT - Add to MCP config for enhanced email capabilities  
**Research Date:** 2026-03-16  

---

## Executive Summary

The **Work IQ Mail MCP** is a Microsoft-native email server built into the Agency CLI that provides comprehensive email automation capabilities for Microsoft 365/Outlook mailboxes. It's **officially available** via `agency mcp mail`, requires **zero additional installation**, and significantly enhances our current email tooling.

---

## What It Provides

### Core Email Operations

| Operation | Capability |
|-----------|-----------|
| **Send Email** | Send messages with To/CC/BCC, HTML/text support |
| **Create Drafts** | Compose emails, save as drafts, send later |
| **Reply/Reply-All** | Respond to messages with HTML formatting |
| **Search Messages** | KQL-style queries across subject, body, attachments |
| **Get/Delete Messages** | Retrieve or remove emails by ID |
| **List Sent Items** | Retrieve sent messages with filtering |
| **Update Messages** | Modify subject, body, categories, importance |

### Technical Details

- **Authentication:** OAuth via Microsoft Entra ID (uses signed-in user context)
- **API Backend:** Microsoft Graph Mail API  
- **Search:** Microsoft Graph Search API with KQL support
- **HTML Support:** Full HTML email composition and rendering
- **Concurrency:** ETag support for safe updates
- **Draft Management:** Create, update, send drafts separately

---

## Comparison with Current Tools

| Tool | Read Emails | Send Emails | Search | Microsoft 365 | Best For |
|------|:-----------:|:-----------:|:------:|:-------------:|----------|
| **Outlook COM** | ✅ | ✅ | ✅ | ✅ | Windows only, full mailbox control |
| **WorkIQ** | ✅ | ❌ | ✅ | ✅ | Read-only queries, intelligent search |
| **IMAP Scripts** | ✅ | ✅ | ⚠️ | ❌ | Personal Gmail only |
| **Mail MCP** | ✅ | ✅ | ✅ | ✅ | **Cross-platform, enterprise, native Graph API** |

### Why Mail MCP is Better

1. **Platform-agnostic:** Works on Windows, Mac, Linux
2. **Enterprise-ready:** Microsoft Graph backend, OAuth, audit trails
3. **Official:** Part of Microsoft Agent365 ecosystem
4. **Integrated:** Built into Agency CLI, no extra installation
5. **Powerful Search:** KQL support across attachments
6. **Standards-based:** Model Context Protocol (MCP) standard
7. **Draft Support:** Can compose and schedule emails separately

---

## Available Tools in Mail MCP

```
✓ mcp_MailTools_graph_mail_createMessage      Create draft (HTML/text)
✓ mcp_MailTools_graph_mail_sendMail           Send email with attachments
✓ mcp_MailTools_graph_mail_searchMessages     Search with KQL queries
✓ mcp_MailTools_graph_mail_reply              Reply with HTML support
✓ mcp_MailTools_graph_mail_replyAll           Reply-all to message
✓ mcp_MailTools_graph_mail_getMessage         Get message by ID
✓ mcp_MailTools_graph_mail_deleteMessage      Delete message
✓ mcp_MailTools_graph_mail_listSent           List sent items with filters
✓ mcp_MailTools_graph_mail_sendDraft          Send existing draft
✓ mcp_MailTools_graph_mail_updateMessage      Update message properties
```

---

## How to Add It

### MCP Config Update

Add this to `$USERPROFILE\.copilot\mcp-config.json`:

```json
{
  "mcpServers": {
    "mail": {
      "type": "local",
      "command": "agency",
      "args": ["mcp", "mail"],
      "tools": ["*"]
    }
  }
}
```

### Testing After Setup

```powershell
# Verify the MCP loads
$env:USERPROFILE\.copilot\mcp-config.json

# Test via Copilot CLI
copilot -skills mail
```

---

## Use Cases in Squad Context

1. **Automated Email Responses:** Handle common inquiries from issues/PRs
2. **Inbox Automation:** Search and organize emails by sender/keyword
3. **Report Distribution:** Generate and email summaries automatically
4. **Meeting Scheduling:** Read meeting requests and send confirmations
5. **Team Notifications:** Alert team to important emails
6. **Email-to-Issue Triage:** Forward emails to GitHub issues/ADO work items

---

## Security & Compliance

- ✅ **OAuth-based:** All operations use signed-in user credentials via Entra ID
- ✅ **No Credentials Stored:** Uses existing M365 session
- ✅ **Audit Trail:** All actions logged in Microsoft 365 audit logs
- ✅ **Granular Permissions:** Follows Microsoft Graph Mail API scopes
- ✅ **Preview Status:** Official but still in preview (stable, subject to minor changes)

---

## Limitations & Notes

- **Preview Feature:** Subject to supplemental terms of use
- **Microsoft 365 Only:** Requires M365 subscription (no Gmail, iCloud support)
- **Auth Required:** Must be authenticated user; no shared mailbox delegation yet
- **Rate Limits:** Subject to Microsoft Graph API throttling (standard enterprise limits)

---

## References

- [Microsoft Learn - Work IQ Mail Reference](https://learn.microsoft.com/en-us/microsoft-agent-365/mcp-server-reference/mail)
- [Agency CLI Documentation](https://dev.azure.com/)
- [Model Context Protocol (MCP) Spec](https://modelcontextprotocol.io/)

---

## Recommendation

**✅ YES, ADOPT THIS**

**Reasoning:**
1. **Zero friction:** Already in Agency CLI, just needs config entry
2. **Bridges gap:** Replaces platform-specific Outlook COM automation
3. **Enterprise standard:** Official Microsoft Graph backend
4. **Squad benefit:** Enables email-driven automations in squad workflows
5. **Minimal risk:** Leverages existing M365 auth

**Next Steps:**
1. Add mail MCP to `.copilot/mcp-config.json`
2. Test with simple task (send test email, search mailbox)
3. Document in squad skills inventory
4. Create email automation use-case recipes

---

**Researched by:** Seven (Research & Docs)  
**Recommended for:** All squad members with M365 access
