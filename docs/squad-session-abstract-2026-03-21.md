# Squad AI + The Human Extension Concept — Conference Session Materials

**Issue:** #960  
**Prepared by:** Seven (Research & Docs)  
**Date:** 2026-03-21  
**For:** Tamir Dresher (@tamirdresher)

---

## Talk Title Options

From *most provocative* to *most descriptive*:

| # | Title | Best For |
|---|-------|----------|
| 1 | **Your AI Team Is Already Working. Are You?** | Developer conferences, social posts, provocative CFPs |
| 2 | **Resistance Is Futile — How I Built an AI Engineering Team That Works While I Sleep** | KubeCon, GitHub Universe, NDC — audiences who appreciate the Star Trek energy |
| 3 | **The Human Extension: Why AI Agents Shouldn't Replace You (They Should Extend You)** | Microsoft Build, .NET Conf — enterprise/productivity angle |
| 4 | **Squad: Building an AI Team That Amplifies Your Judgment Instead of Replacing It** | More descriptive, safer for conservative CFP committees |
| 5 | **From One Developer to a Team of Eight: Multi-Agent AI Workflows in Production** | Technical depth audiences — KubeCon, dotNET Conf |

**Recommended:** Option 2 for most audiences. Option 3 when the room skews enterprise/management.

---

## Talk Abstracts

### 50-Word Abstract *(for CFP one-liners and social teasers)*

> Ralph monitors the backlog while I sleep. Picard decomposes my issues into parallel workstreams. Seven writes the docs I'd never get to. I wake up, review the PRs, make the calls, ship the thing. This is Squad — not AI replacing the developer, but *extending* what one developer can actually do.

---

### 100-Word Abstract *(for CFP short description fields)*

> What if your AI tools worked through the night while you didn't? Meet Squad — a GitHub Copilot-native multi-agent framework where each AI agent is a specialist: Ralph watches the queue, Picard decomposes the architecture, Data writes the code, Seven writes the docs. Together, they extend what a single developer can accomplish — not by replacing judgment calls, but by handling everything that doesn't require one.
>
> In this session, Tamir Dresher shows Squad running live: parallel agents, a 24/7 watch loop, and the human extension pattern — where the developer becomes the final authority in a system that never stops working on their behalf.

---

### 250-Word Abstract *(for CFP full description, program notes, website)*

> Every developer has a list. Features to ship, bugs to triage, docs to write, security findings to chase, PRs to review. The list doesn't shrink — it compounds. Traditional AI tooling helps you work faster. But faster alone doesn't close the gap between what one person can do and what a modern software project demands.
>
> Squad is a multi-agent framework built on GitHub Copilot that changes the equation entirely. Instead of one AI assistant, you get a team — each agent with a role, a domain, and a charter. Ralph runs a 5-minute watch loop 24/7, triaging issues and routing work. Picard decomposes feature requests into parallel workstreams and assigns specialists. Data writes the code. Worf reviews for security. Seven produces the documentation. None of this requires you to be awake.
>
> But here's the concept that makes Squad genuinely different from "more automation": the human extension pattern. Squad doesn't try to remove you from the loop. It routes everything that requires judgment — architecture decisions, security sign-offs, production approvals — back to you, pausing until you respond. Everything else runs without interruption. You stop being the person doing all the work. You become the person making the final calls.
>
> In this session, you'll see Squad running live: a real codebase, real parallel agents, a live demo of Ralph picking up a GitHub issue and routing it through the full agent pipeline while Tamir sleeps. You'll leave with the architecture, the mental model, and the ability to start building your own AI team that works for you — around the clock.

---

## Target Audience Map

| Conference | Focus | What to Emphasize | Suggested Title |
|---|---|---|---|
| **KubeCon** | Platform engineers, SREs, cloud-native practitioners | Squad on AKS, distributed watch loops, multi-machine coordination | Option 2 or 5 |
| **dotNET Conf** | .NET / C# developers, tooling focus | Squad's C#/.NET integration, PowerShell watchers, developer productivity | Option 3 or 4 |
| **GitHub Universe** | Developer experience, OSS, Copilot ecosystem | GitHub Copilot CLI, Squad as a Copilot extension, the PR-as-coordination pattern | Option 1 or 2 |
| **Microsoft Build** | Enterprise developers, Azure customers, Microsoft product users | Azure DevBox multi-machine, Teams notifications, human-in-the-loop design | Option 3 |
| **NDC Oslo / London** | Pragmatic developers, .NET and full-stack | The story arc (what broke, how it works now), humor, honesty | Option 2 or 1 |

