# Distributed Systems Patterns for AI-Native Teams

> **Research Report — Issue #678**
> **Author:** Seven (Research & Docs)
> **Date:** 2025-07-22
> **Status:** Complete

---

## 1. Executive Summary

**The thesis is simple: multi-agent AI teams ARE distributed systems.**

Every challenge we face scaling Squad across machines, repos, and contexts — task duplication, stale state, partial failures, coordination overhead — has been solved by distributed systems engineers over the past 40 years. We're not inventing new problems. We're running headfirst into Leslie Lamport's 1978 paper with LLM-shaped nodes instead of CPU-shaped ones.

This report maps 20+ distributed systems patterns to Squad's architecture. The results are striking:

- **10 patterns** already have direct Squad equivalents (some accidental, some deliberate)
- **6 patterns** have partial implementations with clear gaps
- **4+ patterns** are completely unimplemented and represent our biggest scaling bottlenecks

The mapping isn't academic. It gives us:

1. **A vocabulary** — instead of "Ralph sometimes does the same work twice," we say "we lack idempotency guarantees." The fix is obvious once the problem has a name.
2. **Proven solutions** — every gap maps to battle-tested implementations. We don't have to design from scratch.
3. **A prioritized roadmap** — the gap analysis tells us exactly what to build next.
4. **A blog series** — this framing ("your AI team is a distributed system") is the kind of insight that generates conference talks and mindshare.

---

## 2. Pattern Mapping Table

| # | Distributed Systems Pattern | Traditional Problem | Squad Equivalent | Gap | Priority |
|---|---|---|---|---|---|
| 1 | **Service Discovery** | Services finding each other dynamically | Agent roster in `.squad/agents/`, `squad.config.ts` | Static config only; no runtime discovery across machines | 🔴 High |
| 2 | **Saga Pattern** | Distributed transactions across services | Multi-agent task orchestration via Coordinator | No compensation logic; no rollback on partial failure | 🔴 High |
| 3 | **Event Sourcing** | Reconstructing state from history | `decisions.md` as append-only log; `decisions/inbox/` | No replay mechanism; no temporal queries | 🟡 Medium |
| 4 | **Leader Election** | Selecting a coordinator among peers | Picard as static lead; Ralph per-machine | No dynamic re-election; no cross-machine leader | 🔴 High |
| 5 | **Consensus** | Agreement among distributed nodes | Git-based task claiming (branch + PR) | No quorum; race conditions on concurrent claims | 🔴 High |
| 6 | **Service Mesh** | Transparent cross-service communication | Agent upstream inheritance in config | No sidecar proxy; no traffic management | 🟡 Medium |
| 7 | **Circuit Breaker** | Preventing cascading failures | Ralph failure detection + heartbeat | No formal open/half-open/closed states | 🟡 Medium |
| 8 | **Eventual Consistency** | Tolerating temporary state divergence | Cross-machine task queues (git-based) | No convergence guarantees; no conflict resolution | 🔴 High |
| 9 | **CAP Theorem** | Consistency/Availability/Partition tradeoffs | Implicit AP choice (availability over consistency) | No explicit tradeoff policy; no partition handling | 🟡 Medium |
| 10 | **Choreography vs Orchestration** | Centralized vs decentralized coordination | Hybrid — Coordinator orchestrates, agents react | No pure choreography mode; agents can't self-organize | 🟡 Medium |
| 11 | **Write-Ahead Log (WAL)** | Durability before state changes | `decisions/inbox/` write-before-act pattern | Not enforced; agents can act without logging | 🟡 Medium |
| 12 | **Heartbeat** | Failure detection | Ralph heartbeat file (`ralph-heartbeat.json`) | Single-machine only; no cross-machine heartbeat mesh | 🔴 High |
| 13 | **Gossip Protocol** | Decentralized information propagation | None | ❌ Not implemented | 🟡 Medium |
| 14 | **Sidecar Pattern** | Attaching cross-cutting concerns | Scribe as logging sidecar for all agents | Manual invocation; not automatic | 🟢 Low |
| 15 | **Bulkhead Pattern** | Isolating failure domains | Separate agent sessions per task type | No resource limits per agent; no isolation enforcement | 🟡 Medium |
| 16 | **Retry with Backoff** | Recovering from transient failures | Model fallback chains in `squad.config.ts` | Fallback is model-level only; no task-level retry | 🟡 Medium |
| 17 | **Idempotency** | Safe retries without side effects | None formal | ❌ Ralph can duplicate work across rounds | 🔴 High |
| 18 | **Dead Letter Queue** | Handling poison messages | None | ❌ Failed tasks vanish silently | 🟡 Medium |
| 19 | **Backpressure** | Preventing overload | None formal | ❌ No mechanism to slow task intake | 🟡 Medium |
| 20 | **Split Brain Resolution** | Handling network partitions | None | ❌ Two Ralphs on different machines can conflict | 🔴 High |
| 21 | **Consistent Hashing** | Even work distribution | None | ❌ No workload partitioning strategy | 🟢 Low |
| 22 | **Two-Phase Commit** | Atomic multi-party operations | Git commit + push (atomic per repo) | No cross-repo atomicity | 🟢 Low |

