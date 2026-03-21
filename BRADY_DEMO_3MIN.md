# Squad 3-Minute Demo Script for Brady Gaster

> **Target:** Show Squad's autonomous multi-agent workflow end-to-end in 3 minutes

## Demo Flow (180 seconds)

### 1. **Setup - The Before State** (30s)
- **Screen:** GitHub repo with open issue #XYZ (e.g., "Add TypeScript type safety to config loader")
- **Show:**
  - Issue has `squad` label (triage inbox)
  - GitHub Project board shows issue in "Todo" column
  - Ralph Watch running in terminal (last round timestamp visible)
- **Narration:** *"This is Squad - an AI agent team that works autonomously on GitHub issues. Here's an open issue waiting for triage. Ralph, our work monitor, polls every 5 minutes."*

### 2. **Ralph Detects & Routes** (30s)
- **Screen:** Ralph Watch terminal output
- **Show:**
  - Ralph detects new `squad` labeled issue
  - Reads issue content, checks `.squad/routing.md`
  - Assigns to **Scribe** (full-stack specialist) based on work type
  - Updates issue label from `squad` → `squad:scribe`
  - Moves board item: Todo → In Progress
  - Spawns Scribe agent with GitHub Copilot CLI
- **Narration:** *"Ralph triages the issue, routes it to Scribe based on expertise, updates the board, and spawns the agent. All automated."*

