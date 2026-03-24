# squad-git-notes-reference
## Canonical Reference Implementation — Two-Layer Squad State Architecture

> From Part 7b: *"The Invisible Layer — Git Notes, Orphan Branches, and the Squad State Solution"*

---

## Overview

Squad state lives in **two layers with distinct purposes**. Do not merge them.

```
┌─────────────────────────────────────────────────────────┐
│  MAIN REPO  (src/, tests/, etc.)                        │
│                                                         │
│  .squad/                    ← team definition (static)  │
│    copilot-instructions.md  ← committed, visible        │
│    routing.md               ← committed, visible        │
│    agents/                  ← agent charters            │
│    schemas/                 ← notes JSON schema         │
│    scripts/                 ← helpers for humans        │
│    upstream.json            ← pointer to live state     │
│    decisions/inbox/         ← agent drop zone           │
│                                                         │
│  refs/notes/squad/*         ← INVISIBLE LAYER           │
│    squad/data               ← Data's commit decisions   │
│    squad/worf               ← Worf's security findings  │
│    squad/belanna            ← Belanna's infra decisions │
│    squad/picard             ← Picard's arch decisions   │
│    squad/q                  ← Q's risk assessments      │
│    squad/scribe             ← Scribe's context summaries│
│    squad/ralph              ← Ralph's round events      │
│                                                         │
│  (never appears in git diff, PR reviews, git status)    │
└──────────────────────────┬──────────────────────────────┘
                           │
                    Ralph-watch
                    reads upstream.json on startup
                    fetches notes before every round
                    promotes high-confidence notes
                    archives notes from closed PRs
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  SQUAD STATE  (orphan branch: squad/state)              │
│                                                         │
│  decisions.md               ← append-only decision log  │
│  routing.md                 ← current routing snapshot  │
│  agents/{name}/             ← per-agent histories       │
│  research-archive/          ← notes rescued from GC     │
│  ceremonies/                ← retros, reviews           │
│  notes-watermark.json       ← Ralph's promotion cursor  │
│  promotion-log.jsonl        ← what was promoted & why   │
└─────────────────────────────────────────────────────────┘
```

**The invariant:** The main repo's working tree and PR diffs contain zero squad operational state. A human reviewer opens a PR and sees exactly the code changes. Nothing else.

---

## Layer 1: Git Notes — Agent Namespace Design

### Namespace Table

| Agent   | Namespace                    | Content Type                              | Writes on             |
|---------|------------------------------|-------------------------------------------|-----------------------|
| Data    | `refs/notes/squad/data`      | Code decisions, pattern rationale         | Every meaningful commit during PR work |
| Worf    | `refs/notes/squad/worf`      | Security findings, risk flags             | Commits touching auth/crypto/network  |
| Belanna | `refs/notes/squad/belanna`   | Infrastructure decisions                  | Commits touching infra config         |
| Picard  | `refs/notes/squad/picard`    | Architecture decisions, ADR summaries     | Commits with structural changes       |
| Q       | `refs/notes/squad/q`         | Devil's advocate assessments, risk models | On-demand; when asked to review       |
| Scribe  | `refs/notes/squad/scribe`    | Cross-session context summaries           | Session boundaries                    |
| Ralph   | `refs/notes/squad/ralph`     | Round events, promotion records           | After each round                      |

**Rule: one namespace per agent role, not per agent instance.** Two Data instances on different machines both write to `refs/notes/squad/data`. The `instanceId` field inside each entry provides tracing. Consumers query one namespace and see everything.

### Note Format: JSONL

Each note is a **JSONL blob** — one JSON object per line. Never a single JSON object. This is what makes `cat_sort_uniq` merge work correctly and what `append` mode produces naturally.

```
# refs/notes/squad/data for commit abc1234 might look like:
{"v":1,"agent":"data","instanceId":"data-CPC-tamir-WCBED","timestamp":"2026-03-25T02:14:00Z",...}
{"v":1,"agent":"data","instanceId":"data-TAMIRDRESHER","timestamp":"2026-03-25T02:18:33Z",...}
```

### JSON Schema (v1)

See `.squad/schemas/notes-v1.schema.json` for the full JSON Schema.

Key fields:

```jsonc
{
  "v": 1,                              // schema version — increment on breaking changes
  "agent": "data",                     // agent role (matches namespace suffix)
  "instanceId": "data-{machineId}",    // for deduplication and tracing only
  "sessionId": "uuid-v4",              // Copilot CLI session that produced this note
  "timestamp": "ISO-8601",
  "commitSha": "full-sha-40-chars",    // always full SHA, never short

  "type": "decision|context|finding|assessment|summary",
  // decision   → a choice made; promotion candidate
  // context    → why THIS commit does what it does; ephemeral
  // finding    → something discovered (security issue, pattern violation)
  // assessment → Q's evaluation; may or may not promote
  // summary    → Scribe's session boundary note; archived not promoted

  "content": {
    "summary": "one-line, ≤120 chars",
    "reasoning": "full reasoning, may be multi-paragraph",
    "alternatives": ["alt1", "alt2"],   // what was NOT chosen, and why not
    "confidence": "high|medium|low",
    "severity": "critical|high|medium|low|info",  // for finding type
    "promotionCandidate": true          // explicit flag; Ralph respects this
  },

  "refs": {
    "prNumber": 123,                    // null if not yet in a PR
    "workItemId": null,                 // ADO work item if applicable
    "relatedCommits": ["sha1", "sha2"], // commits this decision touches
    "supersedes": "sha-of-earlier-note" // if this note overrides a prior decision
  },

  "tags": ["auth", "jwt", "performance"] // freeform; used by Ralph for categorization
}
```

