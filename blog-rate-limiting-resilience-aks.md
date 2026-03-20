---
layout: post
title: "The Thundering Herd — Rate Limiting & Resilience Patterns for AI Agents on Kubernetes"
date: 2026-03-28
tags: [ai-agents, squad, kubernetes, rate-limits, resilience, keda, circuit-breaker, devops, aks]
series: "Scaling AI-Native Software Engineering"
series_part: 7
---

> *"In theory, there is no difference between theory and practice. In practice, there is."*
> — Attributed to various engineers who have all been rate-limited at 3am

In [Part 5](/blog/2026/03/25/scaling-ai-part5-kubernetes), I showed you how we moved the Squad from a laptop to AKS — containerized Ralph, wrote Helm charts, and felt very clever about it. In the [Multi-Ralph post](/blog/2026/03/17/scaling-ai-rate-limits), I confessed what happened when two Ralphs shared the same API quota: cascading workflow storms, 236 queued Actions runs, and a hard lesson in PAT token suppression.

This post is about what happened *next*. When we didn't just run two Ralphs — we ran a single pod that spawned nine parallel agents, all hammering the GitHub API simultaneously, and produced ten pull requests in twenty-two minutes.

And then everything stopped.

---

## The v10 Diagnostic Pod

It started as a diagnostic run. I spun up a pod — `ralph-diag-v10` — to test how many agents Ralph could orchestrate simultaneously. The answer turned out to be nine. Nine parallel agents (Picard, Data, Worf, B'Elanna, Seven, and task-specific workers), all running inside a single pod on a `Standard_D2_v2` node (2 vCPU, 7GB RAM).

The results were spectacular — for about twenty minutes:

```
Round started:  14:03:12 UTC
PRs created:    10
Agents active:  9 (parallel)
Tokens used:    759,900 input / 4,900 output
Duration:       22 minutes
CPU peak:       85% utilization
Memory peak:    1.8Gi (of 2Gi limit)
```

Ten PRs. Twenty-two minutes. From a single pod costing $0.10/hour.

The PRs were real, substantive work — KEDA autoscaling configurations (#1190), a rate-limit-exporter service (#1193), composite AND triggers for KEDA (#1180), a Grafana dashboard for rate limit visibility (#1178), Predictive Circuit Breaker logic (#1196), and a Cascade Dependency Detector (#1181). These weren't toy PRs. Each one had Helm charts, tests, and documentation.

Then I checked the GitHub API response headers:

```
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1711627200
```

Zero remaining. Every agent had been making API calls — reading issues, creating branches, pushing commits, opening PRs, adding labels — and collectively they'd burned through the entire hourly quota in twenty-two minutes.

The next forty minutes were silence. Nine agents sitting in `BackOff` loops, retrying requests that would never succeed until the rate limit window reset. Burning CPU cycles, burning tokens on retry logic, burning money on a node doing nothing useful.

That's when I realized: **the problem isn't rate limiting. The problem is that nine agents don't know they share a ceiling.**

---

## Why Traditional Retry Doesn't Work Here

Every distributed systems textbook teaches exponential backoff with jitter. It's the standard pattern: wait 1 second, then 2, then 4, then 8, plus some random noise to prevent synchronized retries. It works beautifully when you have a handful of clients that got unlucky and need to spread out.

It does not work when you have nine agents that all started at the same time, all hit the same rate limit at the same time, and are all running the same backoff algorithm with the same base intervals.

This is the *thundering herd* problem, and jitter alone doesn't solve it when:

1. **All agents start simultaneously** (spawned by the same Ralph CronJob)
2. **All agents hit the ceiling simultaneously** (they're all calling the same API)
3. **The ceiling resets simultaneously** (GitHub rate limits reset on a fixed hourly window)
4. **All agents detect the reset simultaneously** (they're all watching the same `X-RateLimit-Reset` header)

Even with jitter, you end up with nine agents all attempting their first retry within a few seconds of each other, right when the rate limit resets. The first three succeed. The next six burn through the new quota. Forty minutes later, you're back where you started.

I needed something fundamentally different.

---

## Pattern 1: Token Bucket Awareness

The first pattern is embarrassingly simple in hindsight: **check how much quota you have before deciding how many agents to spawn**.

GitHub sends rate limit information in every API response:

```powershell
# Check rate limit before spawning agents
$rateLimit = gh api /rate_limit | ConvertFrom-Json
$remaining = $rateLimit.resources.core.remaining
$resetTime = [DateTimeOffset]::FromUnixTimeSeconds($rateLimit.resources.core.reset)
$minutesUntilReset = ($resetTime - [DateTimeOffset]::UtcNow).TotalMinutes

# Budget: each agent needs ~80 API calls per round
$apiCallsPerAgent = 80
$maxAgents = [Math]::Floor($remaining / $apiCallsPerAgent)

# Reserve 20% headroom for merge operations
$safeMaxAgents = [Math]::Floor($maxAgents * 0.8)

Write-Host "Rate limit: $remaining remaining, resets in $([Math]::Round($minutesUntilReset))m"
Write-Host "Can safely spawn: $safeMaxAgents agents"

if ($safeMaxAgents -lt 1) {
    Write-Host "⏳ Insufficient API budget. Entering idle-watch mode."
    Write-Host "   Will resume after $($resetTime.ToString('HH:mm:ss')) UTC"
    exit 0  # Clean exit — next CronJob cycle will retry
}
```

The key insight is the last three lines. When the budget is too low, the agent doesn't crash, doesn't retry, doesn't sit in a `BackOff` loop burning resources. It exits cleanly with code 0. The CronJob will fire again in 5 minutes. If the rate limit has reset by then, great — we spawn agents. If not, we exit again. No drama.

This is what I call **idle-watch mode**: the agent is aware of its constraints and chooses to wait productively rather than fail repeatedly.

---

## Pattern 2: Cooperative Rate Limiting

Token bucket awareness tells you *how many* agents to spawn. But it doesn't prevent those agents from stepping on each other's toes once they're running.

Consider this scenario: Picard reads the issue queue, sees issue #42 is unassigned, and starts working on it. At the same millisecond, Data reads the same queue, sees the same unassigned issue, and also starts working on it. Twenty minutes later, you have two PRs for the same issue, both consuming API quota, and one of them is wasted work.

The solution is **cooperative claiming** — agents coordinate through shared state (the GitHub issue itself) to avoid duplicate work:

```powershell
# Before starting work, attempt to claim the issue
$issue = gh api "/repos/$owner/$repo/issues/$issueNumber" | ConvertFrom-Json

# Check if already assigned
if ($issue.assignee) {
    Write-Host "Issue #$issueNumber already claimed by $($issue.assignee.login). Skipping."
    return
}

# Claim it by assigning to self
gh api -X POST "/repos/$owner/$repo/issues/$issueNumber/assignees" `
    -f "assignees[]=$agentName" 2>$null

# Re-read to confirm we won the race
Start-Sleep -Milliseconds 500
$issue = gh api "/repos/$owner/$repo/issues/$issueNumber" | ConvertFrom-Json
if ($issue.assignee.login -ne $agentName) {
    Write-Host "Lost race for #$issueNumber to $($issue.assignee.login). Moving on."
    return
}

Write-Host "✅ Claimed issue #$issueNumber"
```

This isn't a distributed lock — it's a *best-effort claim* with a check-after-write pattern. It doesn't guarantee mutual exclusion in all cases (two agents could assign themselves in the same API call window), but it reduces wasted work by 90%+ in practice. And critically, it costs only 2-3 API calls per claim attempt, not the 80+ calls of actually doing the work.

---

## Pattern 3: The Rate Limit Exporter

Checking rate limits inside each agent is a start, but it doesn't help with *cluster-level* decisions. If KEDA is going to scale pods based on the issue queue, it also needs to know whether the GitHub API can handle more agents.

This led to the **rate-limit-exporter** — a small sidecar that polls the GitHub API rate limit endpoint and exposes it as a Prometheus metric:

```yaml
# rate-limit-exporter deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-rate-limit-exporter
  namespace: squad
  labels:
    app: rate-limit-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rate-limit-exporter
  template:
    metadata:
      labels:
        app: rate-limit-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      containers:
        - name: exporter
          image: ghcr.io/tamirdresher/rate-limit-exporter:latest
          ports:
            - containerPort: 9090
          env:
            - name: GITHUB_TOKEN
              valueFrom:
                secretKeyRef:
                  name: squad-github-token
                  key: token
            - name: POLL_INTERVAL_SECONDS
              value: "30"
            - name: GITHUB_OWNER
              value: "tamirdresher"
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 50m
              memory: 64Mi
```

The exporter produces metrics like:

```
# HELP github_rate_limit_remaining GitHub API rate limit remaining calls
# TYPE github_rate_limit_remaining gauge
github_rate_limit_remaining{resource="core"} 4237
github_rate_limit_remaining{resource="search"} 28

# HELP github_rate_limit_reset_seconds Seconds until rate limit resets
# TYPE github_rate_limit_reset_seconds gauge
github_rate_limit_reset_seconds{resource="core"} 2147
```

Tiny footprint — 10m CPU, 32Mi memory. It's basically a glorified `curl` in a loop. But it gives KEDA (and Grafana, and alerting) a clean signal about API headroom.

---

## Pattern 4: KEDA Composite Triggers

With the rate limit exporter in place, I could write the KEDA trigger I actually wanted: **scale pods based on both the issue queue depth AND the available API headroom**.

```yaml
# KEDA ScaledJob for Ralph agents
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  name: squad-ralph-scaledjob
  namespace: squad
spec:
  jobTargetRef:
    parallelism: 1
    completions: 1
    backoffLimit: 0
    template:
      spec:
        restartPolicy: Never
        containers:
          - name: ralph
            image: ghcr.io/tamirdresher/squad-ralph:latest
            resources:
              requests:
                cpu: 200m
                memory: 2Gi
              limits:
                cpu: "1"
                memory: 3Gi
            env:
              - name: MAX_PARALLEL_AGENTS
                value: "4"
  pollingInterval: 300          # Check every 5 minutes
  maxReplicaCount: 3            # Never more than 3 parallel Ralph pods
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 3
  triggers:
    # Trigger 1: Issue queue has work
    - type: metrics-api
      metadata:
        targetValue: "1"
        url: "http://squad-board-api.squad.svc/api/queue-depth"
        valueLocation: "pendingIssues"
    # Trigger 2: Rate limit has headroom (AND logic)
    - type: prometheus
      metadata:
        serverAddress: "http://prometheus.monitoring.svc:9090"
        metricName: github_rate_limit_remaining
        query: |
          github_rate_limit_remaining{resource="core"} > 500
        threshold: "1"
        activationThreshold: "0"
```

The critical design choice here is the **AND logic** between triggers. KEDA's default behavior is OR — any trigger firing causes a scale-up. By setting `activationThreshold: "0"` on the rate limit trigger, we ensure the ScaledJob *only* scales up when the rate limit metric is above 500 remaining calls. If the API quota is exhausted, KEDA won't spawn new pods — even if the issue queue is full.

This is the Kubernetes-native equivalent of idle-watch mode. The system *knows* it can't do useful work right now, so it doesn't try.

---

## Pattern 5: The Predictive Circuit Breaker

Traditional circuit breakers have three states: Closed (normal), Open (all calls fail-fast), and Half-Open (allow one test call through). They work well for binary availability — a service is either up or down.

Rate limits aren't binary. They're temporal. You know *exactly* when they'll reset, because GitHub tells you in the response headers. A circuit breaker that treats "rate limited for 37 minutes" the same as "service is completely down" is throwing away information.

So we built a **Predictive Circuit Breaker** with a fourth state:

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│   CLOSED ──── failure ────► OPEN                    │
│     ▲                         │                     │
│     │                         │ rate-limit-reset    │
│     │                         │ header detected     │
│   success                     ▼                     │
│     │               HALF-OPEN-IMMINENT              │
│     │                    │                           │
│     │                    │ (T - 30s) before reset    │
│     │                    ▼                           │
│     └──────────── HALF-OPEN                         │
│                                                     │
└─────────────────────────────────────────────────────┘
```

The **Half-Open-Imminent** state is the new one. When the circuit opens due to a rate limit error, we don't start a blind timer. We read the `X-RateLimit-Reset` header and schedule the transition to Half-Open for 30 seconds *before* the predicted reset time. This gives us a head start — the test call goes out just as the new quota window opens, and if it succeeds, the circuit closes immediately.

In practice, this means the recovery time after a rate limit event dropped from "5+ minutes of retries" to "near-instant once the window resets." The agents effectively sleep through the rate limit window and wake up exactly when they can be productive again.

The configuration captures this behavior declaratively:

```yaml
# Predictive Circuit Breaker configuration
circuitBreaker:
  enabled: true
  failureThreshold: 3           # Open after 3 consecutive failures
  resetTimeoutSeconds: 60       # Default fallback if no reset header
  halfOpenMaxCalls: 1           # Allow 1 test call in half-open
  predictive:
    enabled: true
    headerName: "X-RateLimit-Reset"
    preResetBufferSeconds: 30   # Transition 30s before predicted reset
    maxPredictionWindow: 3600   # Don't trust predictions > 1 hour out
  monitoring:
    prometheusMetrics: true
    metricPrefix: "squad_circuit_breaker"
```

---

## Pattern 6: The Cascade Dependency Detector

The Predictive Circuit Breaker handles a single agent's relationship with the API. But agents don't work in isolation — they form dependency chains:

```
Ralph (CronJob)
  ├── scans board (GitHub API)
  ├── claims issues (GitHub API)
  ├── spawns Picard (GitHub Copilot API)
  │     └── creates PR (GitHub API)
  ├── spawns Data (GitHub Copilot API)
  │     └── creates PR (GitHub API)
  ├── spawns Worf (GitHub Copilot API)
  │     └── creates PR (GitHub API)
  └── spawns B'Elanna (GitHub Copilot API)
        └── creates PR (GitHub API)
```

If the GitHub API is rate-limited, there's no point spawning Picard, Data, Worf, or B'Elanna — they'll all fail at the "create PR" step regardless. The work Copilot does to analyze the issue and generate code is wasted tokens (and at ~760k tokens per round, those tokens aren't free).

The **Cascade Dependency Detector** uses BFS (breadth-first search) backpressure to solve this:

```
1. Build dependency graph: Ralph → [GitHub API, Copilot API]
                           Picard → [GitHub API]
                           Data → [GitHub API]
                           ...

2. Before spawning sub-agents, check all downstream dependencies
3. If ANY downstream dependency is circuit-broken, don't spawn

4. Propagate backpressure UP the graph:
   GitHub API rate-limited
     → Picard can't create PRs → don't spawn Picard
     → Data can't create PRs → don't spawn Data
     → Ralph can't claim issues → enter idle-watch
```

This is the distributed systems equivalent of "don't send soldiers into a battle you know they'll lose." If the upstream API is down, burning Copilot tokens on code generation is pure waste. Wait for the API to recover, then spawn the agents.

---

## The CronJob Pattern: Failure Is the Happy Path

One of the most counterintuitive lessons from this experiment: **for AI agents, `restartPolicy: Never` is the correct choice.**

In traditional Kubernetes deployments, you want pods to restart on failure. A web server crashes? Restart it. A worker dies? Restart it. The assumption is that the previous state was good and we want to get back to it.

AI agents are different. If an agent fails mid-task — maybe it was writing a PR and the API went down — restarting it doesn't help. It has no memory of what it was doing. It'll start fresh regardless. And if it failed because of a rate limit, restarting immediately will just fail again.

```yaml
# Ralph CronJob — the correct pattern for AI agents
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ralph-cronjob
  namespace: squad
spec:
  schedule: "*/5 * * * *"      # Every 5 minutes
  concurrencyPolicy: Forbid     # Never overlap
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 5
  jobTemplate:
    spec:
      backoffLimit: 0           # Never retry failed jobs
      activeDeadlineSeconds: 240 # Kill after 4 minutes (before next cycle)
      template:
        spec:
          restartPolicy: Never   # Don't restart — next CronJob handles it
          containers:
            - name: ralph
              image: ghcr.io/tamirdresher/squad-ralph:latest
              resources:
                requests:
                  cpu: 200m
                  memory: 2Gi
                limits:
                  cpu: "1"
                  memory: 3Gi
              env:
                - name: RALPH_MODE
                  value: "single-round"
                - name: MAX_PARALLEL_AGENTS
                  value: "4"
```

The key settings:

- **`restartPolicy: Never`**: If Ralph fails, don't restart it. Let it die. The next CronJob fires in 5 minutes with a clean slate.
- **`backoffLimit: 0`**: Don't retry the Job either. One attempt per cycle.
- **`concurrencyPolicy: Forbid`**: Never run two Ralphs simultaneously (we learned that lesson already).
- **`activeDeadlineSeconds: 240`**: Kill the pod after 4 minutes, well before the next 5-minute cycle starts. This prevents zombie pods from accumulating.

This pattern treats failure as *normal*. Each cycle is an independent attempt. If it works, great. If it doesn't, we'll try again in 5 minutes. No state to corrupt, no retries to manage, no `BackOff` loops to monitor.

---

## Resource Right-Sizing: The OOMKilled Lessons

The v10 diagnostic pod taught us something else painful: AI agent workloads have a very different resource profile than typical web services.

Our first attempt used `512Mi` memory limits — reasonable for a Node.js API server, catastrophic for a process that spawns 9 parallel AI agents:

```
NAMESPACE   NAME                    READY   STATUS      RESTARTS   AGE
squad       ralph-diag-v10-abc123   0/1     OOMKilled   0          4m
```

After several rounds of trial and error (and yes, each round was a 22-minute CronJob cycle — testing resource limits on AI agents is not fast), we landed on these resource profiles:

| Profile | CPU Request | CPU Limit | Memory Request | Memory Limit | Use Case |
|---------|-------------|-----------|----------------|--------------|----------|
| Minimal | 100m | 500m | 512Mi | 1Gi | Single agent, simple tasks |
| Standard | 200m | 1 | 2Gi | 3Gi | Ralph with 3-4 parallel agents |
| Burst | 500m | 2 | 3Gi | 4Gi | Diagnostic runs, 6+ agents |

The memory is the critical constraint. Each Copilot agent session consumes roughly 200-400Mi for context management, and that scales linearly with the number of parallel agents. CPU is more forgiving — the workload is mostly I/O-bound (waiting for API responses), so 200m CPU request with a limit of 1 core works fine for burst processing.

On a `Standard_D2_v2` (2 vCPU, 7GB RAM, ~$73/month):
- You can run **one Ralph pod with 4 parallel agents** comfortably
- You can run **two pods** if they're staggered (not simultaneous)
- You will **OOMKill** if you try three simultaneous pods

For production, I'd recommend `Standard_D4_v2` (4 vCPU, 14GB RAM) or using KEDA ScaledJobs so the node pool autoscaler can add capacity when needed.

---

## The Architecture: Putting It All Together

Here's how all the patterns compose into a rate-limit-aware AI agent architecture:

```
                          ┌──────────────────────┐
                          │    GitHub API         │
                          │  (rate limited)       │
                          └──────┬───────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                   │
              ▼                  ▼                   ▼
    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
    │  Rate Limit  │   │    Ralph     │   │   Copilot    │
    │  Exporter    │   │  (CronJob)   │   │    API       │
    │              │   │              │   │              │
    │ polls /rate_ │   │ 1. Check     │   │              │
    │ limit every  │   │    budget    │   │              │
    │ 30s          │   │ 2. Claim     │   │              │
    └──────┬───────┘   │    issues   │   │              │
           │           │ 3. Spawn    │   │              │
           ▼           │    agents   │   │              │
    ┌──────────────┐   └──────┬──────┘   └──────────────┘
    │  Prometheus  │          │
    │              │          ▼
    │  github_     │   ┌──────────────┐
    │  rate_limit_ │   │  Sub-Agents  │
    │  remaining   │   │ Picard, Data │
    └──────┬───────┘   │ Worf,B'Elanna│
           │           └──────┬───────┘
           ▼                  │
    ┌──────────────┐          ▼
    │    KEDA      │   ┌──────────────┐
    │              │   │ Predictive   │
    │ Scale only   │   │ Circuit      │
    │ when:        │   │ Breaker      │
    │ issues > 0   │   │              │
    │   AND        │   │ Half-Open-   │
    │ remaining    │   │ Imminent at  │
    │   > 500      │   │ T-30s before │
    └──────────────┘   │ reset        │
                       └──────────────┘
```

The data flow is:

1. **Rate Limit Exporter** polls GitHub every 30 seconds, exposes Prometheus metrics
2. **KEDA** watches both the issue queue depth and the rate limit metric — only scales up when both conditions are met
3. **Ralph CronJob** fires every 5 minutes, checks the API budget, and spawns only as many agents as the remaining quota allows
4. **Sub-agents** use cooperative claiming to avoid duplicate work
5. **Predictive Circuit Breaker** monitors rate limit reset headers and transitions to Half-Open just before the new window opens
6. **Cascade Dependency Detector** prevents spawning sub-agents when downstream APIs are circuit-broken

---

## The Numbers That Matter

After implementing these patterns, here's the before/after:

| Metric | Before (v10 naive) | After (rate-limit-aware) |
|--------|---------------------|--------------------------|
| PRs per hour | 10 (burst) then 0 (stalled) | 6-8 (sustained) |
| Rate limit violations | 12-15 per hour | 0-1 per hour |
| Wasted Copilot tokens | ~200k (failed PRs) | <10k |
| Agent idle time | 40 min/hour (backoff) | 5 min/hour (planned waits) |
| Recovery after limit | 5+ min (retry storms) | ~30s (predictive) |
| Infra cost/month | $73 (same) | $73 (same) |

The total throughput is lower — 6-8 PRs/hour sustained vs. 10 in a burst. But the burst was an illusion. Those 10 PRs came in 22 minutes, followed by 38 minutes of nothing. Sustained throughput over an hour was actually worse than the rate-limit-aware approach.

The real win is **wasted work elimination**. Before, about 25% of Copilot token usage was on tasks that would fail at the PR creation step due to rate limits. After, nearly every token spent results in a successfully created PR.

---

## Honest Reflection

I'll be the first to admit these patterns are overkill for most AI agent deployments. If you're running a single agent on a cron schedule, you don't need a Predictive Circuit Breaker or a Cascade Dependency Detector. Check the rate limit header, back off if needed, and you're fine.

But here's the thing: **this is where AI-native development is heading**. Today it's my hobby project with nine agents. In a year, teams will be running dozens of AI agents — code reviewers, test generators, documentation writers, security scanners — all hitting the same APIs. The thundering herd problem is coming for everyone building AI-powered dev tooling.

The patterns we discovered aren't revolutionary. Token bucket awareness is well-understood in API gateway design. Circuit breakers are a staple of microservice architectures. CronJobs with `restartPolicy: Never` are just... correct use of Kubernetes Job semantics.

What's new is applying these *distributed systems patterns to AI agent orchestration*. The agents aren't microservices — they're more like batch workers with unpredictable resource consumption and a shared dependency on heavily rate-limited APIs. Traditional Kubernetes scaling assumptions (scale on CPU, restart on crash) don't apply. You need to scale on *external quota* and fail on *external state*.

The infrastructure cost hasn't changed. It's still $73/month for a D2_v2 running 24/7. The difference is that every dollar now produces useful work instead of retry storms.

---

## What's Next

The obvious next step is multi-cluster rate limit coordination. Right now, all agents share a single GitHub token. If we move to per-agent tokens (via GitHub App installations), the rate limit math changes entirely — each agent gets its own 5,000 calls/hour. That's a post for another day.

There's also work to be done on **intelligent batching** — instead of spawning agents one-per-issue, batch related issues together so a single agent can create multiple related PRs with fewer API calls. The dependency graph is already there in the Cascade Dependency Detector; it just needs to be read in the other direction.

For now, Ralph runs every 5 minutes, checks his budget, does what he can, and goes to sleep. He doesn't complain about rate limits. He doesn't retry in panic. He just waits.

I've trained my AI team to be patient. I wish I could say the same about myself.

---

*This is Part 7 of the [Scaling AI-Native Software Engineering](/series/scaling-ai) series. [Part 1](/blog/2026/03/11/scaling-ai-part1-first-team) covers building the first AI squad. [Part 5](/blog/2026/03/25/scaling-ai-part5-kubernetes) covers the initial Kubernetes migration. The [Multi-Ralph post](/blog/2026/03/17/scaling-ai-rate-limits) covers the original rate limit catastrophe that started all of this.*
