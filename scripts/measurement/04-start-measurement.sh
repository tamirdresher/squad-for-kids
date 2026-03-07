#!/bin/bash
# WAF/OPA False Positive Measurement - Start Measurement Cycle
# Owner: Worf (Security & Cloud)
# Purpose: Initialize 10-day measurement window with baseline metrics

set -euo pipefail

# Load configuration
if [ ! -f measurement-config.env ]; then
  echo "❌ Error: measurement-config.env not found. Run 01-setup-telemetry.sh first."
  exit 1
fi
source measurement-config.env

MEASUREMENT_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
MEASUREMENT_DAY=1

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Starting false positive measurement cycle"
echo "  - Start time: $MEASUREMENT_START"
echo "  - Duration: 10 days"
echo "  - Environment: ${ENVIRONMENT:-dev-eus2}"
echo ""

# 1. Create measurement metadata in Cosmos DB
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Creating measurement metadata"

COSMOS_ENDPOINT="https://${COSMOS_ACCOUNT}.documents.azure.com:443/"
COSMOS_KEY=$(az cosmosdb keys list \
  --name "$COSMOS_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query primaryMasterKey -o tsv)

# Create measurement session document
cat > /tmp/measurement-session.json <<EOF
{
  "id": "measurement-$(date +%Y%m%d-%H%M%S)",
  "type": "measurement-session",
  "startTime": "$MEASUREMENT_START",
  "environment": "${ENVIRONMENT:-dev-eus2}",
  "duration": "10 days",
  "status": "active",
  "wafPolicies": [
    {
      "id": "OWASP-DRS-2.1",
      "name": "OWASP Core Rule Set",
      "mode": "Detection"
    },
    {
      "id": "Custom-001",
      "name": "nginx-config-injection-block",
      "mode": "Detection"
    },
    {
      "id": "Custom-002",
      "name": "annotation-abuse-block",
      "mode": "Detection"
    },
    {
      "id": "Custom-003",
      "name": "heartbeat-ddos-ratelimit",
      "mode": "Detection"
    }
  ],
  "opaPolicies": [
    {
      "id": "DK8SIngressSafePath",
      "name": "Path injection prevention",
      "mode": "dryrun"
    },
    {
      "id": "DK8SIngressAnnotationAllowlist",
      "name": "Annotation safety",
      "mode": "dryrun"
    },
    {
      "id": "DK8SIngressBackendRestriction",
      "name": "Infrastructure protection",
      "mode": "dryrun"
    },
    {
      "id": "DK8SIngressTLSRequired",
      "name": "TLS enforcement",
      "mode": "dryrun"
    },
    {
      "id": "DK8SIngressNoWildcardHost",
      "name": "Wildcard prevention",
      "mode": "dryrun"
    }
  ],
  "targets": {
    "wafFalsePositiveRate": "< 1.0%",
    "opaFalsePositiveRate": "< 1.0%",
    "falseNegatives": 0
  }
}
EOF

# Upload to Cosmos DB using Azure CLI (simplified approach)
az cosmosdb sql container item create \
  --account-name "$COSMOS_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --database-name "$COSMOS_DATABASE" \
  --container-name "$COSMOS_COLLECTION" \
  --body @/tmp/measurement-session.json

echo "✅ Measurement session created in Cosmos DB"

# 2. Capture baseline metrics (pre-measurement traffic)
echo ""
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Capturing baseline metrics"

# Query WAF logs for baseline (last 24 hours)
cat > /tmp/baseline-waf.kql <<EOF
FrontdoorWebApplicationFirewallLog
| where TimeGenerated >= ago(24h)
| summarize 
    TotalRequests = count(),
    UniqueIPs = dcount(clientIP_s),
    AvgRequestsPerHour = count() / 24
| project TotalRequests, UniqueIPs, AvgRequestsPerHour
EOF

WAF_BASELINE=$(az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "$(cat /tmp/baseline-waf.kql)" \
  --query "tables[0].rows[0]" -o tsv)

echo "  WAF Baseline (last 24h):"
echo "    - Total Requests: $(echo $WAF_BASELINE | cut -f1)"
echo "    - Unique IPs: $(echo $WAF_BASELINE | cut -f2)"
echo "    - Avg Requests/Hour: $(echo $WAF_BASELINE | cut -f3)"

# Query OPA logs for baseline (last 24 hours)
cat > /tmp/baseline-opa.kql <<EOF
GatekeeperViolations_CL
| where TimeGenerated >= ago(24h)
| summarize 
    TotalEvaluations = count(),
    UniqueNamespaces = dcount(namespace_s)
| project TotalEvaluations, UniqueNamespaces
EOF

OPA_BASELINE=$(az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "$(cat /tmp/baseline-opa.kql)" \
  --query "tables[0].rows[0]" -o tsv 2>/dev/null || echo "0\t0")

echo "  OPA Baseline (last 24h):"
echo "    - Total Evaluations: $(echo $OPA_BASELINE | cut -f1)"
echo "    - Unique Namespaces: $(echo $OPA_BASELINE | cut -f2)"

# 3. Schedule daily classification reminders
echo ""
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Setting up daily tasks"

cat > /tmp/measurement-schedule.txt <<EOF
WAF/OPA False Positive Measurement Schedule
Start: $MEASUREMENT_START

Daily Tasks (9:00 AM - 11:00 AM):
  1. Run: ./05-classify-requests.sh --day \$MEASUREMENT_DAY
  2. Review all blocked requests from past 24h
  3. Classify as TP/FP using classification UI
  4. Document justification for inconclusive cases
  5. Update daily metrics dashboard

Day 1-7: Continue daily classification
Day 8: Implement tuning recommendations
Day 9-10: Re-validate with tuned policies
Day 11-13: Aggregate results, prepare go/no-go report

For questions: Contact Worf (Security & Cloud)
EOF

cat /tmp/measurement-schedule.txt

# 4. Create tracking state file
echo ""
cat > measurement-state.json <<EOF
{
  "measurementStart": "$MEASUREMENT_START",
  "currentDay": $MEASUREMENT_DAY,
  "environment": "${ENVIRONMENT:-dev-eus2}",
  "status": "active",
  "dailyReports": [],
  "tuningApplied": false
}
EOF

echo "✅ Measurement state tracking initialized: measurement-state.json"

# 5. Print next steps
echo ""
echo "=========================================="
echo "✅ MEASUREMENT CYCLE STARTED"
echo "=========================================="
echo ""
echo "Start Time: $MEASUREMENT_START"
echo "Duration: 10 days (Day 1 to Day 10)"
echo "Current Day: $MEASUREMENT_DAY"
echo ""
echo "DAILY ROUTINE (Every morning at 9:00 AM):"
echo "  1. Run: ./05-classify-requests.sh"
echo "  2. Review classification UI for all blocked requests"
echo "  3. Update metrics dashboard"
echo "  4. Generate daily report: ./06-generate-report.sh"
echo ""
echo "MONITORING QUERIES:"
echo "  - View WAF logs: ./queries/waf-daily-summary.kql"
echo "  - View OPA logs: ./queries/opa-daily-summary.kql"
echo "  - View all classifications: ./queries/classification-status.kql"
echo ""
echo "GO/NO-GO TARGETS:"
echo "  ✓ WAF False Positive Rate < 1.0%"
echo "  ✓ OPA False Positive Rate < 1.0%"
echo "  ✓ Zero False Negatives"
echo ""
echo "For assistance: Contact Worf (Security & Cloud)"
echo ""
