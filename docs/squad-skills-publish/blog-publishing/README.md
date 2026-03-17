# 📝 Blog Publishing

Multi-account GitHub workflow for publishing content to GitHub Pages sites. Handles authentication switching, branch management, and traceability.

## What It Does

- **Account switching** — Safely switch between work and personal GitHub accounts
- **Content deployment** — Push blog content to the correct repository and branch
- **Safety rollback** — Always switch back to work account after publishing
- **Traceability** — Link published content to tracking issues

## Trigger Phrases

- `publish blog`, `deploy blog`
- `push to blog`, `blog workflow`
- `content publishing`, `blog post`

## Quick Start

### Prerequisites

- GitHub CLI (`gh`) installed with multiple accounts configured
- Blog repository on GitHub Pages (or any static site generator)
- Working repository where drafts are created

### Example Usage

```
User: "Publish blog-ai-agents.md to my blog"
Agent: [Switches to publishing account → pushes → switches back → comments on issue]
Agent: "✅ Published and switched back to work account"
```

## Workflow

1. Draft content locally
2. Switch to publishing account (`gh auth switch`)
3. Push to blog repository
4. Switch back to work account (critical!)
5. Link commit to tracking issue

## See Also

- [Voice Writing](../voice-writing/) — Maintain consistent writing voice
- [GitHub Multi-Account](../github-multi-account/) — Manage multiple GitHub identities
