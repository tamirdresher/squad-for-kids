# Architecture Decision: Two-Layer Squad State

**Date**: 2026-03-25  
**Agent**: Picard  
**Status**: Decided  
**Scope**: squad-git-notes-reference reference implementation

---

## Decision

Squad operational state is split into exactly two layers with a hard boundary between them:

1. **Git notes layer** (`refs/notes/squad/*`) — commit-scoped, ephemeral, invisible in PRs
2. **State branch** (`squad/state` orphan branch) — permanent team memory, append-only

The main repo's working tree contains **zero operational state**. `.squad/` holds static team definition only. `upstream.json` is a stable pointer — it does not change round-to-round.

---

## Agent Namespace Assignment

Per-role namespaces. Not per-instance.

```
refs/notes/squad/data      ← Data (all instances)
refs/notes/squad/worf      ← Worf (all instances)
refs/notes/squad/belanna   ← Belanna (all instances)
refs/notes/squad/picard    ← Picard (all instances)
refs/notes/squad/q         ← Q (all instances)
refs/notes/squad/scribe    ← Scribe (all instances)
refs/notes/squad/ralph     ← Ralph (all instances)
```

Per-instance namespaces were rejected. They require consumers to enumerate all known instances, which is a design debt that compounds as instances proliferate.

---

## Conflict Resolution

The canonical protocol for concurrent writes:
1. Fetch → append → push
2. On rejection: loop back to step 1 with exponential backoff (2^n + jitter, max 5 retries)
3. After 5 failures: failed queue for Ralph to drain

Note format is JSONL (one entry per line). The `cat_sort_uniq` merge strategy handles blob-level conflicts without data loss.

Never edit notes. Supersede them with a new entry that sets the `supersedes` field.

---

## Ralph's Role

Ralph is the single serialization point for writes to the `squad/state` branch. No other agent writes directly to that branch. This prevents concurrent writes to `decisions.md` and eliminates a whole class of conflicts.

Ralph's write sequence: notes fetch → agent round → promotion check → state branch commit.

---

## State Branch

Orphan branch `squad/state`. No history shared with `main`. Files:
- `decisions.md` — append-only promoted decision log
- `agents/{name}/` — per-agent histories and context
- `research-archive/` — notes rescued from branches before GC
- `notes-watermark.json` — Ralph's promotion cursor
- `promotion-log.jsonl` — full audit trail of all promotions

---

## Alternatives Rejected

| Alternative | Why rejected |
|-------------|--------------|
| Store decisions in `.squad/` committed files | Pollutes PRs; every agent write is a commit diff |
| Separate dedicated state repo | Splits "what did we decide on auth" across two repos; no single grep |
| Per-instance namespaces | Consumers must enumerate all instances; breaks when new machines added |
| `git stash` / local files only | Not shared across machines; evaporates on fresh clone |
| Single `refs/notes/squad` namespace | One namespace per namespace per commit; second writer overwrites first |
