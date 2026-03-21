# Eyal's Shared Links — Knowledge Base

This directory captures links shared by Eyal in the Cloud-Dev-and-Architecture Google Group.

## Purpose

Eyal shares valuable technical content about cloud architecture, distributed systems, Kubernetes, and developer practices. This knowledge base allows the Squad to:

- **Learn from experts**: Eyal curates high-quality technical content
- **Build context**: Track trends and patterns in his recommendations
- **Inform decisions**: Reference these links when making architectural choices
- **Share knowledge**: Make Eyal's curated links searchable across the team

## Structure

Each file captures a single Google Group post from Eyal:

```
YYYY-MM-DD-{title-slug}.md
```

Each markdown file contains:
- Original post metadata (author, date, source URL)
- Post content
- All shared links with:
  - Title and description
  - Relevance score (HIGH/MEDIUM/LOW)
  - Content preview for context

## Relevance Scoring

Links are automatically scored based on content analysis:

**HIGH**: Directly relevant to our stack
- Kubernetes, Azure, AKS, cloud architecture
- .NET, C#, microservices, DevOps
- AI, Copilot, GitHub, observability, security

**MEDIUM**: Adjacent technologies worth monitoring

**LOW**: Filtered out of notifications

## Integration

This knowledge base integrates with:

1. **Continuous Monitor**: `scripts/eyal-links-monitor.js` runs hourly
2. **Teams Notifications**: High/medium relevance links posted to Tech News channel
3. **State Tracking**: `.squad/monitoring/eyal-links-state.json` prevents duplicates
4. **Search**: All files are plain markdown — searchable via `grep`, GitHub search, or MCP tools

## Usage

### Manual check
```bash
node scripts/eyal-links-monitor.js once
```

### Continuous monitoring (recommended)
```bash
node scripts/eyal-links-monitor.js continuous
```

### Search the knowledge base
```bash
grep -r "kubernetes" .squad/knowledge/eyal-links/
```

## Maintenance

- Files are append-only (never delete)
- State file tracks processed URLs to avoid reprocessing
- No cleanup needed — knowledge accumulates over time
