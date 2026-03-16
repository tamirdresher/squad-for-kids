---
layout: post
title: "How I Built an AI Squad — The Complete Tool List"
date: 2026-06-29
tags: [ai-agents, squad, tools, github-copilot, developer-tools, automation, dotnet]
description: "Every tool, service, and library used to build a 7-agent AI squad that ships code autonomously. The complete, unabridged list."
affiliate_disclosure: true
---

# How I Built an AI Squad — The Complete Tool List

*Everything it takes to run 7 AI agents that ship code while you sleep.*

---

People read my [blog series on AI-native engineering](/blog/series/scaling-ai) and ask two things:

1. "Is this real?" *(Yes. 14 PRs merged overnight. 6 security findings. Zero manual prompts.)*
2. "What tools do you actually use?" *(This post.)*

Here's every single tool, service, and library in my AI Squad system. Not the aspirational list — the actual, running-right-now list. I've organized it by category so you can build your own.

---

## 🧠 The AI Layer

### GitHub Copilot CLI — The Orchestrator
**What it does:** Runs the AI agents. Provides persistent sessions, custom personas, tool integration, and multi-agent coordination.  
**Why this one:** Only tool I found that supports true agent teams — not just chat, but agents with identity, memory, and specializations.  
**Cost:** $19/month (Copilot Business)  
👉 [GitHub Copilot](https://github.com/features/copilot)

### Azure OpenAI Service — Custom AI
**What it does:** Enterprise-grade LLM access for custom integrations beyond Copilot.  
**Why this one:** Data stays in your Azure tenant. No training on your data. Required for Microsoft compliance.  
👉 [Azure OpenAI](https://azure.microsoft.com/en-us/products/ai-services/openai-service)

---

## 💻 Development Environment

### JetBrains Rider — Primary .NET IDE
**What it does:** Full-featured .NET IDE with integrated debugger, profiler, decompiler, and database tools.  
**Why this one:** When debugging async agent behavior across multiple services, Rider's tooling is unmatched. The integrated dotMemory and dotTrace save hours of context-switching.  
**Cost:** $149/year individual  
👉 **[Get JetBrains Rider](https://www.jetbrains.com/rider/) [AFFILIATE_LINK]**

### Visual Studio Code — Secondary Editor
**What it does:** Lightweight editing, markdown, quick fixes.  
**Why this one:** Free, fast, great extension ecosystem. Copilot integration is excellent for inline suggestions.  
👉 [VS Code](https://code.visualstudio.com/) *(Free)*

### JetBrains ReSharper — When in Visual Studio
**What it does:** Code analysis, refactoring, navigation for Visual Studio users.  
**Why this one:** When I must use Visual Studio (legacy projects, some debugging scenarios), ReSharper makes it tolerable.  
👉 **[Get ReSharper](https://www.jetbrains.com/resharper/) [AFFILIATE_LINK]**

### Azure DevBox — Cloud Dev Environments
**What it does:** Cloud-hosted development machines with GPU access.  
**Why this one:** Hebrew voice cloning experiments need GPU. My laptop doesn't have one. DevBox gives me a cloud workstation with a single click.  
👉 [Azure DevBox](https://azure.microsoft.com/en-us/products/dev-box/)

---

## 🔧 The .NET Stack

### .NET 9 — Runtime
**What it does:** Primary runtime for all agent-related code.  
**Why:** Performance, ecosystem, Microsoft support. Native AOT for fast cold starts.  
👉 [.NET](https://dotnet.microsoft.com/) *(Free)*

### BenchmarkDotNet — Performance Measurement
**What it does:** Microbenchmarking framework for .NET. Statistically rigorous performance measurement.  
**Why:** Agent systems hit hot paths repeatedly. A 10ms regression per agent call = minutes of delay across a full squad run.  
👉 [BenchmarkDotNet](https://benchmarkdotnet.org/) *(Free, open source)*

### dotnet-trace + PerfView — Diagnostics
**What it does:** Lightweight sampling profiler + detailed performance analysis.  
**Why:** When an agent is slow, these tools find the bottleneck in minutes.  
👉 [dotnet-trace](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-trace) *(Free)*

---

## 🏗 Infrastructure

### GitHub — Source Control + Task Queue
**What it does:** Code hosting, issue tracking, PR reviews, Actions CI/CD.  
**Why:** Issues ARE the task queue. PRs ARE the delivery mechanism. GitHub is both the VCS and the workflow engine.  
👉 [GitHub](https://github.com/)

### Azure Kubernetes Service (AKS)
**What it does:** Managed Kubernetes for production workloads.  
**Why:** The DK8S platform at Microsoft runs on AKS. Agent-deployed changes go through real K8s infrastructure.  
👉 [AKS](https://azure.microsoft.com/en-us/products/kubernetes-service/)

### Docker — Containerization
**What it does:** Reproducible build environments. Every agent's work can be replayed.  
👉 [Docker Desktop](https://www.docker.com/products/docker-desktop/) *(Free for personal use)*

### Helm — Kubernetes Packaging
**What it does:** Package and deploy K8s applications. B'Elanna (infrastructure agent) generates Helm charts.  
👉 [Helm](https://helm.sh/) *(Free)*

### ArgoCD — GitOps
**What it does:** Declarative, Git-based continuous delivery for Kubernetes.  
**Why:** When agents create infrastructure changes, ArgoCD syncs them automatically.  
👉 [ArgoCD](https://argoproj.github.io/cd/) *(Free, open source)*

---

## 🔌 Integration Layer (MCP Servers)

These are the connectors that let AI agents interact with external systems via the Model Context Protocol:

### Azure DevOps MCP Server
**What it does:** Agents read/write ADO work items, query pipelines, manage repos.  
👉 Built into Copilot CLI ecosystem

### Outlook MCP Server
**What it does:** Agents send emails, create calendar events, read inbox.  
👉 [outlook-mcp](https://github.com/XenoXilus/outlook-mcp)

### Teams MCP Server
**What it does:** Agents post to Teams channels, search messages.  
👉 Built into Copilot CLI ecosystem

### EngineeringHub MCP Server
**What it does:** Search Microsoft internal documentation, TSGs, onboarding guides.  
👉 Internal Microsoft tool

---

## ✍️ Content & Documentation

### Markdown — Everything is Markdown
Blog posts, book chapters, agent charters, decision logs, documentation. All markdown. All version-controlled. All PR-reviewable.

### edge-tts — Text-to-Speech
**What it does:** Microsoft Edge TTS for generating podcast-style audio from markdown documents.  
**Why:** The Podcaster agent converts every research report into a 2-voice conversational summary.  
👉 [edge-tts](https://github.com/rany2/edge-tts) *(Free)*

### Grammarly — Writing Quality
**What it does:** Grammar, tone, and clarity checking.  
**Why:** Even AI-written content benefits from a final quality pass.  
👉 [Grammarly](https://www.grammarly.com/)

---

## 📊 Monitoring & Operations

### Ralph's Watch Loop — Custom
**What it does:** A 5-minute continuous monitoring loop that watches the GitHub issue queue, auto-merges approved PRs, and opens new issues when it discovers work.  
**Why:** This is the heartbeat of the entire system. Without Ralph, agents are reactive. With Ralph, they're proactive.  
*Implementation: PowerShell script + Copilot CLI*

### Azure Application Insights — Telemetry
**What it does:** Performance monitoring, error tracking, usage analytics.  
**Why:** When agents generate production changes, we need observability.  
👉 [App Insights](https://azure.microsoft.com/en-us/products/monitor/)

---

## 📚 Reference Books on My Desk

These informed the architecture decisions behind the AI Squad:

| Book | Author | Why It Matters |
|------|--------|----------------|
| [Designing Data-Intensive Applications](https://www.amazon.com/dp/1449373321?tag=AFFILIATE_TAG) | Kleppmann | Distributed systems fundamentals for agent coordination |
| [Building Microservices](https://www.amazon.com/dp/1492034029?tag=AFFILIATE_TAG) | Newman | Agent teams = microservices architecture |
| [The Pragmatic Programmer](https://www.amazon.com/dp/0135957052?tag=AFFILIATE_TAG) | Thomas & Hunt | Software craftsmanship principles for agent design |
| [Rx.NET in Action](https://www.amazon.com/dp/1617293067?tag=AFFILIATE_TAG) | Dresher (me) | Reactive patterns powering event-driven agent loops |
| [Site Reliability Engineering](https://www.amazon.com/dp/1491929124?tag=AFFILIATE_TAG) | Google | Reliability patterns for autonomous agent systems |

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

**ROI:** In the first week, my squad automated work that would have taken me 40+ hours. The tools pay for themselves before the first billing cycle ends.

---

## The One Tool You Should Start With

If you can only pick one thing from this list: **GitHub Copilot CLI with the Squad framework.**

Everything else is infrastructure to support it. Copilot CLI + Squad gives you agent teams, persistent memory, routing, and coordination — the core of everything described in this post.

Start there. Add tools as you need them.

---

*Building your own AI squad? I'd love to hear about it. What tools are you using that I should try?*

*Some links on this page are affiliate links. If you purchase through them, I may earn a small commission at no extra cost to you. I only recommend tools I personally use. [Full disclosure](/affiliate-disclosure).*
