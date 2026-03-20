# Squad HQ: Open-Source Packaging Plan

**Issue:** #1062  
**Author:** Seven (Research & Docs)  
**Date:** 2026-03-20  
**Status:** Draft

---

## 1. What Is Squad HQ?

Squad HQ is a **production-grade AI agent team framework** that turns a single GitHub repository into a self-managing, multi-agent software team. It runs continuously on your machine(s), picks up GitHub issues autonomously, assigns them to specialist AI agents, and ships the work — PRs, documentation, research, infrastructure changes — with minimal human intervention.

### The Core Idea

Instead of asking a single AI assistant a question and waiting for an answer, Squad HQ deploys a *team* of specialist agents that:
- Operate 24/7 via the `ralph-watch.ps1` reconciliation loop
- Divide work by domain expertise (code, architecture, docs, security, infra, comms)
- Coordinate through git-committed files (no live server, no database)
- Self-heal from auth failures, git conflicts, and process crashes
- Report status via Teams/email digests and structured logs

### The Agent Roster

| Agent | Role | Domain |
|-------|------|--------|
| **Picard** | Lead | Architecture, distributed systems, key decisions |
| **Data** | Code Expert | C#, Go, .NET, clean code |
| **Seven** | Research & Docs | Documentation, presentations, analysis |
| **B'Elanna** | Infrastructure | K8s, Helm, ArgoCD, cloud native |
| **Worf** | Security & Cloud | Security, Azure, networking |
| **Ralph** | Work Monitor | Backlog management, keep-alive loop, scheduling |
| **Troi** | Blogger & Writer | Blog, voice, storytelling |
| **Scribe** | Session Logger | Decisions, cross-agent context, orchestration log |
| **Neelix** | News & Comms | News briefings, Teams delivery |
| **Kes** | Scheduling | Calendar, emails, people comms |
| **Picard/Q/Crusher/Guinan/Geordi/Paris** | Specialized roles | Additional squad archetypes |

### Key Technical Components

- **`ralph-watch.ps1`** — The heartbeat loop. Runs every N minutes, invokes GitHub Copilot CLI with a routing prompt, enforces single-instance mutex, rotates logs, and sends Teams alerts on consecutive failures.
- **`.squad/` directory** — The team's shared brain: agent charters, decisions log, skills library, cross-machine task queue, scheduling config, knowledge base.
- **`squad.config.ts`** — Typed routing/model/casting configuration using the `@bradygaster/squad` framework package.
- **Skills system** — Discrete capability modules (each a `SKILL.md` manifest + optional scripts) that agents discover and invoke: `error-recovery`, `cross-machine-coordination`, `secrets-management`, `session-recovery`, etc.
- **Decisions framework** — `decisions.md` as the single source of truth for team-level rules. Inbox pattern (`decisions/inbox/`) for async merging by Scribe.
- **Cross-machine coordination** — Git-based task queue (YAML files committed to `.squad/cross-machine/tasks/`) enabling multi-machine agent coordination without a live server.
- **Upstream inheritance** — Org config → team config → personal overrides. Teams can pull shared templates from upstream repositories.
- **Ceremonies system** — `ceremonies.md` defines automated meeting triggers (design review before multi-agent tasks, retrospective after failures).

---

## 2. What to Extract vs. What to Generalize vs. What to Remove

### ✅ Keep As-Is (battle-tested, universally applicable)

| Component | Why it's ready |
|-----------|----------------|
| `ralph-watch.ps1` core loop | Generic reconciliation engine; all personal config is parameterized |
| `.squad/` directory skeleton | Structure is the product — empty templates work for anyone |
| Skills library (generic skills) | `error-recovery`, `session-recovery`, `squad-conventions`, `cross-machine-coordination`, `restart-recovery` are universal |
| Agent charter templates | The AGENT.md template in `.squad/charter.md` is already generic (uses `{placeholders}`) |
| `squad.config.ts` schema | Already typed via `@bradygaster/squad` package; just needs placeholder values |
| `ceremonies.md` | Fully generic trigger system |
| Decisions framework | `decisions.md` + inbox pattern — universally applicable |
| `copilot-instructions.md` | The `squad:{member}` label routing is framework behavior, not personal |
| Cross-machine coordination system | Git-based queue is infrastructure-agnostic |

