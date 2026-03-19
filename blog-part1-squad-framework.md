---
title: "What Is the Squad Framework? Multi-Agent AI for Real Teams"
published: false
description: "The Squad framework isn't another AI coding assistant — it's a full multi-agent runtime that gives your AI team memory, specialization, governance, and the ability to work in parallel. Here's what it actually is and why it matters."
tags: [ai, github-copilot, multi-agent, squad, productivity]
cover_image: ""
series: Squad AI Framework
series_part: 1
canonical_url: ""
---

<!-- Brand: TechAI Explained | Deep Navy #0a0a2e | Cyan #00d4ff | Magenta #ff006e | Gold #ffd700 -->

# What Is the Squad Framework? Multi-Agent AI for Real Teams

Let me tell you about the moment I realized I'd been using AI wrong.

I'd been using GitHub Copilot the way most engineers do — tab-complete here, generate a function there, ask it to explain a gnarly regex. Incredibly useful, definitely faster than before. But fundamentally it's still me driving, me making every decision, me catching every edge case. The AI is a very fast pair programmer who happens to never complain about code review bandwidth.

Then I stumbled onto [bradygaster/squad](https://github.com/bradygaster/squad).

The first thing I noticed was the `.squad/` directory in the repo. Files with names like `decisions.md`, `routing.md`, `team.md`. Agent charters with titles like *Flight*, *CAPCOM*, *RETRO*, *Scribe*. I thought: this is either the most elaborate developer productivity setup I've ever seen, or someone was bored and built a game inside their repo.

It turned out to be both, in the best possible way. And once I understood what it actually was, I couldn't unsee it.

---

## The Core Idea: AI Agents That Work Like a Team

Squad is a multi-agent framework built on top of GitHub Copilot. But "multi-agent" undersells what's actually happening. Lots of tools call themselves multi-agent when they mean "we chain three prompts together." Squad means something more specific: **each agent is a specialist with defined expertise, clear ownership, and explicit boundaries — exactly like hiring a real team.**

The upstream framework ships with 21 agents, all named after the NASA Mission Control team from Apollo 13. You've got:

- **Flight** — the lead architect who reviews proposals and rejects work that skips design
- **CONTROL** — the TypeScript language expert who owns the type system and enforces zero `@ts-ignore`
- **RETRO** — security and hook governance, with write-path enforcement
- **FIDO** — quality assurance, ensuring every fix comes with a test that would have caught the original bug
- **Scribe** — the team's memory system, capturing decisions and maintaining institutional knowledge
- **Ralph** — the monitor who watches the work queue around the clock

The thing that makes Squad different from "just use multiple AI assistants" is that these agents **coordinate**. When you route work to the team, you don't get one agent doing everything sequentially. You get Picard-style orchestration: the lead analyzes the task, identifies dependencies, fans work out to the right specialists, and the team runs in parallel.

```
📨 Issue: User search feature with filtering and pagination

🎖️ Flight: Breaking down task...
   → CONTROL: Build search API with type-safe filter params
   → FIDO: Write test coverage for all filter combinations  
   → PAO: Add API documentation with usage examples
   → RETRO: Validate input sanitization against injection

4 agents, 4 parallel work streams. All running simultaneously.
```

The first time you watch this happen, you feel the shift. That's not a coding assistant. That's a team.

---

## How Routing Actually Works

The framework's routing system is one of its most underappreciated pieces. Squad maintains a routing table that maps work types to specific agents with explicit module ownership. "Architecture work" goes to Flight. "TypeScript errors" go to CONTROL. "Security questions" go to RETRO. "CLI behavior" goes to INCO.

This isn't magic keywords — it's an explicit table in `routing.md` that you configure for your team, your codebase, your patterns. The routing principles are also explicit:

- **Eager spawning** — route to the most specific agent immediately, don't hedge
- **Scribe always runs** — every spawn triggers Scribe to log what happened and why
- **Fan-out on broad tasks** — multi-agent tasks spawn all relevant specialists in parallel
- **Doc-impact check** — PAO (the DevRel agent) reviews every PR for documentation impact

This is not accidental architecture. It reflects years of thinking about how software engineering teams actually divide labor, encoded into a system that AI agents can execute reliably.

---

## The Memory System That Changes Everything

Here's the part that most "AI productivity" content ignores: **memory**.

Every agent in Squad reads `decisions.md` before starting work. This file is the team's shared brain — a structured log of every significant architectural decision, every convention that was adopted, every mistake that shouldn't be repeated. It's maintained by Scribe and written to asynchronously by all agents using a decision inbox pattern.

The structure matters. Decisions are categorized as Foundational Directives (architectural constants, enforced forever), Sprint Directives (current focus areas), or Release Decisions (per-version choices). An agent that reads `decisions.md` knows:

- "We enforce strict TypeScript — no any, no @ts-ignore, no implicit returns"
- "Zero runtime dependencies — built entirely on Node.js built-ins"
- "All new PRs include a PAO doc-impact check"
- "Secret handling follows the pattern in the security skill"

This is institutional knowledge. The kind of thing that normally lives only in the heads of senior engineers and gets lost every time someone leaves. Squad captures it in a format that every AI agent can read before touching your codebase.

The `merge=union` strategy in `.gitattributes` for `decisions.md` is a particularly clever detail — it enables conflict-free parallel writes. Multiple agents can add decisions simultaneously without merge conflicts. That's not a hack; that's careful system design.

---

## Agent Charters: Why Specialization Beats General-Purpose AI

Each Squad agent has a charter — a markdown file that defines its identity, what it owns, how it works, explicit boundaries, and its preferred model. The charter is read at session start, before any code is touched.

What's the difference between a general-purpose AI assistant and a chartered agent? Try asking a general assistant to review a pull request. You'll get a polite, comprehensive, hedged response that covers everything and commits to nothing. 

Ask RETRO (Squad's security agent, chartered to own hook governance and enforce write-path rules) to review the same PR? You get focused, opinionated security analysis. RETRO doesn't care about code style. RETRO cares about whether your new hook creates a PII exposure risk and whether you bypassed the write-path governance guard.

Specialization produces better outputs because it narrows the problem space. A chartered agent with explicit ownership isn't trying to be helpful about everything — it's expert about its domain and knows when to hand off to someone else.

The framework even handles the "what happens when an agent disagrees" case: Flight, the lead, has reviewer-rejection lockout. If Flight rejects a proposal, work stops. The team doesn't bulldoze forward on contested architectural decisions. That's a governance mechanism, not a feature.

---

## Skills: Accumulated Know-How, Not Just Configuration

Beyond charters, Squad has a skills system. Skills are structured knowledge files that agents can learn from — documented patterns, conventions, anti-patterns, and examples for a specific domain.

The current framework ships with 11 skills covering everything from CLI implementation patterns to release process to security conventions. The `squad-conventions` skill is particularly good: it documents the zero-dependency constraint with examples, shows the error handling pattern Squad uses consistently, and explains the Windows compatibility requirements that aren't obvious from reading the code.

Why does this matter? Because a skilled AI agent that has read the Squad conventions skill won't accidentally introduce a `lodash` dependency into a zero-dependency CLI, or use `.then()` chains in a codebase that uses async/await throughout. The skill doesn't just tell the agent what to do — it explains why, with enough context to apply the principle to new situations.

Skills compound. Every new convention documented, every pattern extracted, every anti-pattern recorded makes every future agent invocation slightly sharper. It's institutional knowledge that compounds over time, instead of resetting to zero with every new session.

---

## What Squad Is Not

It's worth naming what Squad isn't, because the multi-agent AI space is full of marketing that overpromises.

Squad is not autonomous. You are still the decision-maker. Agents do work, capture decisions, and coordinate — but you approve PRs, direct strategic priorities, and override when needed. The framework is designed for human-AI collaboration, not full automation.

Squad is not magic prompt engineering. The routing, the memory, the charters — these are real system components that require real setup. You configure your team, define your routing rules, write your agent charters. The framework doesn't do this for you.

Squad is not yet finished. The upstream framework has clear extension points — `defineMemory()`, `defineSpaces()`, `defineWorkflow()` — that aren't fully implemented. Cross-repository team coordination is an identified gap. Copilot session memory integration is a gap. These aren't dealbreakers; they're opportunities.

---

## Why This Matters Beyond Side Projects

Here's the thing I keep coming back to: the Squad framework isn't just clever engineering. It's a model for how AI and human teams can actually work together at scale.

The features that make it work — explicit ownership, documented decisions, specialist agents that stay in their lanes, governance mechanisms that stop bad work from shipping — these are the same features that make *human* teams work well. Squad is essentially applying software engineering's best thinking about team organization to AI agent coordination.

Every real engineering team already has routing rules (you don't ask the security engineer to write the CLI help text). Every real engineering team already has memory (your ADRs, your wiki, your Slack history). Every real engineering team already has specialization. Squad makes these things explicit enough that AI agents can participate in them.

The teams that will get the most out of AI aren't the ones who prompt the hardest. They're the ones who build the systems — the routing, the memory, the governance — that let AI agents participate meaningfully in their actual work.

Squad is a blueprint for doing that.

---

**Next up in this series:** How to configure your first Squad team — agents, routing, and the decisions.md setup that makes everything stick.

---

> 🚀 **Want to go deeper?** The full hands-on course walks through building a production Squad setup from scratch — configuring agents, writing charters, setting up memory, and running your first multi-agent workflow. Get the full course on Gumroad: **[link placeholder]**

---

*Part 1 of the Squad AI Framework series. Published by TechAI Explained.*
