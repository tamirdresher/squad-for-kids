# Squad Decisions Archive — Index

This directory contains archived decisions (resolved, superseded, or historical reference).

## Organization by Quarter

```
archive/
├── 2026-Q1-decisions.md  ← Decisions resolved Q1 2026
├── 2026-Q2-decisions.md  ← Decisions resolved Q2 2026
└── 2026-Q3-decisions.md  ← Decisions resolved Q3 2026 (future)
```

## Why Archive?

- **Active decisions** live in `.squad/decisions.md` (~800 KB and growing)
- **Resolved decisions** moved to archive to keep decisions.md focused
- **Full history** preserved for reference and learning

## What Gets Archived?

- Decisions fully implemented and stable
- Decisions superseded by newer decisions
- Historical decisions with lasting value but no longer active

## How to Search Archives

**Find a specific archived decision:**
```bash
rg "Decision: Knowledge Management" archive/
rg "Issue #321" archive/
```

**Find all decisions about a topic (active + archived):**
```bash
rg "memory\|storage\|indexing" .squad/decisions* --type markdown
```

**Git history of a decision:**
```bash
git log --all -- archive/2026-Q1-decisions.md
```

## Size Tracking

**Archive growth (expected):**
- Q1 2026: ~50-75 KB of decisions archived
- Q2 2026: +50-75 KB additional
- Q3 2026: +50-75 KB additional

If archive totals > 1 MB, consider splitting by team function (e.g., `archive-infrastructure/`, `archive-research/`).

---

**Maintained by:** Seven (Research & Docs)  
**Last Updated:** 2026-Q2 (Phase 1)
