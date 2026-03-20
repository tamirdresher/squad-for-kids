# KEDA GitHub Copilot Rate-Limit External Scaler - Design Document

**Issue**: #1156  
**Parent Issue**: #1141  
**Author**: Picard (Lead)  
**Date**: 2026-03-21  
**Status**: Design Approved  
**Repository**: `keda-github-copilot-scaler` (new public OSS repo)

---

## Executive Summary

This document specifies the architecture and implementation plan for `keda-github-copilot-scaler`, a KEDA external gRPC scaler that enables intelligent horizontal pod autoscaling based on GitHub Copilot rate limits and quota consumption. This fills a genuine gap in the KEDA ecosystem—no existing scaler handles Copilot-specific metrics.

**Key Innovation**: Rate-limit-aware scaling prevents cascading 429 failures by scaling DOWN when rate-limited (counter to traditional queue-depth scaling that accelerates token exhaustion).

**Timeline**: 4-6 weeks to production-ready open-source release  
**License**: Apache 2.0  
**Language**: Go (KEDA standard)

---

## 1. Problem Statement

### Current Pain Points
1. **Squad agents exhaust GitHub rate limits** during peak hours (80-100 issues/hour)
2. **Static replica count** cannot respond to API quota pressure
3. **Cascading 429 failures** when all pods hit rate limits simultaneously
4. **No existing KEDA scaler** understands GitHub Copilot metrics

### Why Not Existing Scalers?
- **Prometheus scaler**: Requires separate metrics exporter (Tier 2 dependency)
- **Metrics API scaler**: No awareness of GitHub's quota reset windows
- **HTTP scaler**: Doesn't understand GitHub rate-limit headers
- **Cron scaler**: Time-based, not reactive to actual consumption

### Solution
**External gRPC scaler** with direct GitHub API integration—minimal dependencies, Copilot-aware scaling logic, rate-limit intelligence.

---

## 2. Architecture Overview

### 2.1 System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌──────────────┐      ┌─────────────────────────────┐    │
│  │ KEDA Operator│─gRPC→│ keda-copilot-scaler         │    │
│  │              │      │ (Deployment)                 │    │
│  │ Polls every  │      │                              │    │
│  │ 30s          │      │  ┌────────────────────────┐ │    │
│  └──────────────┘      │  │ gRPC Server (5000)     │ │    │
│                         │  │ - IsActive()           │ │    │
│         │               │  │ - GetMetrics()         │ │    │
│         │               │  │ - GetMetricSpec()      │ │    │
│         ▼               │  │ - StreamIsActive()     │ │    │
│  ┌──────────────┐      │  └────────────────────────┘ │    │
│  │ ScaledObject │      │                              │    │
│  │ my-squad-app │      │  ┌────────────────────────┐ │    │
│  │              │      │  │ GitHub API Client      │ │    │
│  │ minReplicas:0│      │  │ - GET /rate_limit      │◄──┐  │
│  │ maxReplicas:5│      │  │ - Copilot headers      │   │  │
│  └──────┬───────┘      │  └────────────────────────┘   │  │
│         │               │                              │  │  │
│         │ scales        │  ┌────────────────────────┐   │  │
│         ▼               │  │ Metrics Exporter       │   │  │
│  ┌──────────────┐      │  │ :9090/metrics          │   │  │
│  │ Squad Pods   │      │  │ (Prometheus)           │   │  │
│  │ 0-5 replicas │      │  └────────────────────────┘   │  │
│  └──────────────┘      └─────────────────────────────┘  │  │
│                                                          │  │
└──────────────────────────────────────────────────────────┘  │
                                                              │
                        ┌─────────────────────────────────────┘
                        │
                        ▼
              ┌─────────────────────┐
              │ GitHub API          │
              │ api.github.com      │
              │                     │
              │ /rate_limit         │
              │ /copilot/usage      │
              └─────────────────────┘