**Legend:** 🔴 High = Blocking multi-machine scaling. 🟡 Medium = Causes friction today. 🟢 Low = Nice to have.

---

## 3. Deep Dives

### 3.1 Service Discovery → Agent Discovery / Squad Mesh

**The distributed systems problem:**
In microservices, services start, stop, move, and scale. Hardcoded addresses break. Service discovery (Consul, Eureka, Kubernetes DNS) lets services find each other dynamically through a registry.

**What Squad has today:**
- Static agent roster in `.squad/agents/*.md` with charter files
- `squad.config.ts` defines routing rules and model assignments
- Agent capabilities declared in charter markdown files
- Manual invocation — the coordinator reads config and routes by convention

**What's missing:**
- **Runtime registration:** When a new agent spawns on Machine B, Machine A doesn't know about it. There's no registry broadcast.
- **Health-aware routing:** The coordinator can't distinguish between a healthy agent and one that's been failing for an hour.
- **Capability-based discovery:** Today, routing is by work type → agent name. A real discovery system would let agents advertise capabilities, and the coordinator would match tasks to capabilities dynamically.

**The fix (proposed):**
A lightweight `squad-registry.json` that agents write to on startup (with heartbeat updates), stored in a shared location (git repo, shared filesystem, or a lightweight HTTP service). The coordinator reads this registry before routing.

```
// .squad/registry/seven@machine-a.json
{
  "agent": "seven",
  "machine": "DESKTOP-ABC",
  "capabilities": ["documentation", "research", "analysis"],
  "status": "healthy",
  "lastHeartbeat": "2025-07-22T10:30:00Z",
  "currentTask": null
}
```

---

### 3.2 Saga Pattern → Multi-Agent Task Orchestration

**The distributed systems problem:**
A business transaction spans multiple services (e.g., reserve inventory → charge payment → ship order). If payment fails, inventory must be released. The Saga pattern breaks this into local transactions with compensating actions.

**Two flavors:**
- **Orchestration Saga:** A central coordinator tells each service what to do and manages rollback.
- **Choreography Saga:** Each service acts on events and publishes its own events. No central brain.

**What Squad has today:**
- The Coordinator (user in the CLI) orchestrates multi-agent work
- Tasks are assigned sequentially or in parallel via `task` tool
- Agents write results to files; the coordinator reads and decides next steps
- No formal compensation logic

**What's missing:**
- **Compensating actions:** If Seven writes a report but Data's code changes that the report references get reverted, the report isn't automatically updated.
- **Saga state machine:** No formal tracking of "Step 1 complete → Step 2 in progress → Step 3 pending."
- **Failure propagation:** If agent B fails after agent A completed, agent A doesn't know to roll back.

**The fix (proposed):**
A `task-saga.json` that tracks multi-step operations:

