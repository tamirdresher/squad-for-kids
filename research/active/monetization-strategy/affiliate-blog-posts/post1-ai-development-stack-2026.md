---
layout: post
title: "My AI Development Stack in 2026 — Every Tool I Use Daily"
date: 2026-06-15
tags: [ai-agents, developer-tools, productivity, github-copilot, jetbrains, azure, dotnet]
description: "A working developer's actual tool stack for AI-native software engineering. No hype, just what I use every day."
affiliate_disclosure: true
---

# My AI Development Stack in 2026

*Every tool I use daily as a Principal Engineer building AI agent systems at Microsoft.*

---

I get asked this question at every conference: **"What's your actual stack?"**

Not the aspirational stack. Not the "I tried this once at a hackathon" stack. The one that's running right now, on my machine, making my AI squad work while I sleep. Here's the honest answer — every tool, why I chose it, and what I'd change.

---

## The Foundation: Where Code Lives

### GitHub + GitHub Copilot CLI

Everything starts here. My AI squad — seven specialized agents — lives in a GitHub repo. Issues are the task queue. PRs are the delivery mechanism. [GitHub Copilot CLI](https://github.com/features/copilot) is the orchestration layer that makes the whole system possible.

**Why Copilot CLI specifically?** Because it's the only tool I've found that lets me give a team of AI agents their own persistent context, memory, and specializations. Each agent has a charter. They remember past decisions. They route work based on expertise.

**Cost:** GitHub Copilot Business — $19/month per user. For what I get out of it? Absurdly underpriced.

👉 [GitHub Copilot](https://github.com/features/copilot) — Try the CLI, not just the IDE integration.

---

### JetBrains Rider — My .NET IDE

I know VS Code is free. I know it has great extensions. But for serious .NET development — the kind where I'm debugging async state machines, profiling memory allocations, and navigating a 200K-line codebase — **[JetBrains Rider](https://www.jetbrains.com/rider/) [AFFILIATE_LINK]** is unmatched.

What Rider gives me that VS Code doesn't:
- **Built-in decompiler** — When a NuGet package does something weird, I read the IL
- **Database tools** — SQL Server, PostgreSQL, in the same window
- **dotMemory/dotTrace integration** — Profile without leaving the IDE
- **Structural search** — Find patterns across the whole codebase, not just text

**Cost:** $149/year (individual). Worth every penny.

I've also used **[ReSharper](https://www.jetbrains.com/resharper/) [AFFILIATE_LINK]** for years when I'm in Visual Studio — the refactoring tools alone save hours per week.

👉 [Get Rider](https://www.jetbrains.com/rider/) [AFFILIATE_LINK] | [Get ReSharper](https://www.jetbrains.com/resharper/) [AFFILIATE_LINK]

---

## The AI Layer

### GitHub Copilot (IDE + CLI)

Two different products, both essential:

- **Copilot in IDE:** Autocomplete, chat, code review. You know this already.
- **Copilot CLI:** This is the game-changer. Terminal-based agent orchestration. Persistent sessions. Custom agent personas. This is what runs my AI squad.

The CLI is what lets me say "Team, build the user search feature" and have four agents work in parallel — one on the API, one on docs, one on security review, one on deployment config.

👉 [GitHub Copilot](https://github.com/features/copilot)

### Azure OpenAI Service

For custom AI integrations beyond Copilot. When I need fine-tuned models, custom embeddings, or high-throughput inference, Azure OpenAI gives me enterprise-grade access with the security controls Microsoft requires.

**Key advantage:** Data stays in your Azure tenant. No training on your data. Enterprise compliance baked in.

👉 [Azure OpenAI Service](https://azure.microsoft.com/en-us/products/ai-services/openai-service)

---

## Infrastructure & DevOps

### Azure (Multiple Services)

My AI agents don't just write code — they manage infrastructure. Here's what I actually use:

- **Azure DevBox** — Cloud development environments with GPU access. Essential for voice cloning experiments.
- **Azure Kubernetes Service (AKS)** — Production workloads via the DK8S platform.
- **Azure DevOps** — Pipelines, work tracking, artifacts. Integrated with Squad via MCP servers.
- **Azure Static Web Apps** — Blog hosting with GitHub Actions deploy.

👉 [Azure Free Account](https://azure.microsoft.com/en-us/free/) — Start with $200 credit.

### Docker + Kubernetes

Every agent's work is reproducible. Docker containers for local dev, Kubernetes for production. Helm charts for deployment. ArgoCD for GitOps.

---

## Writing & Documentation

### Markdown + GitHub

All documentation lives in the repo. Blog posts are markdown files. The book manuscript is markdown. Agent charters are markdown. Everything is version-controlled, diff-able, and PR-reviewable.

### Grammarly

Even AI-assisted writing needs proofreading. Grammarly catches the things spell-check misses — tone, clarity, passive voice.

---

## The "Secret Weapons" — Tools Most People Skip

### BenchmarkDotNet

If you're writing performance-sensitive .NET code and you're not benchmarking with [BenchmarkDotNet](https://benchmarkdotnet.org/), you're guessing. My Worf agent runs micro-benchmarks on every hot-path change.

### MCP Servers (Model Context Protocol)

The glue that connects my AI agents to external systems. Outlook, Azure DevOps, Teams, GitHub — all accessible through MCP servers. This is how Ralph reads the issue queue and Kes schedules meetings.

### dotnet-trace + PerfView

For production performance issues, nothing beats `dotnet-trace` for lightweight sampling and PerfView for detailed analysis. My squad has a dedicated skill for diagnosing .NET perf problems.

---

## The Books That Shaped My Thinking

If you want to understand the architecture behind AI agent systems, these are the books I keep coming back to:

📚 **[Designing Data-Intensive Applications](https://www.amazon.com/dp/1449373321?tag=AFFILIATE_TAG)** by Martin Kleppmann — The distributed systems bible. Understanding eventual consistency and event sourcing is critical for multi-agent coordination.

📚 **[The Pragmatic Programmer](https://www.amazon.com/dp/0135957052?tag=AFFILIATE_TAG)** by David Thomas & Andrew Hunt — Still relevant. The "don't repeat yourself" principle applies to AI agent charters too.

📚 **[Building Microservices](https://www.amazon.com/dp/1492034029?tag=AFFILIATE_TAG)** by Sam Newman — Agent teams ARE microservices. Same patterns: independent deployment, clear interfaces, eventual consistency.

📚 **[Rx.NET in Action](https://www.amazon.com/dp/1617293067?tag=AFFILIATE_TAG)** by Tamir Dresher (yes, me) — Reactive programming patterns are the foundation of event-driven agent systems. Ralph's 5-minute watch loop is essentially an observable sequence.

---

## What I'd Change

If I started from scratch today:

1. **Start with Copilot CLI from day one.** I wasted months with custom orchestration before discovering Squad.
2. **Invest in Rider earlier.** The productivity gap vs VS Code widens as your codebase grows.
3. **Set up MCP servers immediately.** The integration surface area is what makes agents truly useful.

---

## The Bottom Line

My stack isn't the cheapest. GitHub Copilot + Rider + Azure adds up. But the ROI is absurd: my AI squad ships code while I sleep, catches security issues I'd miss, and documents everything automatically. The tools pay for themselves in the first week.

*What's in your AI stack? I'm genuinely curious — drop a comment or find me on [Twitter/X](https://twitter.com/tamaborlin).*

---

*Some links on this page are affiliate links. If you purchase through them, I may earn a small commission at no extra cost to you. I only recommend tools I personally use and trust. [Full disclosure](/affiliate-disclosure).*
