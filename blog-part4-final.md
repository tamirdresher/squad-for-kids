---
layout: post
title: "When Eight Ralphs Fight Over One Login — Real Distributed Systems Problems in AI Agent Teams"
date: 2026-03-21
tags: [ai-agents, squad, github-copilot, distributed-systems, auth-race, rate-limiting, star-trek, borg]
series: "Scaling AI-Native Software Engineering"
series_part: 4
---

> *"We have engaged the Borg."*
> — Captain Picard, Star Trek: First Contact

In [Part 3](/blog/2026/03/18/scaling-ai-part3-distributed), I showed you how Squad became a distributed system — multiple machines, git-based task queues, heartbeat-driven failure detection. It sounded clean. Architecturally elegant. Like I had things under control.

I did not have things under control.

This post is about the week everything broke — and how every bug we hit turned out to be a textbook distributed systems problem that the industry has been fighting for decades. Auth races, rate limits, stale locks, notification firehose, write conflicts. We built solutions for all of them. Some of them were clever. Most of them were ugly-but-working. A few of them are still unsolved.

No hypotheticals. No "imagine if." Every story in this post links to a real commit, a real issue, or a real Teams notification that woke me up.

---

## Thirty-Seven Consecutive Failures

Sunday, March 16th, 2026. I'm trying to have a quiet afternoon. My phone lights up with a Teams notification:

```
⚠️ Ralph Watch Alert — TAMIRDRESHER (tamresearch1)
Ralph watch has experienced 15 consecutive failures
Round: 15
Consecutive Failures: 15
Last Exit Code: 1
Timestamp: 2026-03-16 13:17:12
```

Fifteen rounds. Every five minutes, Ralph wakes up, tries to do work, fails, and goes back to sleep. Something is very wrong.

I look at it, fix what I think is the problem (wrong `gh auth` account — Ralph was set to `tamirdresher` instead of `tamirdresher_microsoft`), and go back to my coffee. Twenty minutes later:

```
⚠️ Ralph Watch Alert — TAMIRDRESHER (tamresearch1)
Ralph watch has experienced 37 consecutive failures
Round: 37
Consecutive Failures: 37
Last Exit Code: 1
Timestamp: 2026-03-16 15:14:28
```

**Thirty-seven.** Each failure a full five-minute cycle. Nearly three hours of Ralph spinning in the void.

The root cause? Not a bug in Ralph. Not a code error. Not a network issue. It was a **distributed systems classic**: shared mutable global state.

### The Auth Race

Here's the problem. I have eight Ralph instances — one for each repo I manage. Every Ralph runs `ralph-watch.ps1` in a loop. And every Ralph needs to talk to GitHub via the `gh` CLI.

The `gh` CLI has a **global** auth state. One file. `~/.config/gh/hosts.yml`. When Ralph for repo A calls `gh auth switch --user tamirdresher`, it changes the auth state for **every** process on the machine. Ralph for repo B — which needs `tamirdresher_microsoft` — picks up the wrong credentials and fails. Repo C's Ralph switches back. Repo A fails. And so on.

Eight processes. One shared resource. No coordination. This is the **leader election problem** without an election. Or more precisely, it's the **distributed locking problem** — except nobody's locking anything.

Here's what the failure pattern looks like when you have 8 Ralphs fighting over `~/.config/gh/hosts.yml`:

```
Ralph-A: gh auth switch --user tamirdresher       ✅ (writes to global state)
Ralph-B: gh auth switch --user tamirdresher_microsoft  ✅ (overwrites A's auth)
Ralph-A: gh api repos/tamirdresher/...            ❌ (now using B's credentials!)
Ralph-C: gh auth switch --user tamirdresher       ✅ (overwrites B's auth)
Ralph-B: gh api repos/tamirdresher_microsoft/...  ❌ (now using C's credentials!)
...cascading failures...
```

The fix? **Process-local environment variables.** Instead of switching the global auth state, each Ralph reads the token for the right account and sets it as a process-local `GH_TOKEN` env var. No global mutation. No race.

This is in `ralph-watch.ps1` today:

```powershell
# Step -1: Self-healing — set GH_TOKEN for this process based on repo remote
# This avoids fighting over global gh auth state with other repo Ralphs
$remoteUrl = & git remote get-url origin 2>&1 | Out-String
$requiredAccount = if ($remoteUrl -match "tamirdresher_microsoft") {
    "tamirdresher_microsoft"
} else { "tamirdresher" }
$token = & gh auth token --user $requiredAccount 2>&1 | Out-String
if ($token -and $token.StartsWith("gho_")) {
    $env:GH_TOKEN = $token  # Process-local. No global mutation.
}
```

