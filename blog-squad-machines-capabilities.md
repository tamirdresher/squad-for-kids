---
layout: post
title: "Squad Machines — The Multi-Device Architecture That Runs Your AI Team"
date: 2026-03-24
tags: [ai-agents, squad, github-copilot, distributed-systems, multi-machine, architecture]
series: "Scaling AI-Native Software Engineering"
series_part: 5
---

> *"The machine does not care whether you're on a laptop, a DevBox, or a cloud VM. The squad adapts to the hardware it finds."*
> — From `.squad/SCHEDULING.md`

Before we talk about Kubernetes deployments and Helm charts and cloud-native infrastructure, we need to talk about something simpler: **what can a Squad machine actually do?**

Because the breakthrough in Squad wasn't just "AI agents working on issues." It was **AI agents that can run on any machine with the right capabilities, claim work intelligently, and coordinate across devices without a central server**.

This is the architecture story before the cloud migration. The foundation that made everything else possible.

---

## The Problem: Not All Machines Are Equal

My laptop has a browser. It can run Playwright tests. It has my personal GitHub account authenticated. It has my WhatsApp session for web automation tasks.

My Azure DevBox has a GPU. It can run voice synthesis. It has my work GitHub EMU account. It doesn't have a browser (it's headless).

My Azure VM has neither a GPU nor a browser, but it has 24/7 uptime and can run long-running background tasks without draining my laptop battery.

Same squad. Same codebase. Three radically different machines.

The naive approach: "Just run Ralph on one machine." That works until you need GPU for voice cloning and your laptop doesn't have one. Or until you need 24/7 monitoring and your laptop goes to sleep at night. Or until you need to run browser automation and your DevBox is headless.

The Squad approach: **machines declare capabilities, issues declare requirements, Ralph routes work to machines that match**.

---

## Machine Capabilities: The Foundation

Every Squad machine runs a capability discovery script on startup:

```powershell
# scripts/discover-machine-capabilities.ps1
$capabilities = @{}

# Check for GPU
if (nvidia-smi 2>$null) {
    $capabilities.gpu = $true
}

# Check for browser
if (Get-Command chromium-browser -ErrorAction SilentlyContinue) {
    $capabilities.browser = $true
}

# Check for authenticated GitHub accounts
$capabilities.personalGH = Test-GitHubAuth -Account "personal"
$capabilities.emuGH = Test-GitHubAuth -Account "emu"

# Check for WhatsApp session
$capabilities.whatsapp = Test-WhatsAppSession

# Write to manifest
$capabilities | ConvertTo-Json | 
    Set-Content ~/.squad/machine-capabilities.json
```

The result is a capability manifest for this specific machine:

```json
{
  "hostname": "TAMIRDRESHER",
  "capabilities": {
    "gpu": false,
    "browser": true,
    "whatsapp": true,
    "personalGH": true,
    "emuGH": false,
    "azureSpeech": false
  }
}
```

On my DevBox, the manifest looks different:

```json
{
  "hostname": "DEVBOX-TAMIR",
  "capabilities": {
    "gpu": true,
    "browser": false,
    "whatsapp": false,
    "personalGH": false,
    "emuGH": true,
    "azureSpeech": true
  }
}
```

Same squad code. Different hardware. Different services. **Different capability profile.**

---

## Issue Labels as Capability Requirements

Issues declare what they need using GitHub labels:

```yaml
Issue #507: Generate Hebrew podcast with voice cloning
Labels: squad:neelix, needs:gpu, needs:azure-speech
```

When Ralph sees this issue, he checks the local capability manifest:

```powershell
# In ralph-watch.ps1
$issue = Get-GitHubIssue -Number 507
$requiredCapabilities = $issue.labels | 
    Where-Object { $_.name -match '^needs:' } | 
    ForEach-Object { $_.name -replace '^needs:', '' }

$machineCapabilities = Get-Content ~/.squad/machine-capabilities.json | 
    ConvertFrom-Json

foreach ($required in $requiredCapabilities) {
    if (-not $machineCapabilities.capabilities.$required) {
        Write-Host "⏭️  Skipping issue #507 — missing capability: $required"
        return
    }
}

# All capabilities present — claim the issue
Invoke-SquadAgent -Issue 507 -Agent neelix
```

