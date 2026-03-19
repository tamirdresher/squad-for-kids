# Adaptive Rate Limit Strategies for Multi-Agent AI Systems

**Research Report — Squad Framework**  
**Date:** March 2026  
**Author:** Seven (Research & Docs Agent)  
**Issue:** #979  
**Status:** Final

---

## Executive Summary

The Squad framework runs multiple AI agents in parallel (Picard, Ralph, Data, Seven, Belanna, etc.), each making concurrent calls to Claude/Anthropic, GitHub, and Azure/OpenAI APIs. Without coordinated rate limiting, agents compete for a shared API quota, causing cascading 429 failures, degraded throughput, and unpredictable task delays.

This report synthesizes current state-of-the-art approaches (2024–2026) and translates them into a concrete recommended strategy for Squad. The core recommendation is a **centralized token-bucket governor with priority-weighted queuing and adaptive backoff** — a pattern proven in production multi-agent systems and well-matched to Squad's architecture.

**Key findings at a glance:**

| Problem | Recommended Solution |
|---|---|
| Shared API quota starvation | Centralized rate governor (shared pool model) |
| 429 retry storms | Exponential backoff with jitter + Retry-After header |
| Unequal agent priority | Priority-weighted queue (Picard > Data/Seven > Ralph) |
| Token quota exhaustion (Claude) | Token-aware budgeting per agent turn |
| GitHub 5000/hr exhaustion | Conditional requests + webhook-first, polling-last |
| Azure/OpenAI burst throttling | Even-paced submission via queue, not concurrent flood |

---

## 1. Current State-of-the-Art: Rate Limiting in Multi-Agent Systems

### 1.1 The Core Challenge

Multi-agent systems face a fundamentally different rate limiting problem than single-service applications. When 8–12 agents fire simultaneously — each requesting Claude completions, listing GitHub PRs, and querying Azure APIs — the cumulative burst can exceed API limits within seconds. The traditional per-service backoff fails because:

- **No coordination:** Each agent backs off independently, resetting its own timer, so they re-collide after the backoff window
- **Thundering herd:** After a 429, all agents retry at the same time if they use the same base delay
- **No prioritization:** An idle background agent (Ralph polling for work) can consume quota needed by Picard executing a critical architectural decision

### 1.2 Algorithm Landscape

**Token Bucket**
- Tokens accrue at a steady rate (e.g., 50 tokens/minute for Claude Tier 1 RPM)
- Bursts are allowed up to bucket capacity; excess requests block until tokens are available
- ✅ Best for: smoothing bursty AI agent traffic while allowing short bursts
- ⚠️ Weakness: doesn't account for variable request cost (a large Claude completion consumes far more than a small one)

**Leaky Bucket**
- Requests drain from a queue at a fixed rate regardless of arrival pattern
- ✅ Best for: enforcing a perfectly even outflow (useful for GitHub secondary rate limits)
- ⚠️ Weakness: adds latency even when quota is available; bad for interactive agents

**Sliding Window**
- Tracks all requests within a rolling time window (e.g., last 60 seconds)
- ✅ Best for: accurately modeling API-side enforcement (most modern APIs use this internally)
- ⚠️ Weakness: higher memory overhead at scale; harder to implement across distributed agents

**Adaptive / ML-Driven (Emerging)**
- Deep reinforcement learning (DQN + A3C hybrid) monitors real-time API feedback and adjusts throttling thresholds dynamically
- Research demonstrates 15–30% throughput improvements over static algorithms in high-traffic scenarios
- ⚠️ Weakness: significant implementation complexity; requires training data and monitoring infrastructure

**Recommendation for Squad:** Hybrid token bucket (for RPM/TPM tracking) + sliding window (for burst detection) + priority queue, with adaptive backoff on 429 signals. This covers 95% of production scenarios without ML complexity.

---

## 2. Token Bucket vs. Leaky Bucket vs. Sliding Window: Decision Matrix

| Criterion | Token Bucket | Leaky Bucket | Sliding Window |
|---|---|---|---|
| Burst tolerance | ✅ Yes | ❌ No | ⚠️ Limited |
| Fairness across agents | ⚠️ Manual | ✅ Natural | ⚠️ Manual |
| Variable request cost | ⚠️ With TPM variant | ❌ Request-count only | ✅ Configurable |
| Implementation simplicity | ✅ Simple | ✅ Simple | ⚠️ Moderate |
| Matches Anthropic's algorithm | ✅ Yes (they use token bucket) | ❌ No | ⚠️ Approximation |
| Distributed support | ✅ Redis-ready | ✅ Redis-ready | ✅ Redis-ready |

