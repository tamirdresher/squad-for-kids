# 5-Phase Orchestration Pipeline Formalized

**Date:** 2026-05-30
**Author:** seven
**Status:** Active

## Decision

The squad now has a formal 5-phase orchestration pipeline document at `.squad/process/5-phase-orchestration.md`.

All feature-level tasks labeled `go:yes` must follow this pipeline. Ralph uses it to decompose issues into structured agent handoffs.

## Key Points
- Phase entry is determined by issue labels (`go:needs-research`, `go:yes`, `go:needs-decision`, `go:no`)
- Agent routing in Phase 3: code->data, infra->belanna, security->worf
- Iterative retrieval capped at 3 call-backs during Phase 3
- Phase 5 (DELIVER) is never skippable

## Reference
See `.squad/process/5-phase-orchestration.md` for full details.
