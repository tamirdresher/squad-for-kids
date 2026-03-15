# 🚀 Build Your Own Squad — Hands-On Workshop

> **Turn a single AI agent into a coordinated team of specialists.**

| | |
|---|---|
| **Duration** | ~2.5 hours (5 parts) |
| **Level** | Intermediate — familiar with GitHub, new to AI agents |
| **What You'll Build** | A 4-agent squad that triages issues, writes code, reviews quality, and logs decisions |
| **You Need** | GitHub account · GitHub Copilot CLI · VS Code · Node.js 20+ |

---

## Table of Contents

- [Part 1: Foundation (30 min)](#part-1-foundation-30-min)
- [Part 2: Creating Your First Agent (30 min)](#part-2-creating-your-first-agent-30-min)
- [Part 3: Multi-Agent Collaboration (30 min)](#part-3-multi-agent-collaboration-30-min)
- [Part 4: Automation & Integration (30 min)](#part-4-automation--integration-30-min)
- [Part 5: Advanced Patterns (20 min)](#part-5-advanced-patterns-20-min)
- [Appendix A: Quick Reference Card](#appendix-a-quick-reference-card)
- [Appendix B: Troubleshooting](#appendix-b-troubleshooting)
- [Appendix C: Sample squad.config.ts](#appendix-c-sample-squadconfigts)

---

## Part 1: Foundation (30 min)

### 🎯 Learning Objective

Understand what Squad is, why multi-agent beats single-agent, and initialize your first squad project.

---

### 1.1 What Is Squad? (5 min)

Squad is an **AI agent orchestration framework** built on GitHub Copilot CLI. Instead of one AI agent trying to do everything, you create a **team of specialists** — each with its own role, expertise, boundaries, and personality.

#### The Single-Agent Problem

```
┌─────────────────────────────────────────────┐
│              One AI Agent                    │
│                                              │
│  "Write code AND review it AND deploy it     │
│   AND document it AND check security..."     │
│                                              │
│  ❌ Context overload                         │
│  ❌ No specialization                        │
│  ❌ No checks and balances                   │
│  ❌ Hard to scale                            │
└─────────────────────────────────────────────┘
```

#### The Squad Solution

```
┌─────────────────────────────────────────────────────────────────┐
│                        COORDINATOR                              │
│               (Routes work to the right agent)                  │
│                                                                 │
│    ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│    │  🏗️ Lead  │  │ 💻 Coder │  │ 🔍 Review│  │ 📝 Docs  │     │
│    │          │  │          │  │          │  │          │     │
│    │ Triage & │  │ Features │  │ Quality  │  │ Research │     │
│    │ Decide   │  │ Bug fixes│  │ Security │  │ Logging  │     │
│    └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘     │
│         │              │              │              │           │
│         └──────────────┴──────────────┴──────────────┘           │
│                    Shared decisions.md                           │
│                    Shared skills library                         │
│                    GitHub Issues & Board                         │
└─────────────────────────────────────────────────────────────────┘
```

#### Key Principles

| Principle | What It Means |
|-----------|---------------|
| **Specialized agents** | Each agent has a charter defining exactly what it does (and doesn't do) |
| **Clear routing** | Work types map to agents via explicit rules |
| **Shared memory** | `decisions.md` is the single source of truth all agents respect |
| **Reusable skills** | Methodologies are codified in SKILL.md files any agent can use |
| **GitHub-native** | Issues for work, PRs for code, Projects for status, Actions for CI/CD |
| **Zero-dependency core** | The `@bradygaster/squad-cli` package uses only Node.js built-ins |

---

### 1.2 Prerequisites Check (5 min)

Run each command to verify your environment is ready:

```bash
# 1. Node.js 20+ is installed
node --version
# Expected: v20.x.x or higher

# 2. GitHub CLI is authenticated
gh auth status
# Expected: "Logged in to github.com as <your-username>"

# 3. GitHub Copilot CLI is available
# (Verify you can run Copilot in your terminal)

# 4. VS Code is installed
code --version
# Expected: 1.90+ or similar

# 5. Git is configured
git config user.name && git config user.email
# Expected: your name and email
```

> 💡 **Tip:** If `gh auth status` fails, run `gh auth login` and follow the browser flow.

---

### 1.3 Initialize Your Squad (10 min)

#### Exercise 1: Create a new project and initialize Squad

```bash
# Create a new project directory
mkdir project-phoenix
cd project-phoenix

# Initialize a git repository
git init

# Initialize your squad
npx @bradygaster/squad-cli init
```

You'll see output like:

```
✔ Created .squad/
✔ Created .squad/agents/
✔ Created .squad/skills/
✔ Created .squad/decisions/
✔ Created .squad/decisions/inbox/
✔ Created .squad/templates/
✔ Created .squad/team.md
✔ Created .squad/routing.md
✔ Created .squad/decisions.md
✔ Created .squad/ceremonies.md
✔ Created squad.config.ts
✔ Squad initialized successfully!
```

> ⚠️ **Init is idempotent.** Running `init` again will skip files that already exist — it never overwrites your customizations.

---

### 1.4 Explore the Directory Structure (10 min)

#### Exercise 2: Tour the generated files

Open the project in VS Code:

```bash
code .
```

Explore the directory tree:

```
project-phoenix/
├── .squad/
│   ├── agents/              # 👤 Agent definitions live here
│   ├── skills/              # 🛠️ Reusable methodologies
│   ├── decisions/
│   │   └── inbox/           # 📥 Parallel decision drop-box
│   ├── templates/           # 📄 Customizable templates
│   ├── team.md              # 👥 Team roster & capabilities
│   ├── routing.md           # 🔀 Work routing rules
│   ├── decisions.md         # 📋 Single source of truth
│   └── ceremonies.md        # 🎭 Design reviews, retros, etc.
└── squad.config.ts          # ⚙️ Configuration & model tiers
```

#### Exercise 3: Read the key files

Open and read each file. Answer these questions:

1. **`team.md`** — What columns does the team roster have?
2. **`routing.md`** — What work types are pre-configured?
3. **`decisions.md`** — What is this file for?
4. **`squad.config.ts`** — What is the default model?

> 📝 **Write your answers down.** You'll reference them when building your agents.

#### Understanding the Core Files

| File | Purpose | Who Manages It |
|------|---------|----------------|
| `team.md` | Lists all agents with their roles and status | You (manual) or a logger agent |
| `routing.md` | Maps work types → agents; defines routing rules | Lead agent or you |
| `decisions.md` | Records all decisions the team has made | Logger agent merges from inbox |
| `ceremonies.md` | Defines recurring team meetings and their cadence | You |
| `squad.config.ts` | Model assignments, routing rules, governance | You |

---

## Part 2: Creating Your First Agent (30 min)

### 🎯 Learning Objective

Design, build, and test a single agent with a well-defined charter.

---

### 2.1 Agent Anatomy (5 min)

Every agent lives in `.squad/agents/<name>/` and has at minimum a `charter.md`:

```
.squad/agents/atlas/
├── charter.md          # Required: identity, role, boundaries, model
└── history.md          # Optional: work log (grows over time)
```

A charter has these sections:

```markdown
# Name — Role Title

> One-line personality quote.

## Identity
## What I Own
## How I Work
## Boundaries
## Model
## Collaboration
## Voice
```

Each section serves a specific purpose:

| Section | Purpose | Example |
|---------|---------|---------|
| **Identity** | Name, role, expertise, style | "Atlas — Lead Architect" |
| **What I Own** | Responsibilities this agent covers | "Architecture, API design, decisions" |
| **How I Work** | Principles and patterns followed | "Read decisions.md before starting" |
| **Boundaries** | What it handles, what it doesn't, when it's unsure | "I don't handle: frontend CSS" |
| **Model** | Preferred AI model tier and fallback | "Standard (claude-sonnet-4.5)" |
| **Collaboration** | How it interacts with the team | "Write decisions to inbox/" |
| **Voice** | Personality and communication style | "Concise. Data-driven. No fluff." |

---

### 2.2 Design Your First Agent (10 min)

#### Exercise 4: Design on paper first

Before writing any files, plan your agent. We'll build **Atlas** — a lead/architect agent for "Project Phoenix."

Answer these questions:

| Question | Your Answer |
|----------|-------------|
| What is the agent's name? | Atlas |
| What is its role? | Lead Architect |
| What expertise does it have? | System design, API design, tech decisions |
| What does it own? | Architecture, tech stack choices, design reviews |
| What does it NOT handle? | Implementation details, CSS, testing |
| When is it unsure? | Frontend performance, mobile-specific patterns |
| What model tier? | Standard |
| What's its personality? | Direct, concise, data-driven |

> 💡 **Naming tip:** Pick a name that's memorable and implies the role. "Atlas" suggests someone who carries the big picture. Use any theme you like — mythology, sci-fi, historical figures, or just descriptive names like "Architect."

---

### 2.3 Write the Charter (10 min)

#### Exercise 5: Create the agent directory and charter

```bash
# Create the agent directory
mkdir -p .squad/agents/atlas
```

Now create `.squad/agents/atlas/charter.md` with the following content:

```markdown
# Atlas — Lead Architect

> Sees the whole system. Decides fast, revises when the data changes.

## Identity

- **Name:** Atlas
- **Role:** Lead Architect
- **Expertise:** System design, API design, technology decisions
- **Style:** Direct and data-driven.

## What I Own

- System architecture and design decisions
- API contract definitions
- Technology stack choices
- Design review coordination

## How I Work

- Read decisions.md before starting any work
- Write decisions to inbox when making team-relevant choices
- Focused on the "why" and "what", not the "how"
- Always consider scalability, maintainability, and team velocity

## Boundaries

**I handle:** Architecture decisions, API design, system design reviews, tech stack evaluation

**I don't handle:** Implementation details, frontend styling, test writing, deployment scripts

**When I'm unsure:** I say so explicitly and suggest which team member might know better.

**If I review others' work:** I focus on architectural alignment, not code style. On rejection, I explain the architectural concern and suggest an alternative approach.

## Model

- **Preferred:** auto
- **Rationale:** Coordinator selects the best model based on task complexity
- **Fallback:** Standard chain

## Collaboration

Before starting work:
1. Run `git rev-parse --show-toplevel` to find the repo root
2. Read `.squad/decisions.md` for team decisions that affect my work
3. After making a decision, write it to `.squad/decisions/inbox/atlas-{brief-slug}.md`
4. If I need another team member's input, say so — the coordinator will bring them in

## Voice

Concise. Data-driven. No fluff. If there are three options, I'll list trade-offs for each and recommend one.
```

#### Exercise 6: Register the agent in team.md

Open `.squad/team.md` and add Atlas to the roster table:

```markdown
| Atlas | Lead Architect | Architecture, API design, decisions | ✅ Active |
```

---

### 2.4 Choose the Right Model Tier (5 min)

Squad supports tiered model selection. Each agent can specify a preference:

| Tier | Model Example | Best For | Cost |
|------|--------------|----------|------|
| **Fast** | `claude-haiku-4.5` | Routine tasks, templates, monitoring, background work | $ |
| **Standard** | `claude-sonnet-4.5` | Complex reasoning, code generation, research, most work | $$ |
| **Premium** | `claude-opus-4.6` | Mission-critical decisions, novel architecture, rare use | $$$ |

**Rules of thumb:**
- 🟢 Start every agent on **Standard** — it handles 90% of work well
- 🔵 Downgrade to **Fast** for agents that do routine/repetitive work (monitoring, formatting)
- 🔴 Reserve **Premium** for agents making irreversible decisions (security, architecture)

> 💡 **Exercise 7:** Look at your Atlas charter. Is "Standard" the right tier? What if Atlas only triaged issues — would you change it?

---

### 2.5 Test Your Agent (5 min — Demo)

With a charter in place, Copilot CLI can now assume the Atlas persona when working on relevant issues.

#### How Agent Selection Works

When you (or a CI workflow) invoke Copilot CLI on an issue:

1. The **coordinator** reads `routing.md` to determine which agent should handle it
2. The matched agent's `charter.md` is loaded as system context
3. The agent works within its declared boundaries
4. Decisions are written to `decisions/inbox/`

```bash
# Create a test issue in your repo (if using GitHub)
gh issue create --title "Choose a database for Project Phoenix" \
  --body "We need to decide between PostgreSQL and MongoDB for our main data store. Consider our team's experience, scaling needs, and the read/write patterns of our API." \
  --label "architecture"
```

The coordinator would route this to Atlas (architecture work), and Atlas would:
1. Read `decisions.md` for prior tech stack choices
2. Analyze the trade-offs
3. Write a recommendation to `decisions/inbox/atlas-database-choice.md`

---

## Part 3: Multi-Agent Collaboration (30 min)

### 🎯 Learning Objective

Build a 4-agent team, define routing rules, create shared skills, and practice cross-agent handoffs.

---

### 3.1 Design Your Team (5 min)

A good squad has **complementary** agents with **clear boundaries**. No overlaps, no gaps.

#### Exercise 8: Plan a 4-agent team

We'll extend Project Phoenix with three more agents alongside Atlas:

| Agent | Role | Handles | Doesn't Handle |
|-------|------|---------|----------------|
| **Atlas** | Lead Architect | Architecture, decisions, design reviews | Implementation, testing |
| **Forge** | Code Engineer | Features, bug fixes, refactoring | Architecture, security |
| **Sentinel** | Quality & Security | Code review, testing, security scanning | Feature design, deployment |
| **Chronicle** | Logger & Docs | Session logs, decisions, documentation | Code changes, architecture |

```
                    ┌────────────────┐
                    │  COORDINATOR   │
                    │ reads routing  │
                    └───────┬────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
     ┌──────┴──────┐ ┌─────┴──────┐ ┌──────┴──────┐
     │ 🏗️ Atlas    │ │ 💻 Forge   │ │ 🔍 Sentinel │
     │ Architect   │ │ Engineer   │ │ Quality     │
     └──────┬──────┘ └─────┬──────┘ └──────┬──────┘
            │               │               │
            └───────────────┴───────────────┘
                            │
                    ┌───────┴────────┐
                    │ 📝 Chronicle   │
                    │ Logger & Docs  │
                    └────────────────┘
            (runs after every substantial task)
```

---

### 3.2 Create the Remaining Agents (10 min)

#### Exercise 9: Create Forge — Code Engineer

```bash
mkdir -p .squad/agents/forge
```

Create `.squad/agents/forge/charter.md`:

```markdown
# Forge — Code Engineer

> Clean code is not a goal, it's a habit. Ship it right the first time.

## Identity

- **Name:** Forge
- **Role:** Code Engineer
- **Expertise:** Feature development, bug fixes, refactoring, clean code patterns
- **Style:** Practical and detail-oriented.

## What I Own

- Feature implementation
- Bug fixes and patches
- Code refactoring
- Unit test writing (for own code)

## How I Work

- Read decisions.md before starting — respect architectural choices
- Write small, focused commits with clear messages
- Follow existing code patterns in the repository
- Ask Atlas if an implementation choice has architectural implications

## Boundaries

**I handle:** Writing code, fixing bugs, refactoring, unit tests for my code

**I don't handle:** Architecture decisions, security audits, deployment, documentation

**When I'm unsure:** I check if Atlas has made a relevant decision. If not, I flag it for the coordinator.

## Model

- **Preferred:** auto
- **Rationale:** Standard model for most work; fast model for routine fixes
- **Fallback:** Standard chain

## Collaboration

Before starting work:
1. Read `.squad/decisions.md` for decisions that affect implementation
2. After completing work, signal Chronicle to log the session
3. Request Sentinel review on any PR before merge

## Voice

Practical. Ships working code. Prefers showing over telling.
```

#### Exercise 10: Create Sentinel — Quality & Security

```bash
mkdir -p .squad/agents/sentinel
```

Create `.squad/agents/sentinel/charter.md`:

```markdown
# Sentinel — Quality Guardian

> If it's not tested, it's not done. If it's not secure, it doesn't ship.

## Identity

- **Name:** Sentinel
- **Role:** Quality & Security
- **Expertise:** Code review, testing strategy, security scanning, vulnerability assessment
- **Style:** Thorough and constructive.

## What I Own

- Code review on all PRs
- Test coverage standards
- Security vulnerability scanning
- Quality gates and checklists

## How I Work

- Review every PR before merge — no exceptions
- For every claim, ask: "What evidence supports this? What would disprove it?"
- Flag issues with severity levels: 🔴 Critical, 🟡 Warning, 🟢 Info
- Provide actionable fix suggestions, not just complaints

## Boundaries

**I handle:** Code review, security audits, test strategy, quality standards

**I don't handle:** Writing features, architecture decisions, deployment, documentation

**When I'm unsure:** I flag the concern with a confidence level and suggest verification steps.

**If I review others' work:** On rejection, I may request a different agent to revise (not the original author) to get fresh eyes on the problem.

## Model

- **Preferred:** auto
- **Rationale:** Standard model for reviews; premium for security-critical audits
- **Fallback:** Standard chain

## Collaboration

Before starting work:
1. Read `.squad/decisions.md` for security and quality decisions
2. Use the fact-checking skill for structured review output
3. Write security findings to `.squad/decisions/inbox/sentinel-{slug}.md`

## Voice

Thorough but constructive. Every "no" comes with a "here's how to fix it."
```

#### Exercise 11: Create Chronicle — Logger & Docs

```bash
mkdir -p .squad/agents/chronicle
```

Create `.squad/agents/chronicle/charter.md`:

```markdown
# Chronicle — Logger & Docs

> If it's not written down, it didn't happen.

## Identity

- **Name:** Chronicle
- **Role:** Logger & Documentation
- **Expertise:** Session logging, decision curation, documentation, knowledge management
- **Style:** Precise and organized.

## What I Own

- Session logs after substantial work
- Merging decisions from inbox/ into decisions.md
- Team documentation and knowledge base
- Orchestration log maintenance

## How I Work

- Run automatically after every substantial task (background)
- Merge parallel decision writes from `.squad/decisions/inbox/` into `decisions.md`
- Never modify another agent's work — only document it
- Keep logs concise: what happened, what was decided, what's next

## Boundaries

**I handle:** Logging, documentation, decision merging, knowledge curation

**I don't handle:** Code changes, architecture, security, reviews

**When I'm unsure:** I document the uncertainty itself — "Decision pending on X."

## Model

- **Preferred:** auto
- **Rationale:** Fast model for routine logging; standard for synthesis
- **Fallback:** Fast chain

## Collaboration

Before starting work:
1. Check `.squad/decisions/inbox/` for new decision files
2. Merge any found into `.squad/decisions.md` with proper formatting
3. Update `.squad/team.md` if agent statuses have changed
4. Signal completion — other agents can proceed knowing context is saved

## Voice

Precise. Organized. Writes for the person who'll read this six months from now.
```

#### Exercise 12: Update team.md

Add all agents to `.squad/team.md`:

```markdown
## Team Roster

| Name | Role | Expertise | Status |
|------|------|-----------|--------|
| Atlas | Lead Architect | Architecture, API design, decisions | ✅ Active |
| Forge | Code Engineer | Features, bug fixes, refactoring | ✅ Active |
| Sentinel | Quality Guardian | Code review, security, testing | ✅ Active |
| Chronicle | Logger & Docs | Logging, decisions, documentation | 📋 Background |
```

---

### 3.3 Set Up Routing Rules (5 min)

#### Exercise 13: Define routing in routing.md

Open `.squad/routing.md` and replace its contents with:

```markdown
# Routing Rules — Project Phoenix

## Work Type → Agent Mapping

| Work Type | Route To | Examples |
|-----------|----------|----------|
| Architecture & design | Atlas | System design, API contracts, tech stack |
| Feature development | Forge | New endpoints, UI components, integrations |
| Bug fixes | Forge | Error resolution, patches, hotfixes |
| Code review | Sentinel | PR reviews, quality checks |
| Security | Sentinel | Vulnerability scans, auth review, secrets |
| Testing strategy | Sentinel | Test plans, coverage gaps, CI gates |
| Documentation | Chronicle | Docs, session logs, knowledge base |
| Decision logging | Chronicle | Merge inbox, update decisions.md |

## Routing Principles

1. **Eager by default** — Spawn all agents who could usefully start work in parallel
2. **Chronicle always runs** — After every substantial task (as a background step)
3. **Quick facts** — Coordinator answers directly without spawning agents
4. **Two agents could handle?** — Pick the primary domain owner
5. **"Team, ..." prefix** — Fan out to all relevant agents in parallel
6. **Anticipate downstream** — Spawn Sentinel while Forge is still coding

## Issue Label Routing

| Label | Routed To |
|-------|-----------|
| `squad` | Atlas triages and assigns |
| `squad:atlas` | Atlas picks up directly |
| `squad:forge` | Forge picks up directly |
| `squad:sentinel` | Sentinel picks up directly |
| `squad:chronicle` | Chronicle picks up directly |

## Handoff Protocol

When an agent completes work that another agent needs:
1. The completing agent signals the coordinator
2. The coordinator spawns the next agent with full context
3. The next agent reads `decisions.md` before starting
4. Chronicle logs the handoff
```

---

### 3.4 Create a Shared Skill (5 min)

Skills are reusable methodologies that any agent can reference. Let's create a **code review** skill.

#### Exercise 14: Create a review skill

```bash
mkdir -p .squad/skills/code-review
```

Create `.squad/skills/code-review/SKILL.md`:

```markdown
# Skill: Code Review

**Confidence:** high
**Domain:** quality, engineering
**Last validated:** 2025-01-01

## Context

Standardizes the code review process across all agents. Any agent performing a review
should follow this methodology for consistent, actionable feedback.

## Pattern

### Review Checklist

For every PR or code change:

1. **Correctness** — Does the code do what it claims?
2. **Edge cases** — What happens with empty input, nulls, large data?
3. **Security** — Any injection, auth bypass, or data leak risks?
4. **Performance** — Any N+1 queries, unbounded loops, or memory leaks?
5. **Readability** — Can a new team member understand this in 5 minutes?
6. **Tests** — Are the changes covered by tests?

### Review Output Format

```text
## Code Review — {PR title}

**Reviewer:** {agent name}
**Verdict:** APPROVE / REQUEST CHANGES / COMMENT

### Findings

| # | Severity | File:Line | Finding | Suggestion |
|---|----------|-----------|---------|------------|
| 1 | 🔴/🟡/🟢 | path:42 | description | fix |

### Summary
- **Critical issues:** {count}
- **Warnings:** {count}
- **Suggestions:** {count}
```text

### Severity Levels

- 🔴 **Critical** — Must fix before merge (bugs, security, data loss)
- 🟡 **Warning** — Should fix, but not a blocker (performance, edge cases)
- 🟢 **Info** — Nice to have (style, naming, minor improvements)
```

> 💡 **Key insight:** Skills are not code — they're **documented methodologies**. They codify how work should be done so any agent can follow the same process consistently.

---

### 3.5 Practice Cross-Agent Handoffs (5 min)

#### Exercise 15: Simulate a workflow

Walk through this scenario on paper (or whiteboard):

**Scenario:** A new issue arrives: *"Add rate limiting to the /api/users endpoint"*

1. Issue gets the `squad` label
2. **Atlas** triages:
   - "This is a feature with security implications"
   - Writes decision: "Use token bucket algorithm, 100 req/min per API key"
   - Routes to Forge (implementation) and flags Sentinel (security review)
3. **Forge** implements:
   - Reads Atlas's decision from `decisions.md`
   - Writes the rate limiter code
   - Opens a PR
4. **Sentinel** reviews:
   - Uses the `code-review` skill
   - Checks for bypass vulnerabilities
   - Approves (or requests changes)
5. **Chronicle** logs:
   - Records the session: who did what, what was decided
   - Merges any inbox decisions into `decisions.md`

**Discussion questions:**
- What if Sentinel rejects Forge's PR? Who revises?
- What if Atlas's decision needs to change mid-implementation?
- How does the team avoid conflicting parallel writes to `decisions.md`?

---

## Part 4: Automation & Integration (30 min)

### 🎯 Learning Objective

Add GitHub Actions for automated triage, set up notifications, and implement monitoring patterns.

---

### 4.1 Automated Issue Triage (10 min)

GitHub Actions can automatically trigger your squad when issues are created or labeled.

#### Exercise 16: Create a triage workflow

Create `.github/workflows/squad-triage.yml`:

```yaml
name: Squad Issue Triage

on:
  issues:
    types: [opened, labeled]

jobs:
  triage:
    # Only run when the 'squad' label is added
    if: contains(github.event.issue.labels.*.name, 'squad')
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Read routing rules
        id: routing
        run: |
          echo "Routing rules loaded from .squad/routing.md"
          cat .squad/routing.md

      - name: Assign to lead for triage
        uses: actions/github-script@v7
        with:
          script: |
            // Add a comment indicating triage is needed
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `🤖 **Squad Triage**\n\nThis issue has been flagged for squad triage.\n\n**Next step:** Lead agent (Atlas) will evaluate and route to the appropriate specialist.\n\nRouting rules: See \`.squad/routing.md\``
            });

      - name: Label based on content
        uses: actions/github-script@v7
        with:
          script: |
            const title = context.payload.issue.title.toLowerCase();
            const body = (context.payload.issue.body || '').toLowerCase();
            const content = title + ' ' + body;

            let label = 'squad:atlas'; // default to lead

            if (content.includes('bug') || content.includes('fix') || content.includes('error')) {
              label = 'squad:forge';
            } else if (content.includes('security') || content.includes('vulnerability') || content.includes('review')) {
              label = 'squad:sentinel';
            } else if (content.includes('document') || content.includes('docs') || content.includes('log')) {
              label = 'squad:chronicle';
            }

            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              labels: [label]
            });

            console.log(`Routed to: ${label}`);
```

> 💡 **In production**, the triage step would invoke Copilot CLI with the lead agent's charter to make smarter routing decisions. This simplified version shows the pattern.

---

### 4.2 Webhook Notifications (5 min)

Keep your team informed with webhook notifications to a chat channel (e.g., Teams, Slack, or Discord).

#### Exercise 17: Add a notification step

Add this job to your workflow (or create a separate file):

```yaml
  notify:
    needs: triage
    runs-on: ubuntu-latest
    steps:
      - name: Send notification
        env:
          WEBHOOK_URL: ${{ secrets.TEAM_WEBHOOK_URL }}
        run: |
          curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d '{
              "text": "🤖 Squad Alert: Issue #${{ github.event.issue.number }} triaged.\nTitle: ${{ github.event.issue.title }}\nURL: ${{ github.event.issue.html_url }}"
            }'
```

**Setup steps:**
1. Create an incoming webhook in your chat platform
2. Add the URL as a repository secret: `TEAM_WEBHOOK_URL`
3. The workflow will post a notification whenever an issue is triaged

---

### 4.3 The Work Monitor Pattern (10 min)

A **work monitor** is an agent that runs on a schedule, checking for stale work and sending status reports.

#### Exercise 18: Design a monitor agent

The monitor pattern has three components:

```
┌─────────────────────────────────────────┐
│           MONITOR LOOP                  │
│                                         │
│  1. Check board for stale items         │
│  2. Check for issues without assignees  │
│  3. Check for PRs awaiting review       │
│  4. Generate status digest              │
│  5. Send alerts if thresholds exceeded  │
│  6. Sleep, repeat                       │
└─────────────────────────────────────────┘
```

Create a monitor workflow at `.github/workflows/squad-monitor.yml`:

```yaml
name: Squad Work Monitor

on:
  schedule:
    # Run every 2 hours during business hours (UTC)
    - cron: '0 8-18/2 * * 1-5'
  workflow_dispatch: # Allow manual trigger

jobs:
  monitor:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Check for stale issues
        uses: actions/github-script@v7
        with:
          script: |
            const oneWeekAgo = new Date();
            oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);

            const issues = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'open',
              labels: 'squad',
              since: oneWeekAgo.toISOString(),
              per_page: 50
            });

            const stale = issues.data.filter(i =>
              new Date(i.updated_at) < oneWeekAgo
            );

            if (stale.length > 0) {
              console.log(`⚠️ Found ${stale.length} stale squad issues:`);
              stale.forEach(i => console.log(`  #${i.number}: ${i.title}`));
            } else {
              console.log('✅ No stale issues found');
            }

      - name: Check for unassigned work
        uses: actions/github-script@v7
        with:
          script: |
            const issues = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'open',
              labels: 'squad',
              per_page: 50
            });

            const unassigned = issues.data.filter(i =>
              !i.labels.some(l => l.name.startsWith('squad:'))
            );

            if (unassigned.length > 0) {
              console.log(`📋 ${unassigned.length} issues need triage:`);
              unassigned.forEach(i => {
                console.log(`  #${i.number}: ${i.title}`);
              });
            }