### 🔧 Needs Generalization (good pattern, personal details embedded)

| Component | What to change |
|-----------|----------------|
| `ralph-watch.ps1` header config | Replace hardcoded `tamresearch1` in mutex name, lock file paths, window title — make them auto-derived from `git remote` or a `SQUAD_TEAM_NAME` env var |
| `.squad/config.json` | Remove `machineId`, `teamRoot`, `peers` entries with real hostnames; replace with documented template |
| `squad.config.ts` | Remove personal casting universe preferences; document the schema with comments |
| Agent charters (`agents/*/charter.md`) | Keep archetypes (Picard, Seven, Data…) but strip any org-specific domain knowledge baked in |
| Skills manifests that reference personal tooling | `kids-study-assistant`, `personal-email-access`, `outlook-automation` should be clearly marked "optional/personal" |
| MCP config samples | Good structure, but strip any internal service names; use `${ENV_VAR}` pattern throughout |

### ❌ Remove (personal/org-specific, must not ship)

| Item | Reason |
|------|--------|
| `tamirdresher@microsoft.com`, `tamirdrescher@microsoft.com` | Personal email addresses |
| Teams webhook URLs and channel IDs | Private org resources |
| `CPC-tamir-WCBED`, `tamirdresher` | Personal machine hostnames and usernames |
| Kids Squad configurations (`kids-directives/`, `kids-study-assistant` skill) | Personal family setup |
| `td-squad-ai-team@outlook.com`, `tdsquadai@gmail.com` | Personal service accounts |
| Any reference to `bradygaster` as a person in config (vs. as package author) | Relationship-specific |
| Content-squad pipeline (Gumroad, YouTube TechAI Explained configs) | Personal business venture |
| Microsoft-internal service references (DevBox hostnames, internal ADO orgs) | Microsoft-internal |
| `INFRASTRUCTURE_SETUP_GUIDE.md` sections about personal Gmail/YouTube account creation | Personal setup steps |
| Private repository URLs | Org-specific |
| Personal API keys anywhere in scripts | Security |
| `decisions.md` entries referencing personal names, internal teams, or private accounts | Personal context |
| Agent history files (`agents/*/history*.md`) | Contain real session history with personal context |
| `casting-history.json`, `board_snapshot.json` | Live state snapshots with personal data |
| `orchestration-log/` and `log/` contents | Operational logs with personal context |
| Email pipeline config with personal accounts | `email-pipeline/` directory |

---

## 3. Sensitive Data & Secrets Checklist

Run the following grep audit before any public commit:

```bash
# Email addresses
grep -r "@microsoft.com\|@outlook.com\|@gmail.com" .squad/ --include="*.md" --include="*.json" --include="*.ts" --include="*.ps1"

# Webhook URLs
grep -r "webhook\|teams.microsoft.com/l/channel\|hooks.slack.com" .squad/

# Machine hostnames
grep -r "CPC-\|DESKTOP-\|LAPTOP-" .squad/ --include="*.json" --include="*.md"

# Personal usernames
grep -r "tamirdresher\|tamirdrescher" .squad/

# Private repo URLs
grep -r "https://github.com/.*private\|dev.azure.com" .squad/ --include="*.md"

# API keys / tokens (patterns)
grep -rE "[A-Za-z0-9_]{32,}" .squad/ --include="*.json" | grep -v "history\|snapshot"
```

**Zero-tolerance items for public release:**
- [ ] No email addresses (personal or org)
- [ ] No webhook URLs
- [ ] No machine hostnames
- [ ] No personal usernames or aliases
- [ ] No private repository URLs
- [ ] No internal org names
- [ ] No API keys, tokens, or secrets of any kind
- [ ] No real session history content

---

## 4. Repository Structure for the Open-Source Version

