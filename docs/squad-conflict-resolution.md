# Squad Conflict Resolution Design for Multi-Engineer Repos

**Issue:** [#520](https://github.com/tamirdresher_microsoft/tamresearch1/issues/520)  
**Status:** Proposed  
**Date:** 2026-03-27  
**Author:** Picard (Lead)

---

## 1. Problem Statement

When multiple engineers use Squad agents concurrently in the same repository — especially
Microsoft-internal repos that enforce PR + approval workflows — the following failure modes
emerge:

1. **Add/add conflicts on `.squad/` files.** Every Squad agent branch touches shared config
   files (`decisions.md`, `agent-dag.json`, `casting-registry.json`, etc.). Two branches
   that each append a line to `decisions.md` produce an unresolvable add/add conflict when
   both target `main`.

2. **Stale PR pile-up.** Each engineer's Squad run opens a PR. PRs that land second (or
   later) are immediately stale with respect to the `.squad/` changes already merged by the
   earlier PR. CI re-runs and re-approvals are required even when no real code changed.

3. **Non-deterministic agent output.** Squad reads its own config to inform decisions. If
   two agents race on reading `decisions.md` they may make divergent decisions that require
   manual reconciliation later.

4. **Approval-flow bottleneck.** In repos with mandatory reviewers the squad-config churn
   blocks "real" PRs waiting for reviewer bandwidth, increasing cycle time.

---

## 2. Root Cause Analysis

### 2.1 Shared mutable state in the working tree

`.squad/` lives in the same git tree as product code. Every agent commit that touches any
Squad bookkeeping file (decisions, logs, cast state, etc.) changes the same paths that
every other engineer's agent also modifies.

```
engineer-A branch  →  .squad/decisions.md  (appended decision A)
engineer-B branch  →  .squad/decisions.md  (appended decision B)
                                ↑
                        merge conflict
```

### 2.2 Append-only files without structural ownership

Most `.squad/` files are append-only markdown or JSON arrays. Git's three-way merge cannot
resolve two independent appends to the same section because it has no semantic understanding
of "add a new entry" vs "replace an entry."

### 2.3 No per-engineer namespace

Squad writes to global paths with no per-engineer or per-session sub-directory structure.
Any two agents running in the same repo write to the same file set.

### 2.4 PR approval flow amplifies the problem

Because every PR (including squad-config-only PRs) requires approval, reviewer fatigue sets
in quickly. Reviewers either rubber-stamp squad noise or start declining, both of which
degrade the process.

---

## 3. Solution Options

### Option A — Dedicated `squad-config` Branch

Keep a long-lived `squad-config` branch that holds all `.squad/` state. Agent branches are
cut from `squad-config` (not `main`), and merges of squad-config changes go to
`squad-config` first, then a single periodic squash-merge brings them to `main`.

**Pros:**
- No change to how product code PRs work.
- Single integration point isolates squad churn.

**Cons:**
- Two-branch topology is unfamiliar; engineers must know to sync from `squad-config`.
- Periodic squash-merge still needs approval; just defers the bottleneck.
- `squad-config` can diverge significantly from `main` if the squad touches product files.

---

### Option B — Per-Engineer Namespace Isolation

Each engineer's Squad agent writes to `.squad/engineers/<alias>/` instead of global paths.
A reconciliation agent (e.g., Scribe) runs on a schedule to merge namespaced writes into the
canonical global files.

**Pros:**
- Zero conflicts: different engineers write to disjoint paths.
- No process change for product-code PRs.
- Easy to audit which engineer's agent made which decision.

**Cons:**
- Requires Squad agents to be namespace-aware (code change).
- Reconciliation adds latency before a decision is visible globally.
- Duplicate state during reconciliation window.

---

### Option C — Lock Files (Optimistic Concurrency)

Before writing `.squad/` files, an agent acquires a lightweight lock (e.g., creates
`.squad/locks/<file>.lock` with a unique token). If the lock already exists the agent waits
or aborts and retries.

**Pros:**
- Simple to implement with existing git primitives.

**Cons:**
- Lock files themselves can conflict if two branches add the same lock.
- Does not work well with PRs because a lock acquired in a branch isn't visible to other
  branches until merged.
- Abandoned locks cause permanent blocking without a TTL / cleanup job.

---

### Option D — Squad Overlay Pattern (Recommended) ✅

Separate `.squad/` state into two tiers:

| Tier | Path | Write frequency | PR required? |
|------|------|----------------|--------------|
| **Config** (slow-moving) | `.squad/config/` | Rare | Yes — policy, charter, roster |
| **Runtime state** (fast-moving) | `.squad/state/` | Every run | No — auto-merge via bot |

