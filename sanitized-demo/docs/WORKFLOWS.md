# GitHub Actions Workflows Guide

This document provides detailed information about all Squad automation workflows.

## Overview

Squad uses 6 GitHub Actions workflows to automate issue triage, label management, notifications, and scheduled tasks. All workflows are event-driven and can be manually triggered via `workflow_dispatch`.

## Workflows

### 1. squad-triage.yml — Issue Triage

**Purpose:** Automatically route new issues labeled `squad` to the appropriate agent based on their expertise.

**Triggers:**
- `issues.labeled` — When the `squad` label is added to an issue
- `workflow_dispatch` — Manual trigger

**What it does:**
1. Reads the team roster from `.squad/team.md`
2. Evaluates issue title and body against agent expertise
3. Checks @copilot capability fit if enabled:
   - 🟢 **Good fit** — Simple features, bug fixes, test coverage
   - 🟡 **Needs review** — Medium features, refactoring (PR review recommended)
   - 🔴 **Not suitable** — Architecture, security, performance
4. Routes to best-matching agent or defaults to Lead
5. Applies labels:
   - `squad:{agent-name}` — Agent assignment
   - `go:needs-research` — Default triage verdict
6. Posts triage comment with reasoning
7. Auto-assigns @copilot if configured and applicable

**Configuration:**
- Edit `.squad/team.md` to define agents and their roles
- Add `<!-- copilot-auto-assign: true -->` to enable @copilot auto-assign
- Define @copilot capability tiers in team.md:
  - `🟢 Good fit: bug fix, test coverage, lint, format`
  - `🟡 Needs review: medium feature, refactoring, api endpoint`
  - `🔴 Not suitable: architecture, system design, security, auth`

**Permissions:**
- `issues: write` — Add labels and comments
- `pull-requests: write` — Interact with PRs
- `contents: read` — Read team configuration

---

### 2. squad-heartbeat.yml — Ralph Heartbeat

**Purpose:** Run Squad triage every 5 minutes to keep issues moving through the workflow.

**Triggers:**
- `workflow_dispatch` — Manual trigger
- `schedule` — Every 5 minutes (cron: `*/5 * * * *`)