**Winner for Squad's use case:** Token bucket, with TPM-aware cost accounting. Anthropic explicitly uses token bucket internally, so modeling the same algorithm client-side gives the most accurate pre-flight quota estimation.

---

## 3. Per-Agent vs. Shared Pool Rate Limiting

### 3.1 Per-Agent Model
Each agent gets its own rate limit budget (e.g., Picard gets 20 RPM, Ralph gets 10 RPM).

**Pros:**
- Blast radius isolation: one misbehaving agent can't starve others
- Simple to reason about
- Easy to audit which agent is consuming what

**Cons:**
- Inefficient: Ralph's unused quota doesn't help Picard when it needs a burst
- Requires quota forecasting per agent type — difficult when workloads vary
- Doesn't match API reality (Anthropic enforces org-level limits, not per-key)

### 3.2 Shared Pool Model
All agents draw from a single org-level pool (accurately mirroring Anthropic/GitHub/Azure enforcement).

**Pros:**
- Maximum throughput: idle agent quota flows to busy agents
- Accurately models what the API actually enforces
- Single place to monitor and tune

**Cons:**
- No blast radius protection by default
- Requires priority scheme to prevent starvation

### 3.3 Recommended: Shared Pool + Per-Agent Priority Caps

Use a **shared pool** as the primary model, but add **per-agent caps as ceilings** (not floors). This gives Squad:

1. Full shared-pool efficiency for normal operations
2. Protection against runaway agents (Ralph can consume at most 25% of the pool)
3. Priority override allowing critical agents (Picard, Data) to preempt lower-priority tasks

```
Total Pool (e.g., 50 RPM Claude Tier 1)
├── Critical Priority (Picard, Worf): up to 100% of pool, but served first
├── Standard Priority (Data, Seven, Belanna, Neelix, Troi): up to 70% of pool
└── Background Priority (Ralph, Scribe monitor polls): capped at 25% of pool
```

---

## 4. Adaptive Backoff Strategies on 429 Responses

### 4.1 The Thundering Herd Problem

When 8 agents all receive a 429 simultaneously and all use the same 5-second base backoff, they retry simultaneously 5 seconds later — generating another 429 wave. This is the single most common failure mode in naive multi-agent systems.

### 4.2 Full Jitter Exponential Backoff (Recommended)

```python
import random, time

def backoff_delay(attempt: int, base: float = 1.0, cap: float = 60.0) -> float:
    """Full jitter: sleep = random(0, min(cap, base * 2^attempt))"""
    exp = min(cap, base * (2 ** attempt))
    return random.uniform(0, exp)

def call_with_backoff(fn, max_retries=5):
    for attempt in range(max_retries):
        try:
            return fn()
        except RateLimitError as e:
            if attempt == max_retries - 1:
                raise
            retry_after = e.headers.get("retry-after")
            if retry_after:
                delay = float(retry_after) + random.uniform(0, 2)
            else:
                delay = backoff_delay(attempt)
            time.sleep(delay)
```

**Key rules:**
1. **Always honor `Retry-After` header** — the API tells you exactly how long to wait; don't ignore it
2. **Add jitter on top of Retry-After** — even if agents are told to wait 10 seconds, stagger them by ±2s to avoid re-collision
3. **Cap maximum delay at 60 seconds** — beyond this, the user should be informed the task is queued
4. **Don't retry 4xx errors other than 429** — 401, 403, 400 are not transient and will never succeed

### 4.3 Proactive Throttling (Preferred over Reactive Backoff)

Rather than waiting for 429s, monitor response headers continuously:

