# Work Routing

How to decide who handles what.

## Routing Table

| Work Type | Route To | Examples |
|-----------|----------|----------|
| {domain 1} | {Name} | {example tasks} |
| {domain 2} | {Name} | {example tasks} |
| {domain 3} | {Name} | {example tasks} |
| Code review | {Name} | Review PRs, check quality, suggest improvements |
| Testing | {Name} | Write tests, find edge cases, verify fixes |
| Scope & priorities | {Name} | What to build next, trade-offs, decisions |
| News broadcasts, daily briefings, status updates | Neelix | Styled squad activity reports, Teams delivery |
| Async issue work (bugs, tests, small features) | @copilot 🤖 | Well-defined tasks matching capability profile |
| Session logging | Scribe | Automatic — never needs routing |

## Issue Routing

| Label | Action | Who |
|-------|--------|-----|
| `squad` | Triage: analyze issue, evaluate @copilot fit, assign `squad:{member}` label | Lead |
| `squad:{name}` | Pick up issue and complete the work | Named member |
| `squad:copilot` | Assign to @copilot for autonomous work (if enabled) | @copilot 🤖 |

## Status Label Taxonomy

Status labels describe where an issue stands. Use the most specific label — avoid `status:pending-user` (deprecated).

| Label | Color | When to use |
|-------|-------|-------------|
| `status:needs-action` | 🔴 red | Tamir must physically DO something (approve, reply, fill form, rotate key) |
| `status:needs-decision` | 🟣 purple | Tamir must make a directional call before squad can proceed |
| `status:needs-review` | 🟠 amber | Tamir needs to read and give feedback (PR, doc, plan) |
| `status:waiting-external` | 🔵 blue | Waiting on someone/something outside the squad — no action needed from Tamir |
| `status:in-progress` | 🟡 yellow | Squad is actively working on this |
| `status:blocked` | 🔴 dark | Hard-blocked on a dependency or technical issue |
| `status:scheduled` | 🔷 teal | Planned, not yet started — sitting in queue intentionally |
| `status:postponed` | 🟡 yellow | Deliberately deferred — waiting for a future event |
| `status:done` | 🟢 green | Complete |

### Quick Decision Guide for Agents

```
Is Tamir reviewing something someone produced?   → status:needs-review
Does Tamir need to choose between options?        → status:needs-decision
Does Tamir need to DO a specific concrete task?   → status:needs-action
Is everyone just waiting for an external event?   → status:waiting-external
```

> ⚠️ `status:pending-user` is **deprecated** as of 2026-06-07. Do not use it for new issues.

---

### How Issue Assignment Works

1. When a GitHub issue gets the `squad` label, the **Lead** triages it — analyzing content, evaluating @copilot's capability profile, assigning the right `squad:{member}` label, and commenting with triage notes.
2. **@copilot evaluation:** The Lead checks if the issue matches @copilot's capability profile (🟢 good fit / 🟡 needs review / 🔴 not suitable). If it's a good fit, the Lead may route to `squad:copilot` instead of a squad member.
3. When a `squad:{member}` label is applied, that member picks up the issue in their next session.
4. When `squad:copilot` is applied and auto-assign is enabled, `@copilot` is assigned on the issue and picks it up autonomously.
5. Members can reassign by removing their label and adding another member's label.
6. The `squad` label is the "inbox" — untriaged issues waiting for Lead review.

### Lead Triage Guidance for @copilot

When triaging, the Lead should ask:

1. **Is this well-defined?** Clear title, reproduction steps or acceptance criteria, bounded scope → likely 🟢
2. **Does it follow existing patterns?** Adding a test, fixing a known bug, updating a dependency → likely 🟢
3. **Does it need design judgment?** Architecture, API design, UX decisions → likely 🔴
4. **Is it security-sensitive?** Auth, encryption, access control → always 🔴
5. **Is it medium complexity with specs?** Feature with clear requirements, refactoring with tests → likely 🟡

## Per-Area Routing (Monorepo Support)

Squad supports per-area squad configs for large monorepos. When a task, issue, or PR is associated
with a specific subdirectory, the nearest `.squad-context.md` or `.squads/` config takes precedence
for area-specific routing — while still inheriting all root rules.

### Area Label Schema

| Label | Area | Primary Agent |
|-------|------|---------------|
| `area:platform` | `src/platform/` | B'Elanna |
| `area:platform:infra` | `src/platform/infra/` | B'Elanna |
| `area:platform:security` | Auth + secrets in platform | Worf |
| `area:api` | `src/api/` | Data |
| `area:api:breaking` | Breaking API changes | Data + Picard |
| `area:api:security` | Auth middleware | Worf |

### Area Dispatch Rules

