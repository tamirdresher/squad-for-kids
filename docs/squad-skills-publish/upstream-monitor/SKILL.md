---
name: upstream-monitor
description: "Track changes in upstream/dependency repositories and surface relevant updates. Use when monitoring external repos that feed into your project."
license: MIT
metadata:
  version: 1.0.0
  adapted_from: Upstream repository tracking patterns
---

# Upstream Project Monitor

**Track changes in external repositories** that your project depends on. Surfaces new commits, PRs, releases, and breaking changes before they surprise you.

---

## Triggers

| Phrase | Priority |
|--------|----------|
| `check upstream`, `upstream changes` | HIGH — Active check |
| `dependency updates`, `sync upstream` | HIGH — Sync request |
| `monitor repos`, `what changed upstream` | MEDIUM — Status check |
| `breaking changes`, `new releases` | MEDIUM — Impact assessment |

---

## Registry Format

Track upstream repositories in a configuration file:

### `upstreams.json`

```json
{
  "upstreams": [
    {
      "name": "core-platform",
      "type": "git",
      "source": "https://github.com/org/core-platform.git",
      "ref": "main",
      "added_at": "2026-01-15T00:00:00Z",
      "last_synced": "2026-03-14T10:30:00Z",
      "watch": {
        "commits": true,
        "releases": true,
        "prs": false
      },
      "filters": {
        "paths": ["src/api/", "docs/breaking-changes/"],
        "ignore_authors": ["dependabot[bot]"]
      }
    },
    {
      "name": "shared-library",
      "type": "git",
      "source": "https://github.com/org/shared-lib.git",
      "ref": "main",
      "added_at": "2026-02-01T00:00:00Z",
      "last_synced": "2026-03-14T10:30:00Z",
      "watch": {
        "commits": true,
        "releases": true,
        "prs": true
      }
    }
  ]
}
```

---

## Sync Workflow

### Step 1: Clone or Update Local Mirror

```bash
# First time
git clone --mirror {source_url} _upstream_repos/{name}

# Subsequent syncs
cd _upstream_repos/{name}
git fetch --all
```

### Step 2: Detect Changes Since Last Sync

```bash
# Get commits since last sync
git log --oneline --after="{last_synced}" {ref}

# Get new tags/releases
git tag --sort=-creatordate | head -5
```

### Step 3: Generate Change Digest

```bash
# Commits with stats
git log --stat --after="{last_synced}" {ref}

# Files changed
git diff --name-only {last_sync_commit}..HEAD

# Breaking change detection (look for keywords)
git log --grep="breaking" --grep="BREAKING" --all-match --after="{last_synced}"
```

### Step 4: Update Sync Timestamp

```python
import json
from datetime import datetime

def update_sync_time(registry_path, upstream_name):
    with open(registry_path, 'r+') as f:
        registry = json.load(f)
        for upstream in registry["upstreams"]:
            if upstream["name"] == upstream_name:
                upstream["last_synced"] = datetime.utcnow().isoformat() + "Z"
        f.seek(0)
        json.dump(registry, f, indent=2)
        f.truncate()
```

---

## Change Detection Patterns

### Breaking Change Detection

Look for signals in commit messages and changelogs:

```bash
# Keyword search in commit messages
git log --after="{last_synced}" --grep="BREAKING" --grep="breaking change" \
    --grep="deprecated" --grep="removed" --grep="migration required" -i

# Check CHANGELOG or BREAKING_CHANGES files
git diff {last_sync_commit}..HEAD -- CHANGELOG.md BREAKING_CHANGES.md
```

### Release Detection

```bash
# New tags since last sync
git tag --sort=-creatordate --contains {last_sync_commit}

# Or via GitHub API
gh api repos/{owner}/{repo}/releases --jq '.[].tag_name' | head -5
```

### PR Activity (Optional)

```bash
# Open PRs with breaking change labels
gh pr list --repo {owner}/{repo} --label "breaking-change" --state open
```

---

## Digest Format

Generate a human-readable summary:

```markdown
## Upstream Changes — {date}

### {upstream_name} ({source_url})

**Since:** {last_synced}
**New commits:** {count}
**New releases:** {release_tags}

#### ⚠️ Breaking Changes
- {commit_sha}: {message}

#### 📦 New Releases
- v2.1.0: {release notes summary}

#### 📝 Notable Commits
- {sha}: {message}
- {sha}: {message}

#### 📁 Changed Paths
- src/api/endpoints.go
- docs/migration-v2.md
```

---

## Automation

### Scheduled Sync

Add to your automation schedule:

```json
{
  "upstream_sync": {
    "frequency": "daily",
    "time": "06:00",
    "action": "sync_all_upstreams",
    "notify_on": ["breaking_changes", "new_releases"],
    "notify_channel": "team-updates"
  }
}
```

### PowerShell Sync Script

```powershell
function Sync-Upstream {
    param(
        [string]$RegistryPath = "upstreams.json",
        [string]$MirrorDir = "_upstream_repos"
    )

    $registry = Get-Content $RegistryPath | ConvertFrom-Json

    foreach ($upstream in $registry.upstreams) {
        $repoDir = Join-Path $MirrorDir $upstream.name

        if (-not (Test-Path $repoDir)) {
            git clone --mirror $upstream.source $repoDir
        } else {
            Push-Location $repoDir
            git fetch --all 2>&1 | Out-Null
            Pop-Location
        }

        # Check for new commits
        Push-Location $repoDir
        $newCommits = git log --oneline --after="$($upstream.last_synced)" $upstream.ref 2>&1
        Pop-Location

        if ($newCommits) {
            Write-Host "📦 $($upstream.name): New changes detected"
            Write-Host $newCommits
        } else {
            Write-Host "✅ $($upstream.name): Up to date"
        }
    }
}
```

---

## See Also

- [News Broadcasting](../news-broadcasting/) — Broadcast upstream changes to team
- [Notification Routing](../notification-routing/) — Route critical changes to right people
