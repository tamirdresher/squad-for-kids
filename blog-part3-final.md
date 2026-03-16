---
layout: post
title: "Unimatrix Zero — When Your AI Squad Becomes a Distributed System"
date: 2026-03-18
tags: [ai-agents, squad, github-copilot, distributed-systems, multi-machine, star-trek, borg]
series: "Scaling AI-Native Software Engineering"
series_part: 3
---

> *"We are the Borg. We are everywhere."*
> — The Borg Collective, Star Trek: Voyager

In [Part 1](/blog/2026/03/11/scaling-ai-part1-first-team), I showed you how Picard, Data, Seven, and the rest of my Star Trek crew turned my personal repo into an AI-powered engineering team. In [Part 2](/blog/2026/03/12/scaling-ai-part2-collective), we scaled that to a real work team at Microsoft — humans and AI, together, with routing rules and FedRAMP compliance audits.

Both of those stories have something in common: one machine. One terminal window. One Ralph watching the queue.

This post is about what happened when that stopped being enough.

---

## The Day One Machine Wasn't Enough

It started with voice cloning.

I'd been experimenting with the podcaster agent — turning markdown documents into conversational audio. English worked great: edge-tts, two synthetic hosts, ready in minutes. But I wanted Hebrew. And Hebrew voice cloning needs a GPU. My laptop doesn't have one.

My DevBox in Azure? Plenty of GPU. But Squad runs on my laptop. The codebase lives on my laptop. The agents work on my laptop. Do I really need to SSH into the DevBox, manually copy files, run a script, copy the result back?

No. That's toil. And toil is what Squad was built to eliminate.

So I did what any reasonable person with an AI team would do: I taught Ralph to run on multiple machines simultaneously, and I built a git-based task queue so they could coordinate.

And suddenly, my one-machine AI team became a distributed system.

---

## Subsquads: How Work Naturally Splits

Before we get to multiple machines, let me show you what was already happening on a single machine — because it's the foundation for everything that comes next.

When I say "Team, build the deployment monitoring dashboard," I'm not giving one agent a job. I'm giving Picard a **problem to decompose**. And Picard doesn't just assign tasks randomly. He reads the routing table.

Here's the actual routing table from `.squad/routing.md`:

```markdown
## Work Type → Agent

| Work Type                              | Primary   | Secondary |
|----------------------------------------|-----------|-----------|
| Architecture, distributed systems      | Picard    | —         |
| K8s, Helm, ArgoCD, cloud native        | B'Elanna  | —         |
| Security, Azure, networking            | Worf      | —         |
| C#, Go, .NET, clean code               | Data      | —         |
| Documentation, presentations, analysis | Seven     | —         |
| Blog writing, voice matching           | Troi      | Seven     |
| News, briefings, status reports        | Neelix    | Seven     |
```

This isn't a suggestion list. It's a **routing table** — the same concept as a network routing table, but for work. When Picard decomposes a task, he matches each sub-task against this table and fans out to the right specialist.

Real example from last Tuesday. I filed an issue: "Add Helm chart validation to the CI pipeline." Picard decomposed it:

```
🎖️ Picard: Decomposing Helm validation task...

   → B'Elanna: Write the Helm chart linter and dry-run template validation
   → Data: Add CI pipeline stage with Go test harness
   → Worf: Validate security policies in chart values
   → Seven: Document the new validation requirements and failure modes

   All four workstreams are independent — spawning in parallel.
```

Four agents, four branches, all moving forward at the same time. B'Elanna is writing Helm validation templates while Data builds the test harness while Worf audits the `values.yaml` for security holes while Seven drafts the runbook for when validation fails.

This is the subsquad pattern. Picard doesn't serialize work. He identifies **workstreams** — independent threads of execution that can run concurrently — and routes each one to the specialist who owns that domain. The routing rules in `.squad/routing.md` make this deterministic:

