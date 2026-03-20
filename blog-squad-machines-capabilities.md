---
layout: post
title: "Every Drone Has a Function — Squad's Multi-Machine Brain"
date: 2026-04-01
tags: [ai-agents, squad, github-copilot, multi-machine, architecture, labels, issue-templates, distributed-systems, star-trek, borg]
series: "Scaling AI-Native Software Engineering"
series_part: 5.5
---

> *"Each of us has a function. The Collective does not tolerate redundancy."*
> — Seven of Nine, Star Trek: Voyager

In [Part 5](/blog/2026/03/25/scaling-ai-part5-kubernetes), I showed you how we moved Ralph off a laptop and onto Kubernetes. No more mouse-wiggling scripts. No more stale lock files. The squad finally had a home that doesn't sleep.

But here's the thing I didn't say out loud: by the time we finished that migration, I was running Squad across **three machines at once**. My laptop. A DevBox in the cloud. A small AKS cluster. Each one running a different piece of the squad's brain. And none of them had any idea what the others were capable of.

That's not a distributed system. That's three machines independently hoping they're not doing the same thing.

This post is about what I learned when I stopped thinking about agents and started thinking about **machines**.

---

## The Moment It Clicked

I have a WhatsApp monitor running on my laptop. It watches family messages, watches for printing requests, watches for anything I should know about. It fires Teams notifications through webhooks. It's one of the most genuinely useful things in my Squad setup.

It runs *only* on my laptop. Because it needs to be logged into WhatsApp Web, authenticated to my personal Teams account, and present in my home network. You can't containerize family context. You can't `helm install` twenty years of household logistics. That agent belongs on one specific machine.

Meanwhile, Ralph — the tireless five-minute loop that processes issues, opens PRs, and watches the queue — ideally runs *everywhere but* my laptop. If my laptop sleeps, Ralph sleeps. If I close the lid for a flight, Ralph disappears. Every time I've had a run of consecutive Ralph failures (thirty-seven at one point — [I documented the saga](/blog/2026/03/17/scaling-ai-part4-distributed-failures)), it's because Ralph was living on the wrong machine.

So: some agents belong on the home machine. Some belong on a persistent cloud machine. Some belong on the DevBox where the codebase lives. The question is — how do machines *know* this? How does a task filed on my phone at 10pm know to wake up an AKS pod, not my sleeping laptop?

The answer was in the routing table all along. I just hadn't read it properly.

---

## Labels Are Not Labels. They're Addresses.

Look at the Squad routing table in `.squad/routing.md`:

```markdown
## Issue Routing
| Label         | Action                                           | Who          |
|---------------|--------------------------------------------------|--------------|
| `squad`       | Triage: analyze, evaluate fit, assign member     | Lead         |
| `squad:picard`| Pick up issue and complete the work              | Picard       |
| `squad:seven` | Pick up issue and complete the work              | Seven        |
| `squad:worf`  | Pick up issue and complete the work              | Worf         |
```

I used to read `squad:picard` as "Picard should handle this." That's correct, but it's not the full picture.

`squad:picard` is an **address**. It's a structured message with a recipient. When Ralph sees that label in the issue queue, he doesn't just notify Picard — he checks *which* Picard is available, on *which* machine, with *which* current load. The label is the envelope. The issue body is the letter inside.

Once I saw it that way, the issue template system took on a completely different meaning.

---

## Issue Templates as Inter-Machine Contracts

Every Squad issue template in `.github/ISSUE_TEMPLATE/` is a schema. Fill out the form correctly and you're not just writing a note to yourself — you're writing a structured message that any machine in the squad can parse, validate, and route.

A "Research Request" template with fields for scope, depth, output format, and target deadline isn't a convenience for humans. It's a contract. It tells the receiving machine exactly what work is expected, what constraints apply, and what done looks like. A machine that picks up a malformed research request can *reject it* because the contract isn't satisfied. No ambiguity. No "I wasn't sure what you wanted."

Compare this to how I used to file issues: "hey seven can you write up something about the auth module." That's not a contract. That's a text message. Seven can't parse "something." Machines can't act on vibes.

Structured issue creation is structured inter-machine messaging. The templates enforce the schema. Ralph enforces the routing. Labels enforce the recipient.

We independently built a message-passing protocol using GitHub Issues. It took me six months to notice.

---

## The Cross-Machine Task Queue

