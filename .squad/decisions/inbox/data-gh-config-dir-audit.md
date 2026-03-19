# Decision: Explicit GH_CONFIG_DIR in All Squad Scripts

**Date:** 2026-03-18  
**Agent:** Data  
**Issue:** #939

## Decision

Every `.ps1` script that calls `gh` must set `$env:GH_CONFIG_DIR` explicitly before any `gh` invocation.

- **EMU account** (tamirdresher_microsoft): `$env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"`
- **Public account** (tamirdresher): `$env:GH_CONFIG_DIR = "$HOME\.config\gh-pub"`

## Rationale

Without explicit context, scripts inherit whatever `GH_CONFIG_DIR` the calling shell has set. This is fragile — wrong in CI, on another machine, or when contributors invoke scripts directly.

## Scope

9 scripts patched in PR #939. See `.squad/docs/gh-context-guide.md` for the full audit table.

## Files Updated

`.squad/scripts/generate-digest.ps1`, `.squad/scripts/daily-rp-briefing.ps1`, `.squad/scripts/Invoke-SquadScheduler.ps1`, `scripts/ralph-watch-content.ps1`, `scripts/ralph-email-monitor.ps1`, `scripts/scheduled-cache-review.ps1`, `scripts/ralph-self-heal.ps1`, `scripts/squad-watch.ps1`, `scripts/sync-squad-fork.ps1`