```
{
  "sagaId": "feature-678",
  "steps": [
    { "agent": "seven", "action": "write-research", "status": "completed", "compensate": "delete-file" },
    { "agent": "data", "action": "implement-pattern", "status": "in-progress", "compensate": "revert-branch" },
    { "agent": "troi", "action": "write-blog-post", "status": "pending", "compensate": "delete-draft" }
  ]
}
```

---

### 3.3 Event Sourcing → decisions.md as Append-Only Log

**The distributed systems problem:**
Instead of storing only current state, store every state change as an immutable event. The current state is derived by replaying the event log. This gives you full audit trail, temporal queries ("what was the state at 3pm?"), and the ability to rebuild state from scratch.

**What Squad has today:**
- `decisions.md` — an append-only log of team decisions with numbered entries
- `decisions/inbox/` — pending decisions written by agents before coordinator review
- Agent history files (`history.md`) — chronological work logs
- Git history — the ultimate append-only log

**What's missing:**
- **Structured events:** Decisions are free-form markdown, not structured data. You can't query "all decisions about authentication" without grepping.
- **Replay mechanism:** There's no way to "replay" decisions to reconstruct team state at a point in time.
- **Temporal queries:** "What did the team decide about deployment strategy last month?" requires manual log reading.
- **Event schema:** No enforced structure means events can't be machine-processed.

**What's surprisingly good:**
Git itself is an event-sourced system. Every commit is an immutable event. The current state of the repo is the result of replaying all commits. Squad already benefits from this — `decisions.md` changes are tracked in git, giving us the temporal dimension "for free." The gap is in making this queryable and actionable.

**The fix (proposed):**
Structured decision events alongside the human-readable markdown:

```
<!-- decisions.md entry -->
## Decision 45: Use CAP-AP model for cross-machine sync
...

<!-- decisions/events/decision-045.json -->
{
  "id": 45,
  "timestamp": "2025-07-22T10:00:00Z",
  "author": "picard",
  "category": "architecture",
  "tags": ["cross-machine", "consistency", "cap-theorem"],
  "summary": "Use AP model for cross-machine sync",
  "supersedes": [12],
  "status": "active"
}
```

---

### 3.4 Leader Election → Picard as Lead / Cross-Machine Ralph

**The distributed systems problem:**
In a cluster, one node must be the leader for coordination (accepting writes, making decisions). If the leader fails, a new one must be elected. Algorithms: Raft, Paxos, Bully, ZooKeeper's Zab.

**What Squad has today:**
- **Picard** is the static, pre-assigned leader for architecture decisions
- **Coordinator** (the human/CLI session) is the runtime leader for task routing
- **Ralph** runs independently per machine — each Ralph is "leader" of its own work queue
- No cross-machine coordination between Ralph instances

**What's missing:**
- **Dynamic re-election:** If Picard's session crashes, no other agent assumes the lead role.
- **Cross-machine Ralph:** Two Ralph instances on different machines can pick up the same ADO ticket, do the same work, and create conflicting PRs.
- **Leader lease / fencing:** No mechanism to prevent a "zombie" Ralph (one that lost connectivity but is still running) from doing stale work.

**The fix (proposed):**
A **leader lease** mechanism using git-based locking:

```
// .squad/locks/ralph-leader.json
{
  "leader": "ralph@DESKTOP-ABC",
  "leaseExpiry": "2025-07-22T11:00:00Z",
  "fencingToken": 42,
  "acquiredAt": "2025-07-22T10:00:00Z"
}
```

Before claiming a task, Ralph checks: Is my fencing token current? Has the lease expired? If another Ralph holds the lease, defer. This is the distributed systems **fencing token** pattern that prevents split-brain scenarios.

---

### 3.5 Consensus → Git-Based Task Claiming

**The distributed systems problem:**
Multiple nodes must agree on a single value (which node handles a request, what the next log entry is). Consensus algorithms (Paxos, Raft) ensure agreement even when nodes fail or messages are delayed.