It goes further. Inside `.squad/cross-machine/`, there's a YAML-based task queue that predates any of my AKS work. Machine A creates a file in `tasks/`, commits, pushes. Machine B pulls, picks up the task, executes, writes a result to `results/`, pushes back. Machine A pulls, reads the result.

```yaml
# .squad/cross-machine/tasks/run-tests-desktop.yaml
id: test-run-001
source_machine: TAMIRDRESHER
target_machine: CPC-tamir-3H7BI
task_type: command
description: "Run integration tests on the higher-spec machine"
payload:
  command: "pwsh scripts/run-integration-tests.ps1"
  expected_duration_min: 15
status: pending
```

This is git as a message bus. It's slow (commit round-trips, not milliseconds), it's simple, and it works. Ralph's watch loop calls the cross-machine watcher each cycle. Any machine in the `this_machine_aliases` list wakes up, checks the queue, does its work.

I've used this to run heavy test suites on a desktop when my laptop is too slow. I've used it to kick off voice synthesis jobs that need local GPU access while an agent in the cloud coordinates the workflow. The machines talk to each other. They don't need to be in the same room, the same VPN, or the same cloud region. They just need git.

---

## The Vision: Sub-Squads That Specialize

Here's where we're going — and I mean going, not imagining.

**Home Squad** runs on my laptop and the home network. WhatsApp monitor. Family calendar coordination. Local file access. Tools that can't move to the cloud because they're rooted in physical context. This squad handles everything personal, time-sensitive, and location-aware.

**DevBox Squad** runs on the cloud development machine. Code review. Agent work against open branches. PR creation. Heavy compilation and test runs. The DevBox has the codebase mounted, the dev tools configured, the right credentials for repository work. This is where Data lives — because Data needs the repo.

**AKS Squad** runs on the cluster. Ralph, 24/7. Monitoring pipelines. Long-running coordination tasks. Anything that needs high availability, restart policy, and the kind of stability you can't get from a machine that might sleep at 2am. This is where reliability lives.

Each sub-squad sees the same GitHub Issues. Each reads the same label taxonomy. They don't need to know about each other's internal state — they just need to read the routing table and respect the contracts.

This is how the Borg actually works. Not one giant ship where every drone does everything. A collective of specialized vessels, each optimized for its mission, all coordinated by the same protocol. The cube for overwhelming force. The sphere for speed. The probe for reconnaissance. Each drone knows its function. The collective knows which drone to send.

---

## Why This Matters Before You Go to AKS

I'll be honest: I spent a long time treating AKS as "a better place to run Ralph." More reliable than a laptop. Easier than managing VMs. A fix for the mouse-wiggling script.

That framing was too small.

AKS isn't just a better home for Ralph. It's the foundation for a machine that has a *specific role* in a multi-machine squad. It's the always-on, high-availability node that owns 24/7 coordination. It knows what it can do (run long-lived jobs, handle restarts, manage secrets at scale). It knows what it *can't* do (WhatsApp auth, local file access, personal calendar sync). And because it knows both, it routes work correctly.

The capabilities story comes before the deployment story. You don't containerize agents and push to AKS and then figure out what the machine should do. You figure out what the machine should do, and *then* the deployment choices write themselves.

In the next post, I'll show you exactly how we taught AKS what it's for — node labels, agent selectors, capability profiles, and the Helm chart that wires it all together.

The squad is getting smarter. Machine by machine, function by function.

Resistance is futile. 🟩⬛

---

> 📚 **Series: Scaling Your AI Development Team**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai)
> - **Part 1**: [Resistance is Futile — Your First AI Engineering Team](/blog/2026/03/11/scaling-ai-part1-first-team)
> - **Part 2**: [From Personal Repo to Work Team — Scaling Squad to Production](/blog/2026/03/12/scaling-ai-part2-collective)
> - **Part 3**: [Unimatrix Zero — When Your AI Squad Becomes a Distributed System](/blog/2026/03/18/scaling-ai-part3-distributed)
> - **Part 4**: [When Eight Ralphs Fight Over One Login](/blog/2026/03/17/scaling-ai-part4-distributed-failures)
> - **Part 5**: [Assimilating the Cloud — Running Your AI Squad on Kubernetes](/blog/2026/03/25/scaling-ai-part5-kubernetes)
> - **Part 5.5**: Every Drone Has a Function — Squad's Multi-Machine Brain ← You are here
> - **Part 6**: [The Right Machine for the Right Agent — Squad, AKS, and KAITO](/blog/2026/04/02/scaling-ai-part6-aks-capabilities) — coming next
