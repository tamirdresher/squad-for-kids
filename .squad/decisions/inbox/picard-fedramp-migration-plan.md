# Decision: FedRAMP Dashboard Migration to Dedicated Repository

**Date:** 2026-03-09  
**Author:** Picard (Lead)  
**Status:** Proposed  
**Scope:** Repository Structure & Migration Strategy  
**Related:** Issue #127, Issue #123, PR #131

## Context

FedRAMP Security Dashboard has evolved from research experiment to production system with 13 merged PRs, ~100 files, 5-phase rollout plan, and production deployments to sovereign clouds. The project lives in tamresearch1 (research repository), creating cognitive dissonance and governance challenges.

**Current State:**
- API (.NET 8 REST) with RBAC (5 roles)
- Functions (Azure Functions data pipeline)
- Dashboard UI (React + TypeScript)
- Infrastructure (Bicep IaC, EV2 deployment)
- Tests (validation scripts + API tests)
- Documentation (12 files, training, security assessments)

**Problem:**
- Production-grade work in research-focused repository
- No clear ownership or governance model
- Squad agent allocation unclear (all 5 agents or subset?)
- CI/CD pipelines mixed with research experiments

## Decision

**Migrate FedRAMP Dashboard to dedicated repository ``fedramp-dashboard`` with:**

