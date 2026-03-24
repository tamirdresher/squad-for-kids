# Ralph-Watch Integration: Git Notes

This document specifies exactly how Ralph-watch interacts with the git notes layer.
Implementation target: `ralph-watch.ps1` (the existing script in the reference repo).

---

## Startup Sequence (runs once, before first round)

```
ralph-watch starts
    │
    ├─ 1. MUTEX CHECK (existing behavior — unchanged)
    │
    ├─ 2. NOTES REFSPEC SETUP (NEW)
    │     Check if refs/notes/*:refs/notes/* is in remote.origin.fetch
    │     If missing → git config --add remote.origin.fetch 'refs/notes/*:refs/notes/*'
    │     Log: "[ralph] Configured notes refspec (first time)"
    │
    ├─ 3. NOTES FETCH (NEW — explicit, always)
    │     git fetch origin 'refs/notes/*:refs/notes/*'
    │     This is NOT covered by a regular git fetch.
    │     Errors here are WARNING, not FATAL — notes may be empty on first run.
    │
    ├─ 4. STATE BRANCH SYNC (NEW)
    │     If squad/state branch exists on remote:
    │       git fetch origin squad/state:refs/remotes/origin/squad/state
    │       sync decisions.md and routing.md to .squad/ (read-only overlay)
    │     If state branch does not exist yet:
    │       Ralph creates it on first promotion (see Promotion section)
    │
    └─ 5. FAILED QUEUE CHECK (NEW)
          Process any notes in .squad/notes-failed-queue/ before starting rounds
```

### The New Member Gotcha — Handled Here

A developer fresh-clones the repo. They start ralph-watch. Step 2 fires:

```powershell
$existingRefspecs = git config --get-all remote.origin.fetch 2>&1
if ($existingRefspecs -notcontains 'refs/notes/*:refs/notes/*') {
    git config --add remote.origin.fetch 'refs/notes/*:refs/notes/*'
    Write-Host "[ralph] Added notes refspec to .git/config — future fetches will include squad notes" -ForegroundColor Green
}
```

This is idempotent. Running it on a machine that already has the refspec configured does nothing (the `notcontains` check prevents duplicate entries). Running it on a fresh clone adds the refspec once and logs it clearly.

**This does NOT fix the problem for humans who never run Ralph.** That's what `.squad/SETUP.md` and the `scripts/notes-setup.sh` are for. Ralph handles the automated path; SETUP.md handles the human path.

---

## Per-Round Sequence

```
Round starts
    │
    ├─ 1. PRE-ROUND NOTES FETCH
    │     git fetch origin 'refs/notes/*:refs/notes/*' 2>&1
    │     Silent on success. WARNING on failure (don't abort the round).
    │     Cost: minimal — git fetches only deltas since last fetch.
    │
    ├─ 2. NORMAL ROUND (agent does work, makes commits, etc.)
    │
    ├─ 3. POST-ROUND: PROMOTION CHECK
    │     Read notes-watermark.json for last-processed timestamp
    │     For each namespace in [data, worf, belanna, picard, q, scribe]:
    │       List all commits with notes newer than watermark
    │       For each note entry → run through promotion criteria
    │       Collect promotable entries
    │     Write promotable entries to squad/state branch decisions.md
    │     Update notes-watermark.json
    │
    ├─ 4. POST-ROUND: PR CLOSURE CHECK
    │     Query: PRs closed (not merged) in the last 48h
    │     For each: archive notes → squad/state research-archive/
    │
    └─ 5. POST-ROUND: FAILED QUEUE DRAIN
          Retry any notes in .squad/notes-failed-queue/
```

---

## Promotion Algorithm

A note entry is promoted to `decisions.md` based on a three-tier system.

### Tier 1 — Immediate Promotion (same round)

Promoted in the round that discovers the note.

Criteria (ANY of):
- `content.promotionCandidate == true` — agent explicitly flagged it
- `type == "decision"` AND `content.confidence == "high"`
- `type == "finding"` AND `content.severity` in `["critical", "high"]`

### Tier 2 — Deferred Promotion (after 24-hour cooling period)

Promoted only if no superseding note appears within 24 hours.

Criteria (ALL of):
- `type == "decision"` AND `content.confidence == "medium"`
- OR: note has been referenced in another agent's note (cross-agent validation)
- The commit is still reachable (not on a deleted branch)

**Why the cooling period?** Medium-confidence decisions are sometimes revised in the next round. Immediate promotion of a decision that gets superseded in 6 hours creates noise in `decisions.md`. 24 hours gives the agent a chance to revise. After 24 hours without a superseding note, the decision is considered stable.

