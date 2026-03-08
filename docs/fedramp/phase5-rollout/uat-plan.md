# FedRAMP Dashboard: User Acceptance Testing (UAT) Plan

**Phase:** 5 of 5  
**Document Version:** 1.0  
**Owner:** B'Elanna Torres (Infrastructure Expert)  
**Issue:** #88  
**Date:** March 2026  
**Status:** Ready for UAT  

---

## 1. Executive Summary

This UAT plan validates the complete FedRAMP Security Dashboard (Phases 1-4) across all stakeholder roles. UAT confirms that the system meets functional requirements, performance targets, security controls, and usability standards before production rollout.

**Scope:**
- Phase 1: Data Pipeline (Cosmos DB, Azure Functions, Event Grid)
- Phase 2: REST API with RBAC (6 endpoints, 5 roles)
- Phase 3: React UI (4 pages, Material-UI, Recharts)
- Phase 4: Alerting (6 alert types, PagerDuty, Teams, Azure Monitor)

**UAT Environment:** STG (Staging) - Full production parity with synthetic data  
**Duration:** 5 business days  
**Success Criteria:** 100% critical scenarios pass, < 5% non-critical defects  

---

## 2. Test Scenarios by Role

### 2.1 Security Admin (Full Control)

**User:** security-admin@contoso.com  
**Permissions:** READ, WRITE, DELETE, CONFIGURE, AUDIT  

#### Scenario SA-01: Dashboard Overview & Compliance Trends
**Objective:** Verify Security Admin can view overall compliance status and trends

**Prerequisites:**
- User logged in with security-admin role
- At least 30 days of validation results in Cosmos DB

**Steps:**
1. Navigate to Dashboard Overview page
2. Verify "Compliance Overview" widget displays:
   - Overall compliance rate (%)
   - P0 controls passing count
   - P1 controls passing count
   - Trend chart (last 30 days)
3. Click on "Network Policy" control category
4. Verify drill-down to Network Policy detail page
5. Verify environment filter (DEV, STG, PROD) updates charts

**Expected Results:**
- ✅ Compliance rate displayed within 2 seconds
- ✅ Trend chart renders with 30 data points
- ✅ Environment filter updates data without page reload
- ✅ No console errors or API failures

**Acceptance Criteria:**
- [ ] All widgets load within 2 seconds
- [ ] Compliance rate matches Log Analytics query (±1%)
- [ ] Trend chart is interactive (hover shows tooltips)
- [ ] Environment filter works correctly

---

#### Scenario SA-02: Alert Configuration & Testing
**Objective:** Verify Security Admin can configure and test alert rules

**Prerequisites:**
- User logged in with security-admin role
- Alert rules deployed from Phase 4

