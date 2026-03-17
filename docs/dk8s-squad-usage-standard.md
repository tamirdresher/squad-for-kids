# DK8S Squad Usage Standard & Guidelines

> Baseline standard for Squad adoption across the DK8S Platform engineering group.
> Authored by Picard (Lead) with input from Adir, Tamir Dresher.
> Status: **Draft — v0.1**

---

## Why This Document Exists

Adir said it plainly:

> "We need a clear baseline — how tasks are tracked, how flows/prompts are structured, and what validation, testing, and review standards look like. Otherwise, we risk fragmentation instead of leverage."

This document is that baseline. It covers:
1. How DK8S organizes its Squad topology (org → swimlane → personal)
2. What every Squad in the group must do (non-negotiable gates)
3. What each engineer can customize (universe, ceremonies, local preferences)
4. How cross-team activities (vuln management, CI/CD, cleanups) are coordinated
5. How to get started from zero

If you're reading this and you don't have a Squad yet, skip to [Section 5: Getting Started](#5-getting-started).

---

## 1. Squad Topology for DK8S

### The Three-Level Model

Squad operates across three organizational levels. Knowledge flows **down** (org → team → repo). Skills are **promoted up** manually when they've proven themselves.

```
DK8S Org-Level Squad (microsoft-mtp/dk8s-squad repo)
│
├── .squad/
│   ├── decisions.md            ← org-wide policies (security gates, review requirements)
│   ├── skills/                 ← shared patterns (vuln scanning, PR review, incident response)
│   ├── routing.md              ← default routing rules for DK8S work
│   ├── team.md                 ← org-level agent roster (shared casting)
│   └── upstream.json           ← (empty — this IS the top-level upstream)
│
├── Swimlane Squads (per team area)
│   ├── platform-core/          ← core platform, ARM templates, K8s operators
│   ├── security-compliance/    ← SDL, vulnerability management, CVEs
│   ├── infrastructure/         ← AKS clusters, networking, CI/CD pipelines
│   └── tooling-dx/             ← developer experience, ConfigGen SDK
│
└── Personal Squads (per engineer, separate repos)
    ├── tamir-squad             ← Star Trek: TNG + Voyager universe ✅
    ├── adir-squad              ← [Adir picks universe]
    ├── moshe-squad             ← [Moshe picks universe]
    └── ...                     ← Every engineer gets one
```

### How the Levels Connect

Each personal squad inherits from the org-level squad via upstream:

```bash
# In your personal squad repo:
squad upstream add https://github.com/microsoft-mtp/dk8s-squad.git --name dk8s-org
squad upstream sync
```

This means:
- Org-level **decisions** (security gates, review standards) flow down to every personal squad
- Org-level **skills** (incident response, DK8S support patterns) are available everywhere
- Org-level **routing rules** provide defaults that repos can override

The resolution model is **closest-wins**: your repo's `.squad/decisions.md` takes priority over the org-level one. But org-level security policies are marked as non-overridable (see [Governance](#7-governance)).

### Swimlane Squads: Two Models

Swimlane-level coordination can use either approach:

| Model | When to Use | Example |
|-------|-------------|---------|
| **SubSquads** (`.squad/streams.json`) | Multiple teams in one mono-repo | `dk8s-operators` repo with platform + infra teams |
| **Separate repos** with shared upstream | Independent repos per team area | `dk8s-security-tools` repo with its own squad |

**SubSquads example** (`.squad/streams.json`):
```json
{
  "workstreams": [
    {
      "name": "platform-core",
      "labelFilter": "team:platform",
      "folderScope": ["operators/", "controllers/", "api/"],
      "workflow": "default"
    },
    {
      "name": "infrastructure",
      "labelFilter": "team:infra",
      "folderScope": ["infra/", "deploy/", ".github/workflows/"],
      "workflow": "default"
    }
  ]
}
```

**Activate a SubSquad:**
```bash
squad subsquads activate platform-core
# or via environment variable:
export SQUAD_TEAM=platform-core
```

### Branch Naming with SubSquads
```
{subsquad-name}/issue-{number}-{description}
# Examples:
platform-core/issue-42-fix-reconciler-crash
infrastructure/issue-78-aks-node-pool-scaling
```

---

## 2. Baseline Standards

These are the non-negotiable practices for every Squad in the DK8S group. They apply whether you're in a personal squad, a swimlane squad, or the org-level squad.

### 2.1 Task Tracking

**System:** GitHub Issues in each repo.

**Required labels:**

| Label | Purpose | Example |
|-------|---------|---------|
| `squad` | Untriaged — sitting in the Lead's inbox | New issue, needs triage |
| `squad:{member}` | Assigned to a specific agent or person | `squad:belanna`, `squad:data`, `squad:copilot` |
| `priority:critical` | Drop everything | Production incident, security vuln |
| `priority:high` | Next sprint | Feature blocking another team |
| `priority:medium` | Backlog — planned | Improvement, tech debt |
| `priority:low` | Nice to have | Cleanup, optimization |
| `type:bug` | Defect | Broken functionality |
| `type:feature` | New capability | New API, new tool |
| `type:security` | Security-related | CVE, SDL finding, hardening |
| `type:cleanup` | Tech debt, refactoring | Dead code, dependency update |
| `type:docs` | Documentation | README, ADR, runbook |

**Triage workflow:**
1. Issue created → auto-labeled `squad`
2. Lead triages: evaluates scope, assigns `squad:{member}` label, adds priority
3. Lead evaluates @copilot fit using capability profile:
   - 🟢 **Good fit** (bugs, test additions, well-defined tasks) → `squad:copilot`
   - 🟡 **Needs review** (small features with specs) → `squad:{member}` + PR review required
   - 🔴 **Not suitable** (architecture, security, design judgment) → human or specialized agent only
4. Named member picks up issue in next session

### 2.2 Flow & Prompt Structure

**Issue templates** — every repo should have these in `.github/ISSUE_TEMPLATE/`:

```yaml
# .github/ISSUE_TEMPLATE/squad-task.yml
name: Squad Task
description: Standard task for Squad processing
labels: ["squad"]
body:
  - type: dropdown
    id: priority
    attributes:
      label: Priority
      options:
        - critical
        - high
        - medium
        - low
  - type: dropdown
    id: type
    attributes:
      label: Type
      options:
        - bug
        - feature
        - security
        - cleanup
        - docs
  - type: textarea
    id: description
    attributes:
      label: Description
      description: What needs to happen? Include acceptance criteria.
  - type: textarea
    id: context
    attributes:
      label: Context
      description: Links, logs, related issues.
```

**Routing rules** — every repo's `.squad/routing.md` should include at minimum:

```markdown
## Routing Table
| Work Type | Route To | Examples |
|-----------|----------|----------|
| K8s, Helm, ArgoCD | B'Elanna | Operator bugs, Helm chart fixes |
| Security, compliance | Worf | CVE response, SDL findings |
| C#, Go, .NET code | Data | Code review, refactoring |
| Architecture decisions | Picard | Design review, trade-off analysis |
| Async bounded tasks | @copilot | Test additions, bug fixes with repro |
```

### 2.3 Validation & Security Gates

**Every PR must pass these gates before merge:**

| Gate | Tool | Blocks Merge? | Notes |
|------|------|---------------|-------|
| CodeQL / SAST | GitHub Advanced Security | ✅ Yes | No new high/critical findings |
| Dependency scan | Dependabot / GH Advisory | ✅ Yes | No known vulnerable deps |
| Unit tests | Repo CI pipeline | ✅ Yes | All tests pass, no regressions |
| AI code review | Squad code-review agent | ⚠️ Advisory | Surfaces bugs, logic errors — human decides |
| Human review | PR approver | ✅ Yes for 🔴 items | Required for architecture, security, API changes |

**Three-tier review model:**
1. **Automated SAST** — CodeQL, dependency scanning, secret scanning run on every PR
2. **AI code review** — Squad's code-review agent analyzes diff for bugs, security issues, logic errors
3. **Human approval** — Required for:
   - Any change touching authentication, authorization, or encryption
   - API surface changes (new endpoints, changed contracts)
   - Infrastructure changes (Helm values, Terraform, ARM templates)
   - Architecture decisions (new patterns, dependency additions)

### 2.4 Testing Standards

**Agent-written tests required for all code PRs.** If an agent writes code, the same PR must include tests.

| Change Type | Required Tests | Coverage |
|-------------|---------------|----------|
| Bug fix | Regression test proving the fix | Must fail without fix, pass with it |
| New feature | Unit + integration tests | Happy path + key error paths |
| Refactor | Existing tests must pass | No coverage regression |
| Config change | Validation test | Config parses and applies correctly |

**Test naming convention:**
```
Test_{MethodUnderTest}_{Scenario}_{ExpectedResult}
// Example:
Test_ReconcileCluster_NodePoolMissing_CreatesNodePool
```

### 2.5 Decision Recording

**All significant decisions go in `.squad/decisions.md`** or `.squad/decisions/inbox/`.

A decision is "significant" if:
- It affects more than one person or repo
- It establishes a pattern others should follow
- It has security or compliance implications
- It would be confusing if someone didn't know about it

**Decision format:**
```markdown
### Decision {N}: {Title}
- **Date:** YYYY-MM-DD
- **Author:** {agent or person}
- **Status:** Active | Superseded by #{M}
- **Context:** Why was this decision needed?
- **Decision:** What was decided?
- **Consequences:** What changes because of this?
```

**Inbox workflow:**
1. Agent writes decision to `.squad/decisions/inbox/{author}-{slug}.md`
2. Lead reviews and either promotes to `decisions.md` or sends back with feedback
3. Promoted decisions are append-only — supersede, don't edit

---

## 3. Cross-Team Activities

These activities span multiple repos and swimlanes. Each has a named owner.

### 3.1 Vulnerability Management

| Aspect | Standard |
|--------|----------|
| **Owner** | Worf (Security & Cloud agent) + human security lead |
| **Scope** | All DK8S repos (~50 repos) |
| **Tooling** | GitHub Advanced Security alerts, Dependabot, CodeQL |
| **Cadence** | Daily scan by Ralph; critical vulns escalate immediately |
| **Workflow** | Ralph scans → Worf triages → creates `type:security` issues → human approves fix PRs |
| **Escalation** | Critical/High CVEs → Teams notification to `defenderk8splatform@microsoft.com` within 4 hours |

**Shared skill:** `dk8s-support-patterns` — common cluster issues, capacity exhaustion, node bootstrap failures, Azure platform misattribution.

### 3.2 CI/CD Alignment

| Aspect | Standard |
|--------|----------|
| **Owner** | B'Elanna (Infrastructure Expert) |
| **Scope** | Shared pipeline templates across all DK8S repos |
| **Location** | Org-level squad's `.squad/skills/` |
| **Standard** | All repos use shared OneBranch/ADO pipeline templates |
| **Validation** | `helm-validate` skill for chart linting; `binlog-generation` for .NET build diagnosis |

### 3.3 Automated Cleanups

| Aspect | Standard |
|--------|----------|
| **Owner** | Ralph (Work Monitor) with Data (Code Expert) |
| **Scope** | Cross-repo tech debt scanning |
| **Cadence** | Weekly sweep by Ralph |
| **Types** | Stale branches (>30 days), abandoned PRs, TODO/FIXME audit, dependency freshness |
| **Action** | Ralph creates `type:cleanup` issues; Data or @copilot picks them up |

### 3.4 Incident Response

| Aspect | Standard |
|--------|----------|
| **Owner** | On-call engineer + Worf + B'Elanna |
| **Shared skill** | `incident-response` — always check Azure Status page first |
| **Workflow** | ICM fires → on-call picks up → Squad agents assist with log analysis, blast radius assessment |
| **Post-incident** | Decision recorded in `decisions.md`; runbook updated if gap found |

### 3.5 ConfigGen Support

| Aspect | Standard |
|--------|----------|
| **Owner** | Data (Code Expert) |
| **Shared skill** | `configgen-support-patterns` — enforcement breaking builds, auto-gen conflicts, modeling gaps |
| **Scope** | All repos consuming ConfigurationGeneration.* NuGet packages |
| **Workflow** | Support ticket → DK8S queue → Data triages with skill patterns → fix or escalate |

### 3.6 Ownership Matrix

| Cross-Team Activity | Primary Owner | Secondary | Escalation |
|---------------------|--------------|-----------|------------|
| Vulnerability management | Worf | Human security lead | `defenderk8splatform@microsoft.com` |
| CI/CD templates | B'Elanna | Pipeline engineer | Swimlane lead |
| Cleanups & tech debt | Ralph + Data | @copilot | Picard |
| Incident response | On-call + Worf | B'Elanna | ICM |
| ConfigGen support | Data | `configgen-support-patterns` skill | Tamir |
| Knowledge consolidation | Seven | Picard | — |

---

## 4. Personal Squad Customization

### What's Yours to Customize

Each engineer gets a personal squad. It's your workspace. You pick:

| Customizable | Example |
|-------------|---------|
| **Universe / casting** | Star Trek, Star Wars, Marvel, Dune, Lord of the Rings, anime — your call |
| **Agent names & personalities** | Picard → Gandalf, Worf → Wolverine, etc. |
| **Ceremonies** | Daily standup format, retrospective style |
| **Local preferences** | Editor settings, shell aliases, notification preferences |
| **Additional agents** | Add role-specific agents for your workflow |
| **Model assignments** | Pick faster/cheaper models for routine tasks |

### What's NOT Yours to Override

These flow down from the org-level upstream and are enforced:

| Non-Overridable | Why |
|----------------|-----|
| Security review gates | Compliance — SDL requirements |
| PR must have tests | Quality baseline |
| Decision recording format | Cross-team readability |
| Vulnerability scan requirements | Security posture |
| Label taxonomy (`squad`, `priority:*`, `type:*`) | Cross-team reporting |
| Escalation paths for `priority:critical` | Incident response SLA |

### How Upstream Enforcement Works

The org-level squad marks non-overridable decisions with `[ENFORCED]`:

```markdown
### Decision 1: Security Review Gate [ENFORCED]
All PRs touching auth, encryption, or API surfaces require human approval.
This decision cannot be overridden by downstream squads.
```

Closest-wins still applies for everything else. If the org says "use TypeScript" but your repo is a Go operator, your repo-level decision wins locally.

### Personal Squad Setup Example (Star Trek)

Tamir's squad (the reference implementation):

```
tamresearch1/.squad/
├── team.md                 ← Picard (Lead), B'Elanna, Worf, Data, Seven, ...
├── decisions.md            ← 45+ decisions (local + inherited)
├── routing.md              ← Work routing table
├── skills/                 ← 35 skills (mix of personal + inherited)
│   ├── dk8s-support-patterns/     ← inherited from org
│   ├── incident-response/         ← inherited from org
│   ├── blog-writing/              ← personal (Tamir's voice)
│   └── voice-writing/             ← personal (Tamir's tone)
├── agents/
│   ├── picard/charter.md
│   ├── belanna/charter.md
│   ├── worf/charter.md
│   └── ...
└── upstream.json           ← points to dk8s-org squad
```

---

## 5. Getting Started

### Day 1 Checklist

```
□ Step 1: Create your personal squad repo
□ Step 2: Initialize Squad and pick your universe
□ Step 3: Connect to DK8S org-level upstream
□ Step 4: Configure MCP servers (ADO, GitHub, EngHub)
□ Step 5: Create your first issue and let Squad process it
□ Step 6: Verify Ralph loop is running
```

### Step 1: Create Your Personal Squad Repo

```bash
# Create repo in microsoft-mtp org (or your personal GitHub)
gh repo create microsoft-mtp/{your-alias}-squad --private --clone
cd {your-alias}-squad
```

### Step 2: Initialize Squad

```bash
squad init
# Interactive prompt:
#   Pick your universe: Star Trek / Star Wars / Marvel / Custom
#   Name your Lead agent
#   Configure team size (start small — 4-5 agents)
```

Minimum viable team:

| Role | What They Do |
|------|-------------|
| Lead | Triage, architecture decisions, routing |
| Code Expert | C#/Go code changes, reviews |
| Infrastructure Expert | K8s, Helm, cloud infra |
| Security Expert | Security review, compliance |
| Work Monitor (Ralph) | Background issue scanning, cleanup |

### Step 3: Connect to DK8S Org-Level Upstream

```bash
squad upstream add https://github.com/microsoft-mtp/dk8s-squad.git --name dk8s-org
squad upstream sync

# Verify inherited content:
ls .squad/_upstream_repos/dk8s-org/
# Should see: decisions.md, skills/, routing.md
```

### Step 4: Configure MCP Servers

Your `.copilot/mcp-config.json` (or `.vscode/mcp.json`) should include:

```jsonc
{
  "servers": {
    // Azure DevOps — work items, pipelines, repos
    "azure-devops": {
      "command": "npx",
      "args": ["-y", "@anthropic/azure-devops-mcp"],
      "env": {
        "AZURE_DEVOPS_ORG": "your-org",
        "AZURE_DEVOPS_PAT": "${env:AZURE_DEVOPS_PAT}"
      }
    },
    // GitHub — issues, PRs, code search
    "github": {
      "command": "npx",
      "args": ["-y", "@anthropic/github-mcp"],
      "env": {
        "GITHUB_TOKEN": "${env:GH_TOKEN}"
      }
    },
    // EngHub — internal documentation search
    "enghub": {
      "command": "npx",
      "args": ["-y", "@anthropic/enghub-mcp"]
    }
  }
}
```

### Step 5: Create Your First Issue

```bash
# Create a test issue
gh issue create \
  --title "Test: Squad processes first issue" \
  --body "Verify squad triage, assignment, and completion workflow." \
  --label "squad,priority:low,type:docs"

# Watch the Lead triage it:
# Lead reads issue → assigns squad:{member} label → member picks it up
```

### Step 6: Verify Ralph Loop

Ralph should be scanning for work. Check:

```bash
# In your Copilot CLI session:
# "Ralph, status" → should show work queue, open issues, pending PRs
```

Ralph's keep-alive loop:
1. Scan open issues labeled `squad` (untriaged)
2. Scan open PRs (review needed)
3. Scan for stale branches, abandoned work
4. Report findings → Lead triages

---

## 6. Shared Skills Catalog

These skills live in the org-level squad (`microsoft-mtp/dk8s-squad`) and are inherited by every downstream squad via upstream sync.

### Org-Level Skills (Shared Across All DK8S Squads)

| Skill | Description | Owner |
|-------|------------|-------|
| `dk8s-support-patterns` | K8s cluster issue patterns: capacity exhaustion, node bootstrap failures, Azure platform misattribution | B'Elanna |
| `configgen-support-patterns` | ConfigGen SDK recurring issues: enforcement breaking builds, auto-gen conflicts, modeling gaps | Data |
| `incident-response` | ICM response: always check Azure Status page first, blast radius assessment, escalation protocol | Worf |
| `secrets-management` | Credential handling: Windows Credential Manager (priority 1), machine-local .env (priority 2), never in git | Worf |
| `dotnet-build-diagnosis` | .NET build error categorization: missing packages, framework refs, duplicate definitions | Data |
| `squad-conventions` | Squad CLI patterns: zero-dependency policy, Node.js test runner, error handling via `fatal()` | Picard |

### Skills Eligible for Promotion (Currently Personal, May Graduate)

| Skill | Current Location | Promotion Criteria |
|-------|-----------------|-------------------|
| `github-distributed-coordination` | Tamir's squad | Validate with 2+ engineers using multi-machine workflow |
| `cross-machine-coordination` | Tamir's squad | Validate task queue works across team machines |
| `fact-checking` | Tamir's squad | If other squads want Q-style verification |

### Personal-Only Skills (Stay in Individual Squads)

| Skill | Why Personal |
|-------|-------------|
| `blog-writing` | Tamir's personal voice and blog series |
| `voice-writing` | Individual writing tone matching |
| `news-broadcasting` | Neelix formatting preferences |
| `outlook-automation` | Machine-specific COM automation |
| `session-recovery` | Copilot CLI session tooling |

### Skill Promotion Path

Skills mature through confidence levels before promotion to org-level:

```
Low (single observation, one repo)
  → Medium (validated in multiple contexts)
    → High (battle-tested, reviewed by humans)
      → Promoted to org-level upstream
```

**To promote a skill:**
```bash
# Export from your personal squad
squad export --skill dk8s-support-patterns -o dk8s-support.json

# Submit as PR to org-level squad repo
cd /path/to/dk8s-squad
# Copy skill, create PR, get Lead approval
```

---

## 7. Governance

### Decision Authority Matrix

| Scope | Who Decides | Examples |
|-------|------------|---------|
| **Org-level** | Lead (Picard) + Tamir approval | Security gates, label taxonomy, review standards |
| **Swimlane-level** | Swimlane lead | Team-specific conventions, local CI customizations |
| **Personal squad** | Individual engineer (autonomous) | Universe, casting, ceremonies, model assignments |
| **Security decisions** | Always escalate to human | Auth changes, encryption, access control, CVE response |

### The Closest-Wins Rule

```
Org-level decision: "Use structured logging with correlation IDs"
  ↓ flows down to all squads

Swimlane override: "Use Serilog specifically" (narrows the org policy)
  ↓ flows down to swimlane repos

Repo override: "Add custom enrichers for K8s metadata" (extends further)
  ↓ applies locally
```

Each level can **narrow or extend** the upstream decision. No level can **contradict** an `[ENFORCED]` decision.

### Enforced Policies (Non-Overridable)

These decisions are marked `[ENFORCED]` in the org-level `decisions.md` and cannot be overridden at any level:

1. **Security review gate** — PRs touching auth/encryption/API surfaces require human approval
2. **Vulnerability scanning** — All repos must have CodeQL and Dependabot enabled
3. **Secret hygiene** — No secrets in source code, ever. Use Credential Manager or Azure Key Vault
4. **Decision recording** — Significant decisions must be written down
5. **Test requirement** — Code PRs must include tests
6. **Escalation for critical** — `priority:critical` issues notify `defenderk8splatform@microsoft.com`

### Dispute Resolution

1. Agent disagrees with another agent → Lead decides
2. Engineer disagrees with Lead agent → Human (Tamir) decides
3. Cross-swimlane conflict → Org-level Lead + swimlane leads discuss
4. Security disagreement → Always defaults to the more restrictive option

---

## 8. MCP Server Configuration Reference

Every DK8S squad should have these MCP servers available:

| Server | Purpose | Required? |
|--------|---------|-----------|
| `azure-devops` | ADO work items, pipelines, repos, wiki | ✅ Yes |
| `github` | GitHub issues, PRs, code search, Actions | ✅ Yes |
| `enghub` | EngHub documentation, TSGs, knowledge articles | ✅ Yes |
| `playwright` | Browser automation for web testing | Optional |
| `mail` | Email integration (Outlook) | Optional |
| `teams` | Teams messaging | Optional |

### Authentication

```powershell
# GitHub token (use gh CLI)
$env:GH_TOKEN = (gh auth token --user your_alias_microsoft 2>&1).Trim()

# Azure DevOps PAT
$env:AZURE_DEVOPS_PAT = "your-pat-from-credential-manager"

# Never hard-code tokens. Use environment variables or Credential Manager.
```

---

## 9. Appendix: File Structure Reference

### Org-Level Squad Repo (`dk8s-squad`)

```
dk8s-squad/
├── .squad/
│   ├── team.md                     ← org-level agent roster
│   ├── decisions.md                ← org-wide policies [ENFORCED] items
│   ├── routing.md                  ← default routing rules
│   ├── ceremonies.md               ← shared ceremony definitions
│   ├── skills/
│   │   ├── dk8s-support-patterns/
│   │   ├── configgen-support-patterns/
│   │   ├── incident-response/
│   │   ├── secrets-management/
│   │   ├── dotnet-build-diagnosis/
│   │   └── squad-conventions/
│   └── templates/
│       ├── issue-template.yml      ← standard issue template
│       ├── pr-template.md          ← standard PR template
│       └── decision-template.md    ← decision recording template
├── docs/
│   ├── dk8s-squad-usage-standard.md  ← this document
│   └── onboarding/
│       └── day-1-checklist.md
└── README.md
```

### Personal Squad Repo (`{alias}-squad`)

```
{alias}-squad/
├── .squad/
│   ├── team.md                     ← your cast (your universe!)
│   ├── decisions.md                ← personal + inherited decisions
│   ├── routing.md                  ← your routing overrides
│   ├── upstream.json               ← points to dk8s-squad
│   ├── _upstream_repos/            ← (gitignored) cloned upstream
│   │   └── dk8s-org/
│   ├── skills/
│   │   ├── [inherited skills appear here after sync]
│   │   └── [your personal skills]
│   └── agents/
│       ├── {lead}/charter.md
│       ├── {code-expert}/charter.md
│       └── ...
├── .copilot/
│   └── mcp-config.json            ← MCP server configuration
└── squad.config.ts                 ← Squad runtime config
```

---

## 10. FAQ

**Q: Do I have to use Star Trek?**
No. Pick any universe. Star Trek is Tamir's choice. Your personal squad, your casting. The org-level squad uses neutral role names (Lead, Code Expert, etc.) so universes don't clash.

**Q: What if my repo doesn't need all the agents?**
Start with 4-5. Minimum viable: Lead, Code Expert, Security Expert, Work Monitor. Add more as you find gaps.

**Q: Can I override an org-level security gate?**
No. `[ENFORCED]` decisions cannot be overridden. If you believe one should change, raise it with Picard/Tamir. The decision will be discussed and the org-level `decisions.md` updated if approved.

**Q: How often does upstream sync happen?**
On demand: `squad upstream sync`. Not automatic. Run it when you want the latest org-level decisions and skills.

**Q: What if two agents claim the same issue?**
Git-based claiming: the first agent to push a branch with `squad/issue-{N}-*` owns it. If two race, git merge conflict is the tiebreaker. In practice, the Lead assigns explicitly via labels.

**Q: Where do I report a bug in the Squad framework itself?**
`bradygaster/squad` repo (the upstream framework). Not in the DK8S org-level squad. Brady Gaster owns the framework; Tamir Dresher owns our usage of it.

**Q: What's the distribution list for DK8S escalations?**
`defenderk8splatform@microsoft.com` — the official DK8S Platform group distribution list.

---

*This is a living document. Updates go through the org-level squad's PR process. Propose changes via `.squad/decisions/inbox/` and tag Picard for review.*

*Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>*
