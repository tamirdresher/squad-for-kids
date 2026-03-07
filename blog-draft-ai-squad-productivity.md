# How an AI Squad Changed My Productivity (And Why It Shouldn't Have Surprised Me)

*By Tamir Dresher*

---

## I'm Not an Organized Person

Let me start with a confession: I'm not an organized guy. Never have been.

I've tried everything. Notion with its beautifully nested pages and databases. Microsoft Planner with color-coded tasks. Outlook tasks synchronized to my calendar. Dozens of todo apps promising "the one system that will finally work." I even scheduled meetings with myself to force focus time.

None of it lasted more than a week or two.

The problem wasn't the tools—they were fine. The problem was me. Every productivity system requires two things I'm not good at: **willpower** (to maintain the habit) and **remembering to use the tool** (which is ironic, since that's what the tool is supposed to help with).

I'd set up elaborate task hierarchies, feel productive for three days, then forget to check the app. Two weeks later, I'd discover a backlog of overdue tasks mocking me from a notification badge I'd learned to ignore.

[IMAGE: Screenshot showing multiple productivity apps installed (Notion, Planner, Todoist, etc.) with notification badges indicating abandoned tasks]

## Then AI Changed Everything

Here's what's different about AI: **AI doesn't forget. AI doesn't need willpower. AI just works.**

Unlike a todo app that sits there passively waiting for me to remember it exists, AI agents can:
- **Remember things I forget** (like that decision we made three weeks ago about cluster architecture)
- **Discuss things with me** (not just execute commands, but reason through trade-offs)
- **Research and explore** (while I'm in meetings or sleeping)
- **Keep working when I stop** (because they don't get tired or distracted)

That last point is the breakthrough. I don't need to *maintain* the system. The system maintains itself.

So I built a Squad.

---

## Meet the Team

The Squad is a team of five AI specialists, each with distinct expertise and personality. I named them after Star Trek characters because, honestly, that's a team I respect—specialists who disagree productively and solve problems together.

[IMAGE: Team roster graphic showing 5 AI agents with their roles - Picard (Lead), B'Elanna (Infrastructure), Worf (Security), Data (Code), Seven (Research & Docs)]

**The Core Team:**
- **Picard (Lead):** Architecture and distributed systems. Makes decisions quickly, revisits when data changes.
- **B'Elanna (Infrastructure Expert):** Kubernetes, cloud infrastructure, deployment pipelines. Gets things running.
- **Worf (Security & Cloud):** Security analysis, compliance, cloud architecture. Questions everything.
- **Data (Code Expert):** C#, Go, .NET. Focused and reliable.
- **Seven (Research & Docs):** Documentation, analysis, research synthesis. That's me writing this post.

**The Background Workers:**
- **Ralph (Work Monitor):** Watches the GitHub issue queue, nudges when things stall, keeps work moving.
- **Scribe (Session Logger):** Silent observer who documents decisions and sessions for institutional memory.

Each agent has a **charter** (documented in `.squad/agents/{name}/charter.md`) that defines:
- What they own (expertise domains)
- How they work (read decisions before starting, write decisions when making choices)
- What they don't handle (boundaries that prevent scope creep)
- Their voice (personality traits that make collaboration feel natural)

Why charters? Because clarity prevents conflict. When Data encounters a security question, he knows to say "that's Worf's domain" rather than guess. When Worf proposes infrastructure changes, B'Elanna reviews them because she owns that space.

---

## GitHub Issues as the Source of Truth

Here's how work happens: I create a GitHub issue.

Not a Slack message that gets lost in history. Not an email buried in a thread. Not a meeting that produces notes nobody reads. A GitHub issue.

[IMAGE: Example GitHub issue showing a task from Tamir with context, followed by agent comments showing discussion and decisions]

**Example: Issue #41 (this blog post)**

I wrote:
> "I want to write a blog post about what we built here. Start with a personal note that I'm not an organized guy... AI changes this because AI doesn't forget. Show how Squad works—the team structure, GitHub issues as workflow, Ralph's watch loop, skills and decisions."

Seven (Research & Docs) immediately triaged it, posted an outline, and got my feedback. Then wrote this complete draft you're reading now, including suggestions for images. All tracked in one GitHub issue with full context.

**Why GitHub Issues Work:**
1. **Permanent record:** Decisions don't get lost in Slack history
2. **Context in one place:** Issue description + comments = full conversation history
3. **Async-first:** I don't need to be online. Agents work while I sleep.
4. **Traceable reasoning:** Every decision shows *how* we got there, not just *what* we decided

No meetings required. No email threads. No "can you remind me what we decided?" questions.

---

## The Ralph Watch Loop: AI That Works While You Sleep

The breakthrough moment was realizing I could have Ralph check the work queue automatically, every few minutes, without me prompting him.

Here's the script (`ralph-watch.ps1`):

```powershell
$intervalMinutes = 5
$prompt = 'Ralph, Go! Make sure PR comments are handled, merge PRs when ready, 
           open new issues if needed. Update me in Teams if needed.'

while ($true) {
    # Pull latest code
    git fetch && git pull
    
    # Launch a full Copilot session that can do actual work
    agency copilot --yolo --autopilot --agent squad -p $prompt
    
    # Wait 5 minutes, repeat
    Start-Sleep -Seconds ($intervalMinutes * 60)
}
```

[IMAGE: Terminal output showing Ralph's periodic check-ins, with timestamps showing automated rounds every 5 minutes]

That's it. Ralph wakes up every 5 minutes, pulls the latest code, reviews open issues and PRs, handles comments, merges when tests pass, and opens new issues if he discovers work that needs doing.

**What This Enables:**
- I wake up to PRs merged and tested
- Security findings documented in new issues
- Research analysis completed overnight
- Comments on PRs addressed with full reasoning

**The Future: `squad-cli watch` Command**

Right now, Ralph runs via this PowerShell script. But there's a better version coming: the `squad-cli watch` command. Once it's stable, the entire loop will be built into the CLI—no script needed, just `squad watch --interval 5m` and the agent handles the rest.

---

## Skills and Decisions: Institutional Memory

Most teams lose knowledge when people leave. Documents get outdated. Tribal knowledge evaporates. Six months later, nobody remembers *why* we chose that architecture.

The Squad solves this with two systems: **Skills** and **Decisions**.

### Decisions: Documented Reasoning

Every team decision goes into `.squad/decisions.md` with a standard format:

```markdown
## Decision 6: Security Findings — idk8s-infrastructure

**Date:** 2026-03-02
**Author:** Worf (Security & Cloud)
**Status:** ✅ Adopted
**Impact:** High

**Finding:** Manual certificate rotation in KeyVault creates outage risk
**Rationale:** Service owners must manually rotate TLS certs; human error 
               causes expired certificates
**Action:** Implement cert-manager with automated renewal, enable 30-day 
            expiration alerts
```

[IMAGE: Screenshot of decisions.md showing multiple decision entries with dates, authors, and statuses]

**Why This Works:**
- **Searchable:** Future agents can grep for "certificate" and find the decision
- **Attributed:** Every decision shows who made it and when
- **Reversible:** If context changes, we document why we're changing course
- **Async:** No meeting required to record or review decisions

When a new agent joins (or an existing agent starts a new session), they read `.squad/decisions.md` first. Instant context transfer.

### Skills: Learning What Works

Skills are documented patterns the team has learned:

- "When ADO API access fails, use Playwright + Edge browser with user profile as fallback"
- "When primary repository access is blocked, perform gap analysis on secondary sources"
- "Living documentation (5 layers near code) beats static docs for AI teams"

These aren't just notes—they're operational knowledge that gets reused. When Data encounters an ADO API error, he knows to try Playwright because that skill is documented.

---

## Real Impact: Research While I Sleep

Let me show you what this enables with a real example.

**Issue #23: Cross-repo infrastructure analysis**

I asked the Squad to analyze a complex infrastructure repository (`idk8s-infrastructure`) across Azure DevOps. The repository manages Kubernetes clusters across multiple clouds (Azure Public, Fairfax, Mooncake) with sophisticated fleet management.

**What Happened:**
1. **Picard** (Lead) did architectural analysis, identified 10 major gaps in documentation
2. **B'Elanna** (Infrastructure) documented cluster orchestration patterns, node health lifecycle, multi-cloud abstractions
3. **Worf** (Security) found 6 critical/high security findings (manual cert rotation risk, Traffic Manager public exposure, cross-cloud security inconsistencies)
4. **Seven** (Research & Docs) synthesized everything into executive summaries
5. **Data** (Code) analyzed the .NET and Go codebase for patterns

All of this happened **overnight**, in parallel, with zero meetings.

[IMAGE: Split-screen showing multiple analysis documents created (architecture report, security findings, infrastructure inventory) with timestamps showing they were all created within hours]

The output wasn't just facts—it was **reasoning**:
- "Here's what we found, here's why it matters, here's what to do about it"
- Decision traces showing "we believed X, learned Y, now we think Z"
- Specific code examples and architectural patterns cited with line numbers

This is the leverage I never had before. A task that would take me 2 weeks of serial research happened in a few hours of parallel AI work.

---

## What's Next: Ideas We're Exploring

### 1. Devboxes and Codespaces

Right now, the Squad runs on my local machine. But what if the entire team operated in cloud development environments?

**Vision:**
- Each agent has a Devbox or Codespace
- Coordination still happens via GitHub issues
- Code execution and builds happen in the cloud
- Scale to larger repositories without local resource constraints

### 2. Cross-Repo Coordination

The Squad already works across multiple repositories. We've analyzed infrastructure, security, and code repositories in parallel.

**Vision:**
- Monitor multiple repositories simultaneously
- Detect cross-repo dependencies and conflicts
- Coordinate changes across services (e.g., API contract changes affecting multiple consumers)

### 3. Continuous Learning

Every session teaches the Squad what works:
- Which patterns led to successful outcomes
- What mistakes to avoid next time
- How to improve decision quality

This isn't static documentation—it's **living knowledge** that improves over time.

[IMAGE: Diagram showing feedback loop - Work → Decisions → Skills → Improved Work]

---

## Lessons for Engineers

If you're reading this thinking "I could never build this," stop. You absolutely can. Here's what I learned:

### 1. You Don't Need Perfect Tools—You Need AI That Remembers

Productivity tools fail when they require willpower and memory (the two things you're trying to fix). AI doesn't have those constraints. It just works.

### 2. Async-First Workflows Beat Meetings

Every Squad interaction happens in GitHub issues. No meetings. No calendars. No "let me check my schedule."

Context is preserved, decisions are documented, and work continues regardless of timezones or schedules.

### 3. Document Decisions, Not Just Conclusions

The **why** matters more than the **what**. Future humans (and AI agents) need to understand *how* you reached a decision, not just what you decided.

Template:
```
- What we believed before
- What we learned
- What we disagree about
- What we're doing and why
```

### 4. Specialization Works (for AI and Humans)

Each agent has clear boundaries. Picard handles architecture. Worf handles security. Data handles code.

This prevents:
- Scope creep (agents stay in their lane)
- Decision paralysis (clear ownership)
- Knowledge loss (expertise is documented)

### 5. Let AI Handle Remembering; You Handle Context

I don't manage the Squad's memory. The Squad manages its own memory via decisions, skills, and session logs.

My job is to provide context: "Here's the problem, here's why it matters, here's what success looks like."

[IMAGE: Venn diagram showing "Human: Context & Goals" + "AI: Memory & Execution" = "Productive System"]

---

## This Isn't Magic—It's Systems Design

The Squad isn't a miracle. It's just good systems architecture applied to productivity:

1. **Clear interfaces** (GitHub issues as work items)
2. **Separation of concerns** (each agent owns specific domains)
3. **Documented state** (decisions and skills as persistent memory)
4. **Async communication** (no synchronous coordination required)
5. **Continuous operation** (Ralph's watch loop)

This is how distributed systems work. It's how microservices communicate. It's how APIs compose.

The only difference is I applied these principles to my **personal productivity**.

---

## The Bottom Line

I spent years failing at productivity tools. None of them worked because they all required the thing I'm bad at: remembering to use them consistently.

AI changes this completely. The Squad doesn't need me to remember. It remembers for me. It works while I sleep. It documents decisions I would have forgotten. It researches problems I don't have time to investigate.

**This is the leverage every engineer deserves.**

Not more todo apps. Not better calendar scheduling. Not another meeting about meetings.

Just a team of AI specialists who handle the boring parts (remembering, documenting, tracking) so you can focus on the interesting parts (deciding, designing, building).

If you're tired of abandoning productivity systems after two weeks, maybe it's not your fault. Maybe the tools just aren't designed for how humans actually work.

**Maybe it's time to hire an AI Squad.**

---

## Try It Yourself

Want to build your own Squad?

- **Squad CLI**: [github.com/bradygaster/squad](https://github.com/bradygaster/squad) (install with `npm install -g @bradygaster/squad`)
- **GitHub Copilot**: Enable for your repository
- **Charters**: Start simple—define 3-5 specialists you need
- **GitHub Issues**: Use them as your work queue
- **Decisions**: Document the *why*, not just the *what*

Start small. One agent. One issue. One decision documented. Build from there.

The Squad will remember. You just provide context.

---

*Tamir Dresher is a software engineer who finally got organized by hiring AI specialists named after Star Trek characters. The Squad lives at [github.com/tamirdresher_microsoft/tamresearch1](https://github.com/tamirdresher_microsoft/tamresearch1).*

[IMAGE: Footer graphic showing the tamresearch1 GitHub repository with Star Trek squad members working on various issues]
