# Squad AI Framework — Win-Loss Analysis Process

**Issue:** [#817](https://github.com/tamirdresher_microsoft/tamresearch1/issues/817)
**Date:** 2026-03-21
**Author:** Seven (Research & Docs)
**Status:** Approved for Q1 bootstrap

---

## Table of Contents

1. [What Is Win-Loss Analysis?](#1-what-is-win-loss-analysis)
2. [Why It Matters for Squad](#2-why-it-matters-for-squad)
3. [Interview Framework](#3-interview-framework)
4. [Quarterly Cadence](#4-quarterly-cadence)
5. [Competitor Analysis Template](#5-competitor-analysis-template)
6. [Win Themes to Watch](#6-win-themes-to-watch)
7. [Loss Themes to Watch](#7-loss-themes-to-watch)
8. [Dashboard Template](#8-dashboard-template)
9. [Action Loop](#9-action-loop)
10. [Q1 Starter Kit](#10-q1-starter-kit)

---

## 1. What Is Win-Loss Analysis?

Win-loss analysis is a structured research practice that asks one question after every significant adoption or rejection decision:

> **"Why did this team choose us — or not?"**

You interview developers or engineering leads who recently evaluated Squad against alternatives. You ask what they needed, what they tested, where Squad stood out, and where it fell short. You aggregate patterns across 6–10 interviews per quarter. You turn those patterns into product, messaging, and competitive decisions.

It is not a survey. It is not a NPS score. It is a 30-minute conversation with a human who made a real decision.

### The Three Artifacts

| Artifact | What It Is | Produced By |
|----------|-----------|-------------|
| **Win interview** | Conversation with a team that adopted Squad | Product lead or founder |
| **Loss interview** | Conversation with a team that evaluated and passed | Product lead or founder |
| **Quarterly synthesis** | Patterns across all interviews that quarter | Research/docs lead (Seven) |

---

## 2. Why It Matters for Squad

Squad is an early-stage developer tool with strong technical foundations and real usage. But at this stage, the product-market fit signal lives entirely in conversations — not dashboards.

**Specific risks without win-loss data:**

- **Building the wrong thing.** Teams are asking for cross-repo coordination or MCP server integration, but without structured feedback we're guessing at priority order.
- **Losing on messaging.** A prospect sees "multi-agent AI coordination" and routes us to an IT evaluation. The actual buyers are senior engineers. We don't know this without talking to people who said no.
- **Ceding competitor positioning.** Cursor, Devin, and Claude Code are moving fast. If they are winning on feature X, we need to know in weeks — not months.
- **Missing lighthouse customers.** The lighthouse research (`lighthouse-customer-candidates-2026-03-21.md`) identified candidate profiles. Win-loss interviews tell us which profile actually converts.

**What win-loss uniquely provides:**
- Direct competitor intelligence from buyers who compared options
- Unfiltered feedback before the product team rationalizes it away
- Early signals on whether the research → open source contribution loop is working
- Evidence to prioritize the Phase 1 / Phase 2 / Phase 3 roadmap described in the framework evolution plan

---

## 3. Interview Framework

### 3.1 Setup

Conduct all interviews within **30 days** of the adoption or rejection decision. Memory degrades fast. For wins, reach out the week after onboarding. For losses, reach out 2–3 weeks after the prospect went quiet.

**Length:** 30 minutes
**Format:** Video call, recorded with consent
**Interviewer:** Product lead or founder (not sales)
**Note-taker:** Optional second person; review recording otherwise

---

### 3.2 Win Interview Questions

> Use for teams who installed Squad, ran it on real work, and are continuing to use it.

**Opening (5 min)**

1. Tell me what your team looks like and what kind of work you use Squad for.
2. Walk me through how you first heard about Squad.
3. What were you trying to solve when you started evaluating it?

**The Decision (10 min)**

4. What other tools or approaches did you consider before choosing Squad?
5. What made you actually try Squad rather than just read about it?
6. What moment in the evaluation made you decide to go forward?
7. Was there anything that almost made you walk away?

**Value (10 min)**

8. What has Squad done for your team that you couldn't do before?
9. What's the one thing you'd tell another engineer to watch for in their first week?
10. Where has Squad surprised you — positively or negatively?

**Closing (5 min)**

11. What would make you recommend Squad to another team?
12. If Squad disappeared tomorrow, what would you use instead?
13. Is there anything we should have asked but didn't?

---

### 3.3 Loss Interview Questions

> Use for teams who evaluated Squad but chose a different tool, paused the evaluation, or went back to manual coordination.

**Opening (5 min)**

1. Tell me what you were trying to accomplish when you found Squad.
2. Walk me through your evaluation process — what did you actually try?

**The Decision (10 min)**

3. What was the point in the evaluation where you felt Squad was or wasn't going to work?
4. What did you end up choosing instead? Can you tell me more about that decision?
5. What would Squad have needed to offer for you to choose it?

**Blockers (10 min)**

6. Was there a specific feature or capability you were missing?
7. Was there anything in the setup or onboarding that slowed you down?
8. Were there any internal concerns — security, licensing, integration — that factored in?
9. How did Squad compare to [Cursor / Devin / Claude Code / alternative they named]?

**Closing (5 min)**

10. If Squad addressed the gap you described, would you re-evaluate?
11. Is there anything about this conversation we should share with the product team?
12. Would you be open to a follow-up in three months?

---

### 3.4 Interview Scoring Card

After each interview, score it immediately before memory fades:

```
INTERVIEW SCORING CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Date:
Interviewee role:
Team size:
Outcome: Win / Loss / No decision yet
Primary competitor mentioned:

Top win reason (1 sentence):
Top loss reason (1 sentence):

Feature gaps mentioned (list):
-
-

Competitor strengths mentioned (list):
-
-

Quotes worth capturing verbatim:
-
-

Signals for product team (Y/N): ___
Signals for marketing team (Y/N): ___
Follow-up needed (Y/N + detail): ___
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 4. Quarterly Cadence

### 4.1 Target Volume

| Quarter Stage | Target Interviews | Minimum |
|---------------|------------------|---------|
| Q1 (bootstrap) | 6 total (4 wins, 2 losses) | 4 |
| Q2 onwards | 10 total (6 wins, 4 losses) | 6 |
| Steady state | 12–15 per quarter | 8 |

**Rule:** Never synthesize a quarter with fewer than 4 interviews. You can't find patterns in 2 data points.

---

### 4.2 Roles and Responsibilities

| Activity | Owner | Backup |
|----------|-------|--------|
| Scheduling and outreach | Product lead | Coordinator |
| Win interviews | Product lead | Founder |
| Loss interviews | Founder | Product lead |
| Interview scoring cards | Interviewer (same day) | Nobody — must be done same day |
| Quarterly synthesis | Seven (Research/Docs) | Picard (Lead) |
| Dashboard update | Seven | — |
| Action loop meeting | Picard | — |
| Competitive tracking update | Seven | Data agent |

**Why the founder does loss interviews:** Prospects are more candid with founders than with salespeople. The founder can also make on-the-spot commitments ("we're building that in Q2") that a product manager can't.

---

### 4.3 Quarterly Timeline

```
Week 1-10  → Ongoing: Identify candidates as they convert or churn
Week 1-10  → Ongoing: Schedule and run interviews (1-2 per week)
Week 10    → Scoring cards aggregated into quarterly dataset
Week 11    → Seven synthesizes patterns into quarterly report
Week 12    → Action loop meeting: product + marketing + contributor review
Week 12    → Dashboard updated
Week 13    → Roadmap update informed by win-loss findings
```

---

### 4.4 Candidate Identification

**Win candidates** (teams to interview for wins):
- Joined the Squad Discord or Slack and are active
- Opened issues or PRs in the main repo
- Mentioned Squad in a public blog post or talk
- Reached out directly via email or social

**Loss candidates** (teams to interview for losses):
- Opened an issue asking a setup question, then went silent
- Started a GitHub discussion but didn't follow up
- Responded to outreach with "we decided to go a different direction"
- Mentioned Squad in a social post alongside a competitor name

**Track candidates in the dashboard** (see Section 8). You need a pipeline of 20–25 candidates per quarter to hit 10 completed interviews after scheduling friction.

---

## 5. Competitor Analysis Template

Track why prospects chose alternatives in this structured format. One row per competitive encounter (a single interview may generate multiple rows if multiple competitors were mentioned).

### 5.1 Competitor Encounter Log

```
COMPETITOR ENCOUNTER LOG
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Date:
Source interview ID:
Competitor chosen / mentioned:
  [ ] Cursor         [ ] Devin          [ ] Claude Code
  [ ] GitHub Copilot Workspace          [ ] Aider
  [ ] Continue.dev   [ ] Custom scripts [ ] "Staying manual"
  [ ] Other: _______________

Why they chose the competitor (interviewee's words, not our interpretation):

Feature the competitor had that Squad lacked:

Pricing / licensing factor (if any):

Integration advantage (if any):

Team size / context where competitor fit better:

Could Squad win this back? Y / N / Maybe
If yes — what would it take?

Competitor's apparent weakness (what interviewee didn't like about them):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 5.2 Competitor Positioning Summary (Updated Quarterly)

| Competitor | Their Stated Strength | Our Counter | Head-to-Head Win Rate | Notes |
|-----------|----------------------|-------------|----------------------|-------|
| **Cursor** | AI-native IDE, inline suggestions, strong individual dev UX | Squad is team-coordination, not IDE autocomplete — different jobs | Track separately | Often mentioned first because it's familiar; not a true competitor |
| **Devin** | Fully autonomous agent, hands-off coding | Squad is human+AI collaboration, not full automation | Track | Devin loss = prospect wanted less human involvement than Squad assumes |
| **Claude Code** | Best-in-class code quality, Anthropic trust | Squad is framework-agnostic; integrates Claude as underlying model | Track | Could position as "Claude Code inside a Squad" |
| **GitHub Copilot Workspace** | Native GitHub integration, no setup | Squad requires setup investment; workspace is zero-config | Track | Largest source of inertia losses (people stay with what they have) |
| **Aider** | CLI-first, fast, minimal | Squad has more structure; Aider is simpler for solo work | Track | Aider wins among solo developers — not Squad's market |
| **Custom scripts / manual** | Full control, no external dependency | Squad's value emerges only at team scale | Track | Most common early-stage loss; a timing issue, not a feature issue |

---

## 6. Win Themes to Watch

These patterns across win interviews indicate strong product-market fit. Track whether they strengthen or weaken quarter-over-quarter.

### Theme W1 — Team Scale Unlocks Squad

**Signal:** Wins cluster in teams of 4+ engineers with an existing coordination problem. Solo devs and pairs are rarely wins; squads of 5–15 are the sweet spot.

**What to listen for:**
- "We were spending too much time in stand-up"
- "Nobody knew who was working on what"
- "Agents started stepping on each other's toes"
- "We needed something that could triage issues without waking someone up"

**Why it matters:** Confirms the target customer profile. If this theme weakens (wins start appearing in smaller teams), investigate whether the value prop is broadening or whether we're winning for the wrong reasons.

---

### Theme W2 — Research and Non-Code Workflows

**Signal:** Teams adopt Squad not just for code review and PR routing but for research tasks, evaluations, and architecture decisions.

**What to listen for:**
- "We use it to triage incoming vendor evaluations"
- "The research lifecycle is the main reason we're here"
- "We finally have a way to run failed experiments without it feeling like a failure"

**Why it matters:** This is Squad's differentiated territory vs. code-only tools. Strong signals here validate the Phase 1 contribution roadmap and the research lifecycle innovation.

---

### Theme W3 — Human-in-the-Loop Trust

**Signal:** Teams with compliance, security, or governance requirements choose Squad because it keeps humans in the loop by design — unlike fully autonomous agents.

**What to listen for:**
- "We can't use Devin because we need approval gates"
- "Our security team won't allow fully autonomous PRs"
- "Squad lets us move fast without losing accountability"

**Why it matters:** This opens the enterprise and regulated-industry segment. If this theme appears in 3+ wins per quarter, consider explicit messaging around governance and audit trails.

---

### Theme W4 — Cross-Repo Coordination

**Signal:** Teams with frontend/backend splits or research/production repo separation adopt Squad specifically for its cross-repository communication patterns.

**What to listen for:**
- "Nothing else handles cross-repo agent routing"
- "We needed agents in two repos to talk to each other"
- "The Ralph bridging pattern solved our biggest pain"

**Why it matters:** This is Squad's hardest-to-replicate competitive moat. If this theme grows, accelerate Phase 2 cross-repo SDK work.

---

### Theme W5 — The 10x Contributor Effect

**Signal:** One enthusiastic adopter — often a staff engineer or DevRel — drives Squad adoption for their entire team or community.

**What to listen for:**
- "I found it through [specific person's] blog post"
- "Our tech lead pushed for this evaluation"
- "After the conference talk, the whole team wanted to try it"

**Why it matters:** Identifies the true influencer profile for marketing. If this theme is strong, invest in DevRel and conference presence over paid acquisition.

---

## 7. Loss Themes to Watch

These patterns indicate needed product, positioning, or process improvements.

### Theme L1 — Setup Friction (The "Too Hard" Loss)

**Signal:** Prospect tried Squad, hit a setup problem, and gave up before seeing value.

**What to listen for:**
- "I couldn't get it running on Windows"
- "The config file was confusing"
- "There was no quick-start guide for our stack"
- "I spent two hours and hadn't made any progress"

**What to do:** This is a P0 product and docs fix. Every L1 loss is a failing onboarding funnel. Escalate to docs and product immediately.

---

### Theme L2 — "We Decided to Stay Manual"

**Signal:** Prospect evaluated Squad, found it credible, but concluded their team isn't ready for AI coordination.

**What to listen for:**
- "We're not big enough yet"
- "Our team doesn't trust AI with routing decisions"
- "We'll revisit when we're further along"

**What to do:** This is a timing loss, not a feature loss. Tag these prospects for re-engagement in 2 quarters. Do not change the product; consider nurture content that shows Squad value at their team size.

---

### Theme L3 — Missing Feature Blocker

**Signal:** Prospect made it through evaluation but couldn't adopt because one specific capability was missing.

**What to listen for:**
- "We needed [X] and it wasn't there"
- "The MCP server integration would have closed it for us"
- "We needed VS Code extension support"

**What to do:** Log the missing feature with frequency count. When 3+ independent prospects name the same blocker, it becomes a roadmap priority. Do not build features mentioned by only 1 prospect without further validation.

---

### Theme L4 — Competitor Won on Familiarity

**Signal:** Prospect chose an alternative not because it was better, but because the team already knew it.

**What to listen for:**
- "We already had Cursor licenses"
- "GitHub Copilot was already approved by IT"
- "Devin was already in the evaluation pipeline"

**What to do:** These are activation losses, not product losses. The response is faster time-to-value (onboarding, integrations with existing tools) rather than new features.

---

### Theme L5 — Positioning Mismatch (The "Wrong Buyer" Loss)

**Signal:** The person who found Squad was not the decision-maker. Squad was evaluated for the wrong job.

**What to listen for:**
- "I thought this was a coding assistant"
- "My manager wanted a tool that writes code, not one that coordinates agents"
- "We were looking for something more like Devin"

**What to do:** This is a messaging problem. "AI team coordination" is not landing with the right buyer. Test alternative positioning: "AI-powered engineering operations" or "Multi-agent workflow management for engineering teams."

---

### Theme L6 — Enterprise Blocker (Security / Compliance)

**Signal:** Prospect's IT or security organization blocked Squad adoption due to policy concerns.

**What to listen for:**
- "IT couldn't approve it — we needed SOC 2"
- "Legal had questions about AI-generated code attribution"
- "We couldn't use a GitHub-dependent workflow in our environment"

**What to do:** Log with enterprise context. If this appears in 2+ losses, it signals a near-term enterprise readiness gap. Escalate to product with the specific blocker type.

---

## 8. Dashboard Template

Maintain this as a single spreadsheet (`squad-win-loss-dashboard.xlsx`) or Notion/Airtable table. Update weekly.

### 8.1 Interview Pipeline Tab

| ID | Date | Type | Interviewee Role | Team Size | Status | Outcome | Notes |
|----|------|------|-----------------|-----------|--------|---------|-------|
| WL-001 | 2026-03-15 | Win | Staff Engineer | 8 | Complete | Win | — |
| WL-002 | 2026-03-18 | Loss | Tech Lead | 5 | Scheduled | — | Evaluation ended last week |
| WL-003 | 2026-03-20 | Win | DevRel | 12 | Outreach sent | — | Found us via blog post |

**Status values:** `Candidate` → `Outreach sent` → `Scheduled` → `Complete` → `Archived`

---

### 8.2 KPI Summary Tab

Track these metrics quarter-over-quarter:

| Metric | Q1 Target | Q1 Actual | Q2 Actual | Q3 Actual |
|--------|-----------|-----------|-----------|-----------|
| **Total interviews completed** | 6 | — | — | — |
| **Win rate** (wins / total decisions) | — | — | — | — |
| **Avg team size (wins)** | — | — | — | — |
| **Avg team size (losses)** | — | — | — | — |
| **Most common loss reason** | — | — | — | — |
| **Most common win reason** | — | — | — | — |
| **Avg days to interview after decision** | ≤30 | — | — | — |
| **Competitor mentioned most often** | — | — | — | — |
| **Re-evaluation pipeline** (losses likely to return) | — | — | — | — |

---

### 8.3 Win/Loss Reason Tally Tab

Tally theme frequency per quarter. When a theme is mentioned across 3+ interviews, it becomes actionable.

| Theme | Q1 Count | Q2 Count | Q3 Count | Trend |
|-------|----------|----------|----------|-------|
| W1 — Team Scale Unlocks Squad | | | | |
| W2 — Research/Non-Code Workflows | | | | |
| W3 — Human-in-the-Loop Trust | | | | |
| W4 — Cross-Repo Coordination | | | | |
| W5 — 10x Contributor Effect | | | | |
| L1 — Setup Friction | | | | |
| L2 — Staying Manual | | | | |
| L3 — Missing Feature Blocker | | | | |
| L4 — Familiarity / Incumbent | | | | |
| L5 — Positioning Mismatch | | | | |
| L6 — Enterprise Blocker | | | | |

---

### 8.4 Competitor Scoreboard Tab

| Competitor | Times Mentioned | Times Chosen Over Squad | Times Squad Won Against Them | Head-to-Head Rate |
|-----------|----------------|------------------------|------------------------------|------------------|
| Cursor | | | | |
| Devin | | | | |
| Claude Code | | | | |
| GitHub Copilot Workspace | | | | |
| Aider | | | | |
| Custom / Manual | | | | |

---

## 9. Action Loop

Win-loss data is worthless without a routing process that turns it into decisions. Here is the closed loop:

```
┌─────────────────────────────────────────────────────────┐
│              QUARTERLY WIN-LOSS ACTION LOOP              │
└─────────────────────────────────────────────────────────┘

COLLECT                    SYNTHESIZE               ACT
───────                    ──────────               ───

Interviews (6-15)    →    Seven's quarterly   →   Product team:
Scoring cards        →    synthesis report    →   • Adjust roadmap priorities
Competitor logs      →    (week 11)           →   • File feature requests
Dashboard updates                             →   • Close L1/L3 blockers

                                              Marketing:
                                              • Update positioning copy
                                              • Adjust ICP definition
                                              • Create nurture content
                                                for L2 (timing) losses

                                              Open source / contributors:
                                              • Prioritize Phase 1/2/3 PRs
                                              • Update contribution roadmap
                                              • Inform upstream proposals
```

### 9.1 Product Team Routing

After each quarterly synthesis, product receives:

1. **Feature gap list** — All L3 blockers mentioned by 2+ prospects, sorted by frequency
2. **Onboarding friction list** — All L1 issues, sorted by stage where friction occurred
3. **Competitor feature matrix** — What specific features caused head-to-head losses
4. **Win pattern summary** — Which use cases are converting reliably (protect these)

**Product response SLA:** Within 2 weeks of the synthesis, product must either (a) add items to the roadmap, (b) explicitly reject them with reasoning, or (c) ask for more data. No silent ignoring.

---

### 9.2 Marketing Routing

After each quarterly synthesis, marketing receives:

1. **Buyer profile update** — What roles and team sizes are winning vs. losing
2. **Messaging failures** — Any L5 (positioning mismatch) instances with exact quotes
3. **Win quotes** — Verbatim phrases from win interviews suitable for testimonials
4. **Competitor positioning gaps** — Where our current counter-messaging isn't landing

---

### 9.3 Open Source / Contributor Routing

This is Squad-specific. After each quarterly synthesis, the contribution roadmap receives:

1. **Phase 1/2/3 re-prioritization signal** — Which research innovations are directly named in wins
2. **Cross-repo coordination wins** — Evidence to strengthen the upstream PR proposals
3. **Feature gaps that map to planned SDK work** — Justification for Phase 2 timeline

---

### 9.4 Re-Engagement Pipeline

L2 (timing) and L3 (missing feature, now closed) losses go into a re-engagement list:

| ID | Original Decision | Reason | Re-engage After | Notes |
|----|------------------|--------|----------------|-------|
| WL-002 | Loss (timing) | Team too small | Q3 2026 | Check if team grew |
| WL-005 | Loss (L3 — MCP) | MCP server missing | When MCP ships | Auto-notify when milestone closes |

Ralph (work monitor) or the coordinator should surface re-engagement candidates at the start of each quarter.

---

## 10. Q1 Starter Kit

You have zero interviews. Zero data. Here is exactly what to do in the first quarter to bootstrap this process.

### Week 1: Infrastructure Setup

**Day 1–2**
- [ ] Create the dashboard spreadsheet from Section 8 with the four tabs
- [ ] Save the Interview Scoring Card template (Section 3.4) as a reusable doc
- [ ] Save the Competitor Encounter Log template (Section 5.1) as a reusable doc
- [ ] Schedule the Q1 Action Loop meeting for Week 12 (get calendars now)

**Day 3–5**
- [ ] Identify 15–20 win candidates from: GitHub issues, Discord/Slack, GitHub stars with recent activity, blog posts mentioning Squad
- [ ] Identify 5–10 loss candidates from: cold discussions, silent issue openers, social mentions alongside competitor names
- [ ] Enter all candidates into the dashboard under "Candidate" status

---

### Week 2–3: Outreach

**Win outreach template:**
```
Subject: Quick question about your Squad experience

Hi [Name],

I noticed you've been using the Squad framework — really glad it's in your stack.

I'm doing 30-minute conversations with teams who've adopted Squad to understand what's 
working and where we can improve. Would you be open to a quick call?

No agenda, no sales. Just learning.

[Calendly link or "reply with your availability"]

– [Name], Squad project
```

**Loss outreach template:**
```
Subject: Did Squad work out for you?

Hi [Name],

I saw you were exploring Squad a few weeks ago. Would love to hear how the evaluation went — 
whether you adopted it, chose something else, or put it on hold.

If you have 20 minutes, I'd genuinely value the honest feedback. These conversations 
directly shape the roadmap.

No sales, no follow-up unless you want it.

[Calendly link]

– [Name], Squad project
```

**Target:** Send 20 outreach messages in weeks 2–3. Expect 20–30% response rate. That gets you to 4–6 interviews.

---

### Week 4–8: Run Interviews

- [ ] Run 1–2 interviews per week
- [ ] Complete scoring card same day as each interview
- [ ] Log competitor encounters after any loss interview
- [ ] Update dashboard status after each interview

**If you can't find enough candidates:**
- Post in Squad's Discord/GitHub Discussions: "We're doing 30-min user research calls — would you be open to chatting?"
- Ask existing adopters: "Do you know anyone who looked at Squad and went a different direction?"
- Check GitHub: anyone who forked Squad but hasn't committed in 60+ days is a cold loss candidate

---

### Week 10: Aggregate

- [ ] Export all scoring cards into a single document
- [ ] Tally theme frequencies in the dashboard (Section 8.3)
- [ ] Update competitor scoreboard (Section 8.4)
- [ ] Note: with only 4–6 Q1 interviews, you'll see hints, not patterns. That's fine. Document what you see and flag confidence level.

---

### Week 11: Synthesize

Seven (or whoever runs research) produces the Q1 synthesis report with this structure:

```
Q1 WIN-LOSS SYNTHESIS REPORT
═══════════════════════════════════════════
Quarter: Q1 2026
Interviews completed: [N]
Win interviews: [N]
Loss interviews: [N]

HEADLINE FINDING (1–2 sentences):

WIN THEMES (with frequency):
- [Theme]: [N] mentions
  Quote: "..."

LOSS THEMES (with frequency):
- [Theme]: [N] mentions
  Quote: "..."

COMPETITOR REPORT:
- Most mentioned: [competitor]
- Head-to-head losses: [N]
- Key insight: ...

PRODUCT ASKS (ranked by frequency):
1. [Feature/fix] — [N] mentions
2. ...

MARKETING ASKS:
1. ...

CONTRIBUTION ROADMAP SIGNAL:
- Phase 1/2/3 priority change: ...

CONFIDENCE NOTE:
With [N] interviews, these are early signals. Treat as directional, not conclusive.
Validate or invalidate in Q2.

OPEN QUESTIONS FOR Q2:
- Did we miss a buyer profile?
- Is [competitor] winning on [dimension] consistently?
- ...
═══════════════════════════════════════════
```

---

### Week 12: Action Loop Meeting

30-minute meeting. Attendees: product lead, marketing (if exists), contributor lead, Seven.

Agenda:
1. Seven presents synthesis (10 min, no reading — summarize)
2. Product commits to specific actions from the feature gap list (10 min)
3. Marketing commits to copy/ICP changes (5 min)
4. Contributor roadmap update confirmed (5 min)

Output: Decision log entry in `.squad/decisions.md` with dated commitments.

---

### Q1 Success Criteria

At the end of Q1, you should be able to answer:

- [ ] What is the #1 reason teams adopt Squad?
- [ ] What is the #1 reason teams walk away?
- [ ] Which competitor do we lose to most often, and why?
- [ ] What is the team size of our most successful adopters?
- [ ] What is one thing we should change in onboarding immediately?

If you can answer 3 of these 5, the Q1 bootstrap succeeded. If you can answer all 5, you're already ahead of most early-stage developer tools at this stage.

---

## Appendix A: Quick Reference Card

Laminate this. Put it next to your keyboard.

```
┌─────────────────────────────────────────────────────┐
│           SQUAD WIN-LOSS QUICK REFERENCE             │
├─────────────────────────────────────────────────────┤
│ INTERVIEW WITHIN 30 DAYS OF DECISION                │
│ 30 MINUTES. VIDEO. RECORD WITH CONSENT.             │
│ SCORING CARD SAME DAY — NO EXCEPTIONS.              │
├─────────────────────────────────────────────────────┤
│ WIN SIGNAL?    → Ask: "What moment closed it?"      │
│ LOSS SIGNAL?   → Ask: "What would have changed it?" │
│ COMPETITOR?    → Ask: "What did they have we don't?"│
├─────────────────────────────────────────────────────┤
│ QUARTERLY: 6–15 interviews, week 11 synthesis,      │
│            week 12 action loop meeting              │
├─────────────────────────────────────────────────────┤
│ THE ONLY METRIC THAT MATTERS IN Q1:                 │
│ "Can we answer the 5 questions at the bottom        │
│  of Section 10?"                                    │
└─────────────────────────────────────────────────────┘
```

---

## Appendix B: Related Research

- `lighthouse-customer-candidates-2026-03-21.md` — Candidate profiles likely to be win or loss candidates
- `squad-framework-gap-analysis.md` — Feature gaps that may appear as L3 loss themes
- `squad-framework-evolution-onepager.md` — Contribution roadmap context for Section 9.3
- `cowork-vs-squad-brain-2026-03-21.md` — Competitive landscape context for Section 5

---

*Document owner: Seven (Research & Docs)*
*Next review: End of Q1 2026 (after first synthesis)*
*Closes: [#817](https://github.com/tamirdresher_microsoft/tamresearch1/issues/817)*
