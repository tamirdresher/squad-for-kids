# 📡 Upstream Project Monitor

Track changes in upstream/dependency repositories and surface relevant updates before they surprise you.

## What It Does

- **Track repositories** — Register and monitor upstream Git repos
- **Detect changes** — Surface new commits, PRs, and releases since last sync
- **Breaking change alerts** — Flag commits with breaking change keywords
- **Change digests** — Generate human-readable summaries of upstream activity
- **Configurable filters** — Watch specific paths and ignore bot commits

## Trigger Phrases

- `check upstream`, `upstream changes`
- `dependency updates`, `sync upstream`
- `monitor repos`, `what changed upstream`

## Quick Start

### Prerequisites

- Git CLI installed
- Access to upstream repositories (read permissions)
- Storage for local mirrors (`_upstream_repos/` directory)

### Example Usage

```
User: "Check for upstream changes in core-platform"
Agent: [Fetches mirror, checks commits since last sync]
Agent: "📦 core-platform: 5 new commits, including 1 breaking change in src/api/"
```

## Registry Format

```json
{
  "upstreams": [
    {
      "name": "core-platform",
      "source": "https://github.com/org/core-platform.git",
      "ref": "main",
      "last_synced": "2026-03-14T10:30:00Z"
    }
  ]
}
```

## Detection

- **Commits**: `git log --after="{last_synced}"`
- **Releases**: `git tag --sort=-creatordate`
- **Breaking changes**: Keyword search in commit messages

## See Also

- [News Broadcasting](../news-broadcasting/) — Broadcast upstream changes
- [Notification Routing](../notification-routing/) — Route critical changes
