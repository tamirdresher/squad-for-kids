# Decision: Upstream Inheritance Strategy from bradygaster/squad

**Date**: 2026-03-08  
**Decider**: Picard (Lead, Architecture)  
**Context**: Issue #182 — Upstream Inheritance Implementation  
**Status**: Approved (implementation in progress)

## Problem Statement

Our repository (tamresearch1) is a fork/derivative of bradygaster/squad, but we lack a formal upstream tracking and inheritance strategy. Research from issue #178 revealed that upstream has evolved with:
- New CLI commands (`doctor`, `upstream`, `streams`, `plugin`, `export/import`, `aspire`)
- Improved templates (`.squad-templates/` directory with scaffolding)
- SDK architecture enhancements (casting engine, adapter system, event bus)
- Mature CI/CD workflows (11+ GitHub Actions)
- Version releases up to v0.8.25 (we're at v0.8.18, 7 patches behind)

Without upstream tracking, we miss:
1. Community improvements and bug fixes
2. New feature patterns and best practices
3. Template updates for agent/skill scaffolding
4. Documentation improvements
5. Testing and release automation patterns

## Decision

**Adopt selective upstream inheritance strategy:**

1. **Configure upstream remote**: Track `https://github.com/bradygaster/squad.git` as upstream
2. **Inheritance approach**: **Selective cherry-picking**, NOT wholesale merge
3. **Review cadence**: Monthly upstream review + automated weekly checks
4. **Documentation**: Maintain `docs/UPSTREAM_INHERITANCE.md` as canonical guide

## Rationale

### Why Selective (Not Full Merge)?

**Our Unique Implementations:**
- Azure DevOps integration (`.azuredevops/`, workflows)
- FedRAMP validation workflows
- Drift detection pipeline
- Custom agent themes (Picard/Data/Geordi vs upstream's Apollo 13)
- Enterprise-specific workflows (daily digest, issue notifications, main-guard)

**Upstream's Value:**
- General-purpose patterns applicable to any project
- Community-tested features and bug fixes
- Template improvements for agent/skill documentation
- CLI tooling enhancements
- SDK architecture patterns

**Conclusion**: Full merge would conflict with our custom implementations. Cherry-picking lets us:
- Adopt generic improvements
- Maintain enterprise-specific features
- Learn from their architecture without coupling
- Contribute back generic fixes (bidirectional benefit)

### Why Monthly + Automated?

- **Monthly review**: Aligns with sprint planning, prevents drift accumulation
- **Automated weekly checks**: Early detection of breaking changes or high-value features
- **Low overhead**: GitHub Action creates issue if new commits detected, team decides priority

## Consequences

### Positive

1. **Continuous improvement**: Benefit from community contributions without full coupling
2. **Version visibility**: Track lag (currently 7 patches behind) → prioritize updates
3. **Bidirectional value**: We can contribute back generic features (Azure DevOps adapter, FedRAMP patterns)
4. **Risk reduction**: Selective inheritance = lower breaking change risk vs wholesale merge
5. **Learning**: Study upstream architecture for patterns (casting engine, SDK design)

### Negative

1. **Manual overhead**: Cherry-picking requires review and testing (vs automatic merge)
2. **Conflict resolution**: Manual merge conflicts when cherry-picking diverged files
3. **Drift risk**: If we skip reviews, lag accumulates (mitigation: automated checks)
4. **Decision burden**: Team must decide what to inherit vs ignore (mitigation: documented priorities)

### Neutral

1. **CLI dependency**: We consume `@bradygaster/squad-cli` as devDependency → update when needed
2. **Monorepo divergence**: Upstream uses packages/ structure, we consume published packages (no local fork)

## Implementation

### Completed (Issue #182)

- ✅ Add upstream remote: `git remote add upstream https://github.com/bradygaster/squad.git`
- ✅ Fetch upstream: `git fetch upstream` (retrieved v0.8.25)
- ✅ Analyze differences: Compared file structures, identified high-value targets
- ✅ Document strategy: Created `docs/UPSTREAM_INHERITANCE.md` (11KB guide)
- ✅ Set baseline: Documented current state (v0.8.18 CLI, v0.8.25 upstream)
- ✅ Update project board: Set #182 to "In Progress"
- ✅ Commit: `97586e3` — docs: establish upstream inheritance workflow from bradygaster/squad

### Next Steps

1. **Update CLI**: `npm install --save-dev @bradygaster/squad-cli@^0.8.25`
2. **First inheritance**: Cherry-pick `.squad-templates/skill.md` (better structure)
3. **Automated check**: Create `.github/workflows/upstream-sync-check.yml` (weekly cron)
4. **Squad ceremony**: Add "Upstream Review" to monthly rituals in `.squad/ceremonies.md`
5. **Skill extraction**: Document inheritance pattern in `.squad/skills/upstream-management/SKILL.md`

## High-Value Inheritance Targets

### Immediate (Next Sprint)
1. `.squad-templates/skill.md` — Structured skill template
2. `.squad-templates/workflows/squad-ci.yml` — Improved CI
3. `.github/workflows/squad-heartbeat.yml` — Health monitoring

### Medium-Term (Q1 2026)
4. CLI update: v0.8.18 → v0.8.25 (7 patches)
5. `packages/squad-cli/src/cli/commands/doctor.ts` — Health diagnostics
6. `.squad-templates/casting-policy.json` — Dynamic agent assignment patterns

### Evaluate (As Needed)
7. `.changeset/config.json` — If we publish our fork
8. SDK patterns: casting engine, adapter system, event bus
9. Test fixtures and samples for reference

## Alternatives Considered

### Alternative 1: Full Merge from Upstream
- **Pros**: Automatic updates, no manual cherry-picking
- **Cons**: Conflicts with our Azure DevOps/FedRAMP/custom agents, high breaking change risk
- **Rejected**: Too disruptive for our custom implementations

### Alternative 2: No Upstream Tracking
- **Pros**: Zero overhead, full independence
- **Cons**: Miss community improvements, reinvent solved problems, accumulate technical debt
- **Rejected**: Ignores valuable community work

### Alternative 3: Fork Completely, Diverge Permanently
- **Pros**: Full control, no upstream dependency
- **Cons**: Lose access to upstream improvements, duplicate maintenance burden
- **Rejected**: Wasteful when upstream has generally useful patterns

## Review Criteria

**Success Metrics:**
- [ ] Upstream remote configured and fetchable
- [ ] Documentation in `docs/UPSTREAM_INHERITANCE.md` complete
- [ ] First inheritance (skill.md) cherry-picked successfully
- [ ] Automated sync check workflow deployed
- [ ] Monthly upstream review added to ceremonies
- [ ] CLI updated to v0.8.25 within 1 sprint

**Review Date**: 2026-04-08 (1 month)  
**Review Owner**: Picard  
**Review Questions**:
1. Did automated checks detect new upstream commits?
2. How many cherry-picks succeeded vs conflicted?
3. Did inherited patterns improve our implementations?
4. Are we contributing fixes back to upstream?

## References

- **Issue**: #182 — Upstream Inheritance Implementation
- **Documentation**: `docs/UPSTREAM_INHERITANCE.md`
- **Upstream**: https://github.com/bradygaster/squad (v0.8.25)
- **Our CLI Version**: `@bradygaster/squad-cli@^0.8.18`
- **Commit**: `97586e3` — docs: establish upstream inheritance workflow
- **Branch**: `squad/182-upstream-inheritance`

---

**Signature**: Picard (Lead, Architecture)  
**Approvals**: Self-approved (architectural decision within domain)  
**Filed**: `.squad/decisions/inbox/picard-upstream-inheritance.md`
