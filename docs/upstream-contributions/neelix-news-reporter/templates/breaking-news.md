# ⚡ Breaking News — Example Format

Use this template for urgent, time-sensitive alerts. Breaking news should be short, punchy, and attention-grabbing.

---

## Example: CI Failure

```
🚨 BREAKING NEWS 🚨
━━━━━━━━━━━━━━━━━━━

CI Pipeline FAILED on main

💥 Build #847 — 3 test failures in auth module
📎 PR #172 by @alice — "Add OAuth2 refresh flow"
⏰ Failed at 14:32 UTC

🔍 Quick look:
  - test_token_refresh_expired: AssertionError
  - test_oauth_callback_invalid: TimeoutError
  - test_session_cleanup: KeyError

⚡ Action needed: @alice @bob — please investigate

━━━━━━━━━━━━━━━━━━━
📡 Neelix Breaking News — this is not a drill! 🖖
```

## Example: Critical PR Merged

```
⚡ BREAKING — Major Merge Alert!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PR #180 MERGED: "Database migration to PostgreSQL 16"

🎯 What happened: The long-awaited DB migration just landed on main
👤 Author: @carol | Reviewers: @dave, @eve
📊 +2,847 / -1,203 across 42 files

⚠️ Heads up:
  - Run migrations before next deploy
  - Connection strings updated in config
  - Rollback plan documented in PR description

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📡 Neelix — This changes everything. Or at least the database. 🖖
```

## Example: Blocking Issue

```
🔴 BREAKING — BLOCKER DETECTED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Issue #195 is blocking 3 other work items!

🚫 "API gateway returning 503 in staging"
   Assigned: @frank | Priority: Critical
   Blocking: #192, #194, #196

📋 Impact: Sprint goal at risk — staging deploys halted

⚡ @lead — escalation recommended

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📡 Neelix Breaking News — resistance to this blocker is NOT futile! 🖖
```

## Format Guidelines

| Element | Rule |
|---------|------|
| Opening | Always start with 🚨 or ⚡ — grab attention |
| Body | Max 10 lines — keep it scannable |
| Action | Always specify who needs to act |
| Tone | Urgent but not panicked |
| Sign-off | Short, punchy, with personality |

## When to Send Breaking News

- CI/CD pipeline failure on main/release branches
- Critical or blocking issues created
- Major PRs merged (large impact)
- Security alerts
- Service outages or incidents

## Channel Routing

Breaking news should include: `CHANNEL: general` (or `CHANNEL: pr-code` for CI-specific alerts)
