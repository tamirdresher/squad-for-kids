# Channel Scan — Prompt Template

> Deterministic pipeline for scanning Teams channels via WorkIQ and producing raw daily digests.
> OpenCLAW hybrid pattern: Scripts handle structured data processing; LLM handles interpretation.
> Implements: Issue #22 — Continuous Learning Phase 2

## Purpose

This template drives the automated channel scan step of the digest pipeline. It constructs WorkIQ queries, enforces file naming, and deduplicates results before handing signal items to the LLM for classification.

---

## Inputs

| Input | Source | Example |
|-------|--------|---------|
| `channel` | Caller parameter | `dk8s-support` |
| `scan_date` | Today's date (ISO 8601) | `2026-03-10` |
| `lookback_hours` | Default 24 | `24` |
| `previous_digest` | Last raw digest for this channel | `.squad/digests/2026-03-09.md` |

---

## Step 1: Query Construction (Deterministic)

Load the matching query template from `.squad/scripts/workiq-queries/{channel}.md`.

Substitute variables:

```
{{DATE_FROM}} = scan_date - lookback_hours
{{DATE_TO}}   = scan_date
{{CHANNEL}}   = channel display name
```

Execute the WorkIQ query using the `workiq-ask_work_iq` tool with the constructed question string.

---

## Step 2: File Naming (Deterministic)

Output file path follows this convention:

```
.squad/digests/{scan_date}.md          — combined daily digest (all channels)
.squad/digests/{scan_date}-{channel}.md — per-channel raw scan (Tier 1, gitignored)
```

If the file already exists (re-scan), append with suffix:

```
.squad/digests/{scan_date}-{channel}-rescan.md
```

---

## Step 3: Deduplication (Deterministic)

Before writing items to the digest:

1. **Load previous digest** — Parse `previous_digest` into a set of item fingerprints.
2. **Compute fingerprint** — For each new item: `SHA256(lowercase(author + date + first_50_chars_of_message))`.
3. **Skip duplicates** — If fingerprint exists in previous digest, mark as `[DUP]` and exclude from output.
4. **Cross-channel dedup** — After all channels scanned, merge per-channel files. If the same fingerprint appears in multiple channels, keep only the first occurrence and annotate: `[ALSO: #{other_channel}]`.

### Dedup Statistics

Track and report at the end of each scan:

```
Dedup Report:
- Items scanned: {total}
- Unique items: {unique}
- Duplicates skipped: {duped}
- Cross-channel duplicates: {cross_duped}
```

---

## Step 4: QMD Classification (LLM)

For each unique item, apply the QMD 5-category framework from `.squad/templates/qmd-extraction.md`:

| Category | Signal Words |
|----------|-------------|
| **Decisions** | decided, agreed, chose, adopted, approved, rejected |
| **Commitments** | promised, committed, deadline, due by, will deliver |
| **Pattern Changes** | changed, shifted, increased, decreased, regression |
| **Blockers & Resolutions** | blocked, waiting on, unblocked, resolved, workaround |
| **Contacts & Relationships** | met, introduced, contacted, escalated to, new SME |

Items matching zero categories → DROP (noise).
Items matching one or more → KEEP with category tags.

---

## Step 5: Output Format

Write the daily digest file with this structure:

```markdown
# Channel Scan: {channel} — {scan_date}

> Scanned {lookback_hours}h window. {unique} unique items from {total} scanned.

## Decisions
- [{date}] {item} — Source: {channel}

## Commitments
- [{date}] {item} — Owner: {who}, Due: {when}

## Pattern Changes
- [{date}] {item} — Before: {old}, After: {new}

## Blockers & Resolutions
- [{date}] {item} — Status: {blocked|resolved}

## Contacts & Relationships
- [{date}] {item} — Context: {how encountered}

## Noise Dropped
- {count} items classified as routine/ephemeral/repeated
```

---

## Scan Sequence (All Channels)

Run channels in this order to optimize cross-channel dedup:

1. `dk8s-support` — highest signal, most incidents
2. `incidents` — overlaps with dk8s-support, dedup catches most
3. `configgen` — domain-specific, minimal overlap
4. `general` — lowest signal, highest noise

After all channels complete, run the merge step in `digest-processor.md`.

---

## Error Handling

| Error | Action |
|-------|--------|
| WorkIQ query returns empty | Log warning, skip channel, continue |
| WorkIQ query times out | Retry once after 30s, then skip with error marker |
| Previous digest not found | Run without dedup (first scan) |
| File write fails | Log error, write to stdout as fallback |

---

## Integration Points

- **Input:** WorkIQ query templates (`.squad/scripts/workiq-queries/`)
- **Output:** Raw daily digests (`.squad/digests/`, Tier 1)
- **Downstream:** `digest-processor.md` merges and deduplicates across days
- **Downstream:** `qmd-extraction.md` template extracts weekly QMD from raw digests
- **Downstream:** `digest-rotation.md` handles retention and archival
