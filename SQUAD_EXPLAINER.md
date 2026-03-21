# What Is Squad? (And Why Should I Care?)

> *"Would I rather be feared or loved? Easy. Both. I want people to be afraid of how much they love Squad."*
> — Michael Scott (probably, if he used AI)

---

## The 30-Second Version

**Squad** is like having a team of specialized AI assistants who each own a specific job — and actually know what they're doing.

You don't talk to one generic AI and hope for the best. Instead, you talk to *the right person for the job*: the engineer, the researcher, the writer, the calendar manager, the security reviewer. They coordinate with each other so you don't have to.

Think of it like a real team:
- You open a GitHub issue
- Squad figures out who should handle it
- That agent does the work, creates a branch, opens a PR, and moves the ticket
- You review, approve, and ship

That's it.

---

## Your Squad (Star Trek Edition 🖖)

Each agent has a name, a specialty, and a personality. Here's who they are and what they actually do:

| Agent | Role | What They Do |
|-------|------|-------------|
| **Picard** | Lead / Architect | Makes decisions, owns architecture, reviews designs — the one who says "make it so" |
| **B'Elanna** | Infrastructure Expert | Kubernetes, Helm, CI/CD, deployments — if it runs in the cloud, she owns it |
| **Worf** | Security & Cloud | Azure, networking, security reviews — paranoid by design, assumes everything is hostile |
| **Data** | Code Expert | C#, Go, .NET — clean code, reliable, no drama, just results |
| **Seven** | Research & Docs | Turns complexity into clear documentation — if the docs are wrong, the product is wrong |
| **Troi** | Blogger & Voice Writer | Writes blog posts and content that sound like *you*, not a robot |
| **Kes** | Comms & Scheduling | Calendar, emails, meetings — your personal assistant for people logistics |
| **Neelix** | News Reporter | Scans tech news, sends briefings, keeps you informed without the noise |
| **Q** | Devil's Advocate | Challenges assumptions, fact-checks claims — the one who asks "but what if you're wrong?" |
| **Ralph** | Work Monitor | Watches the issue board, nudges stalled items, keeps the queue honest |
| **Guinan** | Content Strategist | Decides *what* to publish, *when*, and *for whom* — the audience whisperer |
| **Podcaster** | Audio Content | Converts written content into listenable audio summaries and podcast episodes |
| **Paris** | Video & Audio Producer | Handles video and audio production — every frame matters |
| **Geordi** | Growth & SEO | Makes content discoverable, grows audiences, finds patterns in data |
| **Crusher** | Content Safety | Reviews content before publishing — the last line of defense |
| **Scribe** | Session Logger | Silently records decisions, keeps team memory intact across sessions |

---

## The Most Common Confusion Points

### "Wait, Ralph vs Picard — what's the difference?"

- **Ralph** watches the *board*. He monitors open issues, moves stale tickets, sends status nudges. He's your queue janitor and watchdog.
- **Picard** makes *decisions*. Architecture choices, design reviews, "should we build X or Y?" — he's the strategic lead.

Simple rule: **Ralph keeps things moving. Picard decides what moves.**

### "When do I use Seven vs Troi?"

- **Seven** writes *technical* content: docs, READMEs, architecture explanations, how-to guides.
- **Troi** writes *personal* content: blog posts, LinkedIn updates, stories in *your* voice.

Simple rule: **Seven writes for engineers. Troi writes for the world.**

### "What's Q actually for?"

Q challenges you before you ship something you'll regret. Got a big architectural decision? A claim in a blog post? A design you think is clever? Q will tell you why you might be wrong. That's the job.

### "Do Worf and B'Elanna overlap?"

A bit — they're both infrastructure-adjacent. The rough split:
- **B'Elanna** handles the *platform*: clusters, deployments, Helm charts, pipelines.
- **Worf** handles *security* and *cloud access*: Azure policies, secrets, networking, threat modeling.

### "What is Scribe and why do I never talk to them?"

Scribe runs silently in the background, recording decisions and keeping the team's shared memory up to date. You don't talk to Scribe directly — they talk to you via the session log. Think of them as the court reporter who keeps receipts.

---

## Quick Start: 3 Things You Can Do RIGHT NOW

### 1. 🎫 Drop a GitHub issue — Squad handles it

Open an issue like:
```
Summarize the performance problems in the last sprint
```

Label it `squad:seven` (or just `squad`) and Ralph will route it. Seven will research, write a summary, and post it back.

### 2. 📅 Ask Kes to manage your calendar

Say: *"Kes, schedule a 30-minute sync with Brady next week, avoid Mondays"*

Kes looks at your calendar, finds a slot, creates the invite, and sends it. Done.

### 3. 🔍 Ask Q to stress-test a decision

Say: *"Q, challenge this: we should rewrite the auth service in Go"*

Q will give you the top 3 reasons that might be a mistake, the assumptions you haven't validated, and what you'd need to prove first.

---

## How Issues Actually Flow

```
You open a GitHub issue
        ↓
Squad (Coordinator) reads it
        ↓
Routes to the right agent based on labels or content
        ↓
Agent does the work (code, docs, research, etc.)
        ↓
Creates branch + PR (if code), or posts results as a comment
        ↓
Ralph moves the ticket to "Review"
        ↓
You review → approve → merge
```

**Labels that help Squad route faster:**
- `squad:picard` → Architecture / decisions
- `squad:seven` → Docs / research
- `squad:data` → Code changes
- `squad:belanna` → Infrastructure
- `squad:troi` → Blog / content writing
- `squad:kes` → Calendar / emails / scheduling
- Just `squad` → Let the coordinator decide

---

## FAQ

**Q: Do I talk to Squad like it's a person?**
Yes, absolutely. Natural language works. "Hey Seven, can you document the auth flow?" is totally valid. You don't need to format commands.

**Q: Do I need to know which agent to use?**
No. Just label the issue `squad` and the coordinator will figure it out. But if you *do* know (e.g., it's clearly a docs task), adding `squad:seven` will get you there faster.

**Q: Can agents talk to each other?**
Yes. If Picard makes an architecture decision, he'll write it to the shared decisions log and Scribe records it. Other agents read that log before starting work.

**Q: What if an agent messes up?**
Every agent creates a branch and a PR — nothing goes directly to `main`. You review before anything merges. Think of each agent as a junior team member who does great work but you still sign off on it.

**Q: Can I add my own agents?**
Yes — that's what `.squad/agents/` is for. Each agent is just a markdown file with a charter. The coordinator reads it to know who to route work to.

**Q: Is this just ChatGPT with extra steps?**
No. Generic AI gives you generic answers. Squad gives you *specialized* agents with defined ownership, persistent memory (via Scribe), and actual workflow integration (GitHub issues → PRs → merged code). The difference is accountability and routing.

**Q: What does "upstream" mean in Squad context?**
Squad has an upstream framework (`bradygaster/squad`) — it's the open-source base. Your `.squad/` folder is your team's customization layer on top of it. You can pull updates from upstream or contribute patterns back.

---

## The One-Sentence Summary

> **Squad is a team of AI specialists who each own a job, coordinate via GitHub issues, and produce real artifacts (code, docs, PRs, calendar invites) — not just advice.**

Welcome to the team. 🖖

---

*Last updated: 2026-03-20 | Maintained by: Seven (Research & Docs)*
