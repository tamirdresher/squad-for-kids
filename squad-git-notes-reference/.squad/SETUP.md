# Squad Notes — New Team Member Setup

> **TL;DR:** Run `.squad/scripts/notes-setup.sh` once after cloning. That's it.

---

## The Problem

Git does not fetch `refs/notes/*` by default. When you clone this repo and run `git fetch`, squad decision notes are **not included**. You have to explicitly configure git to fetch them.

Ralph-watch handles this automatically for the automated path. This guide is for humans.

---

## One-Time Setup

```bash
# From the repo root
bash .squad/scripts/notes-setup.sh
```

This script:
1. Adds `refs/notes/*:refs/notes/*` to your local `.git/config` (not global — repo-specific)
2. Fetches all existing squad notes from origin
3. Shows you what's available

Future `git fetch` commands will automatically include squad notes.

---

## Reading Notes

### All namespaces for a commit
```bash
# Using the helper script
pwsh .squad/scripts/notes-read.ps1 -CommitSha <sha>

# Or manually
for ns in data worf belanna picard q scribe ralph; do
  echo "=== squad/$ns ==="
  git notes --ref="squad/$ns" show <sha> 2>/dev/null && echo || true
done
```

### One namespace for a commit
```bash
git notes --ref=squad/data show <sha>
```

### All commits annotated by Data
```bash
git notes --ref=squad/data list
```

### Notes since a date (search)
```bash
# List all notes refs
git log refs/notes/squad/data --format="%H %ae %s" --since="2026-03-01"
```

---

## Writing Notes (Agents Only)

Agents write notes using `.squad/scripts/notes-write.ps1`. Humans don't write notes directly.

```powershell
# Example: Data writes a decision note
pwsh .squad/scripts/notes-write.ps1 \
  -Agent data \
  -CommitSha $(git rev-parse HEAD) \
  -NoteContent @{
    type              = "decision"
    summary           = "Use Redis for session storage"
    reasoning         = "PostgreSQL session table created lock contention under load. Redis sessions are O(1) reads."
    alternatives      = @("PostgreSQL sessions — rejected: lock contention at >100 concurrent users")
    confidence        = "high"
    promotionCandidate = $true
    tags              = @("session", "redis", "performance")
  }
```

---

## The State Branch

The `squad/state` orphan branch holds the promoted, long-lived team memory. To access it:

```bash
# Fetch the branch
git fetch origin squad/state:refs/remotes/origin/squad/state

# Create a worktree (recommended — keeps it separate from your working tree)
git worktree add .squad-state squad/state

# Read the promoted decisions
cat .squad-state/decisions.md
```

---

## Namespaces

| Namespace | Agent | Content |
|-----------|-------|---------|
| `refs/notes/squad/data` | Data | Code decisions, pattern rationale |
| `refs/notes/squad/worf` | Worf | Security findings |
| `refs/notes/squad/belanna` | Belanna | Infrastructure decisions |
| `refs/notes/squad/picard` | Picard | Architecture decisions |
| `refs/notes/squad/q` | Q | Risk assessments |
| `refs/notes/squad/scribe` | Scribe | Session boundary summaries |
| `refs/notes/squad/ralph` | Ralph | Round events, promotion records |

---

## If Something Looks Wrong

**Notes not appearing after fetch:**
```bash
# Verify the refspec is configured
git config --get-all remote.origin.fetch

# Should include: refs/notes/*:refs/notes/*
# If not: git config --add remote.origin.fetch 'refs/notes/*:refs/notes/*'
# Then: git fetch origin 'refs/notes/*:refs/notes/*'
```

**Notes exist locally but not on remote after an agent push:**
```bash
# Check the failed queue
ls .squad/notes-failed-queue/
# If files exist, Ralph will retry them next round
```

**Want to see notes in `git log`:**
```bash
git log --notes=squad/data --format="%H %s%n%N"
```
