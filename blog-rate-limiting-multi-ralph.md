# 9 AI Agents, One API Quota — The Rate Limiting Problem Nobody Talks About

![Rate limiting hero — AI agents competing for API access](blog-screenshots/rate-limit-hero.png)

*March 2026 · Tamir Dresher*

---

## The Story

I've been running [Squad](https://github.com/tamirdresher/squad) — a multi-agent AI framework — for a couple of weeks now. It orchestrates a team of AI agents that handle code review, architecture decisions, infrastructure, docs, and more. A reconciliation loop runs every 5 minutes, picking up work and dispatching agents. Most of the time it works great.

As I started planning to run Squad at scale — thinking about platforms like Kubernetes, cloud VMs, or similar — I realized rate limiting with multiple agents is fundamentally different from single-service rate limiting. So I went and did some research and reading, stress-tested the system, and designed 6 patterns to handle it.

Here's what triggered the deep dive. We ran a V10 stress test — spinning up the full agent roster at once.

Nine agents launched simultaneously. In 22 minutes they opened **10 pull requests**. Impressive — until minute 8, when GitHub started returning `429 Too Many Requests`.

Every agent retried at the same time. The retry wave triggered a *second* 429 wave. That triggered a third. Within 90 seconds we'd burned through GitHub's 5,000 requests/hour limit and were locked out entirely. Meanwhile, Picard — our lead agent making critical architecture decisions — was stuck behind Ralph, a background polling agent that had eaten the remaining Anthropic tokens doing low-priority issue triage.

Even in just a couple of weeks of running the system, we'd already hit memory issues, resource contention, and agent crashes. But rate limiting with multiple agents sharing the same quotas? That was a different problem entirely — and one that gets worse the more you scale.

The core lesson:

> **Rate limiting in multi-agent systems is a coordination problem, not a retry problem.**

Every tool we evaluated — AWS API Gateway, Azure API Management, Resilience4j, LangGraph — treats rate limiting as something each caller handles independently. But when 9 agents share the same API quotas, independent retry logic doesn't just fail. It actively makes things worse.

---

## The Three Failure Modes

Before designing anything, we had to understand *why* standard retry logic breaks down. We identified three patterns from our logs and stress tests:

### 1. Thundering Herd

After a 429, all agents wait the same `Retry-After` duration and retry simultaneously. They collide again, triggering another 429. In our stress test, the `ralph-self-heal.log` showed **60+ chained failures** in a single incident. Classic distributed systems problem — except the "services" are AI agents that don't know about each other.

### 2. Priority Inversion

Ralph's background polling (checking for new GitHub issues every 5 minutes) consumed API quota that Picard needed for blocking architecture decisions. Both agents had equal retry priority. There was no way to say "Picard goes first" — so critical work waited behind background noise.

### 3. Cascade Amplification

A single GitHub secondary-rate-limit hit caused multiple agents to queue their pending work. When the limit lifted, they all flushed their queues at once — immediately re-triggering the limit. One 429 became a system-wide outage that took up to 60 minutes to recover from.

---

## 6 Patterns We Built

Based on the research and our stress testing, we designed a **Rate Governor** — a coordination layer that all agents consult before making API calls. Here are the six patterns inside it, each one a direct response to a failure mode we observed or anticipated as the system scales.

![Rate Governor Architecture — 6 components feeding into the Rate State Store](blog-screenshots/rate-governor-architecture.png)

```mermaid
graph TD
    subgraph "Rate Governor"
        TL["Traffic Light<br/>Throttling"]
        TP["Shared<br/>Token Pool"]
        CB["Predictive<br/>Circuit Breaker"]
        CD["Cascade<br/>Detector"]
        LB["Lease-Based<br/>Cleanup"]
        PW["Priority Retry<br/>Windows"]

        RSS["Rate State Store<br/>rate-pool.json · rate-state.json"]
    end

    TL --> RSS
    TP --> RSS
    LB --> RSS
    CB --> RSS
    RSS --> CD
    RSS --> PW

    RSS --> API1["Anthropic Claude API"]
    RSS --> API2["GitHub REST/GraphQL"]
    RSS --> API3["Azure OpenAI"]
```

