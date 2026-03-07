# Decision: Continuous Learning System for Teams Channel Monitoring

**Date:** 2026-07-04  
**Author:** Picard (Lead)  
**Status:** Proposed  
**Scope:** Team Process, Knowledge Management  
**Issue:** #6

## Decision

Adopt a phased continuous learning system that uses WorkIQ to poll DK8S and ConfigGen Teams channels, generate structured digests, and promote recurring patterns into squad skills.

## Key Points

1. **Four channels to monitor:** DK8S Support (P0), ConfigGen Support (P0), DK8S Platform Leads (P1), BAND Collaboration (P2)
2. **WorkIQ is the data source** — no custom API integrations needed, but access is user-scoped (requires Tamir's channel membership)
3. **Phase 1 (immediate):** Manual scan protocol at session start — zero infrastructure, immediate value
4. **Phase 2 (weeks 2-3):** Standardized prompt templates for reproducible scans
5. **Phase 3 (weeks 4-6):** Pattern extraction pipeline with human-gated skill promotion
6. **Phase 4 (deferred):** GitHub Actions automation — blocked on WorkIQ API access from runners
7. **9 recurring patterns already identified** and promoted to `.squad/skills/` as initial seed

## Rationale

- The squad loses operational context between sessions because Teams channel knowledge isn't persisted
- WorkIQ already provides access to all four target channels
- File-based digests and skills align with existing squad architecture (no new infrastructure)
- Manual-first approach validates the pattern before investing in automation

## Consequences

- ✅ Squad starts each session with fresh operational context (< 7 days stale)
- ✅ Recurring support patterns are pre-loaded, reducing re-discovery time
- ✅ Skill library grows organically from real operational data
- ⚠️ WorkIQ access is user-scoped — breaks if Tamir loses channel access
- ⚠️ Digest privacy must be managed — internal support content in repo files
- ⚠️ Manual scanning adds session startup time (~5 min for 4 channels)

## Artifacts

- `continuous-learning-design.md` — Full design document
- `.squad/skills/dk8s-support-patterns/SKILL.md` — Initial DK8S patterns
- `.squad/skills/configgen-support-patterns/SKILL.md` — Initial ConfigGen patterns
- `.squad/digests/` — Directory for future digest storage
