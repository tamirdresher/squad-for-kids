# Event-Driven Agent Triggers — Gap Analysis

> Issue: #805 — Add event-driven agent triggers beyond GitHub Issues

## 1. Current Trigger Mechanisms (Exhaustive)

### A. Manual / Interactive

| Trigger | How It Works | Frequency |
|---------|-------------|-----------|
| **CLI spawn** | User starts a Copilot session and says `{Agent}, work on X` | On-demand |
| **Team fan-out** | `"Team, ..."` message → all relevant agents spawn in parallel | On-demand |
| **Workflow dispatch** | Manual trigger via GitHub Actions UI | On-demand |

### B. Label-Driven (GitHub Issues)

| Trigger | Workflow | Target |
|---------|----------|--------|
| `squad` label applied | `squad-triage.yml` | Picard (Lead) triages, assigns `squad:{member}` |
| `squad:{member}` label applied | `squad-issue-assign.yml` | Named agent picks up issue |
| `squad:copilot` label applied | `squad-issue-assign.yml` | @copilot auto-assigned via PAT |

### C. Scheduled / Periodic

| Trigger | Workflow / Script | Frequency |
|---------|------------------|-----------|
| Ralph monitoring loop | `ralph-watch.ps1` | Every 5 min (300s default) |
| Daily digest | `squad-daily-digest.yml` | 8 AM UTC daily |
| Tech news scan | `tech-news-scan.yml` | 9 AM UTC daily |
| Board reconciliation | Ralph loop | Every 5 min |
| Done item archiving | Ralph loop / `squad-archive-done.yml` | Every 5 min / scheduled |

### D. Event-Reactive (GitHub Actions)

| Trigger | Workflow | Event |
|---------|----------|-------|
| Push to main/dev | `squad-ci.yml` | Run tests |
| PR created/updated | `label-squad-prs.yml` | Auto-label PRs |
| PR validation | `squad-label-enforce.yml` | Enforce required labels |
| Issue closed | `squad-issue-notify.yml` | Teams notification |
| Push to main | `squad-docs.yml` | Build docs |
| Push/PR/scheduled | `codeql-analysis.yml` | Security scanning |

### E. Indirect / Downstream

| Trigger | Mechanism | Target |
|---------|-----------|--------|
| Agent produces >500 word deliverable | Ralph loop checks | Podcaster generates audio |
| Ralph detects newsworthy activity | Ralph loop | Neelix sends Teams report |
| Email from GitHub (alerts) | Ralph email monitor | Creates issue with labels |
| Teams message mentioning squad | Ralph Teams monitor | Creates `teams-bridge` issue |

---

## 2. Gap Analysis — Events That SHOULD Trigger Agents But Don't

### Gap 1: CI/CD Workflow Failures → No Automatic Triage

**Current state:** When a GitHub Actions workflow fails, nothing happens. Ralph may eventually notice via email monitoring, but this is indirect (depends on email delivery, Ralph's 5-minute cycle, and email parsing reliability).

**Desired state:** A workflow failure immediately creates a GitHub issue labeled for squad triage, routing to the right agent based on failure type (infra vs. code).

**Impact:** HIGH — CI failures block the entire team. Minutes matter.

### Gap 2: PR Review Stale → No Nudging

**Current state:** PRs that sit unreviewed for days have no automated escalation. Ralph monitors issues but doesn't track PR review staleness.

**Desired state:** PRs unreviewed for >24h trigger a reminder. PRs unreviewed for >48h escalate to Lead.

**Impact:** MEDIUM — Review delays slow velocity but aren't blocking.

### Gap 3: Deployment Failures → No Automatic Response

**Current state:** If `squad-promote.yml` or `squad-release.yml` fails, there's no automatic issue creation or agent notification.

**Desired state:** Deployment failures create urgent issues with `squad:belanna` label for immediate infra triage.

**Impact:** HIGH — Deployment failures can mean production is stale or broken.

### Gap 4: Security Alert Events → No Real-Time Response

**Current state:** CodeQL findings and Dependabot alerts generate GitHub notifications, but only get picked up when Ralph checks email. No `workflow_run` or `repository_vulnerability_alert` trigger exists.

**Desired state:** Security alerts immediately create issues labeled `squad:worf` for security triage.

**Impact:** HIGH — Security vulnerabilities need immediate response.

### Gap 5: File Change Patterns → No Specialized Routing

**Current state:** When PRs modify specific file patterns (e.g., `.squad/agents/`, `infrastructure/`, `*.csproj`), there's label automation but no agent spawning.

**Desired state:** PRs touching infrastructure files automatically request B'Elanna review. PRs touching security config automatically request Worf review.

**Impact:** LOW — Current label automation handles most of this; agent spawning would be incremental.

### Gap 6: Drift Detection Results → No Agent Response

**Current state:** `drift-detection.yml` can run and produce a report, but doesn't create issues or trigger agents when drift is found.

**Desired state:** Drift detected → issue created with `squad:belanna` for remediation.

**Impact:** MEDIUM — Drift is important but not urgent.

### Gap 7: Board Column Transitions → No Event Triggers

**Current state:** Ralph reconciles the board every 5 minutes, but column transitions (e.g., "In Progress" → "Blocked") don't trigger any agent action.

**Desired state:** When an issue moves to "Blocked", automatically spawn Q to investigate or Picard to reassign.

**Impact:** LOW — Ralph's 5-minute loop covers most of this.

---

## 3. Priority Ranking

| Rank | Gap | Value | Effort | Recommendation |
|------|-----|-------|--------|----------------|
| **1** | CI/CD Workflow Failures | HIGH | LOW | **Implement first** — single workflow file, immediate value |
| **2** | Deployment Failures | HIGH | LOW | Same pattern as #1, extend to deployment workflows |
| **3** | Security Alert Events | HIGH | MEDIUM | Requires `repository_vulnerability_alert` event handling |
| **4** | PR Review Stale | MEDIUM | MEDIUM | Needs scheduled workflow + PR age calculation |
| **5** | Drift Detection Response | MEDIUM | LOW | Add issue creation step to existing drift workflow |
| **6** | Board Column Transitions | LOW | HIGH | Requires GitHub Projects API event handling |
| **7** | File Change Routing | LOW | LOW | Extend existing label automation |

---

## 4. Recommended First Implementation

**CI/CD Workflow Failure Auto-Triage** (Gap 1)

**Why this one:**
- Highest impact (CI failures block everyone)
- Lowest effort (single workflow file using `workflow_run` event)
- Establishes the pattern for all future event-driven triggers
- Uses existing squad infrastructure (labels, triage, routing)

**Implementation:** `.github/workflows/auto-triage-failures.yml`
- Trigger: `workflow_run` completed with `conclusion: failure`
- Action: Create issue with title `[CI-Failure] {workflow} failed on {branch}`
- Labels: `squad`, `github-alert`, `ci-failure`
- Smart routing: infra workflows → `squad:belanna`, code workflows → `squad:data`
- Dedup: Skip if an open issue already exists for the same workflow

See the implementation in `.github/workflows/auto-triage-failures.yml`.
