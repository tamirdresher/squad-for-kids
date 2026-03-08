# FedRAMP Dashboard Cache Alert - Deployment Guide

**Issue:** #113  
**Owner:** B'Elanna (Infrastructure Expert)  
**Status:** Ready for Deployment  
**Created:** March 2026

---

## Overview

This guide provides step-by-step instructions for deploying the FedRAMP Dashboard cache hit rate alert to all environments (dev → stg → prod). This deployment was prepared as part of Issue #113, following the merge of PR #108.

## Prerequisites

### Required Access
- ✅ Azure CLI installed and authenticated
- ✅ Contributor or Owner role on target subscription
- ✅ Access to FedRAMP Dashboard resource groups (dev, stg, prod)
- ✅ Permissions to manage alerts and action groups

### Verification Commands
```powershell
# Verify Azure CLI authentication
az account show

# List available subscriptions
az account list --output table

# Verify resource group access
az group show --name rg-fedramp-dashboard-dev
az group show --name rg-fedramp-dashboard-stg
az group show --name rg-fedramp-dashboard-prod
```

---

## Deployment Resources

### Files Required
1. **Bicep Template:** `infrastructure/phase4-cache-alert.bicep`
   - Defines the cache hit rate alert rule
   - Configures 70% threshold with 15-minute window
   - Routes to PagerDuty via Action Group

2. **Deployment Script:** `infrastructure/deploy-cache-alert.ps1`
   - PowerShell automation with validation
   - Environment-aware (dev/stg/prod)
   - Post-deployment verification

### Pre-Deployment Checklist

Before deploying to each environment, verify:

- [ ] **Application Insights exists:** `appi-fedramp-dashboard-{env}`
- [ ] **Action Group exists:** `fedramp-oncall-{env}`
- [ ] **PagerDuty integration** configured on Action Group
- [ ] **Bicep template** validated locally
- [ ] **Resource group** is accessible

---

## Deployment Procedure

### Phase 1: Development Environment (DEV)

**Purpose:** Validate deployment process and alert configuration in non-production.

```powershell
# Set working directory
cd C:\temp\tamresearch1

# Run deployment script
.\infrastructure\deploy-cache-alert.ps1 -Environment dev

# Expected output:
# ✓ Template validation passed
# ✓ Alert deployed successfully!
# ✓ Alert is ENABLED and monitoring cache hit rate
```

**Post-Deployment Verification:**
1. Navigate to Azure Portal → Monitor → Alerts → Alert Rules
2. Search for: `FedRAMP-Dashboard-Cache-Hit-Rate-Low-dev`
3. Verify:
   - Status: **Enabled**
   - Severity: **2 (Warning)**
   - Evaluation Frequency: **5 minutes**
   - Window Size: **15 minutes**
   - Threshold: **70%**
   - Action Group: **fedramp-oncall-dev**

**Testing (Optional):**
```powershell
# Simulate low cache hit rate (requires test script)
# This step is optional but recommended for dev
.\scripts\test-cache-alert.ps1 -Environment dev
```

**Sign-Off:**
- [ ] Alert deployed and enabled
- [ ] Verified in Azure Portal
- [ ] (Optional) Test alert fired successfully

---

### Phase 2: Staging Environment (STG)

**Purpose:** Final validation before production deployment.

**Timing:** Deploy 24-48 hours after dev deployment.

```powershell
# Run deployment script
.\infrastructure\deploy-cache-alert.ps1 -Environment stg

# Expected output:
# ✓ Template validation passed
# ✓ Alert deployed successfully!
# ✓ Alert is ENABLED and monitoring cache hit rate
```

**Post-Deployment Verification:**
1. Azure Portal → Monitor → Alerts → Alert Rules
2. Search for: `FedRAMP-Dashboard-Cache-Hit-Rate-Low-stg`
3. Verify configuration matches dev

**Validation Period:**
- Monitor for 2-3 days for false positives
- Review any triggered alerts
- Adjust threshold if needed (update Bicep, redeploy)

**Sign-Off:**
- [ ] Alert deployed and enabled
- [ ] Verified in Azure Portal
- [ ] No false positives observed

---

### Phase 3: Production Environment (PROD)

**Purpose:** Enable production monitoring with validated configuration.

**Timing:** Deploy after successful stg validation (2-3 days minimum).

**Prerequisites:**
- [ ] Dev deployment successful
- [ ] Stg deployment successful and validated
- [ ] No outstanding issues with alert configuration
- [ ] Change management approval (if required)

```powershell
# Run deployment script
.\infrastructure\deploy-cache-alert.ps1 -Environment prod

# Expected output:
# ✓ Template validation passed
# ✓ Alert deployed successfully!
# ✓ Alert is ENABLED and monitoring cache hit rate
```

**Post-Deployment Verification:**
1. Azure Portal → Monitor → Alerts → Alert Rules
2. Search for: `FedRAMP-Dashboard-Cache-Hit-Rate-Low-prod`
3. Verify configuration matches stg
4. Confirm PagerDuty integration working
5. Notify on-call team of new alert

