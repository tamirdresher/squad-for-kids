# Promotion Algorithm: From Git Notes to decisions.md

This document covers the promotion algorithm in detail.
For Ralph's integration flow, see `RALPH-INTEGRATION.md`.
For the note format, see `.squad/schemas/notes-v1.schema.json`.

---

## Tiers at a Glance

| Tier | Promoted When | Destination | Examples |
|------|---------------|-------------|---------|
| 1 | Same round as discovery | `decisions.md` | `promotionCandidate:true`, high-confidence decisions, critical findings |
| 2 | After 24h cooling period (if not superseded) | `decisions.md` | Medium-confidence decisions, cross-validated notes |
| Archive | Never promoted | `research-archive/` | Context notes, low-confidence assessments, session summaries |

---

## Tier 1: Immediate Promotion Criteria

Evaluate each JSONL entry. Promote if ANY of these match:

```python
def is_tier1(entry):
    c = entry['content']
    return (
        c.get('promotionCandidate') == True
        or (entry['type'] == 'decision' and c.get('confidence') == 'high')
        or (entry['type'] == 'finding' and c.get('severity') in ['critical', 'high'])
    )
```

**What this catches:**
- Agent explicitly marked a decision for promotion (`promotionCandidate:true`)
- High-confidence, definitively-stated decisions ("we chose X over Y because...")
- Security findings that warrant team awareness

---

## Tier 2: Deferred Promotion Criteria

Evaluate each JSONL entry that didn't qualify for Tier 1.
Add to `pendingTier2` in watermark. Check each round for:

```python
def is_tier2_ready(pending_entry, all_notes, now):
    original = pending_entry['originalEntry']
    promote_after = pending_entry['promoteAfter']

    # Time-based: cooling period has elapsed
    if now < promote_after:
        return False

    # Check for superseding note (same namespace, same commit, newer timestamp)
    for note in all_notes:
        if (note['commitSha'] == original['commitSha']
                and note['_namespace'] == pending_entry['namespace']
                and note['timestamp'] > original['timestamp']
                and note['refs'].get('supersedes') == original['timestamp']):
            return False  # superseded — do not promote

    # Cross-agent validation: another agent referenced this commit with agreement
    cross_validated = any(
        n['commitSha'] == original['commitSha']
        and n['_namespace'] != pending_entry['namespace']
        and n['type'] in ['decision', 'assessment']
        for n in all_notes
    )

    return True  # promote
```

---

## Archive: What Never Gets Promoted

| Type | Confidence | Disposition | Reason |
|------|-----------|-------------|--------|
| `context` | any | archive | "Why this commit" notes are commit-specific. They don't generalize. |
| `summary` | any | archive | Scribe summaries are too long and narrative for decisions.md |
| `assessment` | `low` | archive | Speculative. If it mattered, the agent would have revisited it. |
| any | any | archive | If `supersedes` field references the entry's own timestamp | (this handles the rare case of a self-replacement) |

Archived entries go to `research-archive/session-{id}/context.md` or are included in PR archive bundles. They are never deleted — just not surfaced in the main decision log.

---

## decisions.md: Append-Only Contract

**Never edit existing entries.** If a decision is wrong or outdated, add a new entry that supersedes it:

```markdown
## [2026-04-01] JWT approach superseded — migrated to service-to-service mTLS

| Field | Value |
|-------|-------|
| Supersedes | [2026-03-25 JWT for auth middleware](#link) |
| Agent | worf (worf-CPC-tamir-WCBED) |
...
```

The old entry remains. This is intentional: decisions.md is a log, not a current-state document. To find the current state of any decision, read from bottom to top. The most recent entry on a topic wins.

This makes `git blame` on decisions.md genuinely useful — each entry's line number maps directly to a commit and a timestamp.

---

## Edge Cases

### Duplicate Promotion (same note discovered in two rounds)

Ralph checks `promotion-log.jsonl` before promoting. Key: `commitSha + namespace + noteTimestamp`. If that triple already exists in the promotion log, skip.

```powershell
function Is-AlreadyPromoted($commitSha, $namespace, $noteTimestamp) {
    $log = Get-Content "promotion-log.jsonl" -ErrorAction SilentlyContinue
    if (-not $log) { return $false }
    return $log | Where-Object {
        $entry = $_ | ConvertFrom-Json
        $entry.commitSha -eq $commitSha -and
        $entry.namespace -eq $namespace -and
        $entry.noteTimestamp -eq $noteTimestamp
    }
}
```

### Promotion of a Note Whose Commit is Unreachable

If a commit has been GC'd but its note still exists (notes are stored separately), Ralph can still promote it. The commit SHA link in decisions.md will be a 404 on GitHub — that's acceptable. The reasoning still has value.

If Ralph detects the commit is unreachable (`git cat-file -t <sha>` returns non-zero), it adds a warning to the decisions.md entry:

```markdown
> ⚠️ Note: this commit's branch was deleted. The commit SHA may be unreachable.
```

### Two Notes on the Same Commit Qualify for Tier 1

Promote both. They may represent different aspects (Data says "chose JWT"; Worf says "JWT here is high risk — see CVE-XXXX"). Both entries appear in decisions.md as separate entries with the same commit SHA.

### State Branch Doesn't Exist Yet (First Run)

Ralph creates it:

```bash
# In a temporary worktree
git worktree add /tmp/squad-state --orphan squad/state
cd /tmp/squad-state
# Create initial files
echo "# Squad Decisions\n\n*This file is append-only. Never edit existing entries.*\n" > decisions.md
echo '{"lastProcessed":null,"lastRound":0,"pendingTier2":[]}' > notes-watermark.json
git add .
git commit -m "chore: initialize squad/state branch"
git push origin squad/state
git worktree remove /tmp/squad-state
```
