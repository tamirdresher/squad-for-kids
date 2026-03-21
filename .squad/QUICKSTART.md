# Squad HQ — Customer Quickstart Guide

> **Goal:** Fork → configure → running Squad in under 5 minutes. This is your Squad "hello world."

---

## What Is Squad?

**Squad** is an AI agent team framework built on top of [`bradygaster/squad`](https://github.com/bradygaster/squad). It gives you a fully functional, opinionated AI team that lives inside your GitHub repository — no separate SaaS, no vendor lock-in, just files and agents.

### What you get out of the box

| Component | What it does |
|-----------|-------------|
| **Agent team** | Pre-configured specialists: Lead, Code, Infra, Security, Research, Comms, and more |
| **Ralph** | Automated work monitor — watches your issue board, triages new issues, keeps the queue honest |
| **Skills system** | Pluggable capabilities agents can learn: code review, blog writing, deployment, Kubernetes, etc. |
| **Daily briefing** | Morning report summarizing what happened, what's pending, what needs your attention |
| **Decision log** | Structured inbox pattern for capturing team decisions across sessions |
| **Scheduling** | Automated ceremonies, periodic tasks, and cross-machine coordination via `schedule.json` |
| **Routing engine** | Label-based and rule-based routing so the right agent picks up the right work |

### What makes Squad different

Squad agents are **persistent personas**, not stateless functions. Each agent has a charter (identity, domain, voice, boundaries), reads team decisions before starting work, and writes decisions back when they make choices others should know about. The whole system is version-controlled in `.squad/` alongside your code.

---

## Prerequisites

Before you start, make sure you have:

- **GitHub repository** — Squad lives in your repo's `.squad/` directory
- **`gh` CLI** — [Install](https://cli.github.com/) and authenticate: `gh auth login`
- **`git`** — standard git tooling
- **GitHub Copilot** — either the VS Code extension or `github-copilot-cli`
- **PowerShell 7+** (pwsh) — required for Ralph and squad scripts on Windows; also works on macOS/Linux
- **Node.js 18+** — for `squad.config.ts` and the tech-news scanner

### Optional but recommended

| Tool | Why |
|------|-----|
| GitHub Copilot MCP servers | Gives agents access to Teams, calendar, email, ADO, browser automation |
| `TEAMS_WEBHOOK_URL` secret | Enables Squad → Teams notifications |
| Docker Desktop | For local containerized deployment |

---

## Step 1: Fork the Template

```bash
# Option A: Fork via GitHub (recommended)
# Go to: https://github.com/bradygaster/squad
# Click "Fork" → create under your org or personal account

# Option B: Use gh CLI
gh repo fork bradygaster/squad --clone --org YOUR_ORG
cd squad
```

After forking, the repository already contains a `.squad/` skeleton. Everything Squad needs lives there.

---

## Step 2: Set Required Secrets

Go to **Settings → Secrets and variables → Actions** in your new repo and add:

| Secret | Required | Description |
|--------|----------|-------------|
| `GH_TOKEN` | ✅ Yes | Personal access token with `repo`, `read:org`, `workflow` scopes |
| `TEAMS_WEBHOOK_URL` | Recommended | Incoming webhook URL for your Teams channel (Squad notifications) |
| `OPENAI_API_KEY` | Optional | If you want to use OpenAI models as fallback |
| `AZURE_OPENAI_API_KEY` | Optional | Azure OpenAI endpoint credentials |
| `AZURE_SPEECH_KEY` | Optional | Required for TTS / podcast features |

> **Tip:** `GH_TOKEN` is the only hard requirement. Start with just that and add others as you explore Squad features.

---

## Step 3: Configure Squad

Edit `squad.config.ts` in the repo root. This is the central configuration file:

```typescript
import type { SquadConfig } from '@bradygaster/squad';

const config: SquadConfig = {
  version: '1.0.0',

  models: {
    defaultModel: 'claude-sonnet-4.5',   // Your preferred default model
    defaultTier: 'standard',
    fallbackChains: {
      premium: ['claude-opus-4.6', 'claude-sonnet-4.5'],
      standard: ['claude-sonnet-4.5', 'gpt-5.2-codex'],
      fast: ['claude-haiku-4.5', 'gpt-4.1']
    }
  },

  routing: {
    governance: {
      eagerByDefault: true,   // Agents start work proactively
      scribeAutoRuns: false,  // Scribe logs after substantial work
      allowRecursiveSpawn: false
    }
  }
};

export default config;
```

**Key settings to adjust:**
- `defaultModel` — The model all agents use unless they override it
- `eagerByDefault` — When `true`, agents spawn proactively for anticipated work
- `fallbackChains` — If your preferred model is unavailable, Squad tries the next one

---

## Step 4: Set Up the `.squad/` Directory Structure

The `.squad/` directory is Squad's filesystem. Here's what matters most:

```
.squad/
├── team.md                   # Roster — who's on the team and their roles
├── routing.md                # Work routing rules — who handles what
├── decisions.md              # Persistent team decision log
├── ceremonies.md             # Team ceremonies (Design Review, Retro, etc.)
├── schedule.json             # Automated task schedules
├── config.json               # Machine-level Squad config
├── agents/
│   ├── picard/charter.md     # Lead agent — architecture, decisions
│   ├── ralph/charter.md      # Work monitor — triage, queue tracking
│   ├── data/charter.md       # Code expert — C#, Go, .NET
│   ├── belanna/charter.md    # Infrastructure — K8s, Helm, cloud
│   ├── worf/charter.md       # Security & cloud
│   ├── seven/charter.md      # Research & docs
│   └── ...                   # One charter.md per agent
├── skills/
│   ├── code-review/          # Each skill is a directory with SKILL.md
│   ├── blog-writing/
│   └── ...
├── decisions/
│   └── inbox/                # Agents drop decisions here; Scribe merges them
└── orchestration-log/        # Session logs (auto-generated)
```

### The two most important files to edit first

**`.squad/team.md`** — Define your roster:
```markdown
## Members

| Name    | Role                | Charter                          | Status    |
|---------|---------------------|----------------------------------|-----------|
| Picard  | Lead                | `.squad/agents/picard/charter.md`| ✅ Active |
| Ralph   | Work Monitor        | `.squad/agents/ralph/charter.md` | 🔄 Monitor|
| Data    | Code Expert         | `.squad/agents/data/charter.md`  | ✅ Active |
```

**`.squad/routing.md`** — Wire up work types to agents:
```markdown
## Work Type → Agent

| Work Type        | Primary  | Secondary |
|------------------|----------|-----------|
| Code review, bugs| Data     | —         |
| Infra, K8s       | B'Elanna | —         |
| Documentation    | Seven    | —         |
| Security         | Worf     | —         |
```

---

## Step 5: Configure Your Agents

Each agent lives in `.squad/agents/{name}/charter.md`. The charter defines the agent's identity, domain, boundaries, and voice. Here's the minimal template:

```markdown
# {Name} — {Role}

> {One-line personality statement}

## Identity

- **Name:** Picard
- **Role:** Lead
- **Expertise:** Architecture, distributed systems, decisions
- **Style:** Direct and focused.

## What I Own

- Architecture decisions
- Issue triage
- Agent coordination

## Boundaries

**I handle:** Architecture, distributed systems, decisions

**I don't handle:** Work outside my domain — the coordinator routes that elsewhere.

## Collaboration

Before starting work, read `.squad/decisions.md` for team decisions that affect me.
After making a decision others should know, write it to `.squad/decisions/inbox/{my-name}-{brief-slug}.md`.
```

> **Tip:** Copy one of the existing charters in `.squad/agents/` as a starting point. The template at `.squad/charter.md` has the full scaffold.

---

## Step 6: Configure Routing Labels

Squad uses GitHub issue labels to route work. Set up these labels in your repo:

```bash
# Create squad routing labels
gh label create "squad" --color "0052cc" --description "Untriaged — waiting for Lead review"
gh label create "squad:picard" --color "1d76db" --description "Routed to Picard (Lead)"
gh label create "squad:ralph" --color "e4e669" --description "Routed to Ralph (Work Monitor)"
gh label create "squad:data" --color "006b75" --description "Routed to Data (Code)"
gh label create "squad:belanna" --color "d93f0b" --description "Routed to B'Elanna (Infra)"
gh label create "squad:seven" --color "0075ca" --description "Routed to Seven (Docs)"

# Status labels
gh label create "status:needs-review" --color "e99695" --description "Needs Tamir's review"
gh label create "status:in-progress" --color "fbca04" --description "Squad is working on this"
gh label create "status:done" --color "0e8a16" --description "Complete"
```

---

## Step 7: Start Ralph (Your Work Monitor)

Ralph is the heartbeat of Squad. He watches your issue board, triages new issues, and keeps work moving.

### Option A: Run Ralph manually (simplest start)

```powershell
# From your repo root
agency copilot --agent ralph ".squad/agents/ralph/charter.md" "Check the issue queue and triage any new issues labeled 'squad'. Report what you find."
```

### Option B: Run Ralph on a loop (recommended)

```powershell
# ralph-watch.ps1 — runs Ralph every 5 minutes
while ($true) {
    agency copilot --agent ralph ".squad/agents/ralph/charter.md" "Run your work monitor loop."
    Start-Sleep -Seconds 300
}
```

### Option C: GitHub Actions (automated)

Create `.github/workflows/squad-heartbeat.yml`:

```yaml
name: Squad Heartbeat
on:
  schedule:
    - cron: '*/5 * * * *'   # every 5 minutes
  workflow_dispatch:

jobs:
  ralph:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Ralph
        run: agency copilot --agent ralph ".squad/agents/ralph/charter.md" "Run work monitor loop."
        env:
          GH_TOKEN: ${{ secrets.GH_TOKEN }}
```

---

## Step 8: Verify Your Setup

Run this checklist before going live:

```bash
# 1. Check gh CLI auth
gh auth status

# 2. Verify your repo is set up
gh issue list --label "squad" --limit 5

# 3. Test Ralph (dry run)
agency copilot --agent ralph ".squad/agents/ralph/charter.md" \
  "List the open issues in this repo and tell me which ones have 'squad' labels."

# 4. Confirm .squad/ structure
ls .squad/agents/
ls .squad/skills/
```

Expected output from step 3: Ralph lists issues and identifies any with `squad` labels ready for triage.

---

## Common Workflows

### Morning Briefing

Trigger a daily status report with Neelix (News Reporter):

```powershell
agency copilot --agent neelix ".squad/agents/neelix/charter.md" \
  "Generate the daily squad briefing: what happened yesterday, what's in progress, what needs attention today. Post to Teams."
```

Or use the automated schedule — add this to `.squad/schedule.json`:

```json
{
  "id": "daily-briefing",
  "name": "Daily Briefing",
  "trigger": { "type": "cron", "expression": "0 8 * * 1-5", "timezone": "UTC" },
  "task": {
    "type": "copilot",
    "instruction": "Generate and send the daily squad briefing."
  }
}
```

### Triage a New Issue

When a new issue arrives, add the `squad` label. Picard (the Lead) picks it up:

```bash
# Add squad label to trigger triage
gh issue edit 123 --add-label "squad"

# Or let Ralph catch it automatically on his next loop
```

Picard will analyze the issue, evaluate if `@copilot` can handle it autonomously, and assign the right `squad:{member}` label.

### Request a Code Review

Create an issue or comment with the `squad:data` label to route to your code expert:

```bash
gh issue create \
  --title "Review PR #456 — payment service refactor" \
  --label "squad,squad:data" \
  --body "Please review PR #456. Focus on error handling and test coverage."
```

### Tech News Scan

Neelix scans HackerNews and Reddit for relevant AI, .NET, and DevOps news:

```powershell
agency copilot --agent neelix ".squad/agents/neelix/charter.md" \
  "Run the tech news scan. Check HackerNews and relevant subreddits for .NET, AI, and Kubernetes news. Post a briefing to Teams."
```

### Generate a Weekly Digest

```powershell
# Generate a weekly summary of all squad activity
.squad\scripts\generate-digest.ps1 -Period weekly
```

Output: `.squad/digests/digest-{date}-weekly.md`

---

## Adding Custom Agents

1. **Create the charter** at `.squad/agents/{name}/charter.md`:

```markdown
# Luna — Frontend Expert

> Ships UI that works, every time.

## Identity
- **Name:** Luna
- **Role:** Frontend Expert
- **Expertise:** React, TypeScript, CSS, accessibility
- **Style:** Precise. Never ships broken UI.

## What I Own
- Frontend code review
- UI component development
- Accessibility audits
```

2. **Add to `.squad/team.md`**:

```markdown
| Luna | Frontend Expert | `.squad/agents/luna/charter.md` | ✅ Active |
```

3. **Add to `.squad/routing.md`**:

```markdown
| Frontend, React, CSS, UI | Luna | — |
```

4. **Create routing label**:

```bash
gh label create "squad:luna" --color "c2e0c6" --description "Routed to Luna (Frontend)"
```

Done. Luna can now receive issues via `squad:luna` label.

---

## Adding Custom Skills

Skills are pluggable capabilities that extend what agents know. Each skill is a directory in `.squad/skills/` with a `SKILL.md` manifest.

**Create `.squad/skills/api-testing/SKILL.md`:**

```markdown
---
name: "api-testing"
description: "Automated API contract testing with Pact"
domain: "testing"
confidence: "high"
source: "manual"
---

## Context
When to test API contracts: before any service-to-service integration changes.

## Patterns
- Use Pact for consumer-driven contract tests
- Run contract tests in CI before deployment
- Version contracts alongside API changes

## Anti-Patterns
- Don't test implementation details, test the contract
- Don't skip contract tests for "minor" API changes
```

Agents discover skills automatically when they read `.squad/skills/`.

---

## Connecting Multiple Repos

Squad can monitor multiple repositories. Edit `.squad/upstream.json`:

```json
{
  "repos": [
    { "repo": "your-org/main-app", "labels": ["squad"], "watch": true },
    { "repo": "your-org/api-service", "labels": ["squad"], "watch": true },
    { "repo": "bradygaster/squad", "watch": true, "upstream": true }
  ]
}
```

Ralph will include issues from all watched repos in his triage loop.

---

## Machine Capability Routing

When running Squad on multiple machines (e.g., desktop with GPU vs. dev machine), use `needs:*` labels to route issues to capable machines:

| Label | Capability |
|-------|-----------|
| `needs:gpu` | Machine has NVIDIA GPU |
| `needs:browser` | Playwright / browser automation available |
| `needs:whatsapp` | Active WhatsApp Web session |
| `needs:azure-speech` | Azure Speech SDK + credentials |

```bash
# Tag an issue to require GPU (e.g., audio generation)
gh issue edit 789 --add-label "needs:gpu"
```

Run capability discovery on each machine:

```powershell
.squad\scripts\discover-machine-capabilities.ps1
# Writes: ~/.squad/machine-capabilities.json
```

Ralph reads this file and only picks up issues where all `needs:*` requirements are met.

---

## Tips & Gotchas

### ✅ Do

- **Read decisions.md first** — every agent should read `.squad/decisions.md` before starting work. It holds persistent team decisions that span sessions.
- **Use inbox pattern for decisions** — agents write to `.squad/decisions/inbox/{name}-{slug}.md`; Scribe merges them. Never write directly to `decisions.md`.
- **Branch naming convention** — always `squad/{issue-number}-{slug}` (e.g., `squad/42-fix-auth`).
- **Label before you fork** — add `squad` label to issues *before* asking agents to work on them; the label is the routing trigger.
- **Let Ralph do triage** — don't manually assign `squad:{member}` labels unless you know exactly who should handle it. Ralph's triage includes @copilot fit evaluation.

### ❌ Don't

- **Don't spawn agents for quick facts** — if you know the answer, just answer it. Agent spawns are for real work.
- **Don't route security/auth issues to @copilot** — always 🔴 Not suitable. Keep with Worf or a senior agent.
- **Don't edit decisions.md directly mid-session** — use the inbox. Concurrent writes create merge conflicts.
- **Don't ignore the `squad:seven` label on docs issues** — documentation done wrong is as bad as no documentation.
- **Don't start Ralph without `GH_TOKEN`** — he can't query issues without it. Check `gh auth status` first.

### Common Failure Modes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Ralph finds no issues | `squad` label not applied | Add `squad` label to issues you want triaged |
| Agent ignores routing rules | Didn't read `routing.md` | Check the agent charter's Collaboration section |
| Decisions not persisting | Writing directly to `decisions.md` | Use inbox: `.squad/decisions/inbox/{name}-{slug}.md` |
| Wrong agent picks up work | Missing `squad:{member}` label | Picard should triage first with just `squad` label |
| Schedule not firing | `schedule.json` not linked to runner | Set up `ralph-watch.ps1` or GitHub Actions heartbeat |
| Teams notifications silent | `TEAMS_WEBHOOK_URL` not set | Add secret to repo, verify webhook URL is active |

---

## Project Board Integration

Squad uses a GitHub Project board to track work state. Issues move through columns automatically:

- **Inbox** → New issues with `squad` label (awaiting triage)
- **In Progress** → Ralph has assigned an agent; work underway
- **Review** → PR open, waiting for human or agent review
- **Done** → Closed issues, merged PRs

To move an issue on the board:

```bash
# Move to "Review" column
gh project item-edit \
  --project-id PVT_kwHOC0L5c84BRG-P \
  --id PVTI_lAHOC0L5c84BRG-Pzgn5vYs \
  --field-id PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc \
  --single-select-option-id 1807f788
```

Ralph updates board status automatically as part of his triage loop.

---

## Scheduled Automation Reference

Edit `.squad/schedule.json` to configure automated tasks. Common patterns:

```json
{
  "schedules": [
    {
      "id": "daily-briefing",
      "name": "Daily Briefing",
      "trigger": { "type": "cron", "expression": "0 8 * * 1-5", "timezone": "UTC" },
      "task": { "type": "copilot", "instruction": "Generate daily squad briefing and post to Teams." }
    },
    {
      "id": "ralph-heartbeat",
      "name": "Ralph Heartbeat",
      "trigger": { "type": "interval", "intervalSeconds": 300 },
      "task": { "type": "workflow", "ref": ".github/workflows/squad-heartbeat.yml" }
    },
    {
      "id": "weekly-retro",
      "name": "Weekly Retrospective",
      "trigger": { "type": "cron", "expression": "0 14 * * 5", "timezone": "UTC" },
      "task": { "type": "agent", "agent": "picard", "action": "retrospective" }
    }
  ]
}
```

---

## Troubleshooting

### `agency` command not found

```bash
# Install the Squad CLI
npm install -g @bradygaster/squad-cli

# Or run via npx
npx @bradygaster/squad-cli copilot ...
```

### Ralph isn't picking up issues

1. Check `gh auth status` — make sure you're authenticated
2. Check that issues have the `squad` label: `gh issue list --label squad`
3. Check machine capabilities: does the issue have a `needs:*` label your machine can't satisfy?
4. Look at `.squad/ralph-circuit-breaker.json` — if Ralph's circuit breaker tripped, reset it

### Agent not reading decisions

The agent's charter must include the Collaboration section:
```markdown
## Collaboration
Before starting work, read `.squad/decisions.md` for team decisions that affect me.
```

If it's missing, add it to the charter.

### PR not linked to issue

Make sure the PR description includes `Closes #{issue-number}` or use `gh pr create --body "Closes #123"`.

---

## Next Steps

Once Squad is running, explore these advanced topics:

| Topic | Where to look |
|-------|--------------|
| Knowledge hub (Copilot Space) | `.squad/COPILOT_SPACE_SETUP.md` |
| Knowledge management | `.squad/KNOWLEDGE_MANAGEMENT.md` |
| Digest generator | `.squad/DIGEST_GENERATOR_QUICKSTART.md` |
| Event-driven triggers | `.squad/routing.md` → Event-Driven Triggers section |
| Model selection & tuning | `.squad/routing.md` → Per-Agent Model Selection |
| Cross-machine coordination | `.squad/skills/cross-machine-coordination/` |
| Adding MCP servers | `.squad/mcp-config.md` |

---

## Reference: Key Files

| File | Purpose |
|------|---------|
| `squad.config.ts` | Central Squad configuration (models, routing, casting) |
| `.squad/team.md` | Agent roster and human members |
| `.squad/routing.md` | Work routing rules and issue label taxonomy |
| `.squad/decisions.md` | Persistent team decision log |
| `.squad/ceremonies.md` | Team ceremonies (Design Review, Retro, Model Review) |
| `.squad/schedule.json` | Automated task schedules |
| `.squad/config.json` | Machine-level config (machine ID, peers, devbox) |
| `.squad/agents/{name}/charter.md` | Individual agent identity and boundaries |
| `.squad/skills/{name}/SKILL.md` | Pluggable skill manifests |
| `.squad/decisions/inbox/` | Decision staging area (agents write here) |
| `.squad/orchestration-log/` | Session logs (auto-generated by Scribe) |
| `ralph-watch.ps1` | Ralph loop script for local continuous monitoring |

---

*Created by Seven (Research & Docs) — Issue #1063*  
*Squad HQ — built on [`bradygaster/squad`](https://github.com/bradygaster/squad)*
