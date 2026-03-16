---
layout: post
title: "Unimatrix Zero — When Your AI Team Becomes a Distributed System"
date: 2026-03-13
tags: [ai-agents, squad, github-copilot, distributed-systems, multi-machine, self-healing, devbox]
series: "Scaling AI-Native Software Engineering"
series_part: 3
---

> *"In Unimatrix Zero, drones could exist as individuals."*
> — Seven of Nine, Star Trek: Voyager

In [Part 0](/blog/2026/03/10/organized-by-ai), Squad was my personal productivity system. In [Part 1](/blog/2026/03/11/scaling-ai-part1-first-team), Picard decomposed tasks while Ralph churned through my backlog at 2 AM. In [Part 2](/blog/2026/03/12/scaling-ai-part2-collective), we scaled it to real teams — upstream inheritance, organizational knowledge flowing hierarchically, skills that propagate across repos.

That covered the *knowledge* problem. But there's another scaling challenge I kept hitting that has nothing to do with context or conventions:

**What happens when one machine isn't enough?**

My laptop has 32GB of RAM and no GPU. My Microsoft Dev Box has a GPU but sits idle when I'm not logged in. My work VM runs 24/7 but can't do voice inference. Each machine has different capabilities, different availability, different purpose.

Here's the thing: I didn't set out to build a distributed system. I just wanted Ralph to run everywhere and not step on his own feet. But once you have autonomous agents running on multiple machines, coordinating through git, healing themselves when auth breaks, and resurrecting dead Dev Boxes at 3 AM — well, congratulations. You accidentally built a distributed system.

This post is about that accidental distributed system. Everything here is real, running in production (my production, at least), and was built because I kept solving the *next* annoying problem until I looked up and realized Ralph had become a small Borg Collective all by himself.

---

## Ralph Is Everywhere (And That's the Point)

In Part 1, Ralph was a single `while ($true)` loop running on my laptop. Check issues, merge PRs, document decisions, sleep 5 minutes, repeat. Simple. Reliable. Limited to one machine.

The limitation hit me when I needed GPU inference for voice cloning. My laptop can't do it. My Dev Box can. But I don't want to manually SSH into the Dev Box, kick off a script, wait for results, and copy them back. That's exactly the kind of toil Squad is supposed to eliminate.

So I did what any reasonable engineer would do: I made Ralph run on *both* machines simultaneously.

`start-all-ralphs.ps1` is embarrassingly simple — it launches `ralph-watch.ps1` in separate windows for each repo. Each instance guards itself with a system-wide mutex (`Global\RalphWatch_tamresearch1`) so you can't accidentally run two Ralphs on the same machine. But across machines? That's where it gets interesting.

**The coordination protocol uses GitHub itself as the message bus.** No Redis. No RabbitMQ. No Kafka. Just git and the GitHub API.

When Ralph on my laptop spots an issue, he claims it:

```
gh issue edit 42 --add-assignee "@me"
# Comment: "🔄 Claimed by LAPTOP-TAMIR at 2026-03-15T14:22:33Z"
```

Ralph on my Dev Box sees the assignment and skips it. Branch names include the machine name — `squad/42-fix-auth-LAPTOP-TAMIR` vs `squad/42-fix-auth-DEVBOX-GPU` — so you can always trace which machine did what.

If a machine goes silent (no heartbeat for 15 minutes), other Ralphs reclaim the work. The stale threshold is aggressive on purpose — I'd rather have two machines race on an issue than have work sit idle because a laptop went to sleep.

**Is this a proper distributed task queue?** No. It's a bunch of PowerShell scripts coordinating through GitHub labels and issue comments. But here's the thing — it works. It's been running for weeks. And because the coordination layer is GitHub (which I already have), there's nothing extra to deploy, monitor, or pay for.

---

## Cross-Machine Tasks — Git as a Message Broker

The claim-based coordination handles *independent* issues. But what about *dependent* work — when my laptop needs something that only my Dev Box can provide?

We built a git-based task queue. It lives in `.squad/cross-machine/`:

```
Laptop                     Git Repo                     DevBox (GPU)
──────                     ────────                     ────────────
Create task YAML  ──push──▶ tasks/voice-clone.yaml ◀──pull── Ralph picks up task
                                                              → Execute (GPU work)
                            results/voice-clone.yaml ◀──push── Write result
Read result       ◀──pull──
```

Each task is a YAML file with a `target_machine`, `priority`, and `command` payload. Ralph on each machine polls every 5 minutes, pulls pending tasks, checks if they're targeted at his machine (or `ANY`), validates the command against a whitelist (Worf would insist), executes, and pushes the result back to git.

