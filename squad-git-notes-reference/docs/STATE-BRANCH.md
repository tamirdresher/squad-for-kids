# Squad State Branch — Bootstrap Guide

This document describes the `squad/state` orphan branch structure.
To initialize this branch in a new repo, see the `init-state-branch` section below.

---

## Full File Tree

```
squad/state (orphan branch)
│
├── README.md                            ← this file
├── decisions.md                         ← APPEND-ONLY promoted decision log
├── routing.md                           ← routing table snapshot (Ralph syncs from main)
├── notes-watermark.json                 ← Ralph's promotion cursor
├── promotion-log.jsonl                  ← audit trail: every promotion ever made
│
├── agents/
│   ├── data/
│   │   ├── history.md                   ← rolling session history (last 90 days)
│   │   ├── active-context.md            ← what Data is currently working on
│   │   └── expertise.md                 ← accumulated domain knowledge patterns
│   │
│   ├── worf/
│   │   ├── history.md
│   │   └── security-findings.md         ← persistent security posture log
│   │
│   ├── belanna/
│   │   ├── history.md
│   │   └── infra-decisions.md
│   │
│   ├── picard/
│   │   ├── history.md
│   │   └── adr-index.md                 ← index of architecture decisions
│   │
│   ├── q/
│   │   ├── history.md
│   │   └── open-risks.md                ← risk register
│   │
│   ├── ralph/
│   │   ├── history.md
│   │   ├── work-queue.md                ← current task state
│   │   └── round-log.jsonl              ← structured: round number, duration, outcome
│   │
│   └── scribe/
│       └── history.md
│
├── research-archive/
│   │
│   ├── pr-{number}-{YYYY-MM-DD}/        ← notes rescued from a closed/rejected PR
│   │   ├── metadata.json                ← pr#, title, status, closed_at, commit_count
│   │   ├── notes.jsonl                  ← ALL notes from ALL commits in the PR
│   │   └── summary.md                   ← human-readable summary
│   │
│   └── session-{id}/                    ← long-closed session context
│       ├── metadata.json
│       └── context.md
│
└── ceremonies/
    ├── retrospectives/
    │   └── YYYY-MM-DD-retro.md
    └── reviews/
        └── YYYY-WW-review.md
```

---

## Key Files

### `decisions.md`

Append-only. Never edit existing entries. Structure:

```markdown
# Squad Decisions

*This file is append-only. Most recent entry is at the bottom.
To find the current state of any decision topic, read from bottom to top.*

---

## [2026-03-25] Use JWT for auth middleware on new /api/reports endpoint

| Field | Value |
|-------|-------|
| Agent | data (data-CPC-tamir-WCBED) |
| Commit | [`abc12345`](https://github.com/owner/repo/commit/abc12345...) |
| PR | [#57](https://github.com/owner/repo/pull/57) |
| Confidence | high |
| Type | decision |
| Promoted | 2026-03-25T03:00:00Z (Tier 1) |

**Decision**: Existing auth.go already uses JWT on lines 47-89. Adding API key strategy
would require refactoring the auth interceptor. JWT is already tested and working.

**Alternatives**: API key auth — rejected: requires auth interceptor refactor, no
measurable security benefit for internal endpoint

**Tags**: auth, jwt, api

---
```

### `notes-watermark.json`

Written by Ralph after each round. Never written by other agents.

```json
{
  "lastProcessed": "2026-03-25T03:00:00Z",
  "lastRound": 47,
  "pendingTier2": [
    {
      "commitSha": "def5678901234567890123456789012345678901234",
      "namespace": "squad/data",
      "noteTimestamp": "2026-03-24T22:00:00Z",
      "promoteAfter": "2026-03-25T22:00:00Z",
      "summary": "Consider Redis for session storage"
    }
  ],
  "archivedPrs": [123, 456]
}
```

### `promotion-log.jsonl`

One line per promotion. Used for deduplication and auditing.

```jsonl
{"timestamp":"2026-03-25T03:00:00Z","tier":1,"commitSha":"abc12345...","namespace":"squad/data","noteTimestamp":"2026-03-25T02:14:00Z","summary":"Use JWT for auth middleware","decisionsLine":42,"ralphRound":47}
```

---

## Initializing This Branch (First Time)

```bash
# Option A: Git worktree (preferred — avoids branch switching)
git worktree add /tmp/squad-state-init --orphan squad/state
cd /tmp/squad-state-init

cat > README.md << 'EOF'
# Squad State Branch

This is the `squad/state` orphan branch.
It contains the team's permanent operational memory.
See `.squad/SETUP.md` in the main branch for access instructions.
EOF

cat > decisions.md << 'EOF'
# Squad Decisions

*Append-only. Most recent entry at the bottom.
To find current state of any topic, read from bottom to top.*

---
EOF

echo '{"lastProcessed":null,"lastRound":0,"pendingTier2":[],"archivedPrs":[]}' > notes-watermark.json
touch promotion-log.jsonl

mkdir -p agents/{data,worf,belanna,picard,q,ralph,scribe}
mkdir -p research-archive ceremonies/retrospectives ceremonies/reviews

# Create placeholder files
for agent in data worf belanna picard q ralph scribe; do
  echo "# $agent History" > agents/$agent/history.md
done

git add .
git commit -m "chore: initialize squad/state branch"
git push origin squad/state

cd -
git worktree remove /tmp/squad-state-init
```

---

## Accessing This Branch

```bash
# Fetch
git fetch origin squad/state

# Worktree access (recommended for Ralph-watch)
git worktree add .squad-state squad/state

# Direct checkout (not recommended — disrupts working tree)
git checkout squad/state
```

---

## Write Access

**Only Ralph writes to this branch.** All other agents deposit decisions in `.squad/decisions/inbox/` in the main branch. Ralph picks them up each round, applies them to `decisions.md` on this branch, and clears the inbox.

This is the serialization guarantee that makes `decisions.md` conflict-free.