**What it does:**
1. Checks for `.squad-templates/ralph-triage.js` (Ralph's triage script)
2. Runs smart triage on untriaged issues
3. Outputs `triage-results.json` with decisions
4. Applies labels and posts comments for each triaged issue
5. Looks for `squad:copilot` labeled issues with no assignee
6. Auto-assigns @copilot to eligible issues with custom instructions

**Configuration:**
- Set `COPILOT_ASSIGN_TOKEN` secret for @copilot auto-assignment (requires PAT)
- Falls back to `GITHUB_TOKEN` if PAT not available
- Customize triage logic in `.squad-templates/ralph-triage.js`

**Permissions:**
- `issues: write` — Add labels, comments, assignees
- `pull-requests: write` — Interact with PRs
- `contents: read` — Read team configuration

---

### 3. squad-daily-digest.yml — Daily Activity Summary

**Purpose:** Send a daily summary of squad activity to Microsoft Teams.

**Triggers:**
- `schedule` — 8:00 AM UTC daily (cron: `0 8 * * *`)
- `workflow_dispatch` — Manual trigger

**What it does:**
1. Gathers last 24 hours of activity:
   - Closed issues (up to 50, displays 10)
   - Merged PRs (up to 50, displays 10)
   - Open issues (most recently updated, displays 10)
2. Formats data as Microsoft Teams Adaptive Card
3. Posts to Teams webhook (if `TEAMS_WEBHOOK_URL` is set)

**Configuration:**
- Set `TEAMS_WEBHOOK_URL` secret in GitHub repository
- Create Teams Incoming Webhook:
  1. Go to Teams channel → Connectors → Incoming Webhook
  2. Copy webhook URL
  3. Add as GitHub Secret

**Permissions:**
- `issues: read` — Read issue data
- `pull-requests: read` — Read PR data
- `contents: read` — Read repository

**Adaptive Card Sections:**
- **Title:** "Squad Daily Digest"
- **Facts:** Issue/PR counts (closed, merged, open)
- **Closed Issues:** Last 24h
- **Merged PRs:** Last 24h
- **Open Issues:** Recently updated
- **Action:** "View Repository" button

---

### 4. squad-issue-notify.yml — Issue Close Notification

**Purpose:** Notify Teams when an issue is closed.

**Triggers:**
- `issues.closed` — When any issue is closed

**What it does:**
1. Fetches issue details (title, number, URL)
2. Reads last 100 comments to find agent name
3. Extracts summary from last comment (up to 500 chars)
4. Determines closed_by user
5. Sends Teams notification with Adaptive Card

**Configuration:**
- Set `TEAMS_WEBHOOK_URL` secret
- Agent names detected: Lead, Code Expert, Infrastructure, Research, Security
  - Or falls back to `closed_by` user

**Permissions:**
- `issues: read` — Read issue data
- `contents: read` — Read repository

**Adaptive Card Sections:**
- **Title:** "Issue Closed" (green theme)
- **Facts:** Issue number/title, closed_by, agent
- **Summary:** Last comment snippet
- **Action:** "View Issue" button

---

### 5. sync-squad-labels.yml — Label Sync

**Purpose:** Automatically sync GitHub labels from the team roster to keep labels up-to-date.

**Triggers:**
- `push` — Changes to `.squad/team.md` or `.ai-team/team.md`
- `workflow_dispatch` — Manual trigger

**What it does:**
1. Parses `.squad/team.md` for squad members
2. Checks for @copilot presence (`🤖 Coding Agent`)
3. Creates/updates labels:
   - `squad` — Triage inbox (color: `9B8FCC`)
   - `squad:{agent-name}` — Per-agent labels (color: `9B8FCC`)
   - `squad:copilot` — @copilot label (color: `10b981`)
   - `go:yes/no/needs-research` — Triage verdicts
   - `release:v1.0.0/v2.0.0/backlog` — Release targets
   - `type:feature/bug/docs/chore` — Issue types
   - `priority:p0/p1/p2` — Priority levels

**Label Color Palette:**
- Squad labels: `9B8FCC` (purple)
- @copilot: `10b981` (green)
- go:yes: `0E8A16` (green)
- go:no: `B60205` (red)
- go:needs-research: `FBCA04` (yellow)
- priority:p0: `B60205` (red)
- priority:p1: `D93F0B` (orange)
- priority:p2: `FBCA04` (yellow)

**Permissions:**
- `issues: write` — Create/update labels
- `contents: read` — Read team configuration

---

### 6. squad-label-enforce.yml — Label Enforcement

**Purpose:** Enforce mutual exclusivity rules for label namespaces.

**Triggers:**
- `issues.labeled` — When any label is added to an issue
- `workflow_dispatch` — Manual trigger

**What it does:**
1. Checks if the applied label is in a managed namespace (`go:`, `release:`, `type:`, `priority:`)
2. Removes conflicting labels from the same namespace
3. Posts comment explaining the change
4. **Special rules:**
   - When `go:yes` is applied without a release target → auto-applies `release:backlog`
   - When `go:no` is applied → removes all `release:` labels

**Managed Namespaces:**
- `go:` — Triage verdict (yes/no/needs-research) — **mutually exclusive**
- `release:` — Release target (v1.0.0/v2.0.0/backlog) — **mutually exclusive**
- `type:` — Issue type (feature/bug/docs/chore) — **mutually exclusive**
- `priority:` — Priority level (p0/p1/p2) — **mutually exclusive**

**Permissions:**
- `issues: write` — Remove conflicting labels, post comments
- `pull-requests: write` — Interact with PRs
- `contents: read` — Read repository

---

## Workflow Configuration Tips

### Set Up Teams Notifications
1. Go to your Teams channel
2. Click "..." → Connectors → Configure Incoming Webhook
3. Name it "Squad Notifications"
4. Copy the webhook URL
5. In GitHub: Settings → Secrets and variables → Actions → New repository secret
6. Name: `TEAMS_WEBHOOK_URL`, Value: webhook URL

### Enable @copilot Auto-Assignment
1. Create a Personal Access Token (PAT) with `repo` scope
2. Add as GitHub Secret: `COPILOT_ASSIGN_TOKEN`
3. Add to `.squad/team.md`:
   ```markdown
   | @copilot | 🤖 Coding Agent | Good-fit automation |
   <!-- copilot-auto-assign: true -->
   ```

### Customize Triage Logic
Edit `.squad/team.md` to add agent-specific routing keywords:
```markdown
## Members

| Name | Role | Expertise |
|------|------|-----------|
| Lead | Coordinator | Planning, triage, cross-functional |
| Code Expert | Developer | C#, Go, .NET, testing |
| Infrastructure | DevOps | Deployment, CI/CD, cloud architecture |
```

Triage workflow will match keywords from issue text to agent roles.

### Adjust Schedule Frequencies
Edit workflow YAML files:
```yaml
on:
  schedule:
    - cron: '0 */2 * * *'  # Run every 2 hours
```

Standard cron syntax:
- `*/5 * * * *` — Every 5 minutes
- `0 8 * * *` — 8 AM UTC daily
- `0 2 * * 1` — 2 AM UTC every Monday

---

## Troubleshooting

### Workflows Not Running
- Check GitHub Actions is enabled: Settings → Actions → General
- Verify triggers are correct (schedules use UTC)
- Check workflow run history: Actions tab → Select workflow

### Teams Notifications Not Sent
- Verify `TEAMS_WEBHOOK_URL` secret is set
- Test webhook manually: `curl -X POST -H 'Content-Type: application/json' -d '{"text":"Test"}' <webhook-url>`
- Check workflow logs for errors

### @copilot Not Auto-Assigned
- Verify `COPILOT_ASSIGN_TOKEN` is set (requires PAT with `repo` scope)
- Check `.squad/team.md` has `<!-- copilot-auto-assign: true -->`
- Verify issue has `squad:copilot` label

### Labels Not Syncing
- Check `.squad/team.md` is properly formatted (must have `## Members` header and table)
- Verify workflow triggered (check Actions → sync-squad-labels)
- Manually trigger: Actions → sync-squad-labels → Run workflow

### Triage Not Working
- Verify `squad` label exists
- Check squad-triage workflow run logs
- Verify `.squad/team.md` has at least one agent with "Lead" role

---

## Best Practices

1. **Always sync labels after team changes** — Run `sync-squad-labels.yml` manually or commit changes to `.squad/team.md`
2. **Test workflows locally first** — Use `gh workflow run <workflow-name>` to manually trigger
3. **Monitor Teams notifications** — Set up a dedicated channel for Squad notifications
4. **Review workflow logs regularly** — Check Actions tab for failures
5. **Use semantic labels** — Follow the `namespace:value` pattern for new labels
6. **Document custom workflows** — If you add new workflows, document them here

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Teams Adaptive Cards](https://docs.microsoft.com/en-us/adaptive-cards/)
- [Cron Expression Reference](https://crontab.guru/)
- [Squad Framework](https://github.com/bradygaster/squad)
