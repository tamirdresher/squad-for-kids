# DK8S Squad Usage Standard

> **Version:** 1.0 · **Status:** Proposed · **Date:** 2026-03-17
> **Author:** Tamir Dresher · **Issue:** [#771](https://github.com/tamirdresher_microsoft/tamresearch1/issues/771)

## 1. Purpose

This document defines how DK8S teams adopt and operate Squad — the multi-agent AI framework that runs inside GitHub Copilot CLI and VS Code. It exists so every engineer, across every swimlane, sets up Squad the same way and gets the same benefits:

- **Consistent tooling** — one way to configure agents, route work, and track decisions
- **Shared ownership** — cross-team activities (vuln management, CI/CD, cleanups) have dedicated agent ownership
- **Personal customization** — every engineer gets a personal squad tuned to their workflow
- **Upstream inheritance** — org-level defaults flow down; personal overrides stay local

This is **not** a theoretical document. It tells you exactly what files to create, what to put in them, and how the pieces connect.

---

## 2. Squad Hierarchy

Squad operates at three levels. Each level inherits from the one above.

```
┌─────────────────────────────────────────────┐
│           DK8S Org Squad                    │
│  repo: microsoft-mtp/dk8s-squad             │
│  owns: org-wide standards, shared agents,   │
│        cross-team workflows                 │
├─────────────────────────────────────────────┤
│     Swimlane / SubSquad                     │
│  repo: each swimlane's own repo             │
│  owns: swimlane-specific agents, routing,   │
│        domain expertise                     │
├─────────────────────────────────────────────┤
│     Personal Squad                          │
│  location: engineer's dev environment       │
│  owns: personal preferences, custom agents, │
│        universe theme, shortcuts            │
└─────────────────────────────────────────────┘
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
├── team.md                    # Swimlane roster (inherits + extends org)
├── routing.md                 # Swimlane routing (overrides org defaults)
├── decisions.md               # Swimlane decisions
├── agents/
│   ├── compliance-officer/
│   │   └── charter.md         # FedRAMP-specific agent
│   └── drift-detector/
│       └── charter.md         # Config drift agent
└── skills/
    └── fedramp-audit/
        └── SKILL.md           # Domain skill
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

### 3.1 `squad.config.ts` — The Main Config

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

### 3.2 `.squad/team.md` — Team Roster

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
| Picard | Lead — Architecture & Decisions | ✅ Active | `.squad/agents/picard/charter.md` |
| Data | Code Expert — C#, Go, .NET | ✅ Active | `.squad/agents/data/charter.md` |
| Worf | Security & Cloud — Azure, Networking | ✅ Active | `.squad/agents/worf/charter.md` |
| @copilot | Coding Agent — Autonomous small tasks | 🤖 Active | — |
```

**Rules:**
- Every squad **must** have at least one Lead agent and one human decision maker
- The `@copilot` entry enables GitHub's built-in Copilot coding agent
- Status values: `✅ Active`, `🔄 Monitor` (background), `📋 Silent` (logging only), `🤖 Active` (autonomous)

### 3.3 `.squad/routing.md` — Work Routing

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
| Code review, small bugs, tests | @copilot 🤖 | Well-defined only |

## Issue Triage Process
1. New issues get `squad` label → Lead triages
2. Lead assigns `squad:{member}` label → agent picks up work
3. `squad:copilot` → @copilot works autonomously (🟢 tasks only)
4. Agents can reassign by changing labels

## @copilot Capability Profile
- 🟢 Good fit: Bug fixes, test additions, dependency updates, well-defined tasks
- 🟡 Needs review: Medium features with clear specs (PR review before merge)
- 🔴 Not suitable: Architecture, security, design decisions → escalate

## Governance Rules
1. Eager by default — spawn all agents who could usefully start work
2. Quick facts → coordinator answers directly (don't spawn for trivial questions)
3. When two agents could handle it, pick the one whose domain is primary
4. "Team, ..." → fan-out: spawn all relevant agents in parallel
```

### 3.4 `.squad/agents/{name}/charter.md` — Agent Charters

Each agent has a charter defining its personality, expertise, and constraints.

```yaml
---
name: "worf"
role: "Security & Cloud"
expertise: "Security, Azure, networking, compliance"
style: "Paranoid by design. Assumes every input is hostile."
model: "auto"
---

# Worf — Security & Cloud

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

### 3.5 `.squad/decisions.md` — Decision Log

Tracks all architectural and process decisions. Uses a numbered format:

```markdown
## Decision 1: Adopt Squad Framework for DK8S

**Date:** 2026-03-17
**Evaluator:** Picard (Lead)
**Status:** ✅ APPROVED

### Summary
Adopt Squad as the standard multi-agent framework for all DK8S swimlanes.

### Context
Engineers were using ad-hoc Copilot configurations. Squad provides structure.

### Implementation
1. Create org-level squad repo
2. Each swimlane extends with domain agents
3. Engineers set up personal squads
```

### 3.6 `.squad/ceremonies.md` — Team Ceremonies

```markdown
# Squad Ceremonies

## Design Review
- **Trigger:** Before multi-agent tasks or architecture changes
- **Facilitator:** Lead
- **Agenda:** Review requirements → agree on interfaces → identify risks
- **Output:** Updated decisions.md entry

## Retrospective
- **Trigger:** After build/test failure or PR rejection
- **Facilitator:** Lead
- **Agenda:** What happened → root cause → action items
- **Output:** Process improvement logged

## Model Review
- **Trigger:** Quarterly or on major model releases
- **Facilitator:** Lead
- **Participants:** All agents affected by model changes
- **Process:** Benchmark → evaluate cost/quality → update squad.config.ts
```

---

## 4. Agent Roles & Responsibilities

### 4.1 Standard Agent Roster

Every DK8S squad should include these **core agents** (customize names per your universe):

| Role | Responsibilities | Model Tier | Example Agent |
|------|-----------------|------------|---------------|
| **Lead** | Architecture, decisions, triage, coordination | Standard | Picard |
| **Code Expert** | Code generation, review, refactoring, clean code | Standard | Data |
| **Security** | Security review, Azure, compliance, threat modeling | Standard | Worf |
| **Infrastructure** | K8s, Helm, ArgoCD, CI/CD, cloud native | Standard | B'Elanna |
| **Research & Docs** | Documentation, analysis, presentations | Standard | Seven |
| **Scribe** | Session logging, decision tracking, context sharing | Fast | Scribe |
| **@copilot** | Autonomous small tasks, bug fixes, tests | Built-in | @copilot |

### 4.2 Optional Agents

These are useful but not required for every squad:

| Role | Responsibilities | Model Tier |
|------|-----------------|------------|
| Devil's Advocate | Fact-checking, counter-hypothesis, assumption testing | Standard |
| Communications | Calendar, email, Teams, scheduling | Fast |
| Work Monitor | Queue tracking, backlog health, stale issue detection | Fast |
| News Reporter | Daily briefings, status reports, styled updates | Fast |
| Blogger | Voice writing, content series, external comms | Standard |
| Audio Producer | TTS, podcast generation, audio summaries | Fast |

### 4.3 Model Tier Guidelines

| Tier | Model | Use When |
|------|-------|----------|
| **Standard** | `claude-sonnet-4.5` | Complex reasoning, code generation, security review, architecture |
| **Fast** | `claude-haiku-4.5` | Routine tasks, formatting, logging, daily briefings, monitoring |
| **Premium** | `claude-opus-4.6` | Mission-critical decisions with high error cost (use sparingly) |

---

## 5. Issue Triage Workflow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────┐
│  New Issue    │────▶│  Add `squad` │────▶│  Lead triages     │
│  created      │     │  label       │     │  (assigns agent)  │
└──────────────┘     └──────────────┘     └────────┬─────────┘
                                                    │
                          ┌─────────────────────────┼────────────────────┐
                          │                         │                    │
                          ▼                         ▼                    ▼
                  ┌───────────────┐    ┌────────────────┐    ┌──────────────────┐
                  │ squad:{agent} │    │ squad:copilot   │    │ squad:review      │
                  │ label added   │    │ label added     │    │ needs human eyes  │
                  │               │    │                 │    │                   │
                  │ Agent picks   │    │ @copilot works  │    │ Assign to human   │
                  │ up in next    │    │ autonomously    │    │ for review        │
                  │ session       │    │ (🟢 tasks only) │    │                   │
                  └───────┬───────┘    └────────┬───────┘    └──────────────────┘
                          │                     │
                          ▼                     ▼
                  ┌───────────────┐    ┌────────────────┐
                  │ Create branch │    │ Create branch   │
                  │ squad/{issue} │    │ squad/{issue}   │
                  │ -{description}│    │ -{description}  │
                  └───────┬───────┘    └────────┬───────┘
                          │                     │
                          ▼                     ▼
                  ┌───────────────────────────────────┐
                  │          Open PR                   │
                  │  Title: description (#issue)       │
                  │  Body: Closes #issue               │
                  │  Labels: squad:review if 🟡        │
                  └───────────────────────────────────┘
```

### 5.1 Label Reference

| Label | Meaning | Who Acts |
|-------|---------|----------|
| `squad` | Untriaged — waiting for Lead | Lead agent |
| `squad:{agent}` | Assigned to specific agent | Named agent |
| `squad:copilot` | Assigned to @copilot | GitHub Copilot coding agent |
| `squad:review` | Needs human review before merge | Human team member |
| `go:needs-research` | Requires research before implementation | Seven (Research) |

---

## 6. Branch & PR Conventions

### 6.1 Branch Naming

```
squad/{issue-number}-{brief-description}
```

**Examples:**
```
squad/771-dk8s-squad-standard
squad/42-fix-helm-chart-values
squad/100-add-fedramp-controls
```

### 6.2 Commit Messages

```
{type}({scope}): {brief summary} (#{issue})

{optional body with details}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

**Types:** `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`
**Scopes:** `squad`, `infra`, `security`, `api`, `ui`, `ci`, `docs`

**Examples:**
```
docs(squad): add DK8S squad usage standard (#771)
fix(infra): correct Helm chart memory limits (#42)
feat(security): add FedRAMP SC-7 network policy (#100)
```

### 6.3 Pull Request Template

Every PR should use the repo's template (`.github/PULL_REQUEST_TEMPLATE.md`):

```markdown
## Description
[What changed and why]

## Related Issue
Closes #[issue number]

## Quality Gates Checklist
- [ ] Tests added/updated
- [ ] No new CodeQL/security warnings
- [ ] Code reviewed by squad member
- [ ] Documentation updated if needed
- [ ] Churn rate checked (run `scripts/code-churn-rate.ps1`)

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Refactoring
```

---

## 7. Communication & Teams Integration

### 7.1 Teams Webhook

Squad agents communicate via Microsoft Teams webhooks. Configuration:

```
# Webhook URL stored at:
$env:USERPROFILE\.squad\teams-webhook.url

# Or set as environment variable:
$env:TEAMS_WEBHOOK_URL
```

Agents like Neelix (News Reporter) and Kes (Communications) use this to:
- Send daily briefings to team channels
- Notify on issue assignments
- Share status reports
- Alert on build failures

### 7.2 Communication Rules

1. **Plain text messages only** — no adaptive cards (hard to copy on mobile)
2. **Thread replies** — agents reply in message threads, not top-level
3. **Human escalation** — tag the human owner when blocked or uncertain
4. **No spam** — aggregate updates; don't send per-commit notifications

---

## 8. Cross-Team Activities

These activities span multiple swimlanes and need dedicated agent ownership at the org level:

| Activity | Owner Agent | Cadence | Scope |
|----------|-------------|---------|-------|
| **Vulnerability Management** | Security agent | Continuous + weekly report | All repos |
| **CI/CD Pipeline Health** | Infrastructure agent | Daily checks | All pipelines |
| **Dependency Updates** | @copilot | Weekly PR batches | All repos |
| **Code Quality Cleanup** | Code Expert agent | Monthly sweeps | High-churn files |
| **Documentation Freshness** | Research agent | Bi-weekly audit | All docs/ dirs |
| **Config Drift Detection** | Infrastructure agent | Daily | All environments |
| **FedRAMP Compliance** | Security agent | Continuous | Sovereign deployments |

### 8.1 How Cross-Team Works

1. Org squad repo defines the cross-team agents and their schedules
2. GitHub Actions workflows in the org repo trigger cross-team scans
3. Results are posted to the DK8S Platform leads Teams channel
4. Swimlane squads receive issues auto-created by the org squad for remediation

---

## 9. Upstream Inheritance

Upstream inheritance connects the three squad levels. When the org squad updates a standard:

```
Org Squad (microsoft-mtp/dk8s-squad)
  │
  ├── Updates squad.config.ts defaults
  ├── Updates shared agent charters
  ├── Updates routing rules
  │
  ▼
Swimlane Squads (per-repo .squad/)
  │
  ├── Inherit new defaults on next sync
  ├── Swimlane overrides preserved
  ├── New agents available immediately
  │
  ▼
Personal Squads (~/.squad/)
  │
  └── Personal overrides preserved
      New org/swimlane agents available
```

### 9.1 Sync Mechanism

1. **Org → Swimlane:** PR from org squad to swimlane repos (manual review required)
2. **Swimlane → Personal:** Engineer pulls latest from their repo
3. **Personal → Swimlane (contributions):** PR upstream with new skills/agents

### 9.2 Override Priority

```
Personal config > Swimlane config > Org config
```

A personal `squad.config.ts` can override model preferences, add agents, or disable org-level defaults. Swimlane configs can do the same relative to the org.

---

## 10. Escalation Paths

| Situation | Escalate To | How |
|-----------|-------------|-----|
| Unclear requirements | Lead agent (Picard) | Comment on issue, tag @picard |
| Security concern | Security agent (Worf) | Tag @worf, add `security` label |
| Architecture question | Lead agent | Tag @picard, request design review |
| Infrastructure/deployment | Infrastructure agent (B'Elanna) | Tag @belanna |
| Build/test failure | Lead triggers retrospective ceremony | Automatic |
| Cross-team conflict | DK8S Platform leads (human) | Teams message to leads channel |
| Agent not performing | Lead reviews, triggers model review | Update charter or swap model |

---

## 11. Getting Started — Engineer Quickstart

### Step 1: Clone Your Swimlane Repo

```powershell
git clone https://github.com/microsoft-mtp/{your-swimlane-repo}.git
cd {your-swimlane-repo}
```

### Step 2: Verify Squad Config Exists

```powershell
# These files should exist:
Test-Path squad.config.ts          # Main config
Test-Path .squad/team.md           # Team roster
Test-Path .squad/routing.md        # Work routing
Test-Path .squad/decisions.md      # Decision log
```

### Step 3: Set Up Personal Squad

```powershell
# Create personal squad directory
New-Item -ItemType Directory -Path "$env:USERPROFILE\.squad" -Force

# Copy template config and customize
Copy-Item squad.config.ts "$env:USERPROFILE\.squad\squad.config.ts"
# Edit to set your preferred universe, model overrides, etc.
```

### Step 4: Configure Teams Webhook

```powershell
# Get webhook URL from your team lead
# Save it for agent communication
Set-Content "$env:USERPROFILE\.squad\teams-webhook.url" "https://your-webhook-url"
```

### Step 5: Configure MCP Servers

Create `.copilot/mcp-config.json` in your repo (or `~/.copilot/mcp-config.json` for global):

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
    }
  }
}
```

### Step 6: Start Working

```powershell
# Open in VS Code or use Copilot CLI
code .

# Create an issue for your work
# Add the `squad` label
# Lead will triage and assign
# Or self-assign with `squad:{your-agent}` label
```

---

## 12. File Structure Reference

Complete directory structure for a properly configured squad repo:

```
repo-root/
├── squad.config.ts                    # Main squad configuration
├── .squad/
│   ├── team.md                        # Team roster (humans + agents)
│   ├── routing.md                     # Work routing rules
│   ├── decisions.md                   # Decision log (maintained by Scribe)
│   ├── ceremonies.md                  # Team ceremonies
│   ├── casting-policy.json            # Allowed character universes
│   ├── config.json                    # Machine-specific config
│   ├── mcp-config.md                  # MCP server setup guide
│   ├── charter.md                     # Charter template
│   ├── agents/
│   │   ├── {lead}/charter.md          # Lead agent charter
│   │   ├── {code-expert}/charter.md   # Code expert charter
│   │   ├── {security}/charter.md      # Security agent charter
│   │   ├── {infra}/charter.md         # Infrastructure agent charter
│   │   ├── {research}/charter.md      # Research agent charter
│   │   └── scribe/charter.md          # Scribe charter (always present)
│   ├── skills/
│   │   └── {skill-name}/SKILL.md      # Skill definitions
│   ├── decisions/
│   │   └── inbox/                     # Decision drop-box for parallel work
│   ├── log/                           # Session logs (written by Scribe)
│   └── monitoring/                    # Monitoring state files
├── .github/
│   ├── copilot-instructions.md        # @copilot behavior rules
│   ├── PULL_REQUEST_TEMPLATE.md       # PR quality gates
│   ├── agents/
│   │   └── {name}.agent.md            # GitHub agent definitions
│   ├── workflows/
│   │   ├── squad-ci.yml               # CI pipeline
│   │   ├── squad-triage.yml           # Auto-triage
│   │   ├── squad-issue-assign.yml     # Auto-assignment
│   │   └── squad-*.yml                # Other squad workflows
│   └── ISSUE_TEMPLATE/
│       └── squad-task.yml             # Issue template for squad tasks
└── docs/
    ├── dk8s-squad-usage-standard.md   # This document
    └── adr/
        └── 0001-dk8s-squad-usage-standard.md  # ADR version
```

---

## 13. FAQ

**Q: Do I need all the agents listed above?**
A: No. Start with Lead + Code Expert + Scribe + @copilot. Add more as your squad matures.

**Q: Can I use a different character universe?**
A: Yes. Check the `casting-policy.json` for approved universes. Add your own via PR to the org squad.

**Q: What if two agents disagree?**
A: Lead agent has final say. If it's a security matter, Security agent can veto. Human decision maker is the ultimate escalation.

**Q: How do I add a new agent?**
A: Create `.squad/agents/{name}/charter.md`, add to `.squad/team.md`, add routing rules in `.squad/routing.md`, add `.github/agents/{name}.agent.md`.

**Q: How do I contribute a skill upstream?**
A: Create the skill in `.squad/skills/{name}/SKILL.md`, test it locally, then PR to the org squad repo.

**Q: What models should I use?**
A: Start with `claude-sonnet-4.5` (standard tier). Use `claude-haiku-4.5` for background/routine agents. Only use Opus for mission-critical decisions.

---

## Appendix A: Glossary

| Term | Definition |
|------|-----------|
| **Squad** | Multi-agent AI framework by Brady Gaster, runs in Copilot CLI/VS Code |
| **Agent** | AI persona with defined role, expertise, and constraints |
| **Charter** | Agent's configuration file defining personality and responsibilities |
| **Scribe** | Background agent that logs sessions and tracks decisions |
| **Coordinator** | The orchestration layer that routes work to agents |
| **Universe** | Character theme for agent personas (Star Trek, Marvel, etc.) |
| **Upstream** | The org-level squad configuration that flows down to swimlanes |
| **Swimlane** | A team or workstream within DK8S |
| **MCP** | Model Context Protocol — standard for connecting AI to external tools |
| **Casting Policy** | Rules for which character universes are allowed |
| **Ceremony** | Structured team activity (design review, retro, model review) |
