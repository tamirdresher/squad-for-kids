# Skillshare Version — Build Your AI Engineering Squad

## Course Metadata

- **Title:** Build an AI Engineering Squad: Multi-Agent Systems for Developers
- **Class Type:** Project-Based Class
- **Level:** Intermediate
- **Duration:** ~90 minutes (Skillshare sweet spot: 60-120 min)
- **Instructor:** Tamir Dresher
- **Category:** Technology > Software Engineering

---

## Skillshare Platform Strategy

### Key Differences from Udemy

| Aspect | Udemy | Skillshare |
|--------|-------|-----------|
| Revenue Model | Per-sale (list price) | Per-minute watched (royalty pool) |
| Ideal Length | 8-20 hours | 30-120 minutes |
| Format | Comprehensive, lecture-heavy | Project-based, hands-on |
| Audience | Career advancers, certification seekers | Creative/curious learners, hobbyists |
| Pricing | $12.99-$199.99 per course | $13.99/month subscription |
| Instructor Revenue | 37-97% per sale | ~$0.05-$0.10 per minute watched |
| Discovery | Search + promotions | Staff picks + algorithm |

### Skillshare Revenue Math
- Average payment: ~$0.05-$0.10 per minute of premium member watch time
- 90-minute class × 1,000 students completing = ~$4,500-$9,000/month
- Key metric: **minutes watched**, not enrollments
- Referral bonus: $10 per new premium member via your referral link

---

## Course Outline (Project-Based — 90 Minutes)

### Class Project: Build a 3-Agent AI Squad

**Deliverable:** Students build and deploy a working 3-agent system:
1. **Code Review Agent** — Reviews pull requests and suggests improvements
2. **Issue Triage Agent** — Classifies and prioritizes GitHub issues
3. **Orchestrator Agent** — Routes tasks between the two specialists

Students share their GitHub repo link as their class project.

---

### Lesson 1: Welcome & What We're Building (5 min)
- **Type:** 🎥 Video (talking head + slides)
- Show the finished project in action
- Explain the 3-agent architecture
- Set up expectations: what you'll have by the end

### Lesson 2: Why Multi-Agent Beats Single-Agent (7 min)
- **Type:** 🎥 Video (slides + diagrams)
- The limitations of one-agent-does-everything
- Specialization principle: each agent excels at one thing
- Architecture diagram of our 3-agent squad

### Lesson 3: Environment Setup (8 min)
- **Type:** 🛠️ Hands-on screencast
- Install Node.js, clone starter repo
- Configure API keys (Claude/OpenAI)
- Verify everything works with a hello-world agent

### Lesson 4: Build Agent #1 — The Code Review Agent (15 min)
- **Type:** 🛠️ Hands-on screencast
- Define the agent's system prompt and persona
- Add tools: read files, analyze code, post comments
- Test with a sample pull request
- **Pause point:** Try reviewing your own code with the agent

### Lesson 5: Build Agent #2 — The Issue Triage Agent (12 min)
- **Type:** 🛠️ Hands-on screencast
- Define the triage agent's classification rules
- Add tools: read issues, apply labels, set priority
- Test with sample GitHub issues
- **Pause point:** Customize the triage categories for your project

### Lesson 6: What is MCP? The Glue Between Agents and Tools (8 min)
- **Type:** 🎥 Video (slides + demo)
- MCP explained in 3 minutes
- How MCP servers expose tools to agents
- Quick demo: connecting an agent to an MCP server

### Lesson 7: Build the Orchestrator — Making Agents Collaborate (15 min)
- **Type:** 🛠️ Hands-on screencast
- Define the orchestrator's routing logic
- Implement task classification: "Is this a code review or issue triage?"
- Wire up delegation: orchestrator → specialist agent
- Test the full pipeline end-to-end

### Lesson 8: Deploy with GitHub Actions (10 min)
- **Type:** 🛠️ Hands-on screencast
- Create a GitHub Actions workflow
- Trigger agents on PR creation and issue filing
- Push to GitHub and watch it run