**What Squad has today:**
- Git as the shared state (branch creation = claiming work)
- PR creation as "proposal" — reviewers "vote" by approving
- ADO work items with assignment field as single-writer lock
- `decisions/inbox/` as "proposals" that the coordinator accepts or rejects

**What's missing:**
- **Atomic claim:** Two agents can create branches for the same issue simultaneously. Git doesn't prevent this — it only prevents conflicting merges.
- **Quorum:** No requirement for multiple agents to agree before work begins.
- **Proposal rejection:** If an agent writes to `decisions/inbox/`, there's no formal "reject" mechanism. The coordinator simply doesn't merge it.

**The fix (proposed):**
A lightweight **claim protocol** using git:

1. Agent writes `.squad/claims/issue-678.json` with their ID and timestamp
2. Agent does `git pull` to check for conflicts
3. If another agent already claimed it (file exists with different author), back off
4. If claim is uncontested after N seconds, proceed

This is essentially a simplified **Raft log entry** using git as the replicated log.

---

### 3.6 Service Mesh → Upstream Agent Inheritance

**The distributed systems problem:**
A service mesh (Istio, Linkerd) provides transparent infrastructure between services: load balancing, retries, circuit breaking, observability, mTLS — without changing application code. The sidecar proxy handles it all.

**What Squad has today:**
- `squad.config.ts` routing rules that map work types to agents
- Model fallback chains (retry at the model level)
- Scribe as a cross-cutting logging concern
- Agent charters define interfaces (what each agent handles)

**What's missing:**
- **Transparent interception:** Agents talk to each other through the coordinator. There's no automatic retry, timeout, or circuit breaking on agent-to-agent calls.
- **Observability mesh:** No distributed tracing across agent calls. When Picard spawns Seven who spawns Data, there's no trace ID linking the chain.
- **Policy enforcement:** No way to say "Seven can only call Data, never Worf" or "all cross-agent calls must be logged."

**The fix (proposed):**
A Squad-level "mesh" config that wraps agent invocations:

```typescript
mesh: {
  policies: {
    timeout: '5m',           // kill agent if no output in 5 minutes
    retries: 2,              // retry failed agent calls twice
    circuitBreaker: {
      failureThreshold: 3,   // open circuit after 3 consecutive failures
      resetTimeout: '30m'    // try again after 30 minutes
    },
    tracing: true            // inject trace IDs into all agent contexts
  }
}
```

---

### 3.7 Circuit Breaker → Ralph Failure Detection

**The distributed systems problem:**
When a downstream service is failing, the circuit breaker stops sending requests to it. Three states:
- **Closed:** Normal operation, requests flow through
- **Open:** Service is failing, requests are immediately rejected
- **Half-Open:** After a timeout, allow one test request through

**What Squad has today:**
- Ralph tracks `consecutiveFailures` in its heartbeat file
- After 3+ failures, Ralph sends a Teams alert
- Model fallback chains (`claude-sonnet → gpt-5.2-codex → claude-sonnet-4`)
- `nuclearFallback` config option for last-resort model selection

**What's missing:**
- **Formal state machine:** Ralph doesn't stop trying after N failures. It keeps running rounds even if every round fails.
- **Per-agent circuit breakers:** If Seven keeps failing on documentation tasks, the coordinator should stop routing docs to Seven temporarily.
- **Recovery testing:** No "half-open" state where the system sends a lightweight probe to test if the failing agent has recovered.

**The fix (proposed):**
Add circuit breaker states to Ralph's round logic:

```
if (consecutiveFailures >= THRESHOLD) {
  state = 'OPEN'
  // Stop running rounds
  // Wait for resetTimeout
  // Then try ONE lightweight round (HALF-OPEN)
  // If it succeeds, go back to CLOSED
  // If it fails, go back to OPEN with longer timeout
}
```

---

### 3.8 Eventual Consistency → Cross-Machine Task Queue

