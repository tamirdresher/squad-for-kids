# Decision: Repository Organization via Topic-Based Splitting

**Date:** 2026-03-07  
**Decider:** Picard  
**Status:** Executed  
**Issue:** #34

## Context

tamresearch1 repo contained 61+ research files covering 3 distinct topics:
- DK8S platform investigations (architecture, infrastructure, workload migration)
- Squad formation analysis (5 agent investigation reports)
- SquadPlaces API exploration (screenshots, test data, API docs)

All mixed together in root directory alongside core squad infrastructure (.squad/, configs).

## Decision

Split research artifacts into 3 dedicated private repositories:
1. `tamresearch1-dk8s-investigations`
2. `tamresearch1-agent-analysis`
3. `tamresearch1-squadplaces-research`

Preserve core squad infrastructure in tamresearch1.

## Rationale

**Problem:** Growing root directory clutter makes navigation difficult. Three distinct research topics deserve isolation.

**Benefits of Split:**
1. **Topical Isolation:** Each repo focuses on single domain
2. **Access Control:** Private repos protect research/screenshots from public exposure
3. **Discoverability:** Topic-specific repos easier to share with stakeholders
4. **Clean Main Repo:** tamresearch1 becomes squad infrastructure hub, not research archive

**Preserved Infrastructure:**
- `.squad/` directory (agents, decisions, skills, history)
- `squad.config.ts`, package files, node_modules
- `ralph-watch.ps1` monitoring script
- Summary files (EXECUTIVE_SUMMARY.md, etc.)

## Execution Protocol

1. Create private repos with `gh repo create --private`
2. Clone each repo to temp directory
3. Copy relevant files to each repo
4. Add migration headers to markdown/yaml: `<!-- Moved from tamresearch1 on 2026-03-07 -->`
5. Commit with descriptive messages + co-author trailer
6. Push to main branch
7. Verify all pushes succeeded
8. Delete migrated files from tamresearch1
9. Create `.squad/research-repos.md` catalog
10. Commit cleanup to tamresearch1

## Outcome

- **61 files migrated** across 3 repos
- **tamresearch1 cleaned:** Root directory now contains only active files + .squad/ infrastructure
- **Catalog created:** `.squad/research-repos.md` provides navigation to all research repos
- **Issue #34 closed** with completion report

## Key Insight

**Catalog files are not optional.** When splitting repositories, a catalog file in the main repo is the index to the distributed knowledge graph. Without it, knowledge becomes fragmented and unfindable.

## Alternatives Considered

1. **Git submodules:** Too complex for read-only research artifacts
2. **Monorepo with directories:** Doesn't solve access control or navigation
3. **Single research-archive repo:** Loses topical isolation

## Related Decisions

- Continuous learning system design (Issue #6) — skills stay in tamresearch1
- Ralph monitoring setup — monitoring script stays in tamresearch1
