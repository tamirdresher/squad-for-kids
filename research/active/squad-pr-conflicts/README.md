# Squad PR Conflicts Research

**Issue:** #520 — "One of the things we need to find solution to is the conflicts and PR needed for squad in repo"

**Researcher:** Picard (Lead)  
**Date:** 2026-03-14  
**Status:** ✅ Complete

---

## Problem Statement

In Microsoft (enterprise repos), you need PR approval and can't push directly to main. When multiple team engineers use Squad in the same repo, `.squad/` decisions and changes will keep conflicting and will wait in PRs without being reflected immediately.

This creates a **state synchronization problem**:
- Agent A and Agent B work on different issues simultaneously
- Both append entries to `.squad/decisions.md` or `.squad/agents/*/history.md`
- Both create PRs to main
- First PR merges successfully
- Second PR now has merge conflicts and needs manual resolution
- Agent B's state becomes stale while waiting for human intervention
- Subsequent agents see outdated state, compounding the problem

---

## Conflict Scenarios Analysis

### Scenario 1: Simultaneous Decision Recording
**What happens:**
- Picard evaluates Issue #520 and writes decision to `.squad/decisions/inbox/picard-squad-pr-conflicts.md`
- Seven evaluates Issue #521 and writes decision to `.squad/decisions/inbox/seven-tech-news.md`
- Both decisions get merged to `.squad/decisions.md` via Scribe
- Both agents commit and create PRs
- First PR merges → `.squad/decisions.md` updated
- Second PR conflicts → blocked until human resolves

**Impact:** High. Decisions are authoritative team knowledge. Stale decisions lead to inconsistent behavior.

### Scenario 2: Parallel Agent History Updates
**What happens:**
- Data works on Issue #496 (XTTS voice cloning)
- Seven works on Issue #504 (SAW/GCC research)
- Both append learnings to their respective history files: `.squad/agents/data/history.md` and `.squad/agents/seven/history.md`
- **No conflict** because they're different files
- But orchestration logs in `.squad/orchestration-log/` may still collide if using same timestamp

**Impact:** Low-Medium. Agent-specific history files don't conflict. Orchestration logs use timestamps to avoid collisions.

### Scenario 3: Ralph Multi-Machine Coordination
**What happens:**
- Ralph watch script runs on Machine A (local laptop)
- Ralph watch script runs on Machine B (DevBox)
- Both instances claim issues and update `.squad/monitoring/schedule-state.json`
- First machine's PR merges
- Second machine's state is now stale and conflicts

**Impact:** High. This is the exact scenario from Issue #346/350. Already mitigated via branch namespacing (`squad/{issue}-{slug}-{machineid}`), but still requires PR approval.

### Scenario 4: Orchestration Log Divergence
**What happens:**
- Orchestration runs trigger multiple agents in parallel
- Each agent writes to `.squad/orchestration-log/{timestamp}-{agent}.md`
- Logs from different branches don't merge cleanly
- Historical orchestration context becomes fragmented across branches

**Impact:** Low-Medium. Logs are diagnostic/historical. Timestamp-based filenames prevent direct conflicts.

---

## Current Mitigation Strategies

### 1. **`merge=union` Strategy** (Already Implemented)
**Config:** `.gitattributes`
```gitattributes
.squad/decisions.md merge=union
.squad/agents/*/history.md merge=union
.squad/log/** merge=union
.squad/orchestration-log/** merge=union
```

**How it works:**
- Automatically concatenates both versions during merge
- No manual conflict resolution needed
- Perfect for append-only logs

**Effectiveness:**
- ✅ Eliminates manual merge conflicts for append-only files
- ✅ Preserves all entries from both branches
- ⚠️ Can create duplicate entries if not careful
- ⚠️ Still requires PR approval cycle → state remains stale until merge

**Verdict:** Reduces friction but doesn't solve the core synchronization delay problem.

### 2. **Branch Protection Guard** (Currently Disabled)
**Workflow:** `.github/workflows/squad-main-guard.yml`

**Policy:** `.squad/` files are **forbidden on main** branch.