If the laptop Ralph sees issue #507, he skips it (no GPU). If the DevBox Ralph sees it, he claims it (has GPU + Azure Speech). **The routing happens automatically based on capability matching.**

No manual coordination. No "remember to run that task on the GPU machine." The machine that can do the work claims the work.

---

## The Multi-Machine Coordination Protocol

Once you have multiple machines running Ralph, you need a way to prevent two Ralphs from claiming the same issue simultaneously. The solution: **GitHub Issues as the distributed lock**.

Here's the protocol (from `.squad/SCHEDULING.md`):

### 1. Ralph Discovers Work

Every 5 minutes, each Ralph pulls the repo and scans for issues matching:

- Has a `squad:*` label (assigned to an agent)
- Not already assigned to a human
- Matches this machine's capabilities
- Not currently locked by another Ralph

### 2. Ralph Attempts to Claim

Ralph posts a comment:

```markdown
🔒 **Claimed by Ralph** (machine: TAMIRDRESHER, timestamp: 2026-03-24T14:32:00Z)

Assigned to: Neelix
Capabilities matched: gpu, azure-speech
```

The comment acts as a distributed lock. Ralph then checks: **am I the first comment claiming this issue?** If yes, proceed. If no, another Ralph beat me to it — abort.

### 3. Agent Executes

The winning Ralph spawns the agent (Neelix in this case), waits for completion, posts the result back to the issue.

### 4. Ralph Releases the Lock

When done, Ralph edits the original comment:

```markdown
✅ **Completed by Ralph** (machine: TAMIRDRESHER)

Duration: 8m 32s
Exit code: 0
PR created: #1234
```

The issue is now free for other work. If the agent failed, Ralph posts the error and releases the lock so another machine can retry.

---

## Cross-Machine Task Coordination

Sometimes you need **explicit** cross-machine work. Example: "Run this voice synthesis task on the GPU machine, then copy the result back to the laptop for blog integration."

For this, Squad has a git-based task queue (`.squad/cross-machine/`):

### Creating a Task

From my laptop, I create a task file:

```yaml
# .squad/cross-machine/tasks/voice-synthesis-001.yaml
id: voice-synthesis-001
source_machine: TAMIRDRESHER
target_machine: DEVBOX-TAMIR
priority: high
created_at: 2026-03-24T14:00:00Z
task_type: command
description: "Generate Hebrew podcast audio"
payload:
  command: "pwsh scripts/generate_hebrew_podcast.ps1"
  expected_duration_min: 15
status: pending
```

I commit and push. Done.

### The Target Machine Picks It Up

On the DevBox, Ralph runs the cross-machine watcher every cycle:

```powershell
# In ralph-watch.ps1 (DevBox)
pwsh scripts/cross-machine-watcher.ps1 -GitSync
```

The watcher:
1. Pulls the repo
2. Scans `.squad/cross-machine/tasks/` for tasks targeting this machine
3. Validates the command against a whitelist (security)
4. Executes the command
5. Writes a result file to `.squad/cross-machine/results/`
6. Pushes back to git

### Reading the Result

Back on my laptop, I pull and check the result:

```yaml
# .squad/cross-machine/results/voice-synthesis-001.yaml
task_id: voice-synthesis-001
executing_machine: DEVBOX-TAMIR
started_at: 2026-03-24T14:05:00Z
completed_at: 2026-03-24T14:18:00Z
exit_code: 0
stdout: "✅ Generated: hebrew-executive-summary.mp3 (4.2MB)"
status: completed
```

The audio file is committed to the repo. My laptop pulls it. The blog post gets the audio link. **Zero manual file copying. Zero SSH sessions. Just git.**

---

## What This Enables

### 1. Automatic Workload Distribution

Issues labeled `needs:gpu` automatically route to GPU machines. Issues labeled `needs:browser` route to machines with browsers. You don't manage this. Ralph does.

### 2. 24/7 Availability Without Always-On Laptops

My Azure VM runs Ralph continuously. My laptop Ralph only runs during the day. Background monitoring? VM. Interactive work with browser automation? Laptop. The squad adapts to which machines are online.

### 3. Graceful Degradation

