---
layout: post
title: "Your AI Team Hit a 429 — Rate Limiting as a Management Philosophy"
date: 2026-03-17
author: Tamir Dresher
tags: [ai-agents, squad, rate-limiting, distributed-systems, kanban, management, engineering-patterns]
series: "CS & Management Parallels in AI Agent Teams"
series_part: 1
---

> *"The avalanche has already started. It is too late for the pebbles to vote."*
> — Ambassador Kosh, Babylon 5

Here's something they don't tell you when you build your first AI agent team: the hardest problems aren't about prompting. They're not about model selection. They're not even about getting agents to write decent code.

The hardest problems are the ones you already solved ten years ago — in distributed systems.

I run a team of AI agents built on [Squad](https://github.com/bradygaster/squad) — Picard orchestrates, Data writes code, Worf handles security, Seven does research, and Ralph watches my GitHub board 24/7 so I don't have to. If you've read my [earlier posts](/blog/2026/03/11/scaling-ai-part1-first-team), you know the setup. What I haven't told you yet is how spectacularly it fell apart the first time all seven agents decided to do things *at the same time*.

This is a story about rate limits. About HTTP 429s. About the moment I realized that managing AI agents is just distributed systems engineering wearing a management hat.

---

## The Morning Everything Tried to Send an Email

It was a Tuesday. I know this because the email logs told me later, and because Tuesdays are when my squad runs its weekly summary cycle — research reports get generated, status updates go out, and Neelix (my news agent) tries to deliver briefings to Teams and email simultaneously.

Here's what happened: I had six agents finishing tasks around the same time. Each one, independently, decided it needed to send an email notification. Research report done? Email. PR merged? Email. Security scan complete? Email. Six agents. Six emails. All within about ninety seconds.

Gmail said no.

```
SMTP 421 4.7.28 Too many login attempts. Please try again later.
```

Not a hard failure — a *throttle*. Gmail saw six rapid-fire SMTP connections from the same account and treated it like a credential-stuffing attack. Which, from Gmail's perspective, was a perfectly reasonable assumption. From my perspective, it meant three of those emails vanished into the void and the agents reported success because the connection was established before the throttle kicked in.

I didn't find out until hours later when I noticed the weekly research report never arrived.

---

## You've Seen This Before

If you've built microservices — or honestly, if you've ever called a REST API in anger — you recognize this immediately. It's a rate limit. HTTP 429 Too Many Requests. The server is protecting itself from being overwhelmed, and your client needs to back off.

The thing is, I *knew* this. I've written about reactive programming, about backpressure, about handling load in distributed systems. I literally wrote [a book](https://www.manning.com/books/rx-dot-net-in-action) about it. But when it was my own AI agents hitting the limit, my first instinct wasn't "implement a token bucket." It was "why is Gmail broken?"

Because here's the cognitive trap: when you think of your AI agents as a *team* (and you should — that mental model is powerful), you stop thinking of them as distributed system components. You think of them as people. And people don't hit rate limits. People naturally stagger their work. People see that someone else is using the printer and wait.

AI agents are not people. They are goroutines with opinions.

---

## The CS Side: Rate Limiting 101 (But Make It Agents)

Let me put on my distributed systems hat for a minute. There are a handful of well-known patterns for controlling request rates, and every single one of them applies to AI agent teams:

### Token Bucket

The classic. You have a bucket that fills with tokens at a fixed rate. Each request consumes a token. If the bucket is empty, you wait. Simple, elegant, and the reason most API gateways don't fall over.

For an AI agent team, the "bucket" is your API quota. Gmail gives you roughly 30 emails per hour on a consumer SMTP account. That's your bucket size. Every agent email drains one token. When the bucket is empty, the next agent has to wait.

```powershell
# Simplified token bucket check from our email resilience wrapper
function Test-RateLimit {
    $sendLog = Get-Content ~/.squad/email-send-log.json | ConvertFrom-Json
    $oneHourAgo = (Get-Date).ToUniversalTime().AddHours(-1)
    $recentSends = $sendLog | Where-Object {
        $_.result -eq "Success" -and
        [datetime]$_.timestamp -ge $oneHourAgo
    }
    return ($recentSends.Count -ge $RateLimitPerHour)  # default: 30
}
```

This is real code from our `send-squad-email-resilient.ps1` wrapper. Before every send attempt, we check how many emails went out in the last hour. If we're at the limit, we warn. It's not a theoretical token bucket — it's a practical one, built after that Tuesday morning taught us the hard way.

### Exponential Backoff

When a request fails with a transient error, you don't just retry immediately. You wait. Then you wait longer. Then longer still. The delays grow exponentially: 2 seconds, 8 seconds, 32 seconds.

```powershell
# Retry loop with exponential backoff
for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
    try {
        Send-MailMessage @mailParams
        return @{ Sent = $true }
    }
    catch {
        if (Test-SmtpTransientError $_.Exception.Message) {
            $delay = [math]::Pow($RetryDelaySeconds, (2 * $attempt - 1))
            Write-Host "⏳ Transient failure, retrying in ${delay}s..."
            Start-Sleep -Seconds $delay
        }
        elseif (Test-SmtpPermanentError $_.Exception.Message) {
            return @{ Sent = $false; Permanent = $true }
        }
    }
}
```

Why exponential? Because if the server is overwhelmed, having six agents all retry after exactly 2 seconds just recreates the thundering herd problem. Exponential backoff with jitter spreads the retries out, giving the server time to recover. It's the same principle behind Ethernet collision detection from the 1970s. Some problems are eternal.

### Circuit Breaker

This one is my favorite, because it maps so cleanly to management thinking.

A circuit breaker monitors failure rates. When failures exceed a threshold, the circuit "opens" — meaning subsequent requests fail *immediately* without even trying. After a cooldown period, it lets one request through (the "half-open" state). If that succeeds, the circuit closes and normal traffic resumes. If it fails, the circuit stays open.

```
   ┌─────────┐    failures > threshold    ┌──────────┐
   │  CLOSED  │ ──────────────────────────►│   OPEN   │
   │(normal)  │                            │(fail fast)│
   └────┬─────┘                            └─────┬────┘
        │                                        │
        │          cooldown timer expires         │
        │◄─────────────────────────────────────────
        │                                        │
        │              ┌──────────────┐          │
        └──────────────│  HALF-OPEN   │──────────┘
           success     │(test one req)│  failure
                       └──────────────┘
```

In our squad, we implemented this for the email pipeline. If Gmail fails three times in a row, we stop trying Gmail entirely and switch to the Outlook SMTP fallback. We don't keep hammering a dead endpoint. The circuit breaker pattern saves us from wasting retries on a provider that's clearly having a bad day.

### The Bulkhead Pattern

In naval architecture, bulkheads are watertight compartments that prevent a single breach from sinking the whole ship. In software, the bulkhead pattern isolates failures so that one overloaded resource doesn't cascade into everything else.

For our agent team, this means email failures don't block code reviews. LLM rate limits on research tasks don't prevent security scans. Each agent's external API calls are isolated — a failure in Neelix's Teams delivery channel doesn't prevent Data from merging a PR.

This sounds obvious until you've lived through the alternative: a shared HTTP client pool where one agent's timeout causes connection starvation for all the others. Ask me how I know.

---

## The Management Side: You Already Know This

Here's where it gets interesting. Every single one of those CS patterns has a direct analog in how good engineering managers run teams. And I don't mean that as a loose metaphor — I mean the underlying math is the same.

### WIP Limits Are Token Buckets

If you've ever used Kanban, you know about Work-In-Progress limits. The idea is simple: cap the number of tasks that can be "in progress" at any time. If the limit is reached, nothing new starts until something finishes.

That's... a token bucket. The WIP limit is your bucket size. Each task in progress consumes a token. When the bucket is empty (all WIP slots are full), new work queues up instead of starting.

The insight from Kanban theory is that WIP limits *increase* throughput, which is counterintuitive. Shouldn't more parallel work mean more output? No — because context switching has a cost, because shared resources create contention, and because bottlenecks become invisible when everything is "in progress." This is exactly why token bucket rate limiting works: by constraining the rate, you actually improve the *sustainable* throughput of the system.

### "Don't Overload Your Team" Is Backpressure

Every management book ever written includes some version of "don't overload your team." But few explain *why* in systems terms. Here's why: an overloaded team stops providing feedback. When people are drowning in work, they stop raising blockers, stop asking clarifying questions, stop pushing back on bad requirements. The feedback loop breaks.

In distributed systems, we call this backpressure — the mechanism by which a downstream system signals to an upstream system that it's receiving work faster than it can process. Without backpressure, queues grow unbounded, latencies spike, and eventually the system fails.

My AI agents don't feel burnout. But they do hit context window limits. They do produce lower-quality output when given too many concurrent tasks. And critically, when an LLM endpoint is overwhelmed, the responses get slower and the token quality degrades — which is the AI equivalent of a burned-out engineer writing sloppy code at 2 AM.

### One-on-Ones Are Health Checks

The circuit breaker pattern works because it monitors the health of a dependency. When health drops below a threshold, it stops sending traffic. When health recovers, traffic resumes.

A good engineering manager does exactly this with their team: regular one-on-ones that check how people are doing, whether they're blocked, whether they're underwater. If someone is struggling, you don't pile on more work. You reduce their load (open the circuit) until they recover.

For my AI squad, I built health checks into Ralph's monitoring loop. If an agent's error rate spikes, if tasks are taking 3x longer than usual, if the LLM API is returning degraded responses — Ralph logs it, flags it, and can pause task assignment to that agent. It's a one-on-one, automated.

---

## What We Actually Built

Let me show you what this looks like in practice. After the Great Email Incident of Tuesday, we built `send-squad-email-resilient.ps1` — a 470-line production-grade wrapper that implements every pattern I just described:

1. **Token bucket rate check**: Before every send, check the log. Are we over 30 sends this hour? Warn and proceed with caution.

2. **Exponential backoff retry**: SMTP 4xx errors (421, 450, 451, 452) get retried with delays of 2s → 8s → 32s. Three attempts per provider.

3. **Error classification**: Transient errors (4xx, timeouts, connection resets) get retried. Permanent errors (550, 553, auth failures) fail fast. No point retrying a bad password.

4. **Multi-provider circuit breaker**: Gmail is the primary. If Gmail fails permanently or exhausts retries, we switch to Outlook. If both fail, we exit with a semantic error code (1 = permanent, 2 = transient exhausted).

5. **Structured JSON logging**: Every attempt — success or failure — gets logged with timestamp, provider, result, error message, and retry count. This is how I knew it was a Tuesday.

```
┌──────────────────────────────────────────────────────────┐
│                   Agent wants to send email               │
└─────────────────────────┬────────────────────────────────┘
                          │
                          ▼
                  ┌───────────────┐
                  │ Rate limit OK? │
                  └───┬───────┬───┘
                  yes │       │ no → warn, continue
                      ▼       ▼
              ┌─────────────────────┐
              │  Try Gmail (primary) │
              └───┬─────────┬───────┘
            success│       │ failure
                   ▼       ▼
              ┌──────┐  ┌──────────────────┐
              │ Done │  │ Transient error?  │
              └──────┘  └──┬────────┬──────┘
                       yes │        │ no (permanent)
                           ▼        ▼
                    ┌────────────┐ ┌───────────────────┐
                    │  Backoff   │ │ Try Outlook        │
                    │  & retry   │ │ (circuit breaker)  │
                    └────────────┘ └───────────────────┘
```

The key design decision was **warn but don't block** on rate limits. When you're at 29/30 emails this hour, you still send — because that email might be a critical security alert. But you log the warning so that patterns become visible. It's the difference between a hard stop and an informed decision, which is also exactly how good WIP limits work in practice: they're signals, not handcuffs.

---

## The Thesis

Here's what I've come to believe after running an AI agent team for months: **managing AI agents is just distributed systems engineering wearing a management hat.**

The patterns are identical. Token buckets and WIP limits solve the same problem (constrain concurrent work to improve throughput). Backpressure and "don't overload your team" are the same feedback mechanism. Circuit breakers and management health checks serve the same purpose (stop sending work to struggling components).

This isn't a coincidence. Both fields are trying to solve the same fundamental challenge: *how do you coordinate multiple independent actors sharing limited resources to produce reliable outcomes?* Computer scientists formalized it with queuing theory and control systems. Management theorists formalized it with Lean, Kanban, and Theory of Constraints. They arrived at the same answers because the underlying physics is the same.

And now, with AI agent teams, both traditions converge in one place. Your agents are microservices *and* team members. Your rate limits are API quotas *and* WIP constraints. Your monitoring is observability *and* one-on-ones.

If you come from a distributed systems background, you already have the mental models. You just need to apply them to agents instead of containers. If you come from a management background, you already have the intuitions. You just need to recognize that the patterns you learned about teams also apply to software.

Either way, the next time your AI agent gets a 429, don't think of it as an error. Think of it as the system telling you what every good manager already knows:

**Slow down. You're pushing too hard. The work will still be there when you're ready.**

---

## What's Next

This is Part 1 of a series I'm calling *CS & Management Parallels in AI Agent Teams*. The core thesis: every hard problem in managing AI agents has a direct parallel in both computer science and management theory. Rate limiting was just the beginning.

In Part 2, we'll tackle **consensus protocols** — what happens when your agents disagree about the right approach, and why it looks a lot like the Raft algorithm running in a staff meeting.

Stay tuned. And maybe check your email rate limits before then. 📬

---

*Tamir Dresher is a software architect at Microsoft, author of [Rx.NET in Action](https://www.manning.com/books/rx-dot-net-in-action), and someone who once debugged a distributed lock race condition between two machines running the same AI agent — but that's a story for Part 3.*