**Rationale (from Issue #193, #194):**
- Workflow fired on push to main AFTER merge
- Generated failure emails for .squad/ files that are always part of squad work
- Pure noise → disabled by user request

**Effectiveness:**
- ✅ Would keep team state isolated from production code
- ❌ Creates friction for legitimate squad state updates
- ❌ Disabled because it blocked all squad work, not just conflicting updates

**Verdict:** Too restrictive. Prevents Squad from functioning in normal workflow.

### 3. **Timestamped Filenames** (Implicit Pattern)
**Pattern:** `.squad/orchestration-log/2026-03-14T13-05-00Z-data.md`

**How it works:**
- Each orchestration run creates unique file based on timestamp + agent name
- No two agents write to the same file
- Naturally avoids conflicts

**Effectiveness:**
- ✅ Perfect for logs/telemetry
- ✅ No conflicts possible
- ⚠️ Doesn't work for shared state files (decisions.md, schedule-state.json)
- ⚠️ Fragmentation: hard to find "latest" state

**Verdict:** Excellent for logs, not applicable to authoritative state files.

---

## Proposed Solutions

### Solution 1: **Orphan Branch for Squad State** (`squad/state`)
**Architecture:**
- Create an orphan branch `squad/state` with completely independent history
- All `.squad/` state lives on this branch only
- Development branches checkout this branch into `.squad/` directory at runtime
- Changes to `.squad/` push directly to `squad/state` (no PR needed)
- Production `main` branch never contains `.squad/` files

**Implementation:**
```bash
# One-time setup
git checkout --orphan squad/state
git rm -rf .
mv .squad/* .
git add .
git commit -m "Initial squad state"
git push origin squad/state

# In development workflow
git worktree add .squad squad/state
# Make changes to .squad/
cd .squad && git commit && git push origin squad/state

# Or use subtree strategy
git subtree pull --prefix=.squad origin squad/state
```

**Pros:**
- ✅ Complete separation: squad state never conflicts with code PRs
- ✅ Independent commit history: clear audit trail for team decisions
- ✅ Fast-forward merges: no PR approval needed for squad state updates
- ✅ Rollback capability: can revert squad state without affecting code
- ✅ Enterprise-friendly: doesn't violate branch protection on main

**Cons:**
- ❌ Complexity: requires git worktree or subtree knowledge
- ❌ Tooling friction: agents need to push to two branches (code + state)
- ❌ Discoverability: new contributors won't see `.squad/` in main branch checkout
- ❌ CI/CD integration: workflows need to fetch squad/state branch explicitly

**Feasibility in Enterprise:** 🟢 High. Doesn't require any permissions changes. Common pattern (gh-pages).

**Implementation Complexity:** 🟡 Medium. Requires agent workflow changes and documentation.

**Security Implications:** 🟢 Low risk. State is still in same repo, just different branch.

**Recommendation:** ⭐ **Recommended** if team is comfortable with git worktrees/subtrees.

---

### Solution 2: **GitHub Actions Auto-Merge Bot**
**Architecture:**
- Create a GitHub App or use existing bot account (e.g., `@squad-bot`)
- Grant bot bypass permissions for `.squad/**` path in branch protection rules
- Workflow automatically merges PRs that only touch `.squad/` files and pass checks

**Implementation:**
```yaml
# .github/workflows/squad-auto-merge.yml
name: Squad State Auto-Merge
on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - '.squad/**'

jobs:
  auto-merge:
    runs-on: ubuntu-latest
    steps:
      - name: Check if PR only modifies .squad/
        uses: actions/github-script@v7
        with:
          script: |
            const files = await github.rest.pulls.listFiles({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.issue.number
            });
            
            const nonSquadFiles = files.data.filter(f => !f.filename.startsWith('.squad/'));
            
            if (nonSquadFiles.length === 0 && files.data.length > 0) {
              // All files are in .squad/ → auto-approve
              await github.rest.pulls.createReview({
                owner: context.repo.owner,
                repo: context.repo.repo,
                pull_number: context.issue.number,
                event: 'APPROVE',
                body: '✅ Auto-approved: Squad state update only'
              });
              
              // Merge immediately
              await github.rest.pulls.merge({
                owner: context.repo.owner,
                repo: context.repo.repo,
                pull_number: context.issue.number,
                merge_method: 'merge'
              });
            }
```

**Pros:**
- ✅ Minimal workflow disruption: agents still use normal PR flow
- ✅ Audit trail: every change is a PR with full context
- ✅ Selective: only auto-merges squad-only PRs, code PRs still need approval
- ✅ Rollback: standard git revert workflow
- ✅ Familiar: no new git concepts for contributors

**Cons:**
- ❌ Delay: still requires PR creation + CI checks to pass (~30-60 seconds minimum)
- ❌ Race conditions: if two PRs arrive simultaneously, second still conflicts
- ❌ Permissions complexity: needs bot with merge permissions in enterprise
- ❌ Branch protection bypass: may violate compliance policies

**Feasibility in Enterprise:** 🟡 Medium. Requires security review for bot bypass permissions. May conflict with SOX/FedRAMP compliance.

**Implementation Complexity:** 🟢 Low. Standard GitHub Actions pattern.

**Security Implications:** 🟡 Medium. Bypassing branch protection is a red flag in audits.

**Recommendation:** ⚠️ **Conditional.** Only if enterprise policy allows automated bypass for non-code paths.

---

### Solution 3: **GitHub Issues for State Storage**
**Architecture:**
- Use GitHub Issues as a key-value store for squad state
- Each decision/state change creates an issue comment or updates issue body
- Agents read state via GitHub API at runtime
- No `.squad/` files in git → no conflicts

**Implementation:**
```javascript
// Read decision from Issue #999 (pinned "Squad Decisions" issue)
const issue = await github.rest.issues.get({
  owner,
  repo,
  issue_number: 999
});

// Parse YAML frontmatter or JSON from issue body
const decisions = parseYAML(issue.data.body);

// Append new decision as comment
await github.rest.issues.createComment({
  owner,
  repo,
  issue_number: 999,
  body: `## Decision 23: Squad PR Conflicts\n\n**Date:** 2026-03-14\n...`
});
```

**Pros:**
- ✅ Zero git conflicts: state lives outside repository
- ✅ Instant updates: no PR approval needed
- ✅ Native GitHub interface: humans can view/edit decisions in UI
- ✅ API-driven: easy for agents to read/write programmatically
- ✅ Append-only: comments naturally avoid race conditions

**Cons:**
- ❌ Discoverability: developers must remember to check Issue #999 for decisions
- ❌ Local dev friction: agents need network access + GitHub token
- ❌ Offline work: can't make squad decisions without internet
- ❌ Backup/export: harder to archive state (no longer in git history)
- ❌ Tooling: existing git-based workflows (grep, blame) don't work

**Feasibility in Enterprise:** 🟢 High. Uses standard GitHub API, no special permissions.

**Implementation Complexity:** 🔴 High. Requires rewriting all squad state read/write logic.

**Security Implications:** 🟢 Low. Same permissions as code (repo access).

**Recommendation:** ❌ **Not recommended.** Breaks git-native workflow and loses auditability benefits.

---

### Solution 4: **Git Notes for Squad Metadata**
**Architecture:**
- Use git notes to attach squad state to commits without modifying files
- Each commit carries its squad context as a note (decisions, logs)
- Notes merge independently from file content
- Main branch only contains code; notes contain squad state

**Implementation:**
```bash
# Create note with squad state
git notes --ref=squad/decisions add -m "Decision 23: PR Conflicts" HEAD