If the GPU machine is offline, GPU tasks queue up. When it comes back, Ralph processes the backlog. If the laptop is offline, browser tasks wait. **No single point of failure.**

### 4. Capability Expansion

Adding a new machine? Run the capability discovery script. Commit the manifest. Ralph on that machine starts participating in work distribution immediately. No configuration updates. No central registry.

### 5. Security Isolation

My personal GitHub account lives on my laptop. My work EMU account lives on the DevBox. Issues that need to access work repos automatically route to the DevBox. Personal projects automatically route to the laptop. **Account isolation through capability routing.**

---

## The Directory Structure

Here's what the multi-machine architecture looks like in the repo:

```
.squad/
├── machine-capabilities/         # Capability manifests per machine
│   ├── TAMIRDRESHER.json
│   ├── DEVBOX-TAMIR.json
│   └── AZURE-VM-001.json
├── cross-machine/
│   ├── config.json               # Coordination settings
│   ├── tasks/                    # Pending task queue
│   │   └── *.yaml
│   └── results/                  # Execution results
│       └── *.yaml
├── SCHEDULING.md                 # Ralph coordination protocol
└── routing.md                    # Agent routing rules

scripts/
├── discover-machine-capabilities.ps1
├── cross-machine-watcher.ps1
└── ralph-watch.ps1
```

Every machine has the same code. The capability manifest determines what that machine can do. The cross-machine task queue enables explicit coordination when needed.

---

## Real-World Scenarios

### Scenario 1: Hebrew Podcast Generation

**Issue:** Generate a Hebrew podcast from a markdown blog post.

**Requirements:** `needs:gpu`, `needs:azure-speech`

**What happens:**
1. Laptop Ralph sees the issue, checks capabilities (no GPU), skips it
2. DevBox Ralph sees the issue, checks capabilities (has GPU + Azure Speech), claims it
3. DevBox runs the voice synthesis (15 minutes)
4. DevBox commits the audio file and posts the PR
5. Laptop Ralph reviews the PR (no special capabilities needed)

**Result:** The work automatically ran on the machine that could handle it. Zero manual intervention.

---

### Scenario 2: Browser Automation for Documentation Screenshots

**Issue:** Capture screenshots of the new dashboard UI for the docs.

**Requirements:** `needs:browser`

**What happens:**
1. DevBox Ralph sees the issue, checks capabilities (no browser — headless), skips it
2. Laptop Ralph sees the issue, checks capabilities (has browser), claims it
3. Laptop runs Playwright automation, captures screenshots
4. Laptop commits images to `/docs/screenshots/` and closes the issue

**Result:** Browser work stayed on the machine with a display. The headless DevBox never tried to run it.

---

### Scenario 3: Long-Running Test Suite

**Issue:** Run the full integration test suite (3 hours).

**Requirements:** `needs:24x7`

**What happens:**
1. Laptop Ralph sees the issue, checks capabilities (not 24/7 — laptop sleeps at night), skips it
2. Azure VM Ralph sees the issue, checks capabilities (24/7 uptime), claims it
3. VM runs the test suite for 3 hours
4. VM posts the test results and updates the issue

**Result:** The laptop didn't burn 3 hours of battery. The work ran on infrastructure designed for long-running tasks.

---

## The Cost of This Architecture

### What You Gain
- **Zero central coordination server** — git is the coordination backend
- **Automatic failover** — if one Ralph dies, another picks up the work
- **Capability-based routing** — work lands on the right hardware automatically
- **Multi-tenant isolation** — personal vs. work accounts stay separated
- **Scalability** — adding a machine is just "run Ralph + commit capability manifest"

### What You Pay
- **Eventual consistency** — task claim races are possible (mitigated by GitHub comment timestamps)
- **Git as a message queue** — not instant (5-minute polling cycle per Ralph)
- **Manual capability definition** — you write the discovery script for new capabilities
- **Lock contention** — high-velocity issue queues can cause Ralph instances to compete

For a personal squad or small team, the tradeoffs are overwhelmingly in favor of this design. You get distributed coordination without running Kafka, Redis, or RabbitMQ. The infrastructure you need already exists: git + GitHub + your machines.

---

## The Kubernetes Connection

This multi-machine architecture is what made the Kubernetes migration possible.

