# Contributing Notes — Neelix News Reporter

Notes for the upstream PR to [bradygaster/squad](https://github.com/bradygaster/squad).

## Where to Place Files

In the upstream Squad repo, the recommended file placement is:

```
.squad/
├── agents/
│   └── neelix/
│       └── charter.md              ← from charter-template.md
├── skills/
│   └── news-broadcasting/
│       └── SKILL.md                ← from SKILL.md
├── teams-channels.json             ← from templates/teams-channels.json
```

Templates and examples can live in the docs or examples directory:

```
docs/
└── agent-roles/
    └── neelix-news-reporter/
        ├── README.md               ← this package's README.md
        ├── daily-briefing.md       ← from templates/daily-briefing.md
        └── breaking-news.md        ← from templates/breaking-news.md
```

## Configuration Required

### 1. Teams Webhook

Create an incoming webhook in your Teams channel and save the URL:

```powershell
# Save webhook URL for Neelix to read
$webhookUrl = "https://your-tenant.webhook.office.com/webhookb2/..."
$webhookUrl | Set-Content "$env:USERPROFILE\.squad\teams-webhook.url"
```

### 2. Channel Routing

Edit `.squad/teams-channels.json` with your actual team and channel IDs. You can find these in the Teams admin center or via the Teams MCP tools (`teams-ListTeams`, `teams-ListChannels`).

### 3. Image Generation (Optional)

Set `$env:GOOGLE_API_KEY` if you want Neelix to generate banner images using nano-banana / Gemini. Image generation is optional — Neelix gracefully degrades to text-only if unavailable.

## Model Recommendation

Neelix uses **claude-haiku-4.5** by default. Since it only does text formatting and aggregation (no code generation), a cost-efficient model is ideal.

## How It Works with Orchestration

The Squad orchestrator should route reporting/communication tasks to Neelix. Example routing rule:

```
If task involves: news, briefing, summary, status report, announcement
→ Route to: neelix
```

Neelix reads from:
- GitHub issues/PRs (via MCP tools or API)
- Agent decision logs (`.squad/decisions/`)
- Orchestration history

And outputs to:
- Teams channels (via webhook or MCP)
- Markdown files (for archival)

## What's Included vs. What's Not

### Included
- ✅ Agent charter (identity, boundaries, model preference)
- ✅ News broadcasting skill (formats, delivery, styling)
- ✅ Channel routing configuration template
- ✅ Example message formats (daily briefing, breaking news)
- ✅ Humor and comedy guidelines

### Not Included (team-specific)
- ❌ Specific webhook URLs or channel IDs
- ❌ Team-specific routing rules
- ❌ Custom image generation scripts
- ❌ Orchestrator configuration (varies by deployment)

## Origin

Developed and battle-tested in a real Squad deployment. Neelix has delivered hundreds of news briefings, breaking alerts, and weekly recaps. The humor guidelines have been refined through actual team feedback (turns out "merge-ty" never gets old).