```
squad-hq/
├── README.md                          # 5-minute quickstart
├── LICENSE                            # MIT
├── CONTRIBUTING.md                    # How to contribute
├── CHANGELOG.md                       # Version history
├── CODE_OF_CONDUCT.md                 # Standard contributor covenant
├── .env.example                       # All required env vars documented
├── Dockerfile                         # Pre-built image: Node + pwsh + gh + git
├── docker-compose.yml                 # Quick local run
├── squad.config.ts                    # Template config (all values documented)
│
├── ralph-watch.ps1                    # Core reconciliation loop (sanitized)
├── start-all-ralphs.ps1               # Multi-machine launcher (sanitized)
│
├── .squad/
│   ├── README.md                      # What this directory is and how it works
│   ├── agents/
│   │   ├── INDEX.md                   # Agent roster overview
│   │   ├── picard/charter.md          # Lead archetype
│   │   ├── data/charter.md            # Code expert archetype
│   │   ├── seven/charter.md           # Research & docs archetype
│   │   ├── belanna/charter.md         # Infrastructure archetype
│   │   ├── worf/charter.md            # Security archetype
│   │   ├── ralph/charter.md           # Work monitor archetype
│   │   ├── troi/charter.md            # Writer archetype
│   │   ├── scribe/charter.md          # Logger/orchestration archetype
│   │   └── _template/AGENT.md         # Template for custom agents
│   ├── skills/
│   │   ├── error-recovery/SKILL.md
│   │   ├── session-recovery/SKILL.md
│   │   ├── cross-machine-coordination/SKILL.md
│   │   ├── restart-recovery/SKILL.md
│   │   ├── squad-conventions/SKILL.md
│   │   ├── secrets-management/SKILL.md
│   │   └── github-distributed-coordination/SKILL.md
│   ├── decisions.md                   # Starter decisions (generic team rules only)
│   ├── ceremonies.md                  # Ceremony definitions
│   ├── copilot-instructions.md        # Routing instructions for Copilot
│   ├── config.json.example            # Template config (no real values)
│   ├── mcp-config.md                  # MCP integration guide
│   ├── cross-machine/
│   │   ├── README.md
│   │   ├── config.json.example
│   │   └── tasks/.gitkeep
│   ├── templates/
│   │   ├── issue-triager.md
│   │   ├── weekly-retro.md
│   │   └── model-evaluation.md
│   └── .gitignore                     # Excludes logs, heartbeat, lock files
│
├── docs/
│   ├── architecture.md                # How Squad HQ works (with diagram)
│   ├── agent-archetypes.md            # Deep dive on each agent role
│   ├── skills-system.md               # How skills work, how to write one
│   ├── cross-machine.md               # Multi-machine coordination guide
│   ├── deployment.md                  # Local, Docker, Kubernetes options
│   ├── customization.md               # Adding agents, skills, routing rules
│   └── faq.md                         # Common questions
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                     # Build Docker image + smoke test
│   │   └── lint.yml                   # Lint squad.config.ts + SKILL.md schemas
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── PULL_REQUEST_TEMPLATE.md
│
└── examples/
    ├── solo-dev/                       # Squad for a single developer
    ├── small-team/                     # Squad for a 3-5 person team
    └── oss-project/                    # Squad for an open-source project maintainer
```

---

## 5. Documentation Requirements

### README.md (the most important file)

Structure:
1. **30-second pitch** — What is Squad HQ? Why does it exist?
2. **Prerequisites** — GitHub account, GitHub Copilot subscription, Docker (optional), PowerShell 7+
3. **Quick Start** (5 minutes max):
   ```bash
   git clone https://github.com/your-org/squad-hq
   cp .env.example .env
   # Edit .env with your GitHub token and repo
   pwsh ralph-watch.ps1
   ```
4. **Architecture overview** — 1 diagram showing the loop: issue → ralph → agent → PR
5. **Agent roster** — Table of built-in archetypes with one-line descriptions
6. **Customization** — Link to docs/customization.md
7. **Deployment options** — Local, Docker, Kubernetes (links to docs/deployment.md)
8. **Contributing** — Link to CONTRIBUTING.md
9. **License** badge

### CONTRIBUTING.md

- How to add a new agent archetype
- How to write a skill (SKILL.md spec)
- Testing changes locally before PR
- Code style (TypeScript for config, PowerShell for scripts, Markdown for agent definitions)
- Commit message format (`squad: add X skill`, `agent: update picard charter`)

### .env.example