### 3. **Scribe Executes** (60s)
- **Screen:** Split view - Scribe terminal + GitHub PR page
- **Show Scribe's work (fast-forward):**
  - Creates branch `squad/XYZ-type-safety`
  - Reads existing code in `src/config.ts`
  - Adds TypeScript interface definitions
  - Updates function signatures
  - Writes test coverage
  - Commits changes with descriptive message
  - Pushes branch
  - Opens PR with:
    - Title referencing issue (#XYZ)
    - Body with "Closes #XYZ"
    - Requests review
- **Narration:** *"Scribe reads the code, makes the changes, adds tests, and opens a pull request. No human intervention."*

### 4. **CI & Verification** (30s)
- **Screen:** GitHub PR page
- **Show:**
  - GitHub Actions workflow runs (build + test)
  - All checks pass ✅
  - PR description clearly links to issue
  - File changes viewer shows TypeScript additions
- **Narration:** *"CI validates the changes. Everything passes. The PR is ready for review or auto-merge depending on team policy."*

### 5. **Completion & Notification** (30s)
- **Screen:** Split view - GitHub board + Microsoft Teams channel
- **Show:**
  - Board automatically moves issue: In Progress → Done
  - Issue closed via PR merge
  - Teams message from Neelix:
    ```
    ✅ Issue #XYZ completed by Scribe
    PR #123 merged: Added TypeScript type safety
    View: [link]
    ```
  - Ralph Watch log shows successful round completion
- **Narration:** *"Board syncs automatically. Teams gets notified. Ralph continues monitoring for the next issue. The entire workflow - from issue creation to code merged - was autonomous."*

---

## Key Messages (Supporting Points)

### What Makes This Special?
1. **True Multi-Agent Parallelism** - Ralph coordinates, specialists execute. Not a single chatbot.
2. **Deep GitHub Integration** - Issues, PRs, labels, project boards, CI workflows all native.
3. **Autonomous Operation** - Ralph Watch runs 24/7, no human needed for routine work.
4. **Continuous Learning** - Agents document decisions (`.squad/decisions.md`) and reusable patterns (`.squad/skills/`).
5. **Production-Ready** - Runs on AKS with CronJob scheduling, KEDA autoscaling, KAITO GPU inference (see `blog-part6-squad-on-kubernetes.md`).

### Technical Highlights
- **Framework:** GitHub Copilot CLI + custom orchestration
- **State Management:** Git-backed decisions, skills, and agent history
- **Routing Engine:** Label-based work assignment (`.squad/routing.md`)
- **Observability:** Structured logging, heartbeat files, Teams alerts
- **Deployment:** Docker + Kubernetes + Helm (see `infrastructure/helm/squad-ralph-cronjob/`)

### Live Demo Variants

#### Variant A: Real-Time (requires 5+ min wait for Ralph's next round)
- Create issue live
- Wait for Ralph's next scheduled round
- Watch entire flow in real-time
- **Pros:** Shows true autonomous operation
- **Cons:** Timing dependent, requires patience

#### Variant B: Pre-Recorded Screencast (recommended for 3-min constraint)
- Record full flow ahead of time
- Edit to exactly 3 minutes
- Add narration overlay
- **Pros:** Repeatable, timed perfectly, professional
- **Cons:** Not interactive

#### Variant C: Hybrid (best of both)
- Show pre-recorded video for main workflow
- Switch to live GitHub repo to show actual artifacts:
  - Merged PR
  - Closed issue
  - Updated board
  - Commit history
- **Pros:** Shows real results + fits time constraint
- **Cons:** Requires seamless transition

---

## Demo Preparation Checklist

### Pre-Demo Setup
- [ ] Ralph Watch running and healthy
- [ ] Test issue created with `squad` label
- [ ] GitHub Project board accessible (public or share screen)
- [ ] Teams webhook configured (for Neelix notifications)
- [ ] Terminal font size increased for readability
- [ ] GitHub repo switched to light theme (better for projectors)
- [ ] Screen recording software ready (if pre-recording)

### Artifacts to Show
- [ ] `.squad/team.md` - Team roster
- [ ] `.squad/routing.md` - Work assignment rules
- [ ] `.squad/agents/scribe/charter.md` - Agent definition
- [ ] `.squad/decisions.md` - Team decisions log
- [ ] `.squad/skills/github-project-board/SKILL.md` - Reusable pattern
- [ ] `ralph-watch.ps1` - Autonomous operation script
- [ ] `infrastructure/helm/squad-ralph-cronjob/` - Kubernetes deployment

### Fallback Plan
If live demo fails:
1. Use pre-recorded video
2. Show static screenshots of key artifacts
3. Walk through code in GitHub web UI
4. Demo architecture diagrams from blog posts

---

## Demo Script (Detailed Walkthrough)

### Opening (10s)
**Screen:** GitHub repo homepage with `.squad/` directory visible

*"Squad is an AI agent framework that runs autonomous teams of specialists on GitHub. Let me show you how it works end-to-end in 3 minutes."*

### Act 1: The Issue (20s)
**Screen:** GitHub issue #XYZ

*"Here's a new issue - we need to add TypeScript type safety to our config loader. It's labeled 'squad' which means it's in the triage inbox. Ralph, our work monitor agent, runs every 5 minutes and will pick this up."*

### Act 2: Ralph Triages (30s)
**Screen:** Ralph Watch terminal

```
[2026-03-20 14:00:00] Ralph Round 47 starting
[2026-03-20 14:00:03] Found 1 new squad issue: #XYZ
[2026-03-20 14:00:05] Reading .squad/routing.md
[2026-03-20 14:00:07] Work type: feature-dev, Language: typescript
[2026-03-20 14:00:09] Routing to: @scribe (confidence: high)
[2026-03-20 14:00:11] Updating labels: squad → squad:scribe
[2026-03-20 14:00:13] Moving board: Todo → In Progress
[2026-03-20 14:00:15] Spawning: agency copilot -P scribe ...
```

*"Ralph reads the issue, checks the routing rules, determines this is full-stack TypeScript work, assigns it to Scribe, updates the labels and board, then spawns the Scribe agent using GitHub Copilot CLI."*

### Act 3: Scribe Works (60s)
**Screen:** Scribe terminal output + GitHub PR (split)

```
Scribe: Reading issue #XYZ requirements
Scribe: Creating branch squad/XYZ-type-safety
Scribe: Analyzing src/config.ts
Scribe: Adding TypeScript interfaces...
Scribe: Updating function signatures...
Scribe: Adding test coverage...
Scribe: Running tests... ✅ All passed
Scribe: Committing changes
Scribe: Pushing to origin
Scribe: Opening PR #123
```

**GitHub PR shows:**
- Title: "Add TypeScript type safety to config loader (#XYZ)"
- Body: "Closes #XYZ" + description of changes
- Files changed: `src/config.ts`, `src/config.test.ts`
- Diff showing interface definitions and type annotations

*"Scribe creates a branch, reads the existing code, adds TypeScript type definitions, updates the functions, writes tests, and opens a pull request. All automated. The PR references the issue and includes a clear description."*

### Act 4: CI Validates (20s)
**Screen:** GitHub Actions workflow on PR

```
✅ Build (2m 34s)
✅ Test (1m 12s)
✅ Lint (0m 45s)
```

*"GitHub Actions runs the CI pipeline - build, test, lint. Everything passes. The code is ready."*

### Act 5: Completion (30s)
**Screen:** Split - GitHub board + Teams

**GitHub board:**
- Issue #XYZ moved from "In Progress" → "Done"
- Issue status: Closed (via PR #123)

**Teams message:**
```
✅ Scribe completed issue #XYZ
PR #123 merged: Add TypeScript type safety to config loader
Changes: 2 files, +47 lines
View PR: https://github.com/.../pull/123
```

**Ralph Watch terminal:**
```
[2026-03-20 14:05:30] Scribe completed issue #XYZ
[2026-03-20 14:05:32] Ralph Round 47 complete
```

*"The board updates automatically. Teams gets a notification from Neelix, our communications agent. And Ralph marks this round complete and goes back to waiting. The entire workflow - from issue creation to merged code - was fully autonomous."*

### Closing (10s)
**Screen:** `.squad/` directory structure

*"Squad runs 24/7 on Kubernetes, handling issues in parallel, learning from every task, and continuously improving. Visit github.com/bradygaster/squad to build your own AI agent team."*

---

## Technical Deep-Dive (Backup Material)

### If Brady Wants More Details

#### Architecture
- **Ralph Watch:** PowerShell script → CronJob on AKS
- **Agent Execution:** GitHub Copilot CLI subprocess per agent
- **State Storage:** Git-backed (decisions, skills, history)
- **Routing Logic:** YAML rules + keyword matching
- **Board Sync:** GitHub CLI (`gh project item-edit`)

#### Kubernetes Deployment
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: squad-ralph
spec:
  schedule: "*/5 * * * *"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: squad-ralph
          containers:
          - name: ralph
            image: ghcr.io/tamirdresher/squad-ralph:latest
            env:
            - name: GH_TOKEN
              valueFrom:
                secretKeyRef:
                  name: squad-secrets
                  key: github-token
```

#### Agent Spawning
```powershell
# ralph-watch.ps1 spawns agents like this:
$prompt = @"
You are Scribe, the Full-Stack specialist.
Issue #$issueNumber: $issueTitle
Read the issue, make the changes, open a PR.
"@

agency copilot -P scribe --prompt $prompt
```

#### Continuous Learning
```markdown
# .squad/decisions.md
## Decision 23: Always Run Tests Before PR
**Status:** ✅ Adopted
**Agents:** All

Every PR must include test execution results.
If tests fail, do not open PR - fix first.
```

```markdown
# .squad/skills/github-project-board/SKILL.md
**How to move items:**
gh project item-edit \
  --project-id PVT_kwXYZ \
  --field-id PVTF_lmnop \
  --item-id PVTI_abc123 \
  --text "Done"
```

---

## Demo Recording Guidance (If Pre-Recording)

### Recording Tools
- **OBS Studio** (free, open-source)
- **Camtasia** (paid, easier editing)
- **macOS Quicktime** (built-in, simple)

### Video Specs
- Resolution: 1920x1080 (1080p)
- Frame rate: 30 fps
- Format: MP4 (H.264)
- Duration: Exactly 3:00
- Audio: Clear narration, no background music

### Editing Tips
1. **Speed up slow parts** - Use 1.5x-2x speed for long operations (git clone, npm install, tests running)
2. **Add annotations** - Overlay text to highlight key points
3. **Use transitions** - Fade between major sections
4. **Test on projector** - Ensure text is readable
5. **Export with captions** - Auto-generate for accessibility

### Recording Checklist
- [ ] Terminal in fullscreen mode
- [ ] Font size: 18-20pt minimum
- [ ] High contrast theme (light background for projectors)
- [ ] Hide personal info (email, usernames if sensitive)
- [ ] Close unrelated browser tabs
- [ ] Disable notifications
- [ ] Microphone audio test
- [ ] Rehearse full script 2-3 times

---

## Alternative Demo: Live Walkthrough (No Waiting)

If you can't show Ralph's autonomous operation live, do a **guided tour of artifacts**:

### 5-Minute Guided Tour

1. **Show closed issue** (30s)
   - Find an issue that was completed by Squad
   - Show the issue → PR → commit flow

2. **Show the PR** (60s)
   - Agent's code changes
   - Test additions
   - Commit message format
   - PR description linking issue

3. **Show board state** (30s)
   - Issue moved through columns
   - Agent assignment labels

4. **Show Squad config** (60s)
   - `.squad/team.md` - roster
   - `.squad/routing.md` - assignment rules
   - `.squad/agents/scribe/charter.md` - agent definition

5. **Show Ralph Watch script** (30s)
   - Polling loop
   - Agent spawning logic
   - Board update code

6. **Show Kubernetes deployment** (30s)
   - Helm chart
   - CronJob definition
   - Secrets management

7. **Show learning artifacts** (30s)
   - `.squad/decisions.md` - team decisions
   - `.squad/skills/` - reusable patterns

8. **Call to action** (30s)
   - "Visit github.com/bradygaster/squad"
   - "npm install -g @bradygaster/squad"
   - "squad init to start your own team"

---

## Post-Demo Q&A Prep

### Expected Questions

**Q: How do agents avoid conflicts?**
A: Ralph uses CronJob `concurrencyPolicy: Forbid` to prevent overlapping rounds. Within a round, agents work on separate issues (no file locking needed since they don't share working directories).

**Q: What if an agent makes a mistake?**
A: The PR review process catches it. We can also configure rules like "PRs from agents require human approval" or "security changes must be reviewed by Worf".

**Q: Can agents collaborate on the same issue?**
A: Yes. Ralph can spawn multiple agents for one issue (e.g., Picard for coordination, Scribe for implementation, Seven for docs). They share context via issue comments.

**Q: How do agents learn?**
A: They read `.squad/decisions.md` before every task, extract new patterns into `.squad/skills/`, and append learnings to their `history.md`. The knowledge compounds over time.

**Q: What's the cost?**
A: GitHub Copilot CLI access (included with GitHub Copilot license) + AKS cluster costs (~$200/mo for small team). LLM API calls are via GitHub Copilot's infrastructure.

**Q: Can I use it with private repos?**
A: Yes. Use a GitHub PAT with repo access. For Kubernetes, use Workload Identity to eliminate secret rotation.

**Q: What about security?**
A: Worf agent reviews security-sensitive changes. Agents run in isolated containers. All actions are audited via git history and GitHub Actions logs.

**Q: Does it work with Azure DevOps?**
A: Not yet. Currently GitHub-native. ADO support is possible via MCP server (see `mcp-servers/azure-devops/`).

**Q: Can I run it locally?**
A: Yes. `ralph-watch.ps1` runs on Windows/Mac/Linux. Just needs PowerShell 7, Node.js, gh CLI, and GitHub Copilot CLI.

---

## Success Metrics (Post-Demo)

Track these to measure demo impact:

- [ ] Brady shares in his network
- [ ] Squad repo stars increase
- [ ] Squad npm package downloads spike
- [ ] Issues opened asking "how do I set this up?"
- [ ] Conference talk invitations
- [ ] Blog post shares on LinkedIn/Twitter
- [ ] Questions about AKS/KAITO integration (shows deep engagement)

---

## Resources for Brady

- **Demo repo:** https://github.com/tamirdresher/squad-repo
- **Squad framework:** https://github.com/bradygaster/squad
- **Architecture blog series:**
  - Part 1: Framework intro
  - Part 5: Distributed systems patterns
  - Part 6: Kubernetes architecture (this document references)
- **Ralph Watch script:** `ralph-watch.ps1`
- **Helm chart:** `infrastructure/helm/squad-ralph-cronjob/`
- **Sample artifacts:**
  - Closed issue + PR: [find a good example in repo]
  - Teams notification screenshot: `demos/teams-notification-example.png`
  - Board progression: `demos/board-progression.gif`

---

**END OF DEMO SCRIPT**

✅ **Ready for Brady:** This document provides everything needed for a compelling 3-minute Squad demo.