```

### 2.2 Component Responsibilities

#### KEDA Operator (External)
- Polls scaler every `pollingInterval` (default: 30s)
- Calculates desired replica count from metric values
- Enforces `minReplicaCount`, `maxReplicaCount`, `cooldownPeriod`
- Manages HPA (HorizontalPodAutoscaler) internally

#### keda-copilot-scaler (Our Service)
- **gRPC Server**: Implements KEDA ExternalScaler protocol
- **GitHub Client**: Queries `/rate_limit` endpoint, parses Copilot headers
- **Metrics Exporter**: Prometheus endpoint for observability
- **Scaling Logic**: Threshold-based decisions, rate-limit-aware

---

## 3. KEDA External Scaler Protocol

### 3.1 gRPC Service Interface

Based on [`externalscaler.proto`](https://github.com/kedacore/keda/blob/main/pkg/scalers/externalscaler/externalscaler.proto):

```protobuf
service ExternalScaler {
    rpc IsActive(ScaledObjectRef) returns (IsActiveResponse) {}
    rpc StreamIsActive(ScaledObjectRef) returns (stream IsActiveResponse) {}
    rpc GetMetricSpec(ScaledObjectRef) returns (GetMetricSpecResponse) {}
    rpc GetMetrics(GetMetricsRequest) returns (GetMetricsResponse) {}
}
```

### 3.2 Method Implementation Strategy

#### `GetMetricSpec(ScaledObjectRef) → GetMetricSpecResponse`
**Purpose**: Define metric name + target value for HPA  
**Execution**: Called once on ScaledObject reconciliation

**Implementation**:
```go
func (s *Server) GetMetricSpec(ctx context.Context, ref *pb.ScaledObjectRef) (*pb.GetMetricSpecResponse, error) {
    metricName := ref.ScalerMetadata["metric"] // "github_rate_limit_remaining"
    targetValue := ref.ScalerMetadata["targetValue"] // "1000"
    
    return &pb.GetMetricSpecResponse{
        MetricSpecs: []*pb.MetricSpec{
            {
                MetricName:       metricName,
                TargetSizeFloat:  parseFloat(targetValue), // Use float, int64 deprecated
            },
        },
    }, nil
}
```

**ScaledObject Example**:
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: squad-copilot-scaler
spec:
  scaleTargetRef:
    name: squad-deployment
  minReplicaCount: 0
  maxReplicaCount: 5
  cooldownPeriod: 300
  triggers:
    - type: external
      metadata:
        scalerAddress: keda-copilot-scaler.keda.svc:5000
        metric: github_rate_limit_remaining
        targetValue: "1000"
        github_token_secret: squad-github-token
```

---

#### `IsActive(ScaledObjectRef) → IsActiveResponse`
**Purpose**: Signal if scaling should be active (true) or idle (false)  
**Execution**: Called every `pollingInterval` (30s default)

**Scaling Logic**:
```
IF github_rate_limit_remaining > targetValue:
    RETURN true (keep scaling active)
ELSE:
    RETURN false (scale to minReplicaCount, likely 0)
```

**Implementation**:
```go
func (s *Server) IsActive(ctx context.Context, ref *pb.ScaledObjectRef) (*pb.IsActiveResponse, error) {
    rateLimit, err := s.githubClient.GetRateLimit(ctx)
    if err != nil {
        return &pb.IsActiveResponse{Result: false}, err
    }
    
    targetValue := parseFloat(ref.ScalerMetadata["targetValue"])
    active := float64(rateLimit.Remaining) > targetValue
    
    return &pb.IsActiveResponse{Result: active}, nil
}
```

**Decision Table**:
| Rate Limit Remaining | Target | IsActive | Behavior |
|---------------------|--------|----------|----------|
| 2500 | 1000 | `true` | Normal scaling (use GetMetrics) |
| 800 | 1000 | `false` | Scale to 0, wait for quota reset |
| 0 | 1000 | `false` | Hard stop, prevent 429 cascades |

---

#### `GetMetrics(GetMetricsRequest) → GetMetricsResponse`
**Purpose**: Return current metric value for HPA calculation  
**Execution**: Called every `pollingInterval` if `IsActive == true`

