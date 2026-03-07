# FedRAMP Dashboard: RBAC Configuration Guide

**Document Version:** 1.0  
**Last Updated:** 2026-03-08  
**Owner:** Platform Security Team  

---

## 1. Overview

This document provides the complete RBAC (Role-Based Access Control) configuration for the FedRAMP Security Dashboard API. It includes Azure AD setup instructions, security group management, and permission validation procedures.

---

## 2. Role Definitions

### 2.1 Security Admin

**Azure AD Security Group:** `FedRAMP-SecurityAdmin`

**Responsibilities:**
- Full administrative access to the FedRAMP Dashboard
- Manage RBAC role assignments
- Configure alert rules and thresholds
- Access to all endpoints and operations
- Audit log review and compliance reporting

**Permissions:**
- ✅ `Dashboard.Read`
- ✅ `Controls.Read`
- ✅ `Analytics.Read`
- ✅ `Reports.Export`
- ✅ `Admin.Full`

**Typical Users:**
- Platform Security leadership
- Security architects
- Incident commanders (during P0 incidents)

---

### 2.2 Security Engineer

**Azure AD Security Group:** `FedRAMP-SecurityEngineer`

**Responsibilities:**
- Daily security operations
- Validation test authoring and maintenance
- Investigate compliance failures
- Generate compliance reports for team review
- Monitor control drift and trends

**Permissions:**
- ✅ `Dashboard.Read`
- ✅ `Controls.Read`
- ✅ `Analytics.Read`
- ✅ `Reports.Export`
- ❌ `Admin.Full`

**Typical Users:**
- Security engineers
- Compliance engineers
- SecOps team members

---

### 2.3 SRE (Site Reliability Engineer)

**Azure AD Security Group:** `FedRAMP-SRE`

**Responsibilities:**
- Monitor operational dashboards
- Configure alerts for compliance failures
- Read-only access to control validation data
- Investigate alert root causes
- Correlate compliance status with system health

**Permissions:**
- ✅ `Dashboard.Read`
- ✅ `Controls.Read`
- ✅ `Analytics.Read`
- ❌ `Reports.Export`
- ❌ `Admin.Full`

**Typical Users:**
- Site reliability engineers
- On-call responders
- Platform operations team

---

### 2.4 Ops Viewer

**Azure AD Security Group:** `FedRAMP-OpsViewer`

**Responsibilities:**
- View real-time compliance dashboards
- Monitor overall compliance status
- Read-only access to environment summaries
- No access to detailed control data or analytics

**Permissions:**
- ✅ `Dashboard.Read`
- ❌ `Controls.Read`
- ❌ `Analytics.Read`
- ❌ `Reports.Export`
- ❌ `Admin.Full`

**Typical Users:**
- Operations managers
- Engineering leadership (read-only view)
- Stakeholders requiring compliance visibility

---

### 2.5 Auditor

**Azure AD Security Group:** `FedRAMP-Auditor`

**Responsibilities:**
- Export compliance reports for audit documentation
- No access to real-time dashboards
- Generate historical compliance reports (30-90 days)
- Compliance report analysis for audit submissions

**Permissions:**
- ❌ `Dashboard.Read`
- ❌ `Controls.Read`
- ❌ `Analytics.Read`
- ✅ `Reports.Export`
- ❌ `Admin.Full`

**Typical Users:**
- External auditors (FedRAMP assessment teams)
- Internal compliance officers
- Audit documentation specialists

---

## 3. Permission Matrix

| Endpoint | Permission | Security Admin | Security Engineer | SRE | Ops Viewer | Auditor |
|----------|------------|:--------------:|:-----------------:|:---:|:----------:|:-------:|
| `GET /api/v1/compliance/status` | `Dashboard.Read` | ✅ | ✅ | ✅ | ✅ | ❌ |
| `GET /api/v1/compliance/trend` | `Dashboard.Read` | ✅ | ✅ | ✅ | ✅ | ❌ |
| `GET /api/v1/controls/{id}/validation-results` | `Controls.Read` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `GET /api/v1/environments/{env}/summary` | `Dashboard.Read` | ✅ | ✅ | ✅ | ✅ | ❌ |
| `GET /api/v1/history/control-drift` | `Analytics.Read` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `GET /api/v1/reports/compliance-export` | `Reports.Export` | ✅ | ✅ | ❌ | ❌ | ✅ |

