# Decision: Helm/Kustomize Drift Detection Workflow Intentionally Disabled

**Date:** 2026-03-20  
**Decided by:** Worf (Security & Cloud)  
**Context:** Issue #1143 - CI alert for disabled GitHub Actions runners  

## Problem

Ralph's email monitoring detected CI failures for the Helm/Kustomize Drift Detection workflow with error "GitHub Actions hosted runners are disabled for this repository." The alert triggered investigation into whether this was a failure or intentional.

## Root Cause

The workflow **is intentionally disabled** due to GitHub Enterprise Managed User (EMU) organization policy:
- EMU policy blocks GitHub-hosted runners (ubuntu-latest, windows-latest, etc.)
- Self-hosted runners with bash/WSL support have not been configured
- Workflow was manually disabled on 2026-03-20 at 12:16:17+02:00

**Evidence:** `.github/workflows/drift-detection.yml` lines 4-6:
```yaml
# NOTE: pull_request trigger disabled — GitHub Actions hosted runners are not
# available in this org (EMU policy). To re-enable, configure self-hosted
# runners with bash/WSL support and restore the pull_request trigger.
```

## Decision

**KEEP WORKFLOW DISABLED** until self-hosted runners are available.

**Rationale:**
1. EMU policy prevents use of GitHub-hosted runners (security control)
2. Workflow requires bash/ubuntu environment (detect-drift job runs on `ubuntu-latest`)
3. No self-hosted Linux runners currently configured
4. Re-enabling without infrastructure will only create alert noise

## Follow-Up Actions

1. **Immediate (This PR):** 
   - Document workflow disabled state in README or workflow comments
   - Update Ralph's monitoring to suppress alerts for disabled workflows
   - Close issue #1143 as "working as intended"

2. **Future (When Self-Hosted Runners Available):**
   - Configure self-hosted runners with bash/WSL support
   - Re-enable workflow by setting `state: active`
   - Restore `pull_request` trigger in drift-detection.yml
   - Test drift detection on sample PR

## Impact

- **Security:** No degradation - EMU policy protection maintained
- **Compliance:** Drift detection temporarily unavailable, manual reviews required for Helm/Kustomize PRs
- **CI/CD:** No blocking impact - workflow was advisory, not required check

## Related

- Issue: #1143
- Workflow: `.github/workflows/drift-detection.yml`
- Policy: GitHub EMU hosted runner restrictions