**Implementation**:
```go
func (s *Server) GetMetrics(ctx context.Context, req *pb.GetMetricsRequest) (*pb.GetMetricsResponse, error) {
    rateLimit, err := s.githubClient.GetRateLimit(ctx)
    if err != nil {
        return nil, err
    }
    
    metricName := req.MetricName // "github_rate_limit_remaining"
    var value float64
    
    switch metricName {
    case "github_rate_limit_remaining":
        value = float64(rateLimit.Remaining)
    case "github_rate_limit_used_pct":
        value = (float64(rateLimit.Used) / float64(rateLimit.Limit)) * 100
    default:
        return nil, fmt.Errorf("unknown metric: %s", metricName)
    }
    
    return &pb.GetMetricsResponse{
        MetricValues: []*pb.MetricValue{
            {
                MetricName:       metricName,
                MetricValueFloat: value,
            },
        },
    }, nil
}
```

**HPA Scaling Formula** (KEDA uses Kubernetes HPA):
```
desiredReplicas = ceil(currentReplicas * (currentMetricValue / targetMetricValue))
```

**Example**:
- Current replicas: 2
- Current metric: `github_rate_limit_remaining = 2000`
- Target metric: `1000`
- **Result**: `ceil(2 * (2000 / 1000)) = 4 replicas` (scale UP)

---

#### `StreamIsActive(ScaledObjectRef) → stream IsActiveResponse`
**Purpose**: Push-based scaling for event-driven triggers  
**Execution**: Long-lived connection, scaler pushes updates

**Phase 2 Feature** (not in MVP):
- Monitor GitHub webhooks for rate-limit resets
- Push `IsActive=true` immediately when quota refreshes
- Reduces cold-start latency from 30s (polling) to ~1s (push)

---

## 4. GitHub Rate Limit Metrics

### 4.1 Primary Metric Source: `/rate_limit` Endpoint

**API Call**:
```bash
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
     https://api.github.com/rate_limit
```

**Response Structure**:
```json
{
  "resources": {
    "core": {
      "limit": 5000,
      "used": 3200,
      "remaining": 1800,
      "reset": 1711035600
    },
    "search": {
      "limit": 30,
      "used": 10,
      "remaining": 20,
      "reset": 1711033800
    },
    "graphql": {
      "limit": 5000,
      "used": 50,
      "remaining": 4950,
      "reset": 1711035600
    }
  }
}
```

**Rate Limit Headers** (on every API response):
```
X-RateLimit-Limit: 5000
X-RateLimit-Remaining: 1800
X-RateLimit-Reset: 1711035600
X-RateLimit-Used: 3200
X-RateLimit-Resource: core
```

### 4.2 Copilot-Specific Metrics (Phase 2)

**Endpoint**: `GET /copilot/billing/seats` (requires Business/Enterprise)  
**Metrics**:
- `copilot_active_users`: Current active Copilot users
- `copilot_seat_utilization_pct`: `(active_users / total_seats) * 100`
- `copilot_quota_remaining`: Premium request quota (50-1500 depending on plan)

**Use Case**: Scale based on Copilot load, not just GitHub API quota.

### 4.3 Metrics Implementation Plan

#### Phase 1 (MVP) — Core API Rate Limits
| Metric Name | Source | Type | Description |
|------------|--------|------|-------------|
| `github_rate_limit_remaining` | `/rate_limit` → `resources.core.remaining` | int64 | Remaining API quota |
| `github_rate_limit_used_pct` | `/rate_limit` → `(used / limit) * 100` | float64 | % quota consumed |

#### Phase 2 — Copilot Quotas
| Metric Name | Source | Type | Description |
|------------|--------|------|-------------|
| `copilot_quota_remaining` | Response headers | int64 | Remaining Copilot requests |
| `copilot_seat_utilization_pct` | `/copilot/billing/seats` | float64 | Seat usage % |

---

## 5. Scaling Algorithm

### 5.1 Core Principle: Rate-Limit-Aware Scaling

**Traditional Autoscaling Problem**:
```
High Queue Depth → Scale UP → More Pods → More API Calls
                            → Exhaust Rate Limit → All Pods 429
                            → Cascading Failure
```