---

## 4. Azure AD Configuration

### 4.1 App Registration Setup

#### Step 1: Create App Registration

1. Navigate to **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Click **New registration**
3. Configure:
   - **Name:** `FedRAMP-Dashboard-API`
   - **Supported account types:** Single tenant (your organization only)
   - **Redirect URI:** `https://fedramp-dashboard-api-prod.azurewebsites.net/.auth/login/aad/callback`
4. Click **Register**
5. Note the **Application (client) ID** and **Directory (tenant) ID**

#### Step 2: Expose API Scopes

1. In the app registration, navigate to **Expose an API**
2. Click **Add a scope**
3. Set **Application ID URI:** `api://fedramp-dashboard`
4. Add the following scopes:

| Scope Name | Admin Consent Display Name | Admin Consent Description |
|------------|---------------------------|---------------------------|
| `Dashboard.Read` | Read dashboard data | Allows reading compliance dashboard data |
| `Controls.Read` | Read control validation results | Allows reading control validation test results |
| `Analytics.Read` | Read analytics data | Allows reading compliance analytics and drift detection |
| `Reports.Export` | Export compliance reports | Allows exporting compliance reports |

#### Step 3: Configure Token Claims

1. Navigate to **Token configuration**
2. Click **Add groups claim**
3. Select **Security groups**
4. In token type, select **ID** and **Access**
5. Click **Add**

This ensures security group membership is included in JWT tokens as `roles` claim.

---

### 4.2 Security Group Setup

#### Create Security Groups

Run the following Azure CLI commands to create the required security groups:

```bash
# Security Admin group
az ad group create \
  --display-name "FedRAMP-SecurityAdmin" \
  --mail-nickname "FedRAMP-SecurityAdmin" \
  --description "Full administrative access to FedRAMP Dashboard"

# Security Engineer group
az ad group create \
  --display-name "FedRAMP-SecurityEngineer" \
  --mail-nickname "FedRAMP-SecurityEngineer" \
  --description "Security operations access to FedRAMP Dashboard"

# SRE group
az ad group create \
  --display-name "FedRAMP-SRE" \
  --mail-nickname "FedRAMP-SRE" \
  --description "Site reliability engineer access to FedRAMP Dashboard"

# Ops Viewer group
az ad group create \
  --display-name "FedRAMP-OpsViewer" \
  --mail-nickname "FedRAMP-OpsViewer" \
  --description "Read-only dashboard access for operations"

# Auditor group
az ad group create \
  --display-name "FedRAMP-Auditor" \
  --mail-nickname "FedRAMP-Auditor" \
  --description "Compliance report export access for auditors"
```

#### Add Users to Groups

```bash
# Example: Add user to Security Admin group
az ad group member add \
  --group "FedRAMP-SecurityAdmin" \
  --member-id <user-object-id>

# Example: Add user to Security Engineer group
az ad group member add \
  --group "FedRAMP-SecurityEngineer" \
  --member-id <user-object-id>
```

#### Verify Group Membership

```bash
# List all members of a group
az ad group member list \
  --group "FedRAMP-SecurityAdmin" \
  --query "[].{displayName:displayName, userPrincipalName:userPrincipalName}"
```

---

### 4.3 App Role Assignments

#### Assign Groups to App Registration

1. Navigate to **Azure Portal** → **Enterprise applications**
2. Find and select `FedRAMP-Dashboard-API`
3. Navigate to **Users and groups**
4. Click **Add user/group**
5. Select the security group (e.g., `FedRAMP-SecurityAdmin`)
6. Assign the appropriate app role
7. Repeat for all 5 security groups

---

## 5. API Configuration

### 5.1 appsettings.json

**Production Configuration:**

```json
{
  "AzureAd": {
    "Instance": "https://login.microsoftonline.com/",
    "TenantId": "<your-tenant-guid>",
    "ClientId": "<app-registration-client-id>",
    "Audience": "api://fedramp-dashboard"
  }
}
```

