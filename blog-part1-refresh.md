---
layout: post
title: "Resistance is Futile — Your First AI Engineering Team"
date: 2026-03-04
tags: [ai-agents, squad, github-copilot, scaling, star-trek, borg]
series: "Scaling AI-Native Software Engineering"
series_part: 1
---

> *"You will be assimilated."*
> — The Borg, Star Trek: The Next Generation

Remember [how Squad became my first productivity system that actually worked](/blog/2026/03/10/organized-by-ai)? Not because I changed — because the system doesn't need me to remember. Ralph watches the queue. Scribe captures decisions. The squad runs while I sleep.

That was three weeks ago.

Today I want to show you what happened when I stopped treating Squad like a personal productivity hack and started treating it like an actual engineering team. Because here's the thing about having seven AI agents (Picard, B'Elanna, Worf, Data, Seven, Podcaster, Neelix) plus two background workers (Ralph, Scribe): eventually you stop thinking of them as tools. You start thinking of them as teammates.

And teammates need structure.

![Borg cube](/assets/scaling-ai-part1-first-team/borg-cube.png)
*"Resistance is futile. Your backlog will be assimilated."*

## From "Hey AI, Fix This" to "Team, Here's the Plan"

In my [first Squad post](/blog/2026/03/10/organized-by-ai), I showed you Ralph's 5-minute watch loop — checking issues, merging PRs, documenting decisions. That's still running. Still works. But I realized I was treating Squad like a better todo list when it's actually something more.

The shift happened when I stopped saying "fix the auth bug" and started saying "Team: fix the auth bug."

That one word — **Team** — changed how Squad responds. Instead of Data (my code expert) diving straight into the fix, Picard (my lead) steps in first:

```
🎖️ Picard: Breaking down authentication bug...
   Analysis: JWT token refresh failing on expired sessions
   Dependencies: Need to understand token expiry logic before fixing
   
   → Data: Review authentication flow, identify root cause
   → Worf: Check for security implications (expired tokens, session hijacking)
   → Seven: Update auth documentation with fix reasoning
   
   Expected: 3 parallel streams, Data finishes first, others follow
```

See what happened? Picard didn't just assign the task to Data. He **analyzed** it, **identified dependencies**, and **fanned work out to the right specialists**. This is task decomposition, and it's the difference between "one agent does everything" and "a team coordinates."

