# FedRAMP Dashboard: Training Materials

**Phase:** 5 of 5  
**Document Version:** 1.0  
**Owner:** B'Elanna Torres (Infrastructure Expert)  
**Issue:** #88  
**Date:** March 2026  
**Audience:** All Dashboard Users  

---

## 1. Quick Start Guides

### 1.1 Security Admin Quick Start

**Role:** Full administrative access to the FedRAMP Dashboard  
**Permissions:** READ, WRITE, DELETE, CONFIGURE, AUDIT  
**Time to Complete:** 15 minutes  

#### What You Can Do:
- View compliance status across all environments
- Configure alert rules and thresholds
- Manage user roles and permissions
- Acknowledge and resolve alerts
- Generate compliance reports
- Access complete audit logs

#### Getting Started:

1. **Access the Dashboard**
   - Navigate to: `https://fedramp-dashboard.contoso.com`
   - Sign in with your Azure AD credentials
   - Verify you see "Security Admin" badge in top-right corner

2. **Dashboard Overview**
   - **Compliance Overview Widget:** Shows overall compliance rate (%)
     - Green: > 95% compliant
     - Yellow: 90-95% compliant
     - Red: < 90% compliant
   - **P0 Controls Widget:** Critical controls status (SC-7, CM-3, RA-5, IR-4)
   - **Recent Alerts Widget:** Last 10 alerts requiring attention
   - **Trend Chart:** 30-day compliance trend

3. **Navigate to Controls**
   - Click "Controls" in left navigation
   - View all FedRAMP controls organized by category:
     - Access Control (AC)
     - Configuration Management (CM)
     - Incident Response (IR)
     - Risk Assessment (RA)
     - System and Communications Protection (SC)
   - Click any control to view detailed validation history

4. **Manage Alerts**
   - Click "Alerts" in left navigation
   - Filter by:
     - Status: Active, Acknowledged, Resolved
     - Severity: P0 (Critical), P1 (High), P2 (Medium), P3 (Low)
     - Environment: DEV, STG, PROD
   - Click "Acknowledge" to mark alert as in-progress
   - Add remediation notes (required)
   - Click "Resolve" when issue fixed

5. **Configure Alert Rules**
   - Click "Settings" → "Alert Configuration"
   - Modify thresholds:
     - **Control Drift Detection:** Default 90%, can adjust 80-95%
     - **Control Regression:** Default 10% drop, can adjust 5-20%
     - **Compliance Deadline:** Default 7 days, can adjust 3-14 days
   - Click "Save Configuration"
   - Test alerts: Click "Send Test Alert" to verify delivery

6. **Manage Users**
   - Click "Settings" → "User Management"
   - Click "Add User"
   - Enter email address (must be Azure AD user)
   - Select role:
     - Security Admin: Full access
     - Security Engineer: Write access (no user management)
     - SRE: Write access (focused on infrastructure)
     - Ops Viewer: Read-only
     - Auditor: Read-only + audit logs
   - Click "Save"

#### Common Tasks:

| Task | Steps |
|------|-------|
| **Generate Compliance Report** | Reports → Select date range → Select controls → Generate Report → Export as PDF |
| **Create Custom Dashboard** | Dashboard → Add Widget → Select metric → Configure filters → Save |
| **Set Up PagerDuty Escalation** | Settings → Integrations → PagerDuty → Configure escalation policy → Test integration |
| **Bulk Acknowledge Alerts** | Alerts → Select multiple alerts → Click "Bulk Acknowledge" → Add notes |

#### Tips & Best Practices:
- ✅ Review dashboard daily (morning standup)
- ✅ Acknowledge P0 alerts within 30 minutes
- ✅ Generate monthly compliance reports for leadership
- ✅ Test alert rules after configuration changes
- ⚠️ Avoid deleting historical alerts (audit trail)
- ⚠️ Always add remediation notes when acknowledging alerts

---

### 1.2 Security Engineer Quick Start

**Role:** Operational security monitoring and alert response  
**Permissions:** READ, WRITE, CONFIGURE  
**Time to Complete:** 10 minutes  

#### What You Can Do:
- View compliance status and trends
- Acknowledge and resolve alerts
- Analyze control validation history
- Export data and reports
- Configure personal alert preferences

#### What You CANNOT Do:
- Manage user roles/permissions
- Delete historical data
- Modify global alert thresholds

#### Getting Started:

1. **Access the Dashboard**
   - Navigate to: `https://fedramp-dashboard.contoso.com`
   - Sign in with your Azure AD credentials
   - Verify you see "Security Engineer" badge

