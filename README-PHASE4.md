# Phase 4: Alerting & Integrations - README

## Overview

Phase 4 implements comprehensive alerting and notification capabilities for the FedRAMP Security Dashboard. This phase transforms passive monitoring into active incident response with intelligent routing to PagerDuty, Microsoft Teams, and email.

## Quick Start

### Prerequisites

1. **Phase 1 (Data Pipeline)** deployed and operational
2. **Phase 2 (REST API)** deployed and operational
3. **Key Vault** with the following secrets:
   - `PagerDutyRoutingKey` - PagerDuty Events API v2 integration key
   - `TeamsWebhookUrl-Critical` - Teams incoming webhook for P0/P1 alerts
   - `TeamsWebhookUrl-Medium` - Teams incoming webhook for P2 alerts
   - `TeamsWebhookUrl-Low` - Teams incoming webhook for P3 alerts

### Deployment

```powershell
cd infrastructure

.\deploy-phase4.ps1 `
  -Environment stg `
  -ResourceGroupName fedramp-dashboard-stg-rg `
  -Location eastus2 `
  -LogAnalyticsWorkspaceId "/subscriptions/.../workspaces/fedramp-logs-stg" `
  -KeyVaultName fedramp-kv-stg `
  -CosmosDbConnectionString "AccountEndpoint=https://..."
```

### Testing

```bash
cd tests
chmod +x test-alert-flow.sh

# Set environment variables
export FUNCTION_APP_URL="https://fedramp-alerts-func-stg.azurewebsites.net/api/AlertProcessor"
export FUNCTION_KEY="your-function-key"

# Run tests
./test-alert-flow.sh
```

## Alert Types

### 1. Control Drift Detection
- **Detection:** KQL scheduled query (runs hourly)
- **Trigger:** Failure rate increases > 10% vs prior 7-day period
- **Severity:** P0 (P0 controls), P1 (P1 controls), P2 (others)

### 2. Control Regression
- **Detection:** KQL scheduled query (runs every 15 min)
- **Trigger:** 3+ consecutive failures in last hour (previously passing)
- **Severity:** P0 (P0 controls), P1 (P1 controls), P2 (others)

### 3. Threshold Breach
- **Detection:** KQL scheduled query (runs every 5 min)
- **Trigger:** Compliance rate < 95% for 15+ minutes
- **Severity:** P0 (< 90% PROD), P1 (< 95% PROD), P2 (< 95% STG)

### 4. New Vulnerability
- **Detection:** Cosmos DB change feed (real-time)
- **Trigger:** New HIGH/CRITICAL CVE detected in container images
- **Severity:** P0 (CRITICAL in PROD), P1 (HIGH in PROD), P2 (STG)

### 5. Compliance Deadline
- **Detection:** Timer function (daily at 8am UTC)
- **Trigger:** Deadline approaching (7d, 3d, 1d warnings)
- **Severity:** P1 (1d), P2 (3d), P3 (7d)

### 6. Manual Review Needed
- **Detection:** API trigger from validation scripts
- **Trigger:** Ambiguous test result requiring human review
- **Severity:** P2 (non-blocking)

## Alert Routing

| Severity | PagerDuty | Teams Channel | Email Digest |
|----------|-----------|---------------|--------------|
| P0 | ✓ (critical) | - | - |
| P1 | ✓ (error) | #fedramp-critical | - |
| P2 | - | #security-alerts | - |
| P3 | - | #alerts-low-priority | ✓ (daily) |

## Deduplication

Alerts are deduplicated using Redis cache with 30-minute TTL:
- **Key:** `{alert_type}:{control_id}:{environment}`
- **Purpose:** Prevent alert fatigue from repeated notifications
- **Window:** 30 minutes
- **Example:** Control drift for SC-7 in PROD triggers once per 30 min

## Suppression

