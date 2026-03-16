# Decision: Centralized Secrets Management Pattern

**Author:** Worf (Security & Cloud)
**Date:** 2026-07-11
**Issue:** #666
**PR:** #668
**Status:** Proposed

## Decision

Adopt a centralized secrets management pattern for the squad:

1. **No secrets in git.** Ever. Not in code, not in config, not in screenshots.
2. **Windows Credential Manager** is the primary secret store (key per secret).
3. **`$env:USERPROFILE\.squad\.env`** is the fallback for machines without Credential Manager module.
4. **`.env.example`** in repo root documents all required variables (names and descriptions only).
5. **`scripts/setup-secrets.ps1`** loads secrets at session start; `devbox-startup.ps1` calls it before Ralph.
6. **`.gitignore`** hardened to block `*.env`, secret screenshots, `*.key`, `*.pem`, config JSON.
7. **Each machine sets up independently** — no cross-machine secret sync.

## Rationale

- The Google API key was committed to git (#645). That's a P0 security incident.
- Screenshots with visible secrets are a leak vector (`github-oauth-secret-generated.png`).
- Inconsistent secret storage makes onboarding new devboxes error-prone.
- A single documented pattern prevents future incidents.

## Impact

- **All agents** that need secrets must use `$env:VAR_NAME` after `setup-secrets.ps1` runs.
- **New secrets** must be added to `.env.example`, `setup-secrets.ps1`, and the SKILL.md.
- **Devbox setup** now includes a secrets validation step.

## Action Required

- [ ] Rotate Google API key (was in git history)
- [ ] Team to review and merge PR #668
- [ ] Each devbox owner to run `setup-secrets.ps1` and fill missing secrets
