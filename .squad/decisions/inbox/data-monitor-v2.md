# Decision: squad-monitor v2 uses `gh` CLI for GitHub data

**Date:** 2026-03-08  
**Author:** Data (Code Expert)  
**Status:** Proposed  
**Scope:** Tooling

## Context

squad-monitor needed GitHub Issues and PR data. Two options: direct GitHub API with token management, or shelling out to `gh` CLI.

## Decision

Use `gh` CLI (`gh issue list --json`, `gh pr list --json`) instead of direct API calls.

## Rationale

- `gh` handles authentication — no token storage or refresh logic needed in the monitor
- JSON output mode gives structured data without HTML parsing
- 10s process timeout prevents blocking the refresh loop
- Graceful fallback message when `gh` is not installed or not authenticated
- Keeps the monitor as a single-file C# program with no additional NuGet dependencies

## Trade-offs

- ✅ Zero auth code, zero new dependencies
- ✅ Works immediately for anyone with `gh` installed
- ⚠️ Requires `gh` CLI to be installed and authenticated
- ⚠️ Process spawning is slower than HTTP calls (~1-2s per panel)
- ⚠️ Rate limiting is opaque (handled by `gh` internally)

## Applies to

All squad-monitor GitHub panels (issues, PRs, future board integration).
