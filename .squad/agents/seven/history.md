# Seven — History

## Core Context

### Knowledge Management & Research

**Role:** Squad knowledge architect, research specialist, compliance/standards researcher, pattern validator

**Technologies & Domains:** GitHub (skills/agents/plugins), Azure DevOps (repository research), Microsoft/Teams (research via WorkIQ), Azure (compliance, migrations), Kubernetes (DK8S), knowledge management systems

**Recurring Patterns:**
- **Quarterly Knowledge Rotation:** Phase 1 (2026-Q2) completed — rotate Q1 histories to archives, fresh history.md per quarter, gitignore excludes build artifacts (~29.5MB saved) (Decision #16, Issue #321)
- **Cross-Tool Research Methodology:** WorkIQ (M365 search) + ADO + Teams message analysis + GitHub search for context discovery; key pattern for deep investigations
- **Production Pattern Validation:** Research identifies production-proven architectures: MDE team's 6-agent PR review, Azure Skills Plugin standardization, multi-org MCP patterns (Issues #340, #343)
- **Confidence-Level Learning:** Distinguish HIGH/MED/LOW confidence findings; separate facts from hypotheses in research

**Key Architecture Decisions:**
- **Knowledge Base Queryability:** Markdown + GitHub search + ripgrep beats custom tools; git history preserves rotation timeline (Decision #16)
- **Phase 1 Completion:** INDEX.md for navigation, 50KB max history files, quarterly archives prove scalable (Issue #321)
- **DK8S Wizard CodeQL Gap:** Identified compliance requirement (CodeQL.10000 on DK8S wizard) separate from operational failures (1ES migration + MI permission model) — cross-team handoff pattern (Issue #339)
- **Azure Skills Validation:** 21 skills available; squad alignment via role mapping (B'Elanna→deploy/compute, Worf→compliance/rbac) (Issue #343)

**Key Files & Conventions:**
- `.squad/decisions.md` — Knowledge management decision (Decision #16)
- `.squad/research/` — Research reports (azure-skills-plugin-research.md, etc.)
- `.squad/agents/*/history-2026-Q1.md` — Quarterly archives (pattern established)
- `.squad/KNOWLEDGE_MANAGEMENT.md` — Knowledge base documentation

**Research Template:** WorkIQ search → ADO/GitHub validation → Decision record → Team adoption

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

**2026-Q2 Kickoff:**
- Implementing Phase 1 knowledge management (Issue #321)
- Rotating Q1 histories to archives
- Establishing quarterly archival pattern

