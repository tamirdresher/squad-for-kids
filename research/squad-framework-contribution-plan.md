# Contribution Plan: Squad Framework PRs

> Prioritized list of contributions to [bradygaster/squad](https://github.com/bradygaster/squad), ordered by impact and feasibility.
> All PRs target the `dev` branch per upstream [CONTRIBUTING.md](https://github.com/bradygaster/squad/blob/main/CONTRIBUTING.md).

## PR Roadmap

### Phase 1: Templates & Documentation (Low Friction)

These PRs add new templates without changing runtime code. Low risk, immediate value.

---

#### PR 1: Research Squad Template
**Impact:** 🟢 High | **Effort:** Small (1-2 days) | **Type:** Template

**What:** Add a `research-squad` template to `templates/` and `.squad-templates/` that demonstrates a non-code-development squad pattern.

**Files to add:**
- `templates/research/team.md` — Research squad roster template with human members
- `templates/research/routing.md` — Investigation-focused routing rules
- `templates/research/ceremonies.md` — Symposium + Backlog Review + Failed Research Review
- `templates/research/charter-research-lead.md` — Example research lead charter
- `templates/research/charter-tech-scanner.md` — Example technology scanner charter

**Why:** Today, all Squad examples are software development teams. Research, DevRel, architecture review, and vendor evaluation teams all use similar patterns but aren't represented.

**Contribution approach:** Fork → branch `research-squad-template` → PR to `dev`.

---

#### PR 2: Extended Ceremony Templates
**Impact:** 🟢 High | **Effort:** Small (1 day) | **Type:** Template

**What:** Add ceremony templates beyond Design Review and Retrospective.

**Templates to add:**
- `templates/ceremonies/symposium.md` — Scheduled presentation + decision ceremony
- `templates/ceremonies/backlog-review.md` — Prioritization ceremony
- `templates/ceremonies/failure-analysis.md` — Post-mortem for failed work (not just test failures)

**Why:** Upstream has only 2 ceremony types (both failure-reactive). Squads need proactive ceremonies for knowledge sharing, prioritization, and learning from failures.

---

#### PR 3: Human Team Member Section in Roster Template
**Impact:** 🟡 Medium | **Effort:** Small (half day) | **Type:** Template

**What:** Add a `## Human Members` section to `templates/roster.md` showing how to model humans.

**Example addition:**
```markdown
## Human Members

| Name | Role | Interaction Channel | Notes |
|------|------|---------------------|-------|
| {Name} | {Role} | {Preferred channel} | {How to interact} |
```

**Why:** Real squads have human stakeholders. Agents need to know when to escalate, how to present work, and preferred communication channels.

---

#### PR 4: Research Lifecycle Documentation
**Impact:** 🟡 Medium | **Effort:** Small (half day) | **Type:** Documentation

**What:** Add a `docs/workflows/research-lifecycle.md` explaining the research lifecycle pattern.

**Content:**
- State machine: `Backlog → Active → {Completed|Failed} → Presentation → {Adopt|Archive}`
- Why failed research is valuable
- Directory convention: `research/active/`, `research/failed/`, `research/completed/`
- Integration with Symposium ceremony

**Why:** This is a reusable workflow pattern, not specific to our implementation.

---

### Phase 2: SDK Enhancements (Medium Friction)

These PRs extend the SDK with new builder functions. Requires design alignment with upstream maintainer.

---

#### PR 5: `defineLifecycle` Builder
**Impact:** 🟢 High | **Effort:** Medium (3-5 days) | **Type:** SDK

**What:** Add a `defineLifecycle` function to `@bradygaster/squad-sdk` for custom work state machines.

**Proposed API:**
```typescript
defineLifecycle({
  name: 'research',
  states: ['backlog', 'active', 'completed', 'failed', 'presented', 'adopted', 'archived'],
  transitions: [
    { from: 'backlog', to: 'active', label: 'Start research' },
    { from: 'active', to: 'completed', label: 'Research complete' },
    { from: 'active', to: 'failed', label: 'Research failed' },
    { from: ['completed', 'failed'], to: 'presented', label: 'Present at ceremony' },
    { from: 'presented', to: 'adopted', label: 'Adopt findings' },
    { from: 'presented', to: 'archived', label: 'Archive' },
  ],
  defaultState: 'backlog',
})
```

**Pre-requisite:** Submit as `docs/proposals/lifecycle-builder.md` first (upstream requires proposals before code).

---

#### PR 6: Cross-Repo Squad Links
**Impact:** 🟢 High | **Effort:** Large (5-7 days) | **Type:** SDK

**What:** Add `defineSquadLink` for declaring relationships between squads in different repositories.

**Proposed API:**
```typescript
defineSquadLink({
  name: 'production',
  repository: 'owner/production-repo',
  direction: 'bidirectional',
  labels: {
    requestInbound: 'research:request',
    findingsOutbound: 'research:findings',
    failed: 'research:failed',
  },
  bridge: 'ralph', // Agent responsible for cross-repo communication
})
```

**Pre-requisite:** Submit design proposal. This is architecturally significant — needs upstream buy-in.

---

#### PR 7: Extended Ceremony Schema
**Impact:** 🟡 Medium | **Effort:** Medium (2-3 days) | **Type:** SDK

**What:** Extend `defineCeremony` (or create it — ceremonies are currently markdown-only) with:

```typescript
defineCeremony({
  name: 'symposium',
  trigger: 'scheduled',
  frequency: 'biweekly',
  facilitator: 'research-lead',
  participants: 'all-active',
  agenda: [
    { item: 'Research cycle summary', duration: '5min', owner: 'lead' },
    { item: 'Findings presentations', duration: '30min', owner: 'researchers' },
    { item: 'Discussion', duration: '15min', owner: 'all' },
    { item: 'Adoption decisions', duration: '10min', owner: 'lead' },
  ],
  outcomes: ['adopt', 'archive', 'continue'],
})
```

---

### Phase 3: Copilot Platform Integration (Higher Friction)

These leverage newer Copilot platform capabilities. May require coordination with the GitHub Copilot team.

---

#### PR 8: Ralph-Watch Observability Template
**Impact:** 🟡 Medium | **Effort:** Medium (2-3 days) | **Type:** Template + Code

**What:** Contribute a cross-platform Ralph monitoring template with:
- Structured JSON logging
- Heartbeat file pattern
- Single-instance guard (mutex/lockfile)
- Configurable alerting hooks (not Teams-specific)
- Log rotation

**Considerations:** Current ralph-watch.ps1 is PowerShell-only. Upstream is Node.js-based. Would need to either:
- Port core patterns to a Node.js `ralph-monitor.mjs` template
- Or document the patterns and let upstream implement natively

**Recommendation:** Port to Node.js for upstream contribution, keep PS1 for our internal use.

---

#### PR 9: MCP Server for Squad Operations
**Impact:** 🟢 High | **Effort:** Large (7-10 days) | **Type:** SDK + New Package

**What:** Create `@bradygaster/squad-mcp` — an MCP server that exposes squad state as tools:
- `squad_list_agents` — List team members and statuses
- `squad_get_decisions` — Read current decisions
- `squad_route_work` — Route work to agents
- `squad_ceremony_status` — Check ceremony schedules
- `squad_get_lifecycle_state` — Query work item states

**Why:** Enables other AI tools and Copilot sessions to query and interact with squad state. This is the foundation for cross-squad federation.

---

#### PR 10: Copilot Memory Integration Guide
**Impact:** 🟡 Medium | **Effort:** Small (1-2 days) | **Type:** Documentation

**What:** Document patterns for using Copilot Memory (`store_memory` / session store) with Squad:
- Persisting research context across sessions
- Agent learning patterns (what skills to remember)
- Cross-session decision continuity

---

## Contribution Summary

| # | PR Title | Impact | Effort | Phase |
|---|----------|--------|--------|-------|
| 1 | Research Squad Template | 🟢 High | Small | 1 |
| 2 | Extended Ceremony Templates | 🟢 High | Small | 1 |
| 3 | Human Team Members in Roster | 🟡 Medium | Small | 1 |
| 4 | Research Lifecycle Docs | 🟡 Medium | Small | 1 |
| 5 | `defineLifecycle` Builder | 🟢 High | Medium | 2 |
| 6 | Cross-Repo Squad Links | 🟢 High | Large | 2 |
| 7 | Extended Ceremony Schema | 🟡 Medium | Medium | 2 |
| 8 | Ralph-Watch Observability | 🟡 Medium | Medium | 3 |
| 9 | Squad MCP Server | 🟢 High | Large | 3 |
| 10 | Copilot Memory Guide | 🟡 Medium | Small | 3 |

## Getting Started

1. Fork `bradygaster/squad`
2. Clone and set up per [CONTRIBUTING.md](https://github.com/bradygaster/squad/blob/main/CONTRIBUTING.md)
3. Start with PR 1 (Research Squad Template) — low risk, demonstrates our innovations
4. Open an issue first to discuss PR 5-6 (SDK changes need alignment)
5. Use `npx changeset add` before each PR

## Upstream Contribution Guidelines

Per upstream CONTRIBUTING.md:
- PRs target `dev` branch (not `main`)
- Changesets required (`npx changeset add`)
- Branch naming: `{username}/{issue-number}-{slug}`
- Design proposals required before SDK changes (`docs/proposals/`)
- Co-authored-by trailer required on commits
- All code is MIT licensed
