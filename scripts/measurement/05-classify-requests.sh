#!/bin/bash
# WAF/OPA False Positive Measurement - Daily Classification
# Owner: Worf (Security & Cloud)
# Purpose: Retrieve and classify blocked requests from past 24 hours

set -euo pipefail

# Load configuration
if [ ! -f measurement-config.env ]; then
  echo "❌ Error: measurement-config.env not found. Run 01-setup-telemetry.sh first."
  exit 1
fi
source measurement-config.env

# Load measurement state
if [ ! -f measurement-state.json ]; then
  echo "❌ Error: measurement-state.json not found. Run 04-start-measurement.sh first."
  exit 1
fi

MEASUREMENT_DAY=$(jq -r '.currentDay' measurement-state.json)
OUTPUT_DIR="classifications/day-${MEASUREMENT_DAY}"
mkdir -p "$OUTPUT_DIR"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Daily classification - Day $MEASUREMENT_DAY"
echo ""

# 1. Query WAF blocked requests (past 24h)
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Retrieving WAF blocked requests"

cat > /tmp/waf-daily.kql <<EOF
FrontdoorWebApplicationFirewallLog
| where TimeGenerated >= ago(24h)
| where action_s == "Log" or action_s == "Block"
| project 
    TimeGenerated,
    RequestId = trackingReference_s,
    ClientIP = clientIP_s,
    RequestUri = requestUri_s,
    HttpMethod = httpMethod_s,
    RuleId = ruleId_s,
    RuleName = ruleName_s,
    Action = action_s,
    Details = details_s,
    HttpStatus = httpStatusCode_d,
    UserAgent = userAgent_s
| order by TimeGenerated desc
EOF

az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "$(cat /tmp/waf-daily.kql)" \
  --query "tables[0].rows" \
  --output json > "$OUTPUT_DIR/waf-requests.json"

WAF_COUNT=$(jq 'length' "$OUTPUT_DIR/waf-requests.json")
echo "  ✓ Retrieved $WAF_COUNT WAF requests"

# 2. Query OPA violations (past 24h)
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Retrieving OPA violations"

cat > /tmp/opa-daily.kql <<EOF
GatekeeperViolations_CL
| where TimeGenerated >= ago(24h)
| where event_type_s == "violation"
| project 
    TimeGenerated,
    RequestId = correlation_id_s,
    Namespace = namespace_s,
    ObjectKind = object_kind_s,
    ObjectName = object_name_s,
    ConstraintKind = constraint_kind_s,
    ViolationMessage = violation_message_s,
    EnforcementAction = enforcement_action_s,
    User = user_s,
    ResourceManifest = resource_manifest_s
| order by TimeGenerated desc
EOF

az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "$(cat /tmp/opa-daily.kql)" \
  --query "tables[0].rows" \
  --output json > "$OUTPUT_DIR/opa-violations.json"

OPA_COUNT=$(jq 'length' "$OUTPUT_DIR/opa-violations.json")
echo "  ✓ Retrieved $OPA_COUNT OPA violations"

# 3. Apply automated classification heuristics
echo ""
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Applying automated classification heuristics"

# WAF automated classification
python3 - <<'PYTHON_WAF' > "$OUTPUT_DIR/waf-auto-classified.json"
import json
import sys

# Load WAF requests
with open(sys.argv[1], 'r') as f:
    requests = json.load(f)

classified = []
for req in requests:
    request_id = req[1]
    client_ip = req[2]
    request_uri = req[3]
    rule_id = req[5]
    rule_name = req[6]
    http_status = req[8]
    
    classification = {
        "requestId": request_id,
        "timestamp": req[0],
        "clientIP": client_ip,
        "requestUri": request_uri,
        "ruleId": rule_id,
        "ruleName": rule_name,
        "httpStatus": http_status,
        "classification": "INCONCLUSIVE",
        "confidence": "MEDIUM",
        "reason": "Requires manual review"
    }
    
    # High confidence True Positive
    if "proxy_pass" in request_uri.lower() and ";" in request_uri:
        classification["classification"] = "TP"
        classification["confidence"] = "HIGH"
        classification["reason"] = "CVE-2026-24512 exploit signature detected"
    elif "configuration-snippet" in request_uri.lower():
        classification["classification"] = "TP"
        classification["confidence"] = "HIGH"
        classification["reason"] = "Dangerous annotation abuse pattern"
    
    # High confidence False Positive
    elif client_ip.startswith("10.") or client_ip.startswith("172.") or client_ip.startswith("192.168."):
        classification["classification"] = "FP"
        classification["confidence"] = "HIGH"
        classification["reason"] = "Internal network source (known-good)"
    elif "/healthz" in request_uri or "/metrics" in request_uri:
        classification["classification"] = "FP"
        classification["confidence"] = "HIGH"
        classification["reason"] = "Monitoring endpoint allowlist"
    elif http_status == 200:
        classification["classification"] = "FP"
        classification["confidence"] = "MEDIUM"
        classification["reason"] = "Request succeeded at application layer (HTTP 200)"
    
    classified.append(classification)

