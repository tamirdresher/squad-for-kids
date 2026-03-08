# Cache Configuration Review - [Month Year]

**Date:** [YYYY-MM-DD]  
**Attendees:** [Names and roles]  
**Review Period:** [Start Date] to [End Date] (30 days)

---

## 1. Executive Summary

[2-3 sentence summary of cache performance this month]

**Key Findings:**
- ✅/⚠️/❌ Cache hit rate: [X]% ([above/below] SLO target of 70%)
- ✅/⚠️/❌ Backend query reduction: [X]% ([meeting/not meeting] 80-85% target)
- ✅/⚠️/❌ P95 latency: [X]ms ([within/exceeding] 500ms target)

---

## 2. Performance Metrics

### 2.1 Cache Hit Rate

**30-Day Average:** [X]%  
**SLO Target:** ≥ 70%  
**Status:** ✅ Green / ⚠️ Yellow / ❌ Red

**Weekly Breakdown:**
| Week | Hit Rate | Total Requests | Cache Hits | Cache Misses |
|------|----------|----------------|------------|--------------|
| Week 1 | [X]% | [N] | [N] | [N] |
| Week 2 | [X]% | [N] | [N] | [N] |
| Week 3 | [X]% | [N] | [N] | [N] |
| Week 4 | [X]% | [N] | [N] | [N] |

**Trend Analysis:**
[Describe trend: improving, stable, declining]

### 2.2 Latency Metrics

**P95 Latency:**
- Cached responses: [X]ms
- Uncached responses: [X]ms
- Overall: [X]ms (Target: <500ms)

**P99 Latency:**
- Cached responses: [X]ms
- Uncached responses: [X]ms
- Overall: [X]ms (Target: <1000ms)

### 2.3 Backend Query Reduction

**Cosmos DB Query Metrics:**
- Queries without cache: [N] queries/day (estimated)
- Queries with cache: [N] queries/day (actual)
- Reduction: [X]% (Target: 80-85%)

**RU Consumption:**
- Before caching (estimated): [N] RU/day
- With caching (actual): [N] RU/day
- Savings: [N] RU/day (~$[X]/month)

---

## 3. Access Pattern Analysis

### 3.1 Top Query Combinations

**Most Frequent Requests (by parameter combination):**
| Rank | Environment | Control Category | Request Count | % of Total |
|------|-------------|------------------|---------------|------------|
| 1 | [env] | [category] | [N] | [X]% |
| 2 | [env] | [category] | [N] | [X]% |
| 3 | [env] | [category] | [N] | [X]% |
| 4 | [env] | [category] | [N] | [X]% |
| 5 | [env] | [category] | [N] | [X]% |

**Total Unique Combinations:** [N]  
**Expected Maximum:** ~18 (6 environments × 3 categories)

### 3.2 Traffic Patterns

**Peak Hours:**
- Time window: [HH:MM - HH:MM PT]
- Average hit rate: [X]%
- Average request rate: [N] req/min

**Off-Peak Hours:**
- Time window: [HH:MM - HH:MM PT]
- Average hit rate: [X]%
- Average request rate: [N] req/min

**Weekend Traffic:**
- Average hit rate: [X]%
- Average request rate: [N] req/min

---

## 4. Incidents & Anomalies

### 4.1 Alert History

**Cache Hit Rate Alerts (<70%):**
- Total alerts: [N]
- False positives: [N]
- Legitimate incidents: [N]

**Incident Summary:**
| Date | Duration | Root Cause | Resolution |
|------|----------|------------|------------|
| [YYYY-MM-DD] | [N] min | [Cause] | [Action] |

### 4.2 Anomalies Detected

[Describe any unusual patterns, unexpected traffic spikes, or cache misses]

**Example:**
- [YYYY-MM-DD]: Cache hit rate dropped to 45% for 2 hours due to pod restart
- [YYYY-MM-DD]: Unusual spike in unique parameter combinations (bot traffic detected)

---

## 5. Observations & Insights

[3-5 key observations from this month's data]

**Positive Findings:**
- [Observation 1]
- [Observation 2]

**Areas for Improvement:**
- [Observation 3]
- [Observation 4]

**Operational Notes:**
- [Observation 5]

---

## 6. Recommendations & Action Items

**Cache Configuration Adjustments:**
- [ ] **Action 1:** [Description]
  - **Rationale:** [Why this change is needed]
  - **Owner:** [Name]
  - **Due Date:** [YYYY-MM-DD]
  - **Implementation:** [How to implement - PR number or config change]

- [ ] **Action 2:** [Description]
  - **Rationale:** [Why]
  - **Owner:** [Name]
  - **Due Date:** [YYYY-MM-DD]

**Monitoring Improvements:**
- [ ] **Action 3:** [Description]
  - **Rationale:** [Why]
  - **Owner:** [Name]
  - **Due Date:** [YYYY-MM-DD]

**Documentation Updates:**
- [ ] **Action 4:** [Description]
  - **Rationale:** [Why]
  - **Owner:** [Name]
  - **Due Date:** [YYYY-MM-DD]

---

## 7. Next Review

**Scheduled Date:** [First Tuesday of next month]  
**Pre-Review Actions:**
- [ ] Query Application Insights for 30-day metrics
- [ ] Prepare access pattern analysis
- [ ] Review any open action items from this month

---

## Appendix A: Query Scripts

**Application Insights Query (30-day cache hit rate):**
```kusto
requests
| where timestamp > ago(30d)
| where name has "compliance"
| extend IsCacheHit = iff(duration < 100, 1, 0)
| summarize 
    TotalRequests = count(),
    CacheHits = sum(IsCacheHit),
    CacheMisses = sum(1 - IsCacheHit),
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95),
    P99Duration = percentile(duration, 99)
| extend CacheHitRate = round((CacheHits * 100.0) / TotalRequests, 2)
| project 
    TotalRequests,
    CacheHits,
    CacheMisses,
    CacheHitRate,
    AvgDuration = round(AvgDuration, 2),
    P95Duration = round(P95Duration, 2),
    P99Duration = round(P99Duration, 2)
```

**Weekly Breakdown Query:**
```kusto
requests
| where timestamp > ago(30d) and name has "compliance"
| extend IsCacheHit = iff(duration < 100, 1, 0)
| extend Week = startofweek(timestamp)
| summarize 
    TotalRequests = count(),
    CacheHits = sum(IsCacheHit)
    by Week
| extend CacheHitRate = round((CacheHits * 100.0) / TotalRequests, 2)
| order by Week desc
```

**Top Query Combinations:**
```kusto
requests
| where timestamp > ago(30d) and name has "compliance"
| extend Environment = tostring(customDimensions["Environment"])
| extend ControlCategory = tostring(customDimensions["ControlCategory"])
| summarize RequestCount = count() by Environment, ControlCategory
| extend PercentOfTotal = round((RequestCount * 100.0) / toscalar(requests | where timestamp > ago(30d) and name has "compliance" | count()), 2)
| order by RequestCount desc
| take 10
```

---

**Document Version:** 1.0  
**Template Owner:** Data (Code Expert)
