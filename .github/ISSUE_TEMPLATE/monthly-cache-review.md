---
name: Monthly Cache Review
about: Monthly review of FedRAMP Dashboard cache configuration and performance
title: 'Cache Review: [Month YYYY]'
labels: ['cache-review', 'fedramp', 'squad:data', 'squad:belanna']
assignees: []
---

# FedRAMP Dashboard Cache Configuration Review - [Month YYYY]

**Review Date:** [First Tuesday of Month] at 10:00 AM PT  
**Review Period:** [Start Date] to [End Date] (30 days)  
**Attendees:** Data (Code Expert), Infrastructure Lead, SRE On-Call

---

## Pre-Review Checklist

- [ ] Query Application Insights for 30-day metrics
- [ ] Prepare access pattern analysis
- [ ] Review any open action items from previous month
- [ ] Check for cache-related incidents or alerts

---

## Meeting Agenda

1. **Performance Metrics** (10 min)
   - Cache hit rate: Current vs. SLO (≥70%)
   - Backend query reduction: Current vs. target (80-85%)
   - P95 latency: Current vs. target (<500ms)

2. **Access Pattern Analysis** (10 min)
   - Top query combinations
   - Traffic patterns (peak/off-peak/weekend)
   - Unique parameter combinations

3. **Incidents & Anomalies** (5 min)
   - Alert history (cache hit rate < 70%)
   - Unusual patterns or traffic spikes
   - False positive analysis

4. **Recommendations & Action Items** (5 min)
   - Cache configuration adjustments needed
   - Monitoring improvements
   - Documentation updates

---

## Application Insights Queries

### 30-Day Cache Hit Rate
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

### Weekly Breakdown
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

### Top Query Combinations
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

## Deliverables

After the review meeting:

1. **Create Review Summary**
   - Use template: `docs/fedramp/cache-reviews/template.md`
   - Save as: `docs/fedramp/cache-reviews/YYYY-MM.md`
   - Include all metrics, findings, and action items

2. **Update Historical Tracking**
   - Add row to table in `docs/fedramp/cache-reviews/README.md`

3. **Create Action Item Issues**
   - File separate GitHub issues for any configuration changes
   - Link back to this review issue

4. **Schedule Next Review**
   - Create issue for next month using this template
   - Send calendar invite for first Tuesday of next month

---

## Reference Documentation

- **Cache SLI:** `docs/fedramp-dashboard-cache-sli.md`
- **Review Template:** `docs/fedramp/cache-reviews/template.md`
- **Deployment Runbook:** `docs/fedramp/phase5-rollout/deployment-runbook.md` (Section 9)
- **Alert Configuration:** `infrastructure/phase4-cache-alert.bicep`

---

## Post-Review

- [ ] Review summary document created and committed
- [ ] Historical tracking table updated
- [ ] Action items filed as separate issues
- [ ] Next month's review scheduled
- [ ] Close this issue

---

**Issue Source:** PR #108 (FedRAMP Dashboard caching SLI & monitoring)  
**Template Version:** 1.0  
**Owner:** Data (Code Expert)
