---
layout: post
title: "The 3 Things Missing From Every AI Agent Framework (And How to Fix Them)"
published: true
description: "Most AI agent frameworks look great in demos and fall apart in production. Here are the three gaps that explain why — and how the Squad framework solves each one."
tags: [ai-agents, squad, github-copilot, multi-agent, productivity, aiengineering]
cover_image: ""
series: "Squad AI Framework — TechAI Explained"
series_part: 3
canonical_url: ""
---

> AI agent demos never fail. AI agents in production rarely don't.

There's a specific moment I've come to call the "three weeks later" wall. You set up your AI agent system, you get the demo working, you show it to your team, everyone is appropriately impressed, and then you run it in production for three weeks. At which point it starts doing subtly wrong things. Or it forgets what it decided last month. Or it routes the wrong work to the wrong agent and nobody catches it until the PR review. Or the agents just... stop coordinating and start stepping on each other.

The demos worked because demos are controlled. Production is not.

After spending the better part of a year building, running, and iterating on real multi-agent systems — and comparing notes with the Squad framework's architecture — I've identified three structural gaps that explain almost all of the production failures I've seen. Not in any one specific framework. In most of them. Including setups I built myself.

Here they are. I'm not going to be gentle about it.

---

## Gap 1: Memory That Resets Every Session

### The Problem

Here's a question I have asked myself, verbatim, more times than I care to admit: *"Why does the agent think we're using REST here? We switched to gRPC three weeks ago."*

The answer, every time, is simple and maddening: the agent doesn't remember. It can't remember. By default, most AI agent frameworks give you exactly zero persistence between sessions. Every conversation starts fresh. Every context window is born empty. Your agent is, in the most literal sense, an amnesiac — competent, responsive, genuinely helpful for the duration of the session, and then completely blank the moment it ends.

This isn't a bug. It's a design reality. LLMs don't have native persistent state. Context windows close. Sessions terminate. The question isn't whether this is true — it is — the question is whether your framework has done anything architectural about it.

Most haven't.

### Why Standard Frameworks Fail Here

The typical workaround is a context file. You maintain a `context.json`, or a `system_prompt.txt`, or some equivalent document that you stuff with accumulated decisions, conventions, and preferences. You pass it to the agent at the start of every session. Done.

This works fine in week one. In week eight, it's a 200-entry document where half the entries are stale, contradictory, or redundant. Your agent is now reading 80K tokens of context before doing any actual work — most of which is noise. The sessions get slower. The outputs get less coherent. At some point you have to manually curate the context file, which is exactly the kind of overhead that was supposed to be eliminated.

And none of this — none of it — handles the harder case: *per-agent* memory. An agent that's been building your API layer for six months should know things a new agent doesn't. The specific conventions for your endpoint naming. The two times a particular pattern was tried and failed. The performance optimization that looks counterintuitive but was deliberate. That institutional knowledge doesn't belong in a shared context file. It belongs to the agent that earned it.

### How Squad Solves It

Squad has a four-tier memory architecture, and the reason it works is that each tier serves a different purpose.

**`decisions.md`** is the shared team brain. Every significant architectural decision gets recorded here — not just *what* was decided, but *why*. Before any agent starts any task, they read `decisions.md`. This is how the choice you made about bcrypt in week one is still being respected in week twelve, without you mentioning it again. Agents can surface a disagreement with a decision, but they can't unknowingly violate one.

**`agents/{agent}/history.md`** is per-agent learning. Data's history file tracks every API he's built in your codebase, every database decision, every time he had to refactor something because of a constraint he didn't anticipate. Over time, agents develop actual expertise in *your specific project* — pattern recognition specific to your conventions, your quirks, your accumulated tradeoffs. Not generic coding knowledge. Your project's knowledge.

**`.squad/skills/`** captures reusable patterns and makes them available across agents. Squad ships with 11+ built-in skills — git workflow, reviewer protocol, secret handling, and more. Knowledge doesn't just persist; it spreads.

**Session logs** provide the full audit trail — every round's inputs, outputs, and decisions, timestamped and searchable.

There's a detail worth mentioning because it's elegant: Squad uses `merge=union` in `.gitattributes` for `decisions.md`. Multiple agents can append to the same decisions file simultaneously without ever creating a merge conflict. It's a degenerate CRDT — an append-only log that merges without coordination overhead. Small implementation detail, large operational consequence.

And when `decisions.md` grows large enough to start impacting performance, Squad's Context Optimization feature auto-prunes it — consolidating redundant entries, archiving stale decisions, keeping active context lean. I've seen it trim an 80K-token decisions file down to 33K without losing anything meaningful. Agents actually get *faster* over time. The knowledge compounds, and the noise gets managed.

---

## Gap 2: Routing That's Either Absent or Rigid

### The Problem