This isn't new tech — it's how [Brady Gaster designed Squad from the start](https://github.com/bradygaster/squad). What's new is me finally using it the way it was meant to be used. And once I did, the productivity leap wasn't incremental. It was exponential.

## Your First `squad init` (Or How I Named My Team)

If you're just discovering Squad now, here's the delightful part: when you run `squad init` in your repo, it doesn't give you generic "Agent 1, Agent 2, Agent 3." It **casts** your team from one of 31 fictional universes.

The selection is deterministic based on your repo name. Same repo, same team every time. It's an easter egg system, and it turned out to be brilliant.

For my personal repo, Squad picked **Star Trek: Voyager**:

| Role | Agent | Specialty |
|------|-------|-----------|
| 🎖️ Lead | **Picard** | Architecture, decisions, delegation (I renamed him from Janeway) |
| 🔧 Backend | **Data** | Code review, C#, Go, .NET internals |
| 🔒 Security | **Worf** | Security analysis, compliance, supply chain |
| 📋 Research | **Seven** | Documentation, research, synthesis |
| ⚙️ Infrastructure | **B'Elanna** | Kubernetes, cloud, CI/CD |

The names aren't cosmetic. Each agent gets a **persona** that shapes how they communicate. Picard is strategic and decisive. Data is thorough and precise. Worf is aggressive about security edge cases. Seven is direct and analytical.

I've read every Squad blog post Brady published (all 22+). I've watched [his demos](https://github.com/bradygaster/squad), read [the docs](https://bradygaster.github.io/squad/), tried [the features he covered](https://github.com/bradygaster/squad). What I'm showing you here isn't the tech — it's what it **feels like** to use Squad day after day on a real codebase after you've moved past the tutorial phase.

![Squad team setup](/assets/scaling-ai-part1-first-team/team-setup.png)
*Squad's team setup — roles, capabilities, and how agents coordinate.*

## Giving Your First Real Task

Here's where it clicks. You give your Squad a task:

```
Team, build the user search feature with filtering and pagination
```

Picard takes over. As Lead, he doesn't start coding — he **orchestrates**:

```
🎖️ Picard: Breaking down user search task...
   → Data: Build search API with filtering support
   → Seven: Add API documentation with filter examples
   → Worf: Validate input sanitization (SQL injection risk)
   → B'Elanna: Add pagination config to API deployment
```

All four agents start working **simultaneously**. Data is writing the search endpoint while Seven drafts the docs while Worf audits for injection vulnerabilities while B'Elanna updates the deployment config. This isn't sequential — it's genuinely parallel.

The first time I saw this happen, I just sat there watching the terminal scroll. Four agents, four branches of work, all moving forward at once. The Borg assimilation metaphor isn't accidental — it really does feel like a collective consciousness descending on your codebase.

And remember: [I didn't have to prompt this](/blog/2026/03/10/organized-by-ai). Ralph's 5-minute loop already saw the GitHub issue labeled `squad:picard`, assigned it to the team, and kicked off the work. I just woke up to four PRs in review.

![Parallel execution diagram](/assets/scaling-ai-part1-first-team/parallel-execution.png)
*Squad's parallel execution flow: one task fans out to multiple agents working simultaneously.*

## Ralph — Still Relentless

I covered Ralph in my [first post](/blog/2026/03/10/organized-by-ai), but I want to emphasize this: **Ralph is what makes the system work without you.**

Ralph's three-layer architecture:

1. **In-session loop**: Basic scan-triage-assign in your current Copilot session
2. **`squad watch`**: Local daemon that persists across terminal restarts
3. **GitHub Actions heartbeat**: Scheduled workflow that runs Ralph in CI — your AI team works while you sleep

That third layer is the game changer. I've woken up to merged PRs I never touched. Ralph saw the issue, assigned it to Data, Data fixed it, tests passed, Ralph merged it. Zero human intervention.

This is what I meant in [Part 0](/blog/2026/03/10/organized-by-ai) when I said "AI doesn't forget, AI doesn't need willpower." Ralph runs every 5 minutes, forever, whether you're at your desk or not. Productivity systems fail when they require remembering. Ralph doesn't require remembering.

![Ralph monitoring loop](/assets/scaling-ai-part1-first-team/ralph-loop.png)
*Ralph operates at three layers: in-session, local daemon, and GitHub Actions — from interactive to fully autonomous.*

## Decisions & Memory (Institutional Knowledge That Survives)

I showed you `.squad/decisions.md` in my [first post](/blog/2026/03/10/organized-by-ai) — the single file where every significant decision gets captured with full reasoning, not just conclusions.

Here's what I didn't fully understand three weeks ago: **decisions.md isn't just a log. It's the team's shared brain.**

Every time an agent starts a task, it reads decisions.md first. When it makes a significant choice, it writes it back. This means your team accumulates **institutional knowledge** across sessions.

Session 1: Data decides to use bcrypt for password hashing, documents it in decisions.md.
Session 5: Seven is writing auth documentation and references the bcrypt decision automatically — because it's in decisions.md.
Session 10: Worf audits a password reset feature and validates bcrypt compliance — because decisions.md told him it's the standard.

Each agent also has **history.md** — their individual learning log. Data's history tracks every API he's built, every database decision, every performance optimization. Over time, agents develop genuine **expertise in your specific codebase**.

Then there are **skills** — reusable patterns agents discover and share. When Data figures out your project's error handling convention, he captures it as a skill. Next time Seven needs to handle errors in documentation examples, that skill is available to her. Knowledge doesn't just persist — it **flows across the team**.

This is what I meant when I said Squad became [the first productivity system I didn't abandon](/blog/2026/03/10/organized-by-ai). Traditional systems rely on you maintaining them. Squad maintains **itself**. The knowledge compounds.

![Decisions and memory system](/assets/scaling-ai-part1-first-team/decisions-memory.png)
*Squad's knowledge system: shared decisions flow to all agents, individual history builds expertise, skills transfer across the team.*

## Human Squad Members (The Feature That Changes Everything)

This is where the story turns. Everything I just showed you — Picard delegating tasks, Ralph's watch loop, agents working in parallel — that's what I described in [Part 0](/blog/2026/03/10/organized-by-ai). My **personal repo**. Just me and my AI team.

But here's the question I couldn't stop thinking about:

**What happens when you're not the only human?**

Because I don't just work on personal repos. I have a job. At Microsoft. On the DK8S (Distributed Kubernetes) platform team. With five other engineers. Real teammates with expertise, opinions, and merge authority.

Could I bring Squad there?

My first instinct was "no way." Production systems. Code review standards. Security scanning. FedRAMP compliance. You can't just drop an AI team into that and say "assimilate the backlog." My teammates didn't sign up for AI agents making decisions at 3 AM.

Then I read Brady's docs on **human squad members**, and everything clicked.

You can add humans to the Squad roster. Real people, with real GitHub handles, assigned to real roles. When work routes to a human team member, Squad doesn't hallucinate their response or skip the step — it **pauses and waits**.

I added myself to the roster as a human squad member:

```markdown
## Human Members

- **Tamir Dresher** (@tamirdresher) — Human Squad Member  
  - Role: AI Integration Lead
  - Expertise: AI workflows, DevOps automation, C#/.NET
  - Scope: Squad adoption, agent orchestration, integration patterns
```

Now when Picard's architecture review needs my input, Squad pauses and pings me:

```
📌 Waiting on @tamirdresher for architecture review...
   Task: Authentication API redesign needs sign-off before implementation
   Status: Pinged on GitHub, awaiting response
```

The AI team continues working on everything else that doesn't depend on my input. When I respond, Squad picks up the thread and continues.

**This is the feature that makes Squad enterprise-ready.** It means Squad doesn't replace your team — it **augments** it. Senior engineers still own critical decisions. Security reviews still go through humans. But the implementation work, the test scaffolding, the documentation sync — that's handled by AI squad members while human squad members focus on architecture and judgment calls.

And here's where the next chapter begins: What if I added my **actual teammates** as human squad members? Brady, the guy who created Squad? Worf, our security lead? B'Elanna, our infrastructure expert?

What if the work team itself became a Squad — humans and AI working together, not in parallel?

That's [Part 2](/blog/2026/03/12/scaling-ai-part2-collective). And it's where things get interesting.

## Features the Squad Blogs Don't Cover (From a User's Perspective)

Brady's [22+ Squad blog posts](https://github.com/bradygaster/squad) cover the architecture brilliantly. But here are the features I discovered **as a practitioner** that changed my daily workflow:

### Export/Import

`squad export` packages your team's accumulated knowledge — decisions.md, skills, routing rules — into a portable bundle. `squad import` drops it into a new repo. Instead of repeating three weeks of learning, my new repo's Squad was productive from session one. I moved my team between repos without losing institutional knowledge.

### `squad doctor`

Run `squad doctor` and it validates your entire setup — 9 checks covering config files, agent definitions, upstream connections, and more. All green means you're good. Anything wrong gets a clear diagnostic with a fix suggestion. I run it after every config change. It's saved me from "why isn't this working?" debugging sessions more times than I can count.

### Notifications

Squad pings me on Teams when it needs input. I don't have to watch the terminal. When Picard's review needs my sign-off, or Worf finds a security issue that requires human judgment, I get a notification on my phone. I respond in Teams, and Squad picks up the thread. This is what makes "human in the loop" **actually practical** — you're not chained to your desk watching agent output scroll by.

### OpenTelemetry + Aspire

I can see agent work in an Aspire dashboard. Traces, logs, metrics — full observability into what every agent is doing, how long tasks take, and where bottlenecks form. When Data spent 8 minutes on what should have been a 2-minute API endpoint, I could see exactly where the time went in the trace waterfall. This isn't just debugging — it's **understanding your AI team's performance characteristics over time**.

### Label Taxonomy

Squad's 7-namespace label system (`status:`, `type:`, `priority:`, `squad:`, `go:`, `release:`, `era:`) gives structure to the chaos. Before Squad, my GitHub issues were a flat list with inconsistent labels. Now every issue has a clear lifecycle (`status:new` → `status:triaged` → `status:in-progress` → `status:done`). It's opinionated, and the opinions are right.

### Context Optimization

decisions.md was getting huge. After three weeks, it ballooned in token count. Squad auto-prunes it — consolidating redundant decisions, archiving stale ones, keeping active context lean. I watched it go from 80K tokens down to 33K without losing important context. My agents got faster because they weren't wading through outdated decisions about features that shipped two weeks ago.

### Remote Control

`squad start --tunnel` exposes your session via a devtunnel URL. Open it on your phone, and you're controlling your AI team from the couch. I built this integration and [wrote about it here](/blog/2026/02/26/squad-remote-control). It's become my default way to monitor Squad — kick off work at my desk, check progress from my phone during lunch.

## What's Next: From Personal to Production

This post covered a single repo with a single Squad team — **my personal playground** where Picard could make architecture decisions at 2 AM and nobody would complain.

But I don't just work on personal repos. I work on production systems at Microsoft, with real teammates who have expertise, opinions, and merge authority.

The question that kept me up at night: **Can Squad work on a real engineering team?**

The answer turned out to be yes. But not by copy-pasting my personal setup. The breakthrough wasn't teaching Squad to work **around** my team — it was teaching Squad to work **with** them.

In [Part 2: "From Personal Repo to Work Team"](/blog/2026/03/12/scaling-ai-part2-collective), I'll show you what happened when I added my actual teammates — Brady, Worf, B'Elanna — as **human squad members** to the roster. Where the AI squad members handle grunt work and the human squad members handle judgment calls. Where routing rules define when AI pauses and escalates to humans.

Where the work team itself became a Squad — humans and AI, together.

Resistance is futile. Your backlog will be assimilated. 🟩⬛

---

> 📚 **Series: Scaling Your AI Development Team**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai)
> - **Part 1**: Resistance is Futile — Your First AI Engineering Team ← You are here
> - **Part 2**: [From Personal Repo to Work Team — Scaling Squad to Production](/blog/2026/03/12/scaling-ai-part2-collective)
> - **Part 3**: Coming soon — Organizational Knowledge for AI Teams
