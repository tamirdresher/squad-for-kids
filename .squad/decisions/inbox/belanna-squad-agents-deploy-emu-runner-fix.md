# Decision: Squad Agents Deploy — EMU Runner Policy Fix

**Date:** 2026-03-20  
**Author:** B'Elanna  
**Status:** Implemented  
**Impact:** CI/CD  

## Problem
The **Squad Agents Deploy** workflow (`.github/workflows/squad-agents-deploy.yml`) was triggering on `push` to main with GitHub-hosted runner (`ubuntu-latest`). EMU organization policy disables GitHub-hosted runners, causing workflow failures on every push to infrastructure paths.

## Decision
Disabled the `push` trigger. Workflow now only runs on manual `workflow_dispatch` trigger until a self-hosted runner with Docker + Azure CLI is available.

## Rationale
- **Immediate:** Stops alert noise and false CI failures. Infrastructure work can proceed via manual dispatch.
- **Future:** When self-hosted runner is ready, re-enable push trigger with `runs-on: self-hosted` in both `build` and `deploy` jobs.

## Next Steps
1. Set up self-hosted runner (Windows or Linux) with:
   - Docker
   - Azure CLI
   - kubectl
   - Helm
2. Register runner to this GitHub org (EMU)
3. Re-enable push trigger once runner is online

## Related Files
- `.github/workflows/squad-agents-deploy.yml` — push trigger removed
- Team decision on EMU runner policy in `.squad/decisions.md`