When you have multiple agents and multiple work types, something has to decide who handles what. This is routing. And the absence of a good routing layer is responsible for more production failures than almost any other gap on this list.

In most multi-agent setups I've seen, routing falls into one of two failure modes. Either everything goes to one agent — the "general purpose AI" model — which means you're back to the jack-of-all-trades problem: mediocre at everything, expert at nothing. Or routing is handled by a brittle conditional: "if the issue title contains 'security,' route to the security agent." Fine for toy examples. Completely unreliable for anything real, because real work doesn't announce itself with clean keywords.

The third failure mode — and this one took me the longest to diagnose — is routing that doesn't know when to stop. An agent system with no concept of "this decision requires a human" will make the decision itself, every time, regardless of whether it should. I've watched agents autocomplete architecture decisions that should have had a human in the loop. The agents were confident. The outputs were coherent. And they were completely wrong, because confidence and coherence don't require correctness.

### Why Standard Frameworks Fail Here

Routing logic in custom setups almost universally lives in code. An orchestration script with an `if/elif` block, or a dispatcher function that maps task types to agent names. This is fine until it isn't. The problem isn't technical — it's operational. When the routing logic needs to change, you update the code, test it, deploy it. Non-engineers can't read it, much less edit it. The routing table becomes an implementation detail that nobody outside the original developer understands.

More critically: most custom routing systems have no concept of escalation to humans. They can route work to Agent A or Agent B. They can't route work to "wait for Alice to review this before proceeding." That capability — routing to humans with hold semantics — is simply not in scope for the typical multi-agent orchestration setup.

### How Squad Solves It

Squad's routing lives in `.squad/routing.md`. Markdown. Readable by engineers and non-engineers alike. Editable without touching code. The routing table is a living document of how your team works, not a hidden implementation detail buried in an orchestration script.

```markdown
## Routing Table

| Work Type                              | Primary   | Secondary |
|----------------------------------------|-----------|-----------|
| Architecture, distributed systems      | Picard    | —         |
| K8s, Helm, ArgoCD, cloud native        | B'Elanna  | —         |
| Security, Azure, networking            | Worf      | —         |
| C#, Go, .NET, clean code               | Data      | —         |
| Documentation, presentations, analysis | Seven     | —         |
| Blog writing, voice matching           | Troi      | Seven     |
```

But the routing table isn't just about which agent handles what — it's about when to pause and wait for a human.

```markdown
### Architecture Decisions
- Trigger: Changes to CRD schemas, API contracts, multi-repo dependencies
- Route to: Human squad member
- AI action: Analysis + recommendations, then pause for human approval

### Security Reviews
- Trigger: Authentication, secrets, network policies, supply chain changes
- Route to: Worf (AI) → Human sign-off
- AI action: Automated scans + findings, then escalate before proceeding
```

Human team members are first-class citizens in Squad's roster, not afterthoughts. When the routing table says "pause for human approval," the AI team keeps working on everything that *doesn't* depend on that approval, and holds on the parts that do. No context lost. No session restart. The work queue just waits.

An AI team that knows when to stop and ask a human is categorically different from one that forges ahead with confidence regardless of whether confidence is warranted. This is the feature I wish every AI agent framework shipped on day one.

---

## Gap 3: No Ceremonies. No Team Coordination. No Learning Loops.

### The Problem

This is the one that seems soft until you understand what it means in practice.

Most multi-agent systems are event-driven and stateless. A task arrives, agents execute, output is produced, session ends. Repeat. There's no concept of *pausing before* a complex task to make sure all agents are aligned. There's no concept of *reflecting after* a failure to understand what went wrong. There's no concept of *meeting periodically* to share what individual agents have learned and make collective decisions about adoption.

In other words: most multi-agent systems have no team culture. They're a bunch of contractors who show up, do the work, invoice, and leave. Individual effort, no compound learning.

And this shows up in production in a specific, painful way: agents develop conflicting assumptions in parallel. Two agents are simultaneously working on the same system with subtly different mental models of how it works. Neither one checks with the other. Neither one knows there's a conflict. The outputs look reasonable in isolation and break when integrated. You find out in code review, or worse, after deployment.

### Why Standard Frameworks Fail Here

The framing most frameworks use is: agents are tools. Tools don't need retrospectives. Tools don't need alignment ceremonies. Tools just need to be invoked correctly.

That framing breaks the moment you have multiple tools that share a codebase and need to produce consistent outputs over time. At that point, you don't have tools. You have a team. And teams without coordination protocols are not teams — they're just a collection of individuals whose work sometimes overlaps.

The failure isn't malicious. Nobody designed a multi-agent framework and thought "let's make sure agents can't learn from each other." The ceremonies are just... never added. They're not in scope. The framework does the task dispatch, collects the outputs, and considers its job done.

Meanwhile, the same failure keeps happening in week twelve that happened in week three, because nobody — human or AI — ever stepped back to ask why.

