# WAF/OPA False Positive Measurement — Execution Runbook

**Owner:** Worf (Security & Cloud)  
**Purpose:** Step-by-step operational guide for executing 10-day measurement cycle  
**Version:** 1.0  
**Last Updated:** 2026-03-08

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Phase 1: Setup (Day -3 to Day 0)](#phase-1-setup)
4. [Phase 2: Measurement Window (Day 1 to Day 10)](#phase-2-measurement-window)
5. [Phase 3: Analysis & Tuning (Day 11 to Day 13)](#phase-3-analysis--tuning)
6. [Daily Operational Procedures](#daily-operational-procedures)
7. [Classification Guidelines](#classification-guidelines)
8. [Troubleshooting](#troubleshooting)
9. [Go/No-Go Decision Framework](#gono-go-decision-framework)

---

## Overview

This runbook provides operational procedures for executing the WAF/OPA false positive measurement cycle. The goal is to validate that security policies achieve **< 1% false positive rate** before sovereign deployment.

**Timeline:** 13 days total
- **Days -3 to 0:** Infrastructure setup
- **Days 1-10:** Active measurement with daily classification
- **Days 11-13:** Analysis, tuning validation, and go/no-go decision

**Success Criteria:**
- ✅ WAF False Positive Rate < 1.0%
- ✅ OPA False Positive Rate < 1.0%
- ✅ Zero False Negatives (security bypasses)
- ✅ 100% classification completeness

---

## Prerequisites

### Required Access

| Resource | Access Level | Verification Command |
|----------|--------------|---------------------|
| Azure Subscription | Contributor | `az account show` |
| Log Analytics Workspace | Read/Write | `az monitor log-analytics workspace show --name dk8s-measurement-workspace` |
| Cosmos DB | Data Contributor | `az cosmosdb show --name dk8s-measurement-db` |
| AKS Cluster | Cluster Admin | `kubectl cluster-info` |
| Azure Front Door | Contributor | `az afd profile list` |

### Required Tools

```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install kubectl
az aks install-cli

# Install jq (JSON processor)
sudo apt-get install jq

# Install Python 3.8+
python3 --version
```

### Environment Variables

```bash
export RESOURCE_GROUP="dk8s-security"
export LOCATION="eastus2"
export WORKSPACE_NAME="dk8s-measurement-workspace"
export COSMOS_ACCOUNT="dk8s-measurement-db"
export CLUSTER_NAME="dk8s-dev-eus2"
export FRONTDOOR_NAME="dk8s-frontdoor-dev"
export ENVIRONMENT="dev-eus2"
```

---

## Phase 1: Setup (Day -3 to Day 0)

### Day -3: Infrastructure Provisioning

**Duration:** 4-6 hours  
**Owner:** Security Engineer (Worf) + SRE

#### Task 1.1: Deploy Telemetry Infrastructure

```bash
cd scripts/measurement
chmod +x *.sh
./01-setup-telemetry.sh
```

**Expected Output:**
- ✅ Log Analytics workspace created
- ✅ Cosmos DB account and collection created
- ✅ Data Collection Rule configured
- ✅ Configuration file: `measurement-config.env`

**Verification:**
```bash
source measurement-config.env
az monitor log-analytics workspace show --name "$WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP"
az cosmosdb show --name "$COSMOS_ACCOUNT" --resource-group "$RESOURCE_GROUP"
```

#### Task 1.2: Deploy WAF Policies (Detection Mode)

```bash
./02-deploy-waf-policies.sh
```

**Expected Output:**
- ✅ WAF policy deployed in Detection mode (non-blocking)
- ✅ 3 custom rules configured (nginx-injection, annotation-abuse, heartbeat-ratelimit)
- ✅ OWASP DRS 2.1 enabled
- ✅ Diagnostic settings configured

**Verification:**
```bash
az network front-door waf-policy show \
  --name "$WAF_POLICY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "{mode:policySettings.mode, state:policySettings.enabledState}"
```

**Expected:** `mode: "Detection"`, `state: "Enabled"`

#### Task 1.3: Deploy OPA Policies (Dryrun Mode)

```bash
./03-deploy-opa-policies.sh
```

**Expected Output:**
- ✅ Gatekeeper installed (if not already present)
- ✅ 5 constraint templates deployed
- ✅ 5 constraints configured in dryrun mode
- ✅ Fluent Bit deployed for log collection

**Verification:**
```bash
kubectl get constrainttemplates
kubectl get constraints --all-namespaces
kubectl get pods -n gatekeeper-system
```

**Expected:** All pods running, 5 templates, 5 constraints in dryrun mode

---

### Day -1: Validation & Baseline

#### Task 1.4: Validate Telemetry Flow

**WAF Log Validation:**
```bash
# Generate test traffic
curl -X GET "https://your-frontdoor.azurefd.net/test?id=1'; DROP TABLE users--"

# Wait 5 minutes for ingestion
sleep 300

# Query logs
az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "FrontdoorWebApplicationFirewallLog | where TimeGenerated >= ago(10m) | take 10"
```

**OPA Log Validation:**
```bash
# Create test Ingress with violation
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-violation
  namespace: default
  annotations:
    dangerous-annotation: "test"
spec:
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test
            port:
              number: 80
EOF

# Check Gatekeeper logs
kubectl logs -n gatekeeper-system -l control-plane=controller-manager --tail=50 | grep violation

# Query Log Analytics
az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "GatekeeperViolations_CL | where TimeGenerated >= ago(10m) | take 10"
```

#### Task 1.5: Capture Baseline Metrics

```bash
# Run baseline capture script
cat > capture-baseline.sh <<'EOF'
#!/bin/bash
source measurement-config.env

echo "Capturing baseline metrics (last 7 days)..."

# WAF Baseline
az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "FrontdoorWebApplicationFirewallLog | where TimeGenerated >= ago(7d) | summarize count() by bin(TimeGenerated, 1d)" \
  --output table > baseline-waf.txt

# OPA Baseline
az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "GatekeeperViolations_CL | where TimeGenerated >= ago(7d) | summarize count() by bin(TimeGenerated, 1d)" \
  --output table > baseline-opa.txt

echo "Baseline captured: baseline-waf.txt, baseline-opa.txt"
EOF

chmod +x capture-baseline.sh
./capture-baseline.sh
```

**Store baseline for comparison:**
```bash
mkdir -p baselines
cp baseline-*.txt baselines/pre-measurement-$(date +%Y%m%d).txt
```

---

## Phase 2: Measurement Window (Day 1 to Day 10)

### Day 1: Start Measurement

#### Task 2.1: Initialize Measurement Cycle

```bash
./04-start-measurement.sh
```

**Expected Output:**
- ✅ Measurement session created in Cosmos DB
- ✅ Baseline metrics captured
- ✅ Tracking state initialized: `measurement-state.json`
- ✅ Daily schedule printed

**Critical:** Note the measurement start timestamp

---

## Daily Operational Procedures

**Time Required:** 60-90 minutes per day  
**Schedule:** Every morning at 9:00 AM (UTC or local timezone)

### Step 1: Retrieve Blocked Requests (9:00 AM)

```bash
cd scripts/measurement
./05-classify-requests.sh
```

**Expected Output:**
- ✅ WAF requests exported: `classifications/day-N/waf-requests.json`
- ✅ OPA violations exported: `classifications/day-N/opa-violations.json`
- ✅ Automated classifications applied
- ✅ Manual review list generated

### Step 2: Review Automated Classifications (9:15 AM)

**Check automated results:**
```bash
DAY=$(jq -r '.currentDay' measurement-state.json)
cd classifications/day-$DAY

# WAF summary
echo "WAF Classification Summary:"
jq '[group_by(.classification)[] | {classification: .[0].classification, count: length}]' waf-auto-classified.json

# OPA summary
echo "OPA Classification Summary:"
jq '[group_by(.classification)[] | {classification: .[0].classification, count: length}]' opa-auto-classified.json
```

### Step 3: Manual Review (9:30 AM - 10:30 AM)

**Open classification UI:**
```bash
# Open in browser
python3 -m http.server 8080 &
open http://localhost:8080/classification-ui/index.html
```

**Review each INCONCLUSIVE case:**

For each request:
1. **Examine request details:** URI, headers, body, source IP
2. **Check application logs:** Did request succeed at app layer?
3. **Assess business context:** Legitimate use case or attack?
4. **Classify:** TP / FP / Inconclusive (if truly unclear)
5. **Document justification:** Why did you classify this way?

**Classification UI workflow:**
- Click request to expand details
- Review automated classification and reason
- Override if incorrect
- Add justification notes
- Click "Save Classification"
- Repeat for all INCONCLUSIVE requests

### Step 4: Upload Classifications to Cosmos DB (10:45 AM)

```bash
./07-upload-classifications.sh --day $DAY
```

**Verification:**
```bash
# Query Cosmos DB for today's classifications
az cosmosdb sql query \
  --account-name "$COSMOS_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --database-name "$COSMOS_DATABASE" \
  --container-name "$COSMOS_COLLECTION" \
  --query-text "SELECT COUNT(1) FROM c WHERE c.day = $DAY"
```

### Step 5: Generate Daily Report (11:00 AM)

```bash
./06-generate-report.sh --day $DAY
```

**Expected Output:**
- ✅ Daily report PDF: `reports/day-$DAY-report.pdf`
- ✅ Metrics dashboard updated
- ✅ FP rate calculated and displayed

**Review report sections:**
1. **Summary Metrics:** Total requests, blocks, FP rate
2. **WAF Breakdown:** Per-rule statistics
3. **OPA Breakdown:** Per-policy statistics
4. **Top False Positives:** Most problematic patterns
5. **Tuning Recommendations:** Suggested fixes

### Step 6: Update Tracking State (11:15 AM)

```bash
# Increment day counter
jq '.currentDay += 1 | .dailyReports += ["reports/day-'$DAY'-report.pdf"]' measurement-state.json > tmp.json && mv tmp.json measurement-state.json
```

### Step 7: Alert on Threshold Violations (11:30 AM)

**Check if FP rate > 2% (warning threshold):**
```bash
FP_RATE=$(jq -r '.summary.falsePositiveRate' reports/day-$DAY-metrics.json)

if (( $(echo "$FP_RATE > 2.0" | bc -l) )); then
  echo "⚠️  WARNING: False positive rate $FP_RATE% exceeds 2% threshold"
  echo "Action required: Review tuning recommendations and plan intervention"
  
  # Send alert (customize for your environment)
  # curl -X POST "https://alerts.example.com/api/alerts" -d "..."
fi
```

---

## Classification Guidelines

### True Positive (TP) Criteria

**A request is a TRUE POSITIVE if:**
- Contains known exploit signature (CVE payload)
- Originates from threat intelligence blocklist IP
- Triggers multiple security rules simultaneously
- Contains dangerous patterns (command injection, SQL injection, XSS)
- Attempts to abuse high-risk annotations (`configuration-snippet`)
- Targets infrastructure services (Kubernetes API, etcd)

**Examples:**
- `GET /api?id=1'; DROP TABLE users--` → SQL injection
- `POST /deploy` with `nginx.ingress.kubernetes.io/configuration-snippet: proxy_pass` → Code injection
- Ingress targeting `backend.service.name: kubernetes` → Infrastructure access attempt

### False Positive (FP) Criteria

**A request is a FALSE POSITIVE if:**
- Originates from internal/known-good source (monitoring tools, CI/CD)
- Succeeds at application layer (HTTP 200) despite WAF log
- Legitimate business use case (search query with SQL keywords)
- Safe annotation blocked by overly restrictive allowlist
- Development/test namespace with relaxed requirements

**Examples:**
- Health check from internal monitoring: `/healthz` → FP
- JSON POST with field name "query": `{"query": "SELECT status"}` → FP (not SQL injection)
- Developer using safe annotation: `nginx.ingress.kubernetes.io/auth-url` → FP
- Internal tool with "proxy" in query param: `/api/proxy?target=internal` → FP (not nginx directive)

### Inconclusive Cases

**Mark as INCONCLUSIVE if:**
- Unclear whether request is malicious or legitimate
- Insufficient context to determine business need
- First occurrence of novel pattern (no historical data)
- Conflicting signals (partial attack pattern + legitimate source)

**Action:** Escalate to application team or security architect for decision

---

## Phase 3: Analysis & Tuning (Day 11 to Day 13)

### Day 11: Aggregate Results

#### Task 3.1: Generate Final Measurement Report

```bash
./08-final-report.sh
```

**Expected Output:**
- ✅ 10-day aggregate statistics
- ✅ FP rate per rule/policy
- ✅ Trend analysis charts
- ✅ Go/no-go recommendation

**Report Sections:**
1. **Executive Summary:** Overall FP rate, recommendation
2. **WAF Analysis:** Per-rule FP rates, tuning needs
3. **OPA Analysis:** Per-policy FP rates, allowlist gaps
4. **Trend Analysis:** FP rate over 10 days
5. **Tuning Recommendations:** Prioritized list of fixes

#### Task 3.2: Identify Tuning Priorities

**Extract top problematic rules:**
```bash
# Query Cosmos DB for high-FP rules
az cosmosdb sql query \
  --account-name "$COSMOS_ACCOUNT" \
  --database-name "$COSMOS_DATABASE" \
  --container-name "$COSMOS_COLLECTION" \
  --query-text "SELECT c.ruleId, COUNT(1) as fpCount FROM c WHERE c.classification = 'FP' GROUP BY c.ruleId ORDER BY fpCount DESC"
```

**Prioritization criteria:**
1. **High FP count** (> 10 FPs over 10 days)
2. **High FP rate** (> 5% of triggers are FP)
3. **Business impact** (critical services affected)
4. **Easy fix** (simple exclusion rule or regex refinement)

### Day 12: Implement Tuning

#### Task 3.3: Apply WAF Tuning

**Example: Refine nginx-config-injection rule**

```bash
# Update WAF policy
az network front-door waf-policy update \
  --name "$WAF_POLICY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --set 'customRules.rules[0].matchConditions[0].matchValue=["proxy_pass","lua_","\\$\\("]'
```

#### Task 3.4: Apply OPA Tuning

**Example: Expand annotation allowlist**

```bash
kubectl edit constrainttemplate dk8singressannotationallowlist

# Add safe annotations:
# - nginx.ingress.kubernetes.io/auth-url
# - nginx.ingress.kubernetes.io/limit-rps
```

### Day 13: Re-Validation

#### Task 3.5: Test Tuned Policies

```bash
# Run validation tests
./09-validate-tuning.sh

# Generate post-tuning report
./10-post-tuning-report.sh
```

**Verify:**
- ✅ FP rate reduced to < 1%
- ✅ No false negatives introduced
- ✅ Performance impact acceptable (< 5% latency increase)

---

## Go/No-Go Decision Framework

### Decision Criteria

| Criterion | Threshold | Status | Action if Failed |
|-----------|-----------|--------|------------------|
| **WAF FP Rate** | < 1.0% | ✅ / ❌ | Extended tuning (Week 2) |
| **OPA FP Rate** | < 1.0% | ✅ / ❌ | Allowlist expansion + re-test |
| **False Negatives** | 0 | ✅ / ❌ | BLOCK deployment, emergency fix |
| **Classification Complete** | 100% | ✅ / ❌ | Complete outstanding reviews |
| **Performance Impact** | < 5% p95 latency | ✅ / ❌ | Optimize rules, add caching |
| **Security Confidence** | High | ✅ / ❌ | Red team validation |

### Go Decision

**All criteria met → Proceed to sovereign deployment:**
1. Enable enforcement mode (WAF: Prevention, OPA: Deny)
2. Deploy to STG-GOV for 5-day validation
3. Deploy to PPE-GOV
4. Deploy to PROD-GOV

### No-Go Decision

**Any criterion failed → Block deployment:**
1. Document failure reason
2. Implement corrective actions
3. Re-run measurement (Week 3-4)
4. Escalate if > 2 No-Go cycles

### Decision Authority

- **Recommendation:** Security Engineer (Worf)
- **Approval:** Security Leadership / CISO
- **Meeting:** Day 14, 30-minute review
- **Outcome:** GO / NO-GO / CONDITIONAL-GO

---

## Troubleshooting

### Issue: WAF Logs Not Appearing

**Symptoms:** Zero results from WAF query

**Diagnosis:**
```bash
# Check diagnostic settings
az monitor diagnostic-settings list --resource "$WAF_POLICY_ID"

# Check WAF policy state
az network front-door waf-policy show --name "$WAF_POLICY_NAME" --query "policySettings"
```

**Resolution:**
1. Ensure diagnostic settings enabled: `./02-deploy-waf-policies.sh`
2. Verify WAF mode is "Detection"
3. Wait 5-10 minutes for log ingestion delay
4. Generate test traffic to confirm

### Issue: OPA Violations Not Logged

**Symptoms:** Zero results from OPA query

**Diagnosis:**
```bash
# Check Gatekeeper pods
kubectl get pods -n gatekeeper-system

# Check Fluent Bit logs
kubectl logs -n gatekeeper-system -l app=fluent-bit

# Check constraint enforcement
kubectl get constraints --all-namespaces -o yaml | grep enforcementAction
```

**Resolution:**
1. Ensure Fluent Bit running: `kubectl rollout restart daemonset/fluent-bit -n gatekeeper-system`
2. Verify constraints in dryrun mode
3. Create test Ingress to trigger violation
4. Check Fluent Bit config for workspace ID/key

### Issue: High False Positive Rate (> 5%)

**Symptoms:** FP rate consistently above threshold

**Diagnosis:**
```bash
# Identify problematic rules
jq '[.[] | select(.classification == "FP")] | group_by(.ruleId) | map({rule: .[0].ruleId, count: length}) | sort_by(.count) | reverse' waf-auto-classified.json
```

**Resolution:**
1. Review top 3 rules causing FPs
2. Analyze common patterns (query refine regex, add exclusions)
3. Implement tuning on Day 8 (don't wait until Day 12)
4. Re-validate for 2 more days

---

## Appendix

### A. Measurement Checklist

**Pre-Measurement (Day -3 to 0):**
- [ ] Telemetry infrastructure deployed
- [ ] WAF policies in Detection mode
- [ ] OPA policies in dryrun mode
- [ ] Logs flowing to Log Analytics
- [ ] Baseline metrics captured
- [ ] Classification UI tested

**Daily Routine (Day 1-10):**
- [ ] Retrieve blocked requests (05-classify-requests.sh)
- [ ] Review automated classifications
- [ ] Manually classify INCONCLUSIVE cases
- [ ] Upload classifications to Cosmos DB
- [ ] Generate daily report
- [ ] Update measurement state
- [ ] Alert if FP rate > 2%

**Post-Measurement (Day 11-13):**
- [ ] Generate final aggregate report
- [ ] Identify tuning priorities
- [ ] Implement WAF/OPA tuning
- [ ] Re-validate tuned policies
- [ ] Calculate final FP rates
- [ ] Prepare go/no-go recommendation
- [ ] Present to security leadership

### B. Contact Information

**Primary:** Worf (Security & Cloud)  
**Backup:** Security Team Lead  
**Escalation:** CISO

---

**END OF RUNBOOK**