print(json.dumps(classified, indent=2))
PYTHON_WAF "$OUTPUT_DIR/waf-requests.json"

# OPA automated classification
python3 - <<'PYTHON_OPA' > "$OUTPUT_DIR/opa-auto-classified.json"
import json
import sys

# Load OPA violations
with open(sys.argv[1], 'r') as f:
    violations = json.load(f)

classified = []
for vio in violations:
    request_id = vio[1]
    namespace = vio[2]
    constraint_kind = vio[5]
    violation_msg = vio[6]
    user = vio[8]
    
    classification = {
        "requestId": request_id,
        "timestamp": vio[0],
        "namespace": namespace,
        "constraintKind": constraint_kind,
        "violationMessage": violation_msg,
        "user": user,
        "classification": "INCONCLUSIVE",
        "confidence": "MEDIUM",
        "reason": "Requires manual review"
    }
    
    # High confidence True Positive
    if "configuration-snippet" in violation_msg.lower() or "server-snippet" in violation_msg.lower():
        classification["classification"] = "TP"
        classification["confidence"] = "HIGH"
        classification["reason"] = "High-risk annotation (code injection vector)"
    
    # High confidence False Positive
    elif "dev-sandbox" in namespace or "test-playground" in namespace:
        classification["classification"] = "FP"
        classification["confidence"] = "HIGH"
        classification["reason"] = "Exempt namespace (development/test)"
    elif "auth-url" in violation_msg.lower() or "auth-signin" in violation_msg.lower():
        classification["classification"] = "FP"
        classification["confidence"] = "MEDIUM"
        classification["reason"] = "Safe authentication annotation"
    
    classified.append(classification)

print(json.dumps(classified, indent=2))
PYTHON_OPA "$OUTPUT_DIR/opa-violations.json"

# 4. Calculate automated classification stats
WAF_AUTO_TP=$(jq '[.[] | select(.classification == "TP")] | length' "$OUTPUT_DIR/waf-auto-classified.json")
WAF_AUTO_FP=$(jq '[.[] | select(.classification == "FP")] | length' "$OUTPUT_DIR/waf-auto-classified.json")
WAF_AUTO_INC=$(jq '[.[] | select(.classification == "INCONCLUSIVE")] | length' "$OUTPUT_DIR/waf-auto-classified.json")

OPA_AUTO_TP=$(jq '[.[] | select(.classification == "TP")] | length' "$OUTPUT_DIR/opa-auto-classified.json")
OPA_AUTO_FP=$(jq '[.[] | select(.classification == "FP")] | length' "$OUTPUT_DIR/opa-auto-classified.json")
OPA_AUTO_INC=$(jq '[.[] | select(.classification == "INCONCLUSIVE")] | length' "$OUTPUT_DIR/opa-auto-classified.json")

echo ""
echo "Automated Classification Results:"
echo "  WAF:"
echo "    - True Positives (TP): $WAF_AUTO_TP"
echo "    - False Positives (FP): $WAF_AUTO_FP"
echo "    - Inconclusive: $WAF_AUTO_INC (requires manual review)"
echo "  OPA:"
echo "    - True Positives (TP): $OPA_AUTO_TP"
echo "    - False Positives (FP): $OPA_AUTO_FP"
echo "    - Inconclusive: $OPA_AUTO_INC (requires manual review)"

# 5. Generate manual review list
TOTAL_MANUAL=$((WAF_AUTO_INC + OPA_AUTO_INC))

if [ $TOTAL_MANUAL -gt 0 ]; then
  echo ""
  echo "⚠️  Manual review required for $TOTAL_MANUAL requests"
  echo ""
  echo "Next steps:"
  echo "  1. Review inconclusive cases in: $OUTPUT_DIR/waf-auto-classified.json"
  echo "  2. Review inconclusive cases in: $OUTPUT_DIR/opa-auto-classified.json"
  echo "  3. Update classifications using: ./classification-ui/index.html"
  echo "  4. Or manually edit JSON files and run: ./07-upload-classifications.sh"
else
  echo ""
  echo "✅ All requests auto-classified with high confidence"
fi

# 6. Export for classification UI
cat > "$OUTPUT_DIR/classification-input.json" <<EOF
{
  "measurementDay": $MEASUREMENT_DAY,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "wafRequests": $(cat "$OUTPUT_DIR/waf-auto-classified.json"),
  "opaViolations": $(cat "$OUTPUT_DIR/opa-auto-classified.json"),
  "summary": {
    "totalWafRequests": $WAF_COUNT,
    "totalOpaViolations": $OPA_COUNT,
    "manualReviewRequired": $TOTAL_MANUAL
  }
}
EOF

echo ""
echo "✅ Classification data exported: $OUTPUT_DIR/classification-input.json"
echo ""
echo "Open classification UI: file://$(pwd)/classification-ui/index.html"
echo ""
