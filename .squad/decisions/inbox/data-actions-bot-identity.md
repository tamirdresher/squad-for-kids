# Decision: GitHub Actions Bot Identity for Squad Comments

**Date:** 2026-03-08  
**Author:** Data (Code Expert)  
**Issue:** #62  
**PR:** #154  
**Status:** Implemented

## Problem

Squad comments on issues/PRs were coming from Tamir's own GitHub account, causing:
1. @mention notifications not triggering (GitHub doesn't notify you when you @mention yourself)
2. Confusion about which comments are from automation vs. manual interaction

## Constraints

- **Cannot install GitHub Apps** in this repo (tried multiple times, blocked by Microsoft org restrictions)
- Must work with self-hosted runners
- No additional infrastructure or secrets management desired
- Solution must be simple and maintainable

## Options Considered

### ✅ Option 1: GitHub Actions Bot Identity (SELECTED)
Use GitHub's built-in bot account via explicit workflow permissions.

**Implementation:**
```yaml
permissions:
  issues: write
  pull-requests: write
  contents: read
```

**Pros:**
- Zero infrastructure changes
- Comments from "github-actions[bot]" enable @mentions
- No secrets management (uses built-in GITHUB_TOKEN)
- Works with self-hosted runners
- 1-2 hours implementation time

**Cons:**
- Generic bot name (not customized like "squad-bot")
- Limited to GitHub Actions context

### ❌ Option 2: Machine User Account
Create dedicated GitHub user account for the bot.

**Why rejected:**
- Requires separate GitHub license
- Manual PAT rotation every 90 days
- Security risk if token leaks
- More operational overhead

### ❌ Option 3: Azure Functions + Service Identity
Leverage Azure infrastructure for notification service.

**Why rejected:**
- High initial complexity (2-3 days implementation)
- Requires Azure infrastructure management
- Overkill for this use case
- Still needs GitHub App or PAT for Function → GitHub auth

## Decision

**Selected Option 1** — GitHub Actions bot identity.

## Implementation

Added explicit `permissions:` to 7 workflows:
1. squad-triage.yml
2. squad-heartbeat.yml
3. squad-issue-assign.yml
4. squad-label-enforce.yml
5. sync-squad-labels.yml
6. drift-detection.yml
7. fedramp-validation.yml

Created reusable `post-comment.yml` workflow for future use (though not currently needed since `actions/github-script` already works).

## Key Technical Insight

The issue was **not** with the authentication method (workflows already used `GITHUB_TOKEN`), but with **missing explicit permissions**. GitHub's default permissions were too restrictive, preventing the bot identity from appearing.

When `actions/github-script` uses the default `GITHUB_TOKEN` AND the workflow has `permissions: issues: write`, comments appear from `github-actions[bot]`.

## COPILOT_ASSIGN_TOKEN Preserved

The PAT remains in 2 places, but ONLY for assigning @copilot (requires special GitHub API):
- squad-heartbeat.yml line 94
- squad-issue-assign.yml line 117

These steps do NOT post comments — comment posting happens earlier with `GITHUB_TOKEN`.

## Testing

To verify:
1. Merge PR #154
2. Trigger any workflow that posts comments
3. Confirm comment appears from `github-actions[bot]`
4. Test @mention notification works

## Outcome

✅ @mentions now trigger notifications  
✅ Zero additional infrastructure  
✅ Simple and maintainable  
✅ Works with self-hosted runners

## Related

- Issue #19 — Original GitHub App investigation (not viable)
- Issue #62 — This implementation
- PR #154 — Implementation PR