Alerts can be suppressed:
1. **Maintenance Windows:** Scheduled downtime (stored in Cosmos DB)
2. **Acknowledgment:** Engineer acknowledges via Teams button or API
3. **Auto-Resolve:** Alert resolves when condition clears

## Monitoring

### Application Insights Queries

**Alert Processing Latency:**
```kql
traces
| where message contains "Alert processed"
| extend duration_ms = todouble(customDimensions.duration_ms)
| summarize avg(duration_ms), percentile(duration_ms, 95) by bin(timestamp, 1h)
| render timechart
```

**Alert Routing Success Rate:**
```kql
traces
| where message contains "Alert processed"
| extend routing = parse_json(customDimensions.routing)
| extend pagerduty_success = routing.pagerduty == true
| extend teams_success = routing.teams == true
| summarize 
    pd_success_rate = countif(pagerduty_success) * 100.0 / count(),
    teams_success_rate = countif(teams_success) * 100.0 / count()
  by bin(timestamp, 1h)
```

**Deduplication Rate:**
```kql
traces
| where message contains "is duplicate" or message contains "Alert processed"
| extend is_duplicate = message contains "duplicate"
| summarize 
    total = count(),
    duplicates = countif(is_duplicate)
  by bin(timestamp, 1h)
| extend dedup_rate = (duplicates * 100.0) / total
| render timechart
```

## Troubleshooting

### Issue: Alerts not reaching PagerDuty

1. Check Function App configuration:
   ```powershell
   az functionapp config appsettings list `
     --name fedramp-alerts-func-stg `
     --resource-group fedramp-dashboard-stg-rg `
     --query "[?name=='PagerDutyRoutingKey'].value"
   ```

2. Test PagerDuty integration manually:
   ```bash
   curl -X POST https://events.pagerduty.com/v2/enqueue \
     -H "Content-Type: application/json" \
     -d '{
       "routing_key": "YOUR_KEY",
       "event_action": "trigger",
       "payload": {
         "summary": "Test alert",
         "severity": "info",
         "source": "manual-test"
       }
     }'
   ```

3. Check Application Insights for errors:
   ```kql
   exceptions
   | where outerMessage contains "PagerDuty"
   | project timestamp, outerMessage, innermostMessage
   | order by timestamp desc
   ```

### Issue: Teams notifications not appearing

1. Verify webhook URL is valid (test in browser or curl)
2. Check Function App logs for HTTP response codes
3. Validate Adaptive Card JSON structure (use Teams Adaptive Card designer)

### Issue: High deduplication rate (> 50%)

This indicates noisy alerts. Investigate:
1. Are alert rules too sensitive?
2. Is the 30-minute deduplication window too long?
3. Review alert frequency in KQL queries

## Cost Optimization

Current monthly cost: **$140**

To reduce costs:
1. **Redis Cache:** Use Basic C0 (smallest tier) - Already optimized
2. **Function App:** Consumption plan (pay-per-execution) - Already optimized
3. **Alert Rules:** Increase evaluation frequency to reduce queries
4. **Cosmos DB:** Reduce throughput if alert volume is low

## Documentation

- **Full Documentation:** `docs/fedramp-dashboard-phase4-alerting.md` (78KB)
- **API Specification:** `api/openapi-fedramp-dashboard.yaml`
- **Phase 1 Docs:** `docs/fedramp-dashboard-phase1-data-pipeline.md`
- **Phase 2 Docs:** `docs/fedramp-dashboard-phase2-api-rbac.md`

## Support

For issues or questions:
- **On-Call:** Security Engineering team (via PagerDuty)
- **Teams:** #fedramp-dashboard channel
- **Wiki:** https://wiki.contoso.com/fedramp-dashboard

## Next Steps: Phase 5

Phase 5 will implement:
1. React dashboard UI with real-time updates
2. Control drill-down views
3. Historical trend visualization
4. Role-based access control (RBAC) UI
5. Alert acknowledgment UI

**Timeline:** Weeks 9-10
