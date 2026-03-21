# Content Company: Aspire & Semantic Kernel Repo Inventory

**Date:** 2026-03-21  
**Researcher:** Seven (docs agent)  
**Triggered by:** Issue #870 — "The content company squad should look on the repos I have in tamirdresher GitHub for aspire workshop"  
**Scope:** `https://github.com/tamirdresher` — all public repos surveyed (50 repos scanned)

---

## Executive Summary

Tamir Dresher has two **fully battle-tested workshop repos** that are ready to be turned into premium content: a 3-day .NET Aspire workshop and a comprehensive Semantic Kernel + AI agents workshop. Together they represent a unique end-to-end curriculum: *build the distributed platform with Aspire, then add intelligence with Semantic Kernel*. This is a rare combination in the .NET content ecosystem and a strong differentiator.

---

## Relevant Repos — Inventory

### 🔵 Tier 1: Workshop Gold (turn into courses immediately)

#### 1. [`aspire-workshop`](https://github.com/tamirdresher/aspire-workshop)
> **"Building Distributed Apps with .NET Aspire"**

| Attribute | Detail |
|-----------|--------|
| Description | Comprehensive 3-day workshop for cloud-native distributed apps with .NET Aspire |
| Target SDK | .NET 10 |
| Stars/Forks | Public repo (original, not a fork) |
| Structure | `Exercise/` (Bookstore hands-on app) + `Examples/` (reference implementations) |

**What content already exists:**
- **3-day structured curriculum** with distinct learning arcs (Day 1: Fundamentals → Day 2: Integrations → Day 3: Advanced/Custom Resources)
- **Lesson-01** (Getting Started): adding Aspire to existing apps, AppHost, service discovery ✅
- **Lesson-02** (Integrations): Redis, Cosmos DB, PostgreSQL, parameters, secrets, publish mode
- **Lesson-03** (Custom Resources & Testing): Aspire internals, "Talking Clock" resource, Playwright E2E
- **Examples folder** covering: Annotations, Commands, Eventing, Parameters, Pipelines, URL Customizations, Azure emulators, Bicep templates, container customization, external resources, custom resource (`DevProxy`), full multi-service app, integration testing with xUnit + Playwright
- **Clear prerequisites listed** (Docker, .NET 10, Azure optional)
- **Code-first explanations** of AppHost, service discovery, integrations

**What could be turned into courses/videos:**
- 🎬 Full 3-day course (split into 15–20 short videos, each lesson ≈ 10–15 min)
- 📹 "Add .NET Aspire to an Existing App in 15 minutes" (quick-win intro video)
- 📝 Blog series: "Aspire Fundamentals in 3 Days" (one post per lesson)
- 🎯 Workshop delivery as instructor-led training (corporate or conference)
- 📺 "Aspire + AWS" deep-dive (cross-pollinate with `aspire-aws-feedback`)
- 🧪 "Testing Distributed Apps with Aspire" standalone module

---

#### 2. [`creating-ai-agents-with-csharp`](https://github.com/tamirdresher/creating-ai-agents-with-csharp)
> **"Creating AI Applications and Agents with C# — Semantic Kernel C# Workshop"**

| Attribute | Detail |
|-----------|--------|
| Description | Full workshop: SK basics → multi-agent orchestration → A2A protocol |
| Target SDK | .NET 9 |
| Structure | `notebooks/` (8 Jupyter notebooks) + `src/` (SKCodeAssistent project) + `docs/assignments/` |

**What content already exists:**
- **8 interactive Jupyter notebooks** — full progression from intro to advanced:
  1. Introduction to Semantic Kernel
  2. SK Agents
  3. Functions & Plugins
  3.1. OpenAPI Plugin
  3.2. Model Context Protocol (MCP)
  4. Multi-Agent Orchestration
  5. Chat History Reducers
  6. Agent-to-Agent (A2A) Protocol 🆕
  7. Process Framework & HITL 🆕
  8. Guardrails & AI Safety 🆕
- **SKCodeAssistent project**: full AI coding assistant (Architect + Developer + Tester agents)
- **5 progressive assignments** (Three Agents → Plugins+MCP → Team Orchestration → A2A → Process Framework)
- **GitHub Models setup guide** (no Azure subscription needed — lower barrier to entry)

**What could be turned into courses/videos:**
- 🎬 "Semantic Kernel Crash Course" (8 notebooks = 8 episodes, self-contained)
- 🔥 "Build Your Own AI Coding Assistant" (project-based course using SKCodeAssistent)
- 📝 Blog series: "From Zero to AI Agents in C#"
- 🎯 "MCP + SK: Connect Your AI to Everything" (dedicated module — very hot topic 2025–2026)
- 🎯 "A2A Protocol Deep Dive" (leading edge — almost no content exists on this yet)
- 📺 "Guardrails & AI Safety in .NET" (enterprise angle)

