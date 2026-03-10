# Decision: Use pwsh for shell steps on self-hosted Windows runner

**Date:** 2025-07-16
**Author:** B'Elanna (Infrastructure)
**Issue:** #290
**PR:** #291

## Context

The `squad-heartbeat.yml` workflow runs on `self-hosted` which is a Windows runner in this org. Using `shell: bash` caused consistent failures because bash can't resolve Windows temp file paths (`C:\actions-runner\_work\_temp\...sh`).

## Decision

All shell steps in workflows targeting `self-hosted` must use `shell: pwsh` instead of `shell: bash`. This applies only to the active workflow (`.github/workflows/`), not the templates (`.squad-templates/`, `sanitized-demo/`) which target `ubuntu-latest`.

## Convention

- **Self-hosted runner = Windows** → use `shell: pwsh`
- **ubuntu-latest** → default shell (bash) is fine
- `actions/github-script` steps are unaffected (they use Node.js, not shell)
- The active workflow may intentionally diverge from templates when the runner OS differs