**Environment-Specific Settings:**

- **Production:** `appsettings.Production.json`
- **Staging:** `appsettings.Staging.json`
- **Development:** Use `dotnet user-secrets` (never commit credentials)

### 5.2 Authorization Policies

**Implementation in Program.cs:**

```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("Dashboard.Read", policy =>
        policy.RequireRole(
            "FedRAMP.SecurityAdmin",
            "FedRAMP.SecurityEngineer",
            "FedRAMP.SRE",
            "FedRAMP.OpsViewer"));

    options.AddPolicy("Controls.Read", policy =>
        policy.RequireRole(
            "FedRAMP.SecurityAdmin",
            "FedRAMP.SecurityEngineer",
            "FedRAMP.SRE"));

    options.AddPolicy("Analytics.Read", policy =>
        policy.RequireRole(
            "FedRAMP.SecurityAdmin",
            "FedRAMP.SecurityEngineer",
            "FedRAMP.SRE"));

    options.AddPolicy("Reports.Export", policy =>
        policy.RequireRole(
            "FedRAMP.SecurityAdmin",
            "FedRAMP.SecurityEngineer",
            "FedRAMP.Auditor"));

    options.AddPolicy("Admin.Full", policy =>
        policy.RequireRole("FedRAMP.SecurityAdmin"));
});
```

---

## 6. Testing RBAC

### 6.1 Obtain Azure AD Token

**Using Azure CLI:**

```bash
# Get access token for the API
az account get-access-token \
  --resource api://fedramp-dashboard \
  --query accessToken -o tsv
```

**Using PowerShell:**

```powershell
# Get access token
$token = (Get-AzAccessToken -ResourceUrl "api://fedramp-dashboard").Token
```

### 6.2 Test API Endpoints

**Test as Security Admin:**

```bash
TOKEN="<your-jwt-token>"

# Should succeed (Dashboard.Read)
curl -H "Authorization: Bearer $TOKEN" \
  "https://fedramp-dashboard-api-prod.azurewebsites.net/api/v1/compliance/status"

# Should succeed (Controls.Read)
curl -H "Authorization: Bearer $TOKEN" \
  "https://fedramp-dashboard-api-prod.azurewebsites.net/api/v1/controls/SC-7/validation-results"

# Should succeed (Reports.Export)
curl -H "Authorization: Bearer $TOKEN" \
  "https://fedramp-dashboard-api-prod.azurewebsites.net/api/v1/reports/compliance-export?format=json&startDate=2026-03-01T00:00:00Z&endDate=2026-03-08T00:00:00Z"
```

**Test as Auditor:**

```bash
TOKEN="<auditor-jwt-token>"

# Should fail (403 Forbidden - no Dashboard.Read permission)
curl -H "Authorization: Bearer $TOKEN" \
  "https://fedramp-dashboard-api-prod.azurewebsites.net/api/v1/compliance/status"

# Should succeed (Reports.Export)
curl -H "Authorization: Bearer $TOKEN" \
  "https://fedramp-dashboard-api-prod.azurewebsites.net/api/v1/reports/compliance-export?format=csv&startDate=2026-03-01T00:00:00Z&endDate=2026-03-08T00:00:00Z"
```

### 6.3 Verify Role Claims in JWT

**Decode JWT token:**

```bash
# Use https://jwt.ms or jwt.io to decode the token
# Verify the "roles" claim contains expected group names:
{
  "roles": [
    "FedRAMP.SecurityAdmin"
  ],
  "aud": "api://fedramp-dashboard",
  "iss": "https://login.microsoftonline.com/<tenant-id>/v2.0",
  ...
}
```

---

## 7. Role Management Procedures

### 7.1 Onboarding New Users

**Security Admin Process:**

1. Verify user identity and approval documentation
2. Determine appropriate role based on job function
3. Add user to corresponding Azure AD security group:
   ```bash
   az ad group member add \
     --group "FedRAMP-SecurityEngineer" \
     --member-id <user-object-id>
   ```
4. Notify user of access grant
5. Log access grant in audit system