```

---

### 4.4 Board Synchronization (5 min)

Use GitHub Projects as your squad's kanban board:

#### Exercise 19: Set up project board columns

```bash
# Create a GitHub Project (via CLI)
gh project create --title "Project Phoenix — Squad Board" --owner @me

# Suggested columns:
# 📥 Triage      → New issues land here
# 🏗️ In Progress → Agent is actively working
# 👀 Review      → Sentinel is reviewing
# ✅ Done        → Merged and logged
# 🧊 Blocked     → Waiting on external input
```

**Board ↔ Agent mapping:**

| Column | Agent Action |
|--------|-------------|
| 📥 Triage | Atlas evaluates and routes |
| 🏗️ In Progress | Forge or other agent is working |
| 👀 Review | Sentinel reviews the PR |
| ✅ Done | Chronicle logs the completion |
| 🧊 Blocked | Monitor alerts on items stale > 48h |

---

### 4.5 Session Logging (5 min)

#### Exercise 20: Create a session log template

Chronicle uses a consistent format for session logs. Create `.squad/templates/session-log.md`:

```markdown
# Session Log — {date}

## Context
- **Issue:** #{number} — {title}
- **Agent(s):** {who worked}
- **Duration:** {approximate time}

## What Happened
{Brief narrative of the work done}