**KEDA Copilot Scaler Solution**:
```
High Queue Depth → Scale UP (if rate_limit_remaining > threshold)
Rate Limit Low   → Scale DOWN (to minReplicas, preserve quota)
Rate Limit Reset → Scale UP (resume work)
```

### 5.2 Decision Logic

```python
def should_scale(rate_limit_remaining, target_value, current_replicas, max_replicas):
    """
    Scaling decision algorithm
    """
    # Phase 1: IsActive check
    if rate_limit_remaining <= target_value:
        return 0  # Scale to minReplicaCount (cooldown in effect)
    
    # Phase 2: HPA calculation (KEDA does this)
    desired_replicas = ceil(current_replicas * (rate_limit_remaining / target_value))
    
    # Clamp to bounds
    return min(desired_replicas, max_replicas)
```

### 5.3 Configuration Parameters

**ScaledObject Metadata** (user-configurable):
```yaml
metadata:
  metric: github_rate_limit_remaining
  targetValue: "1000"                 # Scale to 0 when remaining < 1000
  pollingInterval: "30"               # Check every 30s
  cooldownPeriod: "300"               # Wait 5min before scaling back up
  github_token_secret: squad-token    # K8s Secret with GITHUB_TOKEN
  rate_limit_resource: core           # core | search | graphql
```

**Environment Variables** (scaler deployment):
```bash
GITHUB_TOKEN=ghp_xxxxx                # PAT with repo scope
PORT=5000                             # gRPC server port
METRICS_PORT=9090                     # Prometheus metrics
LOG_LEVEL=info                        # debug | info | warn | error
CACHE_TTL=30s                         # Cache GitHub API responses
```

### 5.4 Edge Cases

| Scenario | Behavior |
|----------|----------|
| GitHub API down | Return `IsActive=false`, scale to 0, avoid cascading errors |
| Invalid token | Log error, return `IsActive=false` |
| Rate limit reset during cooldown | Wait for cooldown to expire (KEDA manages) |
| Multiple ScaledObjects | Each polls independently, scaler is stateless |
| Pod eviction during scale-down | KEDA respects `PodDisruptionBudget` |

---

## 6. Implementation Plan (Go)

### 6.1 Repository Structure

```
keda-github-copilot-scaler/
├── cmd/
│   └── scaler/
│       └── main.go                    # Entry point, server bootstrap
├── internal/
│   ├── scaler/
│   │   ├── server.go                  # gRPC service implementation
│   │   └── server_test.go
│   ├── github/
│   │   ├── client.go                  # GitHub REST API client
│   │   ├── ratelimit.go               # Rate limit parsing
│   │   └── client_test.go
│   └── metrics/
│       └── prometheus.go              # Metrics exporter
├── proto/
│   └── externalscaler.proto           # KEDA protocol (Apache 2.0)
├── pkg/
│   └── externalscaler/
│       └── externalscaler.pb.go       # Generated from proto
├── deploy/
│   ├── deployment.yaml                # K8s Deployment
│   ├── service.yaml                   # ClusterIP Service
│   └── secret.yaml                    # GitHub token Secret
├── examples/
│   ├── scaledobject-rate-limit.yaml   # Example ScaledObject
│   └── scaledobject-copilot.yaml      # Phase 2 example
├── helm/
│   └── keda-github-copilot-scaler/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── .github/
│   └── workflows/
│       ├── ci.yaml                    # Build + test on push
│       └── release.yaml               # Docker build + GitHub release
├── Dockerfile                         # Multi-stage Go build
├── Makefile                           # Build, test, lint, docker targets
├── go.mod
├── go.sum
├── README.md                          # Quick-start, usage, examples
├── ARCHITECTURE.md                    # Deep-dive architecture (this doc)
├── CONTRIBUTING.md                    # Contribution guidelines
├── CODE_OF_CONDUCT.md                 # Contributor Covenant
└── LICENSE                            # Apache 2.0
```

### 6.2 Core Dependencies

