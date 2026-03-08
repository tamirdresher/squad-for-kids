#!/bin/bash
# WAF/OPA False Positive Measurement - Generate Daily Report
# Owner: Worf (Security & Cloud)
# Purpose: Generate comprehensive daily report with metrics and classification results

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
CLASSIFICATION_DIR="classifications/day-${MEASUREMENT_DAY}"
REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"

REPORT_FILE="$REPORT_DIR/day-${MEASUREMENT_DAY}-report.md"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Generating Day $MEASUREMENT_DAY report"
echo ""

# Check if classification data exists
if [ ! -f "$CLASSIFICATION_DIR/waf-auto-classified.json" ] || [ ! -f "$CLASSIFICATION_DIR/opa-auto-classified.json" ]; then
  echo "❌ Error: Classification data not found. Run 05-classify-requests.sh first."
  exit 1
fi

# Calculate metrics
WAF_TOTAL=$(jq 'length' "$CLASSIFICATION_DIR/waf-auto-classified.json")
WAF_TP=$(jq '[.[] | select(.classification == "TP")] | length' "$CLASSIFICATION_DIR/waf-auto-classified.json")
WAF_FP=$(jq '[.[] | select(.classification == "FP")] | length' "$CLASSIFICATION_DIR/waf-auto-classified.json")
WAF_INC=$(jq '[.[] | select(.classification == "INCONCLUSIVE")] | length' "$CLASSIFICATION_DIR/waf-auto-classified.json")

OPA_TOTAL=$(jq 'length' "$CLASSIFICATION_DIR/opa-auto-classified.json")
OPA_TP=$(jq '[.[] | select(.classification == "TP")] | length' "$CLASSIFICATION_DIR/opa-auto-classified.json")
OPA_FP=$(jq '[.[] | select(.classification == "FP")] | length' "$CLASSIFICATION_DIR/opa-auto-classified.json")
OPA_INC=$(jq '[.[] | select(.classification == "INCONCLUSIVE")] | length' "$CLASSIFICATION_DIR/opa-auto-classified.json")

# Calculate false positive rates
if [ $WAF_TOTAL -gt 0 ]; then
  WAF_FP_RATE=$(echo "scale=2; ($WAF_FP / $WAF_TOTAL) * 100" | bc)
else
  WAF_FP_RATE="0.00"
fi

if [ $OPA_TOTAL -gt 0 ]; then
  OPA_FP_RATE=$(echo "scale=2; ($OPA_FP / $OPA_TOTAL) * 100" | bc)
else
  OPA_FP_RATE="0.00"
fi

# Query additional context metrics
cat > /tmp/context-metrics.kql <<EOF
// Request volume trends
FrontdoorWebApplicationFirewallLog
| where TimeGenerated >= ago(24h)
| summarize 
    TotalRequests = count(),
    UniqueIPs = dcount(clientIP_s),
    BlockedRequests = countif(action_s == "Block"),
    LoggedRequests = countif(action_s == "Log")
| extend BlockRate = (todouble(BlockedRequests) / TotalRequests) * 100
| project TotalRequests, UniqueIPs, BlockedRequests, LoggedRequests, BlockRate
EOF

CONTEXT_METRICS=$(az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "$(cat /tmp/context-metrics.kql)" \
  --query "tables[0].rows[0]" -o tsv 2>/dev/null || echo "0\t0\t0\t0\t0.00")

TOTAL_REQUESTS=$(echo $CONTEXT_METRICS | cut -f1)
UNIQUE_IPS=$(echo $CONTEXT_METRICS | cut -f2)
BLOCKED_REQUESTS=$(echo $CONTEXT_METRICS | cut -f3)
LOGGED_REQUESTS=$(echo $CONTEXT_METRICS | cut -f4)
BLOCK_RATE=$(echo $CONTEXT_METRICS | cut -f5)

# Generate markdown report
cat > "$REPORT_FILE" <<EOF
# WAF/OPA False Positive Measurement - Day $MEASUREMENT_DAY Report

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**Environment:** ${ENVIRONMENT:-dev-eus2}  
**Measurement Window:** Last 24 hours  

---

## Executive Summary

