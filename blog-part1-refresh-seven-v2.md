---
layout: post
title: "Resistance is Futile — Your First AI Engineering Team"
date: 2026-03-04
tags: [ai-agents, squad, github-copilot, scaling, star-trek, borg]
series: "Scaling AI-Native Software Engineering"
series_part: 1
---

Remember [how Squad became my first productivity system that actually worked](/blog/2026/03/10/organized-by-ai)? Not because I changed — because the system doesn't need me to remember. Ralph watches the queue. Decisions get captured. The squad runs while I sleep.

That was my personal productivity breakthrough. AI that doesn't forget. AI that doesn't need willpower.

But here's the thing: once you have seven AI agents actually working — Picard, Data, Worf, Seven, B'Elanna, Podcaster, Neelix — plus Ralph monitoring everything around the clock, you stop thinking of them as automation scripts. You start thinking of them as a **team**.

And teams need more than prompts. They need onboarding. Structure. Knowledge. Context.

![Borg cube](/assets/scaling-ai-part1-first-team/borg-resistance-is-futile.png)
*"Resistance is futile. Your backlog will be assimilated."*

## From "Hey AI, Fix This" to "Team, Here's the Plan"

In my [Part 0 post](/blog/2026/03/10/organized-by-ai), I showed you Ralph's 5-minute watch loop — checking issues, merging PRs, documenting decisions. That's still running. Still works.

But I realized I was treating Squad like a better todo list when it's actually something more.

The shift happened when I stopped saying "fix the auth bug" and started saying "**Team:** fix the auth bug."

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

Picard didn't just assign the task to Data. He **analyzed** it, **identified dependencies**, and **fanned work out to the right specialists**. This is task decomposition, and it's the difference between "one agent does everything" and "a team coordinates."

