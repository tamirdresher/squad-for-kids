# Neelix — News Reporter Agent Role

> Your daily briefing, coming to you live from the Squad newsroom.

## What Is Neelix?

Neelix is a **news reporter agent role** for [Squad](https://github.com/bradygaster/squad) that transforms dry repository updates into engaging, styled news broadcasts delivered directly to Microsoft Teams.

Instead of sifting through GitHub notifications, CI logs, and PR queues, your team gets a witty, well-formatted news briefing — complete with headlines, graphics, and personality.

## What Problem Does It Solve?

Teams using Squad have multiple agents generating activity: PRs opened, issues closed, decisions made, builds failing. Keeping up with all of it is noisy and tedious.

Neelix solves this by:

- **Aggregating** activity from GitHub, CI/CD, and agent logs into a single digest
- **Formatting** updates as styled news broadcasts (not boring lists)
- **Delivering** directly to Teams channels via webhooks or MCP tools
- **Generating images** (banners, memes, status visuals) using Gemini / nano-banana
- **Making updates enjoyable** — tech puns, Star Trek references, and sharp wit included

## News Formats

| Format | Purpose | Cadence |
|--------|---------|---------|
| 📰 **Daily Briefing** | Full squad activity summary | Daily |
| ⚡ **Breaking News** | Critical alerts (CI failure, blockers) | Immediate |
| 📊 **Weekly Recap** | End-of-week highlights and stats | Weekly |
| 🎯 **Status Flash** | Quick board snapshot | On demand |

## How It Integrates with Squad

Neelix fits into the Squad agent model as a **communication specialist**:

```
┌─────────────┐     ┌─────────┐     ┌───────────────┐
│ Squad Agents │────▶│ Neelix  │────▶│ Teams Channel │
│ (activity)   │     │ (format) │     │ (delivery)    │
└─────────────┘     └─────────┘     └───────────────┘
```

- **Charter:** Define Neelix in `.squad/agents/neelix/charter.md` using the template
- **Skill:** Reference the news-broadcasting skill for format and delivery rules
- **Channel Routing:** Configure `teams-channels.json` to route messages to the right channels
- **Model:** Uses `claude-haiku-4.5` by default — text/formatting work doesn't need heavy models

## Quick Start

1. Copy `charter-template.md` → `.squad/agents/neelix/charter.md`
2. Copy `SKILL.md` → `.squad/skills/news-broadcasting/SKILL.md`
3. Copy `templates/teams-channels.json` → `.squad/teams-channels.json` and fill in your channel IDs
4. Set up a Teams incoming webhook and save the URL to `$USERPROFILE\.squad\teams-webhook.url`
5. Configure your orchestrator to invoke Neelix for reporting tasks

## Files in This Package

| File | Description |
|------|-------------|
| `charter-template.md` | Agent charter — identity, boundaries, model preference |
| `SKILL.md` | News broadcasting skill — formats, delivery, styling, humor |
| `templates/teams-channels.json` | Channel routing configuration template |
| `templates/daily-briefing.md` | Example daily briefing format |
| `templates/breaking-news.md` | Example breaking news format |
| `CONTRIBUTING-NOTES.md` | Notes for integrating into upstream Squad |

## Requirements

- **Squad framework** with agent orchestration
- **Microsoft Teams** with an incoming webhook (or Teams MCP tools)
- **Google API key** (optional) for image generation via nano-banana / Gemini
- **claude-haiku-4.5** or equivalent model for cost-efficient text generation
