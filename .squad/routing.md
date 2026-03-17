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

## Rules

0. **🚨 Project Owner is Tamir Dresher — NOT Brady Gaster.** Brady Gaster is the creator of the upstream Squad framework (`bradygaster/squad`). He is an external collaborator, NOT the owner of this project. ALL notifications, messages, emails, Teams messages, and communications go to **Tamir Dresher**. NEVER address messages to Brady unless Tamir explicitly asks you to contact him for a specific purpose (e.g., patent discussions, upstream contributions). When in doubt, the recipient is always Tamir.
1. **Eager by default** — spawn all agents who could usefully start work, including anticipatory downstream work.
2. **Scribe always runs** after substantial work, always as `mode: "background"`. Never blocks.
3. **Quick facts → coordinator answers directly.** Don't spawn an agent for "what port does the server run on?"
4. **When two agents could handle it**, pick the one whose domain is the primary concern.
5. **"Team, ..." → fan-out.** Spawn all relevant agents in parallel as `mode: "background"`.
6. **Anticipate downstream work.** If a feature is being built, spawn the tester to write test cases from requirements simultaneously.
7. **Issue-labeled work** — when a `squad:{member}` label is applied to an issue, route to that member. The Lead handles all `squad` (base label) triage.
8. **@copilot routing** — when evaluating issues, check @copilot's capability profile in `team.md`. Route 🟢 good-fit tasks to `squad:copilot`. Flag 🟡 needs-review tasks for PR review. Keep 🔴 not-suitable tasks with squad members.

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