```markdown
## Routing Rules

### Architecture Decisions
- **Trigger:** Changes to CRD schemas, API contracts, multi-repo dependencies
- **Route to:** Human squad member
- **AI action:** Analysis + recommendations, then pause for approval

### Security Reviews
- **Trigger:** Authentication, secrets, network policies, supply chain changes
- **Route to:** Worf (AI) → Human sign-off
- **AI action:** Automated scans + findings, then pause for sign-off

### Go Operator Code
- **Trigger:** Reconciler logic, Kubernetes client code, controller changes
- **Route to:** Data (AI) → Human review
- **AI action:** Implementation, tests, then PR for human review
```

The rules are explicit about what needs human approval and what doesn't. B'Elanna can merge infrastructure changes to staging autonomously. Security changes always pause for human sign-off. Architecture decisions route to a human squad member. Clear boundaries, no ambiguity.

The first time I watched four PRs appear in my review queue from four different agents — all created within the same 10-minute window, all for the same issue — I realized this wasn't a single assistant anymore. It was a team with a division of labor. Picard is the manager who never forgets to delegate. The routing table is the org chart he consults. And the workstreams are genuinely parallel, not sequential disguised as parallel.

I went to make coffee. By the time I came back, three of the four PRs had passing CI. The fourth had a test failure that Data was already investigating. I reviewed the code on my phone over lunch. Approved three, left a note on one. By 2 PM, all four were merged.

That's one machine. One Squad. Four parallel workstreams. Now multiply it.

---

## Ralph Goes Multi-Machine

Here's the `ralph-watch.ps1` single-instance guard — the foundation of the multi-machine system:

```powershell
# System-wide named mutex — prevents ANY duplicate across the machine
$mutexName = "Global\RalphWatch_tamresearch1"
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
$acquired = $false
try { $acquired = $mutex.WaitOne(0) }
catch [System.Threading.AbandonedMutexException] { $acquired = $true }
if (-not $acquired) {
    Write-Host "ERROR: Another Ralph instance is already running (mutex: $mutexName)"
    exit 1
}
```

That `Global\` prefix is critical. Windows named mutexes with the `Global\` prefix are system-wide — visible across all user sessions, all terminal windows, all processes. One Ralph per repo per machine. Non-negotiable. If you accidentally open a second terminal and run `ralph-watch.ps1`, it exits immediately. No race condition. No duplicate work.

But across machines? A Windows mutex can't help you there. My laptop's mutex doesn't know about my DevBox's mutex. So when Ralph runs on both machines, watching the same GitHub repo, they both see the same issues. And they both try to work on them.

This is the distributed systems problem I never expected to have with an AI team: **how do you prevent two Ralphs on two machines from doing the same work twice?**

### Claim Before You Work

The answer lives in `ralph-watch.ps1` as multi-machine coordination logic:

```powershell
# Check if issue is already assigned (multi-machine coordination)
function Test-IssueAlreadyAssigned {
    param([string]$IssueNumber)
    $issueData = gh issue view $IssueNumber --json assignees | ConvertFrom-Json
    if ($issueData.assignees -and $issueData.assignees.Count -gt 0) {
        return $true
    }
    return $false
}

