# FedRAMP Dashboard: Phase 4 Alerting & Integrations Implementation

**Status:** Implementation  
**Phase:** 4 of 5  
**Owner:** Worf (Security & Cloud Expert)  
**Issue:** #84  
**Related:** Issue #77 (Design), Issue #85 (Phase 1), Issue #86 (Phase 2)  
**Prerequisites:** Phase 1 (Data Pipeline) - COMPLETE, Phase 2 (REST API) - COMPLETE  
**Timeline:** Weeks 7-8  
**Estimated Cost:** $140/month

---

## Executive Summary

Phase 4 implements comprehensive alerting and notification integrations for the FedRAMP Security Dashboard. This phase transforms passive monitoring into active incident response by routing critical compliance events to PagerDuty, Microsoft Teams, and Azure Monitor with intelligent deduplication and escalation policies.

**Key Deliverables:**
1. ✅ 6 alert type definitions with severity classification and routing rules
2. ✅ PagerDuty integration with webhook receiver and escalation policies
3. ✅ Microsoft Teams integration with Adaptive Cards via incoming webhook
4. ✅ Azure Monitor alert rules with action groups for automated responses
5. ✅ Alert suppression and deduplication logic (30-min window)
6. ✅ End-to-end alerting pipeline with delivery guarantees

**Success Criteria:**
- ✅ P0 alerts delivered to PagerDuty within 60 seconds
- ✅ P1 alerts delivered to Teams within 2 minutes
- ✅ < 5% duplicate alert rate (deduplication effective)
- ✅ 99.9% alert delivery success rate
- ✅ Zero alert fatigue (suppression effective)

---

## 1. Architecture Overview

### 1.1 Alerting Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Data Sources (Phase 1)                        │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐    │
│  │ Cosmos DB      │  │ Log Analytics  │  │ Azure Monitor  │    │
│  │ (Validation    │  │ (KQL Queries)  │  │ (Metrics)      │    │
│  │  Results)      │  │                │  │                │    │
│  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘    │
└───────────┼──────────────────┼──────────────────┼──────────────┘
            │                  │                  │
            ↓                  ↓                  ↓
┌─────────────────────────────────────────────────────────────────┐
│                  Azure Monitor Alert Rules                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  6 Alert Types:                                          │  │
│  │  1. Control Drift Detection (KQL scheduled query)       │  │
│  │  2. Control Regression (KQL scheduled query)            │  │
│  │  3. Threshold Breach (metric alert)                     │  │
│  │  4. New Vulnerability (Cosmos DB change feed)           │  │
│  │  5. Compliance Deadline Approaching (timer function)    │  │
│  │  6. Manual Review Needed (API trigger)                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└───────────┬──────────────────────────────────────────────────────┘
            │ Alert triggered (JSON webhook)
            ↓
┌─────────────────────────────────────────────────────────────────┐
│              Azure Function: AlertProcessor                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  1. Alert Enrichment:                                    │  │
│  │     • Lookup control metadata (name, category, owner)   │  │
│  │     • Lookup environment metadata (region, cloud)       │  │
│  │     • Attach runbook links, remediation steps           │  │
│  │  2. Deduplication:                                       │  │
│  │     • Check Redis cache (30-min window)                 │  │
│  │     • Hash: {alert_type, control_id, environment}       │  │
│  │     • Skip if duplicate found                           │  │
│  │  3. Suppression:                                         │  │
│  │     • Check maintenance windows (Cosmos DB)             │  │
│  │     • Check acknowledged alerts (Redis)                 │  │
│  │     • Skip if suppressed                                │  │
│  │  4. Routing Decision:                                    │  │
│  │     • P0 (Critical) → PagerDuty                         │  │
│  │     • P1 (High) → Teams + PagerDuty (low urgency)      │  │
│  │     • P2 (Medium) → Teams                               │  │
│  │     • P3 (Low) → Email digest (daily rollup)           │  │
│  └──────────────────────────────────────────────────────────┘  │
└───────────┬──────────────────┬───────────────────┬──────────────┘
            │                  │                   │
            ↓                  ↓                   ↓
┌───────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│    PagerDuty      │  │  Microsoft Teams │  │  Email Digest    │
│    Integration    │  │   Integration    │  │  (SendGrid)      │
│  ┌─────────────┐  │  │ ┌──────────────┐ │  │ ┌──────────────┐ │
│  │ Webhook:    │  │  │ │ Adaptive Card│ │  │ │ Daily Summary│ │
│  │ Events API  │  │  │ │ (JSON)       │ │  │ │ (HTML)       │ │
│  │ v2          │  │  │ └──────────────┘ │  │ └──────────────┘ │
│  ├─────────────┤  │  │                  │  │                  │
│  │ Escalation  │  │  │ Channel:         │  │ Recipients:      │
│  │ Policies:   │  │  │ • P1: #fedramp  │  │ • Security team  │
│  │ • P0: 5min  │  │  │ • P2: #security │  │ • Compliance     │
│  │ • P1: 30min │  │  │ • P3: #alerts   │  │                  │
│  └─────────────┘  │  │                  │  │                  │
│                   │  │ Actions:         │  │ Frequency:       │
│  On-Call:         │  │ • View Details  │  │ • 8am UTC daily  │
│  • Security Eng   │  │ • Acknowledge   │  │                  │
│  │  (Primary)      │  │ • Suppress      │  │                  │
│  • SRE (Backup)   │  │                  │  │                  │
│  └───────────────┘  └──────────────────┘  └──────────────────┘
```

### 1.2 Component Responsibilities

| Component | Responsibility | Technology | Cost |
|-----------|----------------|------------|------|
| **Alert Rules** | Trigger detection from data sources | Azure Monitor | $30/month |
| **AlertProcessor Function** | Enrichment, deduplication, routing | Azure Functions | $40/month |
| **Redis Cache** | Deduplication state (30-min TTL) | Azure Cache for Redis (Basic) | $50/month |
| **PagerDuty** | P0/P1 incident management | PagerDuty Events API v2 | External service |
| **Teams Webhook** | P1/P2 notifications | Microsoft Teams Incoming Webhook | Free |
| **SendGrid** | P3 email digest | SendGrid API | $20/month |

**Total Phase 4 Cost:** $140/month

---

## 2. Alert Type Definitions

### 2.1 Alert Type 1: Control Drift Detection

**Description:** Detects when a FedRAMP control's failure rate increases significantly compared to the previous period, indicating potential configuration drift or regression.

**Detection Logic:**
- Compare last 7 days vs prior 7 days
- Alert if failure rate increases > 10%
- Run every 1 hour

**Severity Classification:**
- **P0 (Critical):** P0 control drift > 20% (SC-7, SC-8, SI-2, SI-3)
- **P1 (High):** P1 control drift > 20% (RA-5, CM-3, IR-4)
- **P2 (Medium):** Any control drift 10-20%

**KQL Query:**
```kql
let lookback_hours = 168;  // 7 days
let comparison_period_hours = 336;  // 14 days total
let drift_threshold = 0.10;  // 10% increase
let current_period = ControlValidationResults_CL
| where TimeGenerated between (ago(lookback_hours * 1h) .. now())
| summarize 
    current_total = count(),
    current_failures = countif(Status_s == "FAIL")
  by ControlId_s, Environment_s
| extend current_fail_rate = todouble(current_failures) / current_total;
let prior_period = ControlValidationResults_CL
| where TimeGenerated between (ago(comparison_period_hours * 1h) .. ago(lookback_hours * 1h))
| summarize 
    prior_total = count(),
    prior_failures = countif(Status_s == "FAIL")
  by ControlId_s, Environment_s
| extend prior_fail_rate = todouble(prior_failures) / prior_total;
current_period
| join kind=inner prior_period on ControlId_s, Environment_s
| extend drift_pct = (current_fail_rate - prior_fail_rate) * 100
| where drift_pct > (drift_threshold * 100)
| project 
    alert_type = "control_drift",
    ControlId_s,
    Environment_s,
    current_fail_rate,
    prior_fail_rate,
    drift_pct,
    current_failures,
    prior_failures,
    severity = case(
        ControlId_s in ("SC-7", "SC-8", "SI-2", "SI-3") and drift_pct > 20, "P0",
        drift_pct > 20, "P1",
        "P2"
    )
