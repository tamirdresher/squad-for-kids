# Decision: Gaming Repo CI Fix — Issue #961

**Date:** 2026-03-19  
**Agent:** B'Elanna  
**Issue:** tamirdresher_microsoft/tamresearch1#961

## What Was Fixed

Two JellyBolt gaming repos had failing CI:

### bounce-blitz
- **Root cause 1:** `actions/setup-node@v4` with `cache: 'npm'` — fails when no `package-lock.json` exists
- **Root cause 2:** `npm ci` — also fails without `package-lock.json`  
- **Root cause 3:** `revenuecat-expo-plugin@^0.1.0` in `package.json` — this package does NOT exist on npm

### idle-critter-farm  
- Same issues as bounce-blitz

## Fix Applied

- `.github/workflows/ci.yml`: Removed `cache: 'npm'` AND changed `npm ci` → `npm install`
- `package.json`: Replaced `revenuecat-expo-plugin` with `react-native-purchases@^8.1.2` (official RevenueCat SDK)

## PRs Created (CI passing ✅)

- bounce-blitz: https://github.com/tamirdresher/bounce-blitz/pull/10
- idle-critter-farm: https://github.com/tamirdresher/idle-critter-farm/pull/12

Branch: `squad/961-ci-fix-CPC-tamir-WCBED`

## Notes

- Previous fix (PRs #9 and #11 on `squad/961-fix-ci-CPC-tamir-WCBED`) only addressed `cache: 'npm'` but missed the `npm ci` and fake npm package issues
- `jellybolt-games` is an org coordination repo (no app code, no CI needed)
- `code-conquest` had no CI failures
- `brainrot-quiz-battle` has no CI workflow configured (separate tracking)

## Recommendation

Merge PRs #10 and #12. The old PRs (#9, #11) can be closed as superseded.
