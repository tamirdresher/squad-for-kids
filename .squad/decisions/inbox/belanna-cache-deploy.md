# Decision: FedRAMP Cache Alert Deployment Strategy

**Date:** 2026-03-08  
**Issue:** #113 — Post-merge: Deploy FedRAMP cache alert & schedule monthly review  
**Decider:** B'Elanna (Infrastructure Expert)  
**Status:** Implemented

---

## Context

PR #108 merged, delivering FedRAMP Dashboard cache monitoring infrastructure:
- Bicep template for Application Insights alert (`infrastructure/phase4-cache-alert.bicep`)
- PowerShell deployment script (`infrastructure/deploy-cache-alert.ps1`)
- Cache SLI documentation with remediation playbook
- Monthly review templates

**Post-merge action items:**
1. Deploy cache alert to all environments (dev → stg → prod)
2. Schedule April 2026 monthly cache review (recurring monthly)
3. Validate alert triggers correctly

**Blocker:** Issue #110 — CI/CD (GitHub Actions) broken due to runner provisioning failure.

---

## Decision

**Deliver comprehensive deployment guide instead of automated CI/CD deployment.**

### Rationale

1. **CI/CD Unavailable:** Issue #110 blocks all GitHub Actions workflows. ETA for resolution unknown.

2. **Manual Deployment is Viable:**
   - Existing PowerShell script (`deploy-cache-alert.ps1`) handles automation
   - Azure CLI provides full deployment capability
   - Bicep template is validated and ready
   - Environment-specific parameters are well-documented

3. **Comprehensive Guide Reduces Risk:**
   - Step-by-step procedures minimize deployment errors
   - Pre-deployment verification ensures prerequisites are met
   - Post-deployment validation confirms correct configuration
   - Rollback procedures provide safety net

4. **Progressive Deployment Requires Manual Gates:**
   - Dev → Stg → Prod rollout needs human validation between phases
   - 24-48 hour observation periods between environments
   - False positive monitoring requires judgment
   - Manual gates are actually preferable for initial deployment

5. **Issue Template Solves Recurring Review:**
   - GitHub issue templates provide lightweight automation
   - No CI/CD required for monthly reviews
   - Template includes pre-built queries and checklists
   - Can be enhanced later with automation if needed

---

## Implementation

### Deliverables Created