# Claim issue for this machine
function Invoke-IssueClaim {
    param([string]$IssueNumber, [string]$MachineId)
    gh issue edit $IssueNumber --add-assignee "@me"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $claimMessage = "🔄 Claimed by **$MachineId** at $timestamp"
    gh issue comment $IssueNumber --body $claimMessage
    return $true
}
```

Before Ralph spawns an agent for any issue, he checks: *is this already assigned?* If another Ralph on another machine already claimed it, skip it. If it's unclaimed, claim it first — assign it, leave a comment with your machine name and timestamp, then start working. Branch names include `$env:COMPUTERNAME` so you can trace which machine did what: `squad/591-voice-cloning-LAPTOP` vs `squad/591-voice-cloning-DEVBOX`.

But claims can go stale. What if my laptop Ralph claims an issue, then my laptop goes to sleep? The issue sits there, claimed but unworked, while my DevBox Ralph politely ignores it. So Ralph also runs a heartbeat:

```powershell
# Check for stale work from other machines
function Get-StaleIssues {
    param([string]$MachineId, [int]$StaleThresholdMinutes)
    $issues = gh issue list --json number,labels,comments --limit 100 | ConvertFrom-Json
    foreach ($issue in $issues) {
        $ralphLabels = $issue.labels |
            Where-Object { $_.name -match '^ralph:(.+):active$' -and $Matches[1] -ne $MachineId }
        if ($ralphLabels) {
            # Check last heartbeat comment timestamp
            foreach ($comment in ($issue.comments | Sort-Object -Property createdAt -Descending)) {
                if ($comment.body -match '💓 Heartbeat from \*\*(.+)\*\* at (.+)') {
                    $lastHeartbeat = [datetime]::Parse($Matches[2])
                    $ageMinutes = ((Get-Date) - $lastHeartbeat).TotalMinutes
                    if ($ageMinutes -gt $StaleThresholdMinutes) {
                        # Stale! This machine can reclaim it
                    }
                }
            }
        }
    }
}
```

If a machine's heartbeat is older than 15 minutes, another Ralph can reclaim the work. The reclaim leaves a comment: "⚠️ Reclaimed by **DEVBOX** at 2026-03-15 14:30 (previous owner **LAPTOP** was stale for 22.3 minutes)." Full audit trail. You can read the issue comments and reconstruct exactly which machine worked on what, when, and why.

Is this a production-grade distributed scheduler? No. It's GitHub Issues as a coordination plane, shell scripts as the runtime, and git as the transport layer. Is it elegant? Also no. But it works, it's transparent, and I can debug it by reading issue comments. Try saying that about Kubernetes.

### The Git-Based Task Queue

Issue claiming handles who works on *Squad issues*. But what about cross-machine work that isn't a GitHub issue? My laptop needs GPU compute from my DevBox. That's not a bug to fix or a feature to build — it's a workload to offload.

For that, I built a git-based task queue in `.squad/cross-machine/`:

```
Laptop                    Git Repo                    DevBox (GPU)
──────                    ────────                    ────────────
Create task YAML  ─push─▶ tasks/voice-clone.yaml ◀─pull─  Ralph picks up task
                                                           → Validate & execute
                         results/voice-clone.yaml ◀─push─  Write result
Read result       ◀─pull─
```

A task is just a YAML file:

```yaml
id: gpu-voice-clone-001
source_machine: CPC-tamir-WCBED
target_machine: devbox
priority: high
created_at: 2026-03-14T15:30:00Z
task_type: gpu_workload
payload:
  command: "python scripts/voice-clone.py --input voice.wav --output cloned.wav"
  expected_duration_min: 15
status: pending
```

You commit it. You push. On the next 5-minute cycle, Ralph on the DevBox pulls, sees a pending task targeting his machine, validates the command against a whitelist (Worf would insist), executes it, writes the result to `results/`, and pushes back.

The config is deliberate about security:

```json
{
  "enabled": true,
  "poll_interval_seconds": 300,
  "this_machine_aliases": ["YOURPC", "laptop"],
  "max_concurrent_tasks": 2,
  "task_timeout_minutes": 60,
  "command_whitelist_patterns": [
    "python scripts/*",
    "node scripts/*",
    "pwsh scripts/*",
    "gh *",
    "git *"
  ]
}
```

Only whitelisted commands run. No arbitrary code execution. No inline shell operators. Timeout enforced. This isn't "run whatever the laptop tells you" — it's "run pre-approved scripts with validated inputs."

The real use case that justified all of this: the Hebrew podcast pipeline. My laptop Squad generates the script. It creates a cross-machine task targeting the DevBox for voice cloning inference. Ralph on the DevBox picks it up, runs the GPU workload, pushes the audio file back. Two machines, one workflow, zero manual file copying. No message broker. No Redis. No Kafka. Git is the message bus. Ralph is the scheduler.

### start-all-ralphs.ps1

Launching this distributed system is a one-liner:

```powershell
# Start all Ralphs - launches Ralph monitors for all repositories
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$researchRoot = Join-Path (Split-Path -Parent $repoRoot) "tamresearch1-research"