Here's a real task that runs regularly:

```yaml
id: voice-clone-executive-summary
source_machine: LAPTOP-TAMIR
target_machine: DEVBOX-GPU
priority: high
task_type: inference
description: "Generate Hebrew voice clone of executive summary"
payload:
  command: "python scripts/voice-clone.py --input EXECUTIVE_SUMMARY.md"
  expected_duration_min: 15
status: pending
```

My laptop creates this task. Ralph on the Dev Box picks it up, runs the GPU-intensive voice cloning, writes the result YAML with the output path, and pushes. My laptop's next poll finds the result. No human intervention. No SSH sessions. No manual file transfers.

**The command whitelist is critical.** Without it, you'd have a remote code execution vulnerability disguised as a task queue. Only commands matching patterns like `python scripts/*`, `node scripts/*`, or `gh *` are allowed. Everything else gets rejected with a security warning. Worf didn't build this one, but he'd approve.

---

## Self-Healing — The Part Nobody Talks About

Here's the dirty secret about running autonomous agents 24/7: things break. Not dramatically. Not with alarms and incident pages. They break *quietly*. A GitHub OAuth token loses a scope after a refresh. A git pull hits a merge conflict. A Dev Box goes to sleep and never wakes up.

If you're running agents manually, you notice these failures because *you're sitting there*. When agents run autonomously while you sleep, silent failures are the enemy.

So Ralph heals himself.

**Every round starts with self-healing checks.** Before Ralph even looks at the issue queue, he runs `ralph-self-heal.ps1`. This script checks `gh auth status`, verifies all required OAuth scopes are present (`repo`, `read:org`, `project`), and if anything is missing, it *fixes it automatically*.

Here's the wild part: **Ralph uses Playwright to complete the GitHub device authorization flow.** When `gh auth refresh` needs a device code entered on github.com/login/device, Ralph spawns a browser automation agent that navigates to the page, enters the code, clicks Continue, and completes the auth. No human needed. The AI agent literally logs itself back into GitHub.

(I realize this sounds slightly terrifying. An AI agent that can authenticate itself to GitHub and resume working with full repo access. But consider the alternative: Ralph stops working at 2 AM because a token expired, nobody notices for 8 hours, and you lose a full night of productivity. The self-healing is the responsible choice. Probably.)

**Git conflicts get auto-resolved too.** When `git pull` fails with merge conflicts on non-critical files (logs, heartbeat JSON, cross-machine results), Ralph accepts the remote version and moves on. For actual code conflicts, he stops and creates an issue. The rule is simple: resolve what's safe to resolve, escalate what isn't.

**Email monitoring adds another self-healing layer.** Ralph checks for GitHub notification emails — failed CI workflows, Dependabot alerts, security scanning findings — and auto-remediates where possible. Failed workflow? `gh run rerun`. Dependabot alert? Create an issue with `security-alert` label and route to Worf. The pattern is always the same: fix what can be fixed automatically, escalate what requires human judgment.

The result is a system that runs for weeks without intervention. Not because nothing goes wrong — things go wrong *constantly* — but because the system knows how to recover from the failures it encounters most often.

---

## The DevBox Fleet — Always-On Machines That Never Sleep

My Dev Box is a cloud VM provisioned through Microsoft Dev Box. It has a GPU, 64GB of RAM, and (critically) it goes to sleep after 2 hours of inactivity. This is a problem when you want Ralph running 24/7.

The solution is `keep-devbox-alive.ps1` — a script that prevents the Dev Box from auto-hibernating by simulating activity. Combined with the Dev Box provisioning skill in `.squad/skills/devbox-provisioning/`, Squad can actually *provision new Dev Boxes* programmatically using the Azure CLI dev center extension.

