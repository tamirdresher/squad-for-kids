# YouTube Video Series Plan — Tamir Dresher

> Generated from 50+ existing presentations in `C:\Users\tamirdresher\OneDrive\lectures\`
> Cross-promotes: Gumroad digital products, Udemy courses, Manning's *Rx.NET in Action* book

---

## Table of Contents

1. [Series Plans (5 Series)](#series-plans)
2. [Quick Win Videos (10 Standalone)](#quick-win-videos)
3. [Production Pipeline](#production-pipeline)

---

## Series Plans

---

### Series 1: ".NET Internals Deep Dive" (10 Episodes)

**Concept:** Take viewers from the CLR surface down to memory layout, async machinery, and runtime internals. Position Tamir as *the* .NET internals expert.

**SEO Keywords:** .NET internals, CLR deep dive, async await internals, .NET memory management, garbage collection .NET, C# performance, .NET threading, Task Parallel Library, .NET 10 new features, C# 14

**Cross-Promotion:** Udemy ".NET Concurrent Programming" course; Gumroad .NET cheatsheets

**Thumbnail Concept:** Dark background with X-ray/blueprint style icons of .NET components, "DEEP DIVE" stamp overlay, episode number badge

| # | Episode Title | Duration | Source Lectures | Slides/Recordings to Reuse | Script Outline | Production Effort |
|---|---|---|---|---|---|---|
| 1 | **The Core of .NET: How Your Code Actually Runs** | 20 min | `The Core of .NET Core\Tamir Dresher - The Core of DotNet Core - Update Prague.pptx` (4.93 MB) | Slides 1-25 (CLR boot, JIT, assembly loading) | Hook: "You press F5 — what happens next?" → Host startup → Assembly resolution → JIT compilation → Execution | Slides-with-voice |
| 2 | **ASP.NET Core Request Pipeline Internals** | 25 min | `ASP.NET Core Internals\Tamir Dresher - ASP.NET Core Internals.pptx` (2.91 MB) | Full deck; middleware pipeline diagrams | Hook: "Every HTTP request passes through 12+ layers" → Kestrel → Middleware pipeline → Routing → Endpoint execution | Slides-with-voice |
| 3 | **ASP.NET Core Deep Dive: From Kestrel to Controller** | 25 min | `ASP.NET Core Internals (Deep Dive)\Tamir Dresher - ASP.NET Core Internals.pptx` (2.29 MB) + SVG diagrams (`middleware-pipeline.svg`, `mvc-endpoint.svg`, `swimlane-aspnet-extends-dotnet.svg`) | Architecture SVGs + slides | Hook: "HTTP/SYS vs Kestrel — when to use which?" → Transport layer → HTTP parsing → Model binding deep dive | Slides-with-voice + diagram overlays |
| 4 | **The Async Processing World of .NET** | 30 min | `The Asynchronous Processing World of .NET\The Asynchronous Processing World of NET.pptx` (55.25 MB!) | Massive deck — split into episodes 4 & 5 (first half: async/await mechanics) | Hook: "async/await is syntactic sugar — for what?" → State machine generation → SynchronizationContext → ConfigureAwait truth | Slides-with-voice |
| 5 | **Async Streams & IAsyncEnumerable** | 20 min | `DotNetAsyncStreams\Tamir Dresher - DotNet Async Streams - GoTech 2022.pptx` (18.64 MB) | GoTech 2022 conference version (most polished) | Hook: "Streaming data without blocking threads" → yield + async combined → Real-world: gRPC streams, EF Core → Cancellation patterns | Slides-with-voice |
| 6 | **Concurrent Programming: Threads, Tasks & Synchronization** | 25 min | `Concurrent programming in dotnet\1 Introduction to Parallel Programming.pptx` (3.56 MB) + `2 Basic .NET Threading and Synchronization.pptx` (4.41 MB) | Combine intro + threading decks | Hook: "Every .NET developer gets threading wrong" → Thread vs Task → lock vs SemaphoreSlim → Common deadlock patterns | Slides-with-voice |
| 7 | **Task Parallel Library & Dataflow Networks** | 25 min | `Concurrent programming in dotnet\4 TPL Basics.pptx` (3.05 MB) + `6 Advanced TPL.pptx` (3.80 MB) + `B11 TPL Data Flow Networks.pptx` (4.83 MB) | Three decks merged for advanced content | Hook: "Process 1M records in parallel — correctly" → Parallel.ForEachAsync → Channels → TPL Dataflow blocks → Pipeline pattern | Slides-with-voice |
| 8 | **.NET Memory Internals & GC Adventures** | 25 min | `Reversim 2019 - Clarizen GC Adeventures\` (check for PPTX) + `Concurrent programming in dotnet\7 Diagnostics & Profiling.pptx` (3.41 MB) | GC adventures talk + profiling slides | Hook: "Your app is slow — is it the GC?" → Generations → LOH/POH → GC modes → dotnet-counters → Real incident walkthrough | Slides-with-voice |
| 9 | **Debugging Tricks You Wish You Knew** | 25 min | `Debugging Tricks you wish you knew\Debugging Tricks you wish you knew - Tamir Dresher - Odessa 2019.pptx` (32.90 MB) | Odessa 2019 version (most comprehensive, 32 MB of screenshots) | Hook: "5 debugging tricks even senior devs miss" → Conditional breakpoints → DataTips → Parallel Stacks → Time Travel Debugging → OzCode | Screen recording + slides |
| 10 | **.NET 10 & C# 14: What Actually Matters** | 20 min | `netconf2025\Beyond the Announcements - Practical Highlights from .NET 10 ^0 CSharp 14.pptx` (5.29 MB) + PDF | Most recent talk — fresh content! | Hook: "I watched all the .NET Conf sessions so you don't have to" → Top 5 practical features → Performance improvements → Migration guide | Slides-with-voice |

**Total Series Duration:** ~240 minutes (4 hours)
**Estimated Production Time:** 5-7 days (slides already exist, need narration + light editing)

---

### Series 2: "Building Distributed Systems with .NET Aspire" (8 Episodes)

**Concept:** Progressive course from "What is Aspire?" to custom resources and production deployment. Based on the full 3-day course material (the richest content in the collection).

**SEO Keywords:** .NET Aspire tutorial, distributed systems .NET, microservices .NET, service discovery, OpenTelemetry .NET, Aspire deployment, cloud native .NET, Aspire custom resources, distributed testing

**Cross-Promotion:** Gumroad Aspire course bundle; link to full 3-day training offering

**Thumbnail Concept:** .NET Aspire logo center, connected service icons (Redis, Postgres, Kafka) radiating outward, gradient purple-blue background

**Primary Source:** `C:\Users\tamirdresher\OneDrive\lectures\.NET Aspire\`

| # | Episode Title | Duration | Source Files | Content Extraction | Script Outline | Production Effort |
|---|---|---|---|---|---|---|
| 1 | **What is .NET Aspire? (And Why You Need It)** | 15 min | `Building Distributed Systems with Aspire - Tamir Dresher.pptx` (17.84 MB) — Day 1 slides 1-15 | Intro + architecture overview | Hook: "Microservices are hard. Aspire makes them manageable." → Problem statement → Aspire building blocks → AppHost concept → 5-minute demo | Slides-with-voice + VS demo |
| 2 | **Service Defaults & Observability Out of the Box** | 20 min | Same PPTX — Day 1: Service Defaults section + `Building Distributed Systems with Aspire - Tamir Dresher.md` (course notes) | AddServiceDefaults deep dive | Hook: "Zero-config observability" → OpenTelemetry auto-instrumentation → Health checks → HttpClient resiliency → Before/after dashboard comparison | Slides-with-voice + dashboard demo |
| 3 | **Service Discovery: No More Hardcoded URLs** | 18 min | Same PPTX — Day 1: Service Discovery section | Service discovery mechanics | Hook: "localhost:5001 in production? Never again." → How discovery works → Named vs unnamed endpoints → DNS vs config-based → Docker Compose comparison | Slides-with-voice |
| 4 | **Aspire Integrations: Redis, Postgres, Kafka & More** | 22 min | Same PPTX — Day 2: Integrations section + `NET Aspire - AWS meetup 2024 - Tamir Dresher.pptx` (8.98 MB) for AWS angle | Integration patterns + AWS content | Hook: "Add a database in 3 lines of code" → Built-in integrations → Container resources → Azure resources → Custom integrations → Kafka deep dive | Slides-with-voice + live coding |
| 5 | **Parameters, Commands & Endpoint Customization** | 18 min | Same PPTX — Day 2: Customizations section | Advanced configuration | Hook: "Your Aspire app needs real-world config" → Parameters (secrets, connection strings) → Custom commands → Endpoint URLs → Environment-specific config | Slides-with-voice |
| 6 | **Publishing & Deploying Aspire Apps** | 25 min | Same PPTX — Day 2: Publish Mode section | Deployment pipeline | Hook: "From `dotnet run` to production in one command" → Aspire Manifest → aspire publish vs deploy → Docker target → Kubernetes target → Azure target → Bicep customization | Slides-with-voice + CLI demo |
| 7 | **Aspire Internals: Resources, Annotations & Lifecycle** | 22 min | Same PPTX — Day 3: Internals section | Architecture deep dive | Hook: "Build your own Aspire integration" → IResource interface → Annotations pattern → Lifecycle events → Extension method conventions → Custom resource walkthrough | Slides-with-voice + code |
| 8 | **Distributed Testing with Aspire** | 20 min | Same PPTX — Day 3: Testing section | Testing patterns | Hook: "Integration test your entire distributed system" → Aspire.Hosting.Testing → Full AppHost test launch → Random ports → Playwright UI testing → CI/CD integration | Slides-with-voice + test runner demo |

**Supplementary Sources:**
- `NET Aspire - NET Conf IL 2024 - Tamir Dresher.pptx` (9.72 MB) — can extract conference-style condensed overview for Episode 1
- `NET Aspire - AWS meetup 2024 - Tamir Dresher.pptx` (8.98 MB) — AWS-specific Aspire content for Episode 4
- `Aspire Course Prerequisites.docx` — viewer prerequisites checklist
- `NET Aspire Syllabus.docx` — course structure reference

**Total Series Duration:** ~160 minutes (2.7 hours)
**Estimated Production Time:** 4-5 days

---

### Series 3: "AI Agents & Semantic Kernel for .NET Developers" (6 Episodes)

**Concept:** From LLM basics to production multi-agent systems. Unique angle: .NET-first AI development with enterprise patterns (MCP, Aspire orchestration, DevBox).

**SEO Keywords:** Semantic Kernel tutorial, AI agents C#, MCP protocol .NET, multi-agent AI, LLM C# integration, AI agent orchestration, Playwright MCP, GitHub Copilot agents, .NET AI development

**Cross-Promotion:** Gumroad SK starter kit; Squad framework (open source); Semantic Kernel bootcamp offering

**Thumbnail Concept:** Robot/agent icon with C# logo, neural network visualization background, "AI AGENTS" in bold tech font

| # | Episode Title | Duration | Source Files | Content Extraction | Script Outline | Production Effort |
|---|---|---|---|---|---|---|
| 1 | **Getting Started with Semantic Kernel in C#** | 20 min | `Semantic Kernel\Intro to Semantic Kernel.pptx` (4.11 MB, 27 slides) + `Semantic Kernel Agents Bootcamp\Tamir Dresher - Creating AI Applications and Agents with CSharp - Full.pptx` (25.11 MB) — Module 1 | Intro slides + bootcamp Day 1 content | Hook: "Call GPT-4 from C# in 5 lines" → What is SK → Kernel + Connectors → Chat completion → Prompt templates → First working agent | Slides-with-voice + VS Code demo |
| 2 | **Building Your First AI Agent: State, Memory & History** | 22 min | `Semantic Kernel Agents Bootcamp\Tamir Dresher - Creating AI Applications and Agents with CSharp - Day1.pptx` (20.28 MB) — Module 2 | Agent framework deep dive | Hook: "Agents that remember context" → Agent lifecycle → Chat history management → History reducers (cost control) → Structured instructions → Stateful conversations | Slides-with-voice + demo |
| 3 | **Supercharging Agents: Plugins, OpenAPI & MCP Tools** | 25 min | Same Full PPTX — Module 3 + `Semantic Kernel Agents Bootcamp\AI Assisstant Demo.mp4` (16 MB), `assisstant demo.mp4` (7.17 MB), `assisstant demo2.mp4` (8.23 MB) | Plugin framework + demo recordings | Hook: "Give your agent superpowers" → Function calling → Plugins → OpenAPI integration → MCP tools → Safety & approval patterns → Live demo with existing recordings | Slides + embedded demo video |
| 4 | **Multi-Agent Orchestration: Architect, Developer & Tester** | 25 min | Same Full PPTX — Module 4 (SKCodeAssistant capstone) | Multi-agent patterns | Hook: "3 AI agents collaborating on your code" → Role routing → Turn-taking → Adjudication → SKCodeAssistant walkthrough → VS Code extension demo | Slides-with-voice + screen recording |
| 5 | **Scaling AI Agents for Production** | 25 min | `Scaling and Coordinating AI Agents for Dev&Prod\Scaling and Coordinating AI Agents for Dev&Prod.pptx` (35.44 MB, 53 slides) | Production scaling patterns | Hook: "From demo to production AI agents" → Git worktrees for parallel agents → Playwright MCP (giving agents eyes) → Voice MCP → DevBox for cloud agents → Background agent patterns | Slides-with-voice |
| 6 | **Coordinating AI Agents with .NET Aspire** | 20 min | Same Scaling PPTX — Aspire sections + Squad framework demos | Aspire + MCP integration | Hook: "Orchestrate 10 agents like microservices" → Aspire-MCP-Proxy → Isolation between agents → NoteTaker.AppHost demo → Tool approvals → Monitoring & observability | Slides-with-voice + live demo |

**Supplementary Sources:**
- `Scaling and Coordinating AI Agents for Development - Tamir Dresher.pdf` (5.55 MB) — PDF handout for viewers
- `Semantic Kernel Agents Bootcamp\SemanticKernel_Course_Agenda.docx` — detailed module breakdown
- `Semantic Kernel Agents Bootcamp\Prerequisites.docx` — viewer setup guide
- Demo videos in bootcamp folder — 3 recordings totaling ~31 MB

**Total Series Duration:** ~137 minutes (2.3 hours)
**Estimated Production Time:** 4-5 days

---

### Series 4: "Reactive Programming Masterclass with Rx.NET" (6 Episodes)

**Concept:** From the author of Manning's *Rx.NET in Action*. Covers Rx from first principles to advanced testing patterns. Unique credibility as the literal book author.

**SEO Keywords:** Rx.NET tutorial, reactive programming C#, IObservable, reactive extensions, event-driven C#, Rx testing, TestScheduler, System.Reactive, observable patterns, LINQ to events

**Cross-Promotion:** Manning *Rx.NET in Action* book (affiliate link); Gumroad Rx cheatsheet; Udemy course

**Thumbnail Concept:** Marble diagram visualization, flowing data streams, "MASTERCLASS" badge, book cover thumbnail in corner

| # | Episode Title | Duration | Source Files | Content Extraction | Script Outline | Production Effort |
|---|---|---|---|---|---|---|
| 1 | **Reactive Extensions 101: Why Rx Changes Everything** | 20 min | `Rx101\Rx 101 - Tamir Dresher.pptx` (5.13 MB) + `Rx101\excel.gif` + `Rx101\Sales.xlsx` | Core Rx101 deck | Hook: "Events are streams — treat them that way" → Push vs Pull → IObservable/IObserver → Your first Observable → Marble diagrams explained → Excel demo with Sales data | Slides-with-voice + Excel demo |
| 2 | **Building Responsive Applications with Rx** | 25 min | `Building Responsive Applications with Rx\Building Responsive Application with Rx - CodeMash - Tamir Dresher - Copy.pptx` (5.62 MB) | CodeMash version (most complete) | Hook: "Your UI freezes because you're doing events wrong" → Throttle/Debounce → Buffer → Sample → Window → Real-time search autocomplete → Stock ticker demo | Slides-with-voice + UI demo |
| 3 | **Rx Operators Deep Dive: Transform, Filter, Combine** | 25 min | `ReactiveExtensions\RX.pptx` (1.22 MB) + `Concurrent programming in dotnet\9 Reactive Extensions (Rx).pptx` (5.92 MB) | Combine both Rx decks | Hook: "Master the 20 operators that cover 80% of use cases" → Select/Where/SelectMany → Merge/Zip/CombineLatest → GroupBy → Error handling (Catch, Retry, OnErrorResumeNext) | Slides-with-voice |
| 4 | **Testing Time & Concurrency with Rx Schedulers** | 22 min | `Testing Time and Concurrency Rx\Testing Time and Concurrency Rx.pptx` (4.82 MB) + PDF (2.42 MB) | Full testing deck | Hook: "Test async code that takes 5 minutes — in 5 milliseconds" → TestScheduler → Virtual time → AdvanceTo/AdvanceBy → Testing marble diagrams → CI-friendly Rx tests | Slides-with-voice |
| 5 | **Rx in the Real World: Patterns & Anti-Patterns** | 20 min | Multiple sources: `Building Responsive Applications with Rx\Building Responsive Application with Rx - RigaDevDays - Tamir Dresher.pptx` (3.77 MB) + `Building Responsive Applications with Rx\Building Responsive Application with Rx - Confoo - Tamir Dresher.pptx` (5.50 MB) | Extract unique patterns from each conference version | Hook: "Rx code that works vs Rx code that breaks at 3 AM" → Subscription management → Hot vs Cold pitfalls → Memory leaks → Backpressure → When NOT to use Rx | Slides-with-voice |
| 6 | **From Rx.NET to Async Streams: The Evolution** | 20 min | `DotNetAsyncStreams\Tamir Dresher - DotNet Async Streams.pptx` (3.26 MB) + Rx decks for comparison | Bridge Rx → modern .NET | Hook: "Is Rx dead? (No, but know when to use what)" → IAsyncEnumerable vs IObservable → Pull vs Push decision tree → Migration patterns → Channel + Rx hybrid → Modern .NET reactive patterns | Slides-with-voice |

**Supplementary Sources:**
- `Rx101\Tamir Dresher - Reactive Extensions (Rx) 101 .pdf` (1.49 MB) — viewer handout
- `Testing Time and Concurrency Rx\Testing Time and Concurrency Rx.NET Schedulers.pdf` (2.42 MB) — reference PDF
- `Rx101\points.rtf` — talking points reference
- `RX2.pptx` (root level, 1.22 MB) — additional Rx content

**Total Series Duration:** ~132 minutes (2.2 hours)
**Estimated Production Time:** 4-5 days

---

### Series 5: "Cloud Architecture Patterns for .NET" (8 Episodes)

**Concept:** Battle-tested cloud patterns from conference talks spanning 2016-2024. Combines theory with real-world implementation stories. Rich with PDF references from NDC Oslo research.

**SEO Keywords:** cloud design patterns, microservices .NET, event-driven architecture, RabbitMQ .NET, Kubernetes .NET, containers .NET developers, CQRS, circuit breaker pattern, saga pattern, service mesh

**Cross-Promotion:** Aspire series (Series 2); Gumroad architecture decision templates; consulting services

**Thumbnail Concept:** Cloud infrastructure diagram style, service boxes connected by arrows, pattern name prominently displayed, "ARCHITECTURE" label

| # | Episode Title | Duration | Source Files | Content Extraction | Script Outline | Production Effort |
|---|---|---|---|---|---|---|
| 1 | **Cloud Design Patterns That Actually Matter** | 25 min | `Cloud Patterns\Cloud Patterns- Tamir Dresher.pptx` (6.65 MB) + `NDC Oslo 2016\CloudDesignPatternsBook-PDF.pdf` + `NDC Oslo 2016\AWS_Cloud_Best_Practices.pdf` | Core patterns deck + AWS/Azure references | Hook: "37 cloud patterns exist — you need 7" → Circuit Breaker → Retry → Bulkhead → Cache-Aside → CQRS → Event Sourcing → Saga → When to use each | Slides-with-voice |
| 2 | **Event-Driven Architecture from Zero to Production** | 30 min | `Event driven for bootcamp\Event Driven Architecture - Junior Bootcamp.pptx` (15.33 MB) + **443 MB recording available** | Bootcamp slides + can extract clips from recording | Hook: "Every modern system is event-driven (or should be)" → Events vs Commands → Event bus patterns → Eventual consistency → Ordering guarantees → Dead letter queues | Slides-with-voice (or use recording excerpts) |
| 3 | **Messaging Patterns with RabbitMQ** | 25 min | `Messaging Patterns from the trenches\Tamir Dresher - Messaging Patterns from the trenches.pptx` (5.08 MB) + `Tamir Dresher - Messaging Basics with RabbitMQ PS^0FX.pptx` (5.86 MB) | Two complementary decks | Hook: "Messages get lost. Here's how to prevent it." → Exchange types → Routing patterns → Publisher confirms → Consumer acknowledgments → Poison messages → RabbitMQ management UI tour | Slides-with-voice |
| 4 | **Breaking the Monolith to Microservices** | 25 min | `ArchitectureNext2018\Breaking the monolith to microservice with k8s - Tamir Dresher.pptx` (7.20 MB) | ArchitectureNext 2018 talk | Hook: "Don't rewrite. Strangle." → Strangler Fig pattern → Domain boundary identification → Data decomposition → API gateway → Service mesh → Real migration timeline | Slides-with-voice |
| 5 | **Data-Driven Architecture Anatomy** | 20 min | `Anatomy of Data-Driven Architecture\Tamir Dresher - Anatomy of a Data Driven Architecture 25min.pptx` (9.25 MB) + **25-min recording** (40 MB) + **45-min recording** (61 MB) | Use existing 25-min recording directly or re-narrate slides | Hook: "Your data architecture determines your system's fate" → Data flow patterns → Event store → Projection patterns → Read/Write model separation → Real architecture walkthrough | **Can publish 25-min recording directly** or re-narrate |
| 6 | **Containers for .NET Developers** | 22 min | `Containers for .NET Developers\Containers for .NET Developers.pptx` (4.90 MB) + `Containers for .NET Developers\docker-cheat-sheet.pdf` | Container fundamentals deck | Hook: "Docker isn't scary — here's proof" → Dockerfile for .NET → Multi-stage builds → .NET container optimization → Docker Compose → Container registries → Security scanning | Slides-with-voice + terminal demo |
| 7 | **Kubernetes Orchestration for .NET Apps** | 25 min | `Kubernetes\Containers and Orchestration.pptx` (7.17 MB) + K8s sections from `ArchitectureNext2018\Breaking the monolith to microservice with k8s - Tamir Dresher.pptx` | Combined K8s content | Hook: "Deploy, scale, heal — automatically" → Pods & Deployments → Services & Ingress → ConfigMaps & Secrets → Health probes → Horizontal Pod Autoscaler → Helm charts intro | Slides-with-voice |
| 8 | **Workflow Orchestration & Saga Patterns** | 20 min | `Workflow orchestration\Workflow orchestration.docx` + patterns from `Cloud Patterns` deck + `Event driven for bootcamp` saga sections | Combine multiple sources | Hook: "Long-running processes that don't fail silently" → Orchestration vs Choreography → Saga pattern deep dive → Compensation logic → Durable Functions → Temporal.io comparison | Slides-with-voice (needs more slide creation) |

**Supplementary Sources:**
- `NDC Oslo 2016\` — 19 PDF research papers on distributed systems (Byzantine fault tolerance, Paxos, vector clocks, 2PC)
- `ArchitectureNext2018\Cloud Patterns - Tamir Dresher - ArchitectureNext2018.pptx` (9.72 MB) — updated patterns deck
- `ArchitectureNext2018\Container Techs and Orechstrators trends.xlsx` — container ecosystem comparison data
- `Cloud Patterns\Cloud Patterns - Tamir Dresher.pdf` (3.03 MB) — viewer handout
- `Messaging Patterns from the trenches\script.docx` — existing talk script

**Total Series Duration:** ~192 minutes (3.2 hours)
**Estimated Production Time:** 5-6 days

---

## Quick Win Videos

> 10 standalone videos that can be produced **TODAY** from existing content with minimal editing.

| # | Video Title | Source File | Why It's a Quick Win | Production Steps | Est. Views Potential |
|---|---|---|---|---|---|
| 1 | **"5 Debugging Tricks Every .NET Dev Needs"** | `Debugging Tricks you wish you knew\Debugging Tricks you wish you knew - Tamir Dresher - Odessa 2019.pptx` (32.9 MB) | 32 MB of polished screenshots + demos; viral topic | Extract top 5 tricks → Record 10-min narration over slides → Add intro/outro | High (debugging = evergreen) |
| 2 | **"Data-Driven Architecture in 25 Minutes"** | `Anatomy of Data-Driven Architecture\Tamir Dresher - Anatomy of a Data Driven Architecture - 25min.mp4` (40 MB) | **Recording already exists!** Just needs intro/outro | Add branded intro (15s) → Upload existing recording → Add end screen with CTA | Very High (zero production) |
| 3 | **"Data-Driven Architecture Deep Dive (45 min)"** | `Anatomy of Data-Driven Architecture\Tamir Dresher - Anatomy of a Data Driven Architecture - 45min.mp4` (61 MB) | **Recording already exists!** Longer version for engaged audience | Add branded intro → Upload existing recording → Add chapters + end screen | High (zero production) |
| 4 | **".NET 10 & C# 14: What Actually Matters"** | `netconf2025\Beyond the Announcements - Practical Highlights from .NET 10 ^0 CSharp 14.pptx` (5.29 MB) | Timely content (most recent talk); strong search demand | Narrate over existing slides → 15-20 min video → Upload with .NET 10 keywords | Very High (trending topic) |
| 5 | **"Rx.NET in 10 Minutes — From Zero to Reactive"** | `Rx101\Rx 101 - Tamir Dresher.pptx` (5.13 MB) + `excel.gif` | Concise intro with visual demos; book promotion opportunity | Extract first 15 slides → Fast-paced narration → Link to book in description | Medium-High |
| 6 | **"Semantic Kernel Quick Start: Your First AI Agent in C#"** | `Semantic Kernel\Intro to Semantic Kernel.pptx` (4.11 MB, 27 slides) | Hot topic (AI + C#); compact deck ready to go | Narrate full 27-slide deck → 15-min video → Link to bootcamp | Very High (AI trend) |
| 7 | **"What is .NET Aspire? 10-Minute Overview"** | `NET Aspire - NET Conf IL 2024 - Tamir Dresher.pptx` (9.72 MB) | Conference-condensed version; perfect for short format | Extract overview slides → 10-min narration → CTA to full Aspire series | High |
| 8 | **"Event-Driven Architecture Bootcamp Recording"** | `Event driven for bootcamp\Payoneer Boot-Camp - Event driven by @Tamir Dressher-20210830_103131-Meeting Recording.mp4` (443 MB) | **Full recording exists!** Extract highlights or upload full | Option A: Upload full (long-form) Option B: Extract 3-5 best segments as shorts | Medium (length challenge) |
| 9 | **"Docker for .NET Developers — Everything You Need"** | `Containers for .NET Developers\Containers for .NET Developers.pptx` (4.90 MB) + `docker-cheat-sheet.pdf` | Evergreen topic; cheatsheet = lead magnet | Narrate slides → Offer PDF cheatsheet as free download (email capture) | High (evergreen) |
| 10 | **"Testing Time-Dependent Code with Rx Schedulers"** | `Testing Time and Concurrency Rx\Testing Time and Concurrency Rx.pptx` (4.82 MB) | Unique niche topic; establishes expertise | Narrate deck → 15-min video → "From the author of Rx.NET in Action" positioning | Medium (niche but loyal) |

### Quick Win Priority Order (produce in this sequence):
1. **#2 & #3** — Zero production effort (upload existing recordings today)
2. **#4** — Trending topic (.NET 10), time-sensitive
3. **#6** — AI hype cycle, massive search volume
4. **#1** — Evergreen debugging content, high shareability
5. **#7** — Aspire funnel for full series
6. **#5, #9, #10** — Steady content pipeline
7. **#8** — Repurpose recording (edit first for quality)

---

## Production Pipeline

### 1. PPTX → Video Conversion

#### Option A: Narration-Only (Fastest — 2-3 hours per video)

```powershell
# Step 1: Export PPTX to images
# Use LibreOffice (free) or PowerShell COM automation
$pptx = "C:\Users\tamirdresher\OneDrive\lectures\.NET Aspire\Building Distributed Systems with Aspire  - Tamir Dresher.pptx"

