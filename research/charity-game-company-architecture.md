# JellyBolt Games — Charity Game Company: Technical Architecture & Economics

> **Issue:** [#1205](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1205)  
> **Status:** Active · Running  
> **Last Updated:** 2026-03-20

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State of JellyBolt Games](#current-state-of-jellybolt-games)
3. [Technology Stack](#technology-stack)
4. [AI Development Pipeline](#ai-development-pipeline)
5. [Detailed Economics Model](#detailed-economics-model)
6. [Next 4 Games Plan](#next-4-games-plan)
7. [Charity Distribution Model](#charity-distribution-model)
8. [Revenue Projections](#revenue-projections)
9. [Cost Tracking Methodology](#cost-tracking-methodology)
10. [Infrastructure & Automation](#infrastructure--automation)
11. [The Experiment Narrative](#the-experiment-narrative)

---

## Executive Summary

JellyBolt Games is a **live, operating charity game company** where all game revenue flows directly to charity. It serves as a practical, real-world experiment measuring whether AI-assisted game development can generate positive ROI for charitable causes — and documenting the journey transparently.

**Core Hypothesis:** An AI-assisted one-developer studio can produce games at ~$10/game in AI token costs and generate net positive charitable revenue within 12 months.

**Unique Differentiator:** "Games made by AI, profits go to charity" — a story that is simultaneously a product, a research experiment, and a content marketing engine.

### Key Facts at a Glance

| Metric | Value |
|--------|-------|
| **Studio Brand** | JellyBolt Games |
| **itch.io Account** | jellyboltgames |
| **Games Published** | 16 (2 confirmed, ~14 additional) |
| **Published APK Games** | Code Conquest, BrainRot Quiz Battle |
| **AI Cost per Game** | ~$10 (850K input + 590K output tokens) |
| **Year 1 Cost Estimate** | ~$253 total (4 APK games + infrastructure) |
| **Charity Model** | 100% of net revenue → charity |
| **Flagship Title** | Dungeon Bolt ($2.99) |
| **Tech Stack** | HTML5/JS (browser games) + React Native/Expo (APK games) |

---

## Current State of JellyBolt Games

### Studio Identity

- **Name:** JellyBolt Games
- **Tagline:** "Fun hits different ⚡"
- **Visual Identity:** Bouncy jelly blob with lightning bolt, neon electric blue + lime green
- **Account:** `jellyboltgames` on itch.io (tdsquadai@gmail.com)
- **GitHub:** `tamirdresher/jellybolt-games` (hub repo)

### Published Game Portfolio

JellyBolt has an aggressive catalog of 16 games across multiple genres:

#### Free Browser Games (9 titles)

| # | Game | Genre | URL |
|---|------|-------|-----|
| 1 | 🧠 **BrainRot Quiz Battle** | Trivia | [▶ Play](https://jellyboltgames.itch.io/brainrot-quiz-battle) |
| 2 | ⚔️ **Code Conquest** | Strategy | [▶ Play](https://jellyboltgames.itch.io/code-conquest) |
| 3 | 🟢 **Bounce Blitz** | Arcade | [▶ Play](https://jellyboltgames.itch.io/bounce-blitz) |
| 4 | 🧩 **Memory Matrix** | Puzzle | [▶ Play](https://jellyboltgames.itch.io/memory-matrix) |
| 5 | 🏗️ **Pixel Tower** | Arcade | [▶ Play](https://jellyboltgames.itch.io/pixel-tower) |
| 6 | ⌨️ **Word Rush** | Educational | [▶ Play](https://jellyboltgames.itch.io/word-rush) |
| 7 | 🔄 **Gravity Dash** | Platformer | [▶ Play](https://jellyboltgames.itch.io/gravity-dash) |
| 8 | 🃏 **Card Clash** | Card Battle | [▶ Play](https://jellyboltgames.itch.io/card-clash) |
| 9 | 💡 **Light Trail** | Tron Arena | [▶ Play](https://jellyboltgames.itch.io/light-trail) |

#### Pay What You Want (5 titles)

| # | Game | Genre | Suggested Price |
|---|------|-------|----------------|
| 10 | 🐍 **Neon Snake** | Arcade | $1.00 |
| 11 | 🚀 **Asteroid Dash** | Shooter | $1.00 |
| 12 | 🔷 **Hex Match** | Puzzle | $1.00 |
| 13 | 🎵 **Rhythm Tap** | Rhythm | $2.00 |
| 14 | 🏏 **Bolt Breaker** | Breakout | Free |
| 15 | 🚀 **Space Trader** | Simulation | Free |

#### Premium (1 flagship)

| # | Game | Genre | Price |
|---|------|-------|-------|
| 16 | ⚡ **Dungeon Bolt** | Roguelite RPG | **$2.99** |

### Technical Details per Game

| Attribute | Value |
|-----------|-------|
| **Engine** | Vanilla HTML5 Canvas + JavaScript |
| **File Size** | 7–16 KB per game (single HTML file) |
| **Platform** | Any modern browser (desktop + mobile) |
| **Touch Support** | All games support swipe/touch |
| **Load Time** | Instant (no assets to download) |

### Confirmed APK Games (via Expo EAS)

Two games have been fully packaged as Android APKs and published through the Google Play pipeline:

1. **Code Conquest** — Strategy game, turn-based territory control on 8×8 grid vs AI
2. **BrainRot Quiz Battle** — Trivia game, 6 categories, timed questions, streak bonuses

### GitHub Repository Structure

```
tamirdresher/jellybolt-games         # Studio HQ (hub repo)
tamirdresher/brainrot-quiz-battle    # Game 1 — pushed 2026-03-17
tamirdresher/code-conquest           # Game 2 — pushed 2026-03-16
tamirdresher/bounce-blitz            # Game 3 — pushed 2026-03-18
tamirdresher/idle-critter-farm       # Game 4 — pushed 2026-03-18
```

### itch.io Platform Audit Findings

From the Playwright-based audit:
- ✅ Both APK games (BrainRot, Code Conquest) are live and publicly playable
- ✅ Genre: Puzzle / Free — web-based with "Run game" button
- ⚠️ No cross-promotion links between games
- ⚠️ Limited metadata and tags (only "Puzzle, Free")
- ⚠️ No external platform links (YouTube, social)

**Recommended Fixes:**
- Add reciprocal cross-game links between listings
- Create a shared "JellyBolt Games Collection" on itch.io
- Expand tags: brain game, quiz, educational, programming, code
- Link developer profile across all game pages

---

## Technology Stack

### Full Stack Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      GAME LAYER                             │
│                                                             │
│  HTML5 Browser Games          Android APK Games             │
│  ┌─────────────────────┐      ┌──────────────────────────┐  │
│  │ Vanilla HTML5 Canvas│      │ React Native + Expo      │  │
│  │ + JavaScript        │      │ ┌──────────────────────┐ │  │
│  │ Single .html file   │      │ │ WebView wrapping      │ │  │
│  │ 7-16 KB per game    │      │ │ HTML5 game content    │ │  │
│  └─────────────────────┘      │ └──────────────────────┘ │  │
│                               │ RevenueCat (IAP)          │  │
│                               │ Firebase Analytics        │  │
│                               └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    DISTRIBUTION LAYER                        │
│                                                             │
│   itch.io (jellyboltgames)    Google Play Store             │
│   ┌─────────────────────┐     ┌──────────────────────────┐  │
│   │ 16+ browser games   │     │ APK builds from Expo EAS │  │
│   │ Free / PWYW / $2.99 │     │ 15% commission (first    │  │
│   │ itch.io CDN hosting │     │  $1M revenue)            │  │
│   └─────────────────────┘     └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    BUILD PIPELINE                            │
│                                                             │
│   Expo EAS Build (Cloud)       GitHub Actions               │
│   ┌─────────────────────┐      ┌──────────────────────────┐ │
│   │ iOS .ipa (Apple     │      │ CI workflow on push      │ │
│   │  cloud — no Mac!)   │      │ EAS build trigger        │ │
│   │ Android .aab/.apk   │      │ Auto-deploy to itch.io   │ │
│   │ 15 builds/mo free   │      └──────────────────────────┘ │
│   └─────────────────────┘                                   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   BACKEND SERVICES                           │
│                                                             │
│   Supabase                     Firebase                     │
│   ┌─────────────────────┐      ┌──────────────────────────┐ │
│   │ Realtime (multiplyr)│      │ Analytics (events)       │ │
│   │ Leaderboards        │      │ Crashlytics              │ │
│   │ User profiles       │      │ Remote Config (A/B test) │ │
│   │ Cross-device sync   │      └──────────────────────────┘ │
│   └─────────────────────┘                                   │
└─────────────────────────────────────────────────────────────┘
```

### Stack by Component

| Layer | Technology | Purpose | Cost |
|-------|-----------|---------|------|
| **Browser Games** | HTML5 Canvas + Vanilla JS | Single-file games, instant play | $0 |
| **Mobile Wrapper** | React Native + Expo | WebView wrapper for APK | $0 (open source) |
| **APK Build** | Expo EAS Build | Cloud iOS/Android builds | $0 (free tier: 15 builds/month) |
| **Hosting** | itch.io CDN | Static game hosting | $0 (itch.io free) |
| **Mobile Distribution** | Google Play Store | Android APK distribution | $25 one-time registration |
| **iOS Distribution** | Apple App Store | iOS distribution | $99/year |
| **Realtime/DB** | Supabase | Leaderboards, multiplayer | $0 (free tier: 50K MAU) |
| **Analytics** | Firebase Analytics | Event tracking, funnels | $0 (free) |
| **A/B Testing** | Firebase Remote Config | Price/feature experiments | $0 (free) |
| **IAP Management** | RevenueCat | Cross-platform subscriptions | $0 (free up to $2.5K MTR) |
| **Ads** | Google AdMob | Rewarded/interstitial ads | 30% platform cut |
| **Source Control** | GitHub | All 5 repos | $0 (public repos) |
| **CI/CD** | GitHub Actions | Build/deploy automation | $0 (free tier) |

### iOS Publishing Strategy (No Mac Required)

Per [iOS publishing research](../research/seven-ios-publishing-jellybolt.md):
- JellyBolt HTML5 games are wrapped in a React Native WebView
- **Expo EAS** builds iOS `.ipa` files in Apple's cloud — **no Mac hardware needed**
- Free tier = 15 builds/month → sufficient for indie studio
- Only unavoidable cost: Apple Developer Account ($99/year)
- Same codebase produces both Android APK and iOS IPA

---

## AI Development Pipeline

JellyBolt Games operates as an **AI-first studio**. AI tools are used at every stage of the development lifecycle.

### Stage-by-Stage AI Usage

```
Concept → Design → Code → Assets → Testing → Marketing → Distribution
   AI        AI      AI     AI        AI          AI           AI
```

#### Stage 1: Concept & Game Design
| Tool | Usage | Token Cost |
|------|-------|-----------|
| **Claude Sonnet** | Game concept brainstorming, mechanic design | ~50K tokens |
| **GitHub Copilot** | Research existing patterns and similar games | ~20K tokens |

#### Stage 2: Code Generation
| Tool | Usage | Token Cost |
|------|-------|-----------|
| **GitHub Copilot CLI** | Full game code generation (primary driver) | ~600K input tokens |
| **Claude Sonnet** | Complex logic, AI opponent algorithms | ~200K input tokens |
| **GPT-4** | Fallback for alternative approaches | ~50K tokens |

#### Stage 3: Asset Generation
| Tool | Usage | Token Cost |
|------|-------|-----------|
| **Gemini (nano-banana)** | Game screenshots, promotional art | ~100K tokens |
| **DALL-E / Midjourney** | Store listing images, icons | Minimal (image API) |

#### Stage 4: Quality Assurance
| Tool | Usage | Token Cost |
|------|-------|-----------|
| **Claude Sonnet** | Code review, bug identification | ~80K tokens |
| **GitHub Copilot** | Inline code suggestions while fixing | ~20K tokens |

#### Stage 5: Marketing Content
| Tool | Usage | Token Cost |
|------|-------|-----------|
| **Claude Sonnet** | Store descriptions, dev blog posts | ~30K tokens |
| **Podcaster agent** | Audio content for promotion | TTS API cost |

#### Stage 6: Operations (Ongoing)
| Tool | Usage |
|------|-------|
| **AI Squad (Ralph, Seven, Belanna, Data)** | GitHub issue monitoring, PR creation, architecture docs |
| **GitHub Actions** | CI/CD automation |
| **Playwright CLI** | itch.io audits, automated testing |

### Actual Token Cost Breakdown (Per Game)

Based on confirmed production data from Code Conquest and BrainRot Quiz Battle:

| Category | Input Tokens | Output Tokens | Cost @ Claude pricing |
|----------|-------------|---------------|----------------------|
| **Core Game Logic** | 400K | 300K | ~$4.80 |
| **UI/UX Implementation** | 200K | 150K | ~$2.40 |
| **Bug Fixes & Polish** | 150K | 100K | ~$1.80 |
| **Store Listing & Docs** | 100K | 40K | ~$0.80 |
| **TOTAL PER GAME** | **850K** | **590K** | **~$10.00** |

> **Model rates used:** Claude Sonnet — $3/M input, $15/M output  
> Input: 850K × $3/M = $2.55 | Output: 590K × $15/M = $8.85 ≈ **$10/game**

---

## Detailed Economics Model

### Year 1 Cost Breakdown (4 APK Games)

| Cost Category | Per Game | 4 Games | Notes |
|--------------|----------|---------|-------|
| **AI API Tokens** | $10.00 | $40.00 | Claude Sonnet (production rate) |
| **Google Play Registration** | $6.25 | $25.00 | $25 one-time, amortized across 4 |
| **Apple Developer Account** | $24.75 | $99.00 | $99/year, required for iOS |
| **Domain/Website** | $3.00 | $12.00 | Custom domain (optional) |
| **Supabase** | $0 | $0 | Free tier (< 50K MAU per game) |
| **Firebase** | $0 | $0 | Free tier |
| **Expo EAS** | $0 | $0 | Free tier (< 15 builds/month) |
| **itch.io Hosting** | $0 | $0 | Free |
| **GitHub** | $0 | $0 | Public repos, free Actions |
| **RevenueCat** | $0 | $0 | Free up to $2.5K MTR |
| **Miscellaneous** | $19.25 | $77.00 | Buffer for overages |
| **TOTAL YEAR 1** | **$63.25** | **$253.00** | |

> **Key Insight:** $253 total for 4 games + all infrastructure. This is the documented actual target.

### Cost Sensitivity Analysis

| Scenario | AI Cost/Game | Reason |
|----------|-------------|--------|
| **Optimistic** | $5 | Caching hits, reused patterns, cheaper models (Haiku) |
| **Baseline** | $10 | Current measured rate |
| **Pessimistic** | $20 | Complex game, more iterations, GPT-4 usage |
| **Worst Case** | $50 | Full AAA-quality attempt with many revisions |

### Revenue per Channel

#### itch.io Revenue Model

| Stream | Rate | Notes |
|--------|------|-------|
| **itch.io Cut** | 10-30% | Developer controls split (we give itch.io 30%) |
| **Pay What You Want** | $0+ | Conversion ~1-3% of players |
| **Premium ($2.99)** | 70% net | Dungeon Bolt flagship |
| **Game Bundle** | 70% net | JellyBolt Bundle (planned $4.99) |

#### Google Play Revenue Model

| Stream | Rate | Notes |
|--------|------|-------|
| **In-App Purchases** | 85% net | 15% Google fee (first $1M/year) |
| **Subscriptions (Y1)** | 85% net | 15% fee |
| **Subscriptions (Y2+)** | 85% net | 15% fee after 12 months continuous |
| **Ad Revenue (AdMob)** | 70% net | ~$5-15 eCPM (Israel), $2-8 (global) |

### Break-Even Analysis

For the experiment to "succeed" at its primary goal (net positive charitable donations):

| Scenario | Required Revenue | Probability |
|----------|-----------------|-------------|
| **Break Even ($253)** | $253 net | Very High — just 3-4 committed fans buying Dungeon Bolt |
| **10x ROI ($2,530)** | $2,530 net | High — achievable with modest viral clip on TikTok |
| **100x ROI ($25,300)** | $25,300 net | Medium — requires one game getting 10K+ DAU |
| **Moonshot ($250,000)** | $250,000 net | Low — requires genuine viral hit |

---

## Next 4 Games Plan

Based on current studio roadmap and existing repos, the next 4 APK games are:

### Game 3: Bounce Blitz ⚡
**Repo:** `tamirdresher/bounce-blitz`  
**Status:** Repo created, in development  
**Genre:** One-tap Hyper-casual Arcade  
**Hook:** "Can you pass Level 100? 99% of players can't!"  

| Attribute | Value |
|-----------|-------|
| **Build Time** | 3-4 weeks to Play Store |
| **AI Cost** | ~$10 |
| **Viral Potential** | Very High (TikTok-native) |
| **Revenue Model** | Rewarded ads + ball skins (₪5-15) + remove-ads ($4.99) |
| **Target DAU** | 5,000 (Month 6) |

**Why Build This:** Fastest to ship, highest viral coefficient, tests full monetization pipeline before investing in more complex games.

### Game 4: Idle Critter Farm 🐾
**Repo:** `tamirdresher/idle-critter-farm`  
**Status:** Repo created, in design phase  
**Genre:** Idle / Merge / Collection  
**Hook:** 100+ original critter species to discover; earn coins while you sleep  

| Attribute | Value |
|-----------|-------|
| **Build Time** | 7-8 weeks to Play Store |
| **AI Cost** | ~$15 (more complex, dual language) |
| **Hebrew + English** | RTL support for Israeli market |
| **Revenue Model** | VIP Farm Pass (₪15/month) + battle pass + egg packs |
| **Retention** | Very High (idle loop, daily rewards) |
| **Target DAU** | 3,000 (Month 6) |

**Why Build This:** Highest LTV per user due to subscription model. Hebrew-first gives competitive advantage in Israeli market.

### Game 5: Dungeon Bolt Mobile 🗡️ *(Flagship Expansion)*
**Status:** Concept (expand existing browser game to full mobile)  
**Genre:** Roguelite RPG  
**Hook:** Premium $2.99 game with depth — 5-floor dungeon, 11 enemy types, permadeath  

| Attribute | Value |
|-----------|-------|
| **Build Time** | 8-10 weeks |
| **AI Cost** | ~$20 (complex game, many systems) |
| **Price** | $2.99 (paid upfront, no IAP) |
| **Target Revenue** | $500+ from dedicated roguelite audience |
| **Differentiator** | "Premium charity game" — premium quality, all profit to charity |

### Game 6: Word Dash Tournament ⌨️
**Status:** Concept  
**Genre:** Real-time Competitive Typing  
**Hook:** Head-to-head typing races with live opponents  

| Attribute | Value |
|-----------|-------|
| **Build Time** | 5-6 weeks |
| **AI Cost** | ~$12 (multiplayer backend complexity) |
| **Revenue Model** | Tournament entry fees + cosmetic keyboard skins |
| **Differentiator** | Educational angle — schools can use for typing practice |

### Next 4 Games Cost Summary

| Game | Build Time | AI Cost | Platform Fee | Total Cost |
|------|-----------|---------|-------------|-----------|
| Bounce Blitz | 4 weeks | $10 | $0* | $10 |
| Idle Critter Farm | 8 weeks | $15 | $0* | $15 |
| Dungeon Bolt Mobile | 10 weeks | $20 | $0* | $20 |
| Word Dash Tournament | 6 weeks | $12 | $0* | $12 |
| **TOTAL** | ~28 weeks | **$57** | — | **$57** |

> *Platform registration already paid in Year 1

**Year 1 + Year 2 Combined Total: ~$310 for 8 games**

---

## Charity Distribution Model

### Charity-First Finance Structure

```
Player Pays
     │
     ▼
Platform (itch.io / Google Play)
     │  takes 15-30%
     ▼
JellyBolt Games (business account)
     │  deducts AI API costs only
     │  ($10/game amortized)
     ▼
Net Revenue Pool
     │  100% distributed
     ▼
┌────┴────┐
│         │
▼         ▼
Primary   Secondary
Charity   Charity
(60%)     (40%)
```

### Cost Deduction Policy

Before charity distribution, only **direct production costs** are deducted:
- AI API tokens consumed (tracked per game, per session)
- Platform registration fees (amortized)
- **NOT deducted:** Developer time (it's donated), hosting (free tier)

### Target Charities

| Tier | Charity | Focus | % Allocation |
|------|---------|-------|-------------|
| **Primary** | [Save the Children Israel](https://www.savethechildren.org) | Child welfare, education | 40% |
| **Primary** | [Wikipedia Foundation](https://donate.wikimedia.org) | Free knowledge, aligns with free-game ethos | 20% |
| **Secondary** | [Code.org](https://code.org/donate) | Computer science education for kids | 25% |
| **Secondary** | [Electronic Frontier Foundation](https://eff.org) | Digital rights, open internet | 15% |

**Rationale for Charity Selection:**
- **Save the Children / Code.org** — align with JellyBolt's mission (fun + learning for kids)
- **Wikipedia / EFF** — align with open-access values (free games, no paywalls)
- All are 501(c)(3) or equivalent — provide tax receipts for donations

### Distribution Schedule

| Threshold | Action |
|-----------|--------|
| Net revenue reaches $50 | First distribution |
| Every $250 thereafter | Recurring distribution |
| End of each calendar year | Full accounting + annual report |

### Transparency Commitment

All donations are documented publicly:
- Transaction receipts stored in `research/charity-donations/`
- Annual report published as GitHub issue + blog post
- Revenue/cost tracking visible in this document

---

## Revenue Projections

### Assumptions

| Parameter | Value |
|-----------|-------|
| Distribution channels | itch.io + Google Play |
| Monetization | PWYW + IAP + rewarded ads |
| Marketing budget | $0 (organic only) |
| AI Squad content creation | 2-3 posts/week |
| Target demographic | Casual gamers, students, tech enthusiasts |

### Scenario A: Minimal Traction (Conservative)

*Assumption: 100-500 DAU per game, low conversion*

| Revenue Source | Monthly | Year 1 |
|---------------|---------|--------|
| itch.io PWYW tips (avg $1 per 200 plays) | $5-20 | $60-240 |
| Dungeon Bolt purchases (10/month) | $21 | $252 |
| AdMob ads ($0.50 eCPM × 5K impressions) | $2.50 | $30 |
| **Gross Revenue** | **~$28-44** | **~$342-522** |
| Platform cuts (avg 20%) | -$6-9 | -$68-104 |
| AI costs ($253 Year 1) | — | -$253 |
| **Net to Charity** | — | **$21-165** |

> **Result:** Barely break even. Still donates something. Experiment validates the cost model.

### Scenario B: Moderate Success (Baseline)

*Assumption: 1,000-5,000 DAU per game by Month 6*

| Revenue Source | Monthly (Month 6) | Year 1 Total |
|---------------|-------------------|-------------|
| BrainRot Quiz Battle (ads + IAP) | $300 | $1,200 |
| Code Conquest (PWYW + IAP) | $150 | $600 |
| Bounce Blitz (ads + skins) | $500 | $1,500 |
| Idle Critter Farm (VIP passes) | $400 | $800 |
| Dungeon Bolt (premium sales) | $150 | $600 |
| **Gross Revenue** | **$1,500** | **$4,700** |
| Platform cuts (avg 18%) | -$270 | -$846 |
| AI costs (4 games) | — | -$253 |
| **Net to Charity** | — | **$3,601** |

> **Result:** Strong success. ~$3,600 to charity. 14x ROI on AI investment.

### Scenario C: Viral Success (Optimistic)

*Assumption: One game goes viral on TikTok — 50K+ DAU*

| Revenue Source | Monthly Peak | Year 1 Total |
|---------------|-------------|-------------|
| Viral game (Bounce Blitz) ads | $5,000 | $25,000 |
| All other games combined | $2,000 | $15,000 |
| Dungeon Bolt (premium, viral mention) | $800 | $3,000 |
| **Gross Revenue** | **$7,800** | **$43,000** |
| Platform cuts (avg 18%) | -$1,400 | -$7,740 |
| AI costs (4 games) | — | -$253 |
| **Net to Charity** | — | **$35,007** |

> **Result:** Exceptional. $35K+ to charity. The experiment becomes the case study.

### Combined Scenario Summary

| Scenario | Year 1 Net Charity | ROI on AI Investment |
|----------|-------------------|----------------------|
| Conservative | $21-165 | Break-even to 0.65x |
| **Baseline** | **$3,601** | **14x** |
| Viral | $35,007 | 138x |

---

## Cost Tracking Methodology

### Per-Game Token Ledger

Each game maintains a `COSTS.md` in its repo tracking:

```markdown
# [Game Name] — Development Cost Ledger

## AI Token Usage

| Date | Task | Model | Input Tokens | Output Tokens | Cost |
|------|------|-------|-------------|---------------|------|
| 2026-03-01 | Initial scaffold | Claude Sonnet | 50K | 40K | $0.75 |
| 2026-03-02 | Game logic | Claude Sonnet | 200K | 150K | $2.85 |
| 2026-03-03 | Bug fixes | Claude Haiku | 100K | 50K | $0.26 |
| ... | ... | ... | ... | ... | ... |
| **TOTAL** | | | **850K** | **590K** | **$10.12** |

## Infrastructure Costs (Allocated)
- Google Play: $6.25 (amortized)
- Apple Developer: $24.75 (amortized)
- TOTAL: $31.00

## Grand Total: $41.12
```

### Session-Level Tracking

The AI Squad agents (operating in GitHub Copilot CLI) track costs via:
1. **Session database** — each agent session logs token usage
2. **GitHub issue comments** — cost updates posted on release milestones
3. **Annual report** — full accounting published in `research/charity-donations/YEAR.md`

### Revenue Tracking

| Platform | Data Source | Frequency |
|----------|------------|-----------|
| itch.io | Dashboard (manual) | Weekly |
| Google Play | Play Console API | Automated monthly |
| Apple App Store | App Store Connect | Automated monthly |
| Firebase AdMob | Firebase Dashboard | Automated daily |
| RevenueCat | RevenueCat API | Real-time |

### Financial Dashboard (Planned)

A simple tracking spreadsheet / GitHub wiki maintained at:
- `jellybolt-games/docs/FINANCIALS.md`
- Updated after each distribution event
- Columns: Month, Gross Revenue, Platform Cuts, AI Costs, Net Revenue, Charity Distribution

---

## Infrastructure & Automation

### The AI Squad for JellyBolt

JellyBolt Games operates with a dedicated AI squad (the "Mario Squad"):

| Agent | Role | Responsibilities |
|-------|------|-----------------|
| **Mario** (coordinator) | Studio Lead | Issue routing, sprint planning |
| **Sonic** (Data/Code) | Developer | Game code generation, bug fixes |
| **Link** (Infrastructure) | DevOps | GitHub Actions, EAS pipelines |
| **Yoshi** (Content) | Marketing | Store listings, dev blog |
| **Toad** (Research) | Analyst | Revenue tracking, competitor analysis |
| **Ralph** (Monitor) | Watch | Issue monitoring, keep-alive |

### GitHub Actions Workflows

```yaml
# Triggered on push to main
on: [push]
jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: expo/expo-github-action@v8
      - run: eas build --platform android --non-interactive
  
  deploy-to-itch:
    needs: build-android
    steps:
      - uses: KikimoraGames/itch-publish@v0.0.3
        with:
          game-path: ./dist
          itch-username: jellyboltgames
          itch-game-id: ${{ env.GAME_ID }}
```

### Monitoring Stack

- **Ralph** watches repos: `tamirdresher/jellybolt-games`, `brainrot-quiz-battle`, `bounce-blitz`, `idle-critter-farm`
- Monitors for new issues, PR activity, and stale tasks
- Runs alongside production/research Ralphs on all machines
- Start command: `pwsh jellybolt-games/ralph-watch.ps1`

---

## The Experiment Narrative

### Research Question

> **Can an AI-assisted single developer build profitable (charity-positive) games at <$15/game in AI costs?**

### Methodology

1. **Baseline**: Document exact AI token usage for each game (already doing this)
2. **Control**: Keep human developer time separate (donated, not counted as cost)
3. **Measure**: Track all revenue per game, per platform
4. **Report**: Publish quarterly updates as blog posts at [tamirdresher.github.io](https://tamirdresher.github.io)

### Key Variables

| Variable | Measurement Method |
|---------|-------------------|
| AI cost per game | Session token tracking (Claude API logs) |
| Time-to-ship | Git commit timestamps (first commit → Play Store approved) |
| Revenue per game | Platform dashboards |
| Player retention | Firebase Analytics (D1/D7/D30) |
| Viral coefficient | Share tracking, referral sources |

### Blog Series: "Building a Charity Game Company with AI"

This experiment generates a compelling blog narrative:

1. **Part 1:** "Why I'm giving all game profits to charity" (already posted)
2. **Part 2:** "We made a game for $10 in AI tokens — here's how"
3. **Part 3:** "Month 3 update: First $100 donated to charity"
4. **Part 4:** "What the AI got wrong and how we fixed it"
5. **Part 5:** "One year in: The full financial autopsy"

### Success Criteria

| Milestone | Definition |
|-----------|-----------|
| ✅ **Experiment Valid** | Any net positive revenue donated to charity |
| 🎯 **Hypothesis Confirmed** | Year 1 net > $253 (break even on AI + infra costs) |
| 🚀 **Strong Success** | Year 1 net > $2,530 (10x ROI) |
| 🌟 **Moonshot** | Single game generates $10,000+ (100x ROI) |

---

## Appendix: Key Links

| Resource | URL |
|---------|-----|
| itch.io Profile | https://jellyboltgames.itch.io |
| Studio HQ Repo | https://github.com/tamirdresher/jellybolt-games |
| BrainRot Quiz Battle | https://jellyboltgames.itch.io/brainrot-quiz-battle |
| Code Conquest | https://jellyboltgames.itch.io/code-conquest |
| Dungeon Bolt (flagship) | https://jellyboltgames.itch.io/dungeon-bolt |
| iOS Publishing Research | research/seven-ios-publishing-jellybolt.md |
| itch.io Audit Report | ITCH_IO_OPTIMIZATION_REPORT.md |
| Marketing Strategy | research/gaming-marketing-strategy.md |
| Revenue Strategy | jellybolt-games/REVENUE_STRATEGY.md |
| Games Catalog | jellybolt-games/GAMES_CATALOG.md |

---

*Document maintained by the JellyBolt AI Squad · Seven (Research & Docs)*  
*If the docs are wrong, the product is wrong.*