When we moved Squad to K8s (covered in the next post), we didn't throw away the capability model. We **translated** it. Machine capabilities became **Kubernetes node labels**. The capability discovery script became a **DaemonSet**. Cross-machine task queues became **Jobs**. Ralph became a **CronJob**.

But the mental model — machines declare capabilities, issues declare requirements, work routes intelligently — stayed the same. Kubernetes just gave us better primitives for expressing it.

The multi-machine Squad taught us:
- How to distribute work without a scheduler
- How to claim work without a lock server
- How to route based on capabilities without a service mesh
- How to coordinate across devices using only git

And once we understood those lessons, Kubernetes became the obvious next step. Because Kubernetes is what you reach for when you want to do all of those things at scale, with better tooling, without reinventing distributed systems primitives in PowerShell.

---

## The Transition Point

You know you've outgrown the multi-machine architecture when:

- You have more than 5 machines running Ralph
- Your capability discovery script is 1000+ lines and covers 30+ capabilities
- You're manually managing node pool sizing for GPU machines
- You're debugging lock contention between Ralph instances
- You're writing custom health checks and heartbeat files
- You're thinking "I wish I had real leader election"

That's when you migrate to Kubernetes. Not because the multi-machine model is wrong, but because **you've re-implemented half of Kubernetes and it's time to use the real thing**.

We hit that point in March 2026. The next post tells that story.

---

## What This Means for Your Squad

If you're running Squad today:

1. **Start with one machine.** Get the agents working. Get the workflow right. Don't prematurely distribute.

2. **Add a second machine when you hit a hard constraint.** Need GPU? Add a GPU machine. Need 24/7 uptime? Add a VM. Need browser automation on a headless CI server? Add a machine with a display.

3. **Use capability labels liberally.** Every time you add `needs:X`, you're declaring a routing requirement. Make it explicit. Ralph can't route what isn't labeled.

4. **Audit your capability manifests.** Run `discover-machine-capabilities.ps1` on each machine monthly. Capabilities drift. Services get uninstalled. Auth tokens expire. Keep the manifests current.

5. **Monitor cross-machine task latency.** If tasks are sitting in the queue for hours, either (a) the target machine is offline, or (b) you need more machines with that capability. The task queue tells you where the bottlenecks are.

6. **Plan your Kubernetes migration when you have 5+ machines.** That's the threshold where the operational overhead of managing individual machines exceeds the migration cost of moving to K8s.

---

The Squad machine model is what makes Squad portable. Your laptop, your DevBox, your VM, your Kubernetes cluster — they're all just **machines with capabilities**. The squad adapts to wherever it runs.

And that's the foundation. The rest is just better infrastructure.

Next: [The Unicomplex — AI Squads as Cloud-Native Kubernetes Citizens](/blog/2026/03/25/scaling-ai-part6-unicomplex)

---

> 📚 **Series: Scaling Your AI Development Team**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai)
> - **Part 1**: [Resistance is Futile — Your First AI Engineering Team](/blog/2026/03/11/scaling-ai-part1-first-team)
> - **Part 2**: [From Personal Repo to Work Team — Scaling Squad to Production](/blog/2026/03/12/scaling-ai-part2-collective)
> - **Part 3**: [Unimatrix Zero — When Your AI Squad Becomes a Distributed System](/blog/2026/03/18/scaling-ai-part3-distributed)
> - **Part 4**: [When Eight Ralphs Fight Over One Login](/blog/2026/03/17/scaling-ai-part4-distributed-failures)
> - **Part 5 (this post)**: Squad Machines — The Multi-Device Architecture
> - **Part 5b**: [Assimilating the Cloud — Running Your AI Squad on Kubernetes](/blog/2026/03/25/assimilating-the-cloud)
> - **Part 6**: [The Unicomplex — AI Squads as Cloud-Native Kubernetes Citizens](/blog/2026/03/25/scaling-ai-part6-unicomplex)

*All examples in this post are real. The capability discovery script is in `scripts/discover-machine-capabilities.ps1`. The cross-machine coordination code is in `.squad/cross-machine/`. The Hebrew podcast from issue #507 exists and is 4.2MB. This is not a thought experiment. This is production infrastructure that runs my squad every day.*