## Decisions Made
| Decision | Made By | Recorded In |
|----------|---------|-------------|
| {decision} | {agent} | decisions.md |

## Artifacts
- [ ] Code changes: PR #{number}
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Decision logged

## Next Steps
- {what needs to happen next}
```

---

## Part 5: Advanced Patterns (20 min)

### 🎯 Learning Objective

Learn patterns for scaling squads across machines, managing decisions, and running team ceremonies.

---

### 5.1 Multi-Machine Coordination (5 min)

When your squad runs across multiple machines (e.g., dev laptop + CI server + cloud VM), you need a coordination protocol.

#### The Git-Based Sync Pattern

```
Machine A (Developer)              Machine B (CI Server)
┌──────────────────┐              ┌──────────────────┐
│ Agent: Forge     │              │ Agent: Sentinel   │
│ Writing code     │───git push──▶│ Reviewing PR      │
│                  │              │                    │
│ decisions/inbox/ │              │ decisions/inbox/   │
│  forge-api.md    │              │  sentinel-vuln.md  │
└───────┬──────────┘              └───────┬────────────┘
        │                                  │
        └──────────────┬───────────────────┘
                       │ git merge
                ┌──────┴──────┐
                │  Chronicle  │
                │ Merges all  │
                │ inbox → md  │
                └─────────────┘