# Push notes to remote
git notes push origin refs/notes/squad/decisions

# Fetch notes from remote
git notes fetch origin refs/notes/squad/decisions

# Read notes from commit
git notes --ref=squad/decisions show HEAD
```

**Pros:**
- ✅ Non-intrusive: doesn't modify commit history or file tree
- ✅ Mergeable: git supports note-specific merge strategies
- ✅ Namespace flexibility: separate note refs for decisions, logs, state
- ✅ Git-native: uses built-in git features, no external dependencies

**Cons:**
- ❌ Obscure: most developers don't know git notes exist
- ❌ Tooling: poor IDE/UI support (GitHub web doesn't show notes)
- ❌ Workflow friction: requires explicit push/fetch of notes refs
- ❌ Orphan risk: notes can be lost if not pushed correctly
- ❌ Discovery: hard to find which commits have notes

**Feasibility in Enterprise:** 🟢 High. Standard git feature, no special permissions.

**Implementation Complexity:** 🟡 Medium. Requires agent workflow changes and training.

**Security Implications:** 🟢 Low. Same permissions model as commits.

**Recommendation:** ⚠️ **Experimental.** Interesting but too obscure for team adoption.

---

### Solution 5: **Separate Repo for Squad State** (`tamresearch1-squad`)
**Architecture:**
- Create companion repository: `tamresearch1-squad`
- All `.squad/` state lives in this separate repo
- Agents write to squad repo independently from code repo
- Squad repo has no branch protection → direct pushes allowed
- Code repo references squad repo via git submodule or API

**Implementation:**
```bash
# One-time setup
gh repo create tamresearch1-squad --private
cd .squad
git init
git remote add origin https://github.com/tamirdresher/tamresearch1-squad
git add . && git commit -m "Initial squad state"
git push -u origin main