2. **Daily Workflow**
   - Morning: Check "Recent Alerts" widget
   - Afternoon: Review compliance trends
   - End of Day: Acknowledge/resolve open alerts

3. **Alert Response**
   - Click on alert in "Recent Alerts" widget
   - Read alert details:
     - Control ID (e.g., SC-7)
     - Environment (DEV, STG, PROD)
     - Failure reason
     - Runbook link
   - Click runbook link to view remediation steps
   - Follow runbook procedures
   - Click "Acknowledge" and add notes
   - After remediation, click "Resolve"

4. **Control Analysis**
   - Click "Controls" → Search for control ID
   - View validation history chart (90 days)
   - Click on failure data points to see error details
   - Export validation history as CSV for deeper analysis

#### Common Tasks:

| Task | Steps |
|------|-------|
| **Investigate Control Drift** | Alerts → Filter by "Control Drift" → Click alert → View affected resources → Follow runbook |
| **Analyze Compliance Trend** | Dashboard → Click on trend chart → Drill down to specific control → View validation logs |
| **Export Alert History** | Alerts → Select date range → Click "Export" → Choose CSV or JSON |
| **Set Personal Notifications** | Settings → My Preferences → Configure email/Teams notifications for P0/P1 alerts |

#### Tips & Best Practices:
- ✅ Always add meaningful remediation notes
- ✅ Use runbook links (tested procedures)
- ✅ Export data for trend analysis
- ✅ Escalate to Security Admin if needed
- ⚠️ Don't resolve alerts without verification
- ⚠️ Document non-standard remediation steps

---

### 1.3 SRE Quick Start

**Role:** Infrastructure reliability and incident response  
**Permissions:** READ, WRITE  
**Time to Complete:** 10 minutes  

#### What You Can Do:
- Monitor infrastructure health
- Respond to P0 alerts (PagerDuty integration)
- View Azure Monitor metrics
- Acknowledge and resolve alerts
- Access environment health dashboards

#### Getting Started:

1. **Access the Dashboard**
   - Navigate to: `https://fedramp-dashboard.contoso.com`
   - Sign in with your Azure AD credentials
   - Verify PagerDuty integration configured

2. **Environment Health Monitoring**
   - Click "Environment Health" in left navigation
   - Select environment: PROD
   - View key metrics:
     - **Cosmos DB RU Consumption:** Target < 80%
     - **API Response Time:** Target p95 < 500ms
     - **Function Execution Count:** Monitor for anomalies
     - **Alert Processing Latency:** Target < 60 seconds

3. **P0 Alert Response (PagerDuty Integration)**
   - Receive PagerDuty page for critical alert
   - Incident includes:
     - Control ID and description
     - Environment affected
     - Threshold breached
     - Runbook link
   - Acknowledge in PagerDuty (syncs to dashboard)
   - Follow runbook procedures
   - Resolve in PagerDuty (syncs to dashboard)

4. **Azure Monitor Integration**
   - Click "View Detailed Metrics" link
   - Navigate to Azure Monitor dashboard
   - View infrastructure metrics:
     - Cosmos DB: RU consumption, storage, latency
     - App Service: CPU, memory, request count
     - Azure Functions: executions, failures, duration

#### Common Tasks:

| Task | Steps |
|------|-------|
| **Respond to High RU Consumption** | Environment Health → Click on Cosmos DB widget → View query patterns → Optimize expensive queries |
| **Investigate API Performance Degradation** | Environment Health → API Response Time → View p95/p99 → Check Application Insights for slow requests |
| **Set Infrastructure Alerts** | Settings → Alert Configuration → Set threshold "Alert if Cosmos DB RU > 80%" → Save |
| **Failover to West US 2 (DR)** | Environment Health → DR Status → Click "Initiate Failover" → Confirm |

#### Tips & Best Practices:
- ✅ Monitor Environment Health dashboard hourly
- ✅ Set up custom alerts for infrastructure thresholds
- ✅ Test DR failover quarterly
- ✅ Document incident response in PagerDuty
- ⚠️ Don't ignore sustained high RU consumption
- ⚠️ Always validate after infrastructure changes

---

### 1.4 Ops Viewer Quick Start

**Role:** Read-only dashboard access  
**Permissions:** READ  
**Time to Complete:** 5 minutes  

#### What You Can Do:
- View compliance status and trends
- Read alert details
- Export reports and data
- View control validation history

#### What You CANNOT Do:
- Acknowledge or resolve alerts
- Modify any settings
- Manage users

#### Getting Started:

1. **Access the Dashboard**
   - Navigate to: `https://fedramp-dashboard.contoso.com`
   - Sign in with your Azure AD credentials
   - Verify you see "Ops Viewer" badge

