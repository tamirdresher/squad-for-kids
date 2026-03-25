# Research: Agent Identity — Foundry Model + GHCP Frontmatter Design

**Date:** 2026-03-25  
**Issue:** #1519  
**Triggered by:** Juan Manuel Servera Bondroit — Teams message re: agents drifting from rules, lack of formal identity  
**Author:** Copilot (CPC-tamir-WCBED session)

---

## Executive Summary

Squad for Kids agents currently operate with rich charter documents (`.squad/agents/{name}/charter.md`) that define personality, scope, and behavior — but these charters have **no machine-enforceable identity** attached to them. Any agent can claim any identity, invoke any tool, and perform any action in the repository. This research synthesizes the Azure AI Foundry agent identity model, GitHub Copilot's emerging `agent profile` frontmatter system, and proposes a concrete permission design for Squad.

---

## 1. Azure AI Foundry Agent Identity Model

### 1.1 What is an Agent Identity?

Azure AI Foundry introduces **agent identities** as a first-class security primitive in Microsoft Entra ID. An agent identity is a specialized service principal — not a user, not a managed identity, but explicitly an **agent** — designed for AI workloads.

Key characteristics:
- Provisioned and managed by Foundry automatically throughout the agent lifecycle
- Scoped via Azure RBAC, just like human identities
- Distinguished from workforce and workload identities at the platform level
- Supports both **attended** (delegated/on-behalf-of) and **unattended** (autonomous) auth flows

### 1.2 Agent Identity Blueprint vs. Agent Identity

Foundry uses a two-tier model:

| Concept | What It Is |
|---------|-----------|
| **Agent Identity Blueprint** | A governing template / class definition. Represents a *type* of agent (e.g., "Contoso Sales Agent"). Used for lifecycle ops, Conditional Access, and OAuth credential storage. |
| **Agent Identity** | A runtime service principal instantiated from a blueprint. Represents one running agent instance. Used for actual tool calls. |

The blueprint answers: *What kind of agent is this?*  
The identity answers: *Which specific instance is acting right now?*

### 1.3 Shared vs. Distinct Identity

During development, all agents in a Foundry project share a **common identity** (one blueprint + one identity for the whole project). This simplifies early experimentation.

When an agent is **published to production**, Foundry automatically provisions a **distinct identity** for that specific agent. This is the signal for administrators to:
1. Assign exactly the RBAC roles needed (no more, no less)
2. Create independent audit trails per agent
3. Enable per-agent revocation without affecting other agents

### 1.4 Tool Authentication via Agent Identity

Published agents authenticate to downstream tools using their identity token:
- **MCP servers**: `AgenticIdentityToken` auth type, with an `audience` field specifying the target service
- **Agent-to-Agent (A2A)**: Secure inter-agent calls authenticated by identity
- Other tools may use key-based auth or OAuth passthrough — always check tool docs

### 1.5 Security Principles (Least Privilege)

Foundry's security guidance is explicit:
- Assign **only the permissions an agent needs** for its specific tool actions
- Prefer narrow RBAC scopes (resource or resource group) over subscription-wide roles
- Treat the shared project identity as higher blast radius — publish agents that need tighter controls
- Log and audit all external tool calls, especially to non-Microsoft services

**Key insight for Squad:** Foundry's model is a blueprint for what we should build in our own system — formally typed agents, least-privilege tool access, distinct identities per published agent.

---

## 2. GHCP Agent File Frontmatter: `allowed-tools` and Agent Profiles

### 2.1 What is an Agent Profile?

GitHub Copilot's coding agent now supports **custom agents** defined as Markdown files with YAML frontmatter, stored at `.github/agents/{agent-name}.md`. These are called *agent profiles*.

The frontmatter format:
```yaml
---
name: readme-creator
description: Agent specializing in creating and improving README files
---
```

### 2.2 The `tools` Frontmatter Property

Agent profiles support a `tools` property that **explicitly lists which tools the agent is allowed to use**. Without this, agents get access to all tools by default.

```yaml
---
name: docs-agent
description: Documentation-only specialist
tools:
  - read_file
  - write_file
  - create_pull_request
---
```

This is the `allowed-tools` pattern — a whitelist approach to tool access that enforces least privilege at the **agent definition level**, not just the system prompt level.

### 2.3 Agent Profile Scope Levels

