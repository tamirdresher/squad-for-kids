# 💰 Monetization Quick-Wins Checklist: Unlock Revenue NOW

> **Issue:** [#908](https://github.com/tamirdresher_microsoft/tamresearch1/issues/908)  
> **Prepared by:** Seven (Research & Docs)  
> **Date:** March 2026  
> **Scope:** JellyBolt Games (itch.io) · Gumroad · Blog (tamirdresher.github.io) · YouTube  
> **Status:** All revenue currently $0 — fixable within days

---

## How to Use This Document

Open the checklist. Start at the top. Work down.  
Each item is ordered by **impact × ease** — the fastest path to actual money.  
Dependencies are called out explicitly so you don't hit a wall mid-task.

---

## Section 1: Current Revenue Status

### What Is Live

| Property | Status | Earning? | Notes |
|----------|--------|----------|-------|
| **itch.io — BrainRot Quiz Battle** | ✅ Live, playable | ❌ $0 | Free, no payment path configured |
| **itch.io — Code Conquest** | ✅ Live, playable | ❌ $0 | Free, no payment path configured |
| **itch.io — 14 other games** | ⚠️ Built, NOT published | ❌ $0 | In `jellybolt-games/games/` — never uploaded to itch.io |
| **Gumroad account** | ✅ Account exists | ❌ $0 | Stripe NOT connected — cannot accept any payment |
| **Blog (tamirdresher.github.io)** | ✅ Live | ❌ $0 | No email list, no affiliate links, no product CTAs |
| **YouTube channel** | ⚠️ Status unclear | ❌ $0 | 50+ lectures ready, not published |
| **Rx.NET in Action book** | ✅ Published (Manning) | ❓ Unknown | Affiliate links not configured on blog |
| **ConvertKit / Email list** | ❌ Not set up | ❌ $0 | Account not created |
| **Affiliate programs** | ❌ Not enrolled | ❌ $0 | Amazon Associates, JetBrains, GitHub not joined |

### Current Revenue: **$0/month across all properties**

---

## Section 2: Blocked Revenue

Items that would generate money immediately if unblocked — ordered by estimated monthly impact.

### 🔴 BLOCKER 1 — Stripe Not Connected to Gumroad
**Blocked Revenue:** ~$200–$2,000/month (once payment flows)  
**Why It's Blocked:** Gumroad account exists but Stripe is not connected. No payment can be accepted anywhere — itch.io tip jar, Gumroad products, nothing.  
**Fix Time:** 15–30 minutes  
**What You Need:** Browser, Gumroad login (`tdsquadai@gmail.com`), and a Stripe account (may need to create one — takes 5 minutes with basic identity info)  
**URL:** https://app.gumroad.com/settings/payments  

---

### 🔴 BLOCKER 2 — 14 Games Built But Not Published
**Blocked Revenue:** $50–$500/month (Pay What You Want tipping, Dungeon Bolt $2.99 sales)  
**Why It's Blocked:** The full catalog of 16 games is built and ready in `jellybolt-games/games/`. Only 2 are published to itch.io. Dungeon Bolt ($2.99 premium) and 4 Pay What You Want games are sitting on disk earning nothing.  
**Fix Time:** 1–2 hours to publish all remaining games  
**Key games to prioritize:**

| Game | Price | Priority | Why |
|------|-------|----------|-----|
| **Dungeon Bolt** | $2.99 | 🔴 CRITICAL | Only paid game — actual revenue per download |
| **Rhythm Tap** | $2 suggested | 🟠 HIGH | Highest PWYW price point |
| **Neon Snake** | $1 suggested | 🟡 MEDIUM | Familiar genre, high conversion |
| **Asteroid Dash** | $1 suggested | 🟡 MEDIUM | Classic genre |
| **Hex Match** | $1 suggested | 🟡 MEDIUM | Puzzle audience |
| Remaining 9 | Free | 🟢 LOW | Builds catalog and profile strength |

---

### 🔴 BLOCKER 3 — Mobile Black Screen (BrainRot Quiz Battle)
**Blocked Revenue:** Majority of Gen Alpha plays on mobile. Black screen = 0% conversion on mobile visitors.  
**Status:** Code fix merged (PRs #801, #814) — needs QA on real device.  
**Fix Time:** 2–4 hours (device testing, not coding)  
**What You Need:** iPhone 12+ OR Android device (Samsung Galaxy recommended), test both landscape/portrait  
**Impact:** Mobile players are the primary audience for Gen Alpha casual games. This blocks the highest-traffic audience segment.

---

### 🟠 BLOCKER 4 — itch.io Pages Not Optimized (No Monetization Funnel)
**Blocked Revenue:** $100–$500/month in tip jar + traffic leakage to Gumroad/blog  
**Why It's Blocked:** Both live game pages are missing:
- PWYW ("Name Your Price") tip jar not enabled
- No cross-game links (each game is siloed)
- No Gumroad/support links
- Limited tags ("Puzzle, Free" only — should have 10+ tags each)
- No link to YouTube or blog  

**Fix Time:** 20–30 minutes per game page (manual, requires itch.io dashboard login)

---

### 🟠 BLOCKER 5 — Blog Has No Email Capture or Monetization CTAs
**Blocked Revenue:** $200–$1,000/month (email list + affiliate + product sales)  
**Why It's Blocked:** Blog exists and has traffic from existing posts, but:
- No ConvertKit/email signup form
- No affiliate links on existing posts (Rx.NET in Action, GitHub Copilot, Azure)
- No "Products" or "Support" page
- No lead magnets published  
**Fix Time:** 2–3 hours to set up ConvertKit + add first form + create affiliate account

---

### 🟠 BLOCKER 6 — YouTube Not Publishing
**Blocked Revenue:** $500–$2,000/month (ads + Gumroad cross-sell) by Month 3  
**Why It's Blocked:** 50+ lectures exist. Voice cloning tech is proven. Scripts are ready. But:
- YouTube channel public status unconfirmed
- Script approval workflow undefined
- No publishing schedule set  
**Fix Time:** 1 hour to confirm channel status + define approval workflow + queue first 5 videos

---

## Section 3: Quick Wins Checklist

> **Ordered by: Revenue Impact × Ease of completion**  
> Items marked 🔑 require Tamir's identity — agents can't complete them.

---

### 🏆 TIER 1 — Do Today (Revenue Unblocked in Hours)

- [ ] **🔑 Connect Stripe to Gumroad**  
  - Go to: https://app.gumroad.com/settings/payments  
  - Click "Connect with Stripe" (or "Add payment method")  
  - Create Stripe account if needed: https://stripe.com/  
  - Identity verification: your legal name, address, bank account or debit card  
  - ⏱️ Time: 15–30 min  
  - 💰 Impact: Unlocks ALL payment processing — this is the single most important step  
  - 🔗 Dependency: None — do this first  

- [ ] **🔑 Enable PWYW ("Name Your Price") on BrainRot Quiz Battle and Code Conquest**  
  - Log into: https://itch.io/dashboard → select each game → Edit  
  - Set pricing to "No minimum" with suggested amount of $1–$2  
  - Add a "Support JellyBolt Games" note in the game description  
  - ⏱️ Time: 10 min  
  - 💰 Impact: $20–$200/month from players who want to tip  
  - 🔗 Dependency: Stripe must be connected to Gumroad first (above)  

- [ ] **🔑 Publish Dungeon Bolt ($2.99) to itch.io**  
  - Game is in: `jellybolt-games/games/dungeon-bolt/`  
  - Upload HTML file to itch.io → set price to $2.99 (fixed)  
  - Add description, tags (Roguelite, RPG, Dungeon Crawler, HTML5, Browser)  
  - ⏱️ Time: 20–30 min  
  - 💰 Impact: First paid game = direct revenue per download  
  - 🔗 Dependency: Stripe/Gumroad connected  

---

### 🥈 TIER 2 — Do This Week (High impact, manageable effort)

- [ ] **🔑 QA mobile black screen fix on real device**  
  - Test BrainRot Quiz Battle on: iPhone 12+ and/or Android (Samsung Galaxy)  
  - Test both landscape and portrait mode  
  - Test on cellular (4G/LTE), not just WiFi  
  - If working → deploy to production immediately  
  - If broken → escalate to Data agent  
  - ⏱️ Time: 1–2 hours  
  - 💰 Impact: Unlocks mobile traffic (majority of Gen Alpha audience)  

- [ ] **🤖 Optimize BrainRot Quiz Battle itch.io page**  
  - Add cross-promotion link: "Also try Code Conquest →"  
  - Add tags: Brain game, quiz, educational, trivia, multiplayer, web game, casual, HTML5, browser, free  
  - Add link to JellyBolt Gumroad page  
  - Add YouTube channel link (once confirmed live)  
  - Add "From JellyBolt Games — more games at jellyboltgames.itch.io"  
  - ⏱️ Time: 15 min  
  - 💰 Impact: Better discoverability + funnel to other revenue  

- [ ] **🤖 Optimize Code Conquest itch.io page**  
  - Mirror the above: add cross-promotion, tags, external links  
  - Add tags: Strategy, turn-based, territory control, coding theme, HTML5, browser, free  
  - ⏱️ Time: 15 min  
  - 💰 Impact: Better SEO discovery from itch.io search  

- [ ] **🤖 Create JellyBolt Games collection on itch.io**  
  - Go to: https://itch.io/dashboard/collections  
  - Create collection: "JellyBolt Games — All Games"  
  - Add both published games  
  - Link to collection from each game page  
  - ⏱️ Time: 10 min  
  - 💰 Impact: Increases profile visibility and cross-game discovery  

- [ ] **🔑 Sign up for ConvertKit (email list)**  
  - URL: https://convertkit.com (free up to 10K subscribers)  
  - Use your personal or professional email  
  - Create one signup form: "Get my AI Agent Architecture cheatsheet"  
  - Add embed code to blog sidebar/post footer  
  - Lead magnet PDF is ready in: `research/active/monetization-strategy/lead-magnets/`  
  - ⏱️ Time: 30–45 min  
  - 💰 Impact: Email list is your most durable revenue asset — start building it now  

- [ ] **🔑 Sign up for Amazon Associates**  
  - URL: https://affiliate-program.amazon.com/  
  - Add affiliate link to "Rx.NET in Action" book on blog  
  - Add affiliate link to tech books you reference in posts  
  - ⏱️ Time: 20 min + 1–3 day approval  
  - 💰 Impact: Passive income on book/tool recommendations  

- [ ] **🤖 Publish Rhythm Tap, Neon Snake, Asteroid Dash, Hex Match to itch.io**  
  - Upload HTML files from `jellybolt-games/games/`  
  - Set as "Pay What You Want" with suggested prices from GAMES_CATALOG.md  
  - Add descriptions and tags for each game  
  - ⏱️ Time: 45 min total  
  - 💰 Impact: Expands monetized catalog, increases profile strength  

---

### 🥉 TIER 3 — Do This Week (Medium impact, less urgent)

- [ ] **🤖 Publish remaining 9 free games to itch.io**  
  - Bounce Blitz, Memory Matrix, Pixel Tower, Word Rush, Gravity Dash, Card Clash, Light Trail, Bolt Breaker, Space Trader  
  - Upload from `jellybolt-games/games/`  
  - Add proper tags and descriptions  
  - ⏱️ Time: 1–2 hours  
  - 💰 Impact: Expands catalog, improves profile discoverability, drives traffic to paid titles  

- [ ] **🔑 Confirm YouTube channel is public and monetization-eligible**  
  - Check: is the channel public? (not set to private/unlisted)  
  - Check: how many subscribers and watch hours? (need 1,000 subs + 4,000 hours for ads)  
  - If not at threshold: focus on Gumroad cross-sell strategy (more immediate)  
  - ⏱️ Time: 10 min  
  - 💰 Impact: Unblocks content pipeline planning  

- [ ] **🤖 Add Gumroad product links to blog posts**  
  - Add relevant product CTAs at the bottom of existing blog posts  
  - Example: .NET posts → link to .NET cheatsheet  
  - Example: AI Squad posts → link to "Build Your AI Squad in 30 Minutes" guide  
  - ⏱️ Time: 1 hour  
  - 💰 Impact: Blog traffic → Gumroad sales conversion  

- [ ] **🔑 Create "Products" or "Support" page on blog**  
  - List: books, digital guides, courses, recommended tools  
  - Include: affiliate links, Gumroad links  
  - Add to blog navigation  
  - ⏱️ Time: 1 hour  
  - 💰 Impact: Evergreen revenue page  

- [ ] **🔑 Apply for JetBrains affiliate program**  
  - URL: https://www.jetbrains.com/company/partnerships/affiliate/  
  - Describe developer/AI audience  
  - ⏱️ Time: 15 min (3–7 day approval)  
  - 💰 Impact: Passive income from IDE referrals  

---

## Section 4: Medium-Term Plays (3–30 Days)

### Week 2: Content & Publishing

| Action | Owner | Est. Revenue | Effort |
|--------|-------|-------------|--------|
| Publish first 5 YouTube videos (staggered, 1/day) | Paris/Geordi | $0 now → $200-500/mo by M3 | 2–3 days |
| Finalize script approval workflow (document in decisions.md) | Tamir/Guinan | Unblocks content pipeline | 1 hour |
| Write 3-email welcome sequence in ConvertKit | Seven/Tamir | First email sales | 2 hours |
| Promote lead magnets in existing blog posts | Tamir | 2–5% download conversion | 1 hour |
| Add affiliate links to 5 existing blog posts | Tamir | $30–100/month passive | 30 min |

### Week 3: Cosmetics & Battle Pass MVP

| Action | Owner | Est. Revenue | Effort |
|--------|-------|-------------|--------|
| Implement basic cosmetics shop backend for BrainRot | Data/Dev | $500–$3K/mo at 1K DAU | 3–5 days |
| Deploy Battle Pass UI ($4.99/season) | Dev | $1K–$5K/season | 1 week |
| Enable in-app tip/support prompts on both games | Dev | +20–30% tip conversion | 1 day |
| Monitor itch.io analytics (views → plays → tips funnel) | Geordi | Optimization intel | Ongoing |

### Week 4: Distribution & Discovery

| Action | Owner | Est. Revenue | Effort |
|--------|-------|-------------|--------|
| Submit games to Newgrounds, Kongregate, itch.io bundles | JellyBolt Squad | +1K–5K visitors/month | 2 hours |
| Post game reveal on TikTok/YouTube Shorts (1 clip per game) | Paris | Viral potential | 1–2 hours/game |
| Create DevBlog/Community posts on itch.io | JellyBolt Squad | Community growth | 30 min/week |
| Explore GitHub Sponsors setup for Squad framework | Tamir | $50–500/month | 30 min |

### Month 2+: Scale What's Working

- Launch "JellyBolt Bundle" ($4.99 for all games) once full catalog is published
- Package Squad workshop as paid product ($49–$99 self-paced on Gumroad)
- Consider Pluralsight course authorship ("Building AI Agent Teams with GitHub Copilot")
- Add referral/invite system to BrainRot Quiz Battle (cosmetics for inviting friends)
- Localize games: Spanish + Portuguese = 2× market size with minimal effort

---

## Section 5: Dependencies

> These are gates. If they're not done, downstream items are blocked.

### Critical Path (Ordered)

```
1. Stripe connected to Gumroad
   └→ Enables: ALL payment processing, tip jars, Dungeon Bolt sales,
               Gumroad product sales, email product sales
   └→ Blocks if missing: Everything. Do this first.

2. itch.io dashboard login (manual — requires browser)
   └→ Enables: PWYW pricing, page optimization, tag updates, collection creation
   └→ URL: https://itch.io/login (tdsquadai@gmail.com)

3. Mobile QA pass (real device test)
   └→ Enables: Mobile player revenue (largest audience segment)
   └→ Blocks if missing: All mobile monetization

4. ConvertKit account created
   └→ Enables: Email list building, lead magnet delivery, welcome sequences
   └→ Blocks if missing: Email-driven product sales

5. YouTube channel confirmed public + populated
   └→ Enables: Content publishing, watch hour accumulation, cross-sell traffic
   └→ Blocks if missing: YouTube ad revenue path, content-to-Gumroad funnel
```

### Identity-Gated Actions (Tamir Must Do These Personally)

| Action | Why Agent Can't Do It | Time |
|--------|----------------------|------|
| Connect Stripe to Gumroad | Requires identity verification (SSN/bank) | 15–30 min |
| Enable PWYW on itch.io | Requires tdsquadai@gmail.com login | 10 min |
| Sign up for ConvertKit | Requires personal/business email | 20 min |
| Sign up for Amazon Associates | Requires tax ID, website, contact info | 20 min |
| QA mobile black screen | Requires physical device | 1–2 hours |
| Confirm YouTube channel status | Requires account access | 10 min |

### Agent-Executable Actions (No Human Needed)

| Action | Agent | Status |
|--------|-------|--------|
| Write optimized itch.io descriptions | Seven | Ready — needs dashboard login to paste |
| Publish remaining games to itch.io | JellyBolt Squad | Blocked by tdsquadai login |
| Write blog CTAs and product page copy | Seven | Can start now |
| Draft welcome email sequences | Seven | Can start now |
| Create affiliate disclosure page | Seven | Draft ready in research/ |
| Research additional affiliate programs | Seven | Can do anytime |

---

## Revenue Timeline (If Checklist Completed)

```
Day 1  (Stripe connected, PWYW enabled, Dungeon Bolt published):
  → First potential payment received
  → Estimated: $0–$50 (first tippers, first Dungeon Bolt downloads)

Week 1 (Mobile fix QA, all 16 games published, pages optimized):
  → Full catalog live, mobile players unblocked
  → Estimated: $50–$300/month run rate

Week 2 (Email list started, YouTube publishing begins, blog CTAs live):
  → Content funnel active
  → Estimated: $200–$800/month run rate

Week 3 (Cosmetics/Battle Pass MVP, affiliate links active):
  → First recurring revenue (Battle Pass subscribers)
  → Estimated: $500–$2,000/month run rate

Month 3 (Compounding: catalog growing, email list 500+, YouTube 500+ subs):
  → Estimated: $1,500–$5,000/month (conservative)
  → Estimated: $8,000–$20,000/month (if any viral traction)
```

---

## Anti-Checklist: What NOT to Do First

Avoid these high-effort/low-immediate-return traps while the basics are still unblocked:

- ❌ Don't build a cosmetics shop before Stripe is connected
- ❌ Don't run paid ads before organic monetization is confirmed working
- ❌ Don't build multiplayer infrastructure before mobile is verified working
- ❌ Don't produce 10 YouTube videos before the channel is confirmed public and optimized
- ❌ Don't spend time on Discord/community before the core game experience works on mobile

---

## Quick Reference: Today's Three Moves

If you have 45 minutes right now:

1. **15–30 min → Connect Stripe to Gumroad** (https://app.gumroad.com/settings/payments)  
2. **10 min → Enable PWYW on both live itch.io games** (Name Your Price, $1–2 suggested)  
3. **5 min → Log into itch.io dashboard and check Dungeon Bolt upload status**  

That's it. Everything else flows from here.

---

*Prepared by Seven, Research & Docs | Issue #908 | March 2026*  
*Source documents: ITCH_IO_OPTIMIZATION_REPORT.md · REVENUE_READINESS_REPORT.md · SQUAD_REVENUE_BLOCKING_FINAL_REPORT.md · jellybolt-games/REVENUE_STRATEGY.md · jellybolt-games/GAMES_CATALOG.md · research/active/monetization-strategy/*
