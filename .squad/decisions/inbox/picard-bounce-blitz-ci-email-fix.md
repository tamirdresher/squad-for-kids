# Decision: bounce-blitz CI Fix — Email Spam Root Cause Resolved

**Date:** 2026-03-18  
**Author:** Picard (Lead)  
**Issue:** tamirdresher_microsoft/tamresearch1#965  
**Status:** Partially automated — human action needed for notification settings

## What Was Found

The personal email spam was caused by GitHub Actions failure notifications from `tamirdresher/bounce-blitz`. The CI was failing on every run because:
- The workflow used `npm ci` which requires a `package-lock.json`
- The `bounce-blitz` repo has no `package-lock.json` committed

## What Was Fixed Automatically

Updated `.github/workflows/ci.yml` on branch `squad/961-fix-ci-CPC-tamir-WCBED` (PR #9) to use `npm install` instead of `npm ci`. The CI should now pass.

## What Needs Human Action

1. **Merge PR #9** in `tamirdresher/bounce-blitz` to land the fix on main
2. **Adjust GitHub notification settings** at https://github.com/settings/notifications (as `tamirdresher`) — disable or filter Actions email notifications
3. **Long-term**: Commit `package-lock.json` to `bounce-blitz` (run `npm install` locally, commit the file), then restore `npm ci` + caching for reproducible, faster CI

## Decision for Future Agents

When creating CI workflows for repos without a `package-lock.json`, use `npm install` instead of `npm ci`. Alternatively, ensure `package-lock.json` is committed before enabling `npm ci` + `cache: 'npm'` in setup-node.
