# Decision: Gemini API Key Rotation — Issue #937

**Date:** 2026-03-16  
**Agent:** Worf

## Summary

Investigated GitHub secret scanning alerts #2 and #3 for exposed Gemini API keys.

## Findings

Two distinct Google API keys were committed in commit `0ec5b516` (Ralph merge):

1. **Key in `.nano-banana-config.json`** (`AIzaSyCE...`) — NOT publicly leaked
2. **Key in `.playwright-cli/` log** (`AIzaSyBW...`) — **PUBLICLY LEAKED**, multi-repo exposure

Both files are now gitignored (done in PR #646). No keys in current HEAD.

## Action Required

Tamir must rotate both keys at https://aistudio.google.com/app/apikey and dismiss alerts #2 and #3 as "Revoked".

## No Code Changes Needed

No PR created — the code is already clean. This is purely a credential rotation task for the human.

## Prevention Note

Push Protection was bypassed for commit `0ec5b516`. Consider enforcing push protection to block future bypasses.