### Tier 3 — Archive Only (never promoted to decisions.md)

These types go to `research-archive/` but not to `decisions.md`:
- `type == "context"` — ephemeral "why this commit does X" notes
- `type == "summary"` — Scribe's session boundary notes (too long, wrong format)
- `type == "assessment"` AND `content.confidence == "low"` — speculative

### Promotion Entry Format

Each promoted entry is appended to `decisions.md` on the `squad/state` branch:

```markdown
## [YYYY-MM-DD] {content.summary}

| Field | Value |
|-------|-------|
| Agent | {agent} ({instanceId}) |
| Commit | [`{commitSha[0:8]}`]({repoUrl}/commit/{commitSha}) |
| PR | [#{prNumber}]({repoUrl}/pull/{prNumber}) |
| Confidence | {confidence} |
| Type | {type} |
| Promoted | {promotionTimestamp} (Tier {tier}) |

**Decision**: {content.reasoning}

**Alternatives considered**: {content.alternatives joined by " / " or "none documented"}

**Tags**: {tags joined by ", "}

---
```

### Promotion Log

Every promotion also writes a line to `promotion-log.jsonl` on the `squad/state` branch:

```jsonc
{"timestamp":"2026-03-25T03:00:00Z","tier":1,"commitSha":"abc1234...","namespace":"squad/data","noteTimestamp":"2026-03-25T02:14:00Z","summary":"Use JWT for auth middleware","decisionsMdLine":42}
```

This is the audit trail. If you want to know "when was this decision promoted and why", query `promotion-log.jsonl`.

### Watermark Management

`notes-watermark.json` on the `squad/state` branch:

```json
{
  "lastProcessed": "2026-03-25T03:00:00Z",
  "lastRound": 47,
  "processedCommits": [],
  "pendingTier2": [
    {
      "commitSha": "def5678...",
      "namespace": "squad/data",
      "noteTimestamp": "2026-03-24T22:00:00Z",
      "promoteAfter": "2026-03-25T22:00:00Z"
    }
  ]
}
```

Ralph reads this at round start, writes it at round end. If `pendingTier2` has entries whose `promoteAfter` timestamp has passed, they get promoted.

**Important:** Ralph is the ONLY writer of `notes-watermark.json`. No other agent writes to the state branch directly. This is the serialization guarantee that prevents double-promotion.

---

## PR Closure Detection and Research Archive

### When Ralph Runs This Check

Once per round, after the notes fetch, before the promotion check.

### The Query

```powershell
# Get PRs closed (rejected, not merged) in the last 48h
$cutoff = (Get-Date).AddHours(-48).ToString("yyyy-MM-ddTHH:mm:ssZ")
$closedPRs = gh pr list --state closed --json number,mergedAt,headRefName,title,closedAt `
  | ConvertFrom-Json `
  | Where-Object { $_.mergedAt -eq $null -and $_.closedAt -gt $cutoff }
```

### For Each Closed-Without-Merge PR