---

### Pattern 1: Traffic Light Throttling

**What broke:** Agents only reacted *after* hitting a 429. By then, the entire quota window was gone. Recovery meant waiting up to 60 seconds while every agent sat idle.

**What we learned:** Every API response already includes `x-ratelimit-remaining` and `x-ratelimit-reset` headers. Nobody was reading them.

We added a traffic-light system that reads remaining quota after every API call and adjusts behavior *before* hitting the wall:

| Zone | When | What happens |
|------|------|--------------|
| 🟢 Green | >40% quota left | Normal operation |
| 🟡 Amber | 15–40% left | Add proportional delays — background agents slow down first |
| 🔴 Red | <15% left | Background agents park. Standard agents slow to 1 req/sec. Critical agents pass through. |

Here's what the header parsing looks like:

```powershell
# Read rate-limit state from API response headers
$remaining = [int]$response.Headers["x-ratelimit-remaining"]
$limit     = [int]$response.Headers["x-ratelimit-limit"]
$resetAt   = $response.Headers["x-ratelimit-reset"]

$ratio = $remaining / $limit

if ($ratio -ge 0.40) {
    # GREEN — no throttling
} elseif ($ratio -ge 0.15) {
    # AMBER — proportional delay for non-critical agents
    $delayMs = 2000 * (0.40 - $ratio) / 0.25
    Start-Sleep -Milliseconds $delayMs
} else {
    # RED — park background agents, slow standard agents
    if ($Priority -eq 2) { return "PARKED" }
    if ($Priority -eq 1) { Start-Sleep -Seconds 1 }
    # P0 passes through immediately
}
```

> **Key insight:** Don't wait for a 429 to tell you you're out of quota. The headers tell you 10 calls in advance. Read them.

---

### Pattern 2: Shared Token Pool

**What broke:** All agents share an org-level Anthropic quota (30K input tokens/min at Tier 1) but tracked consumption independently. When Ralph was idle, Picard couldn't borrow his unused allocation. When Ralph was busy triaging, he starved Data's code generation.

**What we learned:** Agents need a shared ledger. We created `rate-pool.json` — a single file (with file-locking) that tracks the shared quota, per-agent soft reservations, and a donation register where idle agents release unused tokens.

```jsonc
// rate-pool.json
{
  "anthropic": {
    "window_tokens_total": 30000,
    "window_tokens_remaining": 18500,
    "agent_allocations": {
      "picard": { "reserved": 8000, "used": 3200 },
      "ralph":  { "reserved": 5000, "used": 800 },
      "data":   { "reserved": 8000, "used": 7100 }
    },
    "donation_pool": 4200
  }
}
```

The rules are simple:
- **P0 agents** (Picard, Worf) always get tokens if any remain
- **P1 agents** (Data, Seven) use their reservation, then pull from the donation pool
- **P2 agents** (Ralph) yield when the pool is under 30% capacity
- **Idle agents** donate unused reservations back to the pool automatically
- **Starvation prevention:** any P2 agent denied for 5+ minutes gets promoted to P1

There's no circular wait — an agent either gets tokens immediately or yields and retries next round. No deadlocks possible.

> **Key insight:** Treat your API quota like a shared bank account, not separate wallets. Idle agents should donate, critical agents should overdraw.

---

### Pattern 3: Predictive Circuit Breaker

**What broke:** Our existing circuit breaker opened only *after* receiving a 429. That's like pulling the fire alarm after the building is already on fire. The quota was gone, and recovery meant waiting the full cooldown window.

**What we learned:** You can predict exhaustion before it happens. If you're burning 1,000 tokens/second and you have 2,000 left, you've got 2 seconds — not enough time for the next agent request to complete.

We added a `PRE-EMPTIVE_OPEN` state to the circuit breaker:

