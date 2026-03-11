---
layout: post
title: "Resistance is Futile — Your First AI Engineering Team"
date: 2026-03-04
tags: [ai-agents, squad, github-copilot, scaling, star-trek, borg]
series: "Scaling AI-Native Software Engineering"
series_part: 1
---

Remember [how Squad became my first productivity system that actually worked](/2026/03/10/organized-by-ai.html)? Not because I changed — because the system doesn't need me to remember. Ralph watches the queue. Decisions get captured. The squad runs while I sleep.

That was my personal productivity breakthrough. AI that doesn't forget. AI that doesn't need willpower.

But here's the thing: once you have seven AI agents actually working (Picard, B'Elanna, Worf, Data, Seven, Podcaster, Neelix) plus Ralph monitoring everything 24/7... you stop thinking of them as automation scripts. You start thinking of them as a **team**.

And teams need more than prompts. They need onboarding. Structure. Knowledge. Context.

![Borg cube](/assets/scaling-ai-part1-first-team/borg-resistance-is-futile.png)
*"Resistance is futile. Your backlog will be assimilated."*

## From "Hey AI, Fix This" to "Team, Here's the Plan"

In my [Part 0 post](/2026/03/10/organized-by-ai.html), I showed you Ralph's 5-minute watch loop — checking issues, merging PRs, documenting decisions. That's still running. Still works.

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

See what happened? Picard didn't just assign the task to Data. He **analyzed** it, **identified dependencies**, and **fanned work out to the right specialists**. This is task decomposition, and it's the difference between "one agent does everything" and "a team coordinates."

