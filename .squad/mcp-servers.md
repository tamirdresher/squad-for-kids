# Squad MCP Server Manifest

> **The authoritative answer to: "What identity do these agents run under?"**
>
> This document covers every MCP server the squad uses, the identity model, scopes per server,
> and which agents are consumers. For per-agent details, see the `## Identity & Access` section
> in each agent's charter (`.squad/agents/*/charter.md`).

---

## Current Identity Model

All agents run under **user passthrough identity** — the signed-in Copilot CLI user
(`tamirdresher_microsoft`). There are no per-agent service principals today.

**What this means in practice:**

- Every action an agent takes (create issue, send Teams message, push to git, read email)
  is attributed to the `tamirdresher_microsoft` account in all service audit logs.
- There is no audit trail distinguishing *which* agent performed an action — only that the
  human account performed it.
- Agents cannot be given different permission scopes from each other; they all share the
  same identity and its full access rights.
- Token expiry/re-auth affects all agents simultaneously (not per-agent).

**Suitable for:** Single-user and small-team development workflows where one engineer runs
the squad from their own workstation.

**Not suitable for:** Multi-user enterprise deployments requiring action-level audit,
shared CI/CD service accounts, or per-agent permission scoping.

---

## Active MCP Servers

### Summary Table

| Server | Binary / Package | Auth Model | Primary Scopes | Used By |
|--------|-----------------|-----------|----------------|---------|
| [GitHub MCP](#github-mcp) | `@modelcontextprotocol/server-github` | User OAuth (`gh` CLI token) | `repo`, `issues`, `pull_requests`, `code` | All agents |
| [Teams MCP](#teams-mcp) | Built-in Copilot CLI plugin | Entra ID SSO (user passthrough) | `Chat.ReadWrite`, `ChannelMessage.ReadWrite` | Kes, Neelix, Troi |
| [Calendar MCP](#calendar-mcp) | Built-in Copilot CLI plugin | Entra ID SSO (user passthrough) | `Calendars.ReadWrite` | Kes |
| [Mail MCP](#mail-mcp) | Built-in Copilot CLI plugin | Entra ID SSO (user passthrough) | `Mail.ReadWrite`, `Mail.Send` | Kes |
| [WorkIQ MCP](#workiq-mcp) | Built-in Copilot CLI plugin | Entra ID SSO (user passthrough) | M365 Copilot read scopes | Kes, Neelix, Guinan |
| [Azure DevOps MCP](#azure-devops-mcp) | Built-in Copilot CLI plugin | Entra ID SSO (user passthrough) | `vso.work`, `vso.build`, `vso.wiki` | Data, B'Elanna, Seven, Ralph |
| [Playwright MCP](#playwright-mcp) | `@playwright/mcp` | Local — no external auth | N/A (browser automation only) | Kes, Ralph |
| [eng.ms MCP](#engms-mcp) | Built-in Copilot CLI plugin | Entra ID SSO (read-only) | Internal docs read | Seven, Picard |
| [Aspire MCP](#aspire-mcp) | Built-in Copilot CLI plugin | Local dashboard URL | N/A (local dev only) | B'Elanna |
| [nano-banana MCP](#nano-banana-mcp) | Built-in Copilot CLI plugin | Gemini API key | Image generation | Neelix, Troi, Paris |
| [ConfigGen MCP](#configgen-mcp) | Built-in Copilot CLI plugin | Entra ID SSO (read-only) | NuGet package metadata read | Data, B'Elanna |

---

### GitHub MCP

**Package:** `@modelcontextprotocol/server-github` (or built-in Copilot CLI integration)
**Config key:** `github` in `.copilot/mcp-config.json`

**Auth model:** User OAuth token from the `gh` CLI.

```
gh auth login  →  token stored in gh credential store  →  MCP server reads via $GITHUB_TOKEN
```

> ⚠️ The GitHub MCP requires a *separate* Personal Access Token from the `gh` CLI auth.
> Generate at: `https://github.com/settings/tokens`

**Capabilities:**
- Read/write issues, pull requests, comments
- Search code across repositories
- Read file contents and directory trees
- Create commits and branches (if token has `repo` scope)
- Manage labels, milestones
- Read workflow runs and CI status
- Manage Copilot Spaces

**Scopes required:** `repo`, `read:org`, `issues`, `pull_requests`

**Used by:** All agents. Every agent that interacts with GitHub uses this server.

**Identity:** `tamirdresher_microsoft` GitHub account (EMU account).

---

### Teams MCP

**Type:** Built-in Copilot CLI plugin
**Config:** Activated by Copilot CLI Entra ID session — no separate config file needed.

**Auth model:** Entra ID SSO. Uses the same interactive session as the signed-in user.
No separate token. Sessions expire with the Copilot CLI session.

**Capabilities:**
- Send and read messages in Teams chats and channels
- Create and manage chats (1:1 and group)
- List teams and channels the user is a member of
- Search Teams messages
- Post to channels

**Scopes required:** `Chat.ReadWrite`, `ChannelMessage.ReadWrite`, `Team.ReadBasic.All`,
`Channel.ReadBasic.All`, `User.Read`

**Used by:**
- **Kes** — sends meeting notifications, coordinates via Teams
- **Neelix** — posts daily briefings and news reports to channels
- **Troi** — delivers blog drafts and content updates to Teams

**Identity:** `tamirdresher_microsoft` Entra ID account.
All Teams messages appear as sent by this user.

---

### Calendar MCP

**Type:** Built-in Copilot CLI plugin
**Config:** Activated by Entra ID session — no separate config.

**Auth model:** Entra ID SSO (same session as Teams MCP).

**Capabilities:**
- List, create, update, cancel calendar events
- Find meeting times across attendees
- Accept/decline/tentatively accept invitations
- Forward events
- Get user timezone and working hours

**Scopes required:** `Calendars.ReadWrite`, `User.Read`, `MailboxSettings.Read`

**Used by:**
- **Kes** — primary consumer. Creates and manages all calendar events.

**Identity:** `tamirdresher_microsoft` Entra ID account.
Events appear as created by / on behalf of this user.

---

### Mail MCP

**Type:** Built-in Copilot CLI plugin
**Config:** Activated by Entra ID session.

**Auth model:** Entra ID SSO.

**Capabilities:**
- Search email messages (via M365 Copilot semantic search)
- Read message details and attachments
- Create and send emails with attachments
- Reply, reply-all, forward
- Create and manage drafts
- Flag messages

**Scopes required:** `Mail.ReadWrite`, `Mail.Send`, `MailboxSettings.Read`

**Used by:**
- **Kes** — sends communications, replies to emails, manages inbox actions.

**Identity:** `tamirdresher_microsoft` Entra ID account.
All sent emails originate from this account. Recipients see this address.

> ⚠️ **High-impact operations.** Kes sending an email or reply is an irreversible action
> under the user's identity. Always confirm before sending unless operating in a well-defined
> automation context.

---

### WorkIQ MCP

**Type:** Built-in Copilot CLI plugin (Microsoft 365 Copilot integration)
**Config:** Activated by Entra ID session. EULA acceptance required on first use.

**Auth model:** Entra ID SSO. Queries Microsoft 365 Copilot with the user's identity.

**Capabilities:**
- Natural language queries across M365 data (emails, Teams, SharePoint, OneDrive, Calendar)
- Find what people said or shared
- Retrieve meeting context and follow-ups
- Search documents in SharePoint/OneDrive

**Scopes required:** M365 Copilot read scopes (managed by Copilot CLI)

**Used by:**
- **Kes** — context for communications and scheduling
- **Neelix** — activity summaries for news briefings
- **Guinan** — audience and content context from org communications

**Identity:** `tamirdresher_microsoft` Entra ID account.
Queries are executed as this user; only data accessible to this user is returned.

---

### Azure DevOps MCP

**Type:** Built-in Copilot CLI plugin
**Config:** Activated by Entra ID session.

**Auth model:** Entra ID SSO. Uses the same interactive session.

**Capabilities:**
- Read/write work items (bugs, tasks, user stories)
- List and trigger pipelines; read build logs
- Read/write wiki pages
- Search code in ADO repositories
- Manage pull requests in ADO repos
- Manage test plans and test cases
- Access Advanced Security alerts

**Scopes required:** `vso.work_write`, `vso.build`, `vso.wiki`, `vso.code`, `vso.test`

**Used by:**
- **Data** — work items, ADO code reviews, test management
- **B'Elanna** — pipeline management, build status, infrastructure work items
- **Seven** — wiki documentation
- **Ralph** — work queue monitoring, work item status updates

**Identity:** `tamirdresher_microsoft` Entra ID account.

---

### Playwright MCP

**Package:** `@playwright/mcp` (local installation)
**Config:** Launched as a local subprocess. No external auth.

**Auth model:** None for the MCP server itself. The *browser sessions* opened by Playwright
carry whatever cookies/sessions are present in the browser profile used.

**Capabilities:**
- Navigate to URLs
- Click, type, fill forms, select options
- Take screenshots
- Read page accessibility snapshots
- Handle dialogs and file uploads
- Evaluate JavaScript in page context
- Run arbitrary Playwright code snippets

**Scopes required:** Local process execution rights only.

**Used by:**
- **Kes** — web-based form filling, Teams web UI automation fallback
- **Ralph** — monitoring dashboards, reading web-based status pages

**Identity:** Local machine user (`tamirdresher_microsoft` Windows session).
Any websites visited see the browser's cookies and local storage.

---

### eng.ms MCP

**Type:** Built-in Copilot CLI plugin (Microsoft internal)
**Config:** Activated by Entra ID session.

**Auth model:** Entra ID SSO. Read-only access to Microsoft internal engineering documentation.

**Capabilities:**
- Full-text search across eng.ms documentation
- Fetch full page content from eng.ms URLs
- Resolve ServiceTree service names and IDs
- Browse service documentation hierarchy
- Retrieve TSGs (Troubleshooting Guides) and onboarding docs

**Scopes required:** Entra ID read scopes for Microsoft internal engineering systems.

**Used by:**
- **Seven** — researching internal documentation for analysis and writing
- **Picard** — architectural reference from internal engineering standards

**Identity:** `tamirdresher_microsoft` Entra ID account.
Access limited to documentation accessible to this user's org membership.

---

### Aspire MCP

**Type:** Built-in Copilot CLI plugin
**Config:** Requires running Aspire AppHost; connects to local dashboard.

**Auth model:** Local — connects to the Aspire dashboard URL (typically `http://localhost:18888`).
No external authentication.

**Capabilities:**
- List Aspire application resources and their status
- Read console and structured logs per resource
- Execute resource commands (start, stop, restart)
- View distributed traces and spans
- List service endpoints

**Scopes required:** Local network access to Aspire dashboard port.

**Used by:**
- **B'Elanna** — monitoring local Aspire-based application infrastructure during development.

**Identity:** Local machine process. No external identity involved.

---

### nano-banana MCP

**Type:** Built-in Copilot CLI plugin
**Config:** Requires Gemini API key (`configure_gemini_token` tool).

**Auth model:** Gemini API key authentication (Google AI Studio).

**Capabilities:**
- Generate new images from text prompts
- Edit existing images (by file path)
- Continue editing the last generated image
- Retrieve info about the last generated image

**Scopes required:** Gemini API key with image generation access.

**Used by:**
- **Neelix** — generating visuals for briefings
- **Troi** — blog post images and visual content
- **Paris** — visual production assets

**Identity:** Gemini API key tied to `tamirdresher_microsoft`'s Google AI Studio account.

---

### ConfigGen MCP

**Type:** Built-in Copilot CLI plugin (Microsoft internal)
**Config:** Activated by Entra ID session.

**Auth model:** Entra ID SSO. Read-only access to ConfigGen package and documentation APIs.

**Capabilities:**
- Search ConfigGen library public APIs
- Retrieve example code for ConfigGen libraries
- Get ConfigGen breaking change documentation
- List and fetch ConfigGen package updates

**Scopes required:** Entra ID read scopes for Microsoft internal NuGet/package systems.

**Used by:**
- **Data** — ConfigGen library integration in C#/.NET code
- **B'Elanna** — infrastructure configuration generation

**Identity:** `tamirdresher_microsoft` Entra ID account.

---

## Limitations & Enterprise Considerations

| Limitation | Impact | Workaround |
|-----------|--------|-----------|
| No per-agent token scoping | All agents share the same access rights | Manual review gate before high-impact ops |
| No audit trail per agent | Logs show user account, not which agent acted | Document agent actions in Scribe session logs |
| Single identity for all services | Cannot restrict Podcaster from touching GitHub code | Operational convention + Crusher safety gate |
| Interactive session required | Cannot run in headless CI/CD without user login | See [Future: Squad Service Principal](#future-squad-service-principal) |
| Token expiry affects all agents | When the user session expires, all agents stop | Re-authenticate; no per-agent session management needed |

---

## Future: Squad Service Principal

For enterprise and unattended scenarios, a dedicated Squad service principal would provide:

### What it enables

- **Own Entra ID app registration** not tied to a human user session
- **Certificate-based auth** — no interactive session for CI/CD runs
- **Per-agent scope restrictions:**
  - Podcaster: read-only GitHub, write-only Teams (audio delivery), no ADO
  - Ralph: read-only everything except work item status writes
  - Worf: read-only code + ADO security alerts only
- **Audit logs attributable to "Squad Agent — {AgentName}"** not the human account
- **Service principal rotation** independent of the human account's lifecycle

### Prerequisites

1. Copilot CLI must support non-interactive service principal auth (not yet available)
2. Each agent needs an individual Entra ID app registration (or a single registration with
   scoped credential sets)
3. GitHub supports OAuth Apps and GitHub Apps — a GitHub App per agent would enable
   per-agent attribution in GitHub audit logs

### Migration path

When service principal support becomes available:
1. Register a Squad GitHub App with minimum required scopes
2. Create an Entra ID app registration for the Squad
3. Map agent names to credential sets
4. Update `.copilot/mcp-config.json` to use app credentials instead of user tokens
5. Update this document's [Current Identity Model](#current-identity-model) section

**Track separately.** This document will be updated when non-interactive auth is available.

---

## Configuration File Locations

MCP servers are configured in priority order (first found wins):

1. **Repository-level:** `.copilot/mcp-config.json` — team-shared, committed to repo
2. **Workspace-level:** `.vscode/mcp.json` — VS Code workspace
3. **User-level:** `~/.copilot/mcp-config.json` — personal/machine-specific
4. **CLI override:** `--additional-mcp-config` flag — session-specific

Full configuration reference: `.squad/mcp-config.md`

---

*Maintained by: Seven (Research & Docs)*
*Last updated: 2026-Q2*
*Related: `.squad/docs/monorepo-support.md` (#1150) · Design: #1012 (Picard, "§3. Agent Identity + MCP Server Manifest")*
*Raised by: Michael Scott, "AI Squads" Teams meeting*