2. **View-Only Dashboard**
   - All charts and widgets are visible
   - No action buttons displayed
   - Export functionality available

3. **Generate Reports**
   - Click "Reports" in left navigation
   - Select date range and controls
   - Click "Generate Report"
   - Export as PDF or CSV

#### Common Tasks:

| Task | Steps |
|------|-------|
| **Weekly Compliance Report** | Reports → Last 7 days → All P0 controls → Generate → Export PDF |
| **Trend Analysis** | Dashboard → Compliance Trend chart → View 90-day history |
| **Control Details** | Controls → Search by ID → View validation history → Export CSV |

---

### 1.5 Auditor Quick Start

**Role:** Compliance audit and verification  
**Permissions:** READ, AUDIT  
**Time to Complete:** 10 minutes  

#### What You Can Do:
- View compliance status and trends
- Access complete audit logs
- Generate compliance reports with evidence
- Export audit trail for FedRAMP authorization

#### Getting Started:

1. **Access the Dashboard**
   - Navigate to: `https://fedramp-dashboard.contoso.com`
   - Sign in with your Azure AD credentials
   - Verify you see "Auditor" badge

2. **Audit Log Access**
   - Click "Audit Logs" in left navigation
   - View all user actions with timestamps:
     - Alert acknowledged/resolved
     - Configuration changes
     - User role changes
     - Report exports
   - Filter by date range, user, or action type

3. **Compliance Report Generation**
   - Click "Reports" → "Compliance Report"
   - Select FedRAMP High Baseline controls
   - Select date range (90 days for continuous monitoring)
   - Click "Generate Report"
   - Report includes:
     - Control pass/fail rates
     - Evidence of monitoring
     - Incident response times
     - Remediation timelines

#### Common Tasks:

| Task | Steps |
|------|-------|
| **FedRAMP Annual Assessment** | Reports → Select all FedRAMP High controls → Last 365 days → Generate → Export PDF with evidence |
| **User Activity Audit** | Audit Logs → Filter by user email → Export as JSON |
| **Incident Timeline** | Audit Logs → Filter by "Alert Acknowledged" and "Alert Resolved" → Export timeline |

---

## 2. Dashboard Navigation Walkthrough

### 2.1 Dashboard Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  FedRAMP Security Dashboard           [Search] [User: John Doe ▼]│
├─────────────────────────────────────────────────────────────────┤
│  Navigation (Left Sidebar)            Main Content Area         │
│  ┌─────────────────────┐              ┌───────────────────────┐ │
│  │ 📊 Dashboard        │              │  Compliance Overview  │ │
│  │ 🛡️  Controls         │              │  ┌─────────────────┐ │ │
│  │ 🔔 Alerts           │              │  │   Overall: 94%  │ │ │
│  │ 📈 Reports          │              │  │   P0:      98%  │ │ │
│  │ 🏥 Environment      │              │  │   P1:      92%  │ │ │
│  │ ⚙️  Settings         │              │  └─────────────────┘ │ │
│  │ 📜 Audit Logs       │              │                       │ │
│  └─────────────────────┘              │  [Trend Chart 30d]    │ │
│                                        └───────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Key Features

#### Search Bar (Top Right)
- Type control ID (e.g., "SC-7") to quickly navigate to control
- Type alert ID (e.g., "ALERT-12345") to view alert details
- Type environment (e.g., "PROD") to filter dashboard

#### User Menu (Top Right)
- View current role badge
- My Preferences (notification settings)
- Help & Documentation
- Sign Out

#### Navigation Sidebar (Left)
- **Dashboard:** Overview and quick stats
- **Controls:** Browse all FedRAMP controls
- **Alerts:** Active, acknowledged, resolved alerts
- **Reports:** Generate compliance reports
- **Environment Health:** Infrastructure metrics (SRE role)
- **Settings:** Configuration (Admin role only)
- **Audit Logs:** User activity (Auditor role only)

### 2.3 Widget Interactions

All dashboard widgets are interactive:
- **Click on widget title:** Opens detailed view
- **Click on data point:** Drills down to specific record
- **Hover over chart:** Shows tooltip with exact values
- **Click "Export" icon:** Exports widget data as CSV

### 2.4 Filters (Top of Each Page)

- **Environment:** DEV, STG, STG-GOV, PPE, PROD
- **Date Range:** Last 7 days, Last 30 days, Last 90 days, Custom
- **Status:** Active, Acknowledged, Resolved (Alerts page)
- **Severity:** P0, P1, P2, P3 (Alerts page)
- **Category:** AC, CM, IR, RA, SC (Controls page)

---