```

**Key rules:**
1. Agents **never** write directly to `decisions.md` — only to `decisions/inbox/`
2. Each agent names its file: `{agent-name}-{brief-slug}.md`
3. Chronicle is the **only** agent that merges inbox → decisions.md
4. This avoids merge conflicts because each agent writes to a unique file

#### Exercise 21: Practice the inbox pattern

```bash
# Simulate Atlas making a decision
cat > .squad/decisions/inbox/atlas-database-choice.md << 'EOF'
## Decision: Database Selection

- **Date:** 2025-01-15
- **Decided by:** Atlas
- **Status:** Approved

### Context
Project Phoenix needs a primary data store for the API.

### Decision
Use PostgreSQL 16 with pgvector extension for future AI features.

### Rationale
- Team has strong PostgreSQL experience
- pgvector avoids a separate vector DB for embeddings
- Strong ecosystem and tooling
EOF

# Simulate Forge making a decision
cat > .squad/decisions/inbox/forge-orm-choice.md << 'EOF'
## Decision: ORM Selection

- **Date:** 2025-01-15
- **Decided by:** Forge
- **Status:** Approved

### Context
Need an ORM that works well with PostgreSQL and supports migrations.

### Decision
Use Drizzle ORM with TypeScript.

### Rationale
- Type-safe by default
- Excellent PostgreSQL support
- Lightweight, no heavy abstractions
EOF