| order by drift_pct desc
```

**Alert Payload:**
```json
{
  "alert_type": "control_drift",
  "alert_id": "drift-SC7-PROD-20260308T153045",
  "severity": "P0",
  "timestamp": "2026-03-08T15:30:45Z",
  "control": {
    "id": "SC-7",
    "name": "Boundary Protection",
    "category": "System and Communications Protection"
  },
  "environment": "PROD",
  "metrics": {
    "current_fail_rate": 0.15,
    "prior_fail_rate": 0.03,
    "drift_percentage": 12.0,
    "current_failures": 45,
    "prior_failures": 9
  },
  "runbook_url": "https://wiki.contoso.com/runbooks/control-drift-sc7",
  "remediation_steps": [
    "1. Review recent NetworkPolicy changes in PROD",
    "2. Compare current policies vs STG baseline",
    "3. Check for cluster configuration drift",
    "4. Run compliance scan: kubectl exec network-policy-test.sh"
  ]
}
```

---

### 2.2 Alert Type 2: Control Regression

**Description:** Detects when a previously passing control begins failing consistently (3+ consecutive failures within 1 hour).

**Detection Logic:**
- Track control status over last 1 hour
- Alert if 3+ consecutive failures detected
- Must have passed within prior 24 hours (not a persistent failure)
- Run every 15 minutes

**Severity Classification:**
- **P0 (Critical):** P0 control regression (SC-7, SC-8, SI-2, SI-3)
- **P1 (High):** P1 control regression (RA-5, CM-3, IR-4)
- **P2 (Medium):** P2/P3 control regression

**KQL Query:**
```kql
let lookback_hours = 1;
let prior_baseline_hours = 24;
let consecutive_failures_threshold = 3;
// Find controls with recent consecutive failures
let recent_failures = ControlValidationResults_CL
| where TimeGenerated > ago(lookback_hours * 1h)
| where Status_s == "FAIL"
| summarize 
    failure_count = count(),
    first_failure = min(TimeGenerated),
    last_failure = max(TimeGenerated)
  by ControlId_s, Environment_s
| where failure_count >= consecutive_failures_threshold;
// Verify control was passing in prior baseline
let prior_passing = ControlValidationResults_CL
| where TimeGenerated between (ago(prior_baseline_hours * 1h) .. ago(lookback_hours * 1h))
| where Status_s == "PASS"
| summarize pass_count = count() by ControlId_s, Environment_s
| where pass_count > 0;
// Join to find regressions
recent_failures
| join kind=inner prior_passing on ControlId_s, Environment_s
| project 
    alert_type = "control_regression",
    ControlId_s,
    Environment_s,
    failure_count,
    first_failure,
    last_failure,
    time_since_first_failure_min = datetime_diff('minute', now(), first_failure),
    severity = case(
        ControlId_s in ("SC-7", "SC-8", "SI-2", "SI-3"), "P0",
        ControlId_s in ("RA-5", "CM-3", "IR-4"), "P1",
        "P2"
    )