Write-Host "Starting Ralph for tamresearch1..." -ForegroundColor Cyan
Start-Process pwsh.exe -ArgumentList "-NoProfile -File ralph-watch.ps1" `
    -WorkingDirectory $repoRoot -WindowStyle Normal

if (Test-Path (Join-Path $researchRoot "ralph-watch.ps1")) {
    Write-Host "Starting Ralph for tamresearch1-research..." -ForegroundColor Cyan
    Start-Process pwsh.exe -ArgumentList "-NoProfile -File ralph-watch.ps1" `
        -WorkingDirectory $researchRoot -WindowStyle Normal
}

Write-Host "Both Ralphs started successfully." -ForegroundColor Green
```

Each repo gets its own Ralph instance, its own mutex (`Global\RalphWatch_tamresearch1` vs `Global\RalphWatch_tamresearch1-research`), its own heartbeat file, its own log. They share the same machine but are completely isolated. Run this on your laptop. Run it on your DevBox. Now you have four Ralph instances across two machines watching two repos. Each one checks for work every 5 minutes, claims before working, and writes results back through git.

### The Challenges (Because Distributed Systems Are Hard)

I'd be lying if I said this was smooth from day one. Here's what actually went wrong:

**Merge conflicts.** Two Ralphs push to the same repo within seconds of each other. Git rejects the second push. Ralph retries on the next cycle, but the conflict sometimes corrupts the task YAML. Fix: Ralph now does a `git pull --rebase` before every push and retries once on failure.

**Stale locks.** My laptop went to sleep with an active issue claim. The DevBox saw the stale heartbeat, reclaimed the work, finished it. Then my laptop woke up, didn't re-check the claim, and started working on the same issue. Two PRs for the same fix. Fix: Ralph now re-validates the claim after waking from sleep before doing any work.

**Race conditions on claiming.** Two Ralphs see the same unassigned issue in the same 5-minute window. Both try to claim it. Both succeed (GitHub doesn't have atomic compare-and-swap on issue assignment). Both start working. Fix: after claiming, Ralph waits one cycle and re-checks — if someone else also claimed it, the machine with the lower hostname alphabetically keeps it. Crude, but effective.

**Clock skew.** Heartbeat timestamps depend on local clocks. My DevBox was 3 minutes ahead of my laptop. This made heartbeats appear stale prematurely. Fix: switched to UTC everywhere, and increased the stale threshold from 10 to 15 minutes.

These are real distributed systems problems. Consensus, idempotency, clock synchronization — the exact same challenges you'd face building any multi-node system. The difference is that my "nodes" are AI agents running PowerShell scripts, and my "message broker" is a git repo. It's inelegant. It's also remarkably resilient, because git gives you an append-only audit log for free.

---

## What's Next

Everything I've described so far is one Squad, spread across machines. But here's the question that keeps me up now: **what happens when Squads talk to each other?**

My Squad lives in `tamresearch1`. My team at Microsoft has twelve repos. Other teams are starting their own Squads. What happens when those Squads need to collaborate?

### Squad Mesh — Multiple Squads, Shared Context

Picture this: my Squad detects a Helm chart change in `dk8s-platform` that breaks an API contract `dk8s-operators` depends on. Today, Picard opens an issue in the downstream repo and a human has to coordinate the fix across teams. Tomorrow? Picard's Squad talks to the other repo's Squad directly. Their Lead picks up the issue, decomposes it, assigns their specialists. Two Squads. Two repos. Zero human handoff.

The primitives already exist. Picard already identifies downstream impact and opens tracking issues. Squad Mesh just closes the loop: instead of waiting for a human to notice, the receiving Squad picks it up autonomously. This is the next phase of distributed coordination — not just machines talking to machines, but **teams talking to teams**.

### Cross-Squad Coordination — How Leads Talk

For this to work, Squads need a protocol beyond just task queues. If Picard runs my Squad and Sisko runs another team's Squad, they need to understand priorities, SLAs, escalation paths, and handoff criteria.

Think of it as the routing table expanding from intra-squad to inter-squad. My routing table says "security → Worf." The mesh routing table says "Helm chart breaking change in `dk8s-operators` → ops Squad, priority high, SLA 4 hours."

This is genuine organizational knowledge: who owns what, how to escalate, which teams collaborate on what problems. Today that lives in wikis nobody reads. Tomorrow it's baked into the Squad mesh as executable routing rules.

### Skills Marketplace — Knowledge That Propagates

Today, when Data figures out our Kubernetes operator testing strategy, he captures it as a skill in `.squad/skills/`. That knowledge lives in our repo. Tomorrow, every platform team at Microsoft could benefit from it.

I'm not talking about publishing a wiki page. I mean a **skills marketplace** where Squads publish proven patterns — "Here's how we handle FedRAMP compliance scanning" or "Here's our dependency update strategy that never breaks production." Other Squads subscribe to skills relevant to their domain. When a skill gets updated, every subscribed Squad gets the update automatically.

This is how institutional knowledge scales beyond one team. It's not about centralizing knowledge. It's about letting knowledge *flow*. Each Squad maintains ownership of their domain expertise, but makes it available for other Squads to use, adapt, and contribute back to.

We even have the infrastructure sketched out: https://github.com/tamirdresher/squad-skills currently has 10 plugins for common Squad tasks. These are the seeds of a marketplace.

### From One Squad to an Ecosystem

Let me zoom out. The trajectory looks like this:

**Personal Squad** (Part 1): One human, one repo, agents with persistent memory.

**Team Squad** (Part 2): Six humans, one repo, agents with routing rules and human governance.

**Squad Mesh** (the next leap): Multiple Squads, multiple repos, cross-team coordination and shared skills.

**Enterprise Squad Ecosystem** (the long view): Squads at every layer — product teams, platform teams, security, data, SRE — each with specialized agents and domain expertise, connected through a mesh that shares relevant skills and coordinates work across team boundaries.

The unit of AI adoption isn't the model. Isn't the prompt. Isn't even the agent. **It's the squad.** A team of specialized agents with persistent knowledge, clear roles, and the ability to collaborate — with humans, with each other, and with other squads.

We started with one person and a watch script. We're heading toward organizational intelligence that compounds across every team, every repo, every sprint.

The Borg knew something: "We are the Borg. We are everywhere." They had their subspace links and transwarp conduits. We'll have ours — git repos linking Squads across the org, knowledge propagating through a skills marketplace, decisions made at the edge but informed by the collective.

Somewhere in the next few months, I'll launch Part 4: "The Mesh." It's not a technical roadmap. It's an architecture for how AI becomes part of how work actually gets done — not replacing humans, but multiplying what each human (and each team) can accomplish.

---

## Honest Reflection

I've been running a multi-machine Squad for several weeks now. The voice cloning pipeline works. Cross-machine task routing works. Ralph successfully coordinates across my laptop and DevBox without me touching anything.

But let me be honest about the cost. I spent more time debugging distributed systems problems — merge conflicts, race conditions, stale heartbeats — than I spent on the actual feature work those machines were supposed to enable. The cross-machine system is useful, but it's also fragile in ways a single-machine setup isn't. Every new machine you add is another node that can fail, another clock that can drift, another git push that can conflict.

What keeps me going is the same thing that kept me going in [Part 1](/blog/2026/03/11/scaling-ai-part1-first-team): the trajectory. The merge conflicts got rarer as I hardened the retry logic. The race conditions got handled with the claim-wait-recheck pattern. The system gets a little more robust every week.

And when it works — when my laptop posts a voice cloning task at midnight, my DevBox picks it up at 12:05 AM, and I wake up to a finished Hebrew podcast episode sitting in my git repo — that's not automation. That's infrastructure. The kind of infrastructure that makes everything on top of it faster.

From one agent on one machine to a distributed AI team across multiple machines. The collective doesn't just scale up. It scales *out*. 🟩⬛

---

> 📚 **Series: Scaling AI-Native Software Engineering**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai)
> - **Part 1**: [Resistance is Futile — Your First AI Engineering Team](/blog/2026/03/11/scaling-ai-part1-first-team)
> - **Part 2**: [From Personal Repo to Work Team — Scaling Squad to Production](/blog/2026/03/12/scaling-ai-part2-collective)
> - **Part 3**: Unimatrix Zero — When Your AI Squad Becomes a Distributed System ← You are here
> - **Part 4**: The Mesh — coming soon
