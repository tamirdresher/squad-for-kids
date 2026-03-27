# Agent Identity Design for Squad for Kids

> **Issue:** [#30 - Agent Identity: Foundry Model + Tool Frontmatter Restrictions](https://github.com/tdsquadAI/squad-for-kids/issues/30)
> **Author:** Seven (Research and Docs)
> **Date:** 2026-03-25
> **Status:** Draft - ready for team review

---

## Problem Statement

Squad agents currently have rich charter documents (`.squad/agents/{name}/charter.md`) that define personality and scope, but enforcement is entirely soft:

- No YAML frontmatter with a `tools` allowlist — any agent can invoke any tool
- No per-agent authentication tokens — all agents share the same permissions
- No formal tier/lifecycle metadata — no governance model

Juan Manuel Servera Bondroit raised this concern via Teams: agents drift from their defined rules because there is no machine-enforced identity system.

---

## 1. Azure AI Foundry Agent Identity Model

Azure AI Foundry introduces **agent identities** as a first-class concept in Microsoft Entra ID — a specialized service principal type designed specifically for AI agents. The framework separates the *template* (blueprint) from the *runtime instance* (identity), enabling governance at scale.

### Key Terms

| Term | Meaning |
|------|---------|
| **Agent Identity** | A Microsoft Entra ID service principal representing the agent at runtime |
| **Agent Identity Blueprint** | A governing template/class from which all agent identities of a given type are created |
| `agentIdentityId` | The identifier used when assigning permissions to a specific agent identity |
| **Audience** | The resource identifier for a downstream service (e.g., `https://storage.azure.com`) |

### Blueprints vs. Identities

**Blueprints** (the class/template):
- Define the *category* of agent (e.g., "Safety Reviewer Agent")
- Enable administrators to apply Conditional Access policies to all agents of a type
- Carry OAuth credentials used by the hosting service to request tokens at runtime
- Include metadata: agent name, publisher, roles, Microsoft Graph permissions

**Agent Identities** (the runtime instance):
- Created from blueprints; represent the agent's authority during execution
- Assigned RBAC roles (read/write on specific resources)
- Can be **shared** (all in-dev agents in a project share one identity) or **distinct** (published agents get their own identity for independent auditing)

### Shared vs. Distinct Identity

| Mode | When to Use | Benefit |
|------|-------------|---------|
| **Shared project identity** | Development / experimentation | Simplified admin; one permission set for all in-dev agents |
| **Distinct agent identity** | Production / published / divergent permissions | Independent audit trail; unique permission set; lifecycle isolation |

### Authentication Flows

1. **Attended (delegated)** - Agent acts on behalf of a human user using delegated permissions (on-behalf-of flow)
2. **Unattended** - Agent acts under its own authority using app-assigned RBAC roles

### Supported Tool Auth (Foundry)

Currently tools with agent identity authentication support:
- **MCP (Model Context Protocol)** - Agent presents identity token to MCP server
- **Agent-to-Agent (A2A)** - Agents authenticate to each other via identities

### Mapping to Squad for Kids

| Foundry Concept | Squad for Kids Equivalent |
|-----------------|--------------------------|
| Blueprint | Agent charter class (e.g., "Safety Agent") |
| Agent Identity | Per-agent GitHub token / credential scope |
| RBAC Roles | GitHub PAT token scopes + repo permissions |
| Shared project identity | Single token for development/testing sessions |
| Distinct agent identity | Separate PAT per agent for production sessions |

---

## 2. GitHub Copilot Agent Profile Frontmatter

GitHub Copilot supports **custom agents** defined as Markdown files with YAML frontmatter. These agent profiles live in `.github/agents/` (repository level) or `/agents/` (org/enterprise level in `.github-private`).

### Agent Profile Format

```yaml
---
name: agent-name
description: "Required - explains purpose and capabilities"
tools: ["read", "edit", "search"]
model: claude-sonnet-4
target: github-copilot
mcp-servers:
  - name: my-server
    url: https://...
---
```

### The `tools` Property

This is the key machine-enforcement mechanism:

- **If omitted:** agent has access to ALL available tools (built-in + MCP server tools)
- **If specified:** agent can ONLY invoke the listed tools
- **Format:** list of tool names or aliases, e.g., `["read", "search", "edit"]`
- **MCP tools:** referenced as `"server-name/tool-name"` syntax

### Example: Read-Only Agent

```yaml
---
name: safety-reviewer
description: Reviews content for child safety - read-only, no modifications
tools: ["read", "search"]
---
```

### Placement in Squad for Kids

Following the GitHub Copilot pattern, agent profiles should live at `.squad/agents/{agent-name}/charter.md`. Adding YAML frontmatter to each existing charter document enforces the tool allowlist at the framework level.

---

## 3. Recommended Design for Squad for Kids

### Principles

1. **Least privilege** - Each agent gets only the tools it legitimately needs
2. **Explicit over implicit** - `tools` allowlist must be present in all charters; no omission
3. **Safety-first** - Dr. Sarah agent is read-only with no content modification rights
4. **Tier-based auth** - Development sessions use shared identity; future production uses distinct
5. **Auditable** - All agent decisions and tool invocations should reference their charter

### Agent Tier Classification

| Tier | Description | Identity Mode |
|------|-------------|---------------|
| **Tier 1 - Observers** | Read-only analysis, safety review | Shared dev identity; read-only PAT |
| **Tier 2 - Contributors** | Write educational content, templates | Shared dev identity; content-scoped PAT |
| **Tier 3 - Coordinators** | Route work, manage issues, review | Shared dev identity; issues + PR PAT |

### PAT Token Scope Design

| Agent | Tier | Recommended PAT Scopes |
|-------|------|------------------------|
| **Dr. Sarah** | 1 - Observer | `contents:read`, `issues:read` |
| **Buddy** | 1 - Observer | `contents:read`, `issues:read` |
| **Maria** | 2 - Contributor | `contents:write`, `pull_requests:write`, `issues:write` |
| **Ken** | 2 - Contributor | `contents:write`, `pull_requests:write`, `issues:write` |
| **Sal** | 2 - Contributor | `contents:write`, `pull_requests:write`, `issues:write` |
| **Emma** | 2 - Contributor | `contents:write`, `pull_requests:write` |
| **Pixel** | 2 - Contributor | `contents:write`, `issues:write` |
| **Zephyr** | 2 - Contributor | `contents:write`, `issues:write` |

> **Note:** Fine-grained PATs are strongly preferred over classic PATs.

---

## 4. Agent Permission Matrix

| Agent | Allowed Tools | Repo Scope | Network Access | Secret Access |
|-------|--------------|------------|----------------|---------------|
| **Maria** - Pedagogy Expert | `read`, `edit`, `search`, `create` | `contents:write`, `pull_requests:write`, `issues:write` | None | None |
| **Ken** - Creative Education | `read`, `edit`, `search`, `create` | `contents:write`, `pull_requests:write`, `issues:write` | None | None |
| **Sal** - EdTech Expert | `read`, `edit`, `search`, `create` | `contents:write`, `pull_requests:write`, `issues:write` | None | None |
| **Emma** - Content Creator | `read`, `edit`, `search`, `create` | `contents:write`, `pull_requests:write` | None | None |
| **Dr. Sarah** - Child Psychologist | `read`, `search` | `contents:read`, `issues:read` | None | None |
| **Pixel** - Gamification Expert | `read`, `edit`, `search`, `create` | `contents:write`, `issues:write` | External game APIs (read-only) | None |
| **Zephyr** - Video Content | `read`, `edit`, `search`, `create` | `contents:write`, `issues:write` | YouTube Data API (read-only) | None |
| **Buddy** - Study Helper | `read`, `search` | `contents:read`, `issues:read` | None | None |

> **Critical:** `run_terminal_cmd` is explicitly excluded from all agent profiles. This prevents any agent from running arbitrary shell commands.

---

## 5. Sample Agent Frontmatter

The actual charter files with frontmatter are at:
- `.squad/agents/dr-sarah/charter.md`
- `.squad/agents/maria/charter.md`

### Dr. Sarah - Tier 1 Observer Pattern

```yaml
---
name: dr-sarah
description: >
  Child psychologist ensuring all educational content is emotionally safe,
  developmentally appropriate, and psychologically sound. Read-only reviewer.
tools: ["read", "search"]
tier: 1
permissions:
  repo: contents:read
  issues: read
safety-clearance: required-for-all-templates
---
```

### Maria - Tier 2 Contributor Pattern

```yaml
---
name: maria
description: >
  Lead pedagogical expert ensuring all templates follow proven educational
  principles. All new templates require Maria's sign-off.
tools: ["read", "edit", "search", "create"]
tier: 2
permissions:
  repo: contents:write
  pull_requests: write
  issues: write
required-reviewer: true
---
```

---

## 6. Implementation Roadmap

### Phase 1 - Frontmatter on All Charters (Immediate)
- [ ] Add YAML frontmatter to all 8 agent charter files in `.squad/agents/`
- [ ] Document the `tools` allowlist for each agent
- [ ] Add `tier` and `permissions` metadata

### Phase 2 - Enforcement Layer (Short-term)
- [ ] Create a charter validation CI action that rejects PRs if any charter is missing `tools` frontmatter
- [ ] Document that the coordinator must read `tools` before routing work

### Phase 3 - Token Isolation (Medium-term)
- [ ] Generate separate fine-grained PATs per agent tier
- [ ] Store in GitHub secrets with naming convention `AGENT_{NAME}_TOKEN`
- [ ] Update spawn scripts to inject the appropriate token per agent

### Phase 4 - Blueprint Registration (Long-term)
- [ ] For Azure AI Foundry deployments, register each agent class as a blueprint
- [ ] Move to distinct agent identities for Dr. Sarah and Buddy (safety-critical observers)

---

## References

- [Azure AI Foundry - Agent Identity](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/agent-identity)
- [GitHub Copilot - About Custom Agents](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-custom-agents)
- [GitHub Copilot - Creating Custom Agents](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-custom-agents)
- [Issue #30](https://github.com/tdsquadAI/squad-for-kids/issues/30)