**The distributed systems problem:**
In a distributed system, not all nodes see the same data at the same time. Eventual consistency guarantees that, given enough time without new updates, all nodes will converge to the same state. This is the tradeoff you accept when choosing availability over consistency (AP in CAP).

**What Squad has today:**
- Git as the shared state — `git pull` syncs state, but not in real-time
- ADO work items as a task queue — all machines see the same backlog
- `decisions.md` propagates through git pushes
- Each machine's Ralph polls independently on its own schedule

**What's missing:**
- **Convergence guarantees:** If Machine A claims a task and Machine B doesn't pull for 10 minutes, B might claim the same task.
- **Conflict resolution:** When two machines make conflicting changes, there's no automated merge strategy. Git's merge conflicts are the symptom; we need a resolution policy.
- **Anti-entropy mechanism:** No background process that periodically reconciles state across machines (the distributed systems equivalent of "read repair" or "merkle tree comparison").

**The fix (proposed):**
1. **Mandatory pull-before-claim:** Before any task assignment, agents must `git pull` and verify no claim exists.
2. **Timestamp-based conflict resolution:** Last-writer-wins with wall-clock timestamps (simple but has known issues with clock skew).
3. **Periodic reconciliation:** A "sync round" where all machines compare their local state and resolve differences.

---

### 3.9 CAP Theorem → Multi-Machine Squad Tradeoffs

**The distributed systems problem:**
The CAP theorem (Brewer, 2000) states that a distributed system can guarantee at most two of:
- **Consistency (C):** All nodes see the same data at the same time
- **Availability (A):** Every request receives a response
- **Partition Tolerance (P):** The system works despite network failures

Since network partitions are inevitable, the real choice is **CP** (consistent but sometimes unavailable) vs **AP** (available but sometimes inconsistent).

**Where Squad sits today: AP (implicitly)**

Squad chooses availability over consistency:
- Each machine's Ralph runs independently, even if it can't reach other machines
- Agents proceed with local state, even if it's stale
- Git pushes can fail; agents keep working locally
- The risk: duplicate work, conflicting decisions, stale context

**When we'd want CP instead:**
- Task claiming (two machines claiming the same task = wasted work)
- Decision-making (conflicting decisions from isolated machines = chaos)
- Deployment (two agents deploying different versions = outage)

**The fix (proposed):**
Make the AP vs CP choice explicit per operation type:

| Operation | Consistency Model | Rationale |
|---|---|---|
| Task claiming | CP | Duplicate work is expensive; block until consensus |
| Research/analysis | AP | Stale context is acceptable; keep working |
| Decision-making | CP | Conflicting decisions cause downstream chaos |
| Code changes | AP (with merge) | Git handles conflict resolution |
| Deployment | CP | Safety-critical; must have consensus |

---

### 3.10 Choreography vs Orchestration → Agent Autonomy vs Coordinator

**The distributed systems problem:**
- **Orchestration:** A central controller tells each service what to do, when, and in what order. Simple to understand, but the orchestrator is a single point of failure and bottleneck.
- **Choreography:** Each service knows what to do when it sees certain events. No central brain. Scales better, but harder to debug and monitor.

**What Squad has today: Primarily Orchestration**

The Coordinator (human in the CLI) is the orchestrator:
- Reads the situation, decides which agents to invoke
- Routes tasks explicitly: "Seven, write the docs. Data, fix the code."
- Manages dependencies: "Wait for Data to finish before starting Seven."
- Ralph adds a layer of autonomous choreography: it polls the backlog and self-assigns work

**The tension:**
Squad is moving toward choreography (Ralph acting autonomously), but the infrastructure assumes orchestration (coordinator making all decisions). This creates friction:
- Ralph can't react to events from other agents
- Agents can't trigger other agents directly
- There's no event bus for "Seven published a report" → "Troi automatically starts a blog post"

**The fix (proposed):**
A **hybrid model** with explicit boundaries:

