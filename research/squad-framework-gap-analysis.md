# Gap Analysis: bradygaster/squad vs. Research Squad

> Detailed feature comparison between the upstream Squad framework and our research squad implementation.

## Architecture Comparison

| Dimension | bradygaster/squad | Our Research Squad |
|-----------|-------------------|-------------------|
| **Config format** | `squad.config.ts` (TypeScript SDK) | `.squad/*.md` (Markdown files) |
| **Package** | npm monorepo (`squad-sdk` + `squad-cli`) | Markdown-only, no runtime |
| **Agent count** | 20 agents (Mission Control theme) | 6 agents (Star Trek TNG theme) |
| **Agent focus** | Software development lifecycle | Research & investigation lifecycle |
| **Repository model** | Single-repo | Multi-repo (production + research) |
| **Casting** | Multi-universe with overflow strategy | Label-based JSON policy |
| **Skills system** | 11 learned skills | None (charters only) |
| **Plugin marketplace** | GitHub repo-based plugins | Not implemented |
| **CLI tooling** | Full CLI (`squad init/build/run/status`) | No CLI (pure markdown) |

---

## Feature-by-Feature Comparison

### 1. Team Definition

**Upstream:**
```typescript
defineTeam({
  name: 'squad-sdk',
  description: '...',
  projectContext: '...',
  members: ['keaton', 'verbal', ...],
})
```
- Members are agent names only
- No human team member concept
- No interaction channel preferences

**Ours:**
```markdown
| Tamir Dresher | 👤 Human — Project Owner | — | 👤 Human |
```
- Human members with interaction channels (Teams, GitHub Issues)
- Clear delegation model ("present work and wait for input")
- Status differentiation: ✅ Active, 📋 Silent, 🔄 Monitor, 👤 Human

**Gap:** Upstream has no way to model human stakeholders in the team roster. This matters for real teams where AI agents need to know when to escalate to humans.

**Recommendation:** Extend `defineTeam` to support `humanMembers` with contact preferences.

---

### 2. Routing

**Upstream:**
```typescript
defineRouting({
  rules: [
    { pattern: 'core-runtime', agents: ['@fenster'], description: '...' },
  ],
  defaultAgent: '@keaton',
  fallback: 'coordinator',
})
```
- Pattern-based routing to agents
- Module ownership table (primary + secondary)
- 7 routing principles (eager spawning, fan-out, etc.)

**Ours:**
```markdown
| Agent | Primary Domain | Work Types |
| Geordi | Technology scanning | Tool/framework monitoring, HackerNews scanning |
```
- Domain-based routing (investigation-focused)
- Label-based routing (`squad:geordi`, `research:request`)
- Cross-repo routing rules (Production → Research, Research → Production)
- Research lifecycle states

**Gap:** Upstream routing is code-centric (module paths, test types). No pattern for:
- Cross-repository work routing
- Label-based automatic agent assignment
- Non-code work types (research, investigation, analysis)

**Recommendation:** Add `crossRepoRouting` and `labelTriggers` to `defineRouting`.

---

### 3. Ceremonies

**Upstream (2 ceremonies):**

| Ceremony | Trigger | When |
|----------|---------|------|
| Design Review | Auto — multi-agent task on shared systems | Before work |
| Retrospective | Auto — build/test failure or reviewer rejection | After failure |

**Ours (3 ceremonies):**

| Ceremony | Trigger | Frequency |
|----------|---------|-----------|
| Symposium | Scheduled | Bi-weekly |
| Backlog Review | Scheduled | Weekly |
| Failed Research Review | As needed | On failure |

**Gap:** Upstream ceremonies are reactive (triggered by failures or multi-agent tasks). Our ceremonies include:
- **Scheduled ceremonies** — Not tied to failures, but to regular cadence
- **Presentation/review format** — Structured agenda with time boxes
- **Decision-making protocol** — Adopt/archive outcomes
- **Positive ceremonies** — Not just failure-driven (Symposium celebrates findings)

**Recommendation:** Extend `defineCeremony` to support `frequency` (scheduled), `agenda` (structured format), and `outcomes` (decision types).

---

### 4. Research Lifecycle

**Upstream:** No concept. Work flows through issues → branches → PRs → merge.

**Ours:**
```
Backlog → Active → {Completed|Failed} → Symposium Presentation → {Adopt|Archive}
```

- Research can *fail* and that's a valid outcome
- Failed research is documented with lessons learned
- All outcomes require formal presentation before adoption
- `research/active/`, `research/failed/` directory convention

**Gap:** This is a completely new concept for the Squad framework. Most teams have work that isn't code — evaluations, architecture decisions, vendor comparisons. The lifecycle model captures this.

**Recommendation:** Add a `defineWorkflow` or `defineLifecycle` builder to the SDK for custom work state machines.

---

### 5. Cross-Repo Communication

**Upstream:** Not supported. Each squad is scoped to a single repository.

**Ours:**
- Ralph-R monitors both `tamresearch1` and `tamresearch1-research`
- Creates mirror issues for cross-repo requests
- Labels: `research:request`, `research:findings`, `research:failed`
- Posts findings back to production issues as comments

**Gap:** This is the biggest architectural gap. Real organizations have:
- Frontend/backend repo splits
- Library/consumer relationships
- Research/production separation

