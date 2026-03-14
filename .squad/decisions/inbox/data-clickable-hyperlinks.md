# Decision: Clickable Hyperlinks via Spectre.Console Markup

**Date:** 2026-06-26
**Author:** Data
**Issue:** tamirdresher/squad-monitor#14

## Decision

Use Spectre.Console's `[link=URL]text[/]` markup for clickable issue/PR numbers in both Spectre.Console and SharpUI modes. No OSC 8 escape sequences needed because SharpUI's `MarkupControl` also renders Spectre markup.

## Key Details

- Repo slug (`owner/repo`) resolved via `gh repo view --json nameWithOwner` and cached in a `static class GitHubLinkCache` (required because Program.cs uses top-level statements which don't allow `static` field declarations)
- Graceful fallback: if `gh` CLI unavailable or repo info can't be resolved, numbers render as plain colored text
- Branch pushed: `squad/14-clickable-hyperlinks` — PR needs to be created via GitHub web UI (EMU auth restriction prevents `gh pr create` on personal repos)

## Impact

- All 8 issue/PR number rendering sites updated across Program.cs (6) and SharpUI.cs (2)
- No breaking changes — existing visual layout preserved, just numbers become clickable in supporting terminals
