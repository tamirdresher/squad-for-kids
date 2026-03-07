#!/bin/bash
# Azure Monitor Helper Functions for Validation Tests
# Source this file in test scripts: source azure-monitor-helper.sh

# Configuration (set via environment variables or defaults)
AZURE_MONITOR_API_VERSION="${AZURE_MONITOR_API_VERSION:-2021-09-01}"
AZURE_MONITOR_RESOURCE="${AZURE_MONITOR_RESOURCE:-https://monitoring.azure.com}"
AZURE_MONITOR_TOKEN="${AZURE_MONITOR_TOKEN:-}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
CLUSTER_NAME="${CLUSTER_NAME:-$(kubectl config current-context 2>/dev/null || echo 'unknown')}"
REGION="${REGION:-$(kubectl get nodes -o jsonpath='{.items[0].metadata.labels.topology\.kubernetes\.io/region}' 2>/dev/null || echo 'unknown')}"
CLOUD="${CLOUD:-Public}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function: Get Azure Monitor access token
get_azure_monitor_token() {
  if [[ -n "$AZURE_MONITOR_TOKEN" ]]; then
    echo "$AZURE_MONITOR_TOKEN"
    return 0
  fi
  
  # Try to get token via Azure CLI
  if command -v az >/dev/null 2>&1; then
    local token
    token=$(az account get-access-token --resource "$AZURE_MONITOR_RESOURCE" --query accessToken -o tsv 2>/dev/null)
    if [[ -n "$token" ]]; then
      echo "$token"
      return 0
    fi
  fi
  
  echo -e "${RED}ERROR: No Azure Monitor token available. Set AZURE_MONITOR_TOKEN or authenticate with 'az login'${NC}" >&2
  return 1
}

# Function: Send validation result to Azure Monitor Custom Metrics
send_to_azure_monitor() {
  local result_json="$1"
  local dry_run="${2:-}"
  
  # Validate JSON
  if ! echo "$result_json" | jq empty 2>/dev/null; then
    echo -e "${RED}ERROR: Invalid JSON format${NC}" >&2
    return 1
  fi
  
  # Extract key fields
  local control_id=$(echo "$result_json" | jq -r '.control_id')
  local test_name=$(echo "$result_json" | jq -r '.test_name')
  local status=$(echo "$result_json" | jq -r '.status')
  local timestamp=$(echo "$result_json" | jq -r '.timestamp')
  
  # Get subscription ID and resource group (from pipeline vars or defaults)
  local subscription_id="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv 2>/dev/null)}"
  local resource_group="${AZURE_RESOURCE_GROUP:-fedramp-dashboard-phase1-${ENVIRONMENT}-rg}"
  
  if [[ -z "$subscription_id" ]]; then
    echo -e "${RED}ERROR: AZURE_SUBSCRIPTION_ID not set${NC}" >&2
    return 1
  fi
  
  # Build Azure Monitor custom metrics API URL
  local api_url="https://management.azure.com/subscriptions/${subscription_id}/resourceGroups/${resource_group}/providers/Microsoft.Insights/metrics?api-version=${AZURE_MONITOR_API_VERSION}"
  
  # Build metrics payload
  local metrics_payload
  metrics_payload=$(cat <<EOF
{
  "time": "${timestamp}",
  "data": {
    "baseData": {
      "metric": "ControlValidationResult",
      "namespace": "FedRAMP/Validation",
      "dimNames": [
        "ControlId",
        "Environment",
        "Status",
        "TestName"
      ],
      "series": [
        {
          "dimValues": [
            "${control_id}",
            "${ENVIRONMENT}",
            "${status}",
            "${test_name}"
          ],
          "min": 1,
          "max": 1,
          "sum": 1,
          "count": 1
        }
      ]
    }
  }
}
EOF
)
  
  if [[ "$dry_run" == "--dry-run" ]]; then
    echo -e "${YELLOW}[DRY RUN] Would send to Azure Monitor:${NC}"
    echo "$metrics_payload" | jq '.'
    return 0
  fi
  
  # Get access token
  local token
  token=$(get_azure_monitor_token)
  if [[ $? -ne 0 ]]; then
    return 1
  fi
  
  # Send to Azure Monitor
  local response
  response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "$metrics_payload")
  
  local http_code=$(echo "$response" | tail -n1)
  local body=$(echo "$response" | sed '$d')
  
  if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    echo -e "${GREEN}✓ Sent to Azure Monitor: $control_id/$test_name [$status]${NC}" >&2
    return 0
  else
    echo -e "${RED}ERROR: Azure Monitor API returned HTTP $http_code${NC}" >&2
    echo "$body" | jq '.' 2>/dev/null || echo "$body" >&2
    return 1
  fi
}