When an issue or PR has an `area:*` label:
1. Check for a `.squads/routing.md` in the corresponding directory tree.
2. Apply area routing rules **on top of** root routing (area rules are additive).
3. HQ security gates (Worf, Crusher) **cannot be overridden** by area routing.
4. If the issue spans multiple areas, union the routing requirements.

### Discovering Which Area Owns a Path

Use `scripts/find-squad-config.ps1`:

```powershell
# Which area owns this file?
.\scripts\find-squad-config.ps1 -Path "src/platform/auth/handler.go" -ShowArea

# List all registered areas
.\scripts\find-squad-config.ps1 -All
```

### Per-Area Config Files

Area configs live alongside the code they describe:
- `src/<area>/.squad-context.md` — lightweight context (owner, key files, routing hints)
- `src/<area>/.squads/team.md` — area agent roster (references root agents by name)
- `src/<area>/.squads/routing.md` — area routing overrides
- `src/<area>/.squads/decisions/` — area-scoped decisions log

Full guide: `.squad/docs/monorepo-support.md`

---

## Feature Task Protocol

Feature-level tasks follow the **5-phase orchestration pipeline** defined in
[`.squad/orchestration-pipeline.md`](./.squad/orchestration-pipeline.md).

```
Phase 1: RESEARCH  → seven / explore agent → .squad/research/<N>-research-summary.md
Phase 2: PLAN      → picard agent          → .squad/implementations/<N>-plan.md
Phase 3: IMPLEMENT → data agent            → code changes on branch
Phase 4: REVIEW    → worf agent            → .squad/reviews/<N>-review-comments.md
Phase 5: VERIFY    → tests / build         → ✅ PR merged  or  🔁 loop back to Phase 3
```

**When to apply the full pipeline:**

| Task type | Pipeline? |
|-----------|-----------|
| New feature (any size) | ✅ Always |
| Refactor touching >1 file | ✅ Yes |
| Bug with unclear root cause | ✅ Yes |
| Well-defined single-file bug | ❌ Skip to Phase 3–5 |
| Hotfix / security patch | ⚠️ Skip Phase 1; Worf mandatory at Phase 4 |
| Docs-only / question | ❌ Route directly to Seven or coordinator |

See `.squad/orchestration-pipeline.md` for full phase definitions, file-naming
conventions, loop-back rules, and invocation shortcuts.

---

## Rules

0. **🚨 Project Owner is Tamir Dresher— NOT Brady Gaster.** Brady Gaster is the creator of the upstream Squad framework (`bradygaster/squad`). He is an external collaborator, NOT the owner of this project. ALL notifications, messages, emails, Teams messages, and communications go to **Tamir Dresher**. NEVER address messages to Brady unless Tamir explicitly asks you to contact him for a specific purpose (e.g., patent discussions, upstream contributions). When in doubt, the recipient is always Tamir.
1. **Eager by default** — spawn all agents who could usefully start work, including anticipatory downstream work.
2. **Scribe always runs** after substantial work, always as `mode: "background"`. Never blocks.
3. **Quick facts → coordinator answers directly.** Don't spawn an agent for "what port does the server run on?"
4. **When two agents could handle it**, pick the one whose domain is the primary concern.
5. **"Team, ..." → fan-out.** Spawn all relevant agents in parallel as `mode: "background"`.
6. **Anticipate downstream work.** If a feature is being built, spawn the tester to write test cases from requirements simultaneously.
7. **Issue-labeled work** — when a `squad:{member}` label is applied to an issue, route to that member. The Lead handles all `squad` (base label) triage.
8. **@copilot routing** — when evaluating issues, check @copilot's capability profile in `team.md`. Route 🟢 good-fit tasks to `squad:copilot`. Flag 🟡 needs-review tasks for PR review. Keep 🔴 not-suitable tasks with squad members.

## Iterative Retrieval Pattern (Issue #1317)

All agent delegation MUST follow the iterative retrieval pattern. This applies to every sub-agent call from the coordinator and from peer agents.

### Delegation: Pass WHY, Not Just WHAT

When spawning a sub-agent, always include **objective context** (the WHY) in the prompt:

```
BAD:  "Analyze this codebase for security vulnerabilities"
GOOD: "We're preparing a FedRAMP compliance audit (WHY). Analyze this codebase for security vulnerabilities so we can file the risk register before the Q3 deadline (OBJECTIVE)."
```

The sub-agent needs to understand:
1. **What** — the task itself
2. **Why** — the objective and business/technical reason
3. **Success criteria** — what "done" looks like so they can self-evaluate their return

### Max 3 Investigation Cycles Per Sub-Agent

Sub-agents may perform at most **3 follow-up investigation cycles** before returning results:

