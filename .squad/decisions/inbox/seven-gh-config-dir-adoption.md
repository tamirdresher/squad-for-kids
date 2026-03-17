# Decision: Adopt GH_CONFIG_DIR as primary auth isolation primitive

**Author:** Seven (Research & Docs)
**Date:** 2026-03-17
**Context:** Issue #778 — Research from jongio/gh-public-gh-emu-setup

## Decision

Replace `GH_TOKEN` extraction and `gh auth switch` with `GH_CONFIG_DIR` as the primary mechanism for GitHub CLI auth isolation across multiple accounts.

## Rationale

- `GH_CONFIG_DIR` isolates **all config** (tokens, preferences, host settings, cache), not just the token
- Eliminates the race condition in `ghp`/`ghe` aliases that use `gh auth switch` (global state mutation)
- Removes the `gh auth token --user X` extraction step and `gho_` format check (2 failure modes)
- Simpler code, fewer moving parts, zero cross-talk between concurrent processes

## Impact

- **Ralph (ralph-watch.ps1):** Simplify auth flow from 15 lines to 3
- **Aliases (ghp/ghe):** Fix race condition, change from `gh auth switch` to `$env:GH_CONFIG_DIR`
- **Skills docs:** Update `gh-auth-isolation/SKILL.md` and `github-account-switching/SKILL.md`
- **Spawn scripts:** Set `GH_CONFIG_DIR` at process launch time

## Sub-issues

- #781 (P0): Setup directories
- #782 (P0): Fix aliases
- #783 (P1): Ralph migration
- #784 (P2): Terminal profiles
- #785 (P2): Auto-activation

## Open Question

Should `GH_TOKEN` extraction be kept as a fallback for CI environments where config dirs may not persist? Recommend yes — document as legacy fallback, not primary path.
