# Build Your Own AI Engineering Squad — From Zero to Autonomous Team

## Course Metadata

- **Title:** Build Your Own AI Engineering Squad — From Zero to Autonomous Team
- **Subtitle:** Master Multi-Agent AI Systems with MCP Servers, GitHub Copilot, Persistent Agents & Real-World Orchestration Patterns
- **Instructor:** Tamir Dresher — Principal Engineer at Microsoft, 4x Book Author
- **Category:** Development > Software Engineering > AI & Machine Learning
- **Level:** Intermediate
- **Language:** English
- **Estimated Length:** ~12 hours (40 lectures)
- **Last Updated:** 2025

---

## Course Description (SEO-Optimized)

Learn how to build, deploy, and orchestrate a team of autonomous AI agents that collaborate like a real engineering squad. This hands-on course takes you from understanding single AI agents to designing multi-agent architectures using MCP (Model Context Protocol) servers, GitHub Copilot CLI, GitHub Actions, and custom orchestration frameworks.

You'll build a complete "Squad" framework — a system where specialized AI agents (code experts, security reviewers, infrastructure specialists, communication managers) work together autonomously to handle real software engineering tasks: writing code, reviewing PRs, managing calendars, sending emails, triaging work items, and even generating audio content.

By the end of this course, you'll have a production-ready multi-agent system integrated with GitHub, Azure DevOps, Microsoft 365, and your existing development workflow. Whether you're a solo developer wanting to 10x your productivity or a team lead exploring AI-augmented engineering, this course gives you the complete blueprint.

**Keywords:** AI agents, multi-agent systems, MCP servers, Model Context Protocol, GitHub Copilot, AI orchestration, autonomous agents, AI engineering, LLM agents, agentic AI, Squad framework, AI-powered development

---

## Target Audience — 3 Personas

### Persona 1: The Productivity-Obsessed Senior Developer
- **Role:** Senior Software Engineer / Tech Lead (5-10 years experience)
- **Pain:** Drowning in context-switching — code reviews, meetings, emails, deployments
- **Goal:** Automate repetitive engineering tasks with AI agents that understand their codebase
- **Tech Stack:** .NET/TypeScript/Python, GitHub, Azure DevOps, VS Code

### Persona 2: The AI-Curious Platform Engineer
- **Role:** Platform Engineer / DevOps Engineer (3-7 years experience)
- **Pain:** Wants to integrate AI into CI/CD and developer tooling but doesn't know where to start
- **Goal:** Build internal developer tools powered by AI agents
- **Tech Stack:** GitHub Actions, Kubernetes, Terraform, CI/CD pipelines

### Persona 3: The Aspiring AI Entrepreneur
- **Role:** Software Engineer exploring AI product ideas (2-5 years experience)
- **Pain:** Understands LLMs conceptually but can't build production multi-agent systems
- **Goal:** Build and monetize AI agent products/services
- **Tech Stack:** Python/TypeScript, OpenAI/Anthropic APIs, basic cloud experience

---

## Prerequisites