**Conference-specific adaptation notes:**
- **KubeCon:** Lead with distributed systems framing — subsquads as workstreams, routing tables as network routing tables, git as coordination primitive
- **GitHub Universe:** Lead with the Copilot story — Squad as what happens when you take Copilot from one chat window to a persistent, parallel, always-on team
- **Microsoft Build:** Lead with enterprise safety — human extension = judgment stays with humans, all decisions tracked in decisions.md, full audit trail
- **NDC / .NET Conf:** Lead with the personal story — Ralph woke you up at 3am once, so you fixed the problem, and now Ralph never wakes you up at 3am

---

## Session Agenda — 45-Minute Version

```
00:00 ─ Hook / Opening Story            5 min
05:00 ─ What Is Squad?                  5 min
10:00 ─ The Human Extension Concept     5 min
15:00 ─ Live Demo                      15 min
30:00 ─ Architecture Deep Dive          5 min
35:00 ─ Key Takeaways                   5 min
40:00 ─ Q&A Setup / Call to Action      5 min
```

---

### SECTION 1: Hook / Opening Story (0:00–5:00)

**The story:**

> It was 11:30pm on a Wednesday. I had filed six GitHub issues before I went to bed — a security finding, two documentation gaps, a performance bug, a feature request, and one labeled "TODO: figure this out tomorrow." I woke up to four open pull requests, one closed issue with a detailed post-mortem, and a Teams notification from Ralph saying: *"Good morning. Here's what happened while you slept."*
>
> I hadn't touched the keyboard in 7 hours. The work had continued without me.

**Talking points:**
- Open with the concrete story — no preamble, no "Hi, I'm Tamir, I work at Microsoft" — earn that later
- The moment that makes the audience realize this isn't automation-as-usual: *you woke up to finished work*
- Then the honest caveat: "The PR for 'TODO: figure this out tomorrow'? Ralph filed a detailed analysis issue and waited. Because that one needed judgment. Mine."
- That tension — what runs without you, what waits for you — is the entire talk
- Land on the question: "What if the bottleneck in your software delivery isn't your team's capacity? What if it's the fact that your team sleeps?"

**Do:**
- Tell it like a story, not a demo preview
- Use the exact Teams notification text on screen (screenshot, not a slide)
- Pause after "I hadn't touched the keyboard in 7 hours"

**Don't:**
- Start with a Squad architecture diagram
- Say "AI is transforming software development"
- Apologize for the Star Trek theme

---

### SECTION 2: What Is Squad + The Human Extension Concept (5:00–15:00)

**Part A — What Is Squad? (5:00–10:00)**

**Talking points:**
- Squad is a GitHub Copilot CLI framework — each agent is a specialized chat session with a persistent identity, a charter, and a role in the routing table
- The crew: Ralph (watch loop), Picard (lead/orchestration), Data (code), Worf (security), Seven (docs/research), B'Elanna (infrastructure), Troi (content), Neelix (comms)
- Key differentiator: agents are *persistent* — they accumulate decisions, skills, and codebase knowledge across sessions
- The routing table isn't a suggestion list: it's deterministic, like a network routing table for work
- Show the `.squad/routing.md` table on screen — it's 10 lines, not a complex system

```markdown
## Work Type → Agent

| Work Type                              | Primary   |
|----------------------------------------|-----------|
| Architecture, distributed systems      | Picard    |
| Security, Azure, networking            | Worf      |
| C#, Go, .NET, clean code               | Data      |
| Documentation, presentations, analysis | Seven     |
| Blog writing, voice matching           | Troi      |
```

- Key point: "This isn't magic. It's a routing table. Any senior developer could have designed this. The interesting part is what happens when you actually run it."

**Part B — The Human Extension Concept (10:00–15:00)**

**Talking points:**
- This is the concept I got wrong for the first two weeks
- I thought Squad was about removing me from the loop. It's the opposite.
- The pattern: AI handles **systematic work**, humans handle **judgment calls**
- What systematic work looks like: triaging issues, writing docs, first-pass code review, security scanning, CI setup, dependency updates
- What judgment calls look like: "Should we redesign this API?" / "Is this security risk acceptable given our constraints?" / "Do we ship this today or wait?"
- The routing rules make this explicit:

