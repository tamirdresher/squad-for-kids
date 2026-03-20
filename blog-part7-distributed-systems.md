---
layout: post
title: "The Cooperative ΓÇö Four More Distributed Systems Patterns Hiding in Your AI Team"
date: 2026-04-02
tags: [ai-agents, squad, github-copilot, distributed-systems, rate-limiting, conways-law, bulkheads, gossip, organization-theory, star-trek]
series: "Scaling AI-Native Software Engineering"
series_part: 7
---

> *"We've discovered that working together as a group is more efficient than working individually. We've even begun to re-establish our neural links."*
> ΓÇö Cooperative former Borg drones, Star Trek: TNG, "The Cooperative"

In [Part 5](/blog/2026/03/24/scaling-ai-part5-vinculum), I mapped eight distributed systems patterns my AI team forced me to relearn: consensus, leader election, idempotency, circuit breakers, backpressure, the Two Generals Problem, event sourcing, and CAP theorem. All classics. All things I thought I understood before running eight AI agents in parallel.

Then the GitHub rate limit hit. Again. And I realized there were more patterns still waiting to surface.

This post covers four more ΓÇö patterns that took a few weeks to emerge, because they need real load and a little bad luck to make themselves obvious. Each one is also a pattern from organization theory. That part surprised me.

---

## 1. The Token Bucket You're Sharing With Seven Strangers

GitHub's API gives you 5,000 requests per hour. That sounds generous. It isn't, when eight agents simultaneously query issue state, fetch PR diffs, read file contents, post comments, and open branches ΓÇö all sharing one service account.

Week three looked like this:

```
TAMIRDRESHER:  847 requests  (Picard decomposing tasks + Data working two PRs)
DEVBOX:       1,204 requests  (B'Elanna running Helm validation ├ù 6 charts)
AKS-POD-1:     892 requests
AKS-POD-2:    1,081 requests
AKS-POD-3:     976 requests
ΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇöΓÇö
Total:        5,000 requests in 23 minutes
```

Rate limited. All of them, simultaneously. The thundering herd hit the wall together.

This is the **Token Bucket** problem ΓÇö a network engineering classic. You have a bucket with fixed capacity. Tokens refill at a fixed rate. Each API call consumes one token. When the bucket empties, everyone waits.

The problem with eight concurrent consumers sharing one bucket: they'll drain it in lockstep unless they coordinate. The fix was a shared rate pool ΓÇö a JSON file acting as the bucket, with agents checking in before consuming:

```powershell
# From scripts/rate-limit-manager.ps1
# Priority tiers ΓÇö lower number = higher priority
$script:PriorityTiers = @{
    P0 = @{ Weight = 4; BaseDelayMs = 500  }  # Picard, Worf
    P1 = @{ Weight = 2; BaseDelayMs = 2000 }  # Data, B'Elanna, Seven
    P2 = @{ Weight = 1; BaseDelayMs = 5000 }  # Ralph, Scribe, Neelix
}

# Before every API call:
$allowed = Request-RateQuota -Api "github" -Tokens 1 -AgentId "Data" -Priority "P1"
if (-not $allowed) {
    Start-Sleep (Get-JitteredBackoff -Priority "P1" -Attempt $attempt)
    continue
}
```

The pool has zones: GREEN (>80% remaining), AMBER (<500 remaining), RED (<100 remaining). In AMBER, P2 agents pause. In RED, only P0 agents proceed ΓÇö Picard's architecture work and Worf's security checks don't stop for a quota crunch, but notification dispatch does.

We also deploy a KEDA scaler reading quota state from Prometheus:

```yaml
# github-rate-limit-exporter ΓÇö scale to zero when ratio Γëñ 10%
- type: prometheus
  metadata:
    query: min(github_rate_limit_remaining{resource="core"} /
               github_rate_limit_limit{resource="core"})
    threshold: "0.1"
```

The cluster scales itself to zero when the bucket is dry, and back up when it refills. That's not a workaround ΓÇö it's the token bucket made infrastructural.

**The pattern:** If multiple agents share a fixed-rate API budget, coordinate token consumption explicitly. Use priority tiers so high-value work (architectural decisions, security audits) gets quota before low-value work (notification dispatch). If you're on Kubernetes: KEDA can make scaling decisions based on quota remaining. The token bucket is one of the oldest ideas in network engineering. Your AI team rediscovers it the moment eight processes share one API key.