![PCB State Machine — CLOSED to PRE-EMPTIVE_OPEN to HALF-OPEN](blog-screenshots/pcb-state-machine.png)

```mermaid
stateDiagram-v2
    [*] --> CLOSED
    CLOSED --> PRE_EMPTIVE_OPEN: predicted exhaustion within 30s
    CLOSED --> REACTIVE_OPEN: received 429
    PRE_EMPTIVE_OPEN --> HALF_OPEN: quota resets or remaining recovers
    REACTIVE_OPEN --> HALF_OPEN: cooldown elapsed
    HALF_OPEN --> CLOSED: 3 consecutive successes
    HALF_OPEN --> REACTIVE_OPEN: probe fails
```

Before switching models entirely, the circuit breaker first tries **reducing load on the same model** — cutting `max_tokens`, compressing prompts. Only if that doesn't help does it walk down the fallback chain:

```
claude-sonnet-4.6 → gpt-5.4-mini → gpt-5-mini → gpt-4.1
```

> **Key insight:** The difference between "locked out for 10 minutes" and "gracefully downgraded for 30 seconds" is prediction. If you can see the wall coming, you can brake instead of crashing.

---

### Pattern 4: Cascade Detector

**What broke:** Squad workflows are sequential — Picard makes an architecture decision, Data implements it, Belanna deploys it, Neelix announces it. A rate limit hit at *any* stage blocked everything downstream. But no agent knew about its dependencies.

**What we learned:** You need a dependency graph. When one agent gets rate-limited, every downstream agent should know *before* it attempts its next call.

```mermaid
graph LR
    RL[/"429 on GitHub API"/]
    R["Ralph<br/>(P2: Triage)"]
    P["Picard<br/>(P0: Architecture)"]
    D["Data<br/>(P1: Code)"]
    B["Belanna<br/>(P1: Deploy)"]
    N["Neelix<br/>(P2: Announce)"]

    RL -->|"triggers"| R
    R -->|"backpressure"| P
    P -->|"backpressure"| D
    D -->|"backpressure"| B
    B -->|"backpressure"| N

    style RL fill:#e74c3c,color:#fff
    style R fill:#f39c12,color:#fff
    style P fill:#e67e22,color:#fff
    style D fill:#e67e22,color:#fff
    style B fill:#e67e22,color:#fff
    style N fill:#e67e22,color:#fff
```

When 3+ agents get rate-limited within a 30-second window, the cascade detector switches to **sequential mode** — agents take an ordered lock and go one at a time instead of all at once. This kills the thundering herd instantly.

We encode the workflow DAG in a simple config:

```yaml
# backpressure.yaml
workflows:
  issue-to-deploy:
    - ralph      # triage
    - picard     # architecture
    - data       # implementation
    - belanna    # deployment
    - neelix     # announcement
  cascade_threshold: 3  # agents hit in 30s triggers sequential mode
```

> **Key insight:** A rate limit isn't a local event — it's a signal that propagates through your agent dependency chain. Map the chain, propagate the signal.

---

### Pattern 5: Lease-Based Cleanup

**What broke:** When an agent crashed mid-round, its token reservation in the shared pool was never released. Even in a couple of weeks of running, we saw phantom allocations start to accumulate — agents got denied tokens despite actual API quota being available. At scale, this would get much worse.

**What we learned:** Every allocation needs a lease with an expiry. We tag each reservation with a timestamp and tie it to the agent's heartbeat. A background sweep every 30 seconds checks:

```powershell
# Reclaim tokens from dead agents
$heartbeatFiles = Get-ChildItem "$env:SQUAD_DIR/heartbeats/*.json"
foreach ($hb in $heartbeatFiles) {
    $agent = $hb.BaseName
    $lastBeat = (Get-Content $hb.FullName | ConvertFrom-Json).timestamp
    $staleness = (Get-Date) - [datetime]$lastBeat

    if ($staleness.TotalMinutes -gt 2) {
        # Agent is dead — reclaim its tokens
        $pool = Get-Content "rate-pool.json" | ConvertFrom-Json
        $unused = $pool.anthropic.agent_allocations.$agent.reserved -
                  $pool.anthropic.agent_allocations.$agent.used
        $pool.anthropic.donation_pool += [Math]::Max(0, $unused)
        $pool.anthropic.agent_allocations.$agent.reserved = 0
        $pool | ConvertTo-Json -Depth 5 | Set-Content "rate-pool.json"
        Write-Host "♻️ Reclaimed $unused tokens from crashed agent: $agent"
    }
}
```

This hooks directly into Squad's existing `ralph-heartbeat.ps1` — the heartbeat files are already there. We just started reading them.

> **Key insight:** In any environment where agents can crash — and they will — allocations outlive the processes that made them. Add a lease, or your token pool will slowly starve.

---

### Pattern 6: Priority Retry Windows

**What broke:** The standard AWS exponential-backoff-with-jitter formula treats every caller equally. When Picard (critical architecture decisions) and Ralph (background polling) both get a 429 at the same time, they both retry in the same random window. Ralph can get lucky and grab the quota before Picard. That's priority inversion.

**What we learned:** Give each priority tier its own non-overlapping retry window. P0 retries first. P1 retries after P0 is done. P2 goes last.

![PWJG Priority Retry Windows — P0, P1, P2 in non-overlapping time bands](blog-screenshots/pwjg-priority-windows.png)

```mermaid
gantt
    title Retry Windows After 429 (non-overlapping)
    dateFormat X
    axisFormat %s

    section P0 (Critical)
    Picard, Worf : 0, 500ms

    section P1 (Standard)
    Data, Seven, Belanna, Troi, Neelix : 500ms, 3500ms

    section P2 (Background)
    Ralph, Scribe : 3500ms, 9500ms
```

| Priority | Agents | Retry Window |
|----------|--------|-------------|
| **P0** Critical | Picard, Worf | **0 – 0.5s** |
| **P1** Standard | Data, Seven, Belanna, Troi, Neelix | **0.5 – 3.5s** |
| **P2** Background | Ralph, Scribe | **3.5 – 9.5s** |

This guarantees P0 agents consume available quota before P1 agents even begin retrying. Priority inversion becomes structurally impossible.

```powershell
function Get-RetryDelay {
    param(
        [int]$RetryAfterSeconds,
        [int]$Attempt,
        [int]$Priority  # 0=critical, 1=standard, 2=background
    )

    # Base delay from Retry-After header (or exponential backoff)
    if (-not $RetryAfterSeconds) {
        $RetryAfterSeconds = [Math]::Min(60, [Math]::Pow(2, $Attempt))
    }

    # Non-overlapping priority windows
    switch ($Priority) {
        0 { $windowStart = 0;    $windowEnd = 0.5  }  # P0: first 500ms
        1 { $windowStart = 0.5;  $windowEnd = 3.5  }  # P1: 500ms–3.5s
        2 { $windowStart = 3.5;  $windowEnd = 9.5  }  # P2: 3.5s–9.5s
    }

    $jitter = Get-Random -Minimum 0 -Maximum (($windowEnd - $windowStart) * 1000)
    return $RetryAfterSeconds + $windowStart + ($jitter / 1000.0)
}
```

> **Key insight:** Standard jitter treats all callers as equal. In a multi-agent system, they're not. Separate the retry windows by priority and the problem disappears.

---

## The Full Architecture

All six patterns feed into a shared **Rate State Store** — a pair of JSON files (`rate-pool.json` and `rate-state.json`) with file locking. Every agent reads state before calling an API and writes state after receiving a response. No central server needed — it's cooperative coordination through the filesystem.

