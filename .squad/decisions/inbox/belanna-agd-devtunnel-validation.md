# Decision: AGD + DevTunnel Validation Guide Created

**Date:** 2026-03-19  
**Author:** B'Elanna  
**Issue:** #981  
**Status:** ✅ Guide created, blocked on Tamir action

## Summary

Created `docs/agd-devtunnel-validation.md` as the canonical guide for validating AGD + DevTunnel integration. Key findings:

1. **AGD is not documented in this repo** — term needs confirmation from Baseplatform RP Squad
2. **Most likely root cause of complaints:** The DevTunnel URL from 2026-03-11 (`0flc6tk5-62358.euw.devtunnels.ms`) is almost certainly expired; AGD backend config likely still points to it → 502/504 for all users
3. **Prior validation gap:** The March 11 validation only confirmed browser terminal connectivity — it never validated AGD → DevTunnel → RP traffic flow
4. **Tamir must:** confirm AGD acronym, run `devtunnel list` on DevBox, update AGD backend config, and run `gh auth login`

## Required Actions (blocked on human)

- Tamir confirms what "AGD" stands for in RP Squad context
- Tamir runs diagnostic script from guide Section 7 on DevBox
- RP Squad updates AGD backend to current tunnel URL

## Files Created

- `docs/agd-devtunnel-validation.md` — Full validation checklist + troubleshooting guide
