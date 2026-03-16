---
layout: post
title: "How I Built an AI Squad — The Complete Tool List"
date: 2026-06-29
categories: [ai-engineering, tools]
tags: [ai-agents, squad, tools, github-copilot, developer-tools, automation, dotnet]
description: "Every tool, service, and library used to build a 7-agent AI squad that ships code autonomously. The complete, unabridged list."
image: /assets/images/ai-squad-tools.png
affiliate_disclosure: true
---

People read my [blog series on AI-native engineering](/blog/series/scaling-ai) and ask two things:

1. "Is this real?" *(Yes. 14 PRs merged overnight. 6 security findings. Zero manual prompts.)*
2. "What tools do you actually use?" *(This post.)*

Here's every single tool, service, and library in my AI Squad system. Not the aspirational list — the actual, running-right-now, bills-show-up-on-my-credit-card list. I've organized it by category so you can build your own.

---

## 🧠 The AI Layer

### GitHub Copilot CLI — The Orchestrator
**What it does:** Runs the AI agents. Provides persistent sessions, custom personas, tool integration, and multi-agent coordination.
**Why this one:** Only tool I found that supports true agent teams — not just chat, but agents with identity, memory, and specializations. I tried four other orchestrators before settling here.
**Cost:** $19/month (Copilot Business)
👉 [GitHub Copilot](https://github.com/features/copilot)

### Azure OpenAI Service — Custom AI
**What it does:** Enterprise-grade LLM access for custom integrations beyond Copilot.
**Why this one:** Data stays in your Azure tenant. No training on your data. Required for Microsoft compliance. Also the only option where my security team doesn't send me worried Slack messages.
👉 [Azure OpenAI](https://azure.microsoft.com/en-us/products/ai-services/openai-service)

---

## 💻 Development Environment

### JetBrains Rider — Primary .NET IDE
**What it does:** Full-featured .NET IDE with integrated debugger, profiler, decompiler, and database tools.
**Why this one:** When debugging async agent behavior across multiple services, Rider's tooling is unmatched. The integrated dotMemory and dotTrace save hours of context-switching. Also, the dark theme is objectively the best dark theme in any IDE. I will die on this hill.
**Cost:** $149/year individual
👉 [AFFILIATE:jetbrains:Rider](https://www.jetbrains.com/rider/?JETBRAINS_AID)

### Visual Studio Code — Secondary Editor
**What it does:** Lightweight editing, markdown, quick fixes.
**Why this one:** Free, fast, great extension ecosystem. Copilot integration is excellent for inline suggestions. I use it for everything that isn't heavy .NET work.
👉 [VS Code](https://code.visualstudio.com/) *(Free)*

### JetBrains ReSharper — When in Visual Studio
**What it does:** Code analysis, refactoring, navigation for Visual Studio users.
**Why this one:** When I must use Visual Studio (legacy projects, some debugging scenarios), ReSharper makes it tolerable. It's the difference between "I hate this" and "I can work with this."
👉 [AFFILIATE:jetbrains:ReSharper](https://www.jetbrains.com/resharper/?JETBRAINS_AID)

### Azure DevBox — Cloud Dev Environments
**What it does:** Cloud-hosted development machines with GPU access.
**Why this one:** Hebrew voice cloning experiments need GPU. My laptop doesn't have one. DevBox gives me a cloud workstation with a single click. Plus, my laptop's fan doesn't sound like a jet engine taking off.
👉 [Azure DevBox](https://azure.microsoft.com/en-us/products/dev-box/)

---

## 🔧 The .NET Stack

### .NET 9 — Runtime
**What it does:** Primary runtime for all agent-related code.
**Why:** Performance, ecosystem, Microsoft support. Native AOT for fast cold starts. Also, it's what I've been writing for 15 years. Muscle memory is real.
👉 [.NET](https://dotnet.microsoft.com/) *(Free)*

### BenchmarkDotNet — Performance Measurement
**What it does:** Microbenchmarking framework for .NET. Statistically rigorous performance measurement.
**Why:** Agent systems hit hot paths repeatedly. A 10ms regression per agent call = minutes of delay across a full squad run. BenchmarkDotNet catches these before they hit production.
👉 [BenchmarkDotNet](https://benchmarkdotnet.org/) *(Free, open source)*

### dotnet-trace + PerfView — Diagnostics
**What it does:** Lightweight sampling profiler + detailed performance analysis.
**Why:** When an agent is slow, these tools find the bottleneck in minutes. My squad has a dedicated skill (`dotnet-trace-collect`) that walks you through the diagnostic process.
👉 [dotnet-trace](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-trace) *(Free)*

---

## 🏗 Infrastructure

### GitHub — Source Control + Task Queue
**What it does:** Code hosting, issue tracking, PR reviews, Actions CI/CD.
**Why:** Issues ARE the task queue. PRs ARE the delivery mechanism. GitHub is both the VCS and the workflow engine. My agents don't use a separate project management tool because GitHub IS the project management tool.
👉 [GitHub](https://github.com/)

### Azure Kubernetes Service (AKS)
**What it does:** Managed Kubernetes for production workloads.
**Why:** The DK8S platform at Microsoft runs on AKS. Agent-deployed changes go through real K8s infrastructure with real health checks, rollbacks, and monitoring.
👉 [AKS](https://azure.microsoft.com/en-us/products/kubernetes-service/)

### Docker — Containerization
**What it does:** Reproducible build environments. Every agent's work can be replayed.
👉 [Docker Desktop](https://www.docker.com/products/docker-desktop/) *(Free for personal use)*

### Helm — Kubernetes Packaging
**What it does:** Package and deploy K8s applications. B'Elanna (my infrastructure agent) generates Helm charts. She's better at YAML than I am, which is both useful and slightly humiliating.
👉 [Helm](https://helm.sh/) *(Free)*

### ArgoCD — GitOps
**What it does:** Declarative, Git-based continuous delivery for Kubernetes.
**Why:** When agents create infrastructure changes, ArgoCD syncs them automatically. Git is the source of truth. Always.
👉 [ArgoCD](https://argoproj.github.io/cd/) *(Free, open source)*

---

## 🔌 Integration Layer (MCP Servers)

These are the connectors that let AI agents interact with external systems via the Model Context Protocol. Think of MCP as USB for AI agents — a standardized way to plug into anything:

| MCP Server | What It Does | Source |
|-----------|-------------|--------|
| **Azure DevOps** | Read/write work items, query pipelines, manage repos | Built into Copilot CLI |
| **Outlook** | Send emails, create calendar events, read inbox | [outlook-mcp](https://github.com/XenoXilus/outlook-mcp) |
| **Teams** | Post to channels, search messages | Built into Copilot CLI |
| **GitHub** | Issues, PRs, commits, actions | Built into Copilot CLI |
| **EngineeringHub** | Search internal docs, TSGs, onboarding guides | Internal Microsoft |

---

## ✍️ Content & Documentation

### Markdown — Everything is Markdown
Blog posts, book chapters, agent charters, decision logs, documentation. All markdown. All version-controlled. All PR-reviewable. If it's not in markdown, it doesn't exist.

### edge-tts — Text-to-Speech
**What it does:** Microsoft Edge TTS for generating podcast-style audio from markdown documents.
**Why:** My Podcaster agent converts every research report into a 2-voice conversational summary. It's genuinely useful for reviewing content while walking the dog.
👉 [edge-tts](https://github.com/rany2/edge-tts) *(Free)*

### Grammarly — Writing Quality
**What it does:** Grammar, tone, and clarity checking.
**Why:** Even AI-written content benefits from a final quality pass. The irony of using AI to proofread AI-generated text is not lost on me.
👉 [Grammarly](https://www.grammarly.com/)

---

## 📊 Monitoring & Operations

### Ralph's Watch Loop — Custom
**What it does:** A 5-minute continuous monitoring loop that watches the GitHub issue queue, auto-merges approved PRs, and opens new issues when it discovers work.
**Why:** This is the heartbeat of the entire system. Without Ralph, agents are reactive — they wait for you to tell them what to do. With Ralph, they're proactive — they find work and do it. Ralph is the employee who arrives before everyone else and has the coffee ready.
*Implementation: PowerShell script + Copilot CLI*

### Azure Application Insights — Telemetry
**What it does:** Performance monitoring, error tracking, usage analytics.
**Why:** When agents generate production changes, we need observability. "It worked in my agent's context window" is the new "it works on my machine."
👉 [App Insights](https://azure.microsoft.com/en-us/products/monitor/)

---

## 📚 Reference Books on My Desk

These informed the architecture decisions behind the AI Squad:

| Book | Author | Why It Matters |
|------|--------|----------------|
| [AFFILIATE:amazon:Designing Data-Intensive Applications](https://www.amazon.com/dp/1449373321?tag=tamirdresher2-20) | Martin Kleppmann | Distributed systems fundamentals for agent coordination |
| [AFFILIATE:amazon:Building Microservices](https://www.amazon.com/dp/1492034029?tag=tamirdresher2-20) | Sam Newman | Agent teams = microservices architecture |
| [AFFILIATE:amazon:The Pragmatic Programmer](https://www.amazon.com/dp/0135957052?tag=tamirdresher2-20) | Thomas & Hunt | Software craftsmanship principles for agent design |
| [AFFILIATE:manning:Rx.NET in Action](https://www.manning.com/books/rx-dot-net-in-action?a_aid=8ec75026&a_bid=BANNER_ID) | Dresher (me) | Reactive patterns powering event-driven agent loops |
| [AFFILIATE:amazon:Site Reliability Engineering](https://www.amazon.com/dp/1491929124?tag=tamirdresher2-20) | Beyer et al. (Google) | Reliability patterns for autonomous agent systems |
| [AFFILIATE:amazon:AI Engineering](https://www.amazon.com/dp/1098166302?tag=tamirdresher2-20) | Chip Huyen | Production AI systems — evaluation, deployment, monitoring |

---

## 💰 What It Costs

Let's be honest about the monthly bill:

| Tool | Monthly Cost |
|------|-------------|
| GitHub Copilot Business | $19 |
| JetBrains Rider | ~$12.50 ($149/yr) |
| Azure (DevBox + AKS + misc) | ~$50-150 |
| Grammarly | $12 |
| **Total** | **~$95-195/month** |

**ROI:** In the first week, my squad automated work that would have taken me 40+ hours. The tools pay for themselves before the first billing cycle ends. I tracked this. Meticulously. With spreadsheets. Because I'm that kind of nerd.

---

## The One Tool You Should Start With

If you can only pick one thing from this list: **GitHub Copilot CLI with the Squad framework.**

Everything else is infrastructure to support it. Copilot CLI + Squad gives you agent teams, persistent memory, routing, and coordination — the core of everything described in this post.

Start there. Add tools as you need them. Resist the urge to set up the entire stack on day one. I tried that. It ended with 47 browser tabs, three half-configured services, and a strong desire to go back to writing code by hand.

---

*Building your own AI squad? I'd love to hear about it. What tools are you using that I should try? Find me on [Twitter/X](https://twitter.com/tamaborlin) or drop a comment below.*

---

<small>*Disclosure: Some links on this page are affiliate links. If you purchase through them, I may earn a small commission at no extra cost to you. I only recommend tools I personally use — if it's not in my actual stack, it's not on this page. See my [full affiliate disclosure](/affiliate-disclosure) for details.*</small>