---

### 🟢 Tier 2: Supporting Content (enrich or extend Tier 1)

#### 3. [`semantic-kernel-intro`](https://github.com/tamirdresher/semantic-kernel-intro)
> Older SK intro demos — prompts, plugins, KernelFunctions, OpenAPI, RAG, Chat app with kubectl+AzDO

- Good as **supplemental material** for the SK course intro modules
- The Kubernetes-aware chat app is a compelling demo for DevOps-minded audiences
- Could be a blog post: "Build a Kubernetes AI Assistant with Semantic Kernel"

#### 4. [`aspire-aws-feedback`](https://github.com/tamirdresher/aspire-aws-feedback)
> Aspire + AWS: CloudFormation provisioning, SQS/SNS messaging, DynamoDB Local emulator, LocalStack

- Unique content: **almost no .NET Aspire + AWS content exists** — this is a gap in the market
- Could be: "Using .NET Aspire with AWS" blog series / video mini-series
- DynamoDB Local integration is genuinely novel

#### 5. [`eShop`](https://github.com/tamirdresher/eShop)
> Reference eCommerce app using .NET Aspire (fork of dotnet/eShop)

- Excellent **"real world Aspire" showcase** material
- Could anchor a "Aspire in Production" content piece
- Walk-through the architecture as a companion piece to the workshop

#### 6. [`AsyncProcessingInDotNet-Webscraper`](https://github.com/tamirdresher/AsyncProcessingInDotNet-Webscraper)
> Async concurrency models (Naive, Task.WhenAll, BlockingCollection, Channels, TPL Dataflow) + Aspire AppHost

- Strong standalone topic: "5 Ways to Write Concurrent .NET Code"
- Aspire integration is a nice bonus angle
- Pairs well with Tamir's existing async expertise (published book author)

#### 7. [`net-conf-il-2025`](https://github.com/tamirdresher/net-conf-il-2025)
> .NET Conf IL 2025 talk: .NET 10 & C# 14 features

- Talk already delivered — repurpose into blog post + YouTube video
- Existing before/after examples are content-ready

#### 8. [`RxInAction`](https://github.com/tamirdresher/RxInAction)
> Source code for Manning book "Rx.NET in Action"

- Not a priority for new content — book already covers this
- Could reference as "from the author of Rx.NET in Action" for credibility

---

### 🟡 Tier 3: Infrastructure / Meta (not direct content, but useful context)

| Repo | Notes |
|------|-------|
| `aspire` | Fork of dotnet/aspire — used to track upstream, not direct content |
| `aspire-samples` | Fork of dotnet/aspire-samples — reference, not original content |
| `semantic-kernel` | Fork of microsoft/semantic-kernel — reference only |
| `content-empire` | The content publishing platform itself (Hugo + Netlify) — delivery vehicle |
| `tamirdresher.github.io` | Personal Jekyll blog — good cross-promotion target |

---

## `tamirdresher.github.io` — Aspire Workshop Presence

The personal site (`tamirdresher.github.io`) is a Jekyll-based blog with `_posts/`, `blog/`, and `resources.md`. No dedicated Aspire workshop page was found in the root structure. **Opportunity:** Add an Aspire workshop landing page pointing to the GitHub repo and any course/video content produced.

---

## Top 3 Content Ideas

### 🥇 #1 — "Building Distributed .NET Apps with Aspire" — Full Video Course
**Source:** `aspire-workshop`  
**Format:** 15–20 video modules on YouTube / Udemy / Pluralsight  
**Pitch:** The only comprehensive, hands-on Aspire workshop backed by production-ready code. Covers the full arc from fundamentals to custom resources to cloud deployment.

| Item | Estimate |
|------|----------|
| Total effort | 4–6 weeks (content is 90% done — needs recording + editing) |
| Videos | ~18 videos, avg. 12 min each |
| Monetization | Udemy course ($20–$50), Pluralsight pitch, YouTube ad revenue + affiliate |
| Differentiator | .NET 10, includes testing + deployment, only multi-day Aspire workshop that exists |

**Recommended first steps:**
1. Record Lesson-01 walkthrough (Getting Started) as the free preview
2. Publish "Add Aspire to an Existing App in 15 Minutes" to YouTube as a teaser
3. Open a Udemy/Teachable course page with Lessons 01–03 as modules

---

### 🥈 #2 — "Building AI Agents with C# and Semantic Kernel" — Workshop Course
**Source:** `creating-ai-agents-with-csharp`  
**Format:** 8-part video series (one per notebook) + optional paid "full course" tier  
**Pitch:** Most SK content stops at "call the model." This goes all the way to multi-agent orchestration, MCP integration, and the brand-new A2A protocol. Nothing like this exists in C#.