### How Squad Solves It

Squad ships with four built-in ceremonies, each with explicit triggers and purposes:

| Ceremony | Trigger | Purpose |
|----------|---------|---------|
| **Design Review** | Auto — multi-agent task on shared systems | Architectural alignment *before* work starts |
| **Retrospective** | Auto — build failure or reviewer rejection | Learning from failures *after* they happen |
| **Symposium** | Scheduled — bi-weekly | Knowledge sharing, adoption decisions |
| **Backlog Review** | Scheduled — weekly | Prioritization, research lifecycle management |

The Design Review ceremony is worth dwelling on because it's the one that prevents the most expensive failures.

When you assign a task that touches more than one system or requires multiple agents, the Lead agent — Picard, in the Star Trek casting — automatically runs a design review *before* spawning any implementation work. Here's what that looks like:

```
Team, build the user search feature with filtering and pagination
```

Before Data writes a single line of code, Picard runs through the coordination plan:

```
🎖️ Picard: Design review initiated for user search task.

   Scope assessment: Multi-concern feature requiring:
   - API endpoint design (Data)
   - Security review of search filters (Worf)
   - Documentation (Seven)
   - Infrastructure config for search indexing (B'Elanna)

   Coordination plan: B'Elanna and Data need alignment
   on indexing strategy before implementation starts.

   → Routing: B'Elanna and Data sync on schema first.
   → Data: Begin API scaffolding after schema sign-off.
   → Worf: Security review of filter inputs during implementation.
   → Seven: Documentation draft after API shape is finalized.
```

The agents don't start implementing until the coordination plan is approved. This catches "B'Elanna and Data are about to write conflicting migration scripts" before it becomes a 2 AM debugging session. In my experience, the Design Review catches the *I didn't know you were doing that* class of failure, which is maybe the most common class of failure in any team working in parallel.

The Retrospective ceremony handles the other side: learning from what actually went wrong. When a build fails or a reviewer rejects a change, Squad doesn't just let the failure slide. It triggers a structured reflection — what was the root cause, what should be changed in the working approach, what gets added to `decisions.md` so the same mistake doesn't get made by a different agent two weeks from now. Institutional learning, made systematic.

And the Symposium — the bi-weekly scheduled ceremony — is the one that feels most foreign to developers who've never thought about AI team culture. It's a deliberate *positive* ceremony, not failure-driven. Agents present what they've learned, discoveries get surfaced, and the team makes collective adoption decisions: is this pattern worth encoding as a skill? Is this research finding ready to influence production decisions? Are there findings from the last two weeks that contradict each other?

It sounds soft. It compounds hard.

---

## Why These Three Gaps Almost Always Co-Occur

These three gaps — memory, routing, ceremonies — aren't independent problems. They reinforce each other.

Without memory, ceremonies have nothing to write to. The retrospective identifies a root cause, and then the next session starts blank and the agent has no idea the retrospective happened. Without routing, ceremonies can't be automatically triggered — someone has to remember to initiate a design review, and "someone has to remember" is a coordination failure waiting to happen. And without ceremonies, the memory system fills with noise because there's no process for curating what gets promoted from "thing that happened" to "thing we've decided."

The three gaps form a system. Solving one while ignoring the others gets you partway. Solving all three is what makes the difference between an AI team that compounds and an AI team that plateaus.

---

## What This Means For Your Setup

If you're running a multi-agent system right now — whether it's built on Squad, LangChain, AutoGen, CrewAI, or your own infrastructure — here's a quick diagnostic:

**Memory check:** If your agents had a session right now, would they know about a decision made three weeks ago? If no one explicitly put it in a context file this session, the answer is probably no.

**Routing check:** When work arrives that spans multiple concerns, do your agents know who handles what without human intervention? Is there any concept of "this requires a human before proceeding"?

**Ceremony check:** After your last production failure, did anything change about how your agents work? Was there a structured review? Did it produce a documented decision? Did the next agent session start with any knowledge of that review?

If any of these feel uncomfortable to answer, you've found your gaps.

---

## What's Next

In [Part 4](#), we're going to get hands-on with setup — how to actually deploy Squad from scratch, what the first-session onboarding looks like, and the specific patterns I've found most valuable in production. Less theory, more "here's exactly what to do."

If you'd rather learn the full Squad system end-to-end — not just the conceptual overview but the implementation guide, the advanced patterns, and the real-world case studies — we put together a comprehensive course on Gumroad that goes deeper than anything in this series. It covers everything from initial setup to running ceremonies to contributing your squad's learnings back upstream. Worth a look if you're serious about this.

*[Part 1 — What Is Squad?](#) · [Part 2 — Squad vs. Custom Agents](#) · Part 3 — The 3 Gaps · [Part 4 — Deploy from Scratch →](#)*