- **Anthropic:** `anthropic-ratelimit-requests-remaining`, `anthropic-ratelimit-tokens-remaining`
- **GitHub:** `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- **Azure OpenAI:** `x-ratelimit-remaining-requests`, `x-ratelimit-remaining-tokens`

When `remaining < 20%` of limit, switch to **pre-emptive slow mode**: introduce a small delay before each request. This prevents 429s entirely, at a small latency cost.

---

## 5. Request Prioritization Across Squad Agents

### 5.1 Priority Tiers for Squad

Squad agents have meaningfully different priorities based on user-facing impact:

| Priority | Agents | Rationale |
|---|---|---|
| **P0 — Critical** | Picard (architecture decisions), Worf (security alerts) | Blocking decisions; user is waiting |
| **P1 — Standard** | Data (code), Seven (research/docs), Belanna (infra), Troi (blog) | Core work tasks; reasonable wait tolerable |
| **P2 — Background** | Ralph (monitor/polling), Scribe (logging), Neelix (news) | Async tasks; can wait minutes without impact |

### 5.2 Priority Queue Implementation

```typescript
interface QueuedRequest {
  priority: 0 | 1 | 2;
  agentId: string;
  requestFn: () => Promise<any>;
  enqueuedAt: number;
  resolve: (value: any) => void;
  reject: (error: any) => void;
}

class PriorityRateLimiter {
  private queues: QueuedRequest[][] = [[], [], []]; // P0, P1, P2
  private inFlight = 0;
  private maxConcurrent: number;
  private tokenBucket: TokenBucket;

  async enqueue(priority: 0|1|2, agentId: string, fn: () => Promise<any>) {
    return new Promise((resolve, reject) => {
      this.queues[priority].push({ priority, agentId, requestFn: fn,
        enqueuedAt: Date.now(), resolve, reject });
      this.drain();
    });
  }

