# Decision: Squad Docs CI — Build-Only on Self-Hosted

**Date:** 2026-07-16
**Author:** B'Elanna (Infrastructure)
**Issue:** #568
**PR:** #570
**Status:** Proposed

## Context

The Squad Docs workflow needs to run in an EMU repo where:
1. GitHub-hosted runners are disabled
2. The self-hosted runner is Windows-based
3. GitHub Pages deployment is not available for EMU private repos

## Decision

- **Runner:** Always use `runs-on: self-hosted` for all workflows in this repo
- **Docs CI:** Build-only validation (no deployment). The workflow confirms `docs/build.js` produces valid `_site` output
- **Shell:** Use `shell: pwsh` for all workflow steps (Windows self-hosted compatibility)
- **No Pages deployment:** Removed `upload-pages-artifact` and `deploy-pages` actions entirely

## Rationale

Simplest approach that makes CI green. Since GitHub Pages isn't available for EMU private repos anyway, attempting deployment would always fail. Build validation still catches broken docs.

## Impact

- All squad members authoring workflows must use `self-hosted` and `pwsh`
- Docs are validated on CI but not auto-deployed — manual serving or alternative hosting needed if public docs are ever required