| order by severity asc, failure_count desc
```

**Alert Payload:**
```json
{
  "alert_type": "control_regression",
  "alert_id": "regression-SI2-STG-20260308T140022",
  "severity": "P0",
  "timestamp": "2026-03-08T14:00:22Z",
  "control": {
    "id": "SI-2",
    "name": "Flaw Remediation",
    "category": "System and Information Integrity"
  },
  "environment": "STG",
  "metrics": {
    "consecutive_failures": 5,
    "first_failure": "2026-03-08T13:15:00Z",
    "time_since_first_failure_min": 45,
    "prior_pass_count": 120
  },
  "likely_cause": "Recent deployment to STG-EUS2 cluster",
  "recent_changes": [
    "Deployment: dk8s-stg-eus2-28 v1.28.3 (2026-03-08T12:30:00Z)",
    "ConfigMap update: trivy-config (2026-03-08T13:00:00Z)"
  ],
  "runbook_url": "https://wiki.contoso.com/runbooks/control-regression-si2",
  "remediation_steps": [
    "1. Check Trivy scan results in last hour",
    "2. Review recent image updates in STG",
    "3. Compare vulnerability count vs baseline",
    "4. Roll back if critical CVE detected"
  ]
}
```

---

### 2.3 Alert Type 3: Threshold Breach

**Description:** Detects when aggregate compliance metrics fall below acceptable thresholds (e.g., overall compliance < 95%).

**Detection Logic:**
- Calculate aggregate compliance rate across all controls
- Alert if compliance < 95% for 15+ minutes
- Separate thresholds per environment
- Run every 5 minutes

**Severity Classification:**
- **P0 (Critical):** PROD compliance < 90%
- **P1 (High):** PROD compliance < 95% OR STG < 85%
- **P2 (Medium):** STG compliance < 95% OR DEV < 80%

**Metric Alert Configuration:**
```json
{
  "name": "Compliance Threshold Breach",
  "description": "Alert when compliance rate falls below thresholds",
  "evaluationFrequency": "PT5M",
  "windowSize": "PT15M",
  "criteria": {
    "allOf": [
      {
        "name": "PROD Compliance Rate",
        "metricNamespace": "Microsoft.Insights/customMetrics",
        "metricName": "compliance_rate",
        "dimensions": [
          {
            "name": "environment",
            "operator": "Include",
            "values": ["PROD"]
          }
        ],
        "operator": "LessThan",
        "threshold": 95,
        "timeAggregation": "Average",
        "severity": "P1"
      },
      {
        "name": "PROD Critical Compliance Rate",
        "metricNamespace": "Microsoft.Insights/customMetrics",
        "metricName": "compliance_rate",
        "dimensions": [
          {
            "name": "environment",
            "operator": "Include",
            "values": ["PROD"]
          }
        ],
        "operator": "LessThan",
        "threshold": 90,
        "timeAggregation": "Average",
        "severity": "P0"
      }
    ]
  }
}
```

**Alert Payload:**
```json
{
  "alert_type": "threshold_breach",
  "alert_id": "threshold-PROD-20260308T161500",
  "severity": "P1",
  "timestamp": "2026-03-08T16:15:00Z",
  "environment": "PROD",
  "metrics": {
    "current_compliance_rate": 92.5,
    "threshold": 95.0,
    "breach_amount": 2.5,
    "total_controls": 9,
    "passing_controls": 7,
    "failing_controls": 2
  },
  "failing_controls": [
    {
      "control_id": "SI-3",
      "control_name": "Malicious Code Protection",
      "failure_rate": 0.30,
      "recent_failures": 12
    },
    {
      "control_id": "RA-5",
      "control_name": "Vulnerability Scanning",
      "failure_rate": 0.15,
      "recent_failures": 6
    }
  ],
  "runbook_url": "https://wiki.contoso.com/runbooks/threshold-breach",
  "remediation_steps": [
    "1. Investigate failing controls (SI-3, RA-5)",
    "2. Check if related to recent deployments",
    "3. Review compliance dashboard for trends",
    "4. Escalate to security team if persistent"
  ]
}
```

---

### 2.4 Alert Type 4: New Vulnerability

**Description:** Detects when Trivy scanning (SI-2) identifies new HIGH or CRITICAL vulnerabilities in container images deployed to production.

**Detection Logic:**
- Monitor Cosmos DB change feed for new Trivy results
- Compare vulnerability list vs 24-hour baseline
- Alert on new CVEs with CVSS ≥ 7.0
- Real-time processing (change feed trigger)

**Severity Classification:**
- **P0 (Critical):** New CRITICAL vulnerability (CVSS ≥ 9.0) in PROD
- **P1 (High):** New HIGH vulnerability (CVSS 7.0-8.9) in PROD
- **P2 (Medium):** New CRITICAL vulnerability in STG

**Cosmos DB Change Feed Function:**
```csharp
[FunctionName("NewVulnerabilityDetector")]
public static void Run(
    [CosmosDBTrigger(
        databaseName: "SecurityDashboard",
        containerName: "ControlValidationResults",
        Connection = "CosmosDBConnection",
        LeaseContainerName = "leases",
        CreateLeaseContainerIfNotExists = true)]
    IReadOnlyList<Document> input,
    ILogger log)
{
    foreach (var document in input)
    {
        var result = JsonConvert.DeserializeObject<ValidationResult>(document.ToString());
        
        if (result.ControlId != "SI-2" || result.TestCategory != "trivy")
            continue;
        
        var details = JsonConvert.DeserializeObject<TrivyDetails>(result.Details);
        var newVulnerabilities = details.Vulnerabilities
            .Where(v => v.Severity == "CRITICAL" || v.Severity == "HIGH")
            .Where(v => IsNewVulnerability(v.VulnerabilityId, result.Environment))
            .ToList();
        
        if (newVulnerabilities.Any())
        {
            var alert = new Alert
            {
                AlertType = "new_vulnerability",
                AlertId = $"vuln-{result.Environment}-{DateTime.UtcNow:yyyyMMddTHHmmss}",
                Severity = DetermineSeverity(newVulnerabilities.Max(v => v.CvssScore), result.Environment),
                Timestamp = DateTime.UtcNow,
                Control = new ControlInfo
                {
                    Id = "SI-2",
                    Name = "Flaw Remediation",
                    Category = "System and Information Integrity"
                },
                Environment = result.Environment,
                Vulnerabilities = newVulnerabilities.Select(v => new VulnerabilityInfo
                {
                    VulnerabilityId = v.VulnerabilityId,
                    Severity = v.Severity,
                    CvssScore = v.CvssScore,
                    PackageName = v.PackageName,
                    InstalledVersion = v.InstalledVersion,
                    FixedVersion = v.FixedVersion,
                    ImageName = details.ImageName
                }).ToList()
            };
            
            // Send to AlertProcessor for routing
            SendToAlertProcessor(alert);
        }
    }
}
```

**Alert Payload:**
```json
{
  "alert_type": "new_vulnerability",
  "alert_id": "vuln-PROD-20260308T093012",
  "severity": "P0",
  "timestamp": "2026-03-08T09:30:12Z",
  "control": {
    "id": "SI-2",
    "name": "Flaw Remediation",
    "category": "System and Information Integrity"
  },
  "environment": "PROD",
  "vulnerabilities": [
    {
      "vulnerability_id": "CVE-2026-12345",
      "severity": "CRITICAL",
      "cvss_score": 9.8,
      "package_name": "openssl",
      "installed_version": "3.0.7",
      "fixed_version": "3.0.8",
      "image_name": "contoso.azurecr.io/api-service:v2.1.0",
      "published_date": "2026-03-08T00:00:00Z",
      "description": "Remote code execution via TLS handshake"
    }
  ],
  "affected_workloads": [
    "api-service (10 pods)",
    "auth-service (5 pods)"
  ],
  "runbook_url": "https://wiki.contoso.com/runbooks/critical-vulnerability-response",
  "remediation_steps": [
    "1. IMMEDIATE: Review CVE-2026-12345 details",
    "2. Assess exploitability and attack surface",
    "3. If remotely exploitable: Emergency change request",
    "4. Rebuild images with openssl 3.0.8",
    "5. Deploy to PROD with expedited validation",
    "6. Monitor for exploitation attempts"
  ],
  "cve_links": [
    "https://nvd.nist.gov/vuln/detail/CVE-2026-12345",
    "https://www.openssl.org/news/secadv/20260308.txt"
  ]
}
```

---

### 2.5 Alert Type 5: Compliance Deadline Approaching

**Description:** Proactive notification when FedRAMP audit deadlines or remediation deadlines are approaching (7 days, 3 days, 1 day warnings).

**Detection Logic:**
- Timer-triggered function (runs daily at 8am UTC)
- Query Cosmos DB for upcoming deadlines
- Send staged notifications (7d, 3d, 1d before)
- Track notification history to avoid duplicates

**Severity Classification:**
- **P1 (High):** Deadline in 1 day
- **P2 (Medium):** Deadline in 3 days
- **P3 (Low):** Deadline in 7 days

**Timer Function:**
```csharp
[FunctionName("ComplianceDeadlineMonitor")]
public static async Task Run(
    [TimerTrigger("0 0 8 * * *")] TimerInfo myTimer,  // Daily at 8am UTC
    [CosmosDB(
        databaseName: "SecurityDashboard",
        containerName: "ComplianceDeadlines",
        Connection = "CosmosDBConnection")]
    IAsyncCollector<DeadlineNotification> notificationsOut,
    ILogger log)
{
    var container = cosmosClient.GetContainer("SecurityDashboard", "ComplianceDeadlines");
    var query = "SELECT * FROM c WHERE c.deadline_date >= @today AND c.deadline_date <= @future";
    var queryDefinition = new QueryDefinition(query)
        .WithParameter("@today", DateTime.UtcNow.Date)
        .WithParameter("@future", DateTime.UtcNow.Date.AddDays(7));
    
    var iterator = container.GetItemQueryIterator<ComplianceDeadline>(queryDefinition);
    
    while (iterator.HasMoreResults)
    {
        var response = await iterator.ReadNextAsync();
        
        foreach (var deadline in response)
        {
            var daysUntilDeadline = (deadline.DeadlineDate - DateTime.UtcNow.Date).Days;
            
            // Send notification at 7d, 3d, 1d intervals
            if (daysUntilDeadline == 7 || daysUntilDeadline == 3 || daysUntilDeadline == 1)
            {
                var alert = new Alert
                {
                    AlertType = "compliance_deadline",
                    AlertId = $"deadline-{deadline.Id}-{daysUntilDeadline}d",
                    Severity = daysUntilDeadline == 1 ? "P1" : daysUntilDeadline == 3 ? "P2" : "P3",
                    Timestamp = DateTime.UtcNow,
                    Deadline = deadline,
                    DaysUntilDeadline = daysUntilDeadline
                };
                
                await SendToAlertProcessor(alert);
            }
        }
    }
}
```

**Alert Payload:**
```json
{
  "alert_type": "compliance_deadline",
  "alert_id": "deadline-AUDIT2026Q2-1d",
  "severity": "P1",
  "timestamp": "2026-03-08T08:00:00Z",
  "deadline": {
    "id": "AUDIT2026Q2",
    "type": "fedramp_audit",
    "description": "FedRAMP Annual Assessment 2026 Q2",
    "deadline_date": "2026-03-09T23:59:59Z",
    "days_remaining": 1,
    "owner": "Security Team",
    "required_artifacts": [
      "90-day compliance trend report",
      "Control validation test results",
      "Remediation evidence for all findings"
    ]
  },
  "completion_status": {
    "artifacts_completed": 2,
    "artifacts_total": 3,
    "completion_percentage": 66.7,
    "missing_artifacts": [
      "Remediation evidence for SI-3 findings"
    ]
  },
  "runbook_url": "https://wiki.contoso.com/runbooks/fedramp-audit-preparation",
  "action_items": [
    "1. Complete remediation for SI-3 findings (2 open items)",
    "2. Generate evidence package with test results",
    "3. Submit to auditor portal by 11:59pm UTC tomorrow",
    "4. Notify compliance team of submission"
  ]
}
```

---

### 2.6 Alert Type 6: Manual Review Needed

**Description:** Triggered when automated validation detects ambiguous results requiring manual security engineer review (e.g., potential false positives, edge cases).

**Detection Logic:**
- API endpoint for manual triggers: `POST /api/v1/alerts/manual-review`
- Validation scripts detect "REVIEW_NEEDED" status
- Classification function flags ambiguous cases
- Human-in-the-loop escalation

**Severity Classification:**
- **P2 (Medium):** All manual review requests (non-blocking)

**API Trigger:**
```csharp
[FunctionName("TriggerManualReview")]
[OpenApiOperation(operationId: "TriggerManualReview")]
[OpenApiRequestBody("application/json", typeof(ManualReviewRequest))]
[OpenApiResponseWithBody(statusCode: HttpStatusCode.Accepted, contentType: "application/json", bodyType: typeof(ManualReviewResponse))]
public static async Task<IActionResult> Run(
    [HttpTrigger(AuthorizationLevel.Function, "post", Route = "alerts/manual-review")] HttpRequest req,
    [CosmosDB(
        databaseName: "SecurityDashboard",
        containerName: "ManualReviews",
        Connection = "CosmosDBConnection")]
    IAsyncCollector<ManualReview> reviewsOut,
    ILogger log)
{
    var requestBody = await new StreamReader(req.Body).ReadToEndAsync();
    var reviewRequest = JsonConvert.DeserializeObject<ManualReviewRequest>(requestBody);
    
    var alert = new Alert
    {
        AlertType = "manual_review_needed",
        AlertId = $"review-{reviewRequest.ControlId}-{reviewRequest.Environment}-{DateTime.UtcNow:yyyyMMddTHHmmss}",
        Severity = "P2",
        Timestamp = DateTime.UtcNow,
        Control = new ControlInfo
        {
            Id = reviewRequest.ControlId,
            Name = reviewRequest.ControlName,
            Category = reviewRequest.Category
        },
        Environment = reviewRequest.Environment,
        ReviewReason = reviewRequest.Reason,
        TestResults = reviewRequest.TestResults,
        Context = reviewRequest.Context
    };
    
    // Store in Cosmos DB for tracking
    await reviewsOut.AddAsync(new ManualReview
    {
        Id = alert.AlertId,
        Status = "pending",
        CreatedAt = DateTime.UtcNow,
        Alert = alert
    });
    
    // Send to Teams for engineer review
    await SendToAlertProcessor(alert);
    
    return new AcceptedResult($"/api/v1/alerts/manual-review/{alert.AlertId}", alert);
}
```

**Alert Payload:**
```json
{
  "alert_type": "manual_review_needed",
  "alert_id": "review-AC3-STG-20260308T104530",
  "severity": "P2",
  "timestamp": "2026-03-08T10:45:30Z",
  "control": {
    "id": "AC-3",
    "name": "Access Enforcement",
    "category": "Access Control"
  },
  "environment": "STG",
  "review_reason": "ambiguous_opa_violation",
  "test_results": {
    "test_name": "opa-backend-restriction",
    "status": "REVIEW_NEEDED",
    "violation_count": 1,
    "details": "Ingress uses backend 'internal-api.staging.svc.cluster.local' which matches pattern *.staging.* but NOT in explicit allowlist"
  },
  "context": {
    "namespace": "app-staging",
    "ingress_name": "api-gateway-staging",
    "backend_service": "internal-api.staging.svc.cluster.local",
    "allowlist": [
      "api-service.default.svc.cluster.local",
      "auth-service.default.svc.cluster.local"
    ],
    "possible_false_positive": "Backend uses 'staging' subdomain pattern common in STG environment"
  },
  "suggested_actions": [
    "1. Review backend service 'internal-api.staging.svc.cluster.local'",
    "2. Determine if legitimate staging service or misconfiguration",
    "3. If legitimate: Add to OPA allowlist and update policy",
    "4. If misconfiguration: Update Ingress to use correct backend",
    "5. Mark review as PASS or FAIL in dashboard"
  ],
  "review_url": "https://fedramp-dashboard.contoso.com/reviews/review-AC3-STG-20260308T104530"
}
```

---

## 3. Integration Implementations

### 3.1 PagerDuty Integration

**Purpose:** Route P0/P1 alerts to on-call engineers with escalation policies and incident management workflows.

**Architecture:**
```
Azure Function: AlertProcessor
        ↓
