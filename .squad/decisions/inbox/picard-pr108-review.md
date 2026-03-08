# Decision: FedRAMP Dashboard Cache Monitoring — PR #108 Review

**Date:** 2026-03-12  
**Decision Maker:** Picard (Lead)  
**Context:** Issue #106 → PR #108 by Data  
**Status:** Approved & Merged

---

## Problem Statement

PR #102 (FedRAMP Dashboard API Security & Resilience Hardening) introduced HTTP response caching (60s TTL for status, 300s for trend endpoints) to reduce backend load and improve latency. Post-merge requirements (Issue #106) required:
1. Cache configuration documented as production SLI
2. Application Insights alert for low cache hit rate (<70%)
3. Remediation playbook for on-call engineers
4. Monthly review process to track cache effectiveness

Without these, cache performance would silently degrade over time without visibility or accountability.

---

## Solution Delivered (PR #108)

Data delivered comprehensive monitoring and operational processes:

### 1. SLI Documentation (docs/fedramp-dashboard-cache-sli.md, 434 lines)
- **Cache Configuration:** 60s TTL (status), 300s TTL (trend), in-memory per-instance
- **SLO Target:** Cache hit rate ≥ 70% (24-hour rolling window)
- **Expected Performance:** 80-85% hit rate typical, 80-85% query reduction, 20-30% latency improvement
- **Measurement:** Application Insights telemetry with Kusto queries
- **Thresholds:** Green (≥75%), Yellow (70-74%), Red (<70%)

### 2. Application Insights Alert (infrastructure/phase4-cache-alert.bicep)
- **Trigger Condition:** Cache hit rate < 70% for 15 minutes
- **Severity:** 2 (Warning)
- **Evaluation:** Every 5 minutes
- **Query Logic:** `duration < 100ms` as cache hit indicator (pragmatic heuristic for v1)
- **Action:** Routes to PagerDuty via Action Group, includes runbook link in alert properties

### 3. Deployment Automation (infrastructure/deploy-cache-alert.ps1)
- PowerShell script with environment validation (dev/stg/stg-gov/ppe/prod)
- Bicep template validation before deployment
- Post-deployment verification (alert enabled check)
- Environment-aware parameters (appInsightsName, actionGroupName)

### 4. Remediation Playbook (Section 4.2 in SLI doc)
**Immediate Actions (5 min):**
- Check recent deployments (pod restarts → cache warming in progress)
- Analyze request patterns (high diversity → expected fragmentation)

**Investigation (15 min):**
- Review access logs (identify bot/scraper traffic)
- Check cache TTL effectiveness (avg time between repeat requests)

**Resolution Paths:**
| Root Cause | Resolution | Timeline |
|------------|------------|----------|
| Pod restart | Wait for cache warm-up | 15-30 min (automatic) |
| Request diversity | Adjust VaryBy keys or cache size | 1 hour (code change) |
| Short TTL | Increase cache duration to 90-120s | 30 min (config change) |
| Traffic spike | Scale out API instances (HPA) | 5 min (automatic) |
| Cache bug | Review logs, hotfix if needed | 2 hours (code fix) |

### 5. Monthly Review Process
- **Schedule:** First Tuesday of each month, 10 AM PT
- **Template:** docs/fedramp/cache-reviews/template.md (233 lines)
- **Metrics Tracked:** Hit rate, latency (P95/P99), query reduction, RU savings, access patterns
- **Outcomes:** Action items, recommendations, next review date
- **Historical Archive:** docs/fedramp/cache-reviews/YYYY-MM.md

### 6. Operational Runbook Integration
- Added Section 2.4 to deployment-runbook.md
- Checklist: SLI review, alert deployment, monthly review scheduling, team training

---

## Review Assessment

### Technical Quality (9.5/10)

**Strengths:**
1. **SLI Definition:** Clear, measurable, realistic targets based on expected workload
2. **Bicep Template:** Syntax valid (az bicep build passed), query logic sound, alert configuration appropriate
3. **Remediation Playbook:** Actionable 5-min and 15-min procedures, maps symptoms to fixes with timelines
4. **Operational Integration:** Monthly reviews create accountability, deployment runbook updated

