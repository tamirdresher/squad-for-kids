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

### squad-cli loop vs ralph-watch.ps1: Why We Didn't Use squad watch

We tested the new `squad-cli loop` command that comes with squad v0.8.23+. Here's the comparison:

**`squad-cli loop` (Built-in CLI):**
- ✅ Simple: `squad loop --interval 5m` instead of custom script
- ✅ Managed: Handles heartbeat, logging, state management
- ✅ Built for Squad projects: Direct integration with .squad/ config
- ❌ **Limited execution model:** Only supports triage/categorization, not full agent work dispatch
- ❌ **No parallel execution:** Processes one issue at a time (we need 5 agents running on 5 issues simultaneously)
- ❌ **No custom prompting:** Uses hardcoded logic, can't route to specific agents
- ❌ **No observability:** No Teams integration, no structured metrics output

**`ralph-watch.ps1` (Custom Loop):**
- ✅ **Full agent dispatch:** Spawns the `agency copilot` CLI with complete Squad context
- ✅ **Parallel execution:** Can maximize parallelism (e.g., spawn 5 agents for 5 actionable issues in one round)
- ✅ **Custom routing:** Prompts Ralph with explicit agent assignment logic
- ✅ **Teams observability:** Structured logging → heartbeat file → Teams webhook (failure alerts, metrics)
- ✅ **GitHub Project board integration:** ralph-watch prompts Ralph to maintain board status in real-time
- ✅ **Granular metrics:** Tracks PRs merged, issues closed, consecutive failures, round timing
- ❌ **More complex:** PowerShell script, requires webhook config, error handling overhead

**The Decision:**
We built `ralph-watch.ps1` because the built-in `squad loop` didn't exist yet (or was incomplete) when we needed the capability. Now that we have it, `squad loop` is sufficient for simple periodic checks, but **ralph-watch.ps1 remains the right choice for parallel, high-throughput work scheduling** like our production Squad environment.

Think of it this way:
- `squad loop` = basic heartbeat ("is everything still working?")
- `ralph-watch.ps1` = active task dispatch ("here's 5 things to do in parallel, get them done")

**The Future: `squad-cli loop --advanced`**

Eventually, `squad-cli loop` could support full agent dispatch, custom prompting, and Teams integration. When that lands, ralph-watch.ps1 becomes legacy. But for now, the custom script is the only way to get true parallel execution with Squad agents.



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

## Real Impact: 14 PRs in One Day

Let me show you what this enables with a real, concrete example from today.

This morning, I created a batch of GitHub issues for the Squad. By day's end, we'd shipped **14 merged PRs** covering infrastructure, security, research, and compliance—all coordinated through Squad's parallel execution model.

**Today's Shipping Board:**

| PR | Domain | Owner | Status |
|-------|--------|-------|--------|
| #70 | FedRAMP Compliance Validation & Test Suite | Worf | ✅ Merged |
| #69 | Infrastructure Analysis & History | B'Elanna | ✅ Merged |
| #68 | OpenCLAW Workflow Adoption | Seven | ✅ Merged |
| #67 | Security Findings & Compensating Controls | Worf | ✅ Merged |
| #66 | DevBox Provisioning Phase 2 Skill | B'Elanna | ✅ Merged |
| #65 | Infrastructure Inventory & Patterns | B'Elanna | ✅ Merged |
| #64 | Digest Generator Automation | Seven | ✅ Merged |
| #63 | Patent Claims Drafting (TAM-focused) | Data | ✅ Merged |
| #62 | Team Integration & Setup Guide | Picard | ✅ Merged |
| #61 | DevBox Provisioning Phase 1 | B'Elanna | ✅ Merged |
| #60 | Work-Claw Analysis (Issue #17) | Seven | ✅ Merged |
| #59 | Automated Digest Generator Phase 2 | Seven | ✅ Merged |
| #58 | OpenCLAW Pattern Analysis | Seven | ✅ Merged |
| #57 | Ralph Round 1 Orchestration Log | Scribe | ✅ Merged |

