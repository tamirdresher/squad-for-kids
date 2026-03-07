#!/bin/bash
# File: tests/test-alert-flow.sh
# End-to-end alert flow testing for Phase 4

set -e

# Configuration
FUNCTION_APP_URL="${FUNCTION_APP_URL:-https://fedramp-alerts-func-stg.azurewebsites.net/api/AlertProcessor}"
FUNCTION_KEY="${FUNCTION_KEY:-YOUR_FUNCTION_KEY}"

echo "=========================================="
echo "Phase 4 Alert Flow Testing"
echo "=========================================="
echo ""
echo "Function URL: $FUNCTION_APP_URL"
echo ""

# Test 1: Control Drift Alert (P0)
echo "[Test 1/6] Control Drift Alert (P0)"
echo "Expected: PagerDuty incident + Teams notification"
echo ""

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
      "drift_percentage": 12.0,
      "current_failures": 45,
      "prior_failures": 9
    },
    "remediation_steps": [
      "1. Review recent NetworkPolicy changes in STG",
      "2. Compare current policies vs baseline",
      "3. Run compliance scan"
    ]
  }' \
  -s -w "\nHTTP Status: %{http_code}\n" -o /tmp/test1-response.json

echo ""
echo "Response:"
cat /tmp/test1-response.json | jq '.'
echo ""
echo "✓ Verify: PagerDuty incident created (severity=critical)"
echo "✓ Verify: Teams notification in #fedramp-critical"
echo ""
read -p "Press Enter to continue..."

# Test 2: Duplicate Detection
echo ""
echo "[Test 2/6] Duplicate Detection (should be suppressed)"
echo ""

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
      "drift_percentage": 12.0
    }
  }' \
  -s -w "\nHTTP Status: %{http_code}\n" -o /tmp/test2-response.json

echo ""
echo "Response:"
cat /tmp/test2-response.json | jq '.'
echo ""
echo "✓ Verify: Response status='duplicate'"
echo "✓ Verify: No new PagerDuty incident or Teams notification"
echo ""
read -p "Press Enter to continue..."

# Test 3: Control Regression (P1)
echo ""
echo "[Test 3/6] Control Regression (P1)"
echo "Expected: PagerDuty + Teams notification"
echo ""

curl -X POST "$FUNCTION_APP_URL?code=$FUNCTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_type": "control_regression",
    "alert_id": "test-regression-SI2-PROD-001",
    "severity": "P1",
    "timestamp": "2026-03-08T16:00:00Z",
    "control": {
      "id": "SI-2",
      "name": "Flaw Remediation",
      "category": "System and Information Integrity"
    },
    "environment": "PROD",
    "metrics": {
      "consecutive_failures": 5,
      "time_since_first_failure_min": 45
    }
  }' \
  -s -w "\nHTTP Status: %{http_code}\n" -o /tmp/test3-response.json

echo ""
echo "Response:"
cat /tmp/test3-response.json | jq '.'
echo ""
echo "✓ Verify: PagerDuty incident created (severity=error)"
echo "✓ Verify: Teams notification in #fedramp-critical"
echo ""
read -p "Press Enter to continue..."

# Test 4: New Vulnerability (P0)
echo ""
echo "[Test 4/6] New Vulnerability (P0)"
echo "Expected: PagerDuty incident"
echo ""

curl -X POST "$FUNCTION_APP_URL?code=$FUNCTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_type": "new_vulnerability",
    "alert_id": "test-vuln-PROD-001",
    "severity": "P0",
    "timestamp": "2026-03-08T16:30:00Z",
    "control": {
      "id": "SI-2",
      "name": "Flaw Remediation"
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
        "image_name": "contoso.azurecr.io/api-service:v2.1.0"
      }
    ]
  }' \
  -s -w "\nHTTP Status: %{http_code}\n" -o /tmp/test4-response.json

echo ""
echo "Response:"
cat /tmp/test4-response.json | jq '.'
echo ""
echo "✓ Verify: PagerDuty incident with CVE links"
echo "✓ Verify: Includes remediation guidance"
echo ""
read -p "Press Enter to continue..."

# Test 5: Manual Review (P2)
echo ""
echo "[Test 5/6] Manual Review Required (P2)"
echo "Expected: Teams notification only"
echo ""

curl -X POST "$FUNCTION_APP_URL?code=$FUNCTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_type": "manual_review_needed",
    "alert_id": "test-review-AC3-STG-001",
    "severity": "P2",
    "timestamp": "2026-03-08T17:00:00Z",
    "control": {
      "id": "AC-3",
      "name": "Access Enforcement"
    },
    "environment": "STG",
    "review_reason": "ambiguous_opa_violation"
  }' \
  -s -w "\nHTTP Status: %{http_code}\n" -o /tmp/test5-response.json

echo ""
echo "Response:"
cat /tmp/test5-response.json | jq '.'
echo ""
echo "✓ Verify: Teams notification in #security-alerts"
echo "✓ Verify: No PagerDuty incident (P2 severity)"
echo "✓ Verify: Adaptive Card includes 'Acknowledge' button"
echo ""
read -p "Press Enter to continue..."

# Test 6: Compliance Deadline (P3)
echo ""
echo "[Test 6/6] Compliance Deadline Approaching (P3)"
echo "Expected: Logged only (no external notifications)"
echo ""

curl -X POST "$FUNCTION_APP_URL?code=$FUNCTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_type": "compliance_deadline",
    "alert_id": "test-deadline-001",
    "severity": "P3",
    "timestamp": "2026-03-08T17:30:00Z",
    "deadline": {
      "id": "AUDIT2026Q2",
      "type": "fedramp_audit",
      "description": "FedRAMP Annual Assessment 2026 Q2",
      "deadline_date": "2026-03-15T23:59:59Z"
    },
    "days_until_deadline": 7
  }' \
  -s -w "\nHTTP Status: %{http_code}\n" -o /tmp/test6-response.json

echo ""
echo "Response:"
cat /tmp/test6-response.json | jq '.'
echo ""
echo "✓ Verify: Response status='processed'"
echo "✓ Verify: Alert logged in Application Insights"
echo "✓ Verify: No PagerDuty or Teams notifications (P3)"
echo ""

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "All 6 test cases completed!"
echo ""
echo "Manual Verification Checklist:"
echo "  [ ] PagerDuty: 3 incidents created (P0 drift, P1 regression, P0 vuln)"
echo "  [ ] Teams #fedramp-critical: 2 Adaptive Cards"
echo "  [ ] Teams #security-alerts: 1 Adaptive Card (manual review)"
echo "  [ ] Duplicate suppression working (test 2)"
echo "  [ ] Application Insights: All 6 alerts logged"
echo "  [ ] Redis cache: Deduplication keys stored"
echo ""
echo "Next Steps:"
echo "  1. Review PagerDuty incidents and escalation"
echo "  2. Test Teams 'Acknowledge' button functionality"
echo "  3. Validate alert enrichment (runbook URLs, metadata)"
echo "  4. Test alert suppression during maintenance window"
echo ""

# Clean up
rm -f /tmp/test*.json