The vision (and we're most of the way there) is a **fleet management pattern**:

1. **Startup scripts** that bootstrap a fresh Dev Box: clone repos, install dependencies, configure auth, start Ralph
2. **Always-on monitoring** via heartbeat files that track which machines are active, their current round, and failure counts
3. **Git-based sync** so every machine pulls the latest code, decisions, and cross-machine tasks automatically
4. **Auto-restart** built into Ralph himself — if `ralph-watch.ps1` detects that its own file hash has changed (someone pushed an update), it relaunches itself in a new window with the updated code

Each machine writes heartbeat JSON to `~/.squad/heartbeats/{COMPUTERNAME}.json`. A Telegram bot reads these files and responds to `/status` commands with a dashboard showing all active Ralphs, their round counts, and their health. When a heartbeat goes stale (older than 10 minutes), the bot flags it.

**Here's what my typical fleet looks like:**

```
Machine              Status    Round   Last Activity         Role
─────────────────    ───────   ─────   ────────────────────  ──────────────
LAPTOP-TAMIR         running   142     2026-03-15 14:22:33   General work
CPC-tamir-WCBED      idle       89     2026-03-15 14:18:01   GPU inference
CPC-tamir-3H7BI      running    67     2026-03-15 14:20:15   Research tasks
```

Three machines. Three Ralphs. Coordinating through GitHub issues, syncing through git, healing themselves when things break. Each one running the same `ralph-watch.ps1` loop, but picking up different work based on machine capabilities and issue assignment.

Is this overkill for one person's side project? Absolutely. Did I build it because I needed it, or because it was cool? Yes.

---

## The Skills Marketplace — When Squads Teach Each Other

Everything so far has been about making *one* Squad work across multiple machines. But the bigger vision — the one I can't stop thinking about — is what happens when *multiple Squads* share knowledge.

In Part 2, I showed upstream inheritance: repos inherit organizational knowledge from shared upstream repos. Skills flow from `org → team → repo`. That's hierarchical. Top-down. Curated.

The skills marketplace is the peer-to-peer complement. When Data (my code expert) figures out a brilliant pattern for handling authentication token refresh in a specific framework, that pattern gets captured as a skill with a confidence level. Low confidence at first (one observation, one repo). After it's used successfully across multiple contexts, it graduates to medium. After human review and cross-repo validation, it hits high confidence.

High-confidence skills get promoted to the team upstream. Every downstream Squad picks them up on the next sync. **One drone's adaptation becomes every drone's advantage.**

The cross-machine coordination we built is itself a skill that could be shared. The self-healing patterns, the heartbeat protocol, the git-based task queue — all of these are reusable across any Squad deployment. Package them as skills, publish them to a marketplace, and every new Squad that subscribes gets battle-tested infrastructure coordination out of the box.

We're early on this. Today, skill sharing is manual: export from one repo, commit to the upstream, sync downstream. Tomorrow, I want it to be automatic — a federation of Squads discovering and sharing proven patterns the way open-source libraries propagate through package managers.

The Borg had their subspace links for real-time knowledge sharing across the Collective. We'll have ours. Just with more YAML and fewer cybernetic implants.

---

## Honest Reflection

I've been running this distributed Ralph setup for several weeks. Some of it is genuinely elegant — the GitHub-as-message-bus pattern is surprisingly robust, and the self-healing auth flow saves me hours of manual token management.

But let me be honest about the rough edges.

The git-based task queue has race conditions. Two machines can pull the same task simultaneously if their poll intervals align. We handle it with claim semantics, but occasionally work gets duplicated. It's a distributed systems problem, and we're solving it with eventually-consistent git commits. CAP theorem laughs at us.

The self-healing Playwright auth flow is fragile. GitHub changes their device flow UI? It breaks. Browser automation is inherently brittle. I've already had to update the CSS selectors twice.

And the fleet management is still manual enough that I wouldn't call it "production-grade." Provisioning a new Dev Box, cloning repos, configuring auth, starting Ralph — that's a 30-minute checklist, not a one-click operation. We're getting there, but we're not there yet.

What keeps me going is the same thing that kept me going in Part 0: the trajectory. Every week, the system gets more resilient. Every failure mode we hit gets a self-healing fix. Every manual step gets automated. The compounding continues — not just in knowledge, but in infrastructure reliability.

I started with one laptop and a PowerShell script. Now I have a fleet of machines running autonomous agents that coordinate through GitHub, heal themselves when auth breaks, and distribute GPU-intensive work across the cloud. All without a single container, a single Kubernetes cluster, or a single message broker.

Just git. Just GitHub. Just Ralph, running everywhere.

The Collective doesn't need a data center. It just needs a `while ($true)` loop and a good internet connection. 🟩⬛

---

> 📚 **Series: Scaling Your AI Development Team**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai)
> - **Part 1**: [Resistance is Futile — Your First AI Engineering Team](/blog/2026/03/11/scaling-ai-part1-first-team)
> - **Part 2**: [The Collective — Organizational Knowledge for AI Teams](/blog/2026/03/12/scaling-ai-part2-collective)
> - **Part 3**: Unimatrix Zero — When Your AI Team Becomes a Distributed System ← You are here
