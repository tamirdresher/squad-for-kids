# Decision: Teams Notification System for Issue Tracking

**Date:** 2026-03-08  
**Author:** Data  
**Status:** Implemented  
**Related:** Issue #104, PR #107

## Context

Users were not aware when issues were closed or when work was completed by squad agents. Issues closed silently with no external notification, requiring manual monitoring of GitHub notifications or repository activity.

User has Teams webhook integration available and requested:
1. Notifications when issues close
2. Daily digest of activity

## Decision

Implemented two GitHub Actions workflows:

### 1. Issue Close Notifications (`squad-issue-notify.yml`)
- **Trigger:** On issue close event
- **Notification content:**
  - Issue title, number, and link
  - Who closed it (user or agent)
  - Summary from last comment
  - Adaptive Card format for Teams
- **Secret required:** `TEAMS_WEBHOOK_URL`

### 2. Daily Digest (`squad-daily-digest.yml`)
- **Trigger:** Daily at 8:00 AM UTC (+ manual)
- **Digest content:**
  - Issues closed in last 24h
  - PRs merged in last 24h
  - Recently updated open issues with labels
  - Adaptive Card format for Teams
- **Secret required:** `TEAMS_WEBHOOK_URL`

## Alternatives Considered

1. **Email notifications:** Less real-time, requires SMTP configuration
2. **Slack integration:** User requested Teams specifically
3. **Single combined workflow:** Separated for independent triggers and clearer logs
4. **Plain text messages:** Adaptive Cards provide better UX and are standard for Teams integrations

## Consequences

### Positive
- Users instantly aware when issues close
- Daily digest provides activity summary without constant checking
- Adaptive Cards provide professional, interactive notifications
- Manual trigger allows testing without waiting for events
- Team can use pattern for other notification needs

### Negative
- Requires user to configure `TEAMS_WEBHOOK_URL` secret (one-time setup)
- Notifications only work if webhook is valid (silently fails if misconfigured)
- Daily digest time (8 AM UTC) may not align with all timezones

## Team Impact

This pattern can be reused for other notification scenarios:
- PR review requests
- Critical alerts from workflows
- Build/test failures
- Security scan results

Consider adding error handling/fallback if webhook fails in future enhancements.

## Configuration Required

User must add `TEAMS_WEBHOOK_URL` to repository secrets:
- Location: `C:\Users\tamirdresher\.squad\teams-webhook.url`
- Setup: Settings → Secrets → Actions → New repository secret