**Steps:**
1. Navigate to Settings → Alert Configuration
2. Modify "Control Drift Detection" alert threshold from 90% to 85%
3. Click "Save Configuration"
4. Trigger test alert via "Send Test Alert" button
5. Verify test alert appears in Teams channel (#fedramp-uat)
6. Acknowledge alert in UI
7. Verify alert status changes to "Acknowledged"

**Expected Results:**
- ✅ Configuration saved successfully (API returns 200)
- ✅ Test alert delivered to Teams within 60 seconds
- ✅ Alert includes correct metadata (environment, control ID, threshold)
- ✅ Acknowledgment updates Redis cache and UI

**Acceptance Criteria:**
- [ ] Alert configuration persists after page refresh
- [ ] Test alert delivered within 60 seconds
- [ ] Alert acknowledgment reflected in UI immediately
- [ ] No duplicate alerts sent

---

#### Scenario SA-03: User Management & RBAC
**Objective:** Verify Security Admin can manage user roles and permissions

**Prerequisites:**
- User logged in with security-admin role
- Azure AD test users created (test-engineer@contoso.com, test-viewer@contoso.com)

**Steps:**
1. Navigate to Settings → User Management
2. Add test-engineer@contoso.com with "Security Engineer" role
3. Add test-viewer@contoso.com with "Ops Viewer" role
4. Log out as security-admin
5. Log in as test-engineer@contoso.com
6. Verify "Acknowledge Alert" button is visible
7. Verify "Delete Alert" button is NOT visible
8. Log out as test-engineer
9. Log in as test-viewer@contoso.com
10. Verify all action buttons are hidden (read-only)

**Expected Results:**
- ✅ User roles saved to Cosmos DB
- ✅ RBAC policy enforced in API (403 for unauthorized actions)
- ✅ UI buttons hidden based on user role
- ✅ Role changes reflected within 30 seconds

**Acceptance Criteria:**
- [ ] User roles persist after logout/login
- [ ] API returns 403 for unauthorized actions
- [ ] UI correctly hides/shows buttons per role
- [ ] Role changes propagate within 30 seconds

---

### 2.2 Security Engineer (Write Access)

**User:** security-engineer@contoso.com  
**Permissions:** READ, WRITE, CONFIGURE  

#### Scenario SE-01: Acknowledge P1 Alerts
**Objective:** Verify Security Engineer can acknowledge alerts and add remediation notes

**Prerequisites:**
- User logged in with security-engineer role
- At least 1 active P1 alert in system

**Steps:**
1. Navigate to Alerts page
2. Filter by "Active" status
3. Click on first P1 alert
4. Click "Acknowledge" button
5. Enter remediation notes: "Investigating network policy drift. Expected resolution: 2 hours."
6. Click "Submit"
7. Verify alert status changes to "Acknowledged"
8. Verify notes appear in alert detail view

**Expected Results:**
- ✅ Alert acknowledged successfully (API returns 200)
- ✅ Notes saved to Cosmos DB
- ✅ Alert removed from "Active" list
- ✅ Acknowledgment logged to audit trail

**Acceptance Criteria:**
- [ ] Acknowledgment persists after page refresh
- [ ] Notes visible to all users viewing alert
- [ ] Audit trail includes timestamp and user ID
- [ ] Alert no longer triggers notifications

---

#### Scenario SE-02: Control Detail Analysis
**Objective:** Verify Security Engineer can analyze control validation history

**Prerequisites:**
- User logged in with security-engineer role
- Control "SC-7 Boundary Protection" has 90+ days of validation history

**Steps:**
1. Navigate to Controls page
2. Search for "SC-7"
3. Click on "SC-7 Boundary Protection"
4. View "Validation History" chart (90-day trend)
5. Click on data point representing a failure
6. Verify drill-down to validation result detail
7. Verify remediation runbook link is present
8. Export validation history as CSV

**Expected Results:**
- ✅ 90-day trend chart displays correctly
- ✅ Failure point shows detailed error message
- ✅ Runbook link navigates to correct documentation
- ✅ CSV export includes all 90 days of data

**Acceptance Criteria:**
- [ ] Chart renders within 3 seconds
- [ ] Drill-down shows correct validation result
- [ ] Runbook link is accessible
- [ ] CSV export includes expected columns (date, status, environment, error)

---

### 2.3 SRE (Site Reliability Engineer)

**User:** sre@contoso.com  
**Permissions:** READ, WRITE  

#### Scenario SRE-01: P0 Alert Response (Critical Incident)
**Objective:** Verify SRE can respond to P0 alerts via PagerDuty integration

**Prerequisites:**
- User logged in with sre role
- PagerDuty integration configured
- SRE user added to PagerDuty escalation policy

**Steps:**
1. Trigger synthetic P0 alert: "Control Regression: SC-7 dropped from 100% to 75%"
2. Verify PagerDuty incident created within 60 seconds
3. Verify incident includes:
   - Control ID (SC-7)
   - Environment (PROD)
   - Threshold breached (75% < 90%)
   - Runbook link
4. Acknowledge incident in PagerDuty
5. Navigate to dashboard UI
6. Verify alert status synced to "Acknowledged"
7. Add incident notes in PagerDuty: "Network policy validation script failed. Investigating."
8. Resolve incident in PagerDuty
9. Verify alert status synced to "Resolved"

**Expected Results:**
- ✅ PagerDuty incident created within 60 seconds
- ✅ Incident includes all required metadata
- ✅ Acknowledgment synced to dashboard within 2 minutes
- ✅ Resolution synced to dashboard within 2 minutes

**Acceptance Criteria:**
- [ ] P0 alert triggers PagerDuty within 60 seconds
- [ ] Incident metadata is complete and accurate
- [ ] Acknowledgment/resolution synced bidirectionally
- [ ] No duplicate PagerDuty incidents created

---

#### Scenario SRE-02: Environment Health Check
**Objective:** Verify SRE can monitor infrastructure health and performance

**Prerequisites:**
- User logged in with sre role
- Azure Monitor metrics exported for last 24 hours

**Steps:**
1. Navigate to Environment Health page
2. Select environment: PROD
3. Verify metrics displayed:
   - Cosmos DB RU consumption (last 24h)
   - Azure Function execution count (last 24h)
   - API response time (p50, p95, p99)
   - Alert processing latency (avg, max)
4. Click "View Detailed Metrics" link (navigates to Azure Monitor)
5. Verify Azure Monitor dashboard displays PROD metrics
6. Return to dashboard UI
7. Set alert threshold: "Alert if Cosmos DB RU > 80%"
8. Verify alert rule created in Azure Monitor

**Expected Results:**
- ✅ All metrics loaded within 3 seconds
- ✅ Metrics match Azure Monitor query results
- ✅ Azure Monitor link navigates to correct workspace
- ✅ Alert rule created successfully

**Acceptance Criteria:**
- [ ] Metrics displayed accurately (±5% variance)
- [ ] Azure Monitor link works correctly
- [ ] Alert rule visible in Azure Monitor
- [ ] No missing data points in last 24h

---

### 2.4 Ops Viewer (Read-Only)

**User:** ops-viewer@contoso.com  
**Permissions:** READ  

#### Scenario OV-01: Read-Only Dashboard Access
**Objective:** Verify Ops Viewer can view data but cannot modify anything

**Prerequisites:**
- User logged in with ops-viewer role

**Steps:**
1. Navigate to Dashboard Overview
2. Verify all charts and widgets are visible
3. Attempt to acknowledge an alert (button should be hidden)
4. Attempt to modify alert configuration (page should return 403)
5. Attempt to export CSV (should succeed)
6. Attempt to create new alert rule via API (should return 403)

**Expected Results:**
- ✅ All read operations succeed
- ✅ All write operations blocked (UI + API)
- ✅ Export functionality works
- ✅ Appropriate error messages displayed

**Acceptance Criteria:**
- [ ] Dashboard loads correctly for read-only user
- [ ] No action buttons visible in UI
- [ ] API returns 403 for write operations
- [ ] Export operations succeed

---

#### Scenario OV-02: Compliance Report Generation
**Objective:** Verify Ops Viewer can generate compliance reports for audits

**Prerequisites:**
- User logged in with ops-viewer role
- 90 days of validation results available

**Steps:**
1. Navigate to Reports page
2. Select date range: Last 90 days
3. Select controls: All P0 controls
4. Select environments: PROD, PPE
5. Click "Generate Report"
6. Verify report includes:
   - Overall compliance rate per control
   - Trend chart (90 days)
   - Failure count and failure details
   - Export as PDF
7. Download PDF report
8. Verify PDF includes all selected data

**Expected Results:**
- ✅ Report generated within 10 seconds
- ✅ Report includes all selected controls and environments
- ✅ PDF export successful
- ✅ PDF includes charts and tables

**Acceptance Criteria:**
- [ ] Report generation completes within 10 seconds
- [ ] Report data matches Log Analytics query
- [ ] PDF export successful (file size < 5MB)
- [ ] PDF is readable and formatted correctly

---

### 2.5 Auditor (Read-Only + Audit Logs)

**User:** auditor@contoso.com  
**Permissions:** READ, AUDIT  

#### Scenario AUD-01: Audit Trail Review
**Objective:** Verify Auditor can access complete audit trail of all user actions

**Prerequisites:**
- User logged in with auditor role
- At least 7 days of user activity logged

**Steps:**
1. Navigate to Audit Logs page
2. Filter by date range: Last 7 days
3. Filter by action type: "Alert Acknowledged"
4. Verify audit log includes:
   - Timestamp (ISO 8601)
   - User ID (email)
   - Action type
   - Resource ID (alert ID)
   - IP address
   - User agent
5. Export audit logs as JSON
6. Verify JSON export includes all filtered records

**Expected Results:**
- ✅ Audit logs loaded within 3 seconds
- ✅ Filters work correctly
- ✅ All required fields present
- ✅ JSON export successful

**Acceptance Criteria:**
- [ ] Audit logs include all user actions
- [ ] Timestamps are accurate (±1 second)
- [ ] User IDs are correct
- [ ] JSON export includes all filtered records

---

#### Scenario AUD-02: Compliance Verification for FedRAMP Authorization
**Objective:** Verify Auditor can demonstrate compliance with FedRAMP controls

**Prerequisites:**
- User logged in with auditor role
- 90 days of validation results available

**Steps:**
1. Navigate to Compliance Report page
2. Generate report for FedRAMP High Baseline controls (SC-7, CM-3, RA-5, IR-4)
3. Verify report includes:
   - Control pass/fail rate (90-day average)
   - Evidence of continuous monitoring
   - Incident response times (IR-4)
   - Vulnerability remediation times (RA-5)
4. Export report as CSV
5. Verify CSV includes all required evidence fields

**Expected Results:**
- ✅ Report generated successfully
- ✅ All FedRAMP controls included
- ✅ Evidence fields populated
- ✅ CSV export successful

**Acceptance Criteria:**
- [ ] Report includes all FedRAMP High Baseline controls
- [ ] Evidence is sufficient for audit
- [ ] CSV export includes all required fields
- [ ] No data gaps in 90-day period

---

## 3. Non-Functional Testing

### 3.1 Performance Testing

#### Scenario PERF-01: Dashboard Load Time
**Objective:** Verify dashboard loads within 2 seconds

**Steps:**
1. Clear browser cache
2. Navigate to Dashboard Overview
3. Measure page load time (browser DevTools)
4. Verify all widgets render within 2 seconds

**Acceptance Criteria:**
- [ ] Initial page load < 2 seconds
- [ ] All widgets render < 3 seconds
- [ ] No blocking requests > 1 second

---

#### Scenario PERF-02: API Response Time Under Load
**Objective:** Verify API meets SLA under load

**Steps:**
1. Run load test: 100 concurrent users, 5-minute duration
2. Measure API response times (p50, p95, p99)
3. Verify:
   - p50 < 200ms
   - p95 < 500ms
   - p99 < 1000ms
4. Verify error rate < 1%

**Acceptance Criteria:**
- [ ] p50 < 200ms
- [ ] p95 < 500ms
- [ ] p99 < 1000ms
- [ ] Error rate < 1%

---

### 3.2 Security Testing

#### Scenario SEC-01: RBAC Enforcement
**Objective:** Verify RBAC prevents unauthorized access

**Steps:**
1. Log in as ops-viewer
2. Attempt to call DELETE /api/alerts/{id} endpoint via Postman
3. Verify API returns 403 Forbidden
4. Attempt to call POST /api/alerts/configure endpoint
5. Verify API returns 403 Forbidden

**Acceptance Criteria:**
- [ ] All unauthorized API calls return 403
- [ ] Error message indicates insufficient permissions
- [ ] Audit log includes failed authorization attempts

---

#### Scenario SEC-02: Data Encryption
**Objective:** Verify data encrypted at rest and in transit

**Steps:**
1. Verify Cosmos DB encryption enabled (Azure Portal)
2. Verify TLS 1.2 enforced on API endpoints (Postman/curl)
3. Verify Application Insights logs do NOT contain sensitive data (PII, secrets)

**Acceptance Criteria:**
- [ ] Cosmos DB encryption enabled
- [ ] TLS 1.2 enforced on all endpoints
- [ ] No sensitive data in logs

---

### 3.3 Availability Testing

#### Scenario AVAIL-01: Zero-Downtime Deployment
**Objective:** Verify deployment does not cause downtime

**Steps:**
1. Start synthetic traffic (1 request/second to API)
2. Deploy Phase 5 update to STG environment
3. Monitor API success rate during deployment
4. Verify success rate > 99.9% during deployment

**Acceptance Criteria:**
- [ ] Success rate > 99.9% during deployment
- [ ] No 500 errors during deployment
- [ ] Deployment completes within 10 minutes

---

## 4. Defect Management

### 4.1 Severity Definitions

| Severity | Definition | Example | SLA |
|----------|------------|---------|-----|
| **Critical** | Blocker preventing UAT completion | Dashboard completely inaccessible | Fix within 4 hours |
| **High** | Major feature broken, no workaround | Alerts not delivered to PagerDuty | Fix within 1 day |
| **Medium** | Feature broken but workaround exists | Chart not rendering, but data available via API | Fix within 3 days |
| **Low** | Cosmetic issue or minor usability problem | Button alignment off by 2px | Fix before PROD rollout |

### 4.2 Defect Logging

All defects must be logged in Azure DevOps with the following fields:
- **Title:** Brief description (< 80 characters)
- **Severity:** Critical / High / Medium / Low
- **Scenario ID:** Reference to test scenario (e.g., SA-01)
- **Steps to Reproduce:** Detailed repro steps
- **Expected Result:** What should happen
- **Actual Result:** What actually happened
- **Environment:** STG, PPE, PROD
- **Screenshot/Video:** Attach evidence

### 4.3 UAT Exit Criteria

UAT is considered complete when:
- ✅ 100% of Critical and High scenarios pass
- ✅ < 5% of Medium scenarios fail (with workarounds documented)
- ✅ All Low severity defects triaged (fix or defer to post-launch)
- ✅ Performance benchmarks met (< 2s load time, < 500ms API p95)
- ✅ Security tests pass (RBAC, encryption, audit logging)
- ✅ Sign-off obtained from all stakeholder roles

---

## 5. UAT Schedule

| Day | Activities | Stakeholders |
|-----|------------|--------------|
| **Day 1** | Environment setup, smoke tests, training walkthrough | All |
| **Day 2** | Security Admin scenarios (SA-01 to SA-03) | Security Admin |
| **Day 3** | Security Engineer & SRE scenarios (SE-01, SE-02, SRE-01, SRE-02) | Security Engineer, SRE |
| **Day 4** | Ops Viewer & Auditor scenarios (OV-01, OV-02, AUD-01, AUD-02) | Ops Viewer, Auditor |
| **Day 5** | Non-functional testing, defect triage, sign-off | All |

---

## 6. UAT Sign-Off Template

### FedRAMP Security Dashboard - UAT Sign-Off

**Project:** FedRAMP Security Dashboard (Phase 5)  
**UAT Environment:** STG (Staging)  
**UAT Period:** [Start Date] to [End Date]  

#### Stakeholder Sign-Off

| Role | Name | Email | Sign-Off Date | Status | Comments |
|------|------|-------|---------------|--------|----------|
| Security Admin | [Name] | [Email] | [Date] | ✅ Approved / ⚠️ Approved with conditions / ❌ Rejected | |
| Security Engineer | [Name] | [Email] | [Date] | ✅ Approved / ⚠️ Approved with conditions / ❌ Rejected | |
| SRE | [Name] | [Email] | [Date] | ✅ Approved / ⚠️ Approved with conditions / ❌ Rejected | |
| Ops Viewer | [Name] | [Email] | [Date] | ✅ Approved / ⚠️ Approved with conditions / ❌ Rejected | |
| Auditor | [Name] | [Email] | [Date] | ✅ Approved / ⚠️ Approved with conditions / ❌ Rejected | |

#### Exit Criteria Status

- [ ] All Critical scenarios passed
- [ ] All High scenarios passed
- [ ] < 5% Medium scenarios failed
- [ ] Performance benchmarks met
- [ ] Security tests passed
- [ ] All stakeholders signed off

#### Conditions for Approval (if applicable)

[List any conditions that must be met before production rollout]

#### Production Rollout Approval

- [ ] **Approved for Production Rollout**  
  Authorized by: ___________________________  
  Date: ___________________________  

---

**UAT Completion:** This document confirms that the FedRAMP Security Dashboard has successfully completed User Acceptance Testing and is ready for production deployment.