## 3. Alert Response Procedures

### 3.1 Alert Severity Levels

| Severity | Definition | Response Time | Notification Channel |
|----------|------------|---------------|----------------------|
| **P0 (Critical)** | Control regression > 20% OR critical control failure (SC-7, IR-4) | < 30 minutes | PagerDuty + Teams |
| **P1 (High)** | Control regression 10-20% OR high control failure | < 2 hours | Teams |
| **P2 (Medium)** | Control drift detected OR medium control failure | < 8 hours | Teams |
| **P3 (Low)** | Minor compliance issue OR informational alert | < 24 hours | Email digest |

### 3.2 Alert Response Workflow

```
Alert Triggered
     ↓
Notification Sent (PagerDuty/Teams)
     ↓
SRE/Security Engineer Acknowledges Alert
     ↓
Review Alert Details + Runbook
     ↓
Execute Remediation Steps
     ↓
Verify Fix (Re-run Validation)
     ↓
Resolve Alert (Add Resolution Notes)
     ↓
Post-Incident Review (for P0 alerts)
```

### 3.3 Alert Type: Control Drift Detection

**Description:** A control's compliance rate has dropped below threshold (default: 90%)

**Example:** "SC-7 Boundary Protection compliance dropped to 87% in PROD"

**Response Steps:**
1. Acknowledge alert in dashboard
2. Click runbook link: "Control Drift Runbook"
3. Identify affected resources:
   - Navigate to Controls → SC-7
   - View "Failed Validations" table
   - Export list of non-compliant resources
4. Investigate root cause:
   - Recent infrastructure changes?
   - Configuration drift in Terraform/Bicep?
   - New resources added without validation?
5. Remediate:
   - Apply network policies to affected resources
   - Update Infrastructure-as-Code templates
   - Re-run validation script
6. Verify:
   - Confirm compliance rate > 90%
   - Check dashboard for updated metrics
7. Resolve alert and document:
   - Resolution notes: "Applied network policies to 15 new VMs. Compliance restored to 94%."

### 3.4 Alert Type: Control Regression

**Description:** A control's compliance rate dropped > 10% in 24 hours

**Example:** "RA-5 Vulnerability Scanning regression: 98% → 82% in PROD"

**Response Steps:**
1. Acknowledge alert immediately (P0 alert)
2. Escalate to Security Admin if needed
3. Investigate:
   - Check vulnerability scanner status (operational?)
   - Review recent deployments (new workloads?)
   - Check for false positives
4. Remediate:
   - If scanner down: Restart vulnerability scanning service
   - If new vulnerabilities: Follow vulnerability management process
   - If false positives: Update validation script exclusions
5. Resolve alert with detailed notes

### 3.5 Alert Type: Compliance Deadline Approaching

**Description:** Remediation deadline approaching for open compliance issue

**Example:** "CM-3 Configuration Management issue #12345 due in 3 days"

**Response Steps:**
1. Review issue details in ticketing system
2. Assess remediation progress
3. If on track: Update ticket with progress notes
4. If at risk: Escalate to Security Admin and request deadline extension
5. Complete remediation before deadline
6. Resolve alert

### 3.6 Post-Incident Review (P0 Alerts Only)

Within 48 hours of P0 alert resolution:

1. **Schedule Post-Incident Review Meeting**
   - Attendees: Security Admin, SRE, Security Engineer, incident responders
   - Duration: 30-60 minutes

2. **Document Incident Timeline**
   - Detection time
   - Acknowledgment time
   - Resolution time
   - Total downtime (if applicable)

3. **Root Cause Analysis**
   - What happened?
   - Why did it happen?
   - Why wasn't it prevented?

4. **Action Items**
   - Preventive measures
   - Monitoring improvements
   - Runbook updates
   - Training needs