# Now Chronicle merges them
echo "Chronicle would merge these into decisions.md with proper numbering."
ls .squad/decisions/inbox/
```

---

### 5.2 Decision Consolidation (5 min)

Over time, `decisions.md` grows. Here's how to keep it manageable:

#### Decision Format

Every decision in `decisions.md` follows this structure:

```markdown
## Decision {N}: {Title}

- **Date:** YYYY-MM-DD
- **Decided by:** {agent name}
- **Issue/PR:** #{number}
- **Status:** Approved | Superseded by #{N} | Under Review

### Context
{Why this decision was needed}

### Decision
{What was decided}

### Implications
{What this means for the team going forward}
```

#### Quarterly Knowledge Rotation

Every quarter, review decisions.md:

1. **Archive** decisions older than 6 months that are fully implemented
2. **Supersede** decisions that have been replaced by newer ones
3. **Promote** frequently-referenced decisions to the top
4. **Extract** patterns into new skills in the `skills/` library

> 💡 **Rule of thumb:** If three decisions reference the same pattern, it's time to create a skill.

---

### 5.3 Ceremonies (10 min)

Squads need regular "meetings" — structured moments where agents coordinate.

#### 🎨 Design Review (Before Complex Work)

**When:** Before any multi-agent task or architectural change
**Who:** Lead + affected agents
**Format:**

```markdown
## Design Review — {Feature Name}

