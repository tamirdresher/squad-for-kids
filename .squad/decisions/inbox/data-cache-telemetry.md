# Decision: Explicit Cache Telemetry via Age Header and Custom Events

**Date:** 2026-03-08  
**Author:** Data (Code Expert)  
**Issue:** #115  
**Related:** PR #108, #106

## Context

FedRAMP Dashboard API cache hit rate monitoring currently uses `duration < 100ms` as a proxy for cache hits. This inference approach has limitations:
- False positives from fast uncached responses
- No distinction between genuinely fast queries and cached responses
- Lack of explicit cache signal in telemetry

Picard noted in PR #108 review:
> "Alert query assumption: Uses duration < 100ms to infer cache hits. Consider instrumenting explicit cache telemetry (Age header) in future iterations for precision."

## Decision

Implemented explicit cache telemetry using two mechanisms:

### 1. Age Header (HTTP Standard)
- Add standard HTTP `Age` header to all cached API responses
- Value: `0` for cache miss, `>0` for cache hit (seconds since cached)
- Complies with RFC 7234 (HTTP/1.1 Caching)
- Enables client-side cache awareness

### 2. Application Insights Custom Events
- Track `CacheHit` and `CacheMiss` events for every request
- Event properties: Endpoint, CacheStatus, ResponseAge, Environment, ControlCategory
- Event metrics: Duration (ms)
- Enables precise cache analytics via `customEvents` table

### 3. Alert Query Migration
Migrated from inference to explicit signals:
```kusto
// OLD (inference)
requests | extend IsCacheHit = iff(duration < 100, 1, 0)

// NEW (explicit)
customEvents 
| where name in ("CacheHit", "CacheMiss")
| extend IsCacheHit = iff(name == "CacheHit", 1, 0)
```

## Implementation

**Middleware:** `CacheTelemetryMiddleware`
- Intercepts all `/api/v1/compliance` responses
- Tracks cache events post-response
- Adds Age header before response is sent

**Service:** `ICacheTelemetryService` + `CacheTelemetryService`
- Abstraction for cache event tracking
- Registered in DI container
- Integrated with Application Insights TelemetryClient

**Registration:** `Program.cs`
- Added `builder.Services.AddApplicationInsightsTelemetry()`
- Registered middleware: `app.UseCacheTelemetry()`
- Registered service: `builder.Services.AddScoped<ICacheTelemetryService, CacheTelemetryService>()`

## Consequences

### Positive
1. **Precision:** Direct measurement vs. inference eliminates false positives
2. **Standard Compliance:** Age header is HTTP/1.1 standard (RFC 7234)
3. **Client-Side Awareness:** Clients can inspect Age header for debugging
4. **Rich Analytics:** Event properties enable deeper cache analysis
5. **Alert Accuracy:** Eliminates duration-based false positives

### Negative
1. **Additional Storage:** Custom events consume Application Insights storage quota
2. **Query Migration:** Teams must update dashboards to use new queries
3. **Validation Required:** Need production validation period to compare old vs. new metrics

### Neutral
1. **Backward Compatibility:** Both queries can run during validation period
2. **Middleware Overhead:** Negligible (single header addition + async event tracking)

## Validation Plan

1. Deploy to dev environment
2. Validate Age header presence: `curl -I https://api-dev.contoso.com/api/v1/compliance/status`
3. Query Application Insights: Verify `CacheHit`/`CacheMiss` events are logged
4. Compare metrics: Run both old and new queries side-by-side for 1 week
5. Validate alert accuracy: Trigger low cache hit rate scenario, verify alert fires
6. Deploy to staging → prod after validation

## Related Decisions

- **Issue #106:** Cache SLI monitoring setup (established 70% SLO)
- **PR #108:** Caching SLI implementation (duration-based inference)
- **Issue #115:** Explicit telemetry implementation (this decision)

## Team Impact

- **Picard (Lead):** Alert accuracy improves decision-making on cache performance
- **B'Elanna (Infrastructure):** Age header enables CDN/proxy cache troubleshooting
- **Seven (Research):** Explicit signals improve cache behavior analysis
- **Worf (Security):** No security implications (Age header is read-only)
- **Data (Code Expert):** Cleaner telemetry architecture for future monitoring

## Open Questions

None. Decision is final and implemented.

## Status

✅ **Implemented** — PR #117 opened, ready for review and deployment
