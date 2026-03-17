## 🔍 Pulse Component Comparison — Findings (Pre-Repo Share)

Brady hasn't shared a separate "Pulse" repo yet. However, `bradygaster/squad` (public, 858 stars) contains the upstream heartbeat/monitoring foundation. Here's what we have vs. what upstream provides.

---

### Brady's Upstream Monitoring (bradygaster/squad)

| Component | What it does |
|---|---|
| `templates/workflows/squad-heartbeat.yml` | GitHub Actions workflow — runs ralph-triage.js on issue close/label, PR close, manual dispatch. **Cron disabled** |
| `templates/ralph-triage.js` | Node.js script that reads `.squad/routing.md`, matches untriaged issues, outputs JSON decisions |
| `templates/workflows/squad-triage.yml` | Comprehensive triage workflow (11KB — more advanced variant) |
| Copilot auto-assign step | Finds `squad:copilot` labeled issues, assigns `copilot-swe-agent[bot]` |

**What upstream does NOT have:** No long-running daemon, no multi-machine coordination, no scheduled task execution beyond GitHub Actions cron, no health monitoring, no Teams/email/WhatsApp integration, no tech news scanning, no ADR monitoring, no metrics collection.

---

### Our Local Monitoring Stack (tamresearch1)

| Component | Description | Maturity |
|---|---|---|
| **ralph-watch.ps1 v8** | Long-running daemon: 5-min polling, mutex guard, round timeout (20min), structured logging, heartbeat file, Teams alerts on >3 failures, log rotation, multi-machine coordination (#346) | Production |
| `.squad/monitoring/schedule-state.json` | Tracks 3 scheduled monitors: ralph-heartbeat, teams-message-monitor, whatsapp-check | Production |
| `.squad/monitoring/brady-squad-state.json` | Watches upstream bradygaster/squad for new commits/releases | Production |
| `.squad/monitoring/adr-check-state.json` | Scans ADO PRs for Architecture Decision Records | Production |
| `.squad/monitoring/tech-news-state.json` | Scans Reddit/HN/blogs for tech news (190+ URLs tracked) | Production |
| `.squad/watch-config.json` | Configurable: interval, timeout, max concurrent agents, retry backoff | Production |
| **start-all-ralphs.ps1** | Multi-repo launcher | Production |
| `.ralph-state.json` | Issue retry counter (prevents infinite retries) | Production |
| `.ralph-watch.lock` | Lock file for external status reading | Production |

---

### Contribution Plan

**We Should Contribute Upstream (high value):**
1. **Daemon/polling pattern** — ralph-watch.ps1 solves a real gap. Contribute as TS `squad watch` or `squad pulse` CLI command
2. **Issue retry tracking** — `.ralph-state.json` prevents infinite retries on stuck issues
3. **Single-instance guard** — Mutex + lockfile protocol prevents duplicate monitors
4. **Configurable watch-config.json** — Interval, timeout, max concurrent agents, retry backoff schema
5. **Multi-machine coordination** — Machine-specific branch naming and issue claiming protocol (#346)

**We Should Adopt from Upstream:**
1. **TypeScript ralph-triage.js** — Uses routing.md directly
2. **Copilot auto-assign step** — Keep synced with upstream template
3. **SDK-First mode** (`squad.config.ts` + `squad build`) — Move config to TS builders

**Complementary (keep both):**
- Our monitoring state directory tracks domain-specific monitors (project-specific)
- Our Teams/WhatsApp/email integration — contribute the adapter interface, keep implementations local

---

### Ideal Merged Architecture

Brady's Pulse Engine (when shared): Core heartbeat loop (TypeScript, cross-platform), SDK/OTel integration, plugin system.

Our contributions become Pulse Plugins: multi-machine-coordinator, issue-retry-tracker, scheduled-task-runner, upstream-repo-watcher, health-state-tracker.

### Status
**Still blocked** on Brady sharing the dedicated Pulse repo. This analysis is based on the public `bradygaster/squad` repo. When Pulse arrives, we'll refine. The contribution plan above remains valid — these are gaps in the current Squad SDK.
