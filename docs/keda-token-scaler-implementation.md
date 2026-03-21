# KEDA Token-Aware Autoscaling Implementation Guide

> **Issue:** #1134  
> **Status:** Implementation complete  
> **Last updated:** 2026-03-21

## Overview

This guide explains how KEDA's token-aware autoscaler works for Squad agents and how to deploy, configure, and troubleshoot it.

The token scaler prevents Squad agent pods from spinning up when:
1. **Copilot token budget is exhausted** (free tier: 50 requests/month)
2. **GitHub API rate limits are nearly hit** (5000 requests/hour)
3. **No work is queued** (no open `squad:picard` issues)

When any of these conditions fail, Picard pods scale to 0 and wait for the condition to clear.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ GitHub API                                                      │
│  • /rate_limit endpoint (rate-limit status)                    │
│  • /issues list (work queue depth)                             │
└──────────┬──────────────────────────────────────────────────────┘
           │
      (polled every 30s)
           │
    ┌──────▼────────────────────────────────────────┐
    │ Metrics Exporters (Python Deployment)        │
    ├─────────────────────────────────────────────┤
    │ • squad-metrics-exporter (port 9100)         │
    │   - github_api_rate_limit_remaining          │
    │   - squad_copilot_queue_depth                │
    │                                              │
    │ • copilot-metrics-exporter (port 9101)       │
    │   - copilot_tokens_remaining                 │
    │   - copilot_token_burn_rate                  │
    │   - copilot_rate_limit_hits_total            │
    └──────┬─────────────────────────────────────┬─┘
           │                                       │
       (scrapes)                                (scrapes)
           │                                       │
    ┌──────▼───────────────────────────────────────▼──┐
    │ Prometheus (monitoring namespace)               │
    │  • ServiceMonitor: scrapes exporters every 30s  │
    └──────┬──────────────────────────────────────────┘
           │
       (reads metrics)
           │
    ┌──────▼──────────────────────────────────┐
    │ KEDA Operator (keda namespace)          │
    │  • Evaluates ScaledObject triggers      │
    │  • Computes desired replicas            │
    │  • Updates HPA target                   │
    └──────┬───────────────────────────────────┘
           │
       (scales)
           │
    ┌──────▼──────────────────────────────┐
    │ Picard Deployment (squad namespace) │
    │  • 0-5 replicas based on conditions │
    │  • Pods scale up in ~60s             │
    │  • Pods scale down in ~5 min (grace) │
    └───────────────────────────────────────┘
```

---

## Deployment Steps

### Step 1: Verify KEDA is installed

```bash
# AKS Standard Free: manually install KEDA add-on
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-keda

# Verify installation
kubectl get pods -n keda
# Expected output:
#   keda-operator-6d5c8b7f8f-xxxxx
#   keda-metrics-apiserver-7c5d4b8f-xxxxx
```

For AKS Automatic, KEDA is already installed.

### Step 2: Deploy the Helm chart

```bash
helm upgrade --install squad-agents ./infrastructure/helm/squad-agents \
  --namespace squad --create-namespace \
  --set keda.enabled=true \
  --set keda.tokenScaler.enabled=true \
  --set metricsExporter.enabled=true \
  --set global.acrLoginServer=acrsquadprod.azurecr.io \
  --set global.keyVaultName=kv-squad-prod \
  --set global.tenantId=$TENANT_ID \
  --set azure.managedIdentityClientId=$CLIENT_ID
```

### Step 3: Verify exporters are healthy

```bash
# Check if exporters are running
kubectl get pods -n squad -l app.kubernetes.io/component=copilot-metrics-exporter
kubectl get pods -n squad -l app.kubernetes.io/component=squad-metrics-exporter

# Expected: 1 running pod for each

# Check logs for errors (first 30s may show initial setup)
kubectl logs -n squad -l app.kubernetes.io/component=copilot-metrics-exporter --tail=30

# Test metrics endpoint directly
kubectl port-forward -n squad svc/copilot-metrics-exporter 9101:9101 &
curl http://localhost:9101/metrics | grep copilot_tokens_remaining
kill %1  # Stop port-forward
```

### Step 4: Verify KEDA ScaledObject is active

```bash
# List ScaledObjects
kubectl get scaledobjects -n squad
# Expected: picard-token-scaler should be listed

# Check detailed status
kubectl describe scaledobject picard-token-scaler -n squad

# Expected status conditions:
# - Active: True
# - ScalableTargetActive: True
# - FallbackActive: False (when metrics are healthy)
```

### Step 5: Create test work to trigger scaling

```bash
# Create an issue labelled squad:picard
gh issue create \
  --repo tamirdresher_microsoft/tamresearch1 \
  --title "Test KEDA token scaler" \
  --body "This issue tests KEDA autoscaling." \
  --label squad:picard