# PowerShell COM export to PNG
$ppt = New-Object -ComObject PowerPoint.Application
$presentation = $ppt.Presentations.Open($pptx)
$presentation.Export("C:\temp\slides", "PNG")
$presentation.Close()
$ppt.Quit()

# Step 2: Record narration with OBS Studio or Audacity
# Tips: Use Blue Yeti mic, quiet room, 44.1kHz WAV

# Step 3: Combine slides + audio with ffmpeg
# Create a file list with durations per slide
# slides.txt format:
# file 'slide001.png'
# duration 15
# file 'slide002.png'
# duration 20

ffmpeg -f concat -i slides.txt -i narration.wav `
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" `
  -c:v libx264 -preset medium -crf 23 `
  -c:a aac -b:a 192k `
  -pix_fmt yuv420p `
  -movflags +faststart `
  output.mp4
```

#### Option B: Slides-With-Voice (Recommended — 3-4 hours per video)

```powershell
# Use OBS Studio with:
# - Display Capture (PowerPoint slideshow)
# - Audio Input (microphone)
# - Webcam overlay (optional, bottom-right corner)

# OBS Settings for YouTube:
# Resolution: 1920x1080
# FPS: 30
# Encoder: x264 or NVENC
# Bitrate: 6000 kbps
# Audio: 160 kbps AAC