```go
// go.mod
module github.com/tamirdresher/keda-github-copilot-scaler

go 1.21

require (
    google.golang.org/grpc v1.60.0
    google.golang.org/protobuf v1.31.0
    github.com/prometheus/client_golang v1.17.0
    github.com/google/go-github/v58 v58.0.0
    golang.org/x/oauth2 v0.15.0
    github.com/sirupsen/logrus v1.9.3
    github.com/stretchr/testify v1.8.4  // testing
)
```

### 6.3 Implementation Phases

#### **Week 1: Core gRPC Server**
- [ ] Copy `externalscaler.proto`, generate Go stubs (`protoc`)
- [ ] Implement `server.go` with 4 gRPC methods
- [ ] GitHub client with `/rate_limit` endpoint
- [ ] Unit tests for metric parsing
- [ ] Dockerfile + Makefile

**Acceptance**: `go build ./...` succeeds, `make test` passes

---

#### **Week 2: Kubernetes Integration**
- [ ] K8s Deployment + Service manifests
- [ ] Example ScaledObject YAML
- [ ] Secret management for `GITHUB_TOKEN`
- [ ] Prometheus metrics endpoint (`:9090/metrics`)
- [ ] Integration test: deploy to local Kind cluster

**Acceptance**: Scaler deploys to K8s, KEDA can call gRPC methods

---

#### **Week 3: Testing & Validation**
- [ ] Comprehensive unit tests (>80% coverage)
- [ ] Mock GitHub API for tests
- [ ] Load test: 10 ScaledObjects querying scaler
- [ ] Simulate rate limit exhaustion, validate scale-to-0
- [ ] Security audit: token handling, TLS config

**Acceptance**: All tests pass, security review complete

---

#### **Week 4: Production Readiness**
- [ ] Helm chart with values.yaml
- [ ] GitHub Actions CI: build + test on every push
- [ ] Docker image to GHCR (GitHub Container Registry)
- [ ] Grafana dashboard JSON
- [ ] README with quick-start, troubleshooting

**Acceptance**: `helm install` deploys successfully, CI green

---

#### **Week 5-6: Open Source Release**
- [ ] Create public repo `keda-github-copilot-scaler`
- [ ] GitHub release with binaries (Linux, macOS, Windows)
- [ ] Blog post announcement
- [ ] Submit to KEDA community external scalers catalog
- [ ] Social media: Twitter/LinkedIn announcement

**Acceptance**: Repo public, KEDA community notified

---

## 7. Authentication Strategy

### 7.1 Phase 1: GitHub Personal Access Token (PAT)

**Scopes Required**:
- `repo` (for `/rate_limit` access)
- `copilot` (Phase 2, for Copilot APIs)

**Kubernetes Secret**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: squad-github-token
  namespace: keda
type: Opaque
stringData:
  token: ghp_xxxxxxxxxxxxxxxxx
```

**Deployment Volume Mount**:
```yaml
env:
  - name: GITHUB_TOKEN
    valueFrom:
      secretKeyRef:
        name: squad-github-token
        key: token
```

### 7.2 Phase 2: GitHub App Authentication

**Benefits**:
- Higher rate limits (15,000/hour vs 5,000/hour)
- Organization-scoped, not user-scoped
- Fine-grained permissions

**Implementation**:
```go
// internal/github/client.go
func NewClientWithApp(appID int64, privateKey []byte) (*Client, error) {
    itr, err := ghinstallation.NewAppsTransport(http.DefaultTransport, appID, privateKey)
    if err != nil {
        return nil, err
    }
    return github.NewClient(&http.Client{Transport: itr}), nil
}
```

**Configuration**:
```yaml
metadata:
  github_app_id: "123456"
  github_app_private_key_secret: squad-github-app
```

### 7.3 Security Best Practices

1. **Never log tokens**: Mask in logs, metrics
2. **Use read-only scopes**: Minimize attack surface
3. **Rotate tokens regularly**: 90-day rotation policy
4. **Secrets in etcd encrypted**: AKS encryption-at-rest
5. **TLS for gRPC**: Phase 3, mTLS between KEDA ↔ scaler

---

## 8. Observability & Monitoring

### 8.1 Prometheus Metrics (`:9090/metrics`)

```prometheus
# Rate limit status
github_rate_limit_remaining{resource="core"} 1800
github_rate_limit_limit{resource="core"} 5000
github_rate_limit_used{resource="core"} 3200
github_rate_limit_reset_timestamp{resource="core"} 1711035600