| Metric | WAF | OPA | Target | Status |
|--------|-----|-----|--------|--------|
| **False Positive Rate** | ${WAF_FP_RATE}% | ${OPA_FP_RATE}% | < 1.0% | $([ $(echo "$WAF_FP_RATE < 1.0" | bc) -eq 1 ] && [ $(echo "$OPA_FP_RATE < 1.0" | bc) -eq 1 ] && echo "✅ PASS" || echo "⚠️ FAIL") |
| **Total Evaluations** | $WAF_TOTAL | $OPA_TOTAL | - | - |
| **True Positives** | $WAF_TP | $OPA_TP | > 0 | $([ $WAF_TP -gt 0 ] && [ $OPA_TP -gt 0 ] && echo "✅ PASS" || echo "⚠️ CHECK") |
| **False Positives** | $WAF_FP | $OPA_FP | < 1.0% | $([ $(echo "$WAF_FP_RATE < 1.0" | bc) -eq 1 ] && [ $(echo "$OPA_FP_RATE < 1.0" | bc) -eq 1 ] && echo "✅" || echo "⚠️") |
| **Inconclusive** | $WAF_INC | $OPA_INC | - | $([ $WAF_INC -eq 0 ] && [ $OPA_INC -eq 0 ] && echo "✅" || echo "📋 Review") |

---

## Traffic Volume Context

| Metric | Value |
|--------|-------|
| **Total HTTP Requests** | $TOTAL_REQUESTS |
| **Unique Client IPs** | $UNIQUE_IPS |
| **Blocked Requests** | $BLOCKED_REQUESTS |
| **Logged Requests** | $LOGGED_REQUESTS |
| **Overall Block Rate** | ${BLOCK_RATE}% |

---

## WAF Classification Details

**Total WAF Evaluations:** $WAF_TOTAL

| Classification | Count | Percentage |
|----------------|-------|------------|
| True Positive (TP) | $WAF_TP | $(echo "scale=2; ($WAF_TP / $WAF_TOTAL) * 100" | bc 2>/dev/null || echo "0.00")% |
| False Positive (FP) | $WAF_FP | ${WAF_FP_RATE}% |
| Inconclusive | $WAF_INC | $(echo "scale=2; ($WAF_INC / $WAF_TOTAL) * 100" | bc 2>/dev/null || echo "0.00")% |

### Top WAF Rules Triggered

