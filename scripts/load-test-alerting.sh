#!/bin/bash
# FedRAMP Alerting Pipeline - Load Test Script
# Owner: Worf (Security & Cloud)
# Purpose: Validate alerting pipeline can handle 500+ alerts/hour with Redis deduplication

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
FUNCTION_URL="${FUNCTION_URL:-}"
FUNCTION_KEY="${FUNCTION_KEY:-}"
TARGET_RATE="${TARGET_RATE:-500}"  # Alerts per hour
TEST_DURATION="${TEST_DURATION:-300}"  # 5 minutes default
REDIS_HOST="${REDIS_HOST:-}"
REDIS_KEY="${REDIS_KEY:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "FedRAMP Alerting Pipeline Load Test"
echo "=========================================="
echo ""

# Validate configuration
if [ -z "$FUNCTION_URL" ]; then
  echo -e "${RED}❌ Error: FUNCTION_URL not set${NC}"
  echo "Usage: FUNCTION_URL=https://your-function.azurewebsites.net/api/AlertProcessor FUNCTION_KEY=your-key $0"
  exit 1
fi

if [ -z "$FUNCTION_KEY" ]; then
  echo -e "${RED}❌ Error: FUNCTION_KEY not set${NC}"
  echo "Usage: FUNCTION_URL=https://your-function.azurewebsites.net/api/AlertProcessor FUNCTION_KEY=your-key $0"
  exit 1
fi

echo "Configuration:"
echo "  Function URL: $FUNCTION_URL"
echo "  Target Rate: $TARGET_RATE alerts/hour"
echo "  Test Duration: $TEST_DURATION seconds"
echo "  Requests to Send: $(echo "$TARGET_RATE * $TEST_DURATION / 3600" | bc)"
echo ""

# Create test data directory
TEST_DATA_DIR="/tmp/alerting-loadtest-$(date +%s)"
mkdir -p "$TEST_DATA_DIR"
RESULTS_FILE="$TEST_DATA_DIR/results.json"
METRICS_FILE="$TEST_DATA_DIR/metrics.txt"

# Generate sample alert payloads
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Generating test alert payloads..."

# Alert type distribution (realistic mix)
declare -A ALERT_TYPES=(
  ["control_drift"]=40
  ["control_regression"]=20
  ["threshold_breach"]=15
  ["new_vulnerability"]=15
  ["compliance_deadline"]=5
  ["manual_review_needed"]=5
)