**Production Communication:**
```markdown
**Subject:** New FedRAMP Dashboard Cache Alert - Production

Team,

A new Application Insights alert has been deployed to production:

**Alert Name:** FedRAMP Dashboard - Cache Hit Rate Below 70%
**Severity:** 2 (Warning)
**Trigger:** Cache hit rate < 70% for 15 minutes
**Action:** PagerDuty notification via fedramp-oncall-prod

**Runbook:** https://github.com/tamirdresher_microsoft/tamresearch1/blob/main/docs/fedramp-dashboard-cache-sli.md#42-remediation-playbook

This alert monitors API response caching efficiency. If you receive this alert:
1. Check Application Insights for cache hit rate trends
2. Review runbook for 6 remediation paths
3. Escalate if hit rate remains below 70% after 30 minutes

Questions? See docs/fedramp-dashboard-cache-sli.md
```

**Sign-Off:**
- [ ] Alert deployed and enabled
- [ ] Verified in Azure Portal
- [ ] On-call team notified
- [ ] Issue #113 updated with deployment status

---

## Rollback Procedure

If the alert causes issues (excessive false positives, incorrect configuration):

```powershell
# Disable alert (do not delete)
az monitor scheduled-query update \
  --resource-group rg-fedramp-dashboard-{env} \
  --name FedRAMP-Dashboard-Cache-Hit-Rate-Low-{env} \
  --enabled false

# Or delete alert completely
az monitor scheduled-query delete \
  --resource-group rg-fedramp-dashboard-{env} \
  --name FedRAMP-Dashboard-Cache-Hit-Rate-Low-{env} \
  --yes
```

**When to Disable (Not Delete):**
- Temporary issue with alert logic
- Configuration needs adjustment
- False positive storm

**When to Delete:**
- Alert is fundamentally flawed
- Replacing with new implementation
- Feature being deprecated

---

## Known Issues & Workarounds

### Issue #110: CI/CD Runner Provisioning Failure

**Status:** Open  
**Impact:** GitHub Actions workflows cannot deploy automatically  
**Workaround:** Manual deployment using PowerShell script (this guide)

**Actions:**
1. Use manual deployment procedure above
2. Monitor #110 for resolution
3. Once resolved, update deployment to use GitHub Actions workflow

### Missing Action Group

**Symptom:** Deployment fails with "Action Group not found"

**Resolution:**
```powershell
# Create Action Group (if missing)
az monitor action-group create \
  --resource-group rg-fedramp-dashboard-{env} \
  --name fedramp-oncall-{env} \
  --short-name fd-oncall \
  --action email fedramp-team fedramp-oncall@contoso.com

# Then re-run deployment script
```

### Missing Application Insights

**Symptom:** Deployment fails with "Application Insights not found"

**Resolution:**
1. Verify correct resource group and subscription
2. Check Application Insights name matches convention: `appi-fedramp-dashboard-{env}`
3. If resource exists with different name, update script parameter:
   ```powershell
   .\infrastructure\deploy-cache-alert.ps1 `
     -Environment prod `
     -ResourceGroupName "rg-custom-name"
   ```

---

## Post-Deployment Actions

After deploying to all environments:

### 1. Update Documentation
- [ ] Mark deployment complete in Issue #113
- [ ] Update `docs/fedramp-dashboard-cache-sli.md` with deployment dates
- [ ] Add alert details to operational runbook

### 2. Schedule Monthly Reviews
- [ ] Create GitHub Issue for April 2026 review (first Tuesday, 10 AM PT)
- [ ] Set up recurring reminder (calendar invite or issue template)
- [ ] Assign Data (Code Expert) and Infrastructure Lead

### 3. Monitor Initial Period
- [ ] Watch for alerts in first 7 days
- [ ] Review false positive rate
- [ ] Adjust threshold if needed (redeploy with updated Bicep)

### 4. Close Issue #113
- [ ] Verify all deployment phases complete
- [ ] Confirm monthly review scheduled
- [ ] Add comment with deployment summary
- [ ] Close issue with `gh issue close 113`

---

## Quick Reference

### Deployment Commands (TL;DR)

```powershell
# Dev
.\infrastructure\deploy-cache-alert.ps1 -Environment dev

# Stg (wait 24-48 hours after dev)
.\infrastructure\deploy-cache-alert.ps1 -Environment stg

# Prod (wait 2-3 days after stg)
.\infrastructure\deploy-cache-alert.ps1 -Environment prod
```

### Verification Query

```powershell
# List all cache alerts across environments
az monitor scheduled-query list \
  --resource-group rg-fedramp-dashboard-dev \
  --query "[?contains(name, 'Cache')].{Name:name, Enabled:enabled}" \
  --output table
```

### Alert Dashboard

**Azure Portal Quick Link:**
```
https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/alertsV2
```

Filter by:
- Resource group: `rg-fedramp-dashboard-*`
- Alert name contains: `Cache-Hit-Rate`

---

## Support & Escalation

**Primary Contact:** B'Elanna (Infrastructure Expert)  
**Secondary Contact:** Data (Code Expert, alert creator)  
**Escalation:** Picard (Engineering Manager)

**Reference Documentation:**
- Cache SLI: `docs/fedramp-dashboard-cache-sli.md`
- Deployment Runbook: `docs/fedramp/phase5-rollout/deployment-runbook.md`
- Issue #113: Post-merge deployment tracking

---

**Document Version:** 1.0  
**Last Updated:** March 2026  
**Status:** Ready for Execution
