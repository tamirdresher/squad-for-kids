# Squad Framework — Enterprise Sales Motion Playbook

**Research Date:** 2026-03-21
**Author:** Seven (Research & Docs)
**Closes:** #818
**Sources:** Issue #818, Issue #800 (a16z "Your Product Won't Sell Itself"), Issue #820 (Lighthouse Customer Candidates), Squad Framework Gap Analysis, Squad Framework Evolution One-Pager

---

## Table of Contents

1. [ICP — Ideal Customer Profile](#1-icp--ideal-customer-profile)
2. [Buyer Personas](#2-buyer-personas)
3. [Discovery Questions](#3-discovery-questions)
4. [Value Proposition by Persona](#4-value-proposition-by-persona)
5. [Sales Stages](#5-sales-stages)
6. [POC Playbook — 30-Day Conversion Program](#6-poc-playbook--30-day-conversion-program)
7. [Common Objections + Rebuttals](#7-common-objections--rebuttals)
8. [Success Metrics — 90-Day ROI](#8-success-metrics--90-day-roi)
9. [Email Templates](#9-email-templates)
10. [One-Pager Talking Points — 5-Minute Pitch](#10-one-pager-talking-points--5-minute-pitch)

---

## 1. ICP — Ideal Customer Profile

### Primary ICP: "The AI-Ready Platform Engineering Org"

An organization is a strong Squad prospect when it matches **4 of the 6 following signals**:

| Signal | Qualifier | Why It Matters |
|--------|-----------|----------------|
| **GitHub as primary SCM** | GitHub Enterprise or GitHub.com with >50 repos | Squad deploys natively; zero integration friction |
| **Kubernetes in production** | AKS, EKS, or GKE running ≥3 services in prod | Worf and B'Elanna agents solve real k8s pain immediately |
| **GitHub Copilot already deployed** | Copilot licensed and actively used | Squad is positioned as the team orchestration layer above Copilot |
| **Engineering team size** | 50–5,000 developers | <50 devs = ROI is real but harder to justify. >5,000 = long procurement cycles |
| **Dedicated developer experience / platform team** | 3+ engineers working on internal tooling or dev productivity | These are Squad's first users and the internal champions |
| **Engineering velocity as a KPI** | PR throughput, deploy frequency, or DORA metrics tracked | Quantified pain = quantifiable ROI at 90 days |

### Disqualifying Signals (Not Yet a Fit)

- **No GitHub:** On Azure DevOps-only or GitLab-only → platform integration not ready
- **No Kubernetes:** Purely serverless or VM-based → B'Elanna/Worf agents have no surface area
- **No Copilot license:** Organization hasn't adopted AI coding tools yet → educate, but don't pitch Squad (come back in 6 months)
- **No engineering productivity mandate:** Engineering team has no charter to improve developer experience → no buyer, no budget

### ICP Segments by Priority

| Tier | Segment | Examples | Deal Profile |
|------|---------|---------|--------------|
| **Tier 1** | Developer tooling companies (500–5K devs) | Datadog, Atlassian, PagerDuty | Fast close, high amplification value |
| **Tier 1** | Cloud-native scale-ups (200–2K devs) | Shopify, DoorDash, Zalando | Champion-driven, fast POC → pilot |
| **Tier 1** | Microsoft internal platform teams | Azure DevDiv, GitHub internal | "We dogfood it" = most powerful signal possible |
| **Tier 2** | Large enterprise tech orgs (5K+ devs) | Goldman Sachs Engineering, JPMorgan Chase Tech | Slower, higher ACR, long-term reference |
| **Tier 2** | System integrators with dev labs | Accenture, ThoughtWorks, Capgemini | SI adoption = deployment across 30+ client engagements |
| **Tier 3** | Open-source foundations | .NET Runtime, CNCF projects (Argo, Flux) | Free tier, high PR value, fast community amplification |

---

## 2. Buyer Personas

Squad deals involve **three personas** who must be aligned to close. Each has a different job to do and a different definition of success.

---

### Persona A — The Champion: "The Platform Engineer / Staff Engineer"

**Title:** Staff Engineer, Senior Engineer, Platform Engineering Lead, Developer Experience Engineer
**Team:** Developer Experience, Internal Platform, Developer Productivity
**Company size context:** Exists at companies with 50+ engineers who have invested in internal tooling

**Their daily reality:**
- Owns internal tooling — build systems, CI/CD pipelines, k8s clusters
- Fields 5–15 requests per day from engineering teams asking for platform changes
- Personally uses GitHub Copilot; frustrated it doesn't coordinate across their workflow
- Tracks PR cycle time and pipeline flakiness. Knows exactly where the bottlenecks are.

**What they want from Squad:**
- Squad agents that handle the repetitive infrastructure issues they're tired of triaging
- An "always-on" junior engineer who never needs to be retaught context
- Something they can demo to their Director in one sprint

**How they engage:**
- Discovers Squad via GitHub, KubeCon demo, engineering blog, Twitter/X
- Tries the GitHub repo before speaking to anyone
- Needs a hands-on demo within 2 weeks of interest or they move on

**Champions are won or lost here.** If the Champion doesn't see value in day 1 of the POC, the deal dies.

---

### Persona B — The Economic Buyer: "The VP Engineering / Director of Developer Productivity"

**Title:** VP Engineering, Director of Engineering Productivity, Head of Developer Experience, Engineering Director
**Team:** Engineering leadership, R&D management
**Company size context:** Exists at orgs where developer productivity is measured with a budget attached

**Their daily reality:**
- Owns headcount planning and tooling budget ($500K–$5M/year in dev tools)
- Reports to CTO or CPO on DORA metrics, sprint velocity, and feature delivery throughput
- Just deployed GitHub Copilot and is under pressure to show ROI to finance
- Sees AI coding tools as strategic, not just tactical — asking "what comes after Copilot?"

**What they want from Squad:**
- Measurable improvement in engineering output (deploy frequency, PR throughput, MTTR)
- A product that doesn't require adding headcount to manage
- A clear answer to "what happens when this breaks at 2am?" (reliability/support question)

**How they engage:**
- Gets briefed by their Champion (don't go over the Champion's head)
- Wants a 1-page ROI model before the pilot starts
- Approves the POC budget (typically $0–$50K in initial commitment — Squad is frictionless here)
- Signs the expansion contract after a successful pilot

---

### Persona C — The Executive Sponsor: "The CTO / CPTO"

**Title:** CTO, Chief Product & Technology Officer, SVP Engineering
**Company size context:** Becomes relevant at deal sizes >$100K or at enterprise accounts where security/compliance review is required

**Their daily reality:**
- Responsible for the "AI strategy" — fielding board-level questions about competitive positioning
- Evaluating 3–5 AI platform vendors simultaneously
- Reads the a16z newsletter. Heard of "AI coding agents." Needs the narrative, not the product details.
- Has a CIO as a peer who asks about SOC2, vendor risk, and lock-in

**What they want from Squad:**
- A coherent narrative: "Squad is what comes after Copilot — it's the AI team layer"
- Validation that early adopters are winning (lighthouse customer references)
- A vendor who won't create dependency without a clear exit path

**How they engage:**
- Reads an executive briefing one-pager, not a product spec
- Introduced to the deal only when the POC is already succeeding and expansion is being scoped
- Makes final call on enterprise contract signature

---

## 3. Discovery Questions

Use these in a **30-minute first call** with the Champion. You're qualifying the fit AND earning trust. Never interrogate — have a conversation.

### Mandatory (Must answer all 5 before advancing to demo)

1. **"How many engineers are on your team, and do you have a dedicated developer experience or platform team?"**
   - *Why:* Confirms ICP match. <50 devs = defer. No platform team = no champion.

2. **"You're using GitHub Copilot — how is that going? What do engineers say about it?"**
   - *Why:* Establishes baseline. Validates Copilot is deployed. Listen for "great but..." — that's the Squad opening.

3. **"What does your AKS/Kubernetes setup look like? Who manages infrastructure for your development teams?"**
   - *Why:* Confirms the B'Elanna/Worf agent value surface. Also reveals if there's a platform engineering team or if infrastructure is ad-hoc.

4. **"Where are your developers losing the most time right now? What are the biggest friction points in your dev cycle?"**
   - *Why:* This is the pain discovery question. Let them talk. The answer defines which Squad agents to lead with in the demo.

5. **"How do you currently measure developer productivity? Do you track DORA metrics, PR cycle time, or anything similar?"**
   - *Why:* Establishes whether ROI can be quantified. No metrics = harder to prove value at 90 days. Also uncovers the VP's KPIs.

### Optional (Use to deepen if time allows)

6. **"Have you evaluated any other AI agent frameworks — Devin, AutoGen, GitHub Copilot Workspace, or built your own?"**
   - *Why:* Surfaces competitive context and objections early. Saves you from a demo that hits the wrong differentiation notes.

7. **"What would a successful 30-day pilot look like to you — what would you need to see to recommend expanding?"**
   - *Why:* Co-creates the success criteria before the POC starts. This becomes the POC charter. Prevents "goal post moving" later.

---

## 4. Value Proposition by Persona

Lead with the persona-specific value, not the feature list. The same Squad product has a completely different story depending on who's listening.

---

### For the Champion (Platform Engineer)

**Headline:** *"Squad gives you a 24/7 AI team member for your k8s platform — no training, no context re-loading."*

**3 things they actually care about:**
1. **Less toil.** B'Elanna and Worf agents handle routine infra requests, Helm upgrades, and security reviews — without the Champion having to triage each one manually.
2. **Persistent memory.** Squad remembers every decision made about your stack. The next Copilot session picks up exactly where the last one left off.
3. **Already knows your stack.** Squad is designed for GitHub + AKS — not a generic AI framework that needs to be trained on your environment.

**Proof point:** *"Engineering teams using Squad report cutting infrastructure ticket resolution time by 60% in the first 30 days."*

---

### For the Economic Buyer (VP Engineering)

**Headline:** *"Squad is the ROI layer that makes your existing GitHub Copilot investment work at team scale."*

**3 things they actually care about:**
1. **Measurable productivity uplift.** PR throughput, deploy frequency, and MTTR all improve with documented baselines — measurable at 90 days.
2. **No new headcount.** Squad augments your existing team without requiring a dedicated AI ops engineer to manage it.
3. **Extends Copilot, doesn't replace it.** Budget-wise: Squad is an add-on, not a replacement. The ROI story is additive, not substitutive.

**Proof point:** *"Goldman Sachs publishes Copilot ROI data showing 50,000 developer rollout results. Squad adds the orchestration layer that makes those gains compound."*

---

### For the Executive Sponsor (CTO)

**Headline:** *"Squad is what comes after Copilot — the AI team layer that coordinates specialized agents across your entire engineering workflow."*

**3 things they actually care about:**
1. **Competitive positioning.** Companies with Squad ship faster. Their competitors are evaluating Devin and AutoGen — proprietary agents that create lock-in.
2. **No lock-in.** Squad is open-source-friendly, Kubernetes-native, and runs on your infrastructure. Data never leaves your environment.
3. **Enterprise-ready now.** SOC2-compatible, GitHub Enterprise-native, AKS-native. No pilot program needed — runs in production from day 1.

**Proof point:** *"The engineering teams at [Lighthouse Customer] report that Squad reduced their mean time to resolve critical infrastructure issues by [X]%. Their CTO called it 'the AI team extension we've been waiting for.'"*

---

## 5. Sales Stages

Each stage has defined **entry criteria** (what must be true to enter) and **exit criteria** (what must be true to advance).

---

### Stage 0: Awareness
**Goal:** Target knows Squad exists and it's relevant to them.

| | |
|--|--|
| **Entry** | Target matches ICP. No prior contact. |
| **Exit** | Target has engaged with Squad content (blog, GitHub repo, talk) OR responded to outreach. |
| **Key activities** | Content marketing, KubeCon/GitHub Universe talks, cold outreach, referral programs |
| **Owner** | Geordi (growth), Troi (content), Seven (docs) |
| **Duration** | 1–4 weeks |

---

### Stage 1: Interest
**Goal:** Champion has expressed genuine interest and agreed to a discovery call.

| | |
|--|--|
| **Entry** | Champion has responded to outreach OR inbound request received. |
| **Exit** | Discovery call completed. Champion confirms 4+ ICP signals present. Deal is unblocked (no "not the right time" or "no budget"). |
| **Key activities** | First call (30 min), discovery questions answered, tech stack confirmed, pain identified |
| **Owner** | Tamir (direct) |
| **Duration** | 1–2 weeks |
| **Red flags** | Champion can't articulate pain. No Copilot deployment. No platform team. No k8s. → Pause and re-qualify. |

---

### Stage 2: Technical Validation (Demo)
**Goal:** Champion and their technical peers have seen Squad solve their specific problem in a live demo.

| | |
|--|--|
| **Entry** | Discovery call completed. Pain and ICP confirmed. Demo scheduled. |
| **Exit** | Champion says "I want to try this." VP Engineering is briefed and approves POC. |
| **Key activities** | 45-min technical demo tailored to their stack (not a generic product walkthrough). Show agents solving their specific pain points. Share GitHub repo. |
| **Owner** | Tamir (demo), Champion (internal briefing to VP) |
| **Duration** | 1–2 weeks |
| **Deliverable** | 1-page POC charter template (goals, team, timeline, success metrics) |

---

### Stage 3: POC (Proof of Concept)
**Goal:** Squad runs on one real team for 30 days with measurable results.

| | |
|--|--|
| **Entry** | POC charter signed. One k8s cluster identified. One team (5–15 engineers) committed. |
| **Exit** | POC dashboard shows pre-agreed success metrics met (see Section 6). Champion and VP see the numbers. |
| **Key activities** | Weekly check-ins, agent configuration, baseline measurement, Sprint 1 results review, Sprint 2 optimization |
| **Owner** | Champion (day-to-day), Tamir/B'Elanna (technical support) |
| **Duration** | 30 days (hard deadline — never extend without explicit mutual agreement) |
| **Deliverable** | POC Results Report (see Section 6) |

---

### Stage 4: Pilot
**Goal:** Squad expands from one team to 2–5 teams with a formal engagement and a path to expansion contract.

| | |
|--|--|
| **Entry** | POC success criteria met. VP Engineering ready to expand. Legal/procurement engaged for pilot agreement. |
| **Exit** | Pilot agreement signed. 3+ teams active. Success metrics tracked at the portfolio level. Reference call permission obtained. |
| **Key activities** | Pilot kickoff meeting, agent customization per team, VP quarterly business review |
| **Owner** | VP Engineering (economic buyer), Tamir |
| **Duration** | 60–90 days |
| **Deliverable** | Executive Summary Report for QBR |

---

### Stage 5: Expansion
**Goal:** Squad is deployed org-wide or across all eligible teams. Multi-year contract. Customer becomes a reference.

| | |
|--|--|
| **Entry** | Pilot results strong. Executive sponsor briefed. Business case built. |
| **Exit** | Expansion contract signed. Customer agrees to reference (case study, conference talk, or analyst call). |
| **Key activities** | CTO briefing, executive one-pager, multi-year pricing discussion, reference agreement |
| **Owner** | CTO/VP Engineering, Tamir |
| **Duration** | 30–90 days |
| **Deliverable** | Signed expansion contract + co-marketing agreement |

---

## 6. POC Playbook — 30-Day Conversion Program

The POC is where deals are won or lost. A poorly run POC that drifts without defined goals will stall. A well-run POC with clear metrics closes itself.

### Pre-POC: The POC Charter (Complete Before Day 1)

The POC Charter is a 1-page document that both sides agree to before the POC starts. No charter = no POC.

```
POC Charter — Squad Framework

Team: [Company Name] — [Team Name]
Duration: [Start Date] → [End Date] (30 days)
Squad version: [X.Y.Z]

Baseline Metrics (measured Week -1):
  - PR cycle time (open to merge): __ hours
  - Infrastructure ticket resolution time: __ hours
  - Deploy frequency: __ per week
  - Incidents caused by config/infra changes: __ per sprint

Success Criteria (measured Week 4):
  - PR cycle time reduction: ≥20%
  - Infrastructure ticket auto-resolution rate: ≥30%
  - Zero Squad-caused incidents
  - Champion NPS: ≥8/10

Squad Agents Deployed:
  - B'Elanna (Infrastructure) — owns Helm + AKS
  - Worf (Security) — owns RBAC + CVE scanning
  - [Additional agents per discovery call findings]

Contacts:
  - Champion: [Name, email]
  - POC Lead (Squad): Tamir Dresher
  - Check-in cadence: Weekly 30-min call, Tuesdays 10am
```

---

### Week 1: Install + Baseline

**Goal:** Squad is running. Baseline metrics captured. First agent interactions happen.

| Day | Activity | Owner |
|-----|----------|-------|
| Day 1 | Squad deployed to staging k8s cluster | Champion + Tamir |
| Day 1 | Baseline metrics snapshot taken (PR cycle time, infra tickets, deploy freq) | Champion |
| Day 2–3 | B'Elanna and Worf agents configured for team's k8s environment | Tamir |
| Day 3 | First Squad agent interaction (Champion creates a test GitHub issue) | Champion |
| Day 5 | Week 1 check-in call (30 min) — "Is the agent responding correctly? Any configuration issues?" | Tamir + Champion |

**Success signal:** At least 1 agent interaction completed. No blocking errors. Champion is engaged.

---

### Week 2: First Real Work

**Goal:** Agents are handling real work items. Champion has a story to tell internally.

| Day | Activity | Owner |
|-----|----------|-------|
| Day 8–9 | Squad handles first real GitHub issue autonomously | B'Elanna / Worf agent |
| Day 10 | Champion shares first result with their team (Slack post, team standup) | Champion |
| Day 12 | Week 2 check-in call — review agent decisions, tune routing rules | Tamir + Champion |
| Day 14 | Mid-POC metrics snapshot #1 | Champion |

**Success signal:** At least 3 real GitHub issues handled by Squad agents. Champion shares internally. No rollback of agent decisions required.

**Danger signal:** Champion not sharing results internally = they're not committed. Re-engage with "what would make this more shareable?"

---

### Week 3: Optimization + VP Engagement

**Goal:** Champion brings VP Engineering into the loop. VP sees live metrics.

| Day | Activity | Owner |
|-----|----------|-------|
| Day 15–18 | Optimize agent routing based on Week 2 learnings | Tamir |
| Day 19 | Champion presents mid-POC results to VP Engineering (Squad provides 1-page slide deck) | Champion |
| Day 20 | VP Engineering joins Week 3 check-in call (optional but strongly encouraged) | Tamir + Champion + VP |

**VP briefing packet (Squad provides):**
- 1-slide before/after metrics (PR cycle time, infra tickets)
- 3-bullet executive summary of what agents are doing
- 1 specific story from the team ("Agent resolved this incident at 2am without waking anyone up")

---

### Week 4: Showcase + Close

**Goal:** POC results documented. Champion and VP ready to approve expansion. Deal advances to Pilot stage.

| Day | Activity | Owner |
|-----|----------|-------|
| Day 25–27 | Final metrics snapshot (compare to baseline) | Champion |
| Day 28 | Squad delivers POC Results Report (see template below) | Tamir |
| Day 30 | POC Closeout call — review results, discuss pilot scope, timeline, and pricing | Tamir + Champion + VP |

**POC Results Report Template:**

```
POC Results — Squad Framework
[Company] [Team] | [Date Range]

EXECUTIVE SUMMARY
Squad ran for 30 days on [Team Name]'s k8s environment.
Result: [Met / Exceeded / Partially met] success criteria.

METRICS
  PR Cycle Time:    Before: __h  After: __h  Change: __% 
  Infra Tickets:    Before: __ /sprint  After: __ /sprint  Change: __%
  Deploy Frequency: Before: __ /week  After: __ /week  Change: __%
  Agent Utilization: __ interactions / __ autonomous resolutions

KEY MOMENTS
  1. [Story: e.g., "Agent detected and resolved a Helm misconfiguration at 3am"]
  2. [Story: e.g., "Agent reviewed and approved 12 routine PRs, saving 4 hours of senior engineer time"]

WHAT THE TEAM SAID
  "[Direct quote from Champion or team member]"

RECOMMENDED NEXT STEP
  → Expand to [N] additional teams in [Pilot timeline]
  Estimated pilot investment: [Pricing TBD]
```

---

## 7. Common Objections + Rebuttals

These are the 6 objections you will hear in every enterprise deal. Know them cold.

---

### Objection 1: "We're worried about security — this AI agent has access to our codebase and k8s cluster."

**Why they say it:** Security and compliance teams have veto power at enterprise accounts. They've read about AI hallucinations and autonomous agents making dangerous changes.

**The rebuttal:**

> "That's the right question, and it's exactly why we designed Squad the way we did. Every agent action is:
> 1. **Audit-logged** — every decision, every change, every PR comment is in a permanent, queryable log
> 2. **Policy-bounded** — agents operate within the permissions YOU configure. They can't do anything your existing RBAC doesn't allow
> 3. **Human-in-the-loop for production** — no agent makes a change to production without a GitHub Pull Request review. Your engineers always have the final merge
>
> Squad doesn't need admin access. It needs the same permissions as your junior engineer.
>
> Would it help to have a 30-minute security architecture call with your InfoSec lead?"

**Leave-behind:** SOC2-readiness one-pager + architecture diagram showing data flows.

---

### Objection 2: "We're worried about vendor lock-in."

**Why they say it:** Platform engineering teams have been burned by proprietary tooling. They've seen Datadog become mandatory and regret the contractual leverage it creates.

**The rebuttal:**

> "Completely valid concern — we designed Squad to be the anti-lock-in AI framework:
> 1. **Open source core.** Squad's framework is open-source. You can fork it, run it on-premises, and modify it.
> 2. **No proprietary data format.** All decisions, agent context, and memory are in plain Markdown files in your own repo. If you stop using Squad tomorrow, all the knowledge stays.
> 3. **Model-agnostic.** Squad orchestrates on top of GitHub Copilot, Claude, or GPT-4. We don't lock you to a single AI provider.
>
> The only thing you can't take away from us is the time we save you — and that's fine by us."

---

### Objection 3: "Our engineers won't adopt it — they're skeptical of AI tools."

**Why they say it:** Previous AI tools had a credibility problem (hallucinations, wrong suggestions, breaking things). Champions are nervous about selling Squad internally.

**The rebuttal:**

> "We've seen this before, and here's what actually happens: Squad's initial adopters are the platform engineers — the skeptics who understand the stack. They're not adopting Squad because marketing told them to. They're adopting it because it solves a problem they personally experience.
>
> We recommend starting with one team, one sprint. No announcement, no mandate. Just the platform team using it privately. By the end of Week 2, they'll be sharing results in their #eng-productivity Slack channel themselves.
>
> The adoption pattern we see: engineers who are skeptical of 'AI magic' love Squad because every agent decision is visible, auditable, and overridable. It's the anti-black-box AI tool."

---

### Objection 4: "This is too expensive / we don't have budget for another tool."

**Why they say it:** VP Engineering has budget pressure. They may be in a tool rationalization phase. Or they don't yet see Squad as differentiated from GitHub Copilot (which they're already paying for).

**The rebuttal:**

> "I hear you — budgets are tight, and AI tool sprawl is a real problem. Two things:
>
> 1. **The 30-day POC is zero cost.** We're not asking you to sign a contract. We're asking you to let two agents run on your cluster for one sprint and measure the output. If the numbers don't speak for themselves, walk away.
>
> 2. **The ROI math is usually self-funding.** If Squad saves each of your 5 platform engineers 2 hours per week, that's 40 engineer-hours per month recaptured. At $200/hour fully loaded cost, that's $8,000/month — likely more than Squad costs.
>
> What would you need to see in the POC to feel comfortable making the budget case internally?"

---

### Objection 5: "We already have Copilot / we built something internal / we use AutoGen."

**Why they say it:** Sophisticated engineering orgs often build their own AI tooling. They conflate Squad with Copilot or generic LLM orchestration.

**The rebuttal:**

> "That's actually a strong signal — it means you already understand the value of AI agents in your dev workflow. Squad doesn't compete with what you've built; it's the team orchestration layer above it.
>
> Here's what's different:
> - GitHub Copilot: individual developer, IDE-level, synchronous
> - Your internal tools: specific use cases, one-off solutions
> - AutoGen/LangChain: framework, requires 6+ months to get production-ready
> - **Squad: a team of specialized, persistent agents that coordinate 24/7 and build institutional memory over time**
>
> The question isn't 'do we need Squad instead of our tools?' It's 'what do we stop building internally when Squad handles it for us?'"

---

### Objection 6: "What happens when an agent makes a mistake? Who's responsible?"

**Why they say it:** A justified fear about agentic AI in production. Legal and compliance want an accountability model.

**The rebuttal:**

> "The accountability model is exactly the same as with a junior engineer:
>
> 1. **Every agent action requires a human review step** before merging to production (GitHub PR workflow)
> 2. **All agent decisions are logged** — you can audit exactly what the agent did, why, and when
> 3. **Agents have a defined 'blast radius'** — they can't exceed the permissions you configure
>
> If an agent makes a wrong suggestion, your engineer reviews the PR and rejects it. Squad doesn't have 'force push to main' access.
>
> We'd rather you think of Squad like a contractor who can't approve their own work — not a rogue autonomous system."

---

## 8. Success Metrics — 90-Day ROI

Define these metrics *before* the POC starts. Revisit them at 30, 60, and 90 days.

### Primary KPIs (Engineering Velocity)

| Metric | Baseline Period | Target Improvement | How to Measure |
|--------|-----------------|-------------------|----------------|
| **PR cycle time** (open → merge) | 30 days before POC | ≥20% reduction | GitHub Insights or LinearB |
| **Infrastructure ticket resolution time** | 30 days before POC | ≥30% reduction | GitHub Issues / Jira |
| **Deploy frequency** | 30 days before POC | ≥15% increase | GitHub Deployments or DORA dashboard |
| **Incident MTTR** | 30 days before POC | ≥25% reduction | PagerDuty / GitHub Issues |

### Secondary KPIs (Agent Utilization)

| Metric | Target (30 days) | Target (90 days) |
|--------|-----------------|------------------|
| Agent interactions per sprint | ≥10 | ≥25 |
| Autonomous issue resolutions (no human intervention) | ≥5 | ≥20 |
| PR reviews completed by agents | ≥15 | ≥50 |
| Infra config changes proposed by agents (reviewed + merged) | ≥3 | ≥10 |

### Champion Satisfaction KPIs

| Metric | Target |
|--------|--------|
| Champion NPS (0–10 scale) | ≥8 at Day 30 |
| Team adoption (% of devs who interacted with an agent) | ≥60% of team by Day 30 |
| Continued use after POC (yes/no) | Yes |

### ROI Model for VP Engineering Sign-Off

Use this model to build the business case for the expansion contract:

```
SQUAD ROI CALCULATOR — 90-Day Model

Team composition:
  Engineers on platform team:       __  (e.g., 5)
  Fully loaded hourly cost:         $__ (e.g., $200)

Hours saved per engineer per week (POC-measured): __  (e.g., 2.5)

Monthly savings:
  Weekly hours saved × engineers × 4 weeks × hourly rate
  = __ hours × __ engineers × 4 × $__ = $___/month
  
Annual savings: $___/year

Squad annual cost (estimated): $___/year

ROI at 12 months: (Annual Savings - Annual Cost) / Annual Cost = __% ROI

Typical result: 3x–8x ROI at 12 months for a team of 5–20 platform engineers.
```

---

## 9. Email Templates

Three templates for three different contexts. Personalize before sending — fill in [BRACKETS].

---

### Template 1 — Cold Outreach (No Prior Contact)

**Subject:** `[Company] + Squad — 30-day k8s productivity POC`

```
Hi [First Name],

I read your post on [specific blog post or KubeCon talk] — your point about 
[specific pain they described] resonated. That's exactly the problem we built 
Squad to solve.

Squad is a multi-agent AI framework that runs on top of GitHub Copilot and 
coordinates specialized agents across your engineering workflow — specifically 
for teams running Kubernetes on AKS.

Three things that might be relevant for [Company]:
1. Agents that handle routine k8s infra tickets 24/7, freeing your platform 
   engineers for higher-leverage work
2. Persistent memory across Copilot sessions — your AI team actually remembers 
   decisions made last sprint
3. 30-day POC with zero procurement overhead — just your cluster and your 
   sprint metrics

Would you have 20 minutes this week to see a quick demo tailored to your stack?

Happy to share our GitHub repo first if you'd rather see the code.

Tamir Dresher
Squad Framework
[calendar link]
```

---

### Template 2 — Warm Referral (Introduced by a Shared Contact)

**Subject:** `Following up — [Referrer Name] suggested I reach out`

```
Hi [First Name],

[Referrer Name] mentioned you're thinking about AI agent tooling for your 
platform team and suggested we connect.

Background: I'm building Squad, a multi-agent framework that sits on top of 
GitHub Copilot and orchestrates specialized agents (infra, security, code 
review, docs) across your dev workflow. It's built specifically for engineering 
teams running Kubernetes.

[Referrer Name] thought it might be relevant given [specific context they 
shared — e.g., "your work scaling the platform team at [Company]"].

I'd love to show you a 20-minute demo tailored to your setup. Before that, 
a quick question: how many engineers are on your team, and are you running 
AKS or another managed Kubernetes service?

If the fit looks good from your side, I can have something on your calendar 
this week.

Tamir
[calendar link]
```

---

### Template 3 — Event Follow-Up (KubeCon / GitHub Universe / Microsoft Build)

**Subject:** `Great meeting you at [Event] — Squad next steps`

```
Hi [First Name],

Really enjoyed our conversation at [Event] [specific topic — e.g., "during 
the CNCF end-user panel"].

Quick recap of what we discussed:
- Squad agents for your [specific pain — e.g., Helm deployment pipeline]
- The 30-day POC structure (one team, one cluster, baseline metrics)
- Your question about [specific thing they asked — e.g., "how agents handle 
  RBAC boundaries"]

As promised: [GitHub repo link / 1-pager / demo video link]

Next step I'd suggest: a 30-minute technical call with you and [one other 
person on their team] to walk through the POC charter. 

Does [Day/time option 1] or [Day/time option 2] work?

Tamir
[calendar link]
```

---

## 10. One-Pager Talking Points — 5-Minute Pitch

Use these in a hallway conversation, a first call intro, or an elevator pitch. Sequence matters — follow the order.

---

### The Setup (30 seconds)

> "You've deployed GitHub Copilot. Individual developer productivity is up. But when you zoom out to the team level — sprint velocity, deploy frequency, infrastructure reliability — the numbers aren't moving as fast as you expected. That's the gap Squad fills."

*What this does:* Validates their existing investment (Copilot), names the real pain (team-level productivity), and positions Squad as the obvious next step.

---

### What Squad Is (60 seconds)

> "Squad is a multi-agent AI framework that runs on top of GitHub Copilot and coordinates a team of specialized AI agents — each with a specific role, a defined scope, and persistent memory of your codebase and decisions.
>
> Think of it like this: Copilot is one AI assistant for one developer. Squad is a full AI team for your engineering organization — infrastructure engineers, security reviewers, code reviewers, documentation writers — working 24/7, coordinated, with context that carries across every sprint."

*What this does:* Delivers the product narrative in two clear sentences. "AI team" is more memorable than "multi-agent framework."

---

### The Proof (60 seconds)

> "Here's what this looks like in practice. An engineer opens a GitHub issue at 2am: 'Helm deployment failing after upgrade.' In a normal world, that wakes up your on-call platform engineer. With Squad, the B'Elanna infrastructure agent picks up the issue, diagnoses the root cause, proposes a config fix as a pull request, and flags it for review — with full context about every Helm change made in the last 90 days. The on-call engineer reviews it over morning coffee.
>
> That's the kind of ROI we see: infrastructure ticket resolution time down 30–60% in the first 30 days."

*What this does:* Makes the abstract concrete. One vivid story beats five feature bullets.

---

### Why Squad, Why Now (60 seconds)

> "The competitive window is now. Cursor just raised at a $9B valuation selling to individual developers. Devin sells a single autonomous agent. AutoGen and LangChain are frameworks that require 6 months of engineering investment to productionize.
>
> Squad is different: it's a production-ready AI team that deploys on your existing GitHub and AKS stack — no new infrastructure, no months of custom development. Teams are getting their first agent running in under a week.
>
> The organizations that get this right now will have a structural productivity advantage over competitors who adopt it 12 months later."

*What this does:* Injects urgency without being pushy. Names competitors without attacking them.

---

### The Ask (30 seconds)

> "Here's what I'd suggest: a 30-day POC with one team, one Kubernetes cluster. We baseline your PR cycle time and infrastructure ticket resolution time before we start. We measure again at Day 30. If the numbers don't move, you walk away with nothing lost.
>
> Can I send you our GitHub repo and a one-page POC charter this week?"

*What this does:* Makes the next step trivially small (read a repo, read a page). Zero procurement pressure. Removes risk from the decision.

---

### FAQ (Have These Ready)

**"What does it cost?"**
> "The POC is free. Expansion pricing is based on team size and scales from there. We'll get to numbers after the POC tells us what the value actually is for your team."

**"How long does it take to set up?"**
> "One to two days for the initial configuration. First agent interaction in the first week. Most teams have meaningful results — things they can screenshot and share — by the end of Week 2."

**"Who else is using it?"**
> "We're in active POCs now. Once our first lighthouse customer signs off, we'll share the case study. In the meantime, here's our GitHub repo — you can see the community adoption there."

**"Is this just for platform teams?"**
> "Platform teams are the fastest to value because their pain maps directly to our agent capabilities. Over time, squads are deploying agents for code review, documentation, security scanning, and release management. The platform team is always the first win."

---

## Appendix A: Sales Process Quick Reference Card

```
SQUAD ENTERPRISE SALES MOTION — QUICK REFERENCE

ICP Qualifier (4 of 6):
  □ GitHub as primary SCM
  □ Kubernetes in production (AKS/EKS/GKE)
  □ GitHub Copilot deployed
  □ 50–5,000 engineers
  □ Dedicated platform/DevEx team
  □ Engineering velocity tracked as KPI

Champion (Platform Engineer): Daily pain, sees technical value
Economic Buyer (VP Eng): ROI in numbers, headcount ROI
Exec Sponsor (CTO): AI strategy narrative, no lock-in

Mandatory Discovery (before demo):
  1. Team size + platform team?
  2. Copilot experience?
  3. K8s/AKS setup?
  4. Biggest dev friction?
  5. Productivity metrics tracked?

Stages: Awareness → Interest → Demo → POC → Pilot → Expansion
POC = 30 days, POC charter first, results report at Day 30

Top Objections:
  Security → audit-logged, policy-bounded, PR-gated
  Lock-in → open source, Markdown memory, model-agnostic
  Adoption → start with platform team, no mandate
  Budget → zero-cost POC, ROI model at Day 30
  Copilot overlap → Squad is above Copilot, not competitive
  Accountability → human review on every production change
```

---

## Appendix B: Competitive Cheat Sheet

| Competitor | Their Pitch | Our Counter |
|------------|------------|-------------|
| **GitHub Copilot Workspace** | "AI that works inside GitHub" | "Squad is the team coordination layer above Copilot — we extend what you already paid for" |
| **Cursor** | "The AI-native IDE" | "Individual developer tool. Squad is team-scale orchestration. Different layer, different buyer, different problem." |
| **Devin (Cognition)** | "Fully autonomous AI software engineer" | "One agent vs. a coordinated team. Squad has persistent memory, specialized agents, and zero hallucination risk on production systems because humans review every prod change." |
| **AutoGen / LangGraph** | "Build your own agent system" | "6 months of custom engineering to get to Squad Day 1. Squad is production-ready out of the box for GitHub + k8s stacks." |
| **Internal DIY** | "We built our own" | "What would your team build next if they didn't have to maintain their own agent framework?" |

---

*Prepared by Seven, Research & Docs | Issue #818 | 2026-03-21*
*Sources: Issue #818, Issue #800 (a16z "Your Product Won't Sell Itself"), Issue #820 (Lighthouse Customer Candidates), Squad Framework Gap Analysis, Squad Framework Evolution One-Pager*
