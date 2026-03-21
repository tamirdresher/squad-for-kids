# Clawpilot Tool Evaluation

**Issue:** #864  
**Date:** 2026-03-21  
**Author:** Seven (Research & Docs)  
**Status:** Complete — recommendation inline  
**Source URL:** https://cautious-giggle-6ly89rr.pages.github.io/ (Microsoft EMU–gated)  
**GitHub repo:** https://github.com/gim-home/m (private, EMU org)

---

## Executive Summary

**Clawpilot** (formerly "M") is an internal Microsoft desktop app — macOS and Windows — that wraps GitHub Copilot with a rich set of agent-like superpowers: file system access, shell commands, browser control, web search, M365/WorkIQ integration, scheduled multi-step workflows, a Skills Marketplace, a Heartbeat background monitor, and a Teams Bridge for remote control from your phone.

**Key finding:** Clawpilot and Squad are **complementary, not competing**. Clawpilot is a personal productivity desktop assistant. Squad is a multi-agent GitHub-integrated automation framework for a team of specialists. They operate at different layers. The most actionable insight is Clawpilot's **Teams Bridge** and **Skills Marketplace** — both are patterns Squad should study or adopt.

**Recommendation: Try it + Monitor closely.**

---

## 1. What Is Clawpilot?

### Overview

| Attribute | Detail |
|-----------|--------|
| **Name** | Clawpilot (previously "M") |
| **Type** | Desktop app (macOS + Windows), internal Microsoft tool |
| **Repo** | `github.com/gim-home/m` (private, EMU org) |
| **Distribution** | GitHub Releases — not code-signed (install with OS bypass) |
| **Auth** | MSAL M365 authentication (as of v0.19.0); up to 99 users on temp tenant admin approval |
| **Community** | Teams channel: `M App` team |

### Six Core Superpowers

| Superpower | What It Does |
|---|---|
| 📁 **File System Access** | Read, write, organize files on your machine |
| ⚡ **Shell Commands** | Run terminal commands, install packages, execute scripts |
| 🌐 **Browser Control** | Navigate websites, fill forms, extract data (like our Playwright skill) |
| 🔍 **Search Web** | Live internet research |
| 💼 **WorkIQ** | Query M365 — emails, meetings, Teams messages, documents |
| 🔄 **Workflows** | Chain multi-step tasks with natural language scheduling |

### Notable Differentiators vs. Standard Copilot

- **Skills** — Teach it once, run forever. Same concept as Squad's skill system, but user-facing with a marketplace
- **Skills Marketplace** — Publish, discover, install community-built skills
- **Heartbeat** — Background monitor: checks Teams & Outlook every 30 min, fires macOS/Windows notifications when urgent items arrive (hot bug, escalation, skip-level message)
- **Teams Bridge** — Send a message to your Teams self-chat from your phone → Clawpilot picks it up, runs the full request with MCP + Copilot power, posts the answer back. No VPN, no app switching
- **Personality modes** — TARS, JARVIS, Sarcastic Teenager, David Attenborough, Enthusiastic Intern, Marvin (Paranoid Android), or custom
- **Multi-model** — Claude Opus 4.6, Sonnet 4.5, GPT-5.2, GPT-5.1-Codex, Gemini 3 Pro, more

---

## 2. Have We Researched This Before?

**No.** Zero prior mentions of "clawpilot" or "gim-home" in:
- All research files (`research/*.md`)
- Full git commit history (`git log --all --grep`)
- GitHub issue tracker (only issue #864 references this URL)
- Session store history

Previous agents (Ralph, Picard, Worf) hit the EMU SSO wall and couldn't see the content. This is the **first full evaluation**.

---

## 3. How Does It Relate to Squad?

### Differences

| Dimension | Clawpilot | Squad |
|---|---|---|
| **Paradigm** | Personal desktop assistant | Multi-agent GitHub automation team |
| **Trigger** | Human types a prompt | Issues, schedules, CI events |
| **Scope** | Single user, single machine | Team of specialists, distributed |
| **Deployment** | Desktop app | GitHub Actions + local scripts |
| **Collaboration** | One AI, many personalities | Many agents, specialized roles |
| **Code-signed** | No (internal, community) | N/A |

### Overlaps Worth Noting

| Clawpilot Feature | Squad Equivalent | Gap? |
|---|---|---|
| WorkIQ / M365 | WorkIQ MCP (Kes, Neelix) | ✅ Covered |
| Browser Control | Playwright skill | ✅ Covered |
| Skills | Squad Skills system | ⚠️ We lack a **marketplace / discovery** layer |
| Heartbeat | Ralph health checks | ⚠️ Different angle — user notification vs. system health |
| Teams Bridge | Teams MCP | ⚠️ We post TO Teams; Clawpilot polls FROM Teams self-chat |
| Workflows / scheduling | Ralph `ralph-watch.ps1` | ✅ Covered but less polished |
| Personality modes | Not in Squad | 🆕 Not applicable |

### Key Insight: Teams Bridge is a Pattern We Should Steal

Clawpilot's Teams Bridge lets you **message your own self-chat → AI executes → reply lands back**. This is a lighter-weight alternative to a full CLI for mobile Squad interaction. A Squad equivalent would let Tamir say "summarize this morning's PRs" from his phone and get a Teams reply without opening a laptop.

---

## 4. Recommendation

### **Try it + Monitor closely**

#### Why Try It

1. **It's directly relevant** — Same technology stack (Copilot, M365, MCP), internal to Microsoft
2. **Teams Bridge is immediately useful** — Interact with your AI assistant from your phone, no VPN
3. **Skills Marketplace** — Potential source of community skills that Squad could learn from or reuse
4. **Heartbeat** — Worth experiencing to understand the UX pattern before we build our own

#### Why Not "Use it" as a Squad replacement

Clawpilot and Squad solve different problems. Clawpilot is a **personal productivity assistant** — one person, one machine, one conversation. Squad is a **specialized team that acts autonomously on the repo** — issues become tasks, tasks become PRs, the team runs itself.

#### Why Not Skip It

This is an internally developed Microsoft tool in our exact problem space (AI + M365 + GitHub), built by people at Microsoft. Missing it entirely would be leaving signal on the table.

#### Specific Squad Value

| If adopted | Concrete value |
|---|---|
| **Try Teams Bridge pattern** | Tamir can interact with Squad from his phone via self-chat |
| **Borrow Skills Marketplace concept** | Skills catalog in the Squad docs with discovery tags — easier for new squad members |
| **Track Clawpilot roadmap** | If they solve agent persistence or multi-machine sync, Squad learns from it |

---

## 5. Action Items

- [ ] **Tamir tries Clawpilot** — Download from `github.com/gim-home/m/releases`, install, evaluate Teams Bridge + Heartbeat firsthand
- [ ] **Squad issue: Teams Bridge equivalent** — Prototype polling Tamir's Teams self-chat and routing to a Squad agent
- [ ] **Join `M App` Teams community channel** — Monitor their roadmap announcements
- [ ] **Skills Marketplace design** — Open a Squad issue to explore a discoverable skills catalog

---

*Research method: Authenticated browser access via Microsoft EMU SSO (machine: TAMIRDRESHER), full page content extraction, git history scan, research folder scan, GitHub issue history review (9 prior comments).*