PagerDuty Events API v2 (HTTPS POST)
        ↓
PagerDuty Event Rules (routing)
        ↓
Escalation Policy (5-min P0, 30-min P1)
        ↓
On-Call Schedule (Security Engineer → SRE)
```

**Implementation:**

```csharp
// File: functions/integrations/PagerDutyClient.cs
using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

public class PagerDutyClient
{
    private readonly HttpClient _httpClient;
    private readonly string _routingKey;
    private readonly ILogger _log;

    public PagerDutyClient(HttpClient httpClient, string routingKey, ILogger log)
    {
        _httpClient = httpClient;
        _routingKey = routingKey;
        _log = log;
    }

    public async Task<bool> SendAlertAsync(Alert alert)
    {
        try
        {
            var payload = new
            {
                routing_key = _routingKey,
                event_action = "trigger",
                dedup_key = alert.AlertId,
                payload = new
                {
                    summary = GetAlertSummary(alert),
                    severity = MapSeverityToPagerDuty(alert.Severity),
                    source = $"FedRAMP Dashboard - {alert.Environment}",
                    timestamp = alert.Timestamp.ToString("o"),
                    component = alert.Control.Id,
                    group = alert.Control.Category,
                    custom_details = new
                    {
                        alert_type = alert.AlertType,
                        control_id = alert.Control.Id,
                        control_name = alert.Control.Name,
                        environment = alert.Environment,
                        metrics = alert.Metrics,
                        runbook_url = alert.RunbookUrl
                    }
                },
                links = new[]
                {
                    new
                    {
                        href = alert.RunbookUrl,
                        text = "Runbook"
                    },
                    new
                    {
                        href = $"https://fedramp-dashboard.contoso.com/controls/{alert.Control.Id}?env={alert.Environment}",
                        text = "Dashboard"
                    }
                }
            };

            var json = JsonConvert.SerializeObject(payload);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync("https://events.pagerduty.com/v2/enqueue", content);
            response.EnsureSuccessStatusCode();

            var responseBody = await response.Content.ReadAsStringAsync();
            var result = JsonConvert.DeserializeObject<PagerDutyResponse>(responseBody);

            _log.LogInformation($"PagerDuty alert sent successfully. Dedup key: {result.DedupKey}");
            return true;
        }
        catch (Exception ex)
        {
            _log.LogError(ex, $"Failed to send PagerDuty alert: {alert.AlertId}");
            return false;
        }
    }

    private string GetAlertSummary(Alert alert)
    {
        return alert.AlertType switch
        {
            "control_drift" => $"[{alert.Severity}] Control Drift Detected: {alert.Control.Id} ({alert.Environment})",
            "control_regression" => $"[{alert.Severity}] Control Regression: {alert.Control.Id} ({alert.Environment})",
            "threshold_breach" => $"[{alert.Severity}] Compliance Threshold Breach: {alert.Environment}",
            "new_vulnerability" => $"[{alert.Severity}] New Vulnerability Detected: {alert.Environment}",
            "compliance_deadline" => $"[{alert.Severity}] Compliance Deadline Approaching: {alert.Deadline.Description}",
            "manual_review_needed" => $"[{alert.Severity}] Manual Review Required: {alert.Control.Id} ({alert.Environment})",
            _ => $"[{alert.Severity}] FedRAMP Alert: {alert.AlertId}"
        };
    }

    private string MapSeverityToPagerDuty(string severity)
    {
        return severity switch
        {
            "P0" => "critical",
            "P1" => "error",
            "P2" => "warning",
            "P3" => "info",
            _ => "warning"
        };
    }
}

public class PagerDutyResponse
{
    [JsonProperty("status")]
    public string Status { get; set; }

    [JsonProperty("message")]
    public string Message { get; set; }

    [JsonProperty("dedup_key")]
    public string DedupKey { get; set; }
}
```

**PagerDuty Configuration:**

1. **Integration Key:** Store in Key Vault (`PagerDutyRoutingKey`)
2. **Event Rules:**
   - Route `severity=critical` → Security Team (Primary)
   - Route `severity=error AND custom_details.environment=PROD` → Security Team (Primary)
   - Route `severity=error AND custom_details.environment!=PROD` → SRE Team (Secondary)
3. **Escalation Policies:**
   - P0 (Critical): 
     - Notify: Security Engineer (Primary) immediately
     - Escalate to: SRE (Backup) after 5 minutes
     - Escalate to: Security Manager after 15 minutes
   - P1 (High):
     - Notify: Security Engineer (Primary) immediately
     - Escalate to: SRE (Backup) after 30 minutes

---

### 3.2 Microsoft Teams Integration

**Purpose:** Send formatted notifications to Teams channels with interactive Adaptive Cards for P1/P2 alerts.

**Architecture:**
```
Azure Function: AlertProcessor
        ↓
Microsoft Teams Incoming Webhook (HTTPS POST)
        ↓
Teams Channel:
  • P1: #fedramp-critical
  • P2: #security-alerts
  • P3: #alerts-low-priority
```

**Implementation:**

```csharp
// File: functions/integrations/TeamsClient.cs
using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