**Scope Snapshot:**
- DevBox provisioning from concept to working Phase 1+2 infrastructure
- FedRAMP compliance assessment with 6 high/critical findings + compensating controls
- DK8S infrastructure security validation (nginx-ingress, Istio NodeStuck issues)
- OpenCLAW pattern adoption with three production-ready templates
- Patent claims drafted and ready for filing (TAM-focused positioning)
- Automated digest generation for continuous learning
- Microsoft Teams integration guide for enterprise deployment

**How This Happened:**

1. **Parallel execution** — Each agent owns their domain (Worf = Security, B'Elanna = Infrastructure, Data = Code, Seven = Research)
2. **Async handoffs** — No meetings. Agent A completes work, posts results to GitHub, Agent B picks up next phase
3. **Ralph monitoring** — Every 5 minutes, Ralph checks the queue, merges tests-passing PRs, surfaces blockers
4. **Documented reasoning** — Every PR includes decision trace and architectural rationale
5. **Continuity** — If an agent stops mid-task, Ralph's log shows exactly where to resume

[IMAGE: Terminal showing Ralph's watch loop firing every 5 minutes with timestamps: "2026-03-07T21:43:57Z — 3 PRs merged, 2 issues opened"; "2026-03-07T21:48:57Z — Research complete on Issue #17, posting analysis"; "2026-03-07T21:53:57Z — All tests passing, ready for merge"]

**The Key Insight:**

This didn't require me to context-switch between 14 different problems. I created the issues, set expectations, then let the Squad work in parallel. I woke up to 14 merged PRs with full reasoning documented.

A task that would take a team of humans 2-3 weeks (negotiating across domains, scheduling meetings, context switching) happened in one day because AI doesn't need meetings or context-switching overhead.

This is the leverage every engineer deserves.

---

## "Holy Shit That Is Too Fun" — Community Response

I didn't expect this part.

When I started sharing what the Squad was doing in the "Welcome to Squad" Teams channel, people didn't just say "cool." They started *designing their own squads*. The reactions were immediate and visceral — "this is amazing," "Holy shit that is too fun" — and within days, people were prototyping use cases I hadn't even considered.

Here's what got people most excited:

**Personal squads.** Not shared team infrastructure — *your own* always-on AI team, customized to your daily work. One person's Squad handles Kubernetes operator development. Another's focuses on documentation and compliance. The idea that everyone gets their own squad, tailored to their role, landed hard.

**Mobile and remote access.** Using cli-tunnel, you can control your Squad session from your phone or any browser — zero servers, private-by-default. Someone immediately asked: "Wait, I can check on my Squad from my couch?" Yes. Yes you can.

**Voice-enabled agents.** Multiple people brought up voice MCPs — hands-free development where you talk to your Squad while walking or commuting. We're not there yet, but the pieces exist.

**Accessibility.** This one hit home. People are using Squad to support cognitive disabilities — ADHD, executive function challenges, memory issues. When I said "I'm not an organized person," several people in the channel said "same, and this actually solves it." Squad doesn't judge you for forgetting. It just picks up where you left off.

**Horizontal scaling.** Engineers started asking: can I run *multiple* Squad instances on the same repo, partitioned by labels or folders? Yes. We're already doing it — Ralph handles orchestration on one loop while individual agents work focused issues on separate sessions.

**The governance debate.** This was the most interesting discussion: how much structure should a personal squad have? Some people want strict guardrails and approval gates. Others want full autonomy — "let the Squad ship and I'll review in the morning." There's no right answer yet, but the fact that people are debating it means they're taking it seriously.

The best signal? People explicitly saying "this solves a real problem I was already researching." Not hypothetical value. Not "that's neat." Actual problems, already felt, now solvable.

---

## New Tools We Built Along the Way

Running a Squad at this scale surfaced real operational needs. So we built tools.

### Podcaster (`scripts/podcaster.ps1`)

Not everyone wants to read a 3,000-word research report. So we built Podcaster — a PowerShell script that converts any markdown file into spoken audio using edge-tts (or Windows System.Speech as a fallback). Now I listen to Seven's research reports while making coffee. It's surprisingly useful for catching nuances you'd skim past while reading.

### Squad Monitor v2

When you have Ralph running 24/7 and agents working in parallel, you need visibility. Squad Monitor v2 is a live terminal dashboard showing Ralph's status, open GitHub issues, pending PRs, and orchestration activity in real time. It adapts dynamically to your terminal height — fullscreen on a monitor, compact on a laptop. Think `htop` but for your AI team.

### Teams Message Monitoring

Ralph was already watching GitHub. But we also needed him watching our Teams channels — people post review requests, questions, and action items there too. Using WorkIQ, we wired silent Teams channel monitoring into Ralph's loop every 15 minutes. He scans for anything requiring Squad attention (review requests, blockers, decision questions) and routes them into GitHub issues automatically. No more "did anyone see my message in Teams?"

### cli-tunnel

Remote access to Squad sessions from any device. No servers to provision, no ports to forward, private by default. Start a tunnel, get a URL, open it on your phone. Check on Ralph from the grocery store. I'm not saying I've done this, but I'm not saying I haven't.

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

### 3. Cross-Squad Orchestration

This is the big one. Right now, each Squad is an island — my Squad doesn't know your Squad exists. But what if they could work together?

We're designing cross-squad orchestration (tracked in [bradygaster/squad#316](https://github.com/bradygaster/squad/issues/316)) where different squads operate as peers: discovering each other, sharing context, and handing off work across team boundaries. Imagine my infrastructure Squad detecting a security issue and handing it to your security-focused Squad with full context — no human relay needed. It's early, but the architecture is taking shape.

### 4. Continuous Learning

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

### 6. The Boring Stuff Will Bite You (Technical Lessons)

I burned real hours on problems that had nothing to do with AI and everything to do with PowerShell:

- **PowerShell 5.1 vs 7 compatibility matters.** Ralph *must* run under `pwsh.exe` (PowerShell 7), not `powershell.exe` (5.1). We learned this the hard way when scripts silently failed.
- **UTF-8 BOM is critical for PS 5.1 script parsing.** Without the byte-order mark, PS 5.1 misreads scripts with special characters. Save your `.ps1` files with BOM encoding.
- **stderr from native commands causes false failures in PS 5.1.** A `try/catch` block will catch stderr output from `git` or `npm` as an exception, even when the command succeeded. This made Ralph think everything was broken when it wasn't.
- **Always push fixes immediately.** Ralph does `git pull` at the start of every loop. If you fix something locally but don't push, Ralph will pull the old code next round and revert your fix. Ask me how many times I learned this lesson.
- **Multiple Ralph processes can collide.** We added a lockfile mechanism after discovering two Ralph instances both trying to merge the same PR simultaneously. Now the first one grabs the lock, the second one skips the round.

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

AI changes this completely. The Squad doesn't need me to remember. It remembers for me. It works while I sleep. It documents decisions I would have forgotten. It researches problems I don't have time to investigate. In a few weeks, we've shipped 220+ issues and 60+ PRs — and the pace is accelerating, not slowing down.

**This is the leverage every engineer deserves.**

Not more todo apps. Not better calendar scheduling. Not another meeting about meetings.

Just a team of AI specialists who handle the boring parts (remembering, documenting, tracking) so you can focus on the interesting parts (deciding, designing, building).

If you're tired of abandoning productivity systems after two weeks, maybe it's not your fault. Maybe the tools just aren't designed for how humans actually work.

**Maybe it's time to hire an AI Squad.**

---

## Try It Yourself

Want to build your own Squad?

- **Squad CLI**: [github.com/bradygaster/squad](https://github.com/bradygaster/squad) (install with `npm install -g @bradygaster/squad`)
- **Demo Repository**: We're preparing a clean demo repo ([issue #225](https://github.com/bradygaster/squad/issues/225)) so you can try Squad without needing internal infrastructure — just clone, configure, and go.
- **GitHub Copilot**: Enable for your repository
- **Charters**: Start simple—define 3-5 specialists you need
- **GitHub Issues**: Use them as your work queue
- **Decisions**: Document the *why*, not just the *what*

Start small. One agent. One issue. One decision documented. Build from there.

The Squad will remember. You just provide context.

---

*Tamir Dresher is a software engineer who finally got organized by hiring AI specialists named after Star Trek characters. The Squad lives at [github.com/tamirdresher_microsoft/tamresearch1](https://github.com/tamirdresher_microsoft/tamresearch1).*

[IMAGE: Footer graphic showing the tamresearch1 GitHub repository with Star Trek squad members working on various issues]
