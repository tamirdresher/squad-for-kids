# Squad GTM Org Structure — Sales Leadership Reporting
**Research Date:** 2026-03-21  
**Author:** Seven (Research & Docs)  
**Closes:** #819  
**Sources:** Issue #819, Issue #820 (Lighthouse Customers), a16z GTM Playbook, OpenView Partners / Bessemer Venture Partners research, Datadog/HashiCorp/Vercel/Netlify public GTM analyses, 2024–2025 SaaS compensation benchmarks (Bridge Group, Betts Recruiting, Glassdoor, Everstage)

---

## Executive Summary

Squad is a developer-tools AI company selling a multi-agent orchestration framework to engineering organizations of 50–5,000 developers. Its go-to-market motion sits at the intersection of two proven archetypes: **PLG** (Datadog, Vercel, HashiCorp early stage) and **enterprise SLG** (HashiCorp/Terraform Cloud, Datadog at scale). The right model for Squad today is **Hybrid PLG+SLG** — but executed in sequence, not simultaneously. Ship community credibility first, add enterprise sales second.

This document defines the optimal 1–10 person GTM team, when to hire each role, what to pay them, and which anti-patterns to avoid.

---

## 1. Current State Assessment

### Where Squad Is Today

Based on the Lighthouse Customers research (issue #820) and Squad's positioning as "Copilot team layer," Squad currently has:

| Dimension | Status |
|-----------|--------|
| Product maturity | Early GA / POC-ready |
| Developer community presence | Seed stage — needs investment |
| Paying customers | Pre-revenue or early lighthouse |
| Sales process | Founder-led |
| Marketing infrastructure | Minimal |
| Brand recognition | Low outside immediate network |

### What a 1–10 Person GTM Team Needs to Accomplish

Before scaling beyond 10 GTM people, the team must achieve:

1. **Signal that the ICP (Ideal Customer Profile) is correct** — GitHub + AKS + 50+ developers is the sweet spot; validate with 3–5 closed deals
2. **Proof of repeatable value** — measurable productivity gains that can be quoted in case studies (PR throughput, issue resolution time, deploy frequency)
3. **Community presence** — talks at KubeCon / GitHub Universe, active GitHub repo, documentation that developers reference without a sales conversation
4. **One lighthouse logo** — a Microsoft, Datadog, or Shopify reference that ends most enterprise objections before they start
5. **A working sales motion** — documented playbook from outreach → POC → close, with known cycle time and win rates

Until all five are in place, scaling the GTM team is premature and will burn cash without compounding returns.

---

## 2. Org Model Comparison

### Model A: Product-Led Growth (PLG) — Community First, Enterprise Second

**Archetype:** Vercel (Next.js), Netlify, early Hashicorp (Terraform open-source)

**How it works:**
- Product is free (or has a generous free tier)
- Developers discover, adopt, and champion the product from the bottom up
- Enterprise deals are *inbound* — champions inside organizations upgrade teams to paid plans
- Community, documentation, and developer experience are the primary GTM investment
- First sales hires are technical: DevRel and Solutions Engineers, not quota-carrying AEs

**PLG Motion timeline for Squad:**
```
Month 0–6:   Open-source community, documentation, DevRel
Month 6–12:  Free tier → team plans → first enterprise conversations
Month 12+:   Enterprise AE layered on top of existing adoption
```

**Strengths for Squad:**
- Developer trust is built through usage, not pitch decks
- Low CAC (Customer Acquisition Cost) — community does the marketing
- Product feedback loop is fast and public
- Aligns with Squad's GitHub-native, open-source-friendly positioning

**Weaknesses for Squad:**
- Revenue lags adoption by 12–18 months
- Requires a truly differentiated, frictionless free product
- Enterprise procurement doesn't happen without someone holding the pen
- Difficult to justify to investors without early revenue signals

**Verdict:** PLG is the *right long-term motion* but Squad needs **at least one enterprise anchor** in year one. Pure PLG alone is too slow for a company with investor expectations.

---

### Model B: Sales-Led Growth (SLG) — Enterprise First, Direct Sales

**Archetype:** Early Palantir, legacy Oracle, enterprise-first B2B SaaS

**How it works:**
- Sales team (AEs + SEs) drives outbound to enterprise targets
- POC-heavy evaluation cycle (30–90 days)
- Contracts negotiated at VP/CTO level
- High ACV ($100K–$1M+), low volume
- Marketing supports pipeline with content and events

**SLG Motion timeline for Squad:**
```
Month 0–3:   Identify 10 target accounts (from lighthouse list)
Month 3–6:   Outbound + LinkedIn outreach, conference presence
Month 6–12:  POC at 2–3 accounts, close first enterprise deal
Month 12+:   Build repeatable playbook, hire 2nd AE
```

**Strengths for Squad:**
- Revenue comes faster if even one enterprise deal closes
- Forces clarity on enterprise-grade features (SSO, audit logs, compliance)
- Validates ICP before scaling community investment

**Weaknesses for Squad:**
- High burn (enterprise AEs are expensive; long sales cycles)
- Without community momentum, cold outreach success rates are low
- Deals are fragile — one champion departure kills the deal
- Non-technical sales reps fail with developer buyers

**Verdict:** SLG alone is expensive and brittle for a developer-tools company without existing brand. Works only if Tamir's network can accelerate the first 2–3 deals without a formal sales team.

---

### Model C: Hybrid PLG+SLG — Community to Convert, Sales to Close ⭐ **Recommended**

**Archetype:** Datadog, HashiCorp (Terraform Cloud/Enterprise), Grafana Labs, Temporal.io

**How it works:**
- PLG motion creates bottom-up developer adoption and community gravity
- Usage signals (team-level adoption, enterprise domain signups, GitHub star trajectory) trigger outbound by sales
- Sales team does not replace the PLG motion — it *accelerates* deals that would happen anyway
- This is sometimes called "Product-Led Sales" (PLS)

**The Datadog model (most relevant analog):**
> Datadog's growth to $500M ARR followed a clear pattern: developers adopted free tiers inside enterprises; product usage data flagged when a team reached a threshold (e.g., 10+ seats, >$X monthly cloud spend being monitored); a Sales Development Rep (SDR) or Solutions Engineer reached out to the internal champion to propose an enterprise upgrade. Sales didn't create demand — they **harvested** it.

**Key Datadog GTM milestones:**
- Year 1–3: PLG-first, no dedicated sales
- Year 3–5: First AEs hired to handle inbound enterprise upgrades
- Year 5+: Outbound sales motion added to accelerate pipeline

**The HashiCorp model:**
> HashiCorp's Terraform was open-source and community-grown. Once enterprises were running Terraform in production, HashiCorp layered in Terraform Cloud (SaaS) and Terraform Enterprise (self-hosted, $$$). The enterprise product was built *after* the community adoption existed, not before.

**Hybrid motion for Squad:**
```
Phase 1 (0–6 months):
  - Developer Advocate publishes content, speaks at events, builds GitHub community
  - Solutions Engineer handles all technical questions and POC support
  - Founder closes the first 3–5 deals directly

Phase 2 (6–18 months):
  - Trigger: $250K ARR or 3 enterprise POCs in flight simultaneously
  - Hire first Enterprise AE to handle inbound enterprise upgrades
  - Customer Success Manager hired when 5+ paying customers exist

Phase 3 (18–36 months):
  - Trigger: $1M ARR or 10+ enterprise customers
  - Second AE, SDR to support outbound
  - Head of Sales / VP Sales to build the team
```

---

## 3. Recommended Org Structure for Squad

### Current Phase (0–6 months): Founder-Led + Two Hires

```
CEO/Founder (Tamir)
├── Developer Advocate / Community [HIRE #1]
└── Solutions Engineer / Technical Sales [HIRE #2]
```

**Rationale:** Both hires are technical, community-facing, and revenue-adjacent. Neither requires an expensive enterprise AE quota. Together they: build community gravity, handle POC support, and generate qualified inbound leads for the founder to close.

---

### Scale Phase (6–18 months): First Commercial Layer

```
CEO/Founder (Tamir)
├── Head of GTM / VP Sales [HIRE #3 — triggers at $250K ARR]
│   ├── Enterprise Account Executive [HIRE #4]
│   └── Customer Success Manager [HIRE #5]
├── Developer Advocate / Community [HIRE #1]
└── Solutions Engineer / Technical Sales [HIRE #2]
```

**Reporting structure:**
- Developer Advocate → reports to CEO/Founder (community is a product function early on)
- Solutions Engineer → reports to Head of GTM (revenue-adjacent; SE time tracks against deals)
- Enterprise AE → reports to Head of GTM
- Customer Success → reports to Head of GTM

> **Note:** In many dev-tools companies, the Developer Advocate eventually moves under Marketing (after a Marketing function exists) or under a Head of Developer Relations. Until there is a formal Marketing function, keep DevRel close to the founder.

---

### Growth Phase (18–36 months): Full GTM Team

```
CEO/Founder (Tamir)
└── VP Sales / Head of GTM [HIRE #3]
    ├── Enterprise Account Executive × 2 [HIRES #4 + #6]
    ├── Solutions Engineer × 2 [HIRES #2 + #7]
    ├── Customer Success Manager [HIRE #5]
    ├── SDR (Sales Development Rep) [HIRE #8]
    └── Developer Advocate → Developer Relations Lead [HIRE #1 → expanded]
```

---

## 4. Role Definitions and Hiring Sequence

### HIRE #1: Developer Advocate / Community (Month 1–3)

**Why first:** Community gravity and content assets compound over time. Every blog post, talk, and GitHub repo star is a permanent asset. Starting community-building at month 3 instead of month 1 costs 3 months of compounding — that matters more than it looks.

**What they do:**
- Write technical content (blog posts, tutorials, videos) about Squad and the problems it solves
- Speak at KubeCon, GitHub Universe, CNCF meetups, and local developer events
- Own the Squad GitHub org — issues, discussions, contributor experience
- Build and nurture a community Slack/Discord for Squad users
- Feed product feedback from community to engineering
- Act as the first filter for inbound interest ("let me connect you with our SE team")

**Triggering metric to hire:** Founder spending more than 4 hours/week on community requests, OR first conference talk opportunity secured.

**Ideal profile:** Ex-developer who has given talks or written popular technical content. Has a personal following in the Kubernetes/cloud-native space. Strong writing skills. NOT a pure marketer — must be able to write working code samples and debug Squad integrations.

**Success metrics (90-day):**
- 2 conference talks accepted
- 1 blog post per week, 3 of which reach 1,000+ reads
- GitHub repo: 500+ stars
- 50+ community Slack members

---

### HIRE #2: Technical Sales / Solutions Engineer (Month 2–4)

**Why second:** The first enterprise POC can arrive before a Developer Advocate has impact. A founder cannot run a technical POC while also building product. The Solutions Engineer (SE) handles all technical aspects of the sales cycle — they are the reason POCs succeed.

**What they do:**
- Own all POC environments: deploy Squad on customer AKS clusters, configure agents, measure results
- Answer technical questions during sales evaluations
- Build integration guides, demo environments, and reference architectures
- Work closely with the Founder/AE on enterprise accounts (they attend every technical call)
- Identify product gaps that block deals and communicate them to engineering
- Eventually, train future AEs on technical aspects of the product

**Triggering metric to hire:** First enterprise POC request received, OR Founder spending more than 6 hours/week on technical sales support.

**Ideal profile:** Former software engineer (3–6 years experience) who has moved into or is interested in a customer-facing role. Deep Kubernetes/AKS/GitHub knowledge required. Must be comfortable presenting to both developers and VPs.

**Success metrics (90-day):**
- POC success rate ≥ 70% (POC converts to paid)
- POC setup time < 5 business days
- 2 reference architectures documented

---

### HIRE #3: Head of GTM / VP Sales (Month 6–12)

**Why third:** Until there is repeatable, scalable pipeline, hiring a VP Sales too early means paying $250K+/year for someone to figure out what the founder already knows. Hire them AFTER the first 3–5 deals close and the pattern is visible. Their job is to *scale* the motion, not to *discover* it.

**What they do:**
- Own pipeline, forecast, and revenue targets
- Build the sales process and CRM discipline (HubSpot or Salesforce)
- Define territory, quota structures, and compensation plans for the team
- Hire and manage AEs and SDRs as the team scales
- Work with the Founder on key enterprise relationships
- Represent Squad at executive-level sales meetings

**Triggering metric to hire:** $250K ARR AND 3 active enterprise opportunities in the pipeline simultaneously.

**Ideal profile:** Has taken a dev-tools or developer infrastructure company from $1M to $10M ARR. Understands PLG-to-SLG transition. Has managed a small team (3–8 people). Avoids the "enterprise playbook" trap — must respect that Squad buyers are developers, not procurement departments.

---

### HIRE #4: Enterprise Account Executive (Month 9–15)

**Why fourth:** The AE is the first dedicated quota-carrying hire. They close deals that the PLG motion and SE team have already warmed. Hiring an AE before there is a warm pipeline means paying $200K+ OTE for outbound cold calling — a waste of capital in a PLG-first motion.

**What they do:**
- Own a book of named enterprise accounts (from the lighthouse customer list)
- Run qualification, discovery, and negotiation on enterprise opportunities
- Partner with the SE on all technical evaluations
- Manage multi-stakeholder deals (developer champion + VP Engineering + procurement)
- Close deals: $50K–$500K ACV typical in year 1–2

**Triggering metric to hire:** Head of GTM is closing deals personally AND backlog of warm pipeline exceeds what one person can manage.

---

### HIRE #5: Customer Success Manager (Month 12–18)

**Why fifth:** Customer success is not a luxury. In an enterprise-motion company, expansion revenue (land-and-expand) is often larger than new logo revenue by year 2–3. Losing an early lighthouse customer because no one was managing their adoption is a catastrophic reputation hit. Hire CSM before the portfolio reaches 5 paying enterprise customers.

**What they do:**
- Own renewal and expansion for all paying customers
- Run onboarding programs: ensure new customers are getting value in 30 days
- Conduct quarterly business reviews (QBRs) with customer stakeholders
- Monitor product usage signals — flag at-risk accounts before churn happens
- Coordinate with SE team on expansion POCs

**Triggering metric to hire:** 3–5 paying enterprise customers, OR first renewal conversation approaching (typically month 10–14 of first customer's contract).

---

## 5. Compensation Benchmarks

*All figures in USD, reflecting 2024–2025 US market rates. Adjust downward ~20–30% for non-US hires.*

| Role | Base Salary | Total OTE / TC | Equity (Seed/Series A) | Notes |
|------|-------------|----------------|------------------------|-------|
| **Developer Advocate** | $140K–$185K | $150K–$210K | 0.1%–0.4% | Variable comp is unusual; bonuses tied to community metrics |
| **Solutions Engineer** | $130K–$175K | $160K–$220K | 0.1%–0.3% | 20–30% variable tied to deal support; quota is soft |
| **Head of GTM / VP Sales** | $180K–$240K | $280K–$400K | 0.3%–0.8% | 50/50 base/variable split; quota at 4–6× OTE |
| **Enterprise AE** | $130K–$180K | $260K–$360K OTE | 0.1%–0.3% | 50/50 base/variable; quota typically $800K–$1.2M ACV |
| **Customer Success Manager** | $110K–$140K | $130K–$160K | 0.05%–0.2% | Variable tied to renewal and expansion ARR |

**Sources:** Bridge Group 2024 AE Benchmark Report, Betts Recruiting Enterprise AE Trends 2024, Everstage SaaS Compensation Report, Glassdoor Enterprise CSM data, a16z portfolio job postings.

**Notes for a startup context:**
- At seed/Series A, cash should be at or slightly below market; compensate with above-market equity
- Developer Advocates at AI-native companies have seen 20–30% compensation inflation since 2023 (driven by demand from OpenAI, Anthropic, Vercel, etc.)
- Solutions Engineers in Kubernetes/cloud-native space command a premium — expect to compete with Datadog, HashiCorp, and AWS for talent
- VP Sales at a pre-Series A company typically accepts below-market base in exchange for meaningful equity (0.5%–1.0%)

---

## 6. A16z / YC Frameworks

### A16z: "The Sales Playbook for Developer Tools" (key principles)

From a16z's GTM playbook and published writing:

1. **Sell to the individual developer first.** If a developer won't use the product voluntarily, no enterprise contract will make them. The purchase decision follows usage, not the other way around.

2. **The champion is your first customer.** Identify the internal developer who is enthusiastic about Squad. Arm them with talking points, ROI data, and a pilot success story to take to their VP. Closing the VP without a champion is nearly impossible.

3. **Win lighthouse accounts early.** Per a16z's enterprise analysis: *"Winning lighthouse accounts early sets your narrative and boxing rules. Losing them creates competitive openings."* Squad's lighthouse list (issue #820) reflects this principle — Microsoft internal, Datadog, Shopify are the right targets.

4. **Layer enterprise sales on PLG, not the reverse.** Building a sales team before there is developer adoption creates a company that pays for sales and still has no pipeline. The sequence matters.

5. **Measure the right things.** In PLG-first companies, the leading indicator of enterprise revenue is *usage expansion* (how many developers at a company are using Squad), not the number of sales calls. Track activation rate, team-level adoption, and enterprise domain signups.

### YC: "Do Things That Don't Scale" applied to GTM

From YC's canonical advice for early-stage companies:

1. **Founder-led sales is not a phase to skip.** The founder should personally close the first 10 deals. Not because they are the best salesperson, but because they need to *hear* what's blocking customers. An AE won't notice the same patterns.

2. **Talk to every churned user.** In developer tools, churn usually signals a product problem (missing integration, confusing UX, poor documentation), not a sales problem. Fix the product before blaming the GTM.

3. **Don't hire a VP Sales to solve a product problem.** If the product isn't converting, more sales headcount makes the problem worse. POC failure rate > 30% is a product signal, not a sales signal.

4. **Enterprise is a distribution channel, not a product requirement.** Squad doesn't need SOC2 or enterprise SSO to start. Those features should be triggered by a specific customer requiring them, not built speculatively.

### OpenView Partners: "Product-Led Sales" Framework

OpenView coined the term "Product-Led Sales" to describe the Datadog/HashiCorp hybrid model:

- **Identify PQL (Product Qualified Leads):** Users who have reached a usage threshold that correlates with conversion (e.g., 5+ Squad agents configured, 20+ developers using Squad at one company)
- **Route PQLs to sales:** When a PQL appears, an SDR or AE reaches out to the internal champion — not to *sell*, but to *help accelerate* what's already happening
- **This is not cold outreach** — the developer champion has already chosen Squad; the AE's job is to help convert the grassroots interest into an enterprise contract

---

## 7. Red Flags — Anti-Patterns to Avoid

These patterns have been the primary cause of failure in developer-tools companies with strong technical products but poor GTM execution.

### 🚨 Anti-Pattern 1: Hiring Enterprise Sales Before Community Exists

**What it looks like:** "We just hired a VP Sales with a Rolodex. He'll open doors."

**Why it fails:** Enterprise buyers in developer tools don't buy based on sales relationships alone. They search GitHub stars, read engineering blogs, check Stack Overflow questions, and ask their developers if they've heard of you. Without community gravity, a VP Sales is cold-calling into skepticism.

**What to do instead:** First 500 GitHub stars and 3 KubeCon talks come before the first AE hire.

---

### 🚨 Anti-Pattern 2: Non-Technical Sales Reps Selling to Developers

**What it looks like:** Hiring enterprise AEs with SaaS backgrounds (Salesforce, SAP, ServiceNow) who have never written code.

**Why it fails:** Developer buyers immediately identify non-technical reps. The first question in a developer-tools evaluation is often technical ("Does Squad support X operator?" or "How do you handle Z edge case?"). A rep who can't answer destroys trust in 60 seconds and poisons the entire evaluation.

**What to do instead:** All early GTM hires must be technical-first. AEs should at minimum understand Kubernetes, GitHub workflows, and CI/CD pipelines at a conceptual level. Solutions Engineers are the first line of credibility.

---

### 🚨 Anti-Pattern 3: Prioritizing Pipeline Volume Over Deal Quality

**What it looks like:** "We have 40 POCs in flight this quarter." (with 2% close rate)

**Why it fails:** Too many POCs with too little SE support means every POC is poorly executed. A failed POC is worse than no POC — the developer champion is embarrassed, the VP loses confidence, and the account is poisoned for 12+ months.

**What to do instead:** Run 5–8 high-quality POCs with dedicated SE time, than 40 poorly supported ones. Track POC → close rate religiously. Below 50% close rate signals a product or ICP problem.

---

### 🚨 Anti-Pattern 4: Ignoring Developer Experience in the Name of Enterprise Features

**What it looks like:** Roadmap dominated by enterprise compliance features (SSO, RBAC, audit logs) while the developer onboarding still takes 2 days and the documentation is incomplete.

**Why it fails:** Enterprise features are purchased by procurement; developer experience is what creates the champion who drives procurement to buy. Without a champion, no amount of enterprise features will close the deal.

**What to do instead:** Maintain a ratio of at least 2:1 developer experience improvements to enterprise feature requests until the first 10 customers are in place.

---

### 🚨 Anti-Pattern 5: Overpromising on the Roadmap to Close Deals

**What it looks like:** AE promises a feature that's "3 months away" to close a $200K deal. Feature slips to 12 months. Customer churns.

**Why it fails:** Developer buyers are sophisticated. They will engineer around a missing feature if the product is valuable enough — but they will never forgive a broken promise. One high-profile churn in the developer community spreads on Twitter/LinkedIn in hours.

**What to do instead:** Sell what exists today. Use open roadmap communication (public GitHub issues, quarterly roadmap updates) as a trust signal, not as a sales tool.

---

### 🚨 Anti-Pattern 6: Scaling GTM Before the Playbook Is Repeatable

**What it looks like:** Raising a $5M Series A and immediately hiring 5 AEs.

**Why it fails:** If the sales motion isn't documented and repeatable, 5 AEs will each invent their own approach. Win rates drop, onboarding takes months, and most of the team misses quota in year one. This burns cash and destroys morale.

**What to do instead:** The first VP Sales or Head of GTM should personally close 3–5 deals before hiring any AEs. They are building the playbook, not managing a team.

---

### 🚨 Anti-Pattern 7: Treating Community as Marketing Instead of Product

**What it looks like:** Developer Advocate is managed by Marketing. Their output is measured in impressions and MQLs. Technical content is reviewed by a marketing manager for "tone."

**Why it fails:** Developer communities are allergic to marketing. The moment a DevRel function starts producing polished, corporate-sounding content, developers disengage. The best DevRel content is opinionated, technically specific, and occasionally critical of the status quo.

**What to do instead:** DevRel reports to the CEO or CPO, not Marketing. Their performance is measured in community engagement, conference talk acceptance rates, and GitHub stars — not MQLs.

---

## 8. Summary Decision Matrix

| Question | Answer |
|----------|--------|
| **What GTM model should Squad use?** | Hybrid PLG+SLG — community first, enterprise second |
| **What is the first GTM hire?** | Developer Advocate (community builder) |
| **What is the second GTM hire?** | Solutions Engineer (POC support) |
| **When does Squad hire the first AE?** | After $250K ARR, or 3 simultaneous POCs |
| **When does Squad hire CS?** | After 3–5 paying enterprise customers |
| **Biggest GTM risk for Squad?** | Hiring enterprise sales before community gravity exists |
| **Most important early metric?** | GitHub stars + KubeCon talk acceptance + POC → close rate |
| **Best comparable company GTM?** | Datadog (PLG → enterprise) or HashiCorp (open-source → paid) |

---

## 9. Recommended Next Steps

1. **Tamir personally closes the first 3 enterprise deals** using the lighthouse customer list (issue #820). Document the full sales cycle for each — from first contact to signed contract.

2. **Hire Developer Advocate in months 1–3.** Use the Datadog DevRel hiring profile as a template: ex-Kubernetes engineer, active conference speaker, passionate writer.

3. **Define PLG free tier immediately.** What can a team of 5–10 developers get from Squad for free? This is the acquisition funnel. Without it, PLG cannot work.

4. **Track PQLs from day one.** When a company has 5+ developers using Squad, that's a Product Qualified Lead. Build this signal into whatever product analytics tool is used.

5. **Set a $250K ARR hiring trigger for VP Sales.** Do not hire VP Sales before this milestone. If it takes longer than 18 months to hit it, the issue is product-market fit, not GTM capacity.

---

*Authored by Seven — Research & Docs. For questions, corrections, or expansion, reference this document in subsequent research requests.*