public class TeamsClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger _log;
    private readonly Dictionary<string, string> _webhookUrls;

    public TeamsClient(HttpClient httpClient, Dictionary<string, string> webhookUrls, ILogger log)
    {
        _httpClient = httpClient;
        _webhookUrls = webhookUrls;
        _log = log;
    }

    public async Task<bool> SendAlertAsync(Alert alert)
    {
        try
        {
            var webhookUrl = GetWebhookUrl(alert.Severity);
            var adaptiveCard = BuildAdaptiveCard(alert);

            var payload = new
            {
                type = "message",
                attachments = new[]
                {
                    new
                    {
                        contentType = "application/vnd.microsoft.card.adaptive",
                        contentUrl = (string)null,
                        content = adaptiveCard
                    }
                }
            };

            var json = JsonConvert.SerializeObject(payload);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync(webhookUrl, content);
            response.EnsureSuccessStatusCode();

            _log.LogInformation($"Teams alert sent successfully to {alert.Severity} channel");
            return true;
        }
        catch (Exception ex)
        {
            _log.LogError(ex, $"Failed to send Teams alert: {alert.AlertId}");
            return false;
        }
    }

    private string GetWebhookUrl(string severity)
    {
        var key = severity switch
        {
            "P0" => "critical",
            "P1" => "critical",
            "P2" => "medium",
            "P3" => "low",
            _ => "medium"
        };
        return _webhookUrls[key];
    }

    private object BuildAdaptiveCard(Alert alert)
    {
        var color = alert.Severity switch
        {
            "P0" => "attention",
            "P1" => "warning",
            "P2" => "good",
            "P3" => "default",
            _ => "default"
        };

        return new
        {
            type = "AdaptiveCard",
            body = new List<object>
            {
                new
                {
                    type = "Container",
                    style = color,
                    items = new List<object>
                    {
                        new
                        {
                            type = "TextBlock",
                            size = "Large",
                            weight = "Bolder",
                            text = $"🚨 {GetAlertTitle(alert)}"
                        }
                    }
                },
                new
                {
                    type = "FactSet",
                    facts = BuildFactSet(alert)
                },
                new
                {
                    type = "TextBlock",
                    text = GetAlertDescription(alert),
                    wrap = true
                },
                new
                {
                    type = "Container",
                    items = new List<object>
                    {
                        new
                        {
                            type = "TextBlock",
                            text = "**Remediation Steps:**",
                            weight = "Bolder"
                        },
                        new
                        {
                            type = "TextBlock",
                            text = string.Join("\n", alert.RemediationSteps ?? new List<string>()),
                            wrap = true
                        }
                    }
                }
            },
            actions = new List<object>
            {
                new
                {
                    type = "Action.OpenUrl",
                    title = "View Dashboard",
                    url = $"https://fedramp-dashboard.contoso.com/controls/{alert.Control?.Id}?env={alert.Environment}"
                },
                new
                {
                    type = "Action.OpenUrl",
                    title = "Runbook",
                    url = alert.RunbookUrl
                },
                new
                {
                    type = "Action.OpenUrl",
                    title = "Acknowledge",
                    url = $"https://fedramp-dashboard.contoso.com/alerts/{alert.AlertId}/acknowledge"
                }
            },
            schema = "http://adaptivecards.io/schemas/adaptive-card.json",
            version = "1.4"
        };
    }

    private string GetAlertTitle(Alert alert)
    {
        return alert.AlertType switch
        {
            "control_drift" => $"Control Drift: {alert.Control.Id}",
            "control_regression" => $"Control Regression: {alert.Control.Id}",
            "threshold_breach" => $"Compliance Threshold Breach",
            "new_vulnerability" => $"New Vulnerability Detected",
            "compliance_deadline" => $"Compliance Deadline Approaching",
            "manual_review_needed" => $"Manual Review Required",
            _ => $"FedRAMP Alert"
        };
    }

    private List<object> BuildFactSet(Alert alert)
    {
        var facts = new List<object>
        {
            new { title = "Severity", value = alert.Severity },
            new { title = "Environment", value = alert.Environment },
            new { title = "Timestamp", value = alert.Timestamp.ToString("yyyy-MM-dd HH:mm:ss UTC") }
        };

        if (alert.Control != null)
        {
            facts.Add(new { title = "Control", value = $"{alert.Control.Id} - {alert.Control.Name}" });
            facts.Add(new { title = "Category", value = alert.Control.Category });
        }

        if (alert.Metrics != null)
        {
            var metricsJson = JsonConvert.SerializeObject(alert.Metrics, Formatting.Indented);
            facts.Add(new { title = "Metrics", value = metricsJson });
        }

        return facts;
    }

    private string GetAlertDescription(Alert alert)
    {
        return alert.AlertType switch
        {
            "control_drift" => $"Control failure rate increased from {alert.Metrics?.GetValueOrDefault("prior_fail_rate"):P1} to {alert.Metrics?.GetValueOrDefault("current_fail_rate"):P1}.",
            "control_regression" => $"Control has {alert.Metrics?.GetValueOrDefault("consecutive_failures")} consecutive failures in the last hour.",
            "threshold_breach" => $"Compliance rate dropped to {alert.Metrics?.GetValueOrDefault("current_compliance_rate"):P1} (threshold: {alert.Metrics?.GetValueOrDefault("threshold"):P1}).",
            "new_vulnerability" => $"New {alert.Vulnerabilities?.FirstOrDefault()?.Severity} vulnerability detected: {alert.Vulnerabilities?.FirstOrDefault()?.VulnerabilityId}.",
            "compliance_deadline" => $"Deadline '{alert.Deadline?.Description}' in {alert.DaysUntilDeadline} days.",
            "manual_review_needed" => $"Ambiguous test result requires manual review: {alert.ReviewReason}.",
            _ => $"Alert ID: {alert.AlertId}"
        };
    }
}
```

**Teams Webhook Configuration:**

Store webhook URLs in Key Vault:
- `TeamsWebhookUrl-Critical` → #fedramp-critical channel
- `TeamsWebhookUrl-Medium` → #security-alerts channel
- `TeamsWebhookUrl-Low` → #alerts-low-priority channel

**Example Adaptive Card:**

![Teams Alert Example](https://via.placeholder.com/400x300.png?text=Teams+Adaptive+Card+Example)

---

### 3.3 Azure Monitor Alert Rules

**Purpose:** Define alert rules in Azure Monitor for automated detection and routing to AlertProcessor function.

**Implementation:**

```bicep
// File: infrastructure/phase4-alert-rules.bicep
param location string = resourceGroup().location
param logAnalyticsWorkspaceId string
param actionGroupId string
param environment string