Agent branches only ever modify files under `.squad/state/`. A lightweight GitHub Actions
bot auto-merges `state/` changes without human approval (because state files are excluded
from required-review rules via `CODEOWNERS`). Config changes still go through the normal
PR + approval flow.

Within `state/`, each engineer's agent writes to a per-engineer sub-directory:

```
.squad/state/<alias>/<session-id>/decisions.json
.squad/state/<alias>/<session-id>/agent-dag.json
.squad/state/<alias>/<session-id>/log.md
```

A Scribe agent (already part of the Squad cast) runs at the end of each session to:
1. Merge the per-session state into the canonical `.squad/decisions.md` and
   `.squad/history.md` via a rebase-friendly append operation.
2. Clean up the session sub-directory.
3. Open a single "state sync" PR that the bot can auto-merge.

```
engineer-A session  →  .squad/state/alice/sess-abc/decisions.json   (no conflict)
engineer-B session  →  .squad/state/bob/sess-xyz/decisions.json     (no conflict)
                                         ↑
                               Scribe reconciles → .squad/decisions.md
```

---

## 4. Recommended Approach: Squad Overlay Pattern

### 4.1 Rationale

- **No conflicts by construction.** Per-engineer/per-session paths are disjoint.
- **Preserves existing product-code PR flow.** Reviewers see only meaningful changes.
- **Leverages existing Scribe agent.** Minimal new code required.
- **Works with MS repo mandatory approvals.** `CODEOWNERS` exemption for `state/` is a
  standard pattern already used by many Microsoft repos for generated files.
- **Incremental migration.** Existing global files remain; new sessions write to the
  namespaced layout. Scribe reconciles both.

### 4.2 `CODEOWNERS` Configuration

```text
# .github/CODEOWNERS

# Product code — require two reviewers
/src/           @<team>
/infrastructure/ @<team>

# Squad config — require one reviewer
/.squad/config/ @<squad-admin>

# Squad runtime state — auto-merge, no human reviewer required
/.squad/state/  @<bot-account>
```

With this setup, PRs that touch only `.squad/state/**` are approved automatically by the
bot account, eliminating the reviewer bottleneck for run-to-run agent state.

### 4.3 Auto-Merge GitHub Actions Bot

```yaml
# .github/workflows/squad-state-automerge.yml
name: Squad state auto-merge
on:
  pull_request:
    paths:
      - '.squad/state/**'
jobs:
  auto-merge:
    if: >
      github.event.pull_request.user.login == 'github-actions[bot]' ||
      startsWith(github.head_ref, 'squad/')
    runs-on: ubuntu-latest
    steps:
      - name: Verify only state/ changed
        uses: actions/github-script@v7
        with:
          script: |
            const files = await github.rest.pulls.listFiles({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.payload.pull_request.number
            });
            const nonState = files.data.filter(f => !f.filename.startsWith('.squad/state/'));
            if (nonState.length > 0) core.setFailed('PR touches files outside .squad/state/');
      - name: Auto-merge
        run: gh pr merge --auto --squash "${{ github.event.pull_request.number }}"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 4.4 Directory Layout After Migration

```
.squad/
├── config/                  # slow-moving; PR + human approval
│   ├── charter.md
│   ├── roster.md
│   ├── routing.md
│   └── casting-policy.json
├── state/                   # fast-moving; auto-merge via bot
│   ├── alice/
│   │   └── sess-20260327-abc/
│   │       ├── decisions.json
│   │       └── log.md
│   └── bob/
│       └── sess-20260327-xyz/
│           ├── decisions.json
│           └── log.md
├── decisions.md             # canonical; written by Scribe reconciliation
├── history.md               # canonical; written by Scribe reconciliation
└── …                        # existing files remain during migration
```

### 4.5 Scribe Reconciliation Protocol

At the end of every Squad session Scribe performs:

1. **Collect.** Find all unreconciled session directories under `.squad/state/<alias>/`.
2. **Parse.** Load `decisions.json` from each session directory.
3. **Append.** Append new decisions to `.squad/decisions.md` using a date-stamped, signed
   block to make authorship clear and future merges non-conflicting.
4. **Commit.** Commit directly to the session's working branch (no extra PR).
5. **Archive.** Move processed session directories to `.squad/state/_archive/`.

```json
// .squad/state/alice/sess-20260327-abc/decisions.json  (example schema)
{
  "session_id": "sess-20260327-abc",
  "engineer": "alice",
  "agent": "picard",
  "timestamp": "2026-03-27T14:30:00Z",
  "decisions": [
    {
      "id": "dec-001",
      "summary": "Adopted overlay pattern for conflict resolution",
      "detail": "…"
    }
  ]
}
```

### 4.6 Per-Engineer Branch Naming Convention

Enforce that every Squad branch follows `squad/<issue>-<slug>-<ALIAS>`. This ensures:

- Branch names are globally unique (alias suffix).
- The auto-merge bot can identify Squad PRs reliably (`startsWith(head_ref, 'squad/')`).
- Stale PRs are easy to identify and clean up.

---

## 5. Handling Mandatory PR Approval in MS Repos

### 5.1 Branch Protection Bypass for State Files

In Microsoft ADO/GitHub repos, branch protection can be scoped to path patterns via
`CODEOWNERS`. Request the repo admin to:

```
1. Add a bot service account (e.g., `squad-bot@microsoft.com`) as owner of `.squad/state/`.
2. Enable "Allow auto-merge" on the repo.
3. Enable "Dismiss stale reviews" only for non-state paths.
```

If the repo policy does not permit file-level bypass, use **Option B** (namespace isolation)
as a fallback — namespaced state files still avoid conflicts even without auto-merge, they
just require a single human approval per "state sync" PR rather than per-session.

### 5.2 Batched State Sync PRs

Instead of one PR per engineer per session, Scribe aggregates all pending session states
into a single "Squad state sync" PR on a configurable cadence (e.g., end of business day).
This reduces PR noise from N PRs/day to 1 PR/day regardless of team size.

```
Squad sessions throughout the day
         ↓