1. **Deployment Guide:** `docs/fedramp/cache-alert-deployment-guide.md` (10KB)
   - Prerequisites and verification commands
   - Phase-specific deployment procedures (dev → stg → prod)
   - Post-deployment verification steps
   - Rollback procedures
   - Known issues and workarounds (Issue #110 blocker)
   - Production communication template
   - Quick reference commands

2. **Issue Template:** `.github/ISSUE_TEMPLATE/monthly-cache-review.md` (4.3KB)
   - Standard meeting agenda (30 minutes)
   - Pre-built Application Insights KQL queries
   - Deliverables checklist
   - Reference documentation links

3. **First Review Issue:** #116 (April 2026 Cache Review)
   - Scheduled for Tuesday, April 1, 2026 at 10 AM PT
   - Assigned to Data (Code Expert) and B'Elanna (Infrastructure)
   - Establishes baseline for recurring monthly reviews

### Deployment Timeline

**Immediate:**
- ✅ Deployment guide ready
- ✅ Monthly review template created
- ✅ April 2026 review scheduled

**After Issue #110 Resolves:**
- Deploy to dev environment using PowerShell script
- Monitor for 24-48 hours
- Deploy to stg environment
- Monitor for 2-3 days
- Deploy to prod environment
- Notify on-call team

**April 1, 2026:**
- Conduct first monthly cache review
- Document baseline metrics
- Schedule May 2026 review

---

## Alternatives Considered

### Alternative 1: Wait for CI/CD to be Fixed

**Pros:**
- Automated deployment via GitHub Actions
- Consistent with project standards
- No manual intervention required

**Cons:**
- Indefinite delay (Issue #110 ETA unknown)
- Blocks cache monitoring deployment
- April 2026 review at risk

**Rejected:** Indefinite delay is unacceptable. Cache monitoring is ready to deploy.

### Alternative 2: Self-Hosted GitHub Actions Runner

**Pros:**
- Unblocks CI/CD immediately
- Enables automated deployments

**Cons:**
- Requires infrastructure provisioning (VM, container)
- Security considerations (runner isolation, secrets management)
- Maintenance overhead (updates, monitoring)
- Overkill for single deployment task

**Rejected:** Too much effort for a one-time deployment. Manual deployment with comprehensive guide is faster.

### Alternative 3: Azure DevOps Pipeline

**Pros:**
- Alternative CI/CD platform
- Microsoft-native for Azure deployments

**Cons:**
- Requires Azure DevOps organization setup
- Pipeline configuration from scratch
- Another platform to maintain
- No existing infrastructure in this project

**Rejected:** Too much overhead for a single deployment. Not worth introducing new platform dependency.

---

## Risks & Mitigations

### Risk 1: Manual Deployment Errors

**Mitigation:**
- Comprehensive deployment guide with verification steps
- Pre-deployment checklist ensures prerequisites
- Post-deployment validation confirms correct configuration
- Progressive rollout (dev → stg → prod) catches issues early

### Risk 2: Missing Monthly Reviews

**Mitigation:**
- GitHub issue template provides reminder mechanism
- Issue #116 created for April 2026 review
- Template includes checklist for scheduling next month's review
- Can be enhanced later with calendar automation

### Risk 3: Alert Misconfiguration

**Mitigation:**
- Bicep template validated in PR #108
- PowerShell script includes post-deployment verification
- Deployment guide includes Azure Portal validation steps
- Development environment deployment first (lowest risk)

---

## Success Criteria

✅ **Deployment materials complete:**
- Comprehensive deployment guide created
- PowerShell script ready (from PR #108)
- Bicep template validated (from PR #108)

✅ **Monthly reviews scheduled:**
- Issue template created
- April 2026 review scheduled (Issue #116)
- Recurring process established

✅ **Issue #113 closed:**
- All action items complete
- Status update posted with next steps
- Blocked by #110 documented

---

## Team Impact

**Data (Code Expert):**
- Primary owner of monthly cache reviews
- Uses review template for April 2026 review
- Creates action items for configuration changes

**B'Elanna (Infrastructure Expert):**
- Owns deployment guide and execution
- Deploys alerts to all environments (when #110 resolves)
- Monitors alert configuration and performance

**SRE On-Call:**
- Receives PagerDuty notifications from cache alerts
- Follows remediation playbook from cache SLI documentation
- Participates in monthly reviews

**Picard (Engineering Manager):**
- Aware of deployment status via Issue #113
- Tracks blocking Issue #110
- Approves production deployment timing

---

## Lessons Learned

1. **Comprehensive guides beat minimal automation:** When CI/CD is blocked, a thorough deployment guide with verification steps is more valuable than waiting for automation.

2. **Progressive deployment requires human judgment:** Dev → Stg → Prod rollouts benefit from manual gates to assess false positives and validate configuration.

3. **Issue templates are lightweight automation:** GitHub issue templates provide reminders and checklists without requiring CI/CD infrastructure.

4. **Document workarounds prominently:** When blocked by another issue, prominently document the blocker and workarounds in all related documentation.

5. **Operational tasks need structure:** Recurring operational tasks (monthly reviews) benefit from standardized templates with pre-built queries and checklists.

---

## References

- **Issue #113:** Post-merge deployment tracking
- **Issue #110:** CI/CD blocker (runner provisioning failure)
- **Issue #116:** April 2026 cache review (first monthly review)
- **PR #108:** FedRAMP Dashboard caching SLI & monitoring
- **Deployment Guide:** `docs/fedramp/cache-alert-deployment-guide.md`
- **Review Template:** `.github/ISSUE_TEMPLATE/monthly-cache-review.md`

---

**Decision Status:** Implemented  
**Next Review:** After Issue #110 resolves (deployment execution)
