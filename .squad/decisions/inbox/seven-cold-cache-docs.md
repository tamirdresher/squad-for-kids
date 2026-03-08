# Decision Memo: Cold-Cache Alert Documentation for FedRAMP Dashboard

**Date:** 2026-03-13  
**Author:** Seven (Research & Docs)  
**Issue:** #134  
**PR:** #138  
**Status:** ✅ MERGED  

## Problem Statement

When the FedRAMP Dashboard is first deployed to a new environment (especially during migration from tamresearch1 to dedicated repo), the in-memory cache starts empty. This causes:
- 0% cache hit rate immediately post-deployment
- Alert fires 15–30 minutes later (< 70% hit rate for 15 minutes)
- On-call team receives alert with no context
- False escalation + confusion ("Is this a problem?")

**Root cause:** Expected behavior, not a bug. But undocumented, causing operational confusion.

## Solution

Updated two key documents with clear guidance:

### 1. Cache SLI Runbook (`docs/fedramp-dashboard-cache-sli.md`)

**Section 4.2 — Remediation Playbook (updated)**
- Added prominent warning at top: "EXPECTED ON FIRST DEPLOYMENT"
- Clarified: "This is normal behavior and does not indicate a problem"
- Added step: "If this is the first deployment to this environment: Expected cold-cache alert"

**New Section 6.2 — Cache Warm-Up Procedure**
- **Option A (Automated):** Bash script runs post-API-deployment, primes cache with 18 standard queries
- **Option B (Manual):** PowerShell script for operators if alerts fire anyway
- **Monitoring:** PowerShell script queries Application Insights every 60 seconds, reports progress
- Timeline: ~5 minutes to warm; 15–30 minutes to return to 75%+ hit rate

### 2. Migration Plan (`docs/fedramp-migration-plan.md`)

**Phase 3 — Infrastructure Validation (updated)**
- Added "⚠️ Expected Alerts During First Deployment" callout box
- Listed what will happen: Alert fires 15–30 minutes post-deployment
- Reason: "In-memory cache is empty; hit rate drops below 70% threshold"
- Action: "Monitor cache warm-up progress; **do not panic or escalate** this alert on first deployment"
- Reference: Cross-linked to cache-sli.md § 4.2 and § 6.2

## Implementation Details

**Deployment scenario trigger:** First deployment to new environment (DEV/STG/PROD/sovereign)

**Timeline:**
- T+0: API deployed, cache empty
- T+5min: First requests start hitting cache
- T+15min: Alert threshold met (< 70% hit rate × 15 min window) → alert fires
- T+15–30min: Cache warms with normal traffic
- T+30min: Hit rate returns to 75%+, alert clears

**Warm-up options:**
- **Recommended:** Include `scripts/warmup-cache.sh` in deployment pipeline post-API-deployment
  - 18 requests × 0.5s delay = ~9 seconds total
  - Cache hits optimal state before normal traffic arrives
  - Alert may not fire at all

- **Fallback:** Manual warm-up via `scripts/manual-warmup.ps1` if alert fires
  - On-call team runs after receiving alert
  - Same 18 requests, operator initiates manually
  - Cache warm-up proceeds, alert clears within 15–30 minutes

## Decision: Architecture Insight on Cache Strategy

**Current design:** Per-instance in-memory cache (ASP.NET Core `IMemoryCache`)
- ✅ Pro: No distributed cache complexity, fast (<50ms hit), <50MB memory
- ❌ Con: Cold starts on deployment, no cross-instance cache sharing
- **Trade-off accepted** for v1 because: low-traffic dashboard, migration timeline critical

**Future consideration (v2.0):** Distributed cache (Redis) if:
- Cache hit rate drops below 60% consistently, OR
- Multi-instance deployments needed, OR
- Cache stale data incidents occur

**Until then:** Cold-cache alert is expected behavior, documented, and handled operationally.

## Why This Matters

**For on-call team:**
- Alerts + runbook = confidence ("I understand why this is happening")
- Clear timeline = no false escalations ("Wait 30 min, then re-evaluate")
- Warm-up option = proactive action ("I can speed this up")
- Result: Smooth first deployment experience

**For SRE/DevOps:**
- Deployment playbook now includes cache warm-up decision point
- Can choose automated (CI/CD integration) or manual (on-call decision)
- Reduces support ticket noise during migration

**For architecture team:**
- Documents the known limitation (per-instance cache)
- Records future enhancement path (distributed cache)
- Provides decision history for v2.0 planning

## Acceptance Criteria (Issue #134) — ALL MET

- [x] Runbook updated with cold-cache expectation (cache-sli.md § 4.2)
- [x] Migration plan references expected alert (migration-plan.md Phase 3)
- [x] Team knows to expect (and not panic about) initial alert
- [x] Cache warm-up steps documented (automated + manual options, monitoring)

## Related Issues & PRs

- **#131 (PR review):** Data's original comment requesting this documentation
- **#106:** Cache Hit Rate Alert (infrastructure)
- **#113:** Cache Alert Deployment Guide
- **#127:** FedRAMP Migration Plan
- **PR #138:** This documentation PR (merged)

## Key Learning

**When expected infrastructure behavior confuses the team, it's a documentation gap—not a design flaw.**

Cold cache on first deployment is normal. The team didn't need better monitoring or different code; they needed:
1. **Context:** "This is expected"
2. **Timeline:** "It will resolve in X minutes"
3. **Monitoring:** "Here's how to track progress"
4. **Agency:** "Here's what you can do to help"

This pattern applies broadly: ephemeral pod restarts, database schema migrations, slow builds, etc. When expected behavior triggers alerts, document it prominently in the runbook.

---

**Document Created:** 2026-03-13T23:45:00Z  
**Status:** Merged to main  
**Next Review:** After first deployment to production (confirm timeline, update if needed)
