---
layout: post
title: "From Personal Repo to Work Team — Scaling Squad to Production"
date: 2026-03-04
tags: [ai-agents, squad, github-copilot, scaling, team-workflows, productivity]
series: "Scaling AI-Native Software Engineering"
series_part: 2
---

By now you know the story. In [Part 0](/blog/2026/03/10/organized-by-ai), I told you how Squad became the first productivity system I didn't abandon after three days. In [Part 1](/blog/2026/03/11/scaling-ai-part1-first-team), you saw how Ralph and my Star Trek crew assimilated my backlog while I slept.

That was the personal repo. My playground. My experimental sandbox where Picard could make architecture decisions at 2 AM and nobody would complain.

Then came the question I'd been avoiding: *Can I bring this to my actual job?*

My team at Microsoft — the DK8S (Distributed Kubernetes) platform team — manages infrastructure that real Azure services depend on. We have code review standards, security scanning, FedRAMP requirements, deployment gates. Six engineers, each with deep expertise. Production systems that can't tolerate "my AI agent had an interesting idea at 3 AM."

This isn't a playground. Could Squad actually work here?

Turns out: yes. But not by copy-pasting my personal setup. The breakthrough wasn't teaching Squad to work *around* my team — it was teaching Squad to work *with* them.

![Resistance is futile](https://github.com/user-attachments/assets/06ab6aad-52d4-4e16-a904-4df98b0be3d3)
*"Resistance is futile. Your work team will be assimilated. Probably."*

---

## Wait, What About My Team?

Here's the problem: In my personal repo, I'm the only human. Picard runs the show. Data writes code. Seven writes docs. Nobody needs permission because there's nobody to ask.

But on a real engineering team? That's six humans with opinions, expertise, and merge authority. You can't just drop an AI team into that and say "assimilate the backlog."

Actually... you kind of can. But only if you do the one thing that changes everything:

**You make the humans part of the Squad.**

---

## Human Squad Members — Not a Workaround, The Whole Point

Remember in Part 1 when I showed you the Squad casting system? Picard as Lead, Data as Code Expert, Worf on Security? That works great when you're the only human.

But here's what I did for the work repo: I added our *real engineers* to `.squad/team.md`.

**Human Squad Members:**

```markdown
## Human Members

- **Brady Gaster** (@bradygaster) — Human Squad Member
  - Role: Engineering Lead
  - Expertise: Squad architecture, platform design, Go/C#
  - Scope: Architecture review, cross-team coordination, Squad framework itself

- **Tamir Dresher** (@tamirdresher) — Human Squad Member  
  - Role: AI Integration Lead
  - Expertise: AI workflows, DevOps automation, C#/.NET
  - Scope: Squad adoption, agent orchestration, integration patterns

- **Worf** (@worf-security) — Human Squad Member
  - Role: Security & Compliance
  - Expertise: FedRAMP, supply chain security, threat modeling
  - Scope: Security reviews, compliance validation, infrastructure hardening

- **B'Elanna Torres** (@belanna-infra) — Human Squad Member
  - Role: Infrastructure
  - Expertise: Kubernetes, Azure networking, CI/CD
  - Scope: Cluster operations, deployment automation, infrastructure code
```

**AI Squad Members:**

```markdown
## AI Agents

- **Picard** (AI Lead)
  - Role: Architecture & Orchestration
  - Scope: Task decomposition, design review, delegation
  - Routes to: Brady (human), Tamir (human)

- **Data** (AI Code Expert)
  - Role: Code analysis, review, implementation
  - Scope: Go operators, C# tooling, code quality
  - Routes to: Brady (human, for design), Worf (human, for security)
```

See what happened there? **Brady isn't just "the guy who reviews PRs." He's a Squad member.** So is Worf. So is B'Elanna. They have charters, expertise areas, and scopes — just like the AI agents.

The routing rules in `.squad/routing.md` define when AI squad members pause and escalate to human squad members:

```markdown
## Routing Rules

### Architecture Decisions
- **Trigger:** Changes to CRD schemas, API contracts, multi-repo dependencies
- **Route to:** @bradygaster (human)
- **AI action:** Analysis + recommendations, then pause for human approval

### Security Reviews
- **Trigger:** Authentication, secrets, network policies, supply chain changes
- **Route to:** @worf-security (human)
- **AI action:** Automated scans + findings, then pause for human sign-off

### Go Operator Code
- **Trigger:** Reconciler logic, Kubernetes client code, controller changes
- **Route to:** Data (AI) → @bradygaster (human review)
- **AI action:** Implementation, tests, then PR for human review

### Documentation
- **Trigger:** READMEs, runbooks, API docs, design docs
- **Route to:** Seven (AI) → @tamirdresher (human review)
- **AI action:** Draft, then ping human for review before merge
```

This is the breakthrough. In my personal repo, Squad was *my team* — AI agents working for me. In the work repo, Squad became *our team* — humans and AI working together, with clear escalation paths when human judgment is required.

The AI squad members handle grunt work. The human squad members handle judgment calls. Nobody wastes time on work the other can do better.

---

---

## What AI Squad Members Actually Do

With routing rules in place, here's what our AI squad members handle:

### 1. Code Review Pre-Screening

When a PR is opened, Data (AI squad member) does the first pass:
- Scans for obvious issues (unhandled errors, leaked contexts, missing tests)
- Checks against team conventions (from `.squad/decisions.md`)
- Flags security concerns (credentials in code, unsafe resource access)
- Writes a review summary

Then routes to Brady or another human squad member if critical issues are found, or approves routine changes automatically.

**Impact:** Human squad members see PRs that already passed basic quality checks. We spend time on architecture and design, not hunting for forgotten error handling.

### 2. Test Scaffolding

For new Go operator features, Data (AI squad member) generates the test skeleton:
- Unit tests for reconciler logic
- Integration test structure
- Mock Kubernetes client setup
- Coverage tracking

Then hands off to a human squad member to fill in the business logic assertions.

**Impact:** New features ship with tests from day one. The "I'll add tests later" excuse doesn't work when Data already built the scaffolding.

### 3. Documentation Sync

Seven (AI squad member for docs) watches for code changes that affect documentation:
- CRD schema changes → update API reference
- New command flags → update CLI docs
- Helm chart changes → update deployment guide

Drafts the doc updates, creates a PR, and pings the human squad member who authored the code for review.

**Impact:** Documentation stays in sync with code because the sync is automatic. Docs debt doesn't accumulate. And unlike my personal repo where Seven can merge docs freely, here she waits for a human squad member to approve.

### 4. Security Scanning

Our human squad member Worf (the security lead) delegates continuous scanning to AI squad members:
- Dependency vulnerability scans
- Secrets detection
- Supply chain analysis (SBOM generation)
- FedRAMP compliance checks

Findings are logged in `.squad/decisions.md` with remediation steps. Critical issues pause the build and route to Worf (human) for review.

**Impact:** Security isn't a gate at the end. It's continuous. Vulnerabilities are caught before they reach production, but a human squad member still makes the final call.

### 5. Cross-Repo Coordination

Our platform has 12 repos. When a change in one repo affects others (API contract change, shared library update), Picard (AI squad member, Lead):
- Identifies downstream impact
- Opens tracking issues in affected repos
- Creates a coordination plan with sequenced PRs
- Monitors the rollout across repos

Then hands the plan to Brady (human squad member, Engineering Lead) for approval before execution.

**Impact:** Multi-repo changes that used to take days of coordination now happen with a single approved plan. The AI squad member handles the sequencing and tracking. The human squad member owns the decision.

---

---

## The First Real Test: FedRAMP Compliance Audit

Three weeks after integrating Squad into the work repo, we had a FedRAMP compliance audit. 47 infrastructure components to validate against security controls. Each component needed vulnerability scans, supply chain attestation, network isolation verification, secrets management audit, and documentation.

Normally this takes two human engineers a full week.

We gave it to the Squad — both AI and human members.

The AI squad members (Worf's delegation rules kicked in here) ran the scans, generated the SBOM, validated network policies, and produced the compliance report — 47 components, 200+ pages — in 6 hours.

Then routed the report to Worf (human squad member, Security Lead) for review.

Findings: 6 vulnerabilities (all patched within the same day), 2 missing network policies (fixed), 1 outdated dependency (upgraded). The report passed human review with minor edits.

**What we learned:**
1. AI squad members are excellent at systematic, repetitive validation work
2. Human squad members are still essential for edge cases and judgment calls
3. The handoff between AI squad members and human squad members needs to be seamless (which Squad's routing handles perfectly)

---

---

## What Doesn't Work (Yet)

Squad on a work repo isn't perfect. Here are the boundaries we've hit:

### 1. Architecture Decisions

AI squad members can *analyze* design trade-offs (performance vs. complexity, cost vs. scale), but they can't *decide* which trade-off to make. That requires understanding business priorities, team capacity, and long-term strategy.

**Current approach:** Picard (AI squad member) drafts the analysis, Brady (human squad member) makes the call. Works well.

### 2. Production Incidents

When a cluster goes down at 2 AM, AI squad members can gather logs, check recent changes, and surface likely root causes — but the final diagnosis and mitigation requires human judgment.

**Current approach:** Ralph pages the on-call human squad member with context. The human decides the fix. AI squad members execute the remediation steps.

### 3. Political/Organizational Context

AI squad members don't understand org dynamics. If a feature request comes from a VP, they treat it the same as a bug report from a junior engineer. That's technically correct, but politically naive.

**Current approach:** Brady and I (human squad members) triage issues with organizational context before AI squad members pick them up. AI handles execution, humans handle stakeholder management.

---

---

## How We Onboarded the Team (Without the Pitchforks)

Introducing AI squad members to a team that didn't sign up for them is tricky. Here's how we did it:

### Week 1: Observation Only
- Squad read-only access to the repos
- AI squad members ran analysis and drafted reports, but no PRs, no code changes
- Human squad members reviewed the output to build trust

### Week 2: Drafts and Suggestions
- AI squad members created draft PRs marked `WIP` with detailed explanations
- Human squad members reviewed, edited, and merged
- Feedback loop: when a draft needed changes, we updated `.squad/decisions.md` so the AI squad members learned team conventions

### Week 3: Delegated Work
- Low-risk tasks (documentation, test scaffolding, dependency updates) delegated to AI squad members with human review
- Critical work (architecture, security, production changes) still owned by human squad members

### Week 4: Full Integration
- Routing rules in place
- AI squad members handle routine work autonomously
- Human squad members focus on design, incidents, and high-judgment calls

**The key:** We never forced it. Engineers who wanted to join as human squad members did. Engineers who preferred traditional workflows weren't blocked. Over time, as people saw the value (faster reviews, better test coverage, docs that stay updated), adoption grew organically.

Resistance? Mostly futile. 🟩⬛

---

## Metrics: What Changed

After 6 weeks with Squad integrated into the work repo, here's what we measured:

| Metric | Before Squad | After Squad | Change |
|--------|-------------|-------------|---------|
| Average PR review time | 18 hours | 4 hours | -78% |
| PRs merged per week | 12 | 23 | +92% |
| Test coverage | 67% | 84% | +17 points |
| Documentation drift (outdated docs) | 22 files | 3 files | -86% |
| Security findings (avg per sprint) | 8 | 2 | -75% |
| Human time spent on toil (estimates, self-reported) | ~35% | ~12% | -66% |

The big wins:
- **Review latency dropped** because AI squad members pre-screened PRs
- **More PRs shipped** because test scaffolding and doc sync were automated by AI squad members
- **Security improved** because scanning was continuous (AI squad members) with human oversight (human squad member Worf)
- **Human squad members had more time** for architecture and design

The tricky part: measuring "quality of thought" on design decisions. Anecdotally, Brady and the human squad members report spending more time thinking deeply about architecture because they're not bogged down in toil. But that's hard to quantify.

---

---

## Cost: What This Actually Costs

Squad on a personal repo is basically free (assuming you have GitHub Copilot). Squad on a work repo with a team? There's a cost.

**Copilot seats:** 6 human squad members + 7 AI squad members = 13 concurrent Copilot sessions during peak hours. Copilot pricing is per-seat, so this matters.

**Compute:** Ralph's watch loop runs 24/7. Background monitoring, scheduled tasks, continuous scanning. We run this on a dedicated VM (Standard D4s v3 in Azure, ~$140/month).

**Token usage:** AI squad members are chatty. Decision logs, routing analysis, cross-repo coordination — all of it generates tokens. We don't have exact numbers (Copilot doesn't expose token-level billing), but anecdotally, our team's Copilot usage is 3-4x higher than before Squad.

**Human time to maintain:** ~4 hours/week (mostly Tamir and Brady — human squad members) to update routing rules, refine agent charters, and handle edge cases where AI squad members get confused.

**Total estimated cost:** ~$400/month (compute + human time). For a 6-person team shipping 23 PRs/week, that's roughly $17 per merged PR. We consider that a bargain.

---

---

## What's Next: When Work Teams Become a Collective

This post covered a single team (DK8S) with a single Squad — human squad members and AI squad members working together.

But we're already seeing the next challenge:

**What happens when multiple teams across Microsoft adopt Squad?** Do they each build isolated AI teams, or do they share knowledge? Can Squad in the Azure Kubernetes team learn from Squad in the Azure Networking team? What about organizational standards — coding conventions, security policies, architectural patterns — that should apply across all teams?

In Part 3, I'll cover **Squad upstreams** — how we're building a hierarchy of shared knowledge across teams, so that organizational context propagates down to every Squad without manual copy-paste.

From personal repo ([Part 0: Organized by AI](/blog/2026/03/10/organized-by-ai)) to personal AI team ([Part 1: Resistance is Futile](/blog/2026/03/11/scaling-ai-part1-first-team)) to work team (this post) to organizational scale (coming next).

The assimilation continues. 🖖

![We are the Borg](https://github.com/user-attachments/assets/06ab6aad-52d4-4e16-a904-4df98b0be3d3)
*The assimilation continues. You have been warned.*

---

> 📚 **Series: Scaling Your AI Development Team**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai)
> - **Part 1**: [Resistance is Futile — Your First AI Engineering Team](/blog/2026/03/11/scaling-ai-part1-first-team)
> - **Part 2**: From Personal Repo to Work Team — Scaling Squad to Production ← You are here
> - **Part 3**: Coming soon — Organizational Knowledge for AI Teams