### Proposed Approach
{What we plan to build and how}

### Agent Assignments
| Agent | Responsibility |
|-------|---------------|
| Atlas | API contract design |
| Forge | Implementation |
| Sentinel | Security review |

### Open Questions
- {question 1}
- {question 2}

### Decision
{Approved / Needs revision / Deferred}
```

#### 🔄 Retrospective (After Failures or Complex Work)

**When:** After a production incident, failed deployment, or complex multi-agent task
**Who:** All involved agents
**Format:**

```markdown
## Retrospective — {Event}

### Timeline
{What happened, when}

### What Went Well
- {positive outcome}

### What Went Wrong
- {issue or failure}

### Root Cause
{The underlying reason}

### Action Items
| Action | Owner | Due |
|--------|-------|-----|
| {action} | {agent} | {date} |
```

#### 🤖 Model Review (Quarterly)

**When:** Quarterly, or when new AI models are released
**Who:** Lead + all agents
**Purpose:** Evaluate whether model tier assignments are still optimal

```markdown
## Model Review — Q1 2025

### Current Assignments
| Agent | Current Tier | Tasks Last Quarter | Quality Score |
|-------|-------------|-------------------|---------------|
| Atlas | Standard | 45 decisions | 4.2/5 |
| Forge | Standard | 120 PRs | 3.8/5 |
| Sentinel | Standard | 85 reviews | 4.5/5 |
| Chronicle | Fast | 200 logs | 4.0/5 |