# Scaler health
keda_copilot_scaler_requests_total{method="GetMetrics",status="success"} 1234
keda_copilot_scaler_requests_total{method="IsActive",status="error"} 5
keda_copilot_scaler_request_duration_seconds{method="GetMetrics"} 0.045

# Scaling events
keda_copilot_scaler_is_active{scaledobject="squad-copilot-scaler"} 1
keda_copilot_scaler_target_value{scaledobject="squad-copilot-scaler"} 1000
```

### 8.2 Grafana Dashboard

**Panels**:
1. **Rate Limit Timeline**: `github_rate_limit_remaining` over time
2. **Scaling Events**: `keda_copilot_scaler_is_active` binary heatmap
3. **API Latency**: `keda_copilot_scaler_request_duration_seconds` percentiles
4. **Error Rate**: `rate(keda_copilot_scaler_requests_total{status="error"}[5m])`

### 8.3 Alerts (PrometheusRule)

```yaml
- alert: GitHubRateLimitLow
  expr: github_rate_limit_remaining{resource="core"} < 500
  for: 5m
  annotations:
    summary: "GitHub rate limit critically low"

- alert: KEDAScalerUnhealthy
  expr: up{job="keda-copilot-scaler"} == 0
  for: 2m
  annotations:
    summary: "KEDA Copilot scaler is down"
```

---

## 9. Deployment Model

### 9.1 Deployment Patterns

#### **Pattern 1: Cluster-Scoped (Recommended)**
- **One scaler per cluster**
- **Pros**: Simple, minimal overhead, shared gRPC connection pool
- **Cons**: Single point of failure (mitigated by KEDA fallback)

```yaml
# deploy/deployment.yaml
replicas: 1  # Stateless, KEDA can handle restarts
```

#### **Pattern 2: Namespace-Scoped**
- **One scaler per namespace**
- **Pros**: Isolation, separate GitHub tokens per team
- **Cons**: Higher resource usage, more GitHub API calls

#### **Pattern 3: High Availability**
- **Multiple replicas with leader election**
- **Pros**: Zero downtime during pod evictions
- **Cons**: Requires distributed locking (etcd/Redis)
- **Status**: Phase 3 feature

### 9.2 Resource Requirements

**Pod Resource Requests/Limits**:
```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

**Rationale**:
- gRPC server: ~20m CPU baseline
- GitHub API client: HTTP pooling, minimal memory
- Prometheus exporter: ~10m CPU
- Overhead: 20m CPU buffer

### 9.3 Helm Values (Configurable)

```yaml
# helm/keda-github-copilot-scaler/values.yaml
replicaCount: 1

image:
  repository: ghcr.io/tamirdresher/keda-copilot-scaler
  tag: v0.1.0
  pullPolicy: IfNotPresent

service:
  grpc:
    port: 5000
  metrics:
    port: 9090

github:
  tokenSecret: squad-github-token  # Existing K8s Secret
  rateLimit:
    resource: core  # core | search | graphql

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s

securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
```

---

## 10. Testing Strategy

### 10.1 Unit Tests

**Coverage Target**: >80%

**Key Tests**:
```go
// internal/github/client_test.go
func TestGetRateLimit(t *testing.T) {
    // Mock GitHub API response
    // Assert parsing of rate limit fields
}

// internal/scaler/server_test.go
func TestIsActive_AboveThreshold(t *testing.T) {
    // Given: rate_limit_remaining = 2000, target = 1000
    // Expect: IsActive = true
}

func TestGetMetrics_RateLimitRemaining(t *testing.T) {
    // Given: GitHub API returns 1800 remaining
    // Expect: MetricValue = 1800.0
}
```

### 10.2 Integration Tests

**Test Scenarios**:
1. Deploy scaler to Kind cluster
2. Create ScaledObject with `type: external`
3. Mock GitHub API with rate limit = 2000
4. Assert KEDA scales deployment to 3 replicas (from metric formula)
5. Reduce rate limit to 500 (below target 1000)
6. Assert KEDA scales to 0 (IsActive = false)