In distributed systems terms, we replaced a **global lock** (shared config file) with **partition-local state** (per-process env var). Each process carries its own identity. No coordination needed.

**The distributed systems pattern:** This is exactly what happens when multiple microservices share a single database connection pool, or when Kubernetes pods fight over a ConfigMap. The fix is always the same — **isolate the state**. Give each process its own credentials. Don't share mutable global state across concurrent actors.

---

## The Stale Lock That Wouldn't Die

While debugging the 37-failure cascading auth crash, I found a bonus problem. Ralph wouldn't start because a lock file existed from a previous instance — a PID that was long dead, from two days earlier.

```json
{
  "pid": 40544,
  "started": "2026-03-14T09:12:04",
  "directory": "C:\\temp\\tamresearch1"
}
```

PID 40544 didn't exist anymore. The process had crashed or been killed. But the lockfile was still there, proudly guarding nothing. This is the **failure detection problem** — how do you know if a process that holds a lock is actually alive?

Traditional distributed systems solve this with **heartbeats** and **lease-based locking**. ZooKeeper ephemeral nodes disappear when the session ends. etcd leases expire if not renewed. Consul health checks fail after a timeout.

Our solution was a three-layer guard in `ralph-watch.ps1`:

1. **System-wide named mutex** — `Global\RalphWatch_tamresearch1` — prevents any duplicate on the same machine. If the process crashes, the OS releases the mutex. The `AbandonedMutexException` catch handles ungraceful exits.
2. **Process scan** — `Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'ralph-watch' }` — finds and kills any stale zombie Ralphs for this specific repo directory.
3. **Lockfile** — for external tools (like squad-monitor) to read status. Cleaned up on exit via `Register-EngineEvent PowerShell.Exiting` and a `trap` block.

Is this elegant? No. It's three mechanisms doing the job of one distributed lock. But it works. Mutex covers the normal case. Process scan handles abandoned mutexes. Lockfile exists for observability. Defense in depth.

**The distributed systems pattern:** This is the same problem that every leader election algorithm solves. Chubby at Google, ZooKeeper at Yahoo, etcd in Kubernetes. The lesson: **lock files without health checks are lies**. A lock is only valid if you can verify the holder is alive.

---

## The Notification Firehose

By mid-March, the squad was sending a lot of Teams notifications. Ralph's failure alerts. Neelix's daily tech news. Issue update summaries. Security findings from Worf.

All of them going to **one channel**.

My `tamir-squads-notifications` channel became a wall of noise. Important alerts — the 37-failure cascades — drowned in daily tech briefings and routine PR summaries. I was getting 20+ notifications a day and ignoring all of them. Which is exactly what happens when you dump every service's logs into one file and call it "logging."

The fix was a **routing map**. We created `teams-channels.json` — a config file that maps notification types to specific channels:

```json
{
  "channels": {
    "notifications": "tamir-squads-notifications",
    "tech-news": "Tech News",
    "dk8s": "DK8S Platform"
  }
}
```

Agents tag their notifications with `CHANNEL:` metadata. The notification function routes them to the right destination. Tech news goes to Tech News. Failure alerts go to the main notification channel. Platform-specific updates go to the platform channel.

**The distributed systems pattern:** This is **pub-sub with topic routing**. Kafka topics. RabbitMQ routing keys. AWS SNS topic filtering. The lesson is the same one the industry learned twenty years ago: **a single message queue for everything is a recipe for missed alerts**. Route by type.