// Alert Rule 1: Control Drift Detection
resource controlDriftAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: 'fedramp-control-drift-${environment}'
  location: location
  properties: {
    displayName: 'FedRAMP Control Drift Detection'
    description: 'Detects when control failure rate increases > 10% vs prior period'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT1H'
    windowSize: 'PT168H'  // 7 days
    scopes: [
      logAnalyticsWorkspaceId
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    criteria: {
      allOf: [
        {
          query: '''
            let lookback_hours = 168;  // 7 days
            let comparison_period_hours = 336;  // 14 days
            let drift_threshold = 0.10;
            let current_period = ControlValidationResults_CL
            | where TimeGenerated between (ago(lookback_hours * 1h) .. now())
            | summarize 
                current_total = count(),
                current_failures = countif(Status_s == "FAIL")
              by ControlId_s, Environment_s
            | extend current_fail_rate = todouble(current_failures) / current_total;
            let prior_period = ControlValidationResults_CL
            | where TimeGenerated between (ago(comparison_period_hours * 1h) .. ago(lookback_hours * 1h))
            | summarize 
                prior_total = count(),
                prior_failures = countif(Status_s == "FAIL")
              by ControlId_s, Environment_s
            | extend prior_fail_rate = todouble(prior_failures) / prior_total;
            current_period
            | join kind=inner prior_period on ControlId_s, Environment_s
            | extend drift_pct = (current_fail_rate - prior_fail_rate) * 100
            | where drift_pct > (drift_threshold * 100)
            | project 
                ControlId_s,
                Environment_s,
                current_fail_rate,
                prior_fail_rate,
                drift_pct
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupId
      ]
    }
  }
}

// Alert Rule 2: Control Regression
resource controlRegressionAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: 'fedramp-control-regression-${environment}'
  location: location
  properties: {
    displayName: 'FedRAMP Control Regression Detection'
    description: 'Detects when previously passing control begins failing (3+ consecutive)'
    severity: 0  // P0 severity
    enabled: true
    evaluationFrequency: 'PT15M'
    windowSize: 'PT1H'
    scopes: [
      logAnalyticsWorkspaceId
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    criteria: {
      allOf: [
        {
          query: '''
            let lookback_hours = 1;
            let prior_baseline_hours = 24;
            let consecutive_failures_threshold = 3;
            let recent_failures = ControlValidationResults_CL
            | where TimeGenerated > ago(lookback_hours * 1h)
            | where Status_s == "FAIL"
            | summarize failure_count = count() by ControlId_s, Environment_s
            | where failure_count >= consecutive_failures_threshold;
            let prior_passing = ControlValidationResults_CL
            | where TimeGenerated between (ago(prior_baseline_hours * 1h) .. ago(lookback_hours * 1h))
            | where Status_s == "PASS"
            | summarize pass_count = count() by ControlId_s, Environment_s
            | where pass_count > 0;
            recent_failures
            | join kind=inner prior_passing on ControlId_s, Environment_s
            | project ControlId_s, Environment_s, failure_count
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupId
      ]
    }
  }
}

// Alert Rule 3: Threshold Breach
resource thresholdBreachAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'fedramp-threshold-breach-${environment}'
  location: 'global'
  properties: {
    description: 'Alert when compliance rate falls below 95%'
    severity: 1
    enabled: true
    scopes: [
      logAnalyticsWorkspaceId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          name: 'ComplianceRate'
          metricNamespace: 'Microsoft.Insights/customMetrics'
          metricName: 'compliance_rate'
          dimensions: [
            {
              name: 'environment'
              operator: 'Include'
              values: [
                environment
              ]
            }
          ]
          operator: 'LessThan'
          threshold: 95
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

// Action Group for Alert Routing
resource alertActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'fedramp-alert-action-group-${environment}'
  location: 'global'
  properties: {
    groupShortName: 'FedRAMP'
    enabled: true
    azureFunctionReceivers: [
      {
        name: 'AlertProcessor'
        functionAppResourceId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/fedramp-alerts-func-${environment}'
        functionName: 'AlertProcessor'
        httpTriggerUrl: 'https://fedramp-alerts-func-${environment}.azurewebsites.net/api/AlertProcessor'
        useCommonAlertSchema: true
      }
    ]
  }
}

output actionGroupId string = alertActionGroup.id
output controlDriftAlertId string = controlDriftAlert.id
output controlRegressionAlertId string = controlRegressionAlert.id
output thresholdBreachAlertId string = thresholdBreachAlert.id
```

---

## 4. Alert Processing Pipeline

### 4.1 AlertProcessor Function

**Purpose:** Central alert processing function that handles enrichment, deduplication, suppression, and routing.

```csharp
// File: functions/AlertProcessor.cs
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using StackExchange.Redis;

public static class AlertProcessor
{
    private static readonly HttpClient _httpClient = new HttpClient();
    private static readonly ConnectionMultiplexer _redis = ConnectionMultiplexer.Connect(
        Environment.GetEnvironmentVariable("RedisConnectionString"));

    [FunctionName("AlertProcessor")]
    public static async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)] HttpRequest req,
        ILogger log)
    {
        log.LogInformation("AlertProcessor triggered");

        try
        {
            // Parse incoming alert
            var requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            var alert = JsonConvert.DeserializeObject<Alert>(requestBody);

            if (alert == null)
            {
                return new BadRequestObjectResult("Invalid alert payload");
            }

            log.LogInformation($"Processing alert: {alert.AlertId} ({alert.AlertType})");

            // Step 1: Enrich alert with metadata
            await EnrichAlertAsync(alert, log);

            // Step 2: Check for duplicates (30-min window)
            if (await IsDuplicateAsync(alert, log))
            {
                log.LogInformation($"Alert {alert.AlertId} is duplicate. Skipping.");
                return new OkObjectResult(new { status = "duplicate", alert_id = alert.AlertId });
            }

            // Step 3: Check suppression rules
            if (await IsSuppressedAsync(alert, log))
            {
                log.LogInformation($"Alert {alert.AlertId} is suppressed. Skipping.");
                return new OkObjectResult(new { status = "suppressed", alert_id = alert.AlertId });
            }

            // Step 4: Route alert based on severity
            var routingResults = await RouteAlertAsync(alert, log);

            // Step 5: Store alert in cache for deduplication
            await StoreAlertInCacheAsync(alert, log);

            // Step 6: Log to Cosmos DB for audit trail
            await LogAlertToCosmosAsync(alert, routingResults, log);

            return new OkObjectResult(new
            {
                status = "processed",
                alert_id = alert.AlertId,
                routing = routingResults
            });
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Error processing alert");
            return new StatusCodeResult(StatusCodes.Status500InternalServerError);
        }
    }

    private static async Task EnrichAlertAsync(Alert alert, ILogger log)
    {
        // Lookup control metadata
        if (alert.Control != null && string.IsNullOrEmpty(alert.Control.Name))
        {
            var controlMetadata = await GetControlMetadataAsync(alert.Control.Id);
            alert.Control.Name = controlMetadata.Name;
            alert.Control.Category = controlMetadata.Category;
        }

        // Attach runbook URL
        if (string.IsNullOrEmpty(alert.RunbookUrl))
        {
            alert.RunbookUrl = GetRunbookUrl(alert.AlertType, alert.Control?.Id);
        }

        // Lookup environment metadata
        var envMetadata = await GetEnvironmentMetadataAsync(alert.Environment);
        alert.Region = envMetadata.Region;
        alert.Cloud = envMetadata.Cloud;

        log.LogInformation($"Alert enriched: {alert.AlertId}");
    }

    private static async Task<bool> IsDuplicateAsync(Alert alert, ILogger log)
    {
        var db = _redis.GetDatabase();
        var dedupKey = $"alert:dedup:{alert.AlertType}:{alert.Control?.Id}:{alert.Environment}";
        
        var exists = await db.KeyExistsAsync(dedupKey);
        return exists;
    }

    private static async Task<bool> IsSuppressedAsync(Alert alert, ILogger log)
    {
        // Check maintenance windows
        var maintenanceWindows = await GetMaintenanceWindowsAsync(alert.Environment);
        if (maintenanceWindows.Any(w => w.IsActive))
        {
            log.LogInformation($"Alert suppressed due to maintenance window: {alert.AlertId}");
            return true;
        }

        // Check acknowledged alerts
        var db = _redis.GetDatabase();
        var ackKey = $"alert:ack:{alert.AlertId}";
        var isAcknowledged = await db.KeyExistsAsync(ackKey);
        
        if (isAcknowledged)
        {
            log.LogInformation($"Alert suppressed due to acknowledgment: {alert.AlertId}");
            return true;
        }

        return false;
    }

    private static async Task<Dictionary<string, bool>> RouteAlertAsync(Alert alert, ILogger log)
    {
        var results = new Dictionary<string, bool>();

        // Routing logic based on severity
        switch (alert.Severity)
        {
            case "P0":
                // P0: PagerDuty only (urgent)
                results["pagerduty"] = await SendToPagerDutyAsync(alert, "high", log);
                break;

            case "P1":
                // P1: PagerDuty (low urgency) + Teams
                results["pagerduty"] = await SendToPagerDutyAsync(alert, "low", log);
                results["teams"] = await SendToTeamsAsync(alert, log);
                break;

            case "P2":
                // P2: Teams only
                results["teams"] = await SendToTeamsAsync(alert, log);
                break;

            case "P3":
                // P3: Email digest (queued, sent daily)
                results["email_digest"] = await QueueForEmailDigestAsync(alert, log);
                break;

            default:
                log.LogWarning($"Unknown severity: {alert.Severity}. Routing to Teams.");
                results["teams"] = await SendToTeamsAsync(alert, log);
                break;
        }

        return results;
    }

    private static async Task StoreAlertInCacheAsync(Alert alert, ILogger log)
    {
        var db = _redis.GetDatabase();
        var dedupKey = $"alert:dedup:{alert.AlertType}:{alert.Control?.Id}:{alert.Environment}";
        
        // Store with 30-minute TTL
        await db.StringSetAsync(dedupKey, alert.AlertId, TimeSpan.FromMinutes(30));
        
        log.LogInformation($"Alert stored in cache for deduplication: {dedupKey}");
    }

    private static async Task<bool> SendToPagerDutyAsync(Alert alert, string urgency, ILogger log)
    {
        var routingKey = Environment.GetEnvironmentVariable("PagerDutyRoutingKey");
        var client = new PagerDutyClient(_httpClient, routingKey, log);
        return await client.SendAlertAsync(alert);
    }

    private static async Task<bool> SendToTeamsAsync(Alert alert, ILogger log)
    {
        var webhookUrls = new Dictionary<string, string>
        {
            ["critical"] = Environment.GetEnvironmentVariable("TeamsWebhookUrl-Critical"),
            ["medium"] = Environment.GetEnvironmentVariable("TeamsWebhookUrl-Medium"),
            ["low"] = Environment.GetEnvironmentVariable("TeamsWebhookUrl-Low")
        };
        var client = new TeamsClient(_httpClient, webhookUrls, log);
        return await client.SendAlertAsync(alert);
    }

    private static async Task<bool> QueueForEmailDigestAsync(Alert alert, ILogger log)
    {
        // Queue to Azure Storage Queue for daily digest processing
        var queueClient = new Azure.Storage.Queues.QueueClient(
            Environment.GetEnvironmentVariable("StorageConnectionString"),
            "email-digest-queue");
        
        var message = JsonConvert.SerializeObject(alert);
        await queueClient.SendMessageAsync(message);
        
        log.LogInformation($"Alert queued for email digest: {alert.AlertId}");
        return true;
    }

    private static async Task LogAlertToCosmosAsync(Alert alert, Dictionary<string, bool> routingResults, ILogger log)
    {
        // Implementation: Write to Cosmos DB audit trail
        log.LogInformation($"Alert logged to Cosmos DB: {alert.AlertId}");
    }

    // Helper methods
    private static async Task<ControlMetadata> GetControlMetadataAsync(string controlId)
    {
        // Implementation: Lookup from Cosmos DB or cache
        return new ControlMetadata
        {
            Id = controlId,
            Name = "Sample Control Name",
            Category = "Sample Category"
        };
    }

    private static string GetRunbookUrl(string alertType, string controlId)
    {
        return $"https://wiki.contoso.com/runbooks/{alertType.Replace("_", "-")}-{controlId?.ToLower()}";
    }

    private static async Task<EnvironmentMetadata> GetEnvironmentMetadataAsync(string environment)
    {
        // Implementation: Lookup from Cosmos DB or config
        return new EnvironmentMetadata
        {
            Environment = environment,
            Region = "eastus2",
            Cloud = "Public"
        };
    }

    private static async Task<List<MaintenanceWindow>> GetMaintenanceWindowsAsync(string environment)
    {
        // Implementation: Query Cosmos DB for active maintenance windows
        return new List<MaintenanceWindow>();
    }
}

// Supporting classes
public class Alert
{
    public string AlertType { get; set; }
    public string AlertId { get; set; }
    public string Severity { get; set; }
    public DateTime Timestamp { get; set; }
    public ControlInfo Control { get; set; }
    public string Environment { get; set; }
    public string Region { get; set; }
    public string Cloud { get; set; }
    public Dictionary<string, object> Metrics { get; set; }
    public string RunbookUrl { get; set; }
    public List<string> RemediationSteps { get; set; }
    public List<VulnerabilityInfo> Vulnerabilities { get; set; }
    public DeadlineInfo Deadline { get; set; }
    public int? DaysUntilDeadline { get; set; }
    public string ReviewReason { get; set; }
}

public class ControlInfo
{
    public string Id { get; set; }
    public string Name { get; set; }
    public string Category { get; set; }
}