- **Required:**
  - Intermediate programming experience (any language — examples use TypeScript, Python, C#)
  - Basic understanding of REST APIs and JSON
  - GitHub account (free tier is fine)
  - Familiarity with command line / terminal
  
- **Recommended (not required):**
  - Experience with at least one LLM API (OpenAI, Anthropic, etc.)
  - Basic understanding of Git workflows (branches, PRs)
  - Familiarity with CI/CD concepts

- **Tools You'll Need:**
  - VS Code or any code editor
  - Node.js 18+ installed
  - GitHub Copilot subscription (free trial works)
  - API keys for Claude/OpenAI (free tier credits sufficient for the course)

---

## Course Structure

### Section 1: The AI Squad Vision — Why Multi-Agent Systems Win
**Learning Objectives:**
- Understand why single-agent AI has limitations for complex engineering tasks
- Articulate the value proposition of multi-agent orchestration
- Map the complete architecture of an AI engineering squad

| # | Lecture Title | Duration | Type |
|---|--------------|----------|------|
| 1.1 | Why One AI Agent Isn't Enough — The Case for Squads | 12 min | 🎥 Video |
| 1.2 | Architecture Overview: Agents, Orchestrators & MCP Servers | 15 min | 🎥 Video |
| 1.3 | Meet the Squad: Roles, Capabilities & Specialization Patterns | 10 min | 🎥 Video |
| 1.4 | Setting Up Your Development Environment | 18 min | 🛠️ Hands-on |
| 1.5 | Quiz: Multi-Agent Fundamentals | 5 min | 📝 Quiz |

---

### Section 2: Understanding AI Agents — Foundations & Mental Models
**Learning Objectives:**
- Define what makes an AI agent different from a chatbot
- Understand the agent loop: Observe → Think → Act → Reflect
- Implement a basic agent with tool-calling capabilities

| # | Lecture Title | Duration | Type |
|---|--------------|----------|------|
| 2.1 | Anatomy of an AI Agent: Beyond Chat Completions | 14 min | 🎥 Video |
| 2.2 | The Agent Loop: Reasoning, Planning & Tool Use | 12 min | 🎥 Video |
| 2.3 | Hands-On: Build Your First Tool-Calling Agent | 25 min | 🛠️ Hands-on |
| 2.4 | Prompt Engineering for Agents: System Prompts, Personas & Guardrails | 18 min | 🎥 Video |
| 2.5 | Quiz: Agent Fundamentals | 5 min | 📝 Quiz |

---

### Section 3: MCP Servers — The Universal Tool Protocol
**Learning Objectives:**
- Understand the Model Context Protocol (MCP) and why it matters
- Build custom MCP servers that expose tools to AI agents
- Connect multiple MCP servers to create a rich tool ecosystem

| # | Lecture Title | Duration | Type |
|---|--------------|----------|------|
| 3.1 | What is MCP? The USB-C of AI Tool Integration | 10 min | 🎥 Video |
| 3.2 | MCP Architecture: Clients, Servers, Transports & Tools | 15 min | 🎥 Video |
| 3.3 | Hands-On: Build Your First MCP Server (File System Tools) | 25 min | 🛠️ Hands-on |
| 3.4 | Hands-On: Build an Azure DevOps MCP Server | 30 min | 🛠️ Hands-on |
| 3.5 | Composing MCP Servers: Multi-Server Configuration | 15 min | 🛠️ Hands-on |

---

### Section 4: Designing Your Squad — Agent Roles & Specialization
**Learning Objectives:**
- Design specialized agent personas with clear boundaries
- Implement capability routing — matching tasks to the right agent
- Create agent configuration files (team.md, routing.md patterns)

| # | Lecture Title | Duration | Type |
|---|--------------|----------|------|
| 4.1 | The Squad Framework: Team Roster & Capability Profiles | 12 min | 🎥 Video |
| 4.2 | Agent Specialization: Code, Security, Infra, Comms & More | 15 min | 🎥 Video |
| 4.3 | Hands-On: Define Your Squad — team.md & routing.md | 20 min | 🛠️ Hands-on |
| 4.4 | Hands-On: Build a Code Expert Agent (Data/Seven Pattern) | 25 min | 🛠️ Hands-on |
| 4.5 | Hands-On: Build a Security & Cloud Agent (Worf Pattern) | 20 min | 🛠️ Hands-on |

---

### Section 5: Multi-Agent Orchestration — Making Agents Collaborate
**Learning Objectives:**
- Implement agent-to-agent communication and delegation
- Build an orchestrator (Picard pattern) that routes work to specialists
- Handle cross-agent context sharing and conflict resolution

| # | Lecture Title | Duration | Type |
|---|--------------|----------|------|
| 5.1 | Orchestration Patterns: Hub-Spoke, Pipeline, Swarm & Hierarchy | 15 min | 🎥 Video |
| 5.2 | The Lead Agent Pattern: Task Decomposition & Delegation | 12 min | 🎥 Video |
| 5.3 | Hands-On: Build the Orchestrator — The Picard Agent | 30 min | 🛠️ Hands-on |
| 5.4 | Cross-Agent Context: Scribe Pattern & Session Logging | 20 min | 🛠️ Hands-on |
| 5.5 | Quiz: Orchestration Patterns | 5 min | 📝 Quiz |

---

### Section 6: GitHub Integration — Agents in Your Dev Workflow
**Learning Objectives:**
- Integrate AI agents with GitHub Actions for automated workflows
- Build agents that review PRs, triage issues, and manage backlogs
- Implement persistent agents that survive session boundaries

| # | Lecture Title | Duration | Type |
|---|--------------|----------|------|
| 6.1 | GitHub Actions + AI Agents: The Automation Superpower | 12 min | 🎥 Video |
| 6.2 | Hands-On: Auto-Triage Issues with AI Agent Labels | 25 min | 🛠️ Hands-on |
| 6.3 | Hands-On: AI-Powered PR Review with Code-Review Agent | 25 min | 🛠️ Hands-on |
| 6.4 | Persistent Agents: Background Processes & Keep-Alive Patterns | 18 min | 🎥 Video + Demo |
| 6.5 | Hands-On: Work Queue Monitor — The Ralph Agent Pattern | 20 min | 🛠️ Hands-on |

---

### Section 7: Voice, Email & Communication Agents
**Learning Objectives:**
- Build agents that interact with Microsoft 365 (email, calendar, Teams)
- Create audio content generators (podcast-style summaries)
- Implement the Kes communication pattern for scheduling automation

| # | Lecture Title | Duration | Type |
|---|--------------|----------|------|
| 7.1 | Communication Agents: Beyond Code — Email, Calendar & Teams | 10 min | 🎥 Video |
| 7.2 | Hands-On: Build an Email & Calendar Agent (Kes Pattern) | 25 min | 🛠️ Hands-on |
| 7.3 | Hands-On: Build a Podcast/Audio Content Agent | 20 min | 🛠️ Hands-on |
| 7.4 | Hands-On: News Reporter Agent — Styled Briefings to Teams | 20 min | 🛠️ Hands-on |

---

### Section 8: Production Deployment & Observability
**Learning Objectives:**
- Deploy multi-agent systems to production environments
- Implement logging, tracing, and observability for agent interactions
- Handle failures, retries, and graceful degradation

| # | Lecture Title | Duration | Type |
|---|--------------|----------|------|
| 8.1 | From Prototype to Production: Deployment Patterns | 15 min | 🎥 Video |
| 8.2 | Observability: Logging Agent Decisions & Tool Calls | 12 min | 🎥 Video |
| 8.3 | Hands-On: Add Structured Logging & Distributed Traces | 20 min | 🛠️ Hands-on |
| 8.4 | Error Handling: Retries, Fallbacks & Circuit Breakers for Agents | 15 min | 🎥 Video |
| 8.5 | Cost Management: Token Budgets & Model Selection Strategies | 12 min | 🎥 Video |

---

### Section 9: Advanced Patterns — Research, Fact-Checking & Devil's Advocate
**Learning Objectives:**
- Build research agents that synthesize information from multiple sources
- Implement verification agents (the Q pattern) for fact-checking and counter-hypotheses
- Create documentation and presentation agents

| # | Lecture Title | Duration | Type |
|---|--------------|----------|------|
| 9.1 | Research Agents: Web Search, Document Analysis & Synthesis | 12 min | 🎥 Video |
| 9.2 | Hands-On: Build a Devil's Advocate Agent (Q Pattern) | 20 min | 🛠️ Hands-on |
| 9.3 | Hands-On: Build a Blog Writer Agent with Voice Matching | 20 min | 🛠️ Hands-on |
| 9.4 | Skills & Plugins: Extending Agents with Composable Capabilities | 15 min | 🎥 Video |

---

### Section 10: Monetization & Scaling Your AI Squad
**Learning Objectives:**
- Identify monetization opportunities for multi-agent systems
- Package and sell AI agent templates and frameworks
- Scale from personal productivity to team/enterprise deployment

| # | Lecture Title | Duration | Type |
|---|--------------|----------|------|
| 10.1 | Monetizing AI Agents: Products, Services & Content | 12 min | 🎥 Video |
| 10.2 | Packaging Your Squad: Templates, Marketplaces & SaaS | 15 min | 🎥 Video |
| 10.3 | Scaling: From Solo Developer to Enterprise Teams | 12 min | 🎥 Video |
| 10.4 | The Future of AI Engineering: What's Next | 10 min | 🎥 Video |
| 10.5 | Course Wrap-Up & Your Action Plan | 8 min | 🎥 Video |

---

## Course Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Sections** | 10 |
| **Total Lectures** | 44 |
| **Video Lectures** | 26 |
| **Hands-on Labs** | 15 |
| **Quizzes** | 3 |
| **Estimated Total Duration** | ~11.5 hours |
| **Hands-on Percentage** | 34% |

---

## Downloadable Resources (Per Section)

1. **Section 1:** Architecture diagram PDF, environment setup checklist
2. **Section 2:** Agent loop reference card, prompt template library
3. **Section 3:** MCP server starter template, configuration reference
4. **Section 4:** Squad team.md template, routing.md template
5. **Section 5:** Orchestration patterns cheat sheet
6. **Section 6:** GitHub Actions workflow templates (3 workflows)
7. **Section 7:** Microsoft 365 integration guide, audio generation config
8. **Section 8:** Production deployment checklist, observability dashboard template
9. **Section 9:** Research agent prompt library, fact-checking framework
10. **Section 10:** Monetization canvas template, pricing calculator spreadsheet

---

## Capstone Project

**Build & Deploy Your Personal AI Engineering Squad**

Students will build a complete multi-agent system with:
- At least 3 specialized agents (code, security, communication)
- MCP server integration with at least 2 external services
- GitHub Actions automation for at least 1 workflow
- Orchestrator agent that routes tasks to specialists
- Deployed and running in their own GitHub repository

Submission: GitHub repository link with README documenting the squad architecture.
