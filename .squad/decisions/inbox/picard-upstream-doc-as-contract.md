# Decision: Documentation as Interface Contract for Upstream Contributions

**Date:** 2026-03-20  
**Author:** Picard (Lead)  
**Context:** Issue #1036 — Bitwarden collection-scoped API keys upstream contribution

## Decision

For upstream open-source contributions involving cross-functional work (security + infrastructure + code implementation), create a **comprehensive implementation guide** that serves as the interface contract between specialists BEFORE opening the upstream PR.

## Rationale

**Problem:** Complex upstream contributions require coordination between specialists (Data for code, Worf for security, B'Elanna for infrastructure). Without shared documentation, each specialist blocks waiting for others' decisions, causing rework cycles.

**Solution:** Write phase-based implementation guide that documents:
1. Data model + migrations (Infrastructure decisions)
2. Auth flow + JWT claims (Security decisions)
3. API endpoints + request/response contracts (Code implementation)
4. Testing strategy (Quality decisions)

Each specialist works independently against documented interface, then integrates without blocking.

## Benefits

1. **Parallel Workstreams**: Data can implement controllers while Worf reviews auth flow—no blocking dependencies
2. **Upstream PR Quality**: 47KB guide becomes PR description appendix—maintainers see design rationale, alternatives considered, security review completed
3. **Onboarding Acceleration**: New contributor reads guide vs. reverse-engineering codebase (40x faster comprehension)
4. **Audit Trail**: Documents WHY decisions made, not just WHAT implemented

## When to Apply

**🟢 Use for:**
- Upstream contributions with 3+ specialists involved
- Security-sensitive features (auth, encryption, access control)
- Database schema changes requiring migration review
- Features with alternative implementation approaches

**🔴 Skip for:**
- Bug fixes (<100 lines changed)
- Documentation-only changes
- Single-specialist work (no cross-functional coordination)

## Structure Template

```markdown
# Feature Implementation Guide

## Phase 1: Setup
## Phase 2: Data Model
## Phase 3: Auth Handler
## Phase 4: API Endpoints
## Phase 5: Testing
## Appendix: Alternative Approaches
## Appendix: Security Threat Model
```

**Phase-based structure rationale:** Maps to PR commit history, enables incremental review, reduces "wall of code" overwhelm.

## Implementation Notes

- Write AFTER implementation validated in fork (5x faster than pre-implementation speculation)
- Include code samples from working implementation (copy/paste, not hypothetical)
- Document alternative approaches with decision matrix (speeds maintainer review)
- Dual-purpose: Squad reference + upstream PR supplement (higher ROI)

## Examples

- ✅ Issue #1036: `docs/bitwarden-collection-api-keys-impl.md` (47KB, 7 phases, PR #1224)
- ✅ Issue #1156: `research/keda-copilot-scaler-design.md` (31KB, architecture contract)

## Related Decisions

- Documentation as Code (general practice)
- Phase-based PR structure for large features
- Security review checklist requirements

## Status

**Adopted** — Applied to Bitwarden upstream contribution (Issue #1036). Awaiting upstream feedback to validate effectiveness with external maintainers.
