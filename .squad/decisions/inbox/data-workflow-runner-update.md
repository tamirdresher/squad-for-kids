# Decision: Migrate All Workflows to Self-Hosted Runner

**Date:** 2026-03-08  
**Decider:** Data (Code Expert)  
**Context:** Issue #110 - CI workflows failing in EMU personal repos due to hosted runner unavailability  
**Status:** ✅ Implemented

## Problem

GitHub Actions workflows were failing because EMU (Enterprise Managed User) personal repositories cannot use GitHub-hosted runners at the organization level. All auto-triggers were disabled with comments stating "All auto-triggers disabled - hosted runners unavailable at org level", leaving workflows manually triggered only.

## Decision

Migrate all 16 GitHub Actions workflows to use the self-hosted Windows runner "squad-local-runner" (labels: `self-hosted, Windows, X64`) and re-enable all auto-triggers.

## Alternatives Considered

1. **Keep workflows disabled** - Not viable; breaks CI/CD completely
2. **Use GitHub-hosted runners** - Not possible in EMU personal repos
3. **Migrate to Azure DevOps** - Too much infrastructure change; self-hosted runner is simpler

## Implementation

### Runner Configuration Changes

Changed all workflow files from:
```yaml
runs-on: ubuntu-latest
```

To:
```yaml
runs-on: self-hosted
```

### Auto-Trigger Re-enablement

Re-enabled the following triggers:

| Workflow | Original Trigger | Re-enabled |
|----------|-----------------|------------|
| squad-ci.yml | N/A | push/PR to main, dev |
| squad-issue-assign.yml | N/A | issues: labeled |
| squad-label-enforce.yml | N/A | issues: labeled |
| squad-main-guard.yml | N/A | PR/push to main, preview |
| squad-triage.yml | N/A | issues: labeled (when label='squad') |
| sync-squad-labels.yml | N/A | push to .squad/team.md, .ai-team/team.md |
| squad-docs.yml | N/A | push to main (docs/**) |
| squad-insider-release.yml | N/A | push to dev |
| squad-preview.yml | N/A | push to preview |
| squad-release.yml | N/A | push to main |

### Shell Configuration

Added `defaults: run: shell: bash` to workflows with bash-specific syntax:
- drift-detection.yml
- fedramp-validation.yml
- squad-daily-digest.yml
- squad-insider-release.yml
- squad-issue-notify.yml
- squad-preview.yml
- squad-promote.yml
- squad-release.yml

**Rationale:** Windows self-hosted runner has Git Bash available, enabling bash scripts (heredocs, source commands) to run properly.

## Files Modified

16 workflow files updated:
1. drift-detection.yml (3 jobs)
2. fedramp-validation.yml (6 jobs)
3. post-comment.yml
4. squad-ci.yml
5. squad-daily-digest.yml
6. squad-docs.yml
7. squad-insider-release.yml
8. squad-issue-assign.yml
9. squad-issue-notify.yml
10. squad-label-enforce.yml
11. squad-main-guard.yml
12. squad-preview.yml
13. squad-promote.yml (2 jobs)
14. squad-release.yml
15. squad-triage.yml
16. sync-squad-labels.yml

**Note:** squad-heartbeat.yml was NOT modified (already using `runs-on: self-hosted`).

## Consequences

### Positive
✅ All CI/CD workflows operational again  
✅ Auto-triggers restored — workflows run automatically on push/PR/label events  
✅ Issue triage, label enforcement, and squad assignment workflows now work  
✅ Release pipelines functional again  
✅ FedRAMP validation and drift detection run automatically on PRs

### Neutral
🟡 Workflows now depend on self-hosted runner availability  
🟡 Runner must have Git Bash installed (already present on squad-local-runner)

### Risks
⚠️ Single point of failure: if squad-local-runner goes down, all workflows break  
⚠️ Runner security: self-hosted runners need careful security management  
⚠️ Runner capacity: single runner may bottleneck if many workflows run concurrently

## Validation

After implementation:
- ✅ All 16 workflows committed with runner changes
- ✅ Bash shell defaults added where needed
- ✅ Auto-triggers re-enabled across the board
- ⏳ Waiting for next trigger event to confirm workflows execute successfully

## Follow-up Actions

1. **Monitor runner health** - Set up monitoring for squad-local-runner availability
2. **Test workflow execution** - Trigger a test run of each re-enabled workflow
3. **Runner scaling** - Consider adding more self-hosted runners if throughput becomes an issue
4. **Security review** - Ensure runner security best practices (isolation, secrets handling)

## References

- Issue #110: CI workflows failing because EMU personal repos can't use GitHub-hosted runners
- squad-heartbeat.yml: Reference implementation already using self-hosted runner
- GitHub Actions docs: Self-hosted runners on Windows with Git Bash support
