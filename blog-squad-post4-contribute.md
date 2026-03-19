---
layout: post
title: "How to Contribute to Open Source AI Agent Frameworks"
published: true
description: "Your team has a framework problem. Here's how to fix it — and how contributing to the Squad framework means every team you'll never meet benefits too."
tags: [ai-agents, squad, github-copilot, multi-agent, open-source, productivity, aiengineering]
cover_image: ""
series: "Squad AI Framework — TechAI Explained"
series_part: 4
canonical_url: ""
---

> The best time to contribute to an open source project was at its founding. The second best time is right now, when there are 44 open issues and a maintainer who actually reads PRs.

Here's something I've noticed about the AI tooling space: everyone is building. Everybody has an agent setup, a prompt library, a clever orchestration script they're quietly proud of. And almost none of it gets shared.

I get it. You built something that solves your specific problem in your specific environment with your specific constraints. It feels precious. It feels local. It doesn't feel like something you'd open-source because it's tangled up with your codebase and your team's quirks and those three hardcoded assumptions you keep meaning to clean up.

But here's the thing about agent frameworks specifically: the network effect is unusually powerful. Every skill someone contributes to the Squad framework doesn't just solve their problem — it becomes available to every squad that's ever spun up, everywhere. Every ceremony template, every routing pattern, every Ralph loop that someone debugged and documented means that the next team to face that exact situation doesn't have to rediscover it from scratch.

This is the final post in a four-part series on the Squad framework. We've covered [what Squad is and why multi-agent AI teams matter](https://dev.to/techaiexplained/what-is-the-squad-framework-multi-agent-ai-for-real-teams), [how it compares to rolling your own agent setup](https://dev.to/techaiexplained/squad-vs-custom-ai-agents-a-feature-by-feature-comparison), and [the three structural gaps that kill most agent frameworks in production](https://dev.to/techaiexplained/the-3-things-missing-from-every-ai-agent-framework). Now we're going to close it out with something more actionable: how to actually contribute.

---

## Why Open Source Matters More for Agent Frameworks Than Almost Anything Else

When I think about why open source matters, my brain usually goes to the standard answers. Transparency. Community. Shared maintenance burden. No single vendor lock-in. All true, all fine.

But for multi-agent AI frameworks, there's a more specific reason that I think is underappreciated: **the hardest part of building an agent team isn't the code. It's the institutional knowledge.**

How do you structure a charter so an agent actually follows it? What ceremony types surface the most useful information? How do you write a Ralph loop that doesn't thrash under load? Which routing patterns hold up when three agents try to work the same issue simultaneously, and which ones silently corrupt your decisions file?

None of this is documented anywhere. It's learned by running systems in production, watching them fail in interesting ways, and making careful notes. And right now, that knowledge is scattered across a handful of people who've been running Squad long enough to develop opinions about it.

Open source is how that knowledge concentrates. When you contribute a skill that solved a problem you had, you're not just donating code. You're donating the learning. Every team that adopts Squad after you gets your three weeks of debugging included for free.

That's the deal. That's why it's worth doing.

---

## What You Can Actually Contribute