**Approval Requirements:**

| Role | Approver | Documentation Required |
|------|----------|------------------------|
| Security Admin | CISO or Security Director | Written approval + justification |
| Security Engineer | Security Manager | Email approval |
| SRE | SRE Manager | Email approval |
| Ops Viewer | Engineering Manager | Email approval |
| Auditor | Compliance Manager | Audit engagement documentation |

### 7.2 Offboarding Users

**Immediate Removal Triggers:**
- User role change (no longer requires access)
- User termination
- End of audit engagement (for Auditors)

**Offboarding Process:**

1. Remove user from Azure AD security group:
   ```bash
   az ad group member remove \
     --group "FedRAMP-SecurityEngineer" \
     --member-id <user-object-id>
   ```
2. Verify token revocation (user must re-authenticate)
3. Log access removal in audit system
4. Review audit logs for user's recent activity

### 7.3 Periodic Access Reviews

**Quarterly Review Process:**

1. Security Admin exports all group memberships:
   ```bash
   az ad group member list --group "FedRAMP-SecurityAdmin" -o table
   az ad group member list --group "FedRAMP-SecurityEngineer" -o table
   az ad group member list --group "FedRAMP-SRE" -o table
   az ad group member list --group "FedRAMP-OpsViewer" -o table
   az ad group member list --group "FedRAMP-Auditor" -o table
   ```
2. Managers review and confirm each user still requires access
3. Remove users who no longer need access
4. Document review completion in compliance system

---

## 8. Troubleshooting

### 8.1 Common Issues

#### Issue: 401 Unauthorized

**Symptoms:** API returns 401 status code

**Possible Causes:**
- Missing `Authorization` header
- Expired JWT token
- Invalid token signature
- Token audience mismatch

**Resolution:**
1. Verify token is included in request header:
   ```
   Authorization: Bearer <jwt-token>
   ```
2. Check token expiration (tokens typically expire after 1 hour)
3. Verify token audience matches `api://fedramp-dashboard`
4. Re-authenticate to obtain fresh token

#### Issue: 403 Forbidden

**Symptoms:** API returns 403 status code with "Insufficient permissions" message

**Possible Causes:**
- User not in required Azure AD security group
- Security group not assigned to app registration
- Missing role claims in JWT token

**Resolution:**
1. Verify user is member of correct security group:
   ```bash
   az ad group member check \
     --group "FedRAMP-SecurityEngineer" \
     --member-id <user-object-id>
   ```
2. Check JWT token for `roles` claim using https://jwt.ms
3. Verify security group is assigned to app registration in Enterprise Apps
4. Wait 5-10 minutes for Azure AD cache refresh after group membership changes

#### Issue: Missing Role Claims in Token

**Symptoms:** JWT token does not contain `roles` claim

**Possible Causes:**
- Token configuration incomplete in app registration
- Security groups not exposed as app roles

**Resolution:**
1. Verify **Token configuration** in app registration includes "groups" claim
2. Ensure groups are assigned to app registration in **Enterprise applications**
3. Re-authenticate to obtain fresh token with updated claims

---

## 9. Audit & Compliance

### 9.1 Audit Logging

**Logged Events:**
- API authentication attempts (success/failure)
- Authorization failures (403 responses)
- Report export operations (including user identity and report parameters)
- Role assignment changes in Azure AD

**Log Retention:** 90 days (Azure AD audit logs), 2 years (Application Insights)

### 9.2 Compliance Reports

**Quarterly RBAC Compliance Report:**

**Contents:**
1. List of all users with FedRAMP Dashboard access
2. Role assignments by user
3. Recent access changes (adds/removes in last quarter)
4. Failed authorization attempts summary
5. Recommendations for access optimization

**Generated by:** Security Admin  
**Reviewed by:** Compliance Manager  
**Submitted to:** CISO

---

## 10. Contact & Support

**Security Team:** platform-security@contoso.com  
**SRE On-Call:** sre-oncall@contoso.com  
**Compliance Team:** compliance@contoso.com

**Emergency Access Issues:** Contact SRE on-call via PagerDuty

---

**Document End**