- **Cycle 1:** Initial investigation — gather the primary data needed
- **Cycle 2:** Fill gaps identified in cycle 1 — targeted follow-up queries
- **Cycle 3:** Final verification — confirm findings, check edge cases
- **Stop:** Return results after cycle 3. Do not continue investigating indefinitely.

If the task cannot be adequately completed in 3 cycles, return partial results with a clear note on what additional investigation would be needed and why it wasn't completed.

### Coordinator Evaluates Returns

The coordinator (or delegating agent) **must evaluate** sub-agent returns before accepting them:

1. **Does the return address the WHY?** Not just the WHAT asked — did they solve the underlying objective?
2. **Is the result complete enough to act on?** Partial results must be flagged as such.
3. **Are there obvious gaps?** If a cycle was wasted on irrelevant investigation, the coordinator may redirect and re-spawn with a more focused prompt.
4. **Reject incomplete returns** by re-spawning with the gap explicitly named: "You returned X, but the objective requires Y. Focus your next 3 cycles on Y."

### Template for Delegation

```
TASK: {specific action requested}
WHY: {objective — what are we trying to achieve and why does it matter}
SUCCESS CRITERIA: {what a complete, acceptable return looks like}
CONSTRAINT: Max 3 investigation cycles. Return results after cycle 3 even if partial.
```
9. **Feature-level tasks use the 5-phase pipeline** — any new feature, refactor touching >1 file, or bug with unclear root cause **must** go through the RESEARCH → PLAN → IMPLEMENT → REVIEW → VERIFY pipeline defined in `.squad/orchestration-pipeline.md`. Picard enforces phase ordering. Phases may not be skipped.

## Work Type → Agent

| Work Type | Primary | Secondary |
|-----------|---------|----------|
| Architecture, distributed systems, decisions | Picard | — |
| Fact-checking, verification, counter-hypothesis, review challenge | Q | Picard |
| K8s, Helm, ArgoCD, cloud native | B'Elanna | — |
| Security, Azure, networking | Worf | — |
| C#, Go, .NET, clean code | Data | — |
| Documentation, presentations, analysis | Seven | — |
| Audio content generation, TTS, markdown to audio | Podcaster | — |
| Blog writing, voice matching, content series, blog publishing | Troi | Seven |
| News, briefings, status reports, Teams updates | Neelix | Seven |
| Editorial strategy, content calendar, pipeline orchestration, audience targeting | Guinan | — |
| Video/audio production, script-to-video, multilingual content, voice cloning | Paris | — |
| Growth & SEO, algorithm optimization, analytics, A/B testing | Geordi | — |
| Content safety review, compliance, confidentiality gate (MANDATORY before publishing) | Crusher | — |
| Meetings, calendar, email, scheduling, invites, attendees, communications | Kes | Playwright + Outlook web |
| Fact-checking, verification, counter-hypothesis testing | Q | Challenge claims, verify sources, test assumptions |

---

## Event-Driven Triggers

Beyond labels and schedules, agents can be triggered automatically by system events.

### How Event Triggers Work

Event-driven triggers use GitHub Actions `workflow_run` events (and similar) to detect system conditions and create issues with squad labels — feeding directly into the existing label-based routing pipeline.

**Flow:** System event → GitHub Actions workflow → Create issue with `squad:{member}` label → Existing triage pipeline picks it up.

### Active Event Triggers

| Event | Workflow | Creates Issue With | Routed To | Since |
|-------|----------|-------------------|-----------|-------|
| CI workflow failure | `auto-triage-failures.yml` | `squad`, `github-alert`, `ci-failure` | B'Elanna (infra), Data (code), Worf (security), Seven (docs) | #805 |

### Routing Rules for Event-Created Issues

Event-triggered issues follow the same routing as manually-created issues, with these additions:

1. **`github-alert` label** — indicates the issue was created by an automated event trigger, not a human.
2. **`ci-failure` label** — specific to CI/CD failures. Other event types will get their own labels (e.g., `security-alert`, `deploy-failure`).
3. **Smart routing** — the trigger workflow classifies the failure and applies the appropriate `squad:{member}` label directly, bypassing Lead triage for known failure types.
4. **Deduplication** — if an open issue already exists for the same event (e.g., same workflow failing repeatedly), the trigger appends a comment instead of creating a new issue.

### Adding New Event Triggers

To add a new event-driven trigger:

1. Create a workflow in `.github/workflows/` that listens to the appropriate event
2. Use `github-script` to create an issue with `squad` + event-specific labels
3. Apply `squad:{member}` label for smart routing (or just `squad` to go through Lead triage)
4. Include deduplication logic (check for existing open issues before creating)
5. Add the trigger to the table above
6. Document in `docs/event-trigger-gap-analysis.md`