### Lesson 9: Make It Your Own — Customization Ideas (5 min)
- **Type:** 🎥 Video (talking head)
- Ideas for extending: add a security agent, docs agent, comms agent
- How to create additional MCP servers
- Scaling patterns for larger squads

### Lesson 10: Share Your Project & Next Steps (5 min)
- **Type:** 🎥 Video (talking head)
- How to submit your class project
- Link to the full Udemy course for deeper learning
- Resources and community links

---

## Lesson Summary

| Lesson | Title | Duration | Type |
|--------|-------|----------|------|
| 1 | Welcome & What We're Building | 5 min | 🎥 Video |
| 2 | Why Multi-Agent Beats Single-Agent | 7 min | 🎥 Video |
| 3 | Environment Setup | 8 min | 🛠️ Hands-on |
| 4 | Build Agent #1 — Code Review Agent | 15 min | 🛠️ Hands-on |
| 5 | Build Agent #2 — Issue Triage Agent | 12 min | 🛠️ Hands-on |
| 6 | What is MCP? The Glue Between Agents and Tools | 8 min | 🎥 Video |
| 7 | Build the Orchestrator | 15 min | 🛠️ Hands-on |
| 8 | Deploy with GitHub Actions | 10 min | 🛠️ Hands-on |
| 9 | Make It Your Own — Customization Ideas | 5 min | 🎥 Video |
| 10 | Share Your Project & Next Steps | 5 min | 🎥 Video |
| **Total** | | **90 min** | |

---

## Class Resources (Downloadable)

1. **Starter repository** (GitHub template) — pre-configured project structure
2. **Architecture diagram** (PDF) — the 3-agent system overview
3. **Prompt templates** — system prompts for all 3 agents
4. **GitHub Actions workflow** (YAML) — ready to copy-paste
5. **Cheat sheet** — MCP server quick reference

---

## Cross-Promotion Strategy

### Skillshare → Udemy Funnel

The Skillshare class serves as a **top-of-funnel** lead generator for the full Udemy course:

```
Skillshare (90 min, project-based, free with subscription)
    → Student completes class project
    → Lesson 10: "Want to go deeper? The full course covers 10x more"
    → Link to Udemy course with instructor coupon ($59.99)
    → Estimated conversion: 5-10% of Skillshare completers
```

### Skillshare Class Project → Kit Email Capture

Include a link in class resources:
- "Download the extended prompt library (50+ agent prompts)" → Kit landing page
- Captures email for nurture sequence
- Estimated email capture: 3-5% of enrollees

---

## Skillshare Revenue Projection

| Scenario | Monthly Minutes Watched | Est. Revenue/Month | Annual Revenue |
|----------|------------------------|-------------------|----------------|
| Conservative | 5,000 min | $350 | $4,200 |
| Moderate | 15,000 min | $1,050 | $12,600 |
| Optimistic | 40,000 min | $2,800 | $33,600 |

*Plus referral bonuses: ~$10/new premium member, estimated 5-20/month*

### Combined Platform Revenue (Udemy + Skillshare)

| Scenario | Udemy Annual | Skillshare Annual | Combined Annual |
|----------|-------------|-------------------|-----------------|
| Conservative | $12,384 | $4,200 | $16,584 |
| Moderate | $34,320 | $12,600 | $46,920 |
| Optimistic | $90,456 | $33,600 | $124,056 |

---

## Production Notes for Skillshare

### Recording Style
- **Screencast-first** (Skillshare students prefer watching someone build, not slides)
- Minimal slides (only for concepts in Lessons 1, 2, 6)
- Fast-paced but clear (no padding — Skillshare penalizes long, slow classes)
- Picture-in-picture webcam overlay during screencasts

### Optimizing for Minutes Watched
- Hook in first 30 seconds (show the finished project immediately)
- Each lesson ends with a mini-cliffhanger or "next, we'll build..."
- Class project milestones keep students engaged through the full 90 minutes
- Avoid front-loading theory — interleave with hands-on building

### Thumbnail & Title Best Practices
- Title: Action-oriented, includes "Build" and "AI"
- Thumbnail: Dark background, code on screen, bright accent color, face optional
- Tags: AI, coding, software engineering, automation, multi-agent, GitHub