The Squad repository at [bradygaster/squad](https://github.com/bradygaster/squad) has a meaningful split between what's complex to contribute and what's genuinely approachable.

**Skills (`.squad/skills/`)** are the most accessible entry point and arguably the highest-leverage contribution. A skill is a markdown file that teaches all agents how to handle a specific type of situation — how to interact with a particular external system, how to apply a specific review protocol, how to structure a type of output. The upstream repo ships with eleven built-in skills covering things like git workflow, secret handling, and code review conventions. Every time you solve a recurring problem in your squad setup and think "this should be a thing," that's a skill contribution waiting to happen. Fork the repo, write the markdown, submit the PR. The barrier to entry here is genuinely low.

**Agent charters** are another high-value, low-friction contribution. If you've designed an agent role that works well — a specialized researcher, a documentation agent, a security reviewer with a well-tuned decision tree — the charter document that defines it is exactly the kind of thing other teams need. Templates for non-engineering squads are particularly underrepresented right now. Research teams, DevRel teams, architecture review boards — these all use Squad-style patterns, but the upstream repository is almost entirely focused on software development. There's a real gap here.

**Ceremony templates** are how you encode what a healthy review rhythm looks like for a team. The upstream repository has two ceremonies by default. There's room for significantly more: symposium-style knowledge-sharing ceremonies, backlog prioritization formats, failure analysis structures that capture *why* something didn't work and not just *that* it didn't. If you've developed a ceremony that your team actually runs and finds useful, that's worth sharing.

**Routing patterns** — the logic that determines which agent handles which category of work — are subtler but deeply impactful. A well-designed routing table doesn't just direct traffic; it enforces ownership, prevents drift, and makes escalation paths explicit. If you've developed routing patterns that handle edge cases gracefully (the "two agents could both plausibly handle this" situation, or "this work spans multiple domains" routing), documenting and contributing those patterns helps the whole community develop better intuition.

**Ralph loops and observability patterns** are where the ops experience lives. Ralph is Squad's keep-alive agent, the background process that watches for stale work, detects idle agents, and surfaces blockers before they become missed deadlines. Getting Ralph right is non-trivial. Cross-platform implementations, structured logging formats, single-instance guards, configurable alerting — all of this is in-scope for contribution and actively needed.

---

## How to Contribute: The Practical Walkthrough

Contributing to Squad isn't complicated, but there are a few conventions worth knowing before you send your first PR.

The upstream CONTRIBUTING.md is worth reading in full, but here's the condensed version:

**PRs target the `dev` branch, not `main`.** This is the most common mistake new contributors make. Main is release-only. All work goes through dev.

**You need a changeset before your PR lands.** Run `npx changeset add` in the root of your fork, follow the prompts to describe your change and its impact level, and commit the generated file with your work. The project uses changesets for automated changelog and release management. No changeset, no merge — it's enforced.

**Branch naming follows `{username}/{issue-number}-{slug}`.** So if you're user `myname` contributing against issue #413, your branch is `myname/413-knowledge-library`. If you're working on something that doesn't have an associated issue yet, open one first, get the number, then branch.

**SDK changes require a proposal document first.** If you're adding a new builder function or extending the data model rather than just adding templates and markdown, open a `docs/proposals/your-feature.md` file in a PR before you write any code. This isn't bureaucracy — it's the maintainer protecting both your time and theirs. Getting alignment on the design before you spend a week on implementation is a kindness.

**The commit footer matters.** Include `Co-authored-by: {your-name} <{your-email}>` in your commit message. Squad is an AI-assisted project, but commits need a human author on record.

The fork-to-PR flow itself is standard GitHub fare: fork the repo, create your branch, make your changes, run `npx changeset add`, push, open the PR against `dev`. The PR template will prompt you for a description of what you changed and why. Fill it out. Maintainers read them.

---

## Three Contribution Opportunities Right Now

I pulled the current open issues this week. Here are three where I think the contribution path is particularly clear:

**Issue #413: Knowledge library — persistent team context.** This is the feature request for a formalized persistent knowledge base that agents can read from and write to, beyond what `decisions.md` currently provides. It's tagged as a research spike, which means the maintainer wants someone to investigate and document the design space before code happens. If you've thought carefully about agent memory, knowledge graphs, or RAG-adjacent patterns for persistent context, this is your contribution. The ask is a well-researched proposal, not a PR.

**Issue #450: Circuit breaker for model rate limiting.** When multiple agents hit the model API simultaneously, they can collide on rate limits in ways that are hard to debug. This issue asks for a circuit breaker pattern that backs off gracefully, queues retries, and surfaces errors clearly rather than silently dropping work. This is the kind of production reliability problem that Squad users hit and fix locally. If you've solved it, the upstream team wants your solution.

**Issue #426: RFC for external communications and community patterns.** This one is about how squads communicate *outward* — to external stakeholders, other squads, wider community. It's an RFC, which means it's in the "help us think through this" phase. If you've built Squad-adjacent tooling around notifications, cross-repo signaling, or stakeholder-facing reporting, there's a real discussion to be had here.

Beyond these three, issues #441 (autoresearch built into Squad) and #437 (coordinator auto-detecting repo owner context) are both well-defined enough that a motivated contributor could take a first pass without much design pre-work.

---

## The Bigger Picture

There's a version of this post I could write that's just tactical — here's how to fork, here's how to submit a PR, here's the changeset command. And I've tried to cover that ground. But I want to end on something more honest.

We're in an unusual moment with AI development tooling. The patterns for how AI teams should work are still being written. The community consensus on what makes a multi-agent system actually maintainable — the ceremonies, the memory architectures, the routing conventions, the observability primitives — none of that has settled yet. The people writing blog posts about it (hi) are simultaneously the people running experiments, watching them fail, and adjusting.

Squad is one of the clearest attempts I've seen to turn those experiments into something reusable. Brady Gaster built something opinionated enough to be immediately useful but open enough to extend. That's genuinely hard. And the 44 open issues aren't a sign of a troubled project — they're a sign of a project with an active user base running it hard enough to surface real problems.

Contributing to Squad is a way of participating in that process. You're not just fixing a bug or adding a template. You're shaping how AI teams work, and that will matter to people for a while.

That's a better investment than the fourth iteration of your local routing script, I promise.

---

## What's Next: The Full Picture

That's the series. Four posts, one through-line:

In [Post 1](https://dev.to/techaiexplained/what-is-the-squad-framework-multi-agent-ai-for-real-teams), we established what the Squad framework is and why the multi-agent team model produces compoundingly better results than single-agent systems.

In [Post 2](https://dev.to/techaiexplained/squad-vs-custom-ai-agents-a-feature-by-feature-comparison), we put Squad head-to-head with rolling your own and found that the gap between "I can build this" and "I should build this" is significantly larger than it looks from the outside.

In [Post 3](https://dev.to/techaiexplained/the-3-things-missing-from-every-ai-agent-framework), we got honest about the three structural problems — memory, coordination, and observability — that kill most agent frameworks in production, and how Squad solves each of them.

And here, in Post 4, we talked about why contributing back matters and how to do it.

If this series was useful to you, there are three things I'd love:

**Contribute something.** Even a small skills template. Even opening an issue with a use case you tried that didn't work. The upstream project benefits from practitioners who've actually run this stuff.

**Share the series** with someone building AI tooling who hasn't found Squad yet. The best way to grow a useful open source community is to route more thoughtful people toward it.

**Come take the course.** I've put together a structured, hands-on curriculum for going from "I've heard of multi-agent AI" to "I have a working squad setup in my own repo." It's on Gumroad, it's practical, and it goes significantly deeper than four blog posts can. [Check it out here](https://techaiexplained.gumroad.com).

And if you want more posts like this — the honest practitioner take, not the hype version — subscribe to TechAI Explained. We do the experiments so you don't have to start from scratch.

---

*This is Post 4 of 4 in the Squad AI Framework series from TechAI Explained. The series covers what Squad is, how it compares to rolling your own, what's missing from most agent frameworks, and how to contribute back.*