# Generate payloads
PAYLOAD_COUNT=100
for i in $(seq 1 $PAYLOAD_COUNT); do
  # Select alert type based on distribution
  rand=$((RANDOM % 100))
  cumulative=0
  alert_type=""
  for type in "${!ALERT_TYPES[@]}"; do
    cumulative=$((cumulative + ALERT_TYPES[$type]))
    if [ $rand -lt $cumulative ]; then
      alert_type=$type
      break
    fi
  done
  
  # Random control ID
  CONTROL_IDS=("SC-7" "SC-8" "SI-2" "SI-3" "RA-5" "CM-3" "IR-4" "AC-3" "CM-7")
  control_id=${CONTROL_IDS[$((RANDOM % ${#CONTROL_IDS[@]}))]}
  
  # Random environment
  ENVIRONMENTS=("dev" "stg" "prod")
  environment=${ENVIRONMENTS[$((RANDOM % ${#ENVIRONMENTS[@]}))]}
  
  # Random severity (weighted toward P2/P3)
  rand=$((RANDOM % 100))
  if [ $rand -lt 5 ]; then
    severity="P0"
  elif [ $rand -lt 20 ]; then
    severity="P1"
  elif [ $rand -lt 60 ]; then
    severity="P2"
  else
    severity="P3"
  fi
  
  # Generate payload
  cat > "$TEST_DATA_DIR/payload-${i}.json" <<EOF
{
  "alert_type": "$alert_type",
  "alert_id": "loadtest-$(uuidgen)",
  "severity": "$severity",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "control": {
    "id": "$control_id",
    "name": "Test Control",
    "category": "Test Category"
  },
  "environment": "$environment",
  "region": "eastus2",
  "cloud": "PublicAzure",
  "metrics": {
    "test_metric": $(echo "$RANDOM / 100" | bc -l)
  },
  "runbook_url": "https://wiki.contoso.com/runbooks/test",
  "remediation_steps": ["Step 1", "Step 2"]
}
EOF
done

echo "✅ Generated $PAYLOAD_COUNT unique alert payloads"
echo ""

# Function to send alert
send_alert() {
  local payload_file=$1
  local request_id=$2
  
  start_time=$(date +%s.%N)
  
  response=$(curl -s -w "\n%{http_code}\n%{time_total}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "x-functions-key: $FUNCTION_KEY" \
    -d @"$payload_file" \
    "$FUNCTION_URL" 2>&1)
  
  http_code=$(echo "$response" | tail -2 | head -1)
  duration=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -2)
  
  echo "$request_id,$http_code,$duration,$body" >> "$RESULTS_FILE"
}

# Start load test
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Starting load test..."
echo ""

# Calculate delay between requests (microseconds)
requests_per_second=$(echo "scale=6; $TARGET_RATE / 3600" | bc)
delay_seconds=$(echo "scale=6; 1 / $requests_per_second" | bc)

echo "Calculated rate: $requests_per_second requests/second"
echo "Delay between requests: ${delay_seconds}s"
echo ""

# Initialize results file
echo "request_id,http_code,duration_s,response_body" > "$RESULTS_FILE"

# Start background process to monitor Redis
if [ -n "$REDIS_HOST" ] && [ -n "$REDIS_KEY" ]; then
  echo "Monitoring Redis deduplication..."
  (
    while true; do
      redis_keys=$(redis-cli -h "$REDIS_HOST" -p 6380 --tls -a "$REDIS_KEY" --no-auth-warning KEYS "alert:dedup:*" 2>/dev/null | wc -l)
      echo "[$(date +%s)] Redis dedup keys: $redis_keys" >> "$TEST_DATA_DIR/redis-monitor.txt"
      sleep 5
    done
  ) &
  REDIS_MONITOR_PID=$!
fi

# Send alerts
request_count=0
total_requests=$(echo "$TARGET_RATE * $TEST_DURATION / 3600" | bc)
end_time=$(($(date +%s) + TEST_DURATION))

while [ $(date +%s) -lt $end_time ]; do
  # Round-robin through payloads
  payload_index=$((request_count % PAYLOAD_COUNT + 1))
  payload_file="$TEST_DATA_DIR/payload-${payload_index}.json"
  
  # Send alert in background
  send_alert "$payload_file" "$request_count" &
  
  request_count=$((request_count + 1))
  
  # Progress update every 50 requests
  if [ $((request_count % 50)) -eq 0 ]; then
    echo "  Sent $request_count requests..."
  fi
  
  # Rate limiting
  sleep "$delay_seconds"
done

echo ""
echo "Waiting for in-flight requests to complete..."
wait

# Stop Redis monitor
if [ -n "${REDIS_MONITOR_PID:-}" ]; then
  kill $REDIS_MONITOR_PID 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "Load Test Complete"
echo "=========================================="
echo ""

# Analyze results
total_sent=$request_count
success_count=$(awk -F',' '$2 == 200 {count++} END {print count+0}' "$RESULTS_FILE")
error_count=$(awk -F',' '$2 != 200 && NR > 1 {count++} END {print count+0}' "$RESULTS_FILE")
success_rate=$(echo "scale=2; $success_count * 100 / $total_sent" | bc)

# Response time stats
avg_duration=$(awk -F',' 'NR > 1 {sum+=$3; count++} END {print sum/count}' "$RESULTS_FILE")
p50_duration=$(awk -F',' 'NR > 1 {print $3}' "$RESULTS_FILE" | sort -n | awk '{arr[NR]=$1} END {print arr[int(NR*0.5)]}')
p95_duration=$(awk -F',' 'NR > 1 {print $3}' "$RESULTS_FILE" | sort -n | awk '{arr[NR]=$1} END {print arr[int(NR*0.95)]}')
p99_duration=$(awk -F',' 'NR > 1 {print $3}' "$RESULTS_FILE" | sort -n | awk '{arr[NR]=$1} END {print arr[int(NR*0.99)]}')

# Deduplication stats (count unique vs total)
duplicate_count=$(awk -F',' '$4 ~ /"status":"duplicate"/ {count++} END {print count+0}' "$RESULTS_FILE")
duplicate_rate=$(echo "scale=2; $duplicate_count * 100 / $total_sent" | bc)

echo "Test Results:"
echo "  Total Requests Sent: $total_sent"
echo "  Successful (200): $success_count (${success_rate}%)"
echo "  Errors: $error_count"
echo ""
echo "Response Times:"
echo "  Average: ${avg_duration}s"
echo "  P50: ${p50_duration}s"
echo "  P95: ${p95_duration}s"
echo "  P99: ${p99_duration}s"
echo ""
echo "Deduplication:"
echo "  Duplicates Detected: $duplicate_count (${duplicate_rate}%)"
echo ""

# Throughput calculation
actual_duration=$TEST_DURATION
actual_rate=$(echo "scale=2; $total_sent * 3600 / $actual_duration" | bc)
echo "Throughput:"
echo "  Target: $TARGET_RATE alerts/hour"
echo "  Actual: ${actual_rate} alerts/hour"
echo ""

# Redis stats
if [ -f "$TEST_DATA_DIR/redis-monitor.txt" ]; then
  max_redis_keys=$(awk '{print $4}' "$TEST_DATA_DIR/redis-monitor.txt" | sort -n | tail -1)
  echo "Redis Cache:"
  echo "  Peak Dedup Keys: $max_redis_keys"
  echo ""
fi

# Save metrics
cat > "$METRICS_FILE" <<EOF
Total Requests: $total_sent
Success Rate: ${success_rate}%
Error Count: $error_count
Average Duration: ${avg_duration}s
P50 Duration: ${p50_duration}s
P95 Duration: ${p95_duration}s
P99 Duration: ${p99_duration}s
Duplicate Rate: ${duplicate_rate}%
Target Rate: $TARGET_RATE alerts/hour
Actual Rate: ${actual_rate} alerts/hour
EOF

echo "Results saved to: $TEST_DATA_DIR"
echo "  - Full results: $RESULTS_FILE"
echo "  - Metrics summary: $METRICS_FILE"
echo ""

# Validation
if [ $(echo "$success_rate < 99.0" | bc) -eq 1 ]; then
  echo -e "${RED}❌ FAIL: Success rate ${success_rate}% below 99% threshold${NC}"
  exit 1
elif [ $(echo "$actual_rate < $TARGET_RATE" | bc) -eq 1 ]; then
  echo -e "${YELLOW}⚠️  WARNING: Actual rate ${actual_rate} alerts/hour below target ${TARGET_RATE}${NC}"
  exit 1
elif [ $(echo "$p95_duration > 2.0" | bc) -eq 1 ]; then
  echo -e "${YELLOW}⚠️  WARNING: P95 latency ${p95_duration}s exceeds 2s threshold${NC}"
  exit 1
else
  echo -e "${GREEN}✅ PASS: Load test successful${NC}"
  echo "  - Success rate: ${success_rate}% (>99%)"
  echo "  - Throughput: ${actual_rate} alerts/hour (>${TARGET_RATE})"
  echo "  - P95 latency: ${p95_duration}s (<2s)"
  exit 0
fi
