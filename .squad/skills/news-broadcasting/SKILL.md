# Skill: News Broadcasting
**Confidence:** low
**Domain:** communication, reporting
**Last validated:** 2026-03-13

## Context
Extracted from Neelix's charter to codify news report formats, Teams delivery mechanics, styling patterns, and humor guidelines. Any agent doing squad reporting can reference this skill.

## News Formats

### 📰 Daily Briefing
Full summary of squad activity: issues closed, PRs merged, decisions made, blockers.
Delivered as a styled Teams message with sections and graphics.

### ⚡ Breaking News
Immediate alert for critical events: CI failures, blocking issues, important merges.
Short, punchy, attention-grabbing.

### 📊 Weekly Recap
End-of-week summary with stats, highlights, and "top stories".

### 🎯 Status Flash
Quick board snapshot: what's in progress, what's blocked, what needs attention.

## Teams Delivery

**Webhook file:** `$env:USERPROFILE\.squad\teams-webhook.url`
Read this file to get the webhook URL, then POST Adaptive Card JSON to it.

```powershell
$webhookUrl = (Get-Content "$env:USERPROFILE\.squad\teams-webhook.url" -Raw).Trim()
$body = @{ text = "📰 **BREAKING:** Your news here" } | ConvertTo-Json
Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "application/json" -Body $body
```

Or use the `workiq-ask_work_iq` tool if available in the Copilot session.

## Message Style

Use Adaptive Cards or rich markdown with:
- 📰 News header banner
- Section dividers (━━━)
- Emoji categories (🟢 Done, 🟡 In Progress, 🔴 Blocked)
- Pull quotes for key decisions
- Stats counters for metrics
- "Reporter sign-off" personality touch

## Humor & Comedy Guidelines

- **Tech Puns:** Dev-lightful fixes, merge-ty news, branch-tastic progress. Wordplay tied to tech concepts.
- **Star Trek References:** Lean into subtle ST universe references. ("Resistance to PRs is futile")
- **Self-Deprecating AI Humor:** Playful observations about being an AI news bot.
- **Playful Analogies:** Compare squad work to relatable scenarios.
- **Witty Observations:** Sharp, quick takes on the news.
- **Tone:** Funny but professional. Make people smile, not cringe. Technical updates should be *enjoyable* while staying informative.