**Recommendation:** Add `defineSquadLink` or `defineRemoteSquad` for cross-repo agent communication. Consider a "federation" model where squads declare their interfaces.

---

### 6. Work Monitor (Ralph)

**Upstream:** `ralph-triage.js` — JavaScript template for issue triage logic.

**Ours:** `ralph-watch.ps1` — Production-grade monitoring script with:
- Structured logging to `~/.squad/ralph-watch.log`
- Heartbeat file at `~/.squad/ralph-heartbeat.json`
- Teams alerts on consecutive failures (>3)
- Single-instance guard (system mutex + lockfile + process scan)
- Log rotation (500 entries / 1MB cap)
- Exit code tracking, round counting, duration metrics
- PowerShell 7+ requirement validation
- UTF-8 encoding fixes for Windows

**Gap:** Upstream Ralph handles *what* to triage. Our Ralph-Watch handles *operational reliability* of the monitoring process itself. These are complementary.

**Recommendation:** Contribute ralph-watch observability patterns as a template. Consider a `squad watch --observable` flag in the CLI.

---

### 7. Decisions Framework

**Upstream:**
- `decisions.md` with structured decisions (foundational + sprint directives)
- `decisions-archive.md` for historical decisions
- Merge driver (`merge=union`) for conflict-free git merges
- Decisions organized by decision-maker and version

**Ours:**
- `decisions.md` with format specification
- `decisions/inbox/` directory for async submission
- Per-agent decision submission pattern

**Gap:** Upstream is more mature here. Their merge driver and archive system is production-tested. Our inbox pattern is simpler but less battle-tested.

**Recommendation:** Adopt upstream's merge driver pattern. Contribute our inbox pattern as an alternative for async decision-making in distributed teams.

---

### 8. Skills System

**Upstream:** 11 learned skills in `.squad/skills/`:
- `architectural-proposals`, `cli-wiring`, `client-compatibility`
- `git-workflow`, `history-hygiene`, `init-mode`, `model-selection`
- `release-process`, `reviewer-protocol`, `secret-handling`, `squad-conventions`

**Ours:** No skills system (charters contain all knowledge).

**Gap:** Skills are a powerful abstraction for shared, cross-agent knowledge. Our charters inline everything, which doesn't scale.

**Recommendation:** Adopt skills from upstream. Consider contributing research-specific skills (e.g., `research-methodology`, `cross-repo-triage`, `failed-experiment-documentation`).

---

### 9. Casting System

**Upstream:**
```typescript
defineCasting({
  allowlistUniverses: ['The Usual Suspects', 'Breaking Bad', 'The Wire', 'Firefly'],
  overflowStrategy: 'generic',
})
```
- Universe-based persona theming
- Alumni system for retired personas
- Casting history and registry JSON files

**Ours:**
```json
{
  "castingPolicy": {
    "rules": [
      { "trigger": "label", "pattern": "squad:guinan", "agent": "guinan" }
    ]
  }
}
```
- Label-based trigger routing
- Simpler but more operationally focused

**Gap:** Different design goals. Upstream focuses on persona *creation*. Ours focuses on work *routing*. Both are useful.

**Recommendation:** Propose adding `triggers` to the casting policy alongside universe-based assignment.

---

## Copilot Platform Integration Opportunities

These are enhancements that leverage newer Copilot platform features, applicable to *all* squads:

| Feature | What It Enables | Exists Upstream? |
|---------|----------------|-----------------|
| **Copilot Hooks** | Enforce ceremony participation, PR review gates, decision logging | Partially (hooks module exists for security) |
| **Copilot Memory** | Persist research context across sessions (e.g., "Geordi evaluated X last week") | ❌ No |
| **Copilot Spaces** | Shared knowledge bases for squad research findings | ❌ No |
| **MCP Server for Squad Ops** | Query squad state, trigger ceremonies, route work via MCP tools | ❌ No (MCP config only, no squad-specific server) |
| **Agentic Workflow Templates** | Pre-built patterns for research, triage, review workflows | ❌ No |
| **Enhanced Charter Schema** | Machine-readable charter sections for agent capabilities | ❌ No (free-form markdown) |

---

## Summary: What's Generalizable vs. Domain-Specific

### ✅ Generalizable (Contribute Upstream)

1. Cross-repo squad communication pattern
2. Research/investigation squad template
3. Symposium and scheduled ceremony templates
4. Failed research/experiment documentation pattern
5. Ralph-Watch observability (structured logging, heartbeat, mutex)
6. Human team member modeling
7. Label-based casting triggers
8. Research lifecycle state machine
9. Current focus tracking (`identity/now.md`)

### ⚠️ Template Only (Good as Examples)

10. Star Trek TNG universe casting (specific theme, but demonstrates the pattern)
11. Research-specific routing domains (shows non-code routing patterns)
12. Backlog review ceremony (shows scheduled ceremony pattern)

### ❌ Not Generalizable (Too Specific)

13. DK8S-specific routing rules
14. Microsoft Teams alerting integration (enterprise-specific)
15. tamresearch1/tamresearch1-research specific repo names
16. PowerShell-only monitoring (limits cross-platform adoption)
