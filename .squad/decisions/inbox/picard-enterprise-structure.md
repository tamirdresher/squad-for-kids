# Decision 33: Enterprise Sub-Company Architecture — SUPERSEDES Decision 23

**Date:** 2026-03-18  
**Author:** Picard (Lead)  
**Status:** ✅ ADOPTED  
**Severity:** CRITICAL — Permanent enterprise rule  
**Supersedes:** Decision 23 (Squad Expansion)

## Context

Decision 23 proposed 4 squads but did not enforce **repo isolation**. After a full audit of all decisions, revenue reports, cross-machine tasks, agent charters, and issue history, this decision formalizes the complete enterprise structure based on **evidence of what actually exists and operates**, not just what was mentioned.

Key discovery: **JellyBolt Games is already a separate company in practice** — it has its own repos, its own squad (Mario, Sonic, Link, Yoshi, Toad), its own Ralph monitor, and 2 live games on itch.io. TechAI Content similarly has repos on personal GitHub (techai-explained, devtools-pro, saas-finder-hub) with dedicated agents. Both just lack formal squad directory structure.

## Decision

### Core Principle

**Every sub-company in the enterprise MUST operate in its own dedicated GitHub repository with its own Squad.** The main `tamresearch1` repo is the enterprise **Upstream Squad** — it serves as the governance layer that sets shared standards for all sub-companies AND coordinates cross-company concerns. Sub-companies are autonomous in their domain work but inherit enterprise-wide policies from HQ.

### Enterprise Map (Evidence-Based)

| # | Sub-Company | Repos (existing) | Needs Squad Repo | Lead | Domain | Evidence |
|---|------------|-------------------|-----------------|------|--------|----------|
| 1 | **HQ / Coordinator** | `tamresearch1` (MS org) | ✅ Has it | Picard | Cross-company coordination, infra, security | Active since inception |
| 2 | **Research Institute** | `tamresearch1-research` (MS org) + 3 archive repos | ✅ Has it | Guinan-R | Deep research, patent analysis | Decision 23, operational since Mar 2026 |
| 3 | **TechAI Content** | `techai-explained`, `devtools-pro`, `saas-finder-hub`, `tamirdresher.github.io` (all personal GH) | ❌ Needs consolidated squad repo | Guinan | Content strategy, YouTube, blog, SEO, newsletter, Gumroad, podcasts, book | Revenue report, 4-part blog series, viral marketing plan, Kit newsletter, 25 SaaS articles |
| 4 | **JellyBolt Games** | `jellybolt-games` (HQ), `brainrot-quiz-battle`, `code-conquest`, `bounce-blitz`, `idle-critter-farm` (all personal GH) | ❌ Needs squad setup in jellybolt-games | Mario (squad exists) | Game dev, itch.io, Play Store, monetization | 2 games LIVE on itch.io, own Ralph, own squad, revenue projections $100K-$800K/yr |
| 5 | **Ventures & IP** | None | ❌ Needs creation | TBD | Patent licensing, consulting, Squad-as-SaaS marketplace | Patent research report, revenue expansion plan (Toptal, MentorCruise, GitHub Sponsors), squad-monitor SaaS concept |

### Side Projects / Future Products

> These are **personal side projects**, NOT enterprise sub-companies. They do not get enterprise routing, do not appear on HQ's board, and are not coordinated via the cross-company issue protocol. If a side project matures into a real business, it graduates to the enterprise map above and gets its own squad.

| Project | Repo | Status | Notes |
|---------|------|--------|-------|
| **Kids Squad** | `kids-squad-setup` (personal GH) | 🧪 Personal side project | Tamir's kids get their own AI squad. Potential future: generalize the format and sell as a product. Decision 14 has design. NOT an enterprise sub-company. |

### Sub-Company Detail

