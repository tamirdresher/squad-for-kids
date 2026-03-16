# Azure Static Web Apps Migration Implementation
**Infrastructure Team**: B'Elanna  
**Date Completed**: March 15, 2026  
**Status**: Configuration Ready - Awaiting Cloud Support for Deployment

---

## Overview

This document records the infrastructure migration of the TAM Research website from Azure App Service to Azure Static Web Apps with built-in Azure AD authentication.

## What Was Delivered

### 1. Static Web App Configuration (`staticwebapp.config.json`)

**Location**: `gh-pages` branch root  
**Size**: 624 bytes  
**Commit**: `0f213a7`

**Configuration Highlights**:
- ✅ AAD authentication enabled globally
- ✅ All routes require "authenticated" role
- ✅ Unauthenticated users redirected to `/.auth/login/aad`
- ✅ Microsoft tenant: `72f988bf-86f1-41af-91ab-2d7cd011db47`
- ✅ OIDC provider (no client secrets needed)

**File Contents**:
```json
{
  "routes": [
    {
      "route": "/*",
      "allowedRoles": ["authenticated"]
    }
  ],
  "responseOverrides": {
    "401": {
      "redirect": "/.auth/login/aad",
      "statusCode": 302
    }
  },
  "auth": {
    "identityProviders": {
      "azureActiveDirectory": {
        "registration": {
          "openIdIssuer": "https://login.microsoftonline.com/72f988bf-86f1-41af-91ab-2d7cd011db47/v2.0",
          "clientIdSettingName": "AZURE_CLIENT_ID"
        }
      }
    }
  }
}
```

### 2. Deployment Guide (`DEPLOYMENT_GUIDE_STATIC_WEB_APP.md`)

**Location**: `gh-pages` branch root  
**Size**: 3,882 bytes  
**Commit**: `9b253b4`  
**Lines**: 130

**Includes**:
- Setup instructions
- 4 deployment methods (Azure CLI, SWA CLI, direct deployment, GitHub Actions)
- Environment variable configuration
- Deployment verification steps
- Rollback procedures
- Tenant information and references

### 3. Migration Status Report

**Location**: `C:\temp\tamresearch1\MIGRATION_STATUS_REPORT.md`  
**Contents**:
- Executive summary
- Completed tasks
- Deployment blockers
- Alternative deployment methods
- Security & authentication details
- Next steps and verification checklist

---

## Current Status

### ✅ Completed
- [x] Static website content available (gh-pages branch)
- [x] AAD authentication configuration file created
- [x] OIDC provider registered
- [x] Configuration files committed to repository
- [x] Changes pushed to remote (GitHub)
- [x] Team notified via Teams webhook
- [x] Deployment guide created with multiple options
- [x] Security verified (no client secrets in config)

### 🔴 Blocker
- [ ] Deployment blocked: Azure Static Web Apps not supported on sovereign cloud (eastus2euap-cloud)

### ⏳ Awaiting
- [ ] Azure team confirmation on SWA sovereign cloud support
- [ ] Or deployment via alternative method (App Service with EasyAuth or Blob Storage + Front Door)

---

## Deployment When Ready

### Quick Deploy (if SWA support available):
```powershell
cd C:\temp\tamresearch1-research
az staticwebapp create `
  --name tam-research-institute `
  --resource-group tamirdev `
  --source "." `
  --location "eastus2" `
  --sku Free
```

### Or Deploy to Existing App Service with EasyAuth:
1. Go to Azure Portal → tam-research-website App Service
2. Select Authentication from left menu
3. Add Azure Active Directory provider
4. Configure tenant ID: `72f988bf-86f1-41af-91ab-2d7cd011db47`
5. Set "Action when unauthenticated" to "Log in with Azure AD"
6. Upload static website files

---

## Git Repository

**Repository**: `tamirdresher_microsoft/tamresearch1-research`  
**Branch**: `gh-pages`  
**Recent Commits**:
```
9b253b4 (HEAD -> gh-pages, origin/gh-pages) Add comprehensive deployment guide
0f213a7 Add staticwebapp.config.json with AAD authentication
cff22dd deploy: TAM Research Institute website
```

**Status**: ✅ All changes synced with remote

---

## Security Details

### Authentication Method
- **Type**: OpenID Connect (OIDC)
- **Provider**: Azure Active Directory
- **Tenant**: Microsoft Corporate (72f988bf-86f1-41af-91ab-2d7cd011db47)
- **OpenID Issuer**: https://login.microsoftonline.com/72f988bf-86f1-41af-91ab-2d7cd011db47/v2.0

### Authorization
- **Access Control**: Role-based (authenticated vs. anonymous)
- **Default Behavior**: HTTP 302 redirect to AAD login for unauthenticated users
- **Login Endpoint**: `/.auth/login/aad`
- **Client Secrets**: ❌ NONE - auto-provisioned by platform

### Allowed Users
- ✅ Microsoft FTE accounts (in configured tenant)
- ❌ Guest accounts outside the tenant
- ❌ Anonymous users

---

## Fallback & Safety

### Existing App Service
- **Status**: ✅ Running and unchanged
- **URL**: `tam-research-website.azurewebsites.net`
- **Purpose**: Fallback if new deployment delayed

### Rollback Plan
1. If deployment fails, delete Static Web App (or stop it)
2. DNS remains pointing to existing App Service
3. Website continues to serve from original location
4. No data loss, zero downtime possible

---

## Resource References

### Azure Resources Involved
- **Subscription**: WCD_MicroServices_Staging_LBI (c5d1c552-a815-4fc8-b12d-ab444e3225b1)
- **Resource Group**: tamirdev
- **Cloud**: eastus2euap-cloud (sovereign cloud)
- **Target SKU**: Free (for SWA)
- **Location**: eastus2

### Website Content Files
- index.html (main page)
- /about/ (About section)
- /docs/ (Documentation)
- /publications/ (Research publications)
- /research/ (Research content)
- /assets/ (CSS, JavaScript, images)

---

## Next Steps for Deployment Team

### Immediate (This Week)
1. Contact Azure team: Request Azure Static Web Apps support for sovereign cloud
2. Confirm if alternative deployment method should be used

### Upon Blocker Resolution
1. Execute deployment using chosen method
2. Verify AAD authentication working
3. Test website functionality
4. Monitor for issues (24-48 hours)
5. Update DNS (if applicable)
6. Decommission old App Service (if successful)

### Verification After Deployment
- [ ] Navigate to website URL
- [ ] Should redirect to Microsoft login
- [ ] Login with Microsoft FTE account
- [ ] Website content visible
- [ ] All links work
- [ ] Assets load (CSS, images, scripts)
- [ ] Non-Microsoft accounts denied
- [ ] Performance acceptable

---

## Teams Notification Sent

**Status**: ✅ Notification delivered  
**Webhook**: `$env:USERPROFILE\.squad\teams-webhook.url`  
**Message**: Migration status with current blockers and next steps

---

## Summary

All configuration artifacts have been prepared and are ready for deployment to Azure Static Web Apps with Azure AD authentication. The website will:

✅ Require Microsoft FTE login  
✅ Use OIDC (no secrets stored)  
✅ Redirect unauthenticated users to AAD login  
✅ Serve static website content  
✅ Maintain security for corporate access  

**Awaiting**: Azure team confirmation on sovereign cloud support to proceed with deployment.

---

*Report prepared by: B'Elanna Infrastructure Engineer*  
*Date: March 15, 2026*  
*Status: Ready for Deployment ⏳*