# Post-processing with ffmpeg:
ffmpeg -i raw_recording.mkv `
  -vf "scale=1920:1080" `
  -c:v libx264 -preset slow -crf 20 `
  -c:a aac -b:a 192k `
  -movflags +faststart `
  final_video.mp4
```

#### Option C: Existing Recordings (Zero Production)

```powershell
# For videos that already have recordings (Data-Driven Architecture, Event-Driven bootcamp)

# Add branded intro/outro:
ffmpeg -i intro.mp4 -i existing_recording.mp4 -i outro.mp4 `
  -filter_complex "[0:v][0:a][1:v][1:a][2:v][2:a]concat=n=3:v=1:a=1[outv][outa]" `
  -map "[outv]" -map "[outa]" `
  -c:v libx264 -preset medium -crf 22 `
  -c:a aac -b:a 192k `
  final_with_branding.mp4

# Add chapters for YouTube:
# Export chapter markers as description text:
# 0:00 Introduction
# 2:15 Architecture Overview
# 8:30 Event Patterns
# etc.
```

### 2. Batch Production Workflow

```
Week 1: Quick Wins
├── Day 1: Upload recordings #2, #3 (zero effort)
├── Day 2: Record narration for #4 (.NET 10) + #6 (Semantic Kernel)
├── Day 3: Edit + upload #4 and #6
├── Day 4: Record #1 (Debugging) + #7 (Aspire overview)
└── Day 5: Edit + upload #1 and #7