# Monitor Picard replicas
kubectl get deployment picard -n squad --watch
# Expected: after 30-60s, replicas should increase to 1

# Watch KEDA metrics
kubectl get hpa -n squad --watch
# Expected: TargetCPU should show desired replicas increasing
```

---

## Configuration Reference

### Token Scaler Values (values.yaml)

```yaml
keda:
  enabled: true                          # Master KEDA switch

  tokenScaler:
    enabled: true                        # Enable token-aware scaling
    
    # Replica bounds
    minReplicaCount: 0                   # Scale to zero when idle
    maxReplicaCount: 5                   # Max 5 concurrent Picard instances
    
    # Timing
    pollingInterval: 30                  # KEDA evaluates every 30s
    cooldownPeriod: 300                  # 5 min idle before scale-to-zero
    
    # Queue targeting (composite scaling formula)
    targetQueuePerReplica: "2"           # 1 replica per 2 open issues
    
    # Token thresholds
    tokenThreshold: "5"                  # Min tokens to allow scaling (free: 5/50)
    tokenActivationThreshold: "1"        # Critical: < 1 token = never scale
    
    # Rate-limit thresholds (GitHub API)
    rateLimitThreshold: "500"            # 10% headroom (500 out of 5000/hour)
    rateLimitActivationThreshold: "100"  # 2% headroom = critical
    
    # Fallback to simple GitHub scaler if metrics unavailable
    fallbackGithubScaler: true

metricsExporter:
  enabled: true                          # Deploy both exporters
  squadLabel: "squad:picard"             # Issue label to count for queue
  pollIntervalSeconds: "30"              # Poll GitHub every 30s
  port: 9100                             # squad-metrics-exporter port
  copilotMetricsPort: 9101               # copilot-metrics-exporter port
```

### Scaling Formula

The token scaler uses KEDA's `scalingModifiers` formula:

```
desiredReplicas = (s1 > 0 && s0 > tokenThreshold && s2 > rateLimitThreshold) 
                  ? ceil(s1 / targetQueuePerReplica) 
                  : 0

where:
  s0 = copilot_tokens_remaining{tier="free"}
  s1 = squad_copilot_queue_depth{label="squad:picard"}
  s2 = github_api_rate_limit_remaining{resource="core"}
```

**Examples:**

1. **Work available, tokens sufficient, rate limit OK:**
   - 4 open issues, 10 tokens remaining, 4500 rate limit remaining
   - Formula: `4 > 0 && 10 > 5 && 4500 > 500` → True
   - Result: `ceil(4 / 2)` → **2 replicas**

2. **Work available, tokens low:**
   - 4 open issues, 2 tokens remaining, 4500 rate limit
   - Formula: `4 > 0 && 2 > 5 && 4500 > 500` → False (tokens too low)
   - Result: **0 replicas** (scale down, wait for monthly reset)

3. **Work available, rate-limited:**
   - 4 open issues, 10 tokens, 80 rate limit remaining
   - Formula: `4 > 0 && 10 > 5 && 80 > 500` → False (rate-limited)
   - Result: **0 replicas** (backoff for 5 min until reset)

4. **No work:**
   - 0 open issues
   - Formula: `0 > 0 && ... && ...` → False
   - Result: **0 replicas** (no work, no need to scale)

---

## Monitoring & Metrics

### Key Metrics Exposed

**copilot-metrics-exporter (port 9101):**
```
copilot_tokens_remaining{tier="free"}     # 0-50 for free tier
copilot_tokens_remaining{tier="pro"}      # Unlimited or rate-limited value
copilot_token_burn_rate{tier="free"}      # tokens/minute consumption trend
copilot_rate_limit_hits_total             # Counter of 429 responses
copilot_queue_depth{agent="picard"}       # Open issues awaiting processing
```

**squad-metrics-exporter (port 9100):**
```
github_api_rate_limit_remaining{resource="core"}   # 0-5000 requests remaining
github_api_rate_limit_reset{resource="core"}       # Unix timestamp of reset
squad_copilot_queue_depth{label="squad:picard"}    # Work queue depth
squad_metrics_exporter_errors_total                # Collection errors
```

### Prometheus Queries

To validate metrics in Prometheus (if installed):

```promql
# Current token count
copilot_tokens_remaining{tier="free"}

# Token consumption rate (last 5 minutes)
rate(copilot_tokens_remaining{tier="free"}[5m])

# GitHub rate-limit headroom (% of 5000)
github_api_rate_limit_remaining{resource="core"} / 5000

# Work queue depth
squad_copilot_queue_depth{label="squad:picard"}

# Desired replicas (from scaling formula)
ceil(squad_copilot_queue_depth / 2)
```

---

## Troubleshooting

### Problem: Metrics not updating

**Symptom:** `kubectl logs -n squad <exporter-pod>` shows API errors

**Root cause:** Usually GitHub API authentication or network connectivity

**Diagnosis:**
```bash
# Check GH_TOKEN is mounted correctly
kubectl exec -n squad <exporter-pod> -- env | grep GH_TOKEN

