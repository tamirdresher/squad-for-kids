# Chapter 6: Humans in the Squad

> *"The most important features are the ones that change how you think about the whole system."*

Let me tell you about the feature I almost didn't try.

Not because it seemed complicated. Not because I didn't understand it. But because I didn't think I **needed** it.

I had my AI team humming along. Ralph watching the queue every 5 minutes. Data writing code while I slept. Seven documenting decisions automatically. My personal repo had zero open issues for the first time in two years. Why would I mess with what was working?

Then I tried to bring Squad to my actual job.

And everything broke.

---

## The Problem I Didn't See Coming

Here's the setup: I work at Microsoft, on a platform team. Five engineers. Real teammates with decades of experience, strong opinions, and merge authority. We're building distributed systems that run at Azure scale. Security matters. Performance matters. Architecture decisions matter a lot.

My personal repo? That's my playground. If Data makes a questionable architecture choice at 2 AM, worst case I roll it back over coffee. No big deal.

My work repo? If Data makes an architecture choice at 2 AM that contradicts the patterns we've been building for six months, my teammates are going to ask very reasonable questions like "who approved this?" and "why are we rewriting the entire auth layer?" and "Tamir, what the hell?"

I couldn't just drop Ralph into the work repo and say "go nuts." That's not delegation, that's abdication.

But I also couldn't **not** use Squad. I'd seen what it could do. The 5-minute watch loop. The parallel execution. The compounding knowledge. Going back to manual issue tracking felt like going back to a flip phone after using a smartphone.

The question that kept me up at night: **How do you get the benefits of AI automation without losing human judgment?**

The answer turned out to be stupidly obvious once I saw it.

You add the humans to the Squad.

---

## The First Experiment: Adding Myself

I started small. Really small. Just me.

I opened `.squad/team.md` in my personal repo — the file that defines who's on the team — and I added a new section:

```markdown
## Human Members

| Name | Role | Interaction Channel | Notes |
|------|------|---------------------|-------|
| Tamir Dresher | Project Owner, Decision Maker | Microsoft Teams (preferred), GitHub Issues | Delegate tasks via Teams. Not spawnable — present work and wait for input. |
```

That's it. That's the whole change.

But look at that last column: **"Not spawnable — present work and wait for input."**

This is the key. When work routes to an AI squad member like Data or Worf, Squad spawns them and they start working immediately. When work routes to a human squad member — me — Squad **pauses**. It doesn't try to guess what I'd decide. It doesn't hallucinate my response. It doesn't skip the step.

It waits.

And while it's waiting, it pings me. On GitHub. On Teams. Wherever I told it to reach me.

The first time this happened, I was at lunch. My phone buzzed:

```
📌 @tamirdresher: Architecture review needed
   Issue #47: Redesign authentication API
   Picard has completed analysis and recommends JWT + refresh tokens
   
   Waiting for your sign-off before Data begins implementation.
```

I read Picard's analysis on my phone. It was solid. The JWT approach made sense for our use case. I commented "approved" on the issue.

By the time I got back to my desk 20 minutes later, Data had opened a PR with the implementation. The tests were passing. The code followed the patterns Picard had outlined in his analysis.

**I made the decision. The AI did the work.**

That's when it clicked: this isn't about AI **replacing** humans. It's about AI handling everything that **doesn't** require human judgment, and then pausing at exactly the moment when judgment is needed.

---

## How the Pause Actually Works

Let me show you what happens under the hood when Squad encounters a human squad member.

Here's a routing rule from `.squad/routing.md`:

```markdown
| Work Type | Route To | Examples |
|-----------|----------|----------|
| Architecture, distributed systems, decisions | Picard | Breaking down complex systems, evaluating trade-offs |
| Security reviews, compliance gates | Worf | Security audits, vulnerability assessments |
| Code review | @copilot 🤖 | Review PRs, check quality, suggest improvements |
```

Notice the last row? That `@copilot` is a special squad member — the GitHub Copilot coding agent. It's another AI, but it works a bit differently. When an issue gets labeled `squad:copilot`, the issue is assigned to the @copilot GitHub user and it starts working autonomously.

Now here's where it gets interesting. Squad has a **capability profile** for @copilot:

```markdown
## @copilot Capability Profile

| Category | Rating | Notes |
|----------|--------|-------|
| Bug fixes, test additions | 🟢 Good fit | Well-defined, bounded scope |
| Small features with specs | 🟡 Needs review | PR review required |
| Architecture, security | 🔴 Not suitable | Keep with squad members |
```