| Scope | Location | Use Case |
|-------|----------|----------|
| Repository | `.github/agents/{name}.md` | Project-specific agents |
| Organization | `.github-private` repo `/agents/{name}.md` | Org-wide agents |
| Enterprise | Enterprise `.github-private` | Fleet-wide standard agents |

### 2.4 Current State of Squad Agent Files

Squad's existing `.github/agents/squad.agent.md` is a rich orchestration file but **has no YAML frontmatter**. All `.squad/agents/{name}/charter.md` files are purely narrative — they're system prompt material, not machine-enforceable identity declarations.

**Gap:** Squad charters are excellent behavioral contracts but have no:
- Formal name/ID binding
- Tool restriction declarations  
- Permission scope statements
- Version/lifecycle metadata

---

## 3. Current State of Squad Agent Identity

### 3.1 What Exists Today

```
.github/agents/squad.agent.md       — Orchestrator (no frontmatter)
.squad/agents/coach/charter.md      — Math & Logic Tutor (narrative only)
.squad/agents/gamer/charter.md      — Gamification Expert (narrative only)
.squad/agents/harmony/charter.md    — Music & Arts (narrative only)
.squad/agents/story/charter.md      — Creative Writing (narrative only)
.squad/agents/study-buddy/charter.md — Homework Helper (narrative only)
.squad/agents/explorer/charter.md   — Science & Discovery (narrative only)
.squad/agents/youtuber/charter.md   — Media & Digital Literacy (narrative only)
```

### 3.2 The Drift Problem

Juan Manuel's concern is well-founded: when an agent has no formally enforced identity, it can:
- Answer questions outside its defined scope
- Use tools it shouldn't access
- Impersonate other agents or the orchestrator
- Escalate its own permissions through clever prompting

Charter files are excellent **aspirational** identity documents. But they're only as strong as the model's willingness to follow them.

---

## 4. Proposal: Frontmatter `allowed-tools` for Each Agent

### 4.1 Pattern

Each agent's primary file (the `.github/agents/*.agent.md` or a new `.github/agents/{name}.md`) should be updated to include YAML frontmatter:

```yaml
---
name: coach
description: Math & Logic Tutor — builds confidence through sports-metaphor coaching
version: "1.0"
tier: subject-specialist
allowed-tools:
  - read_file
  - create_issue_comment
  - search_code
# Explicitly excluded:
# - push_files (coach never commits code)
# - create_pull_request (coach never submits PRs)
# - delete_file (coach has no destructive permissions)
---
```

### 4.2 Tier Definitions

| Tier | Description | Default Tool Set |
|------|-------------|-----------------|
| `orchestrator` | Squad master agent — manages sessions, routes to specialists | Full tool access |
| `subject-specialist` | Domain experts (Coach, Explorer, Harmony, Story) | Read + comment only |
| `study-companion` | Buddy + homework-focused agents | Read + create notes/issues |
| `content-creator` | Youtuber, creative content agents | Read + write (no push) |
| `gamification` | Pixel/Gamer — achievement system management | Read + write specific paths |

### 4.3 Progressive Trust Model

Borrowing from Foundry's shared→distinct identity ladder:

```
Level 0 (Draft)      → Inherits orchestrator identity, no own tools
Level 1 (Active)     → Own charter + frontmatter, tool whitelist enforced  
Level 2 (Trusted)    → PAT-scoped tokens, audit logging enabled
Level 3 (Published)  → Distinct service identity, full RBAC assignment
```

Squad agents are currently mostly at Level 0–1. Target is Level 2 for all subject specialists.

---

## 5. Proposal: Per-Agent PAT Scopes

### 5.1 Why Per-Agent PATs?