Week 2-3: Series 1 (Internals) Episodes 1-5
├── Day 1-2: Record episodes 1-3 back-to-back
├── Day 3: Edit all three
├── Day 4-5: Record episodes 4-5
└── Day 6: Edit + schedule uploads

Week 4-5: Series 2 (Aspire) Episodes 1-4
├── Follow same pattern

Week 6-7: Series 3 (AI Agents) Episodes 1-3
├── Follow same pattern

Week 8-9: Series 4 (Rx) Episodes 1-3
├── Follow same pattern

Week 10-12: Complete remaining episodes across all series
```

### 3. Upload Schedule Recommendation

```
OPTIMAL SCHEDULE (sustainable pace):

Monday:    Series episode (long-form, 20-30 min)
Thursday:  Quick win or standalone (10-15 min)

ALTERNATIVE (aggressive launch):

Monday:    Series episode
Wednesday: Quick win / Short
Friday:    Series episode (different series)

YOUTUBE SHORTS (bonus content):
- Extract 60-second clips from each episode
- Post 2-3 shorts per week
- Source: Most surprising demo moments or "Did you know?" facts
```

### 4. Video Metadata Template

```yaml
# For each video, prepare:
title: "[Series Name] Ep N: Episode Title | Tamir Dresher"
description: |
  In this episode, I cover [topic]. We'll explore [key points].
  
  📚 Resources:
  - Slides: [Gumroad link]
  - Code: [GitHub link]
  - Book: Rx.NET in Action (Manning) - [affiliate link]
  
  🎓 Full Courses:
  - .NET Aspire Training: [link]
  - Semantic Kernel Bootcamp: [link]
  - Udemy: [link]
  
  ⏱️ Chapters:
  0:00 Introduction
  [timestamps]
  
  #dotnet #csharp #[topic-specific tags]

