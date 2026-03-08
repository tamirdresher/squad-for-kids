# FedRAMP Dashboard: Response Cache SLI Documentation

**Document Version:** 1.0  
**Owner:** Data (Code Expert)  
**Issue:** #106  
**Related:** PR #102 (API Security & Resilience Hardening)  
**Date:** March 2026  
**Status:** Production

---

## Executive Summary

The FedRAMP Security Dashboard API implements HTTP response caching to reduce backend load and improve response latency. This document defines the cache configuration as a production Service Level Indicator (SLI), establishes Service Level Objectives (SLOs), and provides monitoring guidance.

**Key Metrics:**
- **Cache Duration (TTL):** 60 seconds (status endpoint), 300 seconds (trend endpoint)
- **SLO Target:** Cache hit rate ≥ 70%
- **Expected Performance:** 80-85% query reduction, 20-30% latency improvement

---

## 1. Cache Configuration

### 1.1 Implementation Overview

The API uses ASP.NET Core's built-in `ResponseCache` middleware configured at the controller action level. Cache entries vary by query parameters to ensure correct data segmentation.

**Location:** `api/FedRampDashboard.Api/Controllers/ComplianceController.cs`

### 1.2 Cache TTL by Endpoint

| Endpoint | Cache Duration | VaryBy Keys | Rationale |
|----------|----------------|-------------|-----------|
| `GET /api/v1/compliance/status` | **60 seconds** | `environment`, `controlCategory` | Real-time compliance view; balance freshness vs. load |
| `GET /api/v1/compliance/trend` | **300 seconds** | `environment`, `startDate`, `endDate`, `granularity` | Historical data; less sensitive to staleness |

**Design Decision:**
- 60s for status endpoint balances user expectation of "current" data with backend query cost
- 300s for trend data acceptable as historical trends don't change rapidly
- VaryByQueryKeys ensures isolation between different environments/filters

### 1.3 Cache Storage

- **Cache Provider:** ASP.NET Core In-Memory Cache (`IMemoryCache`)
- **Cache Scope:** Per-instance (no distributed cache in initial deployment)
- **Maximum Entries:** ~18 expected (6 environments × 3 categories)
- **Memory Footprint:** < 50 MB per instance

---

## 2. Service Level Objectives (SLO)

### 2.1 Cache Hit Rate SLO

**Target:** ≥ 70% cache hit rate  
**Measurement Window:** 24 hours (rolling)  
**Measurement Methodology:** Application Insights telemetry

#### Calculation:
```
Cache Hit Rate = (Cached Responses / Total Requests) × 100%
```

#### Expected Performance:
- **Typical Workload:** 80-85% cache hit rate
- **Dashboard refresh interval:** Most users poll every 30-60 seconds
- **Peak hours (9-11 AM PT):** 85-90% hit rate due to concurrent users
- **Off-hours:** 60-70% hit rate due to sporadic requests

#### SLO Thresholds:
- **Green (Normal):** ≥ 75% hit rate
- **Yellow (Warning):** 70-74% hit rate → Review cache TTL and access patterns
- **Red (Alert):** < 70% hit rate → Trigger investigation (see Section 4)

### 2.2 Performance SLOs

These metrics are improved by caching but measured independently:

| Metric | SLO Target | Cache Impact |
|--------|------------|--------------|
| **P95 Latency** | < 500 ms | 20-30% improvement (cached: ~50 ms, uncached: ~350 ms) |
| **P99 Latency** | < 1000 ms | 30-40% improvement |
| **Throughput** | 100 req/sec | 5x increase (500 req/sec with caching) |
| **Backend Query Load** | < 20 queries/min | 80-85% reduction |

---

## 3. Monitoring & Telemetry

### 3.1 Application Insights Metrics