A single bot token (or the user's token) shared across all agents creates a flat permission model — every agent can do everything that token allows. Per-agent PATs implement least privilege at the authentication layer, not just the prompt layer.

### 5.2 Proposed Token Scope Matrix

| Agent | GitHub Scope | Why |
|-------|-------------|-----|
| Squad Orchestrator | `repo`, `issues`, `pull_requests` | Full coordination access |
| Coach | `contents:read`, `issues:write` | Can read materials, create progress notes |
| Explorer | `contents:read`, `issues:write` | Same as Coach |
| Harmony | `contents:read`, `issues:write` | Same pattern |
| Story | `contents:read`, `contents:write` (own path only) | Can save story drafts |
| Study-Buddy | `contents:read`, `issues:write` | Read homework, write tracking issues |
| Youtuber | `contents:read`, `contents:write` (own path only) | Can save video scripts |
| Gamer/Pixel | `contents:read`, `issues:write` | Read game data, write achievement issues |
| Fleet Monitor | `contents:read`, `actions:read` | Read-only audit agent |

### 5.3 Implementation Sketch

```yaml
# .squad/agent-tokens.yaml (secrets stored in GitHub Secrets)
coach:
  secret_ref: SQUAD_COACH_TOKEN
  scopes: [contents:read, issues:write]
  expires: 2026-12-31
  rotation: quarterly

orchestrator:
  secret_ref: SQUAD_ORCHESTRATOR_TOKEN  
  scopes: [repo, issues, pull_requests]
  expires: 2026-12-31
  rotation: quarterly
```

Tokens would be injected per-session via environment variables, not embedded in code.

---

## 6. Agent Permission Matrix

| Agent | Read Repo | Write Repo | Create Issues | Create PRs | Push Code | Delete Files | Admin Actions |
|-------|-----------|------------|---------------|------------|-----------|--------------|---------------|
| **Orchestrator** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ (protected) | ✅ |
| **Coach** | ✅ | ❌ | ✅ (notes only) | ❌ | ❌ | ❌ | ❌ |
| **Explorer** | ✅ | ❌ | ✅ (notes only) | ❌ | ❌ | ❌ | ❌ |
| **Harmony** | ✅ | ❌ | ✅ (notes only) | ❌ | ❌ | ❌ | ❌ |
| **Story** | ✅ | ✅ (stories/ path) | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Study-Buddy** | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Youtuber** | ✅ | ✅ (content/ path) | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Gamer/Pixel** | ✅ | ✅ (games/ path) | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Fleet Monitor** | ✅ | ❌ | ✅ (alerts only) | ❌ | ❌ | ❌ | ❌ |

Legend: ✅ Allowed | ❌ Denied | ⚠️ Conditional

---

## 7. Recommended Agent Profile Frontmatter Schema

```yaml
---
# Required fields
name: <agent-slug>           # Unique identifier, kebab-case
description: <one-liner>     # What this agent does

# Identity metadata
version: "1.0"
tier: subject-specialist     # orchestrator | subject-specialist | study-companion | content-creator | gamification
lifecycle: active            # draft | active | trusted | published | deprecated

# Tool restrictions (whitelist)
tools:
  - read_file
  - search_code
  - create_issue_comment
  # Add tools as needed per agent

# Path restrictions (optional)
allowed-paths:
  - "**"                     # Read all
  - "content/**"             # Write only own path

# Audit
owner: tamirdresher
created: 2026-03-25
last-reviewed: 2026-03-25
---
```

---

## 8. Next Steps

### Immediate (Sprint 1)
1. **Add YAML frontmatter** to `.github/agents/squad.agent.md` (orchestrator)
2. **Create individual agent profile files** at `.github/agents/{name}.md` with frontmatter + `tools` restriction
3. **Update squad charter files** to reference their corresponding agent profile

### Short-term (Sprint 2)
4. **Create `SQUAD_*_TOKEN` GitHub Secrets** with properly scoped PATs for each agent
5. **Update CI workflows** to inject the right token per agent session
6. **Add an agent identity audit step** to the daily squad report

### Medium-term (Sprint 3)
7. **Evaluate Foundry agent identity integration** — as Squad moves toward Azure/AKS deployment, formal Entra agent identities become the natural upgrade path
8. **Implement Conditional Access** — block agents from tool calls outside their declared scope
9. **Version agent identities** — increment `version` on charter changes, track in `decisions.md`

### For Juan Manuel
The core ask is valid: without machine-enforced identities, agents drift. The fix has three layers:
1. **Frontmatter** (enforce tool lists) — can be done this sprint
2. **PAT scopes** (enforce GitHub permissions) — requires secret setup, 1-2 days
3. **Entra agent identity** (full enterprise governance) — longer-term, but Foundry makes it achievable

---

## References

- [Azure AI Foundry — Agent Identity Concepts](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/agent-identity)
- [GitHub Copilot — Custom Agents (Agent Profiles)](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-custom-agents)
- [Microsoft Entra ID — Service Principals](https://learn.microsoft.com/en-us/entra/architecture/auth-sync-overview)
- Squad Issue #1519 — Agent Identity: Foundry Model + Tool Frontmatter Restrictions