When Picard (my Lead agent) triages a new issue, he reads this capability profile and decides:
- 🟢 Good fit → route to `squad:copilot`, let @copilot handle it autonomously
- 🟡 Needs review → route to an AI squad member, but flag it for human review before merge
- 🔴 Not suitable → route to human squad member for direct handling

This is explicit escalation. No guessing. No "I think the AI can probably handle this." The boundaries are clear, codified, and enforced by the routing system.

---

## The Workflow That Changes Everything

Here's the pattern that emerged once I had human squad members in the roster:

**1. AI Analysis → 2. Human Decision → 3. AI Execution**

Let me show you a real example. A few weeks ago, I filed this issue:

> **Issue #112:** Add rate limiting to public API endpoints

This is a security concern. Worf's domain. But rate limiting also touches architecture (how do we track request counts?), infrastructure (where do we store the counters?), and code (how do we implement the middleware?).

Here's what happened:

**Step 1: AI Analysis**

Worf picked it up first (because it's tagged `squad:worf`). He analyzed the issue and opened a PR with his findings:

```markdown
## Security Analysis: Rate Limiting Implementation

**Threat Model:**
- DDoS attacks on public endpoints
- Credential stuffing via auth endpoint
- Data scraping via search endpoint

**Recommended Approach:**
- Token bucket algorithm (industry standard)
- Redis for distributed counter storage
- Per-IP and per-user rate limits
- Graceful degradation if Redis unavailable

**Trade-offs:**
- Redis dependency adds operational complexity
- In-memory fallback reduces protection but maintains availability
- Rate limit headers (X-RateLimit-*) inform clients of limits

**Implementation complexity:** Medium (3-5 days)
**Security impact:** High (blocks 90%+ of abuse patterns)

@tamirdresher — Does this approach align with our infrastructure strategy?
```

Notice that last line? Worf didn't implement anything. He **analyzed** the problem, identified trade-offs, made a recommendation, and then **explicitly asked for my input**.

**Step 2: Human Decision**

I read Worf's analysis. The Redis approach made sense, but we already had Azure Cache for Redis running for session storage. I commented:

> Approved. Use existing Azure Redis instance for rate limit counters. Add a config flag to disable rate limiting in dev environments.

**Step 3: AI Execution**

Worf handed off to Data (my code expert) with context:

```
🔒 Worf → 💻 Data: Implementation approved by @tamirdresher
   Context: Use existing Azure Redis, add dev config flag
   Implementation: Token bucket middleware, Redis counters, rate limit headers
```

Data implemented it. Tests included. Documentation updated. PR opened. I reviewed the code (10 minutes), approved it, and it shipped.

**Total time from issue filed to merged PR: 6 hours.**

**My time investment: 15 minutes (10 min reading analysis + 5 min reviewing code).**

The AI did the research. The AI did the implementation. The AI did the testing. I made the **decisions**.

---

## Why This Works: Clear Boundaries

Traditional automation has a problem: it's either **too rigid** (can only handle exact scenarios you programmed) or **too autonomous** (makes decisions without consulting you and sometimes gets them wrong).

Squad's human squad member pattern solves this with **explicit escalation boundaries**.

Here's what that looks like in `.squad/routing.md`:

```markdown
## Rules

1. **Eager by default** — spawn all agents who could usefully start work
2. **Scribe always runs** after substantial work, always as background
3. **Quick facts → coordinator answers directly** — don't spawn an agent for "what port does the server run on?"
4. **When two agents could handle it**, pick the one whose domain is the primary concern
5. **"Team, ..." → fan-out** — spawn all relevant agents in parallel
6. **Anticipate downstream work** — if a feature is being built, spawn the tester simultaneously
7. **Issue-labeled work** — when a `squad:{member}` label is applied, route to that member
8. **@copilot routing** — check capability profile, route 🟢 tasks autonomously, flag 🟡 for review, keep 🔴 with humans
```

See rule #8? That's the critical one. The capability profile isn't a suggestion — it's a **contract**. When Picard evaluates an issue, he checks that profile before routing. If it's marked 🔴 (not suitable for autonomous AI work), he routes it to a human squad member.

This means I'm not playing "AI whack-a-mole" — reviewing random PRs hoping the AI didn't make an architecture decision I'll regret. I'm making decisions **before** implementation starts, when it's cheap to change direction.

---

## Practical Patterns: Where Humans Add Value

After three months of running Squad with human squad members, I've identified four patterns where human judgment is irreplaceable:

### Pattern 1: Architecture Decisions

**The Setup:** Squad needs to add a new feature that touches multiple systems.

**AI Role:** Picard analyzes dependencies, identifies integration points, recommends an approach.

**Human Role:** I evaluate trade-offs (complexity vs. flexibility, performance vs. maintainability) and approve the direction.

**Why Humans Matter:** Architecture decisions have long-term consequences. AI can model the immediate trade-offs, but humans understand the **strategic direction** — where the codebase is going, not just where it is.

### Pattern 2: Security Reviews

**The Setup:** Worf finds a potential vulnerability during his automated scan.

**AI Role:** Worf identifies the issue, assesses severity, proposes a fix.

**Human Role:** I validate the threat model (is this actually exploitable in our deployment?) and approve the mitigation strategy.

**Why Humans Matter:** Security is context-dependent. A "vulnerability" in one deployment might be a non-issue in another. Humans understand the **operating environment** — attack surface, threat actors, acceptable risk.

### Pattern 3: Documentation Strategy

**The Setup:** Seven needs to document a complex subsystem.

**AI Role:** Seven drafts comprehensive documentation covering how the system works.

**Human Role:** I review for **why** — why we built it this way, why we rejected alternatives, why this matters to users.

**Why Humans Matter:** Good documentation doesn't just explain how things work. It explains **intent**. AI can document the "what," but humans know the "why."

### Pattern 4: Code Review for Design

**The Setup:** Data implements a feature and opens a PR.

**AI Role:** @copilot pre-screens for bugs, style violations, test coverage.

**Human Role:** I review for **design** — does this fit our patterns? Is this the right abstraction? Will future-us thank us or curse us for this choice?

**Why Humans Matter:** Code review isn't just about correctness. It's about **maintainability**. Humans understand what makes code easy to change six months from now.

---

## The Anecdotes You Actually Want

Enough theory. Let me tell you three stories that show why human squad members changed everything.

### Story 1: The Architecture Review at Lunch

I was at lunch with a friend. My phone buzzed. Picard needed an architecture review for a database migration strategy.

I opened GitHub on my phone. Picard had written a 3-page analysis comparing:
- Approach A: Dual-write during transition (complex, zero downtime)
- Approach B: Maintenance window migration (simple, 2-hour downtime)

His recommendation: Approach B. We're a small team, 2 AM maintenance windows are acceptable, complexity isn't worth it.

I agreed. I commented "approved" and went back to my lunch.

By the time I got back to my desk, Data had the migration script written and tested. B'Elanna had the deployment runbook ready. The migration ran that night at 2 AM. Zero issues.

**I made a 30-second decision on my phone that unblocked 4 hours of implementation work.**

This is the power of "pause and ping." I wasn't chained to my desk. The work didn't stop. But the critical decision waited for me.

### Story 2: The Security Finding That Needed Context

Worf ran his automated security scan and flagged an issue:

> **Security Finding:** Unencrypted Redis connection in production config

His analysis was thorough. Unencrypted Redis traffic could leak session tokens. He recommended enabling TLS immediately.

But here's the thing: our Redis instance runs on Azure Cache for Redis, inside a VNet with strict network isolation. The traffic never touches the public internet. Enabling TLS adds latency and operational complexity for a threat that doesn't exist in our deployment.

I commented:

> Risk accepted. Redis runs in isolated VNet, traffic never leaves Azure backbone. TLS not required for this threat model. Add a config note explaining this decision.

Worf updated the documentation and closed the finding. The decision took me 2 minutes. If Worf had just **implemented** the TLS change without asking, I would have spent 20 minutes figuring out why Redis suddenly had 15ms higher latency, then rolled it back anyway.

**AI found the issue. Human made the call based on operational context.**

### Story 3: The Documentation That Almost Went Wrong

Seven wrote a beautiful guide for our authentication system. Comprehensive. Accurate. Well-structured.

But it was written for **developers**, not **users**.

I reviewed it and realized: this explains **how** JWT tokens work (encoding, signing, validation), but it doesn't explain **why** users should care (stateless auth, horizontal scaling, microservices compatibility).

I left a comment:

> Great technical accuracy, but wrong audience. This needs to explain why stateless auth matters for API consumers, not how JWT internals work. Rework for a product manager reading this, not a security engineer.

Seven revised it. The new version was perfect — explaining the user benefits of stateless auth (faster API responses, no session affinity issues) with just enough technical detail to build confidence.

**AI drafted the content. Human shaped the message.**

---

## State Management: How Squad Tracks "Waiting on @tamirdresher"

You might be wondering: when Squad pauses for human input, how does it track state? What happens if I don't respond immediately? Does the work just hang forever?

Squad's state management is surprisingly elegant. Here's how it works:

### The Waiting State

When work routes to a human squad member, Squad creates a **waiting checkpoint**:

```json
{
  "status": "waiting",
  "waiting_on": "tamirdresher",
  "reason": "Architecture review needed for Issue #47",
  "pinged_at": "2026-03-10T15:23:00Z",
  "ping_channels": ["github", "teams"],
  "blocking": ["issue-47-implementation"]
}
```

This checkpoint has a few key properties:

1. **It's visible** — Ralph's status report shows "Waiting on @tamirdresher" in his monitoring output
2. **It's persistent** — the waiting state survives across sessions, terminals, reboots
3. **It has context** — the checkpoint includes *why* I'm needed and *what's blocked*
4. **It pings proactively** — I get notified on GitHub and Teams automatically

### The Unblocking Flow

When I respond (comment on GitHub, reply in Teams), Squad picks up the thread:

```json
{
  "status": "unblocked",
  "unblocked_by": "tamirdresher",
  "decision": "Approved: JWT + refresh tokens per Picard's recommendation",
  "unblocked_at": "2026-03-10T15:45:00Z",
  "next_agent": "data"
}
```

The checkpoint is updated, the decision is logged in `.squad/decisions.md`, and the next agent (Data, in this case) picks up execution.

### The Timeout Strategy

What if I **don't** respond? What if I'm on vacation? Or ignoring my phone? Or the notification gets buried under 47 Teams messages?

Squad has escalation timeouts:

- **2 hours:** First reminder ping
- **24 hours:** Escalate in priority (marked urgent in notifications)
- **72 hours:** Log as "blocked on human input" and move to next available work

This prevents the entire squad from grinding to a halt because I didn't see one notification. Work that doesn't depend on my input continues. Work that does gets escalated appropriately.

---

## No 3 AM Surprises

Here's my favorite thing about human squad members: **I've never woken up to a disaster.**

Not once.

In three months of running Squad with humans in the roster, I've never had:
- An architecture decision I regretted
- A security change that broke production
- A feature implemented in a way that contradicted team patterns
- A refactor that made the codebase harder to work with

Why? Because Squad doesn't **guess** when human judgment is needed. It **asks**.

The routing rules in `.squad/routing.md` define the boundaries:

```markdown
| Work Type | Route To | Examples |
|-----------|----------|----------|
| Bug fixes, test additions | @copilot 🤖 | Well-defined, bounded scope |
| Small features with specs | Data | Clear requirements, existing patterns |
| Architecture, distributed systems, decisions | Picard → @tamirdresher | Breaking down complex systems, evaluating trade-offs |
| Security, compliance, production access | Worf → @tamirdresher | Security audits, vulnerability assessments |
```

See how that works? Simple stuff (bug fixes, tests) goes directly to @copilot. Medium complexity (small features) goes to AI squad members who can handle it autonomously. Complex stuff (architecture, security) goes to AI squad members **who then escalate to humans** for final decisions.

The boundaries are explicit. The escalation is automatic. There's no "I hope the AI makes the right call here."

And that means I can go to sleep at night knowing that if something important happens, I'll be pinged. And if I'm **not** pinged, it's because nothing important happened.

---

## The Deep Integration: GitHub, Teams, and State

Let me show you how the human squad member integration actually works across different channels.

### GitHub Integration

When Squad needs human input, it pings me on GitHub by:
1. **Mentioning me in a comment:** `@tamirdresher — Architecture review needed`
2. **Assigning the issue to me** (if the issue isn't already assigned)
3. **Adding a `status:waiting-human` label** so it's visible in project boards

I can respond by:
- Commenting directly on the issue
- Approving a draft PR that Picard opened with his analysis
- Closing the issue with a decision note

Squad monitors GitHub notifications and picks up my response within minutes (Ralph's 5-minute watch loop).

### Teams Integration

For urgent decisions, Squad also pings me on Microsoft Teams:

```
📌 Squad Notification
   Issue: #47 — Authentication API redesign
   Agent: Picard
   Status: Waiting for architecture review
   
   [View Issue] [View Analysis] [Approve] [Request Changes]
```

The Teams message includes action buttons. I can approve Picard's recommendation directly from Teams without opening GitHub. When I click "Approve," Squad:
1. Posts a comment on the GitHub issue with my approval
2. Logs the decision in `.squad/decisions.md`
3. Unblocks the next agent (Data) to start implementation

This is **critical** for making "human in the loop" practical. I don't have to be at my desk, watching a terminal scroll. I get a notification on my phone, I make a decision in 30 seconds, and the work continues.

### State Persistence

Squad's waiting state is stored in `.squad/state/waiting.json`:

```json
{
  "waiting_items": [
    {
      "id": "wait-47-architecture",
      "issue": 47,
      "waiting_on": "tamirdresher",
      "reason": "Architecture review needed",
      "agent": "picard",
      "blocked_work": ["issue-47-implementation"],
      "pinged_at": "2026-03-10T15:23:00Z",
      "reminders_sent": 0,
      "status": "pending"
    }
  ]
}
```

This file persists across sessions. If my terminal crashes, my laptop reboots, or I close VS Code and come back tomorrow, Squad still knows:
- What's waiting for me
- How long it's been waiting
- What work is blocked
- Where to ping me

The state doesn't live in my head. It doesn't live in a transient session. It lives in the repo, versioned, persistent, and queryable.

---

## Adding My Actual Teammates (The Next Chapter)

Everything I've shown you so far is **me** as the only human squad member. My personal repo. My decisions. My escalation points.

But here's the question that kept me awake after I got this working:

**What if I added my actual teammates as human squad members?**

Not AI agents. Real people. With real GitHub handles. Real expertise. Real merge authority.

What if Brady (the guy who created Squad) was a human squad member responsible for Squad framework decisions?

What if Worf (our actual security lead — yes, his handle is @worf) was a human squad member for security reviews?

What if B'Elanna (our infrastructure expert) was a human squad member for deployment decisions?

What if the work team itself became a Squad — a mix of humans and AI, working together?

That's not a hypothetical. I tried it. And it worked.

But the patterns are different when you have **multiple humans** in the squad. The routing gets more complex. The escalation strategies need to account for different expertise domains. The notification system needs to ping the **right** human for the **right** decision.

That's the next chapter. And it's where Squad goes from "personal productivity tool" to "team collaboration framework."

---

## The Technical Details: .squad/team.md Structure

For the technical readers who want to know how this actually works, here's the structure of `.squad/team.md`:

```markdown
# Team

## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|
| Picard | Lead | `.squad/agents/picard/charter.md` | ✅ Active |
| Data | Code Expert | `.squad/agents/data/charter.md` | ✅ Active |
| Worf | Security & Cloud | `.squad/agents/worf/charter.md` | ✅ Active |
| Seven | Research & Docs | `.squad/agents/seven/charter.md` | ✅ Active |
| B'Elanna | Infrastructure | `.squad/agents/belanna/charter.md` | ✅ Active |
| @copilot | Coding Agent | — | 🤖 Active |
| Tamir Dresher | 👤 Human — Project Owner | — | 👤 Human |

## @copilot Capability Profile

| Category | Rating | Notes |
|----------|--------|-------|
| Bug fixes, test additions | 🟢 Good fit | Well-defined, bounded scope |
| Small features with specs | 🟡 Needs review | PR review required |
| Architecture, security | 🔴 Not suitable | Keep with squad members |

## Human Members

| Name | Role | Interaction Channel | Notes |
|------|------|---------------------|-------|
| Tamir Dresher | Project Owner, Decision Maker | Microsoft Teams (preferred), GitHub Issues | Delegate tasks via Teams. Not spawnable — present work and wait for input. |
```

The key sections:

1. **Members table:** Lists all squad members (AI and human) with their roles and status
2. **Capability profile:** Defines what @copilot can handle autonomously (🟢), with review (🟡), or should escalate (🔴)
3. **Human Members table:** Lists humans with interaction channels and special notes

The "Not spawnable" note is critical — it tells Squad that when work routes to me, it should **pause and ping**, not try to spawn me like an AI agent.

---

## Why This Feature Changes Everything

Let me zoom out for a moment.

Before I added human squad members, Squad was a **productivity system**. A really good one. Better than Notion, better than Trello, better than every other system I'd tried and abandoned.

But it was still fundamentally about **me getting more done**.

After I added human squad members, Squad became something else.

It became a **collaboration framework**.

The difference is subtle but profound:

**Productivity system:** AI does work for me, I review and approve it.

**Collaboration framework:** AI and humans work together, each contributing what they're uniquely good at.

Productivity systems are about **automation**. Collaboration frameworks are about **augmentation**.

Automation replaces humans. Augmentation **amplifies** them.

And the feature that makes this work — the feature that turns Squad from automation into augmentation — is the ability to add humans to the roster and have the system **respect the boundaries** between what AI should handle and what humans should decide.

The explicit escalation. The pause-and-ping behavior. The persistent waiting state. The multi-channel notifications.

That's not AI replacing humans. That's AI and humans working as a **team**.

---

## The Honest Confession (Again)

I need to tell you something before we move on.

This still isn't perfect.

Sometimes the routing rules get it wrong. Sometimes Picard routes something to me that Data could have handled autonomously. Sometimes @copilot gets assigned a task that's actually 🟡 (needs review) but was classified as 🟢 (good fit).

Some decisions still fall through the cracks. Some notifications get buried. Some waiting states hang longer than they should.

**But here's the difference:** When something goes wrong, I can fix it by **updating the routing rules**. I can tweak the capability profile. I can adjust the escalation thresholds.

The system isn't perfect. But it's **improvable**. And every week, the routing gets a little smarter. The boundaries get a little clearer. The escalations get a little more accurate.

That's compounding again. Not just in decisions and knowledge, but in the **system's understanding of when to ask for help**.

And compounding is the most powerful force in the universe.

---

## Diagram Notes for Seven

*Seven — when you're laying this out, here are the diagrams I'm imagining:*

**Diagram 1: "The Pause-and-Ping Flow"**
- Show a task routing to Picard (AI)
- Picard does analysis, then routes to @tamirdresher (Human)
- System pauses, sends notification (GitHub + Teams)
- Human responds with decision
- System resumes, routes to Data (AI) for implementation
- Visual: Use different colors for AI agents (blue) and human members (green)

**Diagram 2: "Capability Profile in Action"**
- Show three issues coming in
- Issue A: Bug fix → 🟢 → routes to @copilot directly
- Issue B: Small feature → 🟡 → routes to Data, flagged for human review before merge
- Issue C: Architecture decision → 🔴 → routes to Picard → escalates to human immediately
- Visual: Traffic light colors (green/yellow/red)

**Diagram 3: "State Management"**
- Show the waiting state JSON structure
- Highlight the key fields: waiting_on, reason, blocking, pinged_at
- Show how state persists across sessions
- Visual: Timeline showing state transitions

**Diagram 4: "Multi-Channel Notification"**
- Show Squad in center
- Arrows to: GitHub (mention + issue assignment), Teams (notification with action buttons), Email (backup channel)
- Show human responding from phone (Teams) → state updates → work resumes
- Visual: Emphasize "decision from anywhere"

---

## What's Next

This chapter covered the **theory** and **mechanics** of human squad members. How the pause-and-ping works. How routing decisions happen. How state persists across sessions.

But theory only gets you so far.

The real question — the one that determines whether this is a clever personal hack or something that scales — is:

**Can this work with multiple humans?**

Because my personal repo is easy. It's just me. I'm the only human making decisions. When Squad needs human input, it pings me. When I respond, the work continues. Simple.

But my work repo? That's got five engineers. Each with different expertise. Each with different availability. Each with different thresholds for "this needs human judgment."

If Squad needs an architecture review, it should ping me.
If Squad needs a security review, it should ping our security lead.
If Squad needs an infrastructure decision, it should ping our ops expert.

**Squad needs to know which human to ping for which decision.**

And that's exactly what I built next. Multi-human squad routing. Domain expertise mapping. Notification routing based on work type.

The chapter that answers: **How do you scale Squad from a personal tool to a team framework?**

That's where we're going next. But first, you needed to understand why adding a single human changes everything.

Because the feature that makes Squad work for teams isn't more sophisticated AI. It's **respecting the boundary between AI automation and human judgment**.

Everything else builds on that.

---

**End of Chapter 6**

*Next: Chapter 7 — Scaling to the Work Team (Multiple Humans, Domain Routing, Real Engineering Constraints)*