**Explicit Cache Telemetry (Issue #115):**

The API implements explicit cache telemetry through custom events and HTTP headers for precise cache hit/miss tracking:

1. **Age Header** - Standard HTTP cache age header
   - Added to all cached responses
   - Value: `0` for cache miss, `>0` for cache hit (seconds since cached)
   - Enables client-side cache awareness

2. **Custom Events** - Application Insights custom events
   - Event Types: `CacheHit`, `CacheMiss`
   - Properties:
     - `Endpoint`: Request path (e.g., `/api/v1/compliance/status`)
     - `Method`: HTTP method (GET)
     - `CacheStatus`: "HIT" or "MISS"
     - `ResponseAge`: Age header value in seconds
     - `Environment`: Query parameter value
     - `ControlCategory`: Query parameter value
   - Metrics:
     - `Duration`: Response time in milliseconds

**Built-in Metrics:**
1. **Request Duration** (dependency: `requests` table)
   - Filter: `name contains "compliance/status" OR name contains "compliance/trend"`
   - Dimension: `resultCode` (200 cached vs. 200 fresh)

**Structured Logging:**
```csharp
_logger.LogInformation(
    "Cache telemetry tracked: Endpoint={Endpoint}, Status={Status}, Age={Age}s, Duration={Duration}ms",
    endpoint, status, age, duration);
```

### 3.2 Cache Hit Rate Calculation Query

**Primary Query (Explicit Telemetry - Recommended):**
```kusto
// Uses explicit cache events (Issue #115)
customEvents
| where timestamp > ago(24h)
| where name in ("CacheHit", "CacheMiss")
| where customDimensions.Endpoint has "compliance"
| extend IsCacheHit = iff(name == "CacheHit", 1, 0)
| summarize 
    TotalRequests = count(),
    CacheHits = sum(IsCacheHit),
    CacheMisses = sum(1 - IsCacheHit)
| extend CacheHitRate = (CacheHits * 100.0) / TotalRequests
| project 
    TotalRequests,
    CacheHits,
    CacheMisses,
    CacheHitRate = round(CacheHitRate, 2)
```

**Alternative Query (Age Header):**
```kusto
// Uses Age header from custom properties
customEvents
| where timestamp > ago(24h)
| where name in ("CacheHit", "CacheMiss")
| where customDimensions.Endpoint has "compliance"
| extend ResponseAge = tolong(customDimensions["ResponseAge"])
| extend IsCacheHit = iff(ResponseAge > 0, 1, 0)
| summarize 
    TotalRequests = count(),
    CacheHits = sum(IsCacheHit)
| extend CacheHitRate = (CacheHits * 100.0) / TotalRequests
```

**Legacy Query (Duration-based - Deprecated):**
```kusto
// DEPRECATED: Uses duration < 100ms as proxy for cache hit
// Replaced by explicit telemetry in Issue #115
requests
| where timestamp > ago(24h)
| where name has "compliance"
| extend IsCacheHit = iff(duration < 100, 1, 0)
| summarize 
    TotalRequests = count(),
    CacheHits = sum(IsCacheHit)
| extend CacheHitRate = (CacheHits * 100.0) / TotalRequests
```

### 3.3 Dashboard Visualization

**Azure Monitor Workbook:**
- **Chart 1:** Cache hit rate (line chart, 24-hour rolling window)
- **Chart 2:** Request count breakdown (stacked bar: cache hits vs. misses)
- **Chart 3:** P95 latency by cache status (cached vs. uncached)
- **Chart 4:** Backend query count (Cosmos DB RU consumption)

---

## 4. Alerting & Remediation

### 4.1 Application Insights Alert

**Alert Name:** `FedRAMP-Dashboard-Cache-Hit-Rate-Low`  
**Condition:** Cache hit rate < 70% for 15 minutes  
**Evaluation Frequency:** Every 5 minutes  
**Severity:** Warning (Sev 2)  
**Action Group:** `fedramp-oncall` (PagerDuty integration)

**Alert Query:**
```kusto
requests
| where timestamp > ago(15m)
| where name has "compliance"
| extend IsCacheHit = iff(duration < 100, 1, 0)
| summarize 
    CacheHits = sum(IsCacheHit),
    TotalRequests = count()
| extend CacheHitRate = (CacheHits * 100.0) / TotalRequests
| where CacheHitRate < 70
```

**Configuration Steps:** See Section 5 (Infrastructure as Code)

### 4.2 Remediation Playbook

#### **Symptom:** Cache hit rate < 70%

**Immediate Actions (5 minutes):**
1. **Check recent deployments:** Did API restart clear cache?
   - Verify: `kubectl get pods -n fedramp-dashboard` (check restart count)
   - If restart within last hour: **Normal behavior** (cache warming in progress)
   
2. **Analyze request patterns:** Are requests highly diverse?
   - Run query: Count distinct (`environment`, `controlCategory`) pairs
   - If > 50 unique combinations: **Expected** (cache fragmentation)

**Investigation (15 minutes):**
3. **Review access logs:** Identify top request sources
   ```kusto
   requests
   | where timestamp > ago(1h) and name has "compliance"
   | summarize RequestCount = count() by client_IP
   | top 10 by RequestCount
   ```
   - If single IP > 50% traffic: Possible bot/scraper (rate limiting needed)

4. **Check cache TTL effectiveness:**
   - Calculate average time between repeat requests for same parameters
   - If avg > 60s: TTL too short (consider increasing to 90s)

**Resolution Paths:**

| Root Cause | Resolution | Timeline |
|------------|------------|----------|
| **Pod restart / deployment** | Wait for cache to warm (15-30 min) | Automatic |
| **Request diversity (many unique params)** | Adjust VaryBy keys or increase cache size | 1 hour (code change) |
| **Short TTL for access pattern** | Increase cache duration to 90-120s | 30 min (config change) |
| **Unexpected traffic spike** | Scale out API instances (HPA) | 5 min (automatic) |
| **Cache invalidation bug** | Review cache middleware logs, hotfix if needed | 2 hours (code fix) |

---

## 5. Infrastructure as Code

### 5.1 Bicep Template for Alert

**File:** `infrastructure/phase4-cache-alert.bicep`

```bicep
param appInsightsName string
param actionGroupId string
param location string = resourceGroup().location

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource cacheHitRateAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: 'FedRAMP-Dashboard-Cache-Hit-Rate-Low'
  location: location
  properties: {
    displayName: 'FedRAMP Dashboard - Cache Hit Rate Below 70%'
    description: 'Alert when API response cache hit rate falls below 70% for 15 minutes'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [
      appInsights.id
    ]
    criteria: {
      allOf: [
        {
          query: '''
            requests
            | where timestamp > ago(15m)
            | where name has "compliance"
            | extend IsCacheHit = iff(duration < 100, 1, 0)
            | summarize 
                CacheHits = sum(IsCacheHit),
                TotalRequests = count()
            | extend CacheHitRate = (CacheHits * 100.0) / TotalRequests
            | where CacheHitRate < 70
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupId
      ]
      customProperties: {
        Runbook: 'https://github.com/tamirdresher_microsoft/tamresearch1/blob/main/docs/fedramp-dashboard-cache-sli.md#42-remediation-playbook'
        Severity: 'Warning'
        Team: 'FedRAMP-OnCall'
      }
    }
  }
}

output alertId string = cacheHitRateAlert.id
```

### 5.2 Deployment Command

```bash
# Deploy alert to production environment
az deployment group create \
  --resource-group rg-fedramp-dashboard-prod \
  --template-file infrastructure/phase4-cache-alert.bicep \
  --parameters \
    appInsightsName=appi-fedramp-dashboard-prod \
    actionGroupId=/subscriptions/{sub-id}/resourceGroups/rg-fedramp-dashboard-prod/providers/Microsoft.Insights/actionGroups/fedramp-oncall
```

---

## 6. Operational Procedures

### 6.1 Cache Management Commands

**View current cache statistics (PowerShell):**
```powershell
# Query Application Insights for last 1 hour
$query = @"
requests
| where timestamp > ago(1h) and name has "compliance"
| extend IsCacheHit = iff(duration < 100, 1, 0)
| summarize CacheHits = sum(IsCacheHit), Total = count()
| extend HitRate = round((CacheHits * 100.0) / Total, 2)
"@

az monitor app-insights query `
  --app appi-fedramp-dashboard-prod `
  --analytics-query $query
```

**Force cache clear (emergency only):**
```bash
# Restart API pods (clears in-memory cache)
kubectl rollout restart deployment/fedramp-dashboard-api -n fedramp-dashboard

# Verify pods restarted
kubectl get pods -n fedramp-dashboard -w
```

### 6.2 30-Day Cache Configuration Review

**Schedule:** First Tuesday of each month (10 AM PT)  
**Owner:** Data (Code Expert) + SRE Team  
**Duration:** 30 minutes  

**Agenda:**
1. **Review Cache Hit Rate Trends (15 min)**
   - Query Application Insights for 30-day average hit rate
   - Identify anomalies or declining trends
   - Compare against SLO target (70%)

2. **Analyze Access Patterns (10 min)**
   - Top 10 query parameter combinations (by frequency)
   - Request distribution by environment/control category
   - Identify unused cache keys (consider pruning VaryBy parameters)

3. **Performance Impact Assessment (5 min)**
   - Backend query reduction (actual vs. expected 80-85%)
   - Latency improvements (P95/P99)
   - Cost savings (Cosmos DB RU consumption)

4. **Recommendations & Actions**
   - Adjust cache TTL if needed (document in Issue/PR)
   - Update VaryBy keys if query patterns changed
   - Scale cache size if memory pressure detected

**Review Template:**
```markdown
## Cache Configuration Review - [Month Year]

**Date:** [Date]  
**Attendees:** [Names]  

### Metrics (30-day window)
- Cache Hit Rate: [X]% (Target: ≥70%)
- P95 Latency: [X]ms (Cached: [X]ms, Uncached: [X]ms)
- Backend Query Reduction: [X]%
- Cosmos DB RU Savings: [X] RU/month

### Observations
- [Observation 1]
- [Observation 2]

### Recommendations
- [ ] Action 1: [Description] (Owner: [Name], Due: [Date])
- [ ] Action 2: [Description]

### Next Review
**Date:** [First Tuesday of next month]
```

**Tracking:** Store reviews in `docs/fedramp/cache-reviews/YYYY-MM.md`

---

## 7. Cache Invalidation Strategy (Future)

### 7.1 Current State (v1.0)

- **No explicit invalidation:** Cache entries expire naturally after TTL
- **Acceptable for:** Dashboard use case (compliance data updated every 15 minutes)
- **Risk:** Max 60s stale data for status endpoint

### 7.2 Future Enhancements (v2.0)

If compliance data updates become more frequent (< 15 min interval):

1. **Event-driven invalidation:**
   - Azure Function triggers on Cosmos DB change feed
   - Publish cache invalidation event to Azure Service Bus
   - API subscribes and clears specific cache keys

2. **Distributed cache (Redis):**
   - Replace in-memory cache with Azure Cache for Redis
   - Enables cross-instance cache sharing
   - Supports explicit invalidation via Redis pub/sub

3. **Cache versioning:**
   - Include data version in cache key
   - Increment version on backend data update
   - Old cache entries become unreachable (stale but harmless)

**Decision Point:** Implement if cache hit rate drops below 60% consistently or stale data incidents occur.

---

## 8. Related Documentation

- **API Implementation:** `api/FedRampDashboard.Api/Controllers/ComplianceController.cs`
- **PR #102 Review:** FedRAMP Dashboard API Security & Resilience Hardening
- **Deployment Runbook:** `docs/fedramp/phase5-rollout/deployment-runbook.md`
- **Operational Runbook:** TBD (see Issue #106)
- **Infrastructure:** `infrastructure/phase2-api.bicep`

---

## 9. Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | March 2026 | Data (Code Expert) | Initial SLI documentation (Issue #106) |

---

**Document Maintenance:**
- Review quarterly or after significant API changes
- Update SLO targets based on 3-month performance data
- Archive monthly review summaries in `docs/fedramp/cache-reviews/`