This isn't new tech — it's how [Brady Gaster](https://github.com/bradygaster) designed Squad from the start. What's new is me finally using it the way it was meant to be used. And once I did, the productivity leap wasn't incremental. It was exponential.

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

## Onboarding Your Squad (The Part Everyone Skips)

Here's what most people miss: **squad init is not the end. It's the beginning.**

When I first set up my team, I didn't just accept the default roster and start assigning issues. I actually onboarded them. Like real engineers joining a real team.

First thing I did: told the squad to **scan everything**. The entire repo. Not just code — conventions, documentation, architecture decisions, patterns. I pointed them at our internal wiki. Gave them links to EngineeringHub pages. Shared past ADRs (Architecture Decision Records) from other teams.

Why? Because a squad without context is just expensive grep. I needed them to **understand** the codebase, not just execute commands on it.

So they scanned. They indexed. They built their own knowledge base. And I watched them learn.

Data identified our error handling patterns. Seven catalogued our documentation structure. Worf mapped our security controls. B'Elanna learned our deployment pipeline.

This is the phase where your squad goes from "generic AI assistants" to "teammates who actually know your project."

And here's the key: they don't just consume this knowledge passively. They **maintain** it. Every time a decision gets made, it goes into `.squad/decisions.md`. Every time a pattern emerges, it becomes a skill. The knowledge compounds over time.

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

And remember: [I didn't have to prompt this](/2026/03/10/organized-by-ai.html). Ralph's 5-minute loop already saw the GitHub issue labeled `squad:picard`, assigned it to the team, and kicked off the work. I just woke up to four PRs in review.

## Ralph — Still Relentless

I covered Ralph in my [Part 0 post](/2026/03/10/organized-by-ai.html), but I want to emphasize this: **Ralph is what makes the system work without you.**

Ralph's three-layer architecture:

1. **In-session loop**: Basic scan-triage-assign in your current Copilot session
2. **`squad watch`**: Local daemon that persists across terminal restarts
3. **GitHub Actions heartbeat**: Scheduled workflow that runs Ralph in CI — your AI team works while you sleep

That third layer is the game changer. I've woken up to merged PRs I never touched. Ralph saw the issue, assigned it to Data, Data fixed it, tests passed, Ralph merged it. Zero human intervention.

This is what I meant in [Part 0](/2026/03/10/organized-by-ai.html) when I said "AI doesn't forget, AI doesn't need willpower." Ralph runs every 5 minutes, forever, whether you're at your desk or not. Productivity systems fail when they require remembering. Ralph doesn't require remembering.

## Decisions & Memory (Institutional Knowledge That Survives)

I showed you `.squad/decisions.md` in my [Part 0 post](/2026/03/10/organized-by-ai.html) — the single file where every significant decision gets captured with full reasoning, not just conclusions.

Here's what I didn't fully understand at first: **decisions.md isn't just a log. It's the team's shared brain.**

Every time an agent starts a task, it reads decisions.md first. When it makes a significant choice, it writes it back. This means your team accumulates **institutional knowledge** across sessions.

Session 1: Data decides to use bcrypt for password hashing, documents it in decisions.md.  
Session 5: Seven is writing auth documentation and references the bcrypt decision automatically — because it's in decisions.md.  
Session 10: Worf audits a password reset feature and validates bcrypt compliance — because decisions.md told him it's the standard.

Each agent also has **history.md** — their individual learning log. Data's history tracks every API he's built, every database decision, every performance optimization. Over time, agents develop genuine **expertise in your specific codebase**.

Then there are **skills** — reusable patterns agents discover and share. When Data figures out your project's error handling convention, he captures it as a skill. Next time Seven needs to handle errors in documentation examples, that skill is available to her. Knowledge doesn't just persist — it **flows across the team**.

This is what I meant when I said Squad became [the first productivity system I didn't abandon](/2026/03/10/organized-by-ai.html). Traditional systems rely on you maintaining them. Squad maintains **itself**. The knowledge compounds.

## Adding More Expertise (When the Defaults Aren't Enough)

Remember when I said Squad casts your team from fictional universes? That's your starting roster. But here's the secret: **you're not stuck with it**.

During my onboarding phase, I realized the base team was missing something. My project involved Azure infrastructure work — networking, resource management, service integration. None of my initial agents had deep Azure expertise.

So I added an Azure specialist to the roster.

Then regulatory compliance work came up. FedRAMP requirements, security controls, audit trails. Again, nobody on the base team owned that domain.

So I added a compliance specialist.

This is how real teams grow. You don't hire everyone on day one. You assess the work, identify gaps, and bring in the expertise you need.

Squad works the same way. Your initial cast gives you a foundation. But as your project evolves, your squad can evolve too. Domain specialists. Tool experts. Role-specific agents.

And just like with real engineers, you don't just add them and expect them to be productive immediately. You onboard them. Give them the context. Show them the conventions. Let them scan the repo and build their mental model.

The difference is: with AI agents, onboarding takes minutes instead of weeks.

## What's Next: From Personal to Work Team

This post covered a single repo with a single Squad team — **my personal playground** where Picard could make architecture decisions at 2 AM and nobody would complain.

But I don't just work on personal repos. I have a job. At Microsoft. On the DK8S (Distributed Kubernetes) platform team. With five other engineers. Real teammates with expertise, opinions, and merge authority.

The question that kept me up at night: **Can Squad work on a real engineering team?**

Not "can AI agents write code for a production system" — I already knew the answer to that was yes. The real question was: Can Squad work **with humans**? Not replacing them. Not working around them. Actually collaborating.

The breakthrough wasn't teaching Squad to work faster. It was teaching Squad to work **alongside** my actual teammates.

In Part 2, I'll show you what happened when I added my colleagues as **human squad members** to the roster. Where [Brady Gaster](https://github.com/bradygaster) — the guy who created Squad — became a squad member himself. Where routing rules define when AI handles grunt work and when humans handle judgment calls.

Where the work team itself became a Squad — humans and AI, together.

Resistance is futile. Your backlog will be assimilated. 🟩⬛

---

> 📚 **Series: Scaling Your AI Development Team**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/2026/03/10/organized-by-ai.html)
> - **Part 1**: Resistance is Futile — Your First AI Engineering Team ← You are here
> - **Part 2**: Coming soon — From Personal Repo to Work Team
> - **Part 3**: Coming soon — Organizational Knowledge for AI Teams
