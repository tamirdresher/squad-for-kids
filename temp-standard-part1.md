# DK8S Squad Usage Standard

> **Version:** 1.0 ┬╖ **Status:** Proposed ┬╖ **Date:** 2026-03-17
> **Author:** Tamir Dresher ┬╖ **Issue:** [#771](https://github.com/tamirdresher_microsoft/tamresearch1/issues/771)

## 1. Purpose

This document defines how DK8S teams adopt and operate Squad ΓÇö the multi-agent AI framework that runs inside GitHub Copilot CLI and VS Code. It exists so every engineer, across every swimlane, sets up Squad the same way and gets the same benefits:

- **Consistent tooling** ΓÇö one way to configure agents, route work, and track decisions
- **Shared ownership** ΓÇö cross-team activities (vuln management, CI/CD, cleanups) have dedicated agent ownership
- **Personal customization** ΓÇö every engineer gets a personal squad tuned to their workflow
- **Upstream inheritance** ΓÇö org-level defaults flow down; personal overrides stay local

This is **not** a theoretical document. It tells you exactly what files to create, what to put in them, and how the pieces connect.

---

## 2. Squad Hierarchy

Squad operates at three levels. Each level inherits from the one above.

```
ΓöîΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÉ
Γöé           DK8S Org Squad                    Γöé
Γöé  repo: microsoft-mtp/dk8s-squad             Γöé
Γöé  owns: org-wide standards, shared agents,   Γöé
Γöé        cross-team workflows                 Γöé
Γö£ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöñ
Γöé     Swimlane / SubSquad                     Γöé
Γöé  repo: each swimlane's own repo             Γöé
Γöé  owns: swimlane-specific agents, routing,   Γöé
Γöé        domain expertise                     Γöé
Γö£ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöñ
Γöé     Personal Squad                          Γöé
Γöé  location: engineer's dev environment       Γöé
Γöé  owns: personal preferences, custom agents, Γöé
Γöé        universe theme, shortcuts            Γöé
ΓööΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÿ
```

### 2.1 Org Squad (`microsoft-mtp/dk8s-squad`)

The org-level squad repo is the **single source of truth** for DK8S-wide standards. It contains:

| Path | Purpose |
|------|---------|
| `.squad/team.md` | Org-wide shared agents (e.g., security scanner, compliance checker) |
| `.squad/routing.md` | Default routing rules all swimlanes inherit |
| `.squad/decisions.md` | Org-level architecture decisions |
| `.squad/ceremonies.md` | Standard ceremonies (design review, retro, model review) |
| `.squad/casting-policy.json` | Allowed character universes for the org |
| `squad.config.ts` | Org-wide model defaults, fallback chains, governance |
| `docs/` | Standards (this document), runbooks, guides |
| `.github/workflows/squad-*.yml` | Shared GitHub Actions for squad automation |

**Who maintains it:** DK8S Platform leads + designated squad maintainers from each swimlane.

### 2.2 Swimlane Squad (per-repo)

Each swimlane repo has its own `.squad/` directory that **extends** the org squad. Swimlane squads:

- Add domain-specific agents (e.g., a Helm expert for infra, a compliance agent for FedRAMP)
- Override routing rules for their domain
- Track swimlane-specific decisions
- Define swimlane-specific ceremonies and skills

**Example:** A FedRAMP swimlane might add:

```
.squad/
Γö£ΓöÇΓöÇ team.md                    # Swimlane roster (inherits + extends org)
Γö£ΓöÇΓöÇ routing.md                 # Swimlane routing (overrides org defaults)
Γö£ΓöÇΓöÇ decisions.md               # Swimlane decisions
Γö£ΓöÇΓöÇ agents/
Γöé   Γö£ΓöÇΓöÇ compliance-officer/
Γöé   Γöé   ΓööΓöÇΓöÇ charter.md         # FedRAMP-specific agent
Γöé   ΓööΓöÇΓöÇ drift-detector/
Γöé       ΓööΓöÇΓöÇ charter.md         # Config drift agent
ΓööΓöÇΓöÇ skills/
    ΓööΓöÇΓöÇ fedramp-audit/
        ΓööΓöÇΓöÇ SKILL.md           # Domain skill
```

### 2.3 Personal Squad (per-engineer)

Every engineer configures a personal squad in their dev environment. This is where you:

- Choose your character universe (Star Trek, Breaking Bad, Marvel, etc.)
- Add personal productivity agents (e.g., a meeting summarizer, a code reviewer tuned to your style)
- Override model preferences
- Configure MCP server connections for your tools

Personal squads live in `~/.squad/` or in the engineer's personal fork/branch.

---

## 3. Required Files & Configuration

### 3.1 `squad.config.ts` ΓÇö The Main Config

Every squad repo **must** have a `squad.config.ts` at the root. This is the machine-readable configuration.

```typescript
import type { SquadConfig } from '@bradygaster/squad';

const config: SquadConfig = {
  version: '1.0.0',

  models: {
    // Default model for all agents unless overridden in charter
    defaultModel: 'claude-sonnet-4.5',
    defaultTier: 'standard',
    fallbackChains: {
      premium:  ['claude-opus-4.6', 'claude-opus-4.5', 'claude-sonnet-4.5'],
      standard: ['claude-sonnet-4.5', 'gpt-5.2-codex', 'claude-sonnet-4', 'gpt-5.2'],
      fast:     ['claude-haiku-4.5', 'gpt-5.1-codex-mini', 'gpt-4.1', 'gpt-5-mini']
    },
    preferSameProvider: true,
    respectTierCeiling: true,
    nuclearFallback: {
      enabled: false,      // Don't fall back to cheapest model after failures
      model: 'claude-haiku-4.5',
      maxRetriesBeforeNuclear: 3
    }
  },

  routing: {
    rules: [
      // Scribe auto-attaches to all work types for logging
      { workType: 'feature-dev',   agents: ['@scribe'], confidence: 'high' },
      { workType: 'bug-fix',       agents: ['@scribe'], confidence: 'high' },
      { workType: 'testing',       agents: ['@scribe'], confidence: 'high' },
      { workType: 'documentation', agents: ['@scribe'], confidence: 'high' }
    ],
    governance: {
      eagerByDefault: true,         // Spawn agents proactively
      scribeAutoRuns: false,        // Scribe triggered by routing rules, not auto
      allowRecursiveSpawn: false    // Agents cannot spawn other agents
    }
  },

  casting: {
    allowlistUniverses: [
      'Star Trek: TNG',
      'Star Trek: Voyager',
      'Breaking Bad',
      'Firefly'
      // Add your swimlane's preferred universes
    ],
    overflowStrategy: 'generic',   // Use generic names if universe exhausted
    universeCapacity: {}            // Per-universe limits (optional)
  },

  platforms: {
    vscode: {
      disableModelSelection: false,
      scribeMode: 'sync'
    }
  }
};

export default config;
```

### 3.2 `.squad/team.md` ΓÇö Team Roster

Lists every agent and human on the squad. Format:

```markdown
# Squad Team

## Human Members
| Name | Role | Contact | Notes |
|------|------|---------|-------|
| Jane Doe | Tech Lead | Teams: @janedoe | Decision maker |

## Agent Members
| Agent | Role | Status | Charter |
|-------|------|--------|---------|
| Picard | Lead ΓÇö Architecture & Decisions | Γ£à Active | `.squad/agents/picard/charter.md` |
| Data | Code Expert ΓÇö C#, Go, .NET | Γ£à Active | `.squad/agents/data/charter.md` |
| Worf | Security & Cloud ΓÇö Azure, Networking | Γ£à Active | `.squad/agents/worf/charter.md` |
| @copilot | Coding Agent ΓÇö Autonomous small tasks | ≡ƒñû Active | ΓÇö |
```

**Rules:**
- Every squad **must** have at least one Lead agent and one human decision maker
- The `@copilot` entry enables GitHub's built-in Copilot coding agent
- Status values: `Γ£à Active`, `≡ƒöä Monitor` (background), `≡ƒôï Silent` (logging only), `≡ƒñû Active` (autonomous)

### 3.3 `.squad/routing.md` ΓÇö Work Routing

Defines how work gets assigned. This file is read by both humans and the coordinator agent.

```markdown
# Work Routing

## Routing Table
| Work Type | Route To | Notes |
|-----------|----------|-------|
| Architecture, distributed systems | Picard | Primary owner |
| Security, Azure, networking | Worf | Security-first |
| C#, Go, .NET, clean code | Data | Code quality |
| K8s, Helm, ArgoCD | B'Elanna | Infrastructure |
| Code review, small bugs, tests | @copilot ≡ƒñû | Well-defined only |

## Issue Triage Process
1. New issues get `squad` label ΓåÆ Lead triages
2. Lead assigns `squad:{member}` label ΓåÆ agent picks up work
3. `squad:copilot` ΓåÆ @copilot works autonomously (≡ƒƒó tasks only)
4. Agents can reassign by changing labels

## @copilot Capability Profile
- ≡ƒƒó Good fit: Bug fixes, test additions, dependency updates, well-defined tasks
- ≡ƒƒí Needs review: Medium features with clear specs (PR review before merge)
- ≡ƒö┤ Not suitable: Architecture, security, design decisions ΓåÆ escalate

## Governance Rules
1. Eager by default ΓÇö spawn all agents who could usefully start work
2. Quick facts ΓåÆ coordinator answers directly (don't spawn for trivial questions)
3. When two agents could handle it, pick the one whose domain is primary
4. "Team, ..." ΓåÆ fan-out: spawn all relevant agents in parallel
```

### 3.4 `.squad/agents/{name}/charter.md` ΓÇö Agent Charters

Each agent has a charter defining its personality, expertise, and constraints.

```yaml
---
name: "worf"
role: "Security & Cloud"
expertise: "Security, Azure, networking, compliance"
style: "Paranoid by design. Assumes every input is hostile."
model: "auto"
---

# Worf ΓÇö Security & Cloud

## Responsibilities
- Review all security-sensitive changes
- Maintain Azure networking configurations
- Run threat modeling on new features
- Enforce FedRAMP compliance requirements

## Constraints
- Never approve security exceptions without Lead sign-off
- Always run CodeQL analysis before approving PRs
- Escalate any credential exposure immediately
```

### 3.5 `.squad/decisions.md` ΓÇö Decision Log

Tracks all architectural and process decisions. Uses a numbered format:

```markdown
## Decision 1: Adopt Squad Framework for DK8S

**Date:** 2026-03-17
**Evaluator:** Picard (Lead)
**Status:** Γ£à APPROVED

### Summary
Adopt Squad as the standard multi-agent framework for all DK8S swimlanes.

### Context
Engineers were using ad-hoc Copilot configurations. Squad provides structure.

### Implementation
1. Create org-level squad repo
2. Each swimlane extends with domain agents
3. Engineers set up personal squads
```

### 3.6 `.squad/ceremonies.md` ΓÇö Team Ceremonies

```markdown
# Squad Ceremonies

## Design Review
- **Trigger:** Before multi-agent tasks or architecture changes
- **Facilitator:** Lead
- **Agenda:** Review requirements ΓåÆ agree on interfaces ΓåÆ identify risks
- **Output:** Updated decisions.md entry

## Retrospective
- **Trigger:** After build/test failure or PR rejection
- **Facilitator:** Lead
- **Agenda:** What happened ΓåÆ root cause ΓåÆ action items
- **Output:** Process improvement logged

## Model Review
- **Trigger:** Quarterly or on major model releases
- **Facilitator:** Lead
- **Participants:** All agents affected by model changes
- **Process:** Benchmark ΓåÆ evaluate cost/quality ΓåÆ update squad.config.ts
```

---