\`\`\`
EOF

# Extract top WAF rules
jq -r '.[] | [.ruleId, .ruleName, .classification] | @tsv' "$CLASSIFICATION_DIR/waf-auto-classified.json" | \
  awk '{rule[$1" - "$2]++; class[$1" - "$2,$3]++} END {for (r in rule) print rule[r], r, class[r,"TP"], class[r,"FP"], class[r,"INCONCLUSIVE"]}' | \
  sort -rn | head -10 | \
  awk 'BEGIN {print "Count | Rule | TP | FP | INC"} {printf "%d | %s | %s | %s | %s\n", $1, $2" "$3" "$4, $5, $6, $7}' >> "$REPORT_FILE"

cat >> "$REPORT_FILE" <<EOF
\`\`\`

### Notable WAF Incidents

EOF

# Extract high-confidence true positives
jq -r '.[] | select(.classification == "TP" and .confidence == "HIGH") | "- **[\(.requestId)]** \(.reason)\n  - URI: \(.requestUri)\n  - IP: \(.clientIP)\n  - Time: \(.timestamp)\n"' "$CLASSIFICATION_DIR/waf-auto-classified.json" | head -5 >> "$REPORT_FILE"

cat >> "$REPORT_FILE" <<EOF

---

## OPA Classification Details

**Total OPA Evaluations:** $OPA_TOTAL

| Classification | Count | Percentage |
|----------------|-------|------------|
| True Positive (TP) | $OPA_TP | $(echo "scale=2; ($OPA_TP / $OPA_TOTAL) * 100" | bc 2>/dev/null || echo "0.00")% |
| False Positive (FP) | $OPA_FP | ${OPA_FP_RATE}% |
| Inconclusive | $OPA_INC | $(echo "scale=2; ($OPA_INC / $OPA_TOTAL) * 100" | bc 2>/dev/null || echo "0.00")% |

### Top OPA Constraints Triggered

\`\`\`
EOF

# Extract top OPA constraints
jq -r '.[] | [.constraintKind, .classification] | @tsv' "$CLASSIFICATION_DIR/opa-auto-classified.json" | \
  awk '{const[$1]++; class[$1,$2]++} END {for (c in const) print const[c], c, class[c,"TP"], class[c,"FP"], class[c,"INCONCLUSIVE"]}' | \
  sort -rn | head -10 | \
  awk 'BEGIN {print "Count | Constraint | TP | FP | INC"} {printf "%d | %s | %s | %s | %s\n", $1, $2, $3, $4, $5}' >> "$REPORT_FILE"

cat >> "$REPORT_FILE" <<EOF
\`\`\`

### Notable OPA Violations

EOF

# Extract high-confidence true positives
jq -r '.[] | select(.classification == "TP" and .confidence == "HIGH") | "- **[\(.constraintKind)]** \(.reason)\n  - Namespace: \(.namespace)\n  - Message: \(.violationMessage)\n  - Time: \(.timestamp)\n"' "$CLASSIFICATION_DIR/opa-auto-classified.json" | head -5 >> "$REPORT_FILE"

cat >> "$REPORT_FILE" <<EOF

---

## Recommendations

EOF

# Generate recommendations based on FP rate
if [ $(echo "$WAF_FP_RATE > 1.0" | bc) -eq 1 ]; then
  cat >> "$REPORT_FILE" <<EOF
### WAF Tuning Required ⚠️

False positive rate (${WAF_FP_RATE}%) exceeds 1.0% target. Recommended actions:

1. Review top FP rules and consider:
   - Rule exception lists for known-good patterns
   - Adjusting sensitivity thresholds
   - Adding IP allowlists for trusted sources
2. Validate with application team if blocked requests are legitimate
3. Consider progressive rollout of tuned policies

EOF
fi

if [ $(echo "$OPA_FP_RATE > 1.0" | bc) -eq 1 ]; then
  cat >> "$REPORT_FILE" <<EOF
### OPA Tuning Required ⚠️

False positive rate (${OPA_FP_RATE}%) exceeds 1.0% target. Recommended actions:

1. Review top FP constraints and consider:
   - Namespace exemptions for dev/test environments
   - Relaxing constraints for specific use cases
   - Improving constraint logic to reduce overfitting
2. Engage with platform teams to validate violations
3. Update constraint templates based on learnings

EOF
fi

if [ $WAF_INC -gt 0 ] || [ $OPA_INC -gt 0 ]; then
  cat >> "$REPORT_FILE" <<EOF
### Manual Review Required 📋

$((WAF_INC + OPA_INC)) requests require manual classification. Review:

- WAF inconclusive: $WAF_INC requests in \`$CLASSIFICATION_DIR/waf-auto-classified.json\`
- OPA inconclusive: $OPA_INC violations in \`$CLASSIFICATION_DIR/opa-auto-classified.json\`

Use classification UI or manually edit JSON files to complete classification.

EOF
fi

if [ $(echo "$WAF_FP_RATE < 1.0" | bc) -eq 1 ] && [ $(echo "$OPA_FP_RATE < 1.0" | bc) -eq 1 ]; then
  cat >> "$REPORT_FILE" <<EOF
### Status: On Track ✅

Both WAF and OPA false positive rates are within target (<1.0%). Continue monitoring.

- No immediate tuning required
- Proceed with next measurement day
- Document any edge cases for reference

EOF
fi

cat >> "$REPORT_FILE" <<EOF

---

## Next Steps

1. **If FP rate > 1.0%:** Begin tuning analysis
   - Run: \`./queries/tuning-recommendations.kql\`
   - Document proposed changes
   - Test in non-prod environment

2. **If inconclusive > 0:** Complete manual classification
   - Open: \`classification-ui/index.html\`
   - Review each request context
   - Submit classifications

3. **Daily routine:**
   - Update measurement state: \`jq '.currentDay = $((MEASUREMENT_DAY + 1))' measurement-state.json > tmp && mv tmp measurement-state.json\`
   - Run tomorrow: \`./05-classify-requests.sh\`
   - Generate report: \`./06-generate-report.sh\`

---

**Report Location:** \`$REPORT_FILE\`  
**Classification Data:** \`$CLASSIFICATION_DIR/\`  
**Contact:** Worf (Security & Cloud)
EOF

# Update measurement state with report reference
jq --arg report "$REPORT_FILE" '.dailyReports += [$report]' measurement-state.json > tmp && mv tmp measurement-state.json

# Increment day counter
jq ".currentDay = $((MEASUREMENT_DAY + 1))" measurement-state.json > tmp && mv tmp measurement-state.json

echo "✅ Report generated: $REPORT_FILE"
echo ""
echo "Summary:"
echo "  - WAF FP Rate: ${WAF_FP_RATE}% (Target: <1.0%)"
echo "  - OPA FP Rate: ${OPA_FP_RATE}% (Target: <1.0%)"
echo "  - Status: $([ $(echo "$WAF_FP_RATE < 1.0" | bc) -eq 1 ] && [ $(echo "$OPA_FP_RATE < 1.0" | bc) -eq 1 ] && echo "✅ ON TRACK" || echo "⚠️ TUNING NEEDED")"
echo ""
echo "View report: cat $REPORT_FILE"
echo ""
