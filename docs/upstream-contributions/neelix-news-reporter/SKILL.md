# Skill: News Broadcasting

**Confidence:** low
**Domain:** communication, reporting

## Context

Codifies news report formats, Teams delivery mechanics, styling patterns, and humor guidelines for the Neelix agent role. Any agent doing squad reporting can reference this skill.

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

### Webhook Delivery

Store your Teams incoming webhook URL in a known location:

**Webhook file:** `$USERPROFILE\.squad\teams-webhook.url`

Read this file to get the webhook URL, then POST Adaptive Card JSON to it.

```powershell
$webhookUrl = (Get-Content "$env:USERPROFILE\.squad\teams-webhook.url" -Raw).Trim()
$body = @{ text = "📰 **BREAKING:** Your news here" } | ConvertTo-Json
Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "application/json" -Body $body
```

### MCP Tool Delivery

When running inside a Copilot session with Teams MCP tools, post directly to channels using the channel IDs from your `teams-channels.json` configuration.

### Channel Routing

Configure channel routing in `.squad/teams-channels.json` (see `templates/teams-channels.json`). Each message type maps to a channel:

| Message Type | Suggested Channel | Example |
|-------------|-------------------|---------|
| Daily briefings | `tech-news` | Morning summary |
| Breaking alerts | `general` | CI failure |
| Celebrations | `wins` | PR merged, milestone hit |
| PR/code updates | `pr-code` | Review requested |

Include a `CHANNEL: <key>` hint in output so routing middleware can direct the message to the correct channel.

## Image Generation

Neelix broadcasts can include generated images — banners, memes, and status visuals — using **nano-banana** (Google Gemini).

### Copilot Agent Path

Call the `nano-banana-generate_image` MCP tool during broadcast composition:

```
Tool: nano-banana-generate_image
prompt: "Bold news banner about {topic}, modern flat design, blue and gold, 16:9"
output_dir: "~/Documents/nano-banana-images/neelix"
output_name: "neelix-banner"
```

Then embed in the Adaptive Card:

```json
{ "type": "Image", "url": "data:image/png;base64,<data>", "altText": "Banner", "size": "Stretch" }
```

### Standalone Script Path

You can also create a helper script for image generation:

```powershell
$imageUri = & .\scripts\generate-news-image.ps1 -Headline "Topic" -Style "banner"
```

Requires `$env:GOOGLE_API_KEY`. The daily briefing auto-generates images unless `-SkipImages` is set.

### Image Styles

- **banner** — Bold headline visual for top stories
- **meme** — Office humor illustration for lighter items
- **status** — Dashboard/infographic for metrics
- **custom** — Supply your own prompt

### Graceful Degradation

Image generation never blocks delivery. If it fails, broadcast sends text-only.

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