| Mode | When to use | Example |
|---|---|---|
| Orchestration | Complex multi-agent work with dependencies | Feature development across 3+ agents |
| Choreography | Routine, independent work | Ralph picks up bug fixes; Scribe logs decisions |
| Mixed | Orchestrated saga with choreographed sub-steps | Coordinator starts feature; agents self-coordinate on sub-tasks |

An event file pattern to enable choreography:

```
// .squad/events/seven-report-published.json
{
  "event": "report-published",
  "source": "seven",
  "timestamp": "2025-07-22T10:30:00Z",
  "payload": { "file": "distributed-systems-patterns.md" },
  "subscribers": ["troi", "neelix"]
}
```

---

## 4. Gap Analysis

### Critical Gaps (Blocking Multi-Machine Scaling)

| Gap | Pattern Needed | Impact | Effort |
|---|---|---|---|
| **Duplicate task execution** | Idempotency + Consensus | Two Ralphs do the same work, create conflicting PRs | Medium |
| **No cross-machine awareness** | Service Discovery + Heartbeat | Machines operate in isolation; no coordination | High |
| **Split-brain scenarios** | Leader Election + Fencing Tokens | Zombie agents do stale work after reconnecting | High |
| **No conflict resolution** | Eventual Consistency + CRDTs | Git merge conflicts require manual intervention | Medium |
| **Task loss on failure** | Dead Letter Queue + WAL | Failed tasks disappear; no retry, no audit trail | Medium |

### Important Gaps (Causing Daily Friction)

| Gap | Pattern Needed | Impact | Effort |
|---|---|---|---|
| **No formal retry logic** | Retry with Backoff | Agent failures require manual re-invocation | Low |
| **No agent health tracking** | Circuit Breaker | Coordinator routes to failing agents | Low |
| **No event-driven reactions** | Choreography / Event Bus | Agents can't auto-trigger downstream work | Medium |
| **No distributed tracing** | Service Mesh / Correlation IDs | Multi-agent debugging is manual log-reading | Medium |
| **No backpressure** | Backpressure / Rate Limiting | Ralph can overwhelm the system in rapid rounds | Low |

### Nice-to-Have Gaps (Future Optimization)

| Gap | Pattern Needed | Impact | Effort |
|---|---|---|---|
| **Uneven work distribution** | Consistent Hashing | Some agents are overloaded, others idle | Medium |
| **No cross-repo atomicity** | Two-Phase Commit / Saga | Multi-repo changes can partially fail | High |
| **No state snapshots** | Snapshots + WAL | State reconstruction requires full replay | Medium |
| **No formal SLAs** | SLA / Timeout patterns | No expectation-setting on agent response times | Low |

### Recommended Implementation Order

1. **Idempotency keys for Ralph** — Lowest effort, highest impact. Give each task a unique ID; before starting, check if that ID has been completed.
2. **Cross-machine heartbeat** — Extend Ralph's heartbeat to a shared location. Instant visibility into the fleet.
3. **Git-based claim protocol** — Atomic task claiming to prevent duplicate work.
4. **Circuit breaker for agents** — Stop routing to failing agents; auto-recover.
5. **Event bus (file-based)** — Enable choreography for routine work.
6. **Distributed tracing** — Correlation IDs across agent spawns.

---

## 5. Blog Series Outline

### "Distributed Systems Patterns for AI Teams"

A 5-part blog series mapping decades of distributed systems wisdom to the emerging challenge of multi-agent AI coordination.

---

**Part 1: "Your AI Team Is a Distributed System (And That's Great News)"**
- The insight: multi-agent AI teams face the exact same problems as microservices
- Why this matters: 40 years of solutions are waiting to be applied
- Quick tour of the pattern mapping table
- "We accidentally built half of these patterns already"
- Hook: "The problems you're hitting aren't new. The solutions aren't either."

**Part 2: "Consensus, Claiming, and Why Two Agents Doing the Same Work Is a Distributed Systems Bug"**
- Deep dive: Consensus algorithms → Git-based task claiming
- Deep dive: Idempotency → Ralph's duplicate work problem
- Deep dive: Leader Election → Cross-machine Ralph coordination
- Code examples: implementing a claim protocol with git
- The "fencing token" pattern for zombie agent prevention