# Verify gh CLI works inside pod
kubectl exec -n squad <exporter-pod> -- gh copilot status

# Check internet connectivity from pod
kubectl exec -n squad <exporter-pod> -- curl -I https://api.github.com
```

**Fix:**
- Ensure GH_TOKEN secret is in Key Vault and CSI driver is working
- Verify service account has Workload Identity annotation
- Check pod logs for specific API errors

### Problem: KEDA not scaling

**Symptom:** Picard replicas stay at 0 even with open issues

**Root cause:** Often metric thresholds are blocking, or metrics are unavailable

**Diagnosis:**
```bash
# Check ScaledObject status
kubectl describe scaledobject picard-token-scaler -n squad

# Look for:
#   - Active: True/False
#   - FallbackActive: True/False (fallback means metrics unavailable)
#   - Conditions with messages

# Check KEDA operator logs
kubectl logs -n keda deployment/keda-operator -f | grep picard-token-scaler

# Manually query metrics
kubectl port-forward -n squad svc/copilot-metrics-exporter 9101:9101 &
curl http://localhost:9101/metrics | grep -E "copilot_tokens|squad_copilot_queue"
kill %1
```

**Fix:**
- If `FallbackActive: True`, metrics are unavailable — check exporter pods
- If metrics exist but scaling doesn't trigger, check token/rate-limit thresholds
- Increase `tokenThreshold` or `rateLimitThreshold` if they're blocking

### Problem: Pods stuck at 0 replicas

**Symptom:** Work is queued but Picard never scales up

**Root cause:** Token budget exhausted (free tier) or rate-limited

**Diagnosis:**
```bash
# Check token count
kubectl exec -n squad <copilot-exporter-pod> -- gh copilot status

# Check GitHub rate limit
gh api rate_limit -q '.rate'

# Check KEDA formula evaluation in operator logs
kubectl logs -n keda deployment/keda-operator | grep "scaling result"
```

**Fix - Free tier token budget:**
- Wait for monthly reset (typically 1st of month)
- Or upgrade to Copilot Pro for unlimited requests
- Temporarily increase `tokenThreshold` to allow low-token operation

**Fix - Rate-limited:**
- Wait 5+ minutes for GitHub's rate-limit window to reset
- Reduce polling interval if exporters are consuming too much quota
- Increase `rateLimitThreshold` to require more headroom

### Problem: Exporters crashing (CrashLoopBackOff)

**Symptom:** `kubectl get pods -n squad` shows exporter as Error/CrashLoopBackOff

**Diagnosis:**
```bash
kubectl logs -n squad <exporter-pod> --tail=50
```

**Common errors:**
- `ERROR: GH_TOKEN is required` → Secret not mounted (CSI driver issue)
- `No module named 'requests'` → pip install failed (network issue)
- `rate_limit exceeded` → Too many rapid polling requests

**Fix:**
- Verify CSI SecretProviderClass is applied: `kubectl get secretproviderclass -n squad`
- Check Key Vault access: `az keyvault secret show --vault-name $KV_NAME --name squad-gh-token`
- Increase `pollIntervalSeconds` (default 30s should be safe)

---

## Production Checklist

Before enabling token scaler in production:

- [ ] KEDA v2.12+ is installed (`kubectl get deployment -n keda`)
- [ ] Metrics exporters are healthy (running and logging no errors)
- [ ] Prometheus is scraping metrics (check ServiceMonitor, targets)
- [ ] Picard deployment exists with correct labels
- [ ] GitHub token (GH_TOKEN) has `repo:read` scope for rate-limit + issue queries
- [ ] Token and rate-limit thresholds match your tier (free vs. pro)
- [ ] Scale-to-zero is tested (pods scale down when work queue is empty)
- [ ] Scale-up latency is acceptable (~60s from issue creation to pod ready)
- [ ] Fallback GitHub scaler is enabled (in case metrics fail)
- [ ] Monitoring/alerting is configured for exporter health

---

## Related Issues

- #1134 — KEDA autoscaling (this issue)
- #1160 — Composite AND-logic scaling
- #1158 — GitHub Actions runner queue trigger
- #998 — Copilot auth for K8s pods
- #1059 — Squad on Kubernetes architecture
- #1060 — AKS deployment reference

---

## See Also

- **Helm Chart:** `infrastructure/helm/squad-agents/`
- **Templates:**
  - `templates/copilot-metrics-exporter.yaml`
  - `templates/picard-token-scaledobject.yaml`
  - `templates/github-metrics-exporter.yaml`
- **Values:** `values.yaml` (keda, metricsExporter sections)
- **AKS Guide:** `docs/squad-on-aks.md` (deployment steps)