5. **Share Learnings**
   - Post summary in Teams (#fedramp-incidents)
   - Update runbook documentation
   - Add to incident knowledge base

---

## 4. Common Scenarios & Troubleshooting

### 4.1 Scenario: Dashboard Not Loading

**Symptom:** Browser shows "Loading..." indefinitely

**Troubleshooting Steps:**
1. Check internet connection
2. Verify Azure AD authentication:
   - Sign out and sign back in
   - Clear browser cookies/cache
3. Check browser console for errors (F12)
4. Try different browser (Chrome, Edge, Firefox)
5. Contact IT Support if issue persists

### 4.2 Scenario: Alert Not Delivered to Teams

**Symptom:** Alert shows in dashboard but not in Teams channel

**Troubleshooting Steps:**
1. Verify alert severity (P2 and above go to Teams)
2. Check Teams webhook configuration:
   - Settings → Integrations → Microsoft Teams
   - Click "Test Webhook"
3. Check for alert suppression:
   - Settings → Alert Configuration → Suppression Rules
4. Contact Security Admin if webhook needs reconfiguration

### 4.3 Scenario: Unable to Acknowledge Alert

**Symptom:** "Acknowledge" button is grayed out or missing

**Troubleshooting Steps:**
1. Verify your role has WRITE permission
   - Ops Viewer and Auditor roles are read-only
2. Check if alert already acknowledged by another user
3. Refresh page to ensure latest data
4. Contact Security Admin if you need role elevation

### 4.4 Scenario: Compliance Report Shows "No Data"

**Symptom:** Generated report is empty or shows "No data available"

**Troubleshooting Steps:**
1. Verify date range includes data (check Dashboard Overview first)
2. Verify selected controls have validation results
3. Check environment filter (select at least one environment)
4. Try exporting raw data instead of PDF
5. Contact IT Support if data ingestion issue suspected

### 4.5 Scenario: High RU Consumption Alert

**Symptom:** Cosmos DB RU consumption > 80%

**Troubleshooting Steps:**
1. Navigate to Environment Health → Cosmos DB
2. Click "View Query Metrics"
3. Identify expensive queries (> 100 RUs per query)
4. Common causes:
   - Missing indexes
   - Inefficient query patterns
   - Unexpected traffic spike
5. Short-term mitigation:
   - Scale up RUs temporarily
6. Long-term fix:
   - Add indexes to Cosmos DB
   - Optimize query patterns
   - Implement caching

---

## 5. Video Tutorials (Coming Soon)

The following video tutorials will be available on the internal training portal:

1. **Dashboard Overview (5 minutes)**
   - Navigation walkthrough
   - Widget interactions
   - Search and filtering

2. **Alert Response Workflow (10 minutes)**
   - Acknowledging alerts
   - Using runbooks
   - Resolving alerts
   - Post-incident documentation

3. **Generating Compliance Reports (8 minutes)**
   - Selecting controls and date ranges
   - Exporting as PDF/CSV
   - Interpreting report data

4. **Security Admin: User Management (7 minutes)**
   - Adding users and assigning roles
   - RBAC overview
   - Testing permissions

5. **SRE: Infrastructure Monitoring (12 minutes)**
   - Environment Health dashboard
   - Azure Monitor integration
   - Setting custom alerts
   - DR failover procedures

---

## 6. Training Resources

### 6.1 Documentation

- **User Guide:** https://docs.contoso.com/fedramp-dashboard/user-guide
- **API Documentation:** https://docs.contoso.com/fedramp-dashboard/api
- **Runbook Library:** https://docs.contoso.com/fedramp-dashboard/runbooks
- **Architecture Overview:** https://docs.contoso.com/fedramp-dashboard/architecture

### 6.2 Support Channels

- **Teams Channel:** #fedramp-dashboard-support (fastest response)
- **Email:** fedramp-support@contoso.com
- **Help Desk Ticket:** Submit ticket in ServiceNow (category: FedRAMP Dashboard)
- **On-Call Support:** Page "FedRAMP Dashboard" in PagerDuty (P0 issues only)

### 6.3 Training Schedule

- **New User Training:** First Tuesday of every month, 10:00 AM EST (1 hour)
- **Advanced Training (Admin/SRE):** Quarterly (2 hours)
- **Lunch & Learn Sessions:** Monthly "Tips & Tricks" sessions (30 minutes)

### 6.4 FAQ

**Q: How often is the dashboard data refreshed?**  
A: Dashboard data refreshes every 5 minutes. Real-time alerts processed within 60 seconds.

**Q: Can I create custom dashboards?**  
A: Yes, Security Admins can create custom dashboards. Click "Dashboard" → "Create Custom Dashboard".

**Q: How long is historical data retained?**  
A: Validation results: 2 years, Alerts: 1 year, Audit logs: 7 years (compliance requirement).

**Q: What if I need access to a different environment?**  
A: Submit access request to Security Admin with business justification. Approval required for PROD access.

**Q: Can I integrate the dashboard with my own tools?**  
A: Yes, REST API available at `https://api.fedramp-dashboard.contoso.com`. API documentation: https://docs.contoso.com/fedramp-dashboard/api

**Q: What browsers are supported?**  
A: Chrome (latest), Edge (latest), Firefox (latest). IE 11 not supported.

---

**Training Completion Certificate**

After completing training, users will receive a certificate via email. Certificate includes:
- Training completion date
- Role assigned
- Next recertification date (annually)

For questions about training materials, contact: training@contoso.com