But we also hit an accidental comedy along the way. When creating the channels, we discovered there were **two** teams with nearly identical names — "Squad" (a colleague's team) and "squads" (my team). The notification ended up in the wrong team's new channel. We had to delete it and recreate it. In distributed systems, this is the **service discovery problem** — when names that look similar route traffic to the wrong destination, DNS fails quietly and production burns. We learned this the same way everyone learns it: after the fact.

---

## When Two Agents Write to the Same File

Here's a scenario that kept biting us: I tell the team to triage a batch of issues. Picard decomposes. Four agents work in parallel — B'Elanna on infra issues, Worf on security issues, Data on code fixes, Seven on documentation. They each make decisions. They each want to record those decisions in `.squad/decisions.md`.

Two agents finish at the same time. Both try to commit. **Merge conflict.**

This is the **concurrent write problem** — the same reason you can't have two microservices writing to the same database row without a coordination protocol. The solutions in distributed systems are well-known: optimistic concurrency (version vectors, CAS operations), or CRDTs (conflict-free replicated data types) that merge automatically.

We solved it two ways.

### Solution 1: merge=union (The Poor Man's CRDT)

Git has a little-known merge strategy called `union`. For append-only files, it keeps all lines from both sides of a merge. No conflicts. Ever. Our `.gitattributes`:

```
.squad/decisions.md merge=union
.squad/agents/*/history.md merge=union
.squad/log/** merge=union
.squad/orchestration-log/** merge=union
```

This works because these files are **append-only logs**. Decisions get added. History entries get added. Log lines get added. Nothing gets edited or deleted. When two agents append to the same file on different branches, `merge=union` just concatenates both additions. This is literally how CRDTs work — G-Sets (grow-only sets) and append-only logs are the simplest form of conflict-free replication.

### Solution 2: The Drop-Box Pattern (Inbox Merging)

But `merge=union` has limits. It doesn't help when agents need to write **structured** decisions — things that need formatting, context, and cross-references. So we built the **drop-box pattern**.

Each agent writes their decision to their own file in `.squad/decisions/inbox/`:

```
.squad/decisions/inbox/belanna-nap-system-pods.md
.squad/decisions/inbox/worf-defender-fleet-msg.md
.squad/decisions/inbox/data-350-closure.md
```

No conflicts possible — each file has a unique name. Then Scribe (the documentation agent) periodically sweeps the inbox, merges the individual decisions into the canonical `decisions.md`, and deletes the inbox files. This is **eventual consistency** with a merge agent. The same pattern as event sourcing with a projection — individual events are immutable, the aggregate view is materialized asynchronously.

**The distributed systems pattern:** `merge=union` is a G-Set CRDT. The drop-box pattern is event sourcing with ordered projection. Both solve the same underlying problem: **how do concurrent writers avoid coordination without losing data?**

---

## The Prompt That Became a Command Name

Issue #704 was one of those bugs that makes you question your understanding of how computers work.

Five of my eight Ralphs were failing every single round. Same error. Same pattern. The `ralph-watch.ps1` script uses `Start-Process` to launch the Copilot CLI session. And the prompt — a 7KB multiline string with instructions like "MAXIMIZE PARALLELISM" and "MULTI-MACHINE COORDINATION" — was being passed as an argument.

Here's what PowerShell did with that: it treated the **entire 7KB prompt as the command name**. Not the argument. The command. Windows tried to find an executable called `"Ralph, Go! MAXIMIZE PARALLELISM: For every round, identify ALL actionable issues and spawn agents..."` and — shockingly — could not find one.

This is a **serialization/marshalling problem**. When you pass structured data (a multiline prompt) through a transport layer that doesn't preserve structure (command-line argument parsing), the data gets corrupted. Same thing happens when you pass JSON through a shell pipeline, or when you serialize a protobuf through a REST boundary that expects plain text.

The fix: write the prompt to a temp file, pass the file path as the argument. Classic indirection — when you can't pass the data directly, pass a reference to the data.

```powershell
$promptFile = [System.IO.Path]::GetTempFileName()
$prompt | Out-File -FilePath $promptFile -Encoding utf8
agency copilot --yolo --prompt-file $promptFile
```

**The distributed systems pattern:** This is **message serialization**. The same problem gRPC solves with protocol buffers, the same problem Kafka solves with schema registry. When your transport layer can't handle your message format, you need an intermediate representation. Or, as I prefer to think of it: when the transporter can't dematerialize a seven-kilobyte monologue, you fold it into a briefcase first.

---

## Rate Limits: The Problem We Haven't Solved

I'll be honest about this one because I don't have a clean answer yet.

Eight Ralphs running every five minutes. Each round, Ralph checks open issues, reads PRs, reviews comments, spawns sub-agents. Each sub-agent might make 10–30 GitHub API calls. Multiply that by 8 repos, 12 rounds per hour.

That's potentially **thousands of API calls per hour** against GitHub's rate limit of 5,000 per hour per authenticated user.

We hit it. Multiple times. Ralph finishes a productive round, and the next round fails because we've burned through the hourly budget. The error is silent — `gh api` just returns a 403 with a `retry-after` header that nobody reads.

A Solution Architect I connected with recently crystallized the scale problem perfectly:

> *"My goal is to collaborate with this team on defining an operating model that allows squad-based application modernization to scale to 100+ clients, with parallel execution, strict client isolation, and shared learning by design."*

100+ clients. If each client has 8 Ralphs doing 30 API calls per round at 12 rounds per hour — that's 288,000 API calls per hour. GitHub's rate limit laughs at you.

The solutions in distributed systems are well-known: **token bucket rate limiting**, **exponential backoff**, **request coalescing** (batch multiple API calls into one), **read-through caching** (cache issue/PR state locally, only fetch deltas). We've started on some of these — the email system now has retry/backoff after hitting send rate limits. But the broader API rate limit problem at 100+ scale? Still open.

**The distributed systems pattern:** This is **resource exhaustion in a shared-nothing architecture**. Each Ralph is independent, but they share one scarce resource — the API rate limit. Without a **global rate limiter** (a token bucket shared across processes) or **request deduplication** (caching), each process optimizes locally and they collectively exceed the global limit. The Tragedy of the Commons, but for API calls.

---

## What I Learned This Week

Here's the thing that surprised me most: I didn't set out to study distributed systems. I was just trying to get my AI team to work. But every bug we hit this week maps 1:1 to a problem the industry has been solving for decades.

| Problem We Hit | Classic Pattern | What We Built |
|---|---|---|
| 8 Ralphs fighting over `gh auth` | Leader election / distributed locking | Process-local `GH_TOKEN` env vars |
| Dead lockfile blocking restart | Failure detection / heartbeats | Mutex + process scan + lockfile triple guard |
| All notifications in one channel | Pub-sub topic routing | `teams-channels.json` routing map |
| Two agents writing `decisions.md` | CRDTs / eventual consistency | `merge=union` + drop-box inbox pattern |
| 7KB prompt mangled by shell | Message serialization | Temp file indirection |
| API rate limits at scale | Token bucket / request coalescing | Still unsolved at 100+ scale |
| Wrong Teams channel (name collision) | Service discovery | Manual resolution (for now) |

The parallel is uncanny. When you have multiple independent processes that need to coordinate — whether they're microservices, Kubernetes pods, or AI agents — you hit the same fundamental problems. And the solutions are the same fundamental patterns.

**We're not building something new.** We're rediscovering distributed systems, one bug at a time. Leslie Lamport's papers from the 1970s? They're about our Tuesday afternoon. The CAP theorem? It explains why our `decisions.md` file uses eventual consistency instead of strong consistency. The Byzantine Generals Problem? It's what happens when one agent's history file gets corrupted and other agents make decisions based on bad data.

The AI part is just the compute engine. The hard part — the part that keeps breaking — is the coordination. And that's a problem humanity has been working on since we first tried to get two computers to agree on anything.

---

## Honest Reflection

I've been staring at these 37-failure cascades for a while now, and here's the uncomfortable truth: none of this was fun to debug. Distributed systems failures are mean. They're intermittent. They're time-dependent. The thing that worked on round 14 fails on round 15 because some other process touched a file thirty seconds ago.

And yet — the bugs were instructive in a way that clean systems never are. When something fails in a distributed setting, it fails *specifically*, in ways that map to textbook patterns with names and solutions and twenty years of prior art. That's actually reassuring. You're not the first person to have eight processes fight over a shared file. You're just the latest one.

The other thing I'll say honestly: the system is more robust *because* it broke. The mutex + process scan + lockfile triple guard is overkill for a personal project. But it's the kind of overkill that means Ralph hasn't had a stale lock failure since. Sometimes the three-layer solution is the right one, even if it's inelegant. Real distributed systems are full of three-layer solutions with small embarrassing comments in the code.

My AI agents didn't break because AI is fragile. They broke because distributed systems are hard. The same way every distributed system is hard, for the same reasons, with the same solutions. That's oddly comforting.

---

## What's Next

In Part 5, I'll talk about what happens when your AI team starts scaling beyond your control — when agents create their own sub-issues, when Ralphs on different machines start working on the same problem without knowing it, and when you realize the governance you designed for a team of seven agents doesn't hold when the number starts climbing. The Borg had assimilation protocols, a Queen, and a Collective consciousness to keep everyone aligned. What do we have?

Governance for entities that don't sleep. That's Part 5.

But first, I need to go fix a rate limiter.

The distributed problems don't stop when you solve the auth race. They just get more interesting. 🟩⬛

---

> 📚 **Series: Scaling AI-Native Software Engineering**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai)
> - **Part 1**: [Resistance is Futile — Your First AI Engineering Team](/blog/2026/03/11/scaling-ai-part1-first-team)
> - **Part 2**: [From Personal Repo to Work Team — Scaling Squad to Production](/blog/2026/03/12/scaling-ai-part2-collective)
> - **Part 3**: [Unimatrix Zero — When Your AI Squad Becomes a Distributed System](/blog/2026/03/18/scaling-ai-part3-distributed)
> - **Part 4**: When Eight Ralphs Fight Over One Login ← You are here
> - **Part 5**: Governance for Entities That Don't Sleep — coming soon

---

*All code, commit hashes, issue numbers, and error messages in this post are real. The 37 consecutive failures happened on March 16, 2026. I'm still mad about it.*
