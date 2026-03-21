# Decision: Enterprise State Management — Three Approaches

**Date:** 2026-03-22  
**Author:** Troi (Blog & Voice Writer)  
**Status:** Proposed — awaiting Tamir's evaluation  
**Context:** Part 7 of Scaling AI blog series

## Problem Statement

Squad's "Git as database" philosophy creates friction in enterprise repos:
- Squad state (.squad/ files) mixed with code in every PR
- 700+ files in typical code PR (95% state, 5% code)
- Agents require human approval to update their own memory
- Parallel feature branches have stale state
- JSON files corrupted by line-based merge strategies
- Code changes 1x/day, state changes 50x/day — different lifecycles

## Three Approaches Evaluated

### Approach 1: Orphan Branch (git worktree)
- **How:** Separate `squad/state` branch (orphan), mounted via `git worktree add .squad squad/state`
- **Pros:** Zero PR delay, clean code diffs, same repo, independent versioning, scales to 10+ agents
- **Cons:** git worktree is exotic, setup complexity, team education needed, IDE support varies
- **Best for:** Teams that can tolerate setup cost for clean runtime behavior

### Approach 2: Separate Repository
- **How:** `myrepo-squad` repo cloned into `.squad/`, added to `.gitignore`
- **Pros:** Conceptually simple, standard git workflows, easy to explain
- **Cons:** Two repos to manage, split context, cross-repo references messy
- **Best for:** Teams already comfortable with multi-repo workflows

### Approach 3: Auto-Merge Bot
- **How:** GitHub Action auto-approves PRs touching only `.squad/` files
- **Pros:** One repo, minimal setup, standard workflow
- **Cons:** Race conditions with concurrent PRs, compliance approval needed, 10-30s delay, noisy PR history
- **Best for:** Small teams, low PR volume (does not scale to 10+ agents)

## Recommendation

**For tamresearch1 (personal repo):** Orphan branch — already implemented, works beautifully.

**For work repos (enterprise):** Leaning toward Orphan Branch, but socializing with team first. Separate Repo as fallback if worktree education is too heavy a lift.

**Against Auto-Merge Bot:** Race conditions at scale make this unsuitable for multi-agent systems.

## Implementation Notes

Blog post includes:
- SVG diagrams showing problem and architecture
- Comparison table with all tradeoffs
- Code examples for each approach
- Link to Reddit discussion for community feedback

## Community Input Requested

Posted to Reddit: https://www.reddit.com/r/GithubCopilot/s/N5DH2B8YA0  
Looking for real-world feedback from teams running multi-agent systems in enterprise repos.

## Next Steps

1. Publish Part 7 blog post ✅
2. Gather community feedback from Reddit thread
3. Socialize orphan branch approach with work team
4. Document setup procedure for whichever approach is chosen
5. Update Squad README with recommended patterns