### Recommendations
- Sentinel → Consider Premium for security-critical reviews
- Chronicle → Fast tier is working well, keep as-is
- Forge → Standard is good; watch for complex refactoring quality
```

#### Exercise 22: Write a mini design review

Pick a feature for Project Phoenix (e.g., "Add user authentication") and write a design review document using the template above. Include:
- At least 2 agent assignments
- At least 2 open questions
- A decision (approved, with conditions)

---

## Appendix A: Quick Reference Card

### 📦 Commands

```bash
# Initialize a squad in current directory
npx @bradygaster/squad-cli init

# Create a new agent
mkdir -p .squad/agents/<name>
# Then create charter.md in that directory

# Create a new skill
mkdir -p .squad/skills/<skill-name>
# Then create SKILL.md in that directory
```

### 📁 Key Files

| File | Purpose |
|------|---------|
| `.squad/team.md` | Team roster |
| `.squad/routing.md` | Work routing rules |
| `.squad/decisions.md` | All decisions (source of truth) |
| `.squad/decisions/inbox/` | Drop-box for parallel writes |
| `.squad/ceremonies.md` | Meeting definitions |
| `.squad/agents/<name>/charter.md` | Agent definition |
| `.squad/skills/<name>/SKILL.md` | Reusable methodology |
| `squad.config.ts` | Model tiers, routing, governance |

### 🏷️ Issue Labels

| Label | Meaning |
|-------|---------|
| `squad` | Needs triage by lead |
| `squad:<agent>` | Assigned to specific agent |

### 📐 Charter Sections

```
Identity → What I Own → How I Work → Boundaries → Model → Collaboration → Voice
```

### 🔀 Routing Decision Tree

```
New work arrives
  ├── Has squad:<agent> label? → Route to that agent
  ├── Has squad label? → Lead triages
  ├── Quick fact question? → Coordinator answers directly
  ├── Two agents could handle? → Primary domain owner
  └── "Team, ..." prefix? → Fan out to all relevant agents
