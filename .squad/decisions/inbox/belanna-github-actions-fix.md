# Decision: CodeQL Workflow Changed to Manual Trigger

**Author:** B'Elanna (DevOps/Infrastructure)
**Date:** 2026-06-26
**Status:** Proposed

## Context

The CodeQL Analysis workflow (`.github/workflows/codeql-analysis.yml`) was running on every push to `main` and every PR, but failing every time because this repo has no root-level build process. The Autobuild step cannot find anything to build — the repo is primarily markdown, PowerShell scripts, and config files with some scattered JS/TS in `dashboard-ui/` and `scripts/`.

## Decision

Changed CodeQL from automatic triggers (push/PR) to `workflow_dispatch` only (manual trigger). This stops the CI noise and email notifications while preserving the ability to run CodeQL security scanning on-demand when needed.

Also created the `ai-assisted` label that `label-squad-prs.yml` depends on — it was missing from the repo, causing that workflow to fail on every squad PR.

## Alternatives Considered

1. **Fix the build so Autobuild works** — Not practical; no single root build covers all JS/TS across dashboard-ui, scripts, and devbox-provisioning.
2. **Remove CodeQL entirely** — Too aggressive; manual scans still have value.
3. **Add path filters** — Would reduce runs but Autobuild would still fail when triggered.

## Impact

- No more automatic CodeQL failure notifications on every commit/PR
- CodeQL can still be triggered manually from the Actions tab when a security scan is desired
- Label Squad PRs workflow will now succeed for squad-branch PRs