# Add as submodule to code repo
cd /path/to/tamresearch1
git submodule add https://github.com/tamirdresher/tamresearch1-squad .squad

# Agent workflow: push directly to squad repo
cd .squad
git add . && git commit -m "Decision 23: PR Conflicts"
git push  # No PR needed!

# Code PRs never touch .squad/ → no conflicts
```

**Pros:**
- ✅ Complete isolation: squad state and code are fully decoupled
- ✅ Zero PR friction: squad repo allows direct pushes
- ✅ Independent permissions: different collaborators for code vs. squad
- ✅ Scalability: squad repo can grow without bloating code repo
- ✅ Clear ownership: squad repo is explicitly for team state

**Cons:**
- ❌ Complexity: requires managing two repos, submodule updates
- ❌ Clone friction: developers must `git submodule update --init --recursive`
- ❌ Atomicity lost: code PR and squad state update are separate operations
- ❌ Discovery: easy to forget squad repo exists
- ❌ Backup: must back up two repos independently

**Feasibility in Enterprise:** 🟢 High. Standard multi-repo pattern. Common in monorepo ecosystems.

**Implementation Complexity:** 🟡 Medium. Requires CI/CD updates to handle submodules.

**Security Implications:** 🟢 Low. Standard git permissions model. Can restrict squad repo access.

**Recommendation:** ⭐ **Recommended** for large teams with high conflict frequency.

---

### Solution 6: **Enhanced `merge=union` + Conflict-Free Replicated Data Type (CRDT)**
**Architecture:**
- Design `.squad/decisions.md` as a CRDT-friendly structure
- Each decision is immutable with unique ID and timestamp
- Agents only append (never edit) entries
- Merge=union handles automatic concatenation
- Post-merge script deduplicates and sorts entries

**Implementation:**
```markdown
<!-- .squad/decisions.md -->
## Decisions

<!-- Decision entries: ID + timestamp + hash for uniqueness -->
### Decision 23 (2026-03-14T15:30:00Z-picard-abc123)
**Author:** Picard  
**Issue:** #520  
...