```

### ⚙️ Model Tiers

| Tier | Use For | Cost |
|------|---------|------|
| Fast | Routine, monitoring, formatting | $ |
| Standard | Most work, reasoning, coding | $$ |
| Premium | Critical decisions, security, rare | $$$ |

---

## Appendix B: Troubleshooting

### Common Issues

#### ❓ "Agent doesn't pick up work"

**Symptoms:** Issue is labeled but no agent responds.

**Checklist:**
1. Is the agent registered in `team.md`?
2. Is the agent's label in `routing.md`?
3. Does the charter.md exist in `.squad/agents/<name>/`?
4. Is the agent's status set to ✅ Active?

#### ❓ "Agents conflict on the same work"

**Symptoms:** Two agents make contradictory changes.

**Fix:**
- Review `routing.md` for overlapping work types
- Ensure boundaries in each charter are clear and non-overlapping
- Use the "primary domain owner" routing rule
- Add the constraint to `decisions.md`

#### ❓ "decisions.md has merge conflicts"

**Symptoms:** Git conflicts in the decisions file.

**Fix:**
- Agents should **never** write directly to `decisions.md`
- Always use `decisions/inbox/` with unique filenames
- Let Chronicle (or your logger agent) merge

#### ❓ "Agent quality is low"

**Symptoms:** Agent outputs are vague or incorrect.

**Checklist:**
1. Is the charter too vague? Add more specific expertise
2. Is the model tier appropriate? Try upgrading
3. Does the agent have access to relevant skills?
4. Are there decisions it should be reading?

#### ❓ "Init fails or hangs"

**Symptoms:** `npx @bradygaster/squad-cli init` doesn't complete.

**Fix:**
```bash
# Clear npm cache
npm cache clean --force

# Try with explicit version
npx @bradygaster/squad-cli@latest init

# Check Node.js version (need 20+)
node --version
```

#### ❓ "GitHub Actions workflow doesn't trigger"

**Symptoms:** Adding the `squad` label doesn't trigger triage.

**Checklist:**
1. Is the workflow file in `.github/workflows/`?
2. Is the `on.issues.types` set to `[opened, labeled]`?
3. Does the repository have Actions enabled?
4. Check the Actions tab for error logs

---

## Appendix C: Sample squad.config.ts

```typescript
import type { SquadConfig } from '@bradygaster/squad-cli';

const config: SquadConfig = {
  version: '1.0.0',

  // Model tier assignments
  models: {
    defaultModel: 'claude-sonnet-4.5',
    tiers: {
      fast: 'claude-haiku-4.5',
      standard: 'claude-sonnet-4.5',
      premium: 'claude-opus-4.6',
    },
    // Per-agent overrides (optional)
    agentOverrides: {
      chronicle: 'claude-haiku-4.5',    // Logger runs on fast tier
      sentinel: 'claude-sonnet-4.5',     // Reviews need standard
      // atlas: 'claude-opus-4.6',       // Uncomment for premium lead
    },
  },

  // Work routing configuration
  routing: {
    rules: [
      { workType: 'architecture',   agent: 'atlas' },
      { workType: 'feature-dev',    agent: 'forge' },
      { workType: 'bug-fix',        agent: 'forge' },
      { workType: 'code-review',    agent: 'sentinel' },
      { workType: 'security',       agent: 'sentinel' },
      { workType: 'testing',        agent: 'sentinel' },
      { workType: 'documentation',  agent: 'chronicle' },
      { workType: 'logging',        agent: 'chronicle' },
    ],
    governance: {
      eagerByDefault: true,          // Spawn agents that could start work
      chronicleAutoRuns: true,       // Chronicle runs after every task
      allowRecursiveSpawn: false,    // Prevent infinite agent loops
    },
  },

  // Agent casting/selection
  casting: {
    // Theme for agent naming (optional, for fun)
    theme: 'mythology',
    overflowStrategy: 'generic',     // If no agent matches, use generic
  },

  // Platform-specific settings
  platforms: {
    vscode: {
      chronicleMode: 'sync',         // Chronicle logs synchronously in VS Code
    },
  },
};

export default config;
```

---

## 🎓 What You Built Today

By the end of this workshop, you have:

- [x] **Initialized** a squad project with the CLI
- [x] **Created 4 specialized agents** with detailed charters
- [x] **Defined routing rules** that map work types to agents
- [x] **Built a shared skill** (code review) usable by any agent
- [x] **Set up automation** with GitHub Actions for triage and monitoring
- [x] **Practiced the inbox pattern** for safe parallel decision writes
- [x] **Learned ceremonies** for design reviews, retros, and model reviews

### 🚀 Next Steps

1. **Add more agents** — Consider a DevOps agent, a UX agent, or a data agent
2. **Create more skills** — Document your team's best practices as SKILL.md files
3. **Integrate with your CI/CD** — Have agents comment on PRs automatically
4. **Run a model review** — After a month, evaluate if your model tiers are right
5. **Explore the framework** — Check out the [`@bradygaster/squad-cli`](https://www.npmjs.com/package/@bradygaster/squad-cli) package for more features

---

## 📚 Resources

| Resource | Link |
|----------|------|
| Squad CLI (npm) | [`@bradygaster/squad-cli`](https://www.npmjs.com/package/@bradygaster/squad-cli) |
| GitHub Copilot | [github.com/features/copilot](https://github.com/features/copilot) |
| GitHub Actions | [docs.github.com/actions](https://docs.github.com/en/actions) |
| GitHub Projects | [docs.github.com/issues/planning](https://docs.github.com/en/issues/planning-and-tracking-with-projects) |

---

> *"A team of specialists, each brilliant in their domain, coordinated by clear rules and shared memory. That's Squad."*