**Tools**: Kind, KEDA Helm chart, testify/suite

### 10.3 Load Testing

**Scenario**: 10 ScaledObjects → 1 scaler (300 RPC calls/min)

**Metrics**:
- gRPC latency p50/p95/p99
- GitHub API rate limit consumption
- Memory usage under load

**Acceptance**: p95 latency < 100ms, no memory leaks

---

## 11. Security Considerations

### 11.1 Threat Model

| Threat | Impact | Mitigation |
|--------|--------|------------|
| Token leakage via logs | HIGH | Mask tokens in all logs, metrics |
| Token leakage via metrics | HIGH | Never expose token in Prometheus labels |
| Man-in-the-middle (KEDA ↔ scaler) | MEDIUM | TLS for gRPC (Phase 3) |
| Malicious ScaledObject | MEDIUM | RBAC: restrict ScaledObject creation |
| GitHub API token theft | HIGH | Kubernetes Secret encryption-at-rest |

### 11.2 Security Hardening

**Container Security**:
```dockerfile
FROM gcr.io/distroless/static-debian12:nonroot
USER 1000:1000
COPY --chown=1000:1000 scaler /scaler
ENTRYPOINT ["/scaler"]
```

**Network Policies**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: keda-copilot-scaler
spec:
  podSelector:
    matchLabels:
      app: keda-copilot-scaler
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: keda  # Only KEDA operator can call gRPC
      ports:
        - protocol: TCP
          port: 5000
```

**Pod Security Standards**: Restricted profile

---

## 12. Future Enhancements (Roadmap)

### Phase 2: Copilot-Specific Metrics (Week 7-8)
- [ ] `/copilot/billing/seats` API integration
- [ ] `copilot_active_users` metric
- [ ] `copilot_seat_utilization_pct` metric
- [ ] Multi-model support (GPT-4, GPT-4-turbo, O1-preview)

### Phase 3: Advanced Features (Week 9-12)
- [ ] **Predictive Scaling**: ML model predicts rate limit exhaustion 5 minutes ahead
- [ ] **Multi-Org Support**: Single scaler, multiple GitHub orgs
- [ ] **TLS/mTLS**: Encrypted gRPC communication
- [ ] **High Availability**: Leader election, active-passive replicas
- [ ] **GitHub App Auth**: Higher rate limits (15k/hour)

### Phase 4: Community Integration (Month 4+)
- [ ] Submit to KEDA external scaler catalog
- [ ] Publish to ArtifactHub (Helm chart)
- [ ] CNCF landscape inclusion
- [ ] KubeCon presentation proposal

---

## 13. Success Metrics

### 13.1 Technical Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Build time | < 2 minutes | GitHub Actions CI |
| Docker image size | < 20 MB | `docker images` |
| gRPC latency (p95) | < 100ms | Prometheus histogram |
| GitHub API calls | < 120/hour | Rate limit consumption |
| Test coverage | > 80% | `go test -cover` |
| Memory usage | < 64 MB | Kubernetes metrics |

### 13.2 Business Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| 429 error reduction | -80% | Squad agent logs |
| Cold-start latency | < 30s | Scale-from-0 duration |
| Cost savings (off-hours) | 50-70% | AKS node utilization |
| Community adoption | 50 GitHub stars in 3 months | GitHub insights |

---

## 14. Risk Assessment

### 14.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| GitHub API changes break client | MEDIUM | HIGH | Pin API version, integration tests |
| KEDA protocol changes | LOW | HIGH | Use stable KEDA version, monitor releases |
| Rate limit during scale-up | MEDIUM | MEDIUM | Exponential backoff, cache responses |
| Pod restarts during scaling | LOW | LOW | KEDA is stateless, recovers automatically |

### 14.2 Operational Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Scaler downtime | LOW | MEDIUM | KEDA falls back to default HPA |
| Incorrect scaling decisions | MEDIUM | MEDIUM | Start with conservative thresholds |
| Token expiration | LOW | HIGH | Alerts on 401 errors, runbook for rotation |

---

## 15. Dependencies & Prerequisites

### 15.1 External Dependencies

- **KEDA Operator**: v2.10+ (external scaler support stable in v2.9+)
- **Kubernetes**: v1.23+ (HPA v2 API)
- **GitHub API**: REST v3 (rate limit endpoint)
- **GitHub Account**: PAT with `repo` scope (Phase 1) or GitHub App (Phase 2)

### 15.2 Development Tools

```bash
# Required
go 1.21+
protoc (Protocol Buffers compiler)
docker / podman
kubectl
helm