This isn't new tech — it's how [Brady Gaster](https://github.com/bradygaster) designed Squad from the start. What's new is me finally using it the way it was meant to be used. And once I did, the productivity leap wasn't incremental. It was exponential.

## Your First `squad init` (Or How I Named My Team)

I covered the basics of `squad init` in [Part 0](/blog/2026/03/10/organized-by-ai), but here's the part that matters for building a real team: the casting system. Squad has 31 fictional universes built in, and the selection is deterministic based on your repo name. Same repo, same team every time.

For my personal repo, Squad picked **Star Trek: Voyager**:

| Role | Agent | Specialty |
|------|-------|-----------|
| 🎖️ Lead | **Picard** | Architecture, decisions, delegation (I renamed him from Janeway) |
| 🔧 Backend | **Data** | Code review, C#, Go, .NET internals |
| 🔒 Security | **Worf** | Security analysis, compliance, supply chain |
| 📋 Research | **Seven** | Documentation, research, synthesis |
| ⚙️ Infrastructure | **B'Elanna** | Kubernetes, cloud, CI/CD |

The names aren't cosmetic. Each agent gets a **persona** that shapes how they communicate. Picard is strategic and decisive. Data is thorough and precise. Worf is aggressive about security edge cases. Seven is direct and analytical. It sounds gimmicky until you watch them work — the persona system actually produces meaningfully different approaches to the same problem.

## Onboarding Your Squad (The Part Everyone Skips)

Here's what most people miss: **squad init is not the end. It's the beginning.**

When I first set up my team, I didn't just accept the default roster and start assigning issues. I actually onboarded them. Like real engineers joining a real team.

The first thing I did was tell the squad to scan everything. The entire repo. Not just code — conventions, documentation, architecture decisions, patterns. I pointed them at our internal wiki, gave them links to relevant docs, shared past architecture decision records from other teams. Because a squad without context is just expensive grep. I needed them to **understand** the codebase, not just execute commands on it.

So they scanned. They indexed. They built their own knowledge base. And I watched them learn. Data identified our error handling patterns. Seven catalogued our documentation structure. Worf mapped our security controls. B'Elanna learned our deployment pipeline.

This is the phase where your squad goes from "generic AI assistants" to "teammates who actually know your project." And here's the key difference from onboarding a human engineer: they don't just consume this knowledge passively. They **maintain** it. Every time a decision gets made, it goes into `.squad/decisions.md`. Every time a pattern emerges, it becomes a skill. The knowledge compounds over time.

Traditional onboarding is a one-time event. Squad onboarding is **continuous**. They're always learning, always updating, always getting smarter about your specific codebase.

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

## Ralph — Still Relentless

I covered Ralph in my [Part 0 post](/blog/2026/03/10/organized-by-ai), but I want to emphasize this: **Ralph is what makes the system work without you.**

Ralph operates at three layers, and each one extends the reach of your AI team further. The in-session loop is basic scan-triage-assign inside your current Copilot session. Then `squad watch` runs as a local daemon that persists across terminal restarts — so the loop keeps going even when you close a tab. But the real game changer is the GitHub Actions heartbeat: a scheduled workflow that runs Ralph in CI, fully unattended. Your AI team works while you sleep.

I've woken up to merged PRs I never touched. Ralph saw the issue, assigned it to Data, Data fixed it, tests passed, Ralph merged it. Zero human intervention. This is what I meant in [Part 0](/blog/2026/03/10/organized-by-ai) when I said "AI doesn't forget, AI doesn't need willpower." Ralph runs every 5 minutes, forever, whether you're at your desk or not. Productivity systems fail when they require remembering. Ralph doesn't require remembering.

## Decisions & Memory (Institutional Knowledge That Survives)

I showed you `.squad/decisions.md` in my [Part 0 post](/blog/2026/03/10/organized-by-ai) — the single file where every significant decision gets captured with full reasoning, not just conclusions.

Here's what I didn't fully understand at first: **decisions.md isn't just a log. It's the team's shared brain.**

Every time an agent starts a task, it reads decisions.md first. When it makes a significant choice, it writes it back. This means your team accumulates **institutional knowledge** across sessions. In session 1, Data decides to use bcrypt for password hashing and documents it in decisions.md. By session 5, Seven is writing auth documentation and references the bcrypt decision automatically — because it's right there in decisions.md. By session 10, Worf audits a password reset feature and validates bcrypt compliance without anyone reminding him. The decision propagated itself.

Each agent also has **history.md** — their individual learning log. Data's history tracks every API he's built, every database decision, every performance optimization. Over time, agents develop genuine **expertise in your specific codebase**.

Then there are **skills** — reusable patterns agents discover and share. When Data figures out your project's error handling convention, he captures it as a skill. Next time Seven needs to handle errors in documentation examples, that skill is available to her. Knowledge doesn't just persist — it **flows across the team**.

This is what I meant when I said Squad became [the first productivity system I didn't abandon](/blog/2026/03/10/organized-by-ai). Traditional systems rely on you maintaining them. Squad maintains **itself**. The knowledge compounds.

## Growing the Team (When the Defaults Aren't Enough)

Remember when I said Squad casts your team from fictional universes? That's your starting roster. But **you're not stuck with it**.

During my onboarding phase, I realized the base team was missing something. My project involved Azure infrastructure work — networking, resource management, service integration. None of my initial agents had deep Azure expertise. So I added an Azure specialist to the roster. Then regulatory compliance work came up — security controls, audit trails, internal requirements that needed tracking. Nobody on the base team owned that domain, so I added a compliance specialist too.

This is how real teams grow. You don't hire everyone on day one. You assess the work, identify gaps, and bring in the expertise you need. Squad works the same way. Your initial cast gives you a foundation, but as your project evolves, your squad can evolve too. Domain specialists, tool experts, role-specific agents — you shape the team to fit the work.

And just like with real engineers, you don't just add them and expect them to be productive immediately. You onboard them. Give them the context. Show them the conventions. Let them scan the repo and build their mental model. The difference is that with AI agents, onboarding takes minutes instead of weeks.

## Human Squad Members (The Feature That Changes Everything)

This is where the story turns. Everything I just showed you — Picard delegating tasks, Ralph's watch loop, agents working in parallel — that's my **personal repo**. Just me and my AI team.

But here's the question I couldn't stop thinking about: **What happens when you're not the only human?**

Because I don't just work on personal repos. I have a job. At Microsoft. On an infrastructure platform team. With other engineers who have real expertise, real opinions, and real merge authority. You can't just drop an AI team into that and say "assimilate the backlog." Your teammates didn't sign up for AI agents making decisions at 3 AM.

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

Now when Picard's architecture review needs my input, Squad pauses and pings me. The AI team continues working on everything else that doesn't depend on my review. When I respond, Squad picks up the thread and continues.

**This is the feature that makes Squad enterprise-ready.** It means Squad doesn't replace your team — it **augments** it. Senior engineers still own critical decisions. Security reviews still go through humans. But the implementation work, the test scaffolding, the documentation sync — that's handled by AI squad members while human squad members focus on architecture and judgment calls.

And here's where the next chapter begins. What if I added my **actual teammates** as human squad members? What if [Brady Gaster](https://github.com/bradygaster) — the guy who created Squad — became a squad member on my work team? What if the security lead reviewed Worf's findings before they shipped? What if routing rules defined when AI pauses and escalates to humans?

What if the work team itself became a Squad — humans and AI working together, not in parallel?

That's [Part 2](/blog/2026/03/12/scaling-ai-part2-collective). And it's where things get really interesting.

## Practitioner Features (What the Docs Don't Emphasize Enough)

[Brady's Squad blog posts](https://github.com/bradygaster/squad) cover the architecture brilliantly. But here are the features I discovered as a daily user that changed my workflow in ways I didn't expect.

**Export/Import** lets you package your team's accumulated knowledge — decisions.md, skills, routing rules — into a portable bundle with `squad export`, then drop it into a new repo with `squad import`. Instead of repeating three weeks of learning, my new repo's Squad was productive from session one. I moved my team between repos without losing institutional knowledge.

**`squad doctor`** validates your entire setup — 9 checks covering config files, agent definitions, upstream connections, and more. All green means you're good. Anything wrong gets a clear diagnostic with a fix suggestion. I run it after every config change. It's saved me from "why isn't this working?" debugging sessions more times than I can count.

**Notifications** changed how I interact with Squad day to day. Squad pings me on Teams when it needs input. I don't have to watch the terminal. When Picard's review needs my sign-off, or Worf finds a security issue that requires human judgment, I get a notification on my phone. I respond in Teams, and Squad picks up the thread. This is what makes "human in the loop" **actually practical** — you're not chained to your desk watching agent output scroll by.

**OpenTelemetry + Aspire** gives me full observability into what every agent is doing. Traces, logs, metrics — I can see how long tasks take and where bottlenecks form. When Data spent 8 minutes on what should have been a 2-minute API endpoint, I could see exactly where the time went in the trace waterfall. This isn't just debugging — it's understanding your AI team's performance characteristics over time.

**Context Optimization** solves the problem I hit after three weeks: decisions.md was getting huge, ballooning in token count. Squad auto-prunes it — consolidating redundant decisions, archiving stale ones, keeping active context lean. I watched it go from 80K tokens down to 33K without losing important context. My agents got faster because they weren't wading through outdated decisions about features that shipped two weeks ago.

**Remote Control** via `squad start --tunnel` exposes your session through a devtunnel URL. Open it on your phone and you're controlling your AI team from the couch. I built this integration and [wrote about it here](/blog/2026/02/26/squad-remote-control). It's become my default way to monitor Squad — kick off work at my desk, check progress from my phone during lunch.

## What's Next: From Personal to Production

This post covered a single repo with a single Squad team — **my personal playground** where Picard could make architecture decisions at 2 AM and nobody would complain.

But I don't just work on personal repos. I work on production systems at Microsoft, with real teammates who have expertise, opinions, and merge authority. My team manages infrastructure that real services depend on. Code review standards. Security scanning. Deployment gates. You can't just copy-paste your personal Squad setup into that world and expect it to work.

The question that kept me up at night: **Can Squad work on a real engineering team?**

The answer turned out to be yes. But the breakthrough wasn't teaching Squad to work faster. It was teaching Squad to work **alongside** my actual teammates.

In [Part 2: "From Personal Repo to Work Team"](/blog/2026/03/12/scaling-ai-part2-collective), I'll show you what happened when I added my colleagues as **human squad members** to the roster. Where [Brady Gaster](https://github.com/bradygaster) — the guy who created Squad — became a squad member himself. Where routing rules define when AI handles grunt work and when humans handle judgment calls. Where the work team itself became a Squad — humans and AI, together.

Resistance is futile. Your backlog will be assimilated. 🟩⬛

---

> 📚 **Series: Scaling Your AI Development Team**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai)
> - **Part 1**: Resistance is Futile — Your First AI Engineering Team ← You are here
> - **Part 2**: [From Personal Repo to Work Team — Scaling Squad to Production](/blog/2026/03/12/scaling-ai-part2-collective)
> - **Part 3**: Coming soon — Organizational Knowledge for AI Teams