---

## 2. Conway's Law: Your Routing Table Is Your Architecture

Mel Conway wrote this in 1967: *"organizations which design systems are constrained to produce designs which are copies of the communication structures of those organizations."*

I hit this from the wrong direction.

I didn't design Squad's architecture first and then hire agents to match. I hired agents first ΓÇö Picard for architecture, Data for code, Worf for security, Seven for docs, B'Elanna for infrastructure ΓÇö and then watched the codebase organize itself around those communication structures.

Here's `.squad/routing.md`:

```markdown
| Work Type                              | Primary   |
|----------------------------------------|-----------|
| Architecture, distributed systems      | Picard    |
| K8s, Helm, ArgoCD, cloud native        | B'Elanna  |
| Security, Azure, networking            | Worf      |
| C#, Go, .NET, clean code               | Data      |
| Documentation, presentations, analysis | Seven     |
```

That routing table is an **org chart**. And Conway's Law says the org chart will appear in the codebase.

It did. The repo has hard seams between infrastructure (B'Elanna's domain), application code (Data's domain), security config (Worf's domain), and documentation (Seven's domain). These seams exist because different agents own those paths and rarely share context on cross-cutting changes. When a change crosses a seam ΓÇö say, a feature touching both infrastructure and security ΓÇö it surfaces as a PR conflict, because two agents with no shared communication channel made incompatible assumptions about the same component.

I didn't plan for those seams. They emerged from the routing rules. Conway was right: you don't create your architecture by drawing a diagram. You create it by deciding who talks to whom.

This has a practical implication: if you want a hard boundary between two subsystems, give them to different agents with no overlap. If you want tight integration, put them in the same agent's scope. The routing table is not an operational detail. It is an architectural statement.

**The pattern:** Treat your routing table as a first-class architectural decision. Every agent boundary is a service boundary ΓÇö it will accumulate its own interface, its own assumptions, its own drift. Design it deliberately, because the architecture will reflect the team structure whether you planned for it or not.

---

## 3. The Bulkhead: Why One Hanging Agent Shouldn't Stop the Collective

In shipbuilding, bulkheads are watertight partitions. One flooded compartment doesn't sink the ship. The Titanic's problem wasn't the iceberg ΓÇö the bulkheads weren't tall enough.

In microservices, the bulkhead pattern says: isolate failure domains so a slow or failing service can't exhaust shared resources and take down unrelated work.

My version: what happens when Seven hangs?

In early Squad, all agents ran as coroutines in the same PowerShell process. When Seven got stuck on a large research task ΓÇö waiting for an MCP tool that stopped responding ΓÇö the entire process blocked. Ralph couldn't check the issue queue. Picard couldn't decompose new work. The whole collective was hostage to one stuck drone.

The fix was process isolation:

```powershell
# From ralph-watch.ps1 ΓÇö agents run in isolated OS processes
$agentJob = Start-Process -FilePath "gh" `
    -ArgumentList "copilot", "suggest", "--agent", $agentName, $prompt `
    -PassThru `
    -RedirectStandardOutput $outputFile

# If the agent doesn't finish in 10 minutes, kill it
if (-not $agentJob.WaitForExit(600000)) {
    $agentJob.Kill()
    Write-Host "ΓÜí $agentName timed out ΓÇö killed. Other agents unaffected."
}
```

Seven's process can hang, crash, or burn 100% CPU. None of that touches Ralph's polling loop, Data's PR submission, or Worf's security check. The OS process boundary is the bulkhead.

The organizational parallel is direct: cross-functional teams with clear ownership boundaries. If your security team is blocked for a week, your infrastructure team shouldn't stop shipping. Team independence is organizational bulkheading. This is why Netflix built Hystrix and why Amazon decomposed into two-pizza teams ΓÇö not primarily for scaling, but for failure isolation.

**The pattern:** Run agents as isolated processes, not coroutines. Set explicit timeouts. The blast radius of any individual failure should be bounded to that agent's domain. Bulkheads don't prevent failure ΓÇö they contain it.

---

## 4. Gossip Protocol: How Knowledge Spreads Without a Registry

In a gossip protocol, each node periodically shares what it knows with a few neighbors. Those neighbors share with theirs. Within a few rounds, all nodes have the same knowledge ΓÇö without a central registry, without a broadcast, without synchronous coordination.

My version is `.squad/decisions/inbox/`.

When any agent makes a significant decision, it drops a Markdown file into this directory:

```
.squad/decisions/inbox/picard-keda-aks-implementation-plan.md
.squad/decisions/inbox/belanna-996-k8s-poc-decisions.md
.squad/decisions/inbox/data-1166-pcb.md
.squad/decisions/inbox/worf-drift-detection-disabled.md
```

Each file was written independently, by a different agent, without coordination. They don't need to know about each other. The inbox is the gossip node ΓÇö a shared medium where local knowledge accumulates for eventual global consumption.

Ralph's daily round processes the inbox:

```powershell
# From ralph-watch.ps1 ΓÇö gossip propagation
$inboxItems = Get-ChildItem ".squad/decisions/inbox/*.md"
foreach ($item in $inboxItems) {
    Add-Content ".squad/decisions.md" "`n---`n$(Get-Content $item -Raw)"
    Remove-Item $item  # Consume the gossip message
}
```

It's eventually consistent ΓÇö B'Elanna's decision won't reach Data until Ralph's next round (every five minutes). But it's reliable ΓÇö nothing gets lost, because the inbox is a write-ahead buffer. And it's auditable ΓÇö git history captures exactly when each piece of knowledge entered the collective.

The organizational parallel is working-group outputs, skip-level updates, cross-team architecture decision records ΓÇö knowledge that travels through informal channels, accumulating in a shared log until someone processes it into institutional memory. Gossip protocols in human organizations are called "communication." In distributed systems, they're called gossip. The mechanism is the same.

**The pattern:** You don't need a central registry for agents to learn what others decided. You need a gossip medium ΓÇö a shared append point where local decisions are published for eventual global consumption. The inbox is durable, auditable, and eventually consistent. For teams making decisions at human speed, this is sufficient. For distributed systems making decisions at machine speed, this is called Apache Cassandra.

---

## The Common Thread

These four patterns share something: they're all about **coordination without central control**.

Token buckets coordinate resource consumption without a global scheduler. Conway's Law means your routing table coordinates architectural decisions without anyone intending it. Bulkheads coordinate failure containment without a central orchestrator. Gossip protocols coordinate knowledge propagation without a registry.

The former Borg drones in "The Cooperative" re-established their neural links not because they needed a Queen, but because they found that coordination through shared protocols was more efficient than isolation. They built a cooperative ΓÇö multiple independent agents producing coherent output without a central supervisor.

That's exactly what a Squad is.

The useful reframe for anyone building multi-agent systems: when your AI team surprises you, ask "is this a distributed systems problem I recognize?" Nine times out of ten, it is. Someone already wrote the paper.

≡ƒûû

---

> ≡ƒôÜ **Series: Scaling AI-Native Software Engineering**
> - **Part 0**: [Organized by AI ΓÇö How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai)
> - **Part 1**: [Resistance is Futile ΓÇö Your First AI Engineering Team](/blog/2026/03/11/scaling-ai-part1-first-team)
> - **Part 2**: [When the Collective Meets Enterprise](/blog/2026/03/12/scaling-ai-part2-collective)
> - **Part 3**: [Unimatrix Zero ΓÇö When Your AI Squad Becomes a Distributed System](/blog/2026/03/18/scaling-ai-part3-distributed)
> - **Part 4**: [When Eight Ralphs Fight Over One Login](/blog/2026/03/17/scaling-ai-part4-race-conditions)
> - **Part 5**: [The Vinculum ΓÇö Eight Distributed Systems Lessons My AI Team Taught Me the Hard Way](/blog/2026/03/24/scaling-ai-part5-vinculum)
> - **Part 6**: [The Unicomplex ΓÇö AI Squads as Cloud-Native Kubernetes Citizens](/blog/2026/03/25/scaling-ai-part6-unicomplex)
> - **Part 7**: The Cooperative ΓÇö Four More Distributed Systems Patterns Hiding in Your AI Team ΓåÉ You are here

*Code examples are drawn from production Squad scripts at [tamirdresher_microsoft/tamresearch1](https://github.com/tamirdresher_microsoft/tamresearch1). Conway's Law is from 1967. Your AI team's org chart problem is older than you.*
