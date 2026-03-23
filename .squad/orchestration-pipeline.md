# Squad Orchestration Pipeline

> Formal 5-phase pipeline for feature-level squad tasks. Adopted from the
> everything-claude-code audit (issue #1295). Mandatory for all feature work;
> optional for simple fixes and queries.

---

## When to Use the Full Pipeline

| Task type | Use pipeline? |
|-----------|---------------|
| New feature (any size) | ✅ Yes — always |
| Refactor touching >1 file | ✅ Yes |
| Bug fix with unclear root cause | ✅ Yes |
| Well-defined single-file bug fix | ❌ No — direct to Phase 3 → 5 |
| Question / quick fact lookup | ❌ No — coordinator answers directly |
| Documentation-only change | ❌ No — Seven handles end-to-end |
| Security patch | ⚠️ Yes — Worf runs Phases 1 and 4 |

---

## The 5-Phase Pipeline

```
Phase 1: RESEARCH  → seven / explore agent → research-summary.md
Phase 2: PLAN      → picard agent          → plan.md
Phase 3: IMPLEMENT → data agent            → code changes
Phase 4: REVIEW    → worf agent            → review-comments.md
Phase 5: VERIFY    → tests / build         → done  ──or──  loop back to Phase 3
```

Each phase has **one clear input** and produces **one clear output file**.
Outputs become the inputs for the next phase.

---

## Phase Definitions

### Phase 1 — RESEARCH

| Field | Value |
|-------|-------|
| **Agent** | Seven (Research & Docs) or `explore` sub-agent |
| **Input** | Issue text, linked context, codebase |
| **Output file** | `.squad/research/<issue-number>-research-summary.md` |
| **Goal** | Understand the problem space, existing patterns, constraints, and risks |
| **Done when** | Summary answers: What exists today? What must change? What are the unknowns? |

**Invoke:**
```
spawn: seven
prompt: "Research issue #<N>. Produce .squad/research/<N>-research-summary.md covering:
  current state, proposed change, affected files/systems, risks, open questions."
mode: background
```

---

### Phase 2 — PLAN

| Field | Value |
|-------|-------|
| **Agent** | Picard (Lead) |
| **Input** | `.squad/research/<issue-number>-research-summary.md` |
| **Output file** | `.squad/implementations/<issue-number>-plan.md` |
| **Goal** | Produce a step-by-step implementation plan with acceptance criteria |
| **Done when** | Plan covers: approach, files to change, test strategy, rollback plan, open decisions |

**Invoke:**
```
spawn: picard
prompt: "Read .squad/research/<N>-research-summary.md.
  Produce .squad/implementations/<N>-plan.md:
  - Approach (with rationale)
  - Files to change (with what changes)
  - Test strategy
  - Rollback plan
  - Open decisions (if any)"
mode: background
```

---

### Phase 3 — IMPLEMENT

| Field | Value |
|-------|-------|
| **Agent** | Data (Code Expert) — or B'Elanna for infra changes |
| **Input** | `.squad/implementations/<issue-number>-plan.md` |
| **Output** | Code changes committed to branch |
| **Goal** | Execute the plan; produce working, tested code |
| **Done when** | All planned changes are committed; no build errors |

**Invoke:**
```
spawn: data
prompt: "Implement the plan in .squad/implementations/<N>-plan.md.
  Branch: squad/<N>-<slug>.
  Commit with message referencing #<N>.
  Do not skip steps; if a step is impossible, write a note and continue."
mode: background
```

> **If Phase 5 fails**, re-enter Phase 3 with `.squad/reviews/<issue-number>-review-comments.md`
> as an additional input alongside the original plan.

---

### Phase 4 — REVIEW

| Field | Value |
|-------|-------|
| **Agent** | Worf (Security & Cloud) — or Q for logic/correctness review |
| **Input** | Code diff (branch vs. main) + `.squad/implementations/<issue-number>-plan.md` |
| **Output file** | `.squad/reviews/<issue-number>-review-comments.md` |
| **Goal** | Identify bugs, security issues, missing tests, deviations from plan |
| **Done when** | All findings documented with severity (blocker / warning / suggestion) |

**Invoke:**
```
spawn: worf
prompt: "Review the diff on branch squad/<N>-<slug> against the plan in
  .squad/implementations/<N>-plan.md.
  Produce .squad/reviews/<N>-review-comments.md.
  Each finding must have: severity (blocker/warning/suggestion), file+line, description, fix."
mode: background
```

---

### Phase 5 — VERIFY

| Field | Value |
|-------|-------|
| **Agent** | Coordinator (automated) or @copilot |
| **Input** | Branch with committed changes |
| **Output** | ✅ Done (PR merged) or 🔁 Loop back to Phase 3 |
| **Goal** | Confirm tests pass, build succeeds, review blockers are resolved |
| **Done when** | All Phase 4 blockers resolved, CI green, PR ready for merge |

**Verification steps:**
```
1. Run: npm test / dotnet test / make test (whatever applies to the repo area)
2. Run: the build (npm run build / dotnet build)
3. Check: all Phase 4 "blocker" findings are addressed
4. If any check fails → loop back to Phase 3 with review-comments.md as input
5. If all pass → open PR (or push to existing PR) and mark done
```

**Loop-back rule:** When looping from Phase 5 → Phase 3:
- Pass `.squad/reviews/<N>-review-comments.md` as the primary input
- Data agent addresses **only the blocker findings** unless plan changes are needed
- Worf re-reviews **only the changed files** (not the full diff again)

---

## Output File Naming Convention

All pipeline files live under `.squad/` subdirectories so they persist across sessions
and are accessible to all agents.

| Phase | Output file path |
|-------|-----------------|
| Research | `.squad/research/<issue-number>-research-summary.md` |
| Plan | `.squad/implementations/<issue-number>-plan.md` |
| Review | `.squad/reviews/<issue-number>-review-comments.md` |

**Naming rules:**
- Use the GitHub issue number as the prefix (e.g., `1313-`)
- Use kebab-case for the slug
- Never overwrite a previous file — create a new revision: `<N>-plan-r2.md`

---

## Pipeline Rules

1. **One input → one output file** — each agent receives one artifact and produces one artifact.
2. **Never skip phases** — if Phase 2 (PLAN) feels unnecessary, write a one-paragraph plan anyway.
3. **Store all intermediate outputs as files** — not just in conversation context.
4. **Phase 5 failure loops to Phase 3** — not to Phase 1 or 2, unless the research was fundamentally wrong.
5. **Phase 4 "blocker" findings block merge** — "warning" and "suggestion" findings are logged but do not block.
6. **Log every spawn** — create an entry in `.squad/orchestration-log/` before spawning each agent (see `orchestration-log.md` template).
7. **Picard coordinates** — the Lead ensures phases run in order, resolves conflicts, and decides if a loop is needed.

---

## Pipeline Invocation Shortcuts

The coordinator (Picard) can kick off the full pipeline with:

```
"Run the squad pipeline for issue #<N>"
```

This triggers:
1. Spawn Seven (Phase 1) → wait for research-summary.md
2. Spawn Picard (Phase 2) → wait for plan.md
3. Spawn Data (Phase 3) → wait for commit
4. Spawn Worf (Phase 4) → wait for review-comments.md
5. Run verification (Phase 5) → done or loop

---

## Quick Reference

```
Phase 1  RESEARCH    seven        → .squad/research/<N>-research-summary.md
Phase 2  PLAN        picard       → .squad/implementations/<N>-plan.md
Phase 3  IMPLEMENT   data         → branch commits
Phase 4  REVIEW      worf         → .squad/reviews/<N>-review-comments.md
Phase 5  VERIFY      coordinator  → ✅ PR or 🔁 → Phase 3
```

---

*Adopted from everything-claude-code audit. Issue: #1295. Formalized: #1313.*