.squad/state/<alias>/<session>/  (auto-committed to squad branch, no PR yet)
         ↓
Daily 17:00 UTC — Scribe opens "Squad state sync #<date>" PR
         ↓
Single approval → merge → clean up session dirs
```

### 5.3 Emergency Override

For blocking work, individual agents can request a "squad-config emergency" label on their
PR. The squad admin reviews and merges immediately. This bypasses the batching but retains
the human checkpoint.

---

## 6. Migration Path

### Phase 1 — Namespace new sessions (Week 1)

- Update `squad.config.ts` to write session state to `.squad/state/<alias>/<session-id>/`.
- Add `CODEOWNERS` entry for `.squad/state/`.
- Deploy auto-merge workflow.
- **No existing files touched.** Old global files remain canonical.

### Phase 2 — Scribe reconciliation (Week 2)

- Teach Scribe to reconcile `state/<alias>/` directories into global `decisions.md`.
- Validate on three consecutive team sessions with no conflicts.

### Phase 3 — Migrate slow-moving config (Week 3)

- Move `charter.md`, `roster.md`, `routing.md`, `casting-policy.json` to `.squad/config/`.
- Update all agent system prompts to reference new paths.
- Keep symlinks at old paths for one sprint to avoid breaking existing scripts.

### Phase 4 — Remove legacy global paths (Week 4+)

- Remove symlinks.
- Archive old top-level state files to `.squad/state/_legacy/`.
- Update docs.

---

## 7. Tradeoffs and Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Bot account misconfigured; auto-merge bypasses intended reviews | Low | Verify action only merges `state/`-only PRs |
| Scribe reconciliation produces bad `decisions.md` append | Medium | Append uses signed blocks; easy to revert one block |
| Engineers forget to use `<ALIAS>` in branch names | Medium | Pre-push hook + PR title lint in CI |
| MS repo policy blocks all auto-merge | Low | Fall back to batched daily PR (§5.2) |
| Legacy scripts hardcode `.squad/decisions.md` | High | Phase 3 symlinks; grep audit before removal |

---

## 8. Alternatives Considered and Rejected

| Alternative | Reason Rejected |
|---|---|
| Git sparse-checkout for squad config | Requires every developer to configure sparse-checkout locally; fragile in CI |
| "Squad admin merges" pattern | Does not eliminate conflicts, just serializes them through one human; doesn't scale |
| Monorepo sub-module for `.squad/` | Heavyweight; sub-module update PRs have their own approval flow |
| Rebase-only branch strategy | Doesn't prevent add/add conflicts; just reorders them |

---

## 9. Open Questions

1. Should `decisions.json` be NDJSON (one line per decision) to make cherry-pick easier?
2. Does the Scribe reconciliation need a conflict-resolution policy for decisions with the
   same logical topic from two concurrent sessions?
3. For ADO repos without GitHub Actions: replace the auto-merge bot with an Azure Pipeline
   trigger — same logic, different YAML.

---

## References

- [`.squad/config.json`](../.squad/config.json) — current Squad configuration
- [`.squad/decisions.md`](../.squad/decisions.md) — existing decisions log
- [`.squad/scribe-charter.md`](../.squad/scribe-charter.md) — Scribe agent role definition
- [GitHub CODEOWNERS docs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [GitHub auto-merge docs](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/automatically-merging-a-pull-request)