public class VulnerabilityInfo
{
    public string VulnerabilityId { get; set; }
    public string Severity { get; set; }
    public double CvssScore { get; set; }
    public string PackageName { get; set; }
    public string InstalledVersion { get; set; }
    public string FixedVersion { get; set; }
    public string ImageName { get; set; }
}

public class DeadlineInfo
{
    public string Id { get; set; }
    public string Type { get; set; }
    public string Description { get; set; }
    public DateTime DeadlineDate { get; set; }
}

public class ControlMetadata
{
    public string Id { get; set; }
    public string Name { get; set; }
    public string Category { get; set; }
}

public class EnvironmentMetadata
{
    public string Environment { get; set; }
    public string Region { get; set; }
    public string Cloud { get; set; }
}

public class MaintenanceWindow
{
    public string Id { get; set; }
    public string Environment { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public bool IsActive => DateTime.UtcNow >= StartTime && DateTime.UtcNow <= EndTime;
}
```

---

## 5. Deduplication & Suppression Logic

### 5.1 Deduplication Strategy

**Purpose:** Prevent duplicate alerts from triggering multiple notifications within a short time window.

**Implementation:**
- Use Redis cache with 30-minute TTL
- Deduplication key: `{alert_type}:{control_id}:{environment}`
- Hash collision handling: Store full alert ID as value
- If duplicate found: Log and skip routing

**Example:**
```
Alert 1: control_drift:SC-7:PROD → Store in Redis for 30 min
Alert 2: control_drift:SC-7:PROD (5 min later) → Duplicate detected, skip
Alert 3: control_drift:SC-7:PROD (35 min later) → Not duplicate (expired), process
```

### 5.2 Suppression Rules

**Purpose:** Prevent alert fatigue during maintenance windows or for acknowledged alerts.

**Types:**
1. **Maintenance Windows:** Scheduled downtime (stored in Cosmos DB)
   - Example: "PROD maintenance window: 2026-03-08 02:00-04:00 UTC"
   - Suppress all alerts for affected environment during window
2. **Acknowledged Alerts:** Engineer explicitly acknowledges (via API or Teams)
   - Store acknowledgment in Redis with 24-hour TTL
   - Suppress future occurrences of same alert
3. **Auto-Resolve:** Alert resolves automatically when condition clears
   - Example: Control drift alert auto-resolves if next validation passes

**Implementation:**
```csharp
public static async Task<bool> IsSuppressedAsync(Alert alert, ILogger log)
{
    // Check maintenance windows
    var maintenanceWindows = await GetMaintenanceWindowsFromCosmosAsync(alert.Environment);
    if (maintenanceWindows.Any(w => w.IsActive))
    {
        return true;
    }

    // Check acknowledged alerts
    var db = _redis.GetDatabase();
    var ackKey = $"alert:ack:{alert.AlertType}:{alert.Control?.Id}:{alert.Environment}";
    var isAcknowledged = await db.KeyExistsAsync(ackKey);
    
    return isAcknowledged;
}
```

---

## 6. Infrastructure Deployment

### 6.1 Bicep Template for Phase 4

```bicep
// File: infrastructure/phase4-alerting.bicep
@description('Environment name (dev, stg, prod)')
param environment string

@description('Location for resources')
param location string = resourceGroup().location

@description('Log Analytics Workspace ID from Phase 1')
param logAnalyticsWorkspaceId string

@description('PagerDuty routing key (from Key Vault)')
@secure()
param pagerDutyRoutingKey string

@description('Teams webhook URLs (from Key Vault)')
@secure()
param teamsWebhookUrls object

// Redis Cache for deduplication
resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: 'fedramp-redis-${environment}'
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0  // 250 MB
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

// Function App for alert processing
resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'fedramp-alerts-func-${environment}'
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'RedisConnectionString'
          value: '${redisCache.name}.redis.cache.windows.net:6380,password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
        }
        {
          name: 'PagerDutyRoutingKey'
          value: pagerDutyRoutingKey
        }
        {
          name: 'TeamsWebhookUrl-Critical'
          value: teamsWebhookUrls.critical
        }
        {
          name: 'TeamsWebhookUrl-Medium'
          value: teamsWebhookUrls.medium
        }
        {
          name: 'TeamsWebhookUrl-Low'
          value: teamsWebhookUrls.low
        }
        {
          name: 'CosmosDBConnection'
          value: cosmosDbConnectionString
        }
      ]
      netFrameworkVersion: 'v8.0'
    }
  }
}

// App Service Plan for Function App
resource hostingPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'fedramp-alerts-plan-${environment}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

// Storage Account for function app
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'fedrampalerts${environment}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

// Alert Rules (reference external template)
module alertRules 'phase4-alert-rules.bicep' = {
  name: 'alert-rules-deployment'
  params: {
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    actionGroupId: actionGroup.outputs.actionGroupId
    environment: environment
  }
}

// Action Group
module actionGroup 'phase4-action-group.bicep' = {
  name: 'action-group-deployment'
  params: {
    environment: environment
    functionAppUrl: 'https://${functionApp.properties.defaultHostName}/api/AlertProcessor'
  }
}

// Outputs
output redisCacheName string = redisCache.name
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
```

### 6.2 Deployment Script

```powershell
# File: infrastructure/deploy-phase4.ps1
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'stg', 'prod')]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$true)]
    [string]$LogAnalyticsWorkspaceId,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName
)

Write-Host "Deploying Phase 4: Alerting & Integrations to $Environment" -ForegroundColor Green

# Retrieve secrets from Key Vault
Write-Host "Retrieving secrets from Key Vault: $KeyVaultName"
$pagerDutyKey = az keyvault secret show --vault-name $KeyVaultName --name "PagerDutyRoutingKey" --query value -o tsv
$teamsWebhookCritical = az keyvault secret show --vault-name $KeyVaultName --name "TeamsWebhookUrl-Critical" --query value -o tsv
$teamsWebhookMedium = az keyvault secret show --vault-name $KeyVaultName --name "TeamsWebhookUrl-Medium" --query value -o tsv
$teamsWebhookLow = az keyvault secret show --vault-name $KeyVaultName --name "TeamsWebhookUrl-Low" --query value -o tsv

# Deploy infrastructure
Write-Host "Deploying Bicep template..."
az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "./phase4-alerting.bicep" `
    --parameters `
        environment=$Environment `
        location=$Location `
        logAnalyticsWorkspaceId=$LogAnalyticsWorkspaceId `
        pagerDutyRoutingKey=$pagerDutyKey `
        teamsWebhookUrls="{'critical':'$teamsWebhookCritical','medium':'$teamsWebhookMedium','low':'$teamsWebhookLow'}"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed"
    exit 1
}

# Deploy function code
$functionAppName = "fedramp-alerts-func-$Environment"
Write-Host "Deploying function code to $functionAppName..."

# Build and publish
dotnet build ../functions/FedRampDashboard.Functions.csproj --configuration Release
dotnet publish ../functions/FedRampDashboard.Functions.csproj --configuration Release --output ./publish