**Minor Notes:**
- Cache hit detection via latency (<100ms) is pragmatic but imprecise. Future iteration: instrument explicit cache telemetry (Age header or custom dimension).
- Remediation playbook correctly identifies pod restarts as normal behavior (15-30 min cache warming expected).
- Review template includes RU savings calculation for cost visibility.

### Documentation Completeness

- **Configuration:** Cache TTL by endpoint, VaryBy keys, storage (in-memory, per-instance)
- **SLO:** Target, measurement window, calculation methodology, thresholds
- **Monitoring:** Kusto queries, dashboard visualization, telemetry strategy
- **Alerting:** Alert name, condition, frequency, severity, action group
- **Remediation:** Immediate actions, investigation steps, resolution paths
- **Reviews:** Schedule, template, metrics, historical archive
- **Future:** Event-driven invalidation, Redis migration, cache versioning (Section 7)

---

## Decision

**APPROVED & MERGED**

**Rationale:**
1. **Completeness:** Addresses all Issue #106 requirements (SLI, alert, playbook, reviews)
2. **Quality:** Production-grade documentation, validated Bicep template, actionable playbook
3. **Operational Readiness:** Deployment automation, post-deployment verification, team training checklist
4. **Future-Proofing:** Section 7 outlines enhancement path if cache effectiveness degrades

**Post-Merge Actions:**
1. Deploy cache alert to all environments (dev → stg → prod)
2. Schedule April 2026 cache review (recurring monthly)
3. Validate alert triggers correctly (optional: synthetic low hit rate test)

---

## Pattern Recognition

### Monitoring Completeness Prevents Silent Degradation

Without SLI/SLO and alerting, cache would silently degrade over time:
- Cache hit rate drops from 85% → 60% → 40% over weeks
- No alert fires because no alert exists
- User experience degrades (latency increases)
- Backend query load increases (Cosmos DB RU cost escalates)
- Team discovers problem only during incident review

**This PR prevents that scenario.**

### Remediation Playbooks Enable Self-Service

On-call engineers can resolve cache incidents without escalating to code experts:
- Playbook provides clear decision tree (check restarts → analyze patterns → adjust TTL)
- Resolution paths include timelines (5 min, 15 min, 1 hour, 2 hours)
- Root cause table maps symptoms to fixes

**Reduces MTTR and team cognitive load.**

### Monthly Reviews Create Accountability

Scheduled reviews force retrospective analysis, not just reactive incident response:
- Review template tracks: hit rate, latency, query reduction, RU savings, access patterns
- Action items assigned with owners and due dates
- Historical archive enables trend analysis (cache effectiveness over time)

**Continuous improvement mechanism beyond incident-driven fixes.**

---

## Cross-Agent Context

### End-to-End Ownership Model

Data delivered:
1. **PR #102:** Cache implementation (code)
2. **PR #108:** Monitoring and operational processes (SLI, alert, playbook, reviews)

This demonstrates **full lifecycle ownership**: code + monitoring + documentation + operational processes. Not just "ship code and move on."

### Effective Follow-Through

Issue #106 was created by Picard during PR #102 review as post-merge action items. This demonstrates:
1. Review feedback captured as tracked work (Issue #106)
2. Agent assigned to execute (Data)
3. Solution delivered (PR #108)
4. Review closed the loop (PR #108 approved & merged)

**Issue → PR → Review → Merge → Outcome** cycle completed successfully.

---

## Team Standard

**Cache monitoring pattern established:**

When introducing caching in production APIs:
1. Document cache configuration as SLI (TTL, expected performance, SLO)
2. Configure Application Insights alert for low hit rate
3. Provide remediation playbook with clear decision tree
4. Schedule monthly reviews to track effectiveness and cost savings
5. Plan future enhancements (event-driven invalidation, distributed cache)

**Apply this pattern to all future cache implementations.**

---

**Decision recorded by:** Picard (Lead)  
**Review rating:** 9.5/10  
**Status:** Approved & Merged (PR #108)  
**Related:** Issue #106, PR #102