```env
# Required
GITHUB_TOKEN=ghp_...           # GitHub token with repo + issues scope
SQUAD_REPO=owner/repo          # The repository Squad HQ manages
SQUAD_TEAM_NAME=my-squad       # Used for mutex names and log prefixes

# Optional — Teams notifications
TEAMS_WEBHOOK_URL=             # Incoming webhook URL for a Teams channel

# Optional — model overrides
SQUAD_DEFAULT_MODEL=claude-sonnet-4.5
SQUAD_PREMIUM_MODEL=claude-opus-4.6

# Optional — cross-machine
SQUAD_MACHINE_ID=              # Unique ID for this machine (auto-detected if blank)

# Optional — scheduling
SQUAD_RALPH_INTERVAL_MINUTES=5
SQUAD_MAX_CONSECUTIVE_FAILURES=3
```

---

## 6. Recommended License: MIT

**Recommendation: MIT License**

**Rationale:**
- Broadest adoption — any developer, any company, any project can use it without legal review
- Aligns with Brady Gaster's `@bradygaster/squad` package (check its license; MIT is likely)
- No copyleft obligation — commercial users don't have to open-source their configurations
- Squad HQ's value is the *framework*, not secret sauce — openness is the moat
- Apache 2.0 is the alternative if patent grants are a concern (adds explicit patent license), but the complexity isn't worth it for this use case

**Decision:** MIT unless `@bradygaster/squad` upstream uses Apache 2.0, in which case match upstream to avoid license compatibility issues.

---

## 7. Handling the `.squad/` Config Directory

### The Challenge

`.squad/` is simultaneously:
- A runtime state directory (logs, heartbeats, lock files, session history)
- A configuration directory (agent charters, decisions, skills)
- A personal/team knowledge base (decisions.md, history, research)

The runtime state must be gitignored for the user's actual repo. The configuration must be committed as a template.

### Recommended Pattern: Template + .gitignore Layering

**1. Ship the `.squad/` directory as a template skeleton** — commit only:
- Agent charter files (`agents/*/charter.md`)
- Skills manifests (`skills/*/SKILL.md`)
- Generic starter `decisions.md` (no personal content)
- `ceremonies.md`, `copilot-instructions.md`
- `config.json.example` (never `config.json` with real values)
- `cross-machine/config.json.example`
- Template files in `templates/`

**2. The `.squad/.gitignore` handles the rest:**
```gitignore
# Runtime state — never commit
log/
sessions/
orchestration-log/
digests/
agent-tasks/
results/
research/
pending-issues/

# Live state files
*.heartbeat.json
ralph-*.lock
ralph-heartbeat.json

# Machine-specific config
config.json          # User creates this from config.json.example
cross-machine/config.json

# Personal history
agents/*/history*.md
agents/*/history-archive.md

# Commit message staging files
commit-msg*.txt
COMMIT_MSG*.txt
commit-message*.txt

# Board snapshots
board_snapshot.json
casting-history.json
casting-registry.json
```

**3. `squad init` scaffolding** — the CLI should:
1. Clone the template `.squad/` skeleton
2. Prompt for `SQUAD_TEAM_NAME`, `GITHUB_TOKEN`, `SQUAD_REPO`
3. Generate `config.json` from `config.json.example`
4. Generate `.env` from `.env.example`
5. Run first-time health check

### What Users Own

