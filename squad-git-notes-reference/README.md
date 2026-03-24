# squad-git-notes-reference

**Canonical reference implementation of the two-layer Squad state architecture.**

Described in: [Part 7b — The Invisible Layer: Git Notes, Orphan Branches, and the Squad State Solution](https://tamirdresher.github.io/blog/2026/03/23/scaling-ai-part7b-git-notes)

---

## What This Repo Is

This is the reference implementation that Part 7b promised but didn't yet have. It defines precisely:

- The JSON schema for every git note written by a Squad agent
- Which agents write to which `refs/notes/squad/*` namespaces
- How conflicting concurrent writes are resolved
- How Ralph-watch integrates with the notes layer (fetch timing, promotion algorithm, PR archive)
- What lives in the `squad/state` orphan branch
- What lives in `.squad/` in the main repo

If you are building a Squad setup and want the two-layer architecture, clone this repo and use it as your template.

---

## The Architecture in One Paragraph

Squad state lives in two places. **Git notes** (`refs/notes/squad/*`) hold commit-scoped context — invisible in PRs, attached to the commits that caused the decisions, retrieved by SHA when someone asks "why did we do this". **The state branch** (`squad/state`, orphan) holds the permanent team memory — the promoted decisions log, agent histories, research archives. Ralph-watch bridges them: it fetches notes before every round, promotes high-confidence entries to `decisions.md`, and archives notes from closed PRs before git GC can collect them. The main repo's `.squad/` directory holds only static team definition. It never contains operational data. A PR diff contains exactly the code changes.

---

## Repository Structure

```
squad-git-notes-reference/
├── ARCHITECTURE.md               ← master design document (start here)
│
├── .squad/
│   ├── SETUP.md                  ← new team member onboarding (git notes gotcha)
│   ├── upstream.json             ← pointer to state storage
│   ├── schemas/
│   │   └── notes-v1.schema.json  ← JSON Schema for all git notes
│   ├── scripts/
│   │   ├── notes-setup.sh        ← one-time setup (configures refspec + fetches)
│   │   ├── notes-fetch.sh        ← explicit fetch helper
│   │   ├── notes-write.ps1       ← write a note with schema validation + retry
│   │   └── notes-read.ps1        ← read notes for a commit (human-readable or JSON)
│   ├── agents/                   ← agent charters (populate per your team)
│   └── decisions/
│       └── inbox/                ← agents drop decisions here; Ralph promotes them
│
└── docs/
    ├── CONFLICT-PROTOCOL.md      ← multi-agent conflict resolution (the hard part)
    ├── RALPH-INTEGRATION.md      ← Ralph-watch integration: when to fetch, promote, archive
    ├── PROMOTION-ALGORITHM.md    ← Tier 1/2/Archive criteria in detail
    └── STATE-BRANCH.md           ← squad/state branch structure + bootstrap script
```

---

## Quick Start

```bash
# 1. Clone
git clone https://github.com/tamirdresher/squad-git-notes-reference
cd squad-git-notes-reference

# 2. Configure git to fetch squad notes (one-time)
bash .squad/scripts/notes-setup.sh

# 3. Read the architecture
cat ARCHITECTURE.md

# 4. Read a note for a commit (once notes exist)
pwsh .squad/scripts/notes-read.ps1 -CommitSha <sha>

# 5. Write a note (agents use this)
pwsh .squad/scripts/notes-write.ps1 -Agent data -CommitSha <sha> -NoteContent @{
    type       = "decision"
    summary    = "Use Redis for session storage"
    reasoning  = "PostgreSQL sessions created lock contention"
    confidence = "high"
    promotionCandidate = $true
    tags       = @("redis", "session", "performance")
}
```

---

## Key Design Decisions

| Question | Answer |
|----------|--------|
| Per-role or per-instance namespaces? | **Per-role.** All Data instances write to `refs/notes/squad/data`. |
| What's the note format? | **JSONL** — one JSON object per line, no wrapping array. |
| How are concurrent writes handled? | Fetch → append → push retry loop with exponential backoff. |
| When does Ralph fetch notes? | Startup AND start of every round. Never skipped. |
| What gets promoted to decisions.md? | Tier 1 (same round): `promotionCandidate:true`, high-confidence decisions, critical findings. Tier 2 (after 24h): medium-confidence decisions. |
| Who writes to the state branch? | Ralph only. All others use `.squad/decisions/inbox/`. |
| How are PR archives handled? | Ralph queries for PRs closed-not-merged within 48h. Collects all notes, writes to `research-archive/`. |

---

## The Gotcha You Must Not Skip

Git does not fetch `refs/notes/*` by default. A fresh `git clone` + `git fetch` will NOT include squad notes. Run `.squad/scripts/notes-setup.sh` once. Ralph-watch handles this automatically for the automated path.

See `.squad/SETUP.md` for the full explanation.

---

## Part of the Series

- [Part 7b: The Invisible Layer](https://tamirdresher.github.io/blog/2026/03/23/scaling-ai-part7b-git-notes) — the blog post this implements
- [Part 7: When Git Is Your Database](https://tamirdresher.github.io/blog/2026/03/23/scaling-ai-part7-enterprise-state) — the problem this solves
