# Decision Proposal: Adopt OpenCLAW Production Patterns for Continuous Learning System

**Date:** 2026-03-09  
**Author:** Seven (Research & Docs)  
**Status:** Proposed  
**Scope:** Continuous Learning System + Squad Operations  
**Related:** PR #10, Issue #13, Issue #6, continuous-learning-design.md

## Context

The OpenCLAW article documents production patterns for running AI agents at scale, including memory architecture, multi-agent orchestration, and a DevBot case study. Several patterns directly improve our continuous learning system design and squad operations.

## Proposed Changes

### A. Add QMD Extraction Framework to Digest Templates (Phase 1)

Add a 5-category extraction taxonomy to the digest template:
- **Decisions made** — architectural choices, governance changes, policy updates
- **Commitments created** — deadlines, ownership assignments, delivery promises
- **Pattern changes** — frequency shifts, new failure modes, resolution drift
- **Blockers + resolutions** — blocked items, what unblocked them, timeline
- **Drop** — routine operations, simple Q&A, repeated status updates

**Impact:** Immediately improves digest signal quality without infrastructure changes.

### B. Add Dream Routine Cross-Digest Analysis (New Phase 2.5)

Insert a "Dream Routine" between Phase 2 and Phase 3 of the continuous learning design:
- At session start, cross-reference last N digests
- Detect trending topics (frequency increase/decrease across digests)
- Flag items meeting skill promotion criteria (3+ digests, 2+ weeks)
- Surface resolved blockers and stalled items

**Impact:** Bridges the gap between individual digests and skill accumulation. Makes pattern detection continuous rather than manual.

### C. Redesign Channel Scanner as Triage Sub-Agent (Phase 2 Enhancement)

Transform the Channel Scanner from "query and store" to "query, classify, prioritize, escalate":
- **Classification:** incident / decision / question / coordination
- **Priority:** P0 (production outage) → P3 (cleanup)
- **Escalation:** P0 items trigger immediate squad action
- **Audit:** Log all triage decisions for pattern analysis

**Impact:** Turns channel monitoring from passive note-taking into active intelligence gathering.

### D. Define Agent Authority Levels (Squad-Wide)

Adopt DevBot's authority level model:
- **Level 1 — Research:** Gather information, human decides
- **Level 2 — Propose & Execute:** Draft action, execute after approval
- **Level 3 — Full Autonomy:** Act independently, escalate exceptions

**Impact:** Clarifies when agents can act autonomously vs. defer to Tamir.

## Consequences

- ✅ Digest quality immediately improves with QMD framework
- ✅ Cross-digest analysis detects patterns invisible in individual snapshots
- ✅ Triage model transforms scanning from passive to active intelligence
- ✅ Authority levels reduce ambiguity in agent decision-making
- ⚠️ Dream routine adds ~5 min to session start (worthwhile for context)
- ⚠️ Authority level definitions require team discussion to calibrate per agent

## Source

[OpenCLAW in the Real World](https://trilogyai.substack.com/p/openclaw-in-the-real-world?r=18detb) — Trilogy AI Substack