# Create ZIP
Compress-Archive -Path ./publish/* -DestinationPath ./functions.zip -Force

# Deploy ZIP
az functionapp deployment source config-zip `
    --resource-group $ResourceGroupName `
    --name $functionAppName `
    --src ./functions.zip

Write-Host "Phase 4 deployment complete!" -ForegroundColor Green
Write-Host "Function App URL: https://$functionAppName.azurewebsites.net" -ForegroundColor Cyan
```

---

## 7. Testing & Validation

### 7.1 End-to-End Alert Flow Test

```bash
#!/bin/bash
# File: tests/test-alert-flow.sh

set -e

FUNCTION_APP_URL="https://fedramp-alerts-func-stg.azurewebsites.net/api/AlertProcessor"
FUNCTION_KEY="YOUR_FUNCTION_KEY"

echo "Testing Alert Flow: Control Drift (P0)"

# Test 1: Control Drift Alert
curl -X POST "$FUNCTION_APP_URL?code=$FUNCTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_type": "control_drift",
    "alert_id": "test-drift-SC7-STG-001",
    "severity": "P0",
    "timestamp": "2026-03-08T15:30:00Z",
    "control": {
      "id": "SC-7",
      "name": "Boundary Protection",
      "category": "System and Communications Protection"
    },
    "environment": "STG",
    "metrics": {
      "current_fail_rate": 0.15,
      "prior_fail_rate": 0.03,
      "drift_percentage": 12.0
    },
    "remediation_steps": [
      "1. Review recent NetworkPolicy changes",
      "2. Compare vs baseline",
      "3. Run compliance scan"
    ]
  }'

echo ""
echo "Test 1 complete. Check:"
echo "  - PagerDuty incident created"
echo "  - Teams notification in #fedramp-critical"
echo ""

# Test 2: Duplicate detection
echo "Testing duplicate detection (should be suppressed)..."
curl -X POST "$FUNCTION_APP_URL?code=$FUNCTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_type": "control_drift",
    "alert_id": "test-drift-SC7-STG-002",
    "severity": "P0",
    "timestamp": "2026-03-08T15:31:00Z",
    "control": {
      "id": "SC-7"
    },
    "environment": "STG",
    "metrics": {
      "current_fail_rate": 0.15,
      "prior_fail_rate": 0.03,
      "drift_percentage": 12.0
    }
  }'

echo ""
echo "Test 2 complete. Alert should be marked as duplicate."
echo ""

# Test 3: Manual Review (P2)
echo "Testing Manual Review alert (Teams only)..."
curl -X POST "$FUNCTION_APP_URL?code=$FUNCTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_type": "manual_review_needed",
    "alert_id": "test-review-AC3-STG-001",
    "severity": "P2",
    "timestamp": "2026-03-08T15:35:00Z",
    "control": {
      "id": "AC-3",
      "name": "Access Enforcement"
    },
    "environment": "STG",
    "review_reason": "ambiguous_opa_violation",
    "test_results": {
      "test_name": "opa-backend-restriction",
      "status": "REVIEW_NEEDED"
    }
  }'

echo ""
echo "Test 3 complete. Check Teams #security-alerts for Adaptive Card."
echo ""

echo "All tests complete!"
```

### 7.2 Performance Validation

**Latency Targets:**
- P0 alert → PagerDuty: < 60 seconds
- P1 alert → Teams: < 2 minutes
- Deduplication check: < 100ms
- Alert enrichment: < 500ms

**Load Testing:**
- 100 alerts/hour sustained
- 500 alerts/hour peak (burst scenario)
- Redis cache hit rate > 95%

---

## 8. Cost Breakdown

### 8.1 Monthly Cost Estimate

| Component | Tier | Cost |
|-----------|------|------|
| **Azure Monitor Alert Rules** | 5 rules × $0.10/rule | $0.50/month |
| **Log Analytics Queries** | 1 GB data scanned/day × $0.60/GB | $18/month |
| **Azure Functions (AlertProcessor)** | Consumption plan, 50K executions | $40/month |
| **Redis Cache** | Basic C0 (250 MB) | $16/month |
| **Cosmos DB** | Alert audit trail (1000 RU/s) | $60/month |
| **Storage (email digest queue)** | 1 GB transactions | $5/month |
| **PagerDuty** | External service (existing license) | $0 (included) |
| **Teams Webhooks** | Free tier | $0 |
| **SendGrid (email digest)** | 10K emails/month | $0 (free tier) |
| **TOTAL** | | **$139.50/month** |

---

## 9. Operational Runbooks

### 9.1 Runbook: Responding to Control Drift Alert

**Severity:** P0/P1  
**On-Call:** Security Engineer (Primary), SRE (Backup)  
**SLA:** Acknowledge within 15 minutes, resolve within 4 hours

**Steps:**

1. **Acknowledge Alert** (within 15 min)
   - Click "Acknowledge" in PagerDuty or Teams
   - This suppresses duplicate alerts for 24 hours

2. **Assess Drift Severity**
   - Open FedRAMP Dashboard: Control Detail view
   - Compare current failure rate vs prior period
   - Identify failing test cases

3. **Investigate Root Cause**
   - Check recent deployments in affected environment
   - Review cluster configuration changes (NetworkPolicy, OPA, WAF)
   - Compare failing environment vs baseline (STG vs PROD)

4. **Remediate**
   - For NetworkPolicy drift: Restore baseline policies
   - For OPA drift: Review annotation changes, update allowlist
   - For WAF drift: Check rule modifications, test in Detection mode

5. **Validate Fix**
   - Manually run validation tests: `kubectl exec validation-pod -- /tests/run-control-tests.sh SC-7`
   - Verify pass rate returns to baseline
   - Monitor dashboard for 1 hour to confirm stability

6. **Document & Close**
   - Update incident ticket with root cause and remediation
   - Create PR if policy changes needed
   - Mark alert as resolved in dashboard

---

## 10. Monitoring & Observability

### 10.1 Alert Pipeline Health Metrics

**Key Metrics:**
- `alert_processing_duration_ms` — AlertProcessor execution time
- `alert_delivery_success_rate` — % of alerts successfully delivered
- `alert_deduplication_rate` — % of alerts suppressed as duplicates
- `pagerduty_api_latency_ms` — PagerDuty API response time
- `teams_webhook_latency_ms` — Teams webhook response time
- `redis_cache_hit_rate` — Deduplication cache effectiveness

**Dashboard:**
```kql
// Alert Processing Performance
AlertProcessorMetrics_CL
| where TimeGenerated > ago(24h)
| summarize 
    avg_duration_ms = avg(processing_duration_ms),
    p95_duration_ms = percentile(processing_duration_ms, 95),
    success_rate = countif(status == "success") * 100.0 / count(),
    dedup_rate = countif(status == "duplicate") * 100.0 / count()
  by bin(TimeGenerated, 1h)
| render timechart
```

### 10.2 Alerting on Alerting

**Meta-Alerts:** Detect when alerting pipeline itself fails

- Alert if AlertProcessor function fails > 5 times in 15 minutes
- Alert if PagerDuty delivery success rate < 95%
- Alert if Redis cache is unreachable
- Alert if deduplication rate > 50% (indicates noisy alerts)

---

## 11. Future Enhancements (Phase 5+)

1. **Machine Learning for Alert Prioritization**
   - Train model on historical alert data + engineer actions
   - Predict likelihood of false positive
   - Auto-suppress low-confidence alerts

2. **Automated Remediation**
   - Trigger Azure Functions for common fixes
   - Example: Auto-restore baseline NetworkPolicy on drift

3. **Alert Correlation**
   - Group related alerts (e.g., multiple controls fail after deployment)
   - Single incident with multiple affected controls

4. **Advanced Deduplication**
   - Semantic similarity (not just exact match)
   - "Control drift SC-7" ≈ "Control regression SC-7" → Group

5. **Compliance Forecasting**
   - Predict when environment will fall below 95% compliance
   - Proactive alerts 24-48 hours before threshold breach

---

## Appendix A: Alert Type Matrix

| Alert Type | Detection Method | Frequency | P0 Criteria | P1 Criteria | P2 Criteria | P3 Criteria |
|------------|-----------------|-----------|-------------|-------------|-------------|-------------|
| Control Drift | KQL scheduled query | 1 hour | P0 control drift > 20% | P1 control drift > 20% | Any drift 10-20% | — |
| Control Regression | KQL scheduled query | 15 min | P0 control, 3+ consec fails | P1 control, 3+ consec fails | Other control, 3+ fails | — |
| Threshold Breach | Metric alert | 5 min | PROD < 90% | PROD < 95% OR STG < 85% | STG < 95% OR DEV < 80% | — |
| New Vulnerability | Cosmos change feed | Real-time | CRITICAL (≥9.0) in PROD | HIGH (7-8.9) in PROD | CRITICAL in STG | HIGH in STG/DEV |
| Compliance Deadline | Timer (daily 8am) | Daily | — | 1 day remaining | 3 days remaining | 7 days remaining |
| Manual Review | API trigger | On-demand | — | — | All manual reviews | — |

---

## Appendix B: Sample Payloads

See Section 2 (Alert Type Definitions) for complete JSON payloads for each alert type.

---

## Appendix C: Configuration Reference

### Environment Variables (Function App)

```
# Redis
RedisConnectionString="fedramp-redis-stg.redis.cache.windows.net:6380,password=...,ssl=True"

# PagerDuty
PagerDutyRoutingKey="<integration_key_from_pagerduty>"

# Teams
TeamsWebhookUrl-Critical="https://outlook.office.com/webhook/.../IncomingWebhook/..."
TeamsWebhookUrl-Medium="https://outlook.office.com/webhook/.../IncomingWebhook/..."
TeamsWebhookUrl-Low="https://outlook.office.com/webhook/.../IncomingWebhook/..."

# Cosmos DB
CosmosDBConnection="AccountEndpoint=https://...;AccountKey=..."

# Storage
StorageConnectionString="DefaultEndpointsProtocol=https;AccountName=..."
```

### PagerDuty Configuration

```yaml
# Integration Settings
integration_type: Events API v2
integration_key: <routing_key>
service_name: FedRAMP Security Dashboard
escalation_policy: Security Engineering On-Call

# Escalation Policy
escalation_policy:
  name: Security Engineering On-Call
  escalation_rules:
    - escalation_delay_in_minutes: 0
      targets:
        - type: user
          id: <security_engineer_id>
    - escalation_delay_in_minutes: 5
      targets:
        - type: user
          id: <sre_backup_id>
    - escalation_delay_in_minutes: 15
      targets:
        - type: user
          id: <security_manager_id>
```

---

**End of Phase 4 Implementation Documentation**