```
┌─────────────────────────────────────────────────┐
│              Squad Rate Governor                │
│                                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐│
│  │ Traffic  │ │ Shared   │ │ Lease-Based      ││
│  │ Light    │ │ Token    │ │ Cleanup          ││
│  │ Throttle │ │ Pool     │ │ (heartbeat-tied) ││
│  └────┬─────┘ └────┬─────┘ └────────┬─────────┘│
│       │             │                │          │
│       ▼             ▼                ▼          │
│  ┌─────────────────────────────────────────┐    │
│  │  Rate State Store                       │    │
│  │  rate-pool.json · rate-state.json       │    │
│  └────────────┬────────────────────────────┘    │
│               │                                 │
│       ┌───────┼───────┐                         │
│       ▼       ▼       ▼                         │
│  ┌────────┐ ┌──────┐ ┌───────────┐              │
│  │Cascade │ │Retry │ │Predictive │              │
│  │Detector│ │Window│ │Circuit    │              │
│  │        │ │      │ │Breaker    │              │
│  └────────┘ └──────┘ └───────────┘              │
└─────────────────────────────────────────────────┘
         │          │          │
         ▼          ▼          ▼
    GitHub API   Anthropic   Azure OpenAI
```

---

## Real Numbers

Here's what we observed during stress testing *before* designing the Rate Governor:

| Metric | Value |
|--------|-------|
| Agents running concurrently | 9 (V10 stress test) |
| PRs created in one burst | **10 in 22 minutes** |
| GitHub API calls/hour | 4,800+ (dangerously close to 5,000 limit) |
| 429 errors per incident | **60+ chained failures** |
| Cascade chain depth | Up to 5 agents (full workflow blocked) |
| Recovery time (no governor) | Up to **60 minutes** (full hour lockout) |
| Anthropic token budget | 30K ITPM / 8K OTPM (Tier 1) |
| Agent crashes | Several during stress test |

And here's what the patterns address:

| What we tried | What it fixes | Expected improvement |
|--------------|---------------|---------------------|
| Traffic Light Throttling | Hitting 429s reactively | 25–40% fewer 429 errors |
| Shared Token Pool | Agents starving each other | Better token utilization across all agents |
| Predictive Circuit Breaker | Full lockouts after quota exhaustion | Graceful degradation instead of 10-min outages |
| Cascade Detector | One 429 taking down the whole workflow | 60–80% fewer cascade chains |
| Lease-Based Cleanup | Ghost allocations from crashed agents | Prevents phantom token starvation |
| Priority Retry Windows | Ralph retrying before Picard | >95% elimination of priority inversion |

---

## 5 Things to Do Today

If you're running multiple AI agents against shared API quotas, here's the practical checklist:

### 1. Read the rate-limit headers

Every response from Anthropic, OpenAI, and GitHub includes `x-ratelimit-remaining`. Parse it. Log it. React to it *before* hitting a 429. This is free and takes 20 minutes to implement.

### 2. Assign priority tiers to your agents

Not all agents are equal. Your architecture decision-maker should not compete with your background poller. Define P0 (critical), P1 (standard), P2 (background) tiers and stagger your retry windows accordingly.

### 3. Share quota state across agents

If your agents track consumption independently, they will over-consume. A shared JSON file with file-locking is good enough to start. You don't need Redis or a coordinator service on day one.

### 4. Add lease expiry to allocations

If agents can crash (and they will), every token reservation needs a TTL. Dead agents shouldn't hold quota hostage. Tie it to a heartbeat file — if the heartbeat stops, reclaim the tokens.

### 5. Map your agent dependency chain

Which agents depend on which other agents' output? Write it down. When one agent gets rate-limited, propagate a backpressure signal to everything downstream before they waste their own API calls.

---

*These patterns came out of a couple of weeks of running Squad in production and a deep dive into what breaks when you scale multi-agent systems. The full research report — including detailed algorithms, formal proofs, and implementation guidance — is available in the [project repository](https://github.com/tamirdresher/squad).*

*Squad manages 8–12 autonomous AI agents performing code review, architecture decisions, infrastructure deployment, research, and communication — all against shared API quotas that were never designed for this kind of concurrent access.*