```markdown
### Architecture Decisions
Route to: Human squad member
AI action: Analysis + recommendations, then PAUSE for approval

### Security Reviews
Route to: Human squad member  
AI action: Automated scans + findings, then PAUSE for sign-off
```

- The word "PAUSE" is doing enormous work in that config. Squad doesn't hallucinate your response. It stops and waits. Context preserved. No restart. You reply when you're ready.
- **The metaphor that lands:** "You become the CTO of your own AI company. You make the calls. They execute them. You review the work. They respond to your feedback. The work continues while you're in meetings, asleep, or watching Star Trek."
- Be honest: "This doesn't mean Squad never makes a bad call. It means all the bad calls are visible, in version control, with a PR you can decline."

---

### SECTION 3: Live Demo (15:00–30:00)

**Demo Goal:** Show the complete human extension loop — issue filed → Ralph picks it up → agents work in parallel → human reviews → agents respond to feedback

**Demo Setup (prepare in advance):**
- Terminal window visible showing Ralph's watch loop running
- Pre-staged GitHub issue ready to file (don't write it live)
- Parallel agent output visible — ideally two terminal panels side by side
- Teams notification preview on a second screen or window

**Demo Flow (15 minutes):**

```
15:00  File the GitHub issue (pre-written, paste and submit)
       Show issue: "Add input validation to the search endpoint, 
       including error handling and tests"
       
15:30  Switch to terminal — Ralph's watch loop picks it up
       Show: "Ralph polling... found 1 new issue... routing to Picard"
       
16:00  Picard decomposes:
         → Data: implement validation + tests
         → Worf: review for injection vectors  
         → Seven: update API docs with validation rules
       Show the routing output in terminal
       
16:30  Switch to side-by-side panels:
         Left: Data working on implementation
         Right: Worf checking for SQL injection risks
       "These are running simultaneously. Right now."
       
20:00  First PR opens — show GitHub notification
       Show the PR: Data's implementation with test coverage
       
21:00  Point out: Worf flagged one thing
       Show Worf's finding in the PR review thread
       
22:00  THE HUMAN EXTENSION MOMENT:
       "Worf found something I need to decide on. He flagged it 
       and waited. He didn't make the call. That's mine."
       Show the routing pause notification in Teams
       
23:00  Review Worf's finding on screen, leave a comment decision
       "I accepted his recommendation — here's why"
       Show Squad picking up the comment and continuing
       
25:00  Seven's documentation PR opens
       Show docs auto-updated with the validation schema
       
26:00  Wrap demo: "From issue to three parallel PRs — 
       Data, Worf, Seven — in 11 minutes. While I made 
       exactly one judgment call."
       
28:00  Show the decisions.md — the call Tamir made is now 
       captured for every future session. It compounds.
```

**Live vs. Backup:**
- **Prefer live** — the real-time nature is the point
- **Backup plan A:** Pre-recorded video of the demo that you can narrate over. If GitHub rate limits hit or the network is flaky, switch to this seamlessly: "Let me show you this from a session I ran earlier this week."
- **Backup plan B:** Static screenshots of each step, presented as a walk-through. Works fine — GitHub issue → PR → routing → Teams notification. The narrative carries it.

**What to have pre-staged:**
- Issue text pre-written and ready to paste
- Terminal with Ralph already running (started before the session)
- GitHub CLI authenticated
- Teams webhook configured and tested
- Two terminal panels arranged and visible
- Worf's security finding should be pre-staged in the codebase so it gets picked up reliably

**What to say if something goes wrong:**
> "Ralph is having a slower morning than usual. This is good — it means this is real. Let me switch to the backup demo I recorded Tuesday while he catches up."

---

### SECTION 4: Architecture Deep Dive (30:00–35:00)

**Talking points:**
- This is optional — cut it if demo runs long, expand if audience is clearly technical
- The three primitives: the charter (who the agent is), the routing table (where work goes), and decisions.md (what the team has learned)
- Git as coordination primitive: agents don't talk to each other directly — they coordinate through branches, PRs, and the decisions log. Same as a distributed team of humans.
- The watch loop as a heartbeat: Ralph runs every 5 minutes, checks the issue queue, routes work. Simple cron logic. The sophistication is in what happens *after* the route, not in the routing itself.
- Multi-machine: Squad runs on your laptop *and* your DevBox. The git repo is the shared state. You can have Ralph running on three machines and they coordinate automatically via git — no custom protocol, no leader election ceremony.
- **The distributed systems reveal:** "I built what I thought was a clever hack for cross-machine coordination. Then I read about Raft consensus and realized I'd reinvented a version of it using git. I did not feel clever. I felt like I needed to go read more papers."

**Architecture diagram (show on screen):**

```
GitHub Issues / PRs
        │
        ▼
  Ralph Watch Loop (every 5 min)
        │
        ▼
  Picard Orchestrator
  ├── routes to Data (code)
  ├── routes to Worf (security)
  ├── routes to Seven (docs)
  └── pauses and pings → Human (@tamirdresher)
                                │
                                ▼
                         Human judgment
                                │
                                ▼
                       Resume + merge
```

---

### SECTION 5: Key Takeaways (35:00–40:00)

**Five things to leave with:**

1. **The bottleneck isn't capacity — it's context switching.** You're not slow because you can't write code fast. You're slow because every interruption costs 20 minutes to recover from. Squad runs while you're interrupted.

2. **AI should extend your judgment, not replace it.** The most dangerous AI pattern is one that makes decisions you can't see and can't override. Squad's human extension pattern makes every AI decision auditable, overridable, and composable with your own judgment.

3. **Routing rules are the architecture.** The `.squad/routing.md` file is 30 lines. The decisions it encodes are worth weeks of work. Spend time on your routing rules — they're the org chart for your AI team.

4. **Knowledge compounds.** Decisions.md is a log of everything your team has learned. Every future session starts smarter than the last. This is the feature that makes Squad a productivity system you don't abandon after three days.

5. **Start with one agent.** You don't need seven agents on day one. Start with Ralph — the watch loop. Just the watch loop. Route work to yourself initially. Learn the routing patterns before you add agents. Week one: Ralph. Week two: one specialist. Week four: the team.

**The landing:**
> "I'm not a more productive developer because I work faster. I'm a more productive developer because I work on fewer things at once — the high-judgment things — while my team handles everything else. That's the human extension concept. And it's not science fiction. It's running on my laptop right now."

---

### SECTION 6: Q&A Setup / Call to Action (40:00–45:00)

**Seed questions to prime the room (have these ready or ask a planted attendee):**
- "What happens when an agent makes a bad decision?"
- "How do you handle secrets and credentials in the agent config?"
- "Can you use this with an existing team, not just a solo repo?"
- "What does it cost to run?"

**Prepared answers:**

*Bad decisions:* Every agent action goes through a PR. Bad decisions are visible and reversible. The worst outcome is a PR you don't merge. The routing rules push anything irreversible — deployments, emails, external communications — to human approval by default.

*Secrets/credentials:* Standard GitHub secrets management. Agents have only the permissions they need. Ralph doesn't have deploy access. Worf does security scanning with read-only tokens. The charter specifies permissions explicitly.

*Existing team:* This is actually where the human extension concept shines. Add your teammates as human squad members. Route their domain work through them. The AI agents handle everything that doesn't require your experts' attention, so your experts spend their time on the things only they can decide.

*Cost:* Copilot Business or Enterprise subscription. No additional infrastructure for the basic setup. If you run it on AKS (which I now do), that's standard cluster compute. The routing logic is a PowerShell script.

**Call to action:**
> "Squad is open source. Brady Gaster created it, I've been running it for four months. Links are in the session notes. The thing to try first: clone the repo, add one agent, give Ralph a watch loop, and file an issue. Watch what happens. You don't need to understand all of it to start. The understanding comes from watching it run."

---

## Slide Outline

### Slide 1 — Title Slide
**Content:** Talk title + "Tamir Dresher | @tamirdresher | Microsoft"  
**Visual:** Nothing else. Clean. Let the title breathe.  
**Note:** No company logos on first slide. This is a developer talk, not a corporate presentation.

---

### Slide 2 — The Setup (Story)
**Content:**
- "Wednesday, 11:30pm. I filed 6 GitHub issues and went to bed."
- Screenshot: the Teams notification from Ralph (real, not mocked)  

**Visual:** Single screenshot, large. No bullet points.  
**Note:** This is not a slide with text. The image IS the slide.

---

### Slide 3 — Meet the Crew
**Content:** Roster table — agent name, role, one-sentence charter

```
Ralph    │ Watch Loop         │ Monitors the queue 24/7. Never sleeps.
Picard   │ Lead               │ Decomposes tasks. Routes work. Orchestrates.
Data     │ Code Expert        │ Writes C#, Go, tests. Thorough and precise.
Worf     │ Security           │ Finds what you didn't want to find.
Seven    │ Research & Docs    │ Direct and analytical. Docs that explain WHY.
B'Elanna │ Infrastructure     │ Helm, Kubernetes, deployments.
Troi     │ Blogger            │ Writes like Tamir. Even this abstract.
```

**Visual:** Table format, monospaced font, no icons  
**Note:** Light Star Trek acknowledgment — "yes, I named them after Star Trek characters, yes intentionally, yes I know"

---

### Slide 4 — The Routing Table
**Content:** `.squad/routing.md` contents, verbatim

```
| Work Type                    | Primary   | Secondary |
|------------------------------|-----------|-----------|
| Architecture, systems design | Picard    | —         |
| Security, Azure              | Worf      | —         |
| C#, Go, .NET                 | Data      | —         |
| Docs, research, analysis     | Seven     | —         |
```

**Visual:** Code block, full-screen  
**Note:** "This is 30 lines. This is the architecture."

---

### Slide 5 — The Human Extension Pattern
**Content:** The two-column split:

| AI Handles | Human Handles |
|---|---|
| Issue triage | Architecture decisions |
| First-pass code review | Security sign-offs |
| Documentation | Production deployments |
| Test scaffolding | External communications |
| Dependency updates | Strategic direction |

**Visual:** Table — keep it clean  
**Note:** "The line between these two columns is the most important design decision in your Squad setup."

---

### Slide 6 — The Pause
**Content:** The routing config showing the PAUSE behavior

```markdown
### Architecture Decisions
Route to: Human squad member
AI action: Analysis + recommendations, then PAUSE for approval

### Security Reviews
Route to: Human squad member
AI action: Automated scans + findings, then PAUSE for sign-off
```

Plus the Teams notification screenshot showing a paused task  
**Visual:** Split: code block left, Teams screenshot right  
**Note:** "PAUSE is doing more work than any other word in this config."

---

### Slide 7 — Demo (live or pre-recorded)
**Content:** "Let's watch Ralph pick up an issue."  
No bullet points. Just the demo.  
**Note:** Keep this slide visible the entire demo. Simple text on screen.

---

### Slide 8 — The Knowledge That Compounds
**Content:** Decisions.md concept  
- Session 1: Data decides bcrypt for passwords
- Session 5: Seven references it in auth docs. Automatically.
- Session 10: Worf validates bcrypt compliance. Without prompting.

**Visual:** Simple flow diagram showing knowledge persistence across sessions  
**Note:** "This is why you don't abandon Squad after three days. It gets smarter. Your codebase-specific knowledge accumulates."

---

### Slide 9 — How to Start (Not Overwhelm)
**Content:** The week-by-week ramp:

```
Week 1:  Ralph only. Watch loop. Route to yourself.
Week 2:  Add one specialist (Data or Seven).
Week 4:  Add routing rules between agents.
Month 2: Human extension pattern. Add humans to team.md.
Month 3: Multi-machine if needed. Otherwise, you're done.
```

**Visual:** Timeline format  
**Note:** "You do not need the full crew on day one."

---

### Slide 10 — Where to Go Next
**Content:**
- GitHub: `github.com/bradygaster/squad` ← the framework
- Blog series: tamirdresher.com (link)
- Start here: `squad init` → add Ralph → file an issue → watch

**Visual:** Clean links, QR code optional  
**Note:** End on forward momentum, not a summary slide.

---

## Demo Script — Full Sequence

### Before the Session (Pre-flight checklist)

- [ ] Clone tamresearch1 repo to a machine with clean git state
- [ ] Ralph watch loop confirmed running: `npm run ralph:watch` (or equivalent)
- [ ] GitHub CLI authenticated: `gh auth status`
- [ ] Teams webhook URL confirmed working: test ping 30 min before session
- [ ] Terminal layout set: two panels side by side, readable at 1920×1080
- [ ] Pre-written issue text copied to clipboard:
  ```
  Add input validation to the search endpoint.
  Must include: required field validation, type checking, error response schema.
  Include unit tests for the validation logic.
  Label: squad:picard
  ```
- [ ] Pre-staged "Worf finding" in codebase: one obvious SQL injection vector in a helper function (a raw string interpolation in a query) so Worf's scan reliably catches it
- [ ] Backup video recorded: full demo run captured Tuesday, edited to 8 min, saved locally
- [ ] Backup screenshots: 7 screenshots covering each major step, in a folder, numbered

---

### Live Demo Script

**Step 1 — File the Issue (30 seconds)**

```
[TAMIR SAYS]
"I'm going to file a GitHub issue right now. Real one. 
This will go into the actual repo."

[ACTION]
gh issue create --title "Add input validation to search endpoint" \
  --body "[pre-written body]" \
  --label "squad:picard"

[TAMIR SAYS]
"Filed. Now we wait."
[pause — 5 seconds, let it land]
"Ralph checks the queue every 5 minutes. 
He checked 2 minutes ago. So... 3 minutes."
"Unless I already have one running that saw it."
[switch to terminal showing Ralph's watch loop output]
```

**Step 2 — Ralph Picks It Up (1 minute)**

```
[SHOW]
Ralph's output: "Found 1 new issue labeled squad:picard. Routing to Picard."

[TAMIR SAYS]
"Ralph found it. He saw the label, matched it to the routing table,
and handed it to Picard. Ralph didn't decide what to do with it.
He decided who should decide."
```

**Step 3 — Picard Decomposes (2 minutes)**

```
[SHOW]
Picard's decomposition output — route to Data, Worf, Seven

[TAMIR SAYS]
"Picard read the issue. He decomposed it into three workstreams:
Data implements the validation and writes the tests.
Worf checks for injection vectors — because validation code is exactly 
where injection vulnerabilities live.
Seven updates the API documentation.

Three independent workstreams. All starting now. In parallel."

[SHOW]
Two terminal panels side by side — Data and Worf both active
```

**Step 4 — Parallel Work (3–4 minutes)**

```
[TAMIR SAYS]
"I'm not going to narrate every line here. 
Watch the left panel — Data building the validator.
Watch the right panel — Worf running the security scan.
These are running at the same time."

[Let it run. Let the silence do the work.]

"The audience is usually quiet here. 
I think it's because the thing that should feel unremarkable — 
two agents working in parallel — 
still somehow feels like it shouldn't be possible."
```

**Step 5 — The Finding (1 minute)**

```
[WHEN Worf flags something]

[TAMIR SAYS]
"Worf found something."
[show the finding — the SQL injection vector]
"A raw string interpolation in the existing search helper. 
This would be reachable through the new validation endpoint 
if we'd shipped without catching it."

[show the Teams notification / Worf routing pause]
"Worf flagged this and stopped. He didn't make the call.
He surfaced the risk, explained it, and waited for me.
This is the human extension pattern in action.
The judgment call is mine."
```

**Step 6 — The Human Call (1 minute)**

```
[TAMIR SAYS]
"I'm going to look at this. [pause, read it]
He's right. And the fix is straightforward — parameterized query.
I'm going to comment on the issue: 
'Worf finding accepted — fix the interpolation before merging validation PR.'
"

[ACTION: leave comment on GitHub issue]

[TAMIR SAYS]
"Ralph will pick that up in the next loop. 
Data will see the comment, update the PR.
I made exactly one judgment call. Everything else was handled."
```

**Step 7 — Wrap (30 seconds)**

```
[SHOW]
Three PRs: Data's validation + test PR, Worf's security finding, Seven's docs update

[TAMIR SAYS]
"From one filed issue to three PRs — 
validation implementation, security finding, documentation update — 
in under 12 minutes. 
One judgment call from me.
The rest? Extended by my team."
```

---

### If Demo Goes Wrong

**Scenario: GitHub rate limit hit**
> "GitHub and I are having a disagreement. This happens — I'm running a real system with real API calls, not a mocked demo. Let me show you the run I recorded on Tuesday."
> [Switch to backup video — start narrating over it]

**Scenario: Ralph doesn't pick up the issue in time**
> "Ralph's on a 5-minute cycle — we caught him at the end of one. While he catches up, let me show you what the routing config actually looks like — because the routing table is where this all lives."
> [Show routing.md, buy 90 seconds, then switch to backup if needed]

**Scenario: Agent output is slow**
> "This is real. Real agents, real API calls, real latency. The output you'd see on your machine doing actual work. I could mock this, but then you'd think it was faster than it is — and I'd rather you be surprised it works at all than disappointed it doesn't work the way the demo suggested."

---

## Appendix: PR & Issue Details

**Branch:** `squad/960-session-abstract-TAMIRDRESHER`  
**Closes:** #960  
**Files created:** `docs/squad-session-abstract-2026-03-21.md`

---

*Created by Seven — Research & Docs | Squad AI*  
*Source: issue #960, blog posts (Parts 1–3), voice style guide, Troi charter*