After `squad init`, users commit their own:
- `agents/*/charter.md` customizations (their team's voice and rules)
- `decisions.md` (their team's accumulated decisions)
- `skills/` additions (their custom skills)

This is intentional — the `.squad/` directory becomes *their team's institutional memory*.

---

## 8. Scripts That Need Sanitization

### `ralph-watch.ps1`

| Line(s) | Issue | Fix |
|---------|-------|-----|
| `$ralphTitle = "Ralph Watch - tamresearch1"` | Hardcoded repo name | Replace with `$env:SQUAD_TEAM_NAME ?? (Split-Path (git remote get-url origin) -Leaf)` |
| `$mutexName = "Global\RalphWatch_tamresearch1"` | Hardcoded mutex | Same — derive from env or git remote |
| Lock file path referencing `tamresearch1` | Hardcoded | Make dynamic |
| Teams alert target channel | Webhook URL embedded? | Move to `$env:TEAMS_WEBHOOK_URL` |
| Any reference to `gh-emu` or EMU GitHub config | Microsoft-internal auth setup | Generalize or document as optional |

### `start-all-ralphs.ps1`

| Issue | Fix |
|-------|-----|
| Hardcoded machine names/paths | Replace with `SQUAD_MACHINE_ID` env var |
| Personal SSH key paths | Move to env var `SQUAD_SSH_KEY_PATH` |
| DevBox-specific connection strings | Remove; document as "bring your own" |

### Scripts in `.squad/scripts/`

- Audit each script for personal email addresses, webhook URLs, org names
- Replace any hardcoded values with `$env:SQUAD_*` pattern
- Remove scripts that are purely personal (Gumroad, YouTube account creation, etc.)

---

## 9. GitHub Actions / CI Setup

### `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-docker:
    name: Build Docker Image
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -t squad-hq:test .
      - name: Smoke test — ralph-watch syntax
        run: |
          docker run --rm squad-hq:test \
            pwsh -Command "& { . ./ralph-watch.ps1 -DryRun; exit 0 }"

  validate-config:
    name: Validate squad.config.ts
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npx tsc --noEmit

  lint-skills:
    name: Lint SKILL.md files
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check SKILL.md headers
        run: |
          for f in $(find .squad/skills -name "SKILL.md"); do
            if ! grep -q "^# " "$f"; then
              echo "FAIL: $f missing title"
              exit 1
            fi
          done
          echo "All SKILL.md files valid"

  secrets-scan:
    name: Scan for leaked secrets
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check for email addresses in .squad/
        run: |
          if grep -rE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" .squad/ --include="*.md" --include="*.json" --include="*.ts" --include="*.ps1" | grep -v ".example"; then
            echo "FAIL: email address found in committed files"
            exit 1
          fi
```

### `.github/workflows/release.yml`

Trigger on tag push (`v*`):
1. Build and push Docker image to GitHub Container Registry (`ghcr.io/your-org/squad-hq`)
2. Create GitHub Release with changelog
3. Publish `squad` CLI npm package if applicable

---

## 10. Community Setup

### GitHub Repository Settings

- **Issues:** Enabled with templates (bug report, feature request, agent archetype request, skill request)
- **Discussions:** Enabled with categories:
  - 📣 Announcements (maintainer-only)
  - 💡 Ideas (open to all)
  - 🙋 Q&A (open to all)
  - 🤖 Showcase (users sharing their squads)
  - 🔧 Development (technical discussions)
- **Projects:** GitHub Project board with columns: Backlog → Ready → In Progress → Review → Done
- **Wiki:** Disabled initially (docs live in `/docs`)
- **Branch protection on `main`:** Require PR + CI pass

### Roadmap (ROADMAP.md)

**v0.1 — Foundation (ship now)**
- Core ralph-watch loop
- 8 agent archetypes
- Generic skills library
- Docker image
- README + quickstart

**v0.2 — CLI**
- `squad init` scaffolding command
- `squad status` — show current agent state
- `squad deploy` — Kubernetes deployment

**v0.3 — Ecosystem**
- Skill registry (npm-style, community-published skills)
- Agent marketplace (share custom agent archetypes)
- VS Code extension for `.squad/` editing

**v1.0 — Production-ready**
- Full test coverage on core loop
- Documented SLA for issue response times
- Self-hosted deployment guide (Kubernetes, Azure Container Apps, Fly.io)

### Issue Labels

| Label | Description |
|-------|-------------|
| `agent:*` | Relates to a specific agent archetype |
| `skill:*` | Relates to a skill module |
| `good first issue` | Low complexity, good for new contributors |
| `help wanted` | Needs a contributor |
| `breaking change` | API/schema change |
| `community` | Community discussion |

---

## 11. Marketing Plan: Where to Announce

### Tier 1: Immediate (Day 1)

**Hacker News — Show HN**
> "Show HN: Squad HQ — open-source AI agent team framework that self-manages your GitHub repo"

Key angles for HN:
- No live server — all coordination via git (HN loves this)
- Star Trek agent names (memorability + personality)
- "It shipped this PR while I slept" — concrete demo story
- Comparison to single-agent tools (why a *team* matters)
- Show the cross-machine git-queue design (architecture nerds will love it)

**Timing:** Tuesday or Wednesday morning US Pacific time for maximum visibility.

---

**DEV.to — Long-form post**
> "I built an AI team that manages my GitHub repo 24/7 — here's how it works"

Content:
- Personal story of why Squad HQ exists
- Architecture walkthrough with diagrams
- The ralph-watch loop explained simply
- 3 concrete things Squad HQ shipped autonomously (real examples)
- Link to GitHub repo + quickstart

---

### Tier 2: Week 1

**Brady Gaster's Community**
- Direct outreach: Squad HQ is built on `@bradygaster/squad` — this is the first major production deployment going open-source
- Propose a joint blog post or demo: "Squad HQ: taking `@bradygaster/squad` to production"
- Ask Brady to mention in his newsletter / social channels
- Position as the "production batteries-included" version of the upstream framework

**LinkedIn Post (Tamir's account)**
> "I've been running an AI agent team on my GitHub repo for months. Today I'm open-sourcing the whole thing."

- Keep it punchy — 150 words max + link
- Attach the architecture diagram as an image (LinkedIn favors images)

**X/Twitter**
- Thread version of the HN post (5-7 tweets)
- Tag Brady Gaster, GitHub, Anthropic
- Use `#AIAgents`, `#OpenSource`, `#DevTools`

---

### Tier 3: Amplification

**Reddit**
- r/programming — architecture/design angle
- r/MachineLearning — AI agent architecture angle
- r/github — GitHub-native tools angle
- r/selfhosted — self-hosted automation angle

**YouTube (TechAI Explained)**
- Demo video: "I automated my entire GitHub workflow with AI agents"
- Screen recording of Squad HQ picking up an issue, doing the work, opening a PR
- Target: 10-minute video, no slides needed — just the terminal and GitHub UI

**Newsletter (if Tamir has one)**
- Exclusive first look + behind-the-scenes story
- "How Squad HQ works" explainer

---

### Messaging Framework

**One-liner:** "Squad HQ is an open-source AI agent team that self-manages your GitHub repository."

**Elevator pitch:** "You give Squad HQ a list of GitHub issues. It deploys 8 specialist AI agents — one for architecture, one for code, one for docs, one for security — that pick up the work, open PRs, and keep everything moving. All coordination happens via git. No server. No database. Works while you sleep."

**Differentiators to lead with:**
1. *Team, not tool* — multiple specialist agents vs. one generalist
2. *Git-native* — zero live infrastructure required
3. *Battle-tested* — this ran in production for months before being open-sourced
4. *Extensible* — add your own agents, write your own skills
5. *Self-healing* — handles auth failures, conflicts, crashes autonomously

---

## 12. Open Questions / Decisions Needed

| Question | Options | Recommendation |
|----------|---------|----------------|
| Repo name | `squad-hq`, `squad-hq-oss`, `bradygaster/squad-hq` | `squad-hq` under Tamir's org initially |
| License | MIT vs Apache 2.0 | MIT |
| Relationship to `@bradygaster/squad` | Fork, contribute back, or parallel | Start parallel (Option A from issue), then upstream |
| CLI tool delivery | npm package, standalone binary, PowerShell module | npm package (`squad-hq` or `@squad/cli`) |
| Docker base image | `ubuntu:22.04` + installs, or `mcr.microsoft.com/devcontainers/base:ubuntu` | MCR devcontainers base (already has common tools) |
| Agent names | Keep Star Trek theme, make configurable, or offer multiple universes | Keep ST as default; `casting` config already supports universe swapping |
| First version tag | `v0.1.0` or wait for `v1.0` | Ship as `v0.1.0` — lower expectations, faster iteration |

---

## Acceptance Criteria Cross-Reference

From issue #1062:

| Criterion | Status | Notes |
|-----------|--------|-------|
| ✅ Clean repo with zero personal data | 🔧 In progress | See §3 checklist |
| ✅ Working Dockerfile | ⬜ Not started | Needs creation |
| ✅ `squad init` scaffolding | ⬜ Not started | Future milestone (v0.2) |
| ✅ README with 5-minute quickstart | ⬜ Not started | Blocked on repo creation |
| ✅ `.env.example` with all config documented | 🔧 Drafted | See §5 |
| ✅ CI pipeline: build image + smoke test | 🔧 Drafted | See §9 |
| ✅ License file (MIT recommended) | ⬜ Not started | Confirm in §6, then create |

---

*Seven — Research & Docs. If the docs are wrong, the product is wrong.*
