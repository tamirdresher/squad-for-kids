# Digest Processor — Merge, Dedup, and Resolve

> Processes raw per-channel scans into a unified daily digest.
> Handles cross-day deduplication and resolved incident marking.
> OpenCLAW hybrid pattern: Deterministic merging, LLM-assisted conflict resolution.
> Implements: Issue #22 — Continuous Learning Phase 2

## Purpose

After `channel-scan.md` produces per-channel raw scans, this processor merges them into a single daily digest, deduplicates across days, and marks resolved incidents.

---

## Input

| Source | Path | Description |
|--------|------|-------------|
| Per-channel scans | `.squad/digests/{date}-{channel}.md` | Raw output from channel-scan.md |
| Previous daily digests | `.squad/digests/{date-1}.md` through `{date-7}.md` | Last 7 days for dedup window |
| Active incidents list | `.squad/digests/triage/active-incidents.jsonl` | Tracked open incidents |

## Output

| Target | Path | Description |
|--------|------|-------------|
| Unified daily digest | `.squad/digests/{date}.md` | Merged, deduplicated digest (Tier 1) |
| Updated incidents | `.squad/digests/triage/active-incidents.jsonl` | With resolved items marked |

---

## Processing Pipeline

### Stage 1: Merge Per-Channel Scans

Combine all `{date}-{channel}.md` files for the current date into a single document. Preserve the QMD category structure:

```
For each QMD category (Decisions, Commitments, Pattern Changes, Blockers, Contacts):
    Collect all items from all channels
    Sort by timestamp (earliest first)
    Annotate each item with source channel: — Source: {channel}
```

### Stage 2: Cross-Day Deduplication

Compare merged items against the last 7 days of daily digests.

**Dedup Algorithm:**

```
For each item in today's merge:
    fingerprint = SHA256(lowercase(author + date_rounded_to_day + first_50_chars))
    
    For each day in [date-1 .. date-7]:
        Load previous digest fingerprint set
        If fingerprint match found:
            If item has NEW information (LLM judgment):
                Keep item, annotate: [UPDATE from {original_date}]
            Else:
                Drop item, annotate: [DUP:{original_date}]
```

**"New information" criteria (LLM judgment):**
- Status changed (e.g., blocked → resolved)
- New details added (root cause identified, timeline updated)
- Scope changed (additional services affected)
- Owner changed (reassigned)

### Stage 3: Incident Resolution Marking

Scan today's items for resolution signals:

**Resolution signal words:** resolved, fixed, mitigated, closed, completed, rolled back, deployed fix

**Process:**

```
For each item matching resolution signals:
    Search active-incidents.jsonl for matching incident
    If found:
        Update incident status: "resolved"
        Add resolution_date, resolution_method
        Add [RESOLVED] tag to digest entry
    If not found:
        Create new incident entry with status: "resolved" (captured after the fact)
```

**New incident detection:**

```
For each item matching blocker signals:
    If no matching incident in active-incidents.jsonl:
        Create new entry:
        {
            "id": "INC-{date}-{seq}",
            "title": "{item_title}",
            "status": "active",
            "opened_date": "{date}",
            "source_channel": "{channel}",
            "severity": "{inferred_severity}"
        }
```

### Stage 4: Severity Inference (LLM)

For new incidents without explicit severity, infer from context:

| Severity | Signals |
|----------|---------|
| **P0** | "outage", "all users affected", "data loss", "security breach" |
| **P1** | "degraded", "partial outage", "workaround available", "SLA breach" |
| **P2** | "intermittent", "single tenant", "non-blocking workaround" |
| **P3** | "cosmetic", "minor", "planned maintenance impact" |

### Stage 5: Write Unified Digest

Output the merged, deduplicated digest following the standard format:

```markdown
# Daily Digest — {date}

> Merged from {channel_count} channels. {unique_items} unique items, {duped_items} duplicates removed.

## Decisions
{merged items with source channels}

## Commitments
{merged items with owners and due dates}

## Pattern Changes
{merged items with before/after context}

## Blockers & Resolutions
{merged items with status tags: [ACTIVE] or [RESOLVED]}

## Contacts & Relationships
{merged items with encounter context}

## Active Incidents
| ID | Title | Severity | Status | Opened | Channel |
|----|-------|----------|--------|--------|---------|
{rows from active-incidents.jsonl}

## Processing Stats
- Channels scanned: {list}
- Total items: {total}
- After dedup: {unique}
- Cross-day duplicates: {cross_day_duped}
- Incidents opened: {new_incidents}
- Incidents resolved: {resolved_incidents}
```

---

## Conflict Resolution Rules

When the same topic appears in multiple channels with conflicting information:

1. **Incidents channel wins** for incident status and severity
2. **DK8S Support wins** for resolution details and workarounds
3. **ConfigGen wins** for package version and migration details
4. **General loses** to any specific channel

When timestamps conflict, use the **earliest** timestamp as the event time.

---

## Error Handling

| Error | Action |
|-------|--------|
| Missing channel scan file | Skip channel, note in stats |
| Corrupt previous digest | Skip cross-day dedup for that day |
| active-incidents.jsonl missing | Create new file, proceed without history |
| LLM judgment unavailable | Default to KEEP (conservative) |

---

## Integration Points

- **Upstream:** `channel-scan.md` produces per-channel raw scans
- **Downstream:** `qmd-extraction.md` runs weekly on accumulated daily digests
- **Downstream:** `digest-rotation.md` handles retention and archival
- **Data store:** `.squad/digests/triage/active-incidents.jsonl` persists incident state