### Conflicting Writes: Two Agents, Same Commit, Same Namespace

**This is rare but must be handled correctly.** The scenario: Data-machine1 and Data-machine2 both finish working on commit `abc1234` at roughly the same time.

**Always use `append`, never `add`:**
```bash
git notes --ref=squad/data append \
  -m '{"v":1,"agent":"data","instanceId":"data-machine1",...}' \
  abc1234
```

`append` adds a new line to the existing JSONL blob. The conflict happens at push time, not at write time.

**Push-time conflict resolution** — see `docs/CONFLICT-PROTOCOL.md` for the full protocol.

Short version: fetch → re-append on top of remote state → push → retry with exponential backoff. The `cat_sort_uniq` notes merge strategy handles blob-level conflicts.

---

## Layer 2: State Branch — `squad/state`

### Full File Tree

```
squad/state (orphan branch — no common history with main)
│
├── README.md                        # access instructions for humans
├── decisions.md                     # APPEND-ONLY promoted decision log
├── routing.md                       # routing table snapshot (synced from main by Ralph)
├── notes-watermark.json             # Ralph's cursor: last processed notes timestamp
├── promotion-log.jsonl              # structured log: what was promoted, when, why
│
├── agents/
│   ├── data/
│   │   ├── history.md               # rolling session history (last 90 days)
│   │   ├── active-context.md        # what Data is currently working on
│   │   └── expertise.md            # accumulated domain knowledge patterns
│   ├── worf/
│   │   ├── history.md
│   │   └── security-findings.md    # persistent security posture log
│   ├── belanna/
│   │   ├── history.md
│   │   └── infra-decisions.md
│   ├── picard/
│   │   ├── history.md
│   │   └── adr-index.md            # index of architecture decisions
│   ├── q/
│   │   ├── history.md
│   │   └── open-risks.md           # risk register
│   ├── ralph/
│   │   ├── history.md
│   │   ├── work-queue.md           # current task state
│   │   └── round-log.jsonl         # structured: round number, duration, outcome
│   └── scribe/
│       └── history.md
│
├── research-archive/
│   ├── pr-{number}-{YYYY-MM-DD}/
│   │   ├── metadata.json           # pr number, title, status, reason for closure
│   │   ├── notes.jsonl             # ALL notes from ALL commits in the PR
│   │   └── summary.md              # human-readable summary of what was learned
│   └── session-{id}/               # archived context from long-closed sessions
│       ├── metadata.json
│       └── context.md
│
└── ceremonies/
    ├── retrospectives/
    │   └── YYYY-MM-DD-retro.md
    └── reviews/
        └── YYYY-WW-review.md
```

### Key properties of `squad/state`

1. **Orphan branch** — `git checkout --orphan squad/state`. No merge history with `main`. This is intentional: squad state is operational data, not code.

2. **Never squashed** — append-only. `decisions.md` grows; entries are never edited or deleted. This is the permanent record.

3. **Ralph owns writes** — only Ralph pushes to this branch. Other agents write to notes or `.squad/decisions/inbox/`. Ralph is the serialization point.

4. **research-archive is the GC rescue** — when a PR branch gets deleted, its commits become unreachable and git GC eventually drops them. Ralph archives the notes before this happens. See `docs/RALPH-INTEGRATION.md` for the timing.

---

## `.squad/` Structure (Main Repo)

The `.squad/` directory in the main repo contains **static team definition** — things that don't change round-to-round. Not operational state.

```
.squad/
├── copilot-instructions.md          # GitHub Copilot context (committed, visible to all)
├── routing.md                       # who handles what (committed, visible to all)
├── upstream.json                    # pointer to live state storage
│
├── agents/
│   ├── data.md                      # Data's charter + system prompt
│   ├── worf.md
│   ├── belanna.md
│   ├── picard.md
│   ├── ralph.md
│   ├── q.md
│   └── scribe.md
│
├── schemas/
│   └── notes-v1.schema.json         # JSON Schema for all git notes
│
├── scripts/
│   ├── notes-setup.sh               # one-time setup for new team members
│   ├── notes-fetch.sh               # explicit fetch (for humans who want to see notes)
│   ├── notes-write.ps1              # write a note with schema validation
│   ├── notes-read.ps1               # read notes for a commit across all namespaces
│   └── notes-promote.ps1            # promotion logic (Ralph calls this)
│
├── decisions/
│   └── inbox/
│       └── .gitkeep                 # agents drop decision files here; Ralph promotes them
│
└── SETUP.md                         # new team member setup guide (git notes gotcha)
```

### `upstream.json` format

```json
{
  "version": 1,
  "stateStorage": {
    "type": "orphan-branch",
    "branch": "squad/state",
    "note": "Access with: git fetch origin squad/state:squad/state && git worktree add .squad-state squad/state"
  },
  "notes": {
    "namespaces": ["data", "worf", "belanna", "picard", "q", "scribe", "ralph"],
    "refspecBase": "refs/notes/squad/",
    "fetchRefspec": "refs/notes/*:refs/notes/*"
  },
  "ralph": {
    "promotionEnabled": true,
    "archiveOnPrClose": true,
    "watermarkFile": "notes-watermark.json"
  }
}
```

---

## See Also

- `docs/CONFLICT-PROTOCOL.md` — multi-agent conflict resolution
- `docs/RALPH-INTEGRATION.md` — Ralph-watch integration details
- `docs/PROMOTION-ALGORITHM.md` — how notes become decisions
- `.squad/schemas/notes-v1.schema.json` — JSON Schema
- `.squad/scripts/` — operational scripts
- `.squad/SETUP.md` — new team member onboarding
