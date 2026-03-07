# Digest Generator Quick Start

## What It Does

Automatically generates weekly/daily summaries of Squad activity from:
- **GitHub** — Issues and pull requests
- **Orchestration Logs** — Agent work and outcomes
- **Team Decisions** — Leadership decisions tracked in `.squad/decisions.md`

## Usage

### Basic Commands

```powershell
# Generate weekly digest (most common)
cd C:\temp\tamresearch1
.squad\scripts\generate-digest.ps1

# Generate daily digest
.squad\scripts\generate-digest.ps1 -Period daily

# Generate 14-day digest
.squad\scripts\generate-digest.ps1 -Period 14

# Custom output location
.squad\scripts\generate-digest.ps1 -Period weekly -OutputPath ./reports/
```

### Output

Each digest is saved to `.squad/digests/digest-{date}-{period}.md`

Example:
- `.squad/digests/digest-2026-03-07-daily.md`
- `.squad/digests/digest-2026-03-07-weekly.md`

## What's Inside a Digest

- **Summary** — Counts of issues, PRs, agent operations, decisions
- **GitHub Activity** — Recent issues and PRs with links
- **Agent Operations** — Work completed by Squad agents
- **Team Decisions** — New decisions made this period
- **Insights** — Trends and statistics (e.g., % PR work, most active agent)

## Digest Contents Example

```markdown
# Squad Digest — 2026-03-07 (weekly)

**Period:** 3/1/2026 → 3/7/2026

## Summary
- **GitHub Issues:** 12
- **Pull Requests:** 5  
- **Agent Operations:** 8
- **Team Decisions:** 3

## GitHub Activity
### Issues (12)
- **#22** — Implement Continuous Learning Phase 2
  - **State:** open | **Author:** tamirdresher
  - **Updated:** 3/7/2026
...

## Agent Operations
- **Data** — `2026-03-07T15-37-53Z-data.md`
  - **Outcome:** SUCCESS
  - **Timestamp:** 2026-03-07 15:37:53

...

## Insights
- GitHub saw **17 activity items** this period
- **29%** of activity was pull request work
- Squad agents executed **8 operations**
- **Most active agent:** Data (3 operations)
- Team made **1** new decision(s) this period
```

## Automation Options

### Option 1: Windows Scheduled Task

```powershell
# Run as Administrator
$action = New-ScheduledTaskAction -Execute 'pwsh' -Argument '-File C:\temp\tamresearch1\.squad\scripts\generate-digest.ps1 -Period weekly'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 09:00
$task = Register-ScheduledTask -TaskName "Squad-Weekly-Digest" -Action $action -Trigger $trigger -Force
Write-Host "Task created: $($task.TaskName)"
```

### Option 2: Add to Ralph Watch

Edit `ralph-watch.ps1` to generate digest after each round:

```powershell
# Add after: agency copilot ... line
$digestPath = & .squad\scripts\generate-digest.ps1 -Period daily
if ($digestPath) {
    Write-Host "Daily digest generated: $digestPath" -ForegroundColor Green
}
```

### Option 3: Manual Cron (Linux/Mac)

```bash
# Weekly digest every Monday at 09:00
0 9 * * 1 cd /path/to/tamresearch1 && pwsh .squad/scripts/generate-digest.ps1 -Period weekly
```

## What Data Sources Look Like

### GitHub Activity
- Issues and PRs collected from current repository
- Shows title, state (open/closed/merged), author, update date
- Requires `gh` CLI installed and authenticated

### Orchestration Logs
- Stored in `.squad/orchestration-log/` directory
- Named: `{timestamp}-{agent-name}.md` or with revision suffix
- Parser extracts: agent name, outcome, timestamp

### Team Decisions
- Tracked in `.squad/decisions.md`
- Each decision starts with `## Decision N: {Title}`
- Digest shows most recent decision and total count

## Troubleshooting

### "Could not fetch GitHub issues (gh CLI may not be configured)"

**Solution:** Install and authenticate `gh` CLI, or digest will skip GitHub data and continue with other sources

### Orchestration logs show warnings

**Expected behavior** — Parser attempts to extract structured data; older files may have different formats. Warnings are non-fatal; digest continues.

### No GitHub data in digest

**Check:** 
1. Is `gh` CLI installed? `gh --version`
2. Are you authenticated? `gh auth status`
3. Is there recent activity? (digest only shows last N days)

### Decision section is empty

**Check:** `.squad/decisions.md` file was modified in the digest period

## Next Steps

**Phase 3 coming:** LLM-powered insights that will analyze patterns and suggest improvements based on digest trends.

---

**Script:** `.squad/scripts/generate-digest.ps1`  
**Documentation:** `.squad/digest-generator-design.md`  
**Generated Digests:** `.squad/digests/`
