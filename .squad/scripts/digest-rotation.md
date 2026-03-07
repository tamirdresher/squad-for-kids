# Digest Rotation — Retention and Archival Rules

> Manages lifecycle of digest files across the three-tier memory architecture.
> Implements retention policies from `.squad/templates/memory-separation.md`.
> Implements: Issue #22 — Continuous Learning Phase 2

## Purpose

Raw digests accumulate daily. Without rotation, they consume storage and clutter the working directory. This document defines when files move between tiers, when they get archived, and when they get deleted.

---

## Retention Schedule

```
┌──────────────────────────────────────────────────────────────┐
│  Day 0-7:  Raw daily digests accumulate (Tier 1)             │
│            Per-channel scans live in .squad/digests/          │
│                                                              │
│  Day 7:    QMD extraction runs (weekly)                      │
│            Raw → Curated QMD digest (Tier 2)                 │
│            QMD written to .squad/digests/archive/             │
│                                                              │
│  Day 30:   Raw daily digests auto-deleted                    │
│            QMD digests remain forever in archive/             │
│                                                              │
│  Day 90:   Triage JSONL files compressed and archived        │
│                                                              │
│  Never:    QMD digests, Dream reports, Skills — permanent    │
└──────────────────────────────────────────────────────────────┘
```

---

## Tier 1 → Tier 2 Promotion (Weekly QMD Extraction)

**Trigger:** Every 7 days (Sunday end-of-day or end of sprint).

**Process:**

1. Collect all raw daily digests from the past 7 days:
   ```
   .squad/digests/{date}.md  (7 files)
   ```

2. Run QMD 5-category extraction (`.squad/templates/qmd-extraction.md`):
   - Extract: Decisions, Commitments, Pattern Changes, Blockers, Contacts
   - Drop: Routine operations, ephemeral context, repeated info, simple Q&A, mechanical updates

3. Write QMD digest to Tier 2:
   ```
   .squad/digests/archive/{start_date}-to-{end_date}.qmd.md
   ```

4. Per-channel scan files (`{date}-{channel}.md`) are deleted immediately after QMD extraction — they are intermediate artifacts.

---

## Tier 1 Cleanup (30-Day Raw Deletion)

**Trigger:** Daily, as part of the scan pipeline startup.

**Process:**

```
For each file in .squad/digests/:
    If filename matches {YYYY-MM-DD}.md pattern:
        If file_date < today - 30 days:
            Verify QMD extraction has been run for that week:
                Check .squad/digests/archive/ for covering QMD digest
            If QMD exists:
                Delete raw file
            If QMD missing:
                Log WARNING: "Raw digest {file} has no QMD coverage — running emergency extraction"
                Run QMD extraction for the uncovered week
                Then delete raw file
```

**Safety rule:** Never delete a raw digest unless its week has a corresponding QMD digest in the archive.

---

## Triage JSONL Rotation (90-Day)

**Trigger:** Quarterly (or when file exceeds 10MB).

**Process:**

1. Archive current triage file:
   ```
   .squad/digests/triage/triage-{month}.jsonl
   → .squad/digests/triage/archive/triage-{month}.jsonl.gz
   ```

2. Create new empty triage file for current month.

3. Triage archives older than 1 year can be deleted.

---

## Agent Logs and Session Cleanup (14-Day)

**Trigger:** Daily, as part of scan pipeline startup.

**Process:**

```
For each file in .squad/log/:
    If file_modified_date < today - 14 days:
        Delete file

For each file in .squad/sessions/:
    If file_modified_date < today - 30 days:
        Delete file
```

---

## Dream Report Handling

Dream reports (`.squad/digests/dream/`) are **never deleted or rotated**. They are Tier 2 permanent artifacts that feed into trend analysis and skill promotion.

---

## File Inventory Expectations

At any given time, the digest directory should contain:

| Path | Expected Count | Tier |
|------|---------------|------|
| `.squad/digests/{date}.md` | 1-30 files (rolling window) | Tier 1 |
| `.squad/digests/{date}-{channel}.md` | 0-4 per day (deleted after QMD) | Tier 1 |
| `.squad/digests/archive/*.qmd.md` | Growing (never deleted) | Tier 2 |
| `.squad/digests/dream/dream-*.md` | Growing (never deleted) | Tier 2 |
| `.squad/digests/triage/*.jsonl` | 1-3 files (quarterly rotation) | Tier 1 |

---

## Disk Usage Estimates

| Content Type | Per Unit | Monthly | Annual |
|-------------|----------|---------|--------|
| Raw daily digest | ~5 KB | ~150 KB | Deleted |
| Per-channel scan | ~2 KB | ~240 KB | Deleted |
| QMD weekly digest | ~3 KB | ~12 KB | ~144 KB |
| Dream report | ~2 KB | ~8 KB | ~96 KB |
| Triage JSONL | ~50 KB/month | ~50 KB | ~600 KB |
| **Total committed (Tier 2+3)** | | **~20 KB** | **~240 KB** |
| **Total gitignored (Tier 1)** | | **~440 KB** | Rotated out |

---

## Implementation as PowerShell

Add rotation logic to the existing `generate-digest.ps1` script:

```powershell
function Invoke-DigestRotation {
    param([string]$DigestDir = '.squad/digests')
    
    $today = Get-Date
    $archiveDir = Join-Path $DigestDir 'archive'
    
    # Delete raw digests older than 30 days (only if QMD exists)
    Get-ChildItem -Path $DigestDir -Filter '????-??-??.md' | Where-Object {
        $fileDate = [DateTime]::ParseExact($_.BaseName, 'yyyy-MM-dd', $null)
        ($today - $fileDate).Days -gt 30
    } | ForEach-Object {
        $weekStart = # ... find covering QMD
        if (Test-Path "$archiveDir/*$weekStart*.qmd.md") {
            Remove-Item $_.FullName
            Write-Information "Rotated: $($_.Name)"
        } else {
            Write-Warning "No QMD coverage for $($_.Name) — skipping deletion"
        }
    }
    
    # Delete per-channel scans older than 7 days
    Get-ChildItem -Path $DigestDir -Filter '????-??-??-*.md' | Where-Object {
        $parts = $_.BaseName -split '-', 4
        $dateStr = "$($parts[0])-$($parts[1])-$($parts[2])"
        $fileDate = [DateTime]::ParseExact($dateStr, 'yyyy-MM-dd', $null)
        ($today - $fileDate).Days -gt 7
    } | ForEach-Object {
        Remove-Item $_.FullName
        Write-Information "Cleaned channel scan: $($_.Name)"
    }
}
```

---

## Integration Points

- **Upstream:** `digest-processor.md` produces the raw daily digests being rotated
- **Upstream:** `qmd-extraction.md` produces the QMD digests that enable raw deletion
- **Policy source:** `.squad/templates/memory-separation.md` defines the three-tier rules
- **Script:** `.squad/scripts/generate-digest.ps1` should call rotation at startup