```powershell
foreach ($pr in $closedPRs) {
    $archivePath = "research-archive/pr-$($pr.number)-$(Get-Date -Format 'yyyy-MM-dd')"

    # 1. Try to enumerate commits from the (possibly deleted) branch
    $commits = @()
    try {
        $commits = git log --format="%H" "origin/$($pr.headRefName)" 2>&1
    } catch {
        # Branch already deleted — try to recover from PR's commit list via gh api
        $commits = gh api "repos/{owner}/{repo}/pulls/$($pr.number)/commits" `
          --jq '.[].sha' 2>/dev/null
    }

    # 2. Collect all squad notes for these commits
    $allNotes = @()
    foreach ($sha in $commits) {
        foreach ($ns in @('data','worf','belanna','picard','q','scribe','ralph')) {
            $noteBlob = git notes --ref="squad/$ns" show $sha 2>&1
            if ($LASTEXITCODE -eq 0 -and $noteBlob) {
                # Parse each JSONL line and tag with namespace
                $noteBlob -split "`n" | Where-Object { $_ } | ForEach-Object {
                    $entry = $_ | ConvertFrom-Json
                    $entry | Add-Member -NotePropertyName '_namespace' -NotePropertyValue $ns
                    $allNotes += $entry
                }
            }
        }
    }

    # 3. Write archive to state branch
    $metadata = @{
        prNumber = $pr.number
        title    = $pr.title
        status   = "closed_not_merged"
        closedAt = $pr.closedAt
        headRef  = $pr.headRefName
        commitCount = $commits.Count
        noteCount = $allNotes.Count
        archivedAt = (Get-Date -Format 'o')
    }

    # Write to squad/state branch (via worktree or direct git operations)
    Write-StateFile "$archivePath/metadata.json" ($metadata | ConvertTo-Json)
    Write-StateFile "$archivePath/notes.jsonl" ($allNotes | ForEach-Object { $_ | ConvertTo-Json -Compress } | Join-String -Separator "`n")
    Write-StateFile "$archivePath/summary.md" (Build-PRArchiveSummary $pr $allNotes)

    # 4. Track in watermark so we don't re-archive
    Add-WatermarkArchivedPR $pr.number
}
```

### Timing: Why 48h Window?

- PRs are typically reviewed and closed within 24h of being opened
- The 48h window gives a buffer for time zones and delayed review
- Ralph runs this check every round (default: every 30 minutes)
- A PR closed 12h ago will be archived within 30 minutes of closure

**Edge case: branch already deleted before Ralph runs.** This is the most dangerous scenario — the commits become unreachable and git GC can collect them. The mitigation:
1. The 48h window means Ralph has 48 attempts (at 30-min intervals) before a typical branch deletion
2. The `gh api` fallback retrieves commit SHAs from the GitHub API even after branch deletion
3. If commits are already GC'd: the notes ref still exists (notes are separate git objects, not on the commit tree). `git notes show <sha>` will return the note even if the commit is unreachable — until `git gc` drops the notes too.
4. Ralph should run `git notes list refs/notes/squad/data` to find orphaned notes (notes for unreachable commits) and archive them proactively.

---

## New Member Setup (the explicit fetch gotcha)

### Automated Path (Ralph handles this)

Ralph's startup Step 2+3 handles this for anyone running ralph-watch. The refspec gets added once and notes get fetched immediately. This works for CI too — add to CI setup:

```yaml
- name: Configure squad notes fetch
  run: |
    git config --add remote.origin.fetch 'refs/notes/*:refs/notes/*'
    git fetch origin 'refs/notes/*:refs/notes/*'
```

### Human Path (SETUP.md documents this)

For developers who want to read notes but don't run Ralph:

```bash
# One-time setup — adds notes to every future git fetch
git config --add remote.origin.fetch 'refs/notes/*:refs/notes/*'

# Explicit fetch (required after setup, or run git fetch which now includes notes)
git fetch origin 'refs/notes/*:refs/notes/*'

# Read notes for a specific commit
git notes --ref=squad/data show <commit-sha>

# Read notes from all namespaces for a commit
for ns in data worf belanna picard q scribe ralph; do
  echo "=== squad/$ns ===" && git notes --ref="squad/$ns" show <commit-sha> 2>/dev/null || true
done
```

### Why Not Auto-Configure in .gitconfig?

The refspec needs to be in `.git/config` (local), not `~/.gitconfig` (global), because the notes namespaces are repo-specific. The `notes-setup.sh` script does the right thing:

```bash
#!/usr/bin/env bash
# .squad/scripts/notes-setup.sh — run once after cloning
set -e

# Must be run from repo root
git rev-parse --show-toplevel > /dev/null 2>&1 || { echo "ERROR: Not in a git repo"; exit 1; }

# Add refspec if not present
if ! git config --get-all remote.origin.fetch | grep -q 'refs/notes/\*:refs/notes/\*'; then
  git config --add remote.origin.fetch 'refs/notes/*:refs/notes/*'
  echo "✓ Added notes refspec to .git/config"
else
  echo "✓ Notes refspec already configured"
fi

# Fetch notes
git fetch origin 'refs/notes/*:refs/notes/*'
echo "✓ Fetched squad notes"
echo ""
echo "You can now read notes with:"
echo "  git notes --ref=squad/data show <commit-sha>"
```

---

## Summary: When Does Ralph Fetch Notes?

| Trigger | Fetch? | Reason |
|---------|--------|--------|
| Startup | YES — always | First-run refspec setup + initial state |
| Round start | YES — always | Cheap delta; ensures fresh state before agent work |
| Round end | NO | Post-round write only; reading stale notes here is fine |
| After agent writes a note | YES — within the write retry loop | Confirm push succeeded |
| On PR closure detection | YES — targeted namespace fetch | Get latest before archiving |
| On failed queue drain | YES — within retry loop | Same as write retry loop |

The fetch is never skipped. It's cheap (delta only after first fetch). Skipping it to save time is a false economy that creates hard-to-debug staleness bugs.
