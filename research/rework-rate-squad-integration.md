# Rework Rate → bradygaster/squad Integration Proposal

> **Author:** Picard (Lead) | **Issue:** #473 | **Date:** 2026-03-14
> **Status:** Proposal — Ready for Review

---

## Executive Summary

This proposal details how to integrate "Rework Rate" — the emerging 5th DORA metric — into the [bradygaster/squad](https://github.com/bradygaster/squad) framework. After thorough analysis of the squad codebase, **the architecture is already well-positioned** for this integration:

- ✅ **Platform adapter pattern** already supports GitHub AND Azure DevOps
- ✅ **OpenTelemetry infrastructure** is production-ready with no-op fallbacks
- ✅ **PR data normalization** exists (`PullRequest` type with `reviewStatus`)
- ✅ **ADO adapter** already implements work items, PRs, branches, comments
- ⚠️ **Missing:** PR review history, iteration tracking, and rework-specific metrics

The integration requires extending the existing platform adapters with review/iteration data, adding a new rework metrics collector, and defining OTel gauges/histograms for rework measurement.

---

## 1. Codebase Analysis

### 1.1 Repository Structure

```
bradygaster/squad (v0.8.25)
├── packages/
│   ├── squad-sdk/          # Core runtime (TypeScript)
│   │   └── src/
│   │       ├── platform/   # ⭐ Platform adapters (GitHub, ADO, Planner)
│   │       ├── runtime/    # ⭐ OTel, metrics, event bus, telemetry
│   │       ├── adapter/    # Copilot SDK adapter layer
│   │       ├── agents/     # Agent charter compilation
│   │       ├── coordinator/# Agent coordination
│   │       ├── ralph/      # Ralph (work monitor) logic
│   │       └── ...
│   └── squad-cli/          # CLI tool
├── docs/                   # Documentation site
└── test/                   # Vitest test suite
```

### 1.2 Platform Adapter Pattern (Key Integration Point)

**Interface:** `packages/squad-sdk/src/platform/types.ts`

```typescript
export type PlatformType = 'github' | 'azure-devops' | 'planner';

export interface PullRequest {
  id: number;
  title: string;
  sourceBranch: string;
  targetBranch: string;
  status: 'active' | 'completed' | 'abandoned' | 'draft';
  reviewStatus?: 'approved' | 'changes-requested' | 'pending';
  author: string;
  url: string;
}

export interface PlatformAdapter {
  readonly type: PlatformType;
  listWorkItems(options): Promise<WorkItem[]>;
  listPullRequests(options): Promise<PullRequest[]>;
  createPullRequest(options): Promise<PullRequest>;
  mergePullRequest(id: number): Promise<void>;
  createBranch(name: string, fromBranch?: string): Promise<void>;
  // ... work item methods
}
```

**Implementations:**
| Adapter | File | CLI Backend | Status |
|---------|------|-------------|--------|
| `GitHubAdapter` | `platform/github.ts` | `gh` CLI | ✅ Complete |
| `AzureDevOpsAdapter` | `platform/azure-devops.ts` | `az` CLI | ✅ Complete |
| `PlannerAdapter` | `platform/planner.ts` | Microsoft Graph | ✅ Complete |

**Auto-detection:** `platform/detect.ts` reads git remote URL to auto-select adapter.

### 1.3 OpenTelemetry Infrastructure

The squad already has a sophisticated OTel setup:

| File | Purpose |
|------|---------|
| `runtime/otel-api.ts` | Resilient `@opentelemetry/api` wrapper with no-op fallbacks |
| `runtime/otel-init.ts` | Initialize OTel providers (Aspire Dashboard compatible) |
| `runtime/otel-metrics.ts` | Counters, histograms, gauges for tokens, agents, sessions, latency |
| `runtime/otel-bridge.ts` | EventBus → OTel span conversion |
| `runtime/otel.ts` | getMeter/getTracer factory functions |
| `runtime/telemetry.ts` | Internal telemetry event pipeline |

**Existing metric namespaces:**
- `squad.tokens.*` — Token usage (input, output, cost, total)
- `squad.agent.*` — Agent performance (spawns, duration, errors, active)
- `squad.sessions.*` — Session pool (active, idle, created, closed, errors)
- `squad.response.*` — Latency (TTFT, duration, tokens/sec)

### 1.4 ADO Support — Current State

**Already implemented:**
- ✅ Work item CRUD (WIQL queries, create, update, tag, comment)
- ✅ PR listing and creation
- ✅ Branch operations
- ✅ Review status mapping (ADO vote system → normalized status)
- ✅ Hybrid platform support (repo on GitHub, work items on ADO)
- ✅ Communication via ADO work item discussions

**Not yet implemented (needed for rework rate):**
- ❌ PR review history / iterations
- ❌ PR timeline events
- ❌ PR diff statistics per iteration
- ❌ Build/pipeline status correlation

---

## 2. Rework Rate Metric Definition

### 2.1 What is Rework Rate?

Rework Rate measures the percentage of code changes that require revision after initial submission. It captures:

1. **Review Cycles** — How many times a PR goes through review before approval
2. **Code Churn** — Lines changed after initial PR submission (pushes after first review)
3. **Rejection Rate** — Percentage of PRs that receive "changes requested"
4. **Rework Time** — Calendar time spent in rework (from first "changes requested" to final approval)
5. **AI Code Retention** — Percentage of AI-generated code that survives human review unchanged

### 2.2 Calculation Formula

```
Rework Rate = (Σ post-review changes) / (Σ total changes) × 100

Where:
  post-review changes = lines modified in commits AFTER first review
  total changes = all lines modified in the PR

Additional sub-metrics:
  Review Cycle Count = number of review → push → review loops
  Rejection Rate = PRs with ≥1 "changes requested" / total PRs × 100
  Rework Time = last_approval_timestamp - first_changes_requested_timestamp
  AI Retention Rate = (AI-generated lines surviving final merge) / (total AI-generated lines) × 100
```

---

## 3. Integration Design

### 3.1 Extend PlatformAdapter Interface

**File:** `packages/squad-sdk/src/platform/types.ts`

Add new types and methods:

```typescript
/** PR review event — normalized across platforms */
export interface PullRequestReview {
  id: string;
  author: string;
  state: 'approved' | 'changes-requested' | 'commented' | 'dismissed';
  timestamp: Date;
  body?: string;
}

/** PR iteration/push — represents a set of commits pushed to the PR */
export interface PullRequestIteration {
  id: number;
  /** Commit SHA at the head of this iteration */
  headCommit: string;
  /** When this iteration was pushed */
  timestamp: Date;
  /** Diff stats for this iteration */
  stats: {
    filesChanged: number;
    additions: number;
    deletions: number;
  };
}

/** Extended rework data for a PR */
export interface PullRequestReworkData {
  pr: PullRequest;
  reviews: PullRequestReview[];
  iterations: PullRequestIteration[];
  /** Number of review → push → review cycles */
  reviewCycles: number;
  /** Whether any review requested changes */
  hadChangesRequested: boolean;
  /** Time from first "changes-requested" to final approval (ms) */
  reworkTimeMs: number | null;
  /** Lines changed after first review / total lines changed */
  reworkRate: number;
}

// Extend PlatformAdapter interface:
export interface PlatformAdapter {
  // ... existing methods ...

  // Rework Rate data collection (optional — adapters can implement incrementally)
  getPullRequestReviews?(prId: number): Promise<PullRequestReview[]>;
  getPullRequestIterations?(prId: number): Promise<PullRequestIteration[]>;
}
```

### 3.2 GitHub Adapter Extensions

**File:** `packages/squad-sdk/src/platform/github.ts`

```typescript
// Add to GitHubAdapter class:

async getPullRequestReviews(prId: number): Promise<PullRequestReview[]> {
  const output = this.gh([
    'pr', 'view', String(prId), '--repo', this.repoFlag,
    '--json', 'reviews',
  ]);
  const data = parseJson<{
    reviews: Array<{
      id: string;
      author: { login: string };
      state: string;
      submittedAt: string;
      body: string;
    }>;
  }>(output);

  return data.reviews.map(r => ({
    id: r.id,
    author: r.author.login,
    state: mapGitHubReviewState(r.state),
    timestamp: new Date(r.submittedAt),
    body: r.body || undefined,
  }));
}

async getPullRequestIterations(prId: number): Promise<PullRequestIteration[]> {
  // GitHub doesn't have native "iterations" like ADO.
  // Use commit timeline on the PR as proxy.
  const output = this.gh([
    'pr', 'view', String(prId), '--repo', this.repoFlag,
    '--json', 'commits',
  ]);
  const data = parseJson<{
    commits: Array<{
      oid: string;
      committedDate: string;
      additions: number;
      deletions: number;
      changedFiles: number;
    }>;
  }>(output);

  return data.commits.map((c, i) => ({
    id: i + 1,
    headCommit: c.oid,
    timestamp: new Date(c.committedDate),
    stats: {
      filesChanged: c.changedFiles,
      additions: c.additions,
      deletions: c.deletions,
    },
  }));
}
```

**GitHub API endpoints used:**
- `GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews` — Review history
- `GET /repos/{owner}/{repo}/pulls/{pull_number}/commits` — Commit timeline
- `GET /repos/{owner}/{repo}/pulls/{pull_number}` — PR details with `additions`, `deletions`

### 3.3 Azure DevOps Adapter Extensions

**File:** `packages/squad-sdk/src/platform/azure-devops.ts`

```typescript
// Add to AzureDevOpsAdapter class:

async getPullRequestReviews(prId: number): Promise<PullRequestReview[]> {
  // ADO uses "threads" for PR reviews
  const output = this.az([
    'repos', 'pr', 'reviewer', 'list',
    '--id', String(prId),
    ...this.defaultArgs,
    '--output', 'json',
  ]);
  const reviewers = parseJson<Array<{
    id: string;
    displayName: string;
    vote: number;
    hasDeclined: boolean;
    isFlagged: boolean;
  }>>(output);

  return reviewers
    .filter(r => r.vote !== 0) // Filter out no-vote reviewers
    .map(r => ({
      id: r.id,
      author: r.displayName,
      state: mapAdoVoteToReviewState(r.vote),
      timestamp: new Date(), // ADO doesn't expose vote timestamp via CLI
      body: undefined,
    }));
}

async getPullRequestIterations(prId: number): Promise<PullRequestIteration[]> {
  // ADO has native iteration support!
  // API: GET /{org}/{project}/_apis/git/repositories/{repo}/pullRequests/{prId}/iterations
  // Via az CLI, we need REST API call:
  const apiUrl = `${this.orgUrl}/${this.project}/_apis/git/repositories/${this.repo}/pullRequests/${prId}/iterations?api-version=7.1`;
  const output = this.az([
    'rest', '--method', 'GET', '--url', apiUrl, '--output', 'json',
  ]);
  const data = parseJson<{
    value: Array<{
      id: number;
      sourceRefCommit: { commitId: string };
      createdDate: string;
      changeList: Array<{
        changeType: string;
      }>;
    }>;
  }>(output);

  return data.value.map(iter => ({
    id: iter.id,
    headCommit: iter.sourceRefCommit.commitId,
    timestamp: new Date(iter.createdDate),
    stats: {
      filesChanged: iter.changeList?.length ?? 0,
      additions: 0, // Would need diff stats API call
      deletions: 0,
    },
  }));
}
```

**ADO API endpoints used:**
- `GET /{org}/{project}/_apis/git/repositories/{repo}/pullRequests/{prId}/iterations` — Native iteration support ⭐
- `GET /{org}/{project}/_apis/git/repositories/{repo}/pullRequests/{prId}/threads` — Review comments/threads
- `GET /{org}/{project}/_apis/git/repositories/{repo}/pullRequests/{prId}/reviewers` — Reviewer votes
- `GET /{org}/{project}/_apis/git/repositories/{repo}/pullRequests/{prId}/iterations/{iterationId}/changes` — Per-iteration diff stats

> **ADO Advantage:** Azure DevOps has first-class "iteration" support on PRs, making rework tracking more precise than GitHub's commit-based approach.

### 3.4 Rework Rate Collector

**New file:** `packages/squad-sdk/src/runtime/rework-collector.ts`

```typescript
/**
 * Rework Rate Collector — aggregates PR data into rework metrics.
 *
 * @module runtime/rework-collector
 */

import type { PlatformAdapter, PullRequest, PullRequestReview, PullRequestIteration, PullRequestReworkData } from '../platform/types.js';
import { recordReworkMetrics } from './otel-metrics.js';

export interface ReworkCollectorOptions {
  /** Only analyze PRs merged in the last N days (default: 30) */
  lookbackDays?: number;
  /** Minimum PR size to include (lines changed, default: 10) */
  minPrSize?: number;
  /** Whether to track AI-generated code separately */
  trackAiRetention?: boolean;
}

export class ReworkCollector {
  constructor(
    private readonly adapter: PlatformAdapter,
    private readonly options: ReworkCollectorOptions = {},
  ) {}

  /**
   * Collect rework data for recent merged PRs.
   */
  async collectReworkData(): Promise<PullRequestReworkData[]> {
    const prs = await this.adapter.listPullRequests({
      status: 'completed',
      limit: this.options.lookbackDays ? 100 : 50,
    });

    const results: PullRequestReworkData[] = [];

    for (const pr of prs) {
      if (!this.adapter.getPullRequestReviews || !this.adapter.getPullRequestIterations) {
        continue; // Adapter doesn't support rework data
      }

      const [reviews, iterations] = await Promise.all([
        this.adapter.getPullRequestReviews(pr.id),
        this.adapter.getPullRequestIterations(pr.id),
      ]);

      const reworkData = this.calculateReworkData(pr, reviews, iterations);
      results.push(reworkData);

      // Emit OTel metrics
      recordReworkMetrics(reworkData);
    }

    return results;
  }

  private calculateReworkData(
    pr: PullRequest,
    reviews: PullRequestReview[],
    iterations: PullRequestIteration[],
  ): PullRequestReworkData {
    // Sort by timestamp
    const sortedReviews = [...reviews].sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());
    const sortedIterations = [...iterations].sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());

    // Find first review timestamp
    const firstReview = sortedReviews[0];
    const firstChangesRequested = sortedReviews.find(r => r.state === 'changes-requested');
    const lastApproval = [...sortedReviews].reverse().find(r => r.state === 'approved');

    // Count review cycles: sequences of changes-requested → new iteration → review
    let reviewCycles = 0;
    let lastChangeRequest: Date | null = null;
    for (const review of sortedReviews) {
      if (review.state === 'changes-requested') {
        lastChangeRequest = review.timestamp;
      } else if (review.state === 'approved' && lastChangeRequest) {
        reviewCycles++;
        lastChangeRequest = null;
      }
    }

    // Calculate rework rate: iterations after first review / total iterations
    const postReviewIterations = firstReview
      ? sortedIterations.filter(i => i.timestamp > firstReview.timestamp)
      : [];
    const postReviewChanges = postReviewIterations.reduce(
      (sum, i) => sum + i.stats.additions + i.stats.deletions, 0,
    );
    const totalChanges = sortedIterations.reduce(
      (sum, i) => sum + i.stats.additions + i.stats.deletions, 0,
    );
    const reworkRate = totalChanges > 0 ? postReviewChanges / totalChanges : 0;

    // Rework time
    const reworkTimeMs = (firstChangesRequested && lastApproval)
      ? lastApproval.timestamp.getTime() - firstChangesRequested.timestamp.getTime()
      : null;

    return {
      pr,
      reviews: sortedReviews,
      iterations: sortedIterations,
      reviewCycles,
      hadChangesRequested: !!firstChangesRequested,
      reworkTimeMs,
      reworkRate,
    };
  }
}
```

### 3.5 OTel Metrics for Rework Rate

**File:** `packages/squad-sdk/src/runtime/otel-metrics.ts` (extend existing)

```typescript
// ============================================================================
// #NEW — Rework Rate Metrics (5th DORA metric)
// ============================================================================

interface ReworkMetrics {
  reworkRateGauge: ReturnType<ReturnType<typeof getMeter>['createGauge']>;
  reviewCyclesHistogram: ReturnType<ReturnType<typeof getMeter>['createHistogram']>;
  reworkTimeHistogram: ReturnType<ReturnType<typeof getMeter>['createHistogram']>;
  changesRequestedCounter: ReturnType<ReturnType<typeof getMeter>['createCounter']>;
  prsAnalyzedCounter: ReturnType<ReturnType<typeof getMeter>['createCounter']>;
}

let _reworkMetrics: ReworkMetrics | undefined;

function ensureReworkMetrics(): ReworkMetrics {
  if (!_reworkMetrics) {
    const meter = getMeter('squad-sdk');
    _reworkMetrics = {
      reworkRateGauge: meter.createGauge('squad.rework.rate', {
        description: 'Percentage of code changes requiring rework after review',
        unit: '%',
      }),
      reviewCyclesHistogram: meter.createHistogram('squad.rework.review_cycles', {
        description: 'Number of review cycles per PR',
      }),
      reworkTimeHistogram: meter.createHistogram('squad.rework.time', {
        description: 'Time spent in rework (ms)',
        unit: 'ms',
      }),
      changesRequestedCounter: meter.createCounter('squad.rework.changes_requested', {
        description: 'Total PRs that received changes-requested reviews',
      }),
      prsAnalyzedCounter: meter.createCounter('squad.rework.prs_analyzed', {
        description: 'Total PRs analyzed for rework metrics',
      }),
    };
  }
  return _reworkMetrics;
}

/** Record rework metrics for a single PR. */
export function recordReworkMetrics(data: PullRequestReworkData): void {
  const m = ensureReworkMetrics();
  const attrs = {
    'pr.author': data.pr.author,
    'platform': data.pr.url.includes('github.com') ? 'github' : 'azure-devops',
  };

  m.reworkRateGauge.record(data.reworkRate * 100, attrs);
  m.reviewCyclesHistogram.record(data.reviewCycles, attrs);
  m.prsAnalyzedCounter.add(1, attrs);

  if (data.hadChangesRequested) {
    m.changesRequestedCounter.add(1, attrs);
  }
  if (data.reworkTimeMs !== null) {
    m.reworkTimeHistogram.record(data.reworkTimeMs, attrs);
  }
}
```

---

## 4. ADO-Specific Support Plan

### 4.1 ADO API Endpoints Required

| Endpoint | Purpose | Auth Required |
|----------|---------|---------------|
| `GET _apis/git/pullRequests/{id}/iterations` | PR push cycles (native!) | PAT or OAuth |
| `GET _apis/git/pullRequests/{id}/iterations/{id}/changes` | Per-iteration diff stats | PAT or OAuth |
| `GET _apis/git/pullRequests/{id}/threads` | Review comments & status | PAT or OAuth |
| `GET _apis/git/pullRequests/{id}/reviewers` | Reviewer votes | PAT or OAuth |
| `GET _apis/git/pullRequests/{id}/statuses` | Build/CI status | PAT or OAuth |
| `GET _apis/build/builds` | Pipeline run results | PAT or OAuth |

### 4.2 ADO vs GitHub — Rework Detection Differences

| Aspect | GitHub | Azure DevOps |
|--------|--------|--------------|
| PR iterations | No native support; use commit timeline | ✅ First-class `iterations` API |
| Review tracking | `reviews` endpoint with state | `reviewers` with vote (-10 to +10) |
| Diff per iteration | Must diff between commit SHAs | ✅ `iterations/{id}/changes` API |
| Build correlation | Check runs / status checks | Pipeline builds with stages |
| Timeline events | Timeline API (limited) | ✅ Rich thread timeline |

### 4.3 Authentication & Configuration

**Current state:** The `AzureDevOpsAdapter` uses `az` CLI which inherits auth from `az login`. For rework rate data that requires REST API calls beyond what `az boards` and `az repos` support, we need:

```typescript
// In squad.config.ts — extend platform config:
export default defineSquad({
  platform: {
    type: 'azure-devops',
    // Existing:
    org: 'my-org',
    project: 'my-project',
    // New for rework rate:
    reworkRate: {
      enabled: true,
      lookbackDays: 30,
      collectOnSessionStart: false,
      collectOnSchedule: '0 9 * * 1', // Every Monday at 9am
    },
  },
});
```

### 4.4 ADO Pipeline Integration

For tracking rework in CI/CD context:

```typescript
// Detect if running inside Azure Pipelines
const isAdoPipeline = !!process.env.BUILD_BUILDID;
const prId = process.env.SYSTEM_PULLREQUEST_PULLREQUESTID;
const buildReason = process.env.BUILD_REASON; // 'PullRequest', 'IndividualCI', etc.

// In ADO pipelines, we can correlate:
// 1. Build failures after PR push → likely rework trigger
// 2. Number of pipeline runs per PR → rework signal
// 3. Build validation pass/fail rate → quality signal
```

---

## 5. Dashboard & Reporting Integration

### 5.1 Aspire Dashboard (Existing)

Squad already supports the .NET Aspire Dashboard for OTel visualization. Rework metrics would automatically appear when using:

```bash
squad run --otel-endpoint http://localhost:4318
```

### 5.2 Proposed Dashboard Views

1. **Rework Rate Over Time** — Line chart of `squad.rework.rate` gauge per week
2. **Review Cycles Distribution** — Histogram of `squad.rework.review_cycles`
3. **Rework Time Heatmap** — Time-of-day vs rework duration
4. **Platform Comparison** — GitHub vs ADO rework rates side-by-side
5. **Per-Author Analysis** — Rework rate by PR author (for coaching, not shaming)
6. **AI Retention Rate** — How much AI-generated code survives review

### 5.3 Ralph Integration

Ralph (the work monitor) could periodically collect rework metrics:

```typescript
// In ralph's scan cycle, add rework collection:
const collector = new ReworkCollector(platformAdapter, {
  lookbackDays: 7,
  trackAiRetention: true,
});
const reworkData = await collector.collectReworkData();

// Post summary to comms channel
await commsAdapter.postUpdate({
  title: '📊 Weekly Rework Rate Report',
  body: formatReworkReport(reworkData),
  category: 'metrics',
  author: 'ralph',
});
```

---

## 6. Implementation Phases

### Phase 1: Core Types & GitHub Support (Week 1-2)

**Tasks:**
1. [ ] Add `PullRequestReview`, `PullRequestIteration`, `PullRequestReworkData` types to `platform/types.ts`
2. [ ] Add optional `getPullRequestReviews()` and `getPullRequestIterations()` to `PlatformAdapter` interface
3. [ ] Implement in `GitHubAdapter` using `gh pr view --json reviews,commits`
4. [ ] Create `runtime/rework-collector.ts` with `ReworkCollector` class
5. [ ] Add rework OTel metrics to `runtime/otel-metrics.ts`
6. [ ] Unit tests for rework calculation logic

**GitHub Issues to create on bradygaster/squad:**
- `feat(platform): Add PR review history to PlatformAdapter`
- `feat(metrics): Add Rework Rate OTel metrics (5th DORA metric)`
- `feat(runtime): Add ReworkCollector for PR rework analysis`

### Phase 2: Azure DevOps Support (Week 2-3)

**Tasks:**
1. [ ] Implement `getPullRequestReviews()` in `AzureDevOpsAdapter` using reviewer votes
2. [ ] Implement `getPullRequestIterations()` using ADO's native iterations API
3. [ ] Add `az rest` calls for iteration diff stats
4. [ ] Handle ADO vote system mapping (-10 to +10 → normalized review states)
5. [ ] Integration tests with ADO test org
6. [ ] ADO Pipeline environment variable detection

**GitHub Issues to create on bradygaster/squad:**
- `feat(platform/ado): Implement PR review history for Azure DevOps`
- `feat(platform/ado): Leverage ADO native PR iterations API`
- `docs: ADO rework rate setup guide`

### Phase 3: AI Code Retention Tracking (Week 3-4)

**Tasks:**
1. [ ] Detect AI-generated commits (Copilot commit message patterns, `.copilot` metadata)
2. [ ] Track which lines were AI-generated vs human-written
3. [ ] Calculate retention rate: AI lines surviving merge / total AI lines
4. [ ] Add `squad.rework.ai_retention_rate` gauge
5. [ ] Ralph weekly report integration

**GitHub Issues to create on bradygaster/squad:**
- `feat(metrics): Track AI code retention rate`
- `feat(ralph): Weekly rework rate reporting`

### Phase 4: Dashboard & Polish (Week 4-5)

**Tasks:**
1. [ ] Aspire Dashboard custom views for rework metrics
2. [ ] `squad rework-report` CLI command
3. [ ] Documentation: setup guide, interpretation guide
4. [ ] Cross-platform comparison mode (GitHub vs ADO)
5. [ ] Performance optimization for large repos (pagination, caching)

---

## 7. File Change Summary

| File | Action | Description |
|------|--------|-------------|
| `packages/squad-sdk/src/platform/types.ts` | MODIFY | Add `PullRequestReview`, `PullRequestIteration`, `PullRequestReworkData` types; extend `PlatformAdapter` |
| `packages/squad-sdk/src/platform/github.ts` | MODIFY | Add `getPullRequestReviews()`, `getPullRequestIterations()` |
| `packages/squad-sdk/src/platform/azure-devops.ts` | MODIFY | Add review/iteration methods using ADO REST API |
| `packages/squad-sdk/src/runtime/rework-collector.ts` | CREATE | New rework data aggregation module |
| `packages/squad-sdk/src/runtime/otel-metrics.ts` | MODIFY | Add rework rate gauges, histograms, counters |
| `packages/squad-sdk/src/platform/index.ts` | MODIFY | Export new types |
| `packages/squad-sdk/src/index.ts` | MODIFY | Export `ReworkCollector` |
| `test/rework-collector.test.ts` | CREATE | Unit tests for rework calculation |
| `test/platform/github-rework.test.ts` | CREATE | GitHub adapter rework tests |
| `test/platform/ado-rework.test.ts` | CREATE | ADO adapter rework tests |
| `docs/src/content/docs/scenarios/rework-rate.md` | CREATE | Setup & interpretation guide |

---

## 8. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| GitHub API rate limiting for review data | Medium | Batch requests, cache results, respect `X-RateLimit` headers |
| ADO PAT token expiry | Low | Document token refresh, support managed identity |
| Large repos with 1000+ PRs | Medium | Pagination, configurable lookback window, incremental collection |
| Privacy concerns (per-author metrics) | High | Make per-author data opt-in, default to team aggregates only |
| No ADO CLI support for iterations API | Low | Already solved: use `az rest` for direct REST calls |

---

## 9. Success Criteria

1. ✅ Rework rate calculation works for both GitHub and Azure DevOps PRs
2. ✅ OTel metrics emit to Aspire Dashboard correctly
3. ✅ Ralph can generate weekly rework reports
4. ✅ Less than 5 seconds overhead per squad session start
5. ✅ Works with existing `createPlatformAdapter()` auto-detection
6. ✅ Graceful degradation when review history is unavailable
7. ✅ All new code has ≥80% test coverage

---

## Appendix A: ADO REST API Examples

```bash
# List PR iterations (native rework tracking!)
az rest --method GET \
  --url "https://dev.azure.com/{org}/{project}/_apis/git/repositories/{repo}/pullRequests/{prId}/iterations?api-version=7.1"

# Get iteration changes (diff stats per push)
az rest --method GET \
  --url "https://dev.azure.com/{org}/{project}/_apis/git/repositories/{repo}/pullRequests/{prId}/iterations/{iterationId}/changes?api-version=7.1"

# List PR threads (review discussions)
az rest --method GET \
  --url "https://dev.azure.com/{org}/{project}/_apis/git/repositories/{repo}/pullRequests/{prId}/threads?api-version=7.1"
```

## Appendix B: GitHub GraphQL Alternative

```graphql
query PRReviewHistory($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviews(first: 100) {
        nodes {
          author { login }
          state
          submittedAt
          body
        }
      }
      commits(first: 250) {
        nodes {
          commit {
            oid
            committedDate
            additions
            deletions
            changedFiles
          }
        }
      }
      timelineItems(first: 100, itemTypes: [PULL_REQUEST_REVIEW, HEAD_REF_FORCE_PUSHED_EVENT, REVIEW_REQUESTED_EVENT]) {
        nodes {
          __typename
          ... on PullRequestReview {
            state
            submittedAt
          }
        }
      }
    }
  }
}
```
