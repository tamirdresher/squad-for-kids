# Rework Rate Metric for AI Agent Outputs — Research Report

**Date:** 2026-03-12  
**Researcher:** Seven  
**Issue:** #445  
**Source:** [Harness State of DevOps Modernization 2026](https://www.harness.io/state-of-devops-modernization-2026)

---

## Executive Summary

**Rework Rate** is an emerging DevOps metric that tracks how much AI-generated output requires human correction. From the Harness 2026 report: AI tools are moving from "suggest" to "do" — making autonomous decisions in GitHub Actions, deployment pipelines, and code generation. The key finding: **very frequent AI users see 22% of deployments result in rollback/hotfix/incident, with 7.6hr MTTR, versus 15% and 6.3hr for occasional users**.

**Recommendation for Squad:** Implement a lightweight Rework Rate tracking system integrated with squad-monitor. **Priority: Medium** (Q2-Q3 2026). This metric will help us quantify whether our AI agents (Ralph, specialized agents) are truly saving time or creating downstream work.

---

## Key Findings from Harness Report

### 1. The AI Acceleration Paradox

**What the data shows:**
- 45% of very frequent AI users deploy daily or faster (vs 32% frequent, 15% occasional)
- **69% of very frequent AI users** say AI-generated code leads to deployment problems at least half the time (51% overall)
- **22% of deployments** by very frequent AI users result in rollback, hotfix, or customer-impacting incident (vs 15% occasional users)
- **7.6hr MTTR** for very frequent users vs 6.3hr for occasional users
- **47% of very frequent users** report manual downstream work (QA, reviews, remediation) became more problematic (vs 28% occasional users)

**Translation:** Speed gains from AI coding tools are real, but they're creating downstream stability strain. Teams are deploying faster but breaking more often and taking longer to recover.

### 2. Security & Compliance Strain

- **50% of very frequent AI users** cite more vulnerabilities and security incidents since adopting AI coding tools (vs 26% occasional)
- **50% report more non-compliance issues** (vs 26% occasional)
- **49% report more performance problems** (vs 25% occasional)
- **51% cite more code quality issues** (vs 34% occasional)

**Translation:** AI-generated code isn't just breaking builds — it's introducing security vulnerabilities, compliance violations, and performance issues that require human review and rework.

### 3. Downstream Manual Toil

- **69% report wasting time due to slow/unreliable CI/CD pipelines**, contributing to burnout
- **70% say pipelines are plagued by flaky tests and deployment failures**
- **75% say pressure to ship quickly contributes to burnout**
- **96% of very frequent AI users** work evenings/weekends "a few times a month or more" for release tasks/incidents

**Translation:** AI is accelerating code generation, but the quality gates (testing, deployment, monitoring) haven't kept pace. Human operators are working overtime to catch AI mistakes.

### 4. The "Rework Rate" Concept

While the Harness report doesn't use the term "Rework Rate" explicitly, the concept emerges from multiple data points:
- **Rollback/hotfix rate** (22% for very frequent AI users)
- **MTTR increase** (7.6hr vs 6.3hr)
- **Manual downstream work increase** (47% say it's "more problematic")
- **Code review cycles** (implied by "manual remediation" burden)
- **Security/compliance fix cycles** (50% report more incidents)

**Definition (inferred):** Rework Rate = (AI-generated outputs requiring human correction) / (total AI-generated outputs)

This can be measured at multiple stages:
- **Pre-commit:** How many AI suggestions are rejected/modified before commit?
- **PR review:** How many revision cycles before approval?
- **Post-deployment:** How many rollbacks, hotfixes, or incidents?

---

## How This Applies to Squad

### Our AI Agent Workflow

**Current state:**
- Ralph (automation agent) runs every 5 minutes via `ralph-watch.ps1`
- Ralph spawns specialized agents (Picard, Worf, B'Elanna, Seven, etc.) for domain-specific work
- Agents make real changes: open PRs, commit code, update docs, manage issues
- squad-monitor tracks: token usage, tool invocations, sub-agent spawns, PR status, issue status

**AI-generated outputs in our workflow:**
1. **Code changes** — Ralph/agents write code, edit files, create new features
2. **Pull requests** — Agents open PRs with descriptions, request reviews
3. **Issue management** — Agents create, update, close issues, add comments
4. **Documentation** — Agents write/update markdown files, research reports
5. **Configuration changes** — Agents modify .squad/ config, decisions.md, etc.

**Where rework happens:**
- **PR review cycles** — Human reviewer requests changes → agent revises → repeat
- **Rejected PRs** — Human closes PR without merging (agent's work discarded)
- **Issues reopened** — Agent marks issue as done, but human reopens due to incomplete fix
- **Documentation corrections** — Human edits agent-written docs for accuracy/clarity
- **Rollback commits** — Agent's commit breaks something, human reverts
- **CI failures** — Agent's code fails tests, human fixes or agent retries

### What We Can Measure

Our existing infrastructure (squad-monitor, GitHub API, git history) already captures most data needed for Rework Rate:

| Metric | Data Source | Currently Tracked? |
|--------|-------------|-------------------|
| PR revision cycles | GitHub API (PR events, review requests) | ❌ No |
| PR rejection rate | GitHub API (closed PRs without merge) | ❌ No |
| Issue reopen rate | GitHub API (issue state transitions) | ❌ No |
| CI failure rate | GitHub API (check runs, status checks) | ⚠️ Partial (PR status shown, not tracked over time) |
| Rollback/revert commits | Git history (commit messages with "revert", "rollback") | ❌ No |
| Review comment density | GitHub API (PR review comments per file changed) | ❌ No |
| Time to first approval | GitHub API (PR created → first approval) | ❌ No |
| Time to merge | GitHub API (PR created → merged) | ⚠️ Partial (shown in dashboard, not aggregated) |

**Gap:** We track *activity* (tool calls, token usage, PRs opened) but not *quality* (how much rework was needed).

---

## Recommendations

### 1. Define Rework Rate for Squad

**Proposed definition:**

```
Rework Rate = (PR revision cycles + PR rejections + issue reopens + CI failures) / (total agent outputs)
```

**Component metrics:**
- **PR Revision Rate** = Average review cycles per merged PR
- **PR Rejection Rate** = Closed PRs without merge / Total PRs opened
- **Issue Reopen Rate** = Issues reopened / Issues closed by agents
- **CI Failure Rate** = Failed CI runs / Total CI runs on agent PRs
- **Time to Merge (TTM)** = Average time from PR creation to merge (longer TTM suggests more rework)

**Thresholds (proposed):**
- 🟢 Low Rework: <2 review cycles, <10% rejections, <5% reopens, <20% CI failures
- 🟡 Medium Rework: 2-3 review cycles, 10-20% rejections, 5-15% reopens, 20-40% CI failures
- 🔴 High Rework: >3 review cycles, >20% rejections, >15% reopens, >40% CI failures

### 2. Data Collection Strategy

**Phase 1 (Manual Baseline):** Run a one-time audit (1-2 weeks of data)
- Query GitHub API for last 100 agent PRs
- Calculate baseline metrics manually (script or spreadsheet)
- Identify which agents/work types have highest rework
- **Effort:** ~8 hours (one-time) | **Value:** Validates whether rework is actually a problem

**Phase 2 (Automated Tracking):** Integrate with squad-monitor
- Add `ReworkMetrics.cs` class to squad-monitor
- Query GitHub API every refresh cycle (same as existing PR/issue fetching)
- Cache metrics in `~/.squad/rework-metrics.json`
- Display new dashboard section: "Rework Rate (Last 30 Days)"
- **Effort:** ~16-24 hours dev + testing | **Value:** Continuous visibility, trend detection

**Phase 3 (Alerting & Optimization):** React to high rework
- Alert when rework rate exceeds thresholds (webhook to Teams/Slack)
- Tag agents with high rework rates in orchestration logs
- Generate weekly rework summary reports
- Use data to refine agent prompts, improve quality gates
- **Effort:** ~8 hours | **Value:** Proactive quality improvement

### 3. Technical Implementation Plan

#### 3.1. New Script: `Get-ReworkMetrics.ps1`

**Purpose:** Query GitHub API and calculate rework metrics

**Inputs:**
- GitHub repo (from git remote)
- Date range (default: last 30 days)
- Agent filter (optional: only track specific agents)

**Outputs:**
- JSON file: `~/.squad/rework-metrics.json`

**Logic:**
```powershell
# Fetch all PRs by agents (author matches squad members or bot accounts)
$prs = gh pr list --state all --limit 500 --json number,author,state,createdAt,closedAt,mergedAt,reviews,commits

# Calculate metrics
$mergedPRs = $prs | Where-Object { $_.mergedAt }
$rejectedPRs = $prs | Where-Object { $_.state -eq "CLOSED" -and !$_.mergedAt }

$revisionRate = ($mergedPRs | ForEach-Object {
    ($_.reviews | Where-Object { $_.state -eq "CHANGES_REQUESTED" }).Count
}) | Measure-Object -Average

$rejectionRate = $rejectedPRs.Count / $prs.Count
# ... etc
```

#### 3.2. Integrate with squad-monitor

**Add to `Program.cs`:**
- New method: `DisplayReworkMetrics(teamRoot)`
- Load `~/.squad/rework-metrics.json`
- Render table with color-coded thresholds

**Dashboard section example:**
```
┌─────────────────────────────────────────────────────────────────┐
│ Rework Rate (Last 30 Days)                                      │
├─────────────────────────────────────────────────────────────────┤
│ PR Revision Rate:     2.3 cycles/PR    🟡 MEDIUM               │
│ PR Rejection Rate:    12% (8/67 PRs)   🟡 MEDIUM               │
│ Issue Reopen Rate:    7% (3/42 issues) 🟢 LOW                  │
│ CI Failure Rate:      18% (45/250)     🟢 LOW                  │
│ Avg Time to Merge:    4.2 hours        🟢 LOW                  │
│                                                                 │
│ Highest Rework Agents:                                          │
│ 1. Ralph (automation) — 3.1 cycles/PR                           │
│ 2. B'Elanna (infra)   — 2.8 cycles/PR                           │
│ 3. Worf (security)    — 2.2 cycles/PR                           │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.3. Update `automation-watch.ps1`

**Add metrics collection to automation loop:**
```powershell
# After git pull, before running agent
& "$PSScriptRoot/.squad/scripts/Get-ReworkMetrics.ps1" -Days 30
```

This keeps metrics fresh without requiring squad-monitor to poll GitHub API continuously.

### 4. Integration with Existing Squad Tools

**squad-monitor** (already exists):
- Add rework metrics display alongside token usage, PR status, issues
- Color-coded thresholds (green/yellow/red)
- Historical trend (7-day vs 30-day comparison)

**automation-watch.ps1** (already exists):
- Call `Get-ReworkMetrics.ps1` once per loop
- Include rework rate in round summary logs
- Alert if rework exceeds thresholds (via existing webhook)

**Orchestration logs** (already exists):
- Tag agent activities with rework context (e.g., "PR revised 3 times")
- Link to PR/issue for manual inspection

### 5. Priority & Timeline

**Priority: Medium (Q2-Q3 2026)**

**Reasoning:**
- ✅ **High value** — Quantifies whether our AI agents are truly saving time
- ✅ **Low effort** — Leverages existing infrastructure (squad-monitor, GitHub API, automation loop)
- ✅ **Actionable** — Data directly informs agent prompt refinement, quality gates
- ⚠️ **Not urgent** — We're a small team; current workflow is manageable without this
- ⚠️ **Dependency** — Requires baseline data collection before automated tracking is useful

**Suggested timeline:**
- **Week 1-2 (Q2):** Phase 1 manual baseline audit — validate the problem exists
- **Week 3-6 (Q2):** Phase 2 automated tracking — build `Get-ReworkMetrics.ps1` and integrate with squad-monitor
- **Week 7-8 (Q3):** Phase 3 alerting & optimization — add thresholds, webhooks, reports

**Total estimated effort:** 32-40 hours across 2 months

---

## Alternative Approaches Considered

### Option A: GitHub Actions Workflow
**Pros:** Native GitHub, automatic on PR/issue events  
**Cons:** Adds CI complexity, requires new workflow file, harder to test locally  
**Verdict:** ❌ Overkill for our small team; squad-monitor integration is simpler

### Option B: Azure DevOps Work Item Tracking
**Pros:** Rich query language, built-in dashboards  
**Cons:** Our issues are in GitHub, not ADO; would require sync/migration  
**Verdict:** ❌ We're GitHub-native; no reason to add ADO dependency

### Option C: Manual Weekly Review
**Pros:** Zero tooling required, flexible  
**Cons:** Manual toil, hard to spot trends, easy to forget  
**Verdict:** ⚠️ Good for Phase 1 baseline, but not sustainable long-term

### Option D: External Monitoring SaaS (e.g., LinearB, Swarmia)
**Pros:** Turnkey solution, nice dashboards, benchmarking  
**Cons:** Costs money, requires data export, less customizable  
**Verdict:** ❌ We already have squad-monitor; build on what we have

**Selected approach:** Extend squad-monitor (Option: Internal tooling enhancement)

---

## Open Questions

1. **Should we track token usage vs rework rate correlation?**  
   → Hypothesis: Higher token usage (more AI suggestions) might correlate with higher rework. Worth exploring.

2. **How do we distinguish agent-authored PRs from human-authored PRs?**  
   → Use commit author (Copilot bot account) or PR labels (`squad:*` tags) or commit message patterns.

3. **What about indirect rework? (e.g., Human fixes agent's code in a separate PR)**  
   → Phase 1 ignores this (too hard to attribute). Phase 3 could use git blame + commit message analysis.

4. **Should we track rework per agent type or per work type?**  
   → Both. Agent type (Ralph, Picard, Worf) shows which agents need prompt tuning. Work type (docs, code, infra) shows which domains are hard for AI.

5. **What about false positives? (e.g., PR revisions due to human preference, not agent error)**  
   → Accept some noise in Phase 1. Phase 2 could add manual "rework reason" tags in PR comments.

---

## References

- **Harness State of DevOps Modernization 2026** — https://www.harness.io/state-of-devops-modernization-2026
- **DORA Metrics** (context) — https://dora.dev/
- **Squad Monitor** (existing tool) — `C:\temp\tamresearch1\squad-monitor-standalone\`
- **Issue #445** — "lets see how we incoprate this"

---

## Appendix: Data from Harness Report

### Key Statistics (Very Frequent AI Users)

| Metric | Very Frequent Users | Occasional Users | Delta |
|--------|---------------------|------------------|-------|
| Daily+ deployments | 45% | 15% | +30% |
| Deployment problems ≥50% | 69% | 51% | +18% |
| Rollback/hotfix rate | 22% | 15% | +7% |
| MTTR (hours) | 7.6 | 6.3 | +1.3h |
| More vulnerabilities/security incidents | 50% | 26% | +24% |
| More non-compliance issues | 50% | 26% | +24% |
| More performance problems | 49% | 25% | +24% |
| Manual downstream work "more problematic" | 47% | 28% | +19% |
| Flaky tests/deployment failures | 79% | 63% | +16% |
| Work evenings/weekends "a few times/month+" | 96% | 66% | +30% |

**Interpretation:** AI tools accelerate code generation, but downstream quality gates (testing, review, deployment) haven't scaled proportionally. Result: faster delivery, but more rework and human toil.

---

**End of Report**