  private async drain() {
    // Process highest priority first, then P1, then P2
    for (const queue of this.queues) {
      if (queue.length > 0 && this.tokenBucket.consume(1) && 
          this.inFlight < this.maxConcurrent) {
        const item = queue.shift()!;
        this.inFlight++;
        item.requestFn()
          .then(item.resolve)
          .catch(item.reject)
          .finally(() => { this.inFlight--; this.drain(); });
        return;
      }
    }
  }
}
```

### 5.3 Starvation Prevention

A pure priority queue risks starving P2 tasks indefinitely during busy periods. Apply **aging**: after a P2 request has waited more than 5 minutes, promote it to P1. After 15 minutes, promote to P0.

---

## 6. API-Specific Considerations

### 6.1 Anthropic (Claude API)

**Rate limit structure (org-level, token bucket internally):**

| Tier | RPM | ITPM | OTPM | Entry Threshold |
|---|---|---|---|---|
| Tier 1 | 50 | 30K | 8K | $5+ spent |
| Tier 2 | 1,000 | 450K | 90K | $40+ spent |
| Tier 3 | 2,000 | 800K | 160K | $200+ spent |
| Tier 4 | 4,000 | 2M | 400K | $400+ spent |

**Key Squad-specific considerations:**

1. **TPM dominates, not RPM.** A single Picard architecture discussion can burn 50K+ tokens. With 8 agents active, you can exhaust Tier 1 TPM in a single round.

2. **Use prompt caching aggressively.** Repeated system prompts (agent persona, squad config) qualify for caching. Cache hits don't count against TPM — effectively multiplying your quota 5–10x for agents with stable system prompts.

3. **Track both input and output tokens separately.** Claude's OTPM limit (8K on Tier 1) is far more restrictive than ITPM. Agents requesting long completions should use `max_tokens` caps.

4. **Response headers to monitor:**
   ```
   anthropic-ratelimit-requests-limit: 50
   anthropic-ratelimit-requests-remaining: 12
   anthropic-ratelimit-requests-reset: 2026-03-15T10:00:00Z
   anthropic-ratelimit-tokens-remaining: 4821
   ```

5. **Batch API for background tasks.** Ralph and Scribe should use Anthropic's Batch API for non-interactive requests. Batch requests have separate (higher) limits and cost 50% less.

### 6.2 GitHub API

**Rate limit structure:**

| Auth Method | Limit | Notes |
|---|---|---|
| Unauthenticated | 60/hour | Never use |
| PAT / OAuth | 5,000/hour | Per user, per token |
| GitHub App | 15,000/hour | Per installation (Enterprise Cloud) |
| Secondary limits | 100 concurrent, 900 reads/endpoint/min | Easy to hit with multi-agent |

**Key Squad-specific considerations:**

1. **Secondary rate limits are the real danger.** GitHub's primary 5000/hr limit is rarely hit by Squad. The secondary limit — 100 concurrent requests or 900 reads/minute on a single endpoint — fires regularly when multiple agents list issues/PRs simultaneously.

2. **Use separate PATs per agent role if possible.** Picard and Ralph listing PRs in parallel doubles the concurrent connection count. Separate tokens = separate primary quotas.

3. **Conditional requests save quota.** Use `If-None-Match: <etag>` headers when polling. A 304 Not Modified response doesn't count toward the rate limit.

4. **Prefer webhooks over polling for Ralph.** Ralph currently polls for new issues/PRs. Switching to webhook delivery eliminates this poll traffic entirely.

5. **GraphQL over REST for complex queries.** One GraphQL query can replace 5–10 REST calls (e.g., fetching PR + commits + reviews + checks in one request).

6. **Headers to monitor:**
   ```
   X-RateLimit-Limit: 5000
   X-RateLimit-Remaining: 4823
   X-RateLimit-Reset: 1710000000  # Unix timestamp
   X-RateLimit-Used: 177
   ```

### 6.3 Azure / OpenAI APIs

**Rate limit structure:**

| Limit Type | Enforcement | Notes |
|---|---|---|
| TPM (Tokens/Minute) | Per deployment | Primary constraint |
| RPM (Requests/Minute) | Derived from TPM (≈ TPM/1000 * 6) | Can hit before TPM |
| Concurrent requests | Per region | Secondary limit |

**Key Squad-specific considerations:**

1. **Sub-second burst throttling.** Azure enforces limits in sub-minute windows (sometimes per-second). Even if your per-minute total is fine, 10 simultaneous requests can trigger a 429.

2. **Use Azure API Management** as a central gateway with the `azure-openai-token-limit` policy. This enforces per-key budgets server-side, preventing any single agent from monopolizing a deployment.

3. **Separate deployments for different agent types.** Use one deployment for interactive Picard queries (low TPM, low latency) and another for batch Ralph/Scribe tasks (high TPM, latency-tolerant).

4. **Retry-After is reliable.** Azure's 429 responses include a `retry-after-ms` header with exact milliseconds to wait. Honor it precisely.

---

## 7. Recommended Strategy for Squad

### 7.1 Architecture: Centralized Rate Governor

Deploy a **single Rate Governor** component (can be a lightweight in-process service or a separate microservice with Redis backing) that all agents route API calls through.

```
Agent (Picard) → Rate Governor → Anthropic API
Agent (Ralph)  → Rate Governor → GitHub API
Agent (Data)   → Rate Governor → Azure API
Agent (Seven)  → Rate Governor → (any API)
```

The Rate Governor:
1. Maintains a token bucket per API provider (Claude, GitHub, Azure)
2. Enforces per-agent caps (Ralph ≤ 25% of pool)
3. Applies priority queue ordering (Picard before Ralph)
4. Monitors response headers and adjusts in real time
5. Implements full-jitter exponential backoff on 429s

### 7.2 Implementation Phases

**Phase 1 (Immediate — 1 week):** Reactive hardening
- Add `Retry-After` header parsing to all API clients with full-jitter backoff
- Add rate limit header monitoring and logging
- Prevent simultaneous GitHub REST calls from multiple agents (serialize per-endpoint)

**Phase 2 (Short-term — 2–3 weeks):** Centralized governor
- Implement shared token bucket for Claude TPM/RPM tracking
- Add priority queue with P0/P1/P2 tiers
- Add per-agent ceiling caps (Ralph ≤ 25%)
- Wire up proactive slow-mode when `remaining < 20%`

**Phase 3 (Medium-term — 1 month):** Optimization
- Enable Anthropic prompt caching for all agents' system prompts
- Move Ralph/Scribe to Anthropic Batch API
- Switch Ralph's GitHub integration from polling to webhooks
- Add GraphQL for complex multi-resource GitHub queries
- Instrument with metrics (RPM used vs. limit, queue depth, p95 wait time)

### 7.3 Configuration Reference

```typescript
// squad.ratelimit.config.ts
export const RateLimitConfig = {
  anthropic: {
    rpm: 50,           // Tier 1 default; increase when tier upgrades
    itpm: 30_000,
    otpm: 8_000,
    proactiveThreshold: 0.20,  // Slow down at 20% remaining
  },
  github: {
    requestsPerHour: 5_000,
    maxConcurrentPerEndpoint: 10,  // Below GitHub's 100 secondary limit
    proactiveThreshold: 0.15,
  },
  azure: {
    tpm: 60_000,       // Per deployment
    rpm: 360,
    proactiveThreshold: 0.20,
  },
  agents: {
    picard:  { priority: 0, maxPoolFraction: 1.0 },
    worf:    { priority: 0, maxPoolFraction: 1.0 },
    data:    { priority: 1, maxPoolFraction: 0.70 },
    seven:   { priority: 1, maxPoolFraction: 0.70 },
    belanna: { priority: 1, maxPoolFraction: 0.70 },
    troi:    { priority: 1, maxPoolFraction: 0.70 },
    neelix:  { priority: 1, maxPoolFraction: 0.50 },
    ralph:   { priority: 2, maxPoolFraction: 0.25 },
    scribe:  { priority: 2, maxPoolFraction: 0.20 },
  },
  backoff: {
    baseDelayMs: 1_000,
    capDelayMs: 60_000,
    maxRetries: 5,
    jitterFraction: 1.0,  // Full jitter (0 to calculated delay)
  },
  aging: {
    p2ToP1AfterMs: 5 * 60_000,   // 5 minutes
    p1ToP0AfterMs: 15 * 60_000,  // 15 minutes
  },
};
```

---

## 8. Monitoring & Observability

Effective rate limit management requires visibility. Recommended metrics to track:

| Metric | Alert Threshold | Action |
|---|---|---|
| `ratelimit.remaining_pct.<api>` | < 20% | Switch to slow mode |
| `ratelimit.429_count_per_minute` | > 5 | Investigate agent behavior |
| `ratelimit.queue_depth.<priority>` | P2 > 50 | Check for starvation |
| `ratelimit.p50_wait_ms.<agent>` | > 10s for P0 | Increase quota or reduce agent concurrency |
| `ratelimit.token_consumption_rate` | > 80% of TPM | Enable caching / batch fallback |

---

## 9. Key Findings Summary

1. **Shared pool model is correct** — Anthropic and GitHub enforce limits at the org/token level, not per-agent. Model your client-side limiter the same way.

2. **Token bucket matches Anthropic's internal algorithm** — Use TPM-aware token bucket for Claude, where each request consumes tokens proportional to its input+output token count.

3. **Full-jitter exponential backoff is mandatory** — Plain exponential backoff causes thundering herds. Full jitter (`random(0, min(cap, base * 2^n))`) is the industry standard.

4. **Proactive throttling beats reactive backoff** — Monitoring `remaining` headers and pre-emptively slowing at 20% remaining is far better than hitting 429s and recovering.

5. **Priority queuing prevents starvation of critical agents** — Picard executing decisions should never queue behind Ralph's background polls. A three-tier priority system (P0/P1/P2) with starvation prevention covers Squad's full agent roster.

6. **GitHub secondary limits are the real danger** — Not the 5000/hr primary limit, but the 100 concurrent and 900/endpoint/minute secondary limits. Serialize per-endpoint and use conditional requests.

7. **Anthropic prompt caching is a force multiplier** — If agents have stable system prompts (and Squad's agents do — persona + squad config), prompt caching reduces effective TPM consumption by 5–10x at no code cost.

8. **Batch API for background tasks** — Ralph and Scribe do not need interactive latency. The Batch API has separate higher limits and 50% cost reduction.

---

## References

- [Anthropic Rate Limits Documentation](https://platform.claude.com/docs/en/api/rate-limits)
- [GitHub REST API Rate Limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
- [GitHub Best Practices for REST API](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api)
- [Azure API Management: OpenAI Token Limit Policy](https://learn.microsoft.com/en-us/azure/api-management/azure-openai-token-limit-policy)
- [Multi-Objective Adaptive Rate Limiting in Microservices Using Deep RL (arXiv 2511.03279)](https://arxiv.org/abs/2511.03279)
- [Multi-Agent Rate Limits Production Playbook](https://claudecodeplugins.io/playbooks/01-multi-agent-rate-limits/)
- [MCP Rate Limiting Patterns: Token Bucket & Sliding Window](https://makeaihq.com/guides/cluster/mcp-rate-limiting-patterns)
- [Queue-Based Exponential Backoff — Resilient Retry Pattern](https://dev.to/andreparis/queue-based-exponential-backoff-a-resilient-retry-pattern-for-distributed-systems-37f3)
- [Azure OpenAI Rate Limits and Monitoring](https://clemenssiebler.com/posts/understanding-azure-openai-rate-limits-monitoring/)

---

*Report generated by Seven (Research & Docs Agent) for Squad issue #979.*