#### 3. TechAI Content — Products & Revenue Streams
- **YouTube Channel** (`techai-explained`): 4 daily multilingual videos (EN/HE/ES/FR), voice cloning proven (F5-TTS, SeedVC, Azure TTS)
- **Blog** (`tamirdresher.github.io`): 4-part "Scaling AI" series, SEO-optimized, affiliate links
- **Newsletter** (Kit/ConvertKit): Landing page published, lead magnets ready ("Build Your AI Squad in 30 Minutes", "MCP Server Starter Kit")
- **Gumroad** (`devtools-pro`): 5 products + bundle, .NET cheatsheets, code templates
- **SaaS Finder Hub** (`saas-finder-hub`): 25 SEO-optimized affiliate articles, 82/100 SEO score
- **Podcast**: Audio content via Podcaster agent, Azure AI Speech Service ($360/yr)
- **Book**: Planned ("Maybe Agentic AI is the final frontier..." — Decision 12)
- **Agents**: Guinan (Strategy), Paris (Video/Audio), Geordi (SEO), Crusher (Safety)
- **Revenue blockers**: YouTube not public, Stripe not connected to Gumroad, approval workflows undefined

#### 4. JellyBolt Games — Products & Revenue Streams
- **BrainRot Quiz Battle** (LIVE): `jellyboltgames.itch.io/brainrot-quiz-battle` — multiplayer quiz
- **Code Conquest** (LIVE): `jellyboltgames.itch.io/code-conquest` — coding puzzle game
- **Bounce Blitz**: Game 2 (Play Store ready)
- **Idle Critter Farm**: Game 3 (Play Store ready)
- **Squad**: Mario, Sonic, Link, Yoshi, Toad (gaming-themed agents)
- **Account**: `tdsquadai@gmail.com`, itch.io developer profile
- **Revenue blockers**: Mobile black screen bug (PR #814 merged, QA needed), Stripe not connected, Battle Pass disabled
- **Revenue projections**: Conservative $100K-$130K, Optimistic $600K-$800K (Year 1)

#### 5. Ventures & IP — Identified Revenue Opportunities
- **Patent licensing**: Multi-agent orchestration IP evaluated (Patent Research Report, Issue #42)
- **Consulting**: Toptal ($200-350/hr), MentorCruise, Codementor (revenue expansion plan)
- **Squad-as-SaaS**: GitHub Marketplace product (squad-cli plugin + premium actions, 70/30 revenue split)
- **Squad Monitor**: TUI dashboard SaaS micro-product (`squad-monitor` repo)
- **GitHub Sponsors, Patreon, Buy Me A Coffee**: Planned community funding
- **Print-on-Demand Merch**: Planned (revenue expansion doc)

### Organizational Split (Important)

| GitHub Org | Purpose | Repos |
|-----------|---------|-------|
| `tamirdresher_microsoft` (EMU) | Enterprise/work repos | tamresearch1, tamresearch1-research, 3 research archives |
| `tamirdresher` (personal) | Product/venture repos | jellybolt-games, brainrot-quiz-battle, code-conquest, bounce-blitz, idle-critter-farm, techai-explained, devtools-pro, saas-finder-hub, squad-skills, squad-monitor |
| `tamirdresher` (personal) | Side projects (NOT enterprise) | kids-squad-setup |

**Rule**: Product/venture repos live on personal GitHub. HQ coordination + research live on Microsoft org.

### HQ as Upstream Squad — Enterprise Governance Model

The HQ repo (`tamresearch1`) is not just a coordinator — it is the **upstream squad** that manages shared knowledge, standards, and policies for ALL sub-companies. This works like a parent company setting policies that all subsidiaries follow.

#### What HQ Pushes Downstream

| Category | What Gets Inherited | Examples |
|----------|-------------------|----------|
| **Security policies** | Mandatory security standards all companies must follow | Secret management rules, auth patterns, credential handling |
| **Legal rules** | Compliance requirements from Decision 15 | Zero legal liability, ToS/privacy policy requirements, COPPA for kids products |
| **Performance reviews** | Shared reflection and improvement processes | Retrospective formats, quality standards, DORA metrics |
| **Secrets management** | Shared credentials and access patterns | Squad email (`td-squad-ai-team@outlook.com`), Gumroad account, API keys |
| **Cross-company protocols** | How companies interact | GitHub issues as coordination protocol, notification rules (Decision 32) |
| **Content production rules** | Brand and publishing standards | Decision 32 rules (no personal names, no static cards, self-publish, brand consistency) |
| **Squad email access** | Shared operational email | All companies can send/receive via squad email for their operational needs |

#### Inheritance Rules

1. **Automatic inheritance:** When a new sub-company is created, it inherits ALL upstream standards from HQ automatically. The company's `.squad/` setup must reference HQ decisions that apply enterprise-wide.
2. **Enterprise-wide decisions:** Decisions marked as `CRITICAL` or `enterprise-wide` in HQ's `decisions.md` apply to ALL sub-companies. Sub-companies cannot override them.
3. **Local decisions:** Sub-companies make their own domain-specific decisions (content calendar, game roadmap, etc.) that do NOT require HQ approval.
4. **Policy push:** When HQ adopts a new enterprise-wide policy, it creates a GitHub issue on EACH sub-company's repo informing them of the new standard.
5. **Shared infrastructure:** Squad email, Gumroad account, Tamir's notification preferences — managed by HQ, used by all.

#### What Sub-Companies Own (NOT inherited)

- Domain-specific backlog, board, and triage
- Agent roster and charters
- Content/product roadmaps
- Execution cadence and priorities
- Domain-specific decisions
- Their own Ralph monitoring config

#### Enterprise-Wide Decisions (Apply to ALL Companies)

These HQ decisions are inherited by every sub-company:

| Decision | Rule | Scope |
|----------|------|-------|
| Decision 15 | Zero legal liability — proper entity, ToS, privacy policy for all ventures | ALL companies |
| Decision 32 | Content production rules — no personal names, self-publish, brand consistency, revenue hooks | ALL content-producing companies |
| Decision 32, Rule 7 | 2FA handling via Teams | ALL companies |
| Decision 32, Rule 8 | Notifications only to Tamir | ALL companies |
| Decision 33 | Enterprise structure, repo isolation, GitHub issues as coordination | ALL companies |

### Architectural Rules (Permanent)

1. **Repo Isolation:** Each sub-company gets its own repo with its own `.squad/` directory. No exceptions.
2. **Full Autonomy:** Each company manages its own issues, backlog, project board, triage, priorities, and execution. No HQ oversight of sub-company operations.
3. **Own Ralph:** Each sub-company runs its own Ralph watching ITS OWN repo only. No cross-repo monitoring.
4. **GitHub Issues = Coordination Protocol:** Cross-company work is done by creating a GitHub issue on the TARGET company's repo. No YAML task files. No centralized routing.
5. **Direct Company-to-Company:** Any company can create issues on any other company's repo. No HQ intermediary required.
6. **Agent Residency:** Agents live in the repo they serve. Content agents → content repo. Game agents → game repo.
7. **New Sub-Company Rule:** When ANY new sub-company or venture is created, it MUST get its own repo with its own Squad. This is a **permanent enterprise rule** that cannot be overridden.
8. **HQ Board = HQ Work Only:** The main repo's board tracks infrastructure, security, and coordination work. Not content calendars, game roadmaps, or sub-company backlogs.
9. **HQ Scope:** Picard, B'Elanna, Data, Worf, Seven, Kes, Q, Neelix, Podcaster, Ralph, Scribe, Troi.
10. **Legal Compliance:** All monetization ventures require proper entity structure, ToS, privacy policy (Decision 15 — zero legal liability).
11. **No YAML for Cross-Company:** The `.squad/cross-machine/tasks/` system is for machine-to-machine coordination WITHIN a single company, not between companies.

### Migration Plan

**Phase 1 — TechAI Content (Priority: HIGH)**
- Create `tamresearch1-content` squad repo (or set up `.squad/` in existing `techai-explained` repo)
- Migrate agents: Guinan, Paris, Geordi, Crusher from HQ
- Link product repos: techai-explained, devtools-pro, saas-finder-hub, blog
- Set up own Ralph, routing, decisions
- Remove migrated agent charters from HQ `.squad/agents/`

**Phase 2 — JellyBolt Games (Priority: HIGH — already operating)**
- Set up `.squad/` directory in `jellybolt-games` HQ repo
- Formalize agent charters for Mario, Sonic, Link, Yoshi, Toad
- jellybolt-ralph already exists — verify it's self-contained
- Link game repos as sub-projects

**Phase 3 — Ventures & IP (Priority: MEDIUM)**
- Create `tamresearch1-ventures` repo
- Design venture-tracking agent roster
- Centralize patent, consulting, SaaS-product tracking

**Phase 4 — Side Projects (NOT enterprise — track separately)**
- `kids-squad-setup` is a personal side project, not an enterprise sub-company
- If it matures into a sellable product, it graduates to the enterprise map and gets its own squad
- Do NOT create enterprise infrastructure (Ralph, routing, cross-company issues) for side projects

### Cross-Company Communication Protocol

**GitHub issues are the universal coordination protocol between companies.** No YAML cross-machine task files. No centralized routing through HQ. Companies create issues directly on each other's repos.

#### Rules

1. **GitHub issues = the coordination protocol.** To request work from another company, create an issue on THEIR repo. Not yours. Not HQ's.
2. **Any company → Any company.** Direct. No HQ intermediary required. TechAI Content can create an issue on JellyBolt's repo and vice versa.
3. **Each Ralph watches ITS OWN repo only.** JellyBolt's Ralph watches jellybolt-games. Content's Ralph watches techai-explained. HQ Ralph watches tamresearch1. No cross-repo monitoring.
4. **Each company owns its own board, backlog, triage, and priorities.** HQ does NOT track sub-company operations. Sub-companies do NOT report status to HQ unless asked via a GitHub issue.
5. **Sub-companies are fully autonomous.** Own triage, own priorities, own execution cadence. HQ has no veto over sub-company backlogs.
6. **Cross-company issue format:** Use label `cross-company` + `from:{source-company}` in the issue body so the receiving company knows who's asking.
7. **No YAML cross-machine task files for cross-company work.** The `.squad/cross-machine/tasks/` system is for machine-to-machine coordination WITHIN a single company, not between companies.
8. **Notifications:** All notifications go to Tamir Dresher only (Decision 32, Rule 8).
9. **Shared context:** Copilot Spaces for cross-repo semantic search when needed.

#### Examples

| Scenario | Action |
|----------|--------|
| HQ needs a blog post about new infra | Create issue on `techai-explained` repo: "Write blog post about X" |
| JellyBolt needs SEO help for itch.io pages | Create issue on content squad HQ repo: "Optimize itch.io SEO for BrainRot" |
| Research finds something content should publish | Create issue on `techai-explained` repo: "Research complete on X — ready for content" |
| Content needs a game trailer for YouTube | Create issue on `jellybolt-games` repo: "Need 30s trailer for BrainRot Quiz Battle" |
| Any company needs Tamir's input | Create issue on the company's OWN repo and tag Tamir |

### Revenue Summary (All Companies)

| Company | Current Revenue | Year 1 Projection | Status |
|---------|----------------|-------------------|--------|
| TechAI Content | $0 | $5K-$30K | YouTube not public; **Gumroad payments ✅ CLEARED** (bank details added) |
| JellyBolt Games | $0 | $100K-$800K | Mobile QA needed; **Gumroad payments ✅ CLEARED** (bank details added) |
| SaaS Finder Hub | $0 | Affiliate commissions | FTC disclosure missing on 25 articles |
| Ventures & IP | $0 | Consulting $200-350/hr | Not formalized |
| **Total** | **$0** | **$105K-$830K+** | **Payment processing UNBLOCKED — Tamir added bank details to Gumroad directly (no Stripe needed)** |

## Rationale

Evidence shows the enterprise is **far more developed** than Decision 23 captured. JellyBolt Games already has 2 live games, its own squad, and its own Ralph. TechAI Content has 4+ product repos, a complete blog series, newsletter infrastructure, and a viral marketing plan. The Research Institute has been operating independently for weeks. Formalizing this structure ensures each company can scale without cross-contamination, and the HQ can coordinate without becoming a bottleneck.

## Impact

- All squad members must respect cross-company routing
- Content tasks → TechAI Content repos (personal GitHub)
- Gaming tasks → JellyBolt repos (personal GitHub)
- Research tasks → Research Institute (MS org)
- Ventures/IP tasks → Ventures repo (to be created)
- HQ handles: infrastructure, security, governance, upstream policy, cross-cutting concerns
- **Gumroad payment processing UNBLOCKED** — Tamir added bank details directly (Stripe not needed)
- Remaining revenue blockers: YouTube channel not public, mobile QA for JellyBolt, FTC disclosures for SaaS Finder Hub