### Decision 24 (2026-03-14T15:32:00Z-seven-def456)
**Author:** Seven  
**Issue:** #521  
...
```

```bash
# Post-merge hook: .git/hooks/post-merge
#!/bin/bash
# Deduplicate decisions.md by unique ID
cat .squad/decisions.md | sort | uniq > .squad/decisions.md.tmp
mv .squad/decisions.md.tmp .squad/decisions.md
git add .squad/decisions.md && git commit --amend --no-edit
```

**Pros:**
- ✅ Minimal disruption: builds on existing merge=union strategy
- ✅ Automatic deduplication: no manual conflict resolution
- ✅ Git-native: uses standard git features + hooks
- ✅ Append-only: naturally conflict-free
- ✅ Provable correctness: CRDT properties guarantee eventual consistency

**Cons:**
- ❌ Fragile: relies on strict formatting discipline
- ❌ Hook setup: every developer must install post-merge hook
- ❌ Amend risk: `git commit --amend` after merge can confuse history
- ❌ Complexity: CRDT concepts are non-trivial for average developer
- ❌ Limited scope: only works for append-only structures

**Feasibility in Enterprise:** 🟡 Medium. Requires training and strict conventions.

**Implementation Complexity:** 🔴 High. CRDT design + hook distribution + testing.

**Security Implications:** 🟢 Low. Standard git workflow with automation.

**Recommendation:** ⚠️ **Overkill.** Interesting theoretically but overengineered for this problem.

---

## Solution Comparison Matrix

| Solution | Conflict Elimination | PR Delay | Enterprise Feasibility | Implementation Complexity | Security Risk | Recommended? |
|----------|---------------------|----------|----------------------|--------------------------|---------------|--------------|
| **1. Orphan Branch** (`squad/state`) | ✅ Complete | ✅ None | 🟢 High | 🟡 Medium | 🟢 Low | ⭐ Yes |
| **2. Auto-Merge Bot** | ⚠️ Partial | 🟡 30-60s | 🟡 Medium | 🟢 Low | 🟡 Medium | ⚠️ Conditional |
| **3. GitHub Issues** | ✅ Complete | ✅ None | 🟢 High | 🔴 High | 🟢 Low | ❌ No |
| **4. Git Notes** | ✅ Complete | ✅ None | 🟢 High | 🟡 Medium | 🟢 Low | ⚠️ Experimental |
| **5. Separate Repo** | ✅ Complete | ✅ None | 🟢 High | 🟡 Medium | 🟢 Low | ⭐ Yes |
| **6. CRDT + merge=union** | 🟡 Eventual | ⚠️ PR cycle | 🟡 Medium | 🔴 High | 🟢 Low | ❌ No |

---

## Recommended Approach: Hybrid Strategy

**Phase 1: Immediate Relief (Week 1)**
- ✅ Keep existing `merge=union` strategy
- ✅ Educate team on proper append-only formatting
- ✅ Add pre-commit hook to validate decision format
- ✅ Enable auto-merge bot for `.squad/`-only PRs (if compliance allows)

**Phase 2: Structural Change (Week 2-3)**
- ⭐ Migrate to **orphan branch strategy** (`squad/state`)
- ⭐ OR create **separate squad repo** (`tamresearch1-squad`)
- Update agent workflows to push directly to squad branch/repo
- Keep `.squad/` out of main branch entirely

**Phase 3: Long-term Optimization (Month 2)**
- Monitor conflict frequency and resolution time
- Evaluate CRDT approach if append-only discipline fails
- Consider git notes for experimental features

**Rationale:**
- **Orphan branch** is the sweet spot: eliminates conflicts, minimal permissions changes, git-native
- **Separate repo** is the safest long-term bet for large teams with high activity
- **Auto-merge bot** provides immediate relief while structural changes are implemented
- **GitHub Issues / CRDT / Git Notes** are overengineered for current problem scale

---

## Implementation Checklist

### For Orphan Branch (`squad/state`) Approach:

- [ ] Create orphan branch: `git checkout --orphan squad/state`
- [ ] Move `.squad/` contents to root of orphan branch
- [ ] Push orphan branch: `git push origin squad/state`
- [ ] Update `.squad/.gitignore` to be in-place rules (no need for recursive patterns)
- [ ] Configure git worktree in dev workflow: `git worktree add .squad squad/state`
- [ ] Update agent scripts to commit to `.squad/` worktree and push to `squad/state`
- [ ] Document workflow in `.squad/README.md`
- [ ] Update CI/CD to fetch `squad/state` branch for context
- [ ] Train team on worktree workflow

### For Separate Repo (`tamresearch1-squad`) Approach:

- [ ] Create new repo: `gh repo create tamresearch1-squad --private`
- [ ] Initialize squad repo with current `.squad/` contents
- [ ] Add as submodule: `git submodule add <url> .squad`
- [ ] Remove `.squad/` from main repo's branch protection (not needed anymore)
- [ ] Update agent scripts to `cd .squad && git commit && git push`
- [ ] Update CI/CD to `git submodule update --init --recursive`
- [ ] Document submodule workflow in README
- [ ] Set up separate permissions/collaborators for squad repo

### For Auto-Merge Bot Approach:

- [ ] Create GitHub App or bot account with merge permissions
- [ ] Add workflow: `.github/workflows/squad-auto-merge.yml`
- [ ] Configure branch protection: allow bot to bypass PR approval for `.squad/**`
- [ ] Test with sample PR (only touches `.squad/` files)
- [ ] Monitor for false positives (PRs that shouldn't auto-merge)
- [ ] Set up alerting for auto-merge failures

---

## Risk Assessment

### High Risk:
- **Compliance violation:** Auto-merge bot bypassing branch protection may fail SOX/FedRAMP audits
- **State loss:** Orphan branch or separate repo could be lost if not properly backed up
- **Adoption resistance:** Team may resist learning git worktrees/submodules

### Medium Risk:
- **Tooling breakage:** Existing scripts that assume `.squad/` is in main repo will break
- **Discovery problem:** New contributors won't see squad state in default checkout
- **Merge complexity:** Submodules add friction to merge process

### Low Risk:
- **Conflict recurrence:** If append-only discipline fails, conflicts may persist
- **Performance:** Fetching separate branch/repo adds latency to CI/CD

**Mitigation:**
- Document workflow changes extensively (`.squad/README.md`, `CONTRIBUTING.md`)
- Provide onboarding script that sets up worktree/submodule automatically
- Create pre-commit hooks that validate squad state format
- Monitor metrics: conflict frequency, PR approval time, agent blocked time

---

## Open Questions

1. **Compliance:** Does Microsoft/enterprise policy allow bot bypass of branch protection for non-code paths?
2. **Backup:** How is `squad/state` orphan branch backed up? Is it included in disaster recovery?
3. **Permissions:** Should squad repo have different collaborators than code repo?
4. **Rollback:** If a bad decision is committed to `squad/state`, what's the revert process?
5. **Tooling:** Do agents have direct push permissions, or do they still need to create PRs to `squad/state`?

---

## References

- **Issue #520:** "One of the things we need to find solution to is the conflicts and PR needed for squad in repo"
- **Issue #346, #350:** Ralph multi-machine coordination (branch namespacing)
- **Issue #193, #194:** Squad-main-guard workflow disabled (too restrictive)
- **Decision #16:** Knowledge Management Phase 1 (quarterly history rotation)
- **Decision #21:** Squad MCP Server Architecture (state integration via GitHub API)
- **Git Documentation:** [git-worktree](https://git-scm.com/docs/git-worktree), [git-notes](https://git-scm.com/docs/git-notes), [git-submodule](https://git-scm.com/docs/git-submodule)
- **GitHub Actions:** [Auto-merge workflows](https://docs.github.com/en/actions/managing-workflow-runs/approving-workflow-runs-from-public-forks)
- **CRDT Research:** [Conflict-Free Replicated Data Types](https://crdt.tech/)

---

## Appendix: Current Merge=Union Configuration

**File:** `.gitattributes`
```gitattributes
# Squad: union merge for append-only team state files
.squad/decisions.md merge=union
.squad/agents/*/history.md merge=union
.squad/log/** merge=union
.squad/orchestration-log/** merge=union
```

**Effectiveness:**
- ✅ Eliminates manual merge conflicts for these files
- ✅ Proven to work across 519 PRs (recent example: PR #519 with 5 squad files merged cleanly)
- ⚠️ Still requires PR approval cycle → state is stale until merge completes
- ⚠️ Doesn't solve the core problem: synchronization delay

**Enhancement Opportunity:**
- Add post-merge hook to detect and report duplicate entries
- Add pre-commit validation to ensure proper append-only format
- Add CI check to validate decisions.md syntax before merge

---

**Next Steps:** See `.squad/decisions/inbox/picard-squad-pr-conflicts.md` for formal recommendation.