# Function: Send validation result to Log Analytics (DCE/DCR ingestion)
send_to_log_analytics() {
  local result_json="$1"
  local dry_run="${2:-}"
  
  # Log Analytics Data Collection Endpoint (DCE)
  local dce_endpoint="${LOG_ANALYTICS_DCE:-}"
  local dcr_immutable_id="${LOG_ANALYTICS_DCR_ID:-}"
  local stream_name="Custom-ControlValidationResults_CL"
  
  if [[ -z "$dce_endpoint" || -z "$dcr_immutable_id" ]]; then
    echo -e "${YELLOW}WARNING: Log Analytics DCE/DCR not configured, skipping Log Analytics ingestion${NC}" >&2
    return 0
  fi
  
  # Transform JSON to Log Analytics schema
  local log_analytics_json
  log_analytics_json=$(echo "$result_json" | jq '{
    TimeGenerated: .timestamp,
    Environment_s: .environment,
    Cluster_s: .cluster,
    ControlId_s: .control_id,
    ControlName_s: .control_name,
    TestCategory_s: .test_category,
    TestName_s: .test_name,
    Status_s: .status,
    ExecutionTimeMs_d: .execution_time_ms,
    Details_s: (.details | tostring),
    PipelineId_s: .metadata.pipeline_id,
    CommitSha_s: .metadata.commit_sha
  }')
  
  if [[ "$dry_run" == "--dry-run" ]]; then
    echo -e "${YELLOW}[DRY RUN] Would send to Log Analytics:${NC}"
    echo "$log_analytics_json" | jq '.'
    return 0
  fi
  
  # Get access token
  local token
  token=$(get_azure_monitor_token)
  if [[ $? -ne 0 ]]; then
    return 1
  fi
  
  # Send to Log Analytics via DCE/DCR
  local api_url="${dce_endpoint}/dataCollectionRules/${dcr_immutable_id}/streams/${stream_name}?api-version=2023-01-01"
  
  local response
  response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "[$log_analytics_json]")  # Note: Log Analytics expects array
  
  local http_code=$(echo "$response" | tail -n1)
  local body=$(echo "$response" | sed '$d')
  
  if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    echo -e "${GREEN}✓ Sent to Log Analytics${NC}" >&2
    return 0
  else
    echo -e "${RED}ERROR: Log Analytics API returned HTTP $http_code${NC}" >&2
    echo "$body" >&2
    return 1
  fi
}

# Function: Build validation result JSON
build_validation_result() {
  local control_id="$1"
  local control_name="$2"
  local test_category="$3"
  local test_name="$4"
  local status="$5"
  local execution_time_ms="$6"
  local details_json="${7:-{}}"
  
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  local result_json
  result_json=$(cat <<EOF
{
  "timestamp": "${timestamp}",
  "environment": "${ENVIRONMENT}",
  "cluster": "${CLUSTER_NAME}",
  "region": "${REGION}",
  "cloud": "${CLOUD}",
  "control_id": "${control_id}",
  "control_name": "${control_name}",
  "test_category": "${test_category}",
  "test_name": "${test_name}",
  "status": "${status}",
  "execution_time_ms": ${execution_time_ms},
  "details": ${details_json},
  "metadata": {
    "pipeline_id": "${BUILD_BUILDID:-manual}",
    "pipeline_url": "${SYSTEM_TEAMFOUNDATIONCOLLECTIONURI:-}${SYSTEM_TEAMPROJECT:-}/_build/results?buildId=${BUILD_BUILDID:-}",
    "commit_sha": "${BUILD_SOURCEVERSION:-$(git rev-parse HEAD 2>/dev/null || echo 'unknown')}",
    "commit_message": "${BUILD_SOURCEVERSIONMESSAGE:-}",
    "branch": "${BUILD_SOURCEBRANCHNAME:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')}",
    "triggered_by": "${BUILD_REASON:-manual}"
  }
}
EOF
)
  
  echo "$result_json"
}

# Function: Report test result (sends to Azure Monitor + Log Analytics)
report_test_result() {
  local control_id="$1"
  local control_name="$2"
  local test_category="$3"
  local test_name="$4"
  local status="$5"
  local execution_time_ms="$6"
  local details_json="${7:-{}}"
  
  # Build JSON
  local result_json
  result_json=$(build_validation_result "$control_id" "$control_name" "$test_category" "$test_name" "$status" "$execution_time_ms" "$details_json")
  
  # Send to Azure Monitor
  send_to_azure_monitor "$result_json"
  
  # Send to Log Analytics (if configured)
  send_to_log_analytics "$result_json"
  
  # Also print to stdout for pipeline logs
  if [[ "$status" == "PASS" ]]; then
    echo -e "${GREEN}[PASS]${NC} $test_name"
  else
    echo -e "${RED}[FAIL]${NC} $test_name"
  fi
}

# Function: Test connectivity to Azure Monitor
test_azure_monitor_connectivity() {
  echo -e "${YELLOW}Testing Azure Monitor connectivity...${NC}"
  
  local token
  token=$(get_azure_monitor_token)
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Failed to get Azure Monitor token${NC}"
    return 1
  fi
  
  echo -e "${GREEN}✓ Azure Monitor token acquired${NC}"
  
  # Test API call
  local subscription_id="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv 2>/dev/null)}"
  if [[ -n "$subscription_id" ]]; then
    echo -e "${GREEN}✓ Azure subscription: $subscription_id${NC}"
  else
    echo -e "${YELLOW}⚠ Azure subscription ID not available${NC}"
  fi
  
  echo -e "${GREEN}✓ Azure Monitor connectivity OK${NC}"
  return 0
}

# Export functions
export -f get_azure_monitor_token
export -f send_to_azure_monitor
export -f send_to_log_analytics
export -f build_validation_result
export -f report_test_result
export -f test_azure_monitor_connectivity
