# Decision: Digest Generator Pipeline Architecture

**Date:** 2026-03-07
**Author:** Data (Code Expert)
**Status:** Proposed
**Scope:** Continuous Learning Pipeline
**Issue:** #22

## Decision

Implement the Phase 2 digest generator as a set of markdown prompt templates (not executable scripts) that define a deterministic pipeline. The pipeline follows the OpenCLAW hybrid pattern: structured data processing is fully specified in templates, LLM judgment is invoked only for QMD classification, "new information" assessment, and severity inference.

## Key Choices

### 1. Channel Scan Order
**Chosen:** dk8s-support → incidents → configgen → general
**Rationale:** Ordered by signal density (highest first). Cross-channel deduplication becomes more effective when high-signal channels are scanned first — duplicates in lower-signal channels are caught rather than the reverse.

### 2. Deduplication Strategy
**Chosen:** SHA256 fingerprint of `lowercase(author + date_rounded_to_day + first_50_chars_of_message)`
**Rationale:** Simple, deterministic, and avoids false positives. The 50-char prefix captures enough message context for uniqueness without being sensitive to message edits or thread replies.
**Alternative considered:** Semantic similarity via LLM — rejected as non-deterministic and expensive for high-volume dedup.

### 3. Safety-First Rotation
**Chosen:** Never delete raw digests unless a QMD digest covers their week. Run emergency QMD extraction if coverage is missing.
**Rationale:** Raw data is disposable only after signal extraction. Losing a week of raw data before QMD runs means permanent information loss.

### 4. Incident Tracking via JSONL
**Chosen:** `active-incidents.jsonl` in `.squad/digests/triage/` as the incident state store.
**Rationale:** Line-oriented format enables append-only writes, easy grep, and human readability. JSONL is simpler than a database and works well with git-based workflows (though this file is gitignored as Tier 1).

### 5. Three-Tier Gitignore
**Chosen:** Updated `.gitignore` to implement memory-separation.md rules. Raw daily digests and per-channel scans are gitignored. QMD digests, dream reports, and decisions are committed.
**Rationale:** Prevents PII and noise from entering version control while preserving curated institutional knowledge.

## Consequences

- ✅ Pipeline is fully documented and reproducible
- ✅ Deterministic steps can be automated without LLM (cost-effective)
- ✅ Three-tier memory prevents digest bloat in version control
- ✅ Channel-priority dedup maximizes signal retention
- ⚠️ Templates are documentation, not executable code — requires agent interpretation
- ⚠️ SHA256 dedup may miss semantically identical messages with different wording

## Dependencies

- Requires Phase 1 digest directory structure (present)
- Requires Seven's OpenCLAW templates (PR #57, merged)
- `generate-digest.ps1` exists but does not yet call rotation logic
