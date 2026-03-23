# Decision: Keep `.squad/` Tracked Through Squad v1.0 Transition

**Date:** 2026-03-23  
**Author:** Picard  
**Status:** Active  
**Issue:** tamirdresher_microsoft/tamresearch1#1351  
**Assessment:** `.squad/UPSTREAM-MIGRATION-ASSESSMENT.md`

---

## Decision

**Keep `.squad/` tracked in version control (Option A — opt-in behavior)** as upstream Squad moves to treat `.squad/` as build output in v1.0.

This is an explicit opt-in. We are not following upstream's default (untrack `.squad/`). We are knowingly diverging, with documented rationale.

---

## Rationale

1. **44 custom skills** (`/skills/*`) contain irreplaceable domain-specific implementations. `squad build` cannot regenerate these from `squad.config.ts` — they encode years of institutional decisions.

2. **Agent histories** (`/agents/*/history.md`) are institutional memory, not build output. Losing them means losing context on how and why agents evolved.

3. **Upstream PRD #498 explicitly supports this** as an opt-in path. We are not fighting the framework — we are using the escape hatch it provides.

4. **We are already in SDK mode** — `squad.config.ts` is fully configured. The build/runtime split already exists; we just choose to track both sides.

5. **Risk of not acting > risk of staying**: If we silently follow upstream's `.gitignore` changes in v0.10.0, we lose 860 tracked files with no migration window.

---

## What Upstream Is Doing

- **Discussion #499**: [bradygaster/squad#499](https://github.com/bradygaster/squad/discussions/499) — announces `.squad/` removal plan
- **PRD #498**: [bradygaster/squad#498](https://github.com/bradygaster/squad/issues/498) — formal PRD with migration commands
- **Timeline**: v0.9.0 (announced ~2026-03-22) → v0.10.0 (`.squad/` untracked upstream)

---

## Action Items

### Phase 1 — Immediate (this PR, issue #1351)
- [x] Delete root-level `commit-msg-*.txt` temp files (33 files removed)
- [x] Update `upstream-state.json` to reflect discussion #499 and issue #498
- [x] Create this decision record

### Phase 2 — When v0.9.0 Ships
- [ ] Run `squad export` once tooling is available — create snapshot backup
- [ ] Audit `.gitignore` — ensure `cross-machine/`, `monitoring/`, and other runtime-only dirs are properly tiered
- [ ] Verify `squad.config.ts` routing rules produce correct framework scaffolding on `squad build`

### Phase 3 — When v0.10.0 Ships
- [ ] Review upstream `.gitignore` changes before pulling
- [ ] Explicitly override any entries that would untrack our tracked content
- [ ] Document the override in `CONTRIBUTING.md` so new contributors understand why

---

## Not Doing

- NOT untracking `.squad/` from version control
- NOT migrating to `.squad/`-as-build-output at this time
- NOT deleting agent histories or custom skills

---

## Review Date

Revisit when `squad export` tooling is available (v0.9.0), and again when v0.10.0 ships with the upstream `.gitignore` change.