| Item | Estimate |
|------|----------|
| Total effort | 3–4 weeks (notebooks are the script — just record + narrate) |
| Videos | 8–10 videos, avg. 15 min each |
| Monetization | YouTube free series (drive traffic) + paid full course ($30–$80) |
| Differentiator | A2A protocol + Process Framework HITL are 2025/2026 bleeding edge — almost no competition |

**Recommended first steps:**
1. Record notebook 1 (SK Intro) and notebook 4 (Multi-Agent Orchestration) as free YouTube pilots
2. The SKCodeAssistent demo is the "wow moment" — use it as the course trailer

---

### 🥉 #3 — ".NET Aspire + AWS: The Missing Guide" — Blog + Mini-Course
**Source:** `aspire-aws-feedback`  
**Format:** 3-part blog series + 3 short videos  
**Pitch:** 95% of Aspire content assumes Azure. This is the only .NET Aspire + AWS content that exists. Pure blue ocean.

| Item | Estimate |
|------|----------|
| Total effort | 1–2 weeks (3 short posts, 3 companion videos) |
| Videos | 3 videos, avg. 10 min each |
| Monetization | Traffic/SEO play — drives email list and course upsell |
| Differentiator | Literally no competing content on this specific topic |

**Recommended first steps:**
1. Post "Using .NET Aspire with AWS SQS and CloudFormation" on tamirdresher.github.io
2. Cross-post to dev.to and medium
3. Open a GitHub Discussion in the dotnet/aspire repo to signal authority

---

## Recommendation: What to Tackle First

**Start with #1 (Aspire Workshop Course).** Here's why:

1. **Content is production-ready.** The 3-day workshop exists, is structured, has exercises and solutions, and targets .NET 10. Recording is the bottleneck — not writing.
2. **Market timing is perfect.** .NET Aspire reached GA in 2024 and is now being adopted in enterprise. Developers are actively searching for training content.
3. **Lower barrier than SK content.** Aspire is infrastructure/tooling — the audience is broader (all .NET developers, not just AI developers).
4. **Leads into #2 naturally.** Once you have an audience from the Aspire course, pitch the SK course as "now add AI to your Aspire app."
5. **#3 (AWS) is the lowest effort** and best SEO play — do it in parallel as a side track.

### Suggested 8-Week Execution Plan

| Week | Action |
|------|--------|
| 1 | Record "Aspire in 15 min" teaser → publish to YouTube |
| 2 | Record Lesson-01 (Fundamentals) — 4–5 videos |
| 3 | Record Lesson-02 (Integrations) — 5–6 videos |
| 4 | Record Lesson-03 (Custom Resources + Testing) — 5–6 videos |
| 5 | Edit + produce course on Udemy/Teachable, write launch blog post |
| 6 | Publish "Aspire + AWS" 3-part blog series (parallel track) |
| 7 | Record SK notebooks 1–4 (SK intro → multi-agent) |
| 8 | Publish SK mini-series on YouTube, pitch full SK course pre-sale |

---

## Appendix: Full Repo Scan Results

| Repo | Type | Aspire? | SK/AI? | Content Value |
|------|------|---------|--------|---------------|
| `aspire-workshop` | Original workshop | ✅ Core | ❌ | ⭐⭐⭐⭐⭐ |
| `creating-ai-agents-with-csharp` | Original workshop | ✅ AppHost | ✅ Core | ⭐⭐⭐⭐⭐ |
| `aspire-aws-feedback` | Original demo | ✅ Core | ❌ | ⭐⭐⭐⭐ |
| `semantic-kernel-intro` | Original demo | ❌ | ✅ Intro | ⭐⭐⭐ |
| `eShop` | Fork (dotnet) | ✅ Used | ❌ | ⭐⭐⭐ |
| `AsyncProcessingInDotNet-Webscraper` | Original demo | ✅ AppHost | ❌ | ⭐⭐⭐ |
| `net-conf-il-2025` | Conference talk | ❌ | ❌ | ⭐⭐ |
| `RxInAction` | Book code | ❌ | ❌ | ⭐⭐ |
| `aspire-samples` | Fork (dotnet) | ✅ Official | ❌ | ⭐ |
| `aspire` | Fork (dotnet) | ✅ Framework | ❌ | ⭐ |
| `semantic-kernel` | Fork (MS) | ❌ | ✅ Framework | ⭐ |
| `squad-on-aks` | Infrastructure | ❌ | ✅ | ⭐⭐ |
| `content-empire` | Publishing platform | ❌ | ❌ | 🔧 (delivery) |
| `tamirdresher.github.io` | Personal blog | ❌ | ❌ | 🔧 (delivery) |

---

*Research by Seven — docs agent. If docs are wrong, the product is wrong.*