### Planned Event Triggers (Not Yet Implemented)

See `docs/event-trigger-gap-analysis.md` for the full gap analysis. Priority candidates:

- **Deployment failures** → `squad:belanna` (same pattern as CI failures)
- **Security alerts** (Dependabot, CodeQL findings) → `squad:worf`
- **PR review stale >24h** → reminder comment, >48h → escalate to Lead

---

## Machine Capability Routing (Issue #987)

Some issues require specific machine capabilities — a GPU, a WhatsApp session, a particular GitHub account, etc.
The `needs:*` label family declares these requirements on issues so Ralph instances can self-select work they can actually complete.

### Label → Capability Mapping

| Label | Capability key | What it means |
|-------|---------------|---------------|
| `needs:whatsapp` | `whatsapp` | Machine must have an active WhatsApp Web session |
| `needs:browser` | `browser` | Machine must have Playwright / browser automation |
| `needs:gpu` | `gpu` | Machine must have an NVIDIA GPU (nvidia-smi) |
| `needs:personal-gh` | `personal-gh` | Machine must have `tamirdresher` personal GitHub auth |
| `needs:emu-gh` | `emu-gh` | Machine must have `tamirdresher_microsoft` EMU auth |
| `needs:teams-mcp` | `teams-mcp` | Machine must have Teams MCP tools available |
| `needs:onedrive` | `onedrive` | Machine must have OneDrive folder synced |
| `needs:azure-speech` | `azure-speech` | Machine must have Azure Speech SDK / credentials |

### How It Works

1. **Discovery:** `scripts/discover-machine-capabilities.ps1` probes the local machine and writes `~/.squad/machine-capabilities.json`.
2. **Startup:** Ralph runs the discovery script on its first round (and every 50th round to stay fresh).
3. **Filtering:** Before picking up an issue, Ralph checks all `needs:*` labels against the manifest's `capabilities` array.
4. **Skip logic:** If ANY required capability is missing, Ralph skips the issue. Another instance on a capable machine handles it.
5. **No needs labels:** Issues without `needs:*` labels can be picked up by any machine (the common case).

### Manifest Format (`~/.squad/machine-capabilities.json`)

```json
{
  "machine": "DESKTOP-ABC123",
  "capabilities": ["browser", "emu-gh", "onedrive", "teams-mcp"],
  "missing": ["gpu", "whatsapp", "personal-gh", "azure-speech"],
  "details": { ... },
  "last_updated": "2026-07-23T10:30:00Z"
}
```

### When to Add `needs:*` Labels

- **At issue creation** if the requirement is obvious (e.g., "Record Hebrew podcast" → `needs:azure-speech`)
- **During triage** when the Lead or agent identifies a machine dependency
- **Retroactively** when Ralph fails an issue due to missing tooling — add the label so it gets routed correctly next time

---

## Per-Agent Model Selection

Agents can override the platform default model based on their role requirements. Current assignments tracked in `.squad/model-assignments-snapshot.md`.

### Model Tier Guidelines

**Standard Tier** (claude-sonnet-4.5):
- Complex reasoning tasks (architecture, security, multi-step planning)
- Code generation where quality matters (Data, B'Elanna)
- Research and synthesis (Seven)
- Creative writing (Troi)
- Domain expertise (K8s, distributed systems, security)

**Fast Tier** (claude-haiku-4.5):
- High-frequency routine tasks (daily briefings, monitoring)
- Template-driven work (session logging, formatting)
- Speed-critical tasks (audio script generation)
- Background agents (Ralph, Scribe, Neelix, Podcaster)

**Premium Tier** (claude-opus-4.6):
- Mission-critical decisions with high error cost
- Novel problem spaces requiring cutting-edge reasoning
- Currently **not used** — cost vs. quality delta doesn't justify for routine work

### Model Review Process

- **Quarterly reviews:** Evaluate new models against current assignments (see `.squad/ceremonies.md` — Model Review)
- **Ad-hoc triggers:** Major model releases, quality degradation, cost spikes
- **Tech news integration:** Scanner flags model announcements → Picard evaluates within 1 week
- **Evaluation template:** `.squad/templates/model-evaluation.md` provides structured analysis framework

### How to Override Agent Model

1. Test new model with representative agent tasks
2. Use `.squad/templates/model-evaluation.md` for structured comparison
3. Document decision in `.squad/decisions/inbox/lead-model-change-{agent}.md`
4. Update `.squad/model-assignments-snapshot.md` with new assignment
5. Add model preference to agent charter (`.squad/agents/{name}/charter.md`) if persistent override needed