**Part 3: "Event Sourcing Your Decisions (Or: Why decisions.md Is More Powerful Than You Think)"**
- Deep dive: Event Sourcing → decisions.md as append-only log
- Deep dive: Write-Ahead Log → the "write before you act" pattern
- Deep dive: Saga Pattern → Multi-agent task orchestration with rollback
- How git gives you event sourcing for free (and where it falls short)
- Temporal queries: "What did the team decide about X last month?"

**Part 4: "The Service Mesh Your Agents Need (Observability, Circuit Breakers, and Backpressure)"**
- Deep dive: Service Mesh → transparent agent infrastructure
- Deep dive: Circuit Breaker → stop routing to failing agents
- Deep dive: Backpressure → preventing Ralph from overwhelming the system
- Deep dive: Heartbeat → cross-machine health monitoring
- Building observability into multi-agent systems

**Part 5: "CAP Theorem for AI Teams: When to Choose Consistency Over Speed"**
- Deep dive: CAP Theorem → multi-machine Squad tradeoffs
- Deep dive: Eventual Consistency → cross-machine task queues
- Deep dive: Choreography vs Orchestration → agent autonomy spectrum
- The "AP for research, CP for deployment" principle
- Future: gossip protocols for decentralized agent clusters
- Closing: the roadmap from "AI team" to "AI distributed system"

---

## 6. References

### Foundational Papers & Books

- **Lamport, L.** (1978). "Time, Clocks, and the Ordering of Events in a Distributed System." *Communications of the ACM*.
- **Brewer, E.** (2000). "Towards Robust Distributed Systems" (CAP Theorem). *PODC Keynote*.
- **Gilbert, S. & Lynch, N.** (2002). "Brewer's Conjecture and the Feasibility of Consistent, Available, Partition-Tolerant Web Services." *ACM SIGACT News*.
- **Ongaro, D. & Ousterhout, J.** (2014). "In Search of an Understandable Consensus Algorithm" (Raft). *USENIX ATC*.
- **Garcia-Molina, H. & Salem, K.** (1987). "Sagas." *ACM SIGMOD*.
- **Joshi, U.** (2024). *Patterns of Distributed Systems*. Addison-Wesley (Fowler Signature Series).

### Online Pattern Catalogs

- **Martin Fowler's Patterns of Distributed Systems** — https://martinfowler.com/articles/patterns-of-distributed-systems/
- **Microsoft Azure Architecture Patterns** — https://learn.microsoft.com/en-us/azure/architecture/patterns/
- **Chris Richardson's Microservices Patterns** — https://microservices.io/patterns/
- **IBM Microservices Design Patterns** — https://www.ibm.com/think/topics/microservices-design-patterns

### Articles Referenced

- "12 Essential Distributed System Design Patterns Every Architect Should Know" — https://antondevtips.com/blog/12-essential-distributed-system-design-patterns-every-architect-should-know
- "Distributed Systems Design: Patterns and Practices" — https://omid.dev/2024/06/05/distributed-systems-design-patterns-and-practices/
- "Distributed Systems Patterns and Anti-Patterns: A Comprehensive Survey" — https://wjaets.com/sites/default/files/fulltext_pdf/WJAETS-2025-0197.pdf
- "Resilient Microservices: A Systematic Review of Recovery Patterns" — https://arxiv.org/html/2512.16959v1
- "Service Orchestration vs. Choreography" — https://umamahesh.net/service-orchestration-vs-choreography/

### Squad Architecture Sources

- `squad.config.ts` — Squad routing, model fallback chains, and governance configuration
- `.squad/agents/` — Agent charter files defining roles, capabilities, and boundaries
- `.squad/decisions/` — Append-only decision log with inbox pattern
- `ralph-watch.ps1` — Ralph's monitoring, heartbeat, and failure detection implementation

---

*Seven out. The docs are done. The patterns are mapped. The gaps are named. Now build.*