tags:
  # Always include:
  - tamir dresher
  - dotnet
  - csharp
  # Series-specific (see each series above for full keyword lists)

thumbnail: "[Use Canva template with series-specific design]"
playlist: "[Series Name]"
end_screen: "Next episode + Subscribe"
cards: "Link to related series at relevant moments"
```

### 5. Cross-Promotion Strategy

| Touchpoint | Action |
|---|---|
| **Video Description** | Gumroad product links, Udemy course link, book affiliate link |
| **Pinned Comment** | "Want the full course? [Gumroad/Udemy link]" |
| **End Screen** | Next episode + best related video + subscribe |
| **Cards** | Pop up at topic transitions linking to related series |
| **Community Tab** | Weekly poll: "Which series should I continue next?" |
| **Shorts** | 60-sec clips with "Full video in description" CTA |
| **Email List** | Notify subscribers of new uploads; offer exclusive bonus content |

### 6. Content Repurposing Matrix

```
Each episode produces:
├── 1x YouTube video (primary)
├── 2-3x YouTube Shorts (60-sec clips)
├── 1x Blog post (transcript + screenshots)
├── 1x LinkedIn post (key insight + video link)
├── 1x Twitter/X thread (5 key points)
├── Slides PDF → Gumroad (paid bundle)
└── Newsletter mention → email list growth
```

---

## Content Depth Highlights

### .NET Aspire Course — Key Highlights
Based on analysis of the full 3-day course material:

- **Day 1 (Foundations):** Service Defaults (auto-OpenTelemetry, Health Checks, Resiliency), Service Discovery (eliminate hardcoded URLs), AppHost orchestration
- **Day 2 (Advanced):** Parameters & secrets management, Custom integrations (Kafka example), **Publisher Model** (Docker/K8s/Azure targets), Aspire Manifest (IL-like intermediate representation for distributed apps), `aspire publish` vs `aspire deploy` separation
- **Day 3 (Internals):** IResource/IResourceAnnotation interfaces, Lifecycle events system, Custom resource development, **Distributed testing** with Aspire.Hosting.Testing (entire AppHost as test fixture), Playwright integration for E2E testing
- **Enterprise:** Aspire1p support, Geneva integration, EV2 deployment, compliance policies

### AI Agents Talk — Key Highlights
Based on analysis of the 53-slide presentation:

- **Git Worktrees** for parallel agent execution (isolated environments)
- **MCP Integration:** Playwright MCP (browser automation for agents), Voice MCP (speech I/O), GitHub Copilot CLI integration
- **Production Patterns:** Tool approval mechanisms, agent mode configuration, DevBox cloud-based agent environments
- **Distributed Agents:** Aspire-MCP-Proxy for isolation, AppHost orchestration for multi-agent systems, Live Share + Codespaces for remote agents
- **Demo:** NoteTaker.AppHost — complete working example of orchestrated AI agents

### Semantic Kernel Bootcamp — Key Highlights
Based on analysis of the 4-module bootcamp (12 hours):

- **Module 1:** Kernel + Connectors, prompt templates, chat completion from C#
- **Module 2:** Agent lifecycle, state management, chat history reducers (cost optimization)
- **Module 3:** Plugins, OpenAPI wiring, MCP tools integration, function calling safety
- **Module 4 (Capstone):** SKCodeAssistant — multi-agent system with Architect/Developer/Tester agents, VS Code extension, observability & evaluation

---

## Total Content Inventory Summary

| Category | Slide Decks | Recordings | Total Size | YouTube Episodes |
|---|---|---|---|---|
| .NET Internals | 25+ PPTX files | 0 | ~200 MB | 10 |
| .NET Aspire | 4 PPTX + MD + PDF | 0 | ~80 MB | 8 |
| AI & Semantic Kernel | 5 PPTX + demos | 3 demo videos | ~150 MB | 6 |
| Reactive Extensions | 8+ PPTX + PDF | 0 | ~55 MB | 6 |
| Cloud Architecture | 10+ PPTX | 3 recordings | ~600 MB | 8 |
| **TOTAL** | **52+ decks** | **6 recordings** | **~1.1 GB** | **38 episodes** |

> **Bottom Line:** 38 full episodes + 10 quick wins = **48 videos** producible from existing content alone, requiring only narration and light editing. At 2 videos/week, this is **6 months of content** without creating a single new slide.
