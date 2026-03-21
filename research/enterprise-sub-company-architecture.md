# Enterprise Sub-Company Architecture — Repo Isolation & Migration Plan

**Decision Number:** 33  
**Supersedes:** Decision 23  
**Date:** March 2026  
**Author:** Picard (Lead) — synthesized by Seven (Research & Docs)  
**Priority:** Critical  
**Issue:** #907  
**Method:** Full audit of all 32+ decisions, revenue reports, cross-machine task configs, agent charters, issue history, and all repos

---

## Table of Contents

1. [Executive Summary — 6-Company Status Table](#1-executive-summary)
2. [Enterprise Map — Full Inventory](#2-enterprise-map)
3. [Isolation Boundaries — What Lives Where](#3-isolation-boundaries)
4. [Migration Plan — 4 Phases](#4-migration-plan)
5. [Cost/Benefit Analysis](#5-costbenefit-analysis)
6. [NOW vs DEFER Action Table](#6-now-vs-defer-action-table)
7. [Permanent Enterprise Rules](#7-permanent-enterprise-rules)
8. [Decision Record — Decision 33 Supersedes Decision 23](#8-decision-record)
9. [Critical Finding — Stripe Connection Gap](#9-critical-finding-stripe-not-connected)

---

## 1. Executive Summary

Six sub-companies exist in the enterprise today. Four are operational, one is mid-formation, and one is approved-but-deferred. Combined annual revenue potential exceeds $150k/yr once blockers are resolved. The **single largest blocker** is a 15-minute Stripe connection task that currently prevents all monetization across two active companies.

### 6-Company Status Table

| # | Sub-Company | GitHub Account | Primary Repo | Squad Status | Revenue (Current) | Year 1 Target | Critical Blocker |
|---|-------------|---------------|-------------|-------------|-------------------|---------------|-----------------|
| 1 | **HQ / Coordinator** | `tamirdresher_microsoft` (EMU) | `tamresearch1` | ✅ Full squad — 12 agents, 32+ decisions | $0 (internal) | Coordination | None |
| 2 | **Research Institute** | `tamirdresher_microsoft` (EMU) | `tamresearch1-research` | ✅ Full squad — own agents, own Ralph | $0 (internal) | IP licensing | Patent formalization |
| 3 | **TechAI Content** | `tamirdresher` (personal) | `techai-explained` | 🟡 Agents in HQ, needs `.squad/` migration | $0 | $50k–$80k/yr | YouTube not public + Stripe not connected |
| 4 | **JellyBolt Games** | `tamirdresher` (personal) | `jellybolt-games` | 🟢 Has own squad + Ralph, needs `.squad/` formalized | $0 | $30k–$60k/yr | Stripe not connected + mobile QA |
| 5 | **Ventures & IP** | `tamirdresher` (personal) | Not yet created | ❌ Not started | $0 | $50k+/yr (consulting) | Not formalized |
| 6 | **Kids Squad** | `tamirdresher` (personal) | `kids-squad-setup` | ⏸️ Approved, deferred | $0 | Community-funded | COPPA compliance + activation |

**Key Finding:** `$0 total revenue` despite two live games (BrainRot Quiz Battle, Code Conquest) and five Gumroad products. Root cause: Stripe not connected to Gumroad. Estimated time to fix: **15 minutes**. Estimated annual revenue unlocked: **$20k–$50k+**.

---

## 2. Enterprise Map

### 2.1 GitHub Account Topology

| GitHub Account | Type | Purpose | Repos Owned |
|---------------|------|---------|-------------|
| `tamirdresher_microsoft` | EMU (Enterprise Managed) | Microsoft work + enterprise coordination | tamresearch1, tamresearch1-research, 3 archive repos |
| `tamirdresher` | Personal | Products, ventures, content | jellybolt-games, brainrot-quiz-battle, code-conquest, bounce-blitz, idle-critter-farm, techai-explained, devtools-pro, saas-finder-hub, tamirdresher.github.io, kids-squad-setup, squad-skills, squad-monitor |

### 2.2 Sub-Company 1: HQ / Coordinator

| Item | Value |
|------|-------|
| **Repo** | `tamirdresher_microsoft/tamresearch1` |
| **Role** | Enterprise coordination, shared infrastructure, cross-company routing |
| **Active Agents** | Picard (Lead), Seven (Research/Docs), Worf (Security/Cloud), Belanna (Infrastructure), Data (Code), Kes (Communications), Neelix (News), Troi (Blog/Voice), Scribe (Logger), Ralph (Monitor), Q (Devil's Advocate), Podcaster |
| **Decisions** | 32+ recorded decisions in `.squad/decisions/` |
| **Active Assets** | Squad framework, MCP server configs, agent charters, all `.squad/` tooling |
| **Blockers** | None — operational |

### 2.3 Sub-Company 2: Research Institute

| Item | Value |
|------|-------|
| **Repo** | `tamirdresher_microsoft/tamresearch1-research` + 3 archive repos |
| **Role** | Academic research, white papers, technical analysis, IP development |
| **Active Agents** | Guinan-R (Lead), own research agents |
| **Active Assets** | 8-chapter book drafts, peer-review papers (Hebrew voice cloning), rate limiting research, copilot SDK evaluations |
| **Revenue Path** | Patent licensing, Manning book deal, technical consulting |
| **Blockers** | Patent formalization not started |

### 2.4 Sub-Company 3: TechAI Content

| Item | Value |
|------|-------|
| **HQ Repo** | `tamirdresher/techai-explained` (pending `.squad/` initialization) |
| **Product Repos** | `devtools-pro`, `saas-finder-hub`, `tamirdresher.github.io` |
| **Role** | YouTube content, newsletter, blog, Gumroad digital products, SaaS affiliate reviews |
| **Current Agents (in HQ)** | Guinan (Content Strategy), Paris (Video/Audio), Geordi (SEO/Growth), Crusher (Safety/Brand) |
| **Active Assets** | 4-part "Scaling AI" blog series (published), Kit newsletter landing page (live), 25 SEO-optimized SaaS affiliate articles (82/100 score), 5 Gumroad products + bundle, Azure AI Speech voice pipeline |
| **Revenue Streams** | YouTube AdSense, affiliate commissions (SaaS Finder Hub), Gumroad products ($9–$29), newsletter sponsorships |
| **Blockers** | YouTube channel not set to public; Stripe not connected to Gumroad; FTC affiliate disclosures missing on 25 articles |

### 2.5 Sub-Company 4: JellyBolt Games

| Item | Value |
|------|-------|
| **HQ Repo** | `tamirdresher/jellybolt-games` |
| **Game Repos** | `brainrot-quiz-battle` (LIVE), `code-conquest` (LIVE), `bounce-blitz` (Play Store ready), `idle-critter-farm` (Play Store ready) |
| **Role** | Mobile and browser games — Gen Alpha target audience |
| **Active Agents** | Mario (Lead), Sonic (Dev), Link (Level Design), Yoshi (QA), Toad (Marketing) |
| **Monitor** | `jellybolt-ralph` — dedicated Ralph instance |
| **Active Assets** | 2 live itch.io games, CI/CD pipeline, mobile build system |
| **Revenue Streams** | Itch.io donations/pay-what-you-want, future: Battle Pass, cosmetics, Play Store IAP |
| **Account** | `jellyboltgames` on itch.io / `tdsquadai@gmail.com` |
| **Blockers** | Stripe not connected to Gumroad; mobile QA (PR #814 merged, device verification pending); no cross-game promotion links |

### 2.6 Sub-Company 5: Ventures & IP

| Item | Value |
|------|-------|
| **Repo** | Not yet created |
| **Role** | Patent licensing, technical consulting, Squad-as-SaaS, Squad Monitor product, community funding |
| **Status** | All identified in research, no formal entity yet |
| **Opportunities Identified** | Multi-agent orchestration patent (Issue #42), consulting at $150–$350/hr (Toptal, MentorCruise), Squad-as-SaaS (GitHub Marketplace 70/30 split), Squad Monitor TUI dashboard |
| **Blockers** | No dedicated repo, no lead agent assigned, no formalized pipeline |

### 2.7 Sub-Company 6: Kids Squad

| Item | Value |
|------|-------|
| **Repo** | `tamirdresher/kids-squad-setup` (template ready) |
| **Role** | Youth-focused AI education, WhatsApp/Discord community, coding mentorship |
| **Status** | Design approved (Decision 14), EN+HE blog posts written, deferred pending Tamir activation |
| **Channels Planned** | WhatsApp group, Discord server, newsletter |
| **Blockers** | COPPA compliance (Decision 15), explicit activation required from Tamir |

---

## 3. Isolation Boundaries

### 3.1 What Stays in HQ (`tamresearch1`)

The following assets belong in HQ and must **never** be migrated to sub-company repos:

| Asset | Reason |
|-------|--------|
| `.squad/` framework tooling (routing.md, ceremonies.md) | Cross-company shared infrastructure |
| Picard agent charter | Enterprise-wide lead; coordinates all sub-companies |
| `ralph-watch.ps1` (master config) | Monitors all repos; sub-companies get their own but HQ has the master |
| Security credentials and MCP server configs | Centralized secrets management (Worf domain) |
| Enterprise decisions log (Decisions 1–33) | Historical record of all enterprise decisions |
| Cross-company routing rules | Directs tasks to correct sub-company squad |
| Scribe (Logger) agent | Cross-agent context sharing; must remain central |

### 3.2 What Moves to Sub-Company Repos

| Asset | From | To | When |
|-------|------|----|------|
| Guinan agent charter | HQ `.squad/agents/` | `techai-explained/.squad/agents/` | Phase 1 |
| Paris agent charter | HQ `.squad/agents/` | `techai-explained/.squad/agents/` | Phase 1 |
| Geordi agent charter | HQ `.squad/agents/` | `techai-explained/.squad/agents/` | Phase 1 |
| Crusher agent charter | HQ `.squad/agents/` | `techai-explained/.squad/agents/` | Phase 1 |
| Content-related decisions | HQ `.squad/decisions/` | `techai-explained/.squad/decisions/` | Phase 1 |
| Mario/Sonic/Link/Yoshi/Toad charters | Informal | `jellybolt-games/.squad/agents/` | Phase 2 |
| `jellybolt-ralph` config | Standalone | `jellybolt-games/.squad/monitoring/` | Phase 2 |
| Patent research files | `tamresearch1-research/` | `tamresearch1-ventures/` (new) | Phase 3 |

### 3.3 What Gets Duplicated (Shared Infrastructure)

Some assets need to exist in both HQ and sub-company repos:

| Asset | Reason for Duplication |
|-------|----------------------|
| Squad framework core files (`.squad/README.md`) | Each sub-company is self-contained |
| Ralph monitoring script template | Each company needs independent monitoring |
| `decisions.md` template | Each company has its own decision history |
| Agent charter template | Standard format across all companies |

### 3.4 Isolation Rules

```
RULE 1: Each sub-company's `.squad/` is authoritative for its own domain
RULE 2: HQ `.squad/` is authoritative for cross-company routing
RULE 3: No sub-company agent may issue commands to another sub-company's agents directly
         (all cross-company coordination goes through Picard at HQ)
RULE 4: Revenue decisions (Stripe, pricing, products) require Tamir's approval — no agent autonomy
RULE 5: Security credentials live ONLY in HQ (Worf's domain) — sub-companies get scoped tokens
RULE 6: Content safety (Crusher's veto) is mandatory for all TechAI Content output
```

---

## 4. Migration Plan

### Phase 1: TechAI Content — Initialize Squad Infrastructure
**Priority:** HIGH  
**Effort:** ~8 hours  
**Owner:** Seven (docs scaffolding) + Guinan (content migration)  
**Depends on:** None — can start immediately

#### Steps

| Step | Action | Owner | Effort |
|------|--------|-------|--------|
| 1.1 | Create `techai-explained/.squad/` directory structure | Seven | 30 min |
| 1.2 | Write `team.md` with TechAI Content roster | Seven | 1 hr |
| 1.3 | Write `routing.md` for content domain routing | Guinan | 1 hr |
| 1.4 | Write `decisions.md` with content-specific decisions | Seven | 1 hr |
| 1.5 | Write `ceremonies.md` for content team rituals | Seven | 30 min |
| 1.6 | Migrate Guinan agent charter from HQ | Guinan | 30 min |
| 1.7 | Migrate Paris agent charter from HQ | Paris | 30 min |
| 1.8 | Migrate Geordi agent charter from HQ | Geordi | 30 min |
| 1.9 | Migrate Crusher agent charter from HQ | Crusher | 30 min |
| 1.10 | Set up `ralph-watch.ps1` for content repos | Ralph | 1 hr |
| 1.11 | Update HQ `team.md` — mark agents as migrated to TechAI | Picard | 15 min |
| 1.12 | Add cross-company pointer in HQ `routing.md` | Picard | 15 min |
| 1.13 | **Fix FTC affiliate disclosures on all 25 SaaS articles** | Geordi | 2 hr |
| 1.14 | **Connect Stripe to Gumroad** ← 15-MIN CRITICAL FIX | Tamir | 15 min |
| 1.15 | Set YouTube channel to public | Tamir | 10 min |
| 1.16 | Verify Kit newsletter landing page is active | Guinan | 15 min |

**Success Criteria:**
- `techai-explained/.squad/` directory exists with all 5 core files
- All 4 content agents have charters in sub-company repo
- HQ `team.md` reflects migration
- Stripe connected → first revenue possible
- FTC disclosures on all 25 articles

---

### Phase 2: JellyBolt Games — Formalize Squad Structure
**Priority:** HIGH (already operating, needs documentation)  
**Effort:** ~6 hours  
**Owner:** Mario (lead), Yoshi (QA), Data (mobile dev)  
**Depends on:** None — independent of Phase 1

#### Steps

| Step | Action | Owner | Effort |
|------|--------|-------|--------|
| 2.1 | Create `jellybolt-games/.squad/` directory structure | Seven | 30 min |
| 2.2 | Formalize Mario agent charter | Mario | 1 hr |
| 2.3 | Formalize Sonic, Link, Yoshi, Toad charters | Each agent | 1 hr total |
| 2.4 | Write `jellybolt-games/.squad/decisions.md` with game decisions | Mario | 1 hr |
| 2.5 | Migrate `jellybolt-ralph` config into `.squad/monitoring/` | Ralph | 30 min |
| 2.6 | Link game repos (brainrot, code-conquest, bounce-blitz, idle-critter) | Belanna | 30 min |
| 2.7 | **QA mobile black screen fix (PR #814)** — device verification | Yoshi | 2 hr |
| 2.8 | Add cross-game promotion links on both itch.io pages | Toad | 1 hr |
| 2.9 | Optimize itch.io SEO tags (beyond "Puzzle, Free") | Geordi | 30 min |
| 2.10 | Prepare Play Store submissions for bounce-blitz | Data | 3 hr |
| 2.11 | Prepare Play Store submissions for idle-critter-farm | Data | 3 hr |
| 2.12 | Set up cross-promotion: YouTube ↔ itch.io ↔ Gumroad | Toad | 1 hr |

**Success Criteria:**
- `jellybolt-games/.squad/` fully initialized
- All 5 JellyBolt agents have formal charters
- Mobile QA verified on iPhone + Android (both orientations)
- Both Play Store submissions prepared
- Cross-game promotion active

---

### Phase 3: Ventures & IP — Create and Initialize
**Priority:** MEDIUM  
**Effort:** ~10 hours (new repo creation + content)  
**Owner:** Picard (strategy), Seven (docs)  
**Depends on:** Phase 1 and Phase 2 progress tracked; partial overlap acceptable

#### Steps

| Step | Action | Owner | Effort |
|------|--------|-------|--------|
| 3.1 | Create `tamresearch1-ventures` repo (or `tamirdresher/ventures`) | Tamir | 10 min |
| 3.2 | Design venture agent roster (CFO-type lead + specialists) | Picard | 2 hr |
| 3.3 | Initialize `.squad/` for Ventures & IP | Seven | 2 hr |
| 3.4 | Migrate patent research docs from Research Institute | Seven | 1 hr |
| 3.5 | Set up consulting pipeline tracker | Picard | 1 hr |
| 3.6 | Register `squad-monitor` as formal product | Data | 1 hr |
| 3.7 | Register `squad-skills` as formal product | Data | 1 hr |
| 3.8 | Set up GitHub Sponsors application | Tamir | 30 min |
| 3.9 | Set up Patreon or Buy Me A Coffee | Tamir | 30 min |
| 3.10 | Draft Squad-as-SaaS GitHub Marketplace proposal | Picard/Seven | 3 hr |
| 3.11 | Document consulting rates ($150–$350/hr) and platforms | Seven | 1 hr |
| 3.12 | File provisional patent application research | Seven | 3 hr |

**Success Criteria:**
- `tamresearch1-ventures` repo exists with `.squad/` initialized
- Patent research formally consolidated
- At least one community funding channel active (GitHub Sponsors or Patreon)
- Squad-as-SaaS concept documented as a formal proposal

---

### Phase 4: Kids Squad — Activate When Ready
**Priority:** LOW (deferred by Tamir decision)  
**Effort:** ~8 hours (mostly compliance and content)  
**Owner:** TBD (requires new kid-friendly agents)  
**Depends on:** Explicit activation from Tamir + COPPA compliance verified

#### Steps

| Step | Action | Owner | Effort |
|------|--------|-------|--------|
| 4.1 | Tamir: explicit activation decision recorded | Tamir | — |
| 4.2 | COPPA compliance review and legal checklist | Worf | 2 hr |
| 4.3 | Activate `kids-squad-setup` repo with full `.squad/` | Seven | 2 hr |
| 4.4 | Design kid-friendly agent roster (ages 10–16) | Picard | 2 hr |
| 4.5 | Set up WhatsApp notification channel | Kes | 30 min |
| 4.6 | Set up Discord server | Kes | 1 hr |
| 4.7 | Publish EN + HE blog posts about Kids Squad | Troi | 1 hr |
| 4.8 | Set up COPPA-compliant registration/consent flow | Data | 3 hr |
| 4.9 | Establish parental consent and data handling policies | Worf | 2 hr |
| 4.10 | Launch with pilot group (max 10 kids initially) | TBD | — |

**Success Criteria:**
- COPPA compliance documented and verified
- Discord + WhatsApp channels operational
- At least 5 enrolled participants in pilot

---

## 5. Cost/Benefit Analysis

### 5.1 Isolation Decision: TechAI Content Gets Own Repo/Squad

| Factor | Analysis |
|--------|----------|
| **Cost** | ~8 hours setup time, agent migration effort, potential context loss during transition |
| **Benefit** | Dedicated routing means content work doesn't interfere with HQ research tasks; Guinan can make content decisions autonomously; Ralph monitors content-specific KPIs |
| **Risk** | Context loss if migration not done carefully; need to maintain cross-company links |
| **ROI** | HIGH — unlocks $50k–$80k/yr revenue path once Stripe + YouTube unblocked |
| **Verdict** | **DO IT — Phase 1** |

### 5.2 Isolation Decision: JellyBolt Gets Formal `.squad/` Structure

| Factor | Analysis |
|--------|----------|
| **Cost** | ~6 hours to formalize existing informal setup |
| **Benefit** | Mario/Sonic/Link/Yoshi/Toad operate with clear charters; `jellybolt-ralph` has official home; cross-company coordination is documented |
| **Risk** | Low — squad already operating; this is documentation/formalization only |
| **ROI** | HIGH — already live, just needs structure; Play Store + Stripe = $30k–$60k/yr potential |
| **Verdict** | **DO IT — Phase 2 (parallel with Phase 1)** |

### 5.3 Isolation Decision: Ventures & IP Gets Own Repo

| Factor | Analysis |
|--------|----------|
| **Cost** | ~10 hours; requires new agent persona design |
| **Benefit** | Patent, consulting, SaaS product, and community funding all tracked in one place; clear ownership |
| **Risk** | Medium — needs right agent personas; CFO-type thinking required |
| **ROI** | MEDIUM-HIGH — consulting alone worth $150–$350/hr × available hours |
| **Verdict** | **DO IT — Phase 3** |

### 5.4 Isolation Decision: Kids Squad Deferred

| Factor | Analysis |
|--------|----------|
| **Cost** | Deferred opportunity cost only |
| **Benefit** | Avoiding premature complexity; COPPA compliance takes time to do right |
| **Risk** | Low — template ready; can activate in 1 day when needed |
| **ROI** | UNKNOWN — community/educational; non-revenue focus initially |
| **Verdict** | **DEFER — Phase 4 (Tamir activation required)** |

### 5.5 Cost of NOT Isolating (Status Quo Risk)

| Risk | Probability | Impact |
|------|-------------|--------|
| HQ squad overwhelmed with cross-domain tasks | HIGH | HIGH — already happening |
| Guinan making content decisions that affect enterprise routing | MEDIUM | HIGH |
| JellyBolt-Ralph config lost or corrupted (no `.squad/` home) | MEDIUM | MEDIUM |
| Patent research mixed with entertainment content | LOW | MEDIUM |
| Revenue opportunities missed due to routing confusion | HIGH | CRITICAL |

**Bottom line:** Status quo costs an estimated $20k–$50k/yr in delayed revenue realization and agent inefficiency.

---

## 6. NOW vs DEFER Action Table

### Immediate (This Week — Unblocks Revenue)

| Action | Who | Time | Revenue Impact |
|--------|-----|------|----------------|
| 🔴 **Connect Stripe to Gumroad** | Tamir (manual) | **15 min** | Unblocks ALL monetization |
| 🔴 **Set YouTube channel to public** | Tamir (manual) | 10 min | Unblocks AdSense revenue |
| 🟠 **Fix FTC disclosures on 25 SaaS articles** | Geordi | 2 hr | Compliance + affiliate activation |
| 🟠 **Verify mobile QA for BrainRot Quiz Battle** | Yoshi + Data | 2 hr | Majority of mobile players unblocked |
| 🟡 Initialize `techai-explained/.squad/` | Seven | 3 hr | Operational clarity |
| 🟡 Formalize `jellybolt-games/.squad/` | Mario/Seven | 3 hr | Agent autonomy unlocked |

### Short-Term (This Sprint — Foundation Building)

| Action | Who | Time | Value |
|--------|-----|------|-------|
| Migrate TechAI Content agents from HQ | Guinan/Seven | 4 hr | Clear domain separation |
| Add cross-game promotion (itch.io) | Toad | 1 hr | +20% organic discovery |
| Optimize itch.io SEO tags | Geordi/Toad | 30 min | Searchability improvement |
| Set up Kit newsletter autoresponder | Guinan/Paris | 1 hr | Lead nurture automation |
| Prepare Play Store submissions (bounce-blitz) | Data | 3 hr | New revenue channel |
| Create Ventures & IP repo skeleton | Picard/Seven | 2 hr | IP protection starts now |

### Medium-Term (Next 2–4 Weeks)

| Action | Who | Time | Value |
|--------|-----|------|-------|
| Submit provisional patent application | Picard/Tamir | 3–5 days | IP protection for multi-agent orchestration |
| Launch idle-critter-farm on Play Store | Data/Yoshi | 1 wk | Revenue diversification |
| Publish YouTube video series (TechAI) | Paris | ongoing | Channel monetization |
| Set up GitHub Sponsors | Tamir | 30 min | Community funding |
| Squad-as-SaaS GitHub Marketplace proposal | Picard | 3 hr | New B2B revenue stream |

### Deferred (Do Not Start)

| Action | Reason for Deferral |
|--------|---------------------|
| Kids Squad activation | Requires Tamir explicit approval + COPPA work |
| Print-on-demand merch setup | Low ROI relative to current blockers |
| Discord community management | Premature until audience > 1,000 |
| Book formal publishing deal (Manning) | Research phase ongoing; need complete draft first |
| Squad Monitor commercial launch | Product needs more polish |

---

## 7. Permanent Enterprise Rules

These rules are permanent and cannot be overridden by any agent or decision:

### Rule 1: Sub-Company Isolation (PERMANENT)
> **When ANY new sub-company or venture is created, it MUST get its own repo with its own Squad, its own `.squad/` directory, its own Ralph monitoring, and its own decision log. No exceptions.**

### Rule 2: GitHub Account Separation (PERMANENT)
> **Enterprise/work assets stay on `tamirdresher_microsoft` (EMU). Products/ventures stay on `tamirdresher` (personal). Cross-account access must be explicitly approved by Tamir and documented.**

### Rule 3: Revenue Authorization (PERMANENT)
> **No agent may make pricing decisions, change product listings, or authorize purchases/charges without explicit Tamir approval. Stripe, Gumroad, App Store, and Play Store decisions require human sign-off.**

### Rule 4: Content Safety Gate (PERMANENT)
> **All TechAI Content output (YouTube videos, blog posts, newsletters, Gumroad products) must pass Crusher's safety review before publication. Crusher's veto is final and cannot be overridden by any other agent — only Tamir can override Crusher.**

### Rule 5: Cross-Company Coordination (PERMANENT)
> **No sub-company agent may directly command agents in another sub-company. All cross-company work requests route through Picard at HQ. This prevents coordination conflicts and maintains clear authority chains.**

### Rule 6: COPPA Compliance (PERMANENT — Kids Squad)
> **The Kids Squad must never launch without documented COPPA compliance review completed by Worf. No exceptions, no "we'll fix it later." Decision 15 is permanent and binding.**

### Rule 7: Secrets Management (PERMANENT)
> **API keys, tokens, and credentials live only in HQ (Worf's domain) or in designated secure vaults. Sub-companies receive scoped, read-limited tokens. No full credentials in sub-company repos.**

### Rule 8: Agent Charter Required (PERMANENT)
> **Every agent operating in any sub-company must have a written charter in `.squad/agents/{name}/charter.md` before making autonomous decisions. Charter must include: role, authority, autonomy bounds, and escalation rules.**

---

## 8. Decision Record

### Decision 33 — Enterprise Sub-Company Architecture (This Decision)

**Status:** ACTIVE  
**Date:** March 2026  
**Author:** Picard (Lead), synthesized by Seven (Research & Docs)  
**Supersedes:** Decision 23

**What Decision 23 Said:**  
Decision 23 established a preliminary enterprise structure with 3 companies (HQ, JellyBolt, TechAI Content) and identified migration needs but lacked specifics on isolation boundaries, migration phases, and cost/benefit analysis.

**Why Decision 33 Supersedes It:**  
This decision is evidence-based (full audit of all 32+ decisions, revenue reports, cross-machine configs, agent histories, and all repos). It:
1. Expands the enterprise map from 3 to 6 sub-companies with evidence
2. Defines concrete isolation boundaries for every asset
3. Provides a 4-phase migration plan with specific steps, owners, and effort estimates
4. Adds cost/benefit analysis for each isolation decision
5. Identifies the critical Stripe revenue blocker (new finding not in Decision 23)
6. Establishes 8 permanent enterprise rules (Decision 23 had 1 rule)
7. Creates a NOW vs DEFER action table with revenue impact estimates

**Files Updated or Created:**
- `research/enterprise-sub-company-architecture.md` — this document (comprehensive, evidence-based)
- `.squad/decisions/inbox/seven-907-enterprise-arch.md` — decision record for team inbox

---

## 9. Critical Finding — Stripe Not Connected

### The Finding

> **Stripe is not connected to Gumroad. This is a 15-minute manual task that blocks ALL monetization across two active sub-companies.**

### Impact Analysis

| Company | What's Blocked | Revenue at Stake |
|---------|---------------|-----------------|
| **JellyBolt Games** | Battle Pass ($2.99), cosmetic items, future Play Store IAP | ~$15k–$30k/yr |
| **TechAI Content** | .NET cheatsheets ($9–$19), code templates ($15–$29), bundle ($29) | ~$10k–$25k/yr |
| **Combined** | All Gumroad-based revenue | **$25k–$55k/yr potential** |

### The Fix

```
1. Navigate to: https://app.gumroad.com/settings/payments
2. Log in as: td-squad-ai-team@outlook.com
3. Connect Stripe account (or create one if not exists)
4. Verify bank account details
5. Test with a $1 dummy product purchase
6. Confirm payout settings
```

**Estimated time:** 15 minutes for an account that already exists, 30 minutes if Stripe account needs creation.

### Why This Wasn't Fixed Earlier

The Stripe/Gumroad connection task was identified in multiple reports (Revenue Readiness Report, JellyBolt squad status, TechAI Content blocker analysis) but was consistently categorized as "infrastructure" and routed away from agents who couldn't execute it. This document **explicitly flags it as a human task for Tamir** with the highest priority.

### Action Required

**This is the single highest-priority action in this entire document.**

```
ASSIGNED TO: Tamir Dresher (human only — agent cannot execute payment setup)
DEADLINE: Before any other Phase 1 or Phase 2 work begins
TIME: 15 minutes
GUMROAD URL: https://app.gumroad.com/settings/payments
ACCOUNT: td-squad-ai-team@outlook.com
REVENUE UNLOCKED: $25k–$55k/yr potential across JellyBolt + TechAI Content
```

---

## Appendix A: Repository Quick Reference

| Repo | Account | Squad | Active | Revenue |
|------|---------|-------|--------|---------|
| `tamresearch1` | EMU | HQ Squad (12 agents) | ✅ | $0 (internal) |
| `tamresearch1-research` | EMU | Research Squad | ✅ | $0 (IP pipeline) |
| `tamresearch1-ventures` | EMU or personal | TBD | ❌ Not created | $0 (target: $50k) |
| `jellybolt-games` | Personal | JellyBolt Squad (5) | ✅ | $0 (Stripe blocker) |
| `brainrot-quiz-battle` | Personal | JellyBolt (product) | ✅ | $0 |
| `code-conquest` | Personal | JellyBolt (product) | ✅ | $0 |
| `bounce-blitz` | Personal | JellyBolt (product) | 🟡 | $0 (Play Store ready) |
| `idle-critter-farm` | Personal | JellyBolt (product) | 🟡 | $0 (Play Store ready) |
| `techai-explained` | Personal | TechAI Squad (pending) | 🟡 | $0 (YouTube + Stripe) |
| `devtools-pro` | Personal | TechAI (product) | 🟡 | $0 (Gumroad products) |
| `saas-finder-hub` | Personal | TechAI (product) | 🟡 | $0 (FTC + Stripe) |
| `tamirdresher.github.io` | Personal | TechAI (blog) | ✅ | $0 (affiliate links) |
| `kids-squad-setup` | Personal | Kids Squad (deferred) | ⏸️ | $0 |
| `squad-skills` | Personal | Ventures product | 🟡 | $0 (potential SaaS) |
| `squad-monitor` | Personal | Ventures product | 🟡 | $0 (potential SaaS) |

---

## Appendix B: Agent Roster by Sub-Company

### HQ (tamresearch1) — Shared Infrastructure
- **Picard** — Lead, enterprise coordination
- **Seven** — Research & Docs
- **Worf** — Security & Cloud
- **Belanna** — Infrastructure (K8s, Helm, ArgoCD)
- **Data** — Code (C#, Go, .NET)
- **Kes** — Communications & Scheduling
- **Neelix** — News Reporter
- **Troi** — Blog & Voice Writer
- **Scribe** — Session Logger
- **Ralph** — Work Monitor
- **Q** — Devil's Advocate & Fact Checker
- **Podcaster** — Audio Content

### TechAI Content (techai-explained) — Post-Migration
- **Guinan** — Content Lead/Strategy
- **Paris** — Video/Audio Production
- **Geordi** — SEO/Growth
- **Crusher** — Safety/Brand (veto power)

### JellyBolt Games (jellybolt-games) — Post-Formalization
- **Mario** — Studio Lead
- **Sonic** — Game Development
- **Link** — Level Design
- **Yoshi** — QA/Testing
- **Toad** — Marketing

### Research Institute (tamresearch1-research)
- **Guinan-R** — Research Lead
- Research-specific agents (own charter)

### Ventures & IP (TBD) — Phase 3
- Lead agent TBD (CFO-type persona recommended)
- IP specialist agent TBD
- Community/monetization agent TBD

---

## Appendix C: Revenue Timeline Projection

| Month | Milestone | Expected Revenue |
|-------|-----------|-----------------|
| Week 1 | Stripe connected + YouTube public | $0 → first sales possible |
| Month 1 | FTC disclosures fixed + both itch.io games cross-promoting | $200–$500 |
| Month 2 | Play Store: bounce-blitz + idle-critter-farm live | $500–$1,500 |
| Month 3 | TechAI newsletter → 500 subscribers, affiliate links active | $1,000–$3,000 |
| Month 6 | YouTube monetization threshold hit (1,000 subs / 4,000 hrs) | $2,000–$5,000/mo |
| Year 1 | Full portfolio active | **$50k–$140k** |

*Note: These are projections based on industry benchmarks for similar content/game portfolios. Not guaranteed. Actual results depend on execution quality, Tamir's direct involvement in content approval, and market conditions.*

---

*Document prepared by: Seven (Research & Docs)*  
*Issue: #907*  
*Branch: squad/907-enterprise-arch-v2-TAMIRDRESHER*  
*Last updated: March 2026*
