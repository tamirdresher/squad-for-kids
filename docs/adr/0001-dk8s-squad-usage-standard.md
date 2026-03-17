# ADR 0001: DK8S Squad Usage Standard

| Field | Value |
|-------|-------|
| **Status** | Proposed |
| **Date** | 2026-03-17 |
| **Deciders** | Tamir Dresher, DK8S Platform Leads |
| **Issue** | [#771](https://github.com/tamirdresher_microsoft/tamresearch1/issues/771) |

## Context

DK8S is adopting Squad — a multi-agent AI framework — across all swimlanes. Without a standard, each engineer and team will implement Squad differently, leading to:

- Inconsistent agent configurations and naming
- No shared agents for cross-team activities (vulnerability management, CI/CD health, dependency updates)
- No upstream inheritance path from org-level to swimlane to personal squads
- Duplicated effort across swimlanes creating similar agents independently
- No clear escalation path when agents encounter situations beyond their scope

Adir requested a clear baseline so engineers don't each implement Squad differently. This ADR formalizes the proposed standard.

## Decision

We adopt a **three-tier squad hierarchy** with **upstream inheritance**:

### 1. Org Squad (`microsoft-mtp/dk8s-squad`)

A central repository containing:
- Org-wide `squad.config.ts` with default models, fallback chains, and governance rules
- Shared agent charters for cross-team responsibilities
- Standard `.squad/` directory structure (team.md, routing.md, decisions.md, ceremonies.md)
- GitHub Actions workflows for squad automation (triage, assignment, CI, notifications)
- This standard document and future org-level standards

### 2. Swimlane Squads (per-repo)

Each swimlane repo extends the org squad with:
- Domain-specific agents (e.g., compliance officer for FedRAMP, drift detector for infrastructure)
- Swimlane-specific routing rules and overrides
- Swimlane-level decisions and ceremonies
- Custom skills for domain workflows

### 3. Personal Squads (per-engineer)

Each engineer configures a personal squad with:
- Preferred character universe
- Model preference overrides
- Personal productivity agents
- Local MCP server connections

### Override Priority

```
Personal config > Swimlane config > Org config
```

### Required Configuration Files

Every squad-enabled repo must contain:

| File | Purpose | Required |
|------|---------|----------|
| `squad.config.ts` | Machine-readable config (models, routing, casting) | ✅ Yes |
| `.squad/team.md` | Team roster (humans + agents) | ✅ Yes |
| `.squad/routing.md` | Work routing rules | ✅ Yes |
| `.squad/decisions.md` | Decision log | ✅ Yes |
| `.squad/ceremonies.md` | Team ceremonies | Recommended |
| `.squad/casting-policy.json` | Allowed universes | Recommended |
| `.squad/agents/{name}/charter.md` | Agent charters | ✅ Yes (per agent) |
| `.github/copilot-instructions.md` | @copilot behavior rules | ✅ Yes |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR quality gates | ✅ Yes |

### Minimum Agent Roster

Every squad must include at minimum:

1. **Lead** — architecture, decisions, triage
2. **Code Expert** — code generation, review, clean code
3. **Scribe** — session logging, decision tracking (always background)
4. **@copilot** — autonomous small tasks (GitHub built-in)

### Standard Workflows

- **Branch naming:** `squad/{issue-number}-{brief-description}`
- **Commit format:** `{type}({scope}): {summary} (#{issue})`
- **Issue triage:** `squad` label → Lead triages → `squad:{agent}` label → agent works
- **PR template:** quality gates checklist (tests, security, review, docs, churn)

### Cross-Team Ownership

Org-level squad owns these cross-team activities:

| Activity | Cadence |
|----------|---------|
| Vulnerability management | Continuous + weekly report |
| CI/CD pipeline health | Daily checks |
| Dependency updates | Weekly PR batches |
| Code quality cleanup | Monthly sweeps |
| Documentation freshness | Bi-weekly audit |
| Config drift detection | Daily |

### Communication

- Teams webhooks for agent-to-human communication
- Plain text messages only (no adaptive cards)
- Thread replies for conversation continuity

## Consequences

### Positive

- **Consistency** — every DK8S team sets up Squad the same way
- **Shared ownership** — cross-team activities have dedicated agents, not ad-hoc handling
- **Personal customization** — engineers keep autonomy over their local experience
- **Upstream inheritance** — org-level improvements automatically flow to all teams
- **Clear escalation** — defined paths for security, architecture, infrastructure issues
- **Knowledge sharing** — skills and agents can be contributed upstream for org-wide use

### Negative

- **Initial setup cost** — teams need to create the required files and configure agents
- **Maintenance burden** — org squad needs active maintainers from each swimlane
- **Learning curve** — engineers unfamiliar with Squad need onboarding time
- **Sync overhead** — upstream changes need manual PR review before flowing downstream

### Risks

- **Adoption resistance** — mitigated by making the standard practical (not theoretical) and starting with minimal required setup
- **Config drift** — mitigated by automated drift detection workflows
- **Over-engineering** — mitigated by requiring only 4 minimum agents; rest are optional

## Alternatives Considered

### 1. No Standard (Status Quo)

Each engineer configures Squad independently. Rejected because it leads to inconsistency, duplicated effort, and no shared cross-team ownership.

### 2. Single Monorepo Squad

One repo with all agents for all swimlanes. Rejected because it doesn't allow swimlane-specific customization and creates a bottleneck for changes.

### 3. Fully Automated Inheritance

Org changes auto-merge to swimlane repos without review. Rejected because it risks breaking swimlane-specific configurations and removes human oversight.

## Related

- [DK8S Squad Usage Standard (full document)](../dk8s-squad-usage-standard.md)
- [Squad Framework by Brady Gaster](https://github.com/bradygaster/squad)
- `.squad/decisions.md` — ongoing decision log
- `.squad/routing.md` — work routing rules