# Optional
kind (local Kubernetes)
grpcurl (gRPC testing)
golangci-lint (code quality)
```

---

## 16. Alternatives Considered

### 16.1 Prometheus + Metrics Exporter (Tier 2)

**Pros**:
- Leverage existing kalgurn/github-rate-limits-exporter
- KEDA Prometheus scaler is mature, well-tested
- Separates concerns (exporter vs scaler)

**Cons**:
- Requires Prometheus deployment (additional infrastructure)
- Two-hop latency: GitHub → Exporter → Prometheus → KEDA
- No Copilot-specific logic (just raw rate limits)

**Decision**: Build external scaler for **Phase 1** (no Prometheus dependency). Add Prometheus integration as **Phase 2 alternative**.

---

### 16.2 KEDA Metrics API Scaler

**Pros**:
- Built-in KEDA scaler, no custom code
- Works with any HTTP endpoint returning JSON

**Cons**:
- Requires custom HTTP server to transform GitHub API → KEDA format
- No rate-limit-aware logic (just metric passthrough)
- Still custom code, but less flexible than gRPC

**Decision**: External gRPC scaler offers more control, native KEDA integration.

---

### 16.3 KEDA Cron Scaler

**Pros**:
- Simple, time-based scaling (e.g., scale to 5 at 9am, 0 at 6pm)
- No GitHub API calls, zero dependencies

**Cons**:
- Not reactive to actual rate limit consumption
- Wastes resources if rate limit is already low at 9am
- Doesn't handle unexpected load spikes

**Decision**: Cron as **fallback**, not primary strategy.

---

## 17. Open Questions (For Review)

1. **Multi-Org Support**: Should a single scaler support multiple GitHub orgs with separate tokens?
   - **Recommendation**: Phase 3 feature, start with single-org for simplicity

2. **Metric Caching**: Should we cache GitHub API responses for 30s to reduce API calls?
   - **Recommendation**: Yes, TTL = `pollingInterval` (default 30s)

3. **High Availability**: Should we support active-passive replicas with leader election?
   - **Recommendation**: Phase 3, start with single replica (KEDA is resilient to scaler restarts)

4. **Rate Limit Resource**: Should we support scaling on `search` or `graphql` resources?
   - **Recommendation**: Yes, make `rate_limit_resource` configurable (default: `core`)

5. **Error Handling**: What should `IsActive` return if GitHub API is down?
   - **Recommendation**: `false` (scale to 0, fail safe) + alert on repeated failures

---

## 18. Conclusion

This design provides a production-ready architecture for the first KEDA external scaler dedicated to GitHub Copilot rate-limit awareness. By scaling DOWN when rate-limited (not up), we prevent cascading 429 failures while maximizing API quota utilization.

**Key Innovations**:
1. **Rate-limit-aware scaling** (unique in KEDA ecosystem)
2. **Direct GitHub API integration** (no Prometheus dependency)
3. **Copilot-specific metrics** (Phase 2, no existing solution)

**Next Steps**:
1. **B'Elanna**: Review infrastructure deployment strategy (Week 1)
2. **Data**: Begin Go implementation, gRPC server skeleton (Week 1-2)
3. **Worf**: Security review, token management strategy (Week 2)
4. **Seven**: Draft README, CONTRIBUTING, open-source prep (Week 3-4)

---

**Approved by**: Picard (Lead)  
**Reviewed by**: TBD (B'Elanna, Data, Worf)  
**Status**: Ready for Implementation