1. **Full git history preservation** using git filter-repo (13 PRs, ~80 commits)
2. **Progressive 6-week migration** (setup → code → infra → CI/CD → prod → cleanup)
3. **Zero-downtime deployment** via blue-green deployment slots
4. **Squad integration portability** (Ralph Watch, agent charters, decisions log)
5. **Clear ownership model** (Data = code, B'Elanna = infra, Worf = security, Seven = docs)

## Rationale

**1. Production System Recognition:**
- Signal: 13 PRs, 5-phase rollout, sovereign cloud configs, production alerting, RBAC
- Repository name "tamresearch1" signals research intent, conflicts with production reality
- Dedicated repo enables proper governance, release management, and access controls

**2. History Preservation Value:**
- Git blame helps debug production issues
- Commit messages link to PRs and issues (context for future maintainers)
- Authorship attribution important for 13 PRs across multiple contributors

**3. Risk Mitigation:**
- Blue-green deployment slots eliminate downtime risk
- Progressive validation (DEV → STG → PROD) catches issues before production
- Go/no-go decision points prevent "point of no return" mistakes
- Tested rollback procedures documented for each phase

**4. Squad Integration:**
- Squad infrastructure (.squad/, ralph-watch.ps1, squad.config.ts) designed for portability
- CODEOWNERS enables agent-based code ownership
- Ralph Watch can monitor multiple repos (extensibility for future projects)

## Implementation

**6-Week Timeline:**
- **Week 1:** Repository setup (access controls, squad integration, CI/CD scaffolding)
- **Week 2:** Code migration (git filter-repo)
- **Week 3:** Infrastructure validation (DEV deployment)
- **Week 4:** CI/CD migration (Azure DevOps + GitHub Actions)
- **Week 5:** Production switchover (zero downtime)
- **Week 6:** Cleanup (archive tamresearch1 FedRAMP artifacts)

**Migration Approach:**
```bash
# Git filter-repo to preserve history
git filter-repo --path api/FedRampDashboard.Api --path functions --path dashboard-ui \
  --path infrastructure --path tests/fedramp-validation [...]

# Reorganize structure
git mv api/FedRampDashboard.Api src/api
git mv functions src/functions
git mv dashboard-ui src/dashboard-ui
[...]

# Push to new repo
git remote add fedramp-dashboard https://github.com/tamirdresher_microsoft/fedramp-dashboard.git
git push fedramp-dashboard fedramp-migration:main
```

**Ownership Model:**
| Component | Primary | Backup |
|-----------|---------|--------|
| API & Functions | Data | Picard |
| Infrastructure | B'Elanna | Picard |
| Security & Compliance | Worf | Seven |
| Dashboard UI | Data | Seven |
| Documentation | Seven | Picard |
| Orchestration | Scribe | Picard |

## Consequences

**Positive:**
- ✅ Clear repository purpose (production compliance monitoring)
- ✅ Proper governance and access controls
- ✅ Independent release cadence
- ✅ tamresearch1 returns to pure research focus
- ✅ Squad integration portable to other projects
- ✅ Production system has production-grade home

**Negative:**
- ⚠️ 6-week migration effort (~20-30 person-days)
- ⚠️ Split attention during transition (maintain both repos)
- ⚠️ Documentation links require updating (automated link checker helps)
- ⚠️ Team must learn new repo structure

**Risks & Mitigations:**
1. **Deployment disruption** → Blue-green slots, low-traffic window, tested rollback
2. **Git history loss** → Test migration on throwaway repo, backup tamresearch1
3. **Broken cross-references** → Automated link checker, search for "tamresearch1"
4. **Squad integration failure** → Test Ralph in new repo before migration
5. **CI/CD gaps** → Copy pipelines (not rebuild), test in DEV first

## Open Questions (for Tamir)

1. **Repository name:** Confirm `fedramp-dashboard`? Alternatives: `dk8s-fedramp-dashboard`, `compliance-dashboard`
2. **Sovereign cloud scope:** Which clouds in Phase 1? (Azure Gov, Azure Gov Secret, Azure China?)
3. **Squad agent allocation:** All 5 agents move, or subset?
4. **CI/CD platform:** Consolidate to GitHub Actions, or keep both (ADO + GHA)?
5. **License:** Confirm MIT License?

## Related Decisions

- **Decision 1:** Gap Analysis When Repository Access Blocked (cross-repo analysis pattern)
- **Issue #123:** FedRAMP scope question (origin of migration decision)
- **Issue #127:** Migration planning task (this deliverable)

## Alternatives Considered

**Alternative 1: Keep in tamresearch1**
- ❌ Cognitive dissonance (research repo with production system)
- ❌ No clear governance model
- ❌ Mixed CI/CD pipelines (research + production)
- ❌ Access control complexity

**Alternative 2: Fresh start without history**
- ✅ Simpler migration (single commit)
- ❌ Lose git blame (debugging harder)
- ❌ Lose commit context (PR references, issue links)
- ❌ Lose authorship attribution (13 PRs across multiple contributors)

**Alternative 3: Monorepo with workspaces**
- ✅ Single repository (familiarity)
- ❌ Doesn't solve governance problem
- ❌ Release cadence still coupled
- ❌ Access controls still complex

**Recommendation:** Proceed with dedicated repo + history preservation (proposed decision)

## Success Criteria

**Week 1 (Setup):**
- [ ] Repository created and accessible
- [ ] 5 agents have write access
- [ ] Squad integration tested (1 issue triaged)
- [ ] CI/CD scaffolding in place

**Week 3 (Migration):**
- [ ] All code migrated with history
- [ ] DEV environment deployed from new repo
- [ ] All tests passing (unit + integration)
- [ ] Zero regressions detected

**Week 5 (Production):**
- [ ] PROD deployed from new repo
- [ ] Zero customer-impacting incidents
- [ ] Monitoring and alerting operational
- [ ] Team trained on new structure

**Week 6 (Cleanup):**
- [ ] tamresearch1 FedRAMP artifacts archived
- [ ] Old pipelines disabled
- [ ] All documentation updated
- [ ] Issue #127 closed

## References

- **Migration Plan:** `docs/fedramp-migration-plan.md` (PR #131)
- **Issue #127:** https://github.com/tamirdresher_microsoft/tamresearch1/issues/127
- **Issue #123:** https://github.com/tamirdresher_microsoft/tamresearch1/issues/123
- **Git Filter-Repo:** https://github.com/newren/git-filter-repo

---

**Next Steps:**
1. Tamir reviews migration plan (PR #131)
2. Tamir answers open questions
3. Picard creates new repository upon approval
4. Team begins Week 1 (Repository Setup)
